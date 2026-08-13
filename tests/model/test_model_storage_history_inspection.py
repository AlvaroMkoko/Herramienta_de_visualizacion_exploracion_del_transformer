"""Pruebas dirigidas de la inspeccion ligera de modelos guardados."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest
import torch

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from model.persistencia import model_storage
from model.persistencia.model_storage import (
    guardar_checkpoint,
    guardar_modelo_portable,
    inspeccionar_historial_entrenamiento,
    inspeccionar_modelo,
)


class _EncodingFalso:
    name = "p50k_base"


class _TokenizerFalso:
    tipo_encoding = 2
    encoding = _EncodingFalso()
    vocab_size = 13


def _modelo() -> Transformer:
    config = ConfiguracionTransformer(
        tamano_vocabulario=16,
        dimension_modelo=8,
        num_cabezas=2,
        num_capas=1,
        dimension_ff=16,
        longitud_maxima_secuencia=8,
        dropout=0.0,
        id_token_relleno=13,
        activacion="gelu",
        usar_mascara_causal=True,
    )
    return Transformer(config, compartir_pesos_salida=True)


def test_inspeccion_portable_lee_solo_estado_y_expone_datos_reales(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    modelo = _modelo()
    optimizador = torch.optim.Adam(modelo.parameters(), lr=0.003)
    ruta = tmp_path / "historial.tvismodel"
    guardar_modelo_portable(
        ruta,
        modelo,
        _TokenizerFalso(),
        optimizador=optimizador,
        reanudable=True,
        epoca=2,
        siguiente_epoca=3,
        paso_epoca=4,
        paso_global=9,
        historial_perdidas=[2.0, 1.25],
        hiperparametros_entrenamiento={
            "learning_rate": 0.003,
            "batch_size": 2,
        },
        metadata_extra={"datasets": [{"nombre": "demo"}]},
    )

    cargas: list[str] = []
    load_original = model_storage._torch_load_seguro

    def _load_vigilado(origen: Any, **kwargs: Any) -> Any:
        cargas.append(Path(origen).name)
        return load_original(origen, **kwargs)

    def _no_construir(*args: Any, **kwargs: Any) -> None:
        raise AssertionError("La inspeccion no debe construir el Transformer")

    monkeypatch.setattr(model_storage, "_torch_load_seguro", _load_vigilado)
    monkeypatch.setattr(model_storage, "_construir_modelo", _no_construir)
    resultado = inspeccionar_historial_entrenamiento(ruta)

    assert cargas == ["training_state.pt"]
    assert resultado["historial_perdidas"] == [2.0, 1.25]
    assert resultado["epoca"] == 2
    assert resultado["siguiente_epoca"] == 3
    assert resultado["paso_epoca"] == 4
    assert resultado["paso_global"] == 9
    assert resultado["perdida_final"] == 1.25
    assert resultado["hiperparametros_entrenamiento"] == {
        "learning_rate": 0.003,
        "batch_size": 2,
    }
    assert resultado["metadata_extra"] == {
        "datasets": [{"nombre": "demo"}]
    }
    assert resultado["resume_available"] is True
    assert resultado["estado_optimizador_disponible"] is True
    assert "validacion" not in resultado
    assert "perplexity" not in resultado
    assert "precision" not in resultado

    descriptor = inspeccionar_modelo(ruta)
    assert descriptor["dtype"] == "float32"
    assert descriptor["num_tensores"] == len(modelo.state_dict())
    assert descriptor["weight_tying"] is True
    assert descriptor["checksum_pesos"]
    assert descriptor["checksum_estado_entrenamiento"]
    assert descriptor["arquitectura"]["activation"] == "gelu"
    assert descriptor["arquitectura"]["causal_mask"] is True
    assert descriptor["arquitectura"]["normalization_order"] == "post_norm"


def test_inspeccion_legacy_usa_weights_only_y_recupera_hiperparametros(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    ruta = tmp_path / "legacy.pt"
    guardar_checkpoint(
        ruta,
        _modelo(),
        epoca=1,
        paso_global=5,
        historial_perdidas=[3.0, 2.0],
        metadata_extra={
            "tipo_encoding": 2,
            "hiperparametros_entrenamiento": {"tasa_aprendizaje": 0.01},
        },
    )
    torch_load_original = model_storage.torch.load
    llamadas: list[dict[str, Any]] = []

    def _load_vigilado(*args: Any, **kwargs: Any) -> Any:
        llamadas.append(dict(kwargs))
        return torch_load_original(*args, **kwargs)

    monkeypatch.setattr(model_storage.torch, "load", _load_vigilado)
    resultado = inspeccionar_historial_entrenamiento(ruta)

    assert llamadas and all(
        llamada.get("weights_only") is True for llamada in llamadas
    )
    assert resultado["es_legacy"] is True
    assert resultado["historial_perdidas"] == [3.0, 2.0]
    assert resultado["epoca"] == 1
    assert resultado["paso_global"] == 5
    assert resultado["hiperparametros_entrenamiento"] == {
        "tasa_aprendizaje": 0.01
    }
