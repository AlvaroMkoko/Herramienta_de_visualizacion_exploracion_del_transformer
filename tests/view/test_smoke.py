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
from PySide6.QtQuick import QQuickItem

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
    window._test_view_model = view_model
    qapp.processEvents()

    yield window

    window.deleteLater()
    engine.deleteLater()
    qapp.processEvents()


def test_seleccionar_bloque_espera_el_boton_para_abrir_teoria(
    setup_qml, qapp
):
    window, _ = setup_qml
    diagram = window.findChild(QObject, "setupTransformerDiagram")
    summary = window.findChild(QObject, "setupConceptSummary")
    open_button = window.findChild(QObject, "setupOpenTheoryButton")
    panel = window.findChild(QObject, "setupContextPanel")
    modal = window.findChild(QObject, "setupTheoryModal")
    training_parameters = window.findChild(QObject, "trainingParametersCard")

    assert diagram is not None
    assert summary is not None
    assert open_button is not None
    assert panel is not None
    assert modal is not None
    assert training_parameters is not None
    assert panel.property("visible") is False
    assert modal.property("visible") is False
    assert training_parameters.property("visible") is True

    _invocar(diagram, "selectComponent", "input_embedding")
    qapp.processEvents()

    concepto = _como_python(summary.property("concepto"))
    assert summary.property("visible") is True
    assert panel.property("visible") is False
    assert modal.property("visible") is False
    assert concepto["id"] == "embeddings"
    assert concepto["componente_id"] == "input_embedding"
    assert concepto["short_description"]
    # La explicación grande solo se abre mediante el botón de la selección.
    _invocar(summary, "requestOpen")
    qapp.processEvents()

    concepto = _como_python(panel.property("concepto"))
    assert panel.property("visible") is True
    assert modal.property("visible") is True
    assert modal.property("width") >= 700
    assert modal.property("height") >= 500
    assert concepto["id"] == "embeddings"
    assert concepto["componente_id"] == "input_embedding"
    assert concepto["explanation"]
    # Los parámetros de entrenamiento ya no dependen de la selección.
    assert training_parameters.property("visible") is True

    # El segundo clic sobre el mismo bloque alterna de vuelta a la vista general.
    _invocar(diagram, "selectComponent", "input_embedding")
    qapp.processEvents()
    assert panel.property("visible") is False
    assert summary.property("visible") is False

    _invocar(diagram, "selectComponent", "softmax")
    qapp.processEvents()
    concepto = _como_python(summary.property("concepto"))
    assert modal.property("visible") is False
    assert concepto["id"] == "softmax_final"

    _invocar(diagram, "clearSelection")
    qapp.processEvents()
    assert panel.property("visible") is False
    assert modal.property("visible") is False


def test_configuracion_muestra_el_primer_paso_del_laboratorio(setup_qml):
    window, _ = setup_qml
    progress = window.findChild(QObject, "setupLaboratoryProgress")

    assert progress is not None
    assert progress.property("currentStep") == 0
    assert progress.property("totalSteps") == 3
    assert progress.property("currentStepTitle") == "Configuración"


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


