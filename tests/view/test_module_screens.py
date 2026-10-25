"""Carga de humo de las pantallas reutilizables del curso modular."""

from __future__ import annotations

import os
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

import pytest
from PySide6.QtCore import QObject, QPointF, QUrl
from PySide6.QtQml import QQmlComponent, QQmlEngine
from PySide6.QtQuick import QQuickItem

from model.aprendizaje import LearningModuleCatalog
from model.evaluacion.results_repository import ResultsRepository
from viewmodel.main_viewmodel import MainViewModel


ROOT = Path(__file__).resolve().parents[2]
HOST = b"""\
import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {
    width: 1280
    height: 820
    visible: false
    StackView { id: navigation; anchors.fill: parent }
    Item {
        anchors.fill: parent
        Screens.ModuleMapScreen { stackView: navigation }
        Screens.ModuleScreen { stackView: navigation; moduleId: "module_1" }
        Screens.ModuleGuidedTourScreen { stackView: navigation; moduleId: "module_1" }
        Screens.ModuleLaboratoryScreen { stackView: navigation; moduleId: "module_1" }
        Screens.ModuleResultsScreen { stackView: navigation; moduleId: "module_1" }
        Screens.EvaluationIntroScreen {
            anchors.fill: parent
            stackView: navigation
            moduleId: "module_1"
            assessmentType: "pre"
        }
    }
}
"""

MODULE_LAYOUT_HOST = b"""\
import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {
    width: 1536
    height: 802
    visible: true
    StackView { id: navigation; anchors.fill: parent }
    Screens.ModuleScreen {
        anchors.fill: parent
        stackView: navigation
        moduleId: "module_3"
    }
}
"""

MODULE_PROGRESS_HOST = b"""\
import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {
    width: 1280
    height: 820
    visible: true
    StackView { id: navigation; anchors.fill: parent }
    Screens.ModuleScreen {
        anchors.fill: parent
        stackView: navigation
        moduleId: "module_1"
    }
}
"""


def _errors(component: QQmlComponent) -> str:
    return "\n".join(error.toString() for error in component.errors())


def _visual_descendants(item: QQuickItem) -> list[QQuickItem]:
    pending = list(item.childItems())
    descendants = []
    while pending:
        child = pending.pop()
        descendants.append(child)
        pending.extend(child.childItems())
    return descendants


def test_ruta_modular_no_recorta_boton_del_laboratorio_con_escalado(qapp):
    """Reproduce 1920x1000 fisicos con escalado de Windows al 125 %."""
    engine = QQmlEngine()
    view_model = MainViewModel()
    engine.rootContext().setContextProperty("mainViewModel", view_model)
    component = QQmlComponent(engine)
    component.setData(
        MODULE_LAYOUT_HOST,
        QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "ModuleLayoutHost.qml")),
    )

    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    for _ in range(5):
        qapp.processEvents()

    screen = window.findChild(QQuickItem, "moduleScreen")
    page_scroll = window.findChild(QQuickItem, "modulePageScroll")
    stage_scroll = window.findChild(QQuickItem, "moduleStageScroll")
    assert screen is not None
    assert page_scroll is not None
    assert stage_scroll is not None

    descendants = _visual_descendants(screen)
    cards = {
        item.objectName().removeprefix("moduleStageCard_"): item
        for item in descendants
        if item.objectName().startswith("moduleStageCard_")
    }
    buttons = {
        item.objectName().removeprefix("moduleStageButton_"): item
        for item in descendants
        if item.objectName().startswith("moduleStageButton_")
    }
    assert cards.keys() == buttons.keys()
    assert len(cards) == 5

    expected_height = 250 * float(screen.property("sx"))
    assert stage_scroll.height() >= expected_height - 1
    button_tops = []
    card_bottoms = []
    for index, card in cards.items():
        button = buttons[index]
        button_origin = button.mapToItem(card, QPointF(0, 0))
        button_tops.append(button_origin.y())
        assert button_origin.y() >= -1
        assert button_origin.y() + button.height() <= card.height() + 1

        card_bottom = card.mapToItem(
            page_scroll, QPointF(0, card.height())
        ).y()
        card_bottoms.append(card_bottom)
        assert card_bottom <= page_scroll.height() + 1
    assert max(button_tops) - min(button_tops) <= 1
    assert page_scroll.height() - max(card_bottoms) >= 10

    window.deleteLater()
    engine.deleteLater()


