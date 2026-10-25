"""Integración de evaluación y progreso por módulo."""

from __future__ import annotations

from model.aprendizaje import ModuleProgressRepository
from model.evaluacion.results_repository import ResultsRepository
from viewmodel.course_controller import STAGES, CourseController
from viewmodel.module_evaluation_controller import ModuleEvaluationController


def _answer_current(controller: ModuleEvaluationController) -> dict:
    question = controller._manager.current_question
    if question["tipo"] == "opcion_unica":
        return {"opcion_id": question["correct_option_id"]}
    if question["tipo"] == "seleccion_multiple":
        return {"opciones_ids": question["correct_option_ids"]}
    if question["tipo"] == "texto":
        return {"texto": question["respuestas_aceptadas"][0]}
    if question["tipo"] == "asignacion":
        return {
            "asignaciones": {
                item["id"]: item["correcto"] for item in question["elementos"]
            }
        }
    raise AssertionError(f"Tipo no cubierto por la prueba: {question['tipo']}")


def test_evaluacion_modular_guarda_contexto_y_quince_reactivos(tmp_path):
    results = ResultsRepository(tmp_path / "results.json")
    controller = ModuleEvaluationController(repository=results)
    controller.startModuleEvaluation("module_4", "pre")

    while controller.isActive:
        controller.registrarRespuesta(_answer_current(controller))
        controller.submitCurrentAnswer()

    saved = results.latest("pre", module_id="module_4")
    assert saved["module_id"] == "module_4"
    assert saved["reactivos"] == 15
    assert len(saved["question_ids_used"]) == 15
    assert saved["difficulty_counts"] == {
        "Básica": 5,
        "Intermedia": 5,
        "Avanzada": 5,
    }
    assert all(answer["concept_id"] for answer in saved["answers"])


def test_progreso_guiado_y_laboratorio_persiste(tmp_path):
    results = ResultsRepository(tmp_path / "results.json")
    evaluation = ModuleEvaluationController(repository=results)
    repository = ModuleProgressRepository(tmp_path / "progress.json")
    course = CourseController(evaluation, repository=repository)

    results.save_result(
        {
            "schema_version": 2,
            "assessment_type": "pre",
            "module_id": "module_1",
            "percentage": 0.0,
        }
    )

    _answer_guided_checks(course, "module_1")
    assert course.completeGuidedTour("module_1") is True
    _practice_laboratory(course, "module_1")

    restored = ModuleProgressRepository(tmp_path / "progress.json").snapshot()
    state = restored["modules"]["module_1"]
    assert state["guided_completed"] is True
    assert len(state["guided_steps_completed"]) == 8
    assert state["laboratory_completed"] is True


def _answer_guided_checks(course: CourseController, module_id: str) -> None:
    for step in course.catalog.get(module_id)["guided_steps"]:
        course.recordGuidedCheck(module_id, step["id"], 0)


def _practice_laboratory(course: CourseController, module_id: str) -> None:
    steps = course.catalog.get(module_id)["guided_steps"]
    for step in steps[: CourseController.REQUIRED_LAB_CYCLES]:
        course.recordDiscoveryCycle(module_id, step["id"], True, 1)
    course.recordAnchorClosing(module_id, 0)


def _course(tmp_path) -> tuple[CourseController, ResultsRepository]:
    results = ResultsRepository(tmp_path / "results.json")
    evaluation = ModuleEvaluationController(repository=results)
    course = CourseController(
        evaluation, repository=ModuleProgressRepository(tmp_path / "progress.json")
    )
    return course, results


def _completar_etapas(course, results, module_id: str, etapas) -> None:
    for etapa in etapas:
        if etapa in ("pretest", "posttest"):
            results.save_result(
                {
                    "schema_version": 2,
                    "assessment_type": "pre" if etapa == "pretest" else "post",
                    "module_id": module_id,
                    "percentage": 80.0,
                }
            )
        elif etapa == "guided":
            _answer_guided_checks(course, module_id)
            assert course.completeGuidedTour(module_id)
        elif etapa == "laboratory":
            _practice_laboratory(course, module_id)
        elif etapa == "results":
            course.markResultsViewed(module_id)
        assert course.stageCompleted(module_id, etapa), (module_id, etapa)


