"""
Orquesta el entrenamiento del Transformer, reutilizando el mismo patrón
de `inference_controller.py`: una función-generador que hace todo el
trabajo pesado (ejecutada dentro de `GestorConcurrencia`), y un
`QObject` liviano que traduce eso a señales para la Vista.

Este controlador NO sabe cómo se arman los batches — recibe un
`proveedor_batches` (una función sin argumentos que retorna un iterable
nuevo de tuplas `(tokens_origen, tokens_destino, objetivo)` cada vez que
se la llama, para poder recorrer el dataset de nuevo en cada época). Esa
función normalmente va a venir de `gestor_de_datos/`, pero
`training_controller.py` no depende de esa carpeta directamente — solo
del contrato: "una función que, llamada, da batches".
"""

from __future__ import annotations

from collections.abc import Callable, Generator, Iterable
from typing import TYPE_CHECKING

import torch
from PySide6.QtCore import QObject, Signal

from .concurrency_manager import GestorConcurrencia

if TYPE_CHECKING:
    from model.motor_llm.transformer import Transformer

Batch = tuple[torch.Tensor, torch.Tensor, torch.Tensor]


def _norma_gradiente_global(modelo: "Transformer") -> float:
    """Norma L2 global de los gradientes de todo el modelo (después de
    `backward()`). Métrica estándar para detectar gradientes que
    explotan o desaparecen durante el entrenamiento."""
    total = 0.0
    for p in modelo.parameters():
        if p.grad is not None:
            total += p.grad.detach().norm(2).item() ** 2
    return total**0.5


def _tarea_entrenamiento(
    trabajador,
    modelo: "Transformer",
    proveedor_batches: Callable[[], Iterable[Batch]],
    num_epocas: int,
    tasa_aprendizaje: float,
) -> Generator[dict, None, dict]:
    """Bucle de entrenamiento completo: por cada batch, hace
    forward -> pérdida -> backward -> paso de optimización, y reporta un
    `yield` por batch. No revisa `trabajador.debe_detenerse`:
    `GestorConcurrencia` ya lo hace antes de pedir el siguiente batch.

    Nota: se crea un optimizador Adam NUEVO en cada llamada (cada
    `iniciar_entrenamiento()`). Si el usuario detiene y vuelve a iniciar,
    el estado del optimizador no se conserva entre esas dos corridas —
    solo mientras la MISMA ejecución está pausada/reanudada.
    """
    optimizador = torch.optim.Adam(modelo.parameters(), lr=tasa_aprendizaje)
    modelo.train()

    historial_perdidas: list[float] = []
    paso_global = 0

    for epoca in range(num_epocas):
        for paso_epoca, (tokens_origen, tokens_destino, objetivo) in enumerate(proveedor_batches()):
            optimizador.zero_grad()

            logits = modelo(tokens_origen, tokens_destino)
            perdida = modelo.calcular_perdida(logits, objetivo)
            perdida.backward()

            norma_gradiente = _norma_gradiente_global(modelo)
            optimizador.step()

            paso_global += 1
            perdida_valor = perdida.item()
            historial_perdidas.append(perdida_valor)

            yield {
                "epoca": epoca,
                "paso_epoca": paso_epoca,
                "paso_global": paso_global,
                "perdida": perdida_valor,
                "norma_gradiente_global": norma_gradiente,
                "pesos_atencion_encoder_por_capa": modelo.encoder.pesos_atencion_por_capa(),
                "pesos_atencion_cruzada_por_capa": modelo.decoder.pesos_atencion_cruzada_por_capa(),
            }

    return {
        "historial_perdidas": historial_perdidas,
        "perdida_final": historial_perdidas[-1] if historial_perdidas else None,
    }


class TrainingController(QObject):
    """Controlador de entrenamiento: `iniciar_entrenamiento`, `detener`,
    `pausar`, `reanudar`, `establecer_velocidad` — mismo vocabulario que
    `InferenceController`."""

    paso_entrenamiento = Signal(dict)
    entrenamiento_completo = Signal(dict)
    entrenamiento_cancelado = Signal(dict)
    error = Signal(str)

    def __init__(self, modelo: "Transformer", parent: QObject | None = None):
        super().__init__(parent)
        self.modelo = modelo

        self._gestor = GestorConcurrencia(self)
        self._gestor.progreso.connect(self._al_recibir_paso)
        self._gestor.finalizado.connect(self._al_completar)
        self._gestor.cancelado.connect(self._al_cancelar)
        self._gestor.error.connect(self.error.emit)

        self._historial_perdidas: list[float] = []

    @property
    def esta_entrenando(self) -> bool:
        return self._gestor.esta_en_ejecucion

    @property
    def esta_pausado(self) -> bool:
        return self._gestor.esta_pausado

    def iniciar_entrenamiento(
        self, proveedor_batches, num_epocas: int = 1,
        tasa_aprendizaje: float = 3e-4, velocidad_inicial: float = 0.0,
    ) -> None:
        self._historial_perdidas = []
        self._gestor.ejecutar_en_segundo_plano(
            _tarea_entrenamiento, self.modelo, proveedor_batches,
            num_epocas, tasa_aprendizaje, velocidad_inicial=velocidad_inicial,
        )

    def detener(self) -> None: self._gestor.detener()
    def pausar(self) -> None: self._gestor.pausar()
    def reanudar(self) -> None: self._gestor.reanudar()
    def establecer_velocidad(self, segundos_por_paso: float) -> None:
        self._gestor.establecer_velocidad(segundos_por_paso)

    def _al_recibir_paso(self, paso: dict) -> None:
        self._historial_perdidas.append(paso["perdida"])
        self.paso_entrenamiento.emit(paso)

    def _al_completar(self, resultado: dict) -> None:
        self.entrenamiento_completo.emit(resultado)

    def _al_cancelar(self) -> None:
        self.entrenamiento_cancelado.emit({"historial_perdidas": list(self._historial_perdidas)})