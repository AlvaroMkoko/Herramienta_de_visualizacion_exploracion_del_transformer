"""
Pruebas de `viewmodel/training_controller.py`.

Como `gestor_de_datos/` (batches reales) todavía no existe, se usa un
`proveedor_batches` de prueba que genera tensores aleatorios de la forma
correcta — lo único que nos importa validar aquí es que el CONTROLADOR
orqueste bien el bucle de entrenamiento (pérdida, gradientes, señales,
pausa/detención/velocidad), no la calidad del aprendizaje en sí (eso ya
se probó en `test_transformer.py::TestBackward::test_un_paso_de_optimizacion_reduce_la_perdida`).
"""

import pytest
import torch

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from viewmodel.training_controller import TrainingController


@pytest.fixture
def config() -> ConfiguracionTransformer:
    return ConfiguracionTransformer(
        tamano_vocabulario=50, dimension_modelo=32, num_cabezas=4, num_capas=2,
        dimension_ff=64, longitud_maxima_secuencia=100, dropout=0.0, id_token_relleno=0,
    )


@pytest.fixture
def modelo(config) -> Transformer:
    torch.manual_seed(0)
    return Transformer(config)


def _crear_proveedor_batches(config, cantidad_batches: int, batch_size: int = 2, longitud: int = 6):
    """Genera un proveedor de batches de prueba: cada llamada retorna una
    lista NUEVA de `cantidad_batches` tuplas (origen, destino, objetivo)
    con ids aleatorios validos para el vocabulario de `config`."""

    def proveedor():
        batches = []
        for _ in range(cantidad_batches):
            origen = torch.randint(1, config.tamano_vocabulario, (batch_size, longitud))
            destino = torch.randint(1, config.tamano_vocabulario, (batch_size, longitud))
            objetivo = torch.randint(1, config.tamano_vocabulario, (batch_size, longitud))
            batches.append((origen, destino, objetivo))
        return batches

    return proveedor


@pytest.fixture
def controlador(qtbot, modelo) -> TrainingController:
    c = TrainingController(modelo)
    yield c
    if c.esta_entrenando:
        c.detener()
        qtbot.waitUntil(lambda: not c.esta_entrenando, timeout=2000)


# ---------------------------------------------------------------------------
# Entrenamiento básico
# ---------------------------------------------------------------------------

class TestEntrenamientoBasico:
    def test_entrenamiento_completo_emite_historial(self, qtbot, controlador, config):
        proveedor = _crear_proveedor_batches(config, cantidad_batches=5)

        with qtbot.waitSignal(controlador.entrenamiento_completo, timeout=10000) as blocker:
            controlador.iniciar_entrenamiento(proveedor, num_epocas=1)

        resultado = blocker.args[0]
        assert len(resultado["historial_perdidas"]) == 5
        assert resultado["perdida_final"] == resultado["historial_perdidas"][-1]

    def test_recorre_el_proveedor_una_vez_por_epoca(self, qtbot, controlador, config):
        contador_llamadas = {"veces": 0}
        proveedor_base = _crear_proveedor_batches(config, cantidad_batches=3)

        def proveedor_contado():
            contador_llamadas["veces"] += 1
            return proveedor_base()

        with qtbot.waitSignal(controlador.entrenamiento_completo, timeout=10000):
            controlador.iniciar_entrenamiento(proveedor_contado, num_epocas=4)

        assert contador_llamadas["veces"] == 4

    def test_paso_entrenamiento_incluye_perdida_y_tensores(self, qtbot, controlador, config):
        pasos_recibidos = []
        controlador.paso_entrenamiento.connect(pasos_recibidos.append)

        proveedor = _crear_proveedor_batches(config, cantidad_batches=3)
        with qtbot.waitSignal(controlador.entrenamiento_completo, timeout=10000):
            controlador.iniciar_entrenamiento(proveedor, num_epocas=1)

        assert len(pasos_recibidos) == 3
        for i, paso in enumerate(pasos_recibidos):
            assert isinstance(paso["perdida"], float)
            assert paso["perdida"] > 0
            assert paso["norma_gradiente_global"] >= 0
            assert paso["epoca"] == 0
            assert paso["paso_epoca"] == i
            assert paso["paso_global"] == i + 1
            assert len(paso["pesos_atencion_encoder_por_capa"]) == config.num_capas
            assert len(paso["pesos_atencion_cruzada_por_capa"]) == config.num_capas

    def test_contadores_de_epoca_y_paso_global_a_traves_de_varias_epocas(self, qtbot, controlador, config):
        pasos_recibidos = []
        controlador.paso_entrenamiento.connect(pasos_recibidos.append)

        proveedor = _crear_proveedor_batches(config, cantidad_batches=2)
        with qtbot.waitSignal(controlador.entrenamiento_completo, timeout=10000):
            controlador.iniciar_entrenamiento(proveedor, num_epocas=3)

        assert len(pasos_recibidos) == 6  # 3 epocas x 2 batches
        epocas_observadas = [p["epoca"] for p in pasos_recibidos]
        assert epocas_observadas == [0, 0, 1, 1, 2, 2]
        pasos_globales = [p["paso_global"] for p in pasos_recibidos]
        assert pasos_globales == [1, 2, 3, 4, 5, 6]

    def test_esta_entrenando_refleja_el_estado(self, qtbot, controlador, config):
        assert controlador.esta_entrenando is False

        proveedor = _crear_proveedor_batches(config, cantidad_batches=3)
        with qtbot.waitSignal(controlador.entrenamiento_completo, timeout=10000):
            controlador.iniciar_entrenamiento(proveedor, num_epocas=1, velocidad_inicial=0.02)
            assert controlador.esta_entrenando is True

        assert controlador.esta_entrenando is False


