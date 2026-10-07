"""Código de clase: lo que el docente dicta y el alumno escribe.

Se usa el alfabeto de Crockford (base 32 sin I, L, O ni U). Al normalizar, las
letras que se confunden con dígitos se convierten en ellos: si el pizarrón dice
``K0P-1QX`` y el alumno escribe ``kop-iqx``, el código sigue siendo válido.

Seis caracteres dan unos mil millones de combinaciones. No es un secreto fuerte,
pero no tiene que serlo: la sesión limita los intentos fallidos por conexión y
la clase sólo vive dentro de la red del aula.
"""

from __future__ import annotations

import hashlib
import secrets

ALFABETO = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
LONGITUD = 6
_EQUIVALENCIAS = str.maketrans({"O": "0", "I": "1", "L": "1"})


def generar_codigo() -> str:
    return "".join(secrets.choice(ALFABETO) for _ in range(LONGITUD))


def normalizar_codigo(texto: str) -> str:
    """Mayúsculas, sin guiones ni espacios y con equivalencias aplicadas.

    Devuelve ``""`` si el resultado no es un código bien formado.
    """
    compacto = "".join(c for c in str(texto or "").upper() if c.isalnum())
    compacto = compacto.translate(_EQUIVALENCIAS)
    if len(compacto) != LONGITUD or any(c not in ALFABETO for c in compacto):
        return ""
    return compacto


def formatear_codigo(codigo: str) -> str:
    """``K7P4QX`` → ``K7P-4QX``, más fácil de dictar."""
    mitad = len(codigo) // 2
    return f"{codigo[:mitad]}-{codigo[mitad:]}" if codigo else ""


def huella_codigo(codigo: str) -> str:
    """Huella que viaja en el broadcast de descubrimiento.

    El código no se difunde en claro: cualquiera en la red escucha el
    broadcast, y con la huella sólo puede confirmar un código que ya conoce.
    """
    normalizado = normalizar_codigo(codigo)
    return hashlib.sha256(f"tvaula:{normalizado}".encode()).hexdigest()[:16]
