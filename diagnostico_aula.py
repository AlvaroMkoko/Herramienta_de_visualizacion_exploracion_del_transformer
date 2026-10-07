"""Diagnóstico de red del aula (fase 0): ¿se ven el docente y el alumno?

Usa exactamente el mismo protocolo y los mismos sockets que la aplicación,
pero sin interfaz ni datos reales: la clase de prueba vive en una carpeta
temporal que se borra al terminar.

    python diagnostico_aula.py interfaces
    python diagnostico_aula.py docente
    python diagnostico_aula.py alumno K7P-4QX
    python diagnostico_aula.py alumno K7P-4QX --direccion 192.168.1.20:47801

Se corre ``docente`` en un equipo y ``alumno`` en otro. Cada paso imprime si
funcionó y, si no, qué suele causarlo.
"""

from __future__ import annotations

import argparse
import signal
import sys
import tempfile
import time
from pathlib import Path

from PySide6.QtCore import QCoreApplication, QTimer

from model.aula import protocolo as p
from model.aula.codigo_clase import formatear_codigo, normalizar_codigo
from model.aula.repositorio_clase import RepositorioClase
from model.aula.sesion_clase import SesionClase
from viewmodel.aula.cliente_lan import ClienteAulaLan
from viewmodel.aula.red import interfaces_locales, separar_direccion
from viewmodel.aula.servidor_lan import ServidorAulaLan


def _ok(texto: str) -> None:
    print(f"  [OK]    {texto}", flush=True)


def _falla(texto: str, causa: str = "") -> None:
    print(f"  [FALLA] {texto}", flush=True)
    if causa:
        print(f"          Posible causa: {causa}", flush=True)


def _app() -> QCoreApplication:
    app = QCoreApplication.instance() or QCoreApplication(sys.argv)
    # Qt bloquea Ctrl+C mientras corre su event loop; un temporizador
    # periódico devuelve el control a Python para que lo atienda.
    signal.signal(signal.SIGINT, lambda *_: app.quit())
    latido = QTimer(app)
    latido.timeout.connect(lambda: None)
    latido.start(200)
    return app


def comando_interfaces() -> int:
    filas = interfaces_locales()
    if not filas:
        _falla("No hay interfaces IPv4 activas.", "El equipo no está conectado a ninguna red.")
        return 1
    print("Interfaces de red activas:")
    for fila in filas:
        extra = "  (probable hotspot de Windows)" if fila["hotspot"] else ""
        print(f"  - {fila['nombre']}: {fila['ip']}  broadcast {fila['broadcast'] or '—'}{extra}")
    return 0


def comando_docente(args) -> int:
    app = _app()
    carpeta = Path(tempfile.mkdtemp(prefix="tvaula_diag_"))
    repo = RepositorioClase.crear(carpeta, "Diagnóstico de red")
    sesion = SesionClase(repo)
    servidor = ServidorAulaLan(sesion, args.puerto, p.PUERTO_DESCUBRIMIENTO)
    error = servidor.iniciar()
    print("Docente de prueba")
    if error:
        _falla(error, "Otro programa usa los puertos o el sistema los bloquea.")
        return 1
    _ok(f"Servidor WebSocket escuchando en el puerto {servidor.puerto}")
    if servidor.descubrimiento_activo:
        _ok(f"Respondiendo búsquedas UDP en el puerto {p.PUERTO_DESCUBRIMIENTO}")
    else:
        _falla(
            f"No se pudo escuchar el puerto UDP {p.PUERTO_DESCUBRIMIENTO}",
            "Otra copia de la aplicación lo ocupa. La conexión por dirección sigue funcionando.",
        )
    print()
    print(f"  Código de clase:  {formatear_codigo(repo.codigo)}")
    for fila in interfaces_locales():
        print(f"  Dirección:        {fila['ip']}:{servidor.puerto}   ({fila['nombre']})")
    print()
    print("  Si Windows pregunta por el firewall, permite el acceso en redes privadas")
    print("  Y públicas. Esperando alumnos... (Ctrl+C para terminar)")

    vistos: set[str] = set()

    def informar() -> None:
        for ficha in repo.alumnos():
            if ficha["alumno_id"] not in vistos:
                vistos.add(ficha["alumno_id"])
                _ok(f"Se unió «{ficha['apodo']}»")

    servidor.actividad.connect(informar)
    try:
        app.exec()
    finally:
        servidor.detener()
    print(f"\nTerminado. Alumnos que se unieron: {len(vistos)}")
    return 0


