"""Pruebas del formato portable y la compatibilidad de persistencia.

Los modelos de estas pruebas son deliberadamente diminutos.  El tokenizador
es un doble que expone el mismo contrato de metadatos que ``Tokenizer``, por
lo que las pruebas no descargan vocabularios ni necesitan acceso a red.
"""

from __future__ import annotations

from dataclasses import asdict
import hashlib
import json
from pathlib import Path
from typing import Any, Mapping
import zipfile

import pytest
import torch

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from model.persistencia import model_storage
from model.persistencia.model_storage import (
    VERSION_FORMATO_MODELO,
    cargar_checkpoint,
    cargar_modelo_portable,
    exportar_codigo_modelo,
    guardar_checkpoint,
    guardar_modelo_portable,
    importar_codigo_modelo,
    inspeccionar_modelo,
    verificar_integridad_modelo,
)


class _EncodingFalso:
    name = "p50k_base"


class TokenizerFalso:
    """Contrato minimo utilizado por ``guardar_modelo_portable``."""

    tipo_encoding = 2
    encoding = _EncodingFalso()
    vocab_size = 13

    def encode(self, texto: str) -> list[int]:
        return [ord(caracter) % self.vocab_size for caracter in texto]

    def decode(self, tokens: list[int]) -> str:
        return "".join(chr(token) for token in tokens)


def _crear_modelo(*, compartir_pesos: bool = True) -> Transformer:
    config = ConfiguracionTransformer(
        # 13 tokens base y tres especiales: pad, bos y eos.
        tamano_vocabulario=16,
        dimension_modelo=8,
        num_cabezas=2,
        num_capas=1,
        dimension_ff=16,
        longitud_maxima_secuencia=8,
        dropout=0.0,
        id_token_relleno=13,
    )
    torch.manual_seed(731)
    modelo = Transformer(config, compartir_pesos_salida=compartir_pesos)
    # Evita que una igualdad accidental de dos inicializaciones oculte que los
    # pesos realmente se leyeron del archivo.
    with torch.no_grad():
        for indice, parametro in enumerate(modelo.parameters(), start=1):
            valores = torch.arange(
                parametro.numel(), dtype=parametro.dtype, device=parametro.device
            ).reshape_as(parametro)
            parametro.copy_(valores.mul_(0.0001).add_(indice * 0.01))
    return modelo


def _assert_state_dict_exacto(
    esperado: Mapping[str, torch.Tensor], obtenido: Mapping[str, torch.Tensor]
) -> None:
    assert obtenido.keys() == esperado.keys()
    for nombre, tensor_esperado in esperado.items():
        tensor_obtenido = obtenido[nombre]
        assert tensor_obtenido.dtype == tensor_esperado.dtype, nombre
        assert tensor_obtenido.shape == tensor_esperado.shape, nombre
        assert torch.equal(tensor_obtenido.cpu(), tensor_esperado.cpu()), nombre


def _assert_estructura_exacta(esperado: Any, obtenido: Any) -> None:
    """Compara estados de optimizador que mezclan contenedores y tensores."""
    if isinstance(esperado, torch.Tensor):
        assert isinstance(obtenido, torch.Tensor)
        assert esperado.dtype == obtenido.dtype
        assert esperado.shape == obtenido.shape
        assert torch.equal(esperado.cpu(), obtenido.cpu())
    elif isinstance(esperado, Mapping):
        assert isinstance(obtenido, Mapping)
        assert obtenido.keys() == esperado.keys()
        for clave in esperado:
            _assert_estructura_exacta(esperado[clave], obtenido[clave])
    elif isinstance(esperado, (list, tuple)):
        assert isinstance(obtenido, type(esperado))
        assert len(obtenido) == len(esperado)
        for item_esperado, item_obtenido in zip(esperado, obtenido, strict=True):
            _assert_estructura_exacta(item_esperado, item_obtenido)
    else:
        assert obtenido == esperado


