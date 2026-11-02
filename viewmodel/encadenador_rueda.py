"""Encadena la rueda del ratón entre áreas desplazables anidadas.

``ScrollView`` hereda de ``Control``, que acepta la rueda aunque su ``Flickable``
ya esté en el tope: el evento nunca llega al contenedor y la página sólo se mueve
sacando el puntero del área interna. Con ``wheelEnabled: false`` tampoco sirve,
porque también apaga el desplazamiento propio. Por eso se resuelve aquí, una vez,
y no en cada uno de los ``ScrollView`` de la aplicación.

La conducta es la de los navegadores (*scroll chaining* con *latching*): mientras
dura un gesto, la rueda se queda con el área donde empezó, aunque llegue al tope;
sólo el gesto siguiente pasa al área que la contiene. Así, girar rápido sobre una
lista no arrastra de golpe a toda la página al terminarla.
"""

from __future__ import annotations

from typing import Iterable

from PySide6.QtCore import QElapsedTimer, QEvent, QObject, QPointF
from PySide6.QtGui import QGuiApplication, QWheelEvent, QWindow
from PySide6.QtQuick import QQuickItem, QQuickWindow


def _es_flickable(item: QQuickItem) -> bool:
    meta = item.metaObject()
    while meta is not None:
        if meta.className() == "QQuickFlickable":
            return True
        meta = meta.superClass()
    return False


def _areas_bajo(item: QQuickItem, escena: QPointF) -> list[QQuickItem] | None:
    """Flickables bajo el punto, del más interno al más externo.

    Devuelve ``None`` si el punto no cae sobre ``item`` ni sobre sus hijos.
    """
    if not item.isVisible():
        return None
    local = item.mapFromScene(escena)
    dentro = item.contains(local)
    if item.clip() and not dentro:
        return None
    # A igual z, el último hijo se dibuja encima: se recorre al revés.
    hijos = sorted(
        enumerate(item.childItems()), key=lambda par: (par[1].z(), par[0]), reverse=True
    )
    for _, hijo in hijos:
        areas = _areas_bajo(hijo, escena)
        if areas is not None:
            return areas + ([item] if _es_flickable(item) else [])
    if dentro:
        return [item] if _es_flickable(item) else []
    return None


def _puede_moverse(area: QQuickItem, delta_y: int) -> bool:
    if not area.property("interactive"):
        return False
    if float(area.property("contentHeight")) <= area.height():
        return False
    return not area.property("atYBeginning" if delta_y > 0 else "atYEnd")


class EncadenadorRueda(QObject):
    """Filtro de eventos de una ventana QML; ver el docstring del módulo."""

    # Una pausa mayor que ésta termina el gesto. Coincide con lo que tarda en
    # asentarse el desplazamiento animado de un Flickable tras una muesca.
    PAUSA_FIN_DE_GESTO_MS = 350

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._reloj = QElapsedTimer()
        self._reloj.start()
        self._ultimo_evento_ms = -self.PAUSA_FIN_DE_GESTO_MS
        self._area_del_gesto: QQuickItem | None = None
        self._enviando = False

    def instalar_en(self, ventanas: Iterable[QWindow]) -> None:
        for ventana in ventanas:
            ventana.installEventFilter(self)

    def instalar_en_toda_ventana(self, app: QGuiApplication) -> None:
        """También en las ventanas que se abren después (guía desacoplada)."""
        self.instalar_en(app.allWindows())
        app.focusWindowChanged.connect(self._vigilar_ventana)

    def _vigilar_ventana(self, ventana: QWindow | None) -> None:
        # installEventFilter sobre un filtro ya instalado sólo lo reordena.
        if ventana is not None:
            ventana.installEventFilter(self)

    def eventFilter(self, objeto: QObject, evento: QEvent) -> bool:
        if (
            self._enviando
            or evento.type() != QEvent.Type.Wheel
            or not isinstance(objeto, QQuickWindow)
        ):
            return False
        delta_y = evento.angleDelta().y() or evento.pixelDelta().y()
        if delta_y == 0 or evento.angleDelta().x() != 0:
            return False
        return self._repartir(objeto, evento, delta_y)

    def _repartir(self, ventana: QQuickWindow, evento: QWheelEvent, delta_y: int) -> bool:
        ahora = self._reloj.elapsed()
        gesto_continua = ahora - self._ultimo_evento_ms < self.PAUSA_FIN_DE_GESTO_MS
        self._ultimo_evento_ms = ahora

        areas = _areas_bajo(ventana.contentItem(), evento.position()) or []
        if not areas:
            self._area_del_gesto = None
            return False
        if gesto_continua and self._area_del_gesto in areas:
            destino = self._area_del_gesto
        else:
            destino = next((area for area in areas if _puede_moverse(area, delta_y)), None)
            self._area_del_gesto = destino
        if destino is None:
            return False
        if destino is areas[0]:
            # Lo más interno se atiende por la vía normal de Qt: respeta a quien
            # usa la rueda por su cuenta dentro del área (zoom de la nube 3D).
            return False
        if destino is not self._area_del_gesto or not _puede_moverse(destino, delta_y):
            return True
        return self._entregar(destino, evento)

    def _entregar(self, destino: QQuickItem, evento: QWheelEvent) -> bool:
        local = destino.mapFromScene(evento.position())
        copia = QWheelEvent(
            local,
            evento.globalPosition(),
            evento.pixelDelta(),
            evento.angleDelta(),
            evento.buttons(),
            evento.modifiers(),
            evento.phase(),
            evento.inverted(),
        )
        copia.setTimestamp(evento.timestamp())
        self._enviando = True
        try:
            QGuiApplication.sendEvent(destino, copia)
        finally:
            self._enviando = False
        return True
