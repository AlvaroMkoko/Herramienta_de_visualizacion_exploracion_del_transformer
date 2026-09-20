"""Smoke tests del explorador visual de la inferencia."""

from __future__ import annotations

import os
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import QObject, QPointF, QUrl
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

ApplicationWindow {
    width: 1920
    height: 1080
    visible: false

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
        "inferencePedagogicalGuide",
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

    animation_position = animation.mapToItem(panel, QPointF(0, 0))
    guide_position = guide.mapToItem(panel, QPointF(0, 0))
    assert animation_position.x() + animation.width() <= guide_position.x() + 0.5

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
    assert panel.property("locationMapVisible") is True
    assert technical_map is not None and technical_map.property("visible") is True
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


def test_panel_de_explicacion_se_puede_ocultar_para_ampliar_la_animacion(qapp):
    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)
    window.setProperty("visible", True)
    qapp.processEvents()
    animation = window.findChild(QObject, "inferenceAnimationViewport")
    guide = window.findChild(QObject, "inferencePedagogicalGuide")
    toggle = window.findChild(QObject, "inferenceGuideToggle")

    assert animation is not None
    assert guide is not None and guide.property("visible") is True
    assert toggle is not None and toggle.property("visible") is True
    assert panel.property("guideVisible") is True
    original_width = float(animation.property("width"))

    panel.setProperty("detailsExpanded", True)
    panel.setProperty("guideVisible", False)
    QTest.qWait(50)
    qapp.processEvents()

    assert guide.property("visible") is False
    assert panel.property("detailsExpanded") is False
    assert toggle.property("label") == "Mostrar explicación"
    assert float(animation.property("width")) > original_width

    panel.setProperty("guideVisible", True)
    QTest.qWait(50)
    qapp.processEvents()

    assert guide.property("visible") is True
    assert toggle.property("label") == "Ocultar explicación"
    assert float(animation.property("width")) < original_width + 1

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
