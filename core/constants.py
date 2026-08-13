"""
Constantes compartidas por Model / ViewModel / View.

Nada de lógica aquí — solo valores fijos que deben mantenerse
consistentes entre las tres capas (ej. los rangos de un slider en QML
deben coincidir con los límites que valida el ViewModel antes de pedirle
al Modelo que genere texto).
"""

from enum import StrEnum

# ---------------------------------------------------------------------------
# Pantallas de la aplicación (usado por la navegación en view/qml/)
# ---------------------------------------------------------------------------

class Pantalla(StrEnum):
    CONFIGURACION = "configuracion"
    ENTRENAMIENTO = "entrenamiento"
    INFERENCIA = "inferencia"
    COMPARACION = "comparacion"
    EVALUACION = "evaluacion"


# ---------------------------------------------------------------------------
# Parámetros de generación (muestreo) — límites válidos
# ---------------------------------------------------------------------------
# Estos rangos los usa la Vista para configurar los sliders y el
# ViewModel para validar antes de invocar al Modelo (model/motor_llm/muestreo.py).

TEMPERATURA_MIN = 0.1
TEMPERATURA_MAX = 2.0
TEMPERATURA_DEFECTO = 1.0

TOP_K_MIN = 1
TOP_K_MAX = 100
TOP_K_DEFECTO = 50

TOP_P_MIN = 0.0
TOP_P_MAX = 1.0
TOP_P_DEFECTO = 0.9

MAX_TOKENS_NUEVOS_MIN = 1
MAX_TOKENS_NUEVOS_MAX = 512
MAX_TOKENS_NUEVOS_DEFECTO = 100


# ---------------------------------------------------------------------------
# Entrenamiento
# ---------------------------------------------------------------------------

TAMANO_BATCH_DEFECTO = 32
TASA_APRENDIZAJE_DEFECTO = 3e-4
TAMANO_BLOQUE_DEFECTO = 256  # longitud de secuencia de entrenamiento


# ---------------------------------------------------------------------------
# Evaluación (RF22-RF25)
# ---------------------------------------------------------------------------

MIN_PREGUNTAS_POR_EVALUACION = 5
MAX_PREGUNTAS_POR_EVALUACION = 20


# ---------------------------------------------------------------------------
# Persistencia
# ---------------------------------------------------------------------------

EXTENSION_CHECKPOINT = ".tvismodel"
NOMBRE_CHECKPOINT_DEFECTO = "modelo_transformer"