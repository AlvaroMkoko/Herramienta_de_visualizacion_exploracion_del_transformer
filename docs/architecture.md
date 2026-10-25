# Arquitectura del Sistema (MVVM)

## Panorama

App de escritorio educativa: **Python 3.12+ + PyTorch + PySide6 + QML**, patrón **MVVM estricto**.
Es el Trabajo Terminal de un equipo de tres personas que trabajan sobre el mismo `main`. Dos
consecuencias mandan sobre todo lo demás:

1. **La aplicación mide aprendizaje.** Varias decisiones de interfaz que parecen mejoras obvias
   invalidan la medición del pre-test y el post-test. Ver [medicion.md](medicion.md).
2. **`data/resultados/` y `data/progreso/` son datos, no caché.** Guardan los resultados de
   estudiantes reales y su avance; borrarlos o reescribirlos para «limpiar estado» destruye
   datos de la tesis. Ver *Rutas y datos*, abajo.

Otros documentos: [trampas.md](trampas.md) (trampas de PySide6 y QML que no producen error),
[red_aula.md](red_aula.md) y [uso_aula.md](uso_aula.md) (aula conectada), y el `README.md`
(flujo funcional, perfiles estudiante/profesor y contrato de datasets).

## Capas y regla de dependencias

```
view/  (QML)        ──usa──>  viewmodel/  (PySide6)  ──usa──>  model/  (PyTorch)
                                                      \
core/  (sin Qt)  <──────────── lo usan todas ──────────/
```

| Capa | Líneas | Regla dura |
|---|---|---|
| `core/` | ~370 | `rutas.py` y `constants.py` no importan Qt **ni torch**. `config.py` sí importa torch. |
| `model/` | ~8 800 | **Cero Qt.** Ningún archivo importa PySide6. Si agregas uno, lo rompes. |
| `viewmodel/` | ~17 000 | Única capa que conoce Qt y el Modelo a la vez. **Nunca importa de `view/`.** |
| `view/` | ~55 000 | Solo QML + `canvas/`. Todo el estado llega por `mainViewModel.*`. |
| `tests/` | ~14 800 | 48 archivos de prueba en `tests/`, `tests/model`, `tests/viewmodel` y `tests/view`. |

Las cifras de líneas son aproximadas y envejecen; las reglas, no.

## Rutas y datos

**`recurso()` vs `dato()`** (`core/rutas.py`). `recurso()` es solo-lectura y viaja dentro del
paquete PyInstaller; `dato()` es escribible y vive junto al ejecutable. Usar la equivocada no da
error: el trabajo del usuario simplemente desaparece al empaquetar.

**Toda ruta de escritura pasa por `core.rutas`**: `dato()` o una constante `DIR_*` de ese módulo,
nunca una ruta armada con `__file__` ni con `Path("data")`. De eso depende que las pruebas no
toquen los datos de quien las corre: `tests/conftest.py` redirige `DIR_DATOS` y los `DIR_*` a un
temporal antes de que se importe el proyecto, y al arrancar **detiene la suite** si algún `DIR_*`
sigue apuntando a `data/`. Si agregas una carpeta de escritura, declárala como `DIR_*` en
`core/rutas.py` y agrégala a la redirección del conftest; la guarda avisa si se olvida. Una ruta
de escritura que no pase por `core.rutas` no la detecta nada: la suite volvería a escribir en
`data/` real sin avisar.

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

### Alineación teoría–práctica–evaluación

`data/aprendizaje/alineacion.json` complementa `modules.json` y
`LearningModuleCatalog` lo fusiona al cargar, así que recorrido, laboratorio y
evaluación leen la misma fuente. Por módulo declara:

| Clave | Dónde se usa | Para qué |
|---|---|---|
| `anchor` | `ModuleScreen`, recorrido, laboratorio | Pregunta problema, ejemplo numérico pequeño que se sigue en recorrido y laboratorio, y pregunta de cierre (`closing`). |
| `step_checks` | `ModuleGuidedTourScreen` (`guided_steps[].check`) | Predicción por paso. CAMBIO y RESULTADO se revelan al intentarla; «Siguiente» se habilita sólo entonces. |
| `post_variants` | `ModuleQuestionBank` (`challenges[].post_variant`) | Forma post isomorfa de cada reto: mismo constructo y dificultad, otros números, sin nombrar la operación. |
| `transfer_items` | `ModuleQuestionBank` (A6 y A7) | Situación nueva con el mismo mecanismo; no comparte caso con otro reactivo del intento. |
| `lab_challenges` | `ModuleLaboratoryScreen`, repaso espaciado | Retos propios del laboratorio. El de índice *i* trata el mismo concepto que `challenges[i]` (lo valida el catálogo) para que el mapa paso→reto del laboratorio siga valiendo. |

Reglas que dependen de esta alineación (todas en `CourseController`):

- **Recorrido completo** = las 8 predicciones intentadas (`recordGuidedCheck`).
  Navegar o mirar no basta: `completeGuidedTour` devuelve `False` mientras falte alguna.
- **Laboratorio completo** = `REQUIRED_LAB_CYCLES` (3) ciclos predecir→probar→
  observar→explicar en pasos distintos (`recordDiscoveryCycle`) más la
  pregunta de cierre (`recordAnchorClosing`). Un forward sólo se registra
  (`recordLaboratoryAnalysis`).
- **Pre-test**: sin retroalimentación de claves. Sus conceptos fallados sólo
  marcan pasos «★» en el recorrido (`guidedProgress().focus_step_ids`).
- **Post-test**: `moduleResults().review` da clave, explicación y paso del
  recorrido por reactivo. **Nunca se construye para el pre-test.**
- **Resultados**: ganancia normalizada de Hake (total y por concepto),
  recomendaciones con paso del recorrido y reto de laboratorio, y la
  interacción registrada (`interaction`) para cruzarla con la ganancia.
- **Repaso espaciado**: al abrir el módulo *n* se repasan 3 retos de
  laboratorio del módulo *n − 1* (no reactivos del test). Cuenta el primer
  intento (`retention`).

`INSTRUMENT_VERSION` del banco modular pasó a **8**: los resultados de la
versión 7 no son comparables con los nuevos y `_build_results` ya los separa
por versión. Un catálogo sin `alineacion.json` junto a él conserva el
comportamiento anterior (lo usan algunas pruebas).

El panel del aula (`model/aula/analisis.py`) añade `item_analysis`: por par
de reactivos paralelos (mismo `code` en pre y post), la proporción de acierto
*p*, el índice de discriminación *D* (27 % superior − 27 % inferior, con 4 o más
alumnos) y Δp. Marca para revisión los reactivos con techo en el pre
(p ≥ 0.9), D < 0.2 o sin ganancia.

### Compatibilidad e incorporación incremental

La ruta global, sus controladores y las pantallas históricas no se eliminaron.
El botón principal de bienvenida abre el curso modular, mientras que las APIs
anteriores continúan disponibles para pruebas, perfiles docentes y accesos
existentes. Los resultados sin `module_id` permanecen separados de los del
curso al calcular progreso modular.

Este documento mapea el diseño arquitectónico (TT1, sección 4.9) contra la
estructura real del código. Cuando un componente está diseñado pero todavía
no implementado, se marca como **pendiente**.

## Aula conectada

El docente comparte un código de clase y los alumnos se unen con un apodo; la
app del docente actúa como servidor en la red local (o en su hotspot), con
archivos `.tvclase` como respaldo sin red.

- `model/aula/` — protocolo, reglas de la clase (`SesionClase`), persistencia
  del docente y del alumno, archivos firmados y análisis del grupo. Sin Qt.
