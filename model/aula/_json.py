"""Lectura y escritura atómica de JSON para los archivos del aula.

Repite el patrón de ``ResultsRepository`` y ``ModuleProgressRepository``:
escribir a un temporal, forzar a disco y reemplazar. Un corte de luz a mitad de
la clase deja el archivo anterior intacto en vez de uno truncado.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


def leer_json(ruta: Path, por_defecto: Any) -> Any:
    """Nunca lanza: un archivo ausente o corrupto devuelve ``por_defecto``."""
    if not ruta.is_file():
        return por_defecto
    try:
        with ruta.open("r", encoding="utf-8") as origen:
            return json.load(origen)
    except (OSError, ValueError, TypeError):
        return por_defecto


def escribir_json(ruta: Path, contenido: Any) -> None:
    ruta.parent.mkdir(parents=True, exist_ok=True)
    temporal = ruta.with_suffix(ruta.suffix + ".tmp")
    try:
        with temporal.open("w", encoding="utf-8") as destino:
            json.dump(contenido, destino, ensure_ascii=False, indent=2)
            destino.flush()
            os.fsync(destino.fileno())
        os.replace(temporal, ruta)
    finally:
        if temporal.exists():
            try:
                temporal.unlink()
            except OSError:
                pass
