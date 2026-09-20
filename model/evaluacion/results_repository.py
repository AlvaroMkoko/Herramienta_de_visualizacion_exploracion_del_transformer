"""Repositorio persistente de resultados de evaluación."""

from __future__ import annotations

from copy import deepcopy
import json
import os
from pathlib import Path
from typing import Any


class ResultsRepository:
    """Mantiene el historial separado del ViewModel y de las pantallas QML."""

    def __init__(self, ruta: Path | None = None) -> None:
        self._ruta = Path(ruta) if ruta else None
        self._results = self._cargar()

    def _cargar(self) -> list[dict[str, Any]]:
        if self._ruta is None or not self._ruta.is_file():
            return []
        try:
            with self._ruta.open("r", encoding="utf-8") as archivo:
                contenido = json.load(archivo)
        except (OSError, ValueError, TypeError):
            return []

        if isinstance(contenido, list):
            resultados = contenido
        elif isinstance(contenido, dict) and contenido.get("version") == 1:
            resultados = contenido.get("results", [])
        else:
            return []

        if not isinstance(resultados, list):
            return []
        return [
            deepcopy(resultado)
            for resultado in resultados
            if isinstance(resultado, dict) and resultado.get("assessment_type")
        ]

    def _persistir(self) -> None:
        if self._ruta is None:
            return
        self._ruta.parent.mkdir(parents=True, exist_ok=True)
        temporal = self._ruta.with_suffix(".tmp")
        contenido = {"version": 1, "results": self._results}
        try:
            with temporal.open("w", encoding="utf-8") as archivo:
                json.dump(contenido, archivo, ensure_ascii=False, indent=2)
                archivo.flush()
                os.fsync(archivo.fileno())
            os.replace(temporal, self._ruta)
        finally:
            if temporal.exists():
                try:
                    temporal.unlink()
                except OSError:
                    pass

    def save_result(self, evaluation_result: dict[str, Any]) -> None:
        self._results.append(deepcopy(evaluation_result))
        self._persistir()

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

    def clear(self) -> None:
        self._results = []
        if self._ruta is not None:
            try:
                self._ruta.unlink()
            except FileNotFoundError:
                pass
            except OSError:
                self._persistir()
