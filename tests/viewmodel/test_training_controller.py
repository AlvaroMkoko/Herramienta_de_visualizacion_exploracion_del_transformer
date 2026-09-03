"""
Pruebas de `viewmodel/training_controller.py`.

Como `gestor_de_datos/` (batches reales) todavía no existe, se usa un
`proveedor_batches` de prueba que genera tensores aleatorios de la forma
correcta — lo único que nos importa validar aquí es que el CONTROLADOR
orqueste bien el bucle de entrenamiento (pérdida, gradientes, señales,
pausa/detención/velocidad), no la calidad del aprendizaje en sí (eso ya
se probó en `test_transformer.py::TestBackward::test_un_paso_de_optimizacion_reduce_la_perdida`).
"""

import threading
from types import SimpleNamespace

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
        assert resultado["ejemplos_vistos"] == 10
        assert resultado["tokens_origen_vistos"] == 60
        assert resultado["tokens_objetivo_vistos"] == 60
        assert resultado["duracion_entrenamiento_segundos"] > 0

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
            visualizacion = paso["visualizacion"]
            assert visualizacion["resumen"]["norma_gradiente_global"] >= 0
            assert visualizacion["resumen"]["componente_relevante_id"]
            assert {
                "input_embedding",
                "encoder_self_attention",
                "decoder_cross_attention",
                "linear",
                "softmax",
            }.issubset(visualizacion["componentes"])
            assert visualizacion["componentes"]["encoder_self_attention"]["capas"]

            def metricas_en(nodo):
                if isinstance(nodo, dict):
                    if "etiqueta" in nodo and "valor" in nodo:
                        yield nodo
                    for valor in nodo.values():
                        yield from metricas_en(valor)
                elif isinstance(nodo, list):
                    for valor in nodo:
                        yield from metricas_en(valor)

            metricas = list(metricas_en(visualizacion["componentes"]))
            assert metricas
            assert all(metrica.get("concepto_id") for metrica in metricas)

    def test_payload_qml_no_retiene_tensores_crudos_cuda(
        self, qtbot, controlador, config
    ):
        pasos_recibidos = []
        controlador.paso_entrenamiento.connect(pasos_recibidos.append)

        proveedor = _crear_proveedor_batches(config, cantidad_batches=2)
        with qtbot.waitSignal(controlador.entrenamiento_completo, timeout=10000):
            controlador.iniciar_entrenamiento(
                proveedor,
                num_epocas=1,
                incluir_tensores_crudos=False,
            )

        assert len(pasos_recibidos) == 2
        assert all(
            paso["pesos_atencion_encoder_por_capa"] == []
            and paso["pesos_atencion_cruzada_por_capa"] == []
            for paso in pasos_recibidos
        )
        assert all(paso["visualizacion"]["componentes"] for paso in pasos_recibidos)

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

        assert [p["epoca_sesion"] for p in pasos_recibidos] == [1, 1, 2, 2, 3, 3]
        assert [p["epocas_sesion"] for p in pasos_recibidos] == [3] * 6
        assert [p["lote_actual"] for p in pasos_recibidos] == [1, 2, 1, 2, 1, 2]
        assert [p["lotes_por_epoca"] for p in pasos_recibidos] == [2] * 6
        assert [p["pasos_sesion_completados"] for p in pasos_recibidos] == list(
            range(1, 7)
        )
        assert [p["pasos_sesion_totales"] for p in pasos_recibidos] == [6] * 6
        assert [p["progreso_fraccion"] for p in pasos_recibidos] == pytest.approx(
            [1 / 6, 2 / 6, 3 / 6, 4 / 6, 5 / 6, 1]
        )
        assert all(p["tiempo_transcurrido_segundos"] >= 0 for p in pasos_recibidos)
        assert all(p["eta_segundos"] >= 0 for p in pasos_recibidos)
        assert pasos_recibidos[-1]["eta_segundos"] == pytest.approx(0)

    def test_progreso_de_sesion_no_se_confunde_con_checkpoint_reanudado(
        self, qtbot, modelo, config
    ):
        carga = SimpleNamespace(
            metadata_extra={},
            optimizer_state_dict=None,
            historial_perdidas=[4.2, 4.1],
            epoca=4,
            siguiente_epoca=5,
            paso_epoca=1,
            paso_global=17,
            hiperparametros_entrenamiento={},
        )
        controlador = TrainingController(modelo, resultado_carga=carga)
        pasos_recibidos = []
        controlador.paso_entrenamiento.connect(pasos_recibidos.append)

        try:
            proveedor = _crear_proveedor_batches(config, cantidad_batches=2)
            with qtbot.waitSignal(controlador.entrenamiento_completo, timeout=10000):
                controlador.iniciar_entrenamiento(proveedor, num_epocas=2)
        finally:
            controlador.cerrar()

        assert [p["epoca"] for p in pasos_recibidos] == [5, 5, 6, 6]
        assert [p["paso_global"] for p in pasos_recibidos] == [18, 19, 20, 21]
        assert [p["epoca_sesion"] for p in pasos_recibidos] == [1, 1, 2, 2]
        assert [p["pasos_sesion_completados"] for p in pasos_recibidos] == [1, 2, 3, 4]
        assert [p["pasos_sesion_totales"] for p in pasos_recibidos] == [4] * 4
        assert pasos_recibidos[-1]["progreso_fraccion"] == pytest.approx(1)

    def test_iterable_sin_len_reporta_progreso_indeterminado(
        self, qtbot, controlador, config
    ):
        def proveedor_generador():
            for batch in _crear_proveedor_batches(config, cantidad_batches=2)():
                yield batch

        pasos_recibidos = []
        controlador.paso_entrenamiento.connect(pasos_recibidos.append)
        with qtbot.waitSignal(controlador.entrenamiento_completo, timeout=10000):
            controlador.iniciar_entrenamiento(proveedor_generador, num_epocas=1)

        assert [p["lote_actual"] for p in pasos_recibidos] == [1, 2]
        assert [p["pasos_sesion_completados"] for p in pasos_recibidos] == [1, 2]
        assert all(p["lotes_por_epoca"] is None for p in pasos_recibidos)
        assert all(p["pasos_sesion_totales"] is None for p in pasos_recibidos)
        assert all(p["progreso_fraccion"] is None for p in pasos_recibidos)
        assert all(p["eta_segundos"] is None for p in pasos_recibidos)

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

    def test_detencion_solicitada_es_observable_mientras_termina_el_lote(
        self, qtbot, controlador, config
    ):
        proveedor = _crear_proveedor_batches(config, cantidad_batches=30)
        with qtbot.waitSignal(controlador.paso_entrenamiento, timeout=3000):
            controlador.iniciar_entrenamiento(
                proveedor, num_epocas=1, velocidad_inicial=0.2
            )

        with qtbot.waitSignal(controlador.detencionSolicitadaCambio, timeout=1000):
            controlador.detener()
        assert controlador.detencionSolicitada is True

        with qtbot.waitSignal(controlador.entrenamiento_cancelado, timeout=3000):
            pass
        assert controlador.detencionSolicitada is False


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

    def test_solicitud_de_pausa_se_notifica_inmediatamente(
        self, qtbot, controlador, config
    ):
        proveedor = _crear_proveedor_batches(config, cantidad_batches=30)
        with qtbot.waitSignal(controlador.paso_entrenamiento, timeout=3000):
            controlador.iniciar_entrenamiento(
                proveedor, num_epocas=1, velocidad_inicial=0.2
            )

        with qtbot.waitSignal(controlador.pausaSolicitadaCambio, timeout=1000):
            controlador.pausar()
        assert controlador.pausaSolicitada is True
        assert controlador.estaPausado is True

        controlador.reanudar()
        assert controlador.pausaSolicitada is False
        assert controlador.estaPausado is False
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


