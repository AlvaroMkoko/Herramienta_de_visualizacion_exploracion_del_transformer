# Arquitectura del Sistema (MVVM)

Este documento mapea el diseño arquitectónico (TT1, sección 4.9) contra la
estructura real del código. Cuando un componente está diseñado pero todavía
no implementado, se marca como **pendiente**.

## Model (`model/`)

Capa sin ninguna dependencia de Qt/QML: se puede importar y probar sin
levantar la interfaz.

### `motor_llm/`
Motor Transformer encoder-decoder, fiel al diagrama de *Attention Is All You Need*.

- `config.py` — `ConfiguracionTransformer` (dataclass). Valida divisibilidad
  `dimension_modelo % num_cabezas`, activación (`relu`/`gelu`/`swish`) y
  `usar_mascara_causal`.
- `transformer.py` — ensamblaje completo, `forward`, `calcular_perdida`,
  `crear_mascaras` y `generar()` (generador autoregresivo que emite un dict
  por token con pesos de atención por capa).
- `atencion.py` — `atencion_escalada` y `AtencionMultiCabeza` (auto-atención
  y atención cruzada). Cada cabeza ocupa un bloque **contiguo** de dimensiones.
- `encoder.py` / `decoder.py` — bloques y pilas de N capas.
- `feed_forward.py` — activación seleccionable vía `config.activacion`.
- `conexion_residual.py` — Add & Norm (post-norm).
- `mascara.py` — máscaras causal y de relleno. Convención: `True` = permitido.
- `embedding.py`, `positional_encoding.py` — embeddings y codificación sinusoidal.
- `muestreo.py` — temperatura, top-k, top-p, muestreo codicioso.
- `tokenizer.py` — envoltorio de `tiktoken`.

### `gestor_de_datos/`
- `dataset_loader.py` — carga de `.csv`, `.json`, `.jsonl`, `.txt` y `.pdf`;
  `DatasetSecuencias`, colación con relleno y `crear_dataloader`.
  Reserva **3 ids extra** más allá del vocabulario del tokenizador
  (relleno = `vocab_size`, inicio = `+1`, fin = `+2`); usar siempre las
  funciones `obtener_id_token_*`, nunca ids fijos escritos a mano.

### `simulacion_numerica/`
- `tensor_to_array.py` — cómputo numérico puro sobre tensores, devuelve
  `numpy`/`float`. Mapas de atención, entropía de Shannon, top-n de
  probabilidades, proyección sobre dimensiones elegidas, PCA con
  estabilización de signo y agrupación de dimensiones por cabeza.

### `persistencia/`
- `model_storage.py` — guardado/carga de checkpoints, generación automática
  de nombres a partir de la arquitectura y saneamiento de nombres escritos
  por el usuario.

### `evaluacion/` — **pendiente**
`question_bank.py`, `evaluation_manager.py`, `results_repository.py` y
`metrics.py` existen como esqueletos con `TODO` (RF22–RF25).

## ViewModel (`viewmodel/`)

Única capa que conoce Qt y el Modelo a la vez.

- `main_viewmodel.py` — orquestador raíz, el **único** objeto registrado en el
  contexto QML (`mainViewModel`). Expone los demás controladores como
  propiedades. `setupController`, `datasetController` y `theoryController`
  existen desde el arranque; `trainingController` e `inferenceController`
  aparecen recién cuando `SetupController` crea un modelo.
- `setup_controller.py` — único componente que **crea** el modelo. Calcula un
  resumen de parámetros en vivo sin instanciar nada ni consultar la red.
- `training_controller.py` — entrenamiento en segundo plano, guardado de
  checkpoints y configuración de la nube de embeddings.
- `inference_controller.py` — generación de texto token a token.
- `dataset_controller.py` — catálogo de datasets: análisis, metadatos,
  vista previa de registros.
