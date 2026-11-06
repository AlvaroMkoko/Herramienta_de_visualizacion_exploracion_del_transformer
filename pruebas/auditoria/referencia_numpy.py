"""Implementación de referencia del Transformer en NumPy puro (float64).

Sirve de oráculo independiente para el motor de PyTorch (RNF07): no importa
nada de ``model/motor_llm`` y reescribe cada operación desde las fórmulas de
Vaswani et al. (2017). Solo recibe los pesos ya entrenados, como arreglos.

Fórmulas que reproduce, en el mismo orden que el motor (post-norm):
    E·√d_model + PE                    embedding escalado más posición
    softmax(QKᵀ/√d_k + M)·V            atención escalada por cabeza
    Concat(cabezas)·W_O                multi-head
    LayerNorm(x + Subcapa(x))          Add & Norm (ε = 1e-5, varianza sesgada)
    W₂·f(W₁x + b₁) + b₂                feed-forward, f ∈ {ReLU, GELU, SiLU}
    x·W_salidaᵀ + b                    logits
"""

from __future__ import annotations

import math
from collections.abc import Mapping

import numpy as np

_erf = np.vectorize(math.erf)

ACTIVACIONES = {
    "relu": lambda x: np.maximum(x, 0.0),
    # GELU exacta (la de nn.GELU por omisión), no la aproximación tanh.
    "gelu": lambda x: 0.5 * x * (1.0 + _erf(x / math.sqrt(2.0))),
    "swish": lambda x: x / (1.0 + np.exp(-x)),
}


def codificacion_posicional(longitud: int, d_model: int) -> np.ndarray:
    pe = np.zeros((longitud, d_model))
    for pos in range(longitud):
        for i in range(0, d_model, 2):
            angulo = pos / (10000.0 ** (i / d_model))
            pe[pos, i] = math.sin(angulo)
            if i + 1 < d_model:
                pe[pos, i + 1] = math.cos(angulo)
    return pe


def softmax(x: np.ndarray) -> np.ndarray:
    maximo = np.max(x, axis=-1, keepdims=True)
    maximo = np.where(np.isfinite(maximo), maximo, 0.0)
    e = np.exp(x - maximo)
    return e / np.sum(e, axis=-1, keepdims=True)


def capa_norma(x: np.ndarray, gamma: np.ndarray, beta: np.ndarray, eps: float = 1e-5) -> np.ndarray:
    media = x.mean(axis=-1, keepdims=True)
    varianza = ((x - media) ** 2).mean(axis=-1, keepdims=True)
    return (x - media) / np.sqrt(varianza + eps) * gamma + beta