def test_pantallas_modulares_compilan_y_se_instancian(qapp):
    engine = QQmlEngine()
    view_model = MainViewModel()
    engine.rootContext().setContextProperty("mainViewModel", view_model)
    component = QQmlComponent(engine)
    component.setData(
        HOST,
        QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "ModuleScreensHost.qml")),
    )

    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    qapp.processEvents()

    guided = window.findChild(QObject, "moduleGuidedTourScreen")
    assert guided is not None
    module = view_model.courseController.currentModule
    assert guided.property("currentTheoryConceptId") == module["theory_sequence"][0]

    dimensions_scroll = window.findChild(QObject, "evaluationDimensionsScroll")
    dimensions_grid = window.findChild(QObject, "evaluationDimensionGrid")
    assert dimensions_scroll is not None
    assert dimensions_grid is not None

    window.deleteLater()
    engine.deleteLater()


def test_modulo_actualiza_etapas_al_completar_sin_recrear_pantalla(qapp, tmp_path):
    """La pantalla queda viva debajo de cada etapa dentro del StackView."""
    from model.aprendizaje import ModuleProgressRepository
    from model.aprendizaje.module_question_bank import ModuleQuestionBank

    engine = QQmlEngine()
    view_model = MainViewModel()
    course = view_model.courseController
    course._repository = ModuleProgressRepository(tmp_path / "progreso.json")
    course._state = course._repository.snapshot()
    results = ResultsRepository(tmp_path / "resultados.json")
    course._evaluation._repository = results
    engine.rootContext().setContextProperty("mainViewModel", view_model)
    component = QQmlComponent(engine)
    component.setData(
        MODULE_PROGRESS_HOST,
        QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "ModuleProgressHost.qml")),
    )

    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    for _ in range(5):
        qapp.processEvents()

    screen = window.findChild(QQuickItem, "moduleScreen")
    assert screen is not None
    descendants = _visual_descendants(screen)
    by_name = {item.objectName(): item for item in descendants if item.objectName()}
    pre_card = by_name.get("moduleStageCard_0")
    guided_card = by_name.get("moduleStageCard_1")
    guided_button = by_name.get("moduleStageButton_1")
    laboratory_card = by_name.get("moduleStageCard_2")
    laboratory_button = by_name.get("moduleStageButton_2")
    post_card = by_name.get("moduleStageCard_3")
    post_button = by_name.get("moduleStageButton_3")
    results_card = by_name.get("moduleStageCard_4")
    results_button = by_name.get("moduleStageButton_4")
    assert all(
        item is not None
        for item in (
            pre_card,
            guided_card,
            guided_button,
            laboratory_card,
            laboratory_button,
            post_card,
            post_button,
            results_card,
            results_button,
        )
    )
    assert pre_card.property("completed") is False
    assert guided_card.property("available") is False
    assert guided_button.property("enabled") is False

    result = {
        "schema_version": 2,
        "instrument_version": ModuleQuestionBank.VERSION_PREGUNTAS,
        "assessment_type": "pre",
        "module_id": "module_1",
        "percentage": 80.0,
    }
    results.save_result(result)
    course._on_evaluation_completed(result)
    qapp.processEvents()

    assert pre_card.property("completed") is True
    assert guided_card.property("available") is True
    assert guided_button.property("enabled") is True

    course.enterGuidedTour("module_1")
    for step in course.catalog.get("module_1")["guided_steps"]:
        course.recordGuidedCheck(
            "module_1", step["id"], int(step["check"]["correct_index"])
        )
    assert course.completeGuidedTour("module_1")
    qapp.processEvents()
    assert guided_card.property("completed") is True
    assert laboratory_card.property("available") is True
    assert laboratory_button.property("enabled") is True

    steps = course.catalog.get("module_1")["guided_steps"]
    for step in steps[: course.REQUIRED_LAB_CYCLES]:
        course.recordDiscoveryCycle("module_1", step["id"], True, 1)
    closing = course.catalog.get("module_1")["anchor"]["closing"]
    course.recordAnchorClosing("module_1", int(closing["correct_index"]))
    qapp.processEvents()
    assert laboratory_card.property("completed") is True
    assert post_card.property("available") is True
    assert post_button.property("enabled") is True

    post_result = result | {"assessment_type": "post", "percentage": 90.0}
    results.save_result(post_result)
    course._on_evaluation_completed(post_result)
    qapp.processEvents()
    assert post_card.property("completed") is True
    assert results_card.property("available") is True
    assert results_button.property("enabled") is True

    window.deleteLater()
    engine.deleteLater()


