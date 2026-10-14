"""Contrato visual de los ocho laboratorios especializados.

La mayor parte de estas pruebas se mantiene en la frontera publica del
componente: comprueba que el despachador carga exactamente una especializacion
por modulo y que el modo de entrenamiento activa su evidencia propia. Tambien
incluye una regresion geometrica puntual para impedir que la grafica de capas
vuelva a quedar sin ancho o fuera de su viewport.
"""

from __future__ import annotations

import os
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

import pytest
from PySide6.QtCore import QObject, QPointF, QRectF, QSizeF, QUrl, qInstallMessageHandler
from PySide6.QtQml import QQmlComponent, QQmlEngine
from PySide6.QtQuick import QQuickItem

from model.aprendizaje import ModuleProgressRepository
from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from viewmodel.main_viewmodel import MainViewModel
from viewmodel.module_laboratory_controller import _module_steps


ROOT = Path(__file__).resolve().parents[2]

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


def test_guia_separa_la_explicacion_en_pestanas_elegibles(
    qapp, laboratory_guide
):
    window, guide, _formula, _reading, _observation, _flow = laboratory_guide
    tabs = window.findChild(QObject, "moduleLaboratoryGuideTabs")
    idea = window.findChild(QObject, "moduleLaboratoryGuideIdea")
    formula = window.findChild(QObject, "moduleLaboratoryGuideFormula")
    animation = window.findChild(QObject, "moduleLaboratoryGuideObservation")
    data = window.findChild(QObject, "moduleLaboratoryGuideTechnicalDetails")
    assert all(item is not None for item in (tabs, idea, formula, animation, data))

    expected_visibility = {
        0: (True, False, False, False),
        1: (False, True, False, False),
        2: (False, False, True, False),
        3: (False, False, False, True),
    }
    for section, expected in expected_visibility.items():
        guide.setProperty("selectedSection", section)
        qapp.processEvents()
        assert int(tabs.property("currentIndex")) == section
        assert tuple(
            bool(item.property("visible")) for item in (idea, formula, animation, data)
        ) == expected

    # La categoría elegida se conserva cuando el usuario cambia de operación.
    guide.setProperty("stepIndex", 1)
    qapp.processEvents()
    assert int(guide.property("selectedSection")) == 3


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


