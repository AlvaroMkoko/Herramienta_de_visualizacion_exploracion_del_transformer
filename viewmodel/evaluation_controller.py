"""ViewModel del pre-test y post-test (instrumento v2).

Cambio principal respecto a v1: la respuesta dejó de ser el id de una opción y
pasó a ser un objeto cuya forma depende del tipo de reactivo. QML construye ese
objeto en el delegate correspondiente y lo entrega por
:meth:`registrarRespuesta`; el controlador no interpreta su contenido, solo lo
pasa al modelo. Así, agregar un formato nuevo no toca esta clase.

La retroalimentación se muestra **al final**: durante el examen, ninguna
propiedad expuesta a QML revela si la respuesta en curso es correcta.
"""

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
    es_respuesta_completa,
)


def _ruta_resultados() -> Path:
    base = QStandardPaths.writableLocation(QStandardPaths.AppDataLocation)
    return Path(base) / "resultados_evaluacion.json"


def _a_python(valor: Any) -> Any:
    """Convierte lo que llega de QML en estructuras de Python puras.

    Un objeto de JavaScript suele cruzar como ``dict``, pero según la versión de
    PySide6 puede llegar envuelto en un ``QJSValue``. El modelo solo entiende
    ``dict`` y ``list``: si le llega un envoltorio, califica 0 y el botón de
    continuar nunca se habilita, sin ningún error en consola. La normalización
    se hace aquí, que es la frontera con Qt; el modelo sigue siendo Qt-ciego.
    """
    desenvolver = getattr(valor, "toVariant", None)
    if callable(desenvolver):
        valor = desenvolver()
    if isinstance(valor, dict):
        return {str(clave): _a_python(item) for clave, item in valor.items()}
    if isinstance(valor, (list, tuple)):
        return [_a_python(item) for item in valor]
    return valor


