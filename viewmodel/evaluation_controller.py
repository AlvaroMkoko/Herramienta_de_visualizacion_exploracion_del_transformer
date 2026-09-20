"""ViewModel del pre-test y post-test."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from PySide6.QtCore import (
    Property,
    QObject,
    QStandardPaths,
    Signal,
    Slot,
)

from model.evaluacion import (
    EvaluationManager,
    EvaluationStateError,
    QuestionBank,
    QuestionBankError,
    ResultsRepository,
)


def _ruta_resultados() -> Path:
    base = QStandardPaths.writableLocation(QStandardPaths.AppDataLocation)
    return Path(base) / "resultados_evaluacion.json"


class EvaluationController(QObject):
    """Expone a QML solo el estado necesario para presentar la evaluación."""

    stateChanged = Signal()
    evaluationCompleted = Signal("QVariantMap")
    error = Signal(str)

    def __init__(
        self,
        parent: QObject | None = None,
        question_bank: QuestionBank | None = None,
        repository: ResultsRepository | None = None,
    ) -> None:
        super().__init__(parent)
        self._bank = question_bank or QuestionBank()
        self._manager = EvaluationManager(self._bank)
        self._repository = repository or ResultsRepository(_ruta_resultados())
        self._assessment_type = "pre"
        self._assessment_info: dict[str, Any] = {}
        self._selected_option_id = ""
        self._result: dict[str, Any] = {}
        self._prepare("pre")

    def _prepare(self, assessment_type: str) -> None:
        normalized = str(assessment_type).lower().strip()
        self._assessment_info = self._bank.get_assessment(normalized)
        self._assessment_type = normalized

    @Property(str, notify=stateChanged)
    def assessmentType(self) -> str:
        return self._assessment_type

    @Property(str, notify=stateChanged)
    def title(self) -> str:
        return str(self._assessment_info.get("title", "Evaluación"))

    @Property(str, notify=stateChanged)
    def eyebrow(self) -> str:
        return str(self._assessment_info.get("eyebrow", "EVALUACIÓN"))

    @Property(str, notify=stateChanged)
    def description(self) -> str:
        return str(self._assessment_info.get("description", ""))

    @Property(str, notify=stateChanged)
    def instructions(self) -> str:
        return str(self._assessment_info.get("instructions", ""))

    @Property(int, notify=stateChanged)
    def totalQuestions(self) -> int:
        return len(self._assessment_info.get("questions", []))

    @Property("QVariantList", notify=stateChanged)
    def dimensions(self) -> list[dict[str, Any]]:
        questions = self._assessment_info.get("questions", [])
        result = []
        for dimension in self._bank.dimensions:
            count = sum(
                1
                for question in questions
                if question["dimension_id"] == dimension["id"]
            )
            if count:
                result.append({**dimension, "question_count": count})
        return result

    @Property(bool, notify=stateChanged)
    def isActive(self) -> bool:
        return self._manager.active

    @Property(bool, notify=stateChanged)
    def finished(self) -> bool:
        return self._manager.finished

    @Property("QVariantMap", notify=stateChanged)
    def currentQuestion(self) -> dict[str, Any]:
        return self._manager.current_public_question

    @Property(int, notify=stateChanged)
    def currentQuestionNumber(self) -> int:
        if not self._manager.questions:
            return 0
        return self._manager.current_index + 1

    @Property(int, notify=stateChanged)
    def answeredQuestions(self) -> int:
        return len(self._manager.answers)

    @Property(float, notify=stateChanged)
    def progressFraction(self) -> float:
        total = len(self._manager.questions)
        return ((self._manager.current_index + 1) / total) if total else 0.0

    @Property(str, notify=stateChanged)
    def selectedOptionId(self) -> str:
        return self._selected_option_id

    @Property(bool, notify=stateChanged)
    def canContinue(self) -> bool:
        return bool(self._selected_option_id and self._manager.active)

    @Property("QVariantMap", notify=stateChanged)
    def result(self) -> dict[str, Any]:
        return dict(self._result)

    @Property(str, notify=stateChanged)
    def resultMessage(self) -> str:
        if not self._result:
            return ""
        percentage = float(self._result.get("percentage", 0))
        if self._assessment_type == "pre":
            return (
                "Este resultado es tu línea base. Ahora podrás comparar cuánto "
                "avanzaste al completar el post-test."
            )
        if percentage >= 75:
            return "Buen resultado: demuestras dominio de los conceptos evaluados."
        return "Revisa las dimensiones con menor puntuación y repite el recorrido guiado."

    @Property(bool, notify=stateChanged)
    def hasPreviousResult(self) -> bool:
        return bool(self._repository.latest(self._assessment_type))

    @Property("QVariantMap", notify=stateChanged)
    def previousResult(self) -> dict[str, Any]:
        return self._repository.latest(self._assessment_type)

    @Property("QVariantMap", notify=stateChanged)
    def preResult(self) -> dict[str, Any]:
        return self._repository.latest("pre")

    @Property("QVariantMap", notify=stateChanged)
    def postResult(self) -> dict[str, Any]:
        return self._repository.latest("post")

    @Property(bool, notify=stateChanged)
    def hasPre(self) -> bool:
        return bool(self._repository.latest("pre"))

    @Property(bool, notify=stateChanged)
    def hasPost(self) -> bool:
        return bool(self._repository.latest("post"))

    @Property("QVariantList", notify=stateChanged)
    def history(self) -> list[dict[str, Any]]:
        return self._repository.get_history()

    @Property("QVariantMap", notify=stateChanged)
    def improvement(self) -> dict[str, Any]:
        pre = self._repository.latest("pre")
        post = self._repository.latest("post")
        if not pre or not post:
            return {"disponible": False}

        pre_dimensions = {
            dimension.get("id"): dimension
            for dimension in pre.get("dimensions", [])
            if dimension.get("id")
        }
        post_dimensions = {
            dimension.get("id"): dimension
            for dimension in post.get("dimensions", [])
            if dimension.get("id")
        }
        dimensiones = []
        for dimension_id, pre_dimension in pre_dimensions.items():
            post_dimension = post_dimensions.get(dimension_id)
            if post_dimension is None:
                continue
            pre_percentage = float(pre_dimension.get("percentage", 0))
            post_percentage = float(post_dimension.get("percentage", 0))
            dimensiones.append(
                {
                    "id": dimension_id,
                    "name": post_dimension.get(
                        "name", pre_dimension.get("name", dimension_id)
                    ),
                    "pre_percentage": pre_percentage,
                    "post_percentage": post_percentage,
                    "delta_percentage": post_percentage - pre_percentage,
                }
            )
        pre_percentage = float(pre.get("percentage", 0))
        post_percentage = float(post.get("percentage", 0))
        return {
            "disponible": True,
            "pre_percentage": pre_percentage,
            "post_percentage": post_percentage,
            "delta_percentage": post_percentage - pre_percentage,
            "dimensions": dimensiones,
        }

    @Slot(str)
    def prepareEvaluation(self, assessment_type: str) -> None:
        try:
            self._prepare(assessment_type)
        except QuestionBankError as exc:
            self.error.emit(str(exc))
            return
        self._selected_option_id = ""
        self._result = {}
        self.stateChanged.emit()

    @Slot(str)
    def startEvaluation(self, assessment_type: str) -> None:
        try:
            self._prepare(assessment_type)
            self._manager.start_evaluation(self._assessment_type)
        except QuestionBankError as exc:
            self.error.emit(str(exc))
            return
        self._selected_option_id = ""
        self._result = {}
        self.stateChanged.emit()

    @Slot(str)
    def selectAnswer(self, option_id: str) -> None:
        if not self._manager.active:
            return
        valid_ids = {
            option["id"] for option in self._manager.current_question["options"]
        }
        if option_id not in valid_ids:
            return
        if option_id == self._selected_option_id:
            return
        self._selected_option_id = option_id
        self.stateChanged.emit()

    @Slot()
    def submitCurrentAnswer(self) -> None:
        if not self.canContinue:
            return
        question_id = self._manager.current_question["id"]
        try:
            result = self._manager.submit_answer(
                question_id, self._selected_option_id
            )
        except EvaluationStateError as exc:
            self.error.emit(str(exc))
            return

        self._selected_option_id = ""
        if result:
            self._result = result
            self._repository.save_result(result)
        self.stateChanged.emit()
        if result:
            self.evaluationCompleted.emit(dict(result))

    @Slot()
    def borrarHistorial(self) -> None:
        self._repository.clear()
        self._result = {}
        self.stateChanged.emit()
