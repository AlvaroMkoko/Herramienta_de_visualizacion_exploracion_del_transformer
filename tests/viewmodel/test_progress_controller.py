from __future__ import annotations

from PySide6.QtCore import QSettings

from model.evaluacion.results_repository import ResultsRepository
from viewmodel.evaluation_controller import EvaluationController
from viewmodel.learning_controller import LearningController
from viewmodel.progress_controller import ProgressController


def crear_controladores(tmp_path):
    settings = QSettings(str(tmp_path / "progreso.ini"), QSettings.IniFormat)
    learning = LearningController(settings=settings)
    repository = ResultsRepository(tmp_path / "resultados.json")
    evaluation = EvaluationController(repository=repository)
    progress = ProgressController(learning, evaluation, settings=settings)
    return learning, evaluation, progress


def guardar_resultado(evaluation, tipo):
    evaluation._repository.save_result(
        {
            "assessment_type": tipo,
            "percentage": 75.0,
            "dimensions": [],
        }
    )


def test_progreso_vacio_solo_habilita_pretest(tmp_path):
    _, _, progress = crear_controladores(tmp_path)

    assert progress.etapaDisponible(1) is True
    assert all(progress.etapaDisponible(orden) is False for orden in (2, 3, 4, 5))


def test_secuencia_completa_habilita_etapas_en_orden(tmp_path):
    learning, evaluation, progress = crear_controladores(tmp_path)

    guardar_resultado(evaluation, "pre")
    assert progress.etapaDisponible(2) is True
    for unit_id in learning._VALID_UNIT_IDS:
        learning.markUnitCompleted(unit_id)
    assert progress.etapaDisponible(3) is True
    progress.registrarLaboratorioAbierto("entrenamiento")
    progress.registrarLaboratorioAbierto("biblioteca")
    assert progress.etapaDisponible(4) is False
    progress.registrarLaboratorioAbierto("comparacion")
    assert progress.etapaDisponible(4) is True
    guardar_resultado(evaluation, "post")
    assert progress.etapaDisponible(5) is True
    progress.registrarSeguimientoVisitado()
    assert progress.flujoCompleto is True
    assert progress.pasosCompletados == 5


def test_laboratorios_son_idempotentes_y_filtrados(tmp_path):
    _, _, progress = crear_controladores(tmp_path)

    progress.registrarLaboratorioAbierto("entrenamiento")
    progress.registrarLaboratorioAbierto("entrenamiento")
    progress.registrarLaboratorioAbierto("inventado")

    assert progress.laboratoriosAbiertos == ["entrenamiento"]
    assert progress.laboratoriosCompletados is False


def test_qsettings_normaliza_tipos_degradados(tmp_path):
    settings = QSettings(str(tmp_path / "degradado.ini"), QSettings.IniFormat)
    settings.setValue("flujo/ruta_estricta", "false")
    settings.setValue("flujo/seguimiento_visitado", "true")
    settings.setValue("flujo/laboratorios_abiertos", "entrenamiento")
    settings.sync()
    learning = LearningController(settings=settings)
    evaluation = EvaluationController(repository=ResultsRepository())
    progress = ProgressController(learning, evaluation, settings=settings)

    assert progress.rutaEstricta is False
    assert progress.seguimientoVisitado is True
    assert progress.laboratoriosAbiertos == ["entrenamiento"]
    assert progress.laboratoriosCompletados is False


def test_un_laboratorio_persiste_como_lista_normalizada(tmp_path):
    ruta = tmp_path / "ciclo.ini"
    settings = QSettings(str(ruta), QSettings.IniFormat)
    learning = LearningController(settings=settings)
    evaluation = EvaluationController(repository=ResultsRepository())
    progress = ProgressController(learning, evaluation, settings=settings)
    progress.registrarLaboratorioAbierto("entrenamiento")

    settings.sync()
    settings_recargados = QSettings(str(ruta), QSettings.IniFormat)
    nuevo_learning = LearningController(settings=settings_recargados)
    nuevo_evaluation = EvaluationController(repository=ResultsRepository())
    nuevo_progress = ProgressController(
        nuevo_learning, nuevo_evaluation, settings=settings_recargados
    )

    assert nuevo_progress.laboratoriosAbiertos == ["entrenamiento"]
    assert nuevo_progress.etapaDisponible(4) is False


def test_borrar_todo_el_progreso(tmp_path):
    learning, evaluation, progress = crear_controladores(tmp_path)
    guardar_resultado(evaluation, "pre")
    learning.markUnitCompleted("unit_1")
    progress.registrarLaboratorioAbierto("entrenamiento")
    progress.registrarSeguimientoVisitado()

    progress.borrarTodoElProgreso()

    assert progress.pasosCompletados == 0
    assert progress.laboratoriosAbiertos == []
    assert evaluation.history == []
