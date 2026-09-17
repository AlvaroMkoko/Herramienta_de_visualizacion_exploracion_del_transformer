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
from PySide6.QtQuick import QQuickItem

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

    if screen_name == "InferenceScreen":
        progress = window.findChild(QObject, "inferenceLaboratoryProgress")
        assert progress is not None
        assert progress.property("currentStep") == 2
        assert progress.property("currentStepTitle") == "Inferencia"
    elif screen_name == "ComparisonScreen":
        title = window.findChild(QObject, "comparisonScreenTitle")
        assert title is not None
        assert title.property("text") == "Comparación de modelos"

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


def test_lector_destaca_formula_y_separa_su_explicacion(qapp):
    engine = QQmlEngine()
    source = b"""
import QtQuick
import QtQuick.Controls
import "components" as Components

ApplicationWindow {
    width: 1000
    height: 740
    visible: false
    Components.ContextPanel {
        anchors.fill: parent
        expanded: true
        closable: false
        concepto: ({
            "title": "Prueba de formula",
            "short_description": "Una formula con lectura pedagogica.",
            "explanation": "La explicacion principal presenta el concepto.",
            "formula": "y = gamma * x + beta",
            "mathematical": "gamma escala y beta desplaza cada coordenada.",
            "steps": ["Calcular x", "Aplicar gamma", "Sumar beta"]
        })
    }
}
"""
    component = QQmlComponent(engine)
    component.setData(
        source,
        QUrl.fromLocalFile(str(QML_ROOT / "ContextPanelFormulaHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    qapp.processEvents()

    formula = window.findChild(QObject, "theoryFormulaText")
    mathematical = window.findChild(QObject, "theoryMathematicalExplanation")
    assert formula is not None and formula.property("visible") is True
    assert mathematical is not None and mathematical.property("visible") is True
    assert formula.property("text") == "y = gamma * x + beta"
    assert mathematical.property("text").startswith("gamma escala")
    assert formula.property("font").pixelSize() >= 20
    assert formula.property("font").bold() is True

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


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


def test_biblioteca_muestra_las_metricas_junto_a_su_ayuda(qapp, monkeypatch):
    """Evita que el cálculo del layout colapse las etiquetas a ancho cero."""
    engine = QQmlEngine()
    view_model = MainViewModel()
    descriptor = {
        "nombre": "modelo_prueba",
        "ruta": "C:/modelos/modelo_prueba.tvismodel",
        "formato": "tvismodel",
        "compatible": True,
        "encoder_layers": 1,
        "decoder_layers": 1,
        "num_cabezas": 4,
        "dimension_modelo": 32,
        "dimension_ff": 64,
        "longitud_maxima_secuencia": 128,
        "tamano_vocabulario": 100_000,
        "parametros_totales": 6_560_000,
        "tamano": "25.1 MiB",
        "encoding": "cl100k_base",
        "epoca": 0,
        "paso_global": 142,
        "perdida_final": 9.4045,
        "usar_mascara_causal": True,
    }
    controller = view_model.modelLibraryController
    monkeypatch.setattr(controller, "_construir_catalogo", lambda: [descriptor])
    engine.rootContext().setContextProperty("mainViewModel", view_model)
    source = b"""
import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {
    width: 960
    height: 640
    visible: true
    StackView { id: navigation; anchors.fill: parent }
    Screens.ModelLibraryScreen {
        anchors.fill: parent
        stackView: navigation
    }
}
"""
    component = QQmlComponent(engine)
    component.setData(
        source,
        QUrl.fromLocalFile(str(QML_ROOT / "ModelLibraryLayoutHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)

    window = component.create()
    assert window is not None, _errors(component)
    qapp.processEvents()

    screen = window.findChild(QObject, "modelLibraryScreen")
    model_list = window.findChild(QQuickItem, "modelLibraryModelList")
    assert screen is not None
    assert model_list is not None
    visible_models = screen.property("modelosVisibles")
    visible_models = (
        visible_models.toVariant()
        if isinstance(visible_models, QJSValue)
        else visible_models
    )
    assert len(visible_models) == 1
    _invoke_qml(model_list, "forceLayout")
    qapp.processEvents()

    def visual_descendants(item):
        for child in item.childItems():
            yield child
            yield from visual_descendants(child)

    visual_items = list(visual_descendants(model_list.property("contentItem")))

    expected_metrics = {
        "modelLibraryArchitectureMetric": 3,
        "modelLibraryDimensionMetric": 4,
        "modelLibraryStorageMetric": 3,
        "modelLibraryTrainingMetric": 3,
        "modelLibraryMaskMetric": 1,
    }
    adjacent_help_count = 0
    for object_name, expected_count in expected_metrics.items():
        labels = [
            item for item in visual_items if item.objectName() == object_name
        ]
        assert len(labels) == expected_count
        for label in labels:
            assert str(label.property("text")).strip()
            assert float(label.property("width")) > 0

            visible_help = [
                child
                for child in label.parentItem().childItems()
                if str(child.objectName()).startswith("conceptHelp_")
                and bool(child.property("visible"))
            ]
            if not visible_help:
                continue
            assert len(visible_help) == 1
            help_button = visible_help[0]
            gap = float(help_button.property("x")) - (
                float(label.property("x")) + float(label.property("width"))
            )
            assert -0.5 <= gap <= 8
            adjacent_help_count += 1

    # Todas las métricas salvo "Tamaño" tienen ayuda contextual.
    assert adjacent_help_count == 13

    # La biblioteca se prueba en una ventana de 960x640, donde el escalado
    # anterior reducía varias etiquetas a 6-8 px. Los mínimos mantienen
    # legibles tanto la identidad del modelo como sus datos de comparación.
    minimum_font_sizes = {
        "modelLibraryModelName": 18,
        "modelLibraryFormatBadge": 11,
        "modelLibraryModelPath": 12,
        "modelLibraryArchitectureMetric": 14,
        "modelLibraryDimensionMetric": 13,
        "modelLibraryStorageMetric": 13,
        "modelLibraryTrainingMetric": 13,
        "modelLibraryMaskMetric": 12,
        "modelLibraryCapabilityBadge": 11,
    }
    for object_name, minimum_size in minimum_font_sizes.items():
        labels = [
            item for item in visual_items if item.objectName() == object_name
        ]
        assert labels, object_name
        for label in labels:
            assert label.property("font").pixelSize() >= minimum_size

    inference_button = next(
        item
        for item in visual_items
        if item.objectName() == "modelLibraryInferenceButton"
    )
    assert inference_button.property("contentItem").property("font").pixelSize() >= 12

    window.close()
    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()
