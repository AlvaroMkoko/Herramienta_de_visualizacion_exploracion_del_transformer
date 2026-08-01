"""
Script de entrenamiento — entrena el Transformer con tus propios datos,
desde la línea de comandos.

Dónde poner tus datos:
    Coloca tu archivo dentro de `data/datasets/` (se crea sola la
    primera vez que se importa `core/config.py`). No es obligatorio
    usar esa carpeta — podés pasar cualquier ruta con `--datos` — pero
    es la convención del proyecto para no mezclar datos con código
    fuente.

Formatos soportados:

    1) Pares ya emparejados (traducción, preguntas/respuestas):

       CSV con encabezado, dos columnas:
           pregunta,respuesta
           ¿Como estas?,Bien

       o JSON con una lista de objetos:
           [{"pregunta": "¿Como estas?", "respuesta": "Bien"}, ...]

       o JSONL (un objeto por línea, ej. datasets tipo Dolly):
           {"instruction": "...", "context": "", "response": "...", "category": "..."}

    2) Texto corrido, sin pares reales (un libro, artículos, .txt/.pdf):
       se parte automáticamente en fragmentos con `--longitud-ventana`
       tokens, y cada fragmento se empareja con el que le sigue (el
       modelo aprende a "continuar el texto"). Ver `--solapamiento-ventana`
       para generar más ejemplos de un corpus chico. Los .pdf necesitan
       tener texto seleccionable (no escaneados) y requieren `pypdf`
       instalado (`pip install pypdf`).

Ejemplos de uso:

    # Entrenar desde cero con un CSV
    python entrenar.py --datos data/datasets/mis_datos.csv \\
        --columna-origen pregunta --columna-destino respuesta \\
        --epocas 20 --dimension-modelo 128 --num-capas 4

    # Entrenar desde un JSON
    python entrenar.py --datos data/datasets/mis_datos.json \\
        --clave-origen pregunta --clave-destino respuesta --epocas 20

    # Entrenar desde un JSONL (ej. Dolly), usando tambien el contexto
    python entrenar.py --datos data/datasets/databricks-dolly-15k-es.jsonl \\
        --clave-origen instruction --clave-destino response --clave-contexto context \\
        --epocas 20 --dimension-modelo 128 --num-capas 4

    # Entrenar con un corpus de texto plano
    python entrenar.py --datos data/datasets/mi_libro.txt \\
        --longitud-ventana 128 --epocas 20 --dimension-modelo 128 --num-capas 4

    # Entrenar con un PDF (texto seleccionable, no escaneado)
    python entrenar.py --datos data/datasets/mi_documento.pdf \\
        --longitud-ventana 128 --solapamiento-ventana 32 --epocas 20

    # Reanudar un entrenamiento previo desde un checkpoint
    python entrenar.py --datos data/datasets/mis_datos.csv \\
        --columna-origen pregunta --columna-destino respuesta \\
        --reanudar-desde data/checkpoints/modelo.pt --epocas 10

Al terminar (o al interrumpir con Ctrl+C), el checkpoint se guarda en
`--checkpoint-salida` (por defecto `data/checkpoints/modelo.pt`).
"""

import argparse
import sys
from pathlib import Path

import torch

from core.config import DIR_CHECKPOINTS, DIR_DATASETS, fijar_semilla, obtener_dispositivo
from model.gestor_de_datos.dataset_loader import (
    DatasetSecuencias,
    cargar_pares_desde_csv,
    cargar_pares_desde_json,
    cargar_pares_desde_jsonl,
    cargar_texto_desde_pdf,
    cargar_texto_desde_txt,
    crear_dataloader,
    crear_pares_por_ventana,
    obtener_id_token_fin,
    obtener_id_token_inicio,
    obtener_id_token_relleno,
    obtener_tamano_vocabulario_total,
)
from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.tokenizer import Tokenizer
from model.motor_llm.transformer import Transformer
from model.persistencia.model_storage import cargar_checkpoint, guardar_checkpoint