- `model_library_controller.py` — biblioteca de modelos guardados.
- `theory_controller.py` — teoría contextual por componente (CU17).
- `transformer_bridge.py` — información del modelo activo para el diagrama.
- `concurrency_manager.py` — `GestorConcurrencia`: ejecuta generadores en un
  `QThread` con soporte de pausa, cancelación y control de velocidad.
- `visual_adapter.py` — capa delgada sobre `tensor_to_array`: convierte
  `numpy` a listas de Python y agrega lo que el Modelo no conoce (el
  tokenizador, para decodificar etiquetas).
- `evaluation_controller.py` — **pendiente** (RF22–RF25).
- `signal_manager.py` — **sin uso**. Las pantallas hablan directo con los
  controladores; se conserva solo por referencia histórica.

### Convenciones obligatorias del ViewModel

1. **`@Slot` es obligatorio** para que QML pueda invocar un método. Un método
   público sin decorador **no** es visible desde QML.
2. **`@Slot()` vacío declara cero argumentos.** Un método con parámetros
   necesita los tipos: `@Slot(float)`, `@Slot(int, float, int)`.
3. **`@property` de Python no es visible desde QML.** Para exponer estado
   reactivo hace falta `@Property(tipo, notify=señal)`.
4. **Los tensores nunca cruzan a QML.** Todo pasa por `visual_adapter`.
5. **`Dataset` de PyTorch no se puede pasar desde QML.** De ahí el par
   `establecer_dataset()` (Python) / `iniciar_entrenamiento_ui()` (QML).

## View (`view/`)

- `qml/screens/` — `HomeScreen`, `SetupScreen`, `DataSetScreen`,
  `TrainingScreen`, `ResultsScreen`, `InferenceScreen`, `ComparisonScreen`,
  `EvaluationScreen`.
- `qml/components/` — `TransformerDiagram`, `NubeEmbeddings3D`, `SliderColumn`,
  `BotonPrincipal`, `RectanglePrincipal`, `PagePrincipal`, `FlujoPaso`.
- `qml/styles/` — tema y escalado (`sx`/`sy`).
- `canvas/animation_engine.py` — `VispyItem`. **Advertencia:** usa OpenGL en
  modo inmediato (`glBegin`/`glVertex2f`), que no existe en Core Profile ni
  funciona en macOS. La nube 3D de embeddings no lo usa: se dibuja con
  `Canvas` de QML.

### Convenciones obligatorias de la Vista

1. **Un `Connections` = un `target`.** Declarar `target` dos veces en el mismo
   bloque es un error de compilación (`Property value set multiple times`) y
   **el archivo entero deja de cargar**.
2. **`Connections` en vez de `.connect()` dentro de `Component.onCompleted`.**
   Los closures sobreviven a la destrucción de la pantalla y arrojan
   `ReferenceError` al volver a entrar.
3. **Todo se accede vía `mainViewModel.*`** — no hay controladores sueltos en
   el contexto QML.

## Core (`core/`)
Utilidades transversales: `config.py` (rutas, semilla, detección CPU/CUDA),
`constants.py` (rangos que **deben** coincidir con los de la Vista),
`logger.py`.

## Scripts de línea de comandos
- `main.py` — punto de entrada de la aplicación.
- `entrenar.py` — entrenamiento sin interfaz, con todos los formatos de dataset.
- `generar.py` — generación de texto desde un checkpoint.

## Flujo de datos

```
Vista (QML)
│ llamada a @Slot
▼
ViewModel ── GestorConcurrencia ──> QThread
│ │
│ ▼
│ Modelo (PyTorch)
│ │ tensores
│ ▼
│ visual_adapter ── tensor_to_array
│ │ listas/dicts
◄───────── señal Qt ────────────────┘
▼
Vista (re-render)
```

Las tareas de fondo son **generadores**: cada `yield` es un paso observable.
`GestorConcurrencia` revisa cancelación y pausa entre pasos, así que las
tareas no necesitan implementar esa lógica.