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


def test_ruta_no_estricta_abre_todas_las_etapas(tmp_path):
    """El interruptor global existe para desarrollo y demostraciones: sin él,
    enseñar el post-test obligaría a recorrer los cinco pasos en vivo."""
    _, _, progress = crear_controladores(tmp_path)
    progress.establecerRequiereRecorridoParaLabs(False)

    progress.establecerRutaEstricta(False)

    assert all(progress.etapaDisponible(orden) is True for orden in (1, 2, 3, 4, 5))
    assert progress.rutaEstricta is False


def test_el_candado_de_laboratorios_es_independiente_del_interruptor(tmp_path):
    """Son dos banderas distintas: apagar la ruta estricta no debe desbloquear
    los laboratorios si el proyecto todavía exige el recorrido guiado."""
    _, _, progress = crear_controladores(tmp_path)
    progress.establecerRutaEstricta(False)
    progress.establecerRequiereRecorridoParaLabs(True)

    assert progress.etapaDisponible(3) is False
    assert progress.etapaDisponible(4) is True


def test_los_interruptores_persisten_entre_ejecuciones(tmp_path):
    """Sin type=bool, QSettings devuelve la cadena "false", que es verdadera en
    Python: el interruptor parecería apagarse y volvería encendido al reiniciar.
    """
    ruta = tmp_path / "banderas.ini"
    settings = QSettings(str(ruta), QSettings.IniFormat)
    learning = LearningController(settings=settings)
    evaluation = EvaluationController(repository=ResultsRepository())
    progress = ProgressController(learning, evaluation, settings=settings)

    progress.establecerRutaEstricta(False)
    progress.establecerRequiereRecorridoParaLabs(False)
    settings.sync()

    recargados = QSettings(str(ruta), QSettings.IniFormat)
    nuevo = ProgressController(
        LearningController(settings=recargados),
        EvaluationController(repository=ResultsRepository()),
        settings=recargados,
    )

    assert nuevo.rutaEstricta is False
    assert nuevo.requiereRecorridoParaLabs is False


def test_terminar_una_evaluacion_propaga_el_cambio(tmp_path, qtbot):
    """ProgressController deriva su estado de otros dos controladores. Sin
    reemitir sus señales, completar el pre-test no habilitaría el recorrido
    guiado hasta reiniciar la aplicación."""
    _, evaluation, progress = crear_controladores(tmp_path)

    with qtbot.waitSignal(progress.progresoCambio, timeout=1000):
        guardar_resultado(evaluation, "pre")
        evaluation.stateChanged.emit()

    assert progress.preTestCompletado is True
    assert progress.etapaDisponible(2) is True


def test_completar_el_recorrido_propaga_el_cambio(tmp_path, qtbot):
    learning, _, progress = crear_controladores(tmp_path)

    with qtbot.waitSignal(progress.progresoCambio, timeout=1000):
        learning.markUnitCompleted("unit_1")

    assert progress.recorridoCompletado is False


def test_motivo_de_bloqueo_vacio_cuando_la_etapa_esta_disponible(tmp_path):
    _, evaluation, progress = crear_controladores(tmp_path)

    assert progress.motivoBloqueo(1) == ""
    assert progress.motivoBloqueo(2) != ""

    guardar_resultado(evaluation, "pre")

    assert progress.motivoBloqueo(2) == ""


def test_cada_etapa_bloqueada_explica_que_falta(tmp_path):
    """El texto va al ToolTip: un candado sin explicación deja al estudiante
    sin saber qué hacer."""
    _, _, progress = crear_controladores(tmp_path)

    for orden in (2, 3, 4, 5):
        motivo = progress.motivoBloqueo(orden)
        assert motivo, f"la etapa {orden} no explica por qué está bloqueada"
        assert motivo != progress.motivoBloqueo(orden - 1) or orden == 2


def test_una_etapa_fuera_de_rango_no_esta_disponible(tmp_path):
    _, _, progress = crear_controladores(tmp_path)

    assert progress.etapaDisponible(0) is False
    assert progress.etapaDisponible(6) is False


