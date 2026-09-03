"""Pruebas focalizadas del trabajo previo al entrenamiento fuera de QML."""

from __future__ import annotations

import json
import threading

import torch

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from viewmodel import main_viewmodel as modulo_main_viewmodel
from viewmodel import model_library_controller as modulo_biblioteca
from viewmodel import setup_controller as modulo_setup
from viewmodel.dataset_controller import DatasetController
from viewmodel.main_viewmodel import MainViewModel
from viewmodel.setup_controller import SetupController


class TokenizerFalso:
    tipo_encoding = 1
    vocab_size = 40

    def __init__(self, tipo_encoding: int = 1):
        self.tipo_encoding = tipo_encoding

    def encode(self, texto):
        return [1 + (ord(caracter) % 20) for caracter in str(texto)[:8]] or [1]

    def decode(self, tokens):
        return "texto"


def _modelo_pequeno() -> Transformer:
    return Transformer(
        ConfiguracionTransformer(
            tamano_vocabulario=43,
            dimension_modelo=16,
            num_cabezas=4,
            num_capas=1,
            dimension_ff=32,
            longitud_maxima_secuencia=12,
            dropout=0.0,
            id_token_relleno=40,
        )
    )


def _view_model_aislado(monkeypatch, tmp_path) -> MainViewModel:
    ruta_catalogo = tmp_path / "datasets" / "dataSets.json"
    ruta_catalogo.parent.mkdir(parents=True)
    ruta_catalogo.write_text("[]", encoding="utf8")
    monkeypatch.setattr(DatasetController, "DATASET_FILE", ruta_catalogo)
    monkeypatch.setattr(modulo_biblioteca, "DIR_CHECKPOINTS", tmp_path / "modelos")
    monkeypatch.setattr(modulo_main_viewmodel, "DISPOSITIVO", torch.device("cpu"))
    return MainViewModel()


def test_crear_modelo_async_publica_fases_y_resultado(monkeypatch, qtbot):
    monkeypatch.setattr(modulo_setup, "Tokenizer", TokenizerFalso)
    controlador = SetupController()
    controlador.establecer_dimension_modelo(16)
    controlador.establecer_num_cabezas(4)
    controlador.establecer_num_capas(1)
    controlador.establecer_dimension_ff(32)
    fases = []
    controlador.faseCambio.connect(lambda: fases.append(controlador.fase))

    with qtbot.waitSignal(controlador.modelo_creado, timeout=5000):
        controlador.crear_modelo_async()
        assert controlador.ocupado is True

    assert controlador.ocupado is False
    assert controlador.modelo is not None
    assert controlador.tokenizer is not None
    assert any("tokenizador" in fase.lower() for fase in fases)
    assert any("pesos" in fase.lower() for fase in fases)


def test_cancelar_creacion_espera_al_worker_y_evitar_duplicados(
    monkeypatch, qtbot
):
    controlador = SetupController()
    inicio = threading.Event()
    terminar = threading.Event()
    llamadas: list[dict] = []
    publicados = []

    def materializar_lento(parametros, notificar_fase=None):
        llamadas.append(dict(parametros))
        inicio.set()
        assert terminar.wait(timeout=2)
        return _modelo_pequeno(), TokenizerFalso()

    monkeypatch.setattr(controlador, "_materializar_modelo", materializar_lento)
    controlador.modelo_creado.connect(lambda *_args: publicados.append(True))

    controlador.crear_modelo_async()
    assert inicio.wait(timeout=1)
    controlador.cancelar_creacion_modelo()

    assert controlador.ocupado is True
    assert "Cancelando" in controlador.fase
    controlador.crear_modelo_async()
    assert len(llamadas) == 1

    terminar.set()
    qtbot.waitUntil(lambda: not controlador.ocupado, timeout=3000)
    assert publicados == []
    assert controlador.modelo is None


def test_activar_modelo_mueve_pesos_fuera_del_hilo_qt(
    monkeypatch, tmp_path, qtbot
):
    view_model = _view_model_aislado(monkeypatch, tmp_path)
    modelo = _modelo_pequeno()
    tokenizer = TokenizerFalso()
    hilo_principal = threading.get_ident()
    hilos_to = []
    to_original = modelo.to

    def registrar_to(*args, **kwargs):
        hilos_to.append(threading.get_ident())
        return to_original(*args, **kwargs)

    modelo.to = registrar_to
    with qtbot.waitSignal(view_model.modeloListoCambio, timeout=5000):
        view_model._activar_modelo(modelo, tokenizer)
        assert view_model.activandoModelo is True

    assert view_model.modeloListo is True
    assert view_model.activandoModelo is False
    assert hilos_to and hilos_to[0] != hilo_principal


