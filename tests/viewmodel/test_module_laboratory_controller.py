"""El laboratorio modular usa activaciones reales y conserva valores completos."""

from __future__ import annotations

import math

import pytest
from PySide6.QtCore import QObject
import torch

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from viewmodel.formula_demos import FormulaDemoBuilder, _without_data
from viewmodel.module_laboratory_controller import (
    VALUE_KIND_CONTINUOUS,
    VALUE_KIND_TOKEN_IDS,
    ModuleLaboratoryController,
)


class TokenizerStub:
    vocab_size = 36

    def encode(self, _text):
        return [3, 7, 9]

    def decode(self, ids):
        return f"t{ids[0]}"


class _ExecutionState:
    esta_entrenando = False
    esta_generando = False
    esta_pausado = False


class _Owner(QObject):
    def __init__(self):
        super().__init__()
        self._training_controller = _ExecutionState()
        self._inference_controller = _ExecutionState()


@pytest.fixture
def specialized_laboratory():
    config = ConfiguracionTransformer(
        tamano_vocabulario=40,
        dimension_modelo=16,
        num_cabezas=4,
        num_capas=2,
        dimension_ff=32,
        longitud_maxima_secuencia=12,
        dropout=0.0,
        id_token_relleno=0,
    )
    model = Transformer(config)
    controller = ModuleLaboratoryController()
    controller.set_model(model, TokenizerStub())
    return controller, model


EXPECTED_REAL_PANELS = {
    "module_1": {"token_ids", "padding_mask"},
    "module_2": {"embedding", "position", "embedding_plus_position"},
    "module_3": {"q", "k", "v", "scores", "attention_weights", "attention_output"},
    "module_4": {"head_attention", "head_output", "concatenated", "projected"},
    "module_5": {"encoder_input", "attention_residual", "ffn_hidden", "encoder_output"},
    "module_6": {
        "causal_mask",
        "masked_attention",
        "cross_attention",
        "decoder_output",
    },
    "module_7": {"logits", "probabilities"},
    "module_8": {"tokens", "embedding", "encoder", "decoder", "logits"},
}

REQUIRED_STEP_FIELDS = {
    "id",
    "title",
    "formula",
    "explanation",
    "input",
    "output",
    "visual",
    "panel_key",
}


def _parameter_snapshot(model):
    return {
        name: parameter.detach().clone() for name, parameter in model.named_parameters()
    }


def _assert_parameters_unchanged(model, before):
    assert before.keys() == dict(model.named_parameters()).keys()
    for name, parameter in model.named_parameters():
        assert torch.equal(parameter.detach(), before[name]), name


def _run_exploration(
    controller,
    module_id: str,
    mode: str,
    *,
    layer: int = 1,
    head: int = 2,
    token: int = 1,
):
    controller.explore(
        module_id,
        "texto de prueba",
        mode,
        layer,
        head,
        token,
        0.8,
        5,
        0.9,
        True,
    )
    return controller.result


def test_laboratorio_extrae_qkv_y_pesos_reales():
    config = ConfiguracionTransformer(
        tamano_vocabulario=40,
        dimension_modelo=16,
        num_cabezas=4,
        num_capas=1,
        dimension_ff=32,
        longitud_maxima_secuencia=12,
        dropout=0.0,
    )
    controller = ModuleLaboratoryController()
    controller.set_model(Transformer(config), TokenizerStub())

    controller.analyze("module_3", "texto", 0, 1.0, 10, 0.9, True)

    result = controller.result
    assert result["source"] == "real_model"
    assert [panel["key"] for panel in result["panels"]] == [
        "q",
        "k",
        "v",
        "scores",
        "attention_weights",
        "attention_output",
    ]
    assert controller.fullValueLength("q") > 0
    assert len(controller.fullValues("q", 0, 8)) == 8