def _parsear_argumentos() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Entrena el Transformer con datos propios.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )

    # --- Datos ---
    parser.add_argument(
        "--datos", type=Path, required=True,
        help="Ruta al archivo .csv, .json, .jsonl, .txt o .pdf con los datos.",
    )
    parser.add_argument("--columna-origen", type=str, default=None, help="Nombre de columna origen (CSV).")
    parser.add_argument("--columna-destino", type=str, default=None, help="Nombre de columna destino (CSV).")
    parser.add_argument("--clave-origen", type=str, default=None, help="Clave origen (JSON/JSONL).")
    parser.add_argument("--clave-destino", type=str, default=None, help="Clave destino (JSON/JSONL).")
    parser.add_argument(
        "--clave-contexto", type=str, default=None,
        help="Clave opcional (JSON/JSONL) con contexto adicional; se concatena al origen solo si no está vacío.",
    )
    parser.add_argument(
        "--longitud-ventana", type=int, default=64,
        help="Solo para .txt/.pdf: tokens por fragmento al partir el texto corrido en pares.",
    )
    parser.add_argument(
        "--solapamiento-ventana", type=int, default=0,
        help="Solo para .txt/.pdf: tokens que se repiten entre fragmentos consecutivos.",
    )
    parser.add_argument("--longitud-maxima", type=int, default=128, help="Longitud máxima de secuencia (trunca).")

    # --- Tokenizador ---
    parser.add_argument(
        "--tipo-encoding", type=int, default=1, choices=[0, 1, 2],
        help="0=o200k_base, 1=cl100k_base, 2=p50k_base",
    )

    # --- Arquitectura (solo se usan si NO se reanuda desde un checkpoint) ---
    parser.add_argument("--dimension-modelo", type=int, default=128)
    parser.add_argument("--num-cabezas", type=int, default=4)
    parser.add_argument("--num-capas", type=int, default=4)
    parser.add_argument("--dimension-ff", type=int, default=512)
    parser.add_argument("--dropout", type=float, default=0.1)
    parser.add_argument(
        "--sin-compartir-pesos-salida", action="store_true",
        help="Desactiva weight tying entre el embedding de salida y la capa final.",
    )

    # --- Entrenamiento ---
    parser.add_argument("--epocas", type=int, default=10)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--tasa-aprendizaje", type=float, default=3e-4)
    parser.add_argument("--semilla", type=int, default=42)
    parser.add_argument("--dispositivo", type=str, default=None, help="cpu, cuda, o vacío para autodetectar.")

    # --- Checkpoints ---
    parser.add_argument(
        "--checkpoint-salida", type=Path, default=DIR_CHECKPOINTS / "modelo.pt",
        help="Dónde guardar el checkpoint final.",
    )
    parser.add_argument(
        "--checkpoint-cada", type=int, default=0,
        help="Guardar un checkpoint intermedio cada N épocas (0 = solo al final).",
    )
    parser.add_argument(
        "--reanudar-desde", type=Path, default=None,
        help="Ruta a un checkpoint existente para continuar entrenando (ignora --dimension-modelo, etc.).",
    )

    return parser.parse_args()


def _cargar_pares(args: argparse.Namespace, tokenizer: Tokenizer) -> list[tuple[str, str]]:
    if args.datos.suffix == ".csv":
        if not args.columna_origen or not args.columna_destino:
            sys.exit("Para un CSV hay que indicar --columna-origen y --columna-destino.")
        return cargar_pares_desde_csv(args.datos, args.columna_origen, args.columna_destino)

    if args.datos.suffix == ".json":
        if not args.clave_origen or not args.clave_destino:
            sys.exit("Para un JSON hay que indicar --clave-origen y --clave-destino.")
        return cargar_pares_desde_json(args.datos, args.clave_origen, args.clave_destino)

    if args.datos.suffix == ".jsonl":
        if not args.clave_origen or not args.clave_destino:
            sys.exit("Para un JSONL hay que indicar --clave-origen y --clave-destino.")
        return cargar_pares_desde_jsonl(
            args.datos, args.clave_origen, args.clave_destino, clave_contexto=args.clave_contexto
        )

    if args.datos.suffix == ".txt":
        texto = cargar_texto_desde_txt(args.datos)
        return crear_pares_por_ventana(
            texto, tokenizer, args.longitud_ventana, solapamiento=args.solapamiento_ventana
        )

    if args.datos.suffix == ".pdf":
        texto = cargar_texto_desde_pdf(args.datos)
        return crear_pares_por_ventana(
            texto, tokenizer, args.longitud_ventana, solapamiento=args.solapamiento_ventana
        )

    sys.exit(f"Formato no soportado: {args.datos.suffix} (usa .csv, .json, .jsonl, .txt o .pdf)")


