"""Carga de humo de las pantallas reutilizables del curso modular."""

from __future__ import annotations

import os
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import QObject, QPointF, QUrl
from PySide6.QtQml import QQmlComponent, QQmlEngine
from PySide6.QtQuick import QQuickItem

from model.aprendizaje import LearningModuleCatalog
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