def _abrir_etapa(course, results, module_id: str, etapa: str) -> None:
    """Cumple los prerrequisitos reales (RN18), como lo haría un alumno, hasta
    dejar abierta la etapa: el modo revisión está apagado por defecto."""
    modulos = [module["id"] for module in course.modules]
    for previo in modulos[: modulos.index(module_id)]:
        _completar_etapas(course, results, previo, STAGES)
    _completar_etapas(course, results, module_id, STAGES[: STAGES.index(etapa)])
    assert course.stageAvailable(module_id, etapa)


def test_el_recorrido_no_se_completa_solo_con_mirarlo(tmp_path):
    course, results = _course(tmp_path)
    _abrir_etapa(course, results, "module_3", "guided")
    steps = course.catalog.get("module_3")["guided_steps"]

    for step in steps:
        course.completeGuidedStep("module_3", step["id"])
    assert course.completeGuidedTour("module_3") is False
    assert not course.stageCompleted("module_3", "guided")

    feedback = course.recordGuidedCheck(
        "module_3", steps[0]["id"], steps[0]["check"]["correct_index"]
    )
    assert feedback["correct"] is True and feedback["feedback"]
    progress = course.guidedProgress("module_3")
    assert progress["attempted"] == [steps[0]["id"]]
    assert len(progress["pending"]) == 7

    _answer_guided_checks(course, "module_3")
    assert course.completeGuidedTour("module_3") is True


def test_el_primer_intento_de_cada_comprobacion_es_el_que_cuenta(tmp_path):
    course, results = _course(tmp_path)
    _abrir_etapa(course, results, "module_2", "guided")
    step = course.catalog.get("module_2")["guided_steps"][0]
    wrong = (step["check"]["correct_index"] + 1) % len(step["check"]["options"])

    assert course.recordGuidedCheck("module_2", step["id"], wrong)["correct"] is False
    assert course.recordGuidedCheck(
        "module_2", step["id"], step["check"]["correct_index"]
    )["correct"] is True
    assert course.guidedProgress("module_2")["first_correct"] == []
    assert course.recordGuidedCheck("module_2", step["id"], 99) == {}


def test_ejecutar_el_laboratorio_no_lo_completa(tmp_path):
    course, results = _course(tmp_path)
    _abrir_etapa(course, results, "module_4", "laboratory")

    course.recordLaboratoryAnalysis("module_4")
    assert course.completeLaboratory("module_4") is False

    steps = course.catalog.get("module_4")["guided_steps"]
    # Repetir el mismo paso no cuenta como tres prácticas distintas.
    for _ in range(3):
        course.recordDiscoveryCycle("module_4", steps[0]["id"], True, 1)
    course.recordAnchorClosing("module_4", 1)
    assert course.laboratoryProgress("module_4")["cycles"] == 1
    assert not course.stageCompleted("module_4", "laboratory")

    course.recordDiscoveryCycle("module_4", steps[1]["id"], False, 2)
    course.recordDiscoveryCycle("module_4", steps[2]["id"], True, 1)
    progress = course.laboratoryProgress("module_4")
    assert progress["cycles"] == 3 and progress["closing_answered"]
    assert progress["completed"] and course.stageCompleted("module_4", "laboratory")


def _result(module_id: str, assessment: str, percentage: float, answers: list) -> dict:
    return {
        "schema_version": 2,
        "instrument_version": 8,
        "assessment_type": assessment,
        "module_id": module_id,
        "module_title": "Self-Attention",
        "puntaje": percentage * 0.15,
        "maximo": 15.0,
        "percentage": percentage,
        "duration_seconds": 30,
        "dimensions": [
            {"id": "escalamiento_dk", "name": "Escalamiento", "percentage": percentage}
        ],
        "answers": answers,
        "bloom": [],
    }


