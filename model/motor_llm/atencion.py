"""
Núcleo de atención: Scaled Dot-Product Attention + Multi-Head Attention.

La Multi-Head Attention se implementa con proyecciones de Q, K y V
SEPARADAS (en vez de una sola proyección combinada) porque el decoder de
la arquitectura Encoder-Decoder necesita hacer "cross-attention": la
consulta (Q) sale del decoder, pero las llaves y valores (K, V) salen de
la salida del encoder. Con proyecciones separadas, la misma clase
`AtencionMultiCabeza` sirve tanto para self-attention (Q, K, V del mismo
tensor) como para cross-attention (Q de un tensor, K/V de otro).
"""

import math

import torch
import torch.nn as nn
import torch.nn.functional as F

from .config import ConfiguracionTransformer


def atencion_escalada(
    q: torch.Tensor,
    k: torch.Tensor,
    v: torch.Tensor,
    mascara: torch.Tensor | None = None,
    dropout: nn.Dropout | None = None,
) -> tuple[torch.Tensor, torch.Tensor]:
    """Scaled Dot-Product Attention.

    Attention(Q, K, V) = softmax(Q·K^T / sqrt(d_k)) · V

    Args:
        q: consultas (queries), forma (B, num_cabezas, T_q, dimension_cabeza).
        k: llaves (keys), forma (B, num_cabezas, T_k, dimension_cabeza).
        v: valores (values), misma forma que k.
        mascara: booleana, forma compatible por broadcast con
            (B, num_cabezas, T_q, T_k). `True` = posición permitida,
            `False` = posición bloqueada (se pone en -infinito).
        dropout: módulo de dropout a aplicar sobre los pesos de atención
            (después del softmax), o None si no aplica (ej. en eval()).

    Returns:
        Tupla (salida, pesos_atencion):
        - salida: forma (B, num_cabezas, T_q, dimension_cabeza).
        - pesos_atencion: forma (B, num_cabezas, T_q, T_k). Se retornan
          explícitamente porque `viewmodel/visual_adapter.py` los necesita
          para alimentar el Lienzo Científico (mapas de atención).

    Nota: T_q == T_k en self-attention, pero T_q puede ser distinto de
    T_k en cross-attention (Q viene del decoder con longitud T_tgt, K/V
    vienen del encoder con longitud T_src).
    """
    dimension_cabeza = q.size(-1)

    # (B, num_cabezas, T_q, T_k)
    scores = (q @ k.transpose(-2, -1)) / math.sqrt(dimension_cabeza)

    if mascara is not None:
        scores = scores.masked_fill(mascara == False, float("-inf"))  # noqa: E712

    pesos_atencion = F.softmax(scores, dim=-1)

    if dropout is not None:
        pesos_atencion = dropout(pesos_atencion)

    salida = pesos_atencion @ v
    return salida, pesos_atencion


class AtencionMultiCabeza(nn.Module):
    """Multi-Head Attention con proyecciones Q/K/V separadas.

    Sirve para dos casos de uso, según qué le pases en `forward`:

    - Self-attention (encoder, o masked self-attention del decoder):
      `atencion(x, mascara=mascara)` — Q, K y V salen todos de `x`.
    - Cross-attention (decoder atendiendo al encoder):
      `atencion(x_decoder, x_clave_valor=salida_encoder, mascara=mascara)`
      — Q sale de `x_decoder`, K y V salen de `salida_encoder`.
    """

    def __init__(self, config: ConfiguracionTransformer):
        super().__init__()
        self.num_cabezas = config.num_cabezas
        self.dimension_cabeza = config.dimension_cabeza
        self.dimension_modelo = config.dimension_modelo

        self.proyeccion_q = nn.Linear(config.dimension_modelo, config.dimension_modelo)
        self.proyeccion_k = nn.Linear(config.dimension_modelo, config.dimension_modelo)
        self.proyeccion_v = nn.Linear(config.dimension_modelo, config.dimension_modelo)
        self.proyeccion_salida = nn.Linear(config.dimension_modelo, config.dimension_modelo)

        self.dropout_atencion = nn.Dropout(config.dropout)
        self.dropout_salida = nn.Dropout(config.dropout)

        # Se guardan los últimos pesos de atención calculados, para que el
        # ViewModel pueda leerlos después del forward sin tener que
        # modificar la firma de retorno de todo el modelo.
        self.ultimos_pesos_atencion: torch.Tensor | None = None

    def _separar_cabezas(self, x: torch.Tensor) -> torch.Tensor:
        """(B, T, dimension_modelo) -> (B, num_cabezas, T, dimension_cabeza)."""
        b, t, _ = x.shape
        x = x.view(b, t, self.num_cabezas, self.dimension_cabeza)
        return x.transpose(1, 2)

    def _combinar_cabezas(self, x: torch.Tensor) -> torch.Tensor:
        """(B, num_cabezas, T, dimension_cabeza) -> (B, T, dimension_modelo)."""
        b, _, t, _ = x.shape
        x = x.transpose(1, 2).contiguous()
        return x.view(b, t, self.dimension_modelo)

    def forward(
        self,
        x: torch.Tensor,
        x_clave_valor: torch.Tensor | None = None,
        mascara: torch.Tensor | None = None,
    ) -> torch.Tensor:
        """
        Args:
            x: fuente de la consulta (Q), forma (B, T_q, dimension_modelo).
            x_clave_valor: fuente de llaves/valores (K, V), forma
                (B, T_k, dimension_modelo). Si es None, se usa `x` (self-attention).
            mascara: ver `atencion_escalada`.

        Returns:
            Tensor de forma (B, T_q, dimension_modelo).
        """
        if x_clave_valor is None:
            x_clave_valor = x  # self-attention

        q = self._separar_cabezas(self.proyeccion_q(x))
        k = self._separar_cabezas(self.proyeccion_k(x_clave_valor))
        v = self._separar_cabezas(self.proyeccion_v(x_clave_valor))

        salida, pesos_atencion = atencion_escalada(
            q, k, v, mascara=mascara, dropout=self.dropout_atencion
        )
        self.ultimos_pesos_atencion = pesos_atencion.detach()

        salida = self._combinar_cabezas(salida)
        salida = self.proyeccion_salida(salida)
        return self.dropout_salida(salida)