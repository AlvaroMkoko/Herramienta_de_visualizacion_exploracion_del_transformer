"""Contrato visual de los ocho laboratorios especializados.

La mayor parte de estas pruebas se mantiene en la frontera publica del
componente: comprueba que el despachador carga exactamente una especializacion
por modulo y que el modo de entrenamiento activa su evidencia propia. Tambien
incluye una regresion geometrica puntual para impedir que la grafica de capas
vuelva a quedar sin ancho o fuera de su viewport.
"""

from __future__ import annotations

import os
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

import pytest
from PySide6.QtCore import QObject, QPointF, QRectF, QSizeF, QUrl
from PySide6.QtQml import QQmlComponent, QQmlEngine
from PySide6.QtQuick import QQuickItem

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from viewmodel.main_viewmodel import MainViewModel


ROOT = Path(__file__).resolve().parents[2]

HOST = b"""\
import QtQuick
import QtQuick.Controls
import "components" as Components

ApplicationWindow {
    width: 1100
    height: 760
    visible: false

    Components.ModuleLaboratoryVisualization {
        id: visualization
        objectName: "specializedLaboratoryUnderTest"
        anchors.fill: parent
        moduleId: "module_1"
        mode: "inference"
        analysis: ({})
        step: ({
            title: "Paso de prueba",
            formula: "entrada -> operacion -> salida",
            explanation: "Explicacion pedagogica de la operacion.",
            input: "entrada",
            output: "salida",
            visual: "tokenization"
        })
    }
}
"""

SPECIALIZATIONS = {
    "module_1": ("tokenization", "moduleLabTokenizationView"),
    "module_2": ("embedding", "moduleLabEmbeddingView"),
    "module_3": ("attention", "moduleLabAttentionView"),
    "module_4": ("multi_head", "moduleLabMultiHeadView"),
    "module_5": ("encoder", "moduleLabEncoderView"),
    "module_6": ("decoder", "moduleLabDecoderView"),
    "module_7": ("output", "moduleLabOutputView"),
    "module_8": ("transformer", "moduleLabTransformerView"),
}

SCREEN_HOST = b"""\
import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {
    width: 1600
    height: 900
    visible: true
    StackView { id: navigation; anchors.fill: parent }
    Screens.ModuleLaboratoryScreen {
        anchors.fill: parent
        stackView: navigation
        moduleId: "module_3"
    }
}
"""

LAYER_SKYSCRAPER_HOST = b"""\
import QtQuick
import QtQuick.Controls
import "components" as Components

ApplicationWindow {
    width: 1100
    height: 460
    visible: false

    Components.LayerSkyscraperScene {
        objectName: "layerSkyscraperUnderTest"
        anchors.fill: parent
        tokens: [
            { posicion: 0, texto: "uno" },
            { posicion: 1, texto: "dos" },
            { posicion: 2, texto: "tres" }
        ]
        trajectory: ({
            inicio_posicion: 0,
            varianza_conservada: 0.91,
            capas: [
                { capa: 0, puntos: [{ x: -1, y: 0 }, { x: 0, y: 1 }, { x: 1, y: 0 }] },
                { capa: 1, puntos: [{ x: -0.7, y: 0.2 }, { x: 0.2, y: 0.8 }, { x: 0.9, y: -0.2 }] },
                { capa: 2, puntos: [{ x: -0.4, y: 0.5 }, { x: 0.4, y: 0.4 }, { x: 0.7, y: -0.5 }] }
            ]
        })
    }
}
"""


class _ScreenTokenizer:
    vocab_size = 36

    def encode(self, _text):
        return [3, 7, 9, 11]

    def decode(self, ids):
        return f"t{ids[0]}"


def _errors(component: QQmlComponent) -> str:
    return "\n".join(error.toString() for error in component.errors())


