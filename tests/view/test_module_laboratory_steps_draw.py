"""Cada paso de cada laboratorio dibuja algo o dice por qué no.

Las pruebas de ``test_module_laboratory_specializations.py`` validan el
contrato visual con el estado falseado a mano. Esta recorre los ocho módulos
en los dos modos con el resultado real del controlador y exige, paso por paso,
que la vista especializada y la fórmula en acción produzcan contenido
dibujable o un estado ``unavailable`` explícito. Nació del Módulo 1 en blanco:
el panel llegaba con su matriz, pero la vista la leía como vacía.
"""

from __future__ import annotations

import os
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

import pytest
from PySide6.QtCore import Q_ARG, Q_RETURN_ARG, QMetaObject, QObject, QUrl
from PySide6.QtQml import QJSValue, QQmlComponent, QQmlEngine
from PySide6.QtQuick import QQuickItem

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from viewmodel.formula_demos import _without_data
from viewmodel.module_laboratory_controller import ModuleLaboratoryController


ROOT = Path(__file__).resolve().parents[2]

HOST = b"""\
import QtQuick
import QtQuick.Controls
import "components" as Components

ApplicationWindow {
    width: 1300
    height: 1400
    visible: true

    Column {
        anchors.fill: parent
        Components.ModuleLaboratoryVisualization {
            objectName: "stepsVisualizationUnderTest"
            width: parent.width
            height: 760
            showContextChrome: false
        }
        Components.FormulaAnimationScene {
            objectName: "stepsFormulaUnderTest"
            width: parent.width
            height: 600
            reducedMotion: true
        }
    }
}
"""

MODULES = [f"module_{index}" for index in range(1, 9)]


class _TokenizerDePrueba:
    vocab_size = 36

    def encode(self, _text):
        return [3, 7, 9, 11]

    def decode(self, ids):
        return f"t{ids[0]}"


def _errores(component: QQmlComponent) -> str:
    return "\n".join(error.toString() for error in component.errors())


def _valor(value):
    return value.toVariant() if isinstance(value, QJSValue) else value


@pytest.fixture
def laboratorio(qapp):
    config = ConfiguracionTransformer(
        tamano_vocabulario=40,
        dimension_modelo=16,
        num_cabezas=4,
        num_capas=2,
        dimension_ff=32,
        longitud_maxima_secuencia=12,
        dropout=0.0,
        id_token_relleno=0,
    )
    # Controlador suelto, sin MainViewModel: así la prueba no toca el
    # progreso real del curso.
    controller = ModuleLaboratoryController()
    controller.set_model(Transformer(config), _TokenizerDePrueba())

    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(
        HOST, QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "StepsDrawHost.qml"))
    )
    assert component.status() != QQmlComponent.Status.Error, _errores(component)
    window = component.create()
    assert window is not None, _errores(component)
    qapp.processEvents()
    yield controller, window
    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


@pytest.mark.parametrize("mode", ["inference", "training"])
@pytest.mark.parametrize("module_id", MODULES)
def test_cada_paso_dibuja_o_explica_por_que_no(laboratorio, qapp, module_id, mode):
    controller, window = laboratorio
    errores: list[str] = []
    controller.error.connect(errores.append)
    controller.explore(module_id, "texto", mode, 0, 0, 0, 0.8, 5, 0.9, True)
    assert not errores, errores
    result = controller.result
    steps = result["steps"]
    demos = result["formula_demos"]
    assert steps

    visual = window.findChild(QObject, "stepsVisualizationUnderTest")
    scene = window.findChild(QObject, "stepsFormulaUnderTest")
    loader = window.findChild(QQuickItem, "moduleLabSpecializedLoader")
    unavailable = window.findChild(QQuickItem, "moduleLabLoaderUnavailable")
    formula_loader = window.findChild(QQuickItem, "formulaAnimationLoader")
    assert None not in (visual, scene, loader, unavailable, formula_loader)
    visual.setProperty("moduleId", module_id)
    visual.setProperty("mode", mode)
    visual.setProperty("analysis", result)

    for index, step in enumerate(steps):
        where = f"{module_id}/{mode}/{step['id']}"
        visual.setProperty("step", step)
        visual.setProperty("stepIndex", index)
        demo = demos.get(step["id"])
        scene.setProperty("step", step)
        scene.setProperty("demo", demo)
        qapp.processEvents()

        # Vista especializada: hay un item cargado y el aviso de respaldo no
        # tuvo que aparecer.
        item = loader.property("item")
        assert item is not None, f"{where}: el Loader quedó sin vista"
        assert not unavailable.isVisible(), where

        # Una tarjeta que recibe un panel real tiene que dibujar su matriz.
        for card in item.findChildren(QQuickItem, "moduleLabTokenizationMatrix"):
            panel = _valor(card.property("panel")) or {}
            if panel.get("key") and panel.get("matrix"):
                matrix = _valor(card.property("matrix")) or []
                assert len(matrix) > 0, (
                    f"{where}: el panel «{panel['key']}» trae matriz y la vista "
                    "la dibuja vacía"
                )

        # Fórmula en acción: un demo con datos o marcado unavailable.
        assert demo is not None, f"{where}: paso sin demo"
        if demo["kind"] == "unavailable":
            assert str(demo.get("caption", "")).strip(), where
        else:
            assert not _without_data(demo), f"{where}: demo sin datos"
        assert formula_loader.property("item") is not None, where