def test_entrenamiento_desacopla_la_explicacion_del_bloque_del_transformer(
    training_qml, qapp, qtbot
):
    training_qml.show()
    qapp.processEvents()
    diagram = training_qml.findChild(QObject, "trainingTransformerDiagram")
    detail_panel = training_qml.findChild(QObject, "trainingComponentDetailPanel")
    detail_tab = training_qml.findChild(QObject, "trainingComponentDetailTab")
    summary = training_qml.findChild(QObject, "trainingConceptSummary")
    open_button = training_qml.findChild(QObject, "trainingOpenTheoryButton")
    modal = training_qml.findChild(QObject, "trainingTheoryModal")
    panel = training_qml.findChild(QObject, "trainingContextPanel")
    detached_window = training_qml.findChild(
        QObject, "trainingDetachedTransformerExplanationWindow"
    )
    detached_panel = training_qml.findChild(
        QObject, "trainingDetachedTransformerExplanationPanel"
    )
    detached_button = training_qml.findChild(
        QObject, "trainingOpenDetachedTransformerExplanationButton"
    )

    assert diagram is not None
    assert detail_panel is not None
    assert detail_tab is not None
    assert summary is not None
    assert open_button is not None
    assert modal is not None
    assert panel is not None
    assert detached_window is not None
    assert detached_panel is not None
    assert detached_button is not None
    assert panel.property("visible") is False
    assert detail_panel.property("visible") is False
    assert detail_tab.property("enabled") is False
    assert detached_window.property("visible") is False
    diagram_height = diagram.property("height")

    _invocar(diagram, "selectComponent", "decoder_masked_attention")
    qtbot.wait(80)
    qapp.processEvents()

    concepto = _como_python(summary.property("concepto"))
    concepto_aparte = _como_python(detached_panel.property("concepto"))
    assert detail_panel.property("visible") is False
    assert detail_tab.property("enabled") is True
    assert detail_tab.property("checked") is False
    assert diagram.property("height") == diagram_height
    assert detached_window.property("visible") is True
    assert detached_panel.property("visible") is True
    assert detached_button.property("visible") is True
    assert panel.property("visible") is False
    assert modal.property("visible") is False
    assert concepto["id"] == "por_que_mascara"
    assert concepto["componente_id"] == "decoder_masked_attention"
    assert concepto_aparte["id"] == "por_que_mascara"

    screen = training_qml.findChild(QObject, "trainingScreen")
    _invocar(screen, "cerrarExplicacionTransformerAparte")
    qtbot.wait(40)
    qapp.processEvents()
    assert detached_window.property("visible") is False

    _invocar(summary, "requestOpen")
    qtbot.wait(60)
    qapp.processEvents()
    assert detached_window.property("visible") is True
    assert panel.property("visible") is False

    _invocar(diagram, "clearSelection")
    qapp.processEvents()
    assert detail_panel.property("visible") is False
    assert detail_tab.property("checked") is False
    assert detached_window.property("visible") is False
    assert panel.property("visible") is False


def test_entrenamiento_muestra_el_segundo_paso_del_laboratorio(training_qml, qapp):
    progress = training_qml.findChild(QObject, "trainingLaboratoryProgress")
    journey = training_qml.findChild(QObject, "trainingJourney")
    screen = training_qml.findChild(QObject, "trainingScreen")
    summary_strip = training_qml.findChild(QObject, "trainingSummaryStrip")

    assert progress is not None
    assert journey is not None
    assert screen is not None
    assert summary_strip is not None
    assert progress.property("currentStep") == 1
    assert progress.property("totalSteps") == 3
    assert progress.property("currentStepTitle") == "Entrenamiento"
    assert journey.property("stageIndex") == 0

    training_qml.resize(2560, 1640)
    qapp.processEvents()
    assert screen.property("leftSx") <= 1.10
    assert screen.property("leftSy") <= 1.08
    assert journey.property("sx") <= 1.10
    assert journey.property("sy") <= 1.08
    assert summary_strip.property("height") < 70


def test_explicacion_del_entrenamiento_se_desacopla_y_distingue_backward_de_step(
    training_qml, qapp, qtbot
):
    training_qml.show()
    qapp.processEvents()

    journey = training_qml.findChild(QObject, "trainingJourney")
    viewport = training_qml.findChild(QQuickItem, "trainingJourneyViewport")
    panel = training_qml.findChild(QQuickItem, "trainingExplanationPanel")
    dock = training_qml.findChild(QQuickItem, "trainingExplanationDock")
    detached_window = training_qml.findChild(
        QObject, "trainingDetachedExplanationWindow"
    )
    detach_button = training_qml.findChild(
        QObject, "trainingDetachExplanationButton"
    )
    no_update = training_qml.findChild(QObject, "trainingBackpropNoUpdate")
    update_notice = training_qml.findChild(
        QObject, "trainingOptimizerUpdateNotice"
    )

    assert all(
        item is not None
        for item in (
            journey,
            viewport,
            panel,
            dock,
            detached_window,
            detach_button,
            no_update,
            update_notice,
        )
    )
    assert journey.property("explanationVisible") is False
    assert dock.property("visible") is False
    full_viewport_width = viewport.width()

    _invocar(journey, "toggleExplanation")
    qtbot.wait(80)
    qapp.processEvents()

    assert journey.property("explanationVisible") is True
    assert journey.property("explanationDetached") is True
    assert detached_window.property("visible") is True
    assert panel.property("visible") is True
    assert panel.window() == detached_window
    assert viewport.width() >= full_viewport_width - 1

    _invocar(journey, "setStage", 9)
    qapp.processEvents()
    stage = _como_python(journey.property("stage"))
    assert "loss.backward()" in stage["action"]
    assert "optimizer.step()" in stage["purpose"]
    assert no_update.property("visible") is True

    _invocar(journey, "setStage", 11)
    qapp.processEvents()
    assert update_notice.property("visible") is True

    _invocar(journey, "closeExplanation")
    qtbot.wait(50)
    qapp.processEvents()
    assert journey.property("explanationVisible") is False
    assert journey.property("explanationDetached") is False
    assert detached_window.property("visible") is False


