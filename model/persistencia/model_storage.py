"""Persistencia segura de modelos Transformer.

Este modulo mantiene el formato historico ``.pt`` y agrega el formato
portable ``.tvismodel``.  Un ``.tvismodel`` es un ZIP sin compresion que
contiene un manifiesto JSON inspeccionable, los pesos y, opcionalmente, el
estado necesario para continuar el entrenamiento.

Los archivos de PyTorch se cargan siempre con ``weights_only=True``.  Esto
evita ejecutar objetos pickle arbitrarios al importar un modelo compartido.
"""

from __future__ import annotations

import base64
import binascii
import copy
import datetime
import hashlib
import io
import json
import math
import os
import re
import tempfile
import uuid
import zipfile
from collections.abc import Mapping
from dataclasses import asdict, fields
from pathlib import Path
from typing import Any

import torch

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer


VERSION_FORMATO_CHECKPOINT = 1
VERSION_FORMATO_MODELO = 1
SCHEMA_MODELO = "tvismodel"
EXTENSION_MODELO = ".tvismodel"
PREFIJO_CODIGO_MODELO = "TVIS1"
MAX_BYTES_CODIGO_MODELO = 5 * 1024 * 1024
# Base64 ocupa como maximo cuatro caracteres por cada tres bytes, mas el
# prefijo y el SHA-256. Sirve para rechazar antes de duplicar texto enorme.
MAX_CARACTERES_CODIGO_MODELO = ((MAX_BYTES_CODIGO_MODELO + 2) // 3) * 4 + 80

# Se replica la lista corta del wrapper de tokenizacion para que importar la
# persistencia (incluida la carga de checkpoints legacy) no obligue a tener
# ``tiktoken`` inicializado. Al reconstruir el tokenizador, su propia clase
# vuelve a validar el indice.
ENCODINGS = ("o200k_base", "cl100k_base", "p50k_base")
# Se usan solamente para reconocer checkpoints legacy que no guardaban el
# indice del encoding. Los modelos portables siempre declaran ambos valores y
# se validan contra el Tokenizer real al activarlos desde la interfaz.
VOCABULARIOS_CONOCIDOS = (200_019, 100_277, 50_281)

_ARCHIVO_MANIFEST = "manifest.json"
_ARCHIVO_PESOS = "weights.pt"
_ARCHIVO_ENTRENAMIENTO = "training_state.pt"

# Limites defensivos. Son suficientemente amplios para modelos locales, pero
# impiden que un manifiesto malicioso solicite arquitecturas absurdas o que un
# ZIP pequeno anuncie entradas desmesuradas.
_MAX_MANIFEST_BYTES = 2 * 1024 * 1024
_MAX_WEIGHTS_BYTES = 2 * 1024 * 1024 * 1024
_MAX_TRAINING_STATE_BYTES = 4 * 1024 * 1024 * 1024
# La interfaz permite configuraciones de menos de 200 M de parametros. Este
# margen admite todos sus controles actuales sin dejar que un manifiesto
# pequeño fuerce una asignacion de decenas de GB antes de validar los pesos.
_MAX_MODEL_PARAMETERS = 250_000_000
_MAX_STATE_TENSORS = 200_000
_MAX_HISTORY_ITEMS = 10_000_000
_MAX_NESTED_ITEMS = 2_000_000
_MAX_NESTING_DEPTH = 64
_MAX_IMPORT_CODE_BYTES = MAX_BYTES_CODIGO_MODELO


class ResultadoCarga:
    """Resultado uniforme al cargar un checkpoint o modelo portable.

    Los primeros seis argumentos conservan la API del proyecto anterior.
    Los atributos adicionales permiten a la interfaz presentar capacidades y
    reconstruir el tokenizador sin inferir informacion del nombre de archivo.
    """

    def __init__(
        self,
        modelo: Transformer,
        optimizer_state_dict: dict[str, Any] | None,
        epoca: int | None,
        paso_global: int | None,
        historial_perdidas: list[float],
        metadata_extra: dict[str, Any],
        manifest: dict[str, Any] | None = None,
        hiperparametros_entrenamiento: dict[str, Any] | None = None,
        tipo_encoding: int | None = None,
        siguiente_epoca: int | None = None,
        paso_epoca: int | None = None,
    ) -> None:
        self.modelo = modelo
        self.optimizer_state_dict = optimizer_state_dict
        self.epoca = epoca
        self.paso_global = paso_global
        self.historial_perdidas = historial_perdidas
        self.metadata_extra = metadata_extra
        self.manifest = manifest or {}
        self.hiperparametros_entrenamiento = hiperparametros_entrenamiento or {}
        self.tipo_encoding = tipo_encoding
        self.siguiente_epoca = siguiente_epoca
        self.paso_epoca = paso_epoca
        self.tokenizer_info = self.manifest.get("tokenizer", {})

    @property
    def tiene_estado_optimizador(self) -> bool:
        return self.optimizer_state_dict is not None

    @property
    def reanudable(self) -> bool:
        entrenamiento = self.manifest.get("entrenamiento", {})
        return bool(entrenamiento.get("resume_available", self.tiene_estado_optimizador))


# ---------------------------------------------------------------------------
# Utilidades de validacion y serializacion
# ---------------------------------------------------------------------------


def _es_entero(valor: Any) -> bool:
    return isinstance(valor, int) and not isinstance(valor, bool)


def _validar_entero_opcional(nombre: str, valor: Any) -> int | None:
    if valor is None:
        return None
    if not _es_entero(valor) or valor < 0:
        raise ValueError(f"{nombre} debe ser un entero no negativo o None.")
    return valor


def _validar_historial(valor: Any) -> list[float]:
    if valor is None:
        return []
    if not isinstance(valor, (list, tuple)):
        raise ValueError("historial_perdidas debe ser una lista de numeros.")
    if len(valor) > _MAX_HISTORY_ITEMS:
        raise ValueError("historial_perdidas excede el limite permitido.")

    resultado: list[float] = []
    for item in valor:
        if isinstance(item, bool) or not isinstance(item, (int, float)):
            raise ValueError("historial_perdidas contiene un valor no numerico.")
        numero = float(item)
        if not math.isfinite(numero):
            raise ValueError("historial_perdidas contiene NaN o infinito.")
        resultado.append(numero)
    return resultado


def _a_json_seguro(valor: Any, *, ruta: str = "valor", profundidad: int = 0) -> Any:
    """Convierte metadatos comunes a una estructura JSON sin objetos pickle."""
    if profundidad > _MAX_NESTING_DEPTH:
        raise ValueError(f"{ruta} excede la profundidad maxima permitida.")
    if valor is None or isinstance(valor, (str, bool)):
        return valor
    if isinstance(valor, Path):
        return str(valor)
    if isinstance(valor, (datetime.datetime, datetime.date)):
        return valor.isoformat()
    if _es_entero(valor):
        return valor
    if isinstance(valor, float):
        if not math.isfinite(valor):
            raise ValueError(f"{ruta} contiene NaN o infinito.")
        return valor
    if isinstance(valor, Mapping):
        if len(valor) > _MAX_NESTED_ITEMS:
            raise ValueError(f"{ruta} contiene demasiados elementos.")
        resultado = {}
        for clave, item in valor.items():
            if not isinstance(clave, str):
                raise ValueError(f"Las claves de {ruta} deben ser texto.")
            resultado[clave] = _a_json_seguro(
                item, ruta=f"{ruta}.{clave}", profundidad=profundidad + 1
            )
        return resultado
    if isinstance(valor, (list, tuple)):
        if len(valor) > _MAX_NESTED_ITEMS:
            raise ValueError(f"{ruta} contiene demasiados elementos.")
        return [
            _a_json_seguro(item, ruta=f"{ruta}[{indice}]", profundidad=profundidad + 1)
            for indice, item in enumerate(valor)
        ]
    raise ValueError(f"{ruta} contiene un tipo no portable: {type(valor).__name__}.")


def _validar_estructura_torch_segura(
    valor: Any, *, ruta: str = "estado", profundidad: int = 0, contador: list[int] | None = None
) -> None:
    """Valida los tipos que admitimos dentro de estados de optimizador."""
    if profundidad > _MAX_NESTING_DEPTH:
        raise ValueError(f"{ruta} excede la profundidad maxima permitida.")
    if contador is None:
        contador = [0]
    contador[0] += 1
    if contador[0] > _MAX_NESTED_ITEMS:
        raise ValueError(f"{ruta} contiene demasiados elementos.")

    if valor is None or isinstance(valor, (str, bool, bytes, torch.Tensor)):
        return
    if _es_entero(valor):
        return
    if isinstance(valor, float):
        if not math.isfinite(valor):
            raise ValueError(f"{ruta} contiene NaN o infinito.")
        return
    if isinstance(valor, Mapping):
        for clave, item in valor.items():
            if not isinstance(clave, (str, int)) or isinstance(clave, bool):
                raise ValueError(f"{ruta} contiene una clave no permitida.")
            _validar_estructura_torch_segura(
                item, ruta=f"{ruta}[{clave!r}]", profundidad=profundidad + 1, contador=contador
            )
        return
    if isinstance(valor, (list, tuple)):
        for indice, item in enumerate(valor):
            _validar_estructura_torch_segura(
                item, ruta=f"{ruta}[{indice}]", profundidad=profundidad + 1, contador=contador
            )
        return
    raise ValueError(f"{ruta} contiene un tipo no permitido: {type(valor).__name__}.")


def _torch_load_seguro(datos_o_ruta: Any, *, map_location: Any = "cpu") -> Any:
    try:
        return torch.load(datos_o_ruta, map_location=map_location, weights_only=True)
    except Exception as exc:
        raise ValueError(f"No se pudo leer el contenido PyTorch de forma segura: {exc}") from exc


def _sha256_bytes(datos: bytes) -> str:
    return hashlib.sha256(datos).hexdigest()


def _sha256_archivo(ruta: Path) -> str:
    digest = hashlib.sha256()
    with ruta.open("rb") as archivo:
        for bloque in iter(lambda: archivo.read(1024 * 1024), b""):
            digest.update(bloque)
    return digest.hexdigest()


def _escribir_bytes_atomico(ruta: Path, datos: bytes) -> None:
    ruta.parent.mkdir(parents=True, exist_ok=True)
    descriptor, nombre_temporal = tempfile.mkstemp(
        prefix=f".{ruta.name}.", suffix=".tmp", dir=str(ruta.parent)
    )
    temporal = Path(nombre_temporal)
    try:
        with os.fdopen(descriptor, "wb") as archivo:
            archivo.write(datos)
            archivo.flush()
            os.fsync(archivo.fileno())
        os.replace(temporal, ruta)
    except Exception:
        try:
            temporal.unlink(missing_ok=True)
        finally:
            raise


def _torch_save_atomico(ruta: Path, valor: Any) -> None:
    """Variante atomica que no duplica checkpoints grandes en memoria RAM."""
    ruta.parent.mkdir(parents=True, exist_ok=True)
    descriptor, nombre_temporal = tempfile.mkstemp(
        prefix=f".{ruta.name}.", suffix=".tmp", dir=str(ruta.parent)
    )
    os.close(descriptor)
    temporal = Path(nombre_temporal)
    try:
        torch.save(valor, temporal)
        with temporal.open("rb+") as archivo:
            os.fsync(archivo.fileno())
        os.replace(temporal, ruta)
    except Exception:
        temporal.unlink(missing_ok=True)
        raise


def _torch_save_temporal(valor: Any, directorio: Path, etiqueta: str) -> Path:
    """Serializa un componente grande sin mantener otra copia en memoria."""
    descriptor, nombre_temporal = tempfile.mkstemp(
        prefix=f".{etiqueta}.", suffix=".tmp", dir=str(directorio)
    )
    os.close(descriptor)
    temporal = Path(nombre_temporal)
    try:
        torch.save(valor, temporal)
        with temporal.open("rb+") as archivo:
            os.fsync(archivo.fileno())
        return temporal
    except Exception:
        temporal.unlink(missing_ok=True)
        raise


def _ruta_portable(ruta: str | Path) -> Path:
    resultado = Path(ruta)
    if resultado.suffix.lower() != EXTENSION_MODELO:
        resultado = resultado.with_suffix(EXTENSION_MODELO)
    return resultado


def _config_desde_dict(valor: Any) -> ConfiguracionTransformer:
    if not isinstance(valor, Mapping):
        raise ValueError("config debe ser un objeto.")
    nombres = {campo.name for campo in fields(ConfiguracionTransformer)}
    faltantes = {"tamano_vocabulario"} - set(valor)
    desconocidos = set(valor) - nombres
    if faltantes:
        raise ValueError(f"Faltan campos de configuracion: {sorted(faltantes)}.")
    if desconocidos:
        raise ValueError(f"Campos de configuracion desconocidos: {sorted(desconocidos)}.")

    enteros = {
        "tamano_vocabulario": (1, 10_000_000),
        "dimension_modelo": (1, 65_536),
        "num_cabezas": (1, 4_096),
        "num_capas": (1, 1_024),
        "dimension_ff": (1, 262_144),
        "longitud_maxima_secuencia": (1, 1_000_000),
    }
    for nombre, (minimo, maximo) in enteros.items():
        if nombre not in valor:
            continue
        numero = valor[nombre]
        if not _es_entero(numero) or not minimo <= numero <= maximo:
            raise ValueError(f"config.{nombre} esta fuera del rango permitido.")

    dropout = valor.get("dropout", ConfiguracionTransformer.__dataclass_fields__["dropout"].default)
    if isinstance(dropout, bool) or not isinstance(dropout, (int, float)):
        raise ValueError("config.dropout debe ser numerico.")
    if not math.isfinite(float(dropout)) or not 0.0 <= float(dropout) <= 1.0:
        raise ValueError("config.dropout debe estar entre 0 y 1.")

    id_relleno = valor.get("id_token_relleno")
    if id_relleno is not None:
        vocabulario = valor["tamano_vocabulario"]
        if not _es_entero(id_relleno) or not 0 <= id_relleno < vocabulario:
            raise ValueError("config.id_token_relleno no es valido para el vocabulario.")

    try:
        return ConfiguracionTransformer(**dict(valor))
    except (TypeError, ValueError) as exc:
        raise ValueError(f"Configuracion Transformer invalida: {exc}") from exc


def _validar_state_dict(valor: Any) -> Mapping[str, torch.Tensor]:
    if not isinstance(valor, Mapping):
        raise ValueError("Los pesos deben ser un state_dict.")
    if not valor or len(valor) > _MAX_STATE_TENSORS:
        raise ValueError("El state_dict esta vacio o contiene demasiados tensores.")

    elementos = 0
    for nombre, tensor in valor.items():
        if not isinstance(nombre, str) or not nombre or len(nombre) > 1_000:
            raise ValueError("El state_dict contiene un nombre de tensor invalido.")
        if not isinstance(tensor, torch.Tensor):
            raise ValueError(f"El valor de {nombre!r} no es un tensor.")
        if tensor.layout != torch.strided or tensor.is_quantized:
            raise ValueError(f"El tensor {nombre!r} usa un formato no compatible.")
        if tensor.dim() > 16:
            raise ValueError(f"El tensor {nombre!r} tiene demasiadas dimensiones.")
        elementos += tensor.numel()
        if elementos > _MAX_MODEL_PARAMETERS * 4:
            raise ValueError("El state_dict excede el limite de elementos permitido.")
    return valor


def _contar_elementos_unicos(state_dict: Mapping[str, torch.Tensor]) -> int:
    """Evita contar dos veces pesos compartidos presentes con varias claves."""
    vistos: set[tuple[Any, ...]] = set()
    total = 0
    for tensor in state_dict.values():
        try:
            almacenamiento = tensor.untyped_storage()
            clave = (
                almacenamiento.data_ptr(),
                almacenamiento.nbytes(),
                tensor.storage_offset(),
                tuple(tensor.shape),
                str(tensor.dtype),
            )
        except (RuntimeError, AttributeError):
            clave = (id(tensor),)
        if clave not in vistos:
            vistos.add(clave)
            total += tensor.numel()
    return total


def _tipos_pesos(state_dict: Mapping[str, torch.Tensor]) -> list[str]:
    return sorted({str(tensor.dtype).removeprefix("torch.") for tensor in state_dict.values()})


def _arquitectura(config: ConfiguracionTransformer, parametros_totales: int) -> dict[str, Any]:
    return {
        "tipo": "Transformer encoder-decoder",
        "encoder_layers": config.num_capas,
        "decoder_layers": config.num_capas,
        "num_capas": config.num_capas,
        "num_cabezas": config.num_cabezas,
        "dimension_modelo": config.dimension_modelo,
        "d_model": config.dimension_modelo,
        "dimension_ff": config.dimension_ff,
        "d_ff": config.dimension_ff,
        "longitud_maxima_secuencia": config.longitud_maxima_secuencia,
        "context_length": config.longitud_maxima_secuencia,
        "tamano_vocabulario": config.tamano_vocabulario,
        "vocab_size": config.tamano_vocabulario,
        "vocab": config.tamano_vocabulario,
        "dropout": config.dropout,
        "parametros_totales": parametros_totales,
    }


def _calcular_parametros_esperados(
    config: ConfiguracionTransformer, compartir_pesos_salida: bool
) -> int:
    """Formula exacta del Transformer actual, sin instanciar tensores."""
    vocab = config.tamano_vocabulario
    dimension = config.dimension_modelo
    capas = config.num_capas
    dimension_ff = config.dimension_ff

    embeddings = 2 * vocab * dimension
    atencion = 4 * (dimension * dimension + dimension)
    feed_forward = 2 * dimension * dimension_ff + dimension_ff + dimension
    layer_norm = 2 * dimension
    bloque_encoder = atencion + feed_forward + 2 * layer_norm
    bloque_decoder = 2 * atencion + feed_forward + 3 * layer_norm
    salida = vocab if compartir_pesos_salida else dimension * vocab + vocab
    return embeddings + capas * (bloque_encoder + bloque_decoder) + salida


def _validar_tamano_arquitectura(
    config: ConfiguracionTransformer, compartir_pesos_salida: bool
) -> int:
    parametros = _calcular_parametros_esperados(config, compartir_pesos_salida)
    if parametros <= 0 or parametros > _MAX_MODEL_PARAMETERS:
        raise ValueError(
            "La arquitectura excede el limite local de parametros y no puede "
            "materializarse de forma segura."
        )
    return parametros


def _extraer_tokenizer(tokenizer: Any, config: ConfiguracionTransformer) -> dict[str, Any]:
    if tokenizer is None:
        raise ValueError("Se requiere el tokenizador para crear un modelo portable.")

    tipo_encoding = getattr(tokenizer, "tipo_encoding", None)
    encoding_obj = getattr(tokenizer, "encoding", None)
    encoding = getattr(encoding_obj, "name", None)
    if encoding is None and isinstance(encoding_obj, str):
        encoding = encoding_obj
    if tipo_encoding is None and isinstance(encoding, str) and encoding in ENCODINGS:
        tipo_encoding = ENCODINGS.index(encoding)
    if not _es_entero(tipo_encoding) or not 0 <= tipo_encoding < len(ENCODINGS):
        raise ValueError("El tokenizador no expone un tipo_encoding compatible.")
    if encoding is None:
        encoding = ENCODINGS[tipo_encoding]
    if encoding != ENCODINGS[tipo_encoding]:
        raise ValueError("El nombre del encoding no coincide con tipo_encoding.")

    vocab_size = getattr(tokenizer, "vocab_size", None)
    if callable(vocab_size):
        vocab_size = vocab_size()
    if not _es_entero(vocab_size) or vocab_size <= 0:
        raise ValueError("El tokenizador no expone un vocab_size valido.")

    pad = config.id_token_relleno
    bos = vocab_size + 1
    eos = vocab_size + 2
    if (
        pad != vocab_size
        or config.tamano_vocabulario != vocab_size + 3
        or len({pad, bos, eos}) != 3
        or not all(
            _es_entero(token) and 0 <= token < config.tamano_vocabulario
            for token in (pad, bos, eos)
        )
    ):
        raise ValueError(
            "El modelo portable debe reservar exactamente vocab_size, "
            "vocab_size+1 y vocab_size+2 para pad, bos y eos."
        )

    return {
        "tipo": "tiktoken",
        "tipo_encoding": tipo_encoding,
        "encoding": encoding,
        "vocab_size": vocab_size,
        "pad": pad,
        "bos": bos,
        "eos": eos,
        "id_token_relleno": pad,
        "id_token_inicio": bos,
        "id_token_fin": eos,
    }


def _capacidades(
    *,
    reanudable: bool,
    tokenizer_incluido: bool = True,
    portable: bool = True,
    utilizable: bool = True,
) -> dict[str, bool]:
    # Se incluyen nombres en espanol y aliases tecnicos para que el manifiesto
    # tambien resulte comodo fuera de la interfaz QML.
    return {
        "inferencia": utilizable,
        "entrenamiento_desde_pesos": utilizable,
        "reanudacion": reanudable,
        # Adam permite continuar, pero sin sampler/RNG no se promete una
        # reproduccion bit a bit del siguiente paso.
        "reanudacion_exacta": False,
        "tokenizador_incluido": tokenizer_incluido,
        "portable": portable,
        "compartible": portable,
        "inference": utilizable,
        "train_from_weights": utilizable,
        "resume_training": reanudable,
        "exact_resume": False,
    }


def _descriptor(manifest: dict[str, Any], ruta: Path, *, legacy: bool = False) -> dict[str, Any]:
    resultado = copy.deepcopy(manifest)
    resultado["ruta"] = str(ruta.resolve())
    resultado["tamano_archivo"] = ruta.stat().st_size
    resultado["formato"] = "pt_legacy" if legacy else SCHEMA_MODELO
    resultado["es_legacy"] = legacy
    return resultado


# ---------------------------------------------------------------------------
# Formato historico .pt
# ---------------------------------------------------------------------------

def guardar_checkpoint(
    ruta: str | Path,
    modelo: Transformer,
    optimizador: torch.optim.Optimizer | None = None,
    epoca: int | None = None,
    paso_global: int | None = None,
    historial_perdidas: list[float] | None = None,
    metadata_extra: dict[str, Any] | None = None,
) -> None:
    """Guarda un checkpoint ``.pt`` compatible con las versiones anteriores."""
    ruta = Path(ruta)
    _validar_entero_opcional("epoca", epoca)
    _validar_entero_opcional("paso_global", paso_global)
    historial = _validar_historial(historial_perdidas)
    if metadata_extra is not None and not isinstance(metadata_extra, dict):
        raise TypeError("metadata_extra debe ser un diccionario.")

    estado_optimizador = optimizador.state_dict() if optimizador is not None else None
    if estado_optimizador is not None:
        _validar_estructura_torch_segura(estado_optimizador, ruta="optimizer_state_dict")
    contenido = {
        "version_formato": VERSION_FORMATO_CHECKPOINT,
        "config": asdict(modelo.config),
        "compartir_pesos_salida": modelo.compartir_pesos_salida,
        "model_state_dict": modelo.state_dict(),
        "optimizer_state_dict": estado_optimizador,
        "epoca": epoca,
        "paso_global": paso_global,
        "historial_perdidas": historial,
        "metadata_extra": _a_json_seguro(metadata_extra or {}, ruta="metadata_extra"),
    }
    _torch_save_atomico(ruta, contenido)


def _validar_checkpoint_legacy(contenido: Any) -> dict[str, Any]:
    if not isinstance(contenido, dict):
        raise ValueError("El archivo no contiene un checkpoint valido.")
    version = contenido.get("version_formato")
    if not _es_entero(version) or version != VERSION_FORMATO_CHECKPOINT:
        raise ValueError(
            f"Version de checkpoint no compatible: {version!r}; "
            f"se esperaba {VERSION_FORMATO_CHECKPOINT}."
        )
    requeridas = {"config", "compartir_pesos_salida", "model_state_dict"}
    faltantes = requeridas - contenido.keys()
    if faltantes:
        raise ValueError(f"El checkpoint no es valido; faltan claves: {sorted(faltantes)}.")
    if not isinstance(contenido["compartir_pesos_salida"], bool):
        raise ValueError("compartir_pesos_salida debe ser booleano.")

    config = _config_desde_dict(contenido["config"])
    _validar_tamano_arquitectura(config, contenido["compartir_pesos_salida"])
    state_dict = _validar_state_dict(contenido["model_state_dict"])
    optimizer_state = contenido.get("optimizer_state_dict")
    if optimizer_state is not None:
        if not isinstance(optimizer_state, dict):
            raise ValueError("optimizer_state_dict debe ser un diccionario o None.")
        _validar_estructura_torch_segura(optimizer_state, ruta="optimizer_state_dict")
    epoca = _validar_entero_opcional("epoca", contenido.get("epoca"))
    paso = _validar_entero_opcional("paso_global", contenido.get("paso_global"))
    historial = _validar_historial(contenido.get("historial_perdidas", []))
    metadata = contenido.get("metadata_extra", {})
    if not isinstance(metadata, dict):
        raise ValueError("metadata_extra debe ser un diccionario.")
    metadata = _a_json_seguro(metadata, ruta="metadata_extra")

    return {
        **contenido,
        "_config_validada": config,
        "_state_dict_validado": state_dict,
        "epoca": epoca,
        "paso_global": paso,
        "historial_perdidas": historial,
        "metadata_extra": metadata,
    }


def _tipo_encoding_legacy(metadata: Mapping[str, Any]) -> int | None:
    tipo = metadata.get("tipo_encoding")
    if tipo is None:
        return None
    if not _es_entero(tipo) or not 0 <= tipo < len(ENCODINGS):
        raise ValueError("metadata_extra.tipo_encoding no es valido.")
    return tipo


def _manifest_legacy(ruta: Path, contenido: dict[str, Any]) -> dict[str, Any]:
    config: ConfiguracionTransformer = contenido["_config_validada"]
    state_dict = contenido["_state_dict_validado"]
    metadata = contenido["metadata_extra"]
    tipo_encoding = _tipo_encoding_legacy(metadata)
    parametros = _validar_tamano_arquitectura(
        config, contenido["compartir_pesos_salida"]
    )
    historial = contenido["historial_perdidas"]
    reanudable = contenido.get("optimizer_state_dict") is not None
    pad = config.id_token_relleno
    tipo_inferido = (
        VOCABULARIOS_CONOCIDOS.index(pad)
        if tipo_encoding is None and pad in VOCABULARIOS_CONOCIDOS
        else tipo_encoding
    )
    tokenizador_compatible = bool(
        tipo_inferido is not None
        and pad == VOCABULARIOS_CONOCIDOS[tipo_inferido]
        and config.tamano_vocabulario == pad + 3
    )
    tokenizer_info = {
        "tipo": "tiktoken" if tokenizador_compatible else "desconocido",
        "tipo_encoding": tipo_inferido if tokenizador_compatible else None,
        "encoding": ENCODINGS[tipo_inferido] if tokenizador_compatible else None,
        "vocab_size": pad if pad is not None else None,
        "pad": pad,
        "bos": pad + 1 if pad is not None and pad + 1 < config.tamano_vocabulario else None,
        "eos": pad + 2 if pad is not None and pad + 2 < config.tamano_vocabulario else None,
    }
    fecha = datetime.datetime.fromtimestamp(
        ruta.stat().st_mtime, tz=datetime.timezone.utc
    ).isoformat()
    digest = _sha256_archivo(ruta)
    return {
        "schema": "checkpoint_legacy",
        "schema_version": VERSION_FORMATO_CHECKPOINT,
        "version": VERSION_FORMATO_CHECKPOINT,
        "id": f"legacy-{digest[:24]}",
        "nombre": ruta.stem,
        "fecha": fecha,
        "fecha_creacion": fecha,
        "config": asdict(config),
        "compartir_pesos_salida": contenido["compartir_pesos_salida"],
        "arquitectura": _arquitectura(config, parametros),
        "tokenizer": tokenizer_info,
        "pesos": {
            "archivo": ruta.name,
            "sha256": digest,
            "tamano_bytes": ruta.stat().st_size,
            "num_parametros": parametros,
            "dtypes": _tipos_pesos(state_dict),
            "dtype": _tipos_pesos(state_dict)[0] if len(_tipos_pesos(state_dict)) == 1 else "mixed",
        },
        "entrenamiento": {
            "epoca": contenido["epoca"],
            "paso_global": contenido["paso_global"],
            "perdida_final": historial[-1] if historial else None,
            "num_registros_perdida": len(historial),
            "resume_available": reanudable,
        },
        "hiperparametros_entrenamiento": {},
        "metadata_extra": metadata,
        "capabilities": _capacidades(
            reanudable=reanudable,
            tokenizer_incluido=tokenizador_compatible,
            portable=False,
            utilizable=tokenizador_compatible,
        ),
    }


def _cargar_checkpoint_legacy(
    ruta: Path, dispositivo: str | torch.device | None = None
) -> ResultadoCarga:
    if ruta.stat().st_size > _MAX_WEIGHTS_BYTES + _MAX_TRAINING_STATE_BYTES:
        raise ValueError("El checkpoint excede el tamano maximo permitido.")
    contenido = _validar_checkpoint_legacy(_torch_load_seguro(ruta, map_location="cpu"))
    config = contenido["_config_validada"]
    state_dict = contenido["_state_dict_validado"]
    modelo = _construir_modelo(
        config,
        contenido["compartir_pesos_salida"],
        state_dict,
        dispositivo=dispositivo,
    )
    manifest = _descriptor(_manifest_legacy(ruta, contenido), ruta, legacy=True)
    tipo_encoding = _tipo_encoding_legacy(contenido["metadata_extra"])
    return ResultadoCarga(
        modelo=modelo,
        optimizer_state_dict=contenido.get("optimizer_state_dict"),
        epoca=contenido["epoca"],
        paso_global=contenido["paso_global"],
        historial_perdidas=contenido["historial_perdidas"],
        metadata_extra=contenido["metadata_extra"],
        manifest=manifest,
        hiperparametros_entrenamiento={},
        tipo_encoding=tipo_encoding,
    )


def cargar_checkpoint(
    ruta: str | Path, dispositivo: str | torch.device | None = None
) -> ResultadoCarga:
    """Carga de forma segura un ``.pt`` historico o un ``.tvismodel``."""
    ruta = Path(ruta)
    if not ruta.is_file():
        raise FileNotFoundError(f"No se encontro el checkpoint: {ruta}")
    if _parece_modelo_portable(ruta):
        return cargar_modelo_portable(ruta, dispositivo=dispositivo)
    return _cargar_checkpoint_legacy(ruta, dispositivo=dispositivo)


# ---------------------------------------------------------------------------
# Formato portable .tvismodel
# ---------------------------------------------------------------------------


def guardar_modelo_portable(
    ruta: str | Path,
    modelo: Transformer,
    tokenizer: Any,
    *,
    nombre: str | None = None,
    optimizador: torch.optim.Optimizer | None = None,
    epoca: int | None = None,
    siguiente_epoca: int | None = None,
    paso_epoca: int | None = None,
    paso_global: int | None = None,
    historial_perdidas: list[float] | None = None,
    hiperparametros_entrenamiento: dict[str, Any] | None = None,
    metadata_extra: dict[str, Any] | None = None,
    reanudable: bool = False,
    state_dict: Mapping[str, torch.Tensor] | None = None,
    optimizer_state_dict: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Guarda un modelo autocontenido y devuelve su descriptor uniforme."""
    if not isinstance(modelo, Transformer):
        raise TypeError("modelo debe ser una instancia de Transformer.")
    if not isinstance(reanudable, bool):
        raise TypeError("reanudable debe ser booleano.")
    if optimizador is not None and optimizer_state_dict is not None:
        raise ValueError("Usa optimizador u optimizer_state_dict, no ambos.")
    if hiperparametros_entrenamiento is not None and not isinstance(
        hiperparametros_entrenamiento, dict
    ):
        raise TypeError("hiperparametros_entrenamiento debe ser un diccionario.")
    if metadata_extra is not None and not isinstance(metadata_extra, dict):
        raise TypeError("metadata_extra debe ser un diccionario.")

    ruta_final = _ruta_portable(ruta)
    config = _config_desde_dict(asdict(modelo.config))
    epoca = _validar_entero_opcional("epoca", epoca)
    siguiente_epoca = _validar_entero_opcional("siguiente_epoca", siguiente_epoca)
    paso_epoca = _validar_entero_opcional("paso_epoca", paso_epoca)
    paso_global = _validar_entero_opcional("paso_global", paso_global)
    historial = _validar_historial(historial_perdidas)
    hiperparametros = _a_json_seguro(
        hiperparametros_entrenamiento or {}, ruta="hiperparametros_entrenamiento"
    )
    metadata = _a_json_seguro(metadata_extra or {}, ruta="metadata_extra")
    tokenizer_info = _extraer_tokenizer(tokenizer, config)

    pesos_origen = _validar_state_dict(
        state_dict if state_dict is not None else modelo.state_dict()
    )
    parametros_totales = sum(parametro.numel() for parametro in modelo.parameters())
    parametros_esperados = _validar_tamano_arquitectura(
        config, modelo.compartir_pesos_salida
    )
    if parametros_totales != parametros_esperados:
        raise ValueError(
            "La implementacion del modelo no coincide con la arquitectura declarada."
        )

    estado_optimizador = (
        optimizer_state_dict
        if optimizer_state_dict is not None
        else optimizador.state_dict() if optimizador is not None else None
    )
    if estado_optimizador is not None:
        if not isinstance(estado_optimizador, dict):
            raise ValueError("optimizer_state_dict debe ser un diccionario.")
        _validar_estructura_torch_segura(estado_optimizador, ruta="optimizer_state_dict")

    # El indicador es deliberado: pasar un optimizador permite al llamador
    # decidir despues si desea una copia reanudable, pero el estado sensible y
    # voluminoso solo se incluye cuando se solicita expresamente.
    if not reanudable:
        estado_optimizador = None

    resume_available = bool(reanudable and estado_optimizador is not None)
    incluir_estado_entrenamiento = any(
        (
            reanudable,
            estado_optimizador is not None,
            epoca is not None,
            siguiente_epoca is not None,
            paso_epoca is not None,
            paso_global is not None,
            bool(historial),
            bool(hiperparametros),
        )
    )
    estado_entrenamiento: dict[str, Any] | None = None
    if incluir_estado_entrenamiento:
        estado_entrenamiento = {
            "version_formato": VERSION_FORMATO_MODELO,
            "optimizer_state_dict": estado_optimizador,
            "epoca": epoca,
            "siguiente_epoca": siguiente_epoca,
            "paso_epoca": paso_epoca,
            "paso_global": paso_global,
            "historial_perdidas": historial,
            "hiperparametros_entrenamiento": hiperparametros,
        }
    ruta_final.parent.mkdir(parents=True, exist_ok=True)
    pesos_temporal: Path | None = None
    entrenamiento_temporal: Path | None = None
    modelo_temporal: Path | None = None
    try:
        # ``dict`` elimina metadatos internos de OrderedDict que no necesita
        # este Transformer, pero conserva referencias/almacenamientos
        # compartidos y evita clonar cientos de MB en RAM.
        pesos_temporal = _torch_save_temporal(
            dict(pesos_origen), ruta_final.parent, "weights"
        )
        tamano_pesos = pesos_temporal.stat().st_size
        if tamano_pesos > _MAX_WEIGHTS_BYTES:
            raise ValueError("Los pesos exceden el tamano maximo permitido.")

        estado_entrenamiento_info: dict[str, Any] | None = None
        if estado_entrenamiento is not None:
            entrenamiento_temporal = _torch_save_temporal(
                estado_entrenamiento, ruta_final.parent, "training_state"
            )
            tamano_estado = entrenamiento_temporal.stat().st_size
            if tamano_estado > _MAX_TRAINING_STATE_BYTES:
                raise ValueError(
                    "El estado de entrenamiento excede el tamano maximo permitido."
                )
            estado_entrenamiento_info = {
                "archivo": _ARCHIVO_ENTRENAMIENTO,
                "sha256": _sha256_archivo(entrenamiento_temporal),
                "tamano_bytes": tamano_estado,
            }

        fecha = datetime.datetime.now(tz=datetime.timezone.utc).isoformat()
        nombre_visible = Path(
            sanitizar_nombre_modelo(nombre or ruta_final.stem)
        ).stem[:240]
        tipos = _tipos_pesos(pesos_origen)
        entrenamiento = {
            "epoca": epoca,
            "siguiente_epoca": siguiente_epoca,
            "paso_epoca": paso_epoca,
            "paso_global": paso_global,
            "perdida_final": historial[-1] if historial else None,
            "num_registros_perdida": len(historial),
            "resume_available": resume_available,
        }
        if estado_entrenamiento_info is not None:
            entrenamiento["estado"] = estado_entrenamiento_info

        manifest = {
            "schema": SCHEMA_MODELO,
            "schema_version": VERSION_FORMATO_MODELO,
            "version": VERSION_FORMATO_MODELO,
            "id": str(uuid.uuid4()),
            "nombre": nombre_visible,
            "fecha": fecha,
            "fecha_creacion": fecha,
            "config": asdict(config),
            "compartir_pesos_salida": bool(modelo.compartir_pesos_salida),
            "arquitectura": _arquitectura(config, parametros_totales),
            "tokenizer": tokenizer_info,
            "pesos": {
                "archivo": _ARCHIVO_PESOS,
                "sha256": _sha256_archivo(pesos_temporal),
                "tamano_bytes": tamano_pesos,
                "num_parametros": parametros_totales,
                "num_tensores": len(pesos_origen),
                "dtypes": tipos,
                "dtype": tipos[0] if len(tipos) == 1 else "mixed",
            },
            "entrenamiento": entrenamiento,
            "hiperparametros_entrenamiento": hiperparametros,
            "metadata_extra": metadata,
            "capabilities": _capacidades(reanudable=resume_available),
        }
        # La serializacion estricta tambien detecta accidentalmente valores
        # que no sean JSON a pesar de las conversiones anteriores.
        manifest_bytes = json.dumps(
            manifest, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False
        ).encode("utf-8")
        if len(manifest_bytes) > _MAX_MANIFEST_BYTES:
            raise ValueError("El manifiesto excede el tamano maximo permitido.")

        descriptor_temporal, nombre_temporal = tempfile.mkstemp(
            prefix=f".{ruta_final.name}.", suffix=".tmp", dir=str(ruta_final.parent)
        )
        os.close(descriptor_temporal)
        modelo_temporal = Path(nombre_temporal)
        with zipfile.ZipFile(
            modelo_temporal,
            mode="w",
            compression=zipfile.ZIP_STORED,
            allowZip64=True,
        ) as archivo_zip:
            archivo_zip.writestr(
                _ARCHIVO_MANIFEST,
                manifest_bytes,
                compress_type=zipfile.ZIP_STORED,
            )
            archivo_zip.write(
                pesos_temporal,
                arcname=_ARCHIVO_PESOS,
                compress_type=zipfile.ZIP_STORED,
            )
            if entrenamiento_temporal is not None:
                archivo_zip.write(
                    entrenamiento_temporal,
                    arcname=_ARCHIVO_ENTRENAMIENTO,
                    compress_type=zipfile.ZIP_STORED,
                )
        with modelo_temporal.open("rb+") as archivo:
            os.fsync(archivo.fileno())
        os.replace(modelo_temporal, ruta_final)
        modelo_temporal = None
    finally:
        for temporal in (pesos_temporal, entrenamiento_temporal, modelo_temporal):
            if temporal is not None:
                temporal.unlink(missing_ok=True)

    return _descriptor(manifest, ruta_final)


def _validar_manifest(manifest: Any) -> dict[str, Any]:
    if not isinstance(manifest, dict):
        raise ValueError("manifest.json debe contener un objeto JSON.")
    if manifest.get("schema") != SCHEMA_MODELO:
        raise ValueError("El esquema del modelo no es compatible.")
    version = manifest.get("schema_version")
    if not _es_entero(version) or version != VERSION_FORMATO_MODELO:
        raise ValueError(
            f"Version de modelo no compatible: {version!r}; "
            f"se esperaba {VERSION_FORMATO_MODELO}."
        )
    if manifest.get("version") != version:
        raise ValueError("Las versiones declaradas en el manifiesto no coinciden.")
    if not isinstance(manifest.get("id"), str) or not manifest["id"]:
        raise ValueError("El manifiesto no contiene un id valido.")
    try:
        uuid.UUID(manifest["id"])
    except (ValueError, AttributeError) as exc:
        raise ValueError("El id del manifiesto no es un UUID valido.") from exc
    if not isinstance(manifest.get("nombre"), str) or not manifest["nombre"].strip():
        raise ValueError("El manifiesto no contiene un nombre valido.")
    if not isinstance(manifest.get("fecha_creacion"), str):
        raise ValueError("El manifiesto no contiene una fecha de creacion valida.")

    config = _config_desde_dict(manifest.get("config"))
    if not isinstance(manifest.get("compartir_pesos_salida"), bool):
        raise ValueError("compartir_pesos_salida debe ser booleano.")
    parametros_esperados = _validar_tamano_arquitectura(
        config, manifest["compartir_pesos_salida"]
    )
    arquitectura = manifest.get("arquitectura")
    if not isinstance(arquitectura, dict):
        raise ValueError("Falta la descripcion de arquitectura.")
    if arquitectura.get("tipo") != "Transformer encoder-decoder":
        raise ValueError("arquitectura.tipo no es compatible.")
    esperados = _arquitectura(config, arquitectura.get("parametros_totales", -1))
    for clave in (
        "encoder_layers",
        "decoder_layers",
        "num_capas",
        "num_cabezas",
        "dimension_modelo",
        "d_model",
        "dimension_ff",
        "d_ff",
        "longitud_maxima_secuencia",
        "context_length",
        "tamano_vocabulario",
        "vocab_size",
        "vocab",
        "dropout",
    ):
        if arquitectura.get(clave) != esperados[clave]:
            raise ValueError(f"arquitectura.{clave} no coincide con config.")
    parametros = arquitectura.get("parametros_totales")
    if not _es_entero(parametros) or not 0 < parametros <= _MAX_MODEL_PARAMETERS:
        raise ValueError("arquitectura.parametros_totales no es valido.")
    if parametros != parametros_esperados:
        raise ValueError(
            "arquitectura.parametros_totales no coincide con la configuracion."
        )

    tokenizer = manifest.get("tokenizer")
    if not isinstance(tokenizer, dict):
        raise ValueError("Falta la informacion del tokenizador.")
    if tokenizer.get("tipo") != "tiktoken":
        raise ValueError("tokenizer.tipo debe ser tiktoken.")
    tipo_encoding = tokenizer.get("tipo_encoding")
    if not _es_entero(tipo_encoding) or not 0 <= tipo_encoding < len(ENCODINGS):
        raise ValueError("tokenizer.tipo_encoding no es valido.")
    if tokenizer.get("encoding") != ENCODINGS[tipo_encoding]:
        raise ValueError("tokenizer.encoding no coincide con tipo_encoding.")
    vocab_tokenizer = tokenizer.get("vocab_size")
    if not _es_entero(vocab_tokenizer) or vocab_tokenizer <= 0:
        raise ValueError("tokenizer.vocab_size no es valido.")
    especiales = [tokenizer.get(clave) for clave in ("pad", "bos", "eos")]
    if any(
        not _es_entero(token) or not 0 <= token < config.tamano_vocabulario
        for token in especiales
    ) or len(set(especiales)) != 3:
        raise ValueError("Los ids especiales del tokenizador no son validos.")
    if config.id_token_relleno is None or tokenizer["pad"] != config.id_token_relleno:
        raise ValueError("El token pad no coincide con config.id_token_relleno.")
    esperados_especiales = [vocab_tokenizer, vocab_tokenizer + 1, vocab_tokenizer + 2]
    if especiales != esperados_especiales:
        raise ValueError(
            "Los tokens especiales deben ocupar vocab_size, vocab_size+1 y vocab_size+2."
        )
    if config.tamano_vocabulario != vocab_tokenizer + 3:
        raise ValueError(
            "config.tamano_vocabulario debe incluir exactamente tres tokens especiales."
        )
    for alias, canonico in (
        ("id_token_relleno", "pad"),
        ("id_token_inicio", "bos"),
        ("id_token_fin", "eos"),
    ):
        if tokenizer.get(alias) != tokenizer[canonico]:
            raise ValueError(f"tokenizer.{alias} no coincide con tokenizer.{canonico}.")

    pesos = manifest.get("pesos")
    if not isinstance(pesos, dict) or pesos.get("archivo") != _ARCHIVO_PESOS:
        raise ValueError("La seccion de pesos del manifiesto no es valida.")
    if not re.fullmatch(r"[0-9a-f]{64}", str(pesos.get("sha256", ""))):
        raise ValueError("El hash de los pesos no es valido.")
    tamano_pesos = pesos.get("tamano_bytes")
    if not _es_entero(tamano_pesos) or not 0 < tamano_pesos <= _MAX_WEIGHTS_BYTES:
        raise ValueError("El tamano declarado de los pesos no es valido.")
    if pesos.get("num_parametros") != parametros:
        raise ValueError("El numero de parametros no coincide entre secciones.")
    num_tensores = pesos.get("num_tensores")
    if not _es_entero(num_tensores) or not 0 < num_tensores <= _MAX_STATE_TENSORS:
        raise ValueError("pesos.num_tensores no es valido.")
    dtypes = pesos.get("dtypes")
    if (
        not isinstance(dtypes, list)
        or not dtypes
        or any(not isinstance(dtype, str) or not dtype for dtype in dtypes)
    ):
        raise ValueError("pesos.dtypes no es valido.")

    entrenamiento = manifest.get("entrenamiento")
    if not isinstance(entrenamiento, dict):
        raise ValueError("La seccion de entrenamiento no es valida.")
    _validar_entero_opcional("entrenamiento.epoca", entrenamiento.get("epoca"))
    _validar_entero_opcional(
        "entrenamiento.siguiente_epoca", entrenamiento.get("siguiente_epoca")
    )
    _validar_entero_opcional(
        "entrenamiento.paso_epoca", entrenamiento.get("paso_epoca")
    )
    _validar_entero_opcional(
        "entrenamiento.paso_global", entrenamiento.get("paso_global")
    )
    perdida = entrenamiento.get("perdida_final")
    if perdida is not None and (
        isinstance(perdida, bool)
        or not isinstance(perdida, (int, float))
        or not math.isfinite(float(perdida))
    ):
        raise ValueError("entrenamiento.perdida_final no es valida.")
    if not isinstance(entrenamiento.get("resume_available"), bool):
        raise ValueError("entrenamiento.resume_available debe ser booleano.")
    num_perdidas = entrenamiento.get("num_registros_perdida")
    if not _es_entero(num_perdidas) or not 0 <= num_perdidas <= _MAX_HISTORY_ITEMS:
        raise ValueError("entrenamiento.num_registros_perdida no es valido.")
    estado_info = entrenamiento.get("estado")
    if estado_info is not None:
        if not isinstance(estado_info, dict) or estado_info.get("archivo") != _ARCHIVO_ENTRENAMIENTO:
            raise ValueError("La referencia al estado de entrenamiento no es valida.")
        if not re.fullmatch(r"[0-9a-f]{64}", str(estado_info.get("sha256", ""))):
            raise ValueError("El hash del estado de entrenamiento no es valido.")
        tamano_estado = estado_info.get("tamano_bytes")
        if not _es_entero(tamano_estado) or not 0 < tamano_estado <= _MAX_TRAINING_STATE_BYTES:
            raise ValueError("El tamano del estado de entrenamiento no es valido.")
    if entrenamiento["resume_available"] and estado_info is None:
        raise ValueError("Un modelo reanudable debe incluir estado de entrenamiento.")

    capabilities = manifest.get("capabilities")
    if not isinstance(capabilities, dict):
        raise ValueError("Falta la declaracion de capacidades.")
    capacidades_booleanas = (
        "inferencia",
        "entrenamiento_desde_pesos",
        "reanudacion",
        "reanudacion_exacta",
        "tokenizador_incluido",
        "portable",
        "compartible",
        "inference",
        "train_from_weights",
        "resume_training",
        "exact_resume",
    )
    if any(not isinstance(capabilities.get(clave), bool) for clave in capacidades_booleanas):
        raise ValueError("La declaracion de capacidades contiene tipos invalidos.")
    if capabilities["reanudacion"] != entrenamiento["resume_available"]:
        raise ValueError("La capacidad de reanudacion no coincide con el entrenamiento.")
    if capabilities["resume_training"] != entrenamiento["resume_available"]:
        raise ValueError("resume_training no coincide con el entrenamiento.")
    if capabilities["inference"] != capabilities["inferencia"]:
        raise ValueError("Las capacidades de inferencia no coinciden entre aliases.")
    if (
        capabilities["train_from_weights"]
        != capabilities["entrenamiento_desde_pesos"]
    ):
        raise ValueError("Las capacidades de entrenamiento no coinciden entre aliases.")
    if capabilities["reanudacion_exacta"] or capabilities["exact_resume"]:
        raise ValueError("Esta version no admite declarar reanudacion exacta.")
    if not capabilities["portable"] or not capabilities["compartible"]:
        raise ValueError("Un .tvismodel debe declararse portable y compartible.")
    if not (
        capabilities["inferencia"]
        and capabilities["entrenamiento_desde_pesos"]
        and capabilities["tokenizador_incluido"]
    ):
        raise ValueError("Un .tvismodel debe incluir tokenizador y ser utilizable.")
    if not isinstance(manifest.get("metadata_extra", {}), dict):
        raise ValueError("metadata_extra debe ser un objeto.")
    if not isinstance(manifest.get("hiperparametros_entrenamiento", {}), dict):
        raise ValueError("hiperparametros_entrenamiento debe ser un objeto.")
    _a_json_seguro(manifest.get("metadata_extra", {}), ruta="metadata_extra")
    _a_json_seguro(
        manifest.get("hiperparametros_entrenamiento", {}),
        ruta="hiperparametros_entrenamiento",
    )
    return manifest


def _validar_info_entrada(
    zip_file: zipfile.ZipFile, nombre: str, limite: int
) -> zipfile.ZipInfo:
    try:
        info = zip_file.getinfo(nombre)
    except KeyError as exc:
        raise ValueError(f"Falta {nombre} en el modelo portable.") from exc
    if info.flag_bits & 0x1:
        raise ValueError(f"La entrada {nombre} no puede estar cifrada.")
    if info.compress_type != zipfile.ZIP_STORED:
        raise ValueError(f"La entrada {nombre} debe usar ZIP_STORED.")
    if info.file_size <= 0 or info.file_size > limite:
        raise ValueError(f"La entrada {nombre} excede el tamano permitido.")
    return info


def _leer_entrada(
    zip_file: zipfile.ZipFile,
    nombre: str,
    limite: int,
    *,
    conservar: bool = True,
) -> tuple[bytes | None, str]:
    info = _validar_info_entrada(zip_file, nombre, limite)
    digest = hashlib.sha256()
    buffer = io.BytesIO() if conservar else None
    total = 0
    with zip_file.open(info, "r") as archivo:
        while True:
            bloque = archivo.read(1024 * 1024)
            if not bloque:
                break
            total += len(bloque)
            if total > limite:
                raise ValueError(f"La entrada {nombre} excede el tamano permitido.")
            digest.update(bloque)
            if buffer is not None:
                buffer.write(bloque)
    if total != info.file_size:
        raise ValueError(f"El tamano real de {nombre} no coincide con el ZIP.")
    return (buffer.getvalue() if buffer is not None else None), digest.hexdigest()


def _extraer_entrada_temporal(
    zip_file: zipfile.ZipFile,
    nombre: str,
    limite: int,
    destino: Path,
) -> str:
    """Copia y calcula SHA-256 por bloques, sin materializar la entrada en RAM."""
    info = _validar_info_entrada(zip_file, nombre, limite)
    digest = hashlib.sha256()
    total = 0
    with zip_file.open(info, "r") as origen, destino.open("wb") as salida:
        while True:
            bloque = origen.read(1024 * 1024)
            if not bloque:
                break
            total += len(bloque)
            if total > limite:
                raise ValueError(f"La entrada {nombre} excede el tamano permitido.")
            digest.update(bloque)
            salida.write(bloque)
    if total != info.file_size:
        raise ValueError(f"El tamano real de {nombre} no coincide con el ZIP.")
    return digest.hexdigest()


def _extraer_portable_temporal(
    ruta: Path, directorio_temporal: Path
) -> tuple[dict[str, Any], Path, Path | None]:
    """Valida y extrae un paquete para que torch.load lea desde disco."""
    manifest, _, _ = _leer_portable(
        ruta, cargar_pesos=False, verificar_hash=False
    )
    pesos_ruta = directorio_temporal / _ARCHIVO_PESOS
    estado_ruta: Path | None = None
    try:
        with zipfile.ZipFile(ruta, mode="r") as archivo_zip:
            info_pesos = _validar_info_entrada(
                archivo_zip, _ARCHIVO_PESOS, _MAX_WEIGHTS_BYTES
            )
            if info_pesos.file_size != manifest["pesos"]["tamano_bytes"]:
                raise ValueError("El tamano de weights.pt no coincide con el manifiesto.")
            digest_pesos = _extraer_entrada_temporal(
                archivo_zip, _ARCHIVO_PESOS, _MAX_WEIGHTS_BYTES, pesos_ruta
            )
            if digest_pesos != manifest["pesos"]["sha256"]:
                raise ValueError(
                    "El hash de weights.pt no coincide; el modelo esta corrupto."
                )

            estado_info = manifest["entrenamiento"].get("estado")
            tiene_estado = _ARCHIVO_ENTRENAMIENTO in archivo_zip.namelist()
            if tiene_estado != (estado_info is not None):
                raise ValueError(
                    "La presencia de training_state.pt no coincide con el manifiesto."
                )
            if estado_info is not None:
                estado_ruta = directorio_temporal / _ARCHIVO_ENTRENAMIENTO
                info_estado = _validar_info_entrada(
                    archivo_zip,
                    _ARCHIVO_ENTRENAMIENTO,
                    _MAX_TRAINING_STATE_BYTES,
                )
                if info_estado.file_size != estado_info["tamano_bytes"]:
                    raise ValueError(
                        "El tamano de training_state.pt no coincide con el manifiesto."
                    )
                digest_estado = _extraer_entrada_temporal(
                    archivo_zip,
                    _ARCHIVO_ENTRENAMIENTO,
                    _MAX_TRAINING_STATE_BYTES,
                    estado_ruta,
                )
                if digest_estado != estado_info["sha256"]:
                    raise ValueError(
                        "El hash de training_state.pt no coincide; el modelo esta corrupto."
                    )
    except zipfile.BadZipFile as exc:
        raise ValueError("El archivo no es un .tvismodel valido.") from exc
    return manifest, pesos_ruta, estado_ruta


def _leer_portable(
    fuente: str | Path | io.BytesIO,
    *,
    cargar_pesos: bool,
    verificar_hash: bool = True,
) -> tuple[dict[str, Any], bytes | None, bytes | None]:
    try:
        with zipfile.ZipFile(fuente, mode="r") as archivo_zip:
            nombres = archivo_zip.namelist()
            if len(nombres) != len(set(nombres)):
                raise ValueError("El modelo contiene entradas ZIP duplicadas.")
            permitidos = {_ARCHIVO_MANIFEST, _ARCHIVO_PESOS, _ARCHIVO_ENTRENAMIENTO}
            if not {_ARCHIVO_MANIFEST, _ARCHIVO_PESOS}.issubset(nombres):
                raise ValueError("El archivo no contiene un modelo portable completo.")
            desconocidos = set(nombres) - permitidos
            if desconocidos:
                raise ValueError(
                    f"El modelo contiene rutas o entradas no permitidas: {sorted(desconocidos)}."
                )

            manifest_bytes, _ = _leer_entrada(
                archivo_zip, _ARCHIVO_MANIFEST, _MAX_MANIFEST_BYTES
            )
            assert manifest_bytes is not None
            try:
                manifest = json.loads(manifest_bytes.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError) as exc:
                raise ValueError("manifest.json no es JSON UTF-8 valido.") from exc
            manifest = _validar_manifest(manifest)

            pesos_info = _validar_info_entrada(
                archivo_zip, _ARCHIVO_PESOS, _MAX_WEIGHTS_BYTES
            )
            if pesos_info.file_size != manifest["pesos"]["tamano_bytes"]:
                raise ValueError("El tamano de weights.pt no coincide con el manifiesto.")
            pesos_bytes: bytes | None = None
            if cargar_pesos or verificar_hash:
                pesos_bytes, digest_pesos = _leer_entrada(
                    archivo_zip,
                    _ARCHIVO_PESOS,
                    _MAX_WEIGHTS_BYTES,
                    conservar=cargar_pesos,
                )
                if digest_pesos != manifest["pesos"]["sha256"]:
                    raise ValueError(
                        "El hash de weights.pt no coincide; el modelo esta corrupto."
                    )

            estado_bytes: bytes | None = None
            estado_info = manifest["entrenamiento"].get("estado")
            tiene_estado = _ARCHIVO_ENTRENAMIENTO in nombres
            if tiene_estado != (estado_info is not None):
                raise ValueError("La presencia de training_state.pt no coincide con el manifiesto.")
            if tiene_estado:
                info_zip = _validar_info_entrada(
                    archivo_zip, _ARCHIVO_ENTRENAMIENTO, _MAX_TRAINING_STATE_BYTES
                )
                if info_zip.file_size != estado_info["tamano_bytes"]:
                    raise ValueError(
                        "El tamano de training_state.pt no coincide con el manifiesto."
                    )
                if cargar_pesos or verificar_hash:
                    estado_bytes, digest_estado = _leer_entrada(
                        archivo_zip,
                        _ARCHIVO_ENTRENAMIENTO,
                        _MAX_TRAINING_STATE_BYTES,
                        conservar=cargar_pesos,
                    )
                    if digest_estado != estado_info["sha256"]:
                        raise ValueError(
                            "El hash de training_state.pt no coincide; el modelo esta corrupto."
                        )
            return manifest, pesos_bytes, estado_bytes
    except zipfile.BadZipFile as exc:
        raise ValueError("El archivo no es un .tvismodel valido.") from exc


def _parece_modelo_portable(ruta: Path) -> bool:
    if ruta.suffix.lower() == EXTENSION_MODELO:
        return True
    try:
        with zipfile.ZipFile(ruta, mode="r") as archivo:
            nombres = set(archivo.namelist())
        return {_ARCHIVO_MANIFEST, _ARCHIVO_PESOS}.issubset(nombres)
    except (OSError, zipfile.BadZipFile):
        return False


def inspeccionar_modelo(ruta: str | Path) -> dict[str, Any]:
    """Lee y valida capacidades sin instanciar la arquitectura del modelo."""
    ruta = Path(ruta)
    if not ruta.is_file():
        raise FileNotFoundError(f"No se encontro el modelo: {ruta}")
    if _parece_modelo_portable(ruta):
        manifest, _, _ = _leer_portable(
            ruta, cargar_pesos=False, verificar_hash=False
        )
        return _descriptor(manifest, ruta)

    if ruta.stat().st_size > _MAX_WEIGHTS_BYTES + _MAX_TRAINING_STATE_BYTES:
        raise ValueError("El checkpoint excede el tamano maximo permitido.")
    contenido = _validar_checkpoint_legacy(_torch_load_seguro(ruta, map_location="cpu"))
    return _descriptor(_manifest_legacy(ruta, contenido), ruta, legacy=True)


def verificar_integridad_modelo(ruta: str | Path) -> dict[str, Any]:
    """Valida por completo un archivo antes de importarlo o compartirlo.

    A diferencia de :func:`inspeccionar_modelo`, que evita recorrer pesos
    grandes para mantener fluida la biblioteca, esta funcion calcula los
    hashes de todos los componentes. No instancia el Transformer ni duplica
    los pesos en memoria.
    """
    ruta = Path(ruta)
    if not ruta.is_file():
        raise FileNotFoundError(f"No se encontro el modelo: {ruta}")
    if _parece_modelo_portable(ruta):
        manifest, _, _ = _leer_portable(
            ruta, cargar_pesos=False, verificar_hash=True
        )
        return _descriptor(manifest, ruta)
    # La inspeccion legacy ya carga y valida su estructura completa mediante
    # weights_only=True; no existe un manifiesto separado cuyo hash contrastar.
    return inspeccionar_modelo(ruta)


def _construir_modelo(
    config: ConfiguracionTransformer,
    compartir_pesos_salida: bool,
    state_dict: Mapping[str, torch.Tensor],
    *,
    dispositivo: str | torch.device | None,
) -> Transformer:
    modelo = Transformer(config, compartir_pesos_salida=compartir_pesos_salida)

    # Conserva precision reducida cuando todos los tensores flotantes del
    # archivo comparten dtype. Con dtypes mixtos se usa float32, que es la
    # opcion mas interoperable.
    dtypes_flotantes = {tensor.dtype for tensor in state_dict.values() if tensor.is_floating_point()}
    if len(dtypes_flotantes) == 1:
        modelo.to(dtype=next(iter(dtypes_flotantes)))
    try:
        incompatibles = modelo.load_state_dict(state_dict, strict=True)
    except RuntimeError as exc:
        raise ValueError(f"Los pesos no corresponden a la arquitectura declarada: {exc}") from exc
    if incompatibles.missing_keys or incompatibles.unexpected_keys:
        raise ValueError(
            "Los pesos no corresponden a la arquitectura declarada "
            f"(faltan={incompatibles.missing_keys}, sobran={incompatibles.unexpected_keys})."
        )
    if dispositivo is not None:
        try:
            modelo.to(dispositivo)
        except (RuntimeError, TypeError) as exc:
            raise ValueError(f"No se pudo mover el modelo a {dispositivo!s}: {exc}") from exc
    modelo.eval()
    return modelo


def _validar_estado_entrenamiento(valor: Any) -> dict[str, Any]:
    if not isinstance(valor, dict):
        raise ValueError("training_state.pt debe contener un diccionario.")
    version = valor.get("version_formato")
    if not _es_entero(version) or version != VERSION_FORMATO_MODELO:
        raise ValueError("La version del estado de entrenamiento no es compatible.")
    optimizer_state = valor.get("optimizer_state_dict")
    if optimizer_state is not None:
        if not isinstance(optimizer_state, dict):
            raise ValueError("optimizer_state_dict debe ser un diccionario o None.")
        _validar_estructura_torch_segura(optimizer_state, ruta="optimizer_state_dict")
    valor["epoca"] = _validar_entero_opcional("epoca", valor.get("epoca"))
    valor["siguiente_epoca"] = _validar_entero_opcional(
        "siguiente_epoca", valor.get("siguiente_epoca")
    )
    valor["paso_epoca"] = _validar_entero_opcional(
        "paso_epoca", valor.get("paso_epoca")
    )
    valor["paso_global"] = _validar_entero_opcional(
        "paso_global", valor.get("paso_global")
    )
    valor["historial_perdidas"] = _validar_historial(
        valor.get("historial_perdidas", [])
    )
    hiperparametros = valor.get("hiperparametros_entrenamiento", {})
    if not isinstance(hiperparametros, dict):
        raise ValueError("hiperparametros_entrenamiento debe ser un diccionario.")
    valor["hiperparametros_entrenamiento"] = _a_json_seguro(
        hiperparametros, ruta="hiperparametros_entrenamiento"
    )
    return valor


def _cargar_componentes_portables(
    ruta: Path, dispositivo: str | torch.device | None
) -> tuple[dict[str, Any], Transformer, dict[str, Any]]:
    """Carga pesos y entrenamiento secuencialmente desde temporales verificados."""
    with tempfile.TemporaryDirectory(prefix="tvismodel-load-") as nombre_temporal:
        manifest, pesos_ruta, estado_ruta = _extraer_portable_temporal(
            ruta, Path(nombre_temporal)
        )
        state_dict = _validar_state_dict(
            _torch_load_seguro(pesos_ruta, map_location="cpu")
        )

        parametros_declarados = manifest["arquitectura"]["parametros_totales"]
        parametros_archivo = _contar_elementos_unicos(state_dict)
        if parametros_archivo != parametros_declarados:
            # Puede haber buffers persistentes; strict=True valida las claves y
            # formas exactas. Este control rechaza archivos que ni siquiera
            # contienen suficientes elementos para la arquitectura declarada.
            total_elementos = sum(tensor.numel() for tensor in state_dict.values())
            if not parametros_declarados <= total_elementos:
                raise ValueError("El numero de parametros no coincide con weights.pt.")

        config = _config_desde_dict(manifest["config"])
        modelo = _construir_modelo(
            config,
            manifest["compartir_pesos_salida"],
            state_dict,
            dispositivo=dispositivo,
        )
        parametros_modelo = sum(parametro.numel() for parametro in modelo.parameters())
        if parametros_modelo != parametros_declarados:
            raise ValueError(
                "El numero de parametros declarado no corresponde a la arquitectura."
            )

        # load_state_dict copia los tensores al modelo; liberar el diccionario
        # antes de abrir Adam evita sumar ambas representaciones al pico de RAM.
        del state_dict
        estado_entrenamiento: dict[str, Any] = {}
        if estado_ruta is not None:
            estado_entrenamiento = _validar_estado_entrenamiento(
                _torch_load_seguro(estado_ruta, map_location="cpu")
            )
        return manifest, modelo, estado_entrenamiento


def cargar_modelo_portable(
    ruta: str | Path, dispositivo: str | torch.device | None = None
) -> ResultadoCarga:
    ruta = Path(ruta)
    if not ruta.is_file():
        raise FileNotFoundError(f"No se encontro el modelo: {ruta}")
    manifest, modelo, estado_entrenamiento = _cargar_componentes_portables(
        ruta, dispositivo
    )
    optimizer_state = estado_entrenamiento.get("optimizer_state_dict")
    resume_declarado = manifest["entrenamiento"]["resume_available"]
    if resume_declarado != (optimizer_state is not None):
        raise ValueError("La capacidad de reanudacion no coincide con el estado guardado.")
    if estado_entrenamiento:
        for campo, etiqueta in (
            ("epoca", "epoca"),
            ("siguiente_epoca", "siguiente epoca"),
            ("paso_epoca", "paso de epoca"),
            ("paso_global", "paso global"),
        ):
            if estado_entrenamiento.get(campo) != manifest["entrenamiento"].get(campo):
                raise ValueError(
                    f"El {etiqueta} no coincide entre el manifiesto y el estado."
                )

    historial = estado_entrenamiento.get("historial_perdidas", [])
    if len(historial) != manifest["entrenamiento"]["num_registros_perdida"]:
        raise ValueError("La longitud del historial no coincide con el manifiesto.")
    perdida_final = manifest["entrenamiento"].get("perdida_final")
    if (historial[-1] if historial else None) != perdida_final:
        raise ValueError("El historial de perdidas no coincide con el manifiesto.")
    hiperparametros = estado_entrenamiento.get(
        "hiperparametros_entrenamiento",
        manifest.get("hiperparametros_entrenamiento", {}),
    )
    if hiperparametros != manifest.get("hiperparametros_entrenamiento", {}):
        raise ValueError("Los hiperparametros no coinciden entre el manifiesto y el estado.")

    return ResultadoCarga(
        modelo=modelo,
        optimizer_state_dict=optimizer_state,
        epoca=estado_entrenamiento.get("epoca", manifest["entrenamiento"].get("epoca")),
        paso_global=estado_entrenamiento.get(
            "paso_global", manifest["entrenamiento"].get("paso_global")
        ),
        historial_perdidas=historial,
        metadata_extra=copy.deepcopy(manifest.get("metadata_extra", {})),
        manifest=_descriptor(manifest, ruta),
        hiperparametros_entrenamiento=hiperparametros,
        tipo_encoding=manifest["tokenizer"]["tipo_encoding"],
        siguiente_epoca=estado_entrenamiento.get(
            "siguiente_epoca", manifest["entrenamiento"].get("siguiente_epoca")
        ),
        paso_epoca=estado_entrenamiento.get(
            "paso_epoca", manifest["entrenamiento"].get("paso_epoca")
        ),
    )


# ---------------------------------------------------------------------------
# Compartir por codigo de texto
# ---------------------------------------------------------------------------


def exportar_codigo_modelo(
    ruta: str | Path, max_bytes: int = MAX_BYTES_CODIGO_MODELO
) -> str:
    """Convierte un modelo pequeno en texto verificable para copiar y pegar."""
    if not _es_entero(max_bytes) or max_bytes <= 0:
        raise ValueError("max_bytes debe ser un entero positivo.")
    ruta = Path(ruta)
    if not ruta.is_file():
        raise FileNotFoundError(f"No se encontro el modelo: {ruta}")
    tamano = ruta.stat().st_size
    if tamano > max_bytes:
        raise ValueError(
            f"El modelo ocupa {tamano} bytes y excede el limite de {max_bytes}; "
            "comparte el archivo .tvismodel en su lugar."
        )
    # Valida esquema y hashes antes de exportar un archivo potencialmente
    # corrupto. Solo el formato portable se puede convertir a codigo.
    if not _parece_modelo_portable(ruta):
        raise ValueError("Solo los archivos .tvismodel se pueden exportar como codigo.")
    verificar_integridad_modelo(ruta)
    datos = ruta.read_bytes()
    digest = _sha256_bytes(datos)
    contenido = base64.urlsafe_b64encode(datos).decode("ascii").rstrip("=")
    return f"{PREFIJO_CODIGO_MODELO}:{digest}:{contenido}"


def importar_codigo_modelo(codigo: str, ruta_destino: str | Path) -> Path:
    """Reconstruye atomica y verificablemente un ``.tvismodel`` desde texto."""
    if not isinstance(codigo, str):
        raise TypeError("codigo debe ser texto.")
    if len(codigo) > MAX_CARACTERES_CODIGO_MODELO:
        raise ValueError("El codigo excede el tamano maximo permitido.")
    partes = codigo.strip().split(":", 2)
    if len(partes) != 3 or partes[0] != PREFIJO_CODIGO_MODELO:
        raise ValueError(f"El codigo debe comenzar con {PREFIJO_CODIGO_MODELO}:.")
    digest, contenido = partes[1].lower(), "".join(partes[2].split())
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise ValueError("El checksum del codigo no es valido.")
    tamano_estimado = len(contenido) * 3 // 4
    if tamano_estimado > _MAX_IMPORT_CODE_BYTES:
        raise ValueError("El codigo excede el tamano maximo permitido.")
    relleno = "=" * (-len(contenido) % 4)
    try:
        datos = base64.b64decode(
            contenido + relleno, altchars=b"-_", validate=True
        )
    except (ValueError, binascii.Error) as exc:
        raise ValueError("El contenido Base64 del codigo no es valido.") from exc
    if _sha256_bytes(datos) != digest:
        raise ValueError("El checksum no coincide; el codigo esta incompleto o alterado.")

    # Se valida completamente en memoria antes de tocar el destino.
    _leer_portable(io.BytesIO(datos), cargar_pesos=False)
    ruta = _ruta_portable(ruta_destino)
    _escribir_bytes_atomico(ruta, datos)
    return ruta


# ---------------------------------------------------------------------------
# Nombres de archivo
# ---------------------------------------------------------------------------


def generar_nombre_checkpoint(
    modelo: Transformer,
    paso_global: int | None = None,
    dispositivo: str | None = None,
) -> str:
    """Genera el nombre descriptivo del checkpoint historico ``.pt``."""
    config = modelo.config
    if dispositivo is None:
        dispositivo = next(modelo.parameters()).device.type
    fecha_hora = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    partes = [
        "modelo",
        f"{config.dimension_modelo}d",
        f"{config.num_capas}c",
        f"{config.num_cabezas}h",
        config.activacion,
        f"{config.usar_mascara_causal}mascara-c",
    ]
    if paso_global is not None:
        partes.append(f"step{paso_global}")
    partes.extend((str(dispositivo), fecha_hora))
    return "_".join(partes) + ".pt"


def generar_nombre_modelo(
    modelo: Transformer,
    paso_global: int | None = None,
    dispositivo: str | None = None,
) -> str:
    """Genera un nombre descriptivo y portable para la biblioteca visual."""
    config = modelo.config
    if dispositivo is None:
        dispositivo = next(modelo.parameters()).device.type
    fecha_hora = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    partes = [
        "modelo",
        f"{config.dimension_modelo}d",
        f"{config.num_capas}enc-{config.num_capas}dec",
        f"{config.num_cabezas}h",
        config.activacion,
        f"{config.usar_mascara_causal}mascara-c",
    ]
    if paso_global is not None:
        partes.append(f"step{paso_global}")
    partes.extend((str(dispositivo), fecha_hora))
    return sanitizar_nombre_modelo("_".join(partes))


def _sanitizar_base(nombre: str) -> str:
    if not isinstance(nombre, str):
        raise TypeError("nombre debe ser texto.")
    nombre = nombre.strip()
    nombre = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", nombre)
    nombre = nombre.strip(" .")
    return nombre or "modelo"


def sanitizar_nombre_archivo(nombre: str) -> str:
    """Limpia un nombre y conserva la extension historica ``.pt``."""
    nombre = _sanitizar_base(nombre)
    if not nombre.lower().endswith(".pt"):
        nombre += ".pt"
    return nombre


def sanitizar_nombre_modelo(nombre: str) -> str:
    """Limpia un nombre y asegura la extension ``.tvismodel``."""
    nombre = _sanitizar_base(nombre)
    if not nombre.lower().endswith(EXTENSION_MODELO):
        # Evita nombres como modelo.pt.tvismodel al migrar desde el formato
        # anterior, sin eliminar puntos legitimos del nombre base.
        if nombre.lower().endswith(".pt"):
            nombre = nombre[:-3]
        nombre += EXTENSION_MODELO
    return nombre
