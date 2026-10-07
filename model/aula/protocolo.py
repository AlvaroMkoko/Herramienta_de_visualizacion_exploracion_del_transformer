"""Protocolo de mensajes entre la app del alumno y la del docente.

Cada mensaje es un objeto JSON con ``v`` (versión del protocolo) y ``tipo``.
El mismo formato viaja por WebSocket (opciones A y B) y se guarda dentro de los
archivos ``.tvclase`` (opción D), así que el transporte se puede cambiar sin
tocar la lógica de la clase.

Mensajes del alumno al docente:

* ``consulta``   {codigo}                       ¿Existe la clase? ¿Qué pide?
* ``hola``       {codigo, apodo, matricula, device_id, alumno_id?, token?}
* ``progreso``   {snapshot, generado_en}
* ``resultado``  {resultado}
* ``presencia``  {modulo_id, etapa}

Mensajes del docente al alumno:

* ``info_clase`` {clase}
* ``bienvenida`` {alumno_id, token, apodo, clase}
* ``en_espera``  {alumno_id, token, apodo, clase}
* ``rechazo``    {motivo, mensaje, sugerencia?}
* ``ack``        {resultados: [ids], progreso: bool}
* ``config_clase`` {clase}
* ``aviso``      {texto}
* ``renombrado`` {apodo}
* ``expulsado``  {mensaje}
* ``clase_finalizada`` {mensaje}
* ``sesion_reemplazada`` {mensaje}
"""

from __future__ import annotations

import json
from typing import Any

VERSION_PROTOCOLO = 1
VERSION_APLICACION = "0.1.0"

#: Puerto UDP fijo para descubrir al docente por broadcast.
PUERTO_DESCUBRIMIENTO = 47800
#: Primer puerto TCP que intenta abrir el docente; si está ocupado prueba los
#: siguientes y anuncia el elegido en la respuesta de descubrimiento.
PUERTO_WEBSOCKET = 47801
INTENTOS_PUERTO = 10

#: Un resultado completo pesa decenas de KB; 2 MB deja holgura y evita que un
#: mensaje malicioso llene la memoria del docente.
TAMANO_MAXIMO = 2 * 1024 * 1024

MENSAJES_ALUMNO = frozenset({"consulta", "hola", "progreso", "resultado", "presencia"})
MENSAJES_DOCENTE = frozenset(
    {
        "info_clase",
        "bienvenida",
        "en_espera",
        "rechazo",
        "ack",
        "config_clase",
        "aviso",
        "renombrado",
        "expulsado",
        "clase_finalizada",
        "sesion_reemplazada",
    }
)

# Motivos de rechazo: la interfaz del alumno decide qué hacer con cada uno.
CODIGO_INVALIDO = "codigo_invalido"
APODO_INVALIDO = "apodo_invalido"
APODO_EN_USO = "apodo_en_uso"
MATRICULA_REQUERIDA = "matricula_requerida"
EXPULSADO = "expulsado"
CLASE_FINALIZADA = "clase_finalizada"
DEMASIADOS_INTENTOS = "demasiados_intentos"
NO_UNIDO = "no_unido"
MENSAJE_INVALIDO = "mensaje_invalido"
VERSION_INCOMPATIBLE = "version_incompatible"


class ErrorProtocolo(ValueError):
    def __init__(self, motivo: str, mensaje: str) -> None:
        super().__init__(mensaje)
        self.motivo = motivo


def mensaje(tipo: str, **campos: Any) -> dict[str, Any]:
    return {"v": VERSION_PROTOCOLO, "tipo": tipo, **campos}


def codificar(contenido: dict[str, Any]) -> str:
    return json.dumps(contenido, ensure_ascii=False, separators=(",", ":"))


def decodificar(texto: str, permitidos: frozenset[str]) -> dict[str, Any]:
    """Valida forma, tamaño y versión. Lanza :class:`ErrorProtocolo`."""
    if len(texto) > TAMANO_MAXIMO:
        raise ErrorProtocolo(MENSAJE_INVALIDO, "El mensaje excede el tamaño permitido.")
    try:
        contenido = json.loads(texto)
    except ValueError as exc:
        raise ErrorProtocolo(MENSAJE_INVALIDO, "El mensaje no es JSON válido.") from exc
    if not isinstance(contenido, dict):
        raise ErrorProtocolo(MENSAJE_INVALIDO, "El mensaje debe ser un objeto JSON.")
    if contenido.get("v") != VERSION_PROTOCOLO:
        raise ErrorProtocolo(
            VERSION_INCOMPATIBLE,
            "La versión de la aplicación del alumno y la del docente no coinciden. "
            "Actualicen ambas a la misma versión.",
        )
    if contenido.get("tipo") not in permitidos:
        raise ErrorProtocolo(MENSAJE_INVALIDO, "Tipo de mensaje desconocido.")
    return contenido


# ---------------------------------------------------------------------------
# Descubrimiento por UDP
# ---------------------------------------------------------------------------

def datagrama_busqueda(huella: str) -> bytes:
    return codificar(mensaje("buscar", huella=huella)).encode("utf-8")


def datagrama_respuesta(huella: str, puerto: int, nombre_clase: str) -> bytes:
    return codificar(
        mensaje("aqui", huella=huella, puerto=int(puerto), nombre=nombre_clase)
    ).encode("utf-8")


def leer_datagrama(datos: bytes) -> dict[str, Any]:
    """Devuelve ``{}`` ante cualquier datagrama ajeno: el puerto es público y
    otras aplicaciones pueden enviar basura a él."""
    if len(datos) > 4096:
        return {}
    try:
        contenido = json.loads(datos.decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        return {}
    if not isinstance(contenido, dict) or contenido.get("v") != VERSION_PROTOCOLO:
        return {}
    if contenido.get("tipo") not in ("buscar", "aqui"):
        return {}
    return contenido
