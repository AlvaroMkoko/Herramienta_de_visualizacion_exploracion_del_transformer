"""
Orquesta el entrenamiento del Transformer.

`batch_size` se trata EXACTAMENTE igual que `tasa_aprendizaje`: es un
parámetro de la llamada a `iniciar_entrenamiento`, elegido por el
usuario en la Vista y pasado sin persistirse en ningún lado — nunca
forma parte de `ConfiguracionTransformer` ni de ningún estado guardado
del modelo, porque no describe la arquitectura de la red, solo cómo se
quiere correr ESTA sesión de entrenamiento.

Por eso este controlador recibe el `Dataset` (los ejemplos ya
tokenizados, de `gestor_de_datos/dataset_loader.py`) en vez de un
`DataLoader` ya armado con un `batch_size` fijo de antemano — así el
`DataLoader` se construye AQUÍ, adentro del ViewModel, en el momento en
que se conoce el `batch_size` elegido por el usuario.
"""

from __future__ import annotations

from collections.abc import Generator
from typing import TYPE_CHECKING

import torch
from PySide6.QtCore import Property, QObject, Signal, Slot

from .concurrency_manager import GestorConcurrencia

if TYPE_CHECKING:
    from torch.utils.data import Dataset

    from model.motor_llm.transformer import Transformer


def _norma_gradiente_global(modelo: "Transformer") -> float:
    total = 0.0
    for p in modelo.parameters():
        if p.grad is not None:
            total += p.grad.detach().norm(2).item() ** 2
    return total**0.5


