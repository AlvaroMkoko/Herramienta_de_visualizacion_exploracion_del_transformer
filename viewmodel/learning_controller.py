"""Estado persistente del recorrido educativo.

El contenido conceptual sigue perteneciendo a :class:`TheoryController`. Este
controlador solo conserva el avance del usuario y la ultima posicion visitada,
de modo que la futura evaluacion inicial/final pueda compartir la misma sesion
sin acoplar la persistencia a una pantalla QML concreta.
"""

from __future__ import annotations

from PySide6.QtCore import Property, QObject, QSettings, Signal, Slot


class LearningController(QObject):
    """Expone progreso estable y pequeno para el recorrido guiado."""

    progressChanged = Signal()

    _TOTAL_UNITS = 5
    _VALID_UNIT_IDS = tuple(f"unit_{numero}" for numero in range(1, 6))

    def __init__(self, parent: QObject | None = None, settings: QSettings | None = None):
        super().__init__(parent)
        self._settings = settings or QSettings(
            "TransformerVisualizer", "LearningPlatform"
        )
        self._completed_unit_ids = self._read_completed_units()
        self._last_unit_index = self._bounded_int(
            self._settings.value("guided/last_unit_index", 0), 0, 4
        )
        self._last_concept_index = self._bounded_int(
            self._settings.value("guided/last_concept_index", 0), 0, 2
        )

    @staticmethod
    def _bounded_int(value, minimum: int, maximum: int) -> int:
        try:
            numeric = int(value)
        except (TypeError, ValueError):
            numeric = minimum
        return max(minimum, min(maximum, numeric))

    def _read_completed_units(self) -> list[str]:
        raw = self._settings.value("guided/completed_unit_ids", [])
        if isinstance(raw, str):
            raw = [item for item in raw.split(",") if item]
        elif not isinstance(raw, (list, tuple)):
            raw = []

        completed = []
        for unit_id in raw:
            normalized = str(unit_id)
            if normalized in self._VALID_UNIT_IDS and normalized not in completed:
                completed.append(normalized)
        return completed

    def _persist(self) -> None:
        self._settings.setValue(
            "guided/completed_unit_ids", list(self._completed_unit_ids)
        )
        self._settings.setValue("guided/last_unit_index", self._last_unit_index)
        self._settings.setValue(
            "guided/last_concept_index", self._last_concept_index
        )
        self._settings.sync()

    @Property("QVariantList", notify=progressChanged)
    def completedUnitIds(self) -> list[str]:
        return list(self._completed_unit_ids)

    @Property(int, constant=True)
    def totalUnits(self) -> int:
        return self._TOTAL_UNITS

    @Property(int, notify=progressChanged)
    def completedUnitsCount(self) -> int:
        return len(self._completed_unit_ids)

    @Property(int, notify=progressChanged)
    def progressPercent(self) -> int:
        return round(len(self._completed_unit_ids) * 100 / self._TOTAL_UNITS)

    @Property(int, notify=progressChanged)
    def lastUnitIndex(self) -> int:
        return self._last_unit_index

    @Property(int, notify=progressChanged)
    def lastConceptIndex(self) -> int:
        return self._last_concept_index

    @Slot(str, result=bool)
    def isUnitCompleted(self, unit_id: str) -> bool:
        return unit_id in self._completed_unit_ids

    @Slot(str)
    def markUnitCompleted(self, unit_id: str) -> None:
        if unit_id not in self._VALID_UNIT_IDS or unit_id in self._completed_unit_ids:
            return
        self._completed_unit_ids.append(unit_id)
        self._persist()
        self.progressChanged.emit()

    @Slot(int, int)
    def savePosition(self, unit_index: int, concept_index: int) -> None:
        bounded_unit = self._bounded_int(unit_index, 0, self._TOTAL_UNITS - 1)
        bounded_concept = self._bounded_int(concept_index, 0, 2)
        if (
            bounded_unit == self._last_unit_index
            and bounded_concept == self._last_concept_index
        ):
            return
        self._last_unit_index = bounded_unit
        self._last_concept_index = bounded_concept
        self._persist()
        self.progressChanged.emit()

    @Slot()
    def resetProgress(self) -> None:
        had_visible_progress = bool(
            self._completed_unit_ids
            or self._last_unit_index != 0
            or self._last_concept_index != 0
        )
        self._completed_unit_ids = []
        self._last_unit_index = 0
        self._last_concept_index = 0
        # Se persiste incluso si el estado visible ya estaba vacío: así una
        # llamada explícita a reiniciar también elimina valores externos
        # inválidos que se hayan normalizado al cargar QSettings.
        self._persist()
        if had_visible_progress:
            self.progressChanged.emit()
