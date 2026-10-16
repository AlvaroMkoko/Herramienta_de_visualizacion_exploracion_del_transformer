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


def ganancia_normalizada(pre_pct: float, post_pct: float) -> float | None:
    """Ganancia de Hake ``(post − pre) / (100 − pre)``; indefinida con pre = 100."""
    if pre_pct >= 100:
        return None
    return round((post_pct - pre_pct) / (100 - pre_pct), 3)


# Umbrales para marcar un reactivo como candidato a revisión. Son los cortes
# habituales del análisis clásico de reactivos: casi todos aciertan antes de
# enseñar (efecto techo) o el reactivo no separa a quienes saben más.
P_TECHO_PRE = 0.9
D_MINIMO = 0.2
FRACCION_GRUPO_EXTREMO = 0.27


def _proporcion(respuesta: dict[str, Any]) -> float:
    maximo = float(respuesta.get("maximo", 1) or 1)
    return float(respuesta.get("puntaje", 0)) / maximo if maximo else 0.0


def _indice_discriminacion(
    aplicaciones: list[tuple[float, dict[str, float]]], code: str
) -> float | None:
    """Índice D: proporción de acierto del 27 % superior menos la del inferior.

    ``aplicaciones`` es ``[(porcentaje_total, {code: proporción})]``. Sólo
    cuentan quienes recibieron el reactivo; con menos de cuatro no se reporta.
    """
    con_reactivo = sorted(
        (total, puntos[code]) for total, puntos in aplicaciones if code in puntos
    )
    if len(con_reactivo) < 4:
        return None
    tamano = max(1, round(len(con_reactivo) * FRACCION_GRUPO_EXTREMO))
    inferior = [p for _, p in con_reactivo[:tamano]]
    superior = [p for _, p in con_reactivo[-tamano:]]
    return round(mean(superior) - mean(inferior), 2)


def analisis_reactivos(
    modulo_id: str, alumnos: list[tuple[dict[str, Any], list[dict[str, Any]]]]
) -> list[dict[str, Any]]:
    """Dificultad, discriminación y ganancia de cada par de reactivos paralelos.

    El pre y el post usan formas paralelas con el mismo ``code`` (``A1`` del
    pre ↔ ``A1`` del post), así que la ganancia se mide por código. Un reactivo
    que casi todos aciertan en el pre, que no discrimina o que nadie mejora es
    candidato a reescribirse antes de la siguiente aplicación.
    """
    por_tipo: dict[str, list[tuple[float, dict[str, float]]]] = {"pre": [], "post": []}
    enunciados: dict[str, dict[str, str]] = {}
    for _, resultados in alumnos:
        for tipo in ("pre", "post"):
            resultado = _ultimo(resultados, modulo_id, tipo)
            if not resultado:
                continue
            puntos: dict[str, float] = {}
            for respuesta in resultado.get("answers", []):
                code = str(respuesta.get("code", ""))
                if not code:
                    continue
                puntos[code] = _proporcion(respuesta)
                enunciados.setdefault(code, {}).setdefault(
                    tipo, str(respuesta.get("prompt", ""))
                )
                enunciados[code].setdefault(
                    "concept_id", str(respuesta.get("concept_id", ""))
                )
            por_tipo[tipo].append((float(resultado.get("percentage", 0)), puntos))

    filas = []
    for code in sorted(enunciados):
        fila: dict[str, Any] = {
            "code": code,
            "concept_id": enunciados[code].get("concept_id", ""),
            "prompt_pre": enunciados[code].get("pre", ""),
            "prompt_post": enunciados[code].get("post", ""),
        }
        for tipo in ("pre", "post"):
            valores = [p[code] for _, p in por_tipo[tipo] if code in p]
            fila[f"n_{tipo}"] = len(valores)
            fila[f"p_{tipo}"] = round(mean(valores), 2) if valores else None
            fila[f"d_{tipo}"] = _indice_discriminacion(por_tipo[tipo], code)
        fila["gain"] = (
            round(fila["p_post"] - fila["p_pre"], 2)
            if fila["p_pre"] is not None and fila["p_post"] is not None
            else None
        )
        motivos = []
        if fila["p_pre"] is not None and fila["p_pre"] >= P_TECHO_PRE:
            motivos.append("Casi todos aciertan en el pre-test")
        if fila["d_post"] is not None and fila["d_post"] < D_MINIMO:
            motivos.append("No distingue a quienes dominan el tema")
        if fila["gain"] is not None and fila["gain"] <= 0:
            motivos.append("No mejora entre pre y post")
        fila["flags"] = motivos
        filas.append(fila)
    return filas


def _interaccion(estado: dict[str, Any]) -> dict[str, Any]:
    """Lo que el alumno hizo entre pre y post, tomado de su snapshot."""
    checks = estado.get("guided_checks") or {}
    ciclos = estado.get("lab_cycles") or []
    retencion = estado.get("retention") or {}
    return {
        "guided_checks": len(checks),
        "guided_first_correct": sum(1 for c in checks.values() if c.get("first_correct")),
        "lab_cycles": len({str(c.get("step_id", "")) for c in ciclos} - {""}),
        "lab_predictions_correct": sum(1 for c in ciclos if c.get("prediction_correct")),
        "retention_correct": sum(1 for r in retencion.values() if r.get("correct")),
        "retention_total": len(retencion),
    }


def analisis_modulo(
    modulo: dict[str, Any],
    alumnos: list[tuple[dict[str, Any], list[dict[str, Any]]]],
    snapshots: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Promedios pre/post y errores frecuentes de un módulo para toda la clase.

    ``alumnos`` es una lista de ``(ficha_alumno, resultados_del_alumno)``.
    El cambio promedio sólo se calcula con alumnos que tienen ambos tests:
    promediar pre de unos con post de otros mezclaría grupos distintos.
    ``snapshots`` (``alumno_id → snapshot de progreso``) añade a cada fila la
    interacción con recorrido y laboratorio, para cruzarla con su ganancia.
    """
    modulo_id = modulo["id"]
    conceptos = {c["id"]: c.get("title", c["id"]) for c in modulo.get("concepts", [])}
    snapshots = snapshots or {}
    pres: list[float] = []
    posts: list[float] = []
    pares: list[float] = []
    ganancias: list[float] = []
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
        ganancia = None
        if pre_pct is not None and post_pct is not None:
            pares.append(post_pct - pre_pct)
            ganancia = ganancia_normalizada(pre_pct, post_pct)
            if ganancia is not None:
                ganancias.append(ganancia)
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
                "normalized_gain": ganancia,
                "interaction": _interaccion(
                    ((snapshots.get(str(ficha.get("alumno_id", ""))) or {}).get("modules") or {})
                    .get(modulo_id)
                    or {}
                ),
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
        "avg_normalized_gain": round(mean(ganancias), 3) if ganancias else None,
        "item_analysis": analisis_reactivos(modulo_id, alumnos),
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
