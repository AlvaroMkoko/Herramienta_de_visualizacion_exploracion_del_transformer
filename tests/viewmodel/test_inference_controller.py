"""
Pruebas de `viewmodel/inference_controller.py`.

Usa un tokenizador FALSO (`TokenizerDePrueba`) en vez de `Tokenizer`
(tiktoken real), para que las pruebas no dependan de red ni de un
vocabulario de ~100k tokens — solo nos importa que el controlador
orqueste correctamente el generador de `Transformer.generar()` dentro
de `GestorConcurrencia` (texto parcial, cancelación, pausa, velocidad),
no la calidad lingüística real.
"""

import pytest
import torch

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from viewmodel.inference_controller import InferenceController


class TokenizerDePrueba:
    """Tokenizador mínimo y determinista para pruebas: cada caracter se
    mapea a un id fijo dentro del rango del vocabulario de prueba."""

    def encode(self, texto: str) -> list[int]:
        return [(ord(c) % 40) + 1 for c in texto]  # ids en [1, 40], evita el 0 (relleno)

    def decode(self, tokens: list[int]) -> str:
        return ",".join(str(t) for t in tokens)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def config() -> ConfiguracionTransformer:
    return ConfiguracionTransformer(
        tamano_vocabulario=50,
        dimension_modelo=32,
        num_cabezas=4,
        num_capas=2,
        dimension_ff=64,
        longitud_maxima_secuencia=100,
        dropout=0.0,
        id_token_relleno=0,
    )


@pytest.fixture
def modelo(config) -> Transformer:
    torch.manual_seed(0)
    return Transformer(config)


@pytest.fixture
def tokenizer() -> TokenizerDePrueba:
    return TokenizerDePrueba()


@pytest.fixture
def controlador(qtbot, modelo, tokenizer) -> InferenceController:
    c = InferenceController(modelo, tokenizer, id_token_inicio=1, id_token_fin=None)
    yield c
    if c.esta_generando:
        c.detener()
        qtbot.waitUntil(lambda: not c.esta_generando, timeout=2000)


# ---------------------------------------------------------------------------
# Generación básica
# ---------------------------------------------------------------------------

class TestGeneracionBasica:
    def test_generacion_completa_emite_texto_final(self, qtbot, controlador):
        with qtbot.waitSignal(controlador.generacion_completa, timeout=5000) as blocker:
            controlador.iniciar_generacion("hola", max_tokens_nuevos=5, muestreo_codicioso=True)

        texto_final = blocker.args[0]
        assert isinstance(texto_final, str)
        assert len(texto_final.split(",")) == 5  # 5 tokens generados, formato "id,id,id..."

    def test_token_generado_incluye_texto_parcial_y_tensores(self, qtbot, controlador, config):
        pasos_recibidos = []
        controlador.token_generado.connect(pasos_recibidos.append)

        with qtbot.waitSignal(controlador.generacion_completa, timeout=5000):
            controlador.iniciar_generacion("hola", max_tokens_nuevos=4, muestreo_codicioso=True)

        assert len(pasos_recibidos) == 4
        for i, paso in enumerate(pasos_recibidos):
            assert "token_id" in paso
            assert "texto_parcial" in paso
            assert "logits" in paso
            assert "visualizacion" in paso
            assert paso["logits"].shape == (1, config.tamano_vocabulario)
            assert len(paso["pesos_atencion_cruzada_por_capa"]) == config.num_capas
            assert len(paso["texto_parcial"].split(",")) == i + 1

            visualizacion = paso["visualizacion"]
            assert visualizacion["paso"] == i + 1
            assert len(visualizacion["etapas"]) == 6
            assert visualizacion["tokens_entrada_total"] == 4
            assert visualizacion["tokens_salida_total"] == i + 1
            assert visualizacion["token_elegido"]["token_id"] == paso["token_id"]
            assert visualizacion["cantidad_candidatos"] == 1
            assert visualizacion["predicciones_top"]
            assert any(p["elegido"] for p in visualizacion["predicciones_top"])
            assert visualizacion["foco_entrada"]
            assert visualizacion["foco_decoder"]

        assert pasos_recibidos[-1]["texto_parcial"] == controlador._texto_generado_hasta_ahora

    def test_esta_generando_refleja_el_estado(self, qtbot, controlador):
        assert controlador.esta_generando is False

        with qtbot.waitSignal(controlador.generacion_completa, timeout=5000):
            controlador.iniciar_generacion("hola", max_tokens_nuevos=3, velocidad_inicial=0.05)
            assert controlador.esta_generando is True

        assert controlador.esta_generando is False

    def test_no_permite_doble_generacion_concurrente(self, qtbot, controlador):
        segundas_llamadas = {"contador": 0}
        controlador.token_generado.connect(
            lambda p: segundas_llamadas.__setitem__("contador", segundas_llamadas["contador"] + 1)
        )

        with qtbot.waitSignal(controlador.generacion_completa, timeout=5000):
            controlador.iniciar_generacion("hola", max_tokens_nuevos=5, velocidad_inicial=0.05)
            controlador.iniciar_generacion("mundo", max_tokens_nuevos=5, velocidad_inicial=0.05)

        assert segundas_llamadas["contador"] == 5


