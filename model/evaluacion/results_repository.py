"""Repositorio de resultados durante la sesión activa de la aplicación."""

from __future__ import annotations

from copy import deepcopy
from typing import Any


class ResultsRepository:
    """Mantiene el historial separado del ViewModel y de las pantallas QML."""

    def __init__(self) -> None:
        self._results: list[dict[str, Any]] = []

    def save_result(self, evaluation_result: dict[str, Any]) -> None:
        self._results.append(deepcopy(evaluation_result))

    def get_history(self, assessment_type: str | None = None) -> list[dict[str, Any]]:
        results = self._results
        if assessment_type:
            results = [
                result
                for result in results
                if result.get("assessment_type") == assessment_type
            ]
        return deepcopy(results)

    def latest(self, assessment_type: str) -> dict[str, Any]:
        for result in reversed(self._results):
            if result.get("assessment_type") == assessment_type:
                return deepcopy(result)
        return {}
