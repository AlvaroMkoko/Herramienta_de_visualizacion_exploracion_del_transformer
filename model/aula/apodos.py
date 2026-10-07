"""Validación de apodos al estilo Kahoot.

El apodo sólo sirve para que el docente reconozca a cada alumno en la sala. La
identidad real es el ``alumno_id`` con su token, así que un apodo puede
cambiarse sin perder el progreso.
"""

from __future__ import annotations

import json
import re
import unicodedata
from pathlib import Path
from typing import Iterable

LONGITUD_MINIMA = 2
LONGITUD_MAXIMA = 20
_PERMITIDOS = re.compile(r"^[\w\- ]+$", re.UNICODE)


class ApodoInvalido(ValueError):
    """El mensaje es apto para mostrarse tal cual al alumno."""


def limpiar_apodo(texto: str) -> str:
    return " ".join(str(texto or "").split())


def clave_apodo(texto: str) -> str:
    """Forma canónica para comparar: ``Ána  López`` y ``ana lopez`` chocan."""
    normalizado = unicodedata.normalize("NFKD", limpiar_apodo(texto))
    sin_acentos = "".join(c for c in normalizado if not unicodedata.combining(c))
    return sin_acentos.casefold()


def cargar_palabras_bloqueadas(ruta: Path | None) -> frozenset[str]:
    if ruta is None or not ruta.is_file():
        return frozenset()
    try:
        with ruta.open("r", encoding="utf-8") as origen:
            datos = json.load(origen)
    except (OSError, ValueError):
        return frozenset()
    palabras = datos.get("palabras", []) if isinstance(datos, dict) else datos
    return frozenset(clave_apodo(p) for p in palabras if isinstance(p, str) and p.strip())


def _contiene_bloqueada(clave: str, bloqueadas: Iterable[str]) -> bool:
    compacta = re.sub(r"[\s_\-]+", "", clave)
    tokens = set(re.split(r"[\s_\-]+", clave))
    for palabra in bloqueadas:
        # Las palabras cortas sólo se buscan completas: buscarlas como
        # subcadena rechazaría apodos inocentes que las contienen.
        if len(palabra) >= 4 and palabra in compacta:
            return True
        if palabra in tokens:
            return True
    return False


def validar_apodo(texto: str, bloqueadas: Iterable[str] = ()) -> str:
    """Devuelve el apodo limpio o lanza :class:`ApodoInvalido`."""
    apodo = limpiar_apodo(texto)
    if len(apodo) < LONGITUD_MINIMA:
        raise ApodoInvalido(f"El apodo debe tener al menos {LONGITUD_MINIMA} caracteres.")
    if len(apodo) > LONGITUD_MAXIMA:
        raise ApodoInvalido(f"El apodo puede tener como máximo {LONGITUD_MAXIMA} caracteres.")
    if not _PERMITIDOS.match(apodo):
        raise ApodoInvalido("Usa sólo letras, números, espacios, guion o guion bajo.")
    if _contiene_bloqueada(clave_apodo(apodo), bloqueadas):
        raise ApodoInvalido("Elige otro apodo: éste no está permitido en clase.")
    return apodo


def sugerir_apodo(apodo: str, ocupados: Iterable[str]) -> str:
    """``Ana`` ocupado → ``Ana2``; respeta la longitud máxima."""
    claves = {clave_apodo(o) for o in ocupados}
    base = limpiar_apodo(apodo) or "Alumno"
    if clave_apodo(base) not in claves:
        return base
    numero = 2
    while True:
        sufijo = str(numero)
        candidato = base[: LONGITUD_MAXIMA - len(sufijo)].rstrip() + sufijo
        if clave_apodo(candidato) not in claves:
            return candidato
        numero += 1
