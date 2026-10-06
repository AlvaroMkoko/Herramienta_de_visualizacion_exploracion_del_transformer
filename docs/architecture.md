# Arquitectura del Sistema (MVVM)

## Curso modular progresivo

La ruta educativa principal ya no evalúa todo el Transformer como una sola
unidad. El flujo se repite dentro de ocho módulos:

```
Módulo → Pre-test → Recorrido guiado → Laboratorio → Post-test → Resultados
```

### Diagnóstico de la implementación anterior

- `EvaluationController` y `EvaluationManager` ya separaban presentación,
  estado y calificación, pero cargaban dos formas globales fijas de 20
  reactivos. Se reutilizaron mediante `ModuleEvaluationController`.
- `GuidedLearningScreen` contenía seis unidades y gran parte de su contenido
  dentro de QML. Su motor de teoría sigue disponible para ayuda contextual;
  el curso nuevo mueve estructura, objetivos y pasos a datos declarativos.
- Los laboratorios de entrenamiento, biblioteca, comparación e inferencia
  eran pantallas completas y no estaban acotados por concepto. Se conservan
  por compatibilidad y se añade un laboratorio modular que sólo publica las
  activaciones pertinentes al módulo actual.
- `ProgressController` persiste cinco etapas globales. Se conserva para la
  ruta anterior; `CourseController` gestiona en paralelo las cinco etapas de
  cada uno de los ocho módulos.
- `ResultsRepository` ya ofrecía escritura JSON atómica. Ahora admite filtrar
  resultados por `module_id`, sin cambiar el contrato de resultados legados.

### Componentes nuevos

**Modelo educativo y datos**

- `data/aprendizaje/modules.json`: ocho módulos, cada uno con ocho conceptos,
  ocho pasos guiados, configuración de laboratorio y ocho retos de aplicación.
- `model/aprendizaje/learning_module.py`: carga y validación del catálogo.
- `model/aprendizaje/module_question_bank.py`: genera dos formas paralelas de
  25 reactivos por módulo. Cada intento elige 15 (cinco por dificultad),
  prioriza preguntas no vistas y garantiza siete interacciones: opción
  múltiple, selección múltiple, verdadero/falso, ordenar, relacionar,
  respuesta corta y completar espacios. Los reactivos se etiquetan por
  dificultad y proceso cognitivo (`Recordar`, `Comprender`, `Aplicar` y
  `Analizar`).
- `model/aprendizaje/progress_repository.py`: persistencia atómica del módulo
  actual, etapas, intentos, preguntas usadas, tiempo, dificultades y modelo.

**ViewModels**

- `ModuleEvaluationController`: adapta el evaluador existente al banco y al
  ámbito del módulo; los resultados guardan reactivos, respuestas, categoría,
  dificultad, concepto y duración.
- `CourseController`: calcula bloqueos, estado (`not_started`, `in_progress`,
  `completed`, `review_recommended`), avance global y comparación pre/post.
- `ModuleLaboratoryController`: ejecuta un forward real y entrega sólo los
  datos relevantes (IDs, embeddings, Q/K/V, scores, mapas, residuales, FFN,
  máscaras, logits y probabilidades). Los tensores nunca cruzan a QML; sus
  valores completos se consultan por páginas.

**Vista reutilizable**

- `ModuleMapScreen`, `ModuleScreen`, `ModuleGuidedTourScreen`,
  `ModuleLaboratoryScreen` y `ModuleResultsScreen` cargan el módulo activo en
  lugar de duplicarse ocho veces.
- `EvaluationIntroScreen` y `EvaluationScreen` aceptan opcionalmente
  `moduleId`; sin él conservan exactamente el instrumento global anterior.

### Compatibilidad e incorporación incremental

La ruta global, sus controladores y las pantallas históricas no se eliminaron.
El botón principal de bienvenida abre el curso modular, mientras que las APIs
anteriores continúan disponibles para pruebas, perfiles docentes y accesos
existentes. Los resultados sin `module_id` permanecen separados de los del
curso al calcular progreso modular.

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

