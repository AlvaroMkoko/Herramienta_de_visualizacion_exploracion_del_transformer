"""Pruebas del panel de preferencias globales de main.qml."""

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
    // Accessible.name es una propiedad adjunta: desde Python no se lee con
    // property(), asi que el host la expone. (Sin acentos: HOST es bytes.)
    function accessibleName(item) { return item.Accessible.name }
    function panelOpacity() { var panel = panelItem(); return panel ? panel.opacity : -1 }
    function panelItem() {
        for (var i = 0; i < menu.data.length; ++i)
            if (menu.data[i].objectName === "preferencesPanel")
                return menu.data[i]
        return null
    }

    Components.PreferencesMenu {
        id: menu
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


def _invocar(window, metodo, *args):
    return _como_python(
        QMetaObject.invokeMethod(
            window, metodo, Q_RETURN_ARG("QVariant"), *[Q_ARG("QVariant", a) for a in args]
        )
    )


def _clic(window, item, qapp) -> None:
    centro = item.mapToScene(QPointF(item.width() / 2, item.height() / 2))
    QTest.mouseClick(
        window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, centro.toPoint()
    )
    qapp.processEvents()


def _crear(qapp, reducido: bool):
    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(HOST, QUrl.fromLocalFile(str(QML_ROOT / "PreferencesHost.qml")))
    window = component.create()
    assert window is not None, _errores(component)
    QMetaObject.invokeMethod(window, "setGlobalReducedMotion", Q_ARG("QVariant", reducido))
    qapp.processEvents()
    # El componente se devuelve para que el recolector no destruya la ventana.
    return engine, component, window, window.findChild(QQuickItem, "preferencesButton")


def _cerrar(engine, window, qapp) -> None:
    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_el_panel_abre_con_los_dos_interruptores_y_cierra_con_escape(qapp):
    engine, _component, window, boton = _crear(qapp, reducido=True)
    assert boton is not None
    assert _invocar(window, "accessibleName", boton) == "Abrir preferencias"

    _clic(window, boton, qapp)
    assert boton.property("panelOpen") is True
    assert _invocar(window, "accessibleName", boton) == "Cerrar preferencias"
    tema = window.findChild(QQuickItem, "themeSwitch")
    movimiento = window.findChild(QQuickItem, "motionSwitch")
    assert tema is not None and tema.property("visible") is True
    assert movimiento is not None and movimiento.property("visible") is True
    # El foco entra al panel al abrirlo.
    assert tema.property("activeFocus") is True

    QTest.keyClick(window, Qt.Key.Key_Escape)
    qapp.processEvents()
    assert boton.property("panelOpen") is False
    # Y vuelve al botón al cerrarlo.
    assert boton.property("activeFocus") is True

    _cerrar(engine, window, qapp)


def test_pulsar_el_boton_con_el_panel_abierto_lo_cierra(qapp):
    engine, _component, window, boton = _crear(qapp, reducido=True)
    _clic(window, boton, qapp)
    assert boton.property("panelOpen") is True
    # Una pulsación sobre el botón no puede cerrar y reabrir el panel.
    _clic(window, boton, qapp)
    assert boton.property("panelOpen") is False
    _cerrar(engine, window, qapp)


def test_la_apertura_obedece_el_movimiento_reducido(qapp):
    """Abrir el panel es una animación de entrada: el movimiento reducido la apaga."""
    # Control: con movimiento, el panel aún no es opaco justo después de abrir.
    engine, _component, window, boton = _crear(qapp, reducido=False)
    assert boton.property("openDuration") > 0
    _clic(window, boton, qapp)
    assert _invocar(window, "panelOpacity") < 1
    _cerrar(engine, window, qapp)

    engine, _component, window, boton = _crear(qapp, reducido=True)
    assert boton.property("openDuration") == 0
    _clic(window, boton, qapp)
    assert _invocar(window, "panelOpacity") == 1
    _cerrar(engine, window, qapp)
