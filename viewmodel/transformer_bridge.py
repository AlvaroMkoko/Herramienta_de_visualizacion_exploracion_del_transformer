"""Qt object that connects VisPy selections to the QML inspector."""

from __future__ import annotations

from PySide6.QtCore import Property, QObject, Signal, Slot

from .transformer_model import COMPONENTS


class TransformerBridge(QObject):
    selectionChanged = Signal()
    activePageChanged = Signal()
    resetCameraRequested = Signal()
    componentActivated = Signal(str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._selected_id = ""
        self._active_page = "overview"

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
        return list(self._spec_value("parameters", ()))

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

