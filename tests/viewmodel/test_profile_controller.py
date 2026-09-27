from __future__ import annotations

from model.evaluacion.results_repository import ResultsRepository
from viewmodel.evaluation_controller import EvaluationController
from viewmodel.profile_controller import ProfileController


def _result(tipo: str, porcentaje: float, student: dict) -> dict:
    return {
        "schema_version": 2,
        "instrument_version": 3,
        "assessment_type": tipo,
        "puntaje": porcentaje / 5,
        "maximo": 20.0,
        "percentage": porcentaje,
        "completed_at": f"2026-09-27T12:00:0{1 if tipo == 'pre' else 2}+00:00",
        "dimensions": [],
        "bloom": [],
        "student_id": student["id"],
        "student": student,
    }


def test_docente_agrupa_pre_y_post_por_matricula(tmp_path):
    repository = ResultsRepository(tmp_path / "resultados.json")
    evaluation = EvaluationController(repository=repository)
    profiles = ProfileController(evaluation)
    evaluation.set_profile_controller(profiles)

    assert profiles.registrarAlumno(
        "Ana López", "A-001", "3 B", "20", "ana@escuela.edu"
    )
    student = profiles.result_student_snapshot()
    repository.save_result(_result("pre", 45.0, student))
    repository.save_result(_result("post", 80.0, student))

    assert profiles.studentCount == 1
    row = profiles.students[0]
    assert row["nombre"] == "Ana López"
    assert row["pre_percentage"] == 45.0
    assert row["post_percentage"] == 80.0
    assert row["improvement"] == 35.0
    assert row["tests_count"] == 2


def test_resultados_de_alumnos_distintos_no_se_mezclan(tmp_path):
    repository = ResultsRepository(tmp_path / "resultados.json")
    evaluation = EvaluationController(repository=repository)
    profiles = ProfileController(evaluation)
    evaluation.set_profile_controller(profiles)

    profiles.seleccionarRol("teacher")
    assert profiles.registrarAlumno("Ana", "A-001", "3 B", "", "")
    ana = profiles.result_student_snapshot()
    repository.save_result(_result("pre", 40.0, ana))

    assert profiles.registrarAlumno("Luis", "L-002", "3 B", "", "")
    luis = profiles.result_student_snapshot()
    repository.save_result(_result("post", 90.0, luis))

    assert len(profiles.students) == 2
    assert evaluation.hasPre is False
    assert evaluation.hasPost is True


def test_modo_individual_conserva_resultados_anteriores(tmp_path):
    repository = ResultsRepository(tmp_path / "resultados.json")
    repository.save_result(
        {
            "assessment_type": "pre",
            "puntaje": 10.0,
            "maximo": 20.0,
            "percentage": 50.0,
        }
    )
    evaluation = EvaluationController(repository=repository)
    profiles = ProfileController(evaluation)
    evaluation.set_profile_controller(profiles)

    profiles.seleccionarRol("student")

    assert evaluation.hasPre is True
    assert profiles.result_student_snapshot()["id"] == "__self__"


def test_estudiante_no_puede_borrar_resultados_del_docente(tmp_path):
    repository = ResultsRepository(tmp_path / "resultados.json")
    teacher_student = {
        "id": "a-001",
        "nombre": "Ana",
        "matricula": "A-001",
        "grupo": "3 B",
    }
    repository.save_result(_result("pre", 70.0, teacher_student))
    repository.save_result(
        {
            "assessment_type": "pre",
            "puntaje": 10.0,
            "maximo": 20.0,
            "percentage": 50.0,
        }
    )
    evaluation = EvaluationController(repository=repository)
    profiles = ProfileController(evaluation)
    evaluation.set_profile_controller(profiles)
    profiles.seleccionarRol("student")

    evaluation.borrarHistorial()

    assert repository.latest("pre", "a-001")["percentage"] == 70.0
    assert repository.latest("pre", "__self__") == {}


def test_datos_obligatorios_y_edad_se_validan(tmp_path, qtbot):
    evaluation = EvaluationController(
        repository=ResultsRepository(tmp_path / "resultados.json")
    )
    profiles = ProfileController(evaluation)

    with qtbot.waitSignal(profiles.error, timeout=1000):
        assert profiles.registrarAlumno("", "A-001", "3 B", "", "") is False

    with qtbot.waitSignal(profiles.error, timeout=1000):
        assert profiles.registrarAlumno("Ana", "A-001", "3 B", "cuatro", "") is False
