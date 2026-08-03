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

from PySide6.QtCore import Property, QObject, Signal

from .inference_controller import InferenceController
from .setup_controller import SetupController
from .training_controller import TrainingController


class MainViewModel(QObject):
    trainingControllerCambio = Signal()
    inferenceControllerCambio = Signal()
    modeloListoCambio = Signal()

    def __init__(self, parent: QObject | None = None):
        super().__init__(parent)

        self._setup_controller = SetupController(self)
        self._training_controller: TrainingController | None = None
        self._inference_controller: InferenceController | None = None

        self._setup_controller.modelo_creado.connect(self._al_crear_modelo)

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

    def _al_crear_modelo(self, modelo, tokenizer) -> None:
        """Se dispara cada vez que `SetupController` crea un modelo — la
        primera vez, o cuando el usuario reconfigura y crea uno nuevo
        (ej. para comparar arquitecturas distintas)."""
        if self._training_controller is not None and self._training_controller.esta_entrenando:
            self._training_controller.detener()
        if self._inference_controller is not None and self._inference_controller.esta_generando:
            self._inference_controller.detener()

        if modelo.config.id_token_relleno is None:
            id_inicio = id_fin = None
        else:
            id_inicio = modelo.config.id_token_relleno + 1
            id_fin = modelo.config.id_token_relleno + 2

        self._training_controller = TrainingController(modelo, self)
        self._inference_controller = InferenceController(modelo, tokenizer, id_inicio, id_fin, self)

        self.trainingControllerCambio.emit()
        self.inferenceControllerCambio.emit()
        self.modeloListoCambio.emit()