"""Pruebas del enrutamiento de ventanas entre monitores."""

from __future__ import annotations

from PySide6.QtQuick import QQuickWindow

from viewmodel.display_manager import DisplayManager


def test_reporta_las_pantallas_que_qt_detecta(qapp):
    manager = DisplayManager(qapp)

    assert manager.screenCount == len(qapp.screens())
    assert manager.hasSecondaryScreen is (len(qapp.screens()) > 1)
    assert manager.screenNames == [screen.name() for screen in qapp.screens()]


def test_coloca_una_ventana_auxiliar_fuera_de_la_pantalla_principal(qapp):
    manager = DisplayManager(qapp)
    main_window = QQuickWindow()
    auxiliary_window = QQuickWindow()
    main_window.setScreen(qapp.primaryScreen())
    manager.registerMainWindow(main_window)
    manager.registerAuxiliaryWindow(auxiliary_window, False)

    placed = manager.placeAuxiliaryWindow(auxiliary_window, False)

    if len(qapp.screens()) > 1:
        assert placed is True
        assert auxiliary_window.screen() is not main_window.screen()
        assert auxiliary_window.geometry() == auxiliary_window.screen().availableGeometry()
    else:
        assert placed is False

    auxiliary_window.deleteLater()
    main_window.deleteLater()


def test_ignora_objetos_que_no_son_ventanas(qapp):
    manager = DisplayManager(qapp)

    manager.registerMainWindow(manager)
    manager.registerAuxiliaryWindow(manager, True)

    assert manager.placeAuxiliaryWindow(manager, True) is False