def test_resultados_dan_ganancia_normalizada_revision_y_pasos_a_repasar(tmp_path):
    course, results = _course(tmp_path)
    course._evaluation._key_bank.set_module("module_3")
    post_question = next(
        item
        for item in course._evaluation._key_bank.all_questions("post")
        if item["concept_id"] == "escalamiento_dk"
    )
    fallo = {
        "question_id": post_question["id"],
        "concept_id": "escalamiento_dk",
        "prompt": post_question["prompt"],
        "correcto": False,
        "puntaje": 0.0,
        "maximo": 1.0,
    }
    results.save_result(_result("module_3", "pre", 20.0, [dict(fallo)]))
    results.save_result(_result("module_3", "post", 60.0, [fallo]))

    data = course.moduleResults("module_3")

    assert data["normalized_gain"] == 0.5  # (60 − 20) / (100 − 20)
    row = next(item for item in data["concepts"] if item["id"] == "escalamiento_dk")
    assert row["normalized_gain"] == 0.5 and row["step"]["id"] == "m3_s5"
    assert data["recommendations"][0]["step"]["index"] == 4
    assert data["recommendations"][0]["lab_prompt"]
    assert "paso 5" in data["recommendation"]
    review = data["review"][0]
    assert review["correct"] is False and review["correct_text"]
    assert review["step"]["id"] == "m3_s5"


def test_la_revision_nunca_expone_claves_del_pretest(tmp_path):
    course, results = _course(tmp_path)
    course._evaluation._key_bank.set_module("module_3")
    question = course._evaluation._key_bank.all_questions("pre")[0]
    answer = {
        "question_id": question["id"],
        "concept_id": question["concept_id"],
        "prompt": question["prompt"],
        "correcto": False,
        "puntaje": 0.0,
        "maximo": 1.0,
    }
    results.save_result(_result("module_3", "pre", 10.0, [answer]))

    data = course.moduleResults("module_3")

    assert data["review"] == []
    # El diagnóstico sí orienta el recorrido sin revelar claves.
    assert course.guidedProgress("module_3")["focus_step_ids"]


def test_repaso_espaciado_usa_retos_del_modulo_anterior(tmp_path):
    course, results = _course(tmp_path)

    assert course.spacedReview("module_3")["available"] is False
    results.save_result(_result("module_2", "post", 70.0, []))
    review = course.spacedReview("module_3")
    assert review["available"] and review["module_id"] == "module_2"
    item = review["items"][0]
    lab_ids = {c["id"] for c in course.catalog.get("module_2")["lab_challenges"]}
    assert item["id"] in lab_ids

    challenge = next(
        c for c in course.catalog.get("module_2")["lab_challenges"] if c["id"] == item["id"]
    )
    wrong = (challenge["correct_index"] + 1) % len(challenge["options"])
    assert course.recordReviewAnswer("module_2", item["id"], wrong)["correct"] is False
    course.recordReviewAnswer("module_2", item["id"], challenge["correct_index"])
    again = course.spacedReview("module_3")["items"][0]
    assert again["answered"] and again["correct"] is False  # cuenta el primer intento


def test_por_defecto_el_curso_aplica_los_prerrequisitos(tmp_path):
    """RN18: con estudiantes el modo revisión debe estar apagado; abrir el
    post-test sin pasar por el recorrido invalida la comparación pre/post."""
    course, results = _course(tmp_path)

    assert CourseController.REVIEW_MODE_UNLOCK_ALL is False
    assert course.reviewMode is False
    assert [module["available"] for module in course.modules] == [True] + [False] * 7
    assert course.stageAvailable("module_1", "pretest")
    assert not course.stageAvailable("module_1", "guided")
    assert not course.stageAvailable("module_1", "posttest")
    assert course.stageBlockReason("module_2", "pretest") == (
        "Completa el módulo anterior para desbloquear éste."
    )

    _completar_etapas(course, results, "module_1", STAGES)
    assert course.stageAvailable("module_2", "pretest")
    assert not course.stageAvailable("module_2", "guided")


