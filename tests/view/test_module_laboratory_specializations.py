"""Contrato visual de los ocho laboratorios especializados.

La mayor parte de estas pruebas se mantiene en la frontera publica del
componente: comprueba que el despachador carga exactamente una especializacion
por modulo y que el modo de entrenamiento activa su evidencia propia. Tambien
incluye una regresion geometrica puntual para impedir que la grafica de capas
vuelva a quedar sin ancho o fuera de su viewport.
"""

from __future__ import annotations

from difflib import SequenceMatcher
import os
from pathlib import Path
import re
import unicodedata

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

import pytest
from PySide6.QtCore import QObject, QPointF, QRectF, QSizeF, QUrl, qInstallMessageHandler
from PySide6.QtQml import QJSValue, QQmlComponent, QQmlEngine
from PySide6.QtQuick import QQuickItem

from model.aprendizaje import ModuleProgressRepository, ModuleQuestionBank
from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from viewmodel.course_controller import CourseController
from viewmodel.main_viewmodel import MainViewModel
from viewmodel.module_laboratory_controller import _module_steps


ROOT = Path(__file__).resolve().parents[2]


def _qml_value(value):
    """Normaliza objetos JavaScript que PySide convierte de forma contextual."""

    return value.toVariant() if isinstance(value, QJSValue) else value


def _comparable_question(text: str) -> str:
    text = unicodedata.normalize("NFKD", text.lower())
    text = text.encode("ascii", "ignore").decode("ascii")
    return " ".join(re.findall(r"[a-z0-9]+", text))

HOST = b"""\
import QtQuick
import QtQuick.Controls
import "components" as Components

ApplicationWindow {
    width: 1100
    height: 760
    visible: false

    Components.ModuleLaboratoryVisualization {
        id: visualization
        objectName: "specializedLaboratoryUnderTest"
        anchors.fill: parent
        moduleId: "module_1"
        mode: "inference"
        analysis: ({})
        step: ({
            title: "Paso de prueba",
            formula: "entrada -> operacion -> salida",
            explanation: "Explicacion pedagogica de la operacion.",
            input: "entrada",
            output: "salida",
            visual: "tokenization"
        })
    }
}
"""

SPECIALIZATIONS = {
    "module_1": ("tokenization", "moduleLabTokenizationView"),
    "module_2": ("embedding", "moduleLabEmbeddingView"),
    "module_3": ("attention", "moduleLabAttentionView"),
    "module_4": ("multi_head", "moduleLabMultiHeadView"),
    "module_5": ("encoder", "moduleLabEncoderView"),
    "module_6": ("decoder", "moduleLabDecoderView"),
    "module_7": ("output", "moduleLabOutputView"),
    "module_8": ("transformer", "moduleLabTransformerView"),
}

SCREEN_HOST = b"""\
import QtQuick
import QtQuick.Controls
import "screens" as Screens

ApplicationWindow {
    width: 1600
    height: 900
    visible: true
    StackView { id: navigation; anchors.fill: parent }
    Screens.ModuleLaboratoryScreen {
        anchors.fill: parent
        stackView: navigation
        moduleId: "module_3"
    }
}
"""

GUIDE_HOST = b"""\
import QtQuick
import QtQuick.Controls
import "components" as Components

ApplicationWindow {
    width: 720
    height: 900
    visible: false

    Components.LaboratoryAnimationGuide {
        objectName: "laboratoryGuideUnderTest"
        anchors.fill: parent
        moduleId: "module_1"
        mode: "inference"
        steps: []
        step: ({})
        demo: ({
            animation_explanation: "Animacion numerica de prueba",
            caption: "Los valores cambian fase por fase."
        })
    }
}
"""

LAYER_SKYSCRAPER_HOST = b"""\
import QtQuick
import QtQuick.Controls
import "components" as Components

ApplicationWindow {
    width: 1100
    height: 460
    visible: false

    Components.LayerSkyscraperScene {
        objectName: "layerSkyscraperUnderTest"
        anchors.fill: parent
        tokens: [
            { posicion: 0, texto: "uno" },
            { posicion: 1, texto: "dos" },
            { posicion: 2, texto: "tres" }
        ]
        trajectory: ({
            inicio_posicion: 0,
            varianza_conservada: 0.91,
            capas: [
                { capa: 0, puntos: [{ x: -1, y: 0 }, { x: 0, y: 1 }, { x: 1, y: 0 }] },
                { capa: 1, puntos: [{ x: -0.7, y: 0.2 }, { x: 0.2, y: 0.8 }, { x: 0.9, y: -0.2 }] },
                { capa: 2, puntos: [{ x: -0.4, y: 0.5 }, { x: 0.4, y: 0.4 }, { x: 0.7, y: -0.5 }] }
            ]
        })
    }
}
"""


class _ScreenTokenizer:
    vocab_size = 36

    def encode(self, _text):
        return [3, 7, 9, 11]

    def decode(self, ids):
        return f"t{ids[0]}"


def _errors(component: QQmlComponent) -> str:
    return "\n".join(error.toString() for error in component.errors())


@pytest.fixture
def specialized_visual(qapp):
    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(
        HOST,
        QUrl.fromLocalFile(
            str(ROOT / "view" / "qml" / "ModuleLaboratoryVisualizationHost.qml")
        ),
    )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    qapp.processEvents()

    visual = window.findChild(QObject, "specializedLaboratoryUnderTest")
    loader = window.findChild(QObject, "moduleLabSpecializedLoader")
    summary = window.findChild(QObject, "moduleLabStepSummary")
    evidence = window.findChild(QObject, "moduleLabTrainingEvidence")
    assert visual is not None
    assert loader is not None
    assert summary is not None
    assert evidence is not None

    yield window, visual, loader, evidence

    window.deleteLater()
    engine.deleteLater()