- `viewmodel/aula/` — transporte (`QWebSocketServer`/`QWebSocket` y
  descubrimiento por `QUdpSocket`) y los controladores
  `classroomHostController` y `classroomStudentController`.
- Vista: `ClassroomSetupScreen`, `ClassroomScreen` (docente) y
  `JoinClassScreen` (alumno); indicador de estado y avisos en `main.qml`.
- `CourseController` expone `progress_snapshot()` y respeta los módulos que el
  docente habilita (`set_class_modules`), incluso en modo revisión.
- `ResultsRepository` asigna `result_id` a cada resultado para sincronizarlo
  sin duplicados.

Funcionamiento de la red: [red_aula.md](red_aula.md). Guía de uso:
[uso_aula.md](uso_aula.md).

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

- `main_viewmodel.py` — orquestador raíz, registrado en el contexto QML como
  `mainViewModel`. Expone los demás controladores como propiedades. No es el
  único objeto del contexto: `main.py` registra también `displayManager`
  (el docstring de `main.py` todavía dice que es el único). `setupController`, `datasetController` y `theoryController`
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

Romper cualquiera **no produce error**: solo una propiedad `undefined` o un
botón muerto.

1. **`@Slot` es obligatorio** para que QML pueda invocar un método. Un método
   público sin decorador **no** es visible desde QML.
2. **`@Slot()` vacío declara cero argumentos.** Un método con parámetros
   necesita los tipos: `@Slot(float)`, `@Slot(int, float, int)`.
3. **`@property` de Python no es visible desde QML.** Para exponer estado
   reactivo hace falta `@Property(tipo, notify=señal)`.
4. **Los tensores nunca cruzan a QML.** Todo pasa por `visual_adapter`, una
   capa delgada sobre `model/simulacion_numerica/tensor_to_array.py`.
5. **`Dataset` de PyTorch no se puede pasar desde QML.** De ahí el par
   `establecer_dataset()` (Python) / `iniciar_entrenamiento_ui()` (QML).
   Patrón general: **los Slots que QML invoca llevan sufijo `_ui`**, y su
   gemelo sin sufijo es la API Python que recibe objetos no convertibles.

### Separación de señales

Una señal que se emite en cada tecla no puede cargar propiedades costosas:
provoca un ciclo de enlaces en QML. `viewmodel/evaluation_controller.py:88-95`
es el ejemplo canónico: `stateChanged` (cada interacción, 2 propiedades) frente
a `questionChanged` (cambio de reactivo, 34 propiedades). Nombre: sufijo
**`Cambio`** del lado español, **`Changed`** del inglés.

### Concurrencia: tres mecanismos distintos, no uno

- `GestorConcurrencia` (`viewmodel/concurrency_manager.py`) para tareas largas
  observables: la tarea es un generador (ver *Flujo de datos*) y el gestor
  revisa también la velocidad entre pasos. Solo lo usan `training` e
  `inference`.
- `threading.Thread` daemon con nombre para I/O de un solo tiro, con
  `Lock`/`RLock` y **señales privadas con prefijo `_`** para devolver el
  resultado al hilo de la UI.
- Sin hilos, event loop puro, en `viewmodel/aula/`: los sockets de QtNetwork
  son asíncronos. Lo periódico va con `QTimer`.

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

Además:

- **`pragma ComponentBehavior: Bound` como primera línea** en todo archivo nuevo
  (está en 72 de 119). Obliga a `required property var modelData` /
  `required property int index` en los delegates, y a cualificar el acceso con
  el `id` del delegate (`opcion.modelData.id`, nunca `modelData.id` suelto).
- **Escalado `sx`/`sy`**: nacen una sola vez en
  `view/qml/components/PagePrincipal.qml:21-26` como `width / 1280` y
  `height / 820`. Toda medida literal se multiplica: `48 * root.sy`,
  `font.pixelSize: 22 * root.sx`. Cada componente reutilizable redeclara
  `property real sx: 1` con valor neutro y el padre lo pasa explícito. Los
  componentes *inline* no heredan el `sx` del archivo que los contiene: hay que
  redeclararlo.
