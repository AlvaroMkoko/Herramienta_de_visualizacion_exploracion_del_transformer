"""Pruebas QML del flujo guiado para crear datasets desde la interfaz."""

from __future__ import annotations

import json
import os
from pathlib import Path

# Deben fijarse antes de que pytest-qt construya QApplication.
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

import pytest
from PySide6.QtCore import QMetaObject, QObject, Qt, QUrl
from PySide6.QtQml import QQmlComponent, QQmlEngine, qmlRegisterType

from view.canvas.animation_engine import VispyItem
from viewmodel.dataset_controller import DatasetController
from viewmodel.main_viewmodel import MainViewModel


PROJECT_ROOT = Path(__file__).resolve().parents[2]
QML_ROOT = PROJECT_ROOT / "view" / "qml"

# LoadDataSetScreen y DataSetScreen importan el módulo aunque no construyan un
# lienzo en este flujo. La aplicación registra el mismo tipo desde main.py.
qmlRegisterType(VispyItem, "Vispy", 1, 0, "VispyItem")


def _errors(component: QQmlComponent) -> str:
    return "\n".join(error.toString() for error in component.errors())


def _find(root: QObject, object_name: str) -> QObject:
    found = root.findChild(QObject, object_name)
    assert found is not None, f"Falta el hook QML objectName={object_name!r}"
    return found


def _click(control: QObject) -> None:
    invoked = QMetaObject.invokeMethod(
        control, "clicked", Qt.ConnectionType.DirectConnection
    )
    assert invoked, f"No se pudo activar {control.objectName()}"


def _create_host(
    screen_name: str,
    catalog_path: Path,
    monkeypatch,
    qapp,
    qtbot,
):
    monkeypatch.setattr(DatasetController, "DATASET_FILE", catalog_path)
    view_model = MainViewModel()
    engine = QQmlEngine()
    engine.rootContext().setContextProperty("mainViewModel", view_model)

    source = f"""
import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {{
    objectName: "datasetCreationHost"
    width: 1440
    height: 900
    visible: false

    StackView {{
        id: navigation
        anchors.fill: parent
    }}

    Screens.{screen_name} {{
        objectName: "datasetScreenUnderTest"
        anchors.fill: parent
        stackView: navigation
    }}
}}
""".encode()

    component = QQmlComponent(engine)
    component.setData(
        source,
        QUrl.fromLocalFile(str(QML_ROOT / "DatasetCreationHost.qml")),
    )
    if component.status() == QQmlComponent.Status.Loading:
        qtbot.waitUntil(
            lambda: component.status() != QQmlComponent.Status.Loading,
            timeout=5000,
        )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)

    window = component.create()
    assert window is not None, _errors(component)
    window.show()
    qapp.processEvents()
    return engine, component, window, view_model


def _destroy_host(engine, component, window, view_model, qapp) -> None:
    view_model.cerrar()
    window.close()
    window.deleteLater()
    component.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


@pytest.mark.parametrize("screen_name", ["LoadDataSetScreen", "DataSetScreen"])
def test_pantallas_exponen_creador_y_guia_de_formato(
    screen_name, tmp_path, monkeypatch, qapp, qtbot
):
    catalog_path = tmp_path / screen_name / "dataSets.json"
    engine, component, window, view_model = _create_host(
        screen_name, catalog_path, monkeypatch, qapp, qtbot
    )

    try:
        for object_name in (
            "datasetRequirementsButton",
            "datasetImportButton",
            "datasetCreateButton",
            "datasetRequirementsDialog",
            "datasetRequirementsCloseButton",
            "datasetRequirementsUnderstoodButton",
            "datasetCreatorDialog",
            "datasetCreatorNameField",
            "datasetInstructionField",
            "datasetContextField",
            "datasetResponseField",
            "datasetCategoryField",
            "datasetAddExampleButton",
            "datasetExampleCountLabel",
            "datasetCreateConfirmButton",
            "datasetCreatorCancelButton",
            "datasetCreatorErrorLabel",
        ):
            _find(window, object_name)

        guide = _find(window, "datasetRequirementsDialog")
        assert guide.property("visible") is False
        _click(_find(window, "datasetRequirementsButton"))
        qtbot.waitUntil(lambda: guide.property("visible") is True, timeout=2000)
        _click(_find(window, "datasetRequirementsUnderstoodButton"))
        qtbot.waitUntil(lambda: guide.property("visible") is False, timeout=2000)
    finally:
        _destroy_host(engine, component, window, view_model, qapp)


def test_creador_valida_y_agrega_jsonl_a_la_biblioteca(
    tmp_path, monkeypatch, qapp, qtbot
):
    catalog_path = tmp_path / "catalogo" / "dataSets.json"
    engine, component, window, view_model = _create_host(
        "LoadDataSetScreen", catalog_path, monkeypatch, qapp, qtbot
    )

    try:
        screen = _find(window, "datasetScreenUnderTest")
        creator = _find(window, "datasetCreatorDialog")
        assert screen.property("datasetCount") == 0

        _click(_find(window, "datasetCreateButton"))
        qtbot.waitUntil(lambda: creator.property("visible") is True, timeout=2000)

        add_button = _find(window, "datasetAddExampleButton")
        _click(add_button)
        assert "instruction" in creator.property("validationMessage")
        assert creator.property("exampleCount") == 0

        name_field = _find(window, "datasetCreatorNameField")
        instruction_field = _find(window, "datasetInstructionField")
        context_field = _find(window, "datasetContextField")
        response_field = _find(window, "datasetResponseField")
        category_field = _find(window, "datasetCategoryField")

        assert name_field.setProperty("text", "Preguntas de astronomía")
        assert instruction_field.setProperty("text", "¿Qué orbita la Tierra?")
        _click(add_button)
        assert "response" in creator.property("validationMessage")
        assert creator.property("exampleCount") == 0

        assert context_field.setProperty(
            "text", "La Tierra forma parte del sistema solar."
        )
        assert response_field.setProperty("text", "La Tierra orbita el Sol.")
        assert category_field.setProperty("text", "ciencia")
        _click(add_button)
        qapp.processEvents()

        assert creator.property("validationMessage") == ""
        assert creator.property("exampleCount") == 1
        assert _find(window, "datasetCreateConfirmButton").property("enabled") is True

        _click(_find(window, "datasetCreateConfirmButton"))
        qtbot.waitUntil(lambda: creator.property("visible") is False, timeout=2000)
        qtbot.waitUntil(lambda: screen.property("datasetCount") == 1, timeout=2000)

        created_files = list((catalog_path.parent / "creados").glob("*.jsonl"))
        assert len(created_files) == 1
        lines = created_files[0].read_text(encoding="utf8").splitlines()
        assert len(lines) == 1
        assert json.loads(lines[0]) == {
            "instruction": "¿Qué orbita la Tierra?",
            "context": "La Tierra forma parte del sistema solar.",
            "response": "La Tierra orbita el Sol.",
            "category": "ciencia",
        }

        catalog = json.loads(catalog_path.read_text(encoding="utf8"))
        assert len(catalog) == 1
        assert catalog[0]["nombre"] == "Preguntas de astronomía"
        assert Path(catalog[0]["ruta"]) == created_files[0].resolve()
        assert catalog[0]["registros"] == 1
        assert catalog[0]["pares_validos"] == 1
        assert catalog[0]["compatible_entrenamiento"] is True
        assert catalog[0]["creado_por_app"] is True
    finally:
        _destroy_host(engine, component, window, view_model, qapp)