@pytest.fixture
def specialized_visual(qapp):
    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(
        HOST,
        QUrl.fromLocalFile(
            str(ROOT / "view" / "qml" / "ModuleLaboratoryVisualizationHost.qml")
        ),
    )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    qapp.processEvents()

    visual = window.findChild(QObject, "specializedLaboratoryUnderTest")
    loader = window.findChild(QObject, "moduleLabSpecializedLoader")
    summary = window.findChild(QObject, "moduleLabStepSummary")
    evidence = window.findChild(QObject, "moduleLabTrainingEvidence")
    assert visual is not None
    assert loader is not None
    assert summary is not None
    assert evidence is not None

    yield window, visual, loader, evidence

    window.deleteLater()
    engine.deleteLater()


@pytest.mark.parametrize(
    ("module_id", "kind", "child_name"),
    [
        (module_id, kind, child_name)
        for module_id, (kind, child_name) in SPECIALIZATIONS.items()
    ],
)
def test_cada_modulo_carga_su_visualizacion_especializada(
    qapp, specialized_visual, module_id, kind, child_name
):
    _window, visual, loader, _evidence = specialized_visual

    visual.setProperty("moduleId", module_id)
    qapp.processEvents()

    assert visual.property("specializationKind") == kind
    loaded_item = loader.property("item")
    assert loaded_item is not None
    assert loaded_item.objectName() == child_name


@pytest.mark.parametrize("mode", ["training", "inference"])
def test_visualizacion_diferencia_ambos_modos(qapp, specialized_visual, mode):
    _window, visual, _loader, evidence = specialized_visual

    visual.setProperty("mode", mode)
    visual.setProperty("selectedLayer", 1)
    visual.setProperty("selectedHead", 2)
    visual.setProperty("selectedToken", 1)
    qapp.processEvents()

    assert visual.property("trainingMode") is (mode == "training")
    assert evidence.property("visible") is (mode == "training")
    assert visual.property("selectedLayer") == 1
    assert visual.property("selectedHead") == 2
    assert visual.property("selectedToken") == 1


def _rect_in(item: QQuickItem, ancestor: QQuickItem) -> QRectF:
    origin = item.mapToItem(ancestor, QPointF(0, 0))
    return QRectF(origin, QSizeF(item.width(), item.height()))


def _visual_descendants(item: QQuickItem) -> list[QQuickItem]:
    pending = list(item.childItems())
    descendants = []
    while pending:
        child = pending.pop()
        descendants.append(child)
        pending.extend(child.childItems())
    return descendants


