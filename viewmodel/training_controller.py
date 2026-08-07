"""Orquestacion del entrenamiento y de sus snapshots persistentes."""

from __future__ import annotations

import threading
from collections.abc import Generator
from typing import TYPE_CHECKING, Any

import torch
from PySide6.QtCore import Property, QObject, Signal, Slot

from core.config import DIR_CHECKPOINTS
from .concurrency_manager import GestorConcurrencia

if TYPE_CHECKING:
    from torch.utils.data import Dataset

    from model.motor_llm.tokenizer import Tokenizer
    from model.motor_llm.transformer import Transformer


def _norma_gradiente_global(modelo: "Transformer") -> float:
    total = 0.0
    for parametro in modelo.parameters():
        if parametro.grad is not None:
            total += parametro.grad.detach().norm(2).item() ** 2
    return total**0.5


def _crear_batches(dataset, id_token_relleno: int | None, batch_size: int):
    """Acepta tanto Dataset reales como proveedores usados por las pruebas."""
    if callable(dataset):
        return dataset()

    if id_token_relleno is None:
        raise ValueError("El dataset requiere un id_token_relleno para formar batches.")

    from model.gestor_de_datos.dataset_loader import crear_dataloader

    return crear_dataloader(
        dataset,
        id_token_relleno,
        batch_size=batch_size,
        shuffle=True,
    )


def _tarea_entrenamiento(
    trabajador,
    modelo: "Transformer",
    dataset,
    id_token_relleno: int | None,
    num_epocas: int,
    batch_size: int,
    optimizador: torch.optim.Optimizer,
    estado: dict[str, Any],
    bloqueo_estado: threading.RLock,
) -> Generator[dict, None, dict]:
    """Entrena en segundo plano y actualiza un estado snapshotable.

    El bloqueo cubre cada actualizacion completa de pesos y la captura del
    progreso correspondiente. Un guardado adquiere el mismo bloqueo, por lo
    que nunca serializa tensores a mitad de ``optimizer.step()``.
    """
    modelo.train()
    dispositivo = next(modelo.parameters()).device
    epoca_inicial = int(estado.get("siguiente_epoca", 0))
    paso_global = int(estado.get("paso_global", 0))
    historial = estado.setdefault("historial_perdidas", [])

    for epoca in range(epoca_inicial, epoca_inicial + num_epocas):
        with bloqueo_estado:
            # Si se cancela a mitad de la epoca, la continuacion repite esa
            # epoca. Sin conservar el orden completo del sampler no seria
            # correcto afirmar que puede retomarse en el batch exacto.
            estado["siguiente_epoca"] = epoca
        batches = _crear_batches(dataset, id_token_relleno, batch_size)

        for paso_epoca, (tokens_origen, tokens_destino, objetivo) in enumerate(batches):
            tokens_origen = tokens_origen.to(dispositivo)
            tokens_destino = tokens_destino.to(dispositivo)
            objetivo = objetivo.to(dispositivo)

            with bloqueo_estado:
                optimizador.zero_grad()
                logits = modelo(tokens_origen, tokens_destino)
                perdida = modelo.calcular_perdida(logits, objetivo)
                perdida.backward()
                norma_gradiente = _norma_gradiente_global(modelo)
                optimizador.step()

                paso_global += 1
                perdida_valor = float(perdida.item())
                historial.append(perdida_valor)
                estado.update(
                    {
                        "epoca": epoca,
                        "paso_epoca": paso_epoca,
                        "paso_global": paso_global,
                    }
                )

                paso = {
                    "epoca": epoca,
                    "paso_epoca": paso_epoca,
                    "paso_global": paso_global,
                    "perdida": perdida_valor,
                    "norma_gradiente_global": norma_gradiente,
                    "pesos_atencion_encoder_por_capa": modelo.encoder.pesos_atencion_por_capa(),
                    "pesos_atencion_cruzada_por_capa": modelo.decoder.pesos_atencion_cruzada_por_capa(),
                }

            yield paso

        with bloqueo_estado:
            estado["siguiente_epoca"] = epoca + 1

    return {
        "historial_perdidas": list(historial),
        "perdida_final": historial[-1] if historial else None,
        "epoca": estado.get("epoca"),
        "paso_global": paso_global,
    }


