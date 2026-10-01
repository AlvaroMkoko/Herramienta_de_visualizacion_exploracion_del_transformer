"""Pruebas QML del explorador paralelo de la comparación de modelos."""

from __future__ import annotations

import os
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import Q_ARG, QMetaObject, QObject, QPointF, Qt, QUrl
from PySide6.QtQml import QQmlComponent, QQmlEngine
from PySide6.QtQuick import QQuickItem, QQuickWindow
from PySide6.QtTest import QTest

from viewmodel.main_viewmodel import MainViewModel


QML_ROOT = Path(__file__).resolve().parents[2] / "view" / "qml"


def _errors(component: QQmlComponent) -> str:
    return "\n".join(error.toString() for error in component.errors())


def _snapshot(token: str, probability: float) -> dict:
    attention = [
        {"posicion": 0, "token_id": 11, "texto": "El", "peso": 0.2},
        {"posicion": 1, "token_id": 12, "texto": "gato", "peso": 0.8},
    ]
    return {
        "token_elegido": {
            "token_id": 20,
            "texto": token,
            "probabilidad": probability,
            "rango": 1,
        },
        "foco_encoder": attention,
        "foco_decoder": attention,
        "foco_entrada": attention,
        "predicciones_top": [
            {
                "token_id": 20,
                "texto": token,
                "probabilidad": probability,
                "rango": 1,
                "elegido": True,
            }
        ],
        "cantidad_candidatos": 10,
        "entropia_salida": 1.5,
        "atencion_por_bloque": {
            "encoder": [{"capa": 1, "pico": 0.8, "entropia": 0.5}],
            "decoder": [{"capa": 1, "pico": 0.8, "entropia": 0.5}],
            "cruzada": [{"capa": 1, "pico": 0.8, "entropia": 0.5}],
        },
    }


def _detail() -> dict:
    return {
        "metadata": {
            "num_layers": 2,
            "num_heads": 4,
            "d_model": 16,
            "d_head": 4,
            "d_ff": 32,
        },
        "global": {},
        "encoder": [{"capa": 1}, {"capa": 2}],
        "decoder": [{"capa": 1}, {"capa": 2}],
        "trayectorias": {"encoder": {}, "decoder": {}},
        "logits_lineales": {},
    }


