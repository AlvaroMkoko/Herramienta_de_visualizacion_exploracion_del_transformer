"""Rutas del proyecto: una sola respuesta para dos preguntas distintas.

Ejecutando desde el código fuente, los archivos que la aplicación **lee** y los
que **escribe** viven en la misma carpeta, así que basta con la raíz del
proyecto. Al empaquetar con PyInstaller se separan y confundirlos rompe la
aplicación de formas que no dan error claro:

* Los recursos de solo lectura (QML, iconos, banco de preguntas, teoría) quedan
  **dentro** del paquete. ``sys._MEIPASS`` apunta ahí.
* Los datos de escritura (resultados, checkpoints, datasets, logs) necesitan un
  lugar con permiso. En modo *onefile*, escribir dentro del paquete significa
  escribir en una carpeta temporal que Windows borra al cerrar: el trabajo del
  usuario desaparece sin un solo mensaje de error.

Por eso este módulo expone dos raíces, ``DIR_RECURSOS`` y ``DIR_DATOS``, que
coinciden mientras se corra desde el código fuente y divergen al empaquetar.

**Modo portable.** Empaquetada, la aplicación escribe en ``datos/``, junto al
ejecutable, y no en ``%APPDATA%``. Es lo que conviene a este proyecto: los
resultados del pre-test y del post-test se recogen copiando una carpeta, en vez
de entrar al perfil de cada usuario de cada equipo del laboratorio. Además,
``AppData\\Roaming`` se replica al servidor en equipos unidos a un dominio, y
los checkpoints de PyTorch pesan demasiado para eso. Si la carpeta del
ejecutable resulta de solo lectura (una instalación en ``Program Files``), se
recurre a la carpeta de datos del usuario.

Este módulo no importa Qt ni torch a propósito: así puede usarlo cualquier capa
sin arrastrar dependencias ni romper el aislamiento de ``model/``.
"""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

#: Nombre de la carpeta de escritura junto al ejecutable, en modo portable.
NOMBRE_CARPETA_DATOS = "datos"

#: Nombre usado para la carpeta de respaldo dentro de los datos del usuario.
NOMBRE_APLICACION = "TransformerVisualizer"
NOMBRE_ORGANIZACION = "TT"


def esta_empaquetada() -> bool:
    """¿Se está ejecutando desde un paquete de PyInstaller?"""
    return getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS")


def _es_escribible(directorio: Path) -> bool:
    """Comprueba el permiso de escritura intentándolo de verdad.

    En Windows los permisos efectivos no se pueden deducir de ``os.access``:
    una carpeta bajo ``Program Files`` aparece como escribible y falla al
    escribir. La única prueba confiable es crear un archivo.

    No crea el directorio: consultar el estado no debe modificarlo, para que
    ``describir()`` pueda llamarse sin dejar carpetas sembradas.
    """
    if not directorio.is_dir():
        return False
    try:
        with tempfile.NamedTemporaryFile(dir=directorio, prefix=".permiso_"):
            pass
        return True
    except OSError:
        return False


def _puede_habilitarse(directorio: Path) -> bool:
    """Crea el directorio si falta y comprueba que se pueda escribir en él.

    Solo se usa al decidir la raíz de datos, que es el único momento en que
    crear la carpeta es lo que se quiere.
    """
    try:
        directorio.mkdir(parents=True, exist_ok=True)
    except OSError:
        return False
    return _es_escribible(directorio)


def _raiz_datos_del_usuario() -> Path:
    """Carpeta de datos del usuario, sin depender de Qt.

    Se prefiere ``LOCALAPPDATA`` sobre ``APPDATA``: el segundo se sincroniza con
    el servidor en perfiles móviles y aquí se guardan checkpoints de cientos de
    megabytes.
    """
    if sys.platform == "win32":
        base = os.environ.get("LOCALAPPDATA") or os.environ.get("APPDATA")
        if base:
            return Path(base) / NOMBRE_ORGANIZACION / NOMBRE_APLICACION
    elif sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / NOMBRE_APLICACION
    base_xdg = os.environ.get("XDG_DATA_HOME")
    if base_xdg:
        return Path(base_xdg) / NOMBRE_APLICACION
    return Path.home() / ".local" / "share" / NOMBRE_APLICACION


def _calcular_raiz_recursos() -> Path:
    if esta_empaquetada():
        return Path(sys._MEIPASS).resolve()  # noqa: SLF001 - contrato de PyInstaller
    # core/rutas.py -> core/ -> raíz del proyecto
    return Path(__file__).resolve().parents[1]


def _calcular_raiz_datos(raiz_recursos: Path) -> Path:
    if not esta_empaquetada():
        # Desde el código fuente no hay nada que separar: se conserva el
        # comportamiento que el proyecto ya tenía.
        return raiz_recursos / "data"

    portable = Path(sys.executable).resolve().parent / NOMBRE_CARPETA_DATOS
    if _puede_habilitarse(portable):
        return portable
    return _raiz_datos_del_usuario()


DIR_RECURSOS: Path = _calcular_raiz_recursos()
DIR_DATOS: Path = _calcular_raiz_datos(DIR_RECURSOS)

# Subcarpetas de escritura. No se crean al importar: cada una se materializa
# cuando alguien la necesita, con asegurar().
DIR_DATASETS: Path = DIR_DATOS / "datasets"
DIR_CHECKPOINTS: Path = DIR_DATOS / "checkpoints"
DIR_LOGS: Path = DIR_DATOS / "logs"
DIR_RESULTADOS: Path = DIR_DATOS / "resultados"


def recurso(*partes: str) -> Path:
    """Ruta a un archivo de solo lectura que viaja dentro del paquete.

        recurso("view", "qml", "main.qml")
        recurso("data", "evaluacion", "question_bank.json")
    """
    return DIR_RECURSOS.joinpath(*partes)


def dato(*partes: str) -> Path:
    """Ruta a un archivo que la aplicación escribe.

        dato("resultados", "resultados_evaluacion.json")
    """
    return DIR_DATOS.joinpath(*partes)


def asegurar(directorio: Path) -> Path:
    """Crea el directorio si falta y lo devuelve, para encadenar."""
    directorio.mkdir(parents=True, exist_ok=True)
    return directorio


def describir() -> dict[str, str]:
    """Estado de las rutas, para diagnosticar un ejecutable que no arranca.

    Un paquete que no encuentra su QML o que no puede escribir da síntomas
    confusos; imprimir esto responde casi siempre qué pasó.
    """
    return {
        "empaquetada": str(esta_empaquetada()),
        "ejecutable": sys.executable,
        "recursos": str(DIR_RECURSOS),
        "datos": str(DIR_DATOS),
        "datos_escribible": str(_es_escribible(DIR_DATOS)),
        "modo_datos": (
            "codigo_fuente"
            if not esta_empaquetada()
            else ("portable" if DIR_DATOS.name == NOMBRE_CARPETA_DATOS else "usuario")
        ),
    }


if __name__ == "__main__":  # pragma: no cover - utilidad de diagnóstico
    for clave, valor in describir().items():
        print(f"{clave:>18}: {valor}")
