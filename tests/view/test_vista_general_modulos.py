"""La vista general conceptual cubre cada paso de cada módulo, igual que la del 3."""

from __future__ import annotations

from pathlib import Path

import pytest
from PySide6.QtCore import QObject, QUrl
from PySide6.QtQml import QQmlComponent, QQmlEngine
from PySide6.QtQuick import QQuickItem

from viewmodel.module_laboratory_controller import _module_steps

ROOT = Path(__file__).resolve().parents[2]
MODULES = ("module_1", "module_2", "module_4", "module_5", "module_6", "module_7", "module_8")

HOST = """\
import QtQuick
import QtQuick.Controls
import "components" as Components

ApplicationWindow {
    width: %d
    height: 760
    visible: false

    Components.ModuleOverviewScene {
        objectName: "escena"
        anchors.fill: parent
        moduleId: "module_1"
        stepId: "text"
        active: true
        reducedMotion: true
    }
}
"""


def _errores(component):
    return "\n".join(error.toString() for error in component.errors())


@pytest.fixture(params=[1100, 700], ids=["ancha", "compacta"])
def escena(qapp, request):
    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(
        (HOST % request.param).encode(),
        QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "VistaGeneralHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errores(component)
    window = component.create()
    assert window is not None, _errores(component)
    scene = window.findChild(QQuickItem, "escena")
    yield scene
    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def _descendientes(item):
    result = {}
    for child in item.childItems():
        if child.objectName():
            result[child.objectName()] = child
        result.update(_descendientes(child))
    return result


def _pasos(module_id):
    pasos = {}
    for mode in ("inference", "training"):
        for step in _module_steps(module_id, mode):
            pasos[(mode, step["id"])] = step
    return pasos


@pytest.mark.parametrize("module_id", MODULES)
def test_cada_paso_tiene_su_definicion_y_su_grafico(qapp, escena, module_id):
    escena.setProperty("moduleId", module_id)
    contratos = {}
    for (mode, step_id), _step in _pasos(module_id).items():
        escena.setProperty("trainingMode", mode == "training")
        escena.setProperty("stepId", step_id)
        qapp.processEvents()

        definicion = (
            str(escena.property("stageTitle")),
            str(escena.property("stageQuestion")),
            str(escena.property("stageInput")),
            str(escena.property("stageAction")),
            str(escena.property("stageOutput")),
            str(escena.property("stageTakeaway")),
        )
        assert all(definicion), (module_id, step_id)
        assert "Self-Attention" not in definicion[0], (module_id, step_id)
        contratos[step_id, mode] = definicion
        kind = str(escena.property("stageKind"))
        assert kind != "input", (module_id, step_id)
        assert _hay_pintor(qapp, escena, kind), (module_id, step_id, kind)

    # Dos modos pueden compartir una definición, dos pasos distintos no.
    por_paso = {}
    for (step_id, _mode), definicion in contratos.items():
        por_paso.setdefault(definicion, set()).add(step_id)
    assert all(len(pasos) == 1 for pasos in por_paso.values()), por_paso


def _hay_pintor(qapp, escena, kind):
    from PySide6.QtCore import Q_ARG, Q_RETURN_ARG, QMetaObject

    try:
        return bool(
            QMetaObject.invokeMethod(
                escena,
                "hasPainter",
                Q_RETURN_ARG("QVariant"),
                Q_ARG("QVariant", kind),
            )
        )
    finally:
        qapp.processEvents()


@pytest.mark.parametrize("module_id", MODULES)
def test_la_ubicacion_se_adapta_al_modulo(qapp, escena, module_id):
    escena.setProperty("moduleId", module_id)
    qapp.processEvents()

    titulo = str(escena.property("locationTitle"))
    assert titulo.startswith("UBICACIÓN DENTRO DE")
    assert "SELF-ATTENTION" not in titulo
    momentos = escena.property("globalMoments").toVariant()
    assert len(momentos) == 4
    assert all(momento["label"] != "Q / K / V" for momento in momentos)
    assert 0 <= int(escena.property("globalPhase")) < len(momentos)


@pytest.mark.parametrize("module_id", MODULES)
def test_las_tarjetas_no_se_enciman_y_la_ubicacion_no_es_un_boton(
    qapp, escena, module_id
):
    escena.setProperty("moduleId", module_id)
    primer_paso = next(iter(_pasos(module_id).values()))
    escena.setProperty("stepId", primer_paso["id"])
    for _ in range(4):
        qapp.processEvents()

    nombres = _descendientes(escena)
    for nombre in ("Question", "Input", "Action", "Output"):
        assert f"moduleOverviewStage{nombre}" in nombres
    assert nombres["moduleOverviewOverviewFlow"].property("interactive") is False
    assert "no es un botón" in str(
        nombres["moduleOverviewLocationHint"].property("text")
    )
    cartas = [nombres[f"moduleOverviewStage{n}"] for n in ("Input", "Action", "Output")]
    cajas = [carta.mapRectToItem(escena, carta.boundingRect()) for carta in cartas]
    for indice, primera in enumerate(cajas):
        assert primera.width() > 0 and primera.height() > 0
        for segunda in cajas[indice + 1 :]:
            cruce = primera.intersected(segunda)
            assert cruce.width() <= 1 or cruce.height() <= 1


def test_el_modulo_3_no_cambia_de_nombres_ni_de_ubicacion(qapp, escena):
    escena.setProperty("moduleId", "module_3")
    escena.setProperty("stepId", "qkv")
    qapp.processEvents()

    assert escena.objectName() == "escena"
    assert escena.property("locationTitle") == "UBICACIÓN DENTRO DE SELF-ATTENTION"
    nombres = _descendientes(escena)
    assert "selfAttentionStageGraphic" in nombres
    assert isinstance(nombres["selfAttentionStageGraphic"], QObject)


VISUALIZACION_HOST = b"""\
import QtQuick
import QtQuick.Controls
import "components" as Components

ApplicationWindow {
    width: 1100
    height: 760
    visible: false

    Components.ModuleLaboratoryVisualization {
        objectName: "visual"
        anchors.fill: parent
        moduleId: "module_4"
        conceptualOverview: true
        mode: "inference"
        analysis: ({})
        step: ({ id: "split", title: "Separacion", visual: "multi_head" })
    }
}
"""


def test_la_pantalla_abre_la_vista_conceptual_y_conserva_los_datos_del_modelo(qapp):
    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(
        VISUALIZACION_HOST,
        QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "VisualizacionHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errores(component)
    window = component.create()
    assert window is not None, _errores(component)
    visual = window.findChild(QQuickItem, "visual")
    loader = window.findChild(QQuickItem, "moduleLabSpecializedLoader")
    for _ in range(3):
        qapp.processEvents()

    assert loader.property("item").objectName() == "moduleLabConceptualOverviewView"

    visual.setProperty("showCapturedData", True)
    for _ in range(3):
        qapp.processEvents()
    assert loader.property("item").objectName() == "moduleLabMultiHeadView"

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_cada_paso_tiene_un_experimento_propio():
    tabla = (ROOT / "view" / "qml" / "components" / "LaboratoryExperiments.js").read_text(
        encoding="utf-8"
    )
    for module_id in MODULES:
        inicio = tabla.index(f"    {module_id}: {{")
        fin = tabla.find("\n    },", inicio)
        bloque = tabla[inicio:fin]
        for _mode, step_id in _pasos(module_id):
            assert f"        {step_id}:" in bloque, (module_id, step_id)