# ---------------------------------------------------------------------------
# Indicador de guardado
# ---------------------------------------------------------------------------

class TestIndicadorGuardado:
    def test_guardado_expone_estado_y_fase_sin_inventar_porcentaje(
        self, qtbot, modelo, monkeypatch, tmp_path
    ):
        from model.persistencia import model_storage

        inicio_escritura = threading.Event()
        permitir_fin = threading.Event()

        def guardar_falso(*_args, **_kwargs):
            inicio_escritura.set()
            permitir_fin.wait(timeout=2)

        monkeypatch.setattr(model_storage, "guardar_modelo_portable", guardar_falso)
        controlador = TrainingController(modelo, tokenizer=object())
        monkeypatch.setattr(
            controlador,
            "_ruta_sin_sobrescribir",
            lambda _nombre: tmp_path / "modelo.tvismodel",
        )
        fases = []
        controlador.faseGuardadoCambio.connect(
            lambda: fases.append(controlador.faseGuardado)
        )

        try:
            controlador.guardarModeloPortableConNombre("modelo")
            assert controlador.guardando is True
            assert fases[0] == "Preparando modelo portable..."
            qtbot.waitUntil(inicio_escritura.is_set, timeout=1000)
            assert controlador.faseGuardado == "Escribiendo el modelo en disco..."

            with qtbot.waitSignal(controlador.checkpoint_guardado, timeout=2000):
                permitir_fin.set()
            qtbot.waitUntil(lambda: not controlador.guardando, timeout=1000)
            assert controlador.faseGuardado == ""
        finally:
            permitir_fin.set()
            controlador.cerrar()
