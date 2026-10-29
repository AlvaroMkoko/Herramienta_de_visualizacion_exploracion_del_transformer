"""Resumen ligero de los resultados de un módulo, para guardarlo como archivo.

Es el respaldo cuando la red del aula falla y el archivo que el estudiante sube
a la encuesta de la página web. Por eso pesa pocos kilobytes y no lleva
enunciados ni respuestas escritas: sólo qué reactivo era, de qué concepto y
cuánto obtuvo. La página toma de aquí los puntajes y deja fuera la sección
``estudiante``, que sólo sirve al docente.

Funciones puras, sin Qt: el ViewModel decide dónde se guarda.
"""

from __future__ import annotations

from datetime import datetime, timezone
import json
from pathlib import Path
from typing import Any

FORMATO = "tvresultados"
VERSION_FORMATO = 1
EXTENSION = ".tvresultados.json"


def _evaluacion(resultado: dict[str, Any]) -> dict[str, Any] | None:
    if not resultado:
        return None
    return {
        "porcentaje": float(resultado.get("percentage", 0.0)),
        "puntaje": float(resultado.get("puntaje", 0.0)),
        "maximo": float(resultado.get("maximo", 0.0)),
        "instrumento": int(resultado.get("instrument_version", 0) or 0),
        "completado_en": str(resultado.get("completed_at", "")),
        "duracion_s": round(float(resultado.get("duration_seconds", 0.0) or 0.0), 1),
        "reactivos": [
            {
                "codigo": str(item.get("code", "")),
                "concepto": str(item.get("concept_id", "")),
                "nivel": str(item.get("difficulty", "")),
                "bloom": str(item.get("bloom_level", "")),
                "puntaje": round(float(item.get("puntaje", 0.0)), 4),
                "maximo": float(item.get("maximo", 1.0)),
            }
            for item in resultado.get("answers", [])
        ],
    }


def _estudiante(
    pre: dict[str, Any], post: dict[str, Any], apodo: str
) -> dict[str, str]:
    """Quién es, para el docente. En modo individual el resultado no trae
    nombre; si el alumno se unió a una clase, su apodo lo identifica."""
    datos = {"id": "", "nombre": "", "matricula": "", "apodo": str(apodo or "")}
    for resultado in (post, pre):
        alumno = resultado.get("student") if resultado else None
        if isinstance(alumno, dict) and alumno:
            datos.update(
                id=str(alumno.get("id", "")),
                nombre=str(alumno.get("nombre", "")),
                matricula=str(alumno.get("matricula", "")),
            )
            break
    return datos


def resumen_modulo(
    resultados: dict[str, Any],
    interaccion: dict[str, Any],
    apodo: str = "",
    generado_en: str | None = None,
) -> dict[str, Any]:
    """Arma el archivo a partir de ``CourseController.moduleResults``."""
    pre = resultados.get("pre") or {}
    post = resultados.get("post") or {}
    return {
        "formato": FORMATO,
        "version": VERSION_FORMATO,
        "generado_en": generado_en
        or datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "estudiante": _estudiante(pre, post, apodo),
        "modulo": {
            "id": str(resultados.get("module_id", "")),
            "titulo": str(resultados.get("module_title", "")),
        },
        "pre": _evaluacion(pre),
        "post": _evaluacion(post),
        "comparable": bool(resultados.get("comparable")),
        "diferencia": resultados.get("delta_percentage"),
        "ganancia_normalizada": resultados.get("normalized_gain"),
        "intentos": dict(resultados.get("attempts") or {}),
        "conceptos": [
            {
                "id": str(fila.get("id", "")),
                "nombre": str(fila.get("name", "")),
                "pre": fila.get("pre_percentage") if fila.get("assessed_pre") else None,
                "post": fila.get("post_percentage") if fila.get("assessed_post") else None,
            }
            for fila in resultados.get("concepts", [])
        ],
        "actividad": {
            "recorrido_comprobaciones": int(interaccion.get("guided_checks_attempted", 0)),
            "recorrido_correctas_primer_intento": int(
                interaccion.get("guided_checks_first_correct", 0)
            ),
            "laboratorio_ciclos": int(interaccion.get("lab_cycles", 0)),
            "laboratorio_predicciones_correctas": int(
                interaccion.get("lab_predictions_correct", 0)
            ),
            "laboratorio_ejecuciones": int(interaccion.get("lab_runs", 0)),
        },
    }


def guardar(ruta: Path, resumen: dict[str, Any]) -> Path:
    """Escribe el resumen y devuelve la ruta final (con su extensión)."""
    ruta = Path(ruta)
    if not ruta.name.endswith(EXTENSION):
        ruta = ruta.with_name(ruta.name.removesuffix(".json") + EXTENSION)
    ruta.parent.mkdir(parents=True, exist_ok=True)
    ruta.write_text(
        json.dumps(resumen, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
    )
    return ruta
