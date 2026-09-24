"""Smoke tests del explorador visual de la inferencia."""

from __future__ import annotations

import os
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import QObject, QPointF, QUrl
from PySide6.QtGui import QColor
from PySide6.QtQml import QJSValue, QQmlComponent, QQmlEngine
from PySide6.QtQuick import QQuickItem
from PySide6.QtTest import QTest
import torch

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from viewmodel.theory_controller import TheoryController
from viewmodel.visual_adapter import resumir_paso_inferencia


RAIZ_PROYECTO = Path(__file__).resolve().parents[2]
HOST = b"""\
import QtQuick
import QtQuick.Controls
import "components" as Components
import "styles" as Style

ApplicationWindow {
    width: 1920
    height: 1080
    visible: false
    property bool requestedDarkMode: false
    onRequestedDarkModeChanged: Style.Theme.modoOscuro = requestedDarkMode
    Component.onCompleted: Style.Theme.modoOscuro = requestedDarkMode

    Components.InferenceExplorationPanel {
        anchors.fill: parent
        snapshots: []
        detailForward: ({})
        sx: 1
        sy: 1
    }
}
"""


def _errores(component: QQmlComponent) -> str:
    return "\n".join(error.toString() for error in component.errors())


def _como_python(valor):
    return valor.toVariant() if isinstance(valor, QJSValue) else valor


def _luminancia_relativa(color: QColor) -> float:
    def lineal(channel: float) -> float:
        return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4

    return (
        0.2126 * lineal(color.redF())
        + 0.7152 * lineal(color.greenF())
        + 0.0722 * lineal(color.blueF())
    )


def _contraste(first: QColor, second: QColor) -> float:
    lighter, darker = sorted(
        (_luminancia_relativa(first), _luminancia_relativa(second)), reverse=True
    )
    return (lighter + 0.05) / (darker + 0.05)


class _TokenizerVisual:
    def decode(self, tokens):
        return f"tok{int(tokens[0])}"


def _crear_panel(engine: QQmlEngine, qapp):
    component = QQmlComponent(engine)
    component.setData(
        HOST,
        QUrl.fromLocalFile(
            str(RAIZ_PROYECTO / "view" / "qml" / "InferenceExplorerHost.qml")
        ),
    )
    assert component.status() != QQmlComponent.Status.Error, _errores(component)
    window = component.create()
    assert window is not None, _errores(component)
    qapp.processEvents()
    return component, window, window.findChild(QObject, "inferenceExplorationPanel")


def _assert_item_dentro_del_panel(panel, item, margen=0.5):
    assert isinstance(panel, QQuickItem)
    assert isinstance(item, QQuickItem)
    posicion = item.mapToItem(panel, QPointF(0, 0))
    assert posicion.x() >= -margen
    assert posicion.y() >= -margen
    assert posicion.x() + item.width() <= panel.width() + margen
    assert posicion.y() + item.height() <= panel.height() + margen