@pytest.mark.parametrize("mode", ["training", "inference"])
def test_los_ocho_laboratorios_tienen_flujo_especializado_y_no_mutan_el_modelo(
    specialized_laboratory, mode
):
    controller, model = specialized_laboratory

    for module_id, expected_panels in EXPECTED_REAL_PANELS.items():
        parameters_before = _parameter_snapshot(model)
        gradients_before = {
            name: None if parameter.grad is None else parameter.grad.detach().clone()
            for name, parameter in model.named_parameters()
        }
        training_before = model.training

        result = _run_exploration(controller, module_id, mode)

        assert result["module_id"] == module_id
        assert result["mode"] == mode
        assert result["source"] == "real_model"
        assert result["real_data"] is True
        assert result["specialization"]
        assert result["forward_detail"]
        assert expected_panels <= {panel["key"] for panel in result["panels"]}
        assert len(result["steps"]) >= 5
        assert all(REQUIRED_STEP_FIELDS <= step.keys() for step in result["steps"])
        assert all(step["explanation"] for step in result["steps"])
        assert result["experiment"]["weights_modified"] is False
        assert model.training is training_before
        _assert_parameters_unchanged(model, parameters_before)
        for name, parameter in model.named_parameters():
            previous = gradients_before[name]
            if previous is None:
                assert parameter.grad is None, name
            else:
                assert torch.equal(parameter.grad, previous), name

        if mode == "training":
            training = result["training"]
            assert result["experiment"]["didactic_example"] is True
            assert result["experiment"]["didactic_note"]
            assert math.isfinite(training["loss"])
            assert training["update_applied"] is False
            assert training["trainable"] is (module_id != "module_1")
            if module_id != "module_1":
                assert training["gradients"]
                assert training["gradient_norm"] >= 0
                assert {
                    "parameter_before",
                    "component_gradient",
                    "hypothetical_update",
                } <= {panel["key"] for panel in result["panels"]}
        else:
            snapshot = result["inference_snapshot"]
            assert snapshot["predicciones_top"]
            assert (
                snapshot["token_elegido"]["token_id"] == result["selected_token"]["id"]
            )


def test_controles_seleccionan_capa_cabeza_y_token_reales(specialized_laboratory):
    controller, _model = specialized_laboratory

    result = _run_exploration(
        controller, "module_4", "inference", layer=1, head=2, token=1
    )

    assert result["selected_layer"] == 1
    assert result["selected_head"] == 2
    assert result["selected_token_index"] == 1
    assert result["forward_detail"]["encoder"][1]["atencion"]["query_seleccionada"] == 1
    head_panel = next(
        panel for panel in result["panels"] if panel["key"] == "head_attention"
    )
    assert "3" in head_panel["title"]
    assert head_panel["shape"] == [3, 3]
    assert head_panel["matrix"]


def test_salida_separa_cross_entropy_de_los_filtros_de_inferencia(
    specialized_laboratory,
):
    controller, _model = specialized_laboratory

    training = _run_exploration(controller, "module_7", "training")
    inference = _run_exploration(controller, "module_7", "inference")

    training_ids = {step["id"] for step in training["steps"]}
    inference_ids = {step["id"] for step in inference["steps"]}
    assert {"loss", "backward", "update"} <= training_ids
    assert "top_k" not in training_ids
    assert {"temperature", "top_k", "top_p", "softmax", "feedback"} <= inference_ids
    assert "loss" not in inference_ids


def test_desactivar_mascara_se_marca_como_contrafactual(specialized_laboratory):
    controller, _model = specialized_laboratory

    controller.explore("module_6", "texto", "inference", 1, 2, 2, 0.8, 5, 0.9, True)
    causal = controller.result
    causal_panel = next(
        panel for panel in causal["panels"] if panel["key"] == "causal_mask"
    )

    controller.explore("module_6", "texto", "inference", 1, 2, 2, 0.8, 5, 0.9, False)
    counterfactual = controller.result
    counterfactual_panel = next(
        panel for panel in counterfactual["panels"] if panel["key"] == "causal_mask"
    )

    assert causal["experiment"]["causal_counterfactual"] is False
    assert counterfactual["experiment"]["causal_counterfactual"] is True
    assert causal_panel["matrix"][0][-1] is False
    assert all(all(row) for row in counterfactual_panel["matrix"])


@pytest.mark.parametrize("active_controller", ["training", "inference"])
def test_no_compite_con_otro_hilo_que_usa_el_mismo_modelo(active_controller):
    owner = _Owner()
    config = ConfiguracionTransformer(
        tamano_vocabulario=40,
        dimension_modelo=16,
        num_cabezas=4,
        num_capas=1,
        dimension_ff=32,
        longitud_maxima_secuencia=12,
        dropout=0.0,
        id_token_relleno=0,
    )
    controller = ModuleLaboratoryController(owner)
    controller.set_model(Transformer(config), TokenizerStub())
    messages = []
    controller.error.connect(messages.append)
    if active_controller == "training":
        owner._training_controller.esta_entrenando = True
    else:
        owner._inference_controller.esta_generando = True

    controller.explore("module_3", "texto", "inference", 0, 0, 0, 1.0, 5, 0.9, True)

    assert controller.result == {}
    assert messages
    assert "Pausa" in messages[0]