- **Tema**: `view/qml/styles/Theme.qml` es un singleton. Se importa por carpeta
  con prefijo obligatorio — `import "../styles" as Style` → `Style.Theme.fondo`.
  Una sola propiedad mutable (`modoOscuro`) y todo lo demás derivado. **Nunca
  escribas un color literal**; usa el token semántico. Igual con las
  duraciones: `Style.Theme.duracionCorta/Media/Entrada`, no `110`.
- **`objectName`** siempre en inglés camelCase, con prefijo de pantalla y
  sufijo de rol (`evaluationNextButton`, `moduleLaboratoryWorkspace`). Es la API
  que consumen las pruebas, y en algunos casos la producción: `TrainingScreen`
  y `ResultsScreen` buscan pantallas en la pila comparando `objectName`.
  Cambiar uno rompe pruebas y navegación en silencio.
- **Movimiento reducido es contrato, no un extra.** Toda animación decorativa
  respeta `Style.Theme.movimientoReducido` (en las escenas llega como
  `reducedMotion`). Tres efectos: duración 0, salto al estado final, y driver
  que no arranca.
- **Animación como función del progreso.** Una sola `NumberAnimation` escribe
  una propiedad escalar (`t`, `progress`, `stageReveal`) y **todo el dibujo es
  función pura de ella**. Así la animación se puede pausar y recorrer con un
  deslizador sin que los números y los gráficos se desincronicen. Referencia:
  `FormulaAnimationScene.qml:8-11, 74-88`.
- **Guarda para pruebas**:
  `typeof mainViewModel !== "undefined" && mainViewModel ? ... : null`, para que
  el componente cargue sin contexto.

**La esquina superior derecha es del cromo global.** `main.qml` dibuja ahí,
por encima de cualquier pantalla (`z: 100`), el botón de preferencias
(`PreferencesMenu`), que abre un panel con los controles que valen para toda la
aplicación: el interruptor de tema (`ThemeSwitch`) y el de movimiento reducido
(`MotionSwitch`). Toda pantalla nueva debe dejar libre esa franja. Hoy ocupa
46 px de ancho medidos desde el borde derecho (12 de margen + 34) y 46 px de
alto (12 de margen + 34), en píxeles fijos que no escalan con `sx`/`sy`; el
panel abierto flota debajo, sobre el contenido, y se cierra con Escape. La
franja crece a la izquierda cuando aparecen los indicadores condicionales
anclados a la misma fila: la vista dual suma 158 px (150 + 8) y el chip del
aula, su ancho variable más 8. Si una pantalla necesita contenido cerca de esa
esquina, la reserva de forma explícita, como la cabecera del laboratorio
(`ModuleLaboratoryScreen.qml`, `Layout.rightMargin: 208 * root.uiScale`, con la
suma escrita en un comentario), y la ajusta cuando el cromo cambie. Una
preferencia global nueva va dentro del panel, no como otro control en la
esquina.

### Revisar QML sin ejecutar la app

Un error de compilación en QML no rompe una línea: deja de cargar el archivo
completo, y la app arranca con una pantalla en blanco. `qmllint` lo detecta sin
ejecutar nada:

```powershell
pyside6-qmllint -I view\qml view\qml\screens\EvaluationScreen.qml
```

**La caché de QML sirve archivos viejos.** Qt compila cada `.qml` a `.qmlc`
fuera del proyecto y la invalida por fecha; copiar archivos conservando su
fecha la deja obsoleta. Durante el desarrollo:

```powershell
$env:QML_DISABLE_DISK_CACHE = 1
python main.py
```

