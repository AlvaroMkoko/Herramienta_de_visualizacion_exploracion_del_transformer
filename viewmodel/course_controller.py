"""Coordinador MVVM del curso modular progresivo."""

from __future__ import annotations

from copy import deepcopy
from typing import Any

from PySide6.QtCore import Property, QObject, Signal, Slot

from core.rutas import dato
from model.aprendizaje import LearningModuleCatalog, ModuleProgressRepository


STAGES = ("pretest", "guided", "laboratory", "posttest", "results")


class CourseController(QObject):
    """Expone catálogo, guardias, progreso persistente y resultados por módulo."""

    progressChanged = Signal()
    moduleChanged = Signal()

    # Interruptor temporal para revisión funcional. Mantiene el registro real
    # de avance, pero permite abrir cualquier módulo y etapa sin prerrequisitos.
    REVIEW_MODE_UNLOCK_ALL = True

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
        self._current_module_id = str(
            self._state.get("current_module_id", self._catalog.module_ids[0])
        )
        if self._current_module_id not in self._catalog.module_ids:
            self._current_module_id = self._catalog.module_ids[0]
        self._evaluation.evaluationCompleted.connect(self._on_evaluation_completed)

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
        return self._evaluation.repository.latest(
            assessment_type,
            self._student_filter(),
            module_id=module_id,
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
        if self.REVIEW_MODE_UNLOCK_ALL:
            return True
        module = self._catalog.get(module_id)
        if module["order"] == 1:
            return True
        previous = self._catalog.modules[module["order"] - 2]["id"]
        return self._stage_done(previous, "results")

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
                "available": self._module_unlocked(module_id),
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
        if self.REVIEW_MODE_UNLOCK_ALL:
            return True
        if not self._module_unlocked(module_id):
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
        if not self._module_unlocked(module_id):
            return "Completa el módulo anterior para desbloquear éste."
        labels = {
            "guided": "Completa el pre-test del módulo.",
            "laboratory": "Completa el recorrido guiado del módulo.",
            "posttest": "Realiza al menos una práctica en el laboratorio.",
            "results": "Completa el post-test del módulo.",
        }
        return labels.get(stage, "Etapa no disponible.")

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

    @Slot(str)
    def completeGuidedTour(self, module_id: str) -> None:
        if (
            module_id not in self._catalog.module_ids
            or not self.stageAvailable(module_id, "guided")
        ):
            return
        state = self._module_state(module_id)
        state["guided_steps_completed"] = [
            step["id"] for step in self._catalog.get(module_id)["guided_steps"]
        ]
        state["guided_completed"] = True
        self._persist()
        self.progressChanged.emit()

    @Slot(str)
    def completeLaboratory(self, module_id: str) -> None:
        if (
            module_id not in self._catalog.module_ids
            or not self.stageAvailable(module_id, "laboratory")
        ):
            return
        state = self._module_state(module_id)
        if state.get("laboratory_completed"):
            return
        state["laboratory_completed"] = True
        self._persist()
        self.progressChanged.emit()

    @Slot(str)
    def markResultsViewed(self, module_id: str) -> None:
        if (
            module_id not in self._catalog.module_ids
            or not self.stageAvailable(module_id, "results")
        ):
            return
        self._module_state(module_id)["results_viewed"] = True
        next_id = self._catalog.next_id(module_id)
        if next_id:
            self._current_module_id = next_id
            self.moduleChanged.emit()
        self._persist()
        self.progressChanged.emit()

    @Slot(str, result="QVariantMap")
    def moduleResults(self, module_id: str) -> dict[str, Any]:
        if module_id not in self._catalog.module_ids:
            return {}
        return self._build_results(module_id)

    def _build_results(self, module_id: str) -> dict[str, Any]:
        pre = self._result(module_id, "pre")
        post = self._result(module_id, "post")
        if not pre and not post:
            return {"available": False, "module_id": module_id}

        pre_pct = float(pre.get("percentage", 0))
        post_pct = float(post.get("percentage", 0))
        delta = round(post_pct - pre_pct, 1) if pre and post else 0.0
        relative = (
            round(delta * 100 / pre_pct, 1)
            if pre and post and pre_pct > 0
            else (100.0 if post_pct > 0 and pre and post else 0.0)
        )
        by_pre = {item.get("id"): item for item in pre.get("dimensions", [])}
        by_post = {item.get("id"): item for item in post.get("dimensions", [])}
        concept_rows = []
        for concept in self._catalog.get(module_id)["concepts"]:
            before = by_pre.get(concept["id"], {})
            after = by_post.get(concept["id"], {})
            concept_rows.append(
                {
                    "id": concept["id"],
                    "name": concept["title"],
                    "pre_percentage": float(before.get("percentage", 0)),
                    "post_percentage": float(after.get("percentage", 0)),
                    "delta_percentage": round(
                        float(after.get("percentage", 0))
                        - float(before.get("percentage", 0)),
                        1,
                    ),
                    "assessed_pre": bool(before),
                    "assessed_post": bool(after),
                }
            )
        assessed_post = [row for row in concept_rows if row["assessed_post"]]
        mastered = [row["name"] for row in assessed_post if row["post_percentage"] >= 80]
        reinforce = [row["name"] for row in assessed_post if row["post_percentage"] < 70]
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
            "pre_percentage": pre_pct,
            "post_percentage": post_pct,
            "delta_percentage": delta,
            "relative_improvement": relative,
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
                "Repasa " + ", ".join(reinforce[:3]) + " antes de continuar."
                if reinforce
                else "Puedes continuar: los conceptos evaluados muestran un dominio sólido."
            ),
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
        self._current_module_id = self._catalog.module_ids[0]
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
        self._current_module_id = module_id
        self._persist()
        self.moduleChanged.emit()
        self.progressChanged.emit()