def test_pantalla_especializada_reordena_paneles_sin_encimarlos(qapp, tmp_path):
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
    formula_explanation_panel = window.findChild(
        QObject, "formulaAnimationExplanationPanel"
    )
    formula_explanation = window.findChild(QObject, "formulaAnimationExplanation")
    formula_caption = window.findChild(QObject, "formulaAnimationCaption")
    detach_button = window.findChild(QObject, "moduleLaboratoryDetachGuide")
    workspace_tabs = window.findChild(QObject, "moduleLaboratoryWorkspaceTabs")
    analyze_button = window.findChild(QObject, "moduleLaboratoryAnalyzeButton")
    essential_level = window.findChild(QObject, "moduleLaboratoryEssentialLevel")
    advanced_level = window.findChild(QObject, "moduleLaboratoryAdvancedLevel")
    training_mode = window.findChild(QObject, "moduleLaboratoryTrainingMode")
    inference_mode = window.findChild(QObject, "moduleLaboratoryInferenceMode")
    level_tabs = window.findChild(QQuickItem, "moduleLaboratoryLearningLevelTabs")
    level_summary = window.findChild(
        QQuickItem, "moduleLaboratoryLearningLevelSummary"
    )
    level_summary_card = window.findChild(
        QQuickItem, "moduleLaboratoryLearningLevelSummaryCard"
    )
    mode_summary = window.findChild(QObject, "moduleLaboratoryModeSummary")
    essential_step = window.findChild(
        QObject, "moduleLaboratoryEssentialStepCard"
    )
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
    guide_data_tab = window.findChild(QObject, "moduleLaboratoryGuideDataTab")
    guide_input = window.findChild(QObject, "moduleLaboratoryGuideInput")
    progress = window.findChild(QObject, "moduleLaboratoryProgress")
    overview_map = window.findChild(QObject, "moduleLaboratoryOverviewMap")
    restart_steps = window.findChild(QObject, "moduleLaboratoryRestartSteps")
    previous_step = window.findChild(QObject, "moduleLaboratoryPreviousStep")
    play_steps = window.findChild(QObject, "moduleLaboratoryPlaySteps")
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
            formula_explanation_panel,
            formula_explanation,
            formula_caption,
            detach_button,
            workspace_tabs,
            analyze_button,
            essential_level,
            advanced_level,
            training_mode,
            inference_mode,
            level_tabs,
            level_summary,
            level_summary_card,
            mode_summary,
            essential_step,
            detached_window,
            detached_guide,
            step_list,
            advanced_controls,
            guide_data_tab,
            guide_input,
            progress,
            overview_map,
            restart_steps,
            previous_step,
            play_steps,
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
    assert str(formula_explanation.property("text")) == str(first_step["explanation"])
    assert expected_animation in str(formula_caption.property("text"))
    assert "tres tarjetas" not in str(formula_caption.property("text")).lower()
    assert str(guide_formula_reading.property("text")).startswith("CÓMO LEERLA")
    assert "Produce «" in str(guide_purpose.property("text"))
    assert "Datos reales" in str(guide_evidence.property("body"))

    # La vista abre en nivel Esencial y muestra una sola fuente de atención.
    assert screen.property("learningLevel") == "essential"
    assert bool(level_summary.property("truncated")) is False
    assert bool(mode_summary.property("truncated")) is False
    assert level_tabs.y() + level_tabs.height() <= level_summary_card.y() + 1
    assert int(workspace_tabs.property("currentIndex")) == 1
    assert bool(essential_step.property("visible")) is True
    assert bool(step_list.property("visible")) is False
    assert bool(advanced_controls.property("visible")) is False
    assert bool(detach_button.property("visible")) is False
    assert 0 < float(progress.property("value")) <= 1
    assert screen.property("guideDetached") is False
    assert guide.property("visible") is False

    screen.setProperty("workspaceSection", 2)
    qapp.processEvents()
    assert bool(guide.property("visible")) is True
    assert bool(guide_input.property("visible")) is True
    assert bool(guide_context.property("visible")) is False
    assert bool(guide_data_tab.property("visible")) is False
    screen.setProperty("workspaceSection", 0)
    wide_without_guide = [
        _rect_in(item, workspace) for item in (step_pane, visual_pane)
    ]
    assert screen.property("compactLayout") is False, (
        screen.property("width"),
        window.width(),
        workspace.width(),
        wide_without_guide,
    )
    assert wide_without_guide[0].right() <= wide_without_guide[1].left() + 1
    assert wide_without_guide[1].right() <= workspace.width() + 1

    # Avanzado recupera la ventana separada, los datos y todos los controles.
    initial_visual_width = visual_pane.width()
    screen.setProperty("learningLevel", "advanced")
    qapp.processEvents()
    assert bool(step_list.property("visible")) is True
    assert bool(advanced_controls.property("visible")) is True
    assert bool(detach_button.property("visible")) is True
    assert bool(level_summary.property("truncated")) is False
    assert bool(mode_summary.property("truncated")) is False
    screen.setProperty("workspaceSection", 2)
    qapp.processEvents()
    assert bool(guide_data_tab.property("visible")) is True
    screen.setProperty("workspaceSection", 0)
    screen.setProperty("guideDetached", True)
    for _ in range(4):
        qapp.processEvents()
    assert detached_window.property("visible") is True
    assert detached_guide.property("visible") is True
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
    assert bool(level_summary.property("truncated")) is False
    assert level_tabs.y() + level_tabs.height() <= level_summary_card.y() + 1
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
    assert bool(level_summary.property("truncated")) is False
    assert level_tabs.y() + level_tabs.height() <= level_summary_card.y() + 1
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
    assert bool(level_summary.property("truncated")) is False
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
    assert all(bool(control.property("visible")) for control in controls)
    assert all(control.height() >= 70 for control in controls)

    controls_by_name = dict(zip(control_names, controls))
    layer_control = controls_by_name["moduleLaboratoryLayerControl"]
    head_control = controls_by_name["moduleLaboratoryHeadControl"]
    token_control = controls_by_name["moduleLaboratoryTokenControl"]
    causal_control = controls_by_name["moduleLaboratoryCausalControl"]
    temperature_control = controls_by_name["moduleLaboratoryTemperatureControl"]
    top_k_control = controls_by_name["moduleLaboratoryTopKControl"]
    top_p_control = controls_by_name["moduleLaboratoryTopPControl"]

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

    next_step.clicked.emit()
    qapp.processEvents()
    assert screen.property("currentStepIndex") == 1
    previous_step.clicked.emit()
    qapp.processEvents()
    assert screen.property("currentStepIndex") == 0
    screen.setProperty("currentStepIndex", 3)
    restart_steps.clicked.emit()
    qapp.processEvents()
    assert screen.property("currentStepIndex") == 0
    play_steps.clicked.emit()
    qapp.processEvents()
    assert screen.property("playing") is True
    play_steps.clicked.emit()
    qapp.processEvents()
    assert screen.property("playing") is False

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

    expected_visibility = {
        "moduleLaboratoryLayerControl": {"module_3", "module_4", "module_5", "module_6", "module_8"},
        "moduleLaboratoryHeadControl": {"module_3", "module_4", "module_5", "module_6", "module_8"},
        "moduleLaboratoryTokenControl": {f"module_{index}" for index in range(2, 9)},
        "moduleLaboratoryCausalControl": {"module_6", "module_8"},
        "moduleLaboratoryTemperatureControl": {"module_7", "module_8"},
        "moduleLaboratoryTopKControl": {"module_7", "module_8"},
        "moduleLaboratoryTopPControl": {"module_7", "module_8"},
    }
    for module_id in SPECIALIZATIONS:
        view_model._course_controller.selectModule(module_id)
        screen.setProperty("moduleId", module_id)
        view_model.moduleLaboratoryController.explore(
            module_id, "texto", "inference", 1, 2, 1, 0.8, 5, 0.9, True
        )
        qapp.processEvents()
        if module_id == "module_5":
            title = view_model.moduleLaboratoryController.result["formula_demos"][
                "encoder_attention"
            ]["title"]
            assert "cabeza 3" in title
        for control_name, visible_modules in expected_visibility.items():
            control = controls_by_name[control_name]
            assert bool(control.property("visible")) is (module_id in visible_modules), (
                module_id,
                control_name,
            )

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
        content_tabs = window.findChild(QObject, "formulaAnimationContentTabs")
        phase_guidance = window.findChild(
            QObject, "formulaAnimationPhaseGuidance"
        )
        explanation_panel = window.findChild(
            QObject, "formulaAnimationExplanationPanel"
        )
        explanation = window.findChild(QObject, "formulaAnimationExplanation")
        caption = window.findChild(QObject, "formulaAnimationCaption")
        result_card = window.findChild(QObject, "formulaAnimationResultCard")
        result_text = window.findChild(QObject, "formulaAnimationResult")
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
                    content_tabs,
                    phase_guidance,
                    explanation_panel,
                explanation,
                caption,
                result_card,
                result_text,
                replay,
                play,
                speed,
                scrubber,
            )
        )
        assert formula_card.property("color") == window.property("formulaSurface")
        assert formula_text.property("color") == window.property("formulaInk")
        assert result_card.property("color") == window.property("resultSurface")
        assert result_text.property("color") == window.property("resultInk")

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
                    assert step["output"] in str(result_text.property("text"))
                    assert not warnings, (module_id, mode, step["id"], warnings)

        scene.setProperty("formulaExplanation", "Explicación del cálculo")
        scene.setProperty("animationDescription", "Resumen de tres tarjetas")
        for section, expected in ((0, (True, False)), (1, (False, True))):
            scene.setProperty("contentSection", section)
            qapp.processEvents()
            assert int(content_tabs.property("currentIndex")) == section
            assert (
                bool(loader.property("visible")),
                bool(explanation_panel.property("visible")),
            ) == expected
        assert bool(explanation.property("visible")) is True
        assert bool(caption.property("visible")) is True
        assert "tres tarjetas" not in str(caption.property("text")).lower()

        # Los controles de reproducción modifican realmente el estado de la
        # animación; el deslizador no es únicamente decorativo.
        scene.setProperty("reducedMotion", False)
        scene.setProperty("contentSection", 0)
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
        assert result_card.property("color") == window.property("resultSurface")
        assert result_text.property("color") == window.property("resultInk")
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
