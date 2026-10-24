"""Siembra la caché de ``tiktoken`` que viaja dentro del ejecutable.

``tiktoken.get_encoding()`` descarga la tabla de cada codificación desde
``openaipublic.blob.core.windows.net`` la primera vez que se pide. En un equipo
del laboratorio sin red eso deja la aplicación sin tokenizador: ni tokenizar, ni
inferir, ni activar un modelo guardado. Este script descarga las tablas **una
vez, en la máquina que construye**, y ``main.py`` apunta ``TIKTOKEN_CACHE_DIR`` a
la copia empaquetada.

Por qué se le deja escribir la caché a ``tiktoken`` en vez de copiar archivos
-----------------------------------------------------------------------------
El nombre de cada archivo es el SHA-1 de la URL de origen, sin extensión
(``tiktoken/load.py``, ``read_file_cached``). Es un detalle interno que puede
cambiar entre versiones. Pidiendo cada codificación con la variable ya fijada,
los nombres salen de la versión instalada y el contenido queda verificado contra
el SHA-256 que esa misma versión espera.

Se siembran las tres de ``ENCODINGS``: un modelo guardado puede declarar
cualquiera de ellas.

Uso, desde la raíz del repositorio y con red:

    python tools/sembrar_cache_tiktoken.py [directorio_salida]

Por omisión escribe en ``build/cache_tiktoken``, que es donde lo busca
``transformer_visualizer.spec``. La carpeta no entra al repositorio.
"""
import os
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DESTINO_POR_OMISION = RAIZ / "build" / "cache_tiktoken"


def main() -> None:
    destino = Path(sys.argv[1]) if len(sys.argv) > 1 else DESTINO_POR_OMISION
    destino = destino.resolve()
    destino.mkdir(parents=True, exist_ok=True)

    # Antes de importar tiktoken: así ninguna codificación se resuelve contra
    # la caché temporal del usuario.
    os.environ["TIKTOKEN_CACHE_DIR"] = str(destino)

    sys.path.insert(0, str(RAIZ))
    import tiktoken
    from model.motor_llm.tokenizer import ENCODINGS

    for nombre in ENCODINGS:
        n_vocab = tiktoken.get_encoding(nombre).n_vocab
        print(f"{nombre}: {n_vocab} tokens")

    archivos = sorted(p for p in destino.iterdir() if p.is_file())
    sobrantes = [p for p in archivos if p.suffix == ".tmp"]
    if sobrantes:
        sys.exit(f"Quedaron descargas a medias en {destino}: {[p.name for p in sobrantes]}")
    total = sum(p.stat().st_size for p in archivos)
    print(f"tiktoken {tiktoken.__version__} -> {destino}")
    for archivo in archivos:
        print(f"  {archivo.name}  {archivo.stat().st_size:>9} B")
    print(f"  total {total} B")


if __name__ == "__main__":
    main()