def test_modo_revision_desbloquea_todos_los_modulos_y_etapas(tmp_path, monkeypatch):
    monkeypatch.setattr(CourseController, "REVIEW_MODE_UNLOCK_ALL", True)
    evaluation = ModuleEvaluationController(
        repository=ResultsRepository(tmp_path / "results.json")
    )
    course = CourseController(
        evaluation,
        repository=ModuleProgressRepository(tmp_path / "progress.json"),
    )

    assert course.reviewMode is True
    assert all(module["available"] for module in course.modules)
    assert all(
        course.stageAvailable("module_8", stage)
        for stage in ("pretest", "guided", "laboratory", "posttest", "results")
    )


def test_resultados_por_modulo_calculan_mejora_y_recomendacion(tmp_path):
    results = ResultsRepository(tmp_path / "results.json")
    evaluation = ModuleEvaluationController(repository=results)
    course = CourseController(
        evaluation,
        repository=ModuleProgressRepository(tmp_path / "progress.json"),
    )
    common = {
        "schema_version": 2,
        "instrument_version": 4,
        "module_id": "module_1",
        "module_title": "Entrada al Transformer",
        "maximo": 15.0,
        "duration_seconds": 20,
        "answers": [],
        "bloom": [],
    }
    results.save_result(
        {
            **common,
            "assessment_type": "pre",
            "puntaje": 6.0,
            "percentage": 40.0,
            "dimensions": [
                {"id": "tokenizacion", "name": "Tokenización", "percentage": 40}
            ],
        }
    )
    results.save_result(
        {
            **common,
            "assessment_type": "post",
            "puntaje": 12.0,
            "percentage": 80.0,
            "dimensions": [
                {"id": "tokenizacion", "name": "Tokenización", "percentage": 80}
            ],
        }
    )

    summary = course.moduleResults("module_1")
    assert summary["comparable"] is True
    assert summary["delta_percentage"] == 40.0
    assert summary["relative_improvement"] == 100.0
    assert summary["duration_seconds"] == 40.0
    assert "Tokenización" in summary["mastered"]


def test_resultados_de_versiones_distintas_no_calculan_mejora(tmp_path):
    results = ResultsRepository(tmp_path / "results.json")
    evaluation = ModuleEvaluationController(repository=results)
    course = CourseController(
        evaluation,
        repository=ModuleProgressRepository(tmp_path / "progress.json"),
    )
    common = {
        "schema_version": 2,
        "module_id": "module_1",
        "module_title": "Entrada al Transformer",
        "maximo": 15.0,
        "duration_seconds": 20,
        "answers": [],
        "bloom": [],
        "dimensions": [
            {"id": "tokenizacion", "name": "Tokenización", "percentage": 80}
        ],
    }
    results.save_result(
        {
            **common,
            "assessment_type": "pre",
            "instrument_version": 6,
            "percentage": 40.0,
        }
    )
    results.save_result(
        {
            **common,
            "assessment_type": "post",
            "instrument_version": 7,
            "percentage": 80.0,
        }
    )

    summary = course.moduleResults("module_1")
    assert summary["comparable"] is False
    assert summary["delta_percentage"] == 0.0
    assert summary["relative_improvement"] == 0.0
    assert summary["concepts"][0]["comparable"] is False
    # Repetir el pre-test ya no lo arreglaría: la comparación usa el primero.
    assert "no se pueden comparar" in summary["recommendation"]
    assert "Repite" not in summary["recommendation"]


def test_el_pretest_se_cierra_al_entrar_al_recorrido(tmp_path):
    course, results = _course(tmp_path)
    _abrir_etapa(course, results, "module_1", "guided")
    assert course.stageAvailable("module_1", "pretest")  # aún se puede repetir

    course.enterGuidedTour("module_1")

    assert not course.stageAvailable("module_1", "pretest")
    assert "recorrido guiado" in course.stageBlockReason("module_1", "pretest")
    assert course.stageAvailable("module_1", "guided")
    restored = ModuleProgressRepository(tmp_path / "progress.json").snapshot()
    assert restored["modules"]["module_1"]["guided_entered"] is True


