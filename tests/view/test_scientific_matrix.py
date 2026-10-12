"""Una matriz constante no se pinta con gradiente, y los enteros se leen como enteros.

Con mín == máx la escala de color no codifica nada: en el Módulo 1, la
«secuencia desplazada» [[BOS]] salía como un rectángulo azul saturado con el
pie «1.00e+5». La celda debe quedar neutra y con el número escrito.
"""

from __future__ import annotations

import os
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

import pytest
from PySide6.QtCore import Q_ARG, Q_RETURN_ARG, QMetaObject, QObject, QUrl
from PySide6.QtGui import QColor
from PySide6.QtQml import QJSValue, QQmlComponent, QQmlEngine
from PySide6.QtQuick import QQuickItem


ROOT = Path(__file__).resolve().parents[2]

HOST = b"""\
import QtQuick
import QtQuick.Controls
import "components" as Components
import "styles" as Style

ApplicationWindow {
    width: 600
    height: 400
    visible: true

    readonly property color neutral: Style.Theme.superficie_alterna
    readonly property color saturated: Style.Theme.escala_sec_4

    Components.ScientificMatrix {
        objectName: "matrixUnderTest"
        width: 400
        height: 200
    }
    Components.ModuleLaboratoryVisualization {
        objectName: "visualizationUnderTest"
        y: 200
        width: 600
        height: 200
    }
}
"""


def _errores(component: QQmlComponent) -> str:
    return "\n".join(error.toString() for error in component.errors())


def _valor(value):
    return value.toVariant() if isinstance(value, QJSValue) else value


def _invocar(objeto: QObject, metodo: str, argumento):
    resultado = QMetaObject.invokeMethod(
        objeto, metodo, Q_RETURN_ARG("QVariant"), Q_ARG("QVariant", argumento)
    )
    return _valor(resultado)


@pytest.fixture
def matriz(qapp):
    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(
        HOST, QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "ScientificMatrixHost.qml"))
    )
    assert component.status() != QQmlComponent.Status.Error, _errores(component)
    window = component.create()
    assert window is not None, _errores(component)
    qapp.processEvents()
    yield window
    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def _color(matrix: QObject, value) -> QColor:
    return QColor(_invocar(matrix, "colorFor", value))


@pytest.mark.parametrize(
    ("valores", "modo", "escala_local"),
    [
        ([[100278]], "sequential", False),  # [[BOS]] del Módulo 1
        ([[0.5, 0.5], [0.5, 0.5]], "diverging", True),
        ([[3.0, 3.0, 3.0]], "sequential", True),
    ],
)
def test_matriz_constante_no_se_pinta_con_gradiente(matriz, qapp, valores, modo, escala_local):
    matrix = matriz.findChild(QObject, "matrixUnderTest")
    matrix.setProperty("colorMode", modo)
    matrix.setProperty("localScale", escala_local)
    matrix.setProperty("matrix", valores)
    qapp.processEvents()

    assert matrix.property("constantValues") is True
    neutral = QColor(matriz.property("neutral"))
    assert _color(matrix, valores[0][0]) == neutral
    note = matrix.findChild(QQuickItem, "scientificMatrixConstantNote")
    assert note is not None and note.isVisible()
    assert "constante" in note.property("text")


def test_matriz_con_variacion_conserva_su_gradiente(matriz, qapp):
    matrix = matriz.findChild(QObject, "matrixUnderTest")
    matrix.setProperty("colorMode", "sequential")
    matrix.setProperty("localScale", True)
    matrix.setProperty("matrix", [[0.0, 1.0]])
    qapp.processEvents()

    assert matrix.property("constantValues") is False
    assert _color(matrix, 0.0) != _color(matrix, 1.0)
    note = matrix.findChild(QQuickItem, "scientificMatrixConstantNote")
    assert not note.isVisible()


def test_mascara_constante_conserva_su_color_categorico(matriz, qapp):
    # La máscara no es una escala: todo True sigue dibujándose como "visible".
    matrix = matriz.findChild(QObject, "matrixUnderTest")
    matrix.setProperty("colorMode", "mask")
    matrix.setProperty("matrix", [[True, True, True]])
    qapp.processEvents()

    assert matrix.property("constantValues") is False


def test_ids_de_token_no_se_pintan_con_gradiente_aunque_varien(matriz, qapp):
    # Un id es categórico: el 8921 no es "menos" que el 81641. Aunque la fila
    # no sea constante, el color no debe sugerir un orden.
    matrix = matriz.findChild(QObject, "matrixUnderTest")
    matrix.setProperty("colorMode", "sequential")
    matrix.setProperty("localScale", True)
    matrix.setProperty("valueKind", "token_ids")
    matrix.setProperty("matrix", [[8921, 81641, 70444]])
    qapp.processEvents()

    assert matrix.property("constantValues") is False
    assert matrix.property("discreteValues") is True
    neutral = QColor(matriz.property("neutral"))
    assert _color(matrix, 8921) == neutral
    assert _color(matrix, 81641) == neutral


