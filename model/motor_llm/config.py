"""
Configuración centralizada del Motor LLM.

Todos los módulos de `motor_llm/` (embeddings, atención, feed-forward,
bloques, y el ensamblaje final) reciben una instancia de
`ConfiguracionTransformer` en lugar de hiperparámetros sueltos, para que:

- No se dupliquen valores mágicos en cada archivo.
- Sea trivial instanciar variantes distintas del modelo (ej. una
  configuración pequeña para pruebas rápidas en CPU/laptop y otra más
  grande para entrenar en la GPU de escritorio).
- El ViewModel pueda leer esta config para poblar los controles de la
  Vista (rangos válidos de temperatura, top-k, etc. — ver
  core/constants.py para los límites de esos parámetros de generación,
  que son distintos de los hiperparámetros de arquitectura de aquí).
"""

from dataclasses import dataclass

ACTIVACIONES = ["relu", "gelu", "swish"]

@dataclass
class ConfiguracionTransformer:
    """Hiperparámetros de arquitectura del Transformer.

    Atributos:
        tamano_vocabulario: tamaño del vocabulario del tokenizador.
        dimension_modelo: dimensión de los embeddings / dimensión interna del modelo.
        num_cabezas: número de cabezas de atención (dimension_modelo debe ser
            divisible entre num_cabezas, se valida en __post_init__).
        num_capas: número de bloques Transformer apilados.
        dimension_ff: dimensión interna de la red feed-forward (usualmente
            4 * dimension_modelo).
        longitud_maxima_secuencia: longitud máxima de secuencia soportada por
            la codificación posicional (bloque de contexto).
        dropout: probabilidad de dropout aplicada en atención, feed-forward
            y conexiones residuales.
        id_token_relleno: id del token de relleno (padding), usado para
            máscaras (None si el dataset no requiere relleno, ej.
            secuencias de longitud fija).
                activacion: función de activación del feed-forward ("relu" por
            defecto, la del paper original; "gelu" como GPT-2/BERT; "swish").
        usar_mascara_causal: si es False, el decoder puede ver tokens
            futuros durante el entrenamiento. Deliberadamente incorrecto,
            pensado como herramienta educativa (ver Transformer.crear_mascaras).
    """

    tamano_vocabulario: int
    dimension_modelo: int = 384
    num_cabezas: int = 6
    num_capas: int = 6
    dimension_ff: int = 4 * 384
    longitud_maxima_secuencia: int = 256
    dropout: float = 0.1
    id_token_relleno: int | None = None
    activacion: str = "relu"              # "relu" | "gelu" | "swish"
    usar_mascara_causal: bool = True

    def __post_init__(self) -> None:
        if self.dimension_modelo % self.num_cabezas != 0:
            raise ValueError(
                f"dimension_modelo ({self.dimension_modelo}) debe ser divisible "
                f"entre num_cabezas ({self.num_cabezas})."
            )
        if self.tamano_vocabulario <= 0:
            raise ValueError("tamano_vocabulario debe ser mayor a 0.")

        if self.dimension_ff <= 0:
            raise ValueError("dimension_ff debe ser mayor a 0.")

        if self.activacion not in ACTIVACIONES:
            raise ValueError(f"activacion debe ser una de {ACTIVACIONES}.")

    @property
    def dimension_cabeza(self) -> int:
        """Dimensión de cada cabeza de atención (dimension_modelo / num_cabezas)."""
        return self.dimension_modelo // self.num_cabezas


# Configuración pequeña de referencia, útil para pruebas unitarias y para
# validar el pipeline completo en CPU (laptop) antes de escalar en la GPU
# de escritorio.
CONFIG_PRUEBA = ConfiguracionTransformer(
    tamano_vocabulario=1000,
    dimension_modelo=64,
    num_cabezas=4,
    num_capas=2,
    dimension_ff=4 * 64,
    longitud_maxima_secuencia=64,
    dropout=0.1,
    activacion="relu",
    usar_mascara_causal=True
)