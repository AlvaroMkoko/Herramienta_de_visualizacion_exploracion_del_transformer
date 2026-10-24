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


def _profiles_con_alumno(tmp_path):
    repository = ResultsRepository(tmp_path / "resultados.json")
    evaluation = EvaluationController(repository=repository)
    profiles = ProfileController(evaluation)
    evaluation.set_profile_controller(profiles)
    assert profiles.registrarAlumno("Ana López", "A-001", "3 B", "20", "ana@escuela.edu")
    return repository, profiles, profiles.result_student_snapshot()


def _en(resultado: dict, module_id: str, segundo: int) -> dict:
    return {**resultado, "module_id": module_id, "completed_at": f"2026-09-27T12:00:{segundo:02d}+00:00"}


def test_docente_no_compara_pre_y_post_de_modulos_distintos(tmp_path):
    repository, profiles, student = _profiles_con_alumno(tmp_path)
    repository.save_result(_en(_result("pre", 20.0, student), "module_1", 1))
    repository.save_result(_en(_result("post", 95.0, student), "module_4", 2))

    row = profiles.students[0]
    # La fila compara el módulo de la actividad más reciente: el 4, sin pre-test.
    assert row["scope"] == "module_4" and row["scope_label"].startswith("M4")
    assert row["comparable"] is False and row["improvement"] == 0.0
    assert row["pre_completed"] is False
    analysis = profiles.studentAnalysis(student["id"])
    assert analysis["comparable"] is False and analysis["has_pre"] is False


def test_docente_compara_dentro_del_modulo_con_el_primer_intento(tmp_path):
    repository, profiles, student = _profiles_con_alumno(tmp_path)
    repository.save_result(_en(_result("pre", 30.0, student), "module_2", 1))
    repository.save_result(_en(_result("post", 60.0, student), "module_2", 2))
    repository.save_result(_en(_result("post", 100.0, student), "module_2", 3))  # repetido

    row = profiles.students[0]
    assert row["scope"] == "module_2"
    assert row["pre_percentage"] == 30.0 and row["post_percentage"] == 60.0
    assert row["improvement"] == 30.0
    assert row["pre_attempts"] == 1 and row["post_attempts"] == 2
    analysis = profiles.studentAnalysis(student["id"])
    assert analysis["post"]["percentage"] == 60.0 and analysis["post_attempts"] == 2


def test_la_ruta_general_tiene_prioridad_y_no_se_mezcla_con_modulos(tmp_path):
    repository, profiles, student = _profiles_con_alumno(tmp_path)
    repository.save_result(_en(_result("pre", 40.0, student), "", 1))
    repository.save_result(_en(_result("post", 99.0, student), "module_3", 5))

    row = profiles.students[0]
    assert row["scope"] == "" and row["scope_label"] == "Ruta general"
    assert row["post_completed"] is False and row["comparable"] is False
