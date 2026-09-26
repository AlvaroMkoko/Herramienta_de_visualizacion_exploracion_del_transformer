"""Pruebas de contrato de la experiencia educativa guiada en QML.

Estas pruebas verifican estado y navegacion mediante propiedades, funciones y
``objectName`` publicos. Deliberadamente no dependen de coordenadas, colores ni
dimensiones visuales, para permitir que el diseno evolucione sin romperlas.
"""

from __future__ import annotations

import os
from pathlib import Path

# Deben fijarse antes de que pytest-qt construya QApplication.
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

import pytest
from PySide6.QtCore import Q_ARG, QMetaObject, QObject, QSettings, Qt, QUrl
from PySide6.QtQml import QJSValue, QQmlComponent, QQmlEngine

from viewmodel import main_viewmodel as modulo_main_viewmodel
from viewmodel.learning_controller import LearningController
from viewmodel.main_viewmodel import MainViewModel


RAIZ_PROYECTO = Path(__file__).resolve().parents[2]

HOST_GUIDED = b"""\
import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {
    objectName: "guidedLearningHost"
    width: 1280
    height: 820
    visible: false

    StackView {
        id: navigation
        objectName: "learningNavigation"
        anchors.fill: parent
        initialItem: guidedPage
    }

    Component {
        id: guidedPage
        Screens.GuidedLearningScreen {
            stackView: navigation
        }
    }
}
"""

HOST_HOME = b"""\
import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {
    objectName: "learningHomeHost"
    width: 1280
    height: 820
    visible: false

    StackView {
        id: navigation
        objectName: "learningNavigation"
        anchors.fill: parent
        initialItem: homePage
    }

    Component {
        id: homePage
        Screens.HomeScreen {
            stackView: navigation
        }
    }
}
"""


def _errores(component: QQmlComponent) -> str:
    return "\n".join(error.toString() for error in component.errors())


def _como_python(valor):
    return valor.toVariant() if isinstance(valor, QJSValue) else valor


def _propiedad(objeto: QObject, nombre: str):
    return _como_python(objeto.property(nombre))


def _invocar(objeto: QObject, metodo: str, argumento=None) -> None:
    if argumento is None:
        ejecutado = QMetaObject.invokeMethod(
            objeto, metodo, Qt.ConnectionType.DirectConnection
        )
    else:
        ejecutado = QMetaObject.invokeMethod(
            objeto,
            metodo,
            Qt.ConnectionType.DirectConnection,
            Q_ARG("QVariant", argumento),
        )
    assert ejecutado, f"No se pudo invocar {metodo}"


def _buscar(raiz: QObject, object_name: str) -> QObject:
    encontrado = raiz.findChild(QObject, object_name)
    assert encontrado is not None, f"Falta el hook publico objectName={object_name!r}"
    return encontrado


def _crear_view_model_aislado(monkeypatch, tmp_path: Path) -> MainViewModel:
    """Evita leer o escribir el progreso real del usuario durante la prueba."""
    settings = QSettings(
        str(tmp_path / "guided-learning-test.ini"), QSettings.Format.IniFormat
    )
    settings.clear()
    settings.sync()

    def crear_controlador(parent=None):
        return LearningController(parent=parent, settings=settings)

    monkeypatch.setattr(
        modulo_main_viewmodel, "LearningController", crear_controlador
    )
    return MainViewModel()


def _crear_host(
    datos_qml: bytes,
    nombre_host: str,
    qapp,
    qtbot,
    monkeypatch,
    tmp_path: Path,
):
    engine = QQmlEngine()
    view_model = _crear_view_model_aislado(monkeypatch, tmp_path)
    engine.rootContext().setContextProperty("mainViewModel", view_model)

    component = QQmlComponent(engine)
    component.setData(
        datos_qml,
        QUrl.fromLocalFile(str(RAIZ_PROYECTO / "view" / "qml" / nombre_host)),
    )
    if component.status() == QQmlComponent.Status.Loading:
        qtbot.waitUntil(
            lambda: component.status() != QQmlComponent.Status.Loading,
            timeout=5000,
        )
    assert component.status() != QQmlComponent.Status.Error, _errores(component)

    window = component.create()
    assert window is not None, _errores(component)
    # La plataforma offscreen no muestra una ventana real, pero Qt Quick solo
    # resuelve por completo sus Layouts cuando la QWindow está visible.
    window.show()
    qapp.processEvents()
    return engine, component, window, view_model


