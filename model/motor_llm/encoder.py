"""
Bloque Encoder de la arquitectura Transformer original, fiel al diagrama:

    Multi-Head Attention -> Add & Norm -> Feed Forward -> Add & Norm

El encoder NO usa máscara causal: cada posición puede atender a TODAS las
posiciones de la secuencia de entrada (pasado y futuro), a diferencia del
decoder. Solo necesitaría una máscara de relleno (padding) si se entrena
con secuencias de distinta longitud en el mismo batch.
"""

import torch
import torch.nn as nn

from .atencion import AtencionMultiCabeza
from .conexion_residual import ConexionResidual
from .config import ConfiguracionTransformer
from .feed_forward import FeedForward


class BloqueEncoder(nn.Module):
    """Un bloque del Encoder: Multi-Head Attention + Feed Forward.

    Se apila `num_capas` veces (ver `transformer.py`) para formar el
    Encoder completo, tal como indica el "N×" del diagrama.
    """

    def __init__(self, config: ConfiguracionTransformer):
        super().__init__()
        self.atencion = AtencionMultiCabeza(config)
        self.feed_forward = FeedForward(config)

        self.conexion_atencion = ConexionResidual(config.dimension_modelo, config.dropout)
        self.conexion_feed_forward = ConexionResidual(config.dimension_modelo, config.dropout)

    def forward(self, x: torch.Tensor, mascara: torch.Tensor | None = None) -> torch.Tensor:
        """
        Args:
            x: forma (B, T_src, dimension_modelo).
            mascara: máscara de relleno del encoder (opcional; ver nota
                de módulo — el encoder no necesita máscara causal).

        Returns:
            Tensor de forma (B, T_src, dimension_modelo).
        """
        x = self.conexion_atencion(x, lambda x_: self.atencion(x_, mascara=mascara))
        x = self.conexion_feed_forward(x, self.feed_forward)
        return x

    @property
    def ultimos_pesos_atencion(self) -> torch.Tensor | None:
        """Pesos de la Multi-Head Attention de este bloque, expuestos para
        que el ViewModel/Adaptador Visual los use en el Lienzo Científico."""
        return self.atencion.ultimos_pesos_atencion


class Encoder(nn.Module):
    """Encoder completo: apila `num_capas` bloques `BloqueEncoder`.

    Corresponde al rectángulo gris con la etiqueta "N×" del diagrama
    (la pila completa de bloques idénticos).
    """

    def __init__(self, config: ConfiguracionTransformer):
        super().__init__()
        self.bloques = nn.ModuleList(
            [BloqueEncoder(config) for _ in range(config.num_capas)]
        )

    def forward(self, x: torch.Tensor, mascara: torch.Tensor | None = None) -> torch.Tensor:
        """
        Args:
            x: embeddings de entrada + codificación posicional ya sumados,
                forma (B, T_src, dimension_modelo).
            mascara: máscara de relleno del encoder (opcional).

        Returns:
            Tensor de forma (B, T_src, dimension_modelo), la salida final
            del encoder que alimentará la cross-attention del decoder.
        """
        for bloque in self.bloques:
            x = bloque(x, mascara=mascara)
        return x

    def pesos_atencion_por_capa(self) -> list[torch.Tensor | None]:
        """Lista con los pesos de atención de cada bloque (una entrada por
        capa), útil para que el ViewModel permita elegir "ver la capa N"
        en el Lienzo Científico."""
        return [bloque.ultimos_pesos_atencion for bloque in self.bloques]