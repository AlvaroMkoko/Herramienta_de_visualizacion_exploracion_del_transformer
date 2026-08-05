"""
ViewModel raíz: conecta las tres áreas.

`SetupController` existe desde el arranque (no depende de nada). En
cuanto crea un modelo (señal `modelo_creado`), este orquestador
instancia `TrainingController` e `InferenceController` con ESE modelo,
y se los expone a la Vista. Antes de que exista un modelo,
`trainingController` / `inferenceController` son `None` — la Vista usa
`modeloListo` para saber cuándo habilitar esas pantallas.

Este es el objeto que se registra en `main.py` con
`engine.rootContext().setContextProperty("mainViewModel", main_viewmodel)`.
"""

from PySide6.QtCore import Property, QObject, Signal, Slot

from .dataset_controller import DatasetController
from .inference_controller import InferenceController
from .setup_controller import SetupController
from .theory_controller import TheoryController
from .training_controller import TrainingController

from model.gestor_de_datos.dataset_loader import (
    DatasetSecuencias,
    cargar_pares_combinados,
    obtener_id_token_fin,
    obtener_id_token_inicio,
    obtener_id_token_relleno,
)


class MainViewModel(QObject):
    trainingControllerCambio = Signal()
    inferenceControllerCambio = Signal()
    modeloListoCambio = Signal()
    errorDataset = Signal(str)
    datasetListoParaEntrenar = Signal(int)  # cantidad de pares combinados

    def __init__(self, parent: QObject | None = None):
        super().__init__(parent)

        self._setup_controller = SetupController(self)
        self._dataset_controller = DatasetController()
        self._theory_controller = TheoryController(self)
        self._training_controller: TrainingController | None = None
        self._inference_controller: InferenceController | None = None

        self._setup_controller.modelo_creado.connect(self._al_crear_modelo)

    @Property(QObject, constant=True)
    def datasetController(self) -> DatasetController:
        """Disponible desde el arranque, igual que `setupController` — no
        depende de que exista un modelo (se puede armar el catálogo de
        datasets antes, durante o después de configurar la arquitectura)."""
        return self._dataset_controller

    @Property(QObject, constant=True)
    def theoryController(self) -> TheoryController:
        """Disponible desde el arranque — no depende de que exista un
        modelo, la teoría es la misma sin importar la configuración."""
        return self._theory_controller

    # ------------------------------------------------------------------
    # Propiedades observables para QML
    # ------------------------------------------------------------------

    @Property(QObject, constant=True)
    def setupController(self) -> SetupController:
        """Siempre disponible desde el arranque (no depende de que haya
        un modelo creado)."""
        return self._setup_controller

    @Property(QObject, notify=trainingControllerCambio)
    def trainingController(self) -> TrainingController | None:
        """None hasta que `setupController.crear_modelo()` se complete
        con éxito."""
        return self._training_controller

    @Property(QObject, notify=inferenceControllerCambio)
    def inferenceController(self) -> InferenceController | None:
        return self._inference_controller

    @Property(bool, notify=modeloListoCambio)
    def modeloListo(self) -> bool:
        """La Vista usa esto para habilitar/deshabilitar las pantallas
        de Entrenamiento e Inferencia (ej. `enabled: mainViewModel.modeloListo`)."""
        return self._training_controller is not None

    # ------------------------------------------------------------------
    # Reacción a la creación (o re-creación) del modelo
    # ------------------------------------------------------------------

    def _al_crear_modelo(self, modelo, tokenizer) -> None:
        """Se dispara cada vez que `SetupController` crea un modelo — la
        primera vez, o cuando el usuario reconfigura y crea uno nuevo
        (ej. para comparar arquitecturas distintas)."""
        # Si ya había un entrenamiento/generación en curso con el modelo
        # ANTERIOR, se detiene antes de reemplazarlo — seguir escribiendo
        # en un modelo que la Vista ya abandonó no tendría sentido.
        if self._training_controller is not None and self._training_controller.esta_entrenando:
            self._training_controller.detener()
        if self._inference_controller is not None and self._inference_controller.esta_generando:
            self._inference_controller.detener()

        if modelo.config.id_token_relleno is None:
            # No debería pasar con SetupController.crear_modelo() actual
            # (siempre reserva relleno/inicio/fin), pero se protege por
            # si en el futuro se permite crear un modelo sin relleno.
            id_inicio = id_fin = None
        else:
            id_inicio = modelo.config.id_token_relleno + 1
            id_fin = modelo.config.id_token_relleno + 2

        self._training_controller = TrainingController(modelo, self)
        self._inference_controller = InferenceController(modelo, tokenizer, id_inicio, id_fin, self)

        self.trainingControllerCambio.emit()
        self.inferenceControllerCambio.emit()
        self.modeloListoCambio.emit()

    # ------------------------------------------------------------------
    # Puente: dataset(s) elegidos en DataSetScreen -> TrainingController
    # ------------------------------------------------------------------

    @Slot("QVariantList")
    def cargarDatasetsParaEntrenar(self, ids_datasets: list) -> None:
        """Combina los datasets seleccionados (por id, del catálogo de
        `datasetController`) en un solo `DatasetSecuencias`, y lo deja
        listo en `trainingController` — llamado desde `DataSetScreen.qml`
        al presionar "Usar selección".

        Emite `errorDataset(mensaje)` si algo sale mal (sin modelo
        creado todavía, dataset no encontrado, formato no soportado), o
        `datasetListoParaEntrenar(cantidad_de_pares)` si sale bien.
        """
        # print("MainViewModel.cargarDatasetsParaEntrenar", ids_datasets)
        if self._training_controller is None:
            # print("No hay un modelo creado todavía, no se puede entrenar.")
            self.errorDataset.emit(
                "Primero hay que crear un modelo (botón \"Iniciar Entrenamiento\" en Setup)."
            )
            return

        if not ids_datasets:
            self.errorDataset.emit("No seleccionaste ningún dataset.")
            return

        self._dataset_controller.cargar_datasets()  # refresca catálogo desde data/datasets/dataSets.json
        catalogo = {d["id"]: d for d in self._dataset_controller.datasets}
        metadatas = []
        for id_dataset in ids_datasets:
            metadata = catalogo.get(id_dataset)
            if metadata is None:
                print(f"MainViewModel.cargarDatasetsParaEntrenar: No se encontró el dataset {id_dataset} en el catálogo.")
                self.errorDataset.emit(f"No se encontró el dataset {id_dataset} en el catálogo.")
                return
            metadatas.append(metadata)

        tokenizer = self._setup_controller.tokenizer
        modelo = self._setup_controller.modelo

        try:
            rutas_y_formatos = [(m["ruta"], m["formato"]) for m in metadatas]
            pares = cargar_pares_combinados(rutas_y_formatos, tokenizer=tokenizer)
        except (ValueError, FileNotFoundError) as e:
            self.errorDataset.emit(f"No se pudo cargar el dataset: {e}")
            return

        id_relleno = obtener_id_token_relleno(tokenizer)
        id_inicio = obtener_id_token_inicio(tokenizer)
        id_fin = obtener_id_token_fin(tokenizer)

        # -1 porque DatasetSecuencias trunca tokens_destino_completos a
        # longitud_maxima+1 (incluye inicio/fin); con esto el resultado
        # nunca supera longitud_maxima_secuencia del modelo.
        longitud_maxima = max(modelo.config.longitud_maxima_secuencia - 1, 1)

        dataset = DatasetSecuencias(pares, tokenizer, id_inicio, id_fin, longitud_maxima=longitud_maxima)
        self._training_controller.establecer_dataset(dataset, id_relleno)

        self.datasetListoParaEntrenar.emit(len(pares))