@pytest.fixture
def laboratory_guide(qapp):
    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(
        GUIDE_HOST,
        QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "LaboratoryGuideHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    qapp.processEvents()

    guide = window.findChild(QObject, "laboratoryGuideUnderTest")
    formula = window.findChild(QObject, "moduleLaboratoryGuideFormulaText")
    formula_reading = window.findChild(
        QObject, "moduleLaboratoryGuideFormulaReading"
    )
    observation = window.findChild(QObject, "moduleLaboratoryGuideObservation")
    input_output = window.findChild(QObject, "moduleLaboratoryGuideInputOutput")
    assert all(
        item is not None
        for item in (guide, formula, formula_reading, observation, input_output)
    )

    yield window, guide, formula, formula_reading, observation, input_output

    window.deleteLater()
    engine.deleteLater()


@pytest.mark.parametrize(
    ("module_id", "kind", "child_name"),
    [
        (module_id, kind, child_name)
        for module_id, (kind, child_name) in SPECIALIZATIONS.items()
    ],
)
def test_cada_modulo_carga_su_visualizacion_especializada(
    qapp, specialized_visual, module_id, kind, child_name
):
    _window, visual, loader, _evidence = specialized_visual

    visual.setProperty("moduleId", module_id)
    qapp.processEvents()

    assert visual.property("specializationKind") == kind
    loaded_item = loader.property("item")
    assert loaded_item is not None
    assert loaded_item.objectName() == child_name
    if module_id == "module_7":
        visual.setProperty(
            "analysis",
            {
                "candidates": [
                    {
                        "text": f"token_{index}",
                        "logit": 8 - index,
                        "probability": (8 - index) / 36,
                    }
                    for index in range(8)
                ]
            },
        )
        visual.setProperty(
            "step",
            {
                "title": "Logits del vocabulario",
                "visual": "output_projection",
                "panel_key": "logits",
            },
        )
        qapp.processEvents()
        simple_output = loaded_item.findChild(QObject, "simpleOutputStageScene")
        assert simple_output is not None
        assert len(simple_output.property("visibleCandidates").toVariant()) == 5
        assert simple_output.property("definition").toVariant()["kind"] == "logits"
    if module_id == "module_8":
        visual.setProperty(
            "stepIndex", 5
        )
        visual.setProperty(
            "step",
            {
                "title": "Pérdida",
                "visual": "transformer_loss",
                "panel_key": "loss_per_position",
            },
        )
        qapp.processEvents()
        simple_output = loaded_item.findChild(QObject, "simpleOutputStageScene")
        assert simple_output is not None
        assert simple_output.property("active") is True
        assert simple_output.property("definition").toVariant()["kind"] == "training"


@pytest.mark.parametrize(
    ("module_id", "mode", "step_id", "expected_kind"),
    [
        ("module_1", "inference", "no_grad", "process"),
        ("module_2", "inference", "position", "process"),
        ("module_2", "training", "dropout", "process"),
        ("module_3", "inference", "attention_input", "process"),
        ("module_3", "inference", "output", "process"),
        ("module_3", "training", "backward", "training"),
        ("module_5", "inference", "encoder_input", "process"),
        ("module_5", "inference", "encoder_attention", "process"),
        ("module_6", "inference", "decoder_prefix", "process"),
        ("module_8", "inference", "full_encoder", "process"),
    ],
)
def test_etapas_antes_ambiguas_usan_una_animacion_fiel_a_sus_datos(
    qapp,
    specialized_visual,
    module_id,
    mode,
    step_id,
    expected_kind,
):
    _window, visual, loader, _evidence = specialized_visual
    steps = _module_steps(module_id, mode)
    step = next(item for item in steps if item["id"] == step_id)

    visual.setProperty("moduleId", module_id)
    visual.setProperty("mode", mode)
    visual.setProperty("step", step)
    qapp.processEvents()

    loaded_item = loader.property("item")
    assert loaded_item is not None
    assert loaded_item.objectName() == "moduleLabSimpleStageView"
    simple_scene = loaded_item.findChild(QObject, "simpleOutputStageScene")
    assert simple_scene is not None
    definition = simple_scene.property("definition").toVariant()
    assert definition["kind"] == expected_kind
    if expected_kind == "process":
        assert definition["first"] == step["input"]
        assert definition["operation"] == step["title"]
        assert definition["last"] == step["output"]


def test_guia_explica_formula_entrada_salida_y_animacion_de_todas_las_etapas(
    qapp, laboratory_guide
):
    (
        _window,
        guide,
        formula,
        formula_reading,
        observation,
        input_output,
    ) = laboratory_guide

    checked = 0
    for module_number in range(1, 9):
        module_id = f"module_{module_number}"
        for mode in ("inference", "training"):
            steps = _module_steps(module_id, mode)
            guide.setProperty("moduleId", module_id)
            guide.setProperty("mode", mode)
            guide.setProperty("steps", steps)
            for index, step in enumerate(steps):
                scene_description = (
                    f"Escena verificada {module_id} {mode} {step['id']}"
                )
                guide.setProperty("stepIndex", index)
                guide.setProperty("step", step)
                guide.setProperty(
                    "demo",
                    {
                        "animation_explanation": scene_description,
                        "caption": "Los números corresponden a esta fórmula.",
                    },
                )
                qapp.processEvents()

                displayed_formula = str(formula.property("text")).replace(";\n", "; ")
                assert displayed_formula == step["formula"]
                reading = str(formula_reading.property("text"))
                assert reading.startswith("CÓMO LEERLA")
                assert "Lee la expresión de izquierda a derecha" not in reading
                assert scene_description in str(observation.property("body"))
                flow = str(input_output.property("text"))
                assert step["input"] in flow
                assert step["output"] in flow
                checked += 1

    # Evita que una colección accidentalmente vacía haga pasar la revisión.
    assert checked >= 100


def test_guia_muestra_una_lectura_lineal_y_pliega_los_datos_tecnicos(
    qapp, laboratory_guide
):
    window, guide, _formula, _reading, _observation, _flow = laboratory_guide
    idea = window.findChild(QObject, "moduleLaboratoryGuideIdea")
    formula = window.findChild(QObject, "moduleLaboratoryGuideFormula")
    animation = window.findChild(QObject, "moduleLaboratoryGuideObservation")
    data = window.findChild(QObject, "moduleLaboratoryGuideTechnicalDetails")
    details_toggle = window.findChild(
        QObject, "moduleLaboratoryGuideDetailsToggle"
    )
    assert all(
        item is not None
        for item in (idea, formula, animation, data, details_toggle)
    )
    assert window.findChild(QObject, "moduleLaboratoryGuideTabs") is None

    # En Esencial se leen las tres preguntas y la fórmula en el mismo orden,
    # sin aprender otra navegación ni exponer datos densos.
    assert tuple(
        bool(item.property("visible")) for item in (idea, animation, formula)
    ) == (True, True, True)
    assert bool(details_toggle.property("visible")) is False
    assert bool(data.property("visible")) is False

    # Avanzado añade una única revelación progresiva. Cambiar de operación la
    # vuelve a plegar para evitar arrastrar carga técnica al paso siguiente.
    guide.setProperty("essentialMode", False)
    qapp.processEvents()
    assert bool(details_toggle.property("visible")) is True
    assert bool(data.property("visible")) is False
    details_toggle.clicked.emit()
    qapp.processEvents()
    assert bool(data.property("visible")) is True
    guide.setProperty("step", {"id": "otro_paso"})
    qapp.processEvents()
    assert bool(data.property("visible")) is False


def test_decoder_y_filtros_completos_muestran_la_operacion_correcta(
    qapp, specialized_visual
):
    _window, visual, loader, _evidence = specialized_visual

    decoder_output = next(
        step
        for step in _module_steps("module_6", "inference")
        if step["id"] == "decoder_output"
    )
    visual.setProperty("moduleId", "module_6")
    visual.setProperty("stepIndex", 8)
    visual.setProperty("step", decoder_output)
    qapp.processEvents()
    decoder_view = loader.property("item")
    assert decoder_view.objectName() == "moduleLabDecoderView"
    # Índice 1 es la escena residual + LayerNorm; antes regresaba a atención.
    assert decoder_view.property("sceneIndex") == 1

    full_filters = next(
        step
        for step in _module_steps("module_8", "inference")
        if step["id"] == "full_filters"
    )
    visual.setProperty("moduleId", "module_8")
    visual.setProperty("stepIndex", 5)
    visual.setProperty("step", full_filters)
    qapp.processEvents()
    transformer_view = loader.property("item")
    simple_scene = transformer_view.findChild(QObject, "simpleOutputStageScene")
    definition = simple_scene.property("definition").toVariant()
    assert definition["kind"] == "candidates"
    assert definition["operation"] == "Temperatura → Top-K → Top-P"
    assert definition["last"] == full_filters["output"]


@pytest.mark.parametrize("mode", ["training", "inference"])
def test_visualizacion_diferencia_ambos_modos(qapp, specialized_visual, mode):
    _window, visual, _loader, evidence = specialized_visual

    visual.setProperty("mode", mode)
    visual.setProperty("selectedLayer", 1)
    visual.setProperty("selectedHead", 2)
    visual.setProperty("selectedToken", 1)
    qapp.processEvents()

    assert visual.property("trainingMode") is (mode == "training")
    assert evidence.property("visible") is (mode == "training")
    assert visual.property("selectedLayer") == 1
    assert visual.property("selectedHead") == 2
    assert visual.property("selectedToken") == 1


def _rect_in(item: QQuickItem, ancestor: QQuickItem) -> QRectF:
    origin = item.mapToItem(ancestor, QPointF(0, 0))
    return QRectF(origin, QSizeF(item.width(), item.height()))


def _visual_descendants(item: QQuickItem) -> list[QQuickItem]:
    pending = list(item.childItems())
    descendants = []
    while pending:
        child = pending.pop()
        descendants.append(child)
        pending.extend(child.childItems())
    return descendants


def test_rascacielos_reserva_espacio_para_graficas_y_muestra_tres_pisos(qapp):
    engine = QQmlEngine()
    component = QQmlComponent(engine)
    component.setData(
        LAYER_SKYSCRAPER_HOST,
        QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "LayerSkyscraperHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    for _ in range(5):
        qapp.processEvents()

    scene = window.findChild(QQuickItem, "layerSkyscraperUnderTest")
    assert scene is not None
    descendants = _visual_descendants(scene)
    floor_cards = sorted(
        (
            item
            for item in descendants
            if item.objectName().startswith("layerFloorCard_")
        ),
        key=lambda item: _rect_in(item, scene).top(),
    )
    scatter_panels = [
        item
        for item in descendants
        if item.objectName().startswith("layerScatterPanel_")
    ]
    scatter_canvases = [
        item
        for item in descendants
        if item.objectName().startswith("layerScatterCanvas_")
    ]
    detail_panels = [
        item
        for item in descendants
        if item.objectName().startswith("layerFloorDetail_")
    ]

    assert (
        len(floor_cards)
        == len(scatter_panels)
        == len(scatter_canvases)
        == len(detail_panels)
        == 3
    )
    assert floor_cards[-1].mapToItem(scene, QPointF(0, floor_cards[-1].height())).y() \
        <= scene.height() + 1
    assert all(
        _rect_in(first, scene).bottom() <= _rect_in(second, scene).top() + 1
        for first, second in zip(floor_cards, floor_cards[1:])
    )
    # El texto lateral debe conservar un ancho estable sin consumir la zona
    # central: antes de esta restriccion las tres graficas quedaban en 0 px.
    assert all(panel.width() >= 300 for panel in scatter_panels)
    assert all(scatter.width() > detail.width() for scatter, detail in zip(
        sorted(scatter_panels, key=lambda item: item.objectName()),
        sorted(detail_panels, key=lambda item: item.objectName()),
    ))

    scene.setProperty("selectedToken", 2)
    qapp.processEvents()
    assert all(canvas.property("highlightedToken") == 2 for canvas in scatter_canvases)

    window.deleteLater()
    engine.deleteLater()


def _side_by_side(left: QQuickItem, right: QQuickItem, ancestor: QQuickItem) -> bool:
    left_box = _rect_in(left, ancestor)
    return left_box.width() > 0 and _rect_in(right, ancestor).left() >= left_box.right() - 1


def test_pantalla_especializada_reordena_paneles_sin_encimarlos(
    qapp, qtbot, tmp_path, monkeypatch
):
    # Al final se auditan los retos de los ocho módulos, y seleccionar uno
    # cerrado no hace nada: el modo revisión existe justo para esta revisión de
    # contenido. Los prerrequisitos reales se prueban en test_module_course.
    monkeypatch.setattr(CourseController, "REVIEW_MODE_UNLOCK_ALL", True)
    view_model = MainViewModel()
    # Aísla la persistencia: explorar el laboratorio emite señales reales de
    # progreso y una prueba visual nunca debe cambiar la sesión del usuario.
    progress_repository = ModuleProgressRepository(tmp_path / "progress.json")
    view_model._course_controller._repository = progress_repository
    view_model._course_controller._state = progress_repository.snapshot()
    view_model._course_controller._current_module_id = "module_1"
    config = ConfiguracionTransformer(
        tamano_vocabulario=40,
        dimension_modelo=16,
        num_cabezas=4,
        num_capas=2,
        dimension_ff=32,
        longitud_maxima_secuencia=12,
        dropout=0.0,
        id_token_relleno=36,
    )
    model = Transformer(config)
    view_model.moduleLaboratoryController.set_model(model, _ScreenTokenizer())
    view_model._modelo_actual_info = {
        "num_capas": 2,
        "num_cabezas": 4,
        "dimension_modelo": 16,
    }
    view_model.moduleLaboratoryController.explore(
        "module_3", "texto", "inference", 1, 2, 1, 0.8, 5, 0.9, True
    )

    engine = QQmlEngine()
    engine.rootContext().setContextProperty("mainViewModel", view_model)
    component = QQmlComponent(engine)
    component.setData(
        SCREEN_HOST,
        QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "ModuleLabScreenHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    for _ in range(4):
        qapp.processEvents()

    screen = window.findChild(QObject, "moduleLaboratoryScreen")
    workspace = window.findChild(QQuickItem, "moduleLaboratoryWorkspace")
    step_pane = window.findChild(QQuickItem, "moduleLaboratoryStepPane")
    visual_pane = window.findChild(QQuickItem, "moduleLaboratoryVisualPane")
    model_status = window.findChild(QQuickItem, "moduleLaboratoryModelStatus")
    guide = window.findChild(QObject, "moduleLaboratoryAnimationGuide")
    guide_context = window.findChild(QObject, "moduleLaboratoryGuideLocalContext")
    guide_idea = window.findChild(QObject, "moduleLaboratoryGuideIdea")
    guide_observation = window.findChild(
        QObject, "moduleLaboratoryGuideObservation"
    )
    guide_formula = window.findChild(QObject, "moduleLaboratoryGuideFormula")
    guide_formula_reading = window.findChild(
        QObject, "moduleLaboratoryGuideFormulaReading"
    )
    guide_purpose = window.findChild(QObject, "moduleLaboratoryGuidePurpose")
    guide_evidence = window.findChild(QObject, "moduleLaboratoryGuideEvidence")
    visualization = window.findChild(QObject, "moduleLaboratoryVisualization")
    formula_scene = window.findChild(QObject, "moduleLaboratoryFormulaScene")
    detach_button = window.findChild(QObject, "moduleLaboratoryDetachGuide")
    workspace_tabs = window.findChild(QObject, "moduleLaboratoryWorkspaceTabs")
    analyze_button = window.findChild(QObject, "moduleLaboratoryAnalyzeButton")
    essential_level = window.findChild(QObject, "moduleLaboratoryEssentialLevel")
    advanced_level = window.findChild(QObject, "moduleLaboratoryAdvancedLevel")
    training_mode = window.findChild(QObject, "moduleLaboratoryTrainingMode")
    inference_mode = window.findChild(QObject, "moduleLaboratoryInferenceMode")
    level_tabs = window.findChild(QQuickItem, "moduleLaboratoryLearningLevelTabs")
    practice_card = window.findChild(QQuickItem, "moduleLaboratoryPracticeCard")
    standard_practice_host = window.findChild(
        QQuickItem, "moduleLaboratoryStandardPracticeHost"
    )
    advanced_practice_host = window.findChild(
        QQuickItem, "moduleLaboratoryAdvancedPracticeHost"
    )
    mode_summary = window.findChild(QObject, "moduleLaboratoryModeSummary")
    detached_window = window.findChild(
        QObject, "moduleLaboratoryDetachedGuideWindow"
    )
    detached_guide = window.findChild(
        QObject, "moduleLaboratoryDetachedAnimationGuide"
    )
    step_list = window.findChild(QObject, "moduleLaboratoryStepList")
    advanced_controls = window.findChild(
        QObject, "moduleLaboratoryAdvancedControls"
    )
    guide_input = window.findChild(QObject, "moduleLaboratoryGuideInput")
    guide_details_toggle = window.findChild(
        QObject, "moduleLaboratoryGuideDetailsToggle"
    )
    guide_technical_details = window.findChild(
        QObject, "moduleLaboratoryGuideTechnicalDetails"
    )
    discovery_cycle = window.findChild(QObject, "laboratoryDiscoveryCycle")
    discovery_button = window.findChild(
        QObject, "moduleLaboratoryDiscoveryButton"
    )
    confirm_prediction = window.findChild(
        QObject, "laboratoryDiscoveryConfirmPrediction"
    )
    run_experiment = window.findChild(
        QObject, "laboratoryDiscoveryRunExperiment"
    )
    confirm_observation = window.findChild(
        QObject, "laboratoryDiscoveryConfirmObservation"
    )
    check_explanation = window.findChild(
        QObject, "laboratoryDiscoveryCheckExplanation"
    )
    show_explanation = window.findChild(
        QObject, "laboratoryDiscoveryShowExplanation"
    )
    progress = window.findChild(QObject, "moduleLaboratoryProgress")
    overview_map = window.findChild(QObject, "moduleLaboratoryOverviewMap")
    restart_steps = window.findChild(QObject, "moduleLaboratoryRestartSteps")
    previous_step = window.findChild(QObject, "moduleLaboratoryPreviousStep")
    next_step = window.findChild(QObject, "moduleLaboratoryNextStep")
    assert all(
        item is not None
        for item in (
            screen,
            workspace,
            step_pane,
            visual_pane,
            model_status,
            guide,
            guide_context,
            guide_idea,
            guide_observation,
            guide_formula,
            guide_formula_reading,
            guide_purpose,
            guide_evidence,
            visualization,
            formula_scene,
            detach_button,
            workspace_tabs,
            analyze_button,
            essential_level,
            advanced_level,
            training_mode,
            inference_mode,
            level_tabs,
            practice_card,
            standard_practice_host,
            advanced_practice_host,
            mode_summary,
            detached_window,
            detached_guide,
            step_list,
            advanced_controls,
            guide_input,
            guide_details_toggle,
            guide_technical_details,
            discovery_cycle,
            discovery_button,
            confirm_prediction,
            run_experiment,
            confirm_observation,
            check_explanation,
            show_explanation,
            progress,
            overview_map,
            restart_steps,
            previous_step,
            next_step,
        )
    )
    assert visualization.property("specializationKind") == "attention"
    assert guide.property("moduleId") == "module_3"
    assert str(guide_idea.property("body")) == str(
        view_model.moduleLaboratoryController.result["steps"][0]["explanation"]
    )
    assert str(guide_observation.property("body")).strip()
    first_step = view_model.moduleLaboratoryController.result["steps"][0]
    first_demo = view_model.moduleLaboratoryController.result["formula_demos"][
        first_step["id"]
    ]
    expected_animation = first_demo["animation_explanation"]
    assert expected_animation in str(guide_observation.property("body"))
    assert "tres tarjetas" not in str(guide_observation.property("body")).lower()
    # La ayuda especializada también queda visible junto a la fórmula y no
    # depende de que el estudiante abra la ventana separada.
    assert str(formula_scene.property("formulaExplanation")).strip()
    assert str(guide_formula_reading.property("text")).startswith("CÓMO LEERLA")
    assert "Produce «" in str(guide_purpose.property("text"))
    assert "Datos reales" in str(guide_evidence.property("body"))

    # La vista abre en nivel Esencial y muestra una sola fuente de atención.
    assert screen.property("learningLevel") == "essential"
    assert bool(mode_summary.property("truncated")) is False
    assert int(workspace_tabs.property("currentIndex")) == 2
    assert bool(step_pane.property("visible")) is False
    assert bool(step_list.property("visible")) is False
    assert bool(advanced_controls.property("visible")) is False
    assert bool(detach_button.property("visible")) is False
    assert bool(standard_practice_host.property("visible")) is True
    assert bool(advanced_practice_host.property("visible")) is False
    assert practice_card.parentItem().objectName() == (
        "moduleLaboratoryStandardPracticeHost"
    )
    assert 0 < float(progress.property("value")) <= 1
    assert screen.property("guideDetached") is False
    assert guide.property("visible") is False
    assert discovery_cycle.property("visible") is True
    assert int(screen.property("discoveryStage")) == 0

    # El ciclo exige predecir, ejecutar un contrafactual, observar, explicar y
    # recibir feedback antes de revelar la explicación completa.
    screen.setProperty(
        "discoveryPrediction", int(discovery_cycle.property("correctPrediction"))
    )
    confirm_prediction.clicked.emit()
    qapp.processEvents()
    assert int(screen.property("discoveryStage")) == 1
    run_experiment.clicked.emit()
    for _ in range(5):
        qapp.processEvents()
    assert int(screen.property("discoveryStage")) == 2
    assert int(workspace_tabs.property("currentIndex")) == 1
    discovery_button.clicked.emit()
    qapp.processEvents()
    assert int(workspace_tabs.property("currentIndex")) == 2
    confirm_observation.clicked.emit()
    qapp.processEvents()
    assert int(screen.property("discoveryStage")) == 3
    correct_explanation = int(discovery_cycle.property("correctExplanation"))
    wrong_explanation = (correct_explanation + 1) % len(
        _qml_value(screen.property("explanationBundle"))["options"]
    )
    screen.setProperty("discoveryExplanation", wrong_explanation)
    check_explanation.clicked.emit()
    qapp.processEvents()
    assert int(screen.property("discoveryStage")) == 3
    assert str(screen.property("discoveryHint")).strip()
    screen.setProperty(
        "discoveryExplanation", correct_explanation
    )
    check_explanation.clicked.emit()
    qapp.processEvents()
    assert int(screen.property("discoveryStage")) == 4
    show_explanation.clicked.emit()
    qapp.processEvents()
    assert int(screen.property("discoveryStage")) == 5
    assert discovery_cycle.property("visible") is False
    assert bool(guide.property("visible")) is True
    assert bool(guide_input.property("visible")) is True
    assert bool(guide_context.property("visible")) is False
    assert bool(guide_details_toggle.property("visible")) is False
    assert bool(guide_technical_details.property("visible")) is False
    screen.setProperty("workspaceSection", 0)
    wide_visual = _rect_in(visual_pane, workspace)
    assert screen.property("compactLayout") is False, (
        screen.property("width"),
        window.width(),
        workspace.width(),
        wide_visual,
    )
    assert wide_visual.left() >= -1
    assert wide_visual.right() >= workspace.width() - 2
    # Sin encabezado avanzado, las pestañas deben comenzar arriba del panel y
    # no dejar el gran bloque vacío que antes desplazaba toda la animación.
    assert _rect_in(workspace_tabs, visual_pane).top() <= 20

    # Avanzado recupera la ventana separada y permite revelar los datos.
    screen.setProperty("learningLevel", "advanced")
    # El GridLayout pasa a dos columnas en su siguiente polish, no al instante:
    # medir antes daba el ancho de una sola columna y la prueba fallaba a ratos.
    qtbot.waitUntil(lambda: _side_by_side(step_pane, visual_pane, workspace), timeout=3000)
    qtbot.waitUntil(
        lambda: practice_card.parentItem().objectName()
        == "moduleLaboratoryAdvancedPracticeHost",
        timeout=3000,
    )
    initial_visual_width = visual_pane.width()
    assert bool(step_pane.property("visible")) is True
    assert bool(step_list.property("visible")) is True
    assert bool(advanced_controls.property("visible")) is True
    assert bool(detach_button.property("visible")) is True
    assert bool(standard_practice_host.property("visible")) is False
    assert bool(advanced_practice_host.property("visible")) is True
    assert advanced_practice_host.y() >= workspace.y() + workspace.height() - 1
    assert bool(mode_summary.property("truncated")) is False
    screen.setProperty("workspaceSection", 2)
    qapp.processEvents()
    assert bool(guide_details_toggle.property("visible")) is True
    assert bool(guide_technical_details.property("visible")) is False
    guide_details_toggle.clicked.emit()
    qapp.processEvents()
    assert bool(guide_technical_details.property("visible")) is True
    screen.setProperty("workspaceSection", 0)
    screen.setProperty("guideDetached", True)
    qtbot.waitUntil(
        lambda: detached_window.property("visible") is True
        and detached_guide.property("visible") is True,
        timeout=3000,
    )
    # Separar la guía no debe cambiar el reparto. Se fuerza el polish pendiente
    # para no comparar contra un ancho que el layout aún no recalculó.
    # Limitación aceptada: solo alcanza este GridLayout, no el layout padre. Si
    # separar la guía llegara a cambiar el ancho del padre, el cambio podría
    # aterrizar después de la aserción. Riesgo bajo: la guía separada es otra
    # ventana y no ocupa espacio en esta página.
    workspace.ensurePolished()
    assert _side_by_side(step_pane, visual_pane, workspace)
    assert abs(visual_pane.width() - initial_visual_width) <= 1

    # A 1280 px, los pasos se colocan arriba y la escena conserva todo el ancho.
    window.setProperty("width", 1280)
    window.setProperty("height", 820)
    for _ in range(5):
        qapp.processEvents()
    assert screen.property("compactLayout") is True
    assert screen.property("mediumLayout") is True
    assert screen.property("narrowLayout") is False
    assert model_status.property("visible") is True
    medium = [_rect_in(item, workspace) for item in (step_pane, visual_pane)]
    assert medium[0].bottom() <= medium[1].top() + 1
    assert medium[1].width() >= workspace.width() - 2

    screen.setProperty("guideDetached", False)

    window.setProperty("width", 900)
    window.setProperty("height", 900)
    for _ in range(5):
        qapp.processEvents()
    assert screen.property("compactLayout") is True
    assert screen.property("mediumLayout") is False
    assert screen.property("narrowLayout") is True
    assert model_status.property("visible") is False
    compact = [_rect_in(item, workspace) for item in (step_pane, visual_pane)]
    assert compact[0].bottom() <= compact[1].top() + 1
    assert all(
        rect.left() >= -1 and rect.right() <= workspace.width() + 1 for rect in compact
    )
    # Las escenas de atención y del Transformer completo necesitan espacio
    # vertical adicional cuando los tres paneles se apilan. Una altura menor
    # vuelve a superponer matrices y sus leyendas.
    assert compact[1].height() >= 680
    specialized_loader = window.findChild(QQuickItem, "moduleLabSpecializedLoader")
    assert specialized_loader is not None
    assert specialized_loader.property("clip") is True
    assert specialized_loader.height() >= 350

    assert detached_window.property("visible") is False
    assert screen.property("workspacePreferredHeight") < 1000

    # Decoder abre primero un mapa general por bloques y permite saltar a cada
    # parte sin mezclar todas sus operaciones en una sola explicación.
    view_model._course_controller.selectModule("module_6")
    view_model.moduleLaboratoryController.explore(
        "module_6", "texto", "inference", 0, 0, 1, 1.0, 5, 0.9, True
    )
    screen.setProperty("moduleId", "module_6")
    screen.setProperty("learningLevel", "essential")
    for _ in range(4):
        qapp.processEvents()
    assert bool(overview_map.property("visible")) is True
    assert screen.property("activeGroupId") == "prepare"
    screen.setProperty("currentStepIndex", 2)
    qapp.processEvents()
    assert screen.property("activeGroupId") == "causal"

    view_model._course_controller.selectModule("module_8")
    screen.setProperty("moduleId", "module_8")
    view_model.moduleLaboratoryController.explore(
        "module_8", "texto", "inference", 0, 0, 1, 1.0, 5, 0.9, True
    )
    for _ in range(4):
        qapp.processEvents()
    assert bool(overview_map.property("visible")) is True
    assert screen.property("activeGroupId") == "prepare"
    screen.setProperty("currentStepIndex", 2)
    qapp.processEvents()
    assert screen.property("activeGroupId") == "encode"
    screen.setProperty("currentStepIndex", 4)
    qapp.processEvents()
    assert screen.property("activeGroupId") == "generate"

    # La fila que antes se cortaba conserva ambas descripciones completas y
    # el módulo 8 usa tarjetas temáticas, no sliders nativos sin jerarquía.
    window.setProperty("width", 1900)
    window.setProperty("height", 900)
    screen.setProperty("learningLevel", "advanced")
    for _ in range(5):
        qapp.processEvents()
    assert bool(mode_summary.property("truncated")) is False
    control_names = (
        "moduleLaboratoryLayerControl",
        "moduleLaboratoryHeadControl",
        "moduleLaboratoryTokenControl",
        "moduleLaboratoryCausalControl",
        "moduleLaboratoryTemperatureControl",
        "moduleLaboratoryTopKControl",
        "moduleLaboratoryTopPControl",
    )
    controls = [window.findChild(QQuickItem, name) for name in control_names]
    assert all(control is not None for control in controls)

    controls_by_name = dict(zip(control_names, controls))
    layer_control = controls_by_name["moduleLaboratoryLayerControl"]
    head_control = controls_by_name["moduleLaboratoryHeadControl"]
    token_control = controls_by_name["moduleLaboratoryTokenControl"]
    causal_control = controls_by_name["moduleLaboratoryCausalControl"]
    temperature_control = controls_by_name["moduleLaboratoryTemperatureControl"]
    top_k_control = controls_by_name["moduleLaboratoryTopKControl"]
    top_p_control = controls_by_name["moduleLaboratoryTopPControl"]

    # En el paso de filtros solo aparecen los controles que alteran ese
    # concepto; capa y cabeza permanecen ocultos porque no cambian la escena.
    full_steps = view_model.moduleLaboratoryController.result["steps"]
    filters_index = next(
        index for index, step in enumerate(full_steps) if step["id"] == "full_filters"
    )
    screen.setProperty("currentStepIndex", filters_index)
    qapp.processEvents()
    assert tuple(bool(control.property("visible")) for control in controls) == (
        False,
        False,
        True,
        True,
        True,
        True,
        True,
    )
    assert all(control.height() >= 70 for control in controls if control.isVisible())

    assert (float(layer_control.property("from")), float(layer_control.property("to"))) == (0, 1)
    assert (float(head_control.property("from")), float(head_control.property("to"))) == (0, 3)
    assert float(token_control.property("to")) == len(
        view_model.moduleLaboratoryController.result["tokens"]
    ) - 1
    assert float(temperature_control.property("stepSize")) == pytest.approx(0.05)
    assert float(top_k_control.property("stepSize")) == 1
    assert float(top_p_control.property("stepSize")) == pytest.approx(0.01)

    layer_control.setProperty("value", 1)
    head_control.setProperty("value", 3)
    token_control.setProperty("value", 2)
    causal_control.setProperty("checked", False)
    temperature_control.setProperty("value", 0.55)
    top_k_control.setProperty("value", 7)
    top_p_control.setProperty("value", 0.75)
    analyze_button.clicked.emit()
    for _ in range(5):
        qapp.processEvents()

    updated = view_model.moduleLaboratoryController.result
    assert updated["selected_layer"] == 1
    assert updated["selected_head"] == 3
    assert updated["selected_token_index"] == 2
    assert updated["experiment"]["causal_mask"] is False
    assert updated["experiment"]["causal_counterfactual"] is True
    assert updated["experiment"]["temperature"] == pytest.approx(0.55)
    assert updated["experiment"]["top_k"] == 7
    assert updated["experiment"]["top_p"] == pytest.approx(0.75)
    assert screen.property("currentStepIndex") == filters_index

    next_step.clicked.emit()
    qapp.processEvents()
    assert screen.property("currentStepIndex") == filters_index + 1
    previous_step.clicked.emit()
    qapp.processEvents()
    assert screen.property("currentStepIndex") == filters_index
    screen.setProperty("currentStepIndex", 3)
    restart_steps.clicked.emit()
    qapp.processEvents()
    assert screen.property("currentStepIndex") == 0
    assert window.findChild(QObject, "moduleLaboratoryPlaySteps") is None

    # Los selectores de nivel y modo ejecutan su comportamiento, no solo
    # cambian de apariencia.
    essential_level.clicked.emit()
    qapp.processEvents()
    assert screen.property("learningLevel") == "essential"
    advanced_level.clicked.emit()
    qapp.processEvents()
    assert screen.property("learningLevel") == "advanced"
    training_mode.clicked.emit()
    for _ in range(5):
        qapp.processEvents()
    assert screen.property("mode") == "training"
    assert view_model.moduleLaboratoryController.result["mode"] == "training"
    inference_mode.clicked.emit()
    for _ in range(5):
        qapp.processEvents()
    assert screen.property("mode") == "inference"
    assert view_model.moduleLaboratoryController.result["mode"] == "inference"

    visibility_scenarios = (
        ("module_1", "text", (False, False, False, False, False, False, False)),
        ("module_2", "lookup", (False, False, True, False, False, False, False)),
        ("module_3", "attention_input", (True, True, True, False, False, False, False)),
        ("module_5", "encoder_attention", (True, True, True, False, False, False, False)),
        ("module_5", "stack", (False, False, True, False, False, False, False)),
        ("module_6", "causal_mask", (False, False, True, True, False, False, False)),
        ("module_6", "masked_attention", (True, True, True, True, False, False, False)),
        ("module_7", "hidden", (False, False, True, False, False, False, False)),
        ("module_7", "temperature", (False, False, True, False, True, False, False)),
        ("module_7", "top_p", (False, False, True, False, True, True, True)),
        ("module_8", "full_encoder", (True, True, True, False, False, False, False)),
        ("module_8", "full_logits", (False, False, True, True, False, False, False)),
        ("module_8", "full_filters", (False, False, True, True, True, True, True)),
    )
    for module_id, step_id, expected in visibility_scenarios:
        view_model._course_controller.selectModule(module_id)
        screen.setProperty("moduleId", module_id)
        view_model.moduleLaboratoryController.explore(
            module_id, "texto", "inference", 1, 2, 1, 0.8, 5, 0.9, True
        )
        result_steps = view_model.moduleLaboratoryController.result["steps"]
        step_index = next(
            index for index, step in enumerate(result_steps) if step["id"] == step_id
        )
        screen.setProperty("currentStepIndex", step_index)
        qapp.processEvents()
        if module_id == "module_5":
            title = view_model.moduleLaboratoryController.result["formula_demos"][
                "encoder_attention"
            ]["title"]
            assert "cabeza 3" in title
        actual = tuple(bool(control.property("visible")) for control in controls)
        assert actual == expected, (module_id, step_id, actual)

    # Auditoría pedagógica completa: cada operación de los ocho módulos y de
    # ambos modos recibe una predicción válida, un experimento concreto y una
    # comprobación cuya respuesta correcta es la explicación de ese paso.
    audited = 0
    audited_question_ids = {}
    for module_id in SPECIALIZATIONS:
        view_model._course_controller.selectModule(module_id)
        screen.setProperty("moduleId", module_id)
        screen.setProperty("learningLevel", "advanced")
        question_bank = ModuleQuestionBank(module_id=module_id)
        assessment_prompts = [
            _comparable_question(question["prompt"])
            for assessment in ("pre", "post")
            for question in question_bank.all_questions(assessment)
        ]
        for mode in ("inference", "training"):
            screen.setProperty("mode", mode)
            view_model.moduleLaboratoryController.explore(
                module_id, "texto", mode, 1, 2, 1, 0.8, 5, 0.9, True
            )
            qapp.processEvents()
            result_steps = view_model.moduleLaboratoryController.result["steps"]
            for index, step in enumerate(result_steps):
                screen.setProperty("currentStepIndex", index)
                qapp.processEvents()
                challenge = _qml_value(screen.property("discoveryChallenge"))
                prediction = _qml_value(screen.property("predictionBundle"))
                explanation = _qml_value(screen.property("explanationBundle"))
                experiment = _qml_value(screen.property("experimentDescriptor"))
                context = (module_id, mode, step["id"])
                question_id = str(challenge.get("id", "")).strip()
                question_options = [
                    str(option).strip() for option in challenge.get("options", [])
                ]
                assert question_id, context
                assessment_prefix = module_id.replace("module_", "m") + "_a"
                assert not question_id.startswith(assessment_prefix), context
                challenge_prompt = str(challenge.get("prompt", "")).strip()
                assert challenge_prompt, context
                assert challenge_prompt.endswith("?") and "¿" in challenge_prompt, context
                normalized_prompt = _comparable_question(challenge_prompt)
                assert max(
                    SequenceMatcher(None, normalized_prompt, formal_prompt).ratio()
                    for formal_prompt in assessment_prompts
                ) < 0.60, context
                assert str(challenge.get("explanation", "")).strip(), context
                assert len(question_options) >= 3, context
                assert all(question_options), context
                assert len(set(question_options)) == len(question_options), context
                assert len(prediction["options"]) >= 3
                assert 0 <= int(prediction["correct"]) < len(prediction["options"])
                assert str(experiment.get("label", "")).strip()
                assert str(experiment.get("instruction", "")).strip()
                correct = int(explanation["correct"])
                assert 0 <= correct < len(explanation["options"])
                assert explanation["options"][correct] == step["explanation"]
                audited_question_ids[context] = question_id
                audited += 1
    assert audited >= 120
    assert audited_question_ids[("module_1", "inference", "batch")] == "lab_m1_batch_inference"
    assert audited_question_ids[("module_1", "training", "batch")] == "lab_m1_batch_training"
    assert audited_question_ids[("module_2", "inference", "dropout")] == "lab_m2_dropout_inference"
    assert audited_question_ids[("module_2", "training", "dropout")] == "m2_l8"
    assert audited_question_ids[("module_3", "inference", "mask")] == "m3_l7"
    assert audited_question_ids[("module_4", "inference", "contexts")] == "lab_m4_contexts"
    assert audited_question_ids[("module_5", "inference", "ffn_project")] == "lab_m5_ffn_project"
    assert audited_question_ids[("module_6", "inference", "decoder_prefix")] == "lab_m6_prefix_inference"
    assert audited_question_ids[("module_6", "training", "decoder_prefix")] == "m6_l7"
    assert audited_question_ids[("module_7", "inference", "feedback")] == "m7_l7"
    assert audited_question_ids[("module_8", "training", "full_loss")] == "lab_m8_loss"

    window.deleteLater()
    engine.deleteLater()


FORMULA_HOST = b"""\
import QtQuick
import QtQuick.Controls
import "components" as Components
import "styles" as Style

ApplicationWindow {
    width: 1300
    height: 600
    visible: true

    property bool requestedDarkMode: Style.Theme.modoOscuro
    readonly property bool themeIsDark: Style.Theme.modoOscuro
    readonly property color formulaSurface: Style.Theme.formula_fondo
    readonly property color formulaInk: Style.Theme.formula_texto
    readonly property color resultSurface: Style.Theme.proceso_fondo
    readonly property color resultInk: Style.Theme.proceso_texto

    onRequestedDarkModeChanged: Style.Theme.modoOscuro = requestedDarkMode

    Components.FormulaAnimationScene {
        objectName: "formulaSceneUnderTest"
        anchors.fill: parent
        reducedMotion: true
    }
}
"""


def _formula_laboratory():
    config = ConfiguracionTransformer(
        tamano_vocabulario=40,
        dimension_modelo=16,
        num_cabezas=4,
        num_capas=2,
        dimension_ff=32,
        longitud_maxima_secuencia=12,
        dropout=0.1,
        id_token_relleno=0,
    )
    view_model = MainViewModel()
    controller = view_model.moduleLaboratoryController
    controller.set_model(Transformer(config), _ScreenTokenizer())
    return view_model, controller


def test_formula_en_accion_anima_cada_paso_de_los_ocho_modulos(qapp):
    view_model, controller = _formula_laboratory()
    warnings: list[str] = []

    def capture(_mode, _context, message):
        if "FormulaAnimationScene" in message:
            warnings.append(message)

    previous = qInstallMessageHandler(capture)
    engine = QQmlEngine()
    try:
        component = QQmlComponent(engine)
        component.setData(
            FORMULA_HOST,
            QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "FormulaHost.qml")),
        )
        assert component.status() != QQmlComponent.Status.Error, _errors(component)
        window = component.create()
        assert window is not None, _errors(component)
        scene = window.findChild(QObject, "formulaSceneUnderTest")
        loader = window.findChild(QObject, "formulaAnimationLoader")
        title = window.findChild(QObject, "formulaAnimationTitle")
        formula_card = window.findChild(QObject, "formulaAnimationFormulaCard")
        formula_text = window.findChild(QObject, "formulaAnimationFormula")
        phase_guidance = window.findChild(
            QObject, "formulaAnimationPhaseGuidance"
        )
        replay = window.findChild(QObject, "formulaAnimationReplay")
        play = window.findChild(QObject, "formulaAnimationPlay")
        speed = window.findChild(QObject, "formulaAnimationSpeed")
        scrubber = window.findChild(QObject, "formulaAnimationScrubber")
        assert all(
            item is not None
            for item in (
                scene,
                loader,
                title,
                formula_card,
                formula_text,
                phase_guidance,
                replay,
                play,
                speed,
                scrubber,
            )
        )
        assert formula_card.property("color") == window.property("formulaSurface")
        assert formula_text.property("color") == window.property("formulaInk")
        assert window.findChild(QObject, "formulaAnimationContentTabs") is None
        assert window.findChild(QObject, "formulaAnimationExplanationPanel") is None

        kinds: set[str] = set()
        for module_id in SPECIALIZATIONS:
            for mode in ("inference", "training"):
                controller.explore(
                    module_id, "texto", mode, 1, 2, 2, 0.8, 5, 0.9, True
                )
                result = controller.result
                for step in result["steps"]:
                    demo = result["formula_demos"][step["id"]]
                    scene.setProperty("step", step)
                    scene.setProperty("demo", demo)
                    qapp.processEvents()
                    # Mitad de la animación y estado final: ambos deben dibujarse.
                    for progress in (0.5, 1.0):
                        scene.setProperty("t", progress)
                        qapp.processEvents()
                    kinds.add(demo["kind"])
                    assert scene.property("kind") == demo["kind"]
                    assert loader.property("item") is not None, (module_id, step["id"])
                    assert str(title.property("text")) == demo["title"]
                    displayed_formula = str(formula_text.property("text")).replace(
                        ";\n", "; "
                    )
                    assert displayed_formula == step["formula"]
                    assert formula_text.property("font").pixelSize() >= 18
                    assert not bool(formula_text.property("truncated"))
                    assert formula_text.property("width") <= formula_card.property("width")
                    assert bool(loader.property("visible")) is True
                    assert bool(phase_guidance.property("visible")) is True
                    assert not warnings, (module_id, mode, step["id"], warnings)

        # Los controles de reproducción modifican realmente el estado de la
        # animación; el deslizador no es únicamente decorativo.
        scene.setProperty("reducedMotion", False)
        scene.setProperty("t", 1.0)
        initial_speed = float(scene.property("speed"))
        speed.clicked.emit()
        qapp.processEvents()
        assert float(scene.property("speed")) != initial_speed
        scrubber.setProperty("value", 0.42)
        scrubber.moved.emit()
        qapp.processEvents()
        assert float(scene.property("t")) == pytest.approx(0.42, abs=0.01)
        play.clicked.emit()
        qapp.processEvents()
        assert bool(scene.property("running")) is True
        play.clicked.emit()
        qapp.processEvents()
        assert bool(scene.property("running")) is False
        replay.clicked.emit()
        qapp.processEvents()
        assert bool(scene.property("running")) is True
        assert float(scene.property("t")) < 1.0
        play.clicked.emit()

        initial_mode = bool(window.property("themeIsDark"))
        window.setProperty("requestedDarkMode", not initial_mode)
        qapp.processEvents()
        assert formula_card.property("color") == window.property("formulaSurface")
        assert formula_text.property("color") == window.property("formulaInk")
        window.setProperty("requestedDarkMode", initial_mode)
        qapp.processEvents()
        # Las fórmulas se representan con animaciones distintas, no con una
        # plantilla genérica repetida.
        assert len(kinds) >= 25, kinds
        window.deleteLater()
    finally:
        qInstallMessageHandler(previous)
        engine.deleteLater()
        view_model.deleteLater()


def test_pantalla_sincroniza_formula_en_accion_con_el_paso_actual(qapp, tmp_path):
    view_model, controller = _formula_laboratory()
    progress_repository = ModuleProgressRepository(tmp_path / "progress.json")
    view_model._course_controller._repository = progress_repository
    view_model._course_controller._state = progress_repository.snapshot()
    view_model._course_controller._current_module_id = "module_3"
    view_model._modelo_actual_info = {"num_capas": 2, "num_cabezas": 4}
    controller.explore("module_3", "texto", "inference", 0, 1, 1, 0.8, 5, 0.9, True)

    engine = QQmlEngine()
    engine.rootContext().setContextProperty("mainViewModel", view_model)
    component = QQmlComponent(engine)
    component.setData(
        SCREEN_HOST,
        QUrl.fromLocalFile(str(ROOT / "view" / "qml" / "ModuleLabScreenHost.qml")),
    )
    assert component.status() != QQmlComponent.Status.Error, _errors(component)
    window = component.create()
    assert window is not None, _errors(component)
    for _ in range(4):
        qapp.processEvents()

    screen = window.findChild(QObject, "moduleLaboratoryScreen")
    workspace = window.findChild(QQuickItem, "moduleLaboratoryWorkspace")
    visual_pane = window.findChild(QQuickItem, "moduleLaboratoryVisualPane")
    focus_stack = window.findChild(QQuickItem, "moduleLaboratoryFocusStack")
    workspace_tabs = window.findChild(QObject, "moduleLaboratoryWorkspaceTabs")
    scene = window.findChild(QObject, "moduleLaboratoryFormulaScene")
    assert all(
        item is not None
        for item in (screen, workspace, visual_pane, focus_stack, workspace_tabs, scene)
    )
    # La fórmula comparte el área principal y se abre como una vista exclusiva.
    screen.setProperty("workspaceSection", 1)
    qapp.processEvents()
    assert int(workspace_tabs.property("currentIndex")) == 1
    assert bool(scene.property("visible")) is True
    assert focus_stack.mapToItem(visual_pane, QPointF(0, 0)).y() >= 0

    title = window.findChild(QObject, "formulaAnimationTitle")
    assert title is not None
    # En Avanzado la secuencia conserva también los pasos técnicos (pesos y
    # gradientes), por lo que sus índices coinciden con el resultado completo.
    screen.setProperty("learningLevel", "advanced")
    qapp.processEvents()
    steps = controller.result["steps"]
    demos = controller.result["formula_demos"]
    for index in (0, 3, 6):
        screen.setProperty("currentStepIndex", index)
        qapp.processEvents()
        expected = demos[steps[index]["id"]]
        assert scene.property("kind") == expected["kind"]
        assert str(title.property("text")) == expected["title"]

    window.deleteLater()
    engine.deleteLater()
