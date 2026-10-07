"""Transporte del docente: WebSocket para los datos y UDP para ser encontrado.

Todo corre en el event loop de Qt (sin hilos): los sockets de QtNetwork son
asíncronos y avisan con señales, igual que el resto del ViewModel. La lógica
de la clase vive en :class:`model.aula.SesionClase`; aquí sólo se traduce
entre bytes y llamadas.
"""

from __future__ import annotations

import uuid

from PySide6.QtCore import QObject, QTimer, Signal
from PySide6.QtNetwork import QAbstractSocket, QHostAddress, QUdpSocket
from PySide6.QtWebSockets import QWebSocket, QWebSocketServer

from model.aula import protocolo as p
from model.aula.codigo_clase import huella_codigo
from model.aula.sesion_clase import TODOS, Envio, SesionClase

from .red import _ipv4


class ServidorAulaLan(QObject):
    #: Llegó o se fue un alumno, o cambiaron sus datos.
    actividad = Signal()

    def __init__(
        self,
        sesion: SesionClase,
        puerto_websocket: int = p.PUERTO_WEBSOCKET,
        puerto_descubrimiento: int = p.PUERTO_DESCUBRIMIENTO,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self._sesion = sesion
        self._puerto_inicial = puerto_websocket
        self._puerto_udp = puerto_descubrimiento
        self._servidor = QWebSocketServer(
            "TransformerVisualizer", QWebSocketServer.SslMode.NonSecureMode, self
        )
        self._servidor.newConnection.connect(self._nueva_conexion)
        self._udp = QUdpSocket(self)
        self._udp.readyRead.connect(self._leer_datagramas)
        self._sockets: dict[str, QWebSocket] = {}
        self._descubrimiento = False

    # ------------------------------------------------------------------
    # Arranque y parada
    # ------------------------------------------------------------------

    def iniciar(self) -> str:
        """Devuelve ``""`` si todo salió bien o un mensaje para el docente."""
        cualquiera = QHostAddress(QHostAddress.SpecialAddress.AnyIPv4)
        puertos = (
            [0]
            if self._puerto_inicial == 0
            else range(self._puerto_inicial, self._puerto_inicial + p.INTENTOS_PUERTO)
        )
        if not any(self._servidor.listen(cualquiera, puerto) for puerto in puertos):
            return (
                "No se pudo abrir un puerto para la clase: "
                + self._servidor.errorString()
            )
        self._descubrimiento = self._udp.bind(
            cualquiera,
            self._puerto_udp,
            QAbstractSocket.BindFlag.ShareAddress
            | QAbstractSocket.BindFlag.ReuseAddressHint,
        )
        return ""

    def detener(self) -> None:
        for conexion_id in list(self._sockets):
            self._cerrar(conexion_id)
        self._servidor.close()
        self._udp.close()
        self._descubrimiento = False

    @property
    def puerto(self) -> int:
        return int(self._servidor.serverPort()) if self._servidor.isListening() else 0

    @property
    def descubrimiento_activo(self) -> bool:
        return self._descubrimiento

    @property
    def escuchando(self) -> bool:
        return self._servidor.isListening()

    # ------------------------------------------------------------------
    # WebSocket
    # ------------------------------------------------------------------

    def _nueva_conexion(self) -> None:
        while self._servidor.hasPendingConnections():
            socket = self._servidor.nextPendingConnection()
            conexion_id = uuid.uuid4().hex
            socket.setMaxAllowedIncomingMessageSize(p.TAMANO_MAXIMO)
            self._sockets[conexion_id] = socket
            self._sesion.conectar(conexion_id, _ipv4(socket.peerAddress()))
            # Métodos del servidor y no lambdas: Qt corta estas conexiones si
            # el servidor se destruye antes de que el socket termine de
            # cerrarse, y nadie llama a un objeto ya borrado.
            socket.setObjectName(conexion_id)
            socket.textMessageReceived.connect(self._al_texto)
            socket.binaryMessageReceived.connect(self._al_binario)
            socket.disconnected.connect(self._al_desconectar_socket)
            socket.disconnected.connect(socket.deleteLater)

    def _al_texto(self, texto: str) -> None:
        conexion_id = self.sender().objectName()
        self.enviar(self._sesion.procesar(conexion_id, texto))
        self.actividad.emit()

    def _al_binario(self, _datos) -> None:
        self._cerrar(self.sender().objectName())

    def _al_desconectar_socket(self) -> None:
        self._desconectado(self.sender().objectName())

    def _desconectado(self, conexion_id: str) -> None:
        if self._sockets.pop(conexion_id, None) is None:
            return
        self._sesion.desconectar(conexion_id)
        self.actividad.emit()

    def _cerrar(self, conexion_id: str) -> None:
        socket = self._sockets.get(conexion_id)
        if socket is None:
            return
        # Se olvida ya para no enviarle nada más, pero el socket sigue vivo
        # hasta que ``close`` termine: así sale el último mensaje (por
        # ejemplo, el aviso de expulsión) antes del cierre. ``disconnected``
        # lo destruye; si el otro extremo no contesta, se aborta.
        self._desconectado(conexion_id)
        socket.close()
        QTimer.singleShot(3000, socket, socket.abort)

    def enviar(self, envios: list[Envio]) -> None:
        cerrar: list[str] = []
        for envio in envios:
            destinos = self._sesion.destinatarios() if envio.destino == TODOS else [envio.destino]
            texto = p.codificar(envio.mensaje)
            for conexion_id in destinos:
                socket = self._sockets.get(conexion_id)
                if socket is None:
                    continue
                socket.sendTextMessage(texto)
                socket.flush()
                if envio.cerrar:
                    cerrar.append(conexion_id)
        for conexion_id in cerrar:
            self._cerrar(conexion_id)

    # ------------------------------------------------------------------
    # Descubrimiento
    # ------------------------------------------------------------------

    def _leer_datagramas(self) -> None:
        huella = huella_codigo(self._sesion.repo.codigo)
        while self._udp.hasPendingDatagrams():
            datagrama = self._udp.receiveDatagram(4096)
            contenido = p.leer_datagrama(bytes(datagrama.data()))
            if contenido.get("tipo") != "buscar" or contenido.get("huella") != huella:
                continue
            if self._sesion.repo.clase.get("finalizada"):
                continue
            # Se responde a la dirección de origen: el sistema operativo elige
            # la interfaz correcta, aunque el docente esté en varias redes.
            self._udp.writeDatagram(
                p.datagrama_respuesta(huella, self.puerto, self._sesion.repo.clase.get("nombre", "")),
                datagrama.senderAddress(),
                datagrama.senderPort(),
            )
