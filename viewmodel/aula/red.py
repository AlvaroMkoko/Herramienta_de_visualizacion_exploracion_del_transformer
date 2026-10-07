"""Interfaces de red locales, para anunciar y buscar la clase.

El equipo del docente puede estar en dos redes a la vez (Wi-Fi de la escuela y
su propio hotspot). Por eso el servidor escucha en todas las interfaces y la
pantalla muestra todas las direcciones; el alumno, por su parte, envía el
broadcast por cada una de las suyas.
"""

from __future__ import annotations

from typing import Any

from PySide6.QtNetwork import QAbstractSocket, QHostAddress, QNetworkInterface


def _ipv4(direccion: QHostAddress) -> str:
    texto = direccion.toString()
    # Un socket de doble pila entrega IPv4 como ``::ffff:192.168.0.5``.
    return texto[7:] if texto.startswith("::ffff:") else texto


def interfaces_locales() -> list[dict[str, Any]]:
    """Interfaces IPv4 activas que no son loopback, con su broadcast."""
    filas: list[dict[str, Any]] = []
    banderas_requeridas = (
        QNetworkInterface.InterfaceFlag.IsUp | QNetworkInterface.InterfaceFlag.IsRunning
    )
    for interfaz in QNetworkInterface.allInterfaces():
        banderas = interfaz.flags()
        if (banderas & banderas_requeridas) != banderas_requeridas:
            continue
        if banderas & QNetworkInterface.InterfaceFlag.IsLoopBack:
            continue
        for entrada in interfaz.addressEntries():
            ip = entrada.ip()
            if ip.protocol() != QAbstractSocket.NetworkLayerProtocol.IPv4Protocol:
                continue
            texto_ip = _ipv4(ip)
            if texto_ip.startswith("169.254."):
                continue  # APIPA: la interfaz no obtuvo dirección
            broadcast = entrada.broadcast()
            filas.append(
                {
                    "nombre": interfaz.humanReadableName() or interfaz.name(),
                    "ip": texto_ip,
                    "broadcast": _ipv4(broadcast) if not broadcast.isNull() else "",
                    "hotspot": texto_ip.startswith("192.168.137."),
                }
            )
    return filas


def destinos_broadcast() -> list[str]:
    """Direcciones a las que el alumno envía la búsqueda.

    ``255.255.255.255`` en Windows sale sólo por la interfaz principal; los
    broadcast dirigidos de cada interfaz cubren el caso de varias redes.
    ``127.0.0.1`` permite probar docente y alumno en el mismo equipo.
    """
    destinos = ["255.255.255.255", "127.0.0.1"]
    for fila in interfaces_locales():
        if fila["broadcast"] and fila["broadcast"] not in destinos:
            destinos.append(fila["broadcast"])
    return destinos


def separar_direccion(texto: str, puerto_por_defecto: int) -> tuple[str, int]:
    """``"192.168.1.5:47801"`` → ``("192.168.1.5", 47801)``. Devuelve
    ``("", 0)`` si no es una dirección IPv4 válida."""
    limpio = str(texto or "").strip().replace("ws://", "").rstrip("/")
    host, _, puerto = limpio.partition(":")
    direccion = QHostAddress(host)
    if direccion.isNull() or direccion.protocol() != QAbstractSocket.NetworkLayerProtocol.IPv4Protocol:
        return "", 0
    try:
        numero = int(puerto) if puerto else puerto_por_defecto
    except ValueError:
        return "", 0
    if not 0 < numero < 65536:
        return "", 0
    return host, numero