def test_entrar_al_recorrido_cerrado_no_cierra_el_pretest(tmp_path):
    course, _ = _course(tmp_path)
    course.enterGuidedTour("module_1")  # sin pre-test el recorrido está cerrado
    assert course.stageAvailable("module_1", "pretest")


def test_avance_guardado_del_recorrido_tambien_cierra_el_pretest(tmp_path):
    """Progreso de antes de que existiera la marca de entrada."""
    repository = ModuleProgressRepository(tmp_path / "progress.json")
    repository.replace({"modules": {"module_1": {"guided_steps_completed": ["m1_s1"]}}})
    results = ResultsRepository(tmp_path / "results.json")
    course = CourseController(ModuleEvaluationController(repository=results), repository=repository)
    _completar_etapas(course, results, "module_1", ["pretest"])

    assert not course.stageAvailable("module_1", "pretest")


def test_repetir_la_evaluacion_no_se_salta_la_guarda_de_etapa(tmp_path):
    course, results = _course(tmp_path)
    evaluation = course._evaluation
    _abrir_etapa(course, results, "module_1", "guided")
    course.enterGuidedTour("module_1")
    errors: list[str] = []
    evaluation.error.connect(errors.append)

    evaluation.startModuleEvaluation("module_1", "pre")
    evaluation.startModuleEvaluation("module_1", "post")  # falta el laboratorio

    assert evaluation.isActive is False
    assert len(errors) == 2 and "recorrido guiado" in errors[0]
    assert "laboratorio" in errors[1]
    assert len(results.get_history("pre", module_id="module_1")) == 1


def _version_vigente() -> int:
    from model.aprendizaje.module_question_bank import ModuleQuestionBank

    return ModuleQuestionBank.VERSION_PREGUNTAS


def test_cuenta_el_primer_intento_y_registra_cuantas_veces_lo_tomaste(tmp_path):
    course, results = _course(tmp_path)
    evaluation = course._evaluation
    # Un primer pre-test flojo y, antes de entrar al recorrido, uno real perfecto.
    results.save_result(
        {
            "schema_version": 2,
            "assessment_type": "pre",
            "module_id": "module_1",
            "instrument_version": _version_vigente(),
            "percentage": 20.0,
            "completed_at": "2000-01-01T00:00:00+00:00",
        }
    )
    evaluation.startModuleEvaluation("module_1", "pre")
    while evaluation.isActive:
        evaluation.registrarRespuesta(_answer_current(evaluation))
        evaluation.submitCurrentAnswer()
    first_pre, second_pre = results.get_history("pre", module_id="module_1")
    assert first_pre["percentage"] == 20.0 and second_pre["percentage"] == 100.0

    _completar_etapas(course, results, "module_1", ["guided", "laboratory"])
    for percentage in (55.0, 100.0):
        evaluation_result = dict(second_pre, assessment_type="post", percentage=percentage)
        evaluation_result.pop("result_id")
        evaluation_result["completed_at"] = "2999-01-01T00:00:0%d+00:00" % int(percentage == 100.0)
        results.save_result(evaluation_result)

    summary = course.moduleResults("module_1")
    assert summary["pre_percentage"] == 20.0
    assert summary["post_percentage"] == 55.0
    assert summary["attempts"] == {"pre": 2, "post": 2}


def test_borrar_el_historial_no_deja_el_modulo_sin_forma_de_empezar(tmp_path):
    """«Borrar progreso» quita los resultados pero no el estado del curso: sin
    pre-test que proteger, el pre-test vuelve a abrirse."""
    course, results = _course(tmp_path)
    _abrir_etapa(course, results, "module_1", "guided")
    course.enterGuidedTour("module_1")
    assert not course.stageAvailable("module_1", "pretest")

    results.clear("__self__")

    assert course.stageAvailable("module_1", "pretest")
    assert not course.stageAvailable("module_1", "guided")
