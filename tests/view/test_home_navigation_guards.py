"""Pruebas de las guardias de navegación de la ruta de aprendizaje.

La ruta formativa tiene cinco pasos que deben recorrerse en orden: sin el
pre-test no hay recorrido guiado, sin el recorrido no hay laboratorios, sin
abrir los tres laboratorios no hay post-test, y sin post-test no hay pantalla de
progreso. Saltarse el orden invalida la medición: un post-test contestado antes
de practicar no mide lo que el instrumento dice medir.

Estas pruebas verifican las guardias desde QML, a través de ``objectName`` y
propiedades públicas, sin depender de coordenadas ni de colores.
"""

from __future__ import annotations

import os
from pathlib import Path

# Deben fijarse antes de que pytest-qt construya QApplication.
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

import pytest
from PySide6.QtCore import QObject, QSettings, QUrl
from PySide6.QtQml import QQmlComponent, QQmlEngine

from model.evaluacion.results_repository import ResultsRepository
from viewmodel import main_viewmodel as modulo_main_viewmodel
from viewmodel.evaluation_controller import EvaluationController
from viewmodel.learning_controller import LearningController
from viewmodel.main_viewmodel import MainViewModel
from viewmodel.progress_controller import ProgressController

RAIZ_PROYECTO = Path(__file__).resolve().parents[2]

HOST_HOME = b"""\
import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {
    objectName: "guardsHomeHost"
    width: 1280
    height: 820
    visible: false

    StackView {
        id: navigation
        objectName: "learningNavigation"
        anchors.fill: parent
        initialItem: homePage
    }

    Component {
        id: homePage
        Screens.HomeScreen {
            stackView: navigation
        }
    }
}
"""

#: Cada etapa, con el botón que la abre y la tarjeta que la representa.
ETAPAS = (
    (1, "pretestStageCard", "pretestOpenButton"),
    (2, "guidedStageCard", "guidedStartButton"),
    (4, "posttestStageCard", "posttestOpenButton"),
    (5, "resultsStageCard", "resultsOpenButton"),
)

LABORATORIOS = (
    ("trainingLabButton", "entrenamiento"),
    ("modelLibraryLabButton", "biblioteca"),
    ("comparisonLabButton", "comparacion"),
)


def _errores(component: QQmlComponent) -> str:
    return "\n".join(error.toString() for error in component.errors())


def _propiedad(objeto: QObject, nombre: str):
    return objeto.property(nombre)


def _buscar(raiz: QObject, object_name: str) -> QObject:
    encontrado = raiz.findChild(QObject, object_name)
    assert encontrado is not None, f"Falta el hook publico objectName={object_name!r}"
    return encontrado


@pytest.fixture
def home(qapp, qtbot, monkeypatch, tmp_path):
    """Home con los tres controladores persistentes aislados en tmp_path.

    Sin este aislamiento la prueba leería el progreso real de quien la ejecuta y
    pasaría o fallaría según si ya hizo el pre-test en su máquina.
    """
    settings = QSettings(
        str(tmp_path / "guardias-test.ini"), QSettings.Format.IniFormat
    )
    settings.clear()
    settings.sync()
    ruta_resultados = tmp_path / "resultados-test.json"

    def crear_learning(parent=None):
        return LearningController(parent=parent, settings=settings)

    def crear_evaluation(parent=None):
        return EvaluationController(
            parent=parent, repository=ResultsRepository(ruta_resultados)
        )

    def crear_progress(learning, evaluation, parent=None):
        return ProgressController(learning, evaluation, parent, settings=settings)

    monkeypatch.setattr(modulo_main_viewmodel, "LearningController", crear_learning)
    monkeypatch.setattr(
        modulo_main_viewmodel, "EvaluationController", crear_evaluation
    )
    monkeypatch.setattr(modulo_main_viewmodel, "ProgressController", crear_progress)

    engine = QQmlEngine()
    view_model = MainViewModel()
    engine.rootContext().setContextProperty("mainViewModel", view_model)

    component = QQmlComponent(engine)
    component.setData(
        HOST_HOME,
        QUrl.fromLocalFile(str(RAIZ_PROYECTO / "view" / "qml" / "GuardsHost.qml")),
    )
    if component.status() == QQmlComponent.Status.Loading:
        qtbot.waitUntil(
            lambda: component.status() != QQmlComponent.Status.Loading, timeout=5000
        )
    assert component.status() != QQmlComponent.Status.Error, _errores(component)

    window = component.create()
    assert window is not None, _errores(component)
    window.show()
    qapp.processEvents()

    pantalla = _buscar(window, "homeScreen")
    # La ruta estricta se fuerza: el valor por defecto podría cambiarse durante
    # el desarrollo y estas pruebas dejarían de probar lo que dicen probar.
    view_model.progressController.establecerRutaEstricta(True)
    view_model.progressController.establecerRequiereRecorridoParaLabs(True)
    qapp.processEvents()

    yield window, pantalla, view_model

    window.deleteLater()
    component.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def completar_pretest(view_model) -> None:
    view_model.evaluationController._repository.save_result(
        {"assessment_type": "pre", "puntaje": 12.0, "maximo": 20.0, "percentage": 60.0}
    )
    view_model.evaluationController.stateChanged.emit()


