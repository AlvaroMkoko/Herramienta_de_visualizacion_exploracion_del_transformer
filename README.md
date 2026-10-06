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

La pantalla inicial permite elegir un perfil:

- **Estudiante** puede abrir la ruta formativa o entrar directamente al centro
  de laboratorios para entrenar, abrir o comparar modelos.
- **Profesor** abre un panel con todos los alumnos evaluados, sus resultados de
  pre-test y post-test, el cambio total y el desglose por dimensión. Antes de
  aplicar una evaluación se registran nombre, matrícula o identificador, grupo
  y, opcionalmente, edad y correo. La matrícula vincula ambos test.

La ruta guiada presenta la evolución prevista de la herramienta:

1. **Pre-test** — diagnóstico inicial de 20 preguntas en cinco dimensiones.
2. **Recorrido guiado** — disponible. Organiza 18 conceptos esenciales en seis
   unidades, incluida una guía del contrato de datasets, y combina lectura con
   el ciclo *predecir → observar → explicar*.
3. **Laboratorios** — entrenamiento, apertura de modelos y comparación se
  habilitan al completar el recorrido guiado; cada opción queda registrada al
  abrirse.
4. **Post-test** — evaluación final equivalente, con resultado total y por dimensión.
5. **Progreso y resultados** — compara el pre-test con el post-test del perfil
   activo: puntaje total, cambio, tiempo empleado y desglose por dimensión.

La ruta aplica guardias secuenciales: pre-test, recorrido, laboratorios,
post-test y seguimiento. El interruptor de ruta estricta se conserva en la
configuración para demostraciones y desarrollo. El pre-test y el post-test
cuentan con flujo de entrada, resolución y resultados persistidos localmente,
y el seguimiento reutiliza el análisis por alumno del panel docente.

El recorrido guiado guarda localmente las unidades completadas y la última
posición visitada. No requiere un dataset ni un modelo entrenado para comenzar.

El flujo de los laboratorios es:

1. **Configuración** — se define la arquitectura (capas, cabezas, dimensión del
   modelo, feed-forward, dropout, sesgo de las capas lineales, activación,
   máscara causal) con una estimación de parámetros y memoria que se actualiza
   en vivo. Se puede partir de una configuración predefinida (Mínima, Pequeña,
   Mediana o Base del artículo original) y guardar o recuperar configuraciones
   propias como archivos JSON en `data/configuraciones`.
2. **Catálogo de datasets** — se agregan archivos `.jsonl`, `.json`, `.csv`,
   `.txt` o `.pdf`, o se crea un JSONL desde un formulario. La herramienta
   analiza registros, palabras aproximadas, vocabulario, categorías y
   compatibilidad de entrenamiento. Se pueden seleccionar varios y se combinan
   en un solo corpus. Incluye dos datasets predefinidos de solo lectura
   (`data/datasets_predefinidos`): traducción español–inglés básica y
   preguntas sobre el Transformer.
3. **Entrenamiento** — métricas en vivo (pérdida, precisión por token,
  norma del gradiente), controles de pausa/reanudación y de
  velocidad, y dos pestañas: recorrido pedagógico del batch real y nube PCA 3D
  de embeddings. El mapa de arquitectura permanece visible junto a las
  métricas y sus detalles se abren al seleccionar un bloque.
4. **Resultados** — resumen del entrenamiento, curva de pérdida, tabla de
   pérdida media y precisión por época y opciones de guardado.
5. **Inferencia** — generación token a token con temperatura, top-k, top-p y
   muestreo codicioso; los parámetros pueden cambiarse entre un token y el
   siguiente.
6. **Comparación** — dos modelos guardados generan con el mismo prompt y los
   mismos parámetros; se comparan las respuestas y, paso a paso, los estados
   internos (candidatos de salida, entropía de la atención por capa y tokens
   más atendidos por la atención cruzada).

## Formato de los datasets

Los formatos estructurados usan campos exactos: `instruction` (entrada del
encoder) y `response` (salida correcta del decoder) son obligatorios y no pueden
estar vacíos; `context` añade información opcional a la entrada y `category`
solo organiza los ejemplos. JSON contiene una lista de objetos, JSONL un objeto
por línea y CSV una fila de encabezados. El creador integrado genera este
contrato automáticamente y evita sobrescribir archivos existentes.

TXT y PDF se tratan como corpus continuos: se convierten en pares de fragmentos
consecutivos para aprender continuación de texto. Un PDF debe tener texto
seleccionable. La guía completa, incluidos *teacher forcing*, BOS/EOS/PAD,
calidad de datos y truncamiento por contexto, está disponible tanto en el
recorrido guiado como en las dos pantallas del catálogo.

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

El recorrido pedagógico conserva además comparaciones PCA 2D de estados del
forward actual. Todas las nubes comparadas comparten una sola base PCA para
evitar rotaciones engañosas; PCA es solo la lente visual y no una capa ni una
operación aprendida del Transformer.

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
- La comparación ejecuta el mismo prompt en dos modelos y permite avanzar un
  token por vez o generar de corrido. Para cada token se pueden contrastar la
  autoatención del encoder, la atención causal y cruzada del decoder, y los
  candidatos de salida. El último paso sincronizado conserva además la captura
  tensorial para reproducir en paralelo diez vistas animadas: embeddings,
  posición, Q/K/V y máscara, flujo de atención, multi-head, FFN, residual con
  LayerNorm, trayectoria por capas, proyección y carrera Softmax.

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
| Pre-test y post-test conceptuales | Implementada |
| Seguimiento de resultados del estudiante (RF23) | Implementada (pre/post por perfil) |

## Estructura

Ver `docs/architecture.md` para el detalle de la arquitectura MVVM, el mapeo de
componentes y las convenciones obligatorias de cada capa.