class EvaluationController(QObject):
    """Expone a QML solo el estado necesario para presentar la evaluación."""

    #: Cambió la respuesta en curso. Se emite en cada interacción del
    #: estudiante (cada tecla, cada clic), así que de aquí solo pueden colgar
    #: propiedades baratas y que de verdad cambien con cada pulsación.
    stateChanged = Signal()
    #: Cambió el reactivo mostrado, el resultado o la evaluación preparada.
    #: Separarla de stateChanged es lo que evita que escribir en un campo de
    #: texto invalide `currentQuestion` y provoque un binding loop en QML.
    questionChanged = Signal()
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
        self._respuesta_actual: Any = None
        self._result: dict[str, Any] = {}
        self._prepare("pre")

    def _prepare(self, assessment_type: str) -> None:
        normalized = str(assessment_type).lower().strip()
        self._assessment_info = self._bank.get_assessment(normalized)
        self._assessment_type = normalized

    # ------------------------------------------------------------------
    # Metadatos de la evaluación
    # ------------------------------------------------------------------

    @Property(str, notify=questionChanged)
    def assessmentType(self) -> str:
        return self._assessment_type

    @Property(str, notify=questionChanged)
    def title(self) -> str:
        return str(self._assessment_info.get("title", "Evaluación"))

    @Property(str, notify=questionChanged)
    def eyebrow(self) -> str:
        return str(self._assessment_info.get("eyebrow", "EVALUACIÓN"))

    @Property(str, notify=questionChanged)
    def forma(self) -> str:
        return str(self._assessment_info.get("forma", ""))

    @Property(str, notify=questionChanged)
    def description(self) -> str:
        return str(self._assessment_info.get("description", ""))

    @Property(str, notify=questionChanged)
    def instructions(self) -> str:
        return str(self._assessment_info.get("instructions", ""))

    @Property(int, notify=questionChanged)
    def totalQuestions(self) -> int:
        return len(self._assessment_info.get("questions", []))

    @Property(float, notify=questionChanged)
    def puntajeMaximo(self) -> float:
        return float(
            sum(
                float(question.get("puntaje_maximo", 1.0))
                for question in self._assessment_info.get("questions", [])
            )
        )

    @Property("QVariantList", notify=questionChanged)
    def dimensions(self) -> list[dict[str, Any]]:
        questions = self._assessment_info.get("questions", [])
        result = []
        for dimension in self._bank.dimensions:
            propias = [
                question
                for question in questions
                if question.get("dimension_id") == dimension["id"]
            ]
            if propias:
                result.append({**dimension, "question_count": len(propias)})
        return result

    @Property("QVariantMap", constant=True)
    def criterios(self) -> dict[str, str]:
        """Texto del criterio de puntuación por ``criterio_id``.

        La vista lo usa en la retroalimentación final para explicar cómo se
        calificó cada reactivo.
        """
        return self._bank.criterios

    # ------------------------------------------------------------------
    # Estado del examen en curso
    # ------------------------------------------------------------------

    @Property(bool, notify=questionChanged)
    def isActive(self) -> bool:
        return self._manager.active

    @Property(bool, notify=questionChanged)
    def finished(self) -> bool:
        return self._manager.finished

    @Property("QVariantMap", notify=questionChanged)
    def currentQuestion(self) -> dict[str, Any]:
        """Copia pública: sin claves de respuesta en ningún nivel.

        Se agrega ``dimension_nombre`` porque la vista solo necesita mostrarlo;
        resolver el id contra la lista de dimensiones desde QML obligaría a cada
        pantalla a repetir la búsqueda.
        """
        question = self._manager.current_public_question
        if question:
            question["dimension_nombre"] = self._bank.dimension_name(
                str(question.get("dimension_id", ""))
            )
        return question

    @Property(str, notify=questionChanged)
    def currentQuestionType(self) -> str:
        """El delegate que la vista debe cargar para el reactivo en curso."""
        return str(self._manager.current_public_question.get("tipo", ""))

    @Property(int, notify=questionChanged)
    def currentQuestionNumber(self) -> int:
        if not self._manager.questions:
            return 0
        return self._manager.current_index + 1

    @Property(bool, notify=questionChanged)
    def isLastQuestion(self) -> bool:
        return self._manager.is_last_question

    @Property(int, notify=questionChanged)
    def answeredQuestions(self) -> int:
        return len(self._manager.answers)

    @Property(float, notify=questionChanged)
    def progressFraction(self) -> float:
        total = len(self._manager.questions)
        return ((self._manager.current_index + 1) / total) if total else 0.0

    @Property("QVariant", notify=stateChanged)
    def currentAnswer(self) -> Any:
        """Respuesta en curso, para que el delegate recupere su estado si QML lo
        vuelve a instanciar."""
        return self._respuesta_actual

    @Property(bool, notify=stateChanged)
    def canContinue(self) -> bool:
        if not self._manager.active:
            return False
        return es_respuesta_completa(
            self._manager.current_question, self._respuesta_actual
        )

    # ------------------------------------------------------------------
    # Resultados
    # ------------------------------------------------------------------

    @Property("QVariantMap", notify=questionChanged)
    def result(self) -> dict[str, Any]:
        return dict(self._result)

    @Property(str, notify=questionChanged)
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

    @Property(bool, notify=questionChanged)
    def hasPreviousResult(self) -> bool:
        return bool(self._repository.latest(self._assessment_type))

    @Property("QVariantMap", notify=questionChanged)
    def previousResult(self) -> dict[str, Any]:
        return self._repository.latest(self._assessment_type)

    # Estas cuatro NO dependen de ``_assessment_type``: la pantalla de progreso
    # necesita leer el pre y el post al mismo tiempo.

    @Property("QVariantMap", notify=questionChanged)
    def preResult(self) -> dict[str, Any]:
        return self._repository.latest("pre")

    @Property("QVariantMap", notify=questionChanged)
    def postResult(self) -> dict[str, Any]:
        return self._repository.latest("post")

    @Property(bool, notify=questionChanged)
    def hasPre(self) -> bool:
        return bool(self._repository.latest("pre"))

    @Property(bool, notify=questionChanged)
    def hasPost(self) -> bool:
        return bool(self._repository.latest("post"))

    @Property("QVariantList", notify=questionChanged)
    def history(self) -> list[dict[str, Any]]:
        return self._repository.get_history()

    @Property("QVariantMap", notify=questionChanged)
    def improvement(self) -> dict[str, Any]:
        """Avance pre→post, total y por dimensión. Vacío si falta alguno."""
        pre = self._repository.latest("pre")
        post = self._repository.latest("post")
        if not pre or not post:
            return {"disponible": False}

        def indexar(resultado: dict[str, Any], clave: str) -> dict[str, dict[str, Any]]:
            return {
                str(item.get("id")): item
                for item in resultado.get(clave, [])
                if item.get("id")
            }

        def comparar(clave: str) -> list[dict[str, Any]]:
            antes, despues = indexar(pre, clave), indexar(post, clave)
            filas = []
            for item_id, item_pre in antes.items():
                item_post = despues.get(item_id)
                if item_post is None:
                    continue
                pre_pct = float(item_pre.get("percentage", 0))
                post_pct = float(item_post.get("percentage", 0))
                filas.append(
                    {
                        "id": item_id,
                        "name": item_post.get("name", item_pre.get("name", item_id)),
                        "pre_puntaje": float(item_pre.get("puntaje", 0)),
                        "post_puntaje": float(item_post.get("puntaje", 0)),
                        "maximo": float(item_post.get("maximo", 0)),
                        "pre_percentage": pre_pct,
                        "post_percentage": post_pct,
                        "delta_percentage": round(post_pct - pre_pct, 1),
                    }
                )
            return filas

        pre_puntaje = float(pre.get("puntaje", 0))
        post_puntaje = float(post.get("puntaje", 0))
        pre_pct = float(pre.get("percentage", 0))
        post_pct = float(post.get("percentage", 0))
        return {
            "disponible": True,
            "pre_puntaje": pre_puntaje,
            "post_puntaje": post_puntaje,
            "maximo": float(post.get("maximo", 0)),
            "delta_puntaje": round(post_puntaje - pre_puntaje, 2),
            "pre_percentage": pre_pct,
            "post_percentage": post_pct,
            "delta_percentage": round(post_pct - pre_pct, 1),
            "dimensions": comparar("dimensions"),
            "bloom": comparar("bloom"),
        }

    # ------------------------------------------------------------------
    # Acciones desde QML
    # ------------------------------------------------------------------

    def _emitir_pregunta(self) -> None:
        """Cambió el reactivo o el resultado: se notifican ambas señales,
        porque `canContinue` también se reinicia en ese momento."""
        self.questionChanged.emit()
        self.stateChanged.emit()

    @Slot(str)
    def prepareEvaluation(self, assessment_type: str) -> None:
        try:
            self._prepare(assessment_type)
        except QuestionBankError as exc:
            self.error.emit(str(exc))
            return
        self._respuesta_actual = None
        self._result = {}
        self._emitir_pregunta()

    @Slot(str)
    def startEvaluation(self, assessment_type: str) -> None:
        try:
            self._prepare(assessment_type)
            self._manager.start_evaluation(self._assessment_type)
        except QuestionBankError as exc:
            self.error.emit(str(exc))
            return
        self._respuesta_actual = None
        self._result = {}
        self._emitir_pregunta()

    @Slot("QVariant")
    def registrarRespuesta(self, valor: Any) -> None:
        """Recibe la respuesta construida por el delegate del reactivo.

        El controlador no valida la forma: de eso se encarga el modelo, que
        califica como 0 cualquier cosa que no reconozca. Aquí solo se guarda y
        se notifica, para que ``canContinue`` se recalcule.
        """
        if not self._manager.active:
            return
        self._respuesta_actual = _a_python(valor)
        self.stateChanged.emit()

    @Slot()
    def limpiarRespuesta(self) -> None:
        if self._respuesta_actual is None:
            return
        self._respuesta_actual = None
        self.stateChanged.emit()

    @Slot()
    def submitCurrentAnswer(self) -> None:
        if not self.canContinue:
            return
        question_id = self._manager.current_question["id"]
        try:
            result = self._manager.submit_answer(question_id, self._respuesta_actual)
        except EvaluationStateError as exc:
            self.error.emit(str(exc))
            return

        self._respuesta_actual = None
        if result:
            self._result = result
            self._repository.save_result(result)
        self._emitir_pregunta()
        if result:
            self.evaluationCompleted.emit(dict(result))

    @Slot()
    def borrarHistorial(self) -> None:
        self._repository.clear()
        self._result = {}
        self._emitir_pregunta()
