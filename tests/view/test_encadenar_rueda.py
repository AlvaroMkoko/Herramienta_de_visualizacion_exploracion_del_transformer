"""La rueda pasa al área contenedora cuando la interna llegó a su tope."""

from __future__ import annotations

from pathlib import Path

import pytest
from PySide6.QtCore import QObject, QPoint, QPointF, Qt, QUrl
from PySide6.QtGui import QWheelEvent
from PySide6.QtQml import QQmlComponent, QQmlEngine
from PySide6.QtWidgets import QApplication

from viewmodel.encadenador_rueda import EncadenadorRueda

ROOT = Path(__file__).resolve().parents[2]

HOST = b"""\
import QtQuick
import QtQuick.Controls

ApplicationWindow {
    width: 400
    height: 400
    visible: true
    ScrollView {
        objectName: "externa"
        anchors.fill: parent
        contentWidth: availableWidth
        Column {
            width: 400
            Rectangle { width: 400; height: 100; color: "red" }
            ScrollView {
                objectName: "interna"
                width: 400
                height: 200
                contentWidth: availableWidth
                Rectangle { implicitWidth: 380; implicitHeight: 500; color: "green" }
            }
            Item {
                objectName: "zonaZoom"
                width: 400
                height: 200
                property int giros: 0
                MouseArea {
                    anchors.fill: parent
                    onWheel: function(wheel) { parent.giros += 1; wheel.accepted = true }
                }
            }
            Rectangle { width: 400; height: 900; color: "yellow" }
        }
    }
}
"""


@pytest.fixture
def ventana(qapp):
    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(HOST, QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "Rueda.qml")))
    assert component.status() != QQmlComponent.Status.Error, component.errorString()
    window = component.create()
    assert window is not None, component.errorString()
    encadenador = EncadenadorRueda(window)
    encadenador.instalar_en([window])
    # El gesto se decide por el reloj: en la prueba cada asentamiento lo termina
    # y se evita esperar la pausa real entre un gesto y el siguiente.
    encadenador.PAUSA_FIN_DE_GESTO_MS = 150
    for _ in range(5):
        qapp.processEvents()
    yield window, encadenador
    window.close()
    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def _flickable(window, nombre):
    return window.findChild(QObject, nombre).property("contentItem")


def _girar(qapp, qtbot, window, punto, delta, veces=1, pausa=30):
    for _ in range(veces):
        evento = QWheelEvent(
            QPointF(punto),
            QPointF(punto),
            QPoint(0, 0),
            QPoint(0, delta),
            Qt.MouseButton.NoButton,
            Qt.KeyboardModifier.NoModifier,
            Qt.ScrollPhase.NoScrollPhase,
            False,
        )
        evento.setTimestamp(_girar.reloj)
        _girar.reloj += pausa
        QApplication.sendEvent(window, evento)
        qtbot.wait(pausa)


_girar.reloj = 1000


def _punto_en(window, nombre):
    item = window.findChild(QObject, nombre)
    return item.mapToItem(None, QPointF(100, 40)).toPoint()


def test_la_interna_se_desplaza_primero_y_la_externa_no_se_mueve(qapp, qtbot, ventana):
    window, _ = ventana
    punto = _punto_en(window, "interna")

    _girar(qapp, qtbot, window, punto, -120)
    qtbot.waitUntil(lambda: _flickable(window, "interna").property("contentY") > 0)

    assert _flickable(window, "externa").property("contentY") == 0


def test_en_el_tope_el_gesto_siguiente_mueve_la_externa(qapp, qtbot, ventana):
    window, _ = ventana
    interna = _flickable(window, "interna")
    externa = _flickable(window, "externa")
    interna.setProperty("contentY", interna.property("contentHeight") - interna.height())
    qapp.processEvents()
    assert interna.property("atYEnd")

    _girar(qapp, qtbot, window, _punto_en(window, "interna"), -120)
    qtbot.waitUntil(lambda: externa.property("contentY") > 0)


def test_el_mismo_gesto_no_arrastra_a_la_externa_al_llegar_al_tope(qapp, qtbot, ventana):
    window, encadenador = ventana
    encadenador.PAUSA_FIN_DE_GESTO_MS = 100_000
    interna = _flickable(window, "interna")
    externa = _flickable(window, "externa")

    _girar(qapp, qtbot, window, _punto_en(window, "interna"), -120, veces=30)
    qtbot.waitUntil(lambda: interna.property("atYEnd"))

    assert externa.property("contentY") == 0


def test_hacia_arriba_tambien_encadena(qapp, qtbot, ventana):
    window, _ = ventana
    externa = _flickable(window, "externa")
    externa.setProperty("contentY", 50)
    qapp.processEvents()
    assert _flickable(window, "interna").property("atYBeginning")

    _girar(qapp, qtbot, window, _punto_en(window, "interna"), 120)
    qtbot.waitUntil(lambda: externa.property("contentY") < 50)


def test_quien_usa_la_rueda_por_su_cuenta_la_conserva(qapp, qtbot, ventana):
    window, _ = ventana
    zona = window.findChild(QObject, "zonaZoom")

    _girar(qapp, qtbot, window, _punto_en(window, "zonaZoom"), -120)

    assert zona.property("giros") == 1
    assert _flickable(window, "externa").property("contentY") == 0
