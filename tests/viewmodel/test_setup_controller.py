"""
Pruebas de `viewmodel/setup_controller.py`.

`crear_modelo()` instancia el `Tokenizer` real (tiktoken), que la primera
vez necesita descargar un archivo desde internet. Para que estas pruebas
sean deterministas y no dependan de red, se reemplaza la clase
`Tokenizer` que usa el módulo (vía `monkeypatch`) por un doble sin red.

`_estimar_parametros` sí se prueba contra un `Transformer` REAL — ahí no
hay atajo válido: si la fórmula no coincide exacto con el modelo real,
la prueba debe fallar.
"""

import pytest

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from viewmodel import setup_controller as modulo_setup_controller
from viewmodel.setup_controller import SetupController


class TokenizerFalso:
    """Doble de `Tokenizer` sin dependencia de red, para pruebas."""

    def __init__(self, tipo_encoding: int = 1):
        self.tipo_encoding = tipo_encoding
        self._vocab_sizes = {0: 300, 1: 200, 2: 100}  # valores chicos, arbitrarios para pruebas
        if tipo_encoding not in self._vocab_sizes:
            raise ValueError(f"tipo_encoding invalido: {tipo_encoding}")
        self.vocab_size = self._vocab_sizes[tipo_encoding]

    def encode(self, texto):
        return [1, 2, 3]

    def decode(self, tokens):
        return "texto_falso"


@pytest.fixture(autouse=True)
def _reemplazar_tokenizer_por_doble(monkeypatch):
    """Reemplaza `Tokenizer` en el módulo `setup_controller` por el doble
    sin red, para TODAS las pruebas de este archivo."""
    monkeypatch.setattr(modulo_setup_controller, "Tokenizer", TokenizerFalso)


@pytest.fixture
def controlador() -> SetupController:
    return SetupController()


# ---------------------------------------------------------------------------
# _estimar_parametros — verificado contra Transformer REAL
# ---------------------------------------------------------------------------

class TestEstimarParametros:
    @pytest.mark.parametrize(
        "v,d,n,ff,compartir",
        [
            (200, 64, 2, 256, True),
            (200, 64, 2, 256, False),
            (1000, 128, 4, 512, True),
            (500, 96, 3, 300, False),
            (37, 16, 1, 40, True),   # dimensiones chicas/impares, caso borde
            (5000, 256, 6, 1024, True),
        ],
    )
    def test_coincide_exacto_con_modelo_real(self, v, d, n, ff, compartir):
        config = ConfiguracionTransformer(
            tamano_vocabulario=v, dimension_modelo=d, num_cabezas=4,
            num_capas=n, dimension_ff=ff, longitud_maxima_secuencia=50, dropout=0.1,
        )
        modelo = Transformer(config, compartir_pesos_salida=compartir)
        parametros_reales = sum(p.numel() for p in modelo.parameters())

        parametros_estimados = SetupController._estimar_parametros(
            v=v, d=d, n=n, ff=ff, compartir_pesos_salida=compartir
        )

        assert parametros_estimados == parametros_reales


# ---------------------------------------------------------------------------
# Resumen en vivo (sin crear el modelo)
# ---------------------------------------------------------------------------

