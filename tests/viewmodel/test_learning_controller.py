"""Pruebas del progreso persistente del recorrido guiado."""

from PySide6.QtCore import QSettings

from viewmodel.learning_controller import LearningController


def _settings_temporales(tmp_path) -> QSettings:
    return QSettings(
        str(tmp_path / "learning-progress.ini"), QSettings.Format.IniFormat
    )


def test_marca_unidades_sin_duplicarlas_y_calcula_porcentaje(tmp_path):
    controller = LearningController(settings=_settings_temporales(tmp_path))

    controller.markUnitCompleted("unit_1")
    controller.markUnitCompleted("unit_1")
    controller.markUnitCompleted("unit_inexistente")

    assert controller.completedUnitIds == ["unit_1"]
    assert controller.completedUnitsCount == 1
    assert controller.progressPercent == 20
    assert controller.isUnitCompleted("unit_1") is True


def test_restaura_avance_y_ultima_posicion(tmp_path):
    settings_path = tmp_path / "learning-progress.ini"
    first = LearningController(
        settings=QSettings(str(settings_path), QSettings.Format.IniFormat)
    )
    first.markUnitCompleted("unit_2")
    first.savePosition(3, 2)

    restored = LearningController(
        settings=QSettings(str(settings_path), QSettings.Format.IniFormat)
    )

    assert restored.completedUnitIds == ["unit_2"]
    assert restored.lastUnitIndex == 3
    assert restored.lastConceptIndex == 2


def test_limita_posiciones_fuera_de_rango(tmp_path):
    controller = LearningController(settings=_settings_temporales(tmp_path))

    controller.savePosition(99, -7)

    assert controller.lastUnitIndex == 4
    assert controller.lastConceptIndex == 0


def test_reinicia_todo_el_progreso(tmp_path):
    controller = LearningController(settings=_settings_temporales(tmp_path))
    controller.markUnitCompleted("unit_1")
    controller.markUnitCompleted("unit_5")
    controller.savePosition(4, 2)

    controller.resetProgress()

    assert controller.completedUnitIds == []
    assert controller.completedUnitsCount == 0
    assert controller.progressPercent == 0
    assert controller.lastUnitIndex == 0
    assert controller.lastConceptIndex == 0


def test_reinicio_limpia_ids_invalidos_que_fueron_normalizados(tmp_path):
    settings = _settings_temporales(tmp_path)
    settings.setValue("guided/completed_unit_ids", ["unit_desconocida"])
    settings.sync()
    controller = LearningController(settings=settings)

    assert controller.completedUnitIds == []

    controller.resetProgress()

    assert settings.value("guided/completed_unit_ids") == []
