"""
Orquesta la interacción del usuario con el Motor LLM durante la
generación de texto (inferencia).

Este controlador NO conoce nada de la mecánica interna del Transformer
(atención, embeddings, etc.) — solo sabe que `Transformer.generar()` es
un generador de Python que produce un diccionario por token. Tampoco
conoce nada de QThread directamente: delega toda la ejecución en segundo
plano, pausa, detención y control de velocidad a `GestorConcurrencia`.
"""

from __future__ import annotations

from collections.abc import Generator
from typing import TYPE_CHECKING

import torch
from PySide6.QtCore import QObject, Signal

from .concurrency_manager import GestorConcurrencia

if TYPE_CHECKING:
    from model.motor_llm.tokenizer import Tokenizer
    from model.motor_llm.transformer import Transformer


def _tarea_generacion(
    trabajador,
    modelo: "Transformer",
    tokenizer: "Tokenizer",
    prompt: str,
    id_token_inicio: int,
    id_token_fin: int | None,
    max_tokens_nuevos: int,
    temperatura: float,
    top_k: int | None,
    top_p: float | None,
    muestreo_codicioso: bool,
) -> Generator[dict, None, str]:
    """Envuelve `Transformer.generar()`. No necesita revisar
    `trabajador.debe_detenerse`: `GestorConcurrencia` ya lo hace antes
    de pedir el siguiente valor, así que detener/pausar/velocidad
    funcionan "gratis" para cualquier generador que se le pase."""
    tokens_origen = torch.tensor([tokenizer.encode(prompt)], dtype=torch.long)

    ids_generados: list[int] = []
    for paso in modelo.generar(
        tokens_origen, id_token_inicio=id_token_inicio, id_token_fin=id_token_fin,
        max_tokens_nuevos=max_tokens_nuevos, temperatura=temperatura,
        top_k=top_k, top_p=top_p, muestreo_codicioso=muestreo_codicioso,
    ):
        ids_generados.append(paso["token_id"])
        paso["texto_parcial"] = tokenizer.decode(ids_generados)
        yield paso

    return tokenizer.decode(ids_generados)


class InferenceController(QObject):
    token_generado = Signal(dict)
    generacion_completa = Signal(str)
    generacion_cancelada = Signal(str)
    error = Signal(str)

    def __init__(self, modelo, tokenizer, id_token_inicio, id_token_fin=None, parent=None):
        super().__init__(parent)
        self.modelo = modelo
        self.tokenizer = tokenizer
        self.id_token_inicio = id_token_inicio
        self.id_token_fin = id_token_fin

        self._gestor = GestorConcurrencia(self)
        self._gestor.progreso.connect(self._al_recibir_token)
        self._gestor.finalizado.connect(self._al_completar)
        self._gestor.cancelado.connect(self._al_cancelar)
        self._gestor.error.connect(self.error.emit)

        self._texto_generado_hasta_ahora = ""

    @property
    def esta_generando(self) -> bool:
        return self._gestor.esta_en_ejecucion

    @property
    def esta_pausado(self) -> bool:
        return self._gestor.esta_pausado

    def iniciar_generacion(self, prompt, max_tokens_nuevos=100, temperatura=1.0,
                            top_k=None, top_p=None, muestreo_codicioso=False,
                            velocidad_inicial=0.0):
        self._texto_generado_hasta_ahora = ""
        self._gestor.ejecutar_en_segundo_plano(
            _tarea_generacion, self.modelo, self.tokenizer, prompt,
            self.id_token_inicio, self.id_token_fin, max_tokens_nuevos,
            temperatura, top_k, top_p, muestreo_codicioso,
            velocidad_inicial=velocidad_inicial,
        )

    def detener(self): self._gestor.detener()
    def pausar(self): self._gestor.pausar()
    def reanudar(self): self._gestor.reanudar()
    def establecer_velocidad(self, segundos_por_token): self._gestor.establecer_velocidad(segundos_por_token)

    def _al_recibir_token(self, paso):
        self._texto_generado_hasta_ahora = paso["texto_parcial"]
        self.token_generado.emit(paso)

    def _al_completar(self, texto_final):
        self.generacion_completa.emit(texto_final)

    def _al_cancelar(self):
        self.generacion_cancelada.emit(self._texto_generado_hasta_ahora)