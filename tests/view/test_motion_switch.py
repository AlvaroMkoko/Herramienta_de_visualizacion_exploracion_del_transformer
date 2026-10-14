"""Pruebas del interruptor global de movimiento reducido.

Vive dentro del panel de preferencias de main.qml: para pulsarlo, como haría
el estudiante, primero hay que abrir el panel.
"""

from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import Q_ARG, Q_RETURN_ARG, QMetaObject, QObject, QPointF, Qt, QUrl
from PySide6.QtQml import QJSValue, QQmlComponent, QQmlEngine
from PySide6.QtQuick import QQuickItem
from PySide6.QtTest import QTest


QML_ROOT = Path(__file__).resolve().parents[2] / "view" / "qml"
HOST = b"""\
import QtQuick
import QtQuick.Controls
import "components" as Components
import "styles" as Style

ApplicationWindow {
    width: 480
    height: 320
    visible: true
    function setGlobalReducedMotion(value) { Style.Theme.movimientoReducido = value }
    function globalReducedMotion() { return Style.Theme.movimientoReducido }
    // Accessible.name es una propiedad adjunta: desde Python no se lee con
    // property(), asi que el host la expone. (Sin acentos: HOST es bytes.)
    function accessibleName(item) { return item.Accessible.name }

    Components.PreferencesMenu {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
    }
}
"""


def _errores(component: QQmlComponent) -> str:
    return "\n".join(error.toString() for error in component.errors())


def _como_python(valor):
    return valor.toVariant() if isinstance(valor, QJSValue) else valor


def _tema_reducido(window) -> bool:
    return bool(
        _como_python(
            QMetaObject.invokeMethod(window, "globalReducedMotion", Q_RETURN_ARG("QVariant"))
        )
    )


def _nombre_accesible(window, item) -> str:
    return str(
        _como_python(
            QMetaObject.invokeMethod(
                window, "accessibleName", Q_RETURN_ARG("QVariant"), Q_ARG("QVariant", item)
            )
        )
    )


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

    QMetaObject.invokeMethod(window, "setGlobalReducedMotion", Q_ARG("QVariant", False))
    qapp.processEvents()

    # El interruptor ya no está en la esquina: se llega abriendo el panel.
    boton = window.findChild(QQuickItem, "preferencesButton")
    assert boton is not None
    _clic(window, boton, qapp)
    assert boton.property("panelOpen") is True
    interruptor = window.findChild(QQuickItem, "motionSwitch")
    assert interruptor is not None

    assert interruptor.property("checked") is False
    # Como ThemeSwitch: el nombre accesible anuncia la acción, no el estado.
    assert _nombre_accesible(window, interruptor) == "Reducir movimiento"

    # Clic real: es lo que haría el estudiante, y lo que rompería un enlace.
    _clic(window, interruptor, qapp)
    assert _tema_reducido(window) is True
    assert interruptor.property("checked") is True
    assert _nombre_accesible(window, interruptor) == "Restaurar movimiento"

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
