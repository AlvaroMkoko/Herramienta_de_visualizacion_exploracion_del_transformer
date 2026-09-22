"""Métricas puras para evaluaciones conceptuales (esquema v2).

El instrumento v2 admite crédito parcial, así que el resultado dejó de ser un
conteo de aciertos y pasó a ser un puntaje flotante sobre 20. La clave
``correct`` del esquema v1 ya no existe: quien la lea obtendrá ``None`` en vez
de un número engañoso.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Mapping

from .scorers import calificar

RESULT_SCHEMA_VERSION = 2


def _porcentaje(puntaje: float, maximo: float) -> float:
    return round((puntaje * 100 / maximo) if maximo else 0.0, 1)


def _texto_cualitativo(detalle: Mapping[str, Any]) -> str:
    """Extrae la justificación escrita de un reactivo por etapas, si la hay."""
    for datos in (detalle.get("etapas") or {}).values():
        if isinstance(datos, Mapping) and datos.get("puntua") is False:
            texto = str(datos.get("texto", "")).strip()
            if texto:
                return texto
    return ""


def compute_metrics(
    assessment_type: str,
    questions: list[dict[str, Any]],
    answers: Mapping[str, Any],
    dimensions: list[dict[str, str]],
) -> dict[str, Any]:
    """Calcula el puntaje total, el desglose por dimensión y por nivel de Bloom.

    ``answers`` mapea ``question_id`` a la respuesta cruda del estudiante, con
    la forma que documenta :mod:`model.evaluacion.scorers`. Un reactivo sin
    respuesta se califica igual que uno mal contestado: 0 puntos.
    """
    detalles: list[dict[str, Any]] = []
    cualitativos: list[dict[str, Any]] = []
    puntaje_total = 0.0
    maximo_total = 0.0

    for question in questions:
        question_id = str(question.get("id"))
        respuesta = answers.get(question_id)
        resultado = calificar(question, respuesta)

        puntaje_total += resultado["puntaje"]
        maximo_total += resultado["maximo"]

        detalles.append(
            {
                "question_id": question_id,
                "code": question.get("code", ""),
                "dimension_id": question.get("dimension_id", ""),
                "bloom_level": question.get("bloom_level", ""),
                "tipo": question.get("tipo", ""),
                "puntaje": resultado["puntaje"],
                "maximo": resultado["maximo"],
                "correcto": resultado["correcto"],
                "respondida": respuesta is not None,
                "respuesta": respuesta,
                "detalle": resultado["detalle"],
            }
        )

        texto = _texto_cualitativo(resultado["detalle"])
        if texto:
            cualitativos.append(
                {
                    "question_id": question_id,
                    "code": question.get("code", ""),
                    "prompt": question.get("prompt", ""),
                    "texto": texto,
                }
            )

    por_dimension = []
    for dimension in dimensions:
        propios = [d for d in detalles if d["dimension_id"] == dimension["id"]]
        if not propios:
            continue
        puntaje = round(sum(d["puntaje"] for d in propios), 4)
        maximo = round(sum(d["maximo"] for d in propios), 4)
        por_dimension.append(
            {
                "id": dimension["id"],
                "name": dimension["name"],
                "puntaje": puntaje,
                "maximo": maximo,
                "reactivos": len(propios),
                "percentage": _porcentaje(puntaje, maximo),
            }
        )

    por_bloom = []
    for nivel in ("Recordar", "Comprender", "Aplicar"):
        propios = [d for d in detalles if d["bloom_level"] == nivel]
        if not propios:
            continue
        puntaje = round(sum(d["puntaje"] for d in propios), 4)
        maximo = round(sum(d["maximo"] for d in propios), 4)
        por_bloom.append(
            {
                "id": nivel,
                "name": nivel,
                "puntaje": puntaje,
                "maximo": maximo,
                "reactivos": len(propios),
                "percentage": _porcentaje(puntaje, maximo),
            }
        )

    puntaje_total = round(puntaje_total, 4)
    maximo_total = round(maximo_total, 4)

    return {
        "schema_version": RESULT_SCHEMA_VERSION,
        "assessment_type": assessment_type,
        "puntaje": puntaje_total,
        "maximo": maximo_total,
        "percentage": _porcentaje(puntaje_total, maximo_total),
        "reactivos": len(detalles),
        "respondidas": len([d for d in detalles if d["respondida"]]),
        "dimensions": por_dimension,
        "bloom": por_bloom,
        "answers": detalles,
        "cualitativos": cualitativos,
        "completed_at": datetime.now(timezone.utc).isoformat(),
    }