def test_los_64_pasos_modulares_tienen_ilustracion_especifica(qapp):
    engine = QQmlEngine()
    view_model = MainViewModel()
    engine.rootContext().setContextProperty("mainViewModel", view_model)
    component = QQmlComponent(engine)
    component.setData(
        HOST,
        QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "ModuleScreensHost.qml")),
    )

    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    qapp.processEvents()

    visual = window.findChild(QObject, "moduleGuidedVisualization")
    diagram = window.findChild(QObject, "guidedConceptDiagram")
    assert visual is not None
    assert diagram is not None

    summaries = set()
    catalog = LearningModuleCatalog()
    step_ids = [
        step["id"]
        for module in catalog.modules
        for step in module["guided_steps"]
    ]
    assert len(step_ids) == 64

    for step_id in step_ids:
        visual.setProperty("stepId", step_id)
        qapp.processEvents()
        assert visual.property("hasDedicatedVisual") is True
        assert str(visual.property("visualKind")).strip()
        assert diagram.property("sceneKind") == step_id
        summary = str(visual.property("accessibleSummary")).strip()
        assert len(summary) >= 60
        assert "Cómo fluye la información" not in summary
        summaries.add(summary)

    assert len(summaries) == 64

    window.deleteLater()
    engine.deleteLater()


TOUR_HOST = b"""import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {
    width: 1280
    height: 820
    visible: false
    StackView { id: navigation; anchors.fill: parent }
    Screens.ModuleGuidedTourScreen {
        anchors.fill: parent
        stackView: navigation
        moduleId: "module_3"
    }
}
"""


def _unlock_stage(course, results, module_id: str, stage: str) -> None:
    """Meets the real prerequisites (RN18) the way a student would: review
    mode is off by default, so a locked stage ignores the screen's input."""
    from viewmodel.course_controller import STAGES, CourseController

    def complete(target: str, stages) -> None:
        for name in stages:
            if name in ("pretest", "posttest"):
                results.save_result(
                    {
                        "schema_version": 2,
                        "assessment_type": "pre" if name == "pretest" else "post",
                        "module_id": target,
                        "percentage": 80.0,
                    }
                )
            elif name == "guided":
                for step in course.catalog.get(target)["guided_steps"]:
                    course.recordGuidedCheck(target, step["id"], 0)
                assert course.completeGuidedTour(target)
            elif name == "laboratory":
                steps = course.catalog.get(target)["guided_steps"]
                for step in steps[: CourseController.REQUIRED_LAB_CYCLES]:
                    course.recordDiscoveryCycle(target, step["id"], True, 1)
                course.recordAnchorClosing(target, 0)
            elif name == "results":
                course.markResultsViewed(target)
            assert course.stageCompleted(target, name), (target, name)

    module_ids = [module["id"] for module in course.modules]
    for previous in module_ids[: module_ids.index(module_id)]:
        complete(previous, STAGES)
    complete(module_id, STAGES[: STAGES.index(stage)])
    assert course.stageAvailable(module_id, stage)


