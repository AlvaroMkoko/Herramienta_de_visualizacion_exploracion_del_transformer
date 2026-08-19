# Transformer Visualizer

Herramienta de escritorio para explorar, entrenar e interpretar modelos tipo
Transformer, construida bajo el patrón **MVVM**:

- **Model** (`model/`): PyTorch — motor LLM, datos, persistencia, cálculo numérico.
- **ViewModel** (`viewmodel/`): PySide6 — orquestación, señales, concurrencia.
- **View** (`view/`): QML — interfaz gráfica y visualizaciones.

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

## Flujo de trabajo

La pantalla de inicio presenta la evolución prevista de la plataforma educativa:

1. **Pre-test** — diagnóstico inicial; por ahora se muestra como módulo futuro.
2. **Recorrido guiado** — disponible. Organiza 15 conceptos esenciales en cinco
   unidades y combina lectura con el ciclo *predecir → observar → explicar*.
3. **Laboratorios** — entrenamiento, apertura de modelos y comparación siguen
   disponibles como accesos directos para experimentar libremente.
4. **Post-test** — evaluación final; por ahora se muestra como módulo futuro.
5. **Progreso y resultados** — seguimiento integral; por ahora se muestra como
   módulo futuro.

Durante el desarrollo, las cinco etapas pueden abrirse sin requisitos de
progreso. Los módulos futuros llevan a una vista placeholder navegable para
probar el flujo, sin simular que su funcionalidad definitiva ya existe.

El recorrido guiado guarda localmente las unidades completadas y la última
posición visitada. No requiere un dataset ni un modelo entrenado para comenzar.

El flujo de los laboratorios es:

1. **Configuración** — se define la arquitectura (capas, cabezas, dimensión del
   modelo, feed-forward, dropout, activación, máscara causal) con una
   estimación de parámetros y memoria que se actualiza en vivo.
2. **Catálogo de datasets** — se agregan archivos `.jsonl`, `.json`, `.csv`,
   `.txt` o `.pdf`. La herramienta analiza registros, tokens, vocabulario y
   categorías. Se pueden seleccionar varios y se combinan en un solo corpus.
3. **Entrenamiento** — métricas en vivo, controles de pausa/reanudación y de
   velocidad, y dos pestañas: el diagrama del Transformer y la nube 3D de
   embeddings.
4. **Resultados** — resumen del entrenamiento, curva de pérdida y opciones de
   guardado.
5. **Inferencia** — generación token a token con temperatura, top-k, top-p,
   muestreo codicioso y control de velocidad.

## Configuración de la arquitectura

- **Activación del Feed-Forward**: `relu` (por defecto, la del paper original),
  `gelu` (GPT-2/BERT) o `swish`.
- **Máscara causal**: se puede desactivar como experimento. Sin ella el decoder
  ve tokens futuros durante el entrenamiento; la pérdida baja mucho más rápido
  de lo normal porque el modelo *copia* la respuesta en vez de predecirla, y el
  fallo real solo se nota al generar texto. Los checkpoints guardados así se
  marcan con `_nomask` en el nombre.
- El **tamaño de vocabulario no se configura a mano**: se deriva del
  tokenizador elegido, más 3 ids reservados (relleno, inicio, fin).

## Visualización de embeddings 3D

Durante el entrenamiento, la pestaña *Embeddings 3D* muestra la nube de
embeddings de los tokens del batch actual, proyectada a tres dimensiones. Se
puede rotar arrastrando y hacer zoom con la rueda.

Dos modos de proyección:

- **PCA** — las tres direcciones de máxima varianza. Conserva mucha más
  información (en pruebas, 5× más que tres dimensiones elegidas al azar), pero
  los ejes son combinaciones de todas las dimensiones.
- **Dimensiones elegidas** — proyección ortogonal sobre 1–3 dimensiones
  concretas ("sombras"). Los ejes conservan su identidad; se pueden agrupar por
  cabeza de atención, ya que cada cabeza ocupa un bloque contiguo de dimensiones.

La vista informa qué **fracción de la varianza** conserva. Es importante para
leerla bien: la proyección es contractiva, así que dos tokens separados en
pantalla están realmente separados, pero dos que se ven juntos pueden estar
lejos en las dimensiones no mostradas.

El cálculo corre en el hilo de entrenamiento cada N pasos (10 por defecto) y
solo mientras la pestaña está visible.

## Guardar, abrir y compartir modelos

- En la pantalla de resultados se puede guardar un **modelo portable** o un
  **checkpoint reanudable**. Ambos usan la extensión `.tvismodel` y se
  almacenan en `data/checkpoints/`. El nombre se sugiere automáticamente a
  partir de la arquitectura, la activación, el dispositivo y la fecha, y puede
  reemplazarse por uno propio.
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

## Uso desde línea de comandos

Entrenar sin abrir la interfaz:

```bash
python entrenar.py --datos data/datasets/mis_datos.jsonl \
    --clave-origen instruction --clave-destino response --clave-contexto context \
    --epocas 20 --dimension-modelo 128 --num-capas 4
```

Generar texto desde un checkpoint:

```bash
python generar.py --checkpoint data/checkpoints/modelo.pt --prompt "hola"
python generar.py --checkpoint data/checkpoints/modelo.pt   # modo interactivo
```

Ambos aceptan `--help` con el listado completo de opciones.

## Estado de las áreas funcionales

| Área | Estado |
|---|---|
| Configuración de arquitectura | Implementada |
| Catálogo de datasets | Implementada |
| Entrenamiento y métricas | Implementada |
| Persistencia y biblioteca de modelos | Implementada |
| Inferencia | Implementada |
| Teoría contextual (CU17) | Implementada |
| Recorrido guiado y progreso local | Implementada |
| Visualización de embeddings 3D | Implementada |
| Comparación de modelos (CU07) | Implementada |
| Evaluación de utilidad (RF22–RF25) | Pendiente |

## Estructura

Ver `docs/architecture.md` para el detalle de la arquitectura MVVM, el mapeo de
componentes y las convenciones obligatorias de cada capa.
