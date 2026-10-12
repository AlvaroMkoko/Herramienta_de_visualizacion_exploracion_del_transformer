"""El laboratorio modular puede usar un modelo ya guardado en la biblioteca.

Las demás pruebas del laboratorio inyectan el modelo con ``set_model`` y se
saltan el tramo que el usuario sí recorre: laboratorio → biblioteca → elegir
modelo → ``ModelLibraryController.modelo_cargado`` → ``MainViewModel`` →
``set_model`` → de vuelta al laboratorio con ``modelReady``. Aquí se recorre
de extremo a extremo, con la carga real desde disco y sin falsear estado.
"""

from __future__ import annotations

import os
from pathlib import Path
import types

# Deben fijarse antes de que pytest-qt construya QApplication.
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

import pytest
import torch
from PySide6.QtCore import QMetaObject, QObject, QSettings, Qt, QUrl
from PySide6.QtQml import QQmlComponent, QQmlEngine
# Importarlo registra el convertidor de ``QQuickItem*``: sin él, leer
# ``currentItem`` o ``contentItem`` lanza «Can't find converter».
from PySide6.QtQuick import QQuickItem  # noqa: F401

from model.aprendizaje import ModuleProgressRepository
from model.evaluacion.results_repository import ResultsRepository
from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from model.persistencia.model_storage import guardar_modelo_portable
from viewmodel import main_viewmodel as modulo_main_viewmodel
from viewmodel import model_library_controller as modulo_biblioteca
from viewmodel.course_controller import CourseController
from viewmodel.evaluation_controller import EvaluationController
from viewmodel.learning_controller import LearningController
from viewmodel.main_viewmodel import MainViewModel
from viewmodel.progress_controller import ProgressController

RAIZ_QML = Path(__file__).resolve().parents[2] / "view" / "qml"

HOST_LABORATORIO = b"""\
import QtQuick
import QtQuick.Controls

ApplicationWindow {
    width: 1280
    height: 820
    visible: false

    StackView {
        id: navigation
        objectName: "laboratoryLibraryNavigation"
        anchors.fill: parent
    }

    Component.onCompleted: navigation.push(
        "screens/ModuleLaboratoryScreen.qml", {
            "stackView": navigation,
            "moduleId": "module_3",
            "mode": "training"
        }, StackView.Immediate)
}
"""


class TokenizerFalso:
    """Tokenizador determinista: la carga no descarga el BPE real."""

    def __init__(self, tipo_encoding: int = 2) -> None:
        self.tipo_encoding = tipo_encoding
        self.vocab_size = 13
        self.encoding = types.SimpleNamespace(
            name=modulo_biblioteca.ENCODINGS[tipo_encoding]
        )

    def encode(self, texto: str) -> list[int]:
        return [ord(caracter) % self.vocab_size for caracter in texto]

    def decode(self, tokens: list[int]) -> str:
        return "".join(chr(token) for token in tokens)


def _errores(component: QQmlComponent) -> str:
    return "\n".join(error.toString() for error in component.errors())


def _buscar(raiz: QObject, object_name: str) -> QObject:
    encontrado = raiz.findChild(QObject, object_name)
    assert encontrado is not None, f"Falta el hook publico objectName={object_name!r}"
    return encontrado


def _clic(boton: QObject) -> None:
    assert QMetaObject.invokeMethod(
        boton, "clicked", Qt.ConnectionType.DirectConnection
    )


def _descendientes_visuales(item):
    for hijo in item.childItems():
        yield hijo
        yield from _descendientes_visuales(hijo)


def _boton_de_tarjeta(qtbot, biblioteca: QObject) -> QObject:
    # Los delegados del ListView solo cuelgan del árbol visual, no del de
    # QObject: ``findChild`` no los encuentra y hay que recorrer ``childItems``.
    def buscar():
        return next(
            (
                item
                for item in _descendientes_visuales(biblioteca)
                if item.objectName() == "modelLibraryLaboratoryButton"
            ),
            None,
        )

    qtbot.waitUntil(lambda: buscar() is not None, timeout=3000)
    return buscar()