# ---------------------------------------------------------------------------
# El modelo realmente aprende (memoriza un batch fijo)
# ---------------------------------------------------------------------------

class TestAprendizajeReal:
    def test_perdida_disminuye_entrenando_sobre_el_mismo_batch(self, qtbot, controlador, config):
        """Prueba de humo end-to-end: si el proveedor SIEMPRE da el mismo
        batch (sin aleatoriedad entre llamadas), la perdida deberia bajar
        consistentemente a medida que el modelo lo memoriza."""
        torch.manual_seed(0)
        origen = torch.randint(1, config.tamano_vocabulario, (2, 6))
        destino = torch.randint(1, config.tamano_vocabulario, (2, 6))
        objetivo = torch.randint(1, config.tamano_vocabulario, (2, 6))
        batch_fijo = (origen, destino, objetivo)

        def proveedor_fijo():
            return [batch_fijo] * 15  # el mismo batch, 15 veces por "epoca"

        pasos_recibidos = []
        controlador.paso_entrenamiento.connect(pasos_recibidos.append)

        with qtbot.waitSignal(controlador.entrenamiento_completo, timeout=15000):
            controlador.iniciar_entrenamiento(proveedor_fijo, num_epocas=1, tasa_aprendizaje=1e-3)

        perdidas = [p["perdida"] for p in pasos_recibidos]
        assert perdidas[-1] < perdidas[0]


# ---------------------------------------------------------------------------
# Detener
# ---------------------------------------------------------------------------

class TestDetener:
    def test_detener_cancela_y_emite_historial_parcial(self, qtbot, controlador, config):
        proveedor = _crear_proveedor_batches(config, cantidad_batches=100)

        with qtbot.waitSignal(controlador.entrenamiento_cancelado, timeout=10000) as blocker:
            controlador.iniciar_entrenamiento(proveedor, num_epocas=1, velocidad_inicial=0.05)
            qtbot.wait(150)
            controlador.detener()

        resultado = blocker.args[0]
        assert 0 < len(resultado["historial_perdidas"]) < 100
        assert controlador.esta_entrenando is False


# ---------------------------------------------------------------------------
# Pausar / Reanudar / Velocidad
# ---------------------------------------------------------------------------

class TestPausaYVelocidad:
    def test_pausar_detiene_la_llegada_de_pasos(self, qtbot, controlador, config):
        pasos_recibidos = []
        controlador.paso_entrenamiento.connect(pasos_recibidos.append)

        proveedor = _crear_proveedor_batches(config, cantidad_batches=50)
        with qtbot.waitSignal(controlador.paso_entrenamiento, timeout=2000):
            controlador.iniciar_entrenamiento(proveedor, num_epocas=1, velocidad_inicial=0.08)

        controlador.pausar()
        qtbot.waitUntil(lambda: controlador.esta_pausado, timeout=1000)

        cantidad_al_pausar = len(pasos_recibidos)
        qtbot.wait(300)
        assert len(pasos_recibidos) == cantidad_al_pausar

        controlador.reanudar()
        qtbot.waitUntil(lambda: len(pasos_recibidos) > cantidad_al_pausar, timeout=3000)

        controlador.detener()

    def test_establecer_velocidad_ralentiza_los_pasos(self, qtbot, controlador, config):
        import time

        marcas_de_tiempo = []
        controlador.paso_entrenamiento.connect(lambda p: marcas_de_tiempo.append(time.monotonic()))

        proveedor = _crear_proveedor_batches(config, cantidad_batches=20)
        with qtbot.waitSignal(controlador.paso_entrenamiento, timeout=2000):
            controlador.iniciar_entrenamiento(proveedor, num_epocas=1, velocidad_inicial=0.03)

        controlador.establecer_velocidad(0.15)

        qtbot.waitUntil(lambda: len(marcas_de_tiempo) >= 5, timeout=5000)
        controlador.detener()

        deltas = [marcas_de_tiempo[i + 1] - marcas_de_tiempo[i] for i in range(len(marcas_de_tiempo) - 1)]
        assert max(deltas) >= 0.12


# ---------------------------------------------------------------------------
# Manejo de errores
# ---------------------------------------------------------------------------

class TestManejoDeErrores:
    def test_proveedor_roto_propaga_error(self, qtbot, controlador):
        def proveedor_roto():
            raise RuntimeError("fallo simulado del proveedor de batches")

        with qtbot.waitSignal(controlador.error, timeout=2000) as blocker:
            controlador.iniciar_entrenamiento(proveedor_roto, num_epocas=1)

        assert "fallo simulado" in blocker.args[0]
        assert controlador.esta_entrenando is False