def test_explorador_respeta_limites_del_modal_en_resolucion_base(qapp):
    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)
    window.setProperty("width", 1230)
    window.setProperty("height", 772)
    # Q/K/V activa tambien la fila opcional de ajustes, el caso vertical
    # mas exigente del recorrido principal.
    panel.setProperty("operationIndex", 2)
    # El boton de siguiente token completa tambien el caso horizontal mas
    # exigente de la cabecera.
    panel.setProperty("canGenerateNext", True)
    window.setProperty("visible", True)
    QTest.qWait(50)
    qapp.processEvents()

    animation = window.findChild(QQuickItem, "inferenceAnimationViewport")
    guide = window.findChild(QQuickItem, "inferencePedagogicalGuide")
    for object_name in (
        "inferenceProcessMap",
        "inferenceNextTokenButton",
        "inferenceAnimationViewport",
        "inferenceReducedMotionToggle",
        "inferenceGuideToggle",
        "inferenceCloseButton",
        "inferencePreviousOperationButton",
        "inferencePlaySequenceButton",
        "inferenceOperationSelector",
        "inferenceNextOperationButton",
    ):
        item = window.findChild(QQuickItem, object_name)
        assert item is not None, object_name
        _assert_item_dentro_del_panel(panel, item)

    assert guide is not None and guide.property("visible") is False
    assert animation.width() >= panel.width() * 0.90

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_explorador_reorganiza_apoyos_en_viewports_compactos(qapp):
    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)
    window.setProperty("visible", True)

    for width, height in ((1024, 640), (760, 520), (640, 480)):
        window.setProperty("width", width)
        window.setProperty("height", height)
        QTest.qWait(30)
        qapp.processEvents()

        animation = window.findChild(QQuickItem, "inferenceAnimationViewport")
        process_map = window.findChild(QQuickItem, "inferenceProcessMap")
        token_ribbon = window.findChild(QQuickItem, "inferenceTokenRibbon")
        close_button = window.findChild(QQuickItem, "inferenceCloseButton")
        previous_button = window.findChild(
            QQuickItem, "inferencePreviousOperationButton"
        )
        next_button = window.findChild(QQuickItem, "inferenceNextOperationButton")

        assert animation.property("visible") is True
        assert animation.width() >= 500
        assert animation.height() >= 220
        assert 0.68 <= float(panel.property("sceneSx")) <= 1.0
        assert 0.60 <= float(panel.property("sceneSy")) <= 1.0
        for item in (
            animation,
            process_map,
            token_ribbon,
            close_button,
            previous_button,
            next_button,
        ):
            assert item is not None and item.property("visible") is True
            _assert_item_dentro_del_panel(panel, item)
        assert panel.property("tokenRibbonFits") is True

    # En ancho estrecho la ayuda no compite con la transformacion: se abre
    # como vista alterna y permite volver a la animacion con el mismo control.
    guide = window.findChild(QQuickItem, "inferencePedagogicalGuide")
    toggle = window.findChild(QObject, "inferenceGuideToggle")
    assert panel.property("compactWidth") is True
    assert guide.property("visible") is False
    toggle.clicked.emit()
    QTest.qWait(30)
    qapp.processEvents()
    assert animation.property("visible") is False
    assert guide.property("visible") is True
    _assert_item_dentro_del_panel(panel, guide)

    panel.setProperty("locationMapVisible", True)
    QTest.qWait(30)
    qapp.processEvents()
    compact_minimap = window.findChild(QQuickItem, "inferenceTransformerMiniMap")
    assert compact_minimap is not None and compact_minimap.property("visible") is True
    assert compact_minimap.height() >= 175
    assert compact_minimap.property("contentFits") is True
    _assert_item_dentro_del_panel(guide, compact_minimap)

    toggle.clicked.emit()
    QTest.qWait(30)
    qapp.processEvents()
    assert animation.property("visible") is True
    assert guide.property("visible") is False
    assert panel.property("guideVisible") is False

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_multihead_compacto_mantiene_la_transformacion_completa(qapp):
    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)
    window.setProperty("width", 760)
    window.setProperty("height", 520)
    panel.setProperty("operationIndex", 6)
    window.setProperty("visible", True)
    QTest.qWait(50)
    qapp.processEvents()

    scene = window.findChild(QQuickItem, "multiHeadSplitScene")
    projection = window.findChild(QQuickItem, "multiHeadProjection")
    cards = window.findChild(QQuickItem, "multiHeadCards")
    merge = window.findChild(QQuickItem, "multiHeadMerge")
    assert scene is not None and scene.property("compact") is True
    for item in (projection, cards, merge):
        assert item is not None
        assert item.width() > 0 and item.height() > 0
        _assert_item_dentro_del_panel(scene, item)

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_layernorm_no_saca_texto_de_las_tarjetas_de_fase(qapp):
    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)
    window.setProperty("width", 760)
    window.setProperty("height", 520)
    panel.setProperty("operationIndex", 7)
    window.setProperty("visible", True)
    QTest.qWait(30)
    qapp.processEvents()

    scene = window.findChild(QQuickItem, "residualLayerNormScene")
    phases = [
        {
            "nombre": name,
            "valores": [-1.0, -0.4, 0.2, 0.8, 1.1],
            "media": mean,
            "desviacion": deviation,
            "operacion": operation,
        }
        for name, mean, deviation, operation in (
            ("x + Δx", 0.52, 0.79, "Distribución antes de LayerNorm"),
            ("Restar μ", 0.0, 0.79, "x − media(x)"),
            ("Dividir por σ", 0.0, 1.0, "(x − μ) / √(var + ε)"),
            ("Aplicar γ y β", -0.01, 1.01, "γ · x̂ + β"),
        )
    ]
    residual_data = {
            "norma_entrada": 5.63,
            "norma_actualizacion": 5.31,
            "ratio_actualizacion": 0.94,
            "epsilon": 0.00001,
            "layernorm": {
                "fases": phases,
                "gamma_media": 1.0,
                "beta_media": 0.0,
            },
        }
    panel.setProperty("snapshots", [{"token_elegido": {"texto": "tok"}}])
    panel.setProperty("selectedIndex", 0)
    panel.setProperty(
        "detailForward",
        {
            "metadata": {"num_layers": 1, "num_heads": 1},
            "global": {},
            "encoder": [{"residual_atencion": residual_data}],
            "decoder": [],
        },
    )
    QTest.qWait(30)
    qapp.processEvents()

    phase_row = window.findChild(QQuickItem, "layerNormPhaseCards")
    explanation = window.findChild(
        QQuickItem, "layerNormSelectedPhaseExplanation"
    )
    assert scene is not None and phase_row is not None and explanation is not None
    _assert_item_dentro_del_panel(scene, phase_row)
    _assert_item_dentro_del_panel(scene, explanation)
    phase_position = phase_row.mapToItem(scene, QPointF(0, 0))
    explanation_position = explanation.mapToItem(scene, QPointF(0, 0))
    assert phase_position.y() + phase_row.height() <= explanation_position.y() + 0.5
    assert scene.property("phaseCardCount") == 4
    assert scene.property("phaseLayoutFits") is True

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_ffn_compacta_conserva_entrada_activacion_y_salida(qapp):
    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)
    window.setProperty("width", 640)
    window.setProperty("height", 480)
    panel.setProperty("operationIndex", 8)
    window.setProperty("visible", True)
    QTest.qWait(30)
    qapp.processEvents()

    scene = window.findChild(QQuickItem, "feedForwardExpansionScene")
    token_rows = []
    for position in range(3):
        token_rows.append(
            {
                "posicion": position,
                "dimension_entrada": 32,
                "dimension_oculta": 64,
                "dimension_salida": 32,
                "entrada": [0.1, -0.2, 0.4, -0.1],
                "preactivacion": [0.2, -0.4, 0.8, -0.2],
                "salida": [0.3, -0.1, 0.6, 0.2],
                "norma_entrada": 1.2,
                "norma_preactivacion": 2.4,
                "norma_salida": 1.7,
                "fraccion_negativa": 0.5,
                "fraccion_casi_cero": 0.1,
            }
        )
    panel.setProperty("snapshots", [{"token_elegido": {"texto": "tok"}}])
    panel.setProperty("selectedIndex", 0)
    panel.setProperty(
        "detailForward",
        {
            "metadata": {"num_layers": 1, "num_heads": 1},
            "global": {},
            "encoder": [
                {"ffn": {"activacion": "GELU", "tokens": token_rows}}
            ],
            "decoder": [],
        },
    )
    QTest.qWait(30)
    qapp.processEvents()

    assert scene is not None and scene.property("compact") is True
    assert scene.property("renderedTokenCount") == 3
    assert float(scene.property("compactContentWidth")) <= scene.width()

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_logits_mantiene_histograma_y_candidatos_en_el_area_visible(qapp):
    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)
    window.setProperty("width", 1230)
    window.setProperty("height", 772)
    panel.setProperty("operationIndex", 29)
    panel.setProperty("reducedMotion", True)
    window.setProperty("visible", True)
    QTest.qWait(50)
    qapp.processEvents()

    scene = window.findChild(QQuickItem, "outputProjectionScene")
    distribution = window.findChild(QQuickItem, "outputDistributionColumn")
    candidates = window.findChild(QQuickItem, "outputCandidatePanel")
    histogram = window.findChild(QQuickItem, "outputLogitsHistogram")
    dimensions_help = window.findChild(QObject, "outputHiddenDimensionsExplanation")
    histogram_help = window.findChild(QObject, "outputHistogramExplanation")
    candidates_help = window.findChild(QObject, "outputCandidateExplanation")
    reading_guide = window.findChild(QObject, "outputLogitsReadingGuide")
    assert scene is not None
    for item in (distribution, candidates, histogram):
        assert item is not None
        assert item.width() > 0
        assert item.height() > 0
        _assert_item_dentro_del_panel(scene, item)

    distribution_position = distribution.mapToItem(scene, QPointF(0, 0))
    candidates_position = candidates.mapToItem(scene, QPointF(0, 0))
    assert distribution_position.x() + distribution.width() < candidates_position.x()
    assert all(
        item is not None
        for item in (
            dimensions_help,
            histogram_help,
            candidates_help,
            reading_guide,
        )
    )
    assert "no representan tokens" in dimensions_help.property("text")
    assert "cuántos tokens" in histogram_help.property("text")
    assert "token concreto" in candidates_help.property("text")

    scene.setProperty(
        "hiddenData",
        {"matriz": {"valores": [[-1.0, -0.2, 0.2, 1.0]]}},
    )
    qapp.processEvents()
    assert "Softmax" in reading_guide.property("text")
    for value in (-1.0, -0.2, 0.2, 1.0):
        background = QColor(scene.hiddenColor(value))
        foreground = QColor(scene.hiddenTextColor(value))
        assert _contraste(background, foreground) >= 4.5

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_softmax_revela_eleccion_y_conserva_el_token_elegido_visible(qapp):
    predictions = [
        {
            "token_id": token_id,
            "texto": f"tok{token_id}",
            "probabilidad": 0.20 - token_id * 0.01,
            "rango": token_id + 1,
            "elegido": token_id == 10,
        }
        for token_id in range(11)
    ]
    snapshot = {
        "predicciones_top": predictions,
        "token_elegido": {
            "token_id": 10,
            "texto": "tok10",
            "probabilidad": 0.10,
            "rango": 11,
        },
        "tokens_salida": [{"texto": "tok10"}],
        "modo_muestreo": "muestreo",
        "filtros": "Sin filtros",
    }

    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)
    window.setProperty("width", 1230)
    window.setProperty("height", 772)
    panel.setProperty("snapshots", [snapshot])
    panel.setProperty("selectedIndex", 0)
    panel.setProperty("reducedMotion", True)
    panel.setProperty("operationIndex", 30)
    window.setProperty("visible", True)
    QTest.qWait(50)
    qapp.processEvents()

    scene = window.findChild(QQuickItem, "softmaxRaceScene")
    candidates_panel = window.findChild(QQuickItem, "softmaxCandidatesPanel")
    selection_column = window.findChild(QQuickItem, "softmaxSelectionColumn")
    chosen_card = window.findChild(QQuickItem, "softmaxChosenTokenCard")
    return_card = window.findChild(QQuickItem, "softmaxReturnToDecoder")
    assert scene is not None
    assert scene.property("candidateCount") == 10
    assert scene.property("chosenCandidateVisible") is True
    assert scene.property("probabilityReveal") == 1.0
    assert scene.property("selectionReveal") == 1.0
    assert scene.property("returnReveal") == 1.0
    for item in (candidates_panel, selection_column, chosen_card, return_card):
        assert item is not None
        assert item.width() > 0
        assert item.height() > 0
        _assert_item_dentro_del_panel(scene, item)
    candidates_position = candidates_panel.mapToItem(scene, QPointF(0, 0))
    selection_position = selection_column.mapToItem(scene, QPointF(0, 0))
    assert candidates_position.x() + candidates_panel.width() < selection_position.x()
    assert candidates_panel.width() > selection_column.width()

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_explorador_conserva_siete_animaciones_y_agrega_recorrido(qapp):
    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)
    assert panel is not None
    stages = panel.property("stages")
    stages = stages.toVariant() if isinstance(stages, QJSValue) else stages
    assert len(stages) == 7

    flow_steps = _como_python(panel.property("flowSteps"))
    assert len(flow_steps) == 31
    assert flow_steps[0]["id"] == "encoder_embedding"
    assert flow_steps[10]["id"] == "encoder_layers"
    assert flow_steps[11]["id"] == "decoder_embedding"
    assert flow_steps[-2]["id"] == "linear_logits"
    assert flow_steps[-1]["id"] == "output_softmax"
    logits_step = flow_steps[-2]
    logits_terms = {entry["term"] for entry in logits_step["visualElements"]}
    assert "Barra de logit" in logits_terms
    assert "dim 0, dim 1, …" in logits_terms
    assert "Barra de probabilidad" not in logits_terms
    assert "histograma agrupa tokens" in logits_step["visualMeaning"]
    softmax_step = flow_steps[-1]
    softmax_terms = {entry["term"] for entry in softmax_step["visualElements"]}
    assert "Barra relativa" in softmax_terms
    assert "Retorno al decoder" in softmax_terms
    assert "probabilidad real" in softmax_step["visualMeaning"]
    for step in flow_steps:
        for field in (
            "operation",
            "visualMeaning",
            "purpose",
            "nextStep",
            "interactionHelp",
        ):
            assert step[field].strip(), (step["id"], field)
        for field in ("visualElements", "symbolGlossary"):
            assert len(step[field]) >= 4, (step["id"], field)
            for entry in step[field]:
                assert entry["term"].strip(), (step["id"], field, "term")
                assert entry["explanation"].strip(), (
                    step["id"],
                    field,
                    "explanation",
                )

    panel.setProperty("operationIndex", len(flow_steps) - 1)
    qapp.processEvents()
    assert panel.property("stageIndex") == 6

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_todas_las_tarjetas_abren_una_explicacion_completa_y_coherente(qapp):
    engine = QQmlEngine()
    component, window, panel = _crear_panel(engine, qapp)
    assert component is not None and panel is not None
    panel.setProperty("guideVisible", True)
    qapp.processEvents()
    button = window.findChild(QObject, "inferenceFullExplanationButton")
    assert button is not None
    assert button.property("visible") is True
    assert panel.property("detailsExpanded") is False

    theory = TheoryController()
    received_concept_ids = []
    panel.theoryRequested.connect(received_concept_ids.append)
    flow_steps = _como_python(panel.property("flowSteps"))

    for operation_index, operation in enumerate(flow_steps):
        panel.setProperty("operationIndex", operation_index)
        panel.setProperty("sequencePlaying", True)
        qapp.processEvents()

        expected_id = operation["conceptId"]
        assert button.property("targetConceptId") == expected_id
        concept = theory.obtenerConcepto(expected_id)
        assert concept.get("existe") is True, operation["id"]
        for field in (
            "title",
            "short_description",
            "explanation",
            "formula",
            "mathematical",
        ):
            assert str(concept.get(field, "")).strip(), (operation["id"], field)
        assert len(concept.get("steps", [])) >= 4, operation["id"]
        assert len(concept.get("dimensions", {})) >= 2, operation["id"]

        button.clicked.emit()
        qapp.processEvents()
        assert received_concept_ids[-1] == expected_id
        assert panel.property("sequencePlaying") is False

    assert len(received_concept_ids) == len(flow_steps)

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_explorador_prioriza_mapa_y_resumen_con_detalle_bajo_demanda(qapp):
    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)

    process_map = window.findChild(QObject, "inferenceProcessMap")
    essential = window.findChild(QObject, "inferenceEssentialExplanation")
    visual_guide = window.findChild(QObject, "inferenceVisualGuide")
    animation_takeaway = window.findChild(QObject, "inferenceAnimationTakeaway")
    next_step = window.findChild(QObject, "inferenceNextStepText")
    local_context = window.findChild(QObject, "inferenceLocalContext")
    previous_step = window.findChild(QObject, "inferencePreviousStepText")
    current_step = window.findChild(QObject, "inferenceCurrentStepText")
    following_step = window.findChild(QObject, "inferenceFollowingStepText")
    input_output = window.findChild(QObject, "inferenceInputOutputText")
    formula_card = window.findChild(QObject, "inferenceFormulaCard")
    formula = window.findChild(QObject, "inferenceFormulaText")
    formula_explanation = window.findChild(QObject, "inferenceFormulaExplanation")
    purpose = window.findChild(QObject, "inferencePurposeText")
    advanced = window.findChild(QObject, "inferenceAdvancedDetails")
    technical_map = window.findChild(QObject, "inferenceTransformerMiniMap")
    map_toggle = window.findChild(QObject, "inferenceLocationMapToggle")
    pedagogical_scroll = window.findChild(QObject, "inferencePedagogicalScroll")
    reduced_motion = window.findChild(QObject, "inferenceReducedMotionToggle")

    assert process_map is not None
    assert process_map.property("visible") is True
    assert process_map.property("keyboardNavigationEnabled") is True
    chapters = _como_python(panel.property("processChapters"))
    assert [chapter["id"] for chapter in chapters] == [
        "encoder",
        "decoder_causal",
        "cross_attention",
        "output",
    ]

    # La lectura principal conserva el hilo local y la formula relevante.
    assert panel.property("detailsExpanded") is False
    assert advanced is not None and advanced.property("visible") is False
    # Los apoyos redundantes empiezan plegados para priorizar la animacion.
    assert panel.property("guideVisible") is False
    assert panel.property("locationMapVisible") is False
    assert technical_map is not None and technical_map.property("visible") is False
    panel.setProperty("guideVisible", True)
    panel.setProperty("locationMapVisible", True)
    qapp.processEvents()
    assert panel.property("locationMapVisible") is True
    assert technical_map.property("visible") is True
    assert map_toggle is not None and map_toggle.property("visible") is True
    assert map_toggle.property("text") == "Ocultar mapa"
    assert pedagogical_scroll is not None
    assert reduced_motion is not None and reduced_motion.property("visible") is True
    assert panel.property("guidedStepDuration") >= 9000
    assert local_context is not None and local_context.property("visible") is True
    for item in (essential, visual_guide, animation_takeaway, next_step, input_output):
        assert item is not None
        assert str(item.property("text")).strip()
    for item in (previous_step, current_step, following_step):
        assert item is not None
        assert str(item.property("stepText")).strip()
    assert formula_card is not None and formula_card.property("visible") is True
    assert formula is not None and str(formula.property("text")).strip()
    assert formula.property("font").pixelSize() >= 17
    assert formula_explanation is not None
    assert str(formula_explanation.property("text")).startswith("CÓMO LEERLA")
    assert purpose is not None and str(purpose.property("text")).strip()
    assert essential.property("font").pixelSize() >= 13
    assert visual_guide.property("font").pixelSize() >= 13

    # El mapa queda fijo mientras evidencia y matiz se muestran bajo demanda.
    panel.setProperty("detailsExpanded", True)
    qapp.processEvents()
    assert advanced.property("visible") is True
    assert technical_map.property("visible") is True
    for object_name in (
        "inferenceFormulaText",
        "inferencePurposeText",
        "inferenceEvidenceText",
        "inferenceCaveatText",
    ):
        text_item = window.findChild(QObject, object_name)
        assert text_item is not None
        assert str(text_item.property("text")).strip()

    # Ocultarlo libera espacio de lectura sin cerrar la explicación ni el detalle.
    window.setProperty("visible", True)
    QTest.qWait(50)
    scroll_height_with_map = float(pedagogical_scroll.property("height"))
    map_toggle.clicked.emit()
    QTest.qWait(50)
    qapp.processEvents()
    assert panel.property("locationMapVisible") is False
    assert technical_map.property("visible") is False
    assert map_toggle.property("text") == "Mostrar mapa"
    assert advanced.property("visible") is True
    assert float(pedagogical_scroll.property("height")) > scroll_height_with_map

    map_toggle.clicked.emit()
    QTest.qWait(50)
    qapp.processEvents()
    assert panel.property("locationMapVisible") is True
    assert technical_map.property("visible") is True

    panel.setProperty("operationIndex", 11)
    qapp.processEvents()
    assert panel.property("detailsExpanded") is False
    assert panel.property("locationMapVisible") is True

    # La posicion macro cambia en los limites sin alterar los 31 pasos reales.
    for operation_index, chapter_index, local_step, chapter_size in (
        (0, 0, 1, 11),
        (11, 1, 1, 9),
        (20, 2, 1, 9),
        (29, 3, 1, 2),
        (30, 3, 2, 2),
    ):
        panel.setProperty("operationIndex", operation_index)
        qapp.processEvents()
        assert panel.property("processChapterIndex") == chapter_index
        assert panel.property("chapterStep") == local_step
        assert panel.property("chapterStepCount") == chapter_size
        assert process_map.property("currentIndex") == chapter_index
        assert process_map.property("currentStep") == local_step

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_la_guia_visual_precede_a_la_formula_y_aclara_la_muestra_qkv(qapp):
    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)
    panel.setProperty("operationIndex", 2)
    window.setProperty("visible", True)
    QTest.qWait(50)
    qapp.processEvents()

    visual_guide = window.findChild(QQuickItem, "inferenceVisualGuide")
    formula_card = window.findChild(QQuickItem, "inferenceFormulaCard")
    assert visual_guide is not None
    assert formula_card is not None
    assert visual_guide.mapToItem(panel, QPointF(0, 0)).y() < formula_card.mapToItem(
        panel, QPointF(0, 0)
    ).y()
    assert "todas las posiciones" in str(visual_guide.property("text"))

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_codigo_de_color_pedagogico_no_ocupa_otra_franja_y_es_consistente(qapp):
    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)

    legend = window.findChild(QObject, "inferenceColorLegend")
    legend_items = window.findChild(QObject, "inferenceColorLegendRepeater")
    colors = _como_python(panel.property("pedagogicalColors"))
    assert legend is not None and legend.property("visible") is False
    assert legend_items is not None and legend_items.property("count") == 6
    assert [entry["label"] for entry in colors] == [
        "Estructura / flujo",
        "Contexto",
        "Transformación",
        "Foco / selección",
        "Resultado",
        "Solo error",
    ]
    assert len({str(entry["accent"]) for entry in colors}) == len(colors)

    chapters = _como_python(panel.property("processChapters"))
    stages = _como_python(panel.property("stages"))
    assert chapters[0]["accent"] == colors[0]["accent"]  # Encoder = estructura
    assert chapters[2]["accent"] == colors[1]["accent"]  # Cross-attn = contexto
    assert chapters[3]["accent"] == colors[3]["accent"]  # Salida = foco
    assert stages[-1]["accent"] == colors[3]["accent"]

    panel.setProperty("operationIndex", 2)
    qapp.processEvents()
    attention_scene = window.findChild(QObject, "attentionComputationScene")
    qkv_cards = _como_python(attention_scene.property("phaseCards"))
    assert [card["id"] for card in qkv_cards] == ["q", "k", "v"]
    assert len({str(card["accent"]) for card in qkv_cards}) == 3

    # El texto que se dibuja sobre cada color cumple AA para texto normal
    # tanto en la paleta clara como en la oscura.
    for dark_mode in (False, True):
        window.setProperty("requestedDarkMode", dark_mode)
        qapp.processEvents()
        colors = _como_python(panel.property("pedagogicalColors"))
        for entry in colors:
            assert _contraste(QColor(entry["accent"]), QColor(entry["onAccent"])) >= 4.5

        qkv_cards = _como_python(attention_scene.property("phaseCards"))
        for card in qkv_cards:
            assert _contraste(QColor(card["accent"]), QColor(card["onAccent"])) >= 4.5

    window.setProperty("requestedDarkMode", False)
    qapp.processEvents()

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_formula_de_salida_distingue_greedy_de_muestreo(qapp):
    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)
    flow_steps = _como_python(panel.property("flowSteps"))
    panel.setProperty("operationIndex", len(flow_steps) - 1)
    qapp.processEvents()

    formula = window.findChild(QObject, "inferenceFormulaText")
    assert formula is not None
    assert "argmax" in str(formula.property("text"))
    assert "∼ p" in str(formula.property("text"))

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_panel_de_explicacion_se_puede_ocultar_para_ampliar_la_animacion(qapp):
    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)
    window.setProperty("visible", True)
    qapp.processEvents()
    animation = window.findChild(QObject, "inferenceAnimationViewport")
    guide = window.findChild(QObject, "inferencePedagogicalGuide")
    toggle = window.findChild(QObject, "inferenceGuideToggle")

    assert animation is not None
    assert guide is not None and guide.property("visible") is False
    assert toggle is not None and toggle.property("visible") is True
    assert panel.property("guideVisible") is False
    original_width = float(animation.property("width"))

    panel.setProperty("guideVisible", True)
    QTest.qWait(50)
    qapp.processEvents()

    assert guide.property("visible") is True
    assert toggle.property("label") == "Ocultar explicación"
    assert float(animation.property("width")) < original_width
    expanded_width = float(animation.property("width"))

    panel.setProperty("detailsExpanded", True)
    panel.setProperty("guideVisible", False)
    QTest.qWait(50)
    qapp.processEvents()

    assert guide.property("visible") is False
    assert panel.property("detailsExpanded") is False
    assert toggle.property("label") == "Mostrar explicación"
    assert float(animation.property("width")) > expanded_width
    assert float(animation.property("width")) >= original_width - 1

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_prompt_salida_y_mapa_reservan_espacio_legible(qapp):
    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)
    panel.setProperty(
        "snapshots",
        [
            {
                "paso": 1,
                "tokens_entrada": [{"texto": "Hola"}, {"texto": "mundo"}],
                "token_elegido": {"texto": "mas"},
            }
        ],
    )
    panel.setProperty("selectedIndex", 0)
    panel.setProperty("operationIndex", 11)
    panel.setProperty("guideVisible", True)
    panel.setProperty("locationMapVisible", True)
    window.setProperty("visible", True)
    QTest.qWait(50)
    qapp.processEvents()

    ribbon = window.findChild(QQuickItem, "inferenceTokenRibbon")
    prompt_tokens = window.findChild(QQuickItem, "inferencePromptTokens")
    output_tokens = window.findChild(QQuickItem, "inferenceOutputTokens")
    guide = window.findChild(QQuickItem, "inferencePedagogicalGuide")
    minimap = window.findChild(QQuickItem, "inferenceTransformerMiniMap")
    location = window.findChild(QQuickItem, "transformerMiniMapLocation")

    assert all(
        item is not None
        for item in (ribbon, prompt_tokens, output_tokens, guide, minimap, location)
    )
    assert panel.property("tokenRibbonFits") is True
    chip_height = float(panel.property("tokenChipHeight"))
    assert prompt_tokens.height() >= chip_height
    assert output_tokens.height() >= chip_height
    assert minimap.height() >= 220
    assert minimap.height() >= guide.height() * 0.38
    assert minimap.property("contentFits") is True
    _assert_item_dentro_del_panel(panel, ribbon)
    _assert_item_dentro_del_panel(guide, minimap)
    _assert_item_dentro_del_panel(minimap, location)

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_explicacion_se_desacopla_en_otra_ventana_y_libera_la_animacion(qapp):
    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)
    window.setProperty("visible", True)
    QTest.qWait(50)
    qapp.processEvents()

    animation = window.findChild(QQuickItem, "inferenceAnimationViewport")
    guide = window.findChild(QQuickItem, "inferencePedagogicalGuide")
    dock = window.findChild(QQuickItem, "inferencePedagogicalGuideDock")
    detach_button = window.findChild(QObject, "inferenceDetachGuideButton")
    detached_window = window.findChild(QObject, "inferenceDetachedGuideWindow")
    assert all(
        item is not None
        for item in (animation, guide, dock, detach_button, detached_window)
    )
    full_animation_width = animation.width()

    panel.setProperty("guideVisible", True)
    QTest.qWait(50)
    qapp.processEvents()
    embedded_animation_width = animation.width()
    assert dock.property("visible") is True
    assert guide.property("visible") is True
    assert embedded_animation_width < full_animation_width
    assert detach_button.property("text") == "Abrir aparte"

    detach_button.clicked.emit()
    QTest.qWait(80)
    qapp.processEvents()
    assert panel.property("guideDetached") is True
    assert detached_window.property("visible") is True
    assert dock.property("visible") is False
    assert guide.property("visible") is True
    assert guide.window() == detached_window
    assert detach_button.property("text") == "Acoplar"
    assert animation.width() >= full_animation_width - 1

    panel.setProperty("operationIndex", 12)
    QTest.qWait(30)
    qapp.processEvents()
    assert panel.property("guideDetached") is True
    assert detached_window.property("visible") is True
    assert str(detached_window.property("title")).startswith("Explicación · ")

    detach_button.clicked.emit()
    QTest.qWait(50)
    qapp.processEvents()
    assert panel.property("guideDetached") is False
    assert detached_window.property("visible") is False
    assert dock.property("visible") is True
    assert guide.window() == window
    assert animation.width() < full_animation_width

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_minimapa_pasivo_sigue_cada_operacion_semantica(qapp):
    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)
    minimap = window.findChild(QObject, "inferenceTransformerMiniMap")

    assert minimap is not None
    assert minimap.property("interactive") is False

    steps = _como_python(panel.property("flowSteps"))
    index_by_id = {step["id"]: index for index, step in enumerate(steps)}
    expected_by_operation = {
        "encoder_embedding": {"input_embedding"},
        "encoder_position": {"encoder_positional_encoding"},
        "encoder_qkv": {"encoder_self_attention"},
        "encoder_scores": {"encoder_self_attention"},
        "encoder_softmax": {"encoder_self_attention"},
        "encoder_weighted": {"encoder_self_attention"},
        "encoder_multihead": {"encoder_self_attention"},
        "encoder_addnorm_attention": {"encoder_add_norm_attention"},
        "encoder_ffn": {"encoder_feed_forward"},
        "encoder_addnorm_ffn": {"encoder_add_norm_ffn"},
        "encoder_layers": {
            "encoder_self_attention",
            "encoder_add_norm_attention",
            "encoder_feed_forward",
            "encoder_add_norm_ffn",
        },
        "decoder_embedding": {"output_embedding"},
        "decoder_position": {"decoder_positional_encoding"},
        "decoder_masked_mask": {"decoder_masked_attention"},
        "decoder_addnorm_masked": {"decoder_add_norm_masked"},
        "decoder_cross_weighted": {"decoder_cross_attention"},
        "decoder_addnorm_cross": {"decoder_add_norm_cross"},
        "decoder_ffn": {"decoder_feed_forward"},
        "decoder_addnorm_ffn": {"decoder_add_norm_ffn"},
        "decoder_layers": {
            "decoder_masked_attention",
            "decoder_add_norm_masked",
            "decoder_cross_attention",
            "decoder_add_norm_cross",
            "decoder_feed_forward",
            "decoder_add_norm_ffn",
        },
        "linear_logits": {"linear"},
        "output_softmax": {"softmax"},
    }
    for operation_id, expected in expected_by_operation.items():
        panel.setProperty("operationIndex", index_by_id[operation_id])
        qapp.processEvents()
        assert minimap.property("operationId") == operation_id
        assert set(_como_python(minimap.property("activeBlockIds"))) == expected

    panel.setProperty("operationIndex", index_by_id["decoder_addnorm_ffn"])
    panel.setProperty("reducedMotion", True)
    qapp.processEvents()
    assert minimap.property("reducedMotion") is True
    assert "Add & Norm de FFN" in minimap.property("activeRegion")

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_layernorm_explica_sus_cuatro_fases_y_simbolos(qapp):
    engine = QQmlEngine()
    component, window, panel = _crear_panel(engine, qapp)
    assert component is not None and panel is not None
    scene = window.findChild(QObject, "residualLayerNormScene")
    explanation = window.findChild(QObject, "layerNormSelectedPhaseText")

    assert scene is not None
    assert explanation is not None

    expected_symbols = (
        ("x", "Δx"),
        ("μ", "cero"),
        ("σ", "ε"),
        ("γ", "β"),
    )
    explanations = []
    for phase_index, symbols in enumerate(expected_symbols):
        scene.setProperty("selectedPhase", phase_index)
        qapp.processEvents()
        pedagogical_text = str(scene.property("phasePedagogicalExplanation"))
        assert explanation.property("text") == pedagogical_text
        assert all(symbol in pedagogical_text for symbol in symbols)
        explanations.append(pedagogical_text)

    assert len(set(explanations)) == 4

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_explorador_acepta_un_forward_real_en_todo_el_recorrido(qapp):
    config = ConfiguracionTransformer(
        tamano_vocabulario=40,
        dimension_modelo=32,
        num_cabezas=4,
        num_capas=2,
        dimension_ff=64,
        longitud_maxima_secuencia=16,
        dropout=0.0,
    )
    modelo = Transformer(config)
    tokenizer = _TokenizerVisual()
    tokens_origen = torch.tensor([[4, 7, 9, 12]])
    paso = next(
        modelo.generar(
            tokens_origen,
            id_token_inicio=1,
            max_tokens_nuevos=1,
            muestreo_codicioso=True,
        )
    )
    snapshot = resumir_paso_inferencia(
        modelo,
        tokenizer,
        tokens_origen,
        paso,
        ids_generados=[int(paso["token_id"])],
        id_token_inicio=1,
        temperatura=1.0,
        top_k=None,
        top_p=None,
        muestreo_codicioso=True,
    )
    detail = snapshot.pop("detalle_forward")

    for attention in (
        detail["encoder"][0]["atencion"],
        detail["decoder"][0]["autoatencion"],
        detail["decoder"][0]["atencion_cruzada"],
    ):
        for field in (
            "q",
            "k",
            "v",
            "scores",
            "scores_enmascarados",
            "atencion",
            "contribuciones",
        ):
            assert attention[field], field
    assert detail["decoder"][0]["autoatencion"]["validacion"][
        "enmascarados_cero"
    ]
    assert detail["logits_lineales"]["sin_nan"]
    assert detail["logits_lineales"]["sin_inf"]

    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)
    assert panel is not None
    panel.setProperty("snapshots", [snapshot])
    panel.setProperty("detailForward", detail)
    panel.setProperty("selectedIndex", 0)
    panel.setProperty("operationIndex", 30)
    qapp.processEvents()

    softmax_scene = window.findChild(QObject, "softmaxRaceScene")
    assert softmax_scene is not None
    assert softmax_scene.property("candidateCount") > 0

    flow_steps = _como_python(panel.property("flowSteps"))
    formula = window.findChild(QObject, "inferenceFormulaText")
    formula_explanation = window.findChild(QObject, "inferenceFormulaExplanation")
    input_output = window.findChild(QObject, "inferenceInputOutputText")
    previous_step = window.findChild(QObject, "inferencePreviousStepText")
    following_step = window.findChild(QObject, "inferenceFollowingStepText")
    visual_elements = window.findChild(QObject, "inferenceVisualElementsRepeater")
    symbol_glossary = window.findChild(QObject, "inferenceSymbolGlossaryRepeater")
    interaction_help = window.findChild(QObject, "inferenceInteractionHelp")
    for operation_index, operation in enumerate(flow_steps):
        panel.setProperty("operationIndex", operation_index)
        qapp.processEvents()
        assert panel.property("operationIndex") == operation_index
        assert panel.property("stageIndex") == operation["stageIndex"]
        assert panel.property("branchIndex") == operation["branchIndex"]
        assert formula.property("text") == operation["formula"]
        assert len(str(formula_explanation.property("text"))) > len("CÓMO LEERLA")
        assert "ENTRA" in input_output.property("text")
        assert "SALE" in input_output.property("text")
        assert str(previous_step.property("stepText")).strip()
        assert str(following_step.property("stepText")).strip()
        assert visual_elements.property("count") == len(operation["visualElements"])
        assert symbol_glossary.property("count") == len(operation["symbolGlossary"])
        assert interaction_help.property("text").startswith("PRUÉBALO")

    assert window.findChild(QObject, "tokenEmbeddingScene") is not None
    assert window.findChild(QObject, "attentionComputationScene") is not None
    assert window.findChild(QObject, "outputProjectionScene") is not None

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()
