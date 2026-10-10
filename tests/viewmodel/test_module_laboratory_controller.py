"""El laboratorio modular usa activaciones reales y conserva valores completos."""

from __future__ import annotations

import math

import pytest
from PySide6.QtCore import QObject
import torch

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from viewmodel.module_laboratory_controller import ModuleLaboratoryController


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
