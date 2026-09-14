"""Carga y valida el banco JSON de pre-test y post-test."""

from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
from typing import Any


DEFAULT_QUESTION_BANK_PATH = (
    Path(__file__).resolve().parents[2] / "data" / "evaluacion" / "question_bank.json"
)


class QuestionBankError(ValueError):
    """El banco no cumple el contrato esperado por la evaluación."""


class QuestionBank:
    """Fuente única de preguntas y respuestas correctas.

    El modelo conserva ``correct_option_id``. La vista obtiene copias públicas
    sin esa clave para que la respuesta no viaje a QML durante el examen.
    """

    VALID_ASSESSMENTS = ("pre", "post")

    def __init__(self, path: str | Path | None = None) -> None:
        self.path = Path(path) if path is not None else DEFAULT_QUESTION_BANK_PATH
        self._data = self._load()
        self._validate()
        self._dimensions = {
            item["id"]: item["name"] for item in self._data["dimensions"]
        }

    def _load(self) -> dict[str, Any]:
        try:
            with self.path.open("r", encoding="utf-8") as source:
                data = json.load(source)
        except (OSError, json.JSONDecodeError) as exc:
            raise QuestionBankError(
                f"No se pudo cargar el banco de preguntas: {exc}"
            ) from exc
        if not isinstance(data, dict):
            raise QuestionBankError("La raíz del banco debe ser un objeto JSON.")
        return data

    def _validate(self) -> None:
        dimensions = self._data.get("dimensions")
        assessments = self._data.get("assessments")
        if not isinstance(dimensions, list) or not dimensions:
            raise QuestionBankError("El banco debe declarar sus dimensiones.")
        if not isinstance(assessments, dict):
            raise QuestionBankError("El banco debe declarar sus evaluaciones.")

        dimension_ids = set()
        for dimension in dimensions:
            if not isinstance(dimension, dict):
                raise QuestionBankError("Cada dimensión debe ser un objeto.")
            dimension_id = str(dimension.get("id", "")).strip()
            name = str(dimension.get("name", "")).strip()
            if not dimension_id or not name or dimension_id in dimension_ids:
                raise QuestionBankError("Las dimensiones deben tener id y nombre únicos.")
            dimension_ids.add(dimension_id)

        question_ids = set()
        for assessment_type in self.VALID_ASSESSMENTS:
            assessment = assessments.get(assessment_type)
            if not isinstance(assessment, dict):
                raise QuestionBankError(
                    f"Falta la evaluación obligatoria {assessment_type!r}."
                )
            questions = assessment.get("questions")
            if not isinstance(questions, list) or not questions:
                raise QuestionBankError(
                    f"La evaluación {assessment_type!r} no tiene preguntas."
                )
            for question in questions:
                self._validate_question(question, dimension_ids, question_ids)

    @staticmethod
    def _validate_question(
        question: Any, dimension_ids: set[str], question_ids: set[str]
    ) -> None:
        if not isinstance(question, dict):
            raise QuestionBankError("Cada pregunta debe ser un objeto.")
        question_id = str(question.get("id", "")).strip()
        if not question_id or question_id in question_ids:
            raise QuestionBankError("Cada pregunta debe tener un id global único.")
        question_ids.add(question_id)
        if question.get("dimension_id") not in dimension_ids:
            raise QuestionBankError(
                f"La pregunta {question_id!r} referencia una dimensión inexistente."
            )
        if not str(question.get("prompt", "")).strip():
            raise QuestionBankError(f"La pregunta {question_id!r} no tiene enunciado.")

        options = question.get("options")
        if not isinstance(options, list) or len(options) < 2:
            raise QuestionBankError(
                f"La pregunta {question_id!r} necesita al menos dos opciones."
            )
        option_ids = [str(option.get("id", "")) for option in options]
        if any(not option_id for option_id in option_ids) or len(option_ids) != len(
            set(option_ids)
        ):
            raise QuestionBankError(
                f"La pregunta {question_id!r} tiene opciones sin id o repetidas."
            )
        if any(not str(option.get("text", "")).strip() for option in options):
            raise QuestionBankError(
                f"La pregunta {question_id!r} tiene una opción sin texto."
            )
        if question.get("correct_option_id") not in option_ids:
            raise QuestionBankError(
                f"La respuesta correcta de {question_id!r} no existe entre sus opciones."
            )

    def get_assessment(self, assessment_type: str) -> dict[str, Any]:
        normalized = str(assessment_type).lower().strip()
        if normalized not in self.VALID_ASSESSMENTS:
            raise QuestionBankError(
                f"Tipo de evaluación desconocido: {assessment_type!r}."
            )
        return deepcopy(self._data["assessments"][normalized])

    def get_questions(self, assessment_type: str) -> list[dict[str, Any]]:
        return self.get_assessment(assessment_type)["questions"]

    @staticmethod
    def public_question(question: dict[str, Any]) -> dict[str, Any]:
        public = deepcopy(question)
        public.pop("correct_option_id", None)
        return public

    def get_public_questions(self, assessment_type: str) -> list[dict[str, Any]]:
        return [
            self.public_question(question)
            for question in self.get_questions(assessment_type)
        ]

    def dimension_name(self, dimension_id: str) -> str:
        return self._dimensions.get(dimension_id, dimension_id)

    @property
    def dimensions(self) -> list[dict[str, str]]:
        return deepcopy(self._data["dimensions"])