@pytest.fixture
def guided_qml(qapp, qtbot, monkeypatch, tmp_path):
    engine, component, window, view_model = _crear_host(
        HOST_GUIDED,
        "GuidedLearningTestHost.qml",
        qapp,
        qtbot,
        monkeypatch,
        tmp_path,
    )

    yield window, view_model

    window.deleteLater()
    component.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


@pytest.fixture
def home_qml(qapp, qtbot, monkeypatch, tmp_path):
    engine, component, window, view_model = _crear_host(
        HOST_HOME,
        "GuidedHomeTestHost.qml",
        qapp,
        qtbot,
        monkeypatch,
        tmp_path,
    )

    yield window, view_model

    window.deleteLater()
    component.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_recorrido_expone_seis_unidades_y_dieciocho_conceptos(guided_qml, qtbot):
    window, _ = guided_qml
    screen = _buscar(window, "guidedLearningScreen")

    assert _propiedad(screen, "totalUnits") == 6
    assert _propiedad(screen, "totalCoreConcepts") == 18
    assert _propiedad(screen, "predictionOptionCount") == 3
    assert _propiedad(screen, "currentUnitIndex") == 0
    assert _propiedad(screen, "currentConceptIndex") == 0
    assert _propiedad(screen, "currentConceptId")

    # La lectura es el contenido central, no debe quedar comprimida por la
    # barra de navegación inferior del ColumnLayout.
    concept_reader = _buscar(window, "guidedConceptReader")
    previous_button = _buscar(window, "guidedPreviousConceptButton")
    qtbot.waitUntil(lambda: _propiedad(concept_reader, "height") > 300, timeout=3000)
    assert _propiedad(concept_reader, "height") > 300
    assert _propiedad(previous_button, "height") < 80

    # Hooks estables para lectores de pantalla, automatizacion y pruebas.
    for object_name in (
        "guidedBackButton",
        "guidedPreviousConceptButton",
        "guidedNextConceptButton",
        "guidedConceptReader",
        "guidedConceptVisualization",
        "guidedConceptDiagram",
        "guidedActivityCard",
        "guidedQuestionPanel",
        "guidedObservePanel",
        "guidedDemoVisualization",
        "guidedObservationPanel",
        "guidedPedagogicalExplanation",
    ):
        _buscar(window, object_name)

    activity = _buscar(window, "guidedActivityCard")
    concept_visual = _buscar(window, "guidedConceptVisualization")
    assert _propiedad(activity, "stageLabels") == ["1 · Pregunta", "2 · Observa"]
    assert _propiedad(concept_visual, "conceptId") == "que_es_transformer"
    assert _propiedad(concept_visual, "accessibleSummary")
    assert window.findChild(QObject, "guidedExplanationInput") is None
    assert window.findChild(QObject, "guidedFeedbackPanel") is None


