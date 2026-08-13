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

## Guardar, abrir y compartir modelos

- En la pantalla de entrenamiento se puede guardar un **modelo portable** o
  un **checkpoint reanudable**. Ambos usan la extensión `.tvismodel` y se
  almacenan en `data/checkpoints/`.
- **Abrir Modelo** separa la inspección de la activación. La biblioteca permite
  buscar y ordenar checkpoints; **Ver detalles** abre arquitectura, procedencia,
  historial, tokenizador, prueba de salud, versiones e integridad sin cambiar el
  modelo activo. **Abrir en inferencia** sí carga y activa el modelo.
- La vista de detalle explica dimensiones tensoriales, parámetros por bloque,
  weight tying, normalización, compatibilidad y los tres niveles de continuación
  (reanudación exacta, continuar con Adam y entrenar desde pesos). Los campos que
  un checkpoint antiguo no registró se muestran como no disponibles, sin inferir
  validación, perplexity o precisión a partir de la pérdida de entrenamiento.
- El probador de tokenización muestra tokens, ids, caracteres, tokens especiales
  y ocupación del contexto. La prueba de salud ejecuta prompts breves y reporta
  NaN/Inf, repetición, EOS, confianza y rendimiento; la coherencia se deja como
  revisión humana.
- Un modelo puede abrirse directamente en inferencia o cargarse para continuar
  entrenando después de seleccionar nuevos datasets. Los checkpoints también se
  pueden agrupar, etiquetar, anotar, renombrar y duplicar mediante metadatos de
  biblioteca que no alteran sus pesos.
- Desde la biblioteca se puede importar/exportar un archivo, copiarlo al
  portapapeles, copiar únicamente su ficha JSON o generar un código `TVIS1`
  para modelos de hasta 5 MiB.

El formato portable contiene un manifiesto JSON inspeccionable y pesos de
PyTorch cargados con `weights_only=True`, verificados mediante SHA-256. Los
checkpoints `.pt` anteriores siguen siendo compatibles como formato legado.
La variante reanudable conserva el estado de Adam, pero se etiqueta como
reanudación no exacta porque todavía no almacena el orden del sampler ni todos
los estados aleatorios.

## Estructura

Ver `docs/architecture.md` para el detalle de la arquitectura MVVM y el
mapeo de componentes descrito en el documento de diseño (TT1).
