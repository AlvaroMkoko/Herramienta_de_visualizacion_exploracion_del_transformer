"""
Ensamblaje final del Transformer, siguiendo el diagrama completo de
"Attention Is All You Need":

    Inputs -> Input Embedding -> (+) Positional Encoding -> Encoder (N×)
                                                                  |
    Outputs (shifted right) -> Output Embedding -> (+) Positional Encoding -> Decoder (N×)
                                                                  |
                                                              Linear
                                                                  |
                                                              Softmax
                                                                  |
                                                     Output Probabilities

Este módulo NO reimplementa la atención, el feed-forward ni los bloques
encoder/decoder — solo los orquesta. La lógica matemática vive en
`atencion.py`, `feed_forward.py`, `encoder.py` y `decoder.py`.
"""

import math

import torch
import torch.nn as nn
import torch.nn.functional as F

from .config import ConfiguracionTransformer
from .decoder import Decoder
from .embedding import TokenEmbedding
from .encoder import Encoder
from .mascara import combinar_mascaras, crear_mascara_causal, crear_mascara_relleno
from .positional_encoding import PositionalEncoding
from .muestreo import muestrear, muestrear_codicioso

ACTIVACIONES = ["relu", "gelu", "swish"]

class Transformer(nn.Module):
    """Transformer Encoder-Decoder completo.

    Args:
        config: hiperparámetros de arquitectura.
        compartir_pesos_salida: si es True (default, como en el paper
            original, sección 3.4), la tabla de `Output Embedding` y la
            capa `Linear` final comparten los mismos pesos ("weight
            tying"). Reduce el número de parámetros y suele mejorar la
            calidad del modelo.
    """

    def __init__(self, config: ConfiguracionTransformer, compartir_pesos_salida: bool = True):
        super().__init__()
        self.config = config
        self.compartir_pesos_salida = compartir_pesos_salida

        # --- Entradas: Input Embedding / Output Embedding + Positional Encoding ---
        self.embedding_entrada = TokenEmbedding(config.tamano_vocabulario, config.dimension_modelo)
        self.embedding_salida = TokenEmbedding(config.tamano_vocabulario, config.dimension_modelo)
        self.codificacion_posicional = PositionalEncoding(
            config.dimension_modelo, config.longitud_maxima_secuencia
        )
        self.dropout_entrada = nn.Dropout(config.dropout)
        self.dropout_salida = nn.Dropout(config.dropout)

        # --- Encoder (N×) y Decoder (N×) ---
        self.encoder = Encoder(config)
        self.decoder = Decoder(config)

        # --- Linear + Softmax ---
        self.capa_salida = nn.Linear(config.dimension_modelo, config.tamano_vocabulario)

        if compartir_pesos_salida:
            # "Weight tying": la capa Linear final reutiliza la misma matriz
            # de pesos que el Output Embedding (mismo shape: vocab x d_model).
            self.capa_salida.weight = self.embedding_salida.embedding.weight

        self._inicializar_pesos()

    def _inicializar_pesos(self) -> None:
        """Inicialización Xavier/Glorot para las capas lineales, estándar
        en implementaciones de Transformer (ayuda a estabilizar el
        entrenamiento con post-norm, que es más sensible a la
        inicialización que el pre-norm)."""
        for p in self.parameters():
            if p.dim() > 1:
                nn.init.xavier_uniform_(p)

    # ------------------------------------------------------------------
    # Máscaras
    # ------------------------------------------------------------------

    def crear_mascaras(
        self, tokens_origen: torch.Tensor, tokens_destino: torch.Tensor
    ) -> tuple[torch.Tensor | None, torch.Tensor]:
        """Construye automáticamente las máscaras necesarias a partir de
        los tokens de entrada, usando `config.id_token_relleno`.

        Args:
            tokens_origen: ids de la secuencia de entrada, forma (B, T_src).
            tokens_destino: ids de la secuencia de salida (shifted right),
                forma (B, T_tgt).

        Returns:
            Tupla (mascara_encoder, mascara_causal_decoder):
            - mascara_encoder: forma (B, 1, 1, T_src) o None si no hay
              `id_token_relleno` configurado. Se usa tanto dentro del
              encoder como en la cross-attention del decoder.
            - mascara_causal_decoder: forma (T_tgt, T_tgt) combinada con
              el relleno del propio destino si aplica.
        """
        mascara_encoder = None
        if self.config.id_token_relleno is not None:
            mascara_encoder = crear_mascara_relleno(tokens_origen, self.config.id_token_relleno)

        if self.config.usar_mascara_causal:
            mascara_destino = crear_mascara_causal(tokens_destino.size(1), dispositivo=tokens_destino.device)
        else:
            mascara_destino = None
        
        if self.config.id_token_relleno is not None:
            mascara_relleno_destino = crear_mascara_relleno(tokens_destino, self.config.id_token_relleno)
            mascara_destino = (
                combinar_mascaras(mascara_destino, mascara_relleno_destino)
                if mascara_destino is not None
                else mascara_relleno_destino
            )
        
        return mascara_encoder, mascara_destino

    # ------------------------------------------------------------------
    # Forward
    # ------------------------------------------------------------------

    def forward(
        self,
        tokens_origen: torch.Tensor,
        tokens_destino: torch.Tensor,
        mascara_encoder: torch.Tensor | None = None,
        mascara_causal: torch.Tensor | None = None,
    ) -> torch.Tensor:
        """
        Args:
            tokens_origen: ids de la secuencia de entrada ("Inputs"),
                forma (B, T_src).
            tokens_destino: ids de la secuencia de salida ya desplazada
                a la derecha ("Outputs (shifted right)"), forma (B, T_tgt).
            mascara_encoder: si es None, se genera automáticamente con
                `crear_mascaras` a partir de `config.id_token_relleno`.
            mascara_causal: idem, se genera automáticamente si es None.

        Returns:
            Logits (SIN softmax aplicado) de forma (B, T_tgt, tamano_vocabulario).
            Se retornan logits crudos porque `nn.CrossEntropyLoss` (usada en
            el entrenamiento) ya aplica softmax internamente de forma
            numéricamente más estable. Para obtener probabilidades
            explícitas (ej. en inferencia), usar `obtener_probabilidades`.
        """
        if mascara_encoder is None or mascara_causal is None:
            mascara_encoder_auto, mascara_causal_auto = self.crear_mascaras(
                tokens_origen, tokens_destino
            )
            mascara_encoder = mascara_encoder if mascara_encoder is not None else mascara_encoder_auto
            mascara_causal = mascara_causal if mascara_causal is not None else mascara_causal_auto

        # --- Rama del Encoder ---
        x_encoder = self.embedding_entrada(tokens_origen) * math.sqrt(self.config.dimension_modelo)
        x_encoder = self.codificacion_posicional(x_encoder)
        x_encoder = self.dropout_entrada(x_encoder)
        salida_encoder = self.encoder(x_encoder, mascara=mascara_encoder)

        # --- Rama del Decoder ---
        x_decoder = self.embedding_salida(tokens_destino) * math.sqrt(self.config.dimension_modelo)
        x_decoder = self.codificacion_posicional(x_decoder)
        x_decoder = self.dropout_salida(x_decoder)
        salida_decoder = self.decoder(
            x_decoder,
            salida_encoder,
            mascara_causal=mascara_causal,
            mascara_encoder=mascara_encoder,
        )

        # --- Linear ---
        logits = self.capa_salida(salida_decoder)
        return logits

    def obtener_probabilidades(self, logits: torch.Tensor) -> torch.Tensor:
        """Aplica el `Softmax` final del diagrama para obtener las
        `Output Probabilities` explícitas. Se separa del `forward()`
        porque durante el entrenamiento no se necesita (se usan los
        logits crudos con `nn.CrossEntropyLoss`), y solo se usa
        explícitamente en inferencia/generación.
        """
        return F.softmax(logits, dim=-1)

    def calcular_perdida(self, logits: torch.Tensor, objetivo: torch.Tensor) -> torch.Tensor:
        """Calcula la pérdida de entrenamiento (cross-entropy).

        Args:
            logits: forma (B, T_tgt, tamano_vocabulario), salida de `forward`.
            objetivo: ids de los tokens esperados, forma (B, T_tgt).

        Returns:
            Escalar con la pérdida promedio, ignorando las posiciones de
            relleno si `config.id_token_relleno` está definido.
        """
        return F.cross_entropy(
            logits.reshape(-1, self.config.tamano_vocabulario),
            objetivo.reshape(-1),
            ignore_index=self.config.id_token_relleno
            if self.config.id_token_relleno is not None
            else -100,
        )

    @torch.no_grad()
    def generar(
        self,
        tokens_origen: torch.Tensor,
        id_token_inicio: int,
        id_token_fin: int | None = None,
        max_tokens_nuevos: int = 100,
        temperatura: float = 1.0,
        top_k: int | None = None,
        top_p: float | None = None,
        muestreo_codicioso: bool = False,
    ):
        """Generación autoregresiva: produce un token nuevo por paso.

        Es un GENERADOR de Python (usa `yield`), no una función que
        retorna todo el texto de una sola vez — así una capa superior
        (ej. `viewmodel/inference_controller.py`) puede pausar, detener,
        o inspeccionar los tensores intermedios DESPUÉS de cada token,
        sin que este método sepa nada de threads, señales de Qt, ni UI.

        El encoder se ejecuta UNA SOLA VEZ al principio (la secuencia de
        entrada no cambia durante la generación); solo el decoder se
        vuelve a ejecutar en cada paso, con la secuencia de destino cada
        vez un token más larga.
        """
        modo_entrenamiento_previo = self.training
        self.eval()
        try:
            mascara_encoder = None
            if self.config.id_token_relleno is not None:
                mascara_encoder = crear_mascara_relleno(
                    tokens_origen, self.config.id_token_relleno
                )

            x_encoder = self.embedding_entrada(tokens_origen) * math.sqrt(
                self.config.dimension_modelo
            )
            x_encoder = self.codificacion_posicional(x_encoder)
            salida_encoder = self.encoder(x_encoder, mascara=mascara_encoder)

            tokens_destino = torch.tensor(
                [[id_token_inicio]], dtype=torch.long, device=tokens_origen.device
            )

            for paso in range(max_tokens_nuevos):
                mascara_causal = crear_mascara_causal(
                    tokens_destino.size(1), dispositivo=tokens_destino.device
                )

                x_decoder = self.embedding_salida(tokens_destino) * math.sqrt(
                    self.config.dimension_modelo
                )
                x_decoder = self.codificacion_posicional(x_decoder)
                salida_decoder = self.decoder(
                    x_decoder, salida_encoder,
                    mascara_causal=mascara_causal, mascara_encoder=mascara_encoder,
                )

                logits_ultimo_paso = self.capa_salida(salida_decoder[:, -1, :])

                # Los ids reservados (relleno, inicio) son válidos DENTRO
                # del vocabulario del modelo, pero no tienen ningún
                # significado como texto — nada les impide aparecer en el
                # muestreo si no se excluyen explícitamente. id_token_fin
                # SÍ se deja permitido: es la señal legítima de "terminar".
                logits_ultimo_paso = logits_ultimo_paso.clone()
                logits_ultimo_paso[:, id_token_inicio] = float("-inf")
                if self.config.id_token_relleno is not None:
                    logits_ultimo_paso[:, self.config.id_token_relleno] = float("-inf")

                if muestreo_codicioso:
                    token_nuevo = muestrear_codicioso(logits_ultimo_paso)
                else:
                    token_nuevo = muestrear(logits_ultimo_paso, temperatura=temperatura, top_k=top_k, top_p=top_p)

                tokens_destino = torch.cat([tokens_destino, token_nuevo], dim=1)

                yield {
                    "paso": paso,
                    "token_id": token_nuevo.item(),
                    "logits": logits_ultimo_paso.detach(),
                    "pesos_atencion_cruzada_por_capa": self.decoder.pesos_atencion_cruzada_por_capa(),
                    "pesos_autoatencion_por_capa": self.decoder.pesos_autoatencion_por_capa(),
                    "pesos_atencion_encoder_por_capa": self.encoder.pesos_atencion_por_capa(),
                }

                if id_token_fin is not None and token_nuevo.item() == id_token_fin:
                    return tokens_destino[:, 1:]

            return tokens_destino[:, 1:]
        finally:
            self.train(modo_entrenamiento_previo)