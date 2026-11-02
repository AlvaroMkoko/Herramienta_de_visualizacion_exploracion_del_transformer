"""Las mejoras para saber qué hacer a continuación, tras la prueba de usabilidad."""

from __future__ import annotations

from pathlib import Path

import pytest
from PySide6.QtCore import Q_ARG, Q_RETURN_ARG, QMetaObject, QObject, Qt, QUrl
from PySide6.QtQml import QQmlComponent, QQmlEngine
from PySide6.QtQuick import QQuickItem

from model.aprendizaje import LearningModuleCatalog, ModuleProgressRepository
from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from viewmodel.course_controller import CourseController
from viewmodel.main_viewmodel import MainViewModel
from viewmodel.model_library_controller import elegir_modelo_didactico

ROOT = Path(__file__).resolve().parents[2]


def _errores(component):
    return "\n".join(error.toString() for error in component.errors())


def _montar(qapp, host: bytes, nombre: str):
    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(host, QUrl.fromLocalFile(str(ROOT / "view" / "qml" / nombre)))
    assert component.status() != QQmlComponent.Status.Error, _errores(component)
    window = component.create()
    assert window is not None, _errores(component)
    for _ in range(3):
        qapp.processEvents()
    engine.componente = component  # sin esta referencia, Python destruye la ventana
    return engine, window


def _llamar(objeto, metodo, *args):
    resultado = QMetaObject.invokeMethod(
        objeto,
        metodo,
        Qt.ConnectionType.DirectConnection,
        Q_RETURN_ARG("QVariant"),
        *[Q_ARG("QVariant", arg) for arg in args],
    )
    return resultado.toVariant() if hasattr(resultado, "toVariant") else resultado


# ── Modelo didáctico ─────────────────────────────────────────────────────


def _archivo(tmp_path, nombre, tamano):
    ruta = tmp_path / nombre
    ruta.write_bytes(b"x" * tamano)
    return {"ruta": str(ruta), "compatible": True}


def test_se_elige_el_modelo_mas_ligero(tmp_path):
    modelos = [_archivo(tmp_path, "grande.tvismodel", 50), _archivo(tmp_path, "chico.tvismodel", 5)]

    assert elegir_modelo_didactico(modelos).endswith("chico.tvismodel")


def test_un_modelo_didactico_gana_aunque_pese_mas(tmp_path):
    modelos = [
        _archivo(tmp_path, "chico.tvismodel", 5),
        _archivo(tmp_path, "modelo_didactico.tvismodel", 50),
    ]

    assert elegir_modelo_didactico(modelos).endswith("modelo_didactico.tvismodel")


def test_no_se_elige_un_modelo_incompatible_ni_inexistente(tmp_path):
    incompatible = _archivo(tmp_path, "viejo.tvismodel", 5) | {"compatible": False}
    inexistente = {"ruta": str(tmp_path / "no_esta.tvismodel"), "compatible": True}

    assert elegir_modelo_didactico([incompatible, inexistente]) == ""
    assert elegir_modelo_didactico([]) == ""


# ── Guía de primer uso ───────────────────────────────────────────────────

GUIA_HOST = b"""\
import QtQuick
import QtQuick.Controls
import "components" as Components

ApplicationWindow {
    width: 1000
    height: 700
    visible: true
    Rectangle { id: objetivo; objectName: "objetivo"; x: 100; y: 80; width: 200; height: 60 }
    Components.GuidedTour {
        objectName: "guia"
        tourId: "prueba_guia"
        steps: [
            { "target": objetivo, "title": "Uno", "text": "Con objetivo" },
            { "title": "Dos", "text": "Sin objetivo", "preferences": true }
        ]
    }
}
"""


def test_la_guia_descubre_el_objetivo_y_se_recuerda_vista(qapp):
    engine, window = _montar(qapp, GUIA_HOST, "GuiaHost.qml")
    guia = window.findChild(QObject, "guia")

    guia.setProperty("running", False)
    _llamar(guia, "start")
    for _ in range(3):
        qapp.processEvents()

    assert guia.property("running") is True
    assert guia.property("hasSpotlight") is True
    foco = guia.property("spotlight")
    assert foco.x() < 100 and foco.width() > 200

    _llamar(guia, "advance", 1)
    for _ in range(3):
        qapp.processEvents()
    assert guia.property("hasSpotlight") is False

    _llamar(guia, "advance", 1)
    assert guia.property("running") is False
    assert _llamar(guia, "alreadySeen") is True

    _llamar(guia, "startIfNew")
    assert guia.property("running") is False

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


# ── Lección: términos y lectura por partes ───────────────────────────────

