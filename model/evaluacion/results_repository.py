"""Repositorio persistente de resultados de evaluación (esquema v2).

Los resultados producidos con el instrumento v1 **no son comparables** con los
del v2: son reactivos distintos, con otra escala y otro número de dimensiones.
En vez de borrarlos o de mezclarlos con los nuevos, se archivan: siguen en el
archivo pero quedan fuera del historial activo, de modo que ningún cálculo de
avance pre→post cruce dos instrumentos distintos.
"""

from __future__ import annotations

from contextlib import contextmanager
from copy import deepcopy
import hashlib
import json
import os
from pathlib import Path
from typing import Any, Callable, Iterator
import uuid

#: Versión del esquema de resultados que produce ``model.evaluacion.metrics``.
RESULT_SCHEMA_VERSION = 2


def primer_intento(resultados: list[dict[str, Any]]) -> dict[str, Any]:
    """El intento que cuenta para la comparación pre→post: el primero.

    Repetir una evaluación ya hecha (con las claves del post-test a la vista o
    después de estudiar) no debe reemplazar la medición original. Se ordena por
    ``completed_at`` porque al docente los resultados le llegan por red y por
    archivo, no necesariamente en el orden en que se resolvieron; si alguno no
    trae fecha, vale el orden en que se guardaron.
    """
    if not resultados:
        return {}
    fechas = [str(item.get("completed_at", "") or "") for item in resultados]
    if all(fechas):
        indice = min(range(len(resultados)), key=lambda i: (fechas[i], i))
        return resultados[indice]
    return resultados[0]


def primer_intento_vigente(
    resultados: list[dict[str, Any]],
    version: int,
    version_de: Callable[[dict[str, Any]], int],
) -> dict[str, Any]:
    """Primer intento del instrumento vigente; si no hay ninguno, el primero.

    Un intento con otra versión del instrumento no se compara con los de la
    vigente (son reactivos distintos). Elegirlo como «primero» sólo porque es
    más antiguo dejaría inválido el par pre/post para siempre, o lo mezclaría
    donde no se revisa la versión. Si no hay intentos de la vigente se devuelve
    el primero que haya, para mostrarlo; quien compare debe revisar la versión.
    """
    vigentes = [item for item in resultados if version_de(item) == int(version)]
    return primer_intento(vigentes) or primer_intento(resultados)


