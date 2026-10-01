"""Detección y distribución de ventanas entre monitores.

La ventana principal permanece en la pantalla primaria. Las ventanas de apoyo
(comparación detallada, teoría y guías) se colocan en una pantalla secundaria
cuando existe, sin asumir que ambos monitores tienen la misma resolución, DPI
o posición dentro del escritorio virtual.
"""

from __future__ import annotations

from dataclasses import dataclass

from PySide6.QtCore import QObject, Property, QSize, Signal, Slot
from PySide6.QtGui import QGuiApplication, QScreen, QWindow


@dataclass
class _AuxiliaryWindow:
    window: QWindow
    maximize: bool
    normal_size: QSize


class DisplayManager(QObject):
    """Expone el estado de los monitores y coloca ventanas auxiliares."""

    screensChanged = Signal()

    def __init__(self, app: QGuiApplication | None = None) -> None:
        super().__init__()
        self._app = app or QGuiApplication.instance()
        self._main_window: QWindow | None = None
        self._auxiliary_windows: dict[int, _AuxiliaryWindow] = {}
        self._observed_screens: set[int] = set()

        if self._app is not None:
            self._app.screenAdded.connect(self._screens_changed)
            self._app.screenRemoved.connect(self._screens_changed)
            self._app.primaryScreenChanged.connect(self._screens_changed)
            self._observe_screen_geometry()

    @Property(int, notify=screensChanged)
    def screenCount(self) -> int:  # noqa: N802 - nombre consumido desde QML
        return len(self._screens())

    @Property(bool, notify=screensChanged)
    def hasSecondaryScreen(self) -> bool:  # noqa: N802
        return self.screenCount > 1

    @Property("QVariantList", notify=screensChanged)
    def screenNames(self) -> list[str]:  # noqa: N802
        return [screen.name() for screen in self._screens()]

    def _screens(self) -> list[QScreen]:
        if self._app is None:
            return []
        return list(self._app.screens())

    def _primary_screen(self) -> QScreen | None:
        if self._app is None:
            return None
        return self._app.primaryScreen()

    def _secondary_screen_for(self, window: QWindow | None) -> QScreen | None:
        screens = self._screens()
        if len(screens) < 2:
            return None

        occupied = None
        if self._main_window is not None:
            occupied = self._main_window.screen()
        if occupied is None and window is not None and window.transientParent():
            occupied = window.transientParent().screen()
        if occupied is None:
            occupied = self._primary_screen()

        return next((screen for screen in screens if screen is not occupied), screens[1])

    @Slot(QObject)
    def registerMainWindow(self, candidate: QObject) -> None:  # noqa: N802
        if not isinstance(candidate, QWindow):
            return
        self._main_window = candidate
        self._fit_main_window()

    @Slot(QObject, bool)
    def registerAuxiliaryWindow(  # noqa: N802
        self, candidate: QObject, maximize: bool = True
    ) -> None:
        if not isinstance(candidate, QWindow):
            return
        key = id(candidate)
        if key not in self._auxiliary_windows:
            normal_size = candidate.size()
            self._auxiliary_windows[key] = _AuxiliaryWindow(
                candidate, maximize, normal_size
            )
            candidate.destroyed.connect(
                lambda _object=None, window_key=key: self._auxiliary_windows.pop(
                    window_key, None
                )
            )
        else:
            self._auxiliary_windows[key].maximize = maximize

        if candidate.isVisible():
            self.placeAuxiliaryWindow(candidate, maximize)

    @Slot(QObject, bool, result=bool)
    def placeAuxiliaryWindow(  # noqa: N802
        self, candidate: QObject, maximize: bool = True
    ) -> bool:
        if not isinstance(candidate, QWindow):
            return False
        target = self._secondary_screen_for(candidate)
        if target is None:
            return False

        if candidate.screen() is not target:
            candidate.setScreen(target)
        candidate.setGeometry(target.availableGeometry())
        if maximize:
            candidate.showMaximized()
        return True

    def _fit_main_window(self) -> None:
        window = self._main_window
        screen = self._primary_screen()
        if window is None or screen is None:
            return

        if window.screen() is not screen:
            window.setScreen(screen)
        available = screen.availableGeometry()
        width = min(max(window.minimumWidth(), window.width()), available.width())
        height = min(max(window.minimumHeight(), window.height()), available.height())
        window.resize(width, height)
        window.setPosition(
            available.x() + max(0, (available.width() - width) // 2),
            available.y() + max(0, (available.height() - height) // 2),
        )

    def _restore_to_primary(self, registration: _AuxiliaryWindow) -> None:
        window = registration.window
        primary = self._primary_screen()
        if primary is None or not window.isVisible():
            return

        window.showNormal()
        window.setScreen(primary)
        available = primary.availableGeometry()
        requested = registration.normal_size
        width = min(max(window.minimumWidth(), requested.width()), available.width())
        height = min(max(window.minimumHeight(), requested.height()), available.height())
        window.resize(width, height)
        window.setPosition(
            available.x() + max(0, (available.width() - width) // 2),
            available.y() + max(0, (available.height() - height) // 2),
        )

    @Slot()
    def refresh(self) -> None:
        """Reevalúa la distribución; útil tras conectar o retirar un monitor."""

        self._screens_changed()

    def _screens_changed(self, _screen: QScreen | None = None) -> None:
        self._observe_screen_geometry()
        self.screensChanged.emit()
        self._fit_main_window()

        for registration in list(self._auxiliary_windows.values()):
            try:
                if not registration.window.isVisible():
                    continue
                if self.hasSecondaryScreen:
                    self.placeAuxiliaryWindow(
                        registration.window, registration.maximize
                    )
                else:
                    self._restore_to_primary(registration)
            except RuntimeError:
                # La ventana QML ya fue destruida; su señal ``destroyed`` puede
                # llegar después del cambio de pantalla que estamos atendiendo.
                self._auxiliary_windows.pop(id(registration.window), None)

    def _observe_screen_geometry(self) -> None:
        """Reacciona también a cambios de DPI, resolución y barra de tareas."""

        for screen in self._screens():
            key = id(screen)
            if key in self._observed_screens:
                continue
            self._observed_screens.add(key)
            screen.availableGeometryChanged.connect(self._screens_changed)
            screen.geometryChanged.connect(self._screens_changed)
            screen.logicalDotsPerInchChanged.connect(self._screens_changed)

