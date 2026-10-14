"""Configuración común a toda la suite: entorno de Qt y datos aislados.

Pytest carga este archivo antes de importar cualquier módulo de prueba, y eso es
justo lo que necesita todo lo que hace. Tiene que ocurrir *antes* de la primera
importación de código del proyecto; hacerlo en una fixture sería tarde.
"""

from __future__ import annotations

import os
import shutil
import sys
import tempfile
from collections.abc import Mapping
from pathlib import Path
from types import ModuleType

# --- Entorno de Qt ----------------------------------------------------------
# Sin pantalla (CI, SSH, una sesión sin escritorio), construir el ``qapp`` con la
# plataforma nativa aborta el intérprete (``Fatal Python error: Aborted``): no
# falla, se cae. En Windows con sesión gráfica no se reproduce, por eso es fácil
# no notarlo. ``setdefault`` respeta lo que ya venga de fuera, igual que los
# archivos de ``tests/view`` que las fijan al importarse.
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")


# --- Guardas del aislamiento ------------------------------------------------
# Son funciones con nombre para poder probarlas sin correr pytest dentro de
# pytest (``tests/test_aislamiento_de_pruebas.py``). Lo que protegen no da error
# al romperse: la suite seguiría en verde escribiendo en los datos reales.


def comprobar_rutas_sin_importar(modulos: Mapping[str, object]) -> None:
    """Falla si ``core.rutas`` ya estaba importado al llegar aquí.

    Si alguien lo importó antes que este archivo (un plugin, un ``-p``), los
    ``from core.rutas import DIR_X`` ya copiaron las rutas reales y redirigir
    el módulo no las alcanza. Mejor no correr que correr sobre ``data/``
    creyendo que está aislado.
    """
    if "core.rutas" in modulos:
        raise RuntimeError(
            "core.rutas se importó antes de tests/conftest.py; los datos de "
            "prueba no se pueden aislar y la suite escribiría en data/ real."
        )


def rutas_sin_redirigir(modulo_rutas: ModuleType, raiz_real: Path) -> list[str]:
    """Nombres ``DIR_*`` del módulo que todavía apuntan dentro de ``raiz_real``.

    Si ``core.rutas`` gana otra carpeta de escritura y nadie la agrega a la
    redirección de abajo, seguiría apuntando a ``data/`` real sin que nada
    falle. ``DIR_RECURSOS`` no cuenta: es la raíz del repositorio, que contiene
    a ``data/`` y no está dentro de ella.
    """
    raiz = raiz_real.resolve()
    return sorted(
        nombre
        for nombre, valor in vars(modulo_rutas).items()
        if nombre.startswith("DIR_")
        and isinstance(valor, Path)
        and valor.resolve().is_relative_to(raiz)
    )


# --- Aislamiento de los datos de escritura ----------------------------------
# Muchas pruebas construyen ``MainViewModel()``, que crea sus controladores con
# las rutas por omisión de ``core.rutas``: el avance del curso
# (``dato("progreso", ...)``), resultados, checkpoints, datasets, configuraciones
# y el aula. Sin esto, correr la suite reescribe ``data/progreso`` de quien la
# ejecuta, y el ``*.json`` del ``.gitignore`` lo esconde de ``git status``.
#
# Se redirigen las raíces en el propio módulo ``core.rutas`` antes de que nadie
# más lo importe. Así cubre las dos formas de consumirlo: ``dato()`` lee
# ``DIR_DATOS`` en cada llamada, y los ``from core.rutas import DIR_X`` y las
# constantes de clase derivadas (``DatasetController.DATASET_FILE``,
# ``RUTA_RESULTADOS_POR_DEFECTO``) copian el valor al importarse, ya redirigido.
# ``recurso()`` no se toca: los recursos de solo lectura siguen saliendo del
# repositorio.
#
# El temporal es **uno solo para toda la corrida**, no uno por prueba: lo que una
# prueba escribe lo ve la siguiente. Es a propósito. Aislar por prueba obligaría
# a repatchear, en cada prueba, cada constante que algún módulo copió al
# importarse (``DIR_CHECKPOINTS`` en la biblioteca y en el entrenamiento,
# ``DATASET_FILE``, ``RUTA_RESULTADOS_POR_DEFECTO``, ``DIR_CONFIGURACIONES``…).
# Esa lista habría que mantenerla a mano y se rompería en silencio con la
# próxima constante. Redirigir la raíz una vez, antes de cualquier importación,
# no necesita lista. Una prueba que dependa de empezar sin datos tiene que
# inyectar su propia ruta en ``tmp_path``, como ya hacen las dedicadas.
comprobar_rutas_sin_importar(sys.modules)