def test_navegacion_cambia_concepto_y_respeta_unidades(guided_qml, qapp):
    window, view_model = guided_qml
    screen = _buscar(window, "guidedLearningScreen")
    _invocar(screen, "resetProgress")
    qapp.processEvents()

    concepto_inicial = _propiedad(screen, "currentConceptId")
    _invocar(screen, "nextConcept")
    qapp.processEvents()

    assert _propiedad(screen, "currentUnitIndex") == 0
    assert _propiedad(screen, "currentConceptIndex") == 1
    assert _propiedad(screen, "currentConceptId") != concepto_inicial

    _invocar(screen, "previousConcept")
    qapp.processEvents()
    assert _propiedad(screen, "currentConceptIndex") == 0
    assert _propiedad(screen, "currentConceptId") == concepto_inicial

    for unit_number in range(1, 6):
        view_model.learningController.markUnitCompleted(f"unit_{unit_number}")
    qapp.processEvents()
    _invocar(screen, "selectUnit", 5)
    qapp.processEvents()
    assert _propiedad(screen, "currentUnitIndex") == 5
    assert _propiedad(screen, "currentConceptIndex") == 0
    assert _propiedad(screen, "currentConceptId") == "dataset"
    assert _propiedad(_buscar(window, "guidedDemoVisualization"), "visualType") == "dataset_pairs"

    # Cada unidad contiene tres conceptos nucleares y la navegacion se acota.
    _invocar(screen, "nextConcept")
    _invocar(screen, "nextConcept")
    _invocar(screen, "nextConcept")
    qapp.processEvents()
    assert _propiedad(screen, "currentConceptIndex") == 2


def test_cada_concepto_tiene_una_visualizacion_pedagogica_propia(
    guided_qml, qapp
):
    window, view_model = guided_qml
    screen = _buscar(window, "guidedLearningScreen")
    visual = _buscar(window, "guidedConceptVisualization")
    diagram = _buscar(window, "guidedConceptDiagram")
    expected_groups = [
        ["que_es_transformer", "encoder_decoder_general", "flujo_general"],
        ["tokenizacion", "embeddings", "positional_encoding"],
        ["query_key_value", "formula_attention_completa", "problema_multi_head"],
        ["por_que_mascara", "generacion_token_por_token", "seleccion_token"],
        ["entrenamiento_vs_inferencia", "cross_entropy", "actualizacion_parametros"],
        ["dataset", "teacher_forcing", "epoch_batch"],
    ]

    _invocar(screen, "resetProgress")
    summaries = set()
    for unit_index, concept_ids in enumerate(expected_groups):
        if unit_index > 0:
            view_model.learningController.markUnitCompleted(f"unit_{unit_index}")
            qapp.processEvents()
        _invocar(screen, "selectUnit", unit_index)
        for concept_index, concept_id in enumerate(concept_ids):
            _invocar(screen, "selectConcept", concept_index)
            qapp.processEvents()
            assert _propiedad(screen, "currentConceptId") == concept_id
            concept = _propiedad(screen, "currentConcept")
            assert concept["id"] == concept_id
            assert len(str(concept.get("explanation", "")).strip()) >= 80
            assert _propiedad(visual, "conceptId") == concept_id
            assert _propiedad(diagram, "sceneKind") == concept_id
            summary = str(_propiedad(visual, "accessibleSummary")).strip()
            assert len(summary) >= 40
            summaries.add(summary)
            assert _propiedad(visual, "implicitHeight") >= 180

    assert len(summaries) == 18