## Core (`core/`)
Utilidades transversales: `rutas.py` (ver *Rutas y datos*), `config.py`
(reexporta las rutas de `rutas.py`, semilla, detección CPU/CUDA; **importa
torch**), `constants.py` (rangos que
**deben** coincidir con los de la Vista). Solo `rutas.py` y `constants.py`
están libres de Qt y de torch. `logger.py` está vacío (ver *Archivos vacíos o
sin uso*).

## Scripts de línea de comandos
- `main.py` — punto de entrada de la aplicación.
- `entrenar.py` — entrenamiento sin interfaz, con todos los formatos de dataset.
- `generar.py` — generación de texto desde un checkpoint.

## Herramientas de datos (`tools/`)
Scripts que **generan artefactos del repositorio**; la aplicación no los importa ni
los ejecuta. Su salida se versiona y el modelo se entrena con ella, así que cada
script declara la procedencia de sus datos en el encabezado y su salida tiene
prueba de invariantes.

- `filtrar_tatoeba.py` — genera `traduccion_es_en_basica.jsonl` y
  `traduccion_en_es_basica.jsonl` en `data/datasets_predefinidos/` desde el
  volcado de Tatoeba en OPUS (versión, licencia CC BY 2.0 FR y cita en el
  encabezado). El volcado en bruto **no entra al repositorio**. La semilla es fija:
  el mismo volcado da archivos idénticos al byte. `traduccion_demo.jsonl` está
  escrito a mano y este script no lo toca.
- `palabras_vetadas_corpus.txt` — la lista negra de ese script, un patrón por
  línea y comentada por categorías. **No es un duplicado de
  `data/aula/palabras_bloqueadas.json`**: compara distinto, veta cosas distintas
  y no la edita el docente. El porqué completo está en el encabezado del script.
- Los invariantes de la salida (de 3 a 16 tokens por lado con `cl100k_base`, frases
  únicas en cada lado, EN→ES igual a ES→EN invertido, «Tom» entre el 2 % y el 3 %)
  están en `tests/model/test_datasets_traduccion.py`. Si regeneras, córrela.

Uso, desde la raíz: `python tools/filtrar_tatoeba.py <.en> <.es> data/datasets_predefinidos`.
Es la excepción a *Toda ruta de escritura pasa por `core.rutas`*: escribe solo
en el directorio que recibe por argumento, a mano, nunca desde la aplicación ni
desde las pruebas. Regenerar cambia la muestra: hay que volver a leerla.

## Empaquetado (ejecutable del laboratorio)