def test_recorrido_exige_predecir_antes_de_revelar_y_avanzar(qapp, tmp_path):
    from PySide6.QtCore import Q_ARG, QMetaObject

    from model.aprendizaje import ModuleProgressRepository

    engine = QQmlEngine()
    view_model = MainViewModel()
    course = view_model.courseController
    # Progreso y resultados propios: la suite comparte un solo temporal entre
    # pruebas, y abrir el recorrido exige el pre-test y los módulos previos.
    course._repository = ModuleProgressRepository(tmp_path / "progreso.json")
    course._state = course._repository.snapshot()
    results = ResultsRepository(tmp_path / "resultados.json")
    course._evaluation._repository = results
    _unlock_stage(course, results, "module_3", "guided")
    engine.rootContext().setContextProperty("mainViewModel", view_model)
    component = QQmlComponent(engine)
    component.setData(
        TOUR_HOST,
        QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "TourHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    qapp.processEvents()

    tour = window.findChild(QObject, "moduleGuidedTourScreen")
    next_button = window.findChild(QObject, "moduleGuidedNextButton")
    check = window.findChild(QObject, "moduleGuidedCheck")
    definition = window.findChild(QObject, "moduleGuidedDefinition")
    assert tour is not None and next_button is not None and check is not None
    assert definition is not None and definition.property("visible")
    # Abrir la pantalla es entrar al recorrido: el pre-test queda cerrado.
    assert not course.stageAvailable("module_3", "pretest")
    assert tour.property("currentAttempted") is False
    assert next_button.property("enabled") is False

    # Saltar hacia adelante por los chips no pasa de la primera predicción.
    QMetaObject.invokeMethod(tour, "goToStep", Q_ARG("QVariant", 5))
    assert tour.property("currentIndex") == 0

    QMetaObject.invokeMethod(tour, "submitCheck", Q_ARG("QVariant", 0))
    qapp.processEvents()
    assert tour.property("currentAttempted") is True
    assert next_button.property("enabled") is True
    assert course.guidedProgress("module_3")["attempted"] == ["m3_s1"]
    assert not course.stageCompleted("module_3", "guided")

    window.deleteLater()
    engine.deleteLater()


EVALUATION_HOST = b"""import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {
    width: 1280
    height: 820
    visible: false
    StackView { id: navigation; anchors.fill: parent }
    Screens.EvaluationScreen {
        anchors.fill: parent
        stackView: navigation
        moduleId: "module_1"
        assessmentType: "pre"
    }
}
"""


def _correct_answer(question: dict) -> dict:
    if question["tipo"] == "opcion_unica":
        return {"opcion_id": question["correct_option_id"]}
    if question["tipo"] == "seleccion_multiple":
        return {"opciones_ids": question["correct_option_ids"]}
    if question["tipo"] == "texto":
        return {"texto": question["respuestas_aceptadas"][0]}
    return {"asignaciones": {item["id"]: item["correcto"] for item in question["elementos"]}}


@pytest.mark.parametrize("entered_tour", [False, True])
def test_repetir_el_pretest_respeta_la_entrada_al_recorrido(qapp, tmp_path, entered_tour):
    from model.aprendizaje import ModuleProgressRepository

    view_model = MainViewModel()
    course = view_model.courseController
    course._repository = ModuleProgressRepository(tmp_path / "progreso.json")
    course._state = course._repository.snapshot()
    evaluation = view_model.moduleEvaluationController
    evaluation._repository = ResultsRepository(tmp_path / "resultados.json")
    evaluation.startModuleEvaluation("module_1", "pre")
    while evaluation.isActive:
        evaluation.registrarRespuesta(_correct_answer(evaluation._manager.current_question))
        evaluation.submitCurrentAnswer()
    assert evaluation.finished
    if entered_tour:
        course.enterGuidedTour("module_1")

    engine = QQmlEngine()
    engine.rootContext().setContextProperty("mainViewModel", view_model)
    component = QQmlComponent(engine)
    component.setData(
        EVALUATION_HOST,
        QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "EvaluationHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    qapp.processEvents()

    screen = window.findChild(QObject, "evaluationScreen")
    repeat = window.findChild(QObject, "evaluationRepeatButton")
    assert screen.property("showingResult") is True
    assert repeat is not None
    assert repeat.property("visible") is (not entered_tour)

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


RESULTS_HOST = b"""import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {
    width: 1280
    height: 820
    visible: false
    StackView { id: navigation; anchors.fill: parent }
    Screens.ModuleResultsScreen { anchors.fill: parent; stackView: navigation; moduleId: "module_1" }
}
"""


def test_resultados_muestran_cuantas_veces_se_tomo_cada_evaluacion(qapp, tmp_path):
    from model.aprendizaje import ModuleProgressRepository

    view_model = MainViewModel()
    course = view_model.courseController
    course._repository = ModuleProgressRepository(tmp_path / "progreso.json")
    course._state = course._repository.snapshot()
    results = ResultsRepository(tmp_path / "resultados.json")
    view_model.moduleEvaluationController._repository = results
    for assessment, percentage in (("pre", 30.0), ("pre", 90.0), ("post", 70.0)):
        results.save_result(
            {
                "schema_version": 2,
                "assessment_type": assessment,
                "module_id": "module_1",
                "percentage": percentage,
            }
        )

    engine = QQmlEngine()
    engine.rootContext().setContextProperty("mainViewModel", view_model)
    component = QQmlComponent(engine)
    component.setData(
        RESULTS_HOST,
        QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "ResultsHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    qapp.processEvents()

    screen_results = window.findChild(QQuickItem, "moduleResultsScreen")
    assert screen_results.property("results")["pre_percentage"] == 30.0  # el primero
    # Los delegados de un Repeater no son hijos QObject: se buscan en el árbol visual.
    by_name = {item.objectName(): item for item in _visual_descendants(screen_results)}
    assert by_name["moduleResultsPreAttempts"].property("text") == "Cuenta el 1.º de 2 intentos"
    assert by_name["moduleResultsPostAttempts"].property("text") == "1 intento"

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()
