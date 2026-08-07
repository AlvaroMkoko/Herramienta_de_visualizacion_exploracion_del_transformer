"""
Guardado y carga de checkpoints del modelo entrenado.
"""

from dataclasses import asdict
from pathlib import Path
from typing import Any
import datetime
import re

import torch

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer

VERSION_FORMATO_CHECKPOINT = 1

def guardar_checkpoint(
    ruta: str | Path,
    modelo: Transformer,
    optimizador: torch.optim.Optimizer | None = None,
    epoca: int | None = None,
    paso_global: int | None = None,
    historial_perdidas: list[float] | None = None,
    metadata_extra: dict[str, Any] | None = None,
) -> None:
    ruta = Path(ruta)
    ruta.parent.mkdir(parents=True, exist_ok=True)

    contenido = {
        "version_formato": VERSION_FORMATO_CHECKPOINT,
        "config": asdict(modelo.config),
        "compartir_pesos_salida": modelo.compartir_pesos_salida,
        "model_state_dict": modelo.state_dict(),
        "optimizer_state_dict": optimizador.state_dict() if optimizador is not None else None,
        "epoca": epoca,
        "paso_global": paso_global,
        "historial_perdidas": historial_perdidas or [],
        "metadata_extra": metadata_extra or {},
    }

    torch.save(contenido, ruta)


class ResultadoCarga:
    def __init__(self, modelo, optimizer_state_dict, epoca, paso_global, historial_perdidas, metadata_extra):
        self.modelo = modelo
        self.optimizer_state_dict = optimizer_state_dict
        self.epoca = epoca
        self.paso_global = paso_global
        self.historial_perdidas = historial_perdidas
        self.metadata_extra = metadata_extra

    @property
    def tiene_estado_optimizador(self) -> bool:
        return self.optimizer_state_dict is not None


def cargar_checkpoint(ruta: str | Path, dispositivo: str | torch.device | None = None) -> ResultadoCarga:
    """Nota de seguridad: usa weights_only=False porque el checkpoint
    incluye metadatos no-tensor. SOLO cargar checkpoints propios,
    nunca archivos .pt de fuentes no verificadas."""
    ruta = Path(ruta)
    if not ruta.exists():
        raise FileNotFoundError(f"No se encontró el checkpoint: {ruta}")

    contenido = torch.load(ruta, map_location=dispositivo, weights_only=False)

    claves_requeridas = {"config", "compartir_pesos_salida", "model_state_dict"}
    if not claves_requeridas.issubset(contenido.keys()):
        faltantes = claves_requeridas - contenido.keys()
        raise ValueError(f"El archivo no parece ser un checkpoint válido (faltan claves: {faltantes}).")

    config = ConfiguracionTransformer(**contenido["config"])
    modelo = Transformer(config, compartir_pesos_salida=contenido["compartir_pesos_salida"])
    modelo.load_state_dict(contenido["model_state_dict"])
    modelo.eval()

    if dispositivo is not None:
        modelo.to(dispositivo)

    return ResultadoCarga(
        modelo=modelo,
        optimizer_state_dict=contenido.get("optimizer_state_dict"),
        epoca=contenido.get("epoca"),
        paso_global=contenido.get("paso_global"),
        historial_perdidas=contenido.get("historial_perdidas", []),
        metadata_extra=contenido.get("metadata_extra", {}),
    )

def generar_nombre_checkpoint(
    modelo: Transformer,
    paso_global: int | None = None,
    dispositivo: str | None = None,
) -> str:
    """Formato: modelo_{dim}d_{capas}c_{cabezas}h_{activacion}_{usar_mascara_causal}mascara-c[_step{n}]_{dispositivo}_{fecha}_{hora}.pt"""
    config = modelo.config
    if dispositivo is None:
        dispositivo = next(modelo.parameters()).device.type

    fecha_hora = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")

    partes = ["modelo", f"{config.dimension_modelo}d", f"{config.num_capas}c", f"{config.num_cabezas}h", f"{config.activacion}", f"{config.usar_mascara_causal}mascara-c"]
    if paso_global is not None:
        partes.append(f"step{paso_global}")
    partes.append(dispositivo)
    partes.append(fecha_hora)

    return "_".join(partes) + ".pt"


def sanitizar_nombre_archivo(nombre: str) -> str:
    """Limpia caracteres inválidos para nombres de archivo (usa el
    conjunto más restrictivo, el de Windows, para que funcione en
    cualquier sistema operativo) y agrega .pt si falta."""
    nombre = nombre.strip()
    nombre = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", nombre)
    nombre = nombre.strip(" .")

    if not nombre:
        nombre = "modelo"
    if not nombre.lower().endswith(".pt"):
        nombre += ".pt"
    return nombre