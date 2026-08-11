"""
Conexión residual con normalización posterior (post-norm) — corresponde
al bloque "Add & Norm" del diagrama original del paper.

Vive en su propio archivo porque tanto `encoder.py` como
`decoder.py` la reutilizan tal cual, sin ninguna variación.
"""

import torch
import torch.nn as nn


class ConexionResidual(nn.Module):
    """Conexión residual con normalización POSTERIOR (post-norm).

    Aplica: norma(x + dropout(subcapa(x)))
    """

    def __init__(self, dimension_modelo: int, dropout: float):
        super().__init__()
        self.norma = nn.LayerNorm(dimension_modelo)
        self.dropout = nn.Dropout(dropout)
        self.ultima_traza: dict | None = None

    def forward(self, x: torch.Tensor, subcapa) -> torch.Tensor:
        """
        Args:
            x: forma (B, T, dimension_modelo).
            subcapa: función/módulo que recibe `x` (SIN normalizar) y
                retorna un tensor de la misma forma.
        """
        actualizacion = self.dropout(subcapa(x))
        suma = x + actualizacion
        salida = self.norma(suma)
        self.ultima_traza = {
            "entrada": x[:, -1, :].detach(),
            "actualizacion": actualizacion[:, -1, :].detach(),
            "antes_norma": suma[:, -1, :].detach(),
            "salida": salida[:, -1, :].detach(),
            "shape": tuple(salida.shape),
            "epsilon": float(self.norma.eps),
        }
        return salida
