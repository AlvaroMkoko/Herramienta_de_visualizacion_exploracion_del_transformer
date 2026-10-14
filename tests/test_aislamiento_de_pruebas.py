"""Pruebas de las guardas de ``tests/conftest.py``.

Lo que protegen no da error al romperse: sin ellas, la suite seguiría en verde
escribiendo en ``data/`` real o leyendo el registro de quien la corre.
"""

from pathlib import Path
from types import ModuleType

import pytest
from PySide6.QtCore import QSettings

from tests import conftest
from viewmodel.learning_controller import LearningController


def _modulo_rutas_falso(**rutas: Path) -> ModuleType:
    modulo = ModuleType("rutas_falso")
    for nombre, valor in rutas.items():
        setattr(modulo, nombre, valor)
    return modulo


def test_guarda_de_importacion_previa_detiene_si_core_rutas_ya_estaba_cargado() -> None:
    with pytest.raises(RuntimeError, match="core.rutas"):
        conftest.comprobar_rutas_sin_importar({"core.rutas": object()})

    conftest.comprobar_rutas_sin_importar({"core": object(), "core.config": object()})


def test_guarda_de_redireccion_nombra_cada_dir_que_sigue_en_los_datos_reales(
    tmp_path,
) -> None:
    repositorio = tmp_path / "repo"
    datos_reales = repositorio / "data"
    temporal = tmp_path / "temporal"

    olvidado = _modulo_rutas_falso(
        DIR_RECURSOS=repositorio,
        DIR_DATOS=temporal,
        DIR_CHECKPOINTS=temporal / "checkpoints",
        DIR_NUEVA=datos_reales / "nueva",
        RUTA_SUELTA=datos_reales / "no_es_dir",
    )
    completo = _modulo_rutas_falso(
        DIR_RECURSOS=repositorio,
        DIR_DATOS=temporal,
        DIR_CHECKPOINTS=temporal / "checkpoints",
        DIR_NUEVA=temporal / "nueva",
    )

    assert conftest.rutas_sin_redirigir(olvidado, datos_reales) == ["DIR_NUEVA"]
    assert conftest.rutas_sin_redirigir(completo, datos_reales) == []


def test_migracion_del_avance_lee_el_almacen_anterior_desde_el_temporal(tmp_path) -> None:
    anterior = QSettings("TransformerVisualizer", "LearningPlatform")
    assert Path(anterior.fileName()).is_relative_to(conftest.DIR_DATOS_PRUEBAS)

    # El almacén anterior es compartido por toda la corrida: se limpia al salir
    # para que las pruebas que construyen MainViewModel() no hereden la unidad.
    anterior.setValue("guided/completed_unit_ids", ["unit_3"])
    anterior.sync()
    try:
        controller = LearningController(
            settings=QSettings(
                str(tmp_path / "learning-progress.ini"), QSettings.Format.IniFormat
            )
        )
        assert controller.completedUnitIds == ["unit_3"]
    finally:
        anterior.clear()
        anterior.sync()