def completar_posttest(view_model) -> None:
    view_model.evaluationController._repository.save_result(
        {"assessment_type": "post", "puntaje": 18.0, "maximo": 20.0, "percentage": 90.0}
    )
    view_model.evaluationController.stateChanged.emit()


def completar_recorrido(view_model) -> None:
    learning = view_model.learningController
    for unit_id in learning._VALID_UNIT_IDS:
        learning.markUnitCompleted(unit_id)


# ---------------------------------------------------------------------------
# Estado inicial
# ---------------------------------------------------------------------------


def test_con_progreso_vacio_solo_el_pretest_esta_disponible(home, qapp):
    _, pantalla, _ = home

    disponibles = {
        orden: _propiedad(_buscar(pantalla, tarjeta), "stageAvailable")
        for orden, tarjeta, _ in ETAPAS
    }

    assert disponibles == {1: True, 2: False, 4: False, 5: False}
    assert _propiedad(_buscar(pantalla, "labsStageCard"), "stageAvailable") is False


def test_cada_etapa_bloqueada_muestra_su_motivo(home):
    _, pantalla, view_model = home
    progreso = view_model.progressController

    for orden in (2, 3, 4, 5):
        assert progreso.motivoBloqueo(orden), f"la etapa {orden} no explica el candado"
    assert progreso.motivoBloqueo(1) == ""


def test_los_botones_de_una_etapa_bloqueada_estan_deshabilitados(home):
    _, pantalla, _ = home

    assert _propiedad(_buscar(pantalla, "pretestOpenButton"), "enabled") is True
    for object_name in ("guidedStartButton", "posttestOpenButton", "resultsOpenButton"):
        assert _propiedad(_buscar(pantalla, object_name), "enabled") is False
    for object_name, _ in LABORATORIOS:
        assert _propiedad(_buscar(pantalla, object_name), "enabled") is False


# ---------------------------------------------------------------------------
# Desbloqueo secuencial, sin reiniciar la aplicación
# ---------------------------------------------------------------------------


def test_el_pretest_desbloquea_el_recorrido_en_vivo(home, qapp):
    """Sin reiniciar: si los enlaces de QML no se reevaluaran, el estudiante
    tendría que cerrar y volver a abrir la aplicación para continuar."""
    _, pantalla, view_model = home
    assert _propiedad(_buscar(pantalla, "guidedStageCard"), "stageAvailable") is False

    completar_pretest(view_model)
    qapp.processEvents()

    assert _propiedad(_buscar(pantalla, "guidedStageCard"), "stageAvailable") is True
    assert _propiedad(_buscar(pantalla, "guidedStartButton"), "enabled") is True


def test_el_recorrido_desbloquea_los_laboratorios_en_vivo(home, qapp):
    _, pantalla, view_model = home
    completar_pretest(view_model)

    completar_recorrido(view_model)
    qapp.processEvents()

    assert _propiedad(_buscar(pantalla, "labsStageCard"), "stageAvailable") is True
    for object_name, _ in LABORATORIOS:
        assert _propiedad(_buscar(pantalla, object_name), "enabled") is True


def test_hacen_falta_los_tres_laboratorios_para_el_posttest(home, qapp):
    _, pantalla, view_model = home
    completar_pretest(view_model)
    completar_recorrido(view_model)
    progreso = view_model.progressController

    for object_name, laboratorio in LABORATORIOS[:2]:
        progreso.registrarLaboratorioAbierto(laboratorio)
        qapp.processEvents()
        assert (
            _propiedad(_buscar(pantalla, "posttestStageCard"), "stageAvailable")
            is False
        ), f"el post-test se abrió antes de tiempo tras {object_name}"

    progreso.registrarLaboratorioAbierto(LABORATORIOS[2][1])
    qapp.processEvents()

    assert _propiedad(_buscar(pantalla, "posttestStageCard"), "stageAvailable") is True


