"""
Script para probar un modelo ya entrenado — genera texto a partir de un
checkpoint, desde la línea de comandos.

Modo de uso rápido (un solo prompt):

    python generar.py --checkpoint data/checkpoints/modelo.pt \
        --prompt "hola, como estas"

Modo interactivo (sin --prompt, abre un loop tipo chat):

    python generar.py --checkpoint data/checkpoints/modelo.pt

    Escribí "salir" (o Ctrl+C) para terminar.

El tokenizador se reconstruye automáticamente a partir de lo que
`entrenar.py` guardó en el checkpoint (`tipo_encoding`). Si el
checkpoint es de una corrida vieja que no lo guardó, hay que indicarlo a
mano con `--tipo-encoding`.
"""

import argparse
import sys

import torch

from core.config import obtener_dispositivo
from model.motor_llm.tokenizer import Tokenizer
from model.persistencia.model_storage import cargar_checkpoint


def _parsear_argumentos() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Genera texto con un modelo Transformer ya entrenado.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )

    parser.add_argument("--checkpoint", required=True, help="Ruta al checkpoint (.pt) a cargar.")
    parser.add_argument(
        "--prompt", type=str, default=None,
        help="Texto de entrada. Si se omite, se abre un modo interactivo (loop tipo chat).",
    )

    parser.add_argument("--max-tokens", type=int, default=100, help="Máximo de tokens a generar.")
    parser.add_argument(
        "--codicioso", action="store_true",
        help="Muestreo determinista (siempre el token más probable). Sin esto, se muestrea con aleatoriedad.",
    )
    parser.add_argument("--temperatura", type=float, default=1.0, help="Ignorado si --codicioso.")
    parser.add_argument("--top-k", type=int, default=None, help="Ignorado si --codicioso.")
    parser.add_argument("--top-p", type=float, default=None, help="Ignorado si --codicioso.")

    parser.add_argument(
        "--tipo-encoding", type=int, default=None, choices=[0, 1, 2],
        help="Fuerza el tokenizador (0=o200k_base, 1=cl100k_base, 2=p50k_base). "
        "Por defecto usa el que quedó guardado en el checkpoint.",
    )
    parser.add_argument("--dispositivo", type=str, default=None, help="cpu, cuda, o vacío para autodetectar.")

    return parser.parse_args()


def _generar_una_vez(modelo, tokenizer, prompt, id_inicio, id_fin, dispositivo, args) -> str:
    """Genera texto para UN prompt, imprimiendo cada token a medida que
    aparece (para que se sienta interactivo, no una espera larga y
    silenciosa hasta el final)."""
    tokens_origen = torch.tensor([tokenizer.encode(prompt)], device=dispositivo)

    ids_generados: list[int] = []
    for paso in modelo.generar(
        tokens_origen,
        id_token_inicio=id_inicio,
        id_token_fin=id_fin,
        max_tokens_nuevos=args.max_tokens,
        temperatura=args.temperatura,
        top_k=args.top_k,
        top_p=args.top_p,
        muestreo_codicioso=args.codicioso,
    ):
        if paso["token_id"] == id_fin:
            break
        ids_generados.append(paso["token_id"])
        # Se decodifica SOLO el token nuevo para ir imprimiendo en vivo.
        # Ojo: con BPE esto puede mostrar caracteres sueltos raros en
        # medio de una palabra multi-token; es una limitación cosmética
        # menor del streaming token a token, no afecta el resultado final.
        print(tokenizer.decode([paso["token_id"]]), end="", flush=True)

    print()  # salto de línea final
    return tokenizer.decode(ids_generados)


def main() -> None:
    args = _parsear_argumentos()
    dispositivo = obtener_dispositivo(args.dispositivo)

    print(f"Cargando checkpoint desde {args.checkpoint} ...")
    resultado = cargar_checkpoint(args.checkpoint, dispositivo=dispositivo)
    modelo = resultado.modelo

    tipo_encoding = args.tipo_encoding
    if tipo_encoding is None:
        tipo_encoding = resultado.metadata_extra.get("tipo_encoding")
        if tipo_encoding is None:
            print(
                "Aviso: este checkpoint no tiene guardado el tipo_encoding original. "
                "Se usará el valor por defecto (1 = cl100k_base). Si el texto generado "
                "sale con sentido raro, probá pasando --tipo-encoding explícitamente."
            )
            tipo_encoding = 1

    tokenizer = Tokenizer(tipo_encoding)

    # id_inicio e id_fin se derivan del id_token_relleno guardado en la
    # config del propio checkpoint (ver dataset_loader.py: siempre son
    # id_relleno+1 e id_relleno+2), así no hace falta guardarlos aparte.
    if modelo.config.id_token_relleno is None:
        sys.exit(
            "Este checkpoint no tiene id_token_relleno configurado, así que no se puede "
            "determinar id_token_inicio/id_token_fin de forma automática."
        )
    id_inicio = modelo.config.id_token_relleno + 1
    id_fin = modelo.config.id_token_relleno + 2

    num_parametros = sum(p.numel() for p in modelo.parameters())
    print(f"Modelo cargado: {num_parametros:,} parámetros.")
    if resultado.epoca is not None:
        print(f"Entrenado hasta la época {resultado.epoca + 1}, {resultado.paso_global} pasos.")
    print()

    if args.prompt is not None:
        _generar_una_vez(modelo, tokenizer, args.prompt, id_inicio, id_fin, dispositivo, args)
        return

    # --- Modo interactivo ---
    print('Modo interactivo. Escribí "salir" o Ctrl+C para terminar.\n')
    try:
        while True:
            prompt = input("Vos: ").strip()
            if prompt.lower() in {"salir", "exit", "quit"}:
                break
            if not prompt:
                continue
            print("Modelo: ", end="", flush=True)
            _generar_una_vez(modelo, tokenizer, prompt, id_inicio, id_fin, dispositivo, args)
    except (KeyboardInterrupt, EOFError):
        print("\nHasta luego.")


if __name__ == "__main__":
    main()