class TrainingController(QObject):
    paso_entrenamiento = Signal(dict)
    checkpoint_guardado = Signal(str)
    entrenamiento_completo = Signal(dict)
    entrenamiento_cancelado = Signal(dict)
    error = Signal(str)

    estaEntrenandoCambio = Signal()
    estaPausadoCambio = Signal()
    guardandoCambio = Signal()

    def __init__(
        self,
        modelo: "Transformer",
        tokenizer: "Tokenizer | None" = None,
        resultado_carga=None,
        parent: QObject | None = None,
    ):
        super().__init__(parent)
        self.modelo = modelo
        self.tokenizer = tokenizer

        self._gestor = GestorConcurrencia(self)
        self._gestor.progreso.connect(self._al_recibir_paso)
        self._gestor.finalizado.connect(self._al_completar)
        self._gestor.cancelado.connect(self._al_cancelar)
        self._gestor.error.connect(self._al_error)
        self._gestor.iniciado.connect(self.estaEntrenandoCambio.emit)
        self._gestor.pausado.connect(self.estaPausadoCambio.emit)
        self._gestor.reanudado.connect(self.estaPausadoCambio.emit)

        self._dataset: "Dataset | None" = None
        self._id_token_relleno_dataset: int | None = None
        self._origen_datasets: list[dict] = []
        self._bloqueo_estado = threading.RLock()
        self._optimizador: torch.optim.Optimizer | None = None
        self._optimizer_state_pendiente = getattr(
            resultado_carga, "optimizer_state_dict", None
        )
        self._guardando = False
        self._hilo_guardado: threading.Thread | None = None

        historial = list(
            getattr(resultado_carga, "historial_perdidas", []) or []
        )
        ultima_epoca = getattr(resultado_carga, "epoca", None)
        siguiente_epoca = getattr(resultado_carga, "siguiente_epoca", None)
        paso_epoca = getattr(resultado_carga, "paso_epoca", None)
        ultimo_paso = getattr(resultado_carga, "paso_global", None)
        if siguiente_epoca is None:
            siguiente_epoca = (
                int(ultima_epoca) + 1 if ultima_epoca is not None else 0
            )
        self._estado_entrenamiento: dict[str, Any] = {
            "epoca": ultima_epoca,
            "paso_epoca": paso_epoca,
            "paso_global": int(ultimo_paso or 0),
            "siguiente_epoca": int(siguiente_epoca),
            "historial_perdidas": historial,
        }
        self._ultima_epoca = ultima_epoca
        self._ultimo_paso_global = int(ultimo_paso or 0)
        self._historial_perdidas = historial
        self._hiperparametros_entrenamiento = dict(
            getattr(resultado_carga, "hiperparametros_entrenamiento", {}) or {}
        )

    # ------------------------------------------------------------------
    # Estado observable
    # ------------------------------------------------------------------

    @property
    def esta_entrenando(self) -> bool:
        return self._gestor.esta_en_ejecucion

    @property
    def esta_pausado(self) -> bool:
        return self._gestor.esta_pausado

    @Property(bool, notify=estaEntrenandoCambio)
    def estaEntrenando(self) -> bool:
        return self.esta_entrenando

    @Property(bool, notify=estaPausadoCambio)
    def estaPausado(self) -> bool:
        return self.esta_pausado

    @Property(bool, notify=guardandoCambio)
    def guardando(self) -> bool:
        return self._guardando

    # ------------------------------------------------------------------
    # Entrenamiento
    # ------------------------------------------------------------------

    def iniciar_entrenamiento(
        self,
        dataset,
        id_token_relleno: int | None = None,
        num_epocas: int = 1,
        tasa_aprendizaje: float = 3e-4,
        batch_size: int = 32,
        velocidad_inicial: float = 0.0,
    ) -> None:
        if num_epocas <= 0 or batch_size <= 0 or tasa_aprendizaje <= 0:
            self.error.emit("Epocas, batch size y learning rate deben ser mayores que cero.")
            return

        if self._optimizador is None:
            self._optimizador = torch.optim.Adam(
                self.modelo.parameters(), lr=tasa_aprendizaje
            )
            if self._optimizer_state_pendiente is not None:
                try:
                    self._optimizador.load_state_dict(self._optimizer_state_pendiente)
                except (ValueError, RuntimeError) as exc:
                    self.error.emit(
                        f"No se pudo restaurar el optimizador; se usara uno nuevo: {exc}"
                    )
                    self._optimizador = torch.optim.Adam(
                        self.modelo.parameters(), lr=tasa_aprendizaje
                    )
                finally:
                    self._optimizer_state_pendiente = None

        # La seleccion actual de la UI controla el learning rate, incluso al
        # continuar un checkpoint con los momentos de Adam restaurados.
        for grupo in self._optimizador.param_groups:
            grupo["lr"] = tasa_aprendizaje

        self._hiperparametros_entrenamiento = {
            "num_epocas_solicitadas": num_epocas,
            "tasa_aprendizaje": tasa_aprendizaje,
            "batch_size": batch_size,
            "datasets": list(self._origen_datasets),
        }
        self._gestor.ejecutar_en_segundo_plano(
            _tarea_entrenamiento,
            self.modelo,
            dataset,
            id_token_relleno,
            num_epocas,
            batch_size,
            self._optimizador,
            self._estado_entrenamiento,
            self._bloqueo_estado,
            velocidad_inicial=velocidad_inicial,
        )

    @Slot(int, float, int)
    def iniciar_entrenamiento_ui(
        self, num_epocas: int, tasa_aprendizaje: float, batch_size: int
    ) -> None:
        if self._dataset is None:
            self.error.emit(
                'No hay un dataset cargado. Usa "Gestionar DataSet" primero.'
            )
            return
        self.iniciar_entrenamiento(
            self._dataset,
            self._id_token_relleno_dataset,
            num_epocas=num_epocas,
            tasa_aprendizaje=tasa_aprendizaje,
            batch_size=batch_size,
        )

    def establecer_dataset(self, dataset: "Dataset", id_token_relleno: int) -> None:
        self._dataset = dataset
        self._id_token_relleno_dataset = id_token_relleno

    def establecer_origen_datasets(self, datasets: list[dict]) -> None:
        """Guarda solo metadatos no sensibles, nunca rutas absolutas."""
        self._origen_datasets = [dict(item) for item in datasets]

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
    def establecer_velocidad(self, segundos: float) -> None:
        self._gestor.establecer_velocidad(segundos)

    def cerrar(self) -> None:
        """Detiene workers y suelta referencias grandes al retirar la sesion."""
        self._gestor.cerrar()
        hilo_guardado = self._hilo_guardado
        if (
            hilo_guardado is not None
            and hilo_guardado is not threading.current_thread()
            and hilo_guardado.is_alive()
        ):
            hilo_guardado.join()
        self._hilo_guardado = None
        self._dataset = None
        self._optimizador = None
        self._optimizer_state_pendiente = None
        self.modelo = None
        self.tokenizer = None

    # ------------------------------------------------------------------
    # Persistencia legacy y portable
    # ------------------------------------------------------------------

    @Slot(str)
    def guardar_checkpoint(self, ruta: str) -> None:
        """Compatibilidad con el checkpoint .pt usado por la CLI."""
        from model.persistencia.model_storage import guardar_checkpoint

        try:
            with self._bloqueo_estado:
                guardar_checkpoint(
                    ruta,
                    self.modelo,
                    optimizador=self._optimizador,
                    epoca=self._estado_entrenamiento.get("epoca"),
                    paso_global=self._estado_entrenamiento.get("paso_global"),
                    historial_perdidas=list(
                        self._estado_entrenamiento.get("historial_perdidas", [])
                    ),
                    metadata_extra={
                        "tipo_encoding": getattr(self.tokenizer, "tipo_encoding", None),
                        "hiperparametros_entrenamiento": self._hiperparametros_entrenamiento,
                    },
                )
        except Exception as exc:  # se presenta al usuario en QML
            self.error.emit(f"No se pudo guardar el checkpoint: {exc}")
            return
        self.checkpoint_guardado.emit(ruta)

    @Slot(result=str)
    def sugerirNombreCheckpoint(self) -> str:
        from model.persistencia.model_storage import generar_nombre_modelo

        return generar_nombre_modelo(
            self.modelo, paso_global=self._estado_entrenamiento.get("paso_global")
        )

    def _ruta_sin_sobrescribir(self, nombre: str):
        from model.persistencia.model_storage import sanitizar_nombre_modelo

        ruta = DIR_CHECKPOINTS / sanitizar_nombre_modelo(nombre)
        if not ruta.exists():
            return ruta
        contador = 2
        while True:
            candidata = ruta.with_name(f"{ruta.stem}_{contador}{ruta.suffix}")
            if not candidata.exists():
                return candidata
            contador += 1

    def _guardar_modelo_portable(self, nombre: str, reanudable: bool) -> None:
        if self.tokenizer is None:
            self.error.emit("No se puede guardar sin conocer el tokenizador del modelo.")
            return
        if self._guardando:
            self.error.emit("Ya hay un guardado en curso.")
            return

        from model.persistencia.model_storage import guardar_modelo_portable

        ruta = self._ruta_sin_sobrescribir(nombre)
        self._guardando = True
        self.guardandoCambio.emit()

        def guardar_en_segundo_plano() -> None:
            try:
                # El mismo lock protege optimizer.step y la serializacion.
                with self._bloqueo_estado:
                    guardar_modelo_portable(
                        ruta,
                        self.modelo,
                        self.tokenizer,
                        nombre=ruta.stem,
                        optimizador=self._optimizador if reanudable else None,
                        optimizer_state_dict=(
                            self._optimizer_state_pendiente
                            if reanudable and self._optimizador is None
                            else None
                        ),
                        epoca=self._estado_entrenamiento.get("epoca"),
                        siguiente_epoca=self._estado_entrenamiento.get("siguiente_epoca"),
                        paso_epoca=self._estado_entrenamiento.get("paso_epoca"),
                        paso_global=self._estado_entrenamiento.get("paso_global"),
                        historial_perdidas=list(
                            self._estado_entrenamiento.get("historial_perdidas", [])
                        ),
                        hiperparametros_entrenamiento=dict(
                            self._hiperparametros_entrenamiento
                        ),
                        metadata_extra={"datasets": list(self._origen_datasets)},
                        reanudable=reanudable,
                    )
            except Exception as exc:  # noqa: BLE001 - se muestra en la UI
                self.error.emit(f"No se pudo guardar el modelo: {exc}")
            else:
                self.checkpoint_guardado.emit(str(ruta))
            finally:
                self._guardando = False
                self._hilo_guardado = None
                self.guardandoCambio.emit()

        hilo = threading.Thread(
            target=guardar_en_segundo_plano,
            name="guardar-modelo",
            daemon=True,
        )
        self._hilo_guardado = hilo
        hilo.start()

    @Slot(str)
    def guardarModeloPortableConNombre(self, nombre_archivo: str) -> None:
        self._guardar_modelo_portable(nombre_archivo, reanudable=False)

    @Slot(str)
    def guardarCheckpointReanudableConNombre(self, nombre_archivo: str) -> None:
        self._guardar_modelo_portable(nombre_archivo, reanudable=True)

    @Slot(str)
    def guardarCheckpointConNombre(self, nombre_archivo: str) -> None:
        """Alias historico: ahora crea el paquete reanudable moderno."""
        self.guardarCheckpointReanudableConNombre(nombre_archivo)

    # ------------------------------------------------------------------
    # Eventos del worker
    # ------------------------------------------------------------------

    def _sincronizar_estado_publico(self) -> None:
        # No bloquear el hilo de la UI mientras un modelo grande se escribe.
        # El siguiente paso o el evento final volvera a sincronizarlo.
        if not self._bloqueo_estado.acquire(blocking=False):
            return
        try:
            self._ultima_epoca = self._estado_entrenamiento.get("epoca")
            self._ultimo_paso_global = int(
                self._estado_entrenamiento.get("paso_global", 0)
            )
            self._historial_perdidas = list(
                self._estado_entrenamiento.get("historial_perdidas", [])
            )
        finally:
            self._bloqueo_estado.release()

    def _al_recibir_paso(self, paso: dict) -> None:
        self._sincronizar_estado_publico()
        self.paso_entrenamiento.emit(paso)

    def _al_completar(self, resultado: dict) -> None:
        self._sincronizar_estado_publico()
        self.estaEntrenandoCambio.emit()
        self.entrenamiento_completo.emit(resultado)

    def _al_cancelar(self) -> None:
        self._sincronizar_estado_publico()
        self.estaEntrenandoCambio.emit()
        self.entrenamiento_cancelado.emit(
            {"historial_perdidas": list(self._historial_perdidas)}
        )

    def _al_error(self, mensaje: str) -> None:
        self.estaEntrenandoCambio.emit()
        self.error.emit(mensaje)
