# Construye la carpeta distribuible para los equipos del laboratorio (ESPEC-F).
# Desde la raiz del repositorio, con red (la primera vez descarga dependencias
# y las tablas de tiktoken):
#
#   powershell -ExecutionPolicy Bypass -File tools\construir_ejecutable.ps1
#
# Salida: dist\TransformerVisualizer\ (se distribuye comprimida, sin instalador).
#
# Usa un entorno propio, .venv-empaquetado\, con torch de CPU: el .venv de
# desarrollo lleva la rueda de CUDA, que pesa unas diez veces mas, y no se toca.
# El interprete base es el mismo que el del .venv, para construir con la misma
# version de Python con la que se prueba la aplicacion.

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $PSScriptRoot
Set-Location $raiz

$venv = Join-Path $raiz ".venv-empaquetado"
$py = Join-Path $venv "Scripts\python.exe"

if (-not (Test-Path $py)) {
    $base = & (Join-Path $raiz ".venv\Scripts\python.exe") -c "import sys; print(sys._base_executable)"
    Write-Host "Creando $venv con $base"
    & $base -m venv $venv
    if ($LASTEXITCODE -ne 0) { throw "No se pudo crear el entorno de construccion." }
}

& $py -m pip install --quiet --upgrade pip
& $py -m pip install --quiet "torch==2.11.0+cpu" --index-url https://download.pytorch.org/whl/cpu
if ($LASTEXITCODE -ne 0) { throw "No se pudo instalar torch de CPU." }
& $py -m pip install --quiet -r requirements-empaquetado.txt
if ($LASTEXITCODE -ne 0) { throw "No se pudieron instalar las dependencias de empaquetado." }

& $py tools\sembrar_cache_tiktoken.py
if ($LASTEXITCODE -ne 0) { throw "No se pudo sembrar la cache de tiktoken." }

& $py -m PyInstaller --noconfirm --clean transformer_visualizer.spec
if ($LASTEXITCODE -ne 0) { throw "PyInstaller fallo." }

$salida = Join-Path $raiz "dist\TransformerVisualizer"
$bytes = (Get-ChildItem $salida -Recurse -File | Measure-Object Length -Sum).Sum
$modelo = (Get-ChildItem (Join-Path $salida "datos\checkpoints") -File | Measure-Object Length -Sum).Sum
Write-Host ("Listo: {0}" -f $salida) -ForegroundColor Green
Write-Host ("  carpeta completa: {0:N1} MB" -f ($bytes / 1MB))
Write-Host ("  sin el modelo:    {0:N1} MB" -f (($bytes - $modelo) / 1MB))
