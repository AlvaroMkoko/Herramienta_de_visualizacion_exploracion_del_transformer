"""Evaluación reutilizable, acotada al módulo activo del curso."""

from __future__ import annotations

from typing import Any

from PySide6.QtCore import Property, Signal, Slot

from model.aprendizaje import LearningModuleCatalog, ModuleQuestionBank
from model.evaluacion import EvaluationManager, QuestionBankError, ResultsRepository

from .evaluation_controller import EvaluationController


class ModuleEvaluationController(EvaluationController):
    """Especializa el controlador existente sin duplicar el flujo de examen."""

    moduleChanged = Signal()

    def __init__(
        self,
        parent=None,
        catalog: LearningModuleCatalog | None = None,
        repository: ResultsRepository | None = None,
    ) -> None:
        self._catalog = catalog or LearningModuleCatalog()
        self._module_bank = ModuleQuestionBank(self._catalog)
        self._module_id = self._module_bank.module_id
        super().__init__(
            parent=parent,
            question_bank=self._module_bank,
            repository=repository,
        )

    @Property(str, notify=moduleChanged)
    def moduleId(self) -> str:
        return self._module_id

    @Property("QVariantMap", notify=moduleChanged)
    def module(self) -> dict[str, Any]:
        return self._catalog.get(self._module_id)

    def _latest(self, assessment_type: str) -> dict[str, Any]:
        return self._repository.latest(
            assessment_type,
            self._student_filter(),
            module_id=self._module_id,
        )

    @Property("QVariantList", notify=EvaluationController.questionChanged)
    def history(self) -> list[dict[str, Any]]:
        return self._repository.get_history(
            student_id=self._student_filter(), module_id=self._module_id
        )

    def _used_question_ids(self, assessment_type: str) -> list[str]:
        history = self._repository.get_history(
            assessment_type=assessment_type,
            student_id=self._student_filter(),
            module_id=self._module_id,
        )
        used: list[str] = []
        for result in history:
            ids = result.get("question_ids_used")
            if not isinstance(ids, list):
                ids = [
                    item.get("question_id")
                    for item in result.get("answers", [])
                    if isinstance(item, dict)
                ]
            for question_id in ids:
                normalized = str(question_id or "")
                if normalized and normalized not in used:
                    used.append(normalized)
        return used

    def _select_module(self, module_id: str) -> bool:
        try:
            self._catalog.get(module_id)
            self._module_bank.set_module(module_id)
        except (QuestionBankError, ValueError) as exc:
            self.error.emit(str(exc))
            return False
        changed = module_id != self._module_id
        self._module_id = module_id
        self._bank = self._module_bank
        self._manager = EvaluationManager(self._bank)
        if changed:
            self.moduleChanged.emit()
        return True

    @Slot(str, str)
    def prepareModuleEvaluation(self, module_id: str, assessment_type: str) -> None:
        if not self._select_module(module_id):
            return
        self.prepareEvaluation(assessment_type)

    @Slot(str, str)
    def startModuleEvaluation(self, module_id: str, assessment_type: str) -> None:
        if not self._select_module(module_id):
            return
        self._module_bank.start_attempt(
            assessment_type, self._used_question_ids(assessment_type)
        )
        self.startEvaluation(assessment_type)

    def _enrich_result(self, result: dict[str, Any]) -> dict[str, Any]:
        module = self._catalog.get(self._module_id)
        result["module_id"] = self._module_id
        result["module_title"] = module["title"]
        result["question_ids_used"] = [
            str(question.get("id", "")) for question in self._manager.questions
        ]
        result["difficulty_counts"] = {
            difficulty: len(
                [
                    question
                    for question in self._manager.questions
                    if question.get("difficulty") == difficulty
                ]
            )
            for difficulty in ("Básica", "Intermedia", "Avanzada")
        }
        return result