def _reescribir_zip(
    origen: Path,
    destino: Path,
    transformaciones: Mapping[str, Any],
) -> None:
    """Crea una copia alterada sin producir entradas ZIP duplicadas."""
    with zipfile.ZipFile(origen, "r") as archivo:
        entradas = {nombre: archivo.read(nombre) for nombre in archivo.namelist()}
    for nombre, transformar in transformaciones.items():
        entradas[nombre] = transformar(entradas[nombre])
    with zipfile.ZipFile(destino, "w", compression=zipfile.ZIP_STORED) as archivo:
        for nombre, contenido in entradas.items():
            archivo.writestr(nombre, contenido, compress_type=zipfile.ZIP_STORED)


@pytest.mark.parametrize("compartir_pesos", [True, False])
def test_portable_roundtrip_exacto_config_tokenizer_y_weight_tying(
    tmp_path: Path, compartir_pesos: bool
) -> None:
    modelo = _crear_modelo(compartir_pesos=compartir_pesos)
    estado_original = {
        nombre: tensor.detach().cpu().clone()
        for nombre, tensor in modelo.state_dict().items()
    }
    ruta_sin_extension = tmp_path / f"portable_{compartir_pesos}"

    descriptor_guardado = guardar_modelo_portable(
        ruta_sin_extension,
        modelo,
        TokenizerFalso(),
        nombre="Modelo minimo de prueba",
        metadata_extra={"proposito": "roundtrip"},
    )
    ruta = ruta_sin_extension.with_suffix(".tvismodel")

    assert ruta.is_file()
    assert descriptor_guardado["ruta"] == str(ruta.resolve())
    manifiesto = inspeccionar_modelo(ruta)
    assert manifiesto["schema"] == "tvismodel"
    assert manifiesto["schema_version"] == VERSION_FORMATO_MODELO
    assert manifiesto["nombre"] == "Modelo minimo de prueba"
    assert manifiesto["config"] == asdict(modelo.config)
    assert manifiesto["compartir_pesos_salida"] is compartir_pesos
    assert manifiesto["arquitectura"]["encoder_layers"] == 1
    assert manifiesto["arquitectura"]["decoder_layers"] == 1
    assert manifiesto["arquitectura"]["num_cabezas"] == 2
    assert manifiesto["arquitectura"]["d_model"] == 8
    assert manifiesto["arquitectura"]["context_length"] == 8
    assert manifiesto["tokenizer"] == {
        "tipo": "tiktoken",
        "tipo_encoding": 2,
        "encoding": "p50k_base",
        "vocab_size": 13,
        "pad": 13,
        "bos": 14,
        "eos": 15,
        "id_token_relleno": 13,
        "id_token_inicio": 14,
        "id_token_fin": 15,
    }
    assert manifiesto["capabilities"]["inferencia"] is True
    assert manifiesto["capabilities"]["tokenizador_incluido"] is True
    assert manifiesto["capabilities"]["reanudacion"] is False

    resultado = cargar_modelo_portable(ruta, dispositivo="cpu")
    assert asdict(resultado.modelo.config) == asdict(modelo.config)
    assert resultado.tipo_encoding == TokenizerFalso.tipo_encoding
    assert resultado.tokenizer_info == manifiesto["tokenizer"]
    assert resultado.metadata_extra == {"proposito": "roundtrip"}
    assert resultado.optimizer_state_dict is None
    assert resultado.reanudable is False
    _assert_state_dict_exacto(estado_original, resultado.modelo.state_dict())

    peso_embedding = resultado.modelo.embedding_salida.embedding.weight
    peso_salida = resultado.modelo.capa_salida.weight
    assert (peso_embedding.data_ptr() == peso_salida.data_ptr()) is compartir_pesos


