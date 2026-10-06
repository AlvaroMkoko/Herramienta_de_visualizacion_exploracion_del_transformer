"""El laboratorio modular usa activaciones reales y conserva valores completos."""

from __future__ import annotations

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from viewmodel.module_laboratory_controller import ModuleLaboratoryController


class TokenizerStub:
    def encode(self, _text):
        return [3, 7, 9]

    def decode(self, ids):
        return f"t{ids[0]}"


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