class TestResumenEnVivo:
    def test_establecer_dimension_modelo_emite_resumen(self, qtbot, controlador):
        with qtbot.waitSignal(controlador.resumen_cambio, timeout=1000) as blocker:
            controlador.establecer_dimension_modelo(126)  # 126 % 6 == 0 (num_cabezas por defecto)

        resumen = blocker.args[0]
        assert "parametros_totales" in resumen
        assert "memoria_estimada_mb" in resumen
        assert resumen["parametros_totales"] > 0

    def test_resumen_cambia_al_aumentar_num_capas(self, qtbot, controlador):
        with qtbot.waitSignal(controlador.resumen_cambio, timeout=1000) as blocker_1:
            controlador.establecer_num_capas(2)
        parametros_2_capas = blocker_1.args[0]["parametros_totales"]

        with qtbot.waitSignal(controlador.resumen_cambio, timeout=1000) as blocker_2:
            controlador.establecer_num_capas(8)
        parametros_8_capas = blocker_2.args[0]["parametros_totales"]

        assert parametros_8_capas > parametros_2_capas

    def test_no_instancia_tokenizer_real_durante_el_preview(self, monkeypatch, qtbot, controlador):
        """Confirma que el preview NO llama al Tokenizer real — si lo
        hiciera, este monkeypatch (que rompe el Tokenizer real a
        propósito) haria fallar la prueba."""
        def tokenizer_roto(*args, **kwargs):
            raise ConnectionError("no deberia llamarse durante el preview")

        monkeypatch.setattr(
            "model.motor_llm.tokenizer.Tokenizer.__init__", tokenizer_roto
        )

        with qtbot.waitSignal(controlador.resumen_cambio, timeout=1000):
            controlador.establecer_dimension_modelo(120)  # 120 % 6 == 0
        # si llego hasta aqui sin excepcion, el preview no toco Tokenizer real

    def test_tipo_encoding_invalido_emite_error(self, qtbot, controlador):
        with qtbot.waitSignal(controlador.error_configuracion, timeout=1000) as blocker:
            controlador.establecer_tipo_encoding(99)

        assert "tipo_encoding" in blocker.args[0]

    def test_configuracion_invalida_emite_error_en_vez_de_resumen(self, qtbot, controlador):
        """dimension_modelo no divisible entre num_cabezas (4 por defecto)."""
        with qtbot.waitSignal(controlador.error_configuracion, timeout=1000):
            controlador.establecer_dimension_modelo(97)  # 97 no es divisible entre 4


# ---------------------------------------------------------------------------
# Creación del modelo
# ---------------------------------------------------------------------------

class TestCrearModelo:
    def test_crear_modelo_exitoso_emite_modelo_creado(self, qtbot, controlador):
        controlador.establecer_dimension_modelo(32)
        controlador.establecer_num_cabezas(4)
        controlador.establecer_num_capas(2)
        controlador.establecer_dimension_ff(64)

        with qtbot.waitSignal(controlador.modelo_creado, timeout=2000) as blocker:
            controlador.crear_modelo()

        modelo, tokenizer = blocker.args
        assert isinstance(modelo, Transformer)
        assert isinstance(tokenizer, TokenizerFalso)
        assert controlador.modelo is modelo
        assert controlador.tokenizer is tokenizer

    def test_modelo_creado_usa_el_vocab_size_del_tokenizer(self, qtbot, controlador):
        controlador.establecer_tipo_encoding(2)  # TokenizerFalso: vocab_size=100
        controlador.establecer_dimension_modelo(32)
        controlador.establecer_num_cabezas(4)

        with qtbot.waitSignal(controlador.modelo_creado, timeout=2000) as blocker:
            controlador.crear_modelo()

        modelo, _ = blocker.args
        # El vocabulario del modelo incluye PAD, BOS y EOS reservados encima
        # de los 100 tokens que entiende el encoding.
        assert modelo.config.tamano_vocabulario == 103

    def test_configuracion_invalida_no_crea_modelo(self, qtbot, controlador):
        controlador.establecer_dimension_modelo(97)  # invalido: 97 % 4 != 0
        with qtbot.waitSignal(controlador.error_configuracion, timeout=2000):
            controlador.crear_modelo()

        assert controlador.modelo is None
        assert controlador.tokenizer is None

    def test_crear_modelo_no_sobrescribe_uno_previo_si_falla(self, qtbot, controlador):
        controlador.establecer_dimension_modelo(32)
        controlador.establecer_num_cabezas(4)
        with qtbot.waitSignal(controlador.modelo_creado, timeout=2000):
            controlador.crear_modelo()

        modelo_previo = controlador.modelo
        tokenizer_previo = controlador.tokenizer

        controlador.establecer_dimension_modelo(97)  # ahora invalido
        with qtbot.waitSignal(controlador.error_configuracion, timeout=2000):
            controlador.crear_modelo()

        assert controlador.modelo is modelo_previo
        assert controlador.tokenizer is tokenizer_previo

    def test_compartir_pesos_salida_se_respeta_en_creacion(self, qtbot, controlador):
        controlador.establecer_dimension_modelo(32)
        controlador.establecer_num_cabezas(4)
        controlador.establecer_compartir_pesos_salida(False)

        with qtbot.waitSignal(controlador.modelo_creado, timeout=2000) as blocker:
            controlador.crear_modelo()

        modelo, _ = blocker.args
        assert modelo.capa_salida.weight is not modelo.embedding_salida.embedding.weight
