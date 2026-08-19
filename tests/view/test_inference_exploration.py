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


def test_explorador_de_inferencia_carga_las_siete_escenas(qapp):
    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)
    assert panel is not None
    stages = panel.property("stages")
    stages = stages.toVariant() if isinstance(stages, QJSValue) else stages
    assert len(stages) == 7

    panel.setProperty("stageIndex", 6)
    qapp.processEvents()
    assert panel.property("stageIndex") == 6

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_explorador_acepta_un_forward_real_en_todas_las_escenas(qapp):
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

    engine = QQmlEngine()
    _, window, panel = _crear_panel(engine, qapp)
    assert panel is not None
    panel.setProperty("snapshots", [snapshot])
    panel.setProperty("detailForward", detail)
    panel.setProperty("selectedIndex", 0)

    for scene_index in range(7):
        panel.setProperty("stageIndex", scene_index)
        qapp.processEvents()
        assert panel.property("stageIndex") == scene_index

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()
