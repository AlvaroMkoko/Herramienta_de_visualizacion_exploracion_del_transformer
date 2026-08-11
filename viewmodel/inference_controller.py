"""
Orquesta la interacción del usuario con el Motor LLM durante la
generación de texto (inferencia).

Mismo patrón que `training_controller.py`:
- `iniciar_generacion` (Python, con `top_k`/`top_p` opcionales de
  verdad, vía `None`) es la API completa.
- `iniciar_generacion_ui` es la versión invocable desde QML — un
  `@Slot` no puede tener un parámetro "int o None", así que usa
  valores centinela (`top_k <= 0` y `top_p >= 1.0` significan
  "desactivado") y por dentro llama a `iniciar_generacion`.
- `esta_generando`/`esta_pausado` (Python, `@property` normal) para
  uso interno; `estaGenerando`/`estaPausado` (`@Property` con
  `notify`) para QML — un `@property` de Python plano NO es visible
  desde QML, así que hacen falta ambas versiones.
"""

from __future__ import annotations

import math
from collections.abc import Generator
from typing import TYPE_CHECKING

import torch
from PySide6.QtCore import Property, QObject, Signal, Slot

from core.constants import (
    MAX_TOKENS_NUEVOS_MAX,
    MAX_TOKENS_NUEVOS_MIN,
    TEMPERATURA_MAX,
    TEMPERATURA_MIN,
    TOP_K_MAX,
    TOP_K_MIN,
    TOP_P_MAX,
    TOP_P_MIN,
)
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
    """No necesita revisar `trabajador.debe_detenerse`: `GestorConcurrencia`
    ya lo hace antes de pedir el siguiente valor, así que
    detener/pausar/velocidad funcionan "gratis" para cualquier
    generador que se le pase."""
    dispositivo = next(modelo.parameters()).device
    tokens_origen = torch.tensor(
        [tokenizer.encode(prompt)], dtype=torch.long, device=dispositivo
    )

    ids_generados: list[int] = []
    for paso in modelo.generar(
        tokens_origen, id_token_inicio=id_token_inicio, id_token_fin=id_token_fin,
        max_tokens_nuevos=max_tokens_nuevos, temperatura=temperatura,
        top_k=top_k, top_p=top_p, muestreo_codicioso=muestreo_codicioso,
    ):
        # El token de fin (EOS) marca la parada, pero no es parte del
        # texto — se excluye del historial decodificado.
        if paso["token_id"] == id_token_fin:
            break
        ids_generados.append(paso["token_id"])
        paso["texto_parcial"] = tokenizer.decode(ids_generados)
        yield paso

    return tokenizer.decode(ids_generados)


