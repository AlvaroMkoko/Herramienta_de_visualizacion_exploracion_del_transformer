# Transformer Visualizer

Herramienta de escritorio para exploración e interpretación de modelos tipo
Transformer, construida bajo el patrón arquitectónico **MVVM**:

- **Model** (`model/`): PyTorch — lógica de negocio, motor LLM, datos, evaluación.
- **ViewModel** (`viewmodel/`): PySide6 — orquestación, señales, concurrencia.
- **View** (`view/`): QML + VisPy/OpenGL — interfaz gráfica y renderizado científico.

## Instalación

```bash
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# PyTorch con soporte CUDA 12.8+ (necesario para GPUs Blackwell, ej. RTX 5070 Ti)
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

pip install -r requirements.txt
```

## Ejecución

```bash
python main.py
```

## Estructura

Ver `docs/architecture.md` para el detalle de la arquitectura MVVM y el
mapeo de componentes descrito en el documento de diseño (TT1).