def test_borrar_el_progreso_persiste_el_borrado(tmp_path):
    """El test existente comprueba el estado en memoria; esto comprueba que al
    reabrir la aplicación el progreso sigue vacío."""
    ruta = tmp_path / "borrado.ini"
    settings = QSettings(str(ruta), QSettings.IniFormat)
    learning = LearningController(settings=settings)
    evaluation = EvaluationController(
        repository=ResultsRepository(tmp_path / "resultados.json")
    )
    progress = ProgressController(learning, evaluation, settings=settings)
    progress.registrarLaboratorioAbierto("entrenamiento")
    progress.registrarSeguimientoVisitado()

    progress.borrarTodoElProgreso()
    settings.sync()

    recargados = QSettings(str(ruta), QSettings.IniFormat)
    nuevo = ProgressController(
        LearningController(settings=recargados),
        EvaluationController(
            repository=ResultsRepository(tmp_path / "resultados.json")
        ),
        settings=recargados,
    )

    assert nuevo.pasosCompletados == 0
    assert nuevo.laboratoriosAbiertos == []
    assert nuevo.seguimientoVisitado is False


# ---------------------------------------------------------------------------
# Ruta general: la misma regla que el curso por módulos
# ---------------------------------------------------------------------------

def test_el_pretest_general_se_cierra_al_entrar_al_recorrido(tmp_path):
    learning, evaluation, progress = crear_controladores(tmp_path)
    guardar_resultado(evaluation, "pre")
    assert progress.etapaDisponible(1) is True  # aún se puede repetir

    learning.markTourEntered()

    assert progress.etapaDisponible(1) is False
    assert "recorrido guiado" in progress.motivoBloqueo(1)
    assert progress.etapaDisponible(2) is True
    # La marca persiste y la borra el reinicio.
    settings = QSettings(str(tmp_path / "progreso.ini"), QSettings.IniFormat)
    assert LearningController(settings=settings).tourEntered is True
    progress.borrarTodoElProgreso()
    assert learning.tourEntered is False and progress.etapaDisponible(1) is True


def test_sin_pretest_ni_ruta_estricta_no_se_cierra(tmp_path):
    learning, evaluation, progress = crear_controladores(tmp_path)
    learning.markTourEntered()
    assert progress.etapaDisponible(1) is True  # no hay pre-test que proteger

    guardar_resultado(evaluation, "pre")
    progress.establecerRutaEstricta(False)  # demostraciones
    assert progress.etapaDisponible(1) is True


def test_repetir_en_la_ruta_general_respeta_la_guarda(tmp_path):
    learning, evaluation, progress = crear_controladores(tmp_path)
    guardar_resultado(evaluation, "pre")
    learning.markTourEntered()
    errores: list[str] = []
    evaluation.error.connect(errores.append)

    evaluation.startEvaluation("pre")
    evaluation.startEvaluation("post")  # faltan los laboratorios

    assert evaluation.isActive is False
    assert "recorrido guiado" in errores[0] and "laboratorios" in errores[1]
    assert len(evaluation._repository.get_history("pre")) == 1


def test_la_ruta_general_cuenta_el_primer_intento(tmp_path):
    _, evaluation, _ = crear_controladores(tmp_path)
    for porcentaje in (30.0, 90.0):
        evaluation._repository.save_result(
            {"assessment_type": "pre", "percentage": porcentaje, "dimensions": []}
        )
    evaluation.prepareEvaluation("pre")

    assert evaluation.preResult["percentage"] == 30.0
    assert evaluation.previousResult["percentage"] == 90.0  # «Último resultado»
    assert evaluation.attemptCount == 2


def test_reiniciar_el_recorrido_no_reabre_el_pretest(tmp_path):
    learning, evaluation, progress = crear_controladores(tmp_path)
    guardar_resultado(evaluation, "pre")
    learning.markUnitCompleted(learning._VALID_UNIT_IDS[0])
    assert progress.etapaDisponible(1) is False

    learning.restartTour()

    assert learning.completedUnitsCount == 0
    assert progress.etapaDisponible(1) is False  # sigue cerrado


def test_la_ruta_general_ordena_los_intentos_por_fecha(tmp_path):
    """Al docente los resultados le llegan desordenados: cuenta el más antiguo."""
    _, evaluation, _ = crear_controladores(tmp_path)
    version = evaluation.instrumentVersion
    for porcentaje, fecha in ((90.0, "2026-10-07T11:00:00+00:00"), (30.0, "2026-10-07T10:00:00+00:00")):
        evaluation._repository.save_result(
            {
                "assessment_type": "pre",
                "instrument_version": version,
                "percentage": porcentaje,
                "completed_at": fecha,
                "dimensions": [],
            }
        )

    assert evaluation.preResult["percentage"] == 30.0
