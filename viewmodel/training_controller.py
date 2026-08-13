"""Orquestacion del entrenamiento y de sus snapshots persistentes."""

from __future__ import annotations

import threading
import time
from collections.abc import Generator
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Any

import torch
from PySide6.QtCore import Property, QObject, Signal, Slot

from core.config import DIR_CHECKPOINTS
from .concurrency_manager import GestorConcurrencia
from .visual_adapter import resumir_paso_entrenamiento, extraer_nube_segun_modo

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
    tokenizer: "Tokenizer | None",
    dataset,
    id_token_relleno: int | None,
    num_epocas: int,
    batch_size: int,
    optimizador: torch.optim.Optimizer,
    estado: dict[str, Any],
    bloqueo_estado: threading.RLock,
    config_nube: dict[str, Any],
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
    ejes_pca_previos = None
    
    for epoca in range(epoca_inicial, epoca_inicial + num_epocas):
        with bloqueo_estado:
            # Si se cancela a mitad de la epoca, la continuacion repite esa
            # epoca. Sin conservar el orden completo del sampler no seria
            # correcto afirmar que puede retomarse en el batch exacto.
            estado["siguiente_epoca"] = epoca
        batches = _crear_batches(dataset, id_token_relleno, batch_size)

        for paso_epoca, (tokens_origen, tokens_destino, objetivo) in enumerate(batches):
            inicio_paso = time.perf_counter()
            tokens_origen = tokens_origen.to(dispositivo)
            tokens_destino = tokens_destino.to(dispositivo)
            objetivo = objetivo.to(dispositivo)

            with bloqueo_estado:
                optimizador.zero_grad()
                logits = modelo(tokens_origen, tokens_destino)
                perdida = modelo.calcular_perdida(logits, objetivo)
                perdida.backward()
                norma_gradiente = _norma_gradiente_global(modelo)
                perdida_anterior = historial[-1] if historial else None
                optimizador.step()

                nube_cfg = dict(config_nube)

                paso_global += 1
                perdida_valor = float(perdida.item())
                historial.append(perdida_valor)

                cantidad_ejemplos = int(tokens_origen.shape[0])
                if id_token_relleno is None:
                    tokens_origen_reales = int(tokens_origen.numel())
                    tokens_objetivo_reales = int(objetivo.numel())
                else:
                    tokens_origen_reales = int(
                        (tokens_origen != id_token_relleno).sum().item()
                    )
                    tokens_objetivo_reales = int(
                        (objetivo != id_token_relleno).sum().item()
                    )

                estado.update(
                    {
                        "epoca": epoca,
                        "paso_epoca": paso_epoca,
                        "paso_global": paso_global,
                        "ejemplos_vistos": int(estado.get("ejemplos_vistos", 0))
                        + cantidad_ejemplos,
                        "tokens_origen_vistos": int(
                            estado.get("tokens_origen_vistos", 0)
                        )
                        + tokens_origen_reales,
                        "tokens_objetivo_vistos": int(
                            estado.get("tokens_objetivo_vistos", 0)
                        )
                        + tokens_objetivo_reales,
                        "duracion_entrenamiento_segundos": float(
                            estado.get("duracion_entrenamiento_segundos", 0.0)
                        )
                        + (time.perf_counter() - inicio_paso),
                        "telemetria_procedencia_disponible": True,
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
                    "visualizacion": resumir_paso_entrenamiento(
                        modelo=modelo,
                        logits=logits,
                        tokens_origen=tokens_origen,
                        tokens_destino=tokens_destino,
                        objetivo=objetivo,
                        perdida=perdida_valor,
                        perdida_anterior=perdida_anterior,
                        norma_gradiente_global=norma_gradiente,
                        tokenizer=tokenizer,
                    ),
                }

            if nube_cfg.get("activa") and paso_global % nube_cfg.get("intervalo", 10) == 0:
                # La visualizacion nunca debe tumbar el entrenamiento: si algo
                # falla aqui (secuencia demasiado corta, dimension invalida
                # elegida en la UI), se omite la nube de ESTE paso y se sigue.
                try:
                    primera_secuencia = tokens_origen[0]

                    # El batch viene rellenado: sin filtrar, la mayoria de los
                    # puntos serian padding apilados en un mismo lugar, y la
                    # varianza reportada quedaria inflada por esa separacion
                    # artificial (medido: 46 de 50 puntos y 92.5% "conservado").
                    if id_token_relleno is not None:
                        mascara_real = primera_secuencia != id_token_relleno
                    else:
                        mascara_real = torch.ones_like(primera_secuencia, dtype=torch.bool)

                    ids_reales = primera_secuencia[mascara_real].tolist()

                    # PCA necesita al menos 3 puntos para 3 componentes.
                    if len(ids_reales) >= 3:
                        with torch.no_grad():
                            embeddings_batch = modelo.embedding_entrada(
                                primera_secuencia[mascara_real].unsqueeze(0)
                            )
                        nube = extraer_nube_segun_modo(
                            embeddings_batch,
                            nube_cfg,
                            tokens_ids=ids_reales,
                            tokenizer=tokenizer,
                            ejes_previos=ejes_pca_previos,
                        )
                        # `ejes` es un ndarray: se guarda del lado de Python
                        # para el frame siguiente y se quita del payload, que
                        # tiene que ser 100% serializable a QML.
                        ejes_pca_previos = nube.pop("ejes", None)
                        paso["nube_embeddings"] = nube
                except (ValueError, IndexError, RuntimeError):
                    pass

            yield paso

        with bloqueo_estado:
            estado["siguiente_epoca"] = epoca + 1

    return {
        "historial_perdidas": list(historial),
        "perdida_final": historial[-1] if historial else None,
        "epoca": estado.get("epoca"),
        "paso_global": paso_global,
        "ejemplos_vistos": estado.get("ejemplos_vistos", 0),
        "tokens_origen_vistos": estado.get("tokens_origen_vistos", 0),
        "tokens_objetivo_vistos": estado.get("tokens_objetivo_vistos", 0),
        "duracion_entrenamiento_segundos": estado.get(
            "duracion_entrenamiento_segundos", 0.0
        ),
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
        metadata_previa = dict(
            getattr(resultado_carga, "metadata_extra", {}) or {}
        )
        self._origen_datasets: list[dict] = [
            dict(item)
            for item in metadata_previa.get("datasets", [])
            if isinstance(item, dict)
        ]
        self._bloqueo_estado = threading.RLock()
        # Config de la nube 3D. La escribe la UI, la lee el worker —
        self._config_nube = {
            "activa": False,
            "modo": "pca",
            "dimensiones": [0, 1, 2],
            "intervalo": 10,
        }

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
            "ejemplos_vistos": int(metadata_previa.get("ejemplos_vistos", 0) or 0),
            "tokens_origen_vistos": int(
                metadata_previa.get("tokens_origen_vistos", 0) or 0
            ),
            "tokens_objetivo_vistos": int(
                metadata_previa.get("tokens_objetivo_vistos", 0) or 0
            ),
            "duracion_entrenamiento_segundos": float(
                metadata_previa.get("duracion_entrenamiento_segundos", 0.0) or 0.0
            ),
            "telemetria_procedencia_disponible": any(
                clave in metadata_previa
                for clave in (
                    "ejemplos_vistos",
                    "tokens_origen_vistos",
                    "tokens_objetivo_vistos",
                    "duracion_entrenamiento_segundos",
                )
            ),
            "telemetria_procedencia_completa": bool(
                metadata_previa.get(
                    "telemetria_procedencia_completa",
                    any(
                        clave in metadata_previa
                        for clave in (
                            "ejemplos_vistos",
                            "tokens_origen_vistos",
                            "tokens_objetivo_vistos",
                            "duracion_entrenamiento_segundos",
                        )
                    )
                    or int(ultimo_paso or 0) == 0,
                )
            ),
            "telemetria_desde_paso": int(
                metadata_previa.get(
                    "telemetria_desde_paso",
                    0 if int(ultimo_paso or 0) == 0 else int(ultimo_paso or 0) + 1,
                )
            ),
            "primera_sesion_inicio_utc": metadata_previa.get(
                "primera_sesion_inicio_utc"
            ),
            "ultima_sesion_inicio_utc": metadata_previa.get(
                "ultima_sesion_inicio_utc"
            ),
            "ultima_sesion_fin_utc": metadata_previa.get("ultima_sesion_fin_utc"),
        }
        self._ultima_epoca = ultima_epoca
        self._ultimo_paso_global = int(ultimo_paso or 0)
        self._historial_perdidas = historial
        self._hiperparametros_entrenamiento = dict(
            getattr(resultado_carga, "hiperparametros_entrenamiento", {}) or {}
        )
        if not self._hiperparametros_entrenamiento:
            self._hiperparametros_entrenamiento = dict(
                metadata_previa.get("hiperparametros_entrenamiento", {}) or {}
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
            "tarea": self._describir_tarea(),
        }
        inicio_utc = datetime.now(timezone.utc).isoformat()
        with self._bloqueo_estado:
            if int(self._estado_entrenamiento.get("paso_global", 0)) == 0:
                self._estado_entrenamiento[
                    "telemetria_procedencia_completa"
                ] = True
                self._estado_entrenamiento["telemetria_desde_paso"] = 0
            if not self._estado_entrenamiento.get("primera_sesion_inicio_utc"):
                self._estado_entrenamiento["primera_sesion_inicio_utc"] = inicio_utc
            self._estado_entrenamiento["ultima_sesion_inicio_utc"] = inicio_utc
            self._estado_entrenamiento["ultima_sesion_fin_utc"] = None
        self._gestor.ejecutar_en_segundo_plano(
            _tarea_entrenamiento,
            self.modelo,
            self.tokenizer,
            dataset,
            id_token_relleno,
            num_epocas,
            batch_size,
            self._optimizador,
            self._estado_entrenamiento,
            self._bloqueo_estado,
            self._config_nube,
            velocidad_inicial=velocidad_inicial,
        )

    @Slot(int, float, int, float)
    def iniciar_entrenamiento_ui(
        self,
        num_epocas: int,
        tasa_aprendizaje: float, 
        batch_size: int,
        velocidad_inicial: float = 0.0
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
            velocidad_inicial=velocidad_inicial
        )

    def establecer_dataset(self, dataset: "Dataset", id_token_relleno: int) -> None:
        self._dataset = dataset
        self._id_token_relleno_dataset = id_token_relleno

    def establecer_origen_datasets(self, datasets: list[dict]) -> None:
        """Guarda solo metadatos no sensibles, nunca rutas absolutas."""
        self._origen_datasets = [dict(item) for item in datasets]

    def _describir_tarea(self) -> str:
        tareas = {
            str(item.get("tarea", "")).strip()
            for item in self._origen_datasets
            if str(item.get("tarea", "")).strip()
        }
        if not tareas:
            return "secuencia de origen -> secuencia de destino"
        return " + ".join(sorted(tareas))

    def _metadata_de_procedencia(self) -> dict[str, Any]:
        """Datos medidos durante el entrenamiento, sin inferir campos ausentes."""
        metadata: dict[str, Any] = {
            "datasets": list(self._origen_datasets),
            "tarea": self._describir_tarea(),
        }
        for clave in (
            "primera_sesion_inicio_utc",
            "ultima_sesion_inicio_utc",
            "ultima_sesion_fin_utc",
        ):
            valor = self._estado_entrenamiento.get(clave)
            if valor:
                metadata[clave] = valor
        if not self._estado_entrenamiento.get(
            "telemetria_procedencia_disponible", False
        ):
            return metadata

        metadata.update(
            {
                "ejemplos_vistos": int(
                    self._estado_entrenamiento.get("ejemplos_vistos", 0)
                ),
                "tokens_origen_vistos": int(
                    self._estado_entrenamiento.get("tokens_origen_vistos", 0)
                ),
                "tokens_objetivo_vistos": int(
                    self._estado_entrenamiento.get("tokens_objetivo_vistos", 0)
                ),
                "duracion_entrenamiento_segundos": float(
                    self._estado_entrenamiento.get(
                        "duracion_entrenamiento_segundos", 0.0
                    )
                ),
                "telemetria_procedencia_completa": bool(
                    self._estado_entrenamiento.get(
                        "telemetria_procedencia_completa", False
                    )
                ),
                "telemetria_desde_paso": int(
                    self._estado_entrenamiento.get("telemetria_desde_paso", 0)
                ),
            }
        )
        return metadata

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
                        **self._metadata_de_procedencia(),
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

    @Slot(bool)
    def activarNubeEmbeddings(self, activa: bool) -> None:
        """Encender/apagar el cálculo. Apagada no cuesta nada: el worker
        ni siquiera lee los embeddings."""
        with self._bloqueo_estado:
            self._config_nube["activa"] = bool(activa)

    @Slot(str, "QVariantList", int)
    def configurarNubeEmbeddings(self, modo: str, dimensiones: list, intervalo: int) -> None:
        """Cambia el modo de proyección en caliente, sin detener el
        entrenamiento. Se escribe bajo lock para que el worker nunca lea
        un modo nuevo con las dimensiones viejas.

        Args:
            modo: "pca" o "ejes".
            dimensiones: 1-3 índices; solo se usan si modo == "ejes".
            intervalo: cada cuántos pasos recalcular (>= 1).
        """
        dims = [int(d) for d in dimensiones][:3] or [0, 1, 2]
        with self._bloqueo_estado:
            self._config_nube["modo"] = "pca" if modo == "pca" else "ejes"
            self._config_nube["dimensiones"] = dims
            self._config_nube["intervalo"] = max(1, int(intervalo))

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
                        metadata_extra=self._metadata_de_procedencia(),
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
        with self._bloqueo_estado:
            self._estado_entrenamiento["ultima_sesion_fin_utc"] = datetime.now(
                timezone.utc
            ).isoformat()
        self._sincronizar_estado_publico()
        self.estaEntrenandoCambio.emit()
        self.entrenamiento_completo.emit(resultado)

    def _al_cancelar(self) -> None:
        with self._bloqueo_estado:
            self._estado_entrenamiento["ultima_sesion_fin_utc"] = datetime.now(
                timezone.utc
            ).isoformat()
            # El siguiente intento repite la epoca actual; sin conservar el
            # orden del sampler, los contadores dejan de representar un
            # recorrido exacto del historial completo.
            self._estado_entrenamiento[
                "telemetria_procedencia_completa"
            ] = False
        self._sincronizar_estado_publico()
        self.estaEntrenandoCambio.emit()
        self.entrenamiento_cancelado.emit(
            {"historial_perdidas": list(self._historial_perdidas)}
        )

    def _al_error(self, mensaje: str) -> None:
        with self._bloqueo_estado:
            self._estado_entrenamiento["ultima_sesion_fin_utc"] = datetime.now(
                timezone.utc
            ).isoformat()
        self.estaEntrenandoCambio.emit()
        self.error.emit(mensaje)
