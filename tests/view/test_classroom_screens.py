"""Pantallas del aula conectada cargadas sobre la ventana real."""

from __future__ import annotations

import os
from pathlib import Path
import random

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

import pytest
from PySide6.QtCore import QMetaObject, QObject, Qt, QUrl
from PySide6.QtQml import QQmlComponent, QQmlEngine

from model.evaluacion.results_repository import ResultsRepository
from viewmodel import course_controller as modulo_course
from viewmodel import main_viewmodel as modulo_main_viewmodel
from viewmodel.aula import ClassroomHostController, ClassroomStudentController
from viewmodel.aula.cliente_lan import ClienteAulaLan
from viewmodel.evaluation_controller import EvaluationController
from viewmodel.main_viewmodel import MainViewModel

ROOT = Path(__file__).resolve().parents[2]
TIEMPO = 15000


def _errors(component: QQmlComponent) -> str:
    return "\n".join(error.toString() for error in component.errors())


def _invoke(target: QObject, method: str) -> None:
    assert QMetaObject.invokeMethod(target, method, Qt.ConnectionType.DirectConnection)


@pytest.fixture
def ventana(qapp, monkeypatch, tmp_path):
    puerto_udp = random.randint(52000, 60000)

    def host(parent=None, catalog=None):
        return ClassroomHostController(
            parent, raiz_clases=tmp_path / "clases", catalog=catalog,
            puerto_websocket=0, puerto_descubrimiento=puerto_udp,
        )

    def alumno(course, results, evaluations, profile, parent=None):
        return ClassroomStudentController(
            course, results, evaluations, profile, parent,
            ruta_estado=tmp_path / "mi_clase.json",
            cliente=ClienteAulaLan(puerto_descubrimiento=puerto_udp, espera_busqueda_ms=300),
        )

    original_repo = modulo_course.ModuleProgressRepository
    resultados = ResultsRepository(tmp_path / "resultados.json")
    monkeypatch.setattr(
        modulo_main_viewmodel, "EvaluationController",
        lambda parent=None: EvaluationController(parent=parent, repository=resultados),
    )
    monkeypatch.setattr(modulo_main_viewmodel, "ClassroomHostController", host)
    monkeypatch.setattr(modulo_main_viewmodel, "ClassroomStudentController", alumno)
    monkeypatch.setattr(
        modulo_course, "ModuleProgressRepository",
        lambda _ruta=None: original_repo(tmp_path / "progreso.json"),
    )

    engine = QQmlEngine()
    view_model = MainViewModel()
    engine.rootContext().setContextProperty("mainViewModel", view_model)
    component = QQmlComponent(engine)
    component.loadUrl(QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "main.qml")))
    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    qapp.processEvents()
    yield window, view_model
    view_model.classroomHostController.detenerClase()
    window.deleteLater()
    component.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_docente_crea_clase_desde_el_panel(qapp, ventana):
    window, view_model = ventana
    _invoke(window.findChild(QObject, "profileSelectionScreen"), "openTeacher")
    qapp.processEvents()
    assert window.findChild(QObject, "teacherClassroomButton") is not None
    window.findChild(QObject, "teacherClassroomButton").clicked.emit()
    qapp.processEvents()

    setup = window.findChild(QObject, "classroomSetupScreen")
    assert setup is not None
    window.findChild(QObject, "classroomNameField").setProperty("text", "Inteligencia Artificial")
    window.findChild(QObject, "classroomRequireIdCheck").setProperty("checked", True)
    _invoke(setup, "crear")
    qapp.processEvents()

    host = view_model.classroomHostController
    assert host.activa and host.pedirMatricula
    assert window.findChild(QObject, "classroomScreen") is not None
    assert window.findChild(QObject, "classroomCodeText").property("text") == host.codigo


def test_alumno_se_une_desde_la_interfaz(qapp, qtbot, ventana):
    window, view_model = ventana
    host = view_model.classroomHostController
    assert host.crearClase("Inteligencia Artificial", "6CV1", False, False)
    alumno = view_model.classroomStudentController

    _invoke(window.findChild(QObject, "profileSelectionScreen"), "openStudent")
    qapp.processEvents()
    assert window.findChild(QObject, "welcomeClassroomStrip") is not None
    _invoke(window.findChild(QObject, "welcomeScreen"), "abrirClase")
    qapp.processEvents()

    join = window.findChild(QObject, "joinClassScreen")
    assert join is not None
    window.findChild(QObject, "joinClassCodeField").setProperty("text", host.codigo)
    _invoke(join, "buscar")
    qtbot.waitUntil(lambda: alumno.estado == "eligiendo_apodo", timeout=TIEMPO)

    window.findChild(QObject, "joinClassNicknameField").setProperty("text", "Ana")
    _invoke(join, "entrar")
    qtbot.waitUntil(lambda: alumno.estado == "conectado", timeout=TIEMPO)
    qtbot.waitUntil(lambda: host.conectados == 1, timeout=TIEMPO)

    chip = window.findChild(QObject, "classroomStatusChip")
    assert chip.property("visible")
    assert host.enviarAviso("Bienvenidos")
    banner = window.findChild(QObject, "classroomAnnouncementBanner")
    qtbot.waitUntil(lambda: banner.property("visible"), timeout=TIEMPO)
