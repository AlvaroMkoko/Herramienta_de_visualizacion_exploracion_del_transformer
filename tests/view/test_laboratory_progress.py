"""Contrato visual y temático del progreso del laboratorio."""

from __future__ import annotations

import os
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import QObject, QUrl
from PySide6.QtQml import QJSValue, QQmlComponent, QQmlEngine


PROJECT_ROOT = Path(__file__).resolve().parents[2]
QML_ROOT = PROJECT_ROOT / "view" / "qml"

HOST = b"""\
import QtQuick
import QtQuick.Controls
import "components" as Components
import "styles" as Style

ApplicationWindow {
    width: 1280
    height: 820
    visible: false

    property bool requestedDarkMode: Style.Theme.modoOscuro
    readonly property bool themeIsDark: Style.Theme.modoOscuro
    readonly property color progressSurface: progress.color
    readonly property color themeSurface: Style.Theme.surface
    readonly property color themeAccent: Style.Theme.acento
    readonly property color themeTextOnColor: Style.Theme.texto_sobre_color
    readonly property color themeSecondaryText: Style.Theme.texto_secundario

    onRequestedDarkModeChanged: Style.Theme.modoOscuro = requestedDarkMode

    Components.LaboratoryProgress {
        id: progress
        objectName: "laboratoryProgressUnderTest"
        anchors.centerIn: parent
        currentStep: 1
        sx: 1
        sy: 1
    }
}
"""


def _errors(component: QQmlComponent) -> str:
    return "\n".join(error.toString() for error in component.errors())


def test_progreso_sigue_el_theme_claro_y_oscuro(qapp):
    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(
        HOST,
        QUrl.fromLocalFile(str(QML_ROOT / "LaboratoryProgressHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)

    window = component.create()
    assert window is not None, _errors(component)
    qapp.processEvents()

    progress = window.findChild(QObject, "laboratoryProgressUnderTest")
    timeline = window.findChild(QObject, "laboratoryProgressUnderTestTimeline")
    assert progress is not None
    assert timeline is not None
    assert progress.property("currentStepTitle") == "Entrenamiento"
    assert window.property("progressSurface") == window.property("themeSurface")
    assert timeline.property("doneColor") == window.property("themeAccent")
    assert timeline.property("doneCheckColor") == window.property("themeTextOnColor")
    assert timeline.property("pendingLabelColor") == window.property(
        "themeSecondaryText"
    )

    model = timeline.property("model")
    model = model.toVariant() if isinstance(model, QJSValue) else model
    assert [step["state"] for step in model] == ["done", "running", "pending"]

    initial_mode = bool(window.property("themeIsDark"))
    initial_surface = window.property("themeSurface")
    initial_accent = window.property("themeAccent")

    try:
        assert window.setProperty("requestedDarkMode", not initial_mode)
        qapp.processEvents()

        assert bool(window.property("themeIsDark")) == (not initial_mode)
        assert window.property("progressSurface") == window.property("themeSurface")
        assert window.property("themeSurface") != initial_surface
        assert window.property("themeAccent") != initial_accent
        assert timeline.property("doneColor") == window.property("themeAccent")
        assert timeline.property("doneCheckColor") == window.property(
            "themeTextOnColor"
        )
        assert timeline.property("pendingLabelColor") == window.property(
            "themeSecondaryText"
        )
    finally:
        window.setProperty("requestedDarkMode", initial_mode)
        qapp.processEvents()
        window.deleteLater()
        engine.deleteLater()
        qapp.processEvents()
