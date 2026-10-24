"""Perfiles de acceso y vista docente de resultados.

El controlador no autentica usuarios: separa la experiencia de estudiante de
la de profesor y conserva el alumno al que se le está aplicando una evaluación.
Los datos del alumno se copian dentro de cada resultado; de ese modo el archivo
de resultados sigue siendo portable y no depende de una segunda base de datos.
"""

from __future__ import annotations

from copy import deepcopy
import re
import unicodedata
from typing import Any

from PySide6.QtCore import Property, QObject, Signal, Slot

from model.aprendizaje.module_question_bank import ModuleQuestionBank
from model.evaluacion.results_repository import primer_intento_vigente


SELF_STUDENT_ID = "__self__"


def _texto(valor: Any) -> str:
    return " ".join(str(valor or "").strip().split())


def _identificador(valor: str) -> str:
    normalizado = unicodedata.normalize("NFKD", _texto(valor))
    ascii_text = "".join(
        caracter for caracter in normalizado if not unicodedata.combining(caracter)
    )
    compacto = re.sub(r"[^a-zA-Z0-9_-]+", "-", ascii_text).strip("-")
    return compacto.casefold()


def _instrument_version(result: dict[str, Any]) -> int:
    try:
        return int(result.get("instrument_version", 2))
    except (TypeError, ValueError):
        return 2


def _module_instrument_version(result: dict[str, Any]) -> int:
    try:
        return int(result.get("instrument_version", 0))
    except (TypeError, ValueError):
        return 0