def _close(value, expected, tolerance=1e-3):
    return abs(float(value) - float(expected)) <= tolerance


@pytest.mark.parametrize("mode", ["training", "inference"])
def test_cada_paso_trae_una_formula_animable_con_cuentas_exactas(
    specialized_laboratory, mode
):
    """La animación de cada fórmula reproduce el resultado real del modelo."""
    controller, _model = specialized_laboratory

    for module_id in EXPECTED_REAL_PANELS:
        result = _run_exploration(controller, module_id, mode, token=2)
        demos = result["formula_demos"]
        for step in result["steps"]:
            demo = demos.get(step["id"])
            assert demo, (module_id, mode, step["id"])
            assert demo["kind"] != "unavailable", (module_id, step["id"], demo)
            assert demo["formula"] == step["formula"]
            assert demo["title"] and demo["caption"]
            assert demo["animation_explanation"], (module_id, mode, step["id"])
            assert "tres tarjetas" not in demo["animation_explanation"].lower()
            assert not demo["animation_explanation"].startswith(
                "Sigue las fases de la barra inferior"
            ), (module_id, mode, step["id"], demo["kind"])
            assert "phase_explanations" in demo

            kind = demo["kind"]
            if kind in {
                "positional",
                "projection",
                "mask_row",
                "softmax",
                "weighted_sum",
                "multi_softmax",
                "layernorm",
                "ffn",
                "cross_entropy",
                "causal_mask",
                "sampling",
            }:
                assert demo["phase_explanations"], (module_id, step["id"], kind)
            if kind == "softmax":
                assert len(demo["phase_explanations"]) == 4
                assert "sum" in demo["phase_explanations"][-1].lower()
            if kind == "projection":
                for output in demo["outputs"]:
                    total = sum(output["products"]) + output["hidden_sum"]
                    total += output["bias"] or 0.0
                    if output["divisor"]:
                        total /= output["divisor"]
                    assert _close(total, output["result"]), (module_id, step["id"])
                    if output["vector"]:
                        assert _close(
                            output["vector"][output["highlight"]], output["result"]
                        ), (module_id, step["id"])
            elif kind == "sum":
                for a, b, c in zip(demo["a"], demo["b"], demo["c"]):
                    assert _close(a + b, c), (module_id, step["id"])
            elif kind == "layernorm":
                values = zip(
                    demo["normalized"], demo["gamma"], demo["beta"], demo["output"]
                )
                for normalized, gamma, beta, output in values:
                    assert _close(normalized * gamma + beta, output), (
                        module_id,
                        step["id"],
                    )
            elif kind == "softmax":
                assert _close(
                    sum(demo["probs"]) + demo["rest_prob"], 1.0, 1e-3
                ), (module_id, step["id"])
                for exp, prob, allowed in zip(
                    demo["exps"], demo["probs"], demo["allowed"]
                ):
                    expected = exp / demo["total"] if allowed else 0.0
                    assert _close(prob, expected), (module_id, step["id"])
            elif kind == "weighted_sum":
                for dim, value in enumerate(demo["result"]):
                    total = sum(
                        weight * vector[dim]
                        for weight, vector in zip(demo["weights"], demo["vectors"])
                    )
                    assert _close(total, value), (module_id, step["id"])
            elif kind == "cross_entropy":
                assert _close(
                    -math.log(demo["target"]["prob"]), demo["loss"]
                ), (module_id, step["id"])
            elif kind == "update":
                for theta, gradient, updated in zip(
                    demo["theta"], demo["gradient"], demo["updated"]
                ):
                    assert _close(
                        theta - demo["learning_rate"] * gradient, updated, 1e-5
                    ), (module_id, step["id"])


def test_las_explicaciones_describen_la_variante_que_realmente_se_anima(
    specialized_laboratory,
):
    """No se reutiliza texto de padding, sesgo o residual cuando no aplica."""
    controller, _model = specialized_laboratory

    training = _run_exploration(controller, "module_1", "training")
    training_batch = training["formula_demos"]["batch"]["animation_explanation"]
    assert "PAD" in training_batch
    assert "matriz rectangular" in training_batch

    inference = _run_exploration(controller, "module_1", "inference")
    inference_batch = inference["formula_demos"]["batch"]["animation_explanation"]
    assert "Tmax" in inference_batch
    assert "fuera del contexto" in inference_batch
    assert "completa" not in inference_batch

    attention = _run_exploration(controller, "module_3", "inference")
    assert "sesgo" in attention["formula_demos"]["qkv"]["animation_explanation"]
    assert "sesgo" not in attention["formula_demos"]["dot"]["animation_explanation"]

    encoder = _run_exploration(controller, "module_5", "inference")
    norm_without_sum = encoder["formula_demos"]["norm_1"]
    norm_with_sum = encoder["formula_demos"]["norm_2"]
    assert "ya entra a LayerNorm" in norm_without_sum["animation_explanation"]
    assert norm_without_sum["phase_explanations"][0].startswith("Lee el vector")
    assert "suma residual" in norm_with_sum["animation_explanation"]
    assert norm_with_sum["phase_explanations"][0].startswith("Suma el atajo")

    activation = encoder["formula_demos"]["ffn_activation"]
    assert activation["name"] == "ReLU"
    assert "valores positivos" in activation["animation_explanation"]
    assert "negativos a cero" in activation["animation_explanation"]


