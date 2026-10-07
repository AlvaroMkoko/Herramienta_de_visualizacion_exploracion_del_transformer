"""Transporte del alumno: buscar al docente por UDP y hablarle por WebSocket.

No conoce las reglas de la clase; sólo entrega mensajes ya validados al
controlador del alumno, que decide qué hacer con ellos.
"""

from __future__ import annotations

from PySide6.QtCore import QObject, QTimer, QUrl, Signal
from PySide6.QtNetwork import QAbstractSocket, QHostAddress, QUdpSocket
from PySide6.QtWebSockets import QWebSocket

from model.aula import protocolo as p
from model.aula.codigo_clase import huella_codigo

from .red import _ipv4, destinos_broadcast


class ClienteAulaLan(QObject):
    encontrado = Signal(str, int, str)  # host, puerto, nombre de la clase
    noEncontrado = Signal()
    conectado = Signal()
    desconectado = Signal()
    mensajeRecibido = Signal("QVariantMap")
    fallo = Signal(str)

    def __init__(
        self,
        puerto_descubrimiento: int = p.PUERTO_DESCUBRIMIENTO,
        espera_busqueda_ms: int = 900,
        intentos_busqueda: int = 3,
        espera_conexion_ms: int = 5000,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self._puerto_udp = puerto_descubrimiento
        self._intentos_max = intentos_busqueda
        self._udp = QUdpSocket(self)
        self._udp.readyRead.connect(self._leer_respuestas)
        self._huella = ""
        self._intentos = 0
        self._temporizador_busqueda = QTimer(self)
        self._temporizador_busqueda.setInterval(espera_busqueda_ms)
        self._temporizador_busqueda.timeout.connect(self._reintentar_busqueda)

        self._socket = QWebSocket()
        self._socket.setParent(self)
        self._socket.setMaxAllowedIncomingMessageSize(p.TAMANO_MAXIMO)
        self._socket.connected.connect(self._al_conectar)
        self._socket.disconnected.connect(self._al_desconectar)
        self._socket.textMessageReceived.connect(self._recibir)
        self._abriendo = False
        self._temporizador_conexion = QTimer(self)
        self._temporizador_conexion.setSingleShot(True)
        self._temporizador_conexion.setInterval(espera_conexion_ms)
        self._temporizador_conexion.timeout.connect(self._conexion_vencida)

    # ------------------------------------------------------------------
    # Búsqueda
    # ------------------------------------------------------------------

    def buscar(self, codigo: str) -> None:
        self.cancelar_busqueda()
        if self._udp.state() != QAbstractSocket.SocketState.BoundState:
            self._udp.bind(QHostAddress(QHostAddress.SpecialAddress.AnyIPv4), 0)
        self._huella = huella_codigo(codigo)
        self._intentos = 0
        self._enviar_busqueda()
        self._temporizador_busqueda.start()

    def cancelar_busqueda(self) -> None:
        self._temporizador_busqueda.stop()
        self._huella = ""

    def _enviar_busqueda(self) -> None:
        self._intentos += 1
        datos = p.datagrama_busqueda(self._huella)
        for destino in destinos_broadcast():
            self._udp.writeDatagram(datos, QHostAddress(destino), self._puerto_udp)

    def _reintentar_busqueda(self) -> None:
        if not self._huella:
            self._temporizador_busqueda.stop()
            return
        if self._intentos >= self._intentos_max:
            self.cancelar_busqueda()
            self.noEncontrado.emit()
            return
        self._enviar_busqueda()

    def _leer_respuestas(self) -> None:
        while self._udp.hasPendingDatagrams():
            datagrama = self._udp.receiveDatagram(4096)
            contenido = p.leer_datagrama(bytes(datagrama.data()))
            if (
                not self._huella
                or contenido.get("tipo") != "aqui"
                or contenido.get("huella") != self._huella
            ):
                continue
            try:
                puerto = int(contenido.get("puerto", 0))
            except (TypeError, ValueError):
                continue
            if not 0 < puerto < 65536:
                continue
            self.cancelar_busqueda()
            self.encontrado.emit(
                _ipv4(datagrama.senderAddress()), puerto, str(contenido.get("nombre", ""))
            )
            return

    # ------------------------------------------------------------------
    # Conexión
    # ------------------------------------------------------------------

    @property
    def esta_conectado(self) -> bool:
        return self._socket.state() == QAbstractSocket.SocketState.ConnectedState

    def conectar(self, host: str, puerto: int) -> None:
        self.cerrar()
        self._abriendo = True
        self._temporizador_conexion.start()
        self._socket.open(QUrl(f"ws://{host}:{int(puerto)}"))

    def cerrar(self) -> None:
        self._temporizador_conexion.stop()
        self._abriendo = False
        if self._socket.state() != QAbstractSocket.SocketState.UnconnectedState:
            # Un cierre pedido por nosotros no es una caída: sin señales, el
            # controlador no programa una reconexión que nadie pidió.
            self._socket.blockSignals(True)
            self._socket.abort()
            self._socket.blockSignals(False)

    def enviar(self, contenido: dict) -> bool:
        if not self.esta_conectado:
            return False
        self._socket.sendTextMessage(p.codificar(contenido))
        return True

    def _al_conectar(self) -> None:
        self._temporizador_conexion.stop()
        self._abriendo = False
        self.conectado.emit()

    def _al_desconectar(self) -> None:
        self._temporizador_conexion.stop()
        if self._abriendo:
            # Nunca llegó a conectarse: puerto cerrado, firewall o IP errónea.
            self._abriendo = False
            self.fallo.emit("No se pudo abrir la conexión con el equipo del docente.")
            return
        self.desconectado.emit()

    def _conexion_vencida(self) -> None:
        if self._abriendo:
            self._abriendo = False
            self._socket.abort()
            self.fallo.emit(
                "El equipo del docente no respondió. Revisa que estén en la misma red "
                "y que el firewall permita la aplicación."
            )

    def _recibir(self, texto: str) -> None:
        try:
            contenido = p.decodificar(texto, p.MENSAJES_DOCENTE)
        except p.ErrorProtocolo as exc:
            self.fallo.emit(str(exc))
            return
        self.mensajeRecibido.emit(contenido)
