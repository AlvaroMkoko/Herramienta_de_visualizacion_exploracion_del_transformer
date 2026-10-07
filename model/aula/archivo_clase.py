"""Archivos ``.tvclase``: el respaldo sin red (opción D).

Contienen exactamente lo mismo que viaja por WebSocket (snapshot de progreso y
resultados) más la ficha del alumno. Si el alumno ya se había unido por red,
el archivo va firmado con HMAC usando su token, y el docente comprueba que
nadie lo editó a mano. Un alumno que nunca tuvo conexión no tiene token: su
archivo se importa marcado como *sin verificar* para que el docente decida.
"""

from __future__ import annotations

import hashlib
import hmac
import json
from pathlib import Path
from typing import Any

from ._json import escribir_json, leer_json

FORMATO = "tvclase"
VERSION_ARCHIVO = 1
EXTENSION = ".tvclase"


class ArchivoInvalido(ValueError):
    pass


def _canonico(cuerpo: dict[str, Any]) -> bytes:
    return json.dumps(
        cuerpo, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def firmar(token: str, cuerpo: dict[str, Any]) -> str:
    return hmac.new(str(token).encode("utf-8"), _canonico(cuerpo), hashlib.sha256).hexdigest()


def crear_paquete(
    alumno: dict[str, Any],
    clase: dict[str, Any],
    snapshot: dict[str, Any],
    resultados: list[dict[str, Any]],
    generado_en: str,
    token: str = "",
) -> dict[str, Any]:
    cuerpo = {
        "formato": FORMATO,
        "version": VERSION_ARCHIVO,
        "generado_en": generado_en,
        "clase": {
            "class_id": clase.get("class_id", ""),
            "codigo": clase.get("codigo", ""),
            "nombre": clase.get("nombre", ""),
        },
        "alumno": {
            "alumno_id": alumno.get("alumno_id", ""),
            "apodo": alumno.get("apodo", ""),
            "matricula": alumno.get("matricula", ""),
            "device_id": alumno.get("device_id", ""),
        },
        "progreso": snapshot,
        "resultados": resultados,
    }
    return {**cuerpo, "firma": firmar(token, cuerpo) if token else ""}


def guardar_paquete(ruta: Path, paquete: dict[str, Any]) -> Path:
    ruta = Path(ruta)
    if ruta.suffix.lower() != EXTENSION:
        ruta = ruta.with_name(ruta.name + EXTENSION)
    escribir_json(ruta, paquete)
    return ruta


def leer_paquete(ruta: Path) -> dict[str, Any]:
    paquete = leer_json(Path(ruta), None)
    if not isinstance(paquete, dict) or paquete.get("formato") != FORMATO:
        raise ArchivoInvalido("El archivo no es un avance de clase (.tvclase).")
    if paquete.get("version") != VERSION_ARCHIVO:
        raise ArchivoInvalido("El archivo se creó con una versión distinta de la aplicación.")
    if not isinstance(paquete.get("alumno"), dict) or not isinstance(paquete.get("clase"), dict):
        raise ArchivoInvalido("El archivo está incompleto.")
    if not isinstance(paquete.get("progreso"), dict) or not isinstance(
        paquete.get("resultados"), list
    ):
        raise ArchivoInvalido("El archivo está incompleto.")
    return paquete


def firma_valida(paquete: dict[str, Any], token: str) -> bool:
    firma = str(paquete.get("firma", ""))
    if not firma or not token:
        return False
    cuerpo = {k: v for k, v in paquete.items() if k != "firma"}
    return hmac.compare_digest(firmar(token, cuerpo), firma)