def test_cancelar_activacion_espera_el_fin_de_la_copia(
    monkeypatch, tmp_path, qtbot
):
    view_model = _view_model_aislado(monkeypatch, tmp_path)
    modelo = _modelo_pequeno()
    tokenizer = TokenizerFalso()
    inicio = threading.Event()
    terminar = threading.Event()

    def mover_lento(*_args, **_kwargs):
        inicio.set()
        assert terminar.wait(timeout=2)
        return modelo

    modelo.to = mover_lento
    view_model._activar_modelo(modelo, tokenizer)
    assert inicio.wait(timeout=1)
    view_model.cancelarActivacionModelo()

    assert view_model.activandoModelo is True
    assert "Cancelando" in view_model.faseActivacion

    terminar.set()
    qtbot.waitUntil(lambda: not view_model.activandoModelo, timeout=3000)
    assert view_model.modeloListo is False


def test_preparar_dataset_async_tokeniza_y_reporta_progreso(
    monkeypatch, tmp_path, qtbot
):
    view_model = _view_model_aislado(monkeypatch, tmp_path)
    tokenizer = TokenizerFalso()
    modelo = _modelo_pequeno()
    view_model.setupController.adoptar_modelo(modelo, tokenizer, emitir=False)
    view_model._instalar_modelo(modelo, tokenizer)

    ruta_datos = tmp_path / "ejemplos.jsonl"
    ruta_datos.write_text(
        '\n'.join(
            json.dumps({"instruction": f"pregunta {i}", "response": f"respuesta {i}"})
            for i in range(5)
        ),
        encoding="utf8",
    )
    catalogo = [
        {
            "id": "DS-001",
            "nombre": "ejemplos",
            "ruta": str(ruta_datos),
            "formato": ".jsonl",
            "registros": 5,
        }
    ]
    DatasetController.DATASET_FILE.write_text(
        json.dumps(catalogo), encoding="utf8"
    )
    fases = []
    view_model.fasePreparacionDatasetCambio.connect(
        lambda: fases.append(view_model.fasePreparacionDataset)
    )

    with qtbot.waitSignal(view_model.datasetListoParaEntrenar, timeout=5000) as listo:
        view_model.cargarDatasetsParaEntrenarAsync(["DS-001"])
        assert view_model.preparandoDataset is True

    assert listo.args == [5]
    assert view_model.preparandoDataset is False
    assert view_model.totalPreparacionDataset == 5
    assert view_model.progresoPreparacionDataset == 1.0
    assert any("Tokenizando" in fase for fase in fases)


def test_cancelar_dataset_espera_al_worker_y_no_publica_resultado(
    monkeypatch, tmp_path, qtbot
):
    view_model = _view_model_aislado(monkeypatch, tmp_path)
    tokenizer = TokenizerFalso()
    modelo = _modelo_pequeno()
    view_model.setupController.adoptar_modelo(modelo, tokenizer, emitir=False)
    view_model._instalar_modelo(modelo, tokenizer)

    ruta_datos = tmp_path / "lento.jsonl"
    ruta_datos.write_text("{}\n", encoding="utf8")
    DatasetController.DATASET_FILE.write_text(
        json.dumps(
            [
                {
                    "id": "DS-001",
                    "nombre": "lento",
                    "ruta": str(ruta_datos),
                    "formato": ".jsonl",
                    "registros": 1,
                }
            ]
        ),
        encoding="utf8",
    )
    inicio = threading.Event()
    terminar = threading.Event()
    llamadas = 0
    publicados: list[int] = []

    def cargar_lento(*_args, **_kwargs):
        nonlocal llamadas
        llamadas += 1
        inicio.set()
        assert terminar.wait(timeout=2)
        return [("pregunta", "respuesta")]

    monkeypatch.setattr(modulo_main_viewmodel, "cargar_pares_combinados", cargar_lento)
    view_model.datasetListoParaEntrenar.connect(publicados.append)

    view_model.cargarDatasetsParaEntrenarAsync(["DS-001"])
    assert inicio.wait(timeout=1)
    view_model.cancelarPreparacionDataset()

    assert view_model.preparandoDataset is True
    assert "Cancelando" in view_model.fasePreparacionDataset
    view_model.cargarDatasetsParaEntrenarAsync(["DS-001"])
    assert llamadas == 1

    terminar.set()
    qtbot.waitUntil(lambda: not view_model.preparandoDataset, timeout=3000)
    assert publicados == []
    assert view_model.trainingController._dataset is None
