"""
Bloque Decoder de la arquitectura Transformer original, fiel al diagrama:

    Masked Multi-Head Attention -> Add & Norm
    -> Multi-Head Attention (cross-attention con el Encoder) -> Add & Norm
    -> Feed Forward -> Add & Norm

A diferencia del encoder, el decoder tiene TRES subcapas (no dos):

1. Self-attention CAUSAL (masked): cada posición solo puede atender a
   posiciones anteriores o iguales de la propia secuencia del decoder.
2. Cross-attention: la consulta (Q) sale del decoder, pero las llaves y
   valores (K, V) salen de la salida del Encoder — así el decoder
   "consulta" la secuencia de entrada al generar cada token.
3. Feed Forward, igual que en el encoder.
"""

import torch
import torch.nn as nn

from .atencion import AtencionMultiCabeza
from .conexion_residual import ConexionResidual
from .config import ConfiguracionTransformer
from .feed_forward import FeedForward


class BloqueDecoder(nn.Module):
    """Un bloque del Decoder: Masked Multi-Head Attention + Cross-Attention
    (con la salida del Encoder) + Feed Forward.

    Se apila `num_capas` veces (ver `Decoder` más abajo) para formar el
    Decoder completo, tal como indica el "N×" del diagrama.
    """

    def __init__(self, config: ConfiguracionTransformer):
        super().__init__()
        self.autoatencion = AtencionMultiCabeza(config)  # Masked Multi-Head Attention
        self.atencion_cruzada = AtencionMultiCabeza(config)  # Multi-Head Attention (cross)
        self.feed_forward = FeedForward(config)

        self.conexion_autoatencion = ConexionResidual(config.dimension_modelo, config.dropout)
        self.conexion_atencion_cruzada = ConexionResidual(config.dimension_modelo, config.dropout)
        self.conexion_feed_forward = ConexionResidual(config.dimension_modelo, config.dropout)

    def forward(
        self,
        x: torch.Tensor,
        salida_encoder: torch.Tensor,
        mascara_causal: torch.Tensor | None = None,
        mascara_encoder: torch.Tensor | None = None,
    ) -> torch.Tensor:
        """
        Args:
            x: entrada del decoder, forma (B, T_tgt, dimension_modelo).
            salida_encoder: salida del Encoder, forma (B, T_src, dimension_modelo).
                Se usa como fuente de K y V en la cross-attention.
            mascara_causal: máscara para la self-attention del decoder
                (bloquea posiciones futuras; ver `motor_llm/mascara.py`).
                Forma compatible con (T_tgt, T_tgt).
            mascara_encoder: máscara de relleno del encoder, para que la
                cross-attention no atienda a posiciones de relleno de la
                secuencia fuente. Forma compatible con (B, 1, 1, T_src).

        Returns:
            Tensor de forma (B, T_tgt, dimension_modelo).
        """
        # 1) Masked Multi-Head Attention (self-attention causal del decoder)
        x = self.conexion_autoatencion(
            x, lambda x_: self.autoatencion(x_, mascara=mascara_causal)
        )

        # 2) Multi-Head Attention (cross-attention: Q del decoder, K/V del encoder)
        x = self.conexion_atencion_cruzada(
            x,
            lambda x_: self.atencion_cruzada(
                x_, x_clave_valor=salida_encoder, mascara=mascara_encoder
            ),
        )

        # 3) Feed Forward
        x = self.conexion_feed_forward(x, self.feed_forward)
        return x

    @property
    def ultimos_pesos_autoatencion(self) -> torch.Tensor | None:
        """Pesos de la Masked Multi-Head Attention (self-attention del decoder)."""
        return self.autoatencion.ultimos_pesos_atencion

    @property
    def ultimos_pesos_atencion_cruzada(self) -> torch.Tensor | None:
        """Pesos de la cross-attention (decoder atendiendo al encoder) — son
        los más interesantes para visualizar, ya que muestran qué palabras
        de la entrada influyen en cada palabra generada."""
        return self.atencion_cruzada.ultimos_pesos_atencion


class Decoder(nn.Module):
    """Decoder completo: apila `num_capas` bloques `BloqueDecoder`.

    Corresponde al rectángulo gris con la etiqueta "N×" del lado derecho
    del diagrama (la pila completa de bloques idénticos).
    """

    def __init__(self, config: ConfiguracionTransformer):
        super().__init__()
        self.bloques = nn.ModuleList(
            [BloqueDecoder(config) for _ in range(config.num_capas)]
        )

    def forward(
        self,
        x: torch.Tensor,
        salida_encoder: torch.Tensor,
        mascara_causal: torch.Tensor | None = None,
        mascara_encoder: torch.Tensor | None = None,
    ) -> torch.Tensor:
        """
        Args:
            x: embeddings de salida (shifted right) + codificación
                posicional ya sumados, forma (B, T_tgt, dimension_modelo).
            salida_encoder: salida del Encoder completo, forma
                (B, T_src, dimension_modelo).
            mascara_causal: ver `BloqueDecoder.forward`.
            mascara_encoder: ver `BloqueDecoder.forward`.

        Returns:
            Tensor de forma (B, T_tgt, dimension_modelo), listo para pasar
            por la capa `Linear -> Softmax` final (en `transformer.py`).
        """
        for bloque in self.bloques:
            x = bloque(
                x,
                salida_encoder,
                mascara_causal=mascara_causal,
                mascara_encoder=mascara_encoder,
            )
        return x

    def pesos_autoatencion_por_capa(self) -> list[torch.Tensor | None]:
        """Pesos de la self-attention (masked) de cada bloque, una entrada
        por capa."""
        return [bloque.ultimos_pesos_autoatencion for bloque in self.bloques]

    def pesos_atencion_cruzada_por_capa(self) -> list[torch.Tensor | None]:
        """Pesos de la cross-attention de cada bloque, una entrada por
        capa — normalmente los más útiles para el Lienzo Científico."""
        return [bloque.ultimos_pesos_atencion_cruzada for bloque in self.bloques]