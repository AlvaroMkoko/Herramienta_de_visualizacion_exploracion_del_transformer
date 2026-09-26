"""Pruebas del ViewModel del pre-test y post-test (instrumento v2).

Tres contratos se fijan aquí porque romperlos no produce ningún error visible:

* ``currentQuestion`` no expone la respuesta correcta a ninguna profundidad.
* ``stateChanged`` y ``questionChanged`` son señales distintas. Colgar la
  pregunta de la primera reintroduce el ciclo de enlaces que bloqueaba la
  pantalla al escribir.
* ``registrarRespuesta`` normaliza lo que llega de QML. Si un envoltorio pasara
  sin convertir, el botón de continuar quedaría deshabilitado para siempre, sin
  error en consola.
"""

from __future__ import annotations

import pytest

from model.evaluacion import QuestionBank
from model.evaluacion.results_repository import ResultsRepository
from viewmodel.evaluation_controller import EvaluationController

CLAVES_SECRETAS = frozenset(
    {"correct_option_id", "correct_option_ids", "respuestas_aceptadas", "correcto"}
)


@pytest.fixture(scope="module")
def bank() -> QuestionBank:
    return QuestionBank()


@pytest.fixture
def controller(bank, tmp_path) -> EvaluationController:
    """Un controlador con repositorio propio: las pruebas no se contaminan
    entre sí ni tocan los resultados reales del usuario."""
    return EvaluationController(
        question_bank=bank,
        repository=ResultsRepository(tmp_path / "resultados.json"),
    )


def respuesta_perfecta(question: dict, bank: QuestionBank) -> dict:
    """Construye la respuesta correcta a partir de la versión privada.

    La pública no trae la solución, que es justo lo que se verifica aparte.
    """
    privada = next(
        q
        for q in bank.get_questions(question.get("id", "").split("_")[0])
        if q["id"] == question["id"]
    )
    tipo = privada["tipo"]
    if tipo == "opcion_unica":
        return {"opcion_id": privada["correct_option_id"]}
    if tipo == "seleccion_multiple":
        return {"opciones_ids": list(privada["correct_option_ids"])}
    if tipo == "texto":
        return {"texto": privada["respuestas_aceptadas"][0]}
    if tipo == "asignacion":
        return {
            "asignaciones": {e["id"]: e["correcto"] for e in privada["elementos"]}
        }
    return {
        "etapas": {
            etapa["id"]: (
                {"texto": "justificación"}
                if etapa["tipo"] == "texto_libre"
                else {"opcion_id": etapa["correct_option_id"]}
            )
            for etapa in privada["etapas"]
        }
    }


def resolver(controller: EvaluationController, bank: QuestionBank) -> None:
    """Contesta correctamente hasta terminar la evaluación."""
    while controller.isActive:
        controller.registrarRespuesta(
            respuesta_perfecta(controller.currentQuestion, bank)
        )
        controller.submitCurrentAnswer()


def buscar_claves_secretas(objeto) -> list[str]:
    encontradas: list[str] = []
    if isinstance(objeto, dict):
        for clave, valor in objeto.items():
            if clave in CLAVES_SECRETAS:
                encontradas.append(clave)
            encontradas += buscar_claves_secretas(valor)
    elif isinstance(objeto, list):
        for valor in objeto:
            encontradas += buscar_claves_secretas(valor)
    return encontradas


# ---------------------------------------------------------------------------
# Metadatos
# ---------------------------------------------------------------------------


def test_prepara_pre_y_post_test(controller):
    controller.prepareEvaluation("post")

    assert controller.assessmentType == "post"
    assert controller.title == "Post-test"
    assert controller.forma == "B"
    assert controller.totalQuestions == 20
    assert controller.puntajeMaximo == 20.0
    assert len(controller.dimensions) == 5


def test_un_tipo_de_evaluacion_desconocido_emite_error(controller, qtbot):
    with qtbot.waitSignal(controller.error, timeout=1000):
        controller.prepareEvaluation("intermedio")


def test_expone_los_criterios_de_puntuacion(controller):
    """La retroalimentación final explica cómo se calificó cada reactivo."""
    assert "seleccion_multiple" in controller.criterios
    assert controller.criterios["opcion_unica"]


# ---------------------------------------------------------------------------
# La respuesta no viaja a la vista
# ---------------------------------------------------------------------------


def test_la_pregunta_publica_no_expone_la_respuesta(controller, bank):
    controller.startEvaluation("pre")

    revisadas = 0
    while controller.isActive:
        assert buscar_claves_secretas(controller.currentQuestion) == []
        revisadas += 1
        controller.registrarRespuesta(
            respuesta_perfecta(controller.currentQuestion, bank)
        )
        controller.submitCurrentAnswer()

    assert revisadas == 20


def test_la_pregunta_publica_trae_el_nombre_de_su_dimension(controller):
    """La vista lo muestra tal cual; resolver el id desde QML obligaría a cada
    pantalla a repetir la búsqueda."""
    controller.startEvaluation("pre")

    assert controller.currentQuestion["dimension_nombre"] == "Tokenización"


# ---------------------------------------------------------------------------
# Señales separadas
# ---------------------------------------------------------------------------


def test_registrar_una_respuesta_no_emite_questionChanged(controller, qtbot):
    """Si la pregunta se invalidara al escribir, QML entraría en un ciclo de
    enlaces y la pantalla dejaría de responder."""
    controller.startEvaluation("pre")

    recibidas: list[int] = []
    controller.questionChanged.connect(lambda: recibidas.append(1))

    with qtbot.waitSignal(controller.stateChanged, timeout=1000):
        controller.registrarRespuesta({"texto": "BP"})
    controller.registrarRespuesta({"texto": "BPE"})

    assert recibidas == []