def test_inspeccion_no_instancia_ni_carga_la_arquitectura(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    ruta = tmp_path / "inspeccion.tvismodel"
    guardar_modelo_portable(ruta, _crear_modelo(), TokenizerFalso())

    def _no_debe_construir(*args: Any, **kwargs: Any) -> None:
        raise AssertionError("inspeccionar_modelo no debe construir el Transformer")

    monkeypatch.setattr(model_storage, "_construir_modelo", _no_debe_construir)
    manifiesto = inspeccionar_modelo(ruta)

    assert manifiesto["arquitectura"]["num_capas"] == 1
    assert manifiesto["pesos"]["archivo"] == "weights.pt"


def test_portable_reanudable_conserva_optimizer_historial_y_hiperparametros(
    tmp_path: Path,
) -> None:
    modelo = _crear_modelo()
    optimizador = torch.optim.Adam(modelo.parameters(), lr=0.004)
    # Materializa momentos de Adam para probar un estado real, no solamente
    # sus param_groups vacios.
    for parametro in modelo.parameters():
        parametro.grad = torch.full_like(parametro, 0.125)
    optimizador.step()
    optimizador.zero_grad(set_to_none=True)

    estado_modelo = {
        nombre: tensor.detach().cpu().clone()
        for nombre, tensor in modelo.state_dict().items()
    }
    estado_optimizer = optimizador.state_dict()
    ruta = tmp_path / "reanudable.tvismodel"
    historial = [2.5, 1.25, 0.75]
    hiperparametros = {"learning_rate": 0.004, "batch_size": 4}

    guardar_modelo_portable(
        ruta,
        modelo,
        TokenizerFalso(),
        optimizador=optimizador,
        reanudable=True,
        epoca=3,
        siguiente_epoca=3,
        paso_epoca=7,
        paso_global=17,
        historial_perdidas=historial,
        hiperparametros_entrenamiento=hiperparametros,
        metadata_extra={"dataset": "sintetico"},
    )

    manifiesto = inspeccionar_modelo(ruta)
    assert manifiesto["entrenamiento"]["resume_available"] is True
    assert manifiesto["entrenamiento"]["epoca"] == 3
    assert manifiesto["entrenamiento"]["paso_global"] == 17
    assert manifiesto["entrenamiento"]["perdida_final"] == 0.75
    assert manifiesto["entrenamiento"]["estado"]["archivo"] == "training_state.pt"
    assert manifiesto["capabilities"]["resume_training"] is True
    # El formato conserva Adam, pero no promete RNG/sampler bit a bit.
    assert manifiesto["capabilities"]["exact_resume"] is False

    resultado = cargar_modelo_portable(ruta, dispositivo="cpu")
    _assert_state_dict_exacto(estado_modelo, resultado.modelo.state_dict())
    _assert_estructura_exacta(estado_optimizer, resultado.optimizer_state_dict)
    assert resultado.epoca == 3
    assert resultado.siguiente_epoca == 3
    assert resultado.paso_epoca == 7
    assert resultado.paso_global == 17
    assert resultado.historial_perdidas == historial
    assert resultado.hiperparametros_entrenamiento == hiperparametros
    assert resultado.metadata_extra == {"dataset": "sintetico"}
    assert resultado.tiene_estado_optimizador is True
    assert resultado.reanudable is True


def test_rechaza_hash_de_pesos_corrupto(tmp_path: Path) -> None:
    original = tmp_path / "original.tvismodel"
    corrupto = tmp_path / "hash_corrupto.tvismodel"
    guardar_modelo_portable(original, _crear_modelo(), TokenizerFalso())

    def _alterar_pesos(datos: bytes) -> bytes:
        assert datos
        return bytes([datos[0] ^ 0x01]) + datos[1:]

    _reescribir_zip(original, corrupto, {"weights.pt": _alterar_pesos})

    with pytest.raises(ValueError, match="hash de weights[.]pt no coincide"):
        cargar_modelo_portable(corrupto, dispositivo="cpu")
    with pytest.raises(ValueError, match="hash de weights[.]pt no coincide"):
        verificar_integridad_modelo(corrupto)


def test_rechaza_version_de_manifest_no_compatible(tmp_path: Path) -> None:
    original = tmp_path / "original.tvismodel"
    incompatible = tmp_path / "version_incompatible.tvismodel"
    guardar_modelo_portable(original, _crear_modelo(), TokenizerFalso())

    def _cambiar_version(datos: bytes) -> bytes:
        manifiesto = json.loads(datos.decode("utf-8"))
        manifiesto["schema_version"] = VERSION_FORMATO_MODELO + 1
        manifiesto["version"] = VERSION_FORMATO_MODELO + 1
        return json.dumps(manifiesto).encode("utf-8")

    _reescribir_zip(original, incompatible, {"manifest.json": _cambiar_version})

    with pytest.raises(ValueError, match="Version de modelo no compatible"):
        inspeccionar_modelo(incompatible)
    with pytest.raises(ValueError, match="Version de modelo no compatible"):
        cargar_modelo_portable(incompatible, dispositivo="cpu")


def test_codigo_tvis1_roundtrip_y_checksum(tmp_path: Path) -> None:
    original = tmp_path / "copiable.tvismodel"
    guardar_modelo_portable(original, _crear_modelo(), TokenizerFalso())

    codigo = exportar_codigo_modelo(original, max_bytes=original.stat().st_size)
    assert codigo.startswith("TVIS1:")
    assert codigo.split(":", 2)[1] == hashlib.sha256(original.read_bytes()).hexdigest()

    importado = importar_codigo_modelo(codigo, tmp_path / "pegado")
    assert importado == tmp_path / "pegado.tvismodel"
    assert importado.read_bytes() == original.read_bytes()
    resultado = cargar_modelo_portable(importado, dispositivo="cpu")
    _assert_state_dict_exacto(
        _crear_modelo().state_dict(), resultado.modelo.state_dict()
    )


def test_codigo_tvis1_rechaza_checksum_alterado(tmp_path: Path) -> None:
    ruta = tmp_path / "codigo.tvismodel"
    guardar_modelo_portable(ruta, _crear_modelo(), TokenizerFalso())
    codigo = exportar_codigo_modelo(ruta, max_bytes=ruta.stat().st_size)
    prefijo, _digest, contenido = codigo.split(":", 2)
    codigo_alterado = f"{prefijo}:{'0' * 64}:{contenido}"

    with pytest.raises(ValueError, match="checksum no coincide"):
        importar_codigo_modelo(codigo_alterado, tmp_path / "no_creado")
    assert not (tmp_path / "no_creado.tvismodel").exists()


def test_codigo_respeta_limites_de_exportacion_e_importacion(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    ruta = tmp_path / "grande_para_el_limite.tvismodel"
    guardar_modelo_portable(ruta, _crear_modelo(), TokenizerFalso())

    with pytest.raises(ValueError, match="excede el limite"):
        exportar_codigo_modelo(ruta, max_bytes=ruta.stat().st_size - 1)

    monkeypatch.setattr(model_storage, "_MAX_IMPORT_CODE_BYTES", 4)
    codigo_sobredimensionado = f"TVIS1:{'0' * 64}:AAAAAAAA"
    with pytest.raises(ValueError, match="excede el tamano maximo"):
        importar_codigo_modelo(codigo_sobredimensionado, tmp_path / "limite")


def test_checkpoint_legacy_roundtrip_usa_weights_only(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    modelo = _crear_modelo(compartir_pesos=False)
    esperado = {
        nombre: tensor.detach().cpu().clone()
        for nombre, tensor in modelo.state_dict().items()
    }
    ruta = tmp_path / "legacy.pt"
    guardar_checkpoint(
        ruta,
        modelo,
        epoca=4,
        paso_global=29,
        historial_perdidas=[1.0, 0.5],
        metadata_extra={"tipo_encoding": 2, "nota": "legacy seguro"},
    )

    torch_load_original = model_storage.torch.load
    llamadas: list[dict[str, Any]] = []

    def _load_vigilado(*args: Any, **kwargs: Any) -> Any:
        llamadas.append(dict(kwargs))
        return torch_load_original(*args, **kwargs)

    monkeypatch.setattr(model_storage.torch, "load", _load_vigilado)
    resultado = cargar_checkpoint(ruta, dispositivo="cpu")

    assert llamadas
    assert all(llamada.get("weights_only") is True for llamada in llamadas)
    assert asdict(resultado.modelo.config) == asdict(modelo.config)
    assert resultado.modelo.compartir_pesos_salida is False
    assert resultado.epoca == 4
    assert resultado.paso_global == 29
    assert resultado.historial_perdidas == [1.0, 0.5]
    assert resultado.tipo_encoding == 2
    assert resultado.metadata_extra == {
        "tipo_encoding": 2,
        "nota": "legacy seguro",
    }
    _assert_state_dict_exacto(esperado, resultado.modelo.state_dict())

    manifiesto = inspeccionar_modelo(ruta)
    assert manifiesto["schema"] == "checkpoint_legacy"
    assert manifiesto["es_legacy"] is True
    assert manifiesto["arquitectura"]["num_capas"] == 1
