"""Pruebas del ViewModel del pre-test y post-test (instrumento v3).

Cuatro contratos se fijan aquí porque romperlos no produce ningún error visible:

* ``currentQuestion`` no expone la respuesta correcta a ninguna profundidad.
* ``stateChanged`` y ``questionChanged`` son señales distintas. Colgar la
  pregunta de la primera reintroduce el ciclo de enlaces que bloqueaba la
  pantalla al escribir.
* ``registrarRespuesta`` normaliza lo que llega de QML. Si un envoltorio pasara
  sin convertir, el botón de continuar quedaría deshabilitado para siempre, sin
  error en consola.
* Volver a un reactivo anterior restaura su respuesta y no borra las que
  siguen. Un fallo aquí se ve como «se me borraron las respuestas», sin traza
  de por qué.
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


# ---------------------------------------------------------------------------
# Guardia de versión del instrumento
# ---------------------------------------------------------------------------


def guardar(controller, tipo: str, version: int | None, porcentaje: float) -> None:
    """Escribe un resultado directo en el repositorio, como si viniera de una
    ejecución anterior de la aplicación."""
    resultado = {
        "assessment_type": tipo,
        "schema_version": 2,
        "puntaje": porcentaje / 5,
        "maximo": 20.0,
        "percentage": porcentaje,
        "dimensions": [],
        "bloom": [],
    }
    if version is not None:
        resultado["instrument_version"] = version
    controller._repository.save_result(resultado)


def test_el_resultado_sella_la_version_del_instrumento(controller, bank):
    controller.startEvaluation("pre")
    resolver(controller, bank)

    assert controller.result["instrument_version"] == bank.instrument_version
    assert controller.instrumentVersion == bank.instrument_version


def test_no_se_compara_un_pre_y_un_post_de_instrumentos_distintos(controller):
    """Restar un pre-test del v2 contra un post-test del v3 daría un número con
    apariencia de dato y sin significado: son reactivos distintos."""
    guardar(controller, "pre", 2, 40.0)
    guardar(controller, "post", 3, 90.0)

    avance = controller.improvement

    assert avance["disponible"] is False
    assert avance["motivo"] == "instrumentos_distintos"
    assert avance["instrument_version_pre"] == 2
    assert avance["instrument_version_post"] == 3
    assert "delta_percentage" not in avance
    assert avance["mensaje"]


def test_si_coinciden_las_versiones_si_se_compara(controller):
    guardar(controller, "pre", 3, 40.0)
    guardar(controller, "post", 3, 90.0)

    avance = controller.improvement

    assert avance["disponible"] is True
    assert avance["instrument_version"] == 3
    assert avance["delta_percentage"] == 50.0


def test_un_resultado_sin_version_cuenta_como_v2(controller):
    """Los resultados guardados antes de que existiera el campo se produjeron
    con el instrumento v2."""
    guardar(controller, "pre", None, 40.0)
    guardar(controller, "post", 2, 90.0)

    assert controller.improvement["disponible"] is True

    guardar(controller, "post", 3, 95.0)

    assert controller.improvement["motivo"] == "instrumentos_distintos"


def test_una_version_corrupta_no_rompe_la_comparacion(controller):
    guardar(controller, "pre", None, 40.0)
    controller._repository._results[-1]["instrument_version"] = "tres"
    guardar(controller, "post", 2, 90.0)

    assert controller.improvement["disponible"] is True


def test_sin_resultados_el_motivo_lo_dice(controller):
    assert controller.improvement["motivo"] == "faltan_resultados"


# ---------------------------------------------------------------------------
# Navegación hacia atrás
# ---------------------------------------------------------------------------
#
# Volver a un reactivo anterior es la única forma de corregir un clic
# equivocado, pero abre tres maneras silenciosas de perder trabajo del
# estudiante: que la respuesta no se restaure, que avanzar desde un reactivo
# revisitado borre el siguiente, y que se pueda saltar por encima de un
# reactivo en blanco y llegar al final con huecos.


def _avanzar(controller, bank, veces: int) -> None:
    for _ in range(veces):
        controller.registrarRespuesta(
            respuesta_perfecta(controller.currentQuestion, bank)
        )
        controller.submitCurrentAnswer()


def test_el_primer_reactivo_no_tiene_anterior(controller):
    controller.startEvaluation("pre")
    assert controller.canGoBack is False

    # Y pulsar el botón igualmente no mueve nada ni emite un error.
    controller.goToPreviousQuestion()
    assert controller.currentQuestionNumber == 1


def test_retroceder_restaura_la_respuesta_ya_registrada(controller, bank):
    controller.startEvaluation("pre")
    primera = controller.currentQuestion
    respuesta = respuesta_perfecta(primera, bank)
    controller.registrarRespuesta(respuesta)
    controller.submitCurrentAnswer()

    assert controller.currentQuestionNumber == 2
    controller.goToPreviousQuestion()

    assert controller.currentQuestionNumber == 1
    assert controller.currentQuestion["id"] == primera["id"]
    # La respuesta vuelve puesta: el reactivo no aparece en blanco y el botón
    # de continuar está habilitado desde el primer momento.
    assert controller.currentAnswer == respuesta
    assert controller.canContinue is True


def test_retroceder_no_registra_el_borrador_en_curso(controller, bank):
    """Una respuesta a medio hacer no se guarda al retroceder: solo cuenta lo
    que se envió con el botón de continuar."""
    controller.startEvaluation("pre")
    _avanzar(controller, bank, 1)

    segunda = controller.currentQuestion
    controller.registrarRespuesta(respuesta_perfecta(segunda, bank))
    controller.goToPreviousQuestion()
    controller.goToFrontierQuestion()

    assert controller.currentQuestion["id"] == segunda["id"]
    assert controller.currentAnswer is None
    assert controller.canContinue is False


def test_avanzar_desde_un_reactivo_revisitado_no_borra_el_siguiente(controller, bank):
    """Corregir el reactivo 2 no debe obligar a rehacer el 3 y el 4.

    Es el fallo más caro de los tres: no da ningún error, el reactivo
    siguiente simplemente aparece vacío y el estudiante cree que se le borró.
    """
    controller.startEvaluation("pre")
    _avanzar(controller, bank, 4)
    assert controller.currentQuestionNumber == 5

    for _ in range(3):
        controller.goToPreviousQuestion()
    assert controller.currentQuestionNumber == 2

    controller.submitCurrentAnswer()

    assert controller.currentQuestionNumber == 3
    assert controller.currentAnswer is not None, "el reactivo 3 quedó en blanco"
    assert controller.canContinue is True
    # Y sigue siendo una revisión: la frontera no retrocedió.
    assert controller.isRevisiting is True
    assert controller.frontierQuestionNumber == 5


def test_volver_al_frente_salta_al_punto_donde_se_quedo(controller, bank):
    controller.startEvaluation("pre")
    _avanzar(controller, bank, 6)
    assert controller.currentQuestionNumber == 7
    assert controller.frontierQuestionNumber == 7

    for _ in range(5):
        controller.goToPreviousQuestion()
    assert controller.currentQuestionNumber == 2
    assert controller.isRevisiting is True

    controller.goToFrontierQuestion()
    assert controller.currentQuestionNumber == 7
    assert controller.isRevisiting is False
    assert controller.currentAnswer is None


def test_no_se_puede_saltar_por_encima_de_un_reactivo_en_blanco(controller, bank):
    """La frontera es el primer reactivo sin contestar. Si se pudiera pasar de
    largo, se llegaría al final con huecos y `score_evaluation` fallaría
    justo al terminar, después de veinte reactivos de trabajo."""
    controller.startEvaluation("pre")
    _avanzar(controller, bank, 3)
    frontera = controller._manager.frontier_index

    assert controller._manager.can_go_to(frontera) is True
    assert controller._manager.can_go_to(frontera + 1) is False
    assert controller._manager.can_go_to(-1) is False


def respuesta_incorrecta(question: dict) -> dict:
    """Una respuesta completa —para que deje avanzar— pero equivocada.

    No mira la clave: basta con que tenga la forma que el tipo exige y un
    contenido que ningún calificador pueda dar por bueno.
    """
    tipo = question["tipo"]
    if tipo == "opcion_unica":
        return {"opcion_id": "__ninguna__"}
    if tipo == "seleccion_multiple":
        return {"opciones_ids": ["__ninguna__"]}
    if tipo in ("texto", "texto_libre"):
        return {"texto": "respuesta deliberadamente equivocada"}
    if tipo == "asignacion":
        return {
            "asignaciones": {
                str(e["id"]): "__ninguno__" for e in question["elementos"]
            }
        }
    return {
        "etapas": {
            str(etapa["id"]): (
                {"texto": "sin justificar"}
                if etapa["tipo"] == "texto_libre"
                else {"opcion_id": "__ninguna__"}
            )
            for etapa in question["etapas"]
        }
    }


def test_corregir_una_respuesta_cambia_el_puntaje_final(controller, bank):
    """Prueba de extremo a extremo: lo que se corrige al volver atrás es lo
    que el modelo califica al final, no lo que se había enviado antes."""
    controller.startEvaluation("pre")
    primera = controller.currentQuestion
    correcta = respuesta_perfecta(primera, bank)

    # El primer reactivo se contesta mal a propósito; el resto, bien.
    controller.registrarRespuesta(respuesta_incorrecta(primera))
    controller.submitCurrentAnswer()
    _avanzar(controller, bank, controller.totalQuestions - 2)

    # Falta solo el último. Se vuelve al primero y se corrige.
    assert controller.currentQuestionNumber == controller.totalQuestions
    for _ in range(controller.totalQuestions - 1):
        controller.goToPreviousQuestion()
    assert controller.currentQuestion["id"] == primera["id"]

    controller.registrarRespuesta(correcta)
    controller.submitCurrentAnswer()
    controller.goToFrontierQuestion()
    _avanzar(controller, bank, 1)

    assert controller.finished is True
    assert controller.result["percentage"] == 100.0


def test_al_terminar_ya_no_se_puede_retroceder(controller, bank):
    """Con el resultado en pantalla, retroceder dejaría la evaluación en un
    estado contestable después de haberse calificado y guardado."""
    controller.startEvaluation("pre")
    resolver(controller, bank)

    assert controller.finished is True
    assert controller.canGoBack is False
    assert controller.isRevisiting is False

    controller.goToPreviousQuestion()
    assert controller.finished is True


def test_la_respuesta_restaurada_es_una_copia(controller, bank):
    """`answer_for` entrega una copia profunda.

    Sin ella, el delegate de QML estaría escribiendo directamente sobre lo ya
    registrado: cambiar de opinión en un reactivo revisitado y luego retroceder
    sin confirmar dejaría guardado el cambio que nunca se envió.
    """
    controller.startEvaluation("pre")
    primera = controller.currentQuestion
    original = respuesta_perfecta(primera, bank)
    controller.registrarRespuesta(original)
    controller.submitCurrentAnswer()

    controller.goToPreviousQuestion()
    restaurada = controller.currentAnswer
    assert restaurada == original

    # Se altera la copia en curso, como haría el delegate al teclear, y se sale
    # del reactivo sin confirmar.
    if isinstance(restaurada, dict):
        for clave, valor in list(restaurada.items()):
            if isinstance(valor, dict):
                valor.clear()
            elif isinstance(valor, list):
                valor.clear()
            else:
                restaurada[clave] = "alterado"

    controller.goToFrontierQuestion()
    controller.goToPreviousQuestion()
    assert controller.currentAnswer == original, "se guardó un cambio sin confirmar"
