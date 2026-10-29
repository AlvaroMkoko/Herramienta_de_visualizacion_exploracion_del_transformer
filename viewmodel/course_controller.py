"""Coordinador MVVM del curso modular progresivo."""

from __future__ import annotations

from copy import deepcopy
from pathlib import Path
from typing import Any

from PySide6.QtCore import Property, QObject, QUrl, Signal, Slot

from core.rutas import dato
from model.aprendizaje import LearningModuleCatalog, ModuleProgressRepository
from model.aprendizaje import exportacion_resultados
from model.aprendizaje.module_question_bank import ModuleQuestionBank
from model.evaluacion.results_repository import primer_intento_vigente


STAGES = ("pretest", "guided", "laboratory", "posttest", "results")


def _instrument_version(result: dict[str, Any]) -> int:
    try:
        return int(result.get("instrument_version", 0))
    except (TypeError, ValueError):
        return 0


class CourseController(QObject):
    """Expone catálogo, guardias, progreso persistente y resultados por módulo."""

    progressChanged = Signal()
    moduleChanged = Signal()

    # Interruptor para revisión funcional. Mantiene el registro real de avance,
    # pero permite abrir cualquier módulo y etapa sin prerrequisitos (RN18).
    # Debe quedar en False con estudiantes: abrir el post-test sin pasar por el
    # recorrido invalida la comparación pre/post.
    REVIEW_MODE_UNLOCK_ALL = False
    # La aplicación de este estudio se concentra en Self-Attention. El modo
    # revisión sigue permitiendo auditar los ocho módulos durante desarrollo.
    FOCUS_MODULE_ID = "module_3"

    # Ejecutar el forward no es practicar: el laboratorio cuenta como hecho
    # cuando el alumno cerró este número de ciclos predecir→probar→observar→
    # explicar en pasos distintos y respondió la pregunta ancla del módulo.
    REQUIRED_LAB_CYCLES = 3
    # Retos del módulo anterior que se repasan al abrir el siguiente.
    REVIEW_ITEM_INDICES = (1, 4, 7)

    def __init__(
        self,
        module_evaluation_controller,
        parent: QObject | None = None,
        catalog: LearningModuleCatalog | None = None,
        repository: ModuleProgressRepository | None = None,
    ) -> None:
        super().__init__(parent)
        self._catalog = catalog or LearningModuleCatalog()
        self._evaluation = module_evaluation_controller
        self._repository = repository or ModuleProgressRepository(
            dato("progreso", "progreso_modular.json")
        )
        self._state = self._repository.snapshot()
        default_module_id = (
            self.FOCUS_MODULE_ID
            if self.FOCUS_MODULE_ID in self._catalog.module_ids
            else self._catalog.module_ids[0]
        )
        stored_module_id = str(
            self._state.get("current_module_id", default_module_id)
        )
        self._current_module_id = (
            stored_module_id
            if self.REVIEW_MODE_UNLOCK_ALL
            and stored_module_id in self._catalog.module_ids
            else default_module_id
        )
        # Módulos que el docente habilitó en la clase. ``None`` = sin clase o
        # con todos habilitados; esta restricción vence al modo revisión.
        self._class_modules: frozenset[str] | None = None
        self._evaluation.evaluationCompleted.connect(self._on_evaluation_completed)
        set_guard = getattr(self._evaluation, "set_stage_guard", None)
        if set_guard is not None:
            set_guard(self._evaluation_block_reason)

    def _evaluation_block_reason(self, module_id: str, assessment_type: str) -> str:
        stage = {"pre": "pretest", "post": "posttest"}.get(str(assessment_type))
        if stage is None or module_id not in self._catalog.module_ids:
            return "Esta evaluación no pertenece al curso."
        return self.stageBlockReason(module_id, stage)

    @property
    def catalog(self) -> LearningModuleCatalog:
        return self._catalog

    def progress_snapshot(self) -> dict[str, Any]:
        """Estado persistido del curso, para sincronizarlo con el aula."""
        return self._repository.snapshot()

    def set_class_modules(self, module_ids: list[str] | None) -> None:
        allowed = None if module_ids is None else frozenset(map(str, module_ids))
        if allowed == self._class_modules:
            return
        self._class_modules = allowed
        self.progressChanged.emit()

    def _blocked_by_class(self, module_id: str) -> bool:
        return self._class_modules is not None and module_id not in self._class_modules

    def _student_filter(self) -> str | None:
        return self._evaluation._student_filter()  # frontera interna compartida

    def _module_state(self, module_id: str) -> dict[str, Any]:
        modules = self._state.setdefault("modules", {})
        state = modules.setdefault(
            module_id,
            {
                "guided_steps_completed": [],
                "guided_completed": False,
                "laboratory_completed": False,
                "results_viewed": False,
                "attempts": {"pre": 0, "post": 0},
                "question_ids_used": {"pre": [], "post": []},
                "time_seconds": 0.0,
                "difficult_concepts": [],
            },
        )
        return state

    def _persist(self) -> None:
        self._state["current_module_id"] = self._current_module_id
        self._repository.replace(self._state)

    def _result(self, module_id: str, assessment_type: str) -> dict[str, Any]:
        # Cuenta el primer intento del instrumento vigente: repetir no reemplaza
        # la medición original, y un intento de otra versión no se compara.
        return primer_intento_vigente(
            self._evaluation.repository.get_history(
                assessment_type, self._student_filter(), module_id=module_id
            ),
            ModuleQuestionBank.VERSION_PREGUNTAS,
            _instrument_version,
        )

    def _attempt_count(self, module_id: str, assessment_type: str) -> int:
        return len(
            self._evaluation.repository.get_history(
                assessment_type, self._student_filter(), module_id=module_id
            )
        )

    def _pretest_closed(self, module_id: str) -> bool:
        # Solo se protege un pre-test que existe: si el alumno borró su
        # historial, no queda medición que contaminar y el módulo no debe
        # quedar sin forma de empezar (recorrido y pre-test cerrados a la vez).
        return self._guided_entered(module_id) and self._stage_done(module_id, "pretest")

    def _guided_entered(self, module_id: str) -> bool:
        # Cualquier avance en el recorrido también cuenta: el progreso guardado
        # antes de que existiera la marca no debe reabrir el pre-test.
        state = self._module_state(module_id)
        return bool(
            state.get("guided_entered")
            or state.get("guided_completed")
            or state.get("guided_steps_completed")
            or state.get("guided_checks")
        )

    def _stage_done(self, module_id: str, stage: str) -> bool:
        state = self._module_state(module_id)
        return {
            "pretest": bool(self._result(module_id, "pre")),
            "guided": bool(state.get("guided_completed")),
            "laboratory": bool(state.get("laboratory_completed")),
            "posttest": bool(self._result(module_id, "post")),
            "results": bool(state.get("results_viewed")),
        }.get(stage, False)

    def _module_unlocked(self, module_id: str) -> bool:
        if self._blocked_by_class(module_id):
            return False
        if self.REVIEW_MODE_UNLOCK_ALL:
            return True
        if module_id == self.FOCUS_MODULE_ID:
            return True
        module = self._catalog.get(module_id)
        if module["order"] == 1:
            return True
        previous = self._catalog.modules[module["order"] - 2]["id"]
        return self._stage_done(previous, "results")

    def _module_available_in_map(self, module_id: str) -> bool:
        if self.REVIEW_MODE_UNLOCK_ALL or not self.FOCUS_MODULE_ID:
            return self._module_unlocked(module_id)
        return module_id == self.FOCUS_MODULE_ID and self._module_unlocked(module_id)

    def _module_status(self, module_id: str) -> str:
        if not self._module_unlocked(module_id):
            return "locked"
        if self._stage_done(module_id, "results"):
            post = self._result(module_id, "post")
            return "review_recommended" if float(post.get("percentage", 0)) < 70 else "completed"
        if any(self._stage_done(module_id, stage) for stage in STAGES):
            return "in_progress"
        return "not_started"

    def _module_view(self, module: dict[str, Any]) -> dict[str, Any]:
        module_id = module["id"]
        done = sum(self._stage_done(module_id, stage) for stage in STAGES)
        result = deepcopy(module)
        result.update(
            {
                "status": self._module_status(module_id),
                "available": self._module_available_in_map(module_id),
                "completed_stages": done,
                "total_stages": len(STAGES),
                "progress_percent": round(done * 100 / len(STAGES)),
                "current_stage": self._first_pending_stage(module_id),
            }
        )
        return result

    def _first_pending_stage(self, module_id: str) -> str:
        for stage in STAGES:
            if not self._stage_done(module_id, stage):
                return stage
        return "completed"

    @Property("QVariantList", notify=progressChanged)
    def modules(self) -> list[dict[str, Any]]:
        return [self._module_view(module) for module in self._catalog.modules]

    @Property(str, notify=moduleChanged)
    def currentModuleId(self) -> str:
        return self._current_module_id

    @Property("QVariantMap", notify=progressChanged)
    def currentModule(self) -> dict[str, Any]:
        return self._module_view(self._catalog.get(self._current_module_id))

    @Property(int, notify=progressChanged)
    def globalProgressPercent(self) -> int:
        total = len(self._catalog.modules) * len(STAGES)
        completed = sum(
            self._stage_done(module_id, stage)
            for module_id in self._catalog.module_ids
            for stage in STAGES
        )
        return round(completed * 100 / total)

    @Property(int, notify=progressChanged)
    def completedModulesCount(self) -> int:
        return sum(
            self._module_status(module_id) in ("completed", "review_recommended")
            for module_id in self._catalog.module_ids
        )

    @Property(int, constant=True)
    def totalModules(self) -> int:
        return len(self._catalog.module_ids)

    @Property(bool, constant=True)
    def reviewMode(self) -> bool:
        return self.REVIEW_MODE_UNLOCK_ALL

    @Property("QVariantMap", notify=progressChanged)
    def currentModuleResults(self) -> dict[str, Any]:
        return self._build_results(self._current_module_id)

    @Slot(str)
    def selectModule(self, module_id: str) -> None:
        if module_id not in self._catalog.module_ids or not self._module_unlocked(module_id):
            return
        if module_id == self._current_module_id:
            return
        self._current_module_id = module_id
        self._persist()
        self.moduleChanged.emit()
        self.progressChanged.emit()

    @Slot(str, str, result=bool)
    def stageAvailable(self, module_id: str, stage: str) -> bool:
        if module_id not in self._catalog.module_ids or stage not in STAGES:
            return False
        if self._blocked_by_class(module_id):
            return False
        if self.REVIEW_MODE_UNLOCK_ALL:
            return True
        if not self._module_unlocked(module_id):
            return False
        # El pre-test mide lo que se sabía antes de la intervención: una vez
        # visto el recorrido, rehacerlo mediría lo aprendido en él.
        if stage == "pretest" and self._pretest_closed(module_id):
            return False
        index = STAGES.index(stage)
        return all(self._stage_done(module_id, previous) for previous in STAGES[:index])

    @Slot(str, str, result=bool)
    def stageCompleted(self, module_id: str, stage: str) -> bool:
        return stage in STAGES and self._stage_done(module_id, stage)

    @Slot(str, str, result=str)
    def stageBlockReason(self, module_id: str, stage: str) -> str:
        if self.stageAvailable(module_id, stage):
            return ""
        if self._blocked_by_class(module_id):
            return "El docente todavía no habilita este módulo en la clase."
        if not self._module_unlocked(module_id):
            return "Completa el módulo anterior para desbloquear éste."
        if stage == "pretest" and self._pretest_closed(module_id):
            return (
                "El pre-test se cierra al entrar al recorrido guiado: mide lo que "
                "sabías antes de verlo."
            )
        posttest_reason = (
            f"En el laboratorio, completa {self.REQUIRED_LAB_CYCLES} retos guiados "
            "y responde la pregunta del módulo."
        )
        if module_id == "module_3":
            posttest_reason = (
                f"En el laboratorio, completa {self.REQUIRED_LAB_CYCLES} retos "
                "guiados o toda la exploración avanzada, y responde la pregunta "
                "del módulo."
            )
        labels = {
            "guided": "Completa el pre-test del módulo.",
            "laboratory": "Completa el recorrido guiado del módulo.",
            "posttest": posttest_reason,
            "results": "Completa el post-test del módulo.",
        }
        return labels.get(stage, "Etapa no disponible.")

    # ── Recorrido guiado: cada paso se completa al intentar su comprobación ──

    @Slot(str)
    def enterGuidedTour(self, module_id: str) -> None:
        """Marca la entrada al recorrido; desde aquí el pre-test queda cerrado."""
        if (
            module_id not in self._catalog.module_ids
            or not self.stageAvailable(module_id, "guided")
        ):
            return
        state = self._module_state(module_id)
        if state.get("guided_entered"):
            return
        state["guided_entered"] = True
        self._persist()
        self.progressChanged.emit()

    @Slot(str, str)
    def completeGuidedStep(self, module_id: str, step_id: str) -> None:
        if (
            module_id not in self._catalog.module_ids
            or not self.stageAvailable(module_id, "guided")
        ):
            return
        state = self._module_state(module_id)
        completed = state.setdefault("guided_steps_completed", [])
        if step_id and step_id not in completed:
            completed.append(step_id)
            self._persist()
            self.progressChanged.emit()

    @Slot(str, str, int, result="QVariantMap")
    def recordGuidedCheck(
        self, module_id: str, step_id: str, option_index: int
    ) -> dict[str, Any]:
        """Califica la predicción de un paso y lo marca como trabajado.

        Se guarda si el primer intento fue correcto: es el indicador que se
        cruza después con la ganancia pre→post de ese concepto.
        """
        if (
            module_id not in self._catalog.module_ids
            or not self.stageAvailable(module_id, "guided")
        ):
            return {}
        step = next(
            (
                item
                for item in self._catalog.get(module_id)["guided_steps"]
                if item["id"] == step_id
            ),
            None,
        )
        check = (step or {}).get("check")
        if not check or not 0 <= int(option_index) < len(check["options"]):
            return {}
        correct = int(option_index) == int(check["correct_index"])
        state = self._module_state(module_id)
        record = state.setdefault("guided_checks", {}).setdefault(
            step_id, {"attempts": 0, "first_correct": correct}
        )
        record["attempts"] = int(record.get("attempts", 0)) + 1
        completed = state.setdefault("guided_steps_completed", [])
        if step_id not in completed:
            completed.append(step_id)
        self._persist()
        self.progressChanged.emit()
        return {
            "correct": correct,
            "correct_index": int(check["correct_index"]),
            "feedback": str(check.get("feedback", "")),
        }

    def _pending_guided_checks(self, module_id: str) -> list[str]:
        if not self._catalog.has_alignment:
            return []
        attempted = self._module_state(module_id).get("guided_checks", {})
        return [
            step["id"]
            for step in self._catalog.get(module_id)["guided_steps"]
            if step["id"] not in attempted
        ]

    @Slot(str, result=bool)
    def completeGuidedTour(self, module_id: str) -> bool:
        if (
            module_id not in self._catalog.module_ids
            or not self.stageAvailable(module_id, "guided")
        ):
            return False
        # Mirar los ocho pasos no basta: sin intentar sus predicciones el
        # recorrido no queda completo.
        if self._pending_guided_checks(module_id):
            return False
        state = self._module_state(module_id)
        state["guided_steps_completed"] = [
            step["id"] for step in self._catalog.get(module_id)["guided_steps"]
        ]
        state["guided_completed"] = True
        self._persist()
        self.progressChanged.emit()
        return True

    @Slot(str, result="QVariantMap")
    def guidedProgress(self, module_id: str) -> dict[str, Any]:
        if module_id not in self._catalog.module_ids:
            return {}
        checks = self._module_state(module_id).get("guided_checks", {})
        steps = self._catalog.get(module_id)["guided_steps"]
        return {
            "attempted": [step["id"] for step in steps if step["id"] in checks],
            "first_correct": [
                step["id"]
                for step in steps
                if checks.get(step["id"], {}).get("first_correct")
            ],
            "pending": self._pending_guided_checks(module_id),
            "total": len(steps),
            "focus_step_ids": self._focus_step_ids(module_id),
        }

    def _focus_step_ids(self, module_id: str) -> list[str]:
        """Pasos cuyos conceptos fallaron en el pre-test que cuenta (el primero)."""
        failed = {
            str(answer.get("concept_id", ""))
            for answer in self._result(module_id, "pre").get("answers", [])
            if not answer.get("correcto")
        }
        return [
            step["id"]
            for step in self._catalog.get(module_id)["guided_steps"]
            if step.get("concept_id") in failed
        ]

    # ── Laboratorio: práctica con predicción, contrafactual y explicación ──

    @Slot(str)
    def recordLaboratoryAnalysis(self, module_id: str) -> None:
        """Un forward real ejecutado. Se registra, pero no completa la etapa."""
        if (
            module_id not in self._catalog.module_ids
            or not self.stageAvailable(module_id, "laboratory")
        ):
            return
        state = self._module_state(module_id)
        state["laboratory_runs"] = int(state.get("laboratory_runs", 0)) + 1
        self._persist()
        self.progressChanged.emit()

    @Slot(str, str, bool, int)
    def recordDiscoveryCycle(
        self,
        module_id: str,
        step_id: str,
        prediction_correct: bool,
        explanation_attempts: int,
    ) -> None:
        if (
            module_id not in self._catalog.module_ids
            or not self.stageAvailable(module_id, "laboratory")
            or not step_id
        ):
            return
        state = self._module_state(module_id)
        state.setdefault("lab_cycles", []).append(
            {
                "step_id": str(step_id),
                "prediction_correct": bool(prediction_correct),
                "explanation_attempts": max(0, int(explanation_attempts)),
            }
        )
        self._refresh_laboratory_completion(module_id)

    @Slot(str, int, result="QVariantMap")
    def recordAnchorClosing(self, module_id: str, option_index: int) -> dict[str, Any]:
        if (
            module_id not in self._catalog.module_ids
            or not self.stageAvailable(module_id, "laboratory")
        ):
            return {}
        closing = (self._catalog.get(module_id).get("anchor") or {}).get("closing")
        if not closing or not 0 <= int(option_index) < len(closing["options"]):
            return {}
        correct = int(option_index) == int(closing["correct_index"])
        state = self._module_state(module_id)
        record = state.get("anchor_closing") or {
            "attempts": 0,
            "first_correct": correct,
        }
        record["attempts"] = int(record.get("attempts", 0)) + 1
        state["anchor_closing"] = record
        self._refresh_laboratory_completion(module_id)
        return {
            "correct": correct,
            "correct_index": int(closing["correct_index"]),
            "feedback": str(closing.get("feedback", "")),
        }

    def _distinct_cycles(self, module_id: str) -> int:
        cycles = self._module_state(module_id).get("lab_cycles", [])
        return len({str(item.get("step_id", "")) for item in cycles} - {""})

    def _advanced_paths(self, module_id: str) -> dict[str, dict[str, Any]]:
        raw = self._module_state(module_id).get("advanced_lab_paths", {})
        return raw if isinstance(raw, dict) else {}

    @staticmethod
    def _advanced_path_counts(path: dict[str, Any]) -> tuple[int, int]:
        expected = {str(value) for value in path.get("expected_step_ids", []) if value}
        visited = {str(value) for value in path.get("visited_step_ids", []) if value}
        return len(visited & expected), len(expected)

    def _advanced_path_completed(self, module_id: str) -> bool:
        if module_id != "module_3":
            return False
        for path in self._advanced_paths(module_id).values():
            if not isinstance(path, dict):
                continue
            visited, required = self._advanced_path_counts(path)
            if required >= self.REQUIRED_LAB_CYCLES and visited >= required:
                return True
        return False

    def _best_advanced_path(self, module_id: str) -> tuple[str, int, int]:
        best = ("", 0, 0)
        best_ratio = -1.0
        for mode, path in self._advanced_paths(module_id).items():
            if not isinstance(path, dict):
                continue
            visited, required = self._advanced_path_counts(path)
            ratio = visited / required if required else 0.0
            if ratio > best_ratio or (ratio == best_ratio and visited > best[1]):
                best = (str(mode), visited, required)
                best_ratio = ratio
        return best

    @Slot(str, str, str, "QVariantList", result="QVariantMap")
    def recordAdvancedLaboratoryStep(
        self,
        module_id: str,
        mode: str,
        step_id: str,
        expected_step_ids: list[Any],
    ) -> dict[str, Any]:
        """Registra una operación realmente recorrida en la ruta avanzada.

        Una ruta cuenta como terminada sólo al visitar todas las operaciones
        anunciadas por el laboratorio en un mismo modo. La pregunta de cierre
        sigue siendo obligatoria antes de desbloquear el post-test.
        """
        if (
            module_id not in self._catalog.module_ids
            or module_id != "module_3"
            or not self.stageAvailable(module_id, "laboratory")
        ):
            return {}
        normalized_mode = str(mode).strip().lower()
        if normalized_mode not in {"inference", "training"}:
            return {}
        expected: list[str] = []
        for value in expected_step_ids or []:
            identifier = str(value).strip()
            if identifier and identifier not in expected:
                expected.append(identifier)
        identifier = str(step_id).strip()
        if len(expected) < self.REQUIRED_LAB_CYCLES or identifier not in expected:
            return {}

        state = self._module_state(module_id)
        paths = state.setdefault("advanced_lab_paths", {})
        path = paths.setdefault(normalized_mode, {})
        previous_expected = [str(value) for value in path.get("expected_step_ids", [])]
        previous_visited = [str(value) for value in path.get("visited_step_ids", [])]
        visited = [value for value in previous_visited if value in expected]
        if identifier not in visited:
            visited.append(identifier)
        changed = previous_expected != expected or previous_visited != visited
        path["expected_step_ids"] = expected
        path["visited_step_ids"] = visited
        if changed:
            self._refresh_laboratory_completion(module_id)
        progress = self.laboratoryProgress(module_id)
        current_visited, current_required = self._advanced_path_counts(path)
        progress.update(
            {
                "advanced_mode": normalized_mode,
                "advanced_steps": current_visited,
                "advanced_required": current_required,
            }
        )
        return progress

    def _laboratory_requirements_met(self, module_id: str) -> bool:
        if not self._catalog.has_alignment:
            return True
        state = self._module_state(module_id)
        practice_completed = (
            self._distinct_cycles(module_id) >= self.REQUIRED_LAB_CYCLES
            or self._advanced_path_completed(module_id)
        )
        return practice_completed and bool(state.get("anchor_closing"))

    def _refresh_laboratory_completion(self, module_id: str) -> None:
        state = self._module_state(module_id)
        if not state.get("laboratory_completed") and self._laboratory_requirements_met(
            module_id
        ):
            state["laboratory_completed"] = True
        self._persist()
        self.progressChanged.emit()

    @Slot(str, result=bool)
    def completeLaboratory(self, module_id: str) -> bool:
        """Cierra el laboratorio sólo si la práctica exigida ya ocurrió."""
        if (
            module_id not in self._catalog.module_ids
            or not self.stageAvailable(module_id, "laboratory")
        ):
            return False
        state = self._module_state(module_id)
        if state.get("laboratory_completed"):
            return True
        if not self._laboratory_requirements_met(module_id):
            return False
        state["laboratory_completed"] = True
        self._persist()
        self.progressChanged.emit()
        return True

    @Slot(str, result="QVariantMap")
    def laboratoryProgress(self, module_id: str) -> dict[str, Any]:
        if module_id not in self._catalog.module_ids:
            return {}
        state = self._module_state(module_id)
        advanced_mode, advanced_steps, advanced_required = self._best_advanced_path(
            module_id
        )
        advanced_completed = self._advanced_path_completed(module_id)
        cycles = self._distinct_cycles(module_id)
        return {
            "cycles": cycles,
            "required_cycles": self.REQUIRED_LAB_CYCLES,
            "cycle_step_ids": sorted(
                {str(item.get("step_id", "")) for item in state.get("lab_cycles", [])}
                - {""}
            ),
            "closing_answered": bool(state.get("anchor_closing")),
            "advanced_mode": advanced_mode,
            "advanced_steps": advanced_steps,
            "advanced_required": advanced_required,
            "advanced_completed": advanced_completed,
            "practice_ready": (
                cycles >= self.REQUIRED_LAB_CYCLES or advanced_completed
            ),
            "completed": bool(state.get("laboratory_completed")),
        }

    # ── Repaso espaciado del módulo anterior ──

    @Slot(str, result="QVariantMap")
    def spacedReview(self, module_id: str) -> dict[str, Any]:
        """Retos del módulo anterior para repasar al abrir ``module_id``.

        Usa retos de laboratorio, no reactivos del test: repasar con el
        instrumento lo volvería a exponer y sesgaría futuras aplicaciones.
        """
        if module_id not in self._catalog.module_ids or not self._catalog.has_alignment:
            return {"available": False}
        order = int(self._catalog.get(module_id)["order"])
        if order == 1:
            return {"available": False}
        previous = self._catalog.modules[order - 2]
        if not self._stage_done(previous["id"], "posttest"):
            return {"available": False}
        answered = self._module_state(previous["id"]).get("retention", {})
        items = []
        for index in self.REVIEW_ITEM_INDICES:
            challenge = previous["lab_challenges"][index]
            items.append(
                {
                    "id": challenge["id"],
                    "prompt": challenge["prompt"],
                    "options": list(challenge["options"]),
                    "answered": challenge["id"] in answered,
                    "correct": bool(answered.get(challenge["id"], {}).get("correct")),
                }
            )
        return {
            "available": True,
            "module_id": previous["id"],
            "module_title": previous["title"],
            "items": items,
            "completed": all(item["answered"] for item in items),
        }

    @Slot(str, str, int, result="QVariantMap")
    def recordReviewAnswer(
        self, previous_module_id: str, item_id: str, option_index: int
    ) -> dict[str, Any]:
        if previous_module_id not in self._catalog.module_ids:
            return {}
        challenge = next(
            (
                item
                for item in self._catalog.get(previous_module_id).get("lab_challenges", [])
                if item["id"] == item_id
            ),
            None,
        )
        if not challenge or not 0 <= int(option_index) < len(challenge["options"]):
            return {}
        correct = int(option_index) == int(challenge["correct_index"])
        retention = self._module_state(previous_module_id).setdefault("retention", {})
        # Sólo cuenta el primer intento: es el que mide retención.
        retention.setdefault(item_id, {"correct": correct})
        self._persist()
        self.progressChanged.emit()
        return {
            "correct": correct,
            "correct_index": int(challenge["correct_index"]),
            "feedback": str(challenge.get("explanation", "")),
        }

    @Slot(str)
    def markResultsViewed(self, module_id: str) -> None:
        if (
            module_id not in self._catalog.module_ids
            or not self.stageAvailable(module_id, "results")
        ):
            return
        self._module_state(module_id)["results_viewed"] = True
        next_id = self._catalog.next_id(module_id)
        if next_id and (self.REVIEW_MODE_UNLOCK_ALL or not self.FOCUS_MODULE_ID):
            self._current_module_id = next_id
            self.moduleChanged.emit()
        self._persist()
        self.progressChanged.emit()

    @Slot(str, result="QVariantMap")
    def moduleResults(self, module_id: str) -> dict[str, Any]:
        if module_id not in self._catalog.module_ids:
            return {}
        return self._build_results(module_id)

    @Slot(str, str, str, result=str)
    def exportarResultados(self, module_id: str, destino: str, apodo: str = "") -> str:
        """Guarda el resumen ligero del módulo; devuelve la ruta o ``""``.

        Es el respaldo si la red del aula falla y el archivo que se sube a la
        encuesta de la página web (ver ``model.aprendizaje.exportacion_resultados``).
        """
        if module_id not in self._catalog.module_ids or not destino:
            return ""
        resultados = self._build_results(module_id)
        if not resultados.get("pre") and not resultados.get("post"):
            return ""
        url = QUrl(destino)
        ruta = Path(url.toLocalFile()) if url.isLocalFile() else Path(destino)
        resumen = exportacion_resultados.resumen_modulo(
            resultados, self._interaction_summary(module_id), apodo
        )
        try:
            return str(exportacion_resultados.guardar(ruta, resumen))
        except OSError:
            return ""

    def _build_results(self, module_id: str) -> dict[str, Any]:
        pre = self._result(module_id, "pre")
        post = self._result(module_id, "post")
        if not pre and not post:
            return {"available": False, "module_id": module_id}

        pre_version = _instrument_version(pre)
        post_version = _instrument_version(post)
        comparable = bool(
            pre
            and post
            and pre_version > 0
            and pre_version == post_version
        )
        pre_pct = float(pre.get("percentage", 0))
        post_pct = float(post.get("percentage", 0))
        delta = round(post_pct - pre_pct, 1) if comparable else 0.0
        relative = (
            round(delta * 100 / pre_pct, 1)
            if comparable and pre_pct > 0
            else (100.0 if post_pct > 0 and comparable else 0.0)
        )
        by_pre = {item.get("id"): item for item in pre.get("dimensions", [])}
        by_post = {item.get("id"): item for item in post.get("dimensions", [])}
        module = self._catalog.get(module_id)
        concept_rows = []
        for concept in module["concepts"]:
            before = by_pre.get(concept["id"], {})
            after = by_post.get(concept["id"], {})
            row_comparable = comparable and bool(before) and bool(after)
            before_pct = float(before.get("percentage", 0))
            after_pct = float(after.get("percentage", 0))
            concept_rows.append(
                {
                    "id": concept["id"],
                    "name": concept["title"],
                    "pre_percentage": before_pct,
                    "post_percentage": after_pct,
                    "delta_percentage": round(after_pct - before_pct, 1)
                    if comparable
                    else 0.0,
                    "normalized_gain": self._normalized_gain(before_pct, after_pct)
                    if row_comparable
                    else None,
                    "assessed_pre": bool(before),
                    "assessed_post": bool(after),
                    "comparable": row_comparable,
                    "step": self._catalog.step_for_concept(module_id, concept["id"]),
                }
            )
        assessed_post = [row for row in concept_rows if row["assessed_post"]]
        mastered = [row["name"] for row in assessed_post if row["post_percentage"] >= 80]
        reinforce = [row["name"] for row in assessed_post if row["post_percentage"] < 70]
        recommendations = [
            self._recommendation_for(module, row)
            for row in assessed_post
            if row["post_percentage"] < 70
        ]
        errors: dict[str, int] = {}
        for answer in post.get("answers", []):
            if not answer.get("correcto"):
                concept_id = str(answer.get("concept_id", answer.get("dimension_id", "")))
                errors[concept_id] = errors.get(concept_id, 0) + 1
        frequent_errors = [
            {"concept_id": key, "count": value}
            for key, value in sorted(errors.items(), key=lambda item: (-item[1], item[0]))
        ]
        return {
            "available": bool(post),
            "module_id": module_id,
            "module_title": self._catalog.get(module_id)["title"],
            "pre": pre,
            "post": post,
            "comparable": comparable,
            "instrument_version_pre": pre_version,
            "instrument_version_post": post_version,
            "pre_percentage": pre_pct,
            "post_percentage": post_pct,
            # La comparación usa el primer intento; las repeticiones se cuentan.
            "attempts": {
                "pre": self._attempt_count(module_id, "pre"),
                "post": self._attempt_count(module_id, "post"),
            },
            "delta_percentage": delta,
            "relative_improvement": relative,
            "normalized_gain": self._normalized_gain(pre_pct, post_pct)
            if comparable
            else None,
            "recommendations": recommendations,
            "review": self._post_review(module_id, post),
            "interaction": self._interaction_summary(module_id),
            "duration_seconds": round(
                float(pre.get("duration_seconds", 0))
                + float(post.get("duration_seconds", 0)),
                1,
            ),
            "concepts": concept_rows,
            "mastered": mastered,
            "needs_reinforcement": reinforce,
            "frequent_errors": frequent_errors,
            "difficulty": post.get("bloom", []),
            "recommendation": (
                # Repetir el pre-test no lo arregla: cuenta el primer intento.
                "El instrumento cambió entre tu primer pre-test y tu primer "
                "post-test, así que no se pueden comparar."
                if pre and post and not comparable
                else (
                    "Repasa "
                    + ", ".join(item["label"] for item in recommendations[:3])
                    + " antes de continuar."
                    if recommendations
                    else "Puedes continuar: los conceptos evaluados muestran un dominio sólido."
                )
            ),
        }

    @staticmethod
    def _normalized_gain(pre_pct: float, post_pct: float) -> float | None:
        """Ganancia normalizada de Hake: qué fracción de lo que faltaba se ganó.

        Con pre = 100 no queda margen y la ganancia no está definida.
        """
        if pre_pct >= 100:
            return None
        return round((post_pct - pre_pct) / (100 - pre_pct), 3)

    def _recommendation_for(
        self, module: dict[str, Any], row: dict[str, Any]
    ) -> dict[str, Any]:
        step = row.get("step") or {}
        lab = next(
            (
                item
                for item in module.get("lab_challenges", [])
                if item.get("concept_id") == row["id"]
            ),
            {},
        )
        label = row["name"]
        if step:
            label += f" (paso {step['index'] + 1}: {step['title']})"
        return {
            "concept_id": row["id"],
            "name": row["name"],
            "label": label,
            "step": step,
            "lab_prompt": str(lab.get("prompt", "")),
        }

    def _post_review(self, module_id: str, post: dict[str, Any]) -> list[dict[str, Any]]:
        """Revisión reactivo por reactivo del post-test.

        Sólo del post: mostrar claves tras el pre-test enseñaría las respuestas
        de los reactivos paralelos antes de la intervención.
        """
        key_source = getattr(self._evaluation, "answer_key", None)
        concepts = {
            item["id"]: item for item in self._catalog.get(module_id)["concepts"]
        }
        review = []
        for answer in post.get("answers", []):
            question_id = str(answer.get("question_id", ""))
            key = key_source(module_id, "post", question_id) if key_source else {}
            concept_id = str(answer.get("concept_id", key.get("concept_id", "")))
            concept = concepts.get(concept_id, {})
            review.append(
                {
                    "question_id": question_id,
                    "prompt": str(answer.get("prompt", "")),
                    "correct": bool(answer.get("correcto")),
                    "score": float(answer.get("puntaje", 0)),
                    "max_score": float(answer.get("maximo", 1)),
                    "correct_text": str(key.get("correct_text", "")),
                    "explanation": str(key.get("explanation", ""))
                    or str(concept.get("description", "")),
                    "concept_id": concept_id,
                    "concept_name": str(concept.get("title", concept_id)),
                    "step": self._catalog.step_for_concept(module_id, concept_id),
                }
            )
        return review

    def _interaction_summary(self, module_id: str) -> dict[str, Any]:
        """Lo que el alumno hizo entre pre y post, para cruzarlo con su ganancia."""
        state = self._module_state(module_id)
        checks = state.get("guided_checks", {})
        cycles = state.get("lab_cycles", [])
        closing = state.get("anchor_closing") or {}
        return {
            "guided_checks_attempted": len(checks),
            "guided_checks_first_correct": sum(
                1 for item in checks.values() if item.get("first_correct")
            ),
            "lab_cycles": len(cycles),
            "lab_cycles_distinct": self._distinct_cycles(module_id),
            "lab_predictions_correct": sum(
                1 for item in cycles if item.get("prediction_correct")
            ),
            "lab_runs": int(state.get("laboratory_runs", 0)),
            "anchor_closing_first_correct": bool(closing.get("first_correct")),
        }

    @Slot("QVariantMap")
    def recordModelConfiguration(self, configuration: dict[str, Any]) -> None:
        self._state["model_configuration"] = deepcopy(dict(configuration or {}))
        self._persist()

    @Slot()
    def resetCourse(self) -> None:
        self._evaluation.repository.clear_module_results(self._student_filter())
        self._repository.clear()
        self._state = self._repository.snapshot()
        self._current_module_id = (
            self.FOCUS_MODULE_ID
            if self.FOCUS_MODULE_ID in self._catalog.module_ids
            else self._catalog.module_ids[0]
        )
        self.moduleChanged.emit()
        self.progressChanged.emit()

    @Slot("QVariantMap")
    def _on_evaluation_completed(self, result: dict[str, Any]) -> None:
        module_id = str(result.get("module_id", ""))
        assessment = str(result.get("assessment_type", ""))
        if module_id not in self._catalog.module_ids or assessment not in ("pre", "post"):
            return
        state = self._module_state(module_id)
        attempts = state.setdefault("attempts", {"pre": 0, "post": 0})
        attempts[assessment] = int(attempts.get(assessment, 0)) + 1
        state.setdefault("question_ids_used", {})[assessment] = list(
            result.get("question_ids_used", [])
        )
        state["time_seconds"] = round(
            float(state.get("time_seconds", 0))
            + float(result.get("duration_seconds", 0)),
            1,
        )
        if assessment == "post":
            state["difficult_concepts"] = [
                row["id"]
                for row in result.get("dimensions", [])
                if float(row.get("percentage", 0)) < 70
            ]
        self._current_module_id = (
            module_id
            if self.REVIEW_MODE_UNLOCK_ALL or not self.FOCUS_MODULE_ID
            else self.FOCUS_MODULE_ID
        )
        self._persist()
        self.moduleChanged.emit()
        self.progressChanged.emit()
