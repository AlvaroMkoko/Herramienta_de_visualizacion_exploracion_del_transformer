"""Integración de evaluación y progreso por módulo."""

from __future__ import annotations

from model.aprendizaje import ModuleProgressRepository
from model.evaluacion.results_repository import ResultsRepository
from viewmodel.course_controller import CourseController
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

    course.completeGuidedStep("module_1", "m1_s1")
    course.completeGuidedTour("module_1")
    course.completeLaboratory("module_1")

    restored = ModuleProgressRepository(tmp_path / "progress.json").snapshot()
    state = restored["modules"]["module_1"]
    assert state["guided_completed"] is True
    assert len(state["guided_steps_completed"]) == 8
    assert state["laboratory_completed"] is True


def test_modo_revision_desbloquea_todos_los_modulos_y_etapas(tmp_path):
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
    assert summary["delta_percentage"] == 40.0
    assert summary["relative_improvement"] == 100.0
    assert summary["duration_seconds"] == 40.0
    assert "Tokenización" in summary["mastered"]
