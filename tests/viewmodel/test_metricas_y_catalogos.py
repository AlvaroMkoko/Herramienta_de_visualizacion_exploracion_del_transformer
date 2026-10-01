"""
Pruebas de las métricas por época del entrenamiento, del catálogo de
configuraciones (predefinidas y guardadas) y de los datasets predefinidos.
"""

import json
from pathlib import Path

import pytest
import torch

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from viewmodel import setup_controller as modulo_setup
from viewmodel.dataset_controller import DatasetController
from viewmodel.setup_controller import CONFIGURACIONES_PREDEFINIDAS, SetupController
from viewmodel.training_controller import TrainingController


# ---------------------------------------------------------------------------
# Precisión por lote y resumen por época
# ---------------------------------------------------------------------------

def _proveedor(config, cantidad_batches=3, batch_size=2, longitud=6):
    def proveedor():
        lotes = []
        for _ in range(cantidad_batches):
            origen = torch.randint(1, config.tamano_vocabulario, (batch_size, longitud))
            destino = torch.randint(1, config.tamano_vocabulario, (batch_size, longitud))
            objetivo = torch.randint(1, config.tamano_vocabulario, (batch_size, longitud))
            # Una posición de relleno por fila: no debe contarse en la precisión.
            objetivo[:, -1] = 0
            lotes.append((origen, destino, objetivo))
        return lotes

    return proveedor


@pytest.fixture
def config():
    return ConfiguracionTransformer(
        tamano_vocabulario=40, dimension_modelo=32, num_cabezas=4, num_capas=1,
        dimension_ff=64, longitud_maxima_secuencia=32, dropout=0.0, id_token_relleno=0,
    )


def test_pasos_reportan_precision_y_resumen_por_epoca(qtbot, config):
    torch.manual_seed(0)
    controlador = TrainingController(Transformer(config))
    pasos = []
    controlador.paso_entrenamiento.connect(pasos.append)

    with qtbot.waitSignal(controlador.entrenamiento_completo, timeout=15000) as blocker:
        controlador.iniciar_entrenamiento(_proveedor(config), id_token_relleno=0, num_epocas=2)

    assert len(pasos) == 6
    for paso in pasos:
        assert 0.0 <= paso["precision"] <= 1.0
        assert 0.0 <= paso["precision_media_epoca"] <= 1.0
        assert paso["perdida_media_epoca"] > 0
    # El resumen de la primera época ya está disponible durante la segunda.
    assert pasos[2]["resumen_epocas"] == []
    assert len(pasos[3]["resumen_epocas"]) == 1

    resultado = blocker.args[0]
    resumen = resultado["resumen_epocas"]
    assert [item["epoca"] for item in resumen] == [0, 1]
    assert all(item["lotes"] == 3 for item in resumen)
    perdidas = resultado["historial_perdidas"]
    assert resumen[0]["perdida_media"] == pytest.approx(sum(perdidas[:3]) / 3)
    assert resumen[1]["perdida_media"] == pytest.approx(sum(perdidas[3:]) / 3)

    metadata = controlador._metadata_de_procedencia()
    assert metadata["historial_precision"] == [item["precision"] for item in resumen]


def test_precision_ignora_el_relleno(qtbot, config):
    """Si el modelo acierta todo salvo el relleno, la precisión es 1."""
    torch.manual_seed(0)
    modelo = Transformer(config)
    controlador = TrainingController(modelo)
    pasos = []
    controlador.paso_entrenamiento.connect(pasos.append)

    origen = torch.randint(1, config.tamano_vocabulario, (2, 5))
    destino = torch.randint(1, config.tamano_vocabulario, (2, 5))
    with torch.no_grad():
        modelo.eval()
        prediccion = modelo(origen, destino).argmax(dim=-1)
    objetivo = prediccion.clone()
    objetivo[:, -1] = 0  # relleno: no cuenta aunque no coincida

    # Con lr = 0 los pesos no cambian; dropout = 0 hace el forward determinista.
    with qtbot.waitSignal(controlador.entrenamiento_completo, timeout=15000):
        controlador.iniciar_entrenamiento(
            lambda: [(origen, destino, objetivo)], id_token_relleno=0,
            num_epocas=1, tasa_aprendizaje=1e-12,
        )

    assert pasos[0]["precision"] == pytest.approx(1.0)


