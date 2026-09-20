"""Estado global de avance del estudiante en la ruta de aprendizaje de cinco pasos."""

from __future__ import annotations

from PySide6.QtCore import Property, QObject, QSettings, Signal, Slot


class ProgressController(QObject):
    progresoCambio = Signal()
    banderasCambio = Signal()

    # Cambiar estos valores permite preparar demostraciones sin guardias. Las
    # preferencias se conservan en QSettings hasta que se reinicia el progreso.
    RUTA_ESTRICTA_POR_DEFECTO = True
    REQUIERE_RECORRIDO_PARA_LABS_POR_DEFECTO = True

    _LABORATORIOS = ("entrenamiento", "biblioteca", "comparacion")

    def __init__(
        self,
        learning_controller,
        evaluation_controller,
        parent: QObject | None = None,
        settings: QSettings | None = None,
    ) -> None:
        super().__init__(parent)
        self._learning = learning_controller
        self._evaluation = evaluation_controller
        self._settings = settings if settings is not None else QSettings()
        self._laboratorios_abiertos: list[str] = []
        self._seguimiento_visitado = False
        self._ruta_estricta = self.RUTA_ESTRICTA_POR_DEFECTO
        self._requiere_recorrido_labs = (
            self.REQUIERE_RECORRIDO_PARA_LABS_POR_DEFECTO
        )
        self._recargar_desde_settings()

        self._learning.progressChanged.connect(self.progresoCambio)
        self._evaluation.stateChanged.connect(self.progresoCambio)

    @staticmethod
    def _leer_lista(valor) -> list[str]:
        """Normaliza listas degradadas por QSettings."""
        if valor is None:
            return []
        if isinstance(valor, str):
            return [item for item in valor.split(",") if item]
        if isinstance(valor, (list, tuple)):
            return [str(item) for item in valor if str(item)]
        return []

    def _recargar_desde_settings(self) -> None:
        crudos = self._leer_lista(
            self._settings.value("flujo/laboratorios_abiertos", [])
        )
        self._laboratorios_abiertos = [
            laboratorio
            for laboratorio in crudos
            if laboratorio in self._LABORATORIOS
        ]
        self._seguimiento_visitado = self._settings.value(
            "flujo/seguimiento_visitado", False, type=bool
        )
        self._ruta_estricta = self._settings.value(
            "flujo/ruta_estricta", self.RUTA_ESTRICTA_POR_DEFECTO, type=bool
        )
        self._requiere_recorrido_labs = self._settings.value(
            "flujo/requiere_recorrido_para_labs",
            self.REQUIERE_RECORRIDO_PARA_LABS_POR_DEFECTO,
            type=bool,
        )

    def _guardar_flujo(self) -> None:
        self._settings.setValue(
            "flujo/laboratorios_abiertos", list(self._laboratorios_abiertos)
        )
        self._settings.setValue(
            "flujo/seguimiento_visitado", self._seguimiento_visitado
        )
        self._settings.setValue("flujo/ruta_estricta", self._ruta_estricta)
        self._settings.setValue(
            "flujo/requiere_recorrido_para_labs", self._requiere_recorrido_labs
        )
        self._settings.sync()

    @Property(bool, notify=progresoCambio)
    def preTestCompletado(self) -> bool:
        return self._evaluation.hasPre

    @Property(bool, notify=progresoCambio)
    def recorridoCompletado(self) -> bool:
        return self._learning.completedUnitsCount >= self._learning.totalUnits

    @Property("QVariantList", notify=progresoCambio)
    def laboratoriosAbiertos(self) -> list[str]:
        return list(self._laboratorios_abiertos)

    @Property(bool, notify=progresoCambio)
    def laboratoriosCompletados(self) -> bool:
        return all(
            laboratorio in self._laboratorios_abiertos
            for laboratorio in self._LABORATORIOS
        )

    @Property(bool, notify=progresoCambio)
    def postTestCompletado(self) -> bool:
        return self._evaluation.hasPost

    @Property(bool, notify=progresoCambio)
    def seguimientoVisitado(self) -> bool:
        return self._seguimiento_visitado

    @Property(int, notify=progresoCambio)
    def pasosCompletados(self) -> int:
        return sum(
            (
                self.preTestCompletado,
                self.recorridoCompletado,
                self.laboratoriosCompletados,
                self.postTestCompletado,
                self.seguimientoVisitado,
            )
        )

    @Property(bool, notify=progresoCambio)
    def flujoCompleto(self) -> bool:
        return self.pasosCompletados == 5

    @Property(int, notify=progresoCambio)
    def porcentajeFlujo(self) -> int:
        return round(self.pasosCompletados * 100 / 5)

    @Property(bool, notify=banderasCambio)
    def rutaEstricta(self) -> bool:
        return self._ruta_estricta

    @Property(bool, notify=banderasCambio)
    def requiereRecorridoParaLabs(self) -> bool:
        return self._requiere_recorrido_labs

    @Slot(bool)
    def establecerRutaEstricta(self, activa: bool) -> None:
        activa = bool(activa)
        if activa == self._ruta_estricta:
            return
        self._ruta_estricta = activa
        self._guardar_flujo()
        self.banderasCambio.emit()
        self.progresoCambio.emit()

    @Slot(bool)
    def establecerRequiereRecorridoParaLabs(self, activa: bool) -> None:
        activa = bool(activa)
        if activa == self._requiere_recorrido_labs:
            return
        self._requiere_recorrido_labs = activa
        self._guardar_flujo()
        self.banderasCambio.emit()
        self.progresoCambio.emit()

    @Slot(str)
    def registrarLaboratorioAbierto(self, laboratorio_id: str) -> None:
        if (
            laboratorio_id not in self._LABORATORIOS
            or laboratorio_id in self._laboratorios_abiertos
        ):
            return
        self._laboratorios_abiertos.append(laboratorio_id)
        self._guardar_flujo()
        self.progresoCambio.emit()

    @Slot()
    def registrarSeguimientoVisitado(self) -> None:
        if self._seguimiento_visitado:
            return
        self._seguimiento_visitado = True
        self._guardar_flujo()
        self.progresoCambio.emit()

    @Slot(int, result=bool)
    def etapaDisponible(self, orden: int) -> bool:
        if orden == 1:
            return True
        if orden == 2:
            return not self._ruta_estricta or self.preTestCompletado
        if orden == 3:
            return (
                (
                    not self._requiere_recorrido_labs
                    or self.recorridoCompletado
                )
                and (not self._ruta_estricta or self.recorridoCompletado)
            )
        if orden == 4:
            return not self._ruta_estricta or self.laboratoriosCompletados
        if orden == 5:
            return not self._ruta_estricta or self.postTestCompletado
        return False

    @Slot(int, result=str)
    def motivoBloqueo(self, orden: int) -> str:
        if self.etapaDisponible(orden):
            return ""
        return {
            2: "Completa el pre-test para desbloquear el recorrido guiado.",
            3: "Completa el recorrido guiado para desbloquear los laboratorios.",
            4: "Abre los tres laboratorios para desbloquear el post-test.",
            5: "Completa el post-test para ver tu progreso y resultados.",
        }.get(orden, "")

    @Slot()
    def borrarTodoElProgreso(self) -> None:
        self._learning.resetProgress()
        self._evaluation.borrarHistorial()
        # El reinicio global elimina tambien los interruptores, que vuelven a
        # sus valores por defecto en la siguiente lectura.
        self._settings.remove("flujo")
        self._settings.sync()
        self._recargar_desde_settings()
        self.progresoCambio.emit()
        self.banderasCambio.emit()