def test_rascacielos_reserva_espacio_para_graficas_y_muestra_tres_pisos(qapp):
    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(
        LAYER_SKYSCRAPER_HOST,
        QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "LayerSkyscraperHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    for _ in range(5):
        qapp.processEvents()

    scene = window.findChild(QQuickItem, "layerSkyscraperUnderTest")
    assert scene is not None
    descendants = _visual_descendants(scene)
    floor_cards = sorted(
        (
            item
            for item in descendants
            if item.objectName().startswith("layerFloorCard_")
        ),
        key=lambda item: _rect_in(item, scene).top(),
    )
    scatter_panels = [
        item
        for item in descendants
        if item.objectName().startswith("layerScatterPanel_")
    ]
    scatter_canvases = [
        item
        for item in descendants
        if item.objectName().startswith("layerScatterCanvas_")
    ]
    detail_panels = [
        item
        for item in descendants
        if item.objectName().startswith("layerFloorDetail_")
    ]

    assert (
        len(floor_cards)
        == len(scatter_panels)
        == len(scatter_canvases)
        == len(detail_panels)
        == 3
    )
    assert floor_cards[-1].mapToItem(scene, QPointF(0, floor_cards[-1].height())).y() \
        <= scene.height() + 1
    assert all(
        _rect_in(first, scene).bottom() <= _rect_in(second, scene).top() + 1
        for first, second in zip(floor_cards, floor_cards[1:])
    )
    # El texto lateral debe conservar un ancho estable sin consumir la zona
    # central: antes de esta restriccion las tres graficas quedaban en 0 px.
    assert all(panel.width() >= 300 for panel in scatter_panels)
    assert all(scatter.width() > detail.width() for scatter, detail in zip(
        sorted(scatter_panels, key=lambda item: item.objectName()),
        sorted(detail_panels, key=lambda item: item.objectName()),
    ))

    scene.setProperty("selectedToken", 2)
    qapp.processEvents()
    assert all(canvas.property("highlightedToken") == 2 for canvas in scatter_canvases)

    window.deleteLater()
    engine.deleteLater()


def test_pantalla_especializada_reordena_paneles_sin_encimarlos(qapp):
    view_model = MainViewModel()
    config = ConfiguracionTransformer(
        tamano_vocabulario=40,
        dimension_modelo=16,
        num_cabezas=4,
        num_capas=2,
        dimension_ff=32,
        longitud_maxima_secuencia=12,
        dropout=0.0,
        id_token_relleno=36,
    )
    model = Transformer(config)
    view_model.moduleLaboratoryController.set_model(model, _ScreenTokenizer())
    view_model._modelo_actual_info = {
        "num_capas": 2,
        "num_cabezas": 4,
        "dimension_modelo": 16,
    }
    view_model.moduleLaboratoryController.explore(
        "module_3", "texto", "inference", 1, 2, 1, 0.8, 5, 0.9, True
    )

    engine = QQmlEngine()
    engine.rootContext().setContextProperty("mainViewModel", view_model)
    component = QQmlComponent(engine)
    component.setData(
        SCREEN_HOST,
        QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "ModuleLabScreenHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    for _ in range(4):
        qapp.processEvents()

    screen = window.findChild(QObject, "moduleLaboratoryScreen")
    workspace = window.findChild(QQuickItem, "moduleLaboratoryWorkspace")
    step_pane = window.findChild(QQuickItem, "moduleLaboratoryStepPane")
    visual_pane = window.findChild(QQuickItem, "moduleLaboratoryVisualPane")
    evidence_pane = window.findChild(QQuickItem, "moduleLaboratoryEvidencePane")
    visualization = window.findChild(QObject, "moduleLaboratoryVisualization")
    assert all(
        item is not None
        for item in (
            screen,
            workspace,
            step_pane,
            visual_pane,
            evidence_pane,
            visualization,
        )
    )
    assert visualization.property("specializationKind") == "attention"

    wide = [
        _rect_in(item, workspace) for item in (step_pane, visual_pane, evidence_pane)
    ]
    assert screen.property("compactLayout") is False, (
        screen.property("width"),
        window.width(),
        workspace.width(),
        wide,
    )
    assert wide[0].right() <= wide[1].left() + 1
    assert wide[1].right() <= wide[2].left() + 1

    # A 1280 px, las barras laterales dejaban menos de 840 px al centro.
    # La pantalla debe apilar aquí, no esperar hasta 1120 px.
    window.setProperty("width", 1280)
    window.setProperty("height", 820)
    for _ in range(5):
        qapp.processEvents()
    assert screen.property("compactLayout") is True
    medium = [
        _rect_in(item, workspace) for item in (step_pane, visual_pane, evidence_pane)
    ]
    assert medium[0].bottom() <= medium[1].top() + 1
    assert medium[1].bottom() <= medium[2].top() + 1

    window.setProperty("width", 900)
    window.setProperty("height", 900)
    for _ in range(5):
        qapp.processEvents()
    assert screen.property("compactLayout") is True
    compact = [
        _rect_in(item, workspace) for item in (step_pane, visual_pane, evidence_pane)
    ]
    assert compact[0].bottom() <= compact[1].top() + 1
    assert compact[1].bottom() <= compact[2].top() + 1
    assert all(
        rect.left() >= -1 and rect.right() <= workspace.width() + 1 for rect in compact
    )
    # Las escenas de atención y del Transformer completo necesitan espacio
    # vertical adicional cuando los tres paneles se apilan. Una altura menor
    # vuelve a superponer matrices, la tira de tensores y la evidencia.
    assert compact[1].height() >= 680
    specialized_loader = window.findChild(QQuickItem, "moduleLabSpecializedLoader")
    assert specialized_loader is not None
    assert specialized_loader.property("clip") is True
    assert specialized_loader.height() >= 350

    window.deleteLater()
    engine.deleteLater()
