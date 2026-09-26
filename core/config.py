"""
Configuración global de la aplicación.

Centraliza:
- Detección dinámica del dispositivo de cómputo (CPU/CUDA), para que el
  mismo código corra sin cambios en distintas GPUs de desarrollo
  (ej. RTX 5070 Ti de escritorio, RTX 3050 de laptop) o incluso sin GPU.
- Reexporta las rutas base del proyecto, que calcula core/rutas.py.
- Semilla global para reproducibilidad de experimentos.
"""

import random
from pathlib import Path

import numpy as np
import torch

from core.rutas import (
    DIR_CHECKPOINTS as _DIR_CHECKPOINTS,
    DIR_DATASETS as _DIR_DATASETS,
    DIR_DATOS as _DIR_DATOS,
    DIR_LOGS as _DIR_LOGS,
    DIR_RECURSOS,
    asegurar,
)

# ---------------------------------------------------------------------------
# Rutas base del proyecto
# ---------------------------------------------------------------------------

# Las rutas ya no se calculan aquí: viven en core/rutas.py, que distingue los
# recursos de solo lectura (dentro del paquete, al empaquetar) de los datos de
# escritura (fuera de él). Antes, DIR_BASE se derivaba de __file__, lo que en un
# ejecutable apunta dentro del paquete: en modo onefile eso es una carpeta
# temporal que el sistema borra al cerrar, y los checkpoints se perderían.
#
# Los nombres se reexportan para no tocar los módulos que ya los importan.
DIR_BASE = DIR_RECURSOS
DIR_DATOS = _DIR_DATOS
DIR_DATASETS = _DIR_DATASETS
DIR_CHECKPOINTS = _DIR_CHECKPOINTS
DIR_LOGS = _DIR_LOGS

# Crea las carpetas si no existen (evita errores al primer guardado)
for _directorio in (DIR_DATASETS, DIR_CHECKPOINTS, DIR_LOGS):
    asegurar(_directorio)


# ---------------------------------------------------------------------------
# Detección de dispositivo de cómputo (CPU/CUDA)
# ---------------------------------------------------------------------------

def obtener_dispositivo(preferido: str | None = None) -> torch.device:
    """Detecta y retorna el dispositivo de cómputo disponible.

    Permite que el mismo código corra sin cambios en distintas máquinas
    de desarrollo (GPU de escritorio, GPU de laptop, o sin GPU).

    Args:
        preferido: fuerza un dispositivo específico ("cuda", "cpu").
            Si es None, se detecta automáticamente. Útil para debugging
            (ej. forzar CPU aunque haya GPU disponible).

    Returns:
        torch.device: "cuda" si hay una GPU NVIDIA disponible y compatible,
        "cpu" en caso contrario.
    """
    if preferido is not None:
        return torch.device(preferido)

    if torch.cuda.is_available():
        return torch.device("cuda")

    return torch.device("cpu")


def obtener_info_dispositivo(dispositivo: torch.device | None = None) -> dict:
    """Retorna información legible del dispositivo activo.

    Para mostrar en la UI qué GPU está usando el usuario.
    """
    dispositivo = dispositivo or obtener_dispositivo()

    info = {"dispositivo": str(dispositivo)}

    if dispositivo.type == "cuda":
        indice = torch.cuda.current_device()
        info.update(
            {
                "nombre": torch.cuda.get_device_name(indice),
                "capacidad": torch.cuda.get_device_capability(indice),
                "memoria_total_gb": round(
                    torch.cuda.get_device_properties(indice).total_memory / 1024**3, 2
                ),
                "version_cuda": torch.version.cuda,
            }
        )
    else:
        info["nombre"] = "CPU"

    return info


# Dispositivo global por defecto, calculado una sola vez al importar el módulo.
DISPOSITIVO = obtener_dispositivo()


# ---------------------------------------------------------------------------
# Reproducibilidad
# ---------------------------------------------------------------------------

def fijar_semilla(semilla: int = 42) -> None:
    """Fija la semilla global para random, numpy y torch (CPU y CUDA).

    Llamar una sola vez al inicio de la aplicación o de cada experimento
    de entrenamiento/evaluación para resultados reproducibles.
    """
    random.seed(semilla)
    np.random.seed(semilla)
    torch.manual_seed(semilla)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(semilla)