def test_avanzar_de_pregunta_si_emite_questionChanged(controller, bank, qtbot):
    controller.startEvaluation("pre")
    controller.registrarRespuesta(respuesta_perfecta(controller.currentQuestion, bank))

    with qtbot.waitSignal(controller.questionChanged, timeout=1000):
        controller.submitCurrentAnswer()

    assert controller.currentQuestionNumber == 2


# ---------------------------------------------------------------------------
# Normalización de lo que llega de QML
# ---------------------------------------------------------------------------


class EnvoltorioQML:
    """Imita un QJSValue: algunas versiones de PySide6 entregan la respuesta
    envuelta en vez de como dict."""

    def __init__(self, valor):
        self._valor = valor

    def toVariant(self):
        return self._valor


def test_una_respuesta_envuelta_se_normaliza(controller):
    controller.startEvaluation("pre")

    controller.registrarRespuesta(EnvoltorioQML({"texto": "BPE"}))

    assert controller.currentAnswer == {"texto": "BPE"}
    assert controller.canContinue is True


def test_la_normalizacion_es_recursiva(controller, bank):
    """Las etapas llegan anidadas: si solo se desenvolviera el nivel superior,
    el reactivo quedaría incompleto."""
    controller.startEvaluation("pre")
    while controller.currentQuestion.get("code") != "F2":
        controller.registrarRespuesta(
            respuesta_perfecta(controller.currentQuestion, bank)
        )
        controller.submitCurrentAnswer()

    controller.registrarRespuesta(
        EnvoltorioQML({"etapas": EnvoltorioQML({"e1": {"opcion_id": "falso"}})})
    )

    assert controller.currentAnswer == {"etapas": {"e1": {"opcion_id": "falso"}}}
    assert controller.canContinue is True


def test_las_tuplas_se_convierten_en_listas(controller):
    controller.startEvaluation("pre")

    controller.registrarRespuesta({"opciones_ids": ("a", "b")})

    assert controller.currentAnswer["opciones_ids"] == ["a", "b"]


# ---------------------------------------------------------------------------
# Avance y finalización
# ---------------------------------------------------------------------------


def test_no_se_avanza_con_la_respuesta_incompleta(controller):
    controller.startEvaluation("pre")
    assert controller.canContinue is False

    controller.submitCurrentAnswer()

    assert controller.currentQuestionNumber == 1


def test_la_respuesta_se_limpia_al_cambiar_de_reactivo(controller, bank):
    controller.startEvaluation("pre")
    controller.registrarRespuesta(respuesta_perfecta(controller.currentQuestion, bank))
    controller.submitCurrentAnswer()

    assert controller.currentAnswer is None
    assert controller.canContinue is False


def test_examen_completo_guarda_el_resultado(controller, bank, qtbot):
    controller.startEvaluation("pre")

    with qtbot.waitSignal(controller.evaluationCompleted, timeout=5000):
        resolver(controller, bank)

    assert controller.finished is True
    assert controller.result["puntaje"] == 20.0
    assert controller.result["percentage"] == 100.0
    assert "correct" not in controller.result, "clave del esquema v1"
    assert controller.hasPre is True
    assert controller.hasPreviousResult is True


def test_isLastQuestion_solo_en_el_ultimo(controller, bank):
    controller.startEvaluation("pre")

    for numero in range(1, 21):
        assert controller.isLastQuestion is (numero == 20)
        controller.registrarRespuesta(
            respuesta_perfecta(controller.currentQuestion, bank)
        )
        controller.submitCurrentAnswer()


# ---------------------------------------------------------------------------
# Comparación pre → post
# ---------------------------------------------------------------------------


def test_pre_y_post_se_leen_a_la_vez(controller, bank):
    """`hasPreviousResult` depende del tipo activo; la pantalla de progreso
    necesita ambos resultados al mismo tiempo."""
    controller.startEvaluation("pre")
    resolver(controller, bank)
    controller.startEvaluation("post")
    resolver(controller, bank)

    assert controller.hasPre is True
    assert controller.hasPost is True
    assert controller.preResult["assessment_type"] == "pre"
    assert controller.postResult["assessment_type"] == "post"
    assert len(controller.history) == 2


def test_improvement_sin_ambos_resultados_no_esta_disponible(controller, bank):
    assert controller.improvement["disponible"] is False

    controller.startEvaluation("pre")
    resolver(controller, bank)

    assert controller.improvement["disponible"] is False


def test_improvement_compara_por_dimension_y_por_nivel(controller, bank):
    controller.startEvaluation("pre")
    resolver(controller, bank)
    controller.startEvaluation("post")
    resolver(controller, bank)

    avance = controller.improvement

    assert avance["disponible"] is True
    assert avance["pre_puntaje"] == 20.0
    assert avance["post_puntaje"] == 20.0
    assert avance["delta_puntaje"] == 0.0
    assert len(avance["dimensions"]) == 5
    assert {fila["id"] for fila in avance["bloom"]} == {
        "Recordar",
        "Comprender",
        "Aplicar",
    }


def test_borrar_historial_deja_todo_vacio(controller, bank):
    controller.startEvaluation("pre")
    resolver(controller, bank)

    controller.borrarHistorial()

    assert controller.hasPre is False
    assert controller.history == []
    assert controller.result == {}