class ResultsRepository:
    """Mantiene el historial separado del ViewModel y de las pantallas QML."""

    def __init__(self, ruta: Path | None = None) -> None:
        self._ruta = Path(ruta) if ruta else None
        self._results: list[dict[str, Any]] = []
        self._archivados: list[dict[str, Any]] = []
        self._en_lote = 0
        self._guardar_al_cerrar_lote = False
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

        sin_id = [item for item in self._results if not item.get("result_id")]
        for item in sin_id:
            item["result_id"] = self._id_determinista(item)

        if len(self._results) != len(validos) or sin_id:
            # Se archivaron resultados de un instrumento anterior o se les
            # asignó identificador; conviene dejarlo escrito para que el
            # archivo refleje el cambio.
            self._persistir()

    @staticmethod
    def _id_determinista(resultado: dict[str, Any]) -> str:
        """Identificador estable para resultados guardados antes de que
        existiera ``result_id``: el mismo contenido produce el mismo id en
        cualquier equipo, así que sincronizarlo dos veces no lo duplica."""
        contenido = json.dumps(resultado, ensure_ascii=False, sort_keys=True, default=str)
        return "h" + hashlib.sha256(contenido.encode("utf-8")).hexdigest()[:31]

    @contextmanager
    def lote(self) -> Iterator["ResultsRepository"]:
        """Agrupa las escrituras del bloque en una sola, al salir de él.

        El docente reescribe el archivo completo por cada resultado que recibe;
        con la clase de un semestre (cientos de resultados) cuarenta entregas
        simultáneas lo bloqueaban decenas de segundos. Quien confirme lo
        guardado debe hacerlo **después** del bloque: dentro, aún no está en disco.
        """
        self._en_lote += 1
        try:
            yield self
        finally:
            self._en_lote -= 1
            if not self._en_lote and self._guardar_al_cerrar_lote:
                self._guardar_al_cerrar_lote = False
                self._persistir()

    def _persistir(self) -> None:
        if self._ruta is None:
            return
        if self._en_lote:
            self._guardar_al_cerrar_lote = True
            return
        self._ruta.parent.mkdir(parents=True, exist_ok=True)
        temporal = self._ruta.with_suffix(".tmp")
        contenido = {
            "version": RESULT_SCHEMA_VERSION,
            "results": self._results,
            "archivados": self._archivados,
        }
        # Mismos bytes que ``json.dump``, pero ``json.dump`` no usa el
        # codificador en C: con un archivo de varios MB es unas 3 veces más lento.
        texto = json.dumps(contenido, ensure_ascii=False, indent=2)
        try:
            with temporal.open("w", encoding="utf-8") as archivo:
                archivo.write(texto)
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
        # El id permite sincronizar el resultado con el aula sin duplicarlo.
        # Se escribe también en el dict recibido para que quien lo emita
        # después (``evaluationCompleted``) comparta el mismo identificador.
        resultado.setdefault("result_id", uuid.uuid4().hex)
        evaluation_result.setdefault("result_id", resultado["result_id"])
        self._results.append(resultado)
        self._persistir()

    def has_result(self, result_id: str) -> bool:
        return any(item.get("result_id") == result_id for item in self._results)

    def save_unique(self, evaluation_result: dict[str, Any]) -> bool:
        """Guarda sólo si su ``result_id`` no existe. Devuelve si lo guardó.

        Usado por el docente: un mismo resultado puede llegar por red y luego
        otra vez dentro de un archivo ``.tvclase``.
        """
        result_id = str(evaluation_result.get("result_id", "")).strip()
        if not result_id or self.has_result(result_id):
            return False
        if self._version_de(evaluation_result) != RESULT_SCHEMA_VERSION:
            return False
        self.save_result(evaluation_result)
        return True

    @staticmethod
    def _student_id_de(resultado: dict[str, Any]) -> str:
        student_id = str(resultado.get("student_id", "")).strip()
        if student_id:
            return student_id
        student = resultado.get("student")
        if isinstance(student, dict):
            return str(student.get("id", "")).strip()
        return ""

    @classmethod
    def _pertenece_al_estudiante(
        cls, resultado: dict[str, Any], student_id: str
    ) -> bool:
        actual = cls._student_id_de(resultado)
        # Los resultados creados antes de que existieran perfiles pertenecen
        # al modo individual. Así se conservan al actualizar la aplicación,
        # pero nunca se mezclan con un alumno identificado por el docente.
        if student_id == "__self__":
            return actual in ("", "__self__")
        return actual == student_id

    def get_history(
        self,
        assessment_type: str | None = None,
        student_id: str | None = None,
        module_id: str | None = None,
    ) -> list[dict[str, Any]]:
        results = self._results
        if assessment_type:
            results = [
                result
                for result in results
                if result.get("assessment_type") == assessment_type
            ]
        if student_id is not None:
            results = [
                result
                for result in results
                if self._pertenece_al_estudiante(result, student_id)
            ]
        if module_id is not None:
            results = [
                result
                for result in results
                if str(result.get("module_id", "")) == str(module_id)
            ]
        return deepcopy(results)

    def latest(
        self,
        assessment_type: str,
        student_id: str | None = None,
        module_id: str | None = None,
    ) -> dict[str, Any]:
        for result in reversed(self._results):
            if (
                result.get("assessment_type") == assessment_type
                and (
                    module_id is None
                    or str(result.get("module_id", "")) == str(module_id)
                )
                and (
                    student_id is None
                    or self._pertenece_al_estudiante(result, student_id)
                )
            ):
                return deepcopy(result)
        return {}

    def first(
        self,
        assessment_type: str,
        student_id: str | None = None,
        module_id: str | None = None,
    ) -> dict[str, Any]:
        """Primer intento (ver :func:`primer_intento`); copia, como ``latest``."""
        return primer_intento(self.get_history(assessment_type, student_id, module_id))

    @property
    def archived_count(self) -> int:
        """Resultados de instrumentos anteriores, conservados pero fuera del
        historial activo."""
        return len(self._archivados)

    def clear(self, student_id: str | None = None) -> None:
        """Borra un historial individual o, sin filtro, todo el repositorio.

        El borrado sin filtro conserva el contrato histórico de «Borrar todo
        el progreso». Con perfiles activos, el estudiante no puede eliminar
        los resultados identificados que recopiló el docente.
        """
        if student_id is not None:
            self._results = [
                result
                for result in self._results
                if not self._pertenece_al_estudiante(result, student_id)
            ]
            self._persistir()
            return
        self._results = []
        self._archivados = []
        if self._ruta is not None:
            try:
                self._ruta.unlink()
            except FileNotFoundError:
                pass
            except OSError:
                self._persistir()

    def clear_module_results(self, student_id: str | None = None) -> None:
        """Elimina sólo intentos del curso modular y conserva el flujo legado."""
        self._results = [
            result
            for result in self._results
            if not result.get("module_id")
            or (
                student_id is not None
                and not self._pertenece_al_estudiante(result, student_id)
            )
        ]
        self._persistir()
