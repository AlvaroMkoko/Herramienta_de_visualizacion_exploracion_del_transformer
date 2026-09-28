from __future__ import annotations

import os
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import QMetaObject, QObject, Qt, QUrl
from PySide6.QtQml import QQmlComponent, QQmlEngine

from model.evaluacion.results_repository import ResultsRepository
from viewmodel import main_viewmodel as modulo_main_viewmodel
from viewmodel.evaluation_controller import EvaluationController
from viewmodel.main_viewmodel import MainViewModel


ROOT = Path(__file__).resolve().parents[2]


def _errors(component: QQmlComponent) -> str:
    return "\n".join(error.toString() for error in component.errors())


def _invoke(target: QObject, method: str) -> None:
    assert QMetaObject.invokeMethod(target, method, Qt.ConnectionType.DirectConnection)


def test_flujo_perfil_docente_y_registro_de_alumno(qapp, monkeypatch, tmp_path):
    repository = ResultsRepository(tmp_path / "resultados.json")

    def create_evaluation(parent=None):
        return EvaluationController(parent=parent, repository=repository)

    monkeypatch.setattr(
        modulo_main_viewmodel, "EvaluationController", create_evaluation
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

    selection = window.findChild(QObject, "profileSelectionScreen")
    assert selection is not None
    _invoke(selection, "openTeacher")
    qapp.processEvents()

    dashboard = window.findChild(QObject, "teacherDashboardScreen")
    assert dashboard is not None
    assert window.findChild(QObject, "teacherNewAssessmentButton") is not None
    _invoke(dashboard, "newAssessment")
    qapp.processEvents()

    registration = window.findChild(QObject, "studentRegistrationScreen")
    assert registration is not None
    window.findChild(QObject, "studentNameField").setProperty("text", "Ana López")
    window.findChild(QObject, "studentIdField").setProperty("text", "A-001")
    window.findChild(QObject, "studentGroupField").setProperty("text", "3 B")
    _invoke(registration, "continueToAssessment")
    qapp.processEvents()

    assert view_model.profileController.activeStudentName == "Ana López"
    assert window.findChild(QObject, "evaluationIntroScreen") is not None

    window.deleteLater()
    component.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_perfil_estudiante_entra_a_la_bienvenida_con_todas_sus_opciones(qapp):
    engine = QQmlEngine()
    view_model = MainViewModel()
    engine.rootContext().setContextProperty("mainViewModel", view_model)
    component = QQmlComponent(engine)
    component.loadUrl(QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "main.qml")))
    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    qapp.processEvents()

    selection = window.findChild(QObject, "profileSelectionScreen")
    assert selection is not None
    # Un solo acceso por perfil: el botón de laboratorio ya no existe aquí.
    assert window.findChild(QObject, "studentProfileButton") is not None
    assert window.findChild(QObject, "studentLaboratoryButton") is None
    _invoke(selection, "openStudent")
    qapp.processEvents()

    assert view_model.profileController.isStudent is True
    assert window.findChild(QObject, "welcomeScreen") is not None
    # La bienvenida reúne ruta y laboratorio.
    assert window.findChild(QObject, "welcomeLearningButton") is not None
    assert window.findChild(QObject, "welcomeTrainingButton") is not None
    assert window.findChild(QObject, "welcomeLibraryButton") is not None
    assert window.findChild(QObject, "welcomeComparisonButton") is not None

    window.deleteLater()
    component.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_pantalla_de_analisis_compila(qapp, tmp_path):
    host = b'''\
import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {
    width: 1280
    height: 820
    visible: false
    StackView { id: navigation; anchors.fill: parent }
    Screens.StudentAnalysisScreen {
        anchors.fill: parent
        stackView: navigation
        studentId: "inexistente"
    }
}
'''
    engine = QQmlEngine()
    view_model = MainViewModel()
    engine.rootContext().setContextProperty("mainViewModel", view_model)
    component = QQmlComponent(engine)
    component.setData(
        host, QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "ProfileHost.qml"))
    )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    qapp.processEvents()
    assert window.findChild(QObject, "studentAnalysisScreen") is not None

    window.deleteLater()
    component.deleteLater()
    engine.deleteLater()
    qapp.processEvents()