def test_mascara_causal_animada_muestra_futuro_bloqueado_en_inferencia(
    specialized_laboratory,
):
    controller, _model = specialized_laboratory

    result = _run_exploration(controller, "module_6", "inference", token=2)
    demo = result["formula_demos"]["masked_attention"]

    assert demo["kind"] == "softmax"
    assert False in demo["allowed"]
    for allowed, probability in zip(demo["allowed"], demo["probs"]):
        if not allowed:
            assert probability == 0.0


@pytest.mark.parametrize(
    ("demo", "esperado"),
    [
        # Todos los campos de datos vacíos: no hay nada que animar.
        ({"kind": "backward", "title": "g", "gradient": [], "parameters": []}, True),
        ({"kind": "weighted_sum", "labels": [], "extra": {}}, True),
        # Un solo campo con datos basta; los opcionales vacíos son legítimos.
        ({"kind": "map", "inputs": [1.0], "labels": [], "dropped": []}, False),
        ({"kind": "weighted_sum", "labels": [], "extra": {"values": [0.5]}}, False),
        # Sin campos de datos (solo escalares) no se puede juzgar: se conserva.
        ({"kind": "no_grad", "title": "sin gradiente", "loss": None}, False),
    ],
)
def test_without_data_solo_marca_demos_sin_ningun_dato(demo, esperado):
    assert _without_data(demo) is esperado


def test_build_convierte_un_demo_sin_datos_en_unavailable():
    class _ConstructorDePrueba(FormulaDemoBuilder):
        def __init__(self):  # build() no usa el contexto del modelo
            pass

        def _module_prueba(self, identifier):
            if identifier == "vacio":
                return {"kind": "backward", "gradient": [], "parameters": []}
            return {"kind": "map", "inputs": [1.0], "dropped": []}

    demos = _ConstructorDePrueba().build(
        "module_prueba",
        [{"id": "vacio", "formula": "g = ∂L/∂θ"}, {"id": "lleno", "formula": "y = f(x)"}],
    )
    assert demos["vacio"]["kind"] == "unavailable"
    assert "vacio" in demos["vacio"]["caption"]
    assert demos["vacio"]["formula"] == "g = ∂L/∂θ"
    assert demos["lleno"]["kind"] == "map"


def _panels_by_key(result):
    return {panel["key"]: panel for panel in result["panels"]}


def test_paneles_de_ids_declaran_su_tipo_y_traen_fichas(specialized_laboratory):
    # Un id de token es categórico: la vista lo dibuja como ficha «texto · id»
    # en vez de mapa de calor. Para eso el panel lo declara y trae el texto.
    controller, _model = specialized_laboratory
    controller.explore("module_1", "texto", "training", 0, 0, 0, 0.8, 5, 0.9, True)
    panels = _panels_by_key(controller.result)

    token_ids = panels["token_ids"]
    assert token_ids["value_kind"] == VALUE_KIND_TOKEN_IDS
    assert [len(row) for row in token_ids["token_labels"]] == [
        len(row) for row in token_ids["matrix"]
    ]
    assert token_ids["token_labels"][0] == ["t3", "t7", "t9"]
    # La fila didáctica truncada se rellena con PAD, que se nombra.
    assert "PAD" in token_ids["token_labels"][1]

    decoder = panels["decoder_tokens"]
    assert decoder["value_kind"] == VALUE_KIND_TOKEN_IDS
    assert decoder["token_labels"][0][0] == "BOS"

    # Las posiciones son ordinales y serán el siguiente tipo discreto; hoy
    # siguen como continuas a propósito.
    assert panels["positions"]["value_kind"] == VALUE_KIND_CONTINUOUS
    assert "token_labels" not in panels["positions"]
    assert panels["padding_mask"]["value_kind"] == VALUE_KIND_CONTINUOUS


