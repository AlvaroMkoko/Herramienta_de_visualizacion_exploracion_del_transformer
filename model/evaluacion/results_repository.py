"""Repositorio persistente de resultados de evaluación (esquema v2).

Los resultados producidos con el instrumento v1 **no son comparables** con los
del v2: son reactivos distintos, con otra escala y otro número de dimensiones.
En vez de borrarlos o de mezclarlos con los nuevos, se archivan: siguen en el
archivo pero quedan fuera del historial activo, de modo que ningún cálculo de
avance pre→post cruce dos instrumentos distintos.
"""

from __future__ import annotations

from copy import deepcopy
import json
import os
from pathlib import Path
from typing import Any

#: Versión del esquema de resultados que produce ``model.evaluacion.metrics``.
RESULT_SCHEMA_VERSION = 2


class ResultsRepository:
    """Mantiene el historial separado del ViewModel y de las pantallas QML."""

    def __init__(self, ruta: Path | None = None) -> None:
        self._ruta = Path(ruta) if ruta else None
        self._results: list[dict[str, Any]] = []
        self._archivados: list[dict[str, Any]] = []
        self._cargar()

    # ------------------------------------------------------------------
    # Persistencia
    # ------------------------------------------------------------------

    @staticmethod
    def _version_de(resultado: dict[str, Any]) -> int:
        """Un resultado sin ``schema_version`` viene del instrumento v1."""
        try:
            return int(resultado.get("schema_version", 1))
        except (TypeError, ValueError):
            return 1

    def _cargar(self) -> None:
        """Nunca lanza: un archivo ausente, corrupto o con otra forma deja el
        historial vacío en lugar de impedir que arranque la aplicación."""
        if self._ruta is None or not self._ruta.is_file():
            return
        try:
            with self._ruta.open("r", encoding="utf-8") as archivo:
                contenido = json.load(archivo)
        except (OSError, ValueError, TypeError):
            return

        if isinstance(contenido, list):
            # Formato más antiguo: lista desnuda, sin envoltorio de versión.
            crudos = contenido
            archivados: list[Any] = []
        elif isinstance(contenido, dict):
            crudos = contenido.get("results", [])
            archivados = contenido.get("archivados", [])
        else:
            return

        if not isinstance(crudos, list):
            crudos = []
        if not isinstance(archivados, list):
            archivados = []

        validos = [
            deepcopy(item)
            for item in crudos
            if isinstance(item, dict) and item.get("assessment_type")
        ]
        self._results = [
            item for item in validos if self._version_de(item) == RESULT_SCHEMA_VERSION
        ]
        self._archivados = [
            deepcopy(item) for item in archivados if isinstance(item, dict)
        ] + [item for item in validos if self._version_de(item) != RESULT_SCHEMA_VERSION]

        if len(self._results) != len(validos):
            # Se archivaron resultados de un instrumento anterior; conviene
            # dejarlo escrito para que el archivo refleje la nueva separación.
            self._persistir()

    def _persistir(self) -> None:
        if self._ruta is None:
            return
        self._ruta.parent.mkdir(parents=True, exist_ok=True)
        temporal = self._ruta.with_suffix(".tmp")
        contenido = {
            "version": RESULT_SCHEMA_VERSION,
            "results": self._results,
            "archivados": self._archivados,
        }
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

    # ------------------------------------------------------------------
    # Consulta
    # ------------------------------------------------------------------

    def save_result(self, evaluation_result: dict[str, Any]) -> None:
        resultado = deepcopy(evaluation_result)
        resultado.setdefault("schema_version", RESULT_SCHEMA_VERSION)
        self._results.append(resultado)
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

    @property
    def archived_count(self) -> int:
        """Resultados de instrumentos anteriores, conservados pero fuera del
        historial activo."""
        return len(self._archivados)

    def clear(self) -> None:
        """Borra el historial activo **y** el archivo histórico: es la acción de
        «Borrar progreso», que el usuario espera que no deje rastro."""
        self._results = []
        self._archivados = []
        if self._ruta is not None:
            try:
                self._ruta.unlink()
            except FileNotFoundError:
                pass
            except OSError:
                self._persistir()
