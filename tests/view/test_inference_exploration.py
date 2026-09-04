"""Smoke tests del explorador visual de la inferencia."""

from __future__ import annotations

import os
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import QObject, QUrl
from PySide6.QtQml import QJSValue, QQmlComponent, QQmlEngine
import torch

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
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
        for field in ("operation", "visualMeaning", "purpose", "nextStep"):
            assert step[field].strip(), (step["id"], field)

    panel.setProperty("operationIndex", len(flow_steps) - 1)
    qapp.processEvents()
    assert panel.property("stageIndex") == 6

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
    for operation_index, operation in enumerate(flow_steps):
        panel.setProperty("operationIndex", operation_index)
        qapp.processEvents()
        assert panel.property("operationIndex") == operation_index
        assert panel.property("stageIndex") == operation["stageIndex"]
        assert panel.property("branchIndex") == operation["branchIndex"]

    assert window.findChild(QObject, "tokenEmbeddingScene") is not None
    assert window.findChild(QObject, "attentionComputationScene") is not None
    assert window.findChild(QObject, "outputProjectionScene") is not None

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()
