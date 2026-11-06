"""El motor coincide con una implementación independiente en NumPy (RNF07)."""

from __future__ import annotations

import pytest
import torch

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from pruebas.auditoria import referencia_numpy
from pruebas.auditoria.auditar_exactitud import (
    TOLERANCIA_FLOAT32,
    TOLERANCIA_FLOAT64,
    comparar,
    configuraciones_sinteticas,
)


@pytest.mark.parametrize(
    "caso", configuraciones_sinteticas(), ids=lambda caso: caso[0]
)
def test_logits_y_atencion_coinciden_con_la_referencia(caso):
    _nombre, config, origen, destino = caso
    torch.manual_seed(3)
    diferencias = comparar(Transformer(config), origen, destino)

    assert diferencias["logits_float64"] <= TOLERANCIA_FLOAT64
    assert diferencias["atencion_float64"] <= TOLERANCIA_FLOAT64
    assert diferencias["logits_float32"] <= TOLERANCIA_FLOAT32


def test_la_referencia_detecta_un_error_de_formula(monkeypatch):
    # Sin esta prueba, una comparación que no mirara nada pasaría igual: se
    # altera una fórmula y la diferencia debe dejar de ser ruido de redondeo.
    _nombre, config, origen, destino = configuraciones_sinteticas()[0]
    torch.manual_seed(3)
    modelo = Transformer(config)
    monkeypatch.setitem(referencia_numpy.ACTIVACIONES, "relu", lambda x: x)

    assert comparar(modelo, origen, destino)["logits_float64"] > 1e-4