def test_recorrido_guiado_recibe_un_batch_real_y_recorre_sus_escenas(
    training_qml, qapp, qtbot
):
    journey = training_qml.findChild(QObject, "trainingJourney")
    controller = training_qml._test_view_model.trainingController
    training_qml.show()
    qapp.processEvents()

    def proveedor():
        return [
            (
                torch.tensor([[1, 2, 3]], dtype=torch.long),
                torch.tensor([[98, 4, 5]], dtype=torch.long),
                torch.tensor([[4, 5, 99]], dtype=torch.long),
            )
        ]

    with qtbot.waitSignal(controller.entrenamiento_completo, timeout=10000):
        controller.iniciar_entrenamiento(
            proveedor,
            num_epocas=1,
            tasa_aprendizaje=1e-3,
            incluir_tensores_crudos=False,
        )
    qapp.processEvents()

    snapshot = _como_python(journey.property("snapshot"))
    viewport = training_qml.findChild(QObject, "trainingJourneyViewport")
    scenes = training_qml.findChild(QObject, "trainingJourneyScenes")
    shift_rows = training_qml.findChild(QObject, "teacherForcingRows")
    shift_alignment = training_qml.findChild(QObject, "teacherForcingAlignment")
    assert journey.property("dataAvailable") is True
    assert viewport is not None
    assert scenes is not None
    assert shift_rows is not None
    assert shift_alignment is not None
    assert journey.property("height") > 100
    assert viewport.property("height") > 100
    assert snapshot["ejemplo"]["tokens_decoder"][0]["texto"] == "<BOS>"
    assert snapshot["ejemplo"]["tokens_objetivo"][-1]["texto"] == "<EOS>"
    assert [len(pair["prefijo"]) for pair in snapshot["ejemplo"]["pares_teacher_forcing"]] == [1, 2, 3]
    assert snapshot["predicciones_por_posicion"]
    assert snapshot["actualizaciones_parametros"]

    expected_scope = [
        (0, "DATOS"),
        (1, "ENCODER"),
        (1, "ENCODER"),
        (1, "ENCODER"),
        (2, "DECODER"),
        (2, "DECODER"),
        (2, "PUENTE · ENCODER → DECODER"),
        (2, "DECODER"),
        (3, "APRENDIZAJE"),
        (3, "APRENDIZAJE"),
        (3, "APRENDIZAJE"),
        (3, "APRENDIZAJE"),
        (3, "APRENDIZAJE"),
    ]
    action_card = training_qml.findChild(QObject, "trainingStageAction")
    input_card = training_qml.findChild(QObject, "trainingStageInput")
    output_card = training_qml.findChild(QObject, "trainingStageOutput")
    purpose_card = training_qml.findChild(QObject, "trainingStagePurpose")
    detail_text = training_qml.findChild(QObject, "trainingStageDetail")
    formula_text = training_qml.findChild(QObject, "trainingStageFormulaText")
    assert action_card is not None
    assert input_card is not None
    assert output_card is not None
    assert purpose_card is not None
    assert detail_text is not None
    assert formula_text is not None

    for stage in range(13):
        _invocar(journey, "setStage", stage)
        qapp.processEvents()
        scene = training_qml.findChild(QObject, f"trainingScene{stage}")
        stage_data = _como_python(journey.property("stage"))
        assert scene is not None
        assert scenes.property("currentIndex") == stage
        assert journey.property("chapterIndex") == expected_scope[stage][0]
        assert journey.property("scopeLabel") == expected_scope[stage][1]
        assert all(
            str(stage_data[field]).strip()
            for field in (
                "action",
                "input",
                "output",
                "purpose",
                "intuitive",
                "technical",
                "mathematical",
                "formula",
            )
        )
        assert action_card.property("value") == stage_data["action"]
        assert input_card.property("value") == stage_data["input"]
        assert output_card.property("value") == stage_data["output"]
        assert purpose_card.property("value") == stage_data["purpose"]
        assert 0 < scene.property("width") <= viewport.property("width")
        assert 0 < scene.property("height") <= viewport.property("height")

        journey.setProperty("explanationDetailsExpanded", True)
        for level, field in enumerate(("intuitive", "technical", "mathematical")):
            journey.setProperty("explanationLevel", level)
            qapp.processEvents()
            assert detail_text.property("text") == stage_data[field]
        assert str(formula_text.property("text")).strip()

    _invocar(journey, "setStage", 6)
    qapp.processEvents()
    attention_scene = training_qml.findChild(QObject, "trainingScene6")
    assert attention_scene is not None
    assert attention_scene.property("summaryMode") is True
    assert attention_scene.property("effectiveFocusedQuery") == 0
    assert attention_scene.property("visibleConnectionCount") <= attention_scene.property(
        "maximumVisibleConnections"
    )
    attention_scene.setProperty("hoveredQuery", 1)
    qapp.processEvents()
    assert attention_scene.property("effectiveFocusedQuery") == 1
    attention_scene.setProperty("hoveredQuery", -1)
    qapp.processEvents()
    assert attention_scene.property("effectiveFocusedQuery") == 0

    # Caso denso equivalente a una frase real: los chips deben repartirse en
    # su carril y la vista inicial no debe volver a dibujar las 96 aristas.
    dense_matrix = []
    for query in range(12):
        raw = [1 + ((query * 3 + key * 5) % 11) for key in range(8)]
        total = sum(raw)
        dense_matrix.append([value / total for value in raw])
    attention_scene.setProperty(
        "attentionData",
        {
            "flujo": {
                "matrices": [dense_matrix],
                "inicio_queries": 0,
                "inicio_keys": 0,
            }
        },
    )
    attention_scene.setProperty(
        "queryTokens",
        [
            {"texto": f"query_extensa_{index}", "posicion": index}
            for index in range(12)
        ],
    )
    attention_scene.setProperty(
        "keyTokens",
        [
            {"texto": f"key_extensa_{index}", "posicion": index}
            for index in range(8)
        ],
    )
    qapp.processEvents()
    assert attention_scene.property("queryCount") == 12
    assert attention_scene.property("keyCount") == 8
    assert attention_scene.property("visibleConnectionCount") <= 4
    assert attention_scene.property("minimumQueryChipGap") >= 4
    assert attention_scene.property("minimumKeyChipGap") >= 4

    _invocar(journey, "setStage", 12)
    assert journey.property("stageIndex") == 12
    assert shift_alignment.property("height") > 0
    assert shift_rows.property("width") > 0
    assert shift_rows.property("height") > 0
    assert shift_rows.property("count") == 3
    assert shift_rows.property("contentHeight") <= shift_rows.property("height")