def comando_alumno(args) -> int:
    app = _app()
    codigo = normalizar_codigo(args.codigo)
    if not codigo:
        _falla("El código no es válido: son 6 caracteres, por ejemplo K7P-4QX.")
        return 2
    cliente = ClienteAulaLan(espera_busqueda_ms=700, intentos_busqueda=4)
    estado = {"salida": 1, "inicio": time.monotonic()}

    def terminar(salida: int) -> None:
        estado["salida"] = salida
        cliente.cerrar()
        app.quit()

    def conectar(host: str, puerto: int) -> None:
        print(f"  ...     Abriendo WebSocket con {host}:{puerto}")
        cliente.conectar(host, puerto)

    def al_encontrar(host: str, puerto: int, nombre: str) -> None:
        demora = (time.monotonic() - estado["inicio"]) * 1000
        _ok(f"Docente encontrado por broadcast en {host}:{puerto} («{nombre}», {demora:.0f} ms)")
        conectar(host, puerto)

    def al_no_encontrar() -> None:
        _falla(
            "Nadie respondió a la búsqueda por broadcast.",
            "Redes distintas, Wi-Fi con aislamiento de clientes, firewall del docente "
            "o código incorrecto. Prueba con --direccion IP:PUERTO.",
        )
        terminar(1)

    def al_conectar() -> None:
        _ok("WebSocket abierto")
        cliente.enviar(p.mensaje("consulta", codigo=codigo))

    def al_fallar(texto: str) -> None:
        _falla(
            texto,
            "El firewall del docente bloquea el puerto, la IP cambió o el Wi-Fi aísla "
            "a los clientes entre sí.",
        )
        terminar(1)

    def al_recibir(mensaje: dict) -> None:
        tipo = mensaje.get("tipo")
        if tipo == "info_clase":
            _ok(f"La clase respondió: «{mensaje['clase'].get('nombre', '')}»")
            cliente.enviar(
                p.mensaje(
                    "hola",
                    codigo=codigo,
                    apodo=args.apodo,
                    matricula=args.matricula,
                    device_id="diagnostico",
                )
            )
        elif tipo in ("bienvenida", "en_espera"):
            _ok(f"Unido como «{mensaje.get('apodo')}». La red del aula funciona.")
            terminar(0)
        elif tipo == "rechazo":
            _falla(f"El docente rechazó la unión: {mensaje.get('mensaje')}")
            terminar(1)

    cliente.encontrado.connect(al_encontrar)
    cliente.noEncontrado.connect(al_no_encontrar)
    cliente.conectado.connect(al_conectar)
    cliente.fallo.connect(al_fallar)
    cliente.mensajeRecibido.connect(al_recibir)

    print(f"Alumno de prueba buscando la clase {formatear_codigo(codigo)}")
    if args.direccion:
        host, puerto = separar_direccion(args.direccion, p.PUERTO_WEBSOCKET)
        if not host:
            _falla("La dirección no es válida. Ejemplo: 192.168.1.20:47801")
            return 2
        QTimer.singleShot(0, lambda: conectar(host, puerto))
    else:
        QTimer.singleShot(0, lambda: cliente.buscar(codigo))
    QTimer.singleShot(20000, lambda: (_falla("Tiempo agotado."), terminar(1)))
    app.exec()
    return estado["salida"]


def main() -> int:
    # Sin esto, al redirigir la salida a un archivo los mensajes llegan
    # tarde o nunca si el proceso se interrumpe.
    sys.stdout.reconfigure(line_buffering=True)
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="comando", required=True)
    sub.add_parser("interfaces", help="Lista las redes de este equipo")
    docente = sub.add_parser("docente", help="Abre una clase de prueba")
    docente.add_argument("--puerto", type=int, default=p.PUERTO_WEBSOCKET)
    alumno = sub.add_parser("alumno", help="Busca y se une a la clase de prueba")
    alumno.add_argument("codigo")
    alumno.add_argument("--direccion", default="", help="IP:PUERTO para omitir la búsqueda")
    alumno.add_argument("--apodo", default="Diagnostico")
    alumno.add_argument("--matricula", default="")
    args = parser.parse_args()
    if args.comando == "interfaces":
        _app()
        return comando_interfaces()
    if args.comando == "docente":
        comando_interfaces()
        print()
        return comando_docente(args)
    return comando_alumno(args)


if __name__ == "__main__":
    sys.exit(main())
