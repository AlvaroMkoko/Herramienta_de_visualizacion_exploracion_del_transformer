"""Carga de humo de las pantallas reutilizables del curso modular."""

from __future__ import annotations

import os
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import QObject, QUrl
from PySide6.QtQml import QQmlComponent, QQmlEngine

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


def _errors(component: QQmlComponent) -> str:
    return "\n".join(error.toString() for error in component.errors())


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