def _guardar_modelo(ruta: Path) -> None:
    config = ConfiguracionTransformer(
        tamano_vocabulario=16,
        dimension_modelo=8,
        num_cabezas=2,
        num_capas=1,
        dimension_ff=16,
        longitud_maxima_secuencia=8,
        dropout=0.0,
        id_token_relleno=13,
    )
    torch.manual_seed(311)
    guardar_modelo_portable(
        ruta, Transformer(config), TokenizerFalso(), nombre="Modelo de laboratorio"
    )


def _textos(item) -> list[str]:
    return [str(hijo.property("text")) for hijo in item.childItems()]


@pytest.fixture
def entorno(qapp, monkeypatch, tmp_path):
    """MainViewModel real con biblioteca, ajustes y progreso en ``tmp_path``.

    Sin aislar ``DIR_CHECKPOINTS`` la prueba dependería de los modelos que
    tenga guardados quien la ejecuta; sin aislar los controladores
    persistentes escribiría en su avance real del curso.
    """
    biblioteca = tmp_path / "biblioteca"
    biblioteca.mkdir()
    monkeypatch.setattr(modulo_biblioteca, "DIR_CHECKPOINTS", biblioteca)
    monkeypatch.setattr(modulo_biblioteca, "DISPOSITIVO", torch.device("cpu"))
    monkeypatch.setattr(modulo_biblioteca, "Tokenizer", TokenizerFalso)
    monkeypatch.setattr(modulo_main_viewmodel, "DISPOSITIVO", torch.device("cpu"))

    settings = QSettings(str(tmp_path / "lab-test.ini"), QSettings.Format.IniFormat)
    settings.clear()
    settings.sync()
    resultados = ResultsRepository(tmp_path / "resultados-test.json")
    monkeypatch.setattr(
        modulo_main_viewmodel,
        "LearningController",
        lambda parent=None: LearningController(parent=parent, settings=settings),
    )
    monkeypatch.setattr(
        modulo_main_viewmodel,
        "EvaluationController",
        lambda parent=None: EvaluationController(parent=parent, repository=resultados),
    )
    monkeypatch.setattr(
        modulo_main_viewmodel,
        "ProgressController",
        lambda learning, evaluation, parent=None: ProgressController(
            learning, evaluation, parent, settings=settings
        ),
    )
    monkeypatch.setattr(
        modulo_main_viewmodel,
        "CourseController",
        lambda evaluation, parent=None: CourseController(
            evaluation,
            parent,
            repository=ModuleProgressRepository(tmp_path / "progreso-test.json"),
        ),
    )

    # El componente y el ViewModel se retienen: si Python los recolecta al
    # salir de ``montar``, la ventana creada se destruye con ellos.
    creados: list[tuple[QObject, QQmlComponent, QQmlEngine, MainViewModel]] = []

    def montar():
        engine = QQmlEngine()
        view_model = MainViewModel()
        engine.rootContext().setContextProperty("mainViewModel", view_model)
        component = QQmlComponent(engine)
        component.setData(
            HOST_LABORATORIO,
            QUrl.fromLocalFile(str(RAIZ_QML / "LaboratoryLibraryHost.qml")),
        )
        assert component.status() != QQmlComponent.Status.Error, _errores(component)
        window = component.create()
        assert window is not None, _errores(component)
        creados.append((window, component, engine, view_model))
        qapp.processEvents()
        return window, view_model

    yield types.SimpleNamespace(biblioteca=biblioteca, montar=montar)

    for window, _component, engine, _view_model in creados:
        window.deleteLater()
        engine.deleteLater()
    qapp.processEvents()


