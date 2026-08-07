"""
Red Feed-Forward posición a posición (Position-wise Feed-Forward Network).

Se aplica de forma independiente a cada posición de la secuencia, después
del bloque de atención. Es la parte del Transformer donde el modelo
"procesa" la información ya mezclada entre tokens por la atención.
"""

import torch
import torch.nn as nn

from .config import ConfiguracionTransformer

_ACTIVACIONES = {"relu": nn.ReLU, "gelu": nn.GELU, "swish": nn.SiLU}

class FeedForward(nn.Module):
    """Linear -> GELU -> Dropout -> Linear.

    Expande la dimensión de `dimension_modelo` a `dimension_ff` (por
    convención, 4x más grande), aplica una no-linealidad, y vuelve a
    proyectar a `dimension_modelo` para poder sumarse en la conexión
    residual del bloque Transformer.
    """

    def __init__(self, config: ConfiguracionTransformer):
        super().__init__()
        self.capa_expansion = nn.Linear(config.dimension_modelo, config.dimension_ff)
        self.activacion = _ACTIVACIONES[config.activacion]()
        self.capa_proyeccion = nn.Linear(config.dimension_ff, config.dimension_modelo)
        self.dropout = nn.Dropout(config.dropout)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Args:
            x: forma (B, T, dimension_modelo).

        Returns:
            Tensor de forma (B, T, dimension_modelo).
        """
        x = self.capa_expansion(x)
        x = self.activacion(x)
        x = self.capa_proyeccion(x)
        return self.dropout(x)