### `evaluacion/`
- `question_bank.py` — banco de reactivos (v2, formas A y B de 20 reactivos,
  cinco dimensiones).
- `evaluation_manager.py` — estado de una aplicación: navegación, respuestas
  y duración.
- `scorers.py` / `metrics.py` — calificación por tipo de reactivo y métricas
  totales, por dimensión y por nivel de Bloom.
- `results_repository.py` — historial JSON local con escritura atómica y
  archivado de versiones anteriores del instrumento.

## ViewModel (`viewmodel/`)

Única capa que conoce Qt y el Modelo a la vez.

- `main_viewmodel.py` — orquestador raíz, el **único** objeto registrado en el
  contexto QML (`mainViewModel`). Expone los demás controladores como
  propiedades. `setupController`, `datasetController` y `theoryController`
  existen desde el arranque; también crea `learningController` para conservar
  el avance educativo. `trainingController` e `inferenceController` aparecen
  recién cuando `SetupController` crea un modelo.
- `setup_controller.py` — único componente que **crea** el modelo. Calcula un
  resumen de parámetros en vivo sin instanciar nada ni consultar la red, y
  administra las configuraciones predefinidas y las guardadas por el usuario.
- `training_controller.py` — entrenamiento en segundo plano, guardado de
  checkpoints, configuración de la nube de embeddings e instrumentación del
  batch real (gradientes y valores antes/después de `optimizer.step()`).
- `inference_controller.py` — generación de texto token a token; los
  parámetros de muestreo pueden cambiarse entre tokens.
- `comparison_controller.py` — carga dos modelos en una sesión independiente
  y crea un `InferenceController` para cada uno.
- `profile_controller.py` / `progress_controller.py` — perfil (estudiante o
  docente), registro de alumnos, análisis pre/post y guardias de la ruta.
- `dataset_controller.py` — catálogo de datasets: análisis, metadatos,
  vista previa de registros.
- `model_library_controller.py` — biblioteca de modelos guardados.
- `theory_controller.py` — teoría contextual por componente (CU17).
- `learning_controller.py` — progreso persistente del recorrido guiado: unidades
  completadas y última posición visitada.
- `transformer_bridge.py` — información del modelo activo para el diagrama.
- `concurrency_manager.py` — `GestorConcurrencia`: ejecuta generadores en un
  `QThread` con soporte de pausa, cancelación y control de velocidad.
- `visual_adapter.py` — capa delgada sobre `tensor_to_array`: convierte
  `numpy` a listas de Python y agrega lo que el Modelo no conoce (el
  tokenizador, para decodificar etiquetas). También prepara el ejemplo
  pedagógico de entrenamiento: teacher forcing, máscara, atenciones, Top-K,
  loss y resúmenes de actualización, sin enviar tensores a QML.
- `evaluation_controller.py` — pre-test y post-test: navegación, calificación
  y guardado de resultados (RF22, RF24).
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

- `qml/screens/` — `ProfileSelectionScreen`, `WelcomeScreen`, `HomeScreen`,
  `GuidedLearningScreen`, `SetupScreen`, `DataSetScreen`, `LoadDataSetScreen`,
  `TrainingScreen`, `ResultsScreen`, `ModelLibraryScreen`, `ModelDetailScreen`,
  `InferenceScreen`, `ComparisonScreen`, `EvaluationIntroScreen`,
  `EvaluationScreen`, `StudentRegistrationScreen`, `TeacherDashboardScreen`,
  `StudentAnalysisScreen` (también usada como etapa de seguimiento).
- `qml/components/` — `TransformerDiagram`, `NubeEmbeddings3D`, `TrainingJourney`,
  `SliderColumn`,
  `GuidedConceptReader`, `GuidedLearningActivity`,
  `GuidedDemoVisualization`, `BotonPrincipal`, `RectanglePrincipal`,
  `PagePrincipal`, `FlujoPaso`.
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
