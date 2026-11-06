"""Manifiesto SHA-256 de un paquete distribuido de la herramienta.

Registra el hash del ``.zip`` que se entrega, del ejecutable y del modelo
incluido, más el de cada archivo de la carpeta, para poder afirmar después
qué binario exacto se probó. El hash detecta discrepancias; no acredita al
autor (para eso hace falta firmar el ejecutable).

Uso:
    python -m pruebas.auditoria.huella_ejecutable RUTA.zip|CARPETA [--commit HASH] [--json salida.json]
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import time
from pathlib import Path


def sha256(ruta: Path) -> str:
    resumen = hashlib.sha256()
    with ruta.open("rb") as archivo:
        for bloque in iter(lambda: archivo.read(1 << 20), b""):
            resumen.update(bloque)
    return resumen.hexdigest()


def _registro(ruta: Path, base: Path) -> dict:
    estado = ruta.stat()
    return {
        "ruta": ruta.relative_to(base).as_posix() if ruta != base else ruta.name,
        "bytes": estado.st_size,
        "modificado": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(estado.st_mtime)),
        "sha256": sha256(ruta),
    }


def manifiesto(objetivo: Path, commit: str | None) -> dict:
    datos: dict = {"generado": time.strftime("%Y-%m-%d %H:%M:%S"), "commit": commit}
    if objetivo.is_file():
        datos["paquete"] = _registro(objetivo, objetivo.parent)
        return datos
    archivos = sorted(p for p in objetivo.rglob("*") if p.is_file())
    datos["carpeta"] = objetivo.name
    datos["num_archivos"] = len(archivos)
    datos["principales"] = [
        _registro(p, objetivo) for p in archivos if p.suffix.lower() in {".exe", ".tvismodel"}
    ]
    # Hash del conjunto: cambia si cambia cualquier archivo o su ruta.
    conjunto = hashlib.sha256()
    for p in archivos:
        conjunto.update(p.relative_to(objetivo).as_posix().encode("utf-8"))
        conjunto.update(bytes.fromhex(sha256(p)))
    datos["sha256_conjunto"] = conjunto.hexdigest()
    return datos


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("objetivos", nargs="+", type=Path)
    parser.add_argument("--commit")
    parser.add_argument("--json", type=Path)
    args = parser.parse_args(argv)
    informe = [manifiesto(objetivo, args.commit) for objetivo in args.objetivos]
    texto = json.dumps(informe, indent=2, ensure_ascii=False)
    print(texto)
    if args.json:
        args.json.write_text(texto, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