class InferenceController(QObject):
    token_generado = Signal(dict)
    generacion_completa = Signal(str)
    generacion_cancelada = Signal(str)
    error = Signal(str)

    estaGenerandoCambio = Signal()
    estaPausadoCambio = Signal()

    def __init__(
        self,
        modelo: "Transformer",
        tokenizer: "Tokenizer",
        id_token_inicio: int,
        id_token_fin: int | None = None,
        parent: QObject | None = None,
    ):
        super().__init__(parent)
        self.modelo = modelo
        self.tokenizer = tokenizer
        self.id_token_inicio = id_token_inicio
        self.id_token_fin = id_token_fin

        self._gestor = GestorConcurrencia(self)
        self._gestor.iniciado.connect(self.estaGenerandoCambio.emit)
        self._gestor.progreso.connect(self._al_recibir_token)
        self._gestor.finalizado.connect(self._al_completar)
        self._gestor.cancelado.connect(self._al_cancelar)
        self._gestor.error.connect(self.error.emit)
        self._gestor.pausado.connect(self.estaPausadoCambio.emit)
        self._gestor.reanudado.connect(self.estaPausadoCambio.emit)

        self._texto_generado_hasta_ahora = ""

    # ------------------------------------------------------------------
    # Estado: version Python (interna) y version QML (reactiva)
    # ------------------------------------------------------------------

    @property
    def esta_generando(self) -> bool:
        """Uso interno desde Python (ej. `MainViewModel`)."""
        return self._gestor.esta_en_ejecucion

    @property
    def esta_pausado(self) -> bool:
        """Uso interno desde Python."""
        return self._gestor.esta_pausado

    @Property(bool, notify=estaGenerandoCambio)
    def estaGenerando(self) -> bool:
        """Versión QML de `esta_generando` — un `@property` de Python
        normal no es visible desde QML."""
        return self.esta_generando

    @Property(bool, notify=estaPausadoCambio)
    def estaPausado(self) -> bool:
        return self.esta_pausado

    # ------------------------------------------------------------------
    # API Python completa (top_k/top_p opcionales de verdad, con None)
    # ------------------------------------------------------------------

    def iniciar_generacion(
        self,
        prompt: str,
        max_tokens_nuevos: int = 100,
        temperatura: float = 1.0,
        top_k: int | None = None,
        top_p: float | None = None,
        muestreo_codicioso: bool = False,
        velocidad_inicial: float = 0.0,
    ) -> None:
        if self.esta_generando:
            return
        try:
            tokens_prompt = self.tokenizer.encode(prompt)
        except (TypeError, ValueError) as exc:
            self.error.emit(f"No se pudo tokenizar el prompt: {exc}")
            return
        contexto = int(self.modelo.config.longitud_maxima_secuencia)
        if not tokens_prompt:
            self.error.emit("El prompt debe contener al menos un token.")
            return
        if len(tokens_prompt) > contexto:
            self.error.emit(
                f"El prompt ocupa {len(tokens_prompt)} tokens y el modelo admite {contexto}."
            )
            return
        maximo_modelo = min(MAX_TOKENS_NUEVOS_MAX, contexto)
        if not isinstance(max_tokens_nuevos, int) or isinstance(max_tokens_nuevos, bool) or not (
            MAX_TOKENS_NUEVOS_MIN <= max_tokens_nuevos <= maximo_modelo
        ):
            self.error.emit(
                f"Los tokens nuevos deben estar entre {MAX_TOKENS_NUEVOS_MIN} y {maximo_modelo}."
            )
            return
        if (
            isinstance(temperatura, bool)
            or not isinstance(temperatura, (int, float))
            or not math.isfinite(float(temperatura))
            or not TEMPERATURA_MIN <= float(temperatura) <= TEMPERATURA_MAX
        ):
            self.error.emit(
                f"La temperatura debe estar entre {TEMPERATURA_MIN} y {TEMPERATURA_MAX}."
            )
            return
        if top_k is not None and (
            not isinstance(top_k, int)
            or isinstance(top_k, bool)
            or not TOP_K_MIN <= top_k <= TOP_K_MAX
        ):
            self.error.emit(f"Top-K debe estar entre {TOP_K_MIN} y {TOP_K_MAX}.")
            return
        if top_p is not None and (
            isinstance(top_p, bool)
            or not isinstance(top_p, (int, float))
            or not math.isfinite(float(top_p))
            or not TOP_P_MIN < float(top_p) <= TOP_P_MAX
        ):
            self.error.emit("Top-P debe estar en el intervalo (0, 1].")
            return
        self._texto_generado_hasta_ahora = ""
        self._gestor.ejecutar_en_segundo_plano(
            _tarea_generacion, self.modelo, self.tokenizer, prompt,
            self.id_token_inicio, self.id_token_fin, max_tokens_nuevos,
            temperatura, top_k, top_p, muestreo_codicioso,
            velocidad_inicial=velocidad_inicial,
        )

    # ------------------------------------------------------------------
    # API QML
    # ------------------------------------------------------------------

    @Slot(str, int, float, int, float, bool)
    @Slot(str, int, float, int, float, bool, float)
    def iniciar_generacion_ui(
        self,
        prompt: str,
        max_tokens_nuevos: int,
        temperatura: float,
        top_k: int,
        top_p: float,
        muestreo_codicioso: bool,
        velocidad_inicial: float = 0.0,
    ) -> None:
        """Versión invocable desde QML. `@Slot` no admite un parámetro
        "int o None", así que se usan valores centinela:
        - `top_k <= 0` -> desactivado (equivale a `top_k=None`).
        - `top_p >= 1.0` -> desactivado (equivale a `top_p=None`).
        """
        top_k_real = top_k if top_k > 0 else None
        top_p_real = top_p if top_p < 1.0 else None
        self.iniciar_generacion(
            prompt,
            max_tokens_nuevos=max_tokens_nuevos,
            temperatura=temperatura,
            top_k=top_k_real,
            top_p=top_p_real,
            muestreo_codicioso=muestreo_codicioso,
            velocidad_inicial=velocidad_inicial
        )

    @Slot()
    def detener(self) -> None:
        self._gestor.detener()

    @Slot()
    def pausar(self) -> None:
        self._gestor.pausar()

    @Slot()
    def reanudar(self) -> None:
        self._gestor.reanudar()

    @Slot(float)
    def establecer_velocidad(self, segundos_por_token: float) -> None:
        self._gestor.establecer_velocidad(segundos_por_token)

    def cerrar(self) -> None:
        """Detiene la generacion y libera el modelo de la sesion retirada."""
        self._gestor.cerrar()
        self.modelo = None
        self.tokenizer = None

    # ------------------------------------------------------------------
    # Manejadores internos
    # ------------------------------------------------------------------

    def _al_recibir_token(self, paso: dict) -> None:
        self._texto_generado_hasta_ahora = paso["texto_parcial"]
        self.token_generado.emit(paso)

    def _al_completar(self, texto_final: str) -> None:
        self.estaGenerandoCambio.emit()
        self.generacion_completa.emit(texto_final)

    def _al_cancelar(self) -> None:
        self.estaGenerandoCambio.emit()
        self.generacion_cancelada.emit(self._texto_generado_hasta_ahora)