def test_explorador_alinea_pasos_y_admite_finales_distintos(qapp):
    engine = QQmlEngine()
    engine.addImportPath(str(QML_ROOT))
    component = QQmlComponent(
        engine,
        QUrl.fromLocalFile(
            str(QML_ROOT / "components" / "ComparisonExplorationPanel.qml")
        ),
    )
    assert component.status() == QQmlComponent.Status.Ready, _errors(component)
    panel = component.create()
    assert panel is not None, _errors(component)

    preview_window = QQuickWindow()
    preview_window.setWidth(1200)
    preview_window.setHeight(760)
    panel.setParentItem(preview_window.contentItem())
    panel.setProperty("width", 1200)
    panel.setProperty("height", 760)
    panel.setProperty("snapshotsA", [_snapshot("corre", 0.7), _snapshot(".", 0.6)])
    panel.setProperty("snapshotsB", [_snapshot("duerme", 0.55)])
    panel.setProperty("detailA", _detail())
    panel.setProperty("detailB", _detail())
    panel.setProperty("detailIndexA", 0)
    panel.setProperty("detailIndexB", 0)
    panel.setProperty("stateB", "Completada")
    panel.setProperty("tokenCountB", 1)
    panel.setProperty("modelBActive", False)
    panel.setProperty("selectedIndex", 0)
    preview_window.show()
    QTest.qWait(30)
    qapp.processEvents()

    trace_a = panel.findChild(QObject, "comparisonModelTraceA")
    trace_b = panel.findChild(QObject, "comparisonModelTraceB")
    assert trace_a is not None
    assert trace_b is not None
    assert panel.property("stepCount") == 2
    assert panel.property("commonStepCount") == 1
    assert panel.property("stepScope") == "último común"
    assert trace_a.property("hasSnapshot") is True
    assert trace_b.property("hasSnapshot") is True
    assert len(trace_a.property("stageEntries")) == 2

    animation_a = panel.findChild(QQuickItem, "comparisonAnimationTraceA")
    animation_b = panel.findChild(QQuickItem, "comparisonAnimationTraceB")
    assert animation_a is not None
    assert animation_b is not None
    panel.setProperty("viewModeIndex", 1)
    panel.setProperty("animationIndex", 6)
    panel.setProperty("branchIndex", 2)
    QTest.qWait(30)
    qapp.processEvents()
    assert panel.property("singleModelMode") is True
    assert animation_a.property("visible") is True
    assert animation_b.property("visible") is False
    assert animation_a.width() > panel.width() * 0.85
    assert len(panel.property("animationLabels").toVariant()) == 10
    assert animation_a.property("animationCount") == 10
    assert animation_a.property("hasDetail") is True
    assert animation_b.property("hasDetail") is True
    assert animation_a.property("animationIndex") == 6
    assert animation_b.property("branchIndex") == 2

    controls = panel.findChild(QQuickItem, "comparisonAnimationControls")
    compact_controls = panel.findChild(
        QQuickItem, "comparisonCompactAnimationControls"
    )
    assert controls is not None
    assert compact_controls is not None
    for animation_index in range(10):
        panel.setProperty("animationIndex", animation_index)
        QTest.qWait(5)
        qapp.processEvents()
        trace_position = animation_a.mapToItem(panel, QPointF(0, 0))
        assert trace_position.x() >= -0.5
        assert trace_position.x() + animation_a.width() <= panel.width() + 0.5, (
            animation_index,
            animation_a.width(),
            animation_a.parentItem().width(),
            animation_a.parentItem().parentItem().width(),
            animation_a.parentItem().parentItem().parentItem().width(),
            animation_a.parentItem().parentItem().parentItem().parentItem().width(),
            animation_a.parentItem().parentItem().parentItem().parentItem().parentItem().width(),
            animation_a.parentItem().parentItem().parentItem().parentItem().parentItem().parentItem().width(),
        )
        for controls_group in (controls, compact_controls):
            for child in controls_group.childItems():
                if not child.isVisible() or child.width() <= 0:
                    continue
                child_position = child.mapToItem(controls_group, QPointF(0, 0))
                assert child_position.x() >= -0.5
                assert (child_position.x() + child.width()
                        <= controls_group.width() + 0.5)

    panel.setProperty("compactModelIndex", 1)
    QTest.qWait(30)
    qapp.processEvents()
    assert animation_a.property("visible") is False
    assert animation_b.property("visible") is True
    assert animation_b.width() > panel.width() * 0.85

    # El modelo B terminó antes: el segundo paso sigue siendo explorable y su
    # panel muestra un resumen terminal en vez de quedar vacío.
    panel.setProperty("selectedIndex", 1)
    qapp.processEvents()
    assert trace_a.property("hasSnapshot") is True
    assert trace_b.property("hasSnapshot") is False
    assert panel.property("stepScope") == "solo A"
    assert trace_b.property("generationFinished") is True
    assert trace_b.property("terminalTitle") == "Generación finalizada"
    assert "1 token" in trace_b.property("terminalDetail")
    assert "duerme" in trace_b.property("terminalDetail")

    preview_window.close()
    preview_window.deleteLater()
    panel.deleteLater()
    component.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_pantalla_conserva_la_ultima_captura_tensorial_comun(qapp):
    engine = QQmlEngine()
    view_model = MainViewModel()
    engine.rootContext().setContextProperty("mainViewModel", view_model)
    component = QQmlComponent(engine)
    component.setData(
        b"""
import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {
    width: 1280
    height: 820
    visible: false
    StackView { id: navigation; anchors.fill: parent }
    Screens.ComparisonScreen {
        objectName: "comparisonCacheScreen"
        anchors.fill: parent
        stackView: navigation
    }
}
""",
        QUrl.fromLocalFile(str(QML_ROOT / "ComparisonCacheHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    screen = window.findChild(QObject, "comparisonCacheScreen")
    assert screen is not None

    def registrar(model: str, token: str) -> None:
        visual = _snapshot(token, 0.7)
        visual["detalle_forward"] = _detail()
        invoked = QMetaObject.invokeMethod(
            screen,
            "registrarToken",
            Qt.ConnectionType.DirectConnection,
            Q_ARG("QVariant", model),
            Q_ARG(
                "QVariant",
                {"visualizacion": visual, "es_ultimo_token": False},
            ),
        )
        assert invoked

    registrar("A", "uno-a")
    assert screen.property("indiceDetalleComun") == -1
    registrar("B", "uno-b")
    assert screen.property("indiceDetalleComun") == 0
    assert screen.property("indiceExploracion") == 0

    # Si A se adelanta, la pantalla mantiene el último detalle comparable y
    # guarda el nuevo hasta que B alcance el mismo índice.
    registrar("A", "dos-a")
    assert screen.property("indiceDetalleComun") == 0
    assert screen.property("indiceExploracion") == 0
    registrar("B", "dos-b")
    assert screen.property("indiceDetalleComun") == 1
    assert screen.property("indiceExploracion") == 1

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_expansion_ffn_no_desborda_un_panel_comparativo(qapp):
    engine = QQmlEngine()
    engine.addImportPath(str(QML_ROOT))
    component = QQmlComponent(
        engine,
        QUrl.fromLocalFile(
            str(QML_ROOT / "components" / "FeedForwardExpansionScene.qml")
        ),
    )
    assert component.status() == QQmlComponent.Status.Ready, _errors(component)
    scene = component.create()
    assert scene is not None, _errors(component)
    window = QQuickWindow()
    window.setWidth(880)
    window.setHeight(540)
    scene.setParentItem(window.contentItem())
    scene.setProperty("width", 880)
    scene.setProperty("height", 540)
    scene.setProperty("reducedMotion", True)
    scene.setProperty(
        "tokens",
        engine.evaluate('[{"posicion": 0, "texto": "Hola", "token_id": 1}]'),
    )
    scene.setProperty(
        "sceneData",
        engine.evaluate("""({
            activacion: "ReLU",
            tokens: [{
                posicion: 0,
                dimension_entrada: 64,
                dimension_oculta: 256,
                dimension_salida: 64,
                entrada: [0.1, -0.2, 0.4, -0.1],
                preactivacion: [0.2, -0.4, 0.8, -0.2],
                activacion: [0.2, 0.0, 0.8, 0.0],
                salida: [0.3, -0.1, 0.6, 0.2],
                norma_entrada: 8.024,
                norma_preactivacion: 10.830,
                norma_activacion: 7.2,
                norma_salida: 9.1,
                fraccion_negativa: 0.543,
                fraccion_casi_cero: 0.543
            }]
        })"""),
    )
    scene.setProperty("active", True)
    window.show()
    QTest.qWait(30)
    qapp.processEvents()

    def visual_child(item: QQuickItem, name: str):
        for child in item.childItems():
            if child.objectName() == name:
                return child
            found = visual_child(child, name)
            if found is not None:
                return found
        return None

    token_row = visual_child(scene, "feedForwardTokenRow")
    output_strip = visual_child(scene, "feedForwardOutputStrip")
    assert scene.property("renderedTokenCount") == 1
    assert token_row is not None
    assert output_strip is not None
    assert scene.property("compact") is False
    assert token_row.property("contentFits") is True
    output_position = output_strip.mapToItem(scene, QPointF(0, 0))
    assert output_position.x() >= 0
    assert output_position.x() + output_strip.width() <= scene.width() + 0.5

    window.close()
    window.deleteLater()
    scene.deleteLater()
    component.deleteLater()
    engine.deleteLater()
    qapp.processEvents()