def _invocar(objeto: QObject, metodo: str, argumento):
    resultado = QMetaObject.invokeMethod(
        objeto, metodo, Q_RETURN_ARG("QVariant"), Q_ARG("QVariant", argumento)
    )
    return _valor(resultado)


def test_values_de_un_arreglo_no_se_confunde_con_la_clave_de_datos(laboratorio):
    # En JS todo arreglo tiene Array.prototype.values (una función de length
    # 0). Si un helper la toma por la clave de datos `values`, la matriz se
    # dibuja vacía sin ningún error: es lo que dejó en blanco el Módulo 1.
    _controller, window = laboratorio
    visual = window.findChild(QObject, "stepsVisualizationUnderTest")
    scene = window.findChild(QObject, "stepsFormulaUnderTest")

    assert _invocar(visual, "matrixFrom", [[1, 2], [3, 4]]) == [[1, 2], [3, 4]]
    assert _invocar(visual, "matrixFrom", {"matrix": [[5, 6]]}) == [[5, 6]]
    assert _invocar(visual, "matrixFrom", {"values": [[7, 8]]}) == [[7, 8]]
    assert _invocar(visual, "matrixFrom", {"valores": [9, 10]}) == [[9, 10]]

    assert _invocar(scene, "valuesOf", {"values": [1.5, -2.0]}) == [1.5, -2.0]
    assert _invocar(scene, "valuesOf", [1.5, -2.0]) == []
    assert _invocar(scene, "valuesOf", {}) == []


def test_tarjeta_explica_un_panel_que_llega_sin_matriz_dibujable(laboratorio, qapp):
    # Si el panel existe pero su matriz no se puede leer, la tarjeta no debe
    # pedir "ejecuta el paso": eso ocultó el fallo del Módulo 1.
    _controller, window = laboratorio
    visual = window.findChild(QObject, "stepsVisualizationUnderTest")
    paso = {"id": "ids", "title": "IDs", "visual": "token_ids", "panel_key": "token_ids"}
    visual.setProperty("moduleId", "module_1")
    visual.setProperty("step", paso)

    def mensaje():
        qapp.processEvents()
        loader = window.findChild(QQuickItem, "moduleLabSpecializedLoader")
        item = loader.property("item")
        assert item is not None
        cards = item.findChildren(QQuickItem, "moduleLabTokenizationMatrix")
        assert len(cards) == 1
        texto = cards[0].findChild(QQuickItem, "moduleLabMatrixMissing")
        assert texto is not None
        # Se devuelve también el item: si su envoltorio de PySide se libera,
        # el texto queda "already deleted" al leerlo.
        return item, texto

    visual.setProperty(
        "analysis",
        {"panels": [{"key": "token_ids", "title": "IDs", "matrix": []}]},
    )
    _item, texto = mensaje()
    assert texto.isVisible()
    assert "«token_ids»" in texto.property("text")
    assert "sin una matriz" in texto.property("text")

    # Sin panel, el aviso sigue siendo el de "ejecuta el paso".
    visual.setProperty("analysis", {"panels": []})
    _item, texto = mensaje()
    assert texto.isVisible()
    assert texto.property("text").startswith("Ejecuta el paso")

    # Con matriz dibujable, el aviso desaparece.
    visual.setProperty(
        "analysis",
        {"panels": [{"key": "token_ids", "title": "IDs", "matrix": [[3, 7, 9]]}]},
    )
    _item, texto = mensaje()
    assert not texto.isVisible()


def _items_visuales(raiz: QQuickItem, nombre: str) -> list[QQuickItem]:
    # Los items de un Repeater cuelgan del árbol visual (childItems), no
    # siempre del árbol de QObject: findChildren no los encuentra.
    encontrados = []
    pendientes = [raiz]
    while pendientes:
        actual = pendientes.pop()
        if actual.objectName() == nombre:
            encontrados.append(actual)
        pendientes.extend(actual.childItems())
    return encontrados


@pytest.mark.parametrize("mode", ["inference", "training"])
def test_modulo_1_dibuja_ids_como_fichas_y_no_como_mapa_de_calor(laboratorio, qapp, mode):
    # El paso «Tokens especiales» era un rectángulo azul liso: [[BOS]] como
    # mapa de calor de una celda. Los ids se leen como fichas «texto · id».
    controller, window = laboratorio
    controller.explore("module_1", "texto", mode, 0, 0, 0, 0.8, 5, 0.9, True)
    result = controller.result
    visual = window.findChild(QObject, "stepsVisualizationUnderTest")
    visual.setProperty("moduleId", "module_1")
    visual.setProperty("mode", mode)
    visual.setProperty("analysis", result)
    specials = next(step for step in result["steps"] if step["id"] == "specials")
    visual.setProperty("step", specials)
    qapp.processEvents()

    loader = window.findChild(QQuickItem, "moduleLabSpecializedLoader")
    item = loader.property("item")
    assert item is not None
    grid = item.findChild(QQuickItem, "moduleLabTokenIdGrid")
    assert grid is not None and grid.isVisible()
    chips = _items_visuales(grid, "moduleLabTokenIdChip")
    textos = [chip.property("chipText") for chip in chips]
    assert any(texto.startswith("BOS · ") for texto in textos), textos
    heatmap = item.findChild(QQuickItem, "moduleLabTensorMatrix")
    assert heatmap is not None and not heatmap.isVisible()