def test_ayuda_inline_de_perdida_abre_el_glosario_en_modal(
    training_qml, qapp
):
    help_button = training_qml.findChild(QObject, "trainingLossHelpButton")
    modal = training_qml.findChild(QObject, "trainingTheoryModal")
    panel = training_qml.findChild(QObject, "trainingContextPanel")

    assert help_button is not None
    assert modal is not None
    assert panel is not None
    assert 22 <= help_button.property("width") <= 30
    assert 22 <= help_button.property("height") <= 30

    _invocar(help_button, "requestHelp")
    qapp.processEvents()

    concepto = _como_python(panel.property("concepto"))
    assert modal.property("visible") is True
    assert panel.property("visible") is True
    assert concepto["id"] == "cross_entropy"
    assert concepto["title"] == "Cross Entropy Loss"
    assert concepto["explanation"]


def test_selector_de_activacion_abre_la_explicacion_de_todas_las_opciones(
    setup_qml, qapp
):
    window, _ = setup_qml
    help_button = window.findChild(QObject, "conceptHelp_activation_functions")
    panel = window.findChild(QObject, "setupContextPanel")

    assert help_button is not None
    assert panel is not None

    _invocar(help_button, "requestHelp")
    qapp.processEvents()

    concepto = _como_python(panel.property("concepto"))
    assert concepto["id"] == "activation_functions"
    assert "ReLU, GELU y Swish" in concepto["title"]
