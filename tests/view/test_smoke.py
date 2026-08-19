"""Pruebas de humo del flujo QML de configuración y teoría contextual."""

from __future__ import annotations

import os
from pathlib import Path

# Deben establecerse antes de que pytest-qt construya QApplication.
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")

import pytest
import torch
from PySide6.QtCore import Q_ARG, QMetaObject, QObject, Qt, QUrl
from PySide6.QtQml import QJSValue, QQmlComponent, QQmlEngine

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from viewmodel import main_viewmodel as modulo_main_viewmodel
from viewmodel.main_viewmodel import MainViewModel


RAIZ_PROYECTO = Path(__file__).resolve().parents[2]
HOST_SETUP = b"""\
import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {
    width: 1280
    height: 820
    visible: false

    StackView {
        id: navigation
        anchors.fill: parent
    }

    Screens.SetupScreen {
        anchors.fill: parent
        stackView: navigation
    }
}
"""
HOST_TRAINING = b"""\
import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {
    width: 1280
    height: 820
    visible: false

    StackView {
        id: navigation
        anchors.fill: parent
    }

    Screens.TrainingScreen {
        anchors.fill: parent
        stackView: navigation
    }
}
"""


class _TokenizerPrueba:
    tipo_encoding = 1
    vocab_size = 97

    def encode(self, _texto):
        return [1, 2]

    def decode(self, _tokens):
        return "prueba"


def _errores(component: QQmlComponent) -> str:
    return "\n".join(error.toString() for error in component.errors())


def _como_python(valor):
    return valor.toVariant() if isinstance(valor, QJSValue) else valor


def _invocar(objeto: QObject, metodo: str, argumento=None) -> None:
    if argumento is None:
        ejecutado = QMetaObject.invokeMethod(
            objeto, metodo, Qt.ConnectionType.DirectConnection
        )
    else:
        ejecutado = QMetaObject.invokeMethod(
            objeto,
            metodo,
            Qt.ConnectionType.DirectConnection,
            Q_ARG("QVariant", argumento),
        )
    assert ejecutado, f"No se pudo invocar {metodo}"


@pytest.fixture
def setup_qml(qapp):
    engine = QQmlEngine()
    view_model = MainViewModel()
    engine.rootContext().setContextProperty("mainViewModel", view_model)

    component = QQmlComponent(engine)
    component.setData(
        HOST_SETUP,
        QUrl.fromLocalFile(str(RAIZ_PROYECTO / "view" / "qml" / "SmokeHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errores(component)

    window = component.create()
    assert window is not None, _errores(component)
    qapp.processEvents()

    yield window, view_model

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


@pytest.fixture
def training_qml(qapp, monkeypatch):
    monkeypatch.setattr(modulo_main_viewmodel, "DISPOSITIVO", torch.device("cpu"))

    engine = QQmlEngine()
    view_model = MainViewModel()
    config = ConfiguracionTransformer(
        tamano_vocabulario=100,
        dimension_modelo=32,
        num_cabezas=4,
        num_capas=1,
        dimension_ff=64,
        longitud_maxima_secuencia=16,
        dropout=0.1,
    )
    view_model._instalar_modelo(Transformer(config), _TokenizerPrueba())
    engine.rootContext().setContextProperty("mainViewModel", view_model)

    component = QQmlComponent(engine)
    component.setData(
        HOST_TRAINING,
        QUrl.fromLocalFile(str(RAIZ_PROYECTO / "view" / "qml" / "SmokeHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errores(component)

    window = component.create()
    assert window is not None, _errores(component)
    qapp.processEvents()

    yield window

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_seleccionar_bloque_muestra_teoria_y_permite_deseleccionar(
    setup_qml, qapp
):
    window, _ = setup_qml
    diagram = window.findChild(QObject, "setupTransformerDiagram")
    panel = window.findChild(QObject, "setupContextPanel")
    training_parameters = window.findChild(QObject, "trainingParametersCard")

    assert diagram is not None
    assert panel is not None
    assert training_parameters is not None
    assert panel.property("visible") is False
    assert training_parameters.property("visible") is True

    _invocar(diagram, "selectComponent", "input_embedding")
    qapp.processEvents()

    concepto = _como_python(panel.property("concepto"))
    assert panel.property("visible") is True
    assert concepto["id"] == "embeddings"
    assert concepto["componente_id"] == "input_embedding"
    assert concepto["explanation"]
    # Los parámetros de entrenamiento ya no dependen de la selección.
    assert training_parameters.property("visible") is True

    # El segundo clic sobre el mismo bloque alterna de vuelta a la vista general.
    _invocar(diagram, "selectComponent", "input_embedding")
    qapp.processEvents()
    assert panel.property("visible") is False

    _invocar(diagram, "selectComponent", "softmax")
    qapp.processEvents()
    concepto = _como_python(panel.property("concepto"))
    assert concepto["id"] == "softmax_final"

    _invocar(diagram, "clearSelection")
    qapp.processEvents()
    assert panel.property("visible") is False


def test_error_de_cabezas_desaparece_al_corregir_configuracion(
    setup_qml, qapp
):
    window, view_model = setup_qml
    screen = window.findChild(QObject, "setupScreen")
    controller = view_model.setupController

    assert screen is not None
    assert controller.configuracionValida is True
    assert screen.property("mensajeErrorVisible") == ""

    controller.establecer_num_cabezas(3)  # 64 no es divisible entre 3
    qapp.processEvents()

    assert controller.configuracionValida is False
    assert "divisible" in screen.property("mensajeErrorVisible")

    controller.establecer_num_cabezas(4)
    qapp.processEvents()

    assert controller.configuracionValida is True
    assert controller.errorConfiguracion == ""
    assert screen.property("mensajeErrorVisible") == ""


def test_entrenamiento_consulta_la_misma_teoria_del_json(training_qml, qapp):
    diagram = training_qml.findChild(QObject, "trainingTransformerDiagram")
    panel = training_qml.findChild(QObject, "trainingContextPanel")

    assert diagram is not None
    assert panel is not None
    assert panel.property("visible") is False

    _invocar(diagram, "selectComponent", "decoder_masked_attention")
    qapp.processEvents()

    concepto = _como_python(panel.property("concepto"))
    assert panel.property("visible") is True
    assert concepto["id"] == "por_que_mascara"
    assert concepto["componente_id"] == "decoder_masked_attention"

    _invocar(diagram, "clearSelection")
    qapp.processEvents()
    assert panel.property("visible") is False
