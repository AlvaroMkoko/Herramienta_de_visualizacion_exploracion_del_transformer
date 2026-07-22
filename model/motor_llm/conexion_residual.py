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

    def forward(self, x: torch.Tensor, subcapa) -> torch.Tensor:
        """
        Args:
            x: forma (B, T, dimension_modelo).
            subcapa: función/módulo que recibe `x` (SIN normalizar) y
                retorna un tensor de la misma forma.
        """
        return self.norma(x + self.dropout(subcapa(x)))