Un solo comando, desde la raíz y con red:
`powershell -ExecutionPolicy Bypass -File tools\construir_ejecutable.ps1`. Deja
`dist\TransformerVisualizer\`, que se distribuye **comprimido, sin instalador**
(modo portable de `core/rutas.py`: los resultados se recogen copiando `datos\`).
Las razones de `onedir`, CPU y portable están en ESPEC-F; aquí van las piezas y
lo que rompe sin dar error al construir.

- `transformer_visualizer.spec` — el análisis de PyInstaller. Copia además
  `scripts\permitir_firewall_aula.ps1` junto al ejecutable (bajo `_internal\` el
  docente no lo encontraría con la ruta de `docs/uso_aula.md`) y el modelo del
  piloto a `datos\checkpoints\`, con su nombre y su estado de optimizador
  intactos.
- `requirements-empaquetado.txt` — el entorno `.venv-empaquetado\`, aparte del
  de desarrollo: `torch` de CPU y sin `datasets`, `torchvision`, `torchaudio`
  ni las herramientas de prueba.
- `tools/sembrar_cache_tiktoken.py` — descarga las tres codificaciones de
  `ENCODINGS` a `build\cache_tiktoken\`; `main.py` apunta `TIKTOKEN_CACHE_DIR` a
  esa copia cuando corre empaquetada. A diferencia del resto de `tools/`, su
  salida no se versiona.

Trampas que el ejecutable solo muestra al correr:

- **Sin la caché, sin red no hay tokenizador**: ni inferencia ni activar un
  modelo. Con el archivo presente y su hash correcto tiktoken solo lee, así que
  la caché puede quedarse dentro del paquete, en solo lectura.
- **`tiktoken_ext.openai_public` es import oculto.** tiktoken halla sus
  codificaciones recorriendo un paquete de espacio de nombres que PyInstaller no
  sigue: sin la línea, «Unknown encoding» aunque la caché esté.
- **`tiktoken==0.13.0` fijo.** El nombre de cada archivo de caché es un detalle
  interno (SHA-1 de la URL); se verificó con esa versión y pip traería otra.
- **Ruta de descompresión corta.** Windows no carga una DLL cuya ruta pase de
  260 caracteres; el plugin de QtQuick.Controls más hondo mide 90 desde
  `TransformerVisualizer\`. La carpeta donde se descomprime debe medir unos 140
  caracteres o menos; si no, `main.qml` no carga («nombre de archivo demasiado
  largo»).
- **`data/aula/clases/` no viaja**: es estado de ejecución y trae el secreto de
  la clase. De `data/aula/` solo es recurso `palabras_bloqueadas.json`.

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

## Convenciones de código

### Idioma de los identificadores

Regla base: **español**. `obtener_*`, `establecer_*`, `AtencionMultiCabeza`,
`SesionClase`. Los nombres de archivo son mayoritariamente ingleses incluso en
paquetes españoles (`dataset_loader.py`, `model_storage.py`), así que **el
nombre del archivo no predice el idioma de su contenido**.

La excepción en inglés no está dispersa: es el subsistema del curso modular,
añadido después.

| Español | Inglés |
|---|---|
| `core/`, `model/motor_llm`, `model/aula`, `model/gestor_de_datos`, `model/persistencia`, `model/simulacion_numerica` | `model/aprendizaje`, `model/evaluacion` |
| `viewmodel/`: `setup`, `training`, `inference`, `comparison`, `dataset`, `model_library`, `theory`, `progress`, `visual_adapter`, `concurrency_manager`, `aula/` | `viewmodel/`: `course`, `evaluation`, `module_*`, `learning`, `display`, `transformer_bridge`, `formula_demos` |

**Dos inversiones dentro de la excepción**, que son las que confunden:

- `model/evaluacion/scorers.py` es un archivo inglés en paquete inglés con
  **API pública en español**: `calificar()`, `es_respuesta_completa()`,
  `normalizar_texto()`, `TIPOS_SOPORTADOS`.
- Las **claves de datos de los reactivos son españolas** (`tipo`,
  `presentacion`, `subtipo`, `destinos`, `elementos`, `respuestas_aceptadas`,
  `puntaje_maximo`) y conviven con claves inglesas (`bloom_level`,
  `concept_id`, `difficulty`, `pedagogical_type`, `explanation`).

En QML: español para el dominio propio (`pregunta`, `respuestaCambiada`,
`restaurar()`, `texto_primario`), inglés para lo que toca Qt o el dominio
Transformer (`active`, `progress`, `reducedMotion`, `moduleId`,
`attentionData`), y `objectName` siempre en inglés camelCase (ver
*Convenciones obligatorias de la Vista*). Los comentarios son íntegramente en
español.

Regla práctica: **imita el archivo que estás editando.** No mezcles idiomas
dentro de un archivo. Esto aplica a los **identificadores de producción**. En
`tests/` la mezcla es la convención correcta: la maquinaria de pytest y Qt va
en inglés (`qapp`, `controller`, `window`, `loader`, `SCREEN_HOST`) y los
términos del dominio en español (`test_cada_paso_…`, `_errores`,
`TokenizerDePrueba`), como en los archivos vecinos. Imita al vecino, no
traduzcas.

### Comentar el por qué, no el qué

Se documenta en el código la razón de una decisión no obvia, sobre todo si
evita un fallo silencioso o protege la validez de la medición. Los comentarios
que explican las entradas de [trampas.md](trampas.md) son el ejemplo a imitar.
En español.

## Pruebas

La suite está toda en verde y sin pruebas intermitentes conocidas. No se
anota aquí cuántas son: crece con casi cada cambio y la cifra quedaría vieja.

- **`python -m pytest`, siempre desde la raíz del repositorio.** No hay
  `pythonpath` configurado; la forma con `-m` pone la raíz del proyecto en
  `sys.path` por sí misma.
- `tests/conftest.py` fija las variables de Qt (`QT_QPA_PLATFORM=offscreen`,
  `QSG_RHI_BACKEND=software`, `QT_QUICK_CONTROLS_STYLE=Basic`) con
  `setdefault` antes de cualquier importación. Sin ellas, construir el `qapp`
  **sin pantalla** (CI, SSH, una sesión sin escritorio) aborta el intérprete
  con `Fatal Python error: Aborted`: no falla, se cae. En Windows con sesión
  gráfica no se reproduce. Fijarlas desde fuera es idempotente y seguro.
- El conftest también aísla los datos: ver *Rutas y datos*.

```powershell
python -m pytest -q                       # suite completa — ~50 s
python -m pytest -q tests/model           # bucle rápido — ~5 s, sin Qt
python -m pytest -q --ignore=tests/view   # todo sin QML — ~25 s
python -m pytest -q tests/view            # solo QML — ~27 s
python -m pytest -q tests/viewmodel/test_module_course.py   # un archivo
```

**`PySide6-Addons` es dependencia obligatoria y no está declarada en
`requirements.txt`.** `viewmodel/aula/servidor_lan.py` necesita
`QtWebSockets`. Sin ese paquete, las pruebas del aula (un centenar) no se
recolectan y la suite sale verde con menos pruebas, sin decir que falta algo.
Compruébalo directamente en vez de fiarte del conteo:
`python -c "import PySide6.QtWebSockets"` tiene que terminar sin error.

```powershell
pip install PySide6-Addons
```

La suite **no** necesita GPU, red ni el paquete `datasets`, aunque
`requirements.txt` lo pida: el tokenizador se sustituye por un doble para no
descargar el BPE, y el dispositivo se fuerza a CPU donde importa.

**Fragilidad latente**: `tests/viewmodel/test_classroom_network.py` abre
sockets UDP y WebSocket reales en `127.0.0.1`, y su fixture `puerto_udp` elige
un puerto al azar **sin comprobar que esté libre**. Es el único candidato
plausible a prueba intermitente. Si falla una vez y pasa a la siguiente, es
eso.

## Archivos vacíos o sin uso

Parecen implementados por su nombre y no lo están:

- `core/logger.py` (6 líneas, solo un TODO) y
  `model/gestor_de_datos/tensor_prep.py` (7 líneas, solo un TODO).
- `view/canvas/attention_canvas.py` y `view/canvas/vector_canvas.py` (solo
  docstring).
- `view/qml/components/ParameterSlider.qml` (9 líneas, solo un TODO).
- `viewmodel/signal_manager.py`: 164 líneas de código real, **ningún
  importador** y 0 % de cobertura; su prueba
  `tests/viewmodel/test_signal_manager.py` es un stub vacío con 0 pruebas.
- El `.coverage` de la raíz es un artefacto obsoleto de una corrida en Windows
  con 3 archivos.

## Control de versiones: `.gitignore`

Ignora `docs` y `*.json` **en bloque**, con excepciones puntuales
(`!data/evaluacion/question_bank.json`, `!data/aprendizaje/modules.json`, …).
Consecuencia: **un `.json` de datos nuevo, o un documento nuevo en `docs/`, no
se versiona y no aparece en `git status`.** Hay que agregarle su excepción o
añadirlo con `git add -f`. Los documentos que ya estaban en `docs/` sí están
versionados a pesar de la regla; uno nuevo no lo estará por sí solo.
