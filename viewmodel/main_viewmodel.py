"""ViewModel raiz y sesion activa de la aplicacion.

Centraliza la creacion y la carga de modelos para que entrenamiento,
inferencia, datasets y visualizacion utilicen siempre el mismo Transformer y
el mismo tokenizador.
"""

from dataclasses import asdict

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
from .model_library_controller import ModelLibraryController
from .setup_controller import SetupController
from .theory_controller import TheoryController
from .training_controller import TrainingController
from .transformer_bridge import TransformerBridge


class MainViewModel(QObject):
    trainingControllerCambio = Signal()
    inferenceControllerCambio = Signal()
    modeloListoCambio = Signal()
    modeloActualInfoCambio = Signal()
    errorDataset = Signal(str)
    datasetListoParaEntrenar = Signal(int)

    def __init__(self, parent: QObject | None = None):
        super().__init__(parent)

        self._setup_controller = SetupController(self)
        self._dataset_controller = DatasetController()
        self._theory_controller = TheoryController(self)
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
        self._temporizador_retiro = QTimer(self)
        self._temporizador_retiro.setInterval(50)
        self._temporizador_retiro.timeout.connect(self._intentar_finalizar_retiro)

        self._setup_controller.modelo_creado.connect(self._al_crear_modelo)
        self._model_library_controller.modelo_cargado.connect(self._al_cargar_modelo)

    # ------------------------------------------------------------------
    # Controladores expuestos a QML
    # ------------------------------------------------------------------

    @Property(QObject, constant=True)
    def transformerBridge(self) -> TransformerBridge:
        return self._transformer_bridge

    @Property(QObject, constant=True)
    def datasetController(self) -> DatasetController:
        return self._dataset_controller

    @Property(QObject, constant=True)
    def theoryController(self) -> TheoryController:
        return self._theory_controller

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

    # ------------------------------------------------------------------
    # Activacion de modelos nuevos o restaurados
    # ------------------------------------------------------------------

    def _al_crear_modelo(self, modelo, tokenizer) -> None:
        self._activar_modelo(modelo, tokenizer)

    def _al_cargar_modelo(self, modelo, tokenizer, resultado_carga) -> None:
        self._activar_modelo(modelo, tokenizer, resultado_carga)

    def _activar_modelo(self, modelo, tokenizer, resultado_carga=None) -> None:
        """Programa una unica sesion sin solapar modelos grandes en VRAM."""
        self._activacion_pendiente = (modelo, tokenizer, resultado_carga)
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
        if self._activacion_pendiente is None:
            return
        modelo, tokenizer, resultado_carga = self._activacion_pendiente
        self._activacion_pendiente = None
        self._instalar_modelo(modelo, tokenizer, resultado_carga)

    def _instalar_modelo(self, modelo, tokenizer, resultado_carga=None) -> None:
        """Materializa controladores una vez retirada por completo la sesion anterior."""
        # Los archivos se reconstruyen primero en CPU para que el modelo nuevo
        # no compita por VRAM con una sesion que aun se esta retirando.
        try:
            modelo.to(DISPOSITIVO)
        except (RuntimeError, TypeError) as exc:
            mensaje = f"No se pudo activar el modelo en {DISPOSITIVO}: {exc}"
            if resultado_carga is None:
                self._setup_controller.error_configuracion.emit(mensaje)
            else:
                self._model_library_controller.error.emit(mensaje)
            return

        if resultado_carga is not None:
            # DatasetController consulta estas referencias al construir tensores.
            self._setup_controller.adoptar_modelo(modelo, tokenizer, emitir=False)

        if modelo.config.id_token_relleno is None:
            id_inicio = id_fin = None
        else:
            id_inicio = modelo.config.id_token_relleno + 1
            id_fin = modelo.config.id_token_relleno + 2

        self._training_controller = TrainingController(
            modelo,
            tokenizer=tokenizer,
            resultado_carga=resultado_carga,
            parent=self,
        )
        self._inference_controller = InferenceController(
            modelo, tokenizer, id_inicio, id_fin, self
        )
        self._training_controller.checkpoint_guardado.connect(
            lambda _ruta: self._model_library_controller.refrescar()
        )

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
            [
                {
                    "id": m.get("id"),
                    "nombre": m.get("nombre", m.get("id", "dataset")),
                    "formato": m.get("formato"),
                }
                for m in metadatas
            ]
        )
        self.datasetListoParaEntrenar.emit(len(pares))
