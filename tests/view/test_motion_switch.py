"""Pruebas del interruptor global de movimiento reducido."""

from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import Q_ARG, Q_RETURN_ARG, QMetaObject, QObject, QPointF, Qt, QUrl
from PySide6.QtQml import QJSValue, QQmlComponent, QQmlEngine
from PySide6.QtTest import QTest


QML_ROOT = Path(__file__).resolve().parents[2] / "view" / "qml"
HOST = b"""\
import QtQuick
import QtQuick.Controls
import "components" as Components
import "styles" as Style

ApplicationWindow {
    width: 400
    height: 200
    visible: true
    function setGlobalReducedMotion(value) { Style.Theme.movimientoReducido = value }
    function globalReducedMotion() { return Style.Theme.movimientoReducido }
    // Accessible.name es una propiedad adjunta: desde Python no se lee con
    // property(), asi que el host la expone. (Sin acentos: HOST es bytes.)
    function accessibleName() { return interruptor.Accessible.name }

    Components.MotionSwitch { id: interruptor; anchors.centerIn: parent }
}
"""


def _errores(component: QQmlComponent) -> str:
    return "\n".join(error.toString() for error in component.errors())


def _tema_reducido(window) -> bool:
    valor = QMetaObject.invokeMethod(window, "globalReducedMotion", Q_RETURN_ARG("QVariant"))
    return bool(valor.toVariant() if isinstance(valor, QJSValue) else valor)


def _nombre_accesible(window) -> str:
    valor = QMetaObject.invokeMethod(window, "accessibleName", Q_RETURN_ARG("QVariant"))
    return str(valor.toVariant() if isinstance(valor, QJSValue) else valor)


def _clic(window, item, qapp) -> None:
    centro = item.mapToScene(QPointF(item.width() / 2, item.height() / 2))
    QTest.mouseClick(
        window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, centro.toPoint()
    )
    qapp.processEvents()


def test_el_interruptor_escribe_el_tema_y_anuncia_la_accion(qapp):
    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(HOST, QUrl.fromLocalFile(str(QML_ROOT / "MotionSwitchHost.qml")))
    window = component.create()
    assert window is not None, _errores(component)
    qapp.processEvents()
    interruptor = window.findChild(QObject, "motionSwitch")
    assert interruptor is not None

    QMetaObject.invokeMethod(window, "setGlobalReducedMotion", Q_ARG("QVariant", False))
    qapp.processEvents()
    assert interruptor.property("checked") is False
    # Como ThemeSwitch: el nombre accesible anuncia la acción, no el estado.
    assert _nombre_accesible(window) == "Reducir movimiento"

    # Clic real: es lo que haría el estudiante, y lo que rompería un enlace.
    _clic(window, interruptor, qapp)
    assert _tema_reducido(window) is True
    assert interruptor.property("checked") is True
    assert _nombre_accesible(window) == "Restaurar movimiento"

    _clic(window, interruptor, qapp)
    assert _tema_reducido(window) is False
    assert interruptor.property("checked") is False

    # Tras las pulsaciones, el interruptor sigue al tema si otro lo cambia.
    QMetaObject.invokeMethod(window, "setGlobalReducedMotion", Q_ARG("QVariant", True))
    qapp.processEvents()
    assert interruptor.property("checked") is True

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()