def test_laboratorio_usa_modelo_guardado_y_vuelve_con_modelo_activo(entorno, qtbot):
    _guardar_modelo(entorno.biblioteca / "guardado.tvismodel")
    window, view_model = entorno.montar()

    navigation = _buscar(window, "laboratoryLibraryNavigation")
    laboratorio = _buscar(window, "moduleLaboratoryScreen")
    lab_controller = view_model.moduleLaboratoryController
    estado = _buscar(window, "moduleLaboratoryModelStatus")
    analizar = _buscar(window, "moduleLaboratoryAnalyzeButton")
    crear = _buscar(window, "moduleLaboratoryCreateModelButton")
    usar = _buscar(window, "moduleLaboratoryLoadModelButton")

    assert lab_controller.property("modelReady") is False
    assert "○ Falta un modelo" in _textos(estado)
    assert analizar.property("enabled") is False
    # A1: la ruta nueva convive con la de creación, no la sustituye.
    assert crear.property("visible") is True
    assert usar.property("visible") is True
    assert str(usar.property("text")) != str(crear.property("text"))
    # Junto a «Crear modelo», no en una fila aparte bajo el campo de texto.
    qtbot.waitUntil(lambda: usar.property("y") == crear.property("y"), timeout=3000)
    assert usar.property("x") > crear.property("x")

    _clic(usar)
    qtbot.waitUntil(lambda: navigation.property("depth") == 2, timeout=3000)
    biblioteca = navigation.property("currentItem")
    assert biblioteca.objectName() == "modelLibraryScreen"
    assert biblioteca.property("regresarAlLaboratorio") is True
    assert biblioteca.property("moduloRetornoLaboratorio") == "module_3"
    assert biblioteca.property("modoRetornoLaboratorio") == "training"

    usar_en_lab = _boton_de_tarjeta(qtbot, biblioteca)
    qtbot.waitUntil(lambda: usar_en_lab.property("visible") is True, timeout=3000)
    qtbot.waitUntil(lambda: usar_en_lab.property("enabled") is True, timeout=3000)
    _clic(usar_en_lab)

    # A2 y A8: la carga real recorre modelo_cargado → MainViewModel → set_model
    # y la biblioteca devuelve al laboratorio del que se salió.
    qtbot.waitUntil(lambda: lab_controller.property("modelReady") is True, timeout=15000)
    qtbot.waitUntil(lambda: navigation.property("depth") == 1, timeout=5000)
    actual = navigation.property("currentItem")
    assert actual.objectName() == "moduleLaboratoryScreen"
    assert actual.property("moduleId") == "module_3"
    assert actual.property("mode") == "training"
    assert laboratorio.property("visible") is True
    assert "● Modelo activo" in _textos(estado)
    assert analizar.property("enabled") is True
    assert view_model.property("modeloListo") is True


def test_laboratorio_sin_modelos_guardados_no_ofrece_cargarlos(entorno):
    window, _view_model = entorno.montar()

    crear = _buscar(window, "moduleLaboratoryCreateModelButton")
    usar = _buscar(window, "moduleLaboratoryLoadModelButton")
    assert crear.property("visible") is True
    # A3: sin modelos, la acción no lleva a una biblioteca vacía.
    assert usar.property("visible") is False

    # A4: el cartel deja de prometer «o carga» cuando no hay qué cargar.
    textos = [
        str(item.property("text") or "")
        for item in _descendientes_visuales(window.property("contentItem"))
    ]
    assert "Primero crea un modelo" in textos
    assert "Primero crea o carga un modelo" not in textos


def test_fallo_al_activar_modelo_guardado_se_informa_en_la_biblioteca(
    entorno, qtbot, monkeypatch
):
    """Si falla la sesión, el usuario se queda en la biblioteca viendo el motivo.

    Volver al laboratorio con «○ Falta un modelo» y sin explicación sería un
    fallo silencioso; quedarse con el mensaje de error visible no lo es.
    """

    def entrenamiento_roto(*_args, **_kwargs):
        raise RuntimeError("sesion de entrenamiento rota")

    monkeypatch.setattr(modulo_main_viewmodel, "TrainingController", entrenamiento_roto)
    _guardar_modelo(entorno.biblioteca / "guardado.tvismodel")
    window, view_model = entorno.montar()

    navigation = _buscar(window, "laboratoryLibraryNavigation")
    _clic(_buscar(window, "moduleLaboratoryLoadModelButton"))
    qtbot.waitUntil(lambda: navigation.property("depth") == 2, timeout=3000)
    biblioteca = navigation.property("currentItem")
    usar_en_lab = _boton_de_tarjeta(qtbot, biblioteca)
    qtbot.waitUntil(lambda: usar_en_lab.property("enabled") is True, timeout=3000)
    _clic(usar_en_lab)

    qtbot.waitUntil(lambda: biblioteca.property("mensajeEsError") is True, timeout=15000)
    assert "sesion de entrenamiento rota" in str(biblioteca.property("mensajeEstado"))
    assert biblioteca.property("accionTrasCarga") == ""
    assert navigation.property("depth") == 2
    assert view_model.moduleLaboratoryController.property("modelReady") is False
