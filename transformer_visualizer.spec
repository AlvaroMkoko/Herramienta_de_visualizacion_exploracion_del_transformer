# -*- mode: python ; coding: utf-8 -*-
"""Empaquetado para los equipos del laboratorio (ESPEC-F).

Se construye con ``tools/construir_ejecutable.ps1``, que prepara el entorno de
CPU, siembra la caché de tiktoken y llama a PyInstaller con este archivo.
A mano, desde la raíz y con ``.venv-empaquetado`` activo:

    python tools/sembrar_cache_tiktoken.py
    python -m PyInstaller --noconfirm --clean transformer_visualizer.spec

Decisiones (la razón completa está en ESPEC-F):

* ``onedir`` y no ``onefile``: ``onefile`` descomprime PyTorch a una carpeta
  temporal en cada arranque y, peor, ahí escribir es perder el trabajo al
  cerrar (docstring de ``core/rutas.py``).
* Se distribuye la carpeta comprimida, no un instalador: en modo portable
  ``DIR_DATOS`` es ``datos\\`` junto al ejecutable y los resultados del piloto
  se recogen copiando esa carpeta.
* El modelo entrenado viaja en ``datos\\checkpoints\\``, no como recurso: la
  biblioteca escribe junto al modelo (metadatos, renombres), y dentro del
  paquete eso sería una ruta de solo lectura.

``TRANSFORMER_SIN_EXCLUSIONES=1`` construye sin la lista ``EXCLUIDOS``; solo
sirve para medir cuánto ahorra (ESPEC-F §8.3) y necesita un entorno que tenga
esos paquetes instalados.
"""
import os
import shutil
from pathlib import Path

RAIZ = Path(SPECPATH)
NOMBRE = "TransformerVisualizer"

CACHE_TIKTOKEN = RAIZ / "build" / "cache_tiktoken"
if not CACHE_TIKTOKEN.is_dir() or len(list(CACHE_TIKTOKEN.iterdir())) < 3:
    # Sin la caché el ejecutable arranca, pero sin red no puede tokenizar ni
    # activar un modelo: el fallo aparecería en el laboratorio, no aquí.
    raise SystemExit(
        f"Falta la caché de tiktoken en {CACHE_TIKTOKEN}. "
        "Corre antes: python tools/sembrar_cache_tiktoken.py"
    )

MODELO = (
    RAIZ / "data" / "checkpoints"
    / "Esp-Ing-modelo_128d_4enc-4dec_4h_relu_Truemascara-c_step3750_cuda_20261023_004238.tvismodel"
)
if not MODELO.is_file():
    raise SystemExit(f"Falta el modelo que se distribuye: {MODELO}")

# Recursos de solo lectura; ``core.rutas.recurso()`` los busca bajo
# ``sys._MEIPASS`` con la misma ruta relativa que en el código fuente.
# Rutas absolutas: PyInstaller resolvería las relativas contra la carpeta del
# .spec que lo invoca, y la sonda de pruebas reutiliza este archivo desde otra.
datos = [
    (str(RAIZ / origen), destino)
    for origen, destino in [
        ("view/qml", "view/qml"),
        ("view/assets", "view/assets"),
        ("data/teoria", "data/teoria"),
        ("data/evaluacion", "data/evaluacion"),
        ("data/aprendizaje", "data/aprendizaje"),
        ("data/datasets_predefinidos", "data/datasets_predefinidos"),
        # De data/aula solo es recurso la lista de apodos. data/aula/clases/
        # es estado de ejecución (``dato("aula", "clases")``) y trae el
        # secreto de la clase con que se probó: no debe viajar.
        ("data/aula/palabras_bloqueadas.json", "data/aula"),
        ("scripts/permitir_firewall_aula.ps1", "scripts"),
    ]
] + [(str(CACHE_TIKTOKEN), "cache_tiktoken")]

# tiktoken descubre sus codificaciones recorriendo el paquete de espacio de
# nombres ``tiktoken_ext``; PyInstaller no lo sigue y el ejecutable falla con
# «Unknown encoding o200k_base» aunque la caché esté.
ocultos = ["tiktoken_ext.openai_public"]

# Ningún módulo de producción los importa (ESPEC-F §3). Se excluyen igual por
# si algún hook los arrastra: datasets trae pandas y pyarrow detrás.
EXCLUIDOS = [
    "datasets", "pandas", "pyarrow",
    "torchvision", "torchaudio",
    "pytest", "pytestqt", "_pytest", "black", "ruff",
]
excluidos = [] if os.environ.get("TRANSFORMER_SIN_EXCLUSIONES") == "1" else EXCLUIDOS

a = Analysis(
    [str(RAIZ / "main.py")],
    pathex=[str(RAIZ)],
    binaries=[],
    datas=datos,
    hiddenimports=ocultos,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=excluidos,
    noarchive=False,
    optimize=0,
)
# view/qml/ trae las instrucciones del agente de desarrollo (CLAUDE.md): son
# del repositorio, no de la aplicación, y no deben viajar a los equipos.
a.datas = [entrada for entrada in a.datas if Path(entrada[0]).name != "CLAUDE.md"]

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name=NOMBRE,
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    # UPX comprime DLLs de Qt y torch y es de lo que más dispara antivirus.
    upx=False,
    console=False,
    icon=str(RAIZ / "view" / "assets" / "icono.ico"),
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,
    name=NOMBRE,
)

# Lo que no es recurso del paquete sino de la carpeta distribuida.
DESTINO = Path(DISTPATH) / NOMBRE

# El docente corre el script a mano con la ruta de docs/uso_aula.md
# (``scripts\permitir_firewall_aula.ps1``); bajo ``_internal\`` no lo hallaría.
(DESTINO / "scripts").mkdir(exist_ok=True)
shutil.copy2(RAIZ / "scripts" / "permitir_firewall_aula.ps1", DESTINO / "scripts")

# El modelo, con su nombre de procedencia intacto y su estado de optimizador:
# tiene que ser idéntico al del piloto. En modo portable ``DIR_CHECKPOINTS``
# resuelve aquí y la biblioteca lo encuentra sin registrarlo.
(DESTINO / "datos" / "checkpoints").mkdir(parents=True, exist_ok=True)
shutil.copy2(MODELO, DESTINO / "datos" / "checkpoints" / MODELO.name)