def test_actividad_se_limita_a_pregunta_y_observacion_y_actualiza_progreso(
    guided_qml, qapp
):
    window, _ = guided_qml
    screen = _buscar(window, "guidedLearningScreen")
    observation_panel = _buscar(window, "guidedObservationPanel")
    demo = _buscar(window, "guidedDemoVisualization")
    pedagogical_explanation = _buscar(window, "guidedPedagogicalExplanation")

    _invocar(screen, "resetProgress")
    _invocar(screen, "selectUnit", 0)
    qapp.processEvents()
    assert _propiedad(screen, "activityStage") == 0
    assert _propiedad(screen, "selectedPrediction") == -1
    assert _propiedad(screen, "completedUnitsCount") == 0
    assert _propiedad(demo, "visualType") == "pipeline"
    assert _propiedad(demo, "compactLayout") is True
    assert _propiedad(demo, "implicitHeight") >= 250
    assert "dataset aporta instruction" in _propiedad(demo, "accessibleSummary")
    _buscar(window, "guidedPipelineDatasetBlock")
    _buscar(window, "guidedPipelineTokenizationBlock")
    _buscar(window, "guidedPipelineTransformerBlock")
    _buscar(window, "guidedPipelineLearningBlock")

    _invocar(screen, "selectPrediction", 1)
    qapp.processEvents()
    assert _propiedad(screen, "selectedPrediction") == 1

    _invocar(screen, "showObservation")
    qapp.processEvents()
    assert _propiedad(screen, "activityStage") == 1
    assert _propiedad(observation_panel, "visible") is True
    assert _propiedad(screen, "completedUnitsCount") == 1
    assert _propiedad(pedagogical_explanation, "visible") is True
    assert window.findChild(QObject, "guidedExplanationInput") is None
    assert window.findChild(QObject, "guidedFeedbackPanel") is None

    # Volver a pedir la observación no debe inflar el progreso.
    _invocar(screen, "showObservation")
    qapp.processEvents()
    assert _propiedad(screen, "completedUnitsCount") == 1


def test_home_expone_secuencia_y_abre_el_recorrido_guiado(home_qml, qapp, qtbot):
    window, view_model = home_qml
    home = _buscar(window, "homeScreen")
    navigation = _buscar(window, "learningNavigation")

    assert _propiedad(home, "totalPlatformStages") == 5
    assert _propiedad(home, "platformStageOrder") == [1, 2, 3, 4, 5]
    assert _propiedad(home, "platformStageAvailability") == [
        True,
        True,
        False,
        True,
        True,
    ]

    etapas = [
        ("pretestStageCard", 1, True, False, "EvaluationIntroScreen.qml"),
        ("guidedStageCard", 2, True, False, "GuidedLearningScreen.qml"),
        ("labsStageCard", 3, False, False, ""),
        ("posttestStageCard", 4, True, False, "EvaluationIntroScreen.qml"),
        ("resultsStageCard", 5, True, True, "ModulePlaceholderScreen.qml"),
    ]
    for object_name, orden, disponible, placeholder, ruta in etapas:
        tarjeta = _buscar(home, object_name)
        assert _propiedad(tarjeta, "stageOrder") == orden
        assert _propiedad(tarjeta, "stageAvailable") is disponible
        assert _propiedad(tarjeta, "stagePlaceholder") is placeholder
        assert _propiedad(tarjeta, "stageStatus")
        assert _propiedad(tarjeta, "stageRoute") == ruta

    for object_name in (
        "guidedStartButton",
        "pretestOpenButton",
        "trainingLabButton",
        "modelLibraryLabButton",
        "comparisonLabButton",
        "posttestOpenButton",
        "resultsOpenButton",
        "datasetManagerButton",
    ):
        _buscar(home, object_name)

    def placeholder_visible():
        return next(
            (
                item
                for item in window.findChildren(QObject, "modulePlaceholderScreen")
                if _propiedad(item, "visible")
            ),
            None,
        )

    def abrir_placeholder(button_name, expected_title, expected_stage):
        _invocar(_buscar(home, button_name), "clicked")
        qtbot.waitUntil(
            lambda: _propiedad(navigation, "depth") == 2
            and placeholder_visible() is not None,
            timeout=5000,
        )
        placeholder = placeholder_visible()
        assert _propiedad(placeholder, "moduleTitle") == expected_title
        assert _propiedad(placeholder, "stageNumber") == expected_stage
        _invocar(_buscar(placeholder, "modulePlaceholderBackButton"), "clicked")
        qtbot.waitUntil(lambda: _propiedad(navigation, "depth") == 1, timeout=5000)
        qapp.processEvents()

    def evaluation_intro_visible():
        return next(
            (
                item
                for item in window.findChildren(QObject, "evaluationIntroScreen")
                if _propiedad(item, "visible")
            ),
            None,
        )

    def abrir_evaluacion(button_name, expected_type, expected_title):
        _invocar(_buscar(home, button_name), "clicked")
        qtbot.waitUntil(
            lambda: _propiedad(navigation, "depth") == 2
            and evaluation_intro_visible() is not None,
            timeout=5000,
        )
        intro = evaluation_intro_visible()
        assert _propiedad(intro, "assessmentType") == expected_type
        assert _propiedad(_buscar(intro, "evaluationIntroTitle"), "text") == expected_title
        assert _propiedad(_buscar(intro, "evaluationStartButton"), "enabled") is True
        _invocar(_buscar(intro, "evaluationIntroBackButton"), "clicked")
        qtbot.waitUntil(lambda: _propiedad(navigation, "depth") == 1, timeout=5000)
        qapp.processEvents()

    abrir_evaluacion("pretestOpenButton", "pre", "Pre-test")
    abrir_evaluacion("posttestOpenButton", "post", "Post-test")
    abrir_placeholder("resultsOpenButton", "Progreso y resultados", 5)

    # Haber avanzado dentro de la primera unidad también debe mostrarse como
    # reanudación, aunque todavía no haya una unidad completa.
    view_model.learningController.savePosition(0, 1)
    qapp.processEvents()
    assert _propiedad(home, "guidedActionLabel") == "Continuar recorrido"

    assert _propiedad(navigation, "depth") == 1
    _invocar(_buscar(home, "guidedStartButton"), "clicked")
    qtbot.waitUntil(
        lambda: _propiedad(navigation, "depth") == 2
        and window.findChild(QObject, "guidedLearningScreen") is not None,
        timeout=5000,
    )
    qapp.processEvents()

    guided = _buscar(window, "guidedLearningScreen")
    assert _propiedad(guided, "totalUnits") == 6
    assert _propiedad(guided, "totalCoreConcepts") == 18
    assert _propiedad(guided, "currentConceptIndex") == 1


