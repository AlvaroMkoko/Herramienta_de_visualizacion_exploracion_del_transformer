"""ViewModel raiz y sesion activa de la aplicacion.

Centraliza la creacion y la carga de modelos para que entrenamiento,
inferencia, datasets y visualizacion utilicen siempre el mismo Transformer y
el mismo tokenizador.
"""

from dataclasses import asdict
import json
from pathlib import Path
import threading
import time

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

from core.config import DISPOSITIVO
from model.gestor_de_datos.dataset_loader import (
    DatasetSecuencias,
    cargar_pares_combinados,
    obtener_id_token_fin,
    obtener_id_token_inicio,
    obtener_id_token_relleno,
)

from .dataset_controller import DatasetController
from .comparison_controller import ComparisonController
from .inference_controller import InferenceController
from .learning_controller import LearningController
from .model_library_controller import ModelLibraryController
from .setup_controller import SetupController
from .theory_controller import TheoryController
from .training_controller import TrainingController
from .transformer_bridge import TransformerBridge


class _TokenizerConProgreso:
    """Proxy liviano usado solo mientras ``DatasetSecuencias`` tokeniza."""

    def __init__(self, tokenizer, total: int, informar) -> None:
        self._tokenizer = tokenizer
        self._total = total
        self._informar = informar
        self._llamadas_encode = 0
        self._ultimo_informe = 0.0
        self._salto = max(total // 100, 1)

    def __getattr__(self, nombre):
        return getattr(self._tokenizer, nombre)

    def encode(self, texto):
        tokens = self._tokenizer.encode(texto)
        self._llamadas_encode += 1
        # DatasetSecuencias hace dos encode por par (origen y destino).
        # Se informa tras completar ambos, limitado a 10 Hz o saltos de 1 %.
        if self._llamadas_encode % 2 == 0:
            actual = min(self._llamadas_encode // 2, self._total)
            ahora = time.monotonic()
            if (
                actual == self._total
                or actual % self._salto == 0
                or ahora - self._ultimo_informe >= 0.1
            ):
                self._ultimo_informe = ahora
                self._informar(actual, self._total)
        return tokens


class MainViewModel(QObject):
    trainingControllerCambio = Signal()
    inferenceControllerCambio = Signal()
    modeloListoCambio = Signal()
    modeloActualInfoCambio = Signal()
    errorDataset = Signal(str)
    datasetListoParaEntrenar = Signal(int)
    activandoModeloCambio = Signal()
    faseActivacionCambio = Signal()
    preparandoDatasetCambio = Signal()
    fasePreparacionDatasetCambio = Signal()
    progresoPreparacionDatasetCambio = Signal()

    _modelo_movido_a_dispositivo = Signal(int, object, object, object)
    _activacion_modelo_fallida = Signal(int, str, bool, object)
    _progreso_dataset_recibido = Signal(int, str, int, int)
    _dataset_preparado = Signal(int, object)
    _preparacion_dataset_fallida = Signal(int, str)

    def __init__(self, parent: QObject | None = None):
        super().__init__(parent)

        self._setup_controller = SetupController(self)
        self._dataset_controller = DatasetController(self)
        self._theory_controller = TheoryController()
        self._learning_controller = LearningController(self)
        self._model_library_controller = ModelLibraryController(self)
        self._comparison_controller = ComparisonController(
            self._model_library_controller, self
        )
        self._training_controller: TrainingController | None = None
        self._inference_controller: InferenceController | None = None
        self._transformer_bridge = TransformerBridge(self)
        self._modelo_actual_info: dict = {}
        self._controladores_retirados: list[QObject] = []
        self._activacion_pendiente = None
        self._activacion_en_curso = False
        self._version_activacion = 0
        self._cancelacion_activacion_pendiente = False
        self._activando_modelo = False
        self._fase_activacion = ""
        self._version_preparacion_dataset = 0
        self._cancelacion_dataset_pendiente = False
        self._preparando_dataset = False
        self._fase_preparacion_dataset = ""
        self._avance_preparacion_dataset = 0
        self._total_preparacion_dataset = 0
        self._temporizador_retiro = QTimer(self)
        self._temporizador_retiro.setInterval(50)
        self._temporizador_retiro.timeout.connect(self._intentar_finalizar_retiro)

        self._setup_controller.modelo_creado.connect(self._al_crear_modelo)
        self._model_library_controller.modelo_cargado.connect(self._al_cargar_modelo)
        self._modelo_movido_a_dispositivo.connect(self._al_mover_modelo)
        self._activacion_modelo_fallida.connect(self._al_fallar_activacion)
        self._progreso_dataset_recibido.connect(self._al_progreso_dataset)
        self._dataset_preparado.connect(self._al_preparar_dataset)
        self._preparacion_dataset_fallida.connect(self._al_fallar_preparacion_dataset)

    # ------------------------------------------------------------------
    # Controladores expuestos a QML
    # ------------------------------------------------------------------

    @Property(QObject, constant=True)
    def transformerBridge(self) -> TransformerBridge:
        return self._transformer_bridge

    @Property(str, constant=True)
    def dispositivoCalculo(self) -> str:
        """Dispositivo elegido por la aplicacion, para avisos previos en QML."""
        return str(DISPOSITIVO)

    @Property(QObject, constant=True)
    def datasetController(self) -> DatasetController:
        return self._dataset_controller

    @Property(QObject, constant=True)
    def theoryController(self) -> TheoryController:
        return self._theory_controller

    @Property(QObject, constant=True)
    def learningController(self) -> LearningController:
        return self._learning_controller

    @Property(QObject, constant=True)
    def setupController(self) -> SetupController:
        return self._setup_controller

    @Property(QObject, constant=True)
    def modelLibraryController(self) -> ModelLibraryController:
        return self._model_library_controller

    @Property(QObject, constant=True)
    def comparisonController(self) -> ComparisonController:
        return self._comparison_controller

    @Property(QObject, notify=trainingControllerCambio)
    def trainingController(self) -> TrainingController | None:
        return self._training_controller

    @Property(QObject, notify=inferenceControllerCambio)
    def inferenceController(self) -> InferenceController | None:
        return self._inference_controller

    @Property(bool, notify=modeloListoCambio)
    def modeloListo(self) -> bool:
        return self._training_controller is not None

    @Property("QVariantMap", notify=modeloActualInfoCambio)
    def modeloActualInfo(self) -> dict:
        """Ficha de capacidades del modelo activo."""
        return dict(self._modelo_actual_info)

    @Property(bool, notify=activandoModeloCambio)
    def activandoModelo(self) -> bool:
        return self._activando_modelo

    @Property(str, notify=faseActivacionCambio)
    def faseActivacion(self) -> str:
        return self._fase_activacion

    @Property(bool, notify=preparandoDatasetCambio)
    def preparandoDataset(self) -> bool:
        return self._preparando_dataset

    @Property(str, notify=fasePreparacionDatasetCambio)
    def fasePreparacionDataset(self) -> str:
        return self._fase_preparacion_dataset

    @Property(int, notify=progresoPreparacionDatasetCambio)
    def avancePreparacionDataset(self) -> int:
        return self._avance_preparacion_dataset

    @Property(int, notify=progresoPreparacionDatasetCambio)
    def totalPreparacionDataset(self) -> int:
        return self._total_preparacion_dataset

    @Property(float, notify=progresoPreparacionDatasetCambio)
    def progresoPreparacionDataset(self) -> float:
        if self._total_preparacion_dataset <= 0:
            return 0.0
        return min(
            max(self._avance_preparacion_dataset / self._total_preparacion_dataset, 0.0),
            1.0,
        )

    def _establecer_estado_activacion(
        self, *, activo: bool | None = None, fase: str | None = None
    ) -> None:
        if activo is not None and activo != self._activando_modelo:
            self._activando_modelo = activo
            self.activandoModeloCambio.emit()
        if fase is not None and fase != self._fase_activacion:
            self._fase_activacion = fase
            self.faseActivacionCambio.emit()

    def _establecer_estado_dataset(
        self,
        *,
        activo: bool | None = None,
        fase: str | None = None,
        avance: int | None = None,
        total: int | None = None,
    ) -> None:
        if activo is not None and activo != self._preparando_dataset:
            self._preparando_dataset = activo
            self.preparandoDatasetCambio.emit()
        if fase is not None and fase != self._fase_preparacion_dataset:
            self._fase_preparacion_dataset = fase
            self.fasePreparacionDatasetCambio.emit()
        progreso_cambio = False
        if avance is not None and avance != self._avance_preparacion_dataset:
            self._avance_preparacion_dataset = avance
            progreso_cambio = True
        if total is not None and total != self._total_preparacion_dataset:
            self._total_preparacion_dataset = total
            progreso_cambio = True
        if progreso_cambio:
            self.progresoPreparacionDatasetCambio.emit()

    # ------------------------------------------------------------------
    # Activacion de modelos nuevos o restaurados
    # ------------------------------------------------------------------

    def _al_crear_modelo(self, modelo, tokenizer) -> None:
        self._activar_modelo(modelo, tokenizer)

    def _al_cargar_modelo(self, modelo, tokenizer, resultado_carga) -> None:
        self._activar_modelo(modelo, tokenizer, resultado_carga)

    def _activar_modelo(self, modelo, tokenizer, resultado_carga=None) -> None:
        """Programa una unica sesion sin solapar modelos grandes en VRAM."""
        self._cancelar_preparacion_dataset()
        self._version_activacion += 1
        version = self._version_activacion
        self._cancelacion_activacion_pendiente = False
        self._activacion_pendiente = (version, modelo, tokenizer, resultado_carga)
        self._establecer_estado_activacion(
            activo=True, fase="Preparando la activacion del modelo..."
        )
        if (
            resultado_carga is not None
            and self._setup_controller.modelo is not modelo
        ):
            self._setup_controller.liberar_modelo()

        anteriores = (self._training_controller, self._inference_controller)
        if any(controlador is not None for controlador in anteriores):
            for controlador in anteriores:
                if controlador is None:
                    continue
                controlador.detener()
                self._controladores_retirados.append(controlador)
            self._training_controller = None
            self._inference_controller = None
            self._modelo_actual_info = {}
            self.trainingControllerCambio.emit()
            self.inferenceControllerCambio.emit()
            self.modeloListoCambio.emit()
            self.modeloActualInfoCambio.emit()

        self._intentar_finalizar_retiro()

    def _intentar_finalizar_retiro(self) -> None:
        """Libera sesiones solo cuando ya no ejecutan ni serializan pesos."""
        pendientes: list[QObject] = []
        for controlador in self._controladores_retirados:
            if isinstance(controlador, TrainingController):
                seguro = not controlador.esta_entrenando and not controlador.guardando
            else:
                seguro = not controlador.esta_generando
            if not seguro:
                pendientes.append(controlador)
                continue
            controlador.cerrar()
            controlador.setParent(None)
            controlador.deleteLater()

        self._controladores_retirados = pendientes
        if pendientes:
            if not self._temporizador_retiro.isActive():
                self._temporizador_retiro.start()
            return

        self._temporizador_retiro.stop()
        if self._activacion_pendiente is None or self._activacion_en_curso:
            return
        version, modelo, tokenizer, resultado_carga = self._activacion_pendiente
        self._activacion_pendiente = None
        self._iniciar_movimiento_modelo(
            version, modelo, tokenizer, resultado_carga
        )

    def _iniciar_movimiento_modelo(
        self, version: int, modelo, tokenizer, resultado_carga=None
    ) -> None:
        """Mueve los pesos al dispositivo en un hilo que no bloquea QML."""
        self._activacion_en_curso = True
        self._establecer_estado_activacion(
            fase=f"Activando modelo en {DISPOSITIVO}..."
        )

        def tarea() -> None:
            try:
                modelo.to(DISPOSITIVO)
            except Exception as exc:  # noqa: BLE001 - se reporta a la UI
                self._activacion_modelo_fallida.emit(
                    version, str(exc), resultado_carga is not None, modelo
                )
                return
            self._modelo_movido_a_dispositivo.emit(
                version, modelo, tokenizer, resultado_carga
            )

        hilo = threading.Thread(
            target=tarea,
            name=f"activar-modelo-{version}",
            daemon=True,
        )
        try:
            hilo.start()
        except RuntimeError as exc:
            self._activacion_en_curso = False
            self._finalizar_activacion_con_error(
                f"No se pudo iniciar el hilo de activacion: {exc}",
                resultado_carga is not None,
                modelo,
            )

    def _liberar_modelo_setup_si_huerfano(self, modelo) -> None:
        if (
            modelo is not None
            and self._training_controller is None
            and self._inference_controller is None
            and self._setup_controller.modelo is modelo
        ):
            self._setup_controller.liberar_modelo()

    @Slot(int, object, object, object)
    def _al_mover_modelo(
        self, version: int, modelo, tokenizer, resultado_carga=None
    ) -> None:
        self._activacion_en_curso = False
        if version != self._version_activacion:
            if (
                self._cancelacion_activacion_pendiente
                and self._activacion_pendiente is None
            ):
                self._cancelacion_activacion_pendiente = False
                self._liberar_modelo_setup_si_huerfano(modelo)
                self._establecer_estado_activacion(activo=False, fase="")
            self._intentar_finalizar_retiro()
            return
        try:
            self._materializar_controladores(modelo, tokenizer, resultado_carga)
        except Exception as exc:  # noqa: BLE001 - tambien puede fallar un controlador
            self._finalizar_activacion_con_error(
                str(exc), resultado_carga is not None, modelo
            )
            return
        self._establecer_estado_activacion(activo=False, fase="Modelo listo")

    @Slot(int, str, bool, object)
    def _al_fallar_activacion(
        self, version: int, detalle: str, proviene_biblioteca: bool, modelo
    ) -> None:
        self._activacion_en_curso = False
        if version != self._version_activacion:
            if (
                self._cancelacion_activacion_pendiente
                and self._activacion_pendiente is None
            ):
                self._cancelacion_activacion_pendiente = False
                self._liberar_modelo_setup_si_huerfano(modelo)
                self._establecer_estado_activacion(activo=False, fase="")
            self._intentar_finalizar_retiro()
            return
        self._finalizar_activacion_con_error(detalle, proviene_biblioteca, modelo)

    def _finalizar_activacion_con_error(
        self, detalle: str, proviene_biblioteca: bool, modelo=None
    ) -> None:
        mensaje = f"No se pudo activar el modelo en {DISPOSITIVO}: {detalle}"
        self._cancelacion_activacion_pendiente = False
        self._liberar_modelo_setup_si_huerfano(modelo)
        self._establecer_estado_activacion(activo=False, fase="")
        if proviene_biblioteca:
            self._model_library_controller.error.emit(mensaje)
        else:
            self._setup_controller.error_configuracion.emit(mensaje)

    @Slot()
    def cancelarActivacionModelo(self) -> None:
        """Descarta la activacion pendiente o su resultado cuando termine.

        ``module.to`` no se interrumpe a mitad de una copia de pesos; la
        version evita instalar el resultado tardio y permite recuperar la UI.
        """
        if not self._activando_modelo:
            return
        pendiente = self._activacion_pendiente
        self._version_activacion += 1
        self._activacion_pendiente = None
        modelo_pendiente = pendiente[1] if pendiente is not None else None
        self._liberar_modelo_setup_si_huerfano(modelo_pendiente)
        if self._activacion_en_curso:
            self._cancelacion_activacion_pendiente = True
            self._establecer_estado_activacion(
                fase="Cancelando; esperando que termine la activacion actual..."
            )
        else:
            self._cancelacion_activacion_pendiente = False
            self._establecer_estado_activacion(activo=False, fase="")

    def _instalar_modelo(self, modelo, tokenizer, resultado_carga=None) -> None:
        """API sincronica historica, conservada para integraciones y pruebas."""
        modelo.to(DISPOSITIVO)
        self._materializar_controladores(modelo, tokenizer, resultado_carga)

    def _materializar_controladores(
        self, modelo, tokenizer, resultado_carga=None
    ) -> None:
        """Instala controladores; el modelo ya esta en su dispositivo final."""

        if resultado_carga is not None:
            # DatasetController consulta estas referencias al construir tensores.
            self._setup_controller.adoptar_modelo(modelo, tokenizer, emitir=False)

        if modelo.config.id_token_relleno is None:
            id_inicio = id_fin = None
        else:
            id_inicio = modelo.config.id_token_relleno + 1
            id_fin = modelo.config.id_token_relleno + 2

        nuevo_entrenamiento: TrainingController | None = None
        nuevo_inferencia: InferenceController | None = None
        try:
            nuevo_entrenamiento = TrainingController(
                modelo,
                tokenizer=tokenizer,
                resultado_carga=resultado_carga,
                parent=self,
            )
            nuevo_inferencia = InferenceController(
                modelo, tokenizer, id_inicio, id_fin, self
            )
            nuevo_entrenamiento.checkpoint_guardado.connect(
                lambda _ruta: self._model_library_controller.refrescar()
            )
        except Exception:
            for controlador in (nuevo_entrenamiento, nuevo_inferencia):
                if controlador is not None:
                    controlador.cerrar()
                    controlador.setParent(None)
                    controlador.deleteLater()
            raise

        # Se publican juntos: QML nunca observa media sesion instalada si la
        # construccion del segundo controlador falla.
        self._training_controller = nuevo_entrenamiento
        self._inference_controller = nuevo_inferencia

        self._transformer_bridge.establecer_modelo(modelo)
        manifest = getattr(resultado_carga, "manifest", None) if resultado_carga else None
        entrenamiento = (manifest or {}).get("entrenamiento", {})
        token_info = (manifest or {}).get("tokenizer", {})
        self._modelo_actual_info = {
            **asdict(modelo.config),
            "encoder_layers": modelo.config.num_capas,
            "decoder_layers": modelo.config.num_capas,
            "compartir_pesos_salida": modelo.compartir_pesos_salida,
            "parametros_totales": sum(p.numel() for p in modelo.parameters()),
            "tipo_encoding": getattr(tokenizer, "tipo_encoding", None),
            "encoding": token_info.get("encoding", ""),
            "epoca": entrenamiento.get("epoca"),
            "paso_global": entrenamiento.get("paso_global"),
            "reanudable": bool(entrenamiento.get("resume_available", False)),
        }

        # La insignia de la biblioteca debe cambiar solamente despues de que
        # el modelo haya podido instalarse en el dispositivo. Si se crea un
        # modelo nuevo (todavia sin archivo), ninguna ruta guardada sigue
        # representando la sesion activa.
        ruta_modelo_activo = (
            str((manifest or {}).get("ruta", "")) if resultado_carga is not None else ""
        )
        self._model_library_controller._establecer_modelo_activo(
            ruta_modelo_activo
        )

        self.trainingControllerCambio.emit()
        self.inferenceControllerCambio.emit()
        self.modeloListoCambio.emit()
        self.modeloActualInfoCambio.emit()
        if resultado_carga is not None:
            nombre = (manifest or {}).get("nombre", "modelo")
            self._model_library_controller.operacion_exitosa.emit(
                f"Modelo activado: {nombre}"
            )

    # ------------------------------------------------------------------
    # Datasets seleccionados -> controlador de entrenamiento
    # ------------------------------------------------------------------

    @staticmethod
    def _describir_origenes(metadatas: list[dict]) -> list[dict]:
        return [
            {
                "id": m.get("id"),
                "nombre": m.get("nombre", m.get("id", "dataset")),
                "formato": m.get("formato"),
                "registros_catalogo": m.get("registros"),
                # El catalogo historico cuenta palabras con split(), no
                # tokens del tokenizer. El nombre explicito evita mostrar
                # esa estimacion como si fuera tokenizacion real.
                "palabras_catalogo_aprox": m.get("tokens"),
                "campos": m.get("campos", []),
                "checksum": m.get("checksum"),
                "tarea": (
                    "ventana de texto -> siguiente ventana"
                    if m.get("formato") in (".txt", ".pdf")
                    else "instruction [ + context ] -> response"
                ),
            }
            for m in metadatas
        ]

    @Slot("QVariantList")
    def cargarDatasetsParaEntrenar(self, ids_datasets: list) -> None:
        if self._training_controller is None:
            self.errorDataset.emit(
                'Primero hay que crear o cargar un modelo antes de entrenar.'
            )
            return

        if not ids_datasets:
            self.errorDataset.emit("No seleccionaste ningun dataset.")
            return

        self._dataset_controller.cargar_datasets()
        catalogo = {d["id"]: d for d in self._dataset_controller.datasets}
        metadatas = []
        for id_dataset in ids_datasets:
            metadata = catalogo.get(id_dataset)
            if metadata is None:
                self.errorDataset.emit(
                    f"No se encontro el dataset {id_dataset} en el catalogo."
                )
                return
            metadatas.append(metadata)

        tokenizer = self._setup_controller.tokenizer
        modelo = self._setup_controller.modelo
        if tokenizer is None or modelo is None:
            self.errorDataset.emit("La sesion activa no tiene modelo o tokenizador.")
            return

        try:
            rutas_y_formatos = [(m["ruta"], m["formato"]) for m in metadatas]
            pares = cargar_pares_combinados(rutas_y_formatos, tokenizer=tokenizer)
        except (ValueError, FileNotFoundError) as exc:
            self.errorDataset.emit(f"No se pudo cargar el dataset: {exc}")
            return
        if not pares:
            self.errorDataset.emit(
                "Los datasets seleccionados no contienen pares de entrenamiento."
            )
            return

        id_relleno = obtener_id_token_relleno(tokenizer)
        id_inicio = obtener_id_token_inicio(tokenizer)
        id_fin = obtener_id_token_fin(tokenizer)
        longitud_maxima = max(modelo.config.longitud_maxima_secuencia - 1, 1)

        dataset = DatasetSecuencias(
            pares,
            tokenizer,
            id_inicio,
            id_fin,
            longitud_maxima=longitud_maxima,
        )
        self._training_controller.establecer_dataset(dataset, id_relleno)
        self._training_controller.establecer_origen_datasets(
            self._describir_origenes(metadatas)
        )
        self.datasetListoParaEntrenar.emit(len(pares))

    @Slot("QVariantList")
    def cargarDatasetsParaEntrenarAsync(self, ids_datasets: list) -> None:
        """Lee y tokeniza los datasets en segundo plano.

        ``cargarDatasetsParaEntrenar`` se conserva como API sincronica para
        consumidores existentes; la interfaz usa esta variante para no
        bloquear el bucle grafico.
        """
        if self._preparando_dataset:
            return
        controlador_entrenamiento = self._training_controller
        if controlador_entrenamiento is None:
            self.errorDataset.emit(
                "Primero hay que crear o cargar un modelo antes de entrenar."
            )
            return
        if not ids_datasets:
            self.errorDataset.emit("No seleccionaste ningun dataset.")
            return

        tokenizer = self._setup_controller.tokenizer
        modelo = self._setup_controller.modelo
        if tokenizer is None or modelo is None:
            self.errorDataset.emit("La sesion activa no tiene modelo o tokenizador.")
            return

        ids = list(ids_datasets)
        ruta_catalogo = Path(self._dataset_controller.DATASET_FILE)
        longitud_maxima = max(modelo.config.longitud_maxima_secuencia - 1, 1)
        self._version_preparacion_dataset += 1
        version = self._version_preparacion_dataset
        self._cancelacion_dataset_pendiente = False
        self._establecer_estado_dataset(
            activo=True,
            fase="Leyendo catalogo de datasets...",
            avance=0,
            total=0,
        )

        def informar(fase: str, avance: int = 0, total: int = 0) -> None:
            self._progreso_dataset_recibido.emit(version, fase, avance, total)

        def tarea() -> None:
            try:
                with ruta_catalogo.open("r", encoding="utf8") as archivo:
                    datos_catalogo = json.load(archivo)
                if not isinstance(datos_catalogo, list):
                    raise ValueError("El catalogo de datasets no contiene una lista.")
                catalogo = {d.get("id"): d for d in datos_catalogo if isinstance(d, dict)}
                metadatas = []
                for id_dataset in ids:
                    metadata = catalogo.get(id_dataset)
                    if metadata is None:
                        raise ValueError(
                            f"No se encontro el dataset {id_dataset} en el catalogo."
                        )
                    metadatas.append(metadata)

                pares: list[tuple[str, str]] = []
                total_archivos = len(metadatas)
                for indice, metadata in enumerate(metadatas, start=1):
                    nombre = metadata.get("nombre", metadata.get("id", "dataset"))
                    informar(
                        f"Leyendo dataset {indice}/{total_archivos}: {nombre}",
                        indice - 1,
                        total_archivos,
                    )
                    pares.extend(
                        cargar_pares_combinados(
                            [(metadata["ruta"], metadata["formato"])],
                            tokenizer=tokenizer,
                        )
                    )
                    informar(
                        f"Dataset {indice}/{total_archivos} leido",
                        indice,
                        total_archivos,
                    )

                total_pares = len(pares)
                if total_pares == 0:
                    raise ValueError(
                        "Los datasets seleccionados no contienen pares de entrenamiento."
                    )
                informar(f"Tokenizando 0/{total_pares}", 0, total_pares)
                tokenizer_progreso = _TokenizerConProgreso(
                    tokenizer,
                    total_pares,
                    lambda actual, total: informar(
                        f"Tokenizando {actual}/{total}", actual, total
                    ),
                )
                id_relleno = obtener_id_token_relleno(tokenizer)
                id_inicio = obtener_id_token_inicio(tokenizer)
                id_fin = obtener_id_token_fin(tokenizer)
                dataset = DatasetSecuencias(
                    pares,
                    tokenizer_progreso,
                    id_inicio,
                    id_fin,
                    longitud_maxima=longitud_maxima,
                )
                resultado = {
                    "dataset": dataset,
                    "id_relleno": id_relleno,
                    "origenes": self._describir_origenes(metadatas),
                    "cantidad_pares": total_pares,
                    "controlador": controlador_entrenamiento,
                }
            except Exception as exc:  # noqa: BLE001 - se reporta a la interfaz
                self._preparacion_dataset_fallida.emit(version, str(exc))
                return
            self._dataset_preparado.emit(version, resultado)

        hilo = threading.Thread(
            target=tarea,
            name=f"preparar-dataset-{version}",
            daemon=True,
        )
        try:
            hilo.start()
        except RuntimeError as exc:
            self._al_fallar_preparacion_dataset(
                version, f"No se pudo iniciar el hilo de preparacion: {exc}"
            )

    def _cancelar_preparacion_dataset(self) -> None:
        if not self._preparando_dataset:
            return
        self._version_preparacion_dataset += 1
        self._cancelacion_dataset_pendiente = True
        self._establecer_estado_dataset(
            fase="Cancelando; esperando que termine la etapa actual..."
        )

    def _finalizar_cancelacion_dataset(self) -> None:
        if not self._cancelacion_dataset_pendiente:
            return
        self._cancelacion_dataset_pendiente = False
        self._establecer_estado_dataset(
            activo=False, fase="", avance=0, total=0
        )

    @Slot()
    def cancelarPreparacionDataset(self) -> None:
        """Invalida el resultado en curso; el trabajo termina sin publicarse."""
        self._cancelar_preparacion_dataset()

    @Slot(int, str, int, int)
    def _al_progreso_dataset(
        self, version: int, fase: str, avance: int, total: int
    ) -> None:
        if version != self._version_preparacion_dataset or not self._preparando_dataset:
            return
        self._establecer_estado_dataset(
            fase=fase, avance=max(avance, 0), total=max(total, 0)
        )

    @Slot(int, object)
    def _al_preparar_dataset(self, version: int, resultado: dict) -> None:
        if version != self._version_preparacion_dataset:
            self._finalizar_cancelacion_dataset()
            return
        if not self._preparando_dataset:
            return
        controlador = resultado["controlador"]
        if controlador is not self._training_controller:
            self._establecer_estado_dataset(
                activo=False, fase="", avance=0, total=0
            )
            return
        controlador.establecer_dataset(
            resultado["dataset"], resultado["id_relleno"]
        )
        controlador.establecer_origen_datasets(resultado["origenes"])
        cantidad = int(resultado["cantidad_pares"])
        self._cancelacion_dataset_pendiente = False
        self._establecer_estado_dataset(
            activo=False,
            fase="Dataset listo para entrenar",
            avance=cantidad,
            total=cantidad,
        )
        self.datasetListoParaEntrenar.emit(cantidad)

    @Slot(int, str)
    def _al_fallar_preparacion_dataset(self, version: int, detalle: str) -> None:
        if version != self._version_preparacion_dataset:
            self._finalizar_cancelacion_dataset()
            return
        if not self._preparando_dataset:
            return
        self._cancelacion_dataset_pendiente = False
        self._establecer_estado_dataset(
            activo=False, fase="", avance=0, total=0
        )
        self.errorDataset.emit(f"No se pudo cargar el dataset: {detalle}")

    @Slot()
    def cerrar(self) -> None:
        """Cierra workers Qt de forma ordenada al salir de la aplicacion."""
        self._dataset_controller.cerrar()
        for controlador in (self._training_controller, self._inference_controller):
            if controlador is not None:
                controlador.cerrar()
        self._comparison_controller.liberarModelos()