# ---------------------------------------------------------------------------
# Configuraciones predefinidas y guardadas
# ---------------------------------------------------------------------------

class _TokenizerFalso:
    def __init__(self, tipo_encoding: int = 1):
        self.tipo_encoding = tipo_encoding
        self.vocab_size = 200


@pytest.fixture
def setup(tmp_path, monkeypatch):
    monkeypatch.setattr(modulo_setup, "Tokenizer", _TokenizerFalso)
    return SetupController(directorio_configuraciones=tmp_path / "configs")


def test_configuraciones_predefinidas_son_validas(setup):
    for item in CONFIGURACIONES_PREDEFINIDAS:
        entrenamiento = setup.aplicarConfiguracionPredefinida(item["id"])
        assert setup.configuracionValida, item["id"]
        actual = setup.configuracionActual
        for campo, valor in item["arquitectura"].items():
            assert actual[campo] == valor
        assert entrenamiento == item["entrenamiento"]


def test_predefinida_inexistente_no_cambia_nada(setup, qtbot):
    antes = dict(setup.configuracionActual)
    with qtbot.waitSignal(setup.error_configuracion, timeout=1000):
        assert setup.aplicarConfiguracionPredefinida("no_existe") == {}
    assert setup.configuracionActual == antes


def test_guardar_y_cargar_configuracion(setup):
    setup.aplicarConfiguracionPredefinida("mediana")
    ruta = setup.guardarConfiguracion(
        "Mi configuración", {"epocas": 3, "tasa_aprendizaje": 0.002, "batch_size": 5}
    )
    assert ruta and Path(ruta).is_file()
    # No sobrescribe: el segundo guardado con el mismo nombre crea otro archivo.
    ruta2 = setup.guardarConfiguracion("Mi configuración", {})
    assert ruta2 != ruta
    assert [item["ruta"] for item in setup.configuracionesGuardadas] == sorted([ruta, ruta2])

    setup.aplicarConfiguracionPredefinida("minima")
    entrenamiento = setup.cargarConfiguracion(ruta)
    assert entrenamiento == {"epocas": 3, "tasa_aprendizaje": 0.002, "batch_size": 5}
    assert setup.configuracionActual["dimension_modelo"] == 128
    assert setup.configuracionActual["activacion"] == "gelu"


def test_cargar_configuracion_invalida_conserva_los_controles(setup, tmp_path, qtbot):
    setup.aplicarConfiguracionPredefinida("pequena")
    antes = dict(setup.configuracionActual)
    ruta = tmp_path / "mala.json"
    ruta.write_text(json.dumps({
        "formato": "tvis-configuracion", "version": 1, "nombre": "mala",
        # 64 no es divisible entre 5 cabezas (RN14)
        "arquitectura": {"dimension_modelo": 64, "num_cabezas": 5},
    }), encoding="utf-8")
    with qtbot.waitSignal(setup.error_configuracion, timeout=1000):
        assert setup.cargarConfiguracion(str(ruta)) == {}
    assert setup.configuracionActual == antes
    assert setup.configuracionValida

    otro = tmp_path / "otro.json"
    otro.write_text("{}", encoding="utf-8")
    assert setup.cargarConfiguracion(str(otro)) == {}
    assert setup.configuracionActual == antes


def test_no_guarda_configuracion_invalida(setup):
    setup.establecer_dimension_modelo(64)
    setup.establecer_num_cabezas(5)
    assert not setup.configuracionValida
    assert setup.guardarConfiguracion("x", {}) == ""
    assert setup.configuracionesGuardadas == []


# ---------------------------------------------------------------------------
# Datasets predefinidos
# ---------------------------------------------------------------------------

