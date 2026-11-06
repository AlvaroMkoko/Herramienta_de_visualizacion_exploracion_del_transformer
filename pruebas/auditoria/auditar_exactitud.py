"""Contrasta el motor de PyTorch con la referencia NumPy (RNF07).

Uso, desde la raíz del repositorio:

    python -m pruebas.auditoria.auditar_exactitud [ruta.tvismodel ...] [--json salida.json]

Compara logits y mapas de atención de todas las capas para configuraciones
aleatorias (las tres activaciones, con y sin relleno) y, si se indican, para
modelos guardados. El motor corre en float64 para que la diferencia mida
errores de fórmula y no redondeo de float32; también se reporta float32.
"""

from __future__ import annotations

import argparse
import json
import platform
import sys
from pathlib import Path

import numpy as np
import torch

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from pruebas.auditoria.referencia_numpy import ReferenciaTransformer, codificacion_posicional

# Tolerancias de aceptación: en float64, con la misma tabla PE, el motor y la
# referencia hacen las mismas operaciones en otro orden; solo cabe redondeo.
TOLERANCIA_FLOAT64 = 1e-9
TOLERANCIA_FLOAT32 = 1e-3


def _referencia(modelo: Transformer) -> ReferenciaTransformer:
    config = modelo.config
    pesos = {n: t.detach().cpu().double().numpy() for n, t in modelo.state_dict().items()}
    return ReferenciaTransformer(
        pesos,
        num_cabezas=config.num_cabezas,
        num_capas=config.num_capas,
        activacion=config.activacion,
        id_relleno=config.id_token_relleno,
        mascara_causal=config.usar_mascara_causal,
    )


def comparar(modelo: Transformer, origen: list[int], destino: list[int]) -> dict[str, float]:
    """Máxima diferencia absoluta por magnitud entre motor y referencia."""
    referencia = _referencia(modelo)
    esperado = referencia.logits(origen, destino)
    resultado: dict[str, float] = {}
    for nombre, tipo in (("float64", torch.float64), ("float32", torch.float32)):
        copia = Transformer(modelo.config).to(tipo)
        copia.load_state_dict({n: t.to(tipo) for n, t in modelo.state_dict().items()})
        copia.eval()
        if nombre == "float64":
            # El búfer PE del motor se calcula en float32 aunque el modelo pase
            # a float64. Se sustituye por la tabla exacta para que la
            # comparación aísle las fórmulas; su error se reporta aparte.
            pe = copia.codificacion_posicional.pe
            exacta = torch.from_numpy(codificacion_posicional(pe.size(1), pe.size(2)))[None]
            resultado["pe_float32"] = float((pe - exacta).abs().max())
            copia.codificacion_posicional.pe = exacta
        with torch.no_grad():
            logits = copia(torch.tensor([origen]), torch.tensor([destino]))[0]
        resultado[f"logits_{nombre}"] = float(np.max(np.abs(logits.double().numpy() - esperado)))
        if nombre == "float64":
            pares = [
                ("encoder", [b.ultimos_pesos_atencion for b in copia.encoder.bloques]),
                ("autoatencion", copia.decoder.pesos_autoatencion_por_capa()),
                ("cruzada", copia.decoder.pesos_atencion_cruzada_por_capa()),
            ]
            diferencia = 0.0
            for clave, motor in pares:
                for capa, pesos in enumerate(motor):
                    diferencia = max(
                        diferencia,
                        float(np.max(np.abs(pesos[0].numpy() - referencia.pesos_atencion[clave][capa]))),
                    )
            resultado["atencion_float64"] = diferencia
    return resultado


def configuraciones_sinteticas() -> list[tuple[str, ConfiguracionTransformer, list[int], list[int]]]:
    casos = []
    for activacion in ("relu", "gelu", "swish"):
        for relleno in (None, 0):
            config = ConfiguracionTransformer(
                tamano_vocabulario=50,
                dimension_modelo=32,
                num_cabezas=4,
                num_capas=2,
                dimension_ff=64,
                longitud_maxima_secuencia=32,
                dropout=0.0,
                activacion=activacion,
                id_token_relleno=relleno,
            )
            origen = [5, 9, 13, 21, 7, 3, 0, 0] if relleno == 0 else [5, 9, 13, 21, 7, 3, 11, 2]
            destino = [1, 14, 8, 30, 0] if relleno == 0 else [1, 14, 8, 30, 6]
            casos.append((f"sintetico {activacion} relleno={relleno}", config, origen, destino))
    return casos


def auditar(rutas: list[Path]) -> dict:
    torch.manual_seed(20261105)
    filas = []
    for nombre, config, origen, destino in configuraciones_sinteticas():
        filas.append({"caso": nombre, **comparar(Transformer(config), origen, destino)})
    for ruta in rutas:
        from model.persistencia.model_storage import cargar_modelo_portable

        modelo = cargar_modelo_portable(ruta, "cpu").modelo
        vocabulario = modelo.config.tamano_vocabulario
        generador = torch.Generator().manual_seed(7)
        origen = torch.randint(4, vocabulario, (12,), generator=generador).tolist()
        destino = torch.randint(4, vocabulario, (9,), generator=generador).tolist()
        filas.append({"caso": ruta.name, **comparar(modelo, origen, destino)})
    aprobado = all(
        f["logits_float64"] <= TOLERANCIA_FLOAT64
        and f["atencion_float64"] <= TOLERANCIA_FLOAT64
        and f["logits_float32"] <= TOLERANCIA_FLOAT32
        for f in filas
    )
    return {
        "aprobado": aprobado,
        "tolerancias": {"float64": TOLERANCIA_FLOAT64, "float32": TOLERANCIA_FLOAT32},
        "entorno": {
            "python": platform.python_version(),
            "torch": torch.__version__,
            "numpy": np.__version__,
            "sistema": platform.platform(),
        },
        "casos": filas,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("modelos", nargs="*", type=Path)
    parser.add_argument("--json", type=Path)
    args = parser.parse_args(argv)
    informe = auditar(args.modelos)
    print(f"{'caso':<62} {'logits f64':>11} {'atencion f64':>13} {'logits f32':>11} {'PE f32':>9}")
    for fila in informe["casos"]:
        print(
            f"{fila['caso'][:62]:<62} {fila['logits_float64']:>11.2e} "
            f"{fila['atencion_float64']:>13.2e} {fila['logits_float32']:>11.2e} "
            f"{fila['pe_float32']:>9.2e}"
        )
    print("APROBADO" if informe["aprobado"] else "NO APROBADO")
    if args.json:
        args.json.write_text(json.dumps(informe, indent=2, ensure_ascii=False), encoding="utf-8")
    return 0 if informe["aprobado"] else 1


if __name__ == "__main__":
    sys.exit(main())
