"""Contratos del lector educativo compartido y sus accesos contextuales."""

from __future__ import annotations

import os
import re
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

import pytest
from PySide6.QtCore import Q_ARG, QMetaObject, QObject, Qt, QUrl
from PySide6.QtQml import QJSValue, QQmlComponent, QQmlEngine

from viewmodel.main_viewmodel import MainViewModel
from viewmodel.theory_controller import TheoryController
from viewmodel.visual_adapter import _CONCEPTO_POR_METRICA


PROJECT_ROOT = Path(__file__).resolve().parents[2]
QML_ROOT = PROJECT_ROOT / "view" / "qml"


def _errors(component: QQmlComponent) -> str:
    return "\n".join(error.toString() for error in component.errors())


def _invoke_qml(obj: QObject, method: str, argument=None) -> None:
    if argument is None:
        invoked = QMetaObject.invokeMethod(
            obj, method, Qt.ConnectionType.DirectConnection
        )
    else:
        invoked = QMetaObject.invokeMethod(
            obj,
            method,
            Qt.ConnectionType.DirectConnection,
            Q_ARG("QVariant", argument),
        )
    assert invoked, f"No se pudo invocar {method}"


@pytest.mark.parametrize(
    "screen_name, extra_properties",
    [
        ("ResultsScreen", "historialPerdidas: [2.0, 1.0]"),
        ("InferenceScreen", ""),
        ("ComparisonScreen", ""),
        ("ModelSetScreen", ""),
        ("ModelLibraryScreen", ""),
        (
            "ModelDetailScreen",
            'rutaModelo: "C:/modelo-inexistente-para-prueba.tvismodel"',
        ),
    ],
)
def test_pantallas_tecnicas_compilan_con_el_lector_compartido(
    qapp, screen_name: str, extra_properties: str
):
    engine = QQmlEngine()
    view_model = MainViewModel()
    engine.rootContext().setContextProperty("mainViewModel", view_model)
    source = f"""
import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {{
    width: 1280
    height: 820
    visible: false
    StackView {{ id: navigation; anchors.fill: parent }}
    Screens.{screen_name} {{
        anchors.fill: parent
        stackView: navigation
        {extra_properties}
    }}
}}
""".encode()

    component = QQmlComponent(engine)
    component.setData(
        source,
        QUrl.fromLocalFile(str(QML_ROOT / "HelpSystemHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)

    window = component.create()
    assert window is not None, _errors(component)
    qapp.processEvents()

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_todos_los_botones_de_ayuda_apuntan_a_conceptos_existentes():
    pattern = re.compile(
        r"(?:conceptId|helpConceptId|help)\s*:\s*\"([a-z0-9_]+)\""
    )
    references: dict[str, set[Path]] = {}

    for qml_path in QML_ROOT.rglob("*.qml"):
        for concept_id in pattern.findall(qml_path.read_text(encoding="utf8")):
            references.setdefault(concept_id, set()).add(qml_path)

    assert references, "No se encontraron accesos de ayuda contextual en QML."

    controller = TheoryController()
    missing = {
        concept_id: sorted(str(path.relative_to(PROJECT_ROOT)) for path in paths)
        for concept_id, paths in references.items()
        if not controller.obtenerConcepto(concept_id).get("existe", False)
    }
    assert missing == {}


def test_las_metricas_dinamicas_apuntan_a_conceptos_existentes():
    controller = TheoryController()
    missing = {
        label: concept_id
        for label, concept_id in _CONCEPTO_POR_METRICA.items()
        if not controller.obtenerConcepto(concept_id).get("existe", False)
    }
    assert missing == {}


def test_detalle_de_modelo_selecciona_antes_de_abrir_la_teoria(qapp):
    engine = QQmlEngine()
    view_model = MainViewModel()
    engine.rootContext().setContextProperty("mainViewModel", view_model)
    source = b"""
import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {
    width: 1280
    height: 820
    visible: false
    StackView { id: navigation; anchors.fill: parent }
    Screens.ModelDetailScreen {
        anchors.fill: parent
        stackView: navigation
        rutaModelo: "C:/modelo-inexistente-para-prueba.tvismodel"
    }
}
"""
    component = QQmlComponent(engine)
    component.setData(
        source,
        QUrl.fromLocalFile(str(QML_ROOT / "HelpSystemHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)

    window = component.create()
    assert window is not None, _errors(component)
    qapp.processEvents()

    diagram = window.findChild(QObject, "modelDetailTransformerDiagram")
    summary = window.findChild(QObject, "modelDetailConceptSummary")
    open_button = window.findChild(QObject, "modelDetailOpenTheoryButton")
    modal = window.findChild(QObject, "modelDetailTheoryModal")
    panel = window.findChild(QObject, "modelDetailTheoryPanel")

    assert all(item is not None for item in (
        diagram, summary, open_button, modal, panel
    ))

    _invoke_qml(diagram, "selectComponent", "input_embedding")
    qapp.processEvents()
    preview = summary.property("concepto")
    preview = preview.toVariant() if isinstance(preview, QJSValue) else preview
    assert summary.property("visible") is True
    assert modal.property("visible") is False
    assert preview["id"] == "embeddings"

    _invoke_qml(summary, "requestOpen")
    qapp.processEvents()
    assert modal.property("visible") is True
    assert panel.property("visible") is True

    _invoke_qml(modal, "close")
    qapp.processEvents()
    assert modal.property("visible") is False
    assert summary.property("visible") is True

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()
