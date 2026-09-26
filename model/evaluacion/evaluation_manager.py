"""Estado de dominio para una ejecución de pre-test o post-test (esquema v2).

Cambio respecto a v1: ``submit_answer`` ya no recibe el id de una opción, sino
la respuesta completa del reactivo, cuya forma depende de su tipo (ver
:mod:`model.evaluacion.scorers`). Eso es lo que permite que un mismo flujo
soporte opción múltiple, ordenamientos, clasificaciones y reactivos por etapas.
"""

from __future__ import annotations

from copy import deepcopy
from typing import Any

from .metrics import compute_metrics
from .question_bank import QuestionBank
from .scorers import es_respuesta_completa


class EvaluationStateError(ValueError):
    """La operación solicitada no es válida en el estado actual."""


class EvaluationManager:
    def __init__(self, question_bank: QuestionBank | None = None) -> None:
        self.question_bank = question_bank or QuestionBank()
        self.assessment_type = ""
        self.assessment: dict[str, Any] = {}
        self.questions: list[dict[str, Any]] = []
        self.answers: dict[str, Any] = {}
        self.current_index = 0
        self.result: dict[str, Any] = {}

    def start_evaluation(self, assessment_type: str) -> None:
        self.assessment_type = str(assessment_type).lower().strip()
        self.assessment = self.question_bank.get_assessment(self.assessment_type)
        self.questions = self.assessment["questions"]
        self.answers = {}
        self.current_index = 0
        self.result = {}

    # ------------------------------------------------------------------
    # Estado
    # ------------------------------------------------------------------

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

    @property
    def is_last_question(self) -> bool:
        return bool(self.questions) and self.current_index == len(self.questions) - 1

    def is_answer_complete(self, respuesta: Any) -> bool:
        """¿La respuesta en curso habilita el botón de continuar?"""
        question = self.current_question
        return bool(question) and es_respuesta_completa(question, respuesta)

    # ------------------------------------------------------------------
    # Navegación hacia atrás
    # ------------------------------------------------------------------

    @property
    def frontier_index(self) -> int:
        """Índice del primer reactivo todavía sin contestar.

        Es el límite de hasta dónde se puede navegar: hacia atrás, cualquier
        reactivo ya contestado; hacia adelante, como mucho el primero que falta.
        Nunca se puede saltar por encima de un reactivo en blanco, porque
        ``score_evaluation`` exige que estén todos y porque dejar huecos
        convertiría el instrumento en otro: quien contesta salteado elige qué
        reactivos responder, y eso cambia lo que mide la puntuación total.
        """
        for indice, question in enumerate(self.questions):
            if str(question["id"]) not in self.answers:
                return indice
        return max(len(self.questions) - 1, 0)

    @property
    def is_revisiting(self) -> bool:
        """¿El reactivo en pantalla es uno al que se volvió?"""
        return self.active and self.current_index < self.frontier_index

    def can_go_to(self, indice: int) -> bool:
        if not self.active:
            return False
        return 0 <= int(indice) <= self.frontier_index

    def go_to(self, indice: int) -> None:
        destino = int(indice)
        if not self.can_go_to(destino):
            raise EvaluationStateError(
                "No se puede ir a ese reactivo desde el estado actual."
            )
        self.current_index = destino

    def can_go_back(self) -> bool:
        return self.active and self.current_index > 0

    def go_back(self) -> None:
        if not self.can_go_back():
            raise EvaluationStateError("No hay un reactivo anterior.")
        self.current_index -= 1

    def answer_for(self, question_id: str) -> Any:
        """Respuesta guardada de un reactivo, o ``None``.

        Se devuelve una copia: quien la reciba va a editarla mientras el
        estudiante cambia de opinión, y esos cambios no deben tocar lo ya
        registrado hasta que se vuelva a enviar.
        """
        guardada = self.answers.get(str(question_id))
        return deepcopy(guardada) if guardada is not None else None

    # ------------------------------------------------------------------
    # Avance
    # ------------------------------------------------------------------

    def submit_answer(self, question_id: str, respuesta: Any) -> dict[str, Any]:
        """Registra la respuesta y avanza. Devuelve ``{}`` salvo en el último
        reactivo, donde devuelve el resultado calculado."""
        if not self.active:
            raise EvaluationStateError("No hay una evaluación activa.")

        question = self.current_question
        if question_id != question["id"]:
            raise EvaluationStateError(
                "La respuesta no corresponde a la pregunta actual."
            )
        if not es_respuesta_completa(question, respuesta):
            raise EvaluationStateError("La respuesta está incompleta.")

        self.answers[question_id] = deepcopy(respuesta)

        if self.is_last_question:
            self.result = self.score_evaluation()
            return deepcopy(self.result)

        self.current_index += 1
        return {}

    def score_evaluation(self) -> dict[str, Any]:
        if len(self.answers) != len(self.questions):
            raise EvaluationStateError(
                "La evaluación todavía tiene preguntas pendientes."
            )
        return compute_metrics(
            self.assessment_type,
            self.questions,
            self.answers,
            self.question_bank.dimensions,
            self.question_bank.instrument_version,
        )