def _tarea_entrenamiento(
    trabajador,
    modelo: "Transformer",
    dataset: "Dataset",
    id_token_relleno: int,
    num_epocas: int,
    tasa_aprendizaje: float,
    batch_size: int,
) -> Generator[dict, None, dict]:
    """`dataset`, `id_token_relleno` y `batch_size` se combinan AQUÍ para
    armar el `DataLoader` — es el único lugar donde `batch_size` se
    "materializa" en algo concreto (el tamaño real de cada batch).

    Se re-arma el `DataLoader` en CADA época porque usa `shuffle=True`:
    cada época debe ver los ejemplos en un orden distinto.
    """
    from model.gestor_de_datos.dataset_loader import crear_dataloader

    optimizador = torch.optim.Adam(modelo.parameters(), lr=tasa_aprendizaje)
    modelo.train()

    historial_perdidas: list[float] = []
    paso_global = 0

    for epoca in range(num_epocas):
        dataloader = crear_dataloader(dataset, id_token_relleno, batch_size=batch_size, shuffle=True)

        for paso_epoca, (tokens_origen, tokens_destino, objetivo) in enumerate(dataloader):
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
    """`iniciar_entrenamiento` recibe TODOS los parámetros que el
    usuario puede elegir en la Vista — incluido `batch_size` — y arma
    el `DataLoader` internamente, en el momento justo de entrenar."""

    paso_entrenamiento = Signal(dict)
    checkpoint_guardado = Signal(str)
    entrenamiento_completo = Signal(dict)
    entrenamiento_cancelado = Signal(dict)
    error = Signal(str)

    estaEntrenandoCambio = Signal()
    estaPausadoCambio = Signal()

    def __init__(self, modelo: "Transformer", parent: QObject | None = None):
        super().__init__(parent)
        self.modelo = modelo

        self._gestor = GestorConcurrencia(self)
        self._gestor.progreso.connect(self._al_recibir_paso)
        self._gestor.finalizado.connect(self._al_completar)
        self._gestor.cancelado.connect(self._al_cancelar)
        self._gestor.error.connect(self.error.emit)
        self._dataset: "Dataset | None" = None
        self._id_token_relleno_dataset: int | None = None
        self._ultima_epoca: int | None = None
        self._ultimo_paso_global: int | None = None
        self._gestor.iniciado.connect(self.estaEntrenandoCambio.emit)
        self._gestor.pausado.connect(self.estaPausadoCambio.emit)
        self._gestor.reanudado.connect(self.estaPausadoCambio.emit)

        self._historial_perdidas: list[float] = []

    @property
    def esta_entrenando(self) -> bool:
        """Uso interno desde Python (ej. `MainViewModel`)."""
        return self._gestor.esta_en_ejecucion

    @property
    def esta_pausado(self) -> bool:
        """Uso interno desde Python."""
        return self._gestor.esta_pausado

    @Property(bool, notify=estaEntrenandoCambio)
    def estaEntrenando(self) -> bool:
        """Versión QML de `esta_entrenando` — un `@property` de Python
        normal NO es visible desde QML. Hace falta esta `@Property` con
        `notify` para que los botones se actualicen solos."""
        return self.esta_entrenando

    @Property(bool, notify=estaPausadoCambio)
    def estaPausado(self) -> bool:
        return self.esta_pausado

    def iniciar_entrenamiento(
        self,
        dataset: "Dataset",
        id_token_relleno: int,
        num_epocas: int = 1,
        tasa_aprendizaje: float = 3e-4,
        batch_size: int = 32,
        velocidad_inicial: float = 0.0,
    ) -> None:
        """
        Args:
            dataset: `DatasetSecuencias` con los ejemplos ya tokenizados.
            id_token_relleno: `ConfiguracionTransformer.id_token_relleno` del modelo.
            num_epocas, tasa_aprendizaje, batch_size: elegidos por el
                usuario en la Vista — ninguno se guarda como parte del modelo.
        """
        self._historial_perdidas = []
        self._gestor.ejecutar_en_segundo_plano(
            _tarea_entrenamiento, self.modelo, dataset, id_token_relleno,
            num_epocas, tasa_aprendizaje, batch_size,
            velocidad_inicial=velocidad_inicial,
        )

    @Slot(int, float, int)
    def iniciar_entrenamiento_ui(self, num_epocas: int, tasa_aprendizaje: float, batch_size: int) -> None:
        """Esta es la que SÍ puede llamar un botón de QML: usa el
        dataset que ya haya sido fijado con `establecer_dataset(...)`
        (llamado desde Python, no desde QML). Si todavía no hay
        ninguno, emite `error` con un mensaje claro en vez de fallar."""
        if self._dataset is None:
            self.error.emit(
                'No hay un dataset cargado todavía. Andá a "Gestionar DataSet" primero.'
            )
            return
        self.iniciar_entrenamiento(
            self._dataset, self._id_token_relleno_dataset,
            num_epocas=num_epocas, tasa_aprendizaje=tasa_aprendizaje, batch_size=batch_size,
        )

    def establecer_dataset(self, dataset: "Dataset", id_token_relleno: int) -> None:
        """Python-only, nunca se llama desde QML (mismo motivo: `Dataset`
        no es un tipo que QML pueda construir ni pasar)."""
        self._dataset = dataset
        self._id_token_relleno_dataset = id_token_relleno

    @Slot()
    def detener(self) -> None: self._gestor.detener()
    @Slot()
    def pausar(self) -> None: self._gestor.pausar()
    @Slot()
    def reanudar(self) -> None: self._gestor.reanudar()
    @Slot()
    def establecer_velocidad(self, s: float) -> None: self._gestor.establecer_velocidad(s)

    @Slot(str)
    def guardar_checkpoint(self, ruta: str) -> None:
        """Guarda un checkpoint del modelo en su estado ACTUAL (no hace
        falta que el entrenamiento haya terminado). Emite
        `checkpoint_guardado(ruta)` si sale bien, o `error(mensaje)` si falla."""
        from model.persistencia.model_storage import guardar_checkpoint

        try:
            guardar_checkpoint(
                ruta, self.modelo,
                epoca=self._ultima_epoca, paso_global=self._ultimo_paso_global,
                historial_perdidas=list(self._historial_perdidas),
            )
        except OSError as e:
            self.error.emit(f"No se pudo guardar el checkpoint: {e}")
            return

        self.checkpoint_guardado.emit(ruta)

    def _al_recibir_paso(self, paso: dict) -> None:
        self._historial_perdidas.append(paso["perdida"])
        self._ultima_epoca = paso["epoca"]
        self._ultimo_paso_global = paso["paso_global"]
        self.paso_entrenamiento.emit(paso)

    def _al_completar(self, resultado: dict) -> None:
        self.estaEntrenandoCambio.emit()
        self.entrenamiento_completo.emit(resultado)

    def _al_cancelar(self) -> None:
        self.estaEntrenandoCambio.emit()
        self.entrenamiento_cancelado.emit({"historial_perdidas": list(self._historial_perdidas)})