"""Qt object that connects VisPy selections to the QML inspector."""

from __future__ import annotations

from PySide6.QtCore import Property, QObject, Signal, Slot

from .transformer_model import COMPONENTS


class TransformerBridge(QObject):
    selectionChanged = Signal()
    activePageChanged = Signal()
    modelConfigChanged = Signal()
    resetCameraRequested = Signal()
    componentActivated = Signal(str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._selected_id = ""
        self._active_page = "overview"
        self._model_info: dict = {}

    def _spec_value(self, attribute: str, default=""):
        spec = COMPONENTS.get(self._selected_id)
        return getattr(spec, attribute) if spec else default

    @Property(str, notify=selectionChanged)
    def selectedId(self) -> str:
        return self._selected_id

    @Property(str, notify=selectionChanged)
    def selectedTitle(self) -> str:
        return self._spec_value("title", "Select a component")

    @Property(str, notify=selectionChanged)
    def selectedGroup(self) -> str:
        return self._spec_value("group", "Transformer architecture")

    @Property(str, notify=selectionChanged)
    def selectedDescription(self) -> str:
        return self._spec_value(
            "description", "Click a block in the 3D scene to inspect it."
        )

    @Property("QVariantList", notify=selectionChanged)
    def selectedParameters(self) -> list[str]:
        parametros = list(self._spec_value("parameters", ()))
        if not self._model_info:
            return parametros

        valores = {
            "Vocabulary size": self._model_info.get("tamano_vocabulario"),
            "Embedding dimension (d_model)": self._model_info.get("dimension_modelo"),
            "Padding index": self._model_info.get("id_token_relleno"),
            "Maximum sequence length": self._model_info.get("longitud_maxima_secuencia"),
            "Dropout": self._model_info.get("dropout"),
            "Attention dropout": self._model_info.get("dropout"),
            "Number of heads": self._model_info.get("num_cabezas"),
            "Key/query dimension": self._model_info.get("dimension_cabeza"),
            "Hidden dimension (d_ff)": self._model_info.get("dimension_ff"),
            "Input dimension": self._model_info.get("dimension_modelo"),
            "Weight tying": self._model_info.get("compartir_pesos_salida"),
        }
        return [
            f"{nombre}: {valores[nombre]}"
            if nombre in valores and valores[nombre] is not None
            else nombre
            for nombre in parametros
        ]

    @Property("QVariantMap", notify=modelConfigChanged)
    def modelInfo(self) -> dict:
        """Configuracion real del modelo activo, lista para QML."""
        return dict(self._model_info)

    @Property(int, notify=modelConfigChanged)
    def numCapas(self) -> int:
        return int(self._model_info.get("num_capas", 0))

    @Property(int, notify=modelConfigChanged)
    def numCabezas(self) -> int:
        return int(self._model_info.get("num_cabezas", 0))

    @Property(int, notify=modelConfigChanged)
    def dimensionModelo(self) -> int:
        return int(self._model_info.get("dimension_modelo", 0))

    def establecer_modelo(self, modelo) -> None:
        """Actualiza las capacidades mostradas por el diagrama/inspector."""
        config = modelo.config
        self._model_info = {
            "tamano_vocabulario": config.tamano_vocabulario,
            "dimension_modelo": config.dimension_modelo,
            "num_cabezas": config.num_cabezas,
            "num_capas": config.num_capas,
            "dimension_ff": config.dimension_ff,
            "longitud_maxima_secuencia": config.longitud_maxima_secuencia,
            "dropout": config.dropout,
            "activacion": config.activacion,
            "usar_mascara_causal": config.usar_mascara_causal,
            "id_token_relleno": config.id_token_relleno,
            "dimension_cabeza": config.dimension_cabeza,
            "compartir_pesos_salida": modelo.compartir_pesos_salida,
            "parametros_totales": sum(p.numel() for p in modelo.parameters()),
        }
        self.modelConfigChanged.emit()
        self.selectionChanged.emit()

    @Property(str, notify=selectionChanged)
    def selectedColor(self) -> str:
        spec = COMPONENTS.get(self._selected_id)
        return spec.accent_hex if spec else "#6d5bd0"

    @Property(str, notify=activePageChanged)
    def activePage(self) -> str:
        return self._active_page

    @Slot(str)
    def selectComponent(self, component_id: str) -> None:
        if component_id not in COMPONENTS:
            return
        changed = component_id != self._selected_id
        self._selected_id = component_id
        if changed:
            self.selectionChanged.emit()
        if self._active_page != "detail":
            self._active_page = "detail"
            self.activePageChanged.emit()
        self.componentActivated.emit(component_id)

    @Slot()
    def showOverview(self) -> None:
        if self._active_page != "overview":
            self._active_page = "overview"
            self.activePageChanged.emit()

    @Slot()
    def resetCamera(self) -> None:
        self.resetCameraRequested.emit()