@pytest.fixture
def datasets(tmp_path, monkeypatch):
    monkeypatch.setattr(DatasetController, "DATASET_FILE", tmp_path / "ds" / "dataSets.json")
    return DatasetController()


def test_datasets_predefinidos_aparecen_y_son_validos(datasets):
    predefinidos = [d for d in datasets.obtenerDatasets() if d.get("predefinido")]
    assert {d["id"] for d in predefinidos} == {"PRE-TRADUCCION", "PRE-CONCEPTOS"}
    for dataset in predefinidos:
        assert dataset["descripcion"] and dataset["dominio"]
        assert dataset["compatible_entrenamiento"] is True
        assert dataset["registros"] > 0
    # No se escriben en el catálogo del usuario.
    assert json.loads(datasets.DATASET_FILE.read_text(encoding="utf8")) == []


def test_datasets_predefinidos_no_se_eliminan_ni_se_persisten(datasets, tmp_path, qtbot):
    with qtbot.waitSignal(datasets.error, timeout=1000):
        datasets.eliminarDataset("PRE-TRADUCCION")
    assert datasets.obtenerDataset("PRE-TRADUCCION")

    propio = tmp_path / "propio.jsonl"
    propio.write_text('{"instruction": "a", "response": "b"}\n', encoding="utf8")
    agregado = datasets.agregarDataset(str(propio))
    assert agregado["id"] == "DS-001"
    guardado = json.loads(datasets.DATASET_FILE.read_text(encoding="utf8"))
    assert [d["id"] for d in guardado] == ["DS-001"]


# ---------------------------------------------------------------------------
# Tiempo de respuesta de la evaluación (RF23)
# ---------------------------------------------------------------------------

def test_resultado_de_evaluacion_registra_su_duracion():
    from model.evaluacion.evaluation_manager import EvaluationManager

    manager = EvaluationManager()
    manager.start_evaluation("pre")
    for pregunta in manager.questions:
        manager.answers[pregunta["id"]] = None
    resultado = manager.score_evaluation()
    assert resultado["duration_seconds"] >= 0


# ---------------------------------------------------------------------------
# Sesgo (bias) configurable (RF02)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("usar_sesgo", [True, False])
def test_estimacion_de_parametros_con_y_sin_sesgo(usar_sesgo):
    config = ConfiguracionTransformer(
        tamano_vocabulario=60, dimension_modelo=32, num_cabezas=4, num_capas=2,
        dimension_ff=64, longitud_maxima_secuencia=16, usar_sesgo=usar_sesgo,
    )
    modelo = Transformer(config)
    real = sum(p.numel() for p in modelo.parameters())
    estimado = SetupController._estimar_parametros(
        v=60, d=32, n=2, ff=64,
        compartir_pesos_salida=modelo.compartir_pesos_salida, usar_sesgo=usar_sesgo,
    )
    assert estimado == real
    tiene_sesgo = modelo.encoder.bloques[0].atencion.proyeccion_q.bias is not None
    assert tiene_sesgo is usar_sesgo


def test_modelo_sin_sesgo_se_guarda_y_se_carga(tmp_path):
    from model.persistencia.model_storage import cargar_modelo_portable, guardar_modelo_portable

    class _Tok:
        tipo_encoding = 1
        vocab_size = 57

    config = ConfiguracionTransformer(
        tamano_vocabulario=60, dimension_modelo=32, num_cabezas=4, num_capas=1,
        dimension_ff=64, longitud_maxima_secuencia=16, id_token_relleno=57,
        usar_sesgo=False,
    )
    modelo = Transformer(config)
    ruta = tmp_path / "sin_sesgo.tvismodel"
    guardar_modelo_portable(ruta, modelo, _Tok(), nombre="sin_sesgo")
    cargado = cargar_modelo_portable(ruta, "cpu").modelo
    assert cargado.config.usar_sesgo is False
    for a, b in zip(modelo.state_dict().values(), cargado.state_dict().values()):
        assert torch.equal(a, b)