class ReferenciaTransformer:
    """Forward de inferencia (sin dropout) a partir de un ``state_dict``."""

    def __init__(
        self,
        pesos: Mapping[str, np.ndarray],
        *,
        num_cabezas: int,
        num_capas: int,
        activacion: str,
        id_relleno: int | None,
        mascara_causal: bool = True,
    ) -> None:
        self.p = {nombre: np.asarray(valor, dtype=np.float64) for nombre, valor in pesos.items()}
        self.h = num_cabezas
        self.n = num_capas
        self.f = ACTIVACIONES[activacion]
        self.relleno = id_relleno
        self.causal = mascara_causal
        self.d = self.p["embedding_entrada.embedding.weight"].shape[1]
        # Pesos de atención de la última llamada, por capa: para comparar los
        # mapas que muestra la herramienta, no solo los logits.
        self.pesos_atencion: dict[str, list[np.ndarray]] = {}

    def _lineal(self, x: np.ndarray, prefijo: str) -> np.ndarray:
        y = x @ self.p[f"{prefijo}.weight"].T
        sesgo = self.p.get(f"{prefijo}.bias")
        return y if sesgo is None else y + sesgo

    def _atencion(self, x: np.ndarray, kv: np.ndarray, permitido: np.ndarray, prefijo: str) -> tuple[np.ndarray, np.ndarray]:
        t_q, t_k = x.shape[0], kv.shape[0]
        d_k = self.d // self.h
        q = self._lineal(x, f"{prefijo}.proyeccion_q").reshape(t_q, self.h, d_k).transpose(1, 0, 2)
        k = self._lineal(kv, f"{prefijo}.proyeccion_k").reshape(t_k, self.h, d_k).transpose(1, 0, 2)
        v = self._lineal(kv, f"{prefijo}.proyeccion_v").reshape(t_k, self.h, d_k).transpose(1, 0, 2)
        scores = q @ k.transpose(0, 2, 1) / math.sqrt(d_k)
        scores = np.where(permitido[None, :, :], scores, -np.inf)
        pesos = softmax(scores)
        cabezas = pesos @ v
        concatenado = cabezas.transpose(1, 0, 2).reshape(t_q, self.d)
        return self._lineal(concatenado, f"{prefijo}.proyeccion_salida"), pesos

    def _add_norm(self, x: np.ndarray, actualizacion: np.ndarray, prefijo: str) -> np.ndarray:
        return capa_norma(x + actualizacion, self.p[f"{prefijo}.norma.weight"], self.p[f"{prefijo}.norma.bias"])

    def _ffn(self, x: np.ndarray, prefijo: str) -> np.ndarray:
        oculta = self.f(self._lineal(x, f"{prefijo}.capa_expansion"))
        return self._lineal(oculta, f"{prefijo}.capa_proyeccion")

    def _entrada(self, ids: list[int], tabla: str) -> np.ndarray:
        embedding = self.p[f"{tabla}.embedding.weight"][ids]
        return embedding * math.sqrt(self.d) + codificacion_posicional(len(ids), self.d)

    def logits(self, origen: list[int], destino: list[int]) -> np.ndarray:
        """Logits (T_destino × vocabulario) de un solo ejemplo."""
        t_s, t_t = len(origen), len(destino)
        real_origen = np.array([self.relleno is None or i != self.relleno for i in origen])
        real_destino = np.array([self.relleno is None or i != self.relleno for i in destino])
        self.pesos_atencion = {"encoder": [], "autoatencion": [], "cruzada": []}

        x = self._entrada(origen, "embedding_entrada")
        permitido_enc = np.broadcast_to(real_origen[None, :], (t_s, t_s))
        for capa in range(self.n):
            base = f"encoder.bloques.{capa}"
            a, w = self._atencion(x, x, permitido_enc, f"{base}.atencion")
            self.pesos_atencion["encoder"].append(w)
            x = self._add_norm(x, a, f"{base}.conexion_atencion")
            x = self._add_norm(x, self._ffn(x, f"{base}.feed_forward"), f"{base}.conexion_feed_forward")
        memoria = x

        y = self._entrada(destino, "embedding_salida")
        permitido_dec = np.broadcast_to(real_destino[None, :], (t_t, t_t))
        if self.causal:
            permitido_dec = permitido_dec & np.tril(np.ones((t_t, t_t), dtype=bool))
        permitido_cruz = np.broadcast_to(real_origen[None, :], (t_t, t_s))
        for capa in range(self.n):
            base = f"decoder.bloques.{capa}"
            a, w = self._atencion(y, y, permitido_dec, f"{base}.autoatencion")
            self.pesos_atencion["autoatencion"].append(w)
            y = self._add_norm(y, a, f"{base}.conexion_autoatencion")
            a, w = self._atencion(y, memoria, permitido_cruz, f"{base}.atencion_cruzada")
            self.pesos_atencion["cruzada"].append(w)
            y = self._add_norm(y, a, f"{base}.conexion_atencion_cruzada")
            y = self._add_norm(y, self._ffn(y, f"{base}.feed_forward"), f"{base}.conexion_feed_forward")
        return self._lineal(y, "capa_salida")