import core.rutas as _rutas  # noqa: E402 - tiene que ir después de la guarda

_DIR_DATOS_REAL = _rutas.DIR_DATOS
DIR_DATOS_PRUEBAS = Path(tempfile.mkdtemp(prefix="tt_datos_pruebas_")).resolve()

_rutas.DIR_DATOS = DIR_DATOS_PRUEBAS
_rutas.DIR_DATASETS = DIR_DATOS_PRUEBAS / "datasets"
_rutas.DIR_CHECKPOINTS = DIR_DATOS_PRUEBAS / "checkpoints"
_rutas.DIR_LOGS = DIR_DATOS_PRUEBAS / "logs"
_rutas.DIR_RESULTADOS = DIR_DATOS_PRUEBAS / "resultados"
_rutas.DIR_CONFIGURACIONES = DIR_DATOS_PRUEBAS / "configuraciones"

_sin_redirigir = rutas_sin_redirigir(_rutas, _DIR_DATOS_REAL)
if _sin_redirigir:
    raise RuntimeError(
        "tests/conftest.py no redirige estas rutas de escritura: "
        + ", ".join(_sin_redirigir)
    )


# --- Aislamiento de los QSettings con nombre fijo ---------------------------
# ``QSettings()`` sin argumentos no persiste nada en pruebas: pytest-qt deja
# vacía la organización y Qt responde con ``AccessError``. Pero
# ``QSettings("org", "app")`` fija ambos nombres y, en Windows, lee el registro
# real de quien corre la suite. Caso concreto: ``LearningController`` migra el
# avance desde ``QSettings("TransformerVisualizer", "LearningPlatform")``, así que
# en una máquina con avance heredado sus pruebas ven unidades que nunca marcaron.
#
# No basta con ``QSettings.setPath``: solo redirige el formato INI, y el nativo
# de Windows es el registro. Inyectar el almacén en el controlador tampoco
# alcanza: ``MainViewModel()`` lo construye con lo de omisión y las pruebas de
# vista no pueden pasarle nada. Por eso se sustituye la clase antes de que el
# proyecto la importe, y solo la forma ``(organización[, aplicación])`` se manda
# a un INI dentro del temporal. Las formas de archivo y la de sin argumentos
# pasan intactas.
#
# Lo que **no** cubre: las formas con scope o format explícitos, como
# ``QSettings(QSettings.NativeFormat, QSettings.UserScope, "X", "Y")`` o
# ``QSettings(QSettings.UserScope, "X", "Y")``, pasan intactas y leerían el
# registro. Hoy nadie las usa. Si alguien las introduce, hay que extender esta
# clase; nada avisará, igual que una ruta de escritura fuera de ``core.rutas``
# escapa al cerco de los ``DIR_*``.
#
# Limitación aceptada: en las pruebas ese almacén es un INI, y en producción
# sobre Windows es el registro. Los dos formatos no devuelven los tipos igual
# (una lista de un elemento puede volver como cadena suelta; por eso
# ``LearningController._read_completed_units`` se defiende de ese caso), así que
# una prueba verde con INI no garantiza el comportamiento con el registro. Es
# preferible a que la suite dependa de la máquina de quien la corre.
from PySide6 import QtCore as _QtCore  # noqa: E402

_QSettingsReal = _QtCore.QSettings


class _QSettingsSinRegistro(_QSettingsReal):
    def __init__(self, *args, **kwargs):
        if args and len(args) <= 2 and not kwargs and all(
            isinstance(arg, str) for arg in args
        ):
            organizacion = args[0]
            aplicacion = args[1] if len(args) == 2 else organizacion
            ruta = DIR_DATOS_PRUEBAS / "qsettings" / organizacion / f"{aplicacion}.ini"
            super().__init__(str(ruta), _QSettingsReal.Format.IniFormat)
        else:
            super().__init__(*args, **kwargs)


_QtCore.QSettings = _QSettingsSinRegistro


def pytest_unconfigure(config):
    shutil.rmtree(DIR_DATOS_PRUEBAS, ignore_errors=True)