class ProfileController(QObject):
    """Mantiene el rol activo y construye reportes por alumno para QML."""

    profileChanged = Signal()
    studentsChanged = Signal()
    error = Signal(str)

    def __init__(self, evaluation_controller, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._evaluation = evaluation_controller
        self._role = ""
        self._active_student: dict[str, Any] = {}
        self._evaluation.evaluationCompleted.connect(self._al_completar_evaluacion)

    @Property(str, notify=profileChanged)
    def role(self) -> str:
        return self._role

    @Property(bool, notify=profileChanged)
    def isStudent(self) -> bool:
        return self._role == "student"

    @Property(bool, notify=profileChanged)
    def isTeacher(self) -> bool:
        return self._role == "teacher"

    @Property("QVariantMap", notify=profileChanged)
    def activeStudent(self) -> dict[str, Any]:
        return deepcopy(self._active_student)

    @Property(bool, notify=profileChanged)
    def hasActiveStudent(self) -> bool:
        return bool(self._active_student.get("id"))

    @Property(str, notify=profileChanged)
    def activeStudentName(self) -> str:
        return str(self._active_student.get("nombre", ""))

    def result_student_snapshot(self) -> dict[str, Any]:
        """Alumno que debe sellarse en el siguiente resultado."""
        if self._role == "teacher":
            return deepcopy(self._active_student)
        if self._role == "student":
            return {
                "id": SELF_STUDENT_ID,
                "nombre": "Estudiante (modo individual)",
                "matricula": "",
                "grupo": "",
                "edad": "",
                "correo": "",
                "origen": "individual",
            }
        return {}

    def result_student_filter(self) -> str | None:
        """Ámbito usado por pre/post y por las guardias de avance."""
        if self._role == "student":
            return SELF_STUDENT_ID
        if self._role == "teacher" and self._active_student.get("id"):
            return str(self._active_student["id"])
        return None

    @Slot(str)
    def seleccionarRol(self, role: str) -> None:
        normalized = str(role).strip().lower()
        if normalized not in ("student", "teacher", ""):
            self.error.emit("El perfil seleccionado no es válido.")
            return
        changed = normalized != self._role or bool(self._active_student)
        self._role = normalized
        self._active_student = {}
        if changed:
            self.profileChanged.emit()
            self._evaluation.refreshResultScope()

    @Slot()
    def limpiarAlumnoActivo(self) -> None:
        if not self._active_student:
            return
        self._active_student = {}
        self.profileChanged.emit()
        self._evaluation.refreshResultScope()

    @Slot(str, str, str, str, str, result=bool)
    def registrarAlumno(
        self,
        nombre: str,
        matricula: str,
        grupo: str,
        edad: str,
        correo: str,
    ) -> bool:
        nombre_limpio = _texto(nombre)
        matricula_limpia = _texto(matricula)
        grupo_limpio = _texto(grupo)
        edad_limpia = _texto(edad)
        correo_limpio = _texto(correo)

        if not nombre_limpio or not matricula_limpia or not grupo_limpio:
            self.error.emit("Completa nombre, matrícula o identificador y grupo.")
            return False
        student_id = _identificador(matricula_limpia)
        if not student_id:
            self.error.emit("La matrícula o identificador no es válido.")
            return False
        if edad_limpia:
            try:
                edad_numero = int(edad_limpia)
            except ValueError:
                self.error.emit("La edad debe ser un número entero.")
                return False
            if edad_numero < 5 or edad_numero > 120:
                self.error.emit("La edad debe estar entre 5 y 120 años.")
                return False
        if correo_limpio and ("@" not in correo_limpio or "." not in correo_limpio):
            self.error.emit("Escribe un correo válido o deja el campo vacío.")
            return False

        self._role = "teacher"
        self._active_student = {
            "id": student_id,
            "nombre": nombre_limpio,
            "matricula": matricula_limpia,
            "grupo": grupo_limpio,
            "edad": edad_limpia,
            "correo": correo_limpio,
            "origen": "docente",
        }
        self.profileChanged.emit()
        self._evaluation.refreshResultScope()
        return True

    @staticmethod
    def _student_from_result(result: dict[str, Any]) -> dict[str, Any]:
        student = result.get("student")
        if isinstance(student, dict) and student.get("id"):
            return deepcopy(student)
        student_id = str(result.get("student_id", "")).strip()
        if student_id == SELF_STUDENT_ID:
            return {
                "id": SELF_STUDENT_ID,
                "nombre": "Estudiante (modo individual)",
                "matricula": "",
                "grupo": "",
                "edad": "",
                "correo": "",
            }
        return {
            "id": student_id or "__legacy__",
            "nombre": "Resultados anteriores",
            "matricula": "Sin identificador",
            "grupo": "",
            "edad": "",
            "correo": "",
        }

    def _grouped_results(self) -> dict[str, dict[str, Any]]:
        grouped: dict[str, dict[str, Any]] = {}
        for result in self._evaluation.repository.get_history():
            student = self._student_from_result(result)
            entry = grouped.setdefault(str(student["id"]), {**student, "results": []})
            # La ficha más reciente corrige nombre/grupo si el docente los
            # actualizó al aplicar el post-test.
            entry.update(student)
            entry["results"].append(result)
        return grouped

    @staticmethod
    def _scope_of(result: dict[str, Any]) -> str:
        return str(result.get("module_id", "") or "")

    def _primary_scope(self, results: list[dict[str, Any]]) -> str:
        """Ámbito que compara la fila: la ruta general si el alumno la usa, o
        el módulo de su actividad más reciente. Pre y post de ámbitos
        distintos nunca se restan: medirían contenidos distintos."""
        if any(not self._scope_of(result) for result in results):
            return ""
        latest = max(
            enumerate(results),
            key=lambda item: (str(item[1].get("completed_at", "")), item[0]),
        )[1]
        return self._scope_of(latest)

    def _scope_label(self, scope: str) -> str:
        if not scope:
            return "Ruta general"
        try:
            from model.aprendizaje import LearningModuleCatalog

            module = LearningModuleCatalog().get(scope)
            return f"M{module['order']} · {module['title']}"
        except Exception:  # noqa: BLE001 - una etiqueta nunca debe tumbar el tablero
            return scope

    def _comparison(self, results: list[dict[str, Any]], scope: str) -> dict[str, Any]:
        """Primer pre y primer post del mismo ámbito, con cuántas veces se tomó cada uno."""
        in_scope = [result for result in results if self._scope_of(result) == scope]
        pre_all = [r for r in in_scope if r.get("assessment_type") == "pre"]
        post_all = [r for r in in_scope if r.get("assessment_type") == "post"]
        # Primer intento del instrumento vigente de ese ámbito.
        version = (
            ModuleQuestionBank.VERSION_PREGUNTAS
            if scope
            else self._evaluation.instrumentVersion
        )
        # En módulos, un resultado sin versión es anterior al campo y no se
        # compara (misma regla que CourseController); la ruta general lo toma
        # como v2, el instrumento con el que se produjo.
        version_de = _instrument_version if not scope else _module_instrument_version
        pre = primer_intento_vigente(pre_all, version, version_de)
        post = primer_intento_vigente(post_all, version, version_de)
        return {
            "scope": scope,
            "pre": pre,
            "post": post,
            "pre_attempts": len(pre_all),
            "post_attempts": len(post_all),
            "comparable": bool(
                pre and post and version_de(pre) > 0 and version_de(pre) == version_de(post)
            ),
        }

    @Property("QVariantList", notify=studentsChanged)
    def students(self) -> list[dict[str, Any]]:
        rows: list[dict[str, Any]] = []
        for entry in self._grouped_results().values():
            results = entry.pop("results")
            scope = self._primary_scope(results)
            comparison = self._comparison(results, scope)
            pre, post = comparison["pre"], comparison["post"]
            pre_pct = float(pre.get("percentage", 0)) if pre else 0.0
            post_pct = float(post.get("percentage", 0)) if post else 0.0
            comparable = comparison["comparable"]
            latest_date = max(
                (str(r.get("completed_at", "")) for r in results), default=""
            )
            if pre and post:
                status = "Pre-test y post-test completados"
            elif pre:
                status = "Pre-test completado"
            else:
                status = "Post-test completado"
            rows.append(
                {
                    **entry,
                    "scope": scope,
                    "scope_label": self._scope_label(scope),
                    "pre_completed": bool(pre),
                    "post_completed": bool(post),
                    "pre_percentage": pre_pct,
                    "post_percentage": post_pct,
                    # Cuenta el primer intento; las repeticiones se registran.
                    "pre_attempts": comparison["pre_attempts"],
                    "post_attempts": comparison["post_attempts"],
                    "improvement": round(post_pct - pre_pct, 1) if comparable else 0.0,
                    "comparable": comparable,
                    "tests_count": len(results),
                    "status": status,
                    "latest_completed_at": latest_date,
                }
            )
        rows.sort(
            key=lambda row: (str(row.get("latest_completed_at", "")), str(row.get("nombre", ""))),
            reverse=True,
        )
        return rows

    @Property(int, notify=studentsChanged)
    def studentCount(self) -> int:
        return len(self.students)

    @Property(int, notify=studentsChanged)
    def resultCount(self) -> int:
        return len(self._evaluation.repository.get_history())

    @Slot(str, result="QVariantMap")
    def studentAnalysis(self, student_id: str) -> dict[str, Any]:
        student_key = str(student_id).strip()
        row = next((item for item in self.students if item["id"] == student_key), None)
        if row is None:
            return {}
        # El mismo ámbito y los mismos intentos que la fila del tablero.
        results = self._grouped_results()[student_key]["results"]
        comparison = self._comparison(results, row["scope"])
        pre, post = comparison["pre"], comparison["post"]
        comparable = comparison["comparable"]

        def dimensions(result: dict[str, Any]) -> dict[str, dict[str, Any]]:
            return {
                str(item.get("id")): item
                for item in result.get("dimensions", [])
                if item.get("id")
            }

        indexed_pre, indexed_post = dimensions(pre), dimensions(post)
        dimension_ids = list(dict.fromkeys([*indexed_pre, *indexed_post]))
        dimension_rows = []
        for dimension_id in dimension_ids:
            before = indexed_pre.get(dimension_id, {})
            after = indexed_post.get(dimension_id, {})
            pre_pct = float(before.get("percentage", 0))
            post_pct = float(after.get("percentage", 0))
            dimension_rows.append(
                {
                    "id": dimension_id,
                    "name": after.get("name", before.get("name", dimension_id)),
                    "has_pre": bool(before),
                    "has_post": bool(after),
                    "pre_percentage": pre_pct,
                    "post_percentage": post_pct,
                    "improvement": round(post_pct - pre_pct, 1)
                    if before and after and comparable
                    else 0.0,
                }
            )
        return {
            "student": row,
            "pre": pre,
            "post": post,
            "dimensions": dimension_rows,
            "has_pre": bool(pre),
            "has_post": bool(post),
            "comparable": comparable,
            "scope": row["scope"],
            "scope_label": row["scope_label"],
            "pre_attempts": comparison["pre_attempts"],
            "post_attempts": comparison["post_attempts"],
        }

    @Slot()
    def refresh(self) -> None:
        self.studentsChanged.emit()

    def _al_completar_evaluacion(self, _result: dict[str, Any]) -> None:
        self.studentsChanged.emit()