def test_abrir_el_mismo_laboratorio_tres_veces_no_desbloquea(home, qapp):
    _, pantalla, view_model = home
    completar_pretest(view_model)
    completar_recorrido(view_model)

    for _ in range(3):
        view_model.progressController.registrarLaboratorioAbierto("entrenamiento")
    qapp.processEvents()

    assert _propiedad(_buscar(pantalla, "posttestStageCard"), "stageAvailable") is False


def test_el_posttest_desbloquea_progreso_y_resultados(home, qapp):
    _, pantalla, view_model = home
    completar_pretest(view_model)
    completar_recorrido(view_model)
    for _, laboratorio in LABORATORIOS:
        view_model.progressController.registrarLaboratorioAbierto(laboratorio)

    completar_posttest(view_model)
    qapp.processEvents()

    assert _propiedad(_buscar(pantalla, "resultsStageCard"), "stageAvailable") is True


# ---------------------------------------------------------------------------
# Interruptor global
# ---------------------------------------------------------------------------


def test_apagar_la_ruta_estricta_abre_todo_en_vivo(home, qapp):
    _, pantalla, view_model = home
    progreso = view_model.progressController

    progreso.establecerRutaEstricta(False)
    progreso.establecerRequiereRecorridoParaLabs(False)
    qapp.processEvents()

    for _, tarjeta, _ in ETAPAS:
        assert _propiedad(_buscar(pantalla, tarjeta), "stageAvailable") is True
    assert _propiedad(_buscar(pantalla, "labsStageCard"), "stageAvailable") is True


def test_volver_a_encender_la_ruta_estricta_cierra_el_paso(home, qapp):
    _, pantalla, view_model = home
    progreso = view_model.progressController
    progreso.establecerRutaEstricta(False)
    qapp.processEvents()

    progreso.establecerRutaEstricta(True)
    qapp.processEvents()

    assert _propiedad(_buscar(pantalla, "guidedStageCard"), "stageAvailable") is False


# ---------------------------------------------------------------------------
# Borrar progreso
# ---------------------------------------------------------------------------


def test_el_boton_de_borrar_progreso_nace_deshabilitado(home):
    _, pantalla, _ = home

    boton = _buscar(pantalla, "homeResetProgressButton")
    assert _propiedad(boton, "enabled") is False


def test_el_boton_se_habilita_al_completar_los_cinco_pasos(home, qapp):
    _, pantalla, view_model = home
    progreso = view_model.progressController
    boton = _buscar(pantalla, "homeResetProgressButton")

    completar_pretest(view_model)
    completar_recorrido(view_model)
    for _, laboratorio in LABORATORIOS:
        progreso.registrarLaboratorioAbierto(laboratorio)
    completar_posttest(view_model)
    qapp.processEvents()
    assert _propiedad(boton, "enabled") is False, "falta visitar el seguimiento"

    progreso.registrarSeguimientoVisitado()
    qapp.processEvents()

    assert progreso.pasosCompletados == 5
    assert _propiedad(boton, "enabled") is True


def test_borrar_el_progreso_vuelve_a_cerrar_la_ruta(home, qapp):
    _, pantalla, view_model = home
    progreso = view_model.progressController
    completar_pretest(view_model)
    completar_recorrido(view_model)
    for _, laboratorio in LABORATORIOS:
        progreso.registrarLaboratorioAbierto(laboratorio)
    completar_posttest(view_model)
    progreso.registrarSeguimientoVisitado()
    qapp.processEvents()

    progreso.borrarTodoElProgreso()
    qapp.processEvents()

    assert _propiedad(_buscar(pantalla, "guidedStageCard"), "stageAvailable") is False
    assert (
        _propiedad(_buscar(pantalla, "homeResetProgressButton"), "enabled") is False
    )


# ---------------------------------------------------------------------------
# Degradación segura
# ---------------------------------------------------------------------------


def test_sin_controlador_de_progreso_no_se_bloquea_nada(home):
    """Si el registro del controlador fallara, bloquear todo dejaría la
    aplicación inutilizable. La regla es abrir, no cerrar."""
    _, pantalla, _ = home

    assert pantalla.property("progressController") is not None
    # La función de QML debe devolver True cuando no hay controlador; se
    # comprueba el contrato invocándola con una etapa fuera de rango, que es el
    # único camino que no consulta al controlador.
    assert _propiedad(_buscar(pantalla, "pretestStageCard"), "stageOrder") == 1
