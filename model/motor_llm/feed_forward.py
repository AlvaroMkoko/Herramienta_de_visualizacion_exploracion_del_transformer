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
        self.ultima_traza: dict | None = None

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Args:
            x: forma (B, T, dimension_modelo).

        Returns:
            Tensor de forma (B, T, dimension_modelo).
        """
        entrada = x
        preactivacion = self.capa_expansion(entrada)
        activacion = self.activacion(preactivacion)
        proyeccion = self.capa_proyeccion(activacion)
        salida = self.dropout(proyeccion)
        self.ultima_traza = {
            "entrada": entrada[:, -1, :].detach(),
            "preactivacion": preactivacion[:, -1, :].detach(),
            "activacion": activacion[:, -1, :].detach(),
            "salida": salida[:, -1, :].detach(),
            "shape_entrada": tuple(entrada.shape),
            "shape_oculta": tuple(activacion.shape),
            "shape_salida": tuple(salida.shape),
            "activacion_nombre": self.activacion.__class__.__name__,
        }
        return salida