def test_enteros_solo_cuando_el_dato_es_un_id(matriz, qapp):
    # Un valor continuo conserva sus decimales aunque caiga en un entero
    # exacto: en una herramienta de cálculo numérico, «1.0000» dice medida.
    matrix = matriz.findChild(QObject, "matrixUnderTest")
    visualization = matriz.findChild(QObject, "visualizationUnderTest")

    matrix.setProperty("valueKind", "continuous")
    qapp.processEvents()
    assert _invocar(matrix, "valueText", 1) == "1.000000"
    assert _invocar(matrix, "valueText", 0.25) == "0.250000"
    matrix.setProperty("valueKind", "token_ids")
    qapp.processEvents()
    assert _invocar(matrix, "valueText", 100278) == "100278"

    def formato(valor, tipo):
        return _valor(QMetaObject.invokeMethod(
            visualization, "formatNumber", Q_RETURN_ARG("QVariant"),
            Q_ARG("QVariant", valor), Q_ARG("QVariant", tipo),
        ))

    assert formato(100278, "token_ids") == "100278"
    assert formato(1, "continuous") == "1.0000"
    assert formato(12345.5, "continuous") == "1.23e+4"
    # Sin tipo declarado se asume continuo: nunca se pierden decimales.
    assert formato(2, None) == "2.0000"


SCREEN_HOST = b"""\
import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {
    width: 1200
    height: 800
    visible: false
    StackView { id: navigation; anchors.fill: parent }
    Screens.ModuleLaboratoryScreen {
        objectName: "screenUnderTest"
        anchors.fill: parent
        stackView: navigation
    }
}
"""


def test_dialogo_inspeccionar_escribe_ids_enteros_y_continuos_con_decimales(qapp):
    # Antes, un id ≥ 1000 caía en notación científica (1.0028e+5) antes de
    # llegar a la rama de enteros, y un continuo exacto perdía sus decimales.
    # La pantalla se monta sin mainViewModel: solo se usa su formateador, y
    # los TypeError de contexto nulo son ruido esperado (ver tests/CLAUDE.md).
    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(
        SCREEN_HOST,
        QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "InspectDialogHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errores(component)
    window = component.create()
    assert window is not None, _errores(component)
    try:
        qapp.processEvents()
        screen = window.findChild(QObject, "screenUnderTest")
        assert screen is not None

        def formato(valor, tipo):
            return _valor(QMetaObject.invokeMethod(
                screen, "formattedValue", Q_RETURN_ARG("QVariant"),
                Q_ARG("QVariant", valor), Q_ARG("QVariant", tipo),
            ))

        assert formato(100278, "token_ids") == "100278"
        assert formato(1, "continuous") == "1.000000"
        assert formato(0.5, "continuous") == "0.500000"
        assert formato(123456.75, "continuous") == "1.2346e+5"
        assert formato(True, "continuous") == "True"
    finally:
        window.deleteLater()
        engine.deleteLater()
        qapp.processEvents()


@pytest.mark.parametrize(("columnas", "caben"), [(3, True), (40, False)])
def test_celdas_estrechas_avisan_que_el_valor_esta_en_el_tooltip(
    matriz, qapp, columnas, caben
):
    # Sin escala de color el número es el único portador del dato: si no
    # cabe en la celda, la nota lo dice para no dejar un hueco mudo.
    matrix = matriz.findChild(QObject, "matrixUnderTest")
    matrix.setProperty("colorMode", "sequential")
    matrix.setProperty("valueKind", "token_ids")
    matrix.setProperty("matrix", [list(range(100, 100 + columnas))])
    qapp.processEvents()

    assert matrix.property("valuesFitInCells") is caben
    note = matrix.findChild(QQuickItem, "scientificMatrixConstantNote")
    assert note.isVisible()
    assert ("pasa el puntero" in note.property("text")) is not caben


GUIDE_HOST = b"""\
import QtQuick
import QtQuick.Controls
import "components" as Components

ApplicationWindow {
    width: 720
    height: 900
    visible: false

    Components.LaboratoryAnimationGuide {
        objectName: "guideUnderTest"
        anchors.fill: parent
        moduleId: "module_1"
        mode: "inference"
        steps: []
        step: ({})
    }
}
"""


def test_explicacion_no_promedia_ids_y_conserva_decimales_en_continuos(qapp):
    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(
        GUIDE_HOST, QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "GuideTextHost.qml"))
    )
    assert component.status() != QQmlComponent.Status.Error, _errores(component)
    window = component.create()
    assert window is not None, _errores(component)
    try:
        guide = window.findChild(QObject, "guideUnderTest")
        stats = {"mean": 50000.5, "min": 1.0, "max": 100278.0}

        guide.setProperty("panel", {
            "key": "token_ids", "title": "IDs", "shape": [1, 2], "full_length": 2,
            "value_kind": "token_ids", "stats": stats,
        })
        qapp.processEvents()
        texto = _valor(QMetaObject.invokeMethod(guide, "captureText", Q_RETURN_ARG("QVariant")))
        # La media de unos ids no significa nada: no se muestra.
        assert "ids de token: categóricos" in texto
        assert "\nmedia " not in texto and "50000" not in texto

        guide.setProperty("panel", {
            "key": "embedding", "title": "E", "shape": [1, 2], "full_length": 2,
            "value_kind": "continuous", "stats": stats,
        })
        qapp.processEvents()
        texto = _valor(QMetaObject.invokeMethod(guide, "captureText", Q_RETURN_ARG("QVariant")))
        assert "categóricos" not in texto
        # Un continuo exacto conserva decimales: mín. 1 se escribe 1.0000.
        assert "mín. 1.0000" in texto
    finally:
        window.deleteLater()
        engine.deleteLater()
        qapp.processEvents()
