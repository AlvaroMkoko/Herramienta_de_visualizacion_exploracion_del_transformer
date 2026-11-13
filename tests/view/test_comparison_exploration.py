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


def _visual_child(item: QQuickItem, name: str):
    for child in item.childItems():
        if child.objectName() == name:
            return child
        found = _visual_child(child, name)
        if found is not None:
            return found
    return None


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
    assert trace_a.isVisible()
    assert trace_b.isVisible()
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


def test_explorador_compacto_alterna_modelos_sin_amontonar_paneles(qapp):
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

    window = QQuickWindow()
    window.setWidth(920)
    window.setHeight(600)
    panel.setParentItem(window.contentItem())
    panel.setProperty("width", 920)
    panel.setProperty("height", 600)
    panel.setProperty("sx", 920 / 1280)
    panel.setProperty("sy", 600 / 820)
    panel.setProperty("snapshotsA", [_snapshot("corre", 0.7)])
    panel.setProperty("snapshotsB", [_snapshot("duerme", 0.55)])
    panel.setProperty("detailA", _detail())
    panel.setProperty("detailB", _detail())
    window.show()
    QTest.qWait(30)
    qapp.processEvents()

    trace_a = panel.findChild(QQuickItem, "comparisonModelTraceA")
    trace_b = panel.findChild(QQuickItem, "comparisonModelTraceB")
    selector = panel.findChild(
        QQuickItem, "comparisonCompactSummaryModelSelector"
    )
    assert panel.property("summarySingleModelMode") is True
    assert selector is not None and selector.isVisible()
    assert trace_a is not None and trace_a.isVisible()
    assert trace_b is not None and not trace_b.isVisible()
    assert trace_a.width() > panel.width() * 0.9

    panel.setProperty("compactModelIndex", 1)
    QTest.qWait(20)
    qapp.processEvents()
    assert not trace_a.isVisible()
    assert trace_b.isVisible()
    assert trace_b.width() > panel.width() * 0.9

    for item in (selector, trace_b):
        position = item.mapToItem(panel, QPointF(0, 0))
        assert position.x() >= -0.5
        assert position.x() + item.width() <= panel.width() + 0.5

    window.close()
    window.deleteLater()
    panel.deleteLater()
    component.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_animaciones_compactas_desplazan_sin_recortar_contenido(qapp):
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

    snapshot = _snapshot("s", 0.5364)
    snapshot["tokens_entrada"] = [
        {"posicion": index, "token_id": index + 1, "texto": f"t{index}"}
        for index in range(4)
    ]
    snapshot["tokens_salida"] = [{"texto": "s"}]
    vector = [(-1 if index % 2 else 1) * (index + 1) / 100 for index in range(32)]
    matrix = {
        "valores": [vector for _ in range(4)],
        "displayed_shape": "4 × 32",
    }
    detail = _detail()
    detail["global"] = {
        "embedding_encoder_escalado": {
            "shape": "1 × 4 × 128",
            "matriz": matrix,
            "normas_tokens": [0.4, 0.5, 0.6, 0.7],
            "estadisticas": {
                "minimo": -0.32,
                "maximo": 0.31,
                "media": 0.01,
                "norma_l2": 1.2,
            },
        },
        "salida_decoder": {
            "shape": "1 × 2 × 128",
            "matriz": {
                "valores": [vector, vector],
                "displayed_shape": "2 × 32",
            },
        },
    }
    detail["logits_lineales"] = {
        "shape": "1 × 100280",
        "histograma": {
            "conteos": [2, 4, 8, 5],
            "bordes": [-2, -1, 0, 1, 2],
            "total": 19,
        },
        "estadisticas": {
            "minimo": -2,
            "maximo": 2,
            "media": 0,
            "desviacion": 1,
        },
    }

    window = QQuickWindow()
    window.setWidth(920)
    window.setHeight(600)
    panel.setParentItem(window.contentItem())
    panel.setProperty("width", 920)
    panel.setProperty("height", 600)
    panel.setProperty("sx", 920 / 1280)
    panel.setProperty("sy", 600 / 820)
    panel.setProperty("snapshotsA", [snapshot])
    panel.setProperty("snapshotsB", [snapshot])
    panel.setProperty("detailA", detail)
    panel.setProperty("detailB", detail)
    panel.setProperty("detailIndexA", 0)
    panel.setProperty("detailIndexB", 0)
    panel.setProperty("selectedIndex", 0)
    panel.setProperty("viewModeIndex", 1)
    panel.setProperty("reducedMotion", True)
    window.show()
    QTest.qWait(40)
    qapp.processEvents()

    animation = panel.findChild(QQuickItem, "comparisonAnimationTraceA")
    assert animation is not None and animation.isVisible()
    viewport = animation.findChild(QQuickItem, "comparisonAnimationViewport")
    embedding = animation.findChild(QQuickItem, "tokenEmbeddingScene")
    vector_strip = animation.findChild(QQuickItem, "tokenEmbeddingVector")
    metrics = animation.findChild(QQuickItem, "tokenEmbeddingMetrics")
    norm = animation.findChild(QQuickItem, "tokenEmbeddingNorm")
    assert all(item is not None for item in (viewport, embedding, vector_strip,
                                              metrics, norm))
    assert viewport.property("contentHeight") > viewport.height()
    assert vector_strip.property("contentWidth") > vector_strip.width()
    metrics_position = metrics.mapToItem(embedding, QPointF(0, 0))
    norm_position = norm.mapToItem(embedding, QPointF(0, 0))
    assert metrics_position.y() + metrics.height() <= norm_position.y() + 0.5

    panel.setProperty("animationIndex", 8)
    QTest.qWait(30)
    qapp.processEvents()
    output = animation.findChild(QQuickItem, "outputProjectionScene")
    hidden_strip = animation.findChild(QQuickItem, "outputHiddenVector")
    hidden_panel = animation.findChild(QQuickItem, "outputHiddenVectorPanel")
    histogram_panel = animation.findChild(QQuickItem, "outputHistogramPanel")
    assert all(item is not None for item in (output, hidden_strip, hidden_panel,
                                              histogram_panel))
    assert viewport.property("contentHeight") > viewport.height()
    assert output.height() == viewport.property("contentHeight")
    assert hidden_strip.property("contentWidth") > hidden_strip.width()
    hidden_position = hidden_panel.mapToItem(output, QPointF(0, 0))
    histogram_position = histogram_panel.mapToItem(output, QPointF(0, 0))
    assert hidden_position.y() + hidden_panel.height() <= histogram_position.y() + 0.5

    maximum_scroll = viewport.property("contentHeight") - viewport.height()
    viewport.setProperty("contentY", maximum_scroll)
    qapp.processEvents()
    assert abs(viewport.property("contentY") - maximum_scroll) < 1

    panel.setProperty("animationIndex", 9)
    QTest.qWait(30)
    qapp.processEvents()
    softmax = animation.findChild(QQuickItem, "softmaxRaceScene")
    stable_formula = animation.findChild(QQuickItem, "softmaxStableFormula")
    chosen = animation.findChild(QQuickItem, "softmaxChosenTokenCard")
    outside_mass = animation.findChild(QQuickItem, "softmaxOutsideMassCard")
    return_card = animation.findChild(QQuickItem, "softmaxReturnToDecoder")
    assert all(item is not None for item in (softmax, stable_formula, chosen,
                                              outside_mass, return_card))
    assert "z/T" in stable_formula.property("text")
    assert "zmax" in stable_formula.property("text")
    assert "Σ" in stable_formula.property("text")
    assert viewport.property("contentY") == 0
    chosen_position = chosen.mapToItem(softmax, QPointF(0, 0))
    mass_position = outside_mass.mapToItem(softmax, QPointF(0, 0))
    return_position = return_card.mapToItem(softmax, QPointF(0, 0))
    assert chosen_position.y() + chosen.height() <= mass_position.y() + 0.5
    assert mass_position.y() + outside_mass.height() <= return_position.y() + 0.5
    assert return_position.y() + return_card.height() <= softmax.height() + 0.5

    window.close()
    window.deleteLater()
    panel.deleteLater()
    component.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_pantalla_compacta_muestra_un_resultado_a_la_vez(qapp):
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
    width: 960
    height: 600
    visible: true
    StackView { id: navigation; anchors.fill: parent }
    Screens.ComparisonScreen {
        objectName: "compactComparisonScreen"
        anchors.fill: parent
        stackView: navigation
    }
}
""",
        QUrl.fromLocalFile(str(QML_ROOT / "CompactComparisonHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    QTest.qWait(30)
    qapp.processEvents()

    screen = window.findChild(QObject, "compactComparisonScreen")
    selector = window.findChild(QQuickItem, "comparisonCompactResultSelector")
    loaded_view = window.findChild(QQuickItem, "comparisonLoadedView")
    assert loaded_view is not None
    loaded_view.setProperty("visible", True)
    QTest.qWait(20)
    qapp.processEvents()
    result_a = _visual_child(loaded_view, "comparisonResultModel1")
    result_b = _visual_child(loaded_view, "comparisonResultModel2")
    result_repeater = window.findChild(QObject, "comparisonResultRepeater")
    assert screen is not None
    assert screen.property("comparacionCompacta") is True
    assert selector is not None
    assert result_repeater is not None and result_repeater.property("count") == 2
    assert result_a is not None and result_b is not None
    assert result_a.property("activoEnVistaCompacta") is True
    assert result_b.property("activoEnVistaCompacta") is False
    assert result_a.isVisible()
    assert not result_b.isVisible()
    assert result_a.width() > loaded_view.width() * 0.9
    selector_position = selector.mapToItem(screen, QPointF(0, 0))
    assert selector_position.x() >= -0.5
    assert selector_position.x() + selector.width() <= screen.width() + 0.5

    screen.setProperty("modeloCompactoIndex", 1)
    QTest.qWait(20)
    qapp.processEvents()
    assert result_a.property("activoEnVistaCompacta") is False
    assert result_b.property("activoEnVistaCompacta") is True
    assert not result_a.isVisible()
    assert result_b.isVisible()
    assert result_b.width() > loaded_view.width() * 0.9

    window.setWidth(1280)
    QTest.qWait(20)
    qapp.processEvents()
    assert screen.property("comparacionCompacta") is False
    assert not selector.isVisible()
    assert result_a.property("activoEnVistaCompacta") is True
    assert result_b.property("activoEnVistaCompacta") is True
    assert result_a.isVisible()
    assert result_b.isVisible()

    window.close()
    window.deleteLater()
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

    token_row = _visual_child(scene, "feedForwardTokenRow")
    output_strip = _visual_child(scene, "feedForwardOutputStrip")
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


def _fijar_movimiento_reducido(engine: QQmlEngine, valor: bool) -> None:
    # El tema es un singleton por engine: se escribe desde un componente del
    # mismo engine, igual que lo haría MotionSwitch en la aplicación.
    component = QQmlComponent(engine)
    component.setData(
        (
            'import QtQuick\nimport "styles" as Style\n'
            "QtObject { Component.onCompleted: Style.Theme.movimientoReducido = "
            + ("true" if valor else "false")
            + " }"
        ).encode(),
        QUrl.fromLocalFile(str(QML_ROOT / "FijarMovimiento.qml")),
    )
    assert component.create() is not None, _errors(component)


def _la_carrera_anima_al_entrar(panel, qapp) -> bool:
    """Entra a la escena de softmax desde otra y dice si algo cambia en 0.6 s."""
    panel.setProperty("animationIndex", 8)
    QTest.qWait(50)
    panel.setProperty("animationIndex", 9)
    qapp.processEvents()
    scene = panel.findChild(QObject, "comparisonAnimationTraceA").findChild(
        QObject, "softmaxRaceScene"
    )
    assert scene is not None and scene.property("active") is True
    primero = scene.property("revealProgress")
    QTest.qWait(600)
    return scene.property("revealProgress") != primero


def test_comparacion_obedece_el_movimiento_reducido_global(qapp):
    """Con la preferencia global activada, el explorador de comparación no anima.

    Antes tenía su propia casilla y una propiedad local que nada enlazaba al
    tema: la preferencia global no llegaba a sus escenas.
    """
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
    window = QQuickWindow()
    window.setWidth(1200)
    window.setHeight(760)
    panel.setParentItem(window.contentItem())
    panel.setProperty("width", 1200)
    panel.setProperty("height", 760)
    panel.setProperty("snapshotsA", [_snapshot("corre", 0.7)])
    panel.setProperty("snapshotsB", [_snapshot("duerme", 0.55)])
    panel.setProperty("detailA", _detail())
    panel.setProperty("detailB", _detail())
    panel.setProperty("viewModeIndex", 1)
    window.show()
    qapp.processEvents()

    # Control: sin la preferencia, la escena sí entra animando. Sin esto, una
    # escena que nunca animara pasaría la aserción de abajo por accidente.
    _fijar_movimiento_reducido(engine, False)
    assert _la_carrera_anima_al_entrar(panel, qapp) is True

    _fijar_movimiento_reducido(engine, True)
    qapp.processEvents()
    assert panel.property("reducedMotion") is True
    assert _la_carrera_anima_al_entrar(panel, qapp) is False
    assert panel.findChild(QObject, "comparisonReducedMotionToggle") is None

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()
