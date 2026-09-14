"""Métricas puras para evaluaciones conceptuales."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Mapping


def _percentage(correct: int, total: int) -> float:
    return round((correct * 100 / total) if total else 0.0, 1)


def compute_metrics(
    assessment_type: str,
    questions: list[dict[str, Any]],
    answers: Mapping[str, str],
    dimensions: list[dict[str, str]],
) -> dict[str, Any]:
    """Calcula el total y el desempeño por dimensión."""

    details = []
    for question in questions:
        selected = answers.get(question["id"], "")
        correct_option = question["correct_option_id"]
        details.append(
            {
                "question_id": question["id"],
                "dimension_id": question["dimension_id"],
                "selected_option_id": selected,
                "correct_option_id": correct_option,
                "correct": selected == correct_option,
            }
        )

    correct = sum(1 for detail in details if detail["correct"])
    dimension_results = []
    for dimension in dimensions:
        dimension_details = [
            detail
            for detail in details
            if detail["dimension_id"] == dimension["id"]
        ]
        dimension_correct = sum(
            1 for detail in dimension_details if detail["correct"]
        )
        dimension_results.append(
            {
                "id": dimension["id"],
                "name": dimension["name"],
                "correct": dimension_correct,
                "total": len(dimension_details),
                "percentage": _percentage(
                    dimension_correct, len(dimension_details)
                ),
            }
        )

    return {
        "assessment_type": assessment_type,
        "correct": correct,
        "total": len(questions),
        "percentage": _percentage(correct, len(questions)),
        "answered": len([answer for answer in answers.values() if answer]),
        "dimensions": dimension_results,
        "answers": details,
        "completed_at": datetime.now(timezone.utc).isoformat(),
    }