def main() -> None:
    args = _parsear_argumentos()
    fijar_semilla(args.semilla)
    dispositivo = obtener_dispositivo(args.dispositivo)
    print(f"Dispositivo: {dispositivo}")

    if not args.datos.exists():
        sys.exit(
            f"No se encontró el archivo de datos: {args.datos}\n"
            f"Tip: coloca tus datos en {DIR_DATASETS} y pasa esa ruta con --datos."
        )

    print(f"Cargando tokenizador (tipo_encoding={args.tipo_encoding}) ...")
    tokenizer = Tokenizer(args.tipo_encoding)
    id_relleno = obtener_id_token_relleno(tokenizer)
    id_inicio = obtener_id_token_inicio(tokenizer)
    id_fin = obtener_id_token_fin(tokenizer)

    print(f"Cargando datos desde {args.datos} ...")
    pares = _cargar_pares(args, tokenizer)
    print(f"{len(pares)} pares de entrenamiento cargados.")

    dataset = DatasetSecuencias(pares, tokenizer, id_inicio, id_fin, longitud_maxima=args.longitud_maxima)
    dataloader = crear_dataloader(dataset, id_relleno, batch_size=args.batch_size, shuffle=True)

    # --- Modelo: nuevo, o reanudado desde un checkpoint ---
    paso_global_inicial = 0
    epoca_inicial = 0
    historial_perdidas: list[float] = []

    if args.reanudar_desde is not None:
        print(f"Reanudando desde {args.reanudar_desde} ...")
        resultado = cargar_checkpoint(args.reanudar_desde, dispositivo=dispositivo)
        modelo = resultado.modelo
        modelo.train()
        optimizador = torch.optim.Adam(modelo.parameters(), lr=args.tasa_aprendizaje)
        if resultado.tiene_estado_optimizador:
            optimizador.load_state_dict(resultado.optimizer_state_dict)
        epoca_inicial = (resultado.epoca or 0) + 1
        paso_global_inicial = resultado.paso_global or 0
        historial_perdidas = list(resultado.historial_perdidas)
        print(f"Modelo cargado. Continuando desde la época {epoca_inicial}.")
    else:
        config = ConfiguracionTransformer(
            tamano_vocabulario=obtener_tamano_vocabulario_total(tokenizer),
            dimension_modelo=args.dimension_modelo,
            num_cabezas=args.num_cabezas,
            num_capas=args.num_capas,
            dimension_ff=args.dimension_ff,
            longitud_maxima_secuencia=args.longitud_maxima + 1,
            dropout=args.dropout,
            id_token_relleno=id_relleno,
        )
        modelo = Transformer(config, compartir_pesos_salida=not args.sin_compartir_pesos_salida)
        modelo.to(dispositivo)
        optimizador = torch.optim.Adam(modelo.parameters(), lr=args.tasa_aprendizaje)
        num_parametros = sum(p.numel() for p in modelo.parameters())
        print(f"Modelo nuevo creado: {num_parametros:,} parámetros.")

    # --- Bucle de entrenamiento ---
    paso_global = paso_global_inicial
    try:
        for epoca in range(epoca_inicial, epoca_inicial + args.epocas):
            perdida_acumulada = 0.0
            num_batches = 0

            for origen, destino_entrada, destino_objetivo in dataloader:
                origen = origen.to(dispositivo)
                destino_entrada = destino_entrada.to(dispositivo)
                destino_objetivo = destino_objetivo.to(dispositivo)

                optimizador.zero_grad()
                logits = modelo(origen, destino_entrada)
                perdida = modelo.calcular_perdida(logits, destino_objetivo)
                perdida.backward()
                optimizador.step()

                paso_global += 1
                perdida_acumulada += perdida.item()
                num_batches += 1
                historial_perdidas.append(perdida.item())

            perdida_promedio = perdida_acumulada / max(num_batches, 1)
            print(f"Época {epoca + 1}: pérdida promedio = {perdida_promedio:.4f}")

            if args.checkpoint_cada and (epoca + 1) % args.checkpoint_cada == 0:
                ruta_intermedia = args.checkpoint_salida.with_stem(
                    f"{args.checkpoint_salida.stem}_epoca{epoca + 1}"
                )
                guardar_checkpoint(
                    ruta_intermedia, modelo, optimizador=optimizador,
                    epoca=epoca, paso_global=paso_global, historial_perdidas=historial_perdidas,
                    metadata_extra={"origen_datos": str(args.datos), "tipo_encoding": args.tipo_encoding},
                )
                print(f"  Checkpoint intermedio guardado: {ruta_intermedia}")

    except KeyboardInterrupt:
        print("\nEntrenamiento interrumpido por el usuario. Guardando checkpoint antes de salir...")

    guardar_checkpoint(
        args.checkpoint_salida, modelo, optimizador=optimizador,
        epoca=epoca, paso_global=paso_global, historial_perdidas=historial_perdidas,
        metadata_extra={"origen_datos": str(args.datos), "tipo_encoding": args.tipo_encoding},
    )
    print(f"Checkpoint final guardado en: {args.checkpoint_salida}")


if __name__ == "__main__":
    main()