LECCION_HOST = b"""\
import QtQuick
import QtQuick.Controls
import "components" as Components

ApplicationWindow {
    id: ventana
    width: 1300
    height: 800
    visible: true
    property var pasos: []
    QtObject {
        id: recorrido
        property var steps: ventana.pasos
        property int currentIndex: 0
        property var currentStep: ventana.pasos.length ? ventana.pasos[currentIndex] : ({})
        property real uiScale: 1
        property var currentConceptDefinition: ({})
        property string currentTheoryConceptId: ""
        property bool currentHasCheck: true
        property bool currentAttempted: false
        property bool currentIsFocus: false
        property var checkResults: ({})
        property bool firstUseGuidance: true
    }
    Components.GuidedLessonView {
        objectName: "leccion"
        anchors.fill: parent
        tour: recorrido
    }
}
"""


@pytest.fixture
def leccion(qapp):
    engine, window = _montar(qapp, LECCION_HOST, "LeccionHost.qml")
    window.setProperty("pasos", LearningModuleCatalog().get("module_4")["guided_steps"])
    for _ in range(3):
        qapp.processEvents()
    vista = window.findChild(QObject, "leccion")
    _llamar(vista, "revelarInicio")
    qapp.processEvents()
    yield vista
    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_un_termino_se_enlaza_una_vez_y_da_su_definicion(leccion):
    marcado = str(_llamar(leccion, "marcarTerminos", "Una cabeza mira. Otra cabeza mira."))

    assert marcado.count("<a href=") == 1
    enlace = marcado.split('href="')[1].split('"')[0]
    assert "atenciones que corren en paralelo" in str(_llamar(leccion, "definicionDe", enlace))


def test_un_termino_no_se_enlaza_dentro_de_otra_palabra(leccion):
    assert "<a" not in str(_llamar(leccion, "marcarTerminos", "Las cabecitas de Xilófono"))


def test_el_texto_se_escapa_para_no_romper_el_formato(leccion):
    assert "1 &lt; 2" in str(_llamar(leccion, "marcarTerminos", "1 < 2"))


def test_la_leccion_se_descubre_por_partes(qapp, leccion):
    assert leccion.property("seccionRevelada") == 1
    assert _llamar(leccion, "revelada", 7) is False

    for _ in range(10):
        _llamar(leccion, "seguirLeyendo")

    assert leccion.property("seccionRevelada") == 7
    assert _llamar(leccion, "revelada", 7) is True


def test_la_comprobacion_no_se_pierde_al_terminar_de_leer(qapp, leccion):
    check = leccion.findChild(QQuickItem, "moduleGuidedCheck")
    assert check is not None

    for _ in range(6):
        _llamar(leccion, "seguirLeyendo")
    qapp.processEvents()

    assert check.isVisible()


# ── Letra y tema ─────────────────────────────────────────────────────────

MENU_HOST = b"""\
import QtQuick
import QtQuick.Controls
import "styles" as Style
import "components" as Components

ApplicationWindow {
    objectName: "ventanaMenu"
    width: 500
    height: 400
    visible: true
    property real escala: Style.Theme.escalaTexto
    function fijar(valor) { Style.Theme.escalaTexto = valor }
    Components.PreferencesMenu { objectName: "menu" }
}
"""


def test_el_tamano_de_letra_se_puede_cambiar(qapp):
    engine, window = _montar(qapp, MENU_HOST, "MenuHost.qml")

    _llamar(window, "fijar", 1.3)
    qapp.processEvents()
    assert window.property("escala") == pytest.approx(1.3)

    _llamar(window, "fijar", 1)
    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


# ── Preparar el modelo sin preguntar ─────────────────────────────────────


@pytest.fixture
def vista_modelo(monkeypatch):
    vm = MainViewModel()
    llamadas = {"cargar": [], "crear": 0}
    monkeypatch.setattr(
        vm._model_library_controller,
        "cargarModelo",
        lambda ruta: llamadas["cargar"].append(ruta),
    )

    def crear():
        llamadas["crear"] += 1

    monkeypatch.setattr(vm._setup_controller, "crear_modelo_async", crear)
    return vm, llamadas


def test_se_carga_un_modelo_guardado_si_hay(tmp_path, monkeypatch, vista_modelo):
    vm, llamadas = vista_modelo
    modelo = _archivo(tmp_path, "guardado.tvismodel", 5)
    monkeypatch.setattr(vm._model_library_controller, "obtenerModelos", lambda: [modelo])

    vm.prepararModeloLaboratorio()

    assert llamadas["cargar"] == [modelo["ruta"]]
    assert llamadas["crear"] == 0
    assert vm.preparandoModeloLaboratorio is True


def test_si_no_hay_modelo_guardado_se_crea_uno(monkeypatch, vista_modelo):
    vm, llamadas = vista_modelo
    monkeypatch.setattr(vm._model_library_controller, "obtenerModelos", lambda: [])

    vm.prepararModeloLaboratorio()

    assert llamadas["crear"] == 1


def test_si_falla_la_carga_se_crea_y_si_falla_se_avisa(tmp_path, monkeypatch, vista_modelo):
    vm, llamadas = vista_modelo
    modelo = _archivo(tmp_path, "danado.tvismodel", 5)
    monkeypatch.setattr(vm._model_library_controller, "obtenerModelos", lambda: [modelo])

    vm.prepararModeloLaboratorio()
    vm._model_library_controller.error.emit("archivo dañado")
    assert llamadas["crear"] == 1
    assert vm.preparandoModeloLaboratorio is True

    vm._setup_controller.error_configuracion.emit("sin red para el tokenizador")
    assert vm.preparandoModeloLaboratorio is False
    assert vm.errorModeloLaboratorio == "sin red para el tokenizador"


def test_un_error_ajeno_no_interrumpe_la_preparacion(vista_modelo):
    vm, llamadas = vista_modelo

    vm._model_library_controller.error.emit("otra operación")

    assert llamadas["crear"] == 0
    assert vm.preparandoModeloLaboratorio is False


# ── Pantalla del laboratorio en el primer uso ────────────────────────────

LABORATORIO_HOST = b"""\
import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {
    width: 1500
    height: 900
    visible: true
    StackView { id: navigation; anchors.fill: parent }
    Screens.ModuleLaboratoryScreen {
        anchors.fill: parent
        stackView: navigation
        moduleId: "module_3"
        firstUseGuidance: true
    }
}
"""


class _Tokenizador:
    vocab_size = 40

    def encode(self, texto):
        return [ord(caracter) % 30 for caracter in texto][:8]

    def decode(self, ids):
        return "".join(chr(97 + int(valor) % 26) for valor in ids)


def test_el_laboratorio_abre_ejecutado_y_dice_que_sigue(qapp, qtbot, tmp_path, monkeypatch):
    monkeypatch.setattr(CourseController, "REVIEW_MODE_UNLOCK_ALL", True)
    vm = MainViewModel()
    repositorio = ModuleProgressRepository(tmp_path / "avance.json")
    vm._course_controller._repository = repositorio
    vm._course_controller._state = repositorio.snapshot()
    configuracion = ConfiguracionTransformer(
        tamano_vocabulario=40,
        dimension_modelo=16,
        num_cabezas=4,
        num_capas=2,
        dimension_ff=32,
        longitud_maxima_secuencia=12,
        dropout=0.0,
        id_token_relleno=36,
    )
    vm.moduleLaboratoryController.set_model(Transformer(configuracion), _Tokenizador())

    engine = QQmlEngine()
    engine.rootContext().setContextProperty("mainViewModel", vm)
    component = QQmlComponent(engine)
    component.setData(
        LABORATORIO_HOST, QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "LaboratorioHost.qml"))
    )
    assert component.status() != QQmlComponent.Status.Error, _errores(component)
    window = component.create()
    assert window is not None, _errores(component)

    texto = window.findChild(QObject, "moduleLaboratoryNextStepText")
    # Se ejecuta solo: el alumno no tuvo que elegir un modelo ni presionar nada.
    qtbot.waitUntil(lambda: "elige qué crees que pasará" in str(texto.property("text")))
    assert "no se califica" in str(texto.property("text"))
    detalle = window.findChild(QObject, "moduleLaboratoryPracticeDetail")
    assert "Retos: 0 de 3" in str(detalle.property("text"))
    assert "Pendientes" in str(detalle.property("text"))

    # La guía aparece una vez listo el análisis.
    guia = window.findChild(QObject, "guidedTour")
    qtbot.waitUntil(lambda: guia.property("running") is True)
    _llamar(guia, "finish")

    # La frase y el ejemplo quedan a un clic.
    assert window.findChild(QObject, "moduleLaboratoryPhraseEditor").property("visible") is False
    assert window.findChild(QObject, "moduleLaboratoryStandardPracticeHost").property("visible") is False
    window.findChild(QObject, "moduleLaboratoryChangePhrase").clicked.emit()
    qapp.processEvents()
    assert window.findChild(QObject, "moduleLaboratoryPhraseEditor").property("visible") is True

    assert window.findChild(QObject, "homeButton") is not None

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()