def test_pretest_responde_ocho_preguntas_y_muestra_resultado(
    home_qml, qapp, qtbot
):
    window, view_model = home_qml
    home = _buscar(window, "homeScreen")
    navigation = _buscar(window, "learningNavigation")

    _invocar(_buscar(home, "pretestOpenButton"), "clicked")
    qtbot.waitUntil(
        lambda: window.findChild(QObject, "evaluationIntroScreen") is not None,
        timeout=5000,
    )
    intro = _buscar(window, "evaluationIntroScreen")
    _invocar(_buscar(intro, "evaluationStartButton"), "clicked")
    qtbot.waitUntil(
        lambda: _propiedad(navigation, "depth") == 3
        and window.findChild(QObject, "evaluationScreen") is not None,
        timeout=5000,
    )
    evaluation = _buscar(window, "evaluationScreen")
    controller = view_model.evaluationController

    first_question = _propiedad(controller, "currentQuestion")
    assert first_question["id"] == "pre_t1"
    assert "correct_option_id" not in first_question
    assert _propiedad(_buscar(evaluation, "evaluationNextButton"), "enabled") is False
    assert _propiedad(_buscar(evaluation, "evaluationOptionsRepeater"), "count") == 4

    for expected_number in range(1, 9):
        assert _propiedad(controller, "currentQuestionNumber") == expected_number
        controller.selectAnswer("a")
        qapp.processEvents()
        assert _propiedad(controller, "selectedOptionId") == "a"
        next_button = _buscar(evaluation, "evaluationNextButton")
        assert _propiedad(next_button, "enabled") is True
        _invocar(next_button, "clicked")
        qapp.processEvents()

    assert _propiedad(controller, "finished") is True
    result = _propiedad(controller, "result")
    assert result["correct"] == 2
    assert result["total"] == 8
    assert len(result["dimensions"]) == 2
    assert _propiedad(_buscar(evaluation, "evaluationResultCard"), "visible") is True
    assert _propiedad(_buscar(evaluation, "evaluationScoreText"), "text") == "2 / 8"