@pytest.mark.parametrize(
    ("module_id", "mode", "key"),
    [
        ("module_6", "inference", "decoder_tokens"),
        ("module_7", "inference", "selected_token"),
        ("module_7", "training", "training_targets"),
        ("module_8", "inference", "tokens"),
        ("module_8", "inference", "selected_token"),
    ],
)
def test_los_demas_paneles_de_ids_tambien_se_declaran(
    specialized_laboratory, module_id, mode, key
):
    controller, _model = specialized_laboratory
    controller.explore(module_id, "texto", mode, 0, 0, 0, 0.8, 5, 0.9, True)
    panel = _panels_by_key(controller.result)[key]
    assert panel["value_kind"] == VALUE_KIND_TOKEN_IDS
    assert panel["token_labels"] and panel["token_labels"][0]


def test_los_paneles_continuos_no_traen_fichas(specialized_laboratory):
    controller, _model = specialized_laboratory
    controller.explore("module_3", "texto", "inference", 0, 0, 0, 0.8, 5, 0.9, True)
    for panel in controller.result["panels"]:
        assert panel["value_kind"] == VALUE_KIND_CONTINUOUS, panel["key"]
        assert "token_labels" not in panel


def test_value_kind_desconocido_se_rechaza(specialized_laboratory):
    # Un tipo que la vista no conoce caería en "continuo" sin avisar.
    controller, _model = specialized_laboratory
    with pytest.raises(ValueError):
        controller._panel("x", "X", "", torch.zeros(2, 2), value_kind="positions")


def test_pad_se_rotula_por_posicion_aunque_su_id_sea_un_token_real():
    # El PAD de este modelo (7) es también un token que produce el
    # tokenizador. Rotular por valor llamaría «PAD» al token real t7 y
    # enseñaría algo falso: el rol sale de cómo se construyó cada fila.
    config = ConfiguracionTransformer(
        tamano_vocabulario=40,
        dimension_modelo=16,
        num_cabezas=4,
        num_capas=2,
        dimension_ff=32,
        longitud_maxima_secuencia=12,
        dropout=0.0,
        id_token_relleno=7,
    )
    controller = ModuleLaboratoryController()
    controller.set_model(Transformer(config), TokenizerStub())
    controller.explore("module_1", "texto", "training", 0, 0, 0, 0.8, 5, 0.9, True)
    panels = _panels_by_key(controller.result)

    token_ids = panels["token_ids"]
    assert token_ids["matrix"][0] == [3, 7, 9]
    assert token_ids["token_labels"][0] == ["t3", "t7", "t9"]
    # La fila truncada sí tiene relleno, con el mismo id 7, y ahí es PAD.
    assert token_ids["matrix"][1] == [3, 7, 7]
    assert token_ids["token_labels"][1] == ["t3", "PAD", "PAD"]

    decoder = panels["decoder_tokens"]
    assert decoder["token_labels"][0] == ["BOS", "t3", "t7", "t9"]
    assert decoder["token_labels"][1][:2] == ["BOS", "t3"]
    assert set(decoder["token_labels"][1][2:]) == {"PAD"}

    # EOS también por posición: se añadió al final del objetivo.
    controller.explore("module_7", "texto", "training", 0, 0, 0, 0.8, 5, 0.9, True)
    targets = _panels_by_key(controller.result)["training_targets"]
    assert targets["token_labels"][0] == ["t3", "t7", "t9", "EOS"]


def test_prefijo_de_inferencia_conserva_un_token_real_con_el_id_de_pad():
    # En inferencia el objetivo nunca se rellena, así que no hay PAD que
    # quitar. Un filtro por id borraría el token real t7 del prefijo.
    config = ConfiguracionTransformer(
        tamano_vocabulario=40,
        dimension_modelo=16,
        num_cabezas=4,
        num_capas=2,
        dimension_ff=32,
        longitud_maxima_secuencia=12,
        dropout=0.0,
        id_token_relleno=7,
    )
    controller = ModuleLaboratoryController()
    controller.set_model(Transformer(config), TokenizerStub())
    # token_index=2 → prefijo del decoder [BOS, 3, 7].
    controller.explore("module_7", "texto", "inference", 0, 0, 2, 0.8, 5, 0.9, True)
    snapshot = controller.result["inference_snapshot"]

    salida = [token["token_id"] for token in snapshot["tokens_salida"]]
    assert salida[:2] == [3, 7]
    assert snapshot["tokens_salida_total"] == 3
