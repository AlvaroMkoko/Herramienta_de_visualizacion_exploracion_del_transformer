"""Cálculos del panel docente a partir de lo que envían los alumnos.

Reproduce las reglas de ``CourseController`` (etapas y estado de cada módulo)
sobre datos recibidos: el snapshot de progreso del alumno y sus resultados.
Vive en el Modelo para que también pueda usarlo un servidor sin Qt.
"""

from __future__ import annotations

import csv
import io
from statistics import mean
from typing import Any, Iterable

ETAPAS = ("pretest", "guided", "laboratory", "posttest", "results")
UMBRAL_REPASO = 70.0


def _ultimo(resultados: Iterable[dict[str, Any]], modulo_id: str, tipo: str) -> dict[str, Any]:
    elegido: dict[str, Any] = {}
    for resultado in resultados:
        if (
            str(resultado.get("module_id", "")) == modulo_id
            and resultado.get("assessment_type") == tipo
        ):
            elegido = resultado  # el repositorio conserva orden cronológico
    return elegido


def estado_modulo(
    modulo_id: str, snapshot: dict[str, Any], resultados: list[dict[str, Any]]
) -> dict[str, Any]:
    estado = (snapshot.get("modules") or {}).get(modulo_id) or {}
    pre = _ultimo(resultados, modulo_id, "pre")
    post = _ultimo(resultados, modulo_id, "post")
    hechas = {
        "pretest": bool(pre),
        "guided": bool(estado.get("guided_completed")),
        "laboratory": bool(estado.get("laboratory_completed")),
        "posttest": bool(post),
        "results": bool(estado.get("results_viewed")),
    }
    completadas = sum(hechas.values())
    if hechas["results"]:
        status = (
            "review_recommended"
            if float(post.get("percentage", 0)) < UMBRAL_REPASO
            else "completed"
        )
    elif completadas:
        status = "in_progress"
    else:
        status = "not_started"
    etapa_actual = next((e for e in ETAPAS if not hechas[e]), "completed")
    return {
        "module_id": modulo_id,
        "status": status,
        "completed_stages": completadas,
        "progress_percent": round(completadas * 100 / len(ETAPAS)),
        "current_stage": etapa_actual,
        "has_pre": bool(pre),
        "has_post": bool(post),
        "pre_percentage": float(pre.get("percentage", 0)) if pre else None,
        "post_percentage": float(post.get("percentage", 0)) if post else None,
    }


def resumen_alumno(
    modulo_ids: list[str], snapshot: dict[str, Any], resultados: list[dict[str, Any]]
) -> dict[str, Any]:
    modulos = [estado_modulo(m, snapshot, resultados) for m in modulo_ids]
    total = len(modulo_ids) * len(ETAPAS)
    hechas = sum(m["completed_stages"] for m in modulos)
    return {
        "modules": modulos,
        "global_percent": round(hechas * 100 / total) if total else 0,
        "completed_modules": sum(
            m["status"] in ("completed", "review_recommended") for m in modulos
        ),
        "current_module_id": str(snapshot.get("current_module_id", "")),
    }


def analisis_modulo(
    modulo: dict[str, Any], alumnos: list[tuple[dict[str, Any], list[dict[str, Any]]]]
) -> dict[str, Any]:
    """Promedios pre/post y errores frecuentes de un módulo para toda la clase.

    ``alumnos`` es una lista de ``(ficha_alumno, resultados_del_alumno)``.
    El cambio promedio sólo se calcula con alumnos que tienen ambos tests:
    promediar pre de unos con post de otros mezclaría grupos distintos.
    """
    modulo_id = modulo["id"]
    conceptos = {c["id"]: c.get("title", c["id"]) for c in modulo.get("concepts", [])}
    pres: list[float] = []
    posts: list[float] = []
    pares: list[float] = []
    errores_concepto: dict[str, int] = {}
    errores_reactivo: dict[str, dict[str, Any]] = {}
    filas = []
    for ficha, resultados in alumnos:
        pre = _ultimo(resultados, modulo_id, "pre")
        post = _ultimo(resultados, modulo_id, "post")
        pre_pct = float(pre["percentage"]) if pre else None
        post_pct = float(post["percentage"]) if post else None
        if pre_pct is not None:
            pres.append(pre_pct)
        if post_pct is not None:
            posts.append(post_pct)
        if pre_pct is not None and post_pct is not None:
            pares.append(post_pct - pre_pct)
        for respuesta in post.get("answers", []) if post else []:
            if respuesta.get("correcto"):
                continue
            concepto = str(respuesta.get("concept_id") or respuesta.get("dimension_id") or "")
            if concepto:
                errores_concepto[concepto] = errores_concepto.get(concepto, 0) + 1
            reactivo = str(respuesta.get("question_id", ""))
            if reactivo:
                fila = errores_reactivo.setdefault(
                    reactivo,
                    {
                        "question_id": reactivo,
                        "prompt": str(respuesta.get("prompt", "")),
                        "concept_id": concepto,
                        "count": 0,
                    },
                )
                fila["count"] += 1
        filas.append(
            {
                "alumno_id": ficha.get("alumno_id", ""),
                "apodo": ficha.get("apodo", ""),
                "pre_percentage": pre_pct,
                "post_percentage": post_pct,
                "delta": round(post_pct - pre_pct, 1)
                if pre_pct is not None and post_pct is not None
                else None,
            }
        )

    def _promedio(valores: list[float]) -> float | None:
        return round(mean(valores), 1) if valores else None

    return {
        "module_id": modulo_id,
        "module_title": modulo.get("title", modulo_id),
        "students": len(alumnos),
        "with_pre": len(pres),
        "with_post": len(posts),
        "with_both": len(pares),
        "avg_pre": _promedio(pres),
        "avg_post": _promedio(posts),
        "avg_delta": _promedio(pares),
        "concept_errors": [
            {"concept_id": c, "name": conceptos.get(c, c), "count": n}
            for c, n in sorted(errores_concepto.items(), key=lambda i: (-i[1], i[0]))
        ],
        "question_errors": sorted(
            errores_reactivo.values(), key=lambda f: (-f["count"], f["question_id"])
        )[:10],
        "rows": filas,
    }


COLUMNAS_CSV = (
    "alumno_id",
    "apodo",
    "matricula",
    "origen",
    "verificado",
    "modulo_id",
    "evaluacion",
    "porcentaje",
    "puntaje",
    "maximo",
    "duracion_segundos",
    "completado_en",
    "result_id",
)


def exportar_csv(filas_alumnos: list[tuple[dict[str, Any], list[dict[str, Any]]]]) -> str:
    """Una fila por evaluación: el formato más cómodo para el análisis
    estadístico pre/post en una hoja de cálculo o en R/pandas."""
    salida = io.StringIO()
    escritor = csv.writer(salida)
    escritor.writerow(COLUMNAS_CSV)
    for ficha, resultados in filas_alumnos:
        for resultado in resultados:
            escritor.writerow(
                [
                    ficha.get("alumno_id", ""),
                    ficha.get("apodo", ""),
                    ficha.get("matricula", ""),
                    ficha.get("origen", ""),
                    "si" if ficha.get("verificado", True) else "no",
                    resultado.get("module_id", "") or "global",
                    resultado.get("assessment_type", ""),
                    resultado.get("percentage", ""),
                    resultado.get("puntaje", ""),
                    resultado.get("maximo", ""),
                    resultado.get("duration_seconds", ""),
                    resultado.get("completed_at", ""),
                    resultado.get("result_id", ""),
                ]
            )
    return salida.getvalue()
