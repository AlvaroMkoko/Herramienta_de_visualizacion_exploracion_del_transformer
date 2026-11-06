"""
Tamaño de la ventana de posiciones que conservan las trazas visuales.

Durante la inferencia, las subcapas guardan solo las últimas posiciones para
no inflar el snapshot que cruza hacia QML. El laboratorio modular, en cambio,
deja elegir cualquier token del texto, así que necesita la secuencia completa:
con una ventana de tres posiciones, el índice absoluto del token elegido caía
fuera de ella (desde la cuarta posición) o, peor, señalaba a otro token.

Se usa una ``ContextVar`` porque el laboratorio corre en su propio hilo y no
debe ensanchar las trazas de una inferencia que ocurra en otro.
"""

from __future__ import annotations

from collections.abc import Iterator
from contextlib import contextmanager
from contextvars import ContextVar

_secuencia_completa: ContextVar[bool] = ContextVar(
    "traza_visual_secuencia_completa", default=False
)


def inicio_ventana(longitud: int, ventana: int) -> int:
    """Primera posición conservada de una secuencia de ``longitud`` tokens."""
    if _secuencia_completa.get():
        return 0
    return max(0, longitud - ventana)


@contextmanager
def conservar_secuencia_completa() -> Iterator[None]:
    """Dentro del bloque, las trazas visuales guardan todas las posiciones."""
    marca = _secuencia_completa.set(True)
    try:
        yield
    finally:
        _secuencia_completa.reset(marca)
