"""Estado de dominio para una ejecución de pre-test o post-test."""

from __future__ import annotations

from copy import deepcopy
from typing import Any

from .metrics import compute_metrics
from .question_bank import QuestionBank


class EvaluationStateError(ValueError):
    """La operación solicitada no es válida en el estado actual."""


class EvaluationManager:
    def __init__(self, question_bank: QuestionBank | None = None) -> None:
        self.question_bank = question_bank or QuestionBank()
        self.assessment_type = ""
        self.assessment: dict[str, Any] = {}
        self.questions: list[dict[str, Any]] = []
        self.answers: dict[str, str] = {}
        self.current_index = 0
        self.result: dict[str, Any] = {}

    def start_evaluation(self, assessment_type: str) -> None:
        self.assessment_type = str(assessment_type).lower().strip()
        self.assessment = self.question_bank.get_assessment(self.assessment_type)
        self.questions = self.assessment["questions"]
        self.answers = {}
        self.current_index = 0
        self.result = {}

    @property
    def active(self) -> bool:
        return bool(self.questions) and not self.finished

    @property
    def finished(self) -> bool:
        return bool(self.result)

    @property
    def current_question(self) -> dict[str, Any]:
        if not self.active:
            return {}
        return self.questions[self.current_index]

    @property
    def current_public_question(self) -> dict[str, Any]:
        question = self.current_question
        return self.question_bank.public_question(question) if question else {}

    def submit_answer(self, question_id: str, option_id: str) -> dict[str, Any]:
        if not self.active:
            raise EvaluationStateError("No hay una evaluación activa.")
        question = self.current_question
        if question_id != question["id"]:
            raise EvaluationStateError("La respuesta no corresponde a la pregunta actual.")
        valid_options = {option["id"] for option in question["options"]}
        if option_id not in valid_options:
            raise EvaluationStateError("La opción elegida no existe.")

        self.answers[question_id] = option_id
        if self.current_index == len(self.questions) - 1:
            self.result = compute_metrics(
                self.assessment_type,
                self.questions,
                self.answers,
                self.question_bank.dimensions,
            )
            return deepcopy(self.result)

        self.current_index += 1
        return {}

    def score_evaluation(self) -> dict[str, Any]:
        if len(self.answers) != len(self.questions):
            raise EvaluationStateError("La evaluación todavía tiene preguntas pendientes.")
        if not self.result:
            self.result = compute_metrics(
                self.assessment_type,
                self.questions,
                self.answers,
                self.question_bank.dimensions,
            )
        return deepcopy(self.result)