# ---------------------------------------------------------------------------
# Detener
# ---------------------------------------------------------------------------

class TestDetener:
    def test_detener_cancela_y_emite_texto_parcial(self, qtbot, controlador):
        with qtbot.waitSignal(controlador.generacion_cancelada, timeout=5000) as blocker:
            controlador.iniciar_generacion("hola", max_tokens_nuevos=50, velocidad_inicial=0.05)
            qtbot.wait(150)
            controlador.detener()

        texto_parcial = blocker.args[0]
        assert isinstance(texto_parcial, str)
        cantidad_tokens_parciales = len(texto_parcial.split(","))
        assert 0 < cantidad_tokens_parciales < 50
        assert controlador.esta_generando is False

    def test_iniciar_generacion_reinicia_el_texto_acumulado(self, qtbot, controlador):
        with qtbot.waitSignal(controlador.generacion_completa, timeout=5000):
            controlador.iniciar_generacion("hola", max_tokens_nuevos=5, muestreo_codicioso=True)

        assert controlador._texto_generado_hasta_ahora != ""

        with qtbot.waitSignal(controlador.generacion_cancelada, timeout=5000):
            controlador.iniciar_generacion("mundo", max_tokens_nuevos=50, velocidad_inicial=0.05)
            qtbot.wait(50)
            controlador.detener()

        assert controlador._texto_generado_hasta_ahora != ""


# ---------------------------------------------------------------------------
# Pausar / Reanudar / Velocidad
# ---------------------------------------------------------------------------

class TestPausaYVelocidad:
    def test_pausar_detiene_la_llegada_de_tokens(self, qtbot, controlador):
        tokens_recibidos = []
        controlador.token_generado.connect(tokens_recibidos.append)

        with qtbot.waitSignal(controlador.token_generado, timeout=2000):
            controlador.iniciar_generacion("hola", max_tokens_nuevos=30, velocidad_inicial=0.1)

        controlador.pausar()
        qtbot.waitUntil(lambda: controlador.esta_pausado, timeout=1000)

        cantidad_al_pausar = len(tokens_recibidos)
        qtbot.wait(300)
        assert len(tokens_recibidos) == cantidad_al_pausar

        controlador.reanudar()
        qtbot.waitUntil(lambda: len(tokens_recibidos) > cantidad_al_pausar, timeout=2000)

        controlador.detener()

    def test_establecer_velocidad_ralentiza_la_generacion_en_vivo(self, qtbot, controlador):
        import time

        marcas_de_tiempo = []
        controlador.token_generado.connect(lambda p: marcas_de_tiempo.append(time.monotonic()))

        # velocidad_inicial pequena (no cero) para asegurar que la
        # generacion siga en curso cuando el hilo principal alcance a
        # llamar establecer_velocidad() mas abajo — con 0.0 el modelo
        # (chico, en CPU) puede terminar los 10 tokens casi al instante,
        # antes de que la nueva velocidad tenga oportunidad de aplicarse.
        with qtbot.waitSignal(controlador.token_generado, timeout=2000):
            controlador.iniciar_generacion("hola", max_tokens_nuevos=10, velocidad_inicial=0.03)

        controlador.establecer_velocidad(0.15)

        qtbot.waitUntil(lambda: len(marcas_de_tiempo) >= 5, timeout=5000)
        controlador.detener()

        deltas = [marcas_de_tiempo[i + 1] - marcas_de_tiempo[i] for i in range(len(marcas_de_tiempo) - 1)]
        assert max(deltas) >= 0.12


# ---------------------------------------------------------------------------
# Parada temprana por id_token_fin
# ---------------------------------------------------------------------------

class TestParadaTemprana:
    def test_id_token_fin_detiene_antes_de_max_tokens_nuevos(self, qtbot, modelo, tokenizer, config):
        torch.manual_seed(5)
        tokens_origen = torch.tensor([tokenizer.encode("hola")], dtype=torch.long)
        pasos_referencia = list(
            modelo.generar(tokens_origen, id_token_inicio=1, max_tokens_nuevos=6, temperatura=1.0)
        )
        ids_referencia = [p["token_id"] for p in pasos_referencia]
        assert len(set(ids_referencia)) > 1, "se necesita variedad para una prueba valida"
        id_fin_forzado = ids_referencia[2]

        controlador = InferenceController(modelo, tokenizer, id_token_inicio=1, id_token_fin=id_fin_forzado)

        torch.manual_seed(5)
        with qtbot.waitSignal(controlador.generacion_completa, timeout=5000) as blocker:
            controlador.iniciar_generacion("hola", max_tokens_nuevos=6, temperatura=1.0)

        texto_final = blocker.args[0]
        cantidad_generada = len(texto_final.split(",")) if texto_final else 0
        # El marcador EOS detiene la generación, pero no forma parte del
        # texto decodificado (ver `_tarea_generacion`).
        assert cantidad_generada == ids_referencia.index(id_fin_forzado)
