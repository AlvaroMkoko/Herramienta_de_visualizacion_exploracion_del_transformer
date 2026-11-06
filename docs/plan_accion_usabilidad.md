# Plan de acción a partir de la prueba de usabilidad

Basado en `Resultados_pruebas.csv` (62 respuestas del 29 de octubre de 2026, módulo 3,
instrumento v14) y en la revisión del código actual. Cada acción indica su evidencia,
dónde se hace y cómo saber que funcionó.

## Estado (2026-11-02)

Ya implementado: **1.1 a 1.7, 2.1, 2.2 y la parte de lectura por partes de 2.3**. La prueba
con estudiantes sigue pendiente, así que aún no hay evidencia de su efecto en el SUS.

| Acción | Cómo quedó | Dónde |
|---|---|---|
| 1.1 Modelo listo | Al entrar como alumno se carga el modelo guardado con «didactico» en el nombre o, si no hay, el más ligero. Si no hay ninguno o falla, se crea el de la configuración mínima, y se ejecuta el análisis. El botón «Cambiar modelo» abre la biblioteca si hay modelos guardados | `MainViewModel.prepararModeloLaboratorio`, `elegir_modelo_didactico` |
| 1.2, 1.3 y 1.5 Qué sigue | Barra fija con la siguiente acción, las reglas del reto y las operaciones hechas y pendientes | `ModuleLaboratoryScreen.buildNextAction` |
| 1.4 Guía | Primer uso en el módulo y el laboratorio; se puede omitir y repetir | `GuidedTour.qml` |
| 1.6 Inicio | Botón en laboratorio y recorrido, y en resultados mediante «Ver todos los módulos»; acceso directo al post-test | `BotonInicio.qml` |
| 1.7 Tema y letra | Elección de tema en la bienvenida, fondo claro más suave, tamaño de letra en Preferencias (laboratorio y recorrido) y letra mínima mayor en la vista general | `Theme.qml`, `PreferencesMenu.qml` |
| 2.1 Laboratorio | En «Esencial», frase y ejemplo a un clic; la tarjeta de práctica aparece sólo al necesitarla | `ModuleLaboratoryScreen.qml` |
| 2.2 Términos | Definición al pasar el cursor o tocar; panel lateral opcional | `GuidedLessonView.qml` |
| 2.3 Lecturas | Lección revelada por partes con «Seguir leyendo» | `GuidedLessonView.qml` |

**Sin hacer:** el contenido nuevo de 2.3 (más ejemplos gráficos y analogías), 2.4, 2.5, 2.6, 2.7 y
la fase 3. **El instrumento no cambió:** la huella de los reactivos del módulo 3 sigue igual, pero
su recorrido y su laboratorio sí, así que la siguiente toma debe tratarse como otra cohorte.

**Decisión pendiente del equipo:** los modelos no se versionan. Para que todos los equipos abran con
el mismo modelo, coloquen uno entrenado con «didactico» en el nombre en `data/checkpoints/`. Sin
ninguno, se crea uno sin entrenar, lo que requiere el tokenizador de tiktoken (puede necesitar red
la primera vez).

## 1. En resumen

- **La herramienta no alcanza el umbral de usabilidad:** SUS medio de **56.4**
  (IC 95 %: 51.7–61.0), por debajo de la referencia habitual de 68. Sólo el 27 % de las
  personas llega a 68.
- **El problema es empezar, no la consistencia:** las funciones se perciben integradas,
  pero las personas sienten que necesitan ayuda y aprender mucho antes de usarla.
- **El aprendizaje depende mucho de la disposición de la clase:** en las dos clases con
  interés, el puntaje sube de 36.1 a 56.0 (+19.8; IC 95 %: 12.4–27.2), con ganancia de
  **0.31**, media según la escala de Hake. La clase de las 21–22 h (UTC), que según el equipo
  mostró apatía y desinterés, baja de 35.9 a 31.6. Con todas juntas, la ganancia es de 0.19.
- **El problema de usabilidad no se explica por esa clase:** sin ella, el SUS sigue en **59.3**
  (IC 95 %: 54.0–64.6), por debajo de 68. Una de las clases con interés tiene un SUS de 46.4,
  igual de bajo.
- **Prioridad:** dejar claro qué hacer a continuación, sobre todo en el laboratorio. Es lo
  más señalado y distingue a quienes tuvieron peor experiencia.

## 2. Qué dicen los datos

### Calidad de los datos

| Fila | Problema | Tratamiento |
|---|---|---|
| `370351a7` | Todo en 1 y «gg»: es una prueba | Excluida |
| `d49c1fee` | Duplicado exacto de `a42a572d` | Excluida |
| `8f3bd102` | Enviada 15 h antes; pre y post de versiones distintas | Sólo cuenta para SUS; sin ella, la media es 55.8 |
| `201da22d` | Pre 82 y post 43.9, con ganancia +0.199 (esa ganancia corresponde a un pre de 30) | Excluida del pre/post |
| `45d2c98d` | Pre 88.3 y post 90.2, con ganancia 0.048 (daría 0.162) | Se conserva; revisar |

Quedan **60 respuestas válidas** para SUS y **52 pares** para aprendizaje. Todos los
puntajes SUS del CSV se recalcularon y coinciden; la consistencia interna es buena
(α = 0.81).

En las dos filas señaladas, la aplicación calcula la ganancia a partir de esos mismos
valores, así que la discrepancia apunta a un archivo editado a mano o a un error. Con los
datos disponibles no se puede distinguir (acción 0.3).

### Usabilidad

| Rango de SUS | Personas |
|---|---|
| 68 o más | 16 (27 %) |
| De 51 a 67.5 | 21 (35 %) |
| Menos de 51 | 23 (38 %) |

| Afirmación | Aporte (0–4) | Respuestas desfavorables |
|---|---|---|
| 4. Necesitaría ayuda técnica | **1.53** | 52 % |
| 10. Aprender muchas cosas antes | **1.53** | 58 % |
| 2. Innecesariamente complejo | **1.63** | 47 % |
| 7. La mayoría aprendería rápido | 2.03 | 32 % |
| 8. Difícil de manejar | 2.37 | 25 % |
| 3. Fácil de utilizar | 2.47 | 22 % |
| 1. Lo usaría con frecuencia | 2.62 | 15 % |
| 9. Me sentí seguro | 2.67 | 15 % |
| 6. Inconsistencias | 2.73 | 17 % |
| 5. Funciones bien integradas | **2.97** | 3 % |

Separando las dos subescalas de SUS, la de **aprendibilidad** (ítems 4 y 10) da **38.3** y
la de usabilidad, 60.9.

**Cautela:** los ítems 4 y 10 pueden mezclar la dificultad de la aplicación con la del tema.
El SUS no permite separarlas: una persona escribió que la aplicación es «algo agresiva para
una persona que no tiene ni idea de los temas» (`3ca69089`). La acción 3.2 lo resuelve.

### Aprendizaje

| Medida (52 pares) | Resultado |
|---|---|
| Pre → post | 36.1 → 48.5 |
| Diferencia | +12.4 (IC 95 %: 6.2–18.6; p ≈ 0.0002, prueba de permutación pareada) |
| Subieron / igual / bajaron | 36 / 2 / 14 |
| Ganancia individual | 14 negativa · 21 baja (< 0.3) · 13 media · 4 alta (≥ 0.7) |
| Post-test | 29 por debajo de 50 · 10 en 70 o más |

La correlación entre SUS y ganancia es débil (Spearman ≈ 0.23): **mejorar la usabilidad no
garantiza mejorar el aprendizaje**, así que hay que medir y atender ambos.

### Tres grupos por hora de respuesta

| Grupo (UTC) | n | SUS | Pre | Post | Ganancia | Ganancia < 0 |
|---|---|---|---|---|---|---|
| A · 17 h | 33 | 62.9 | 37.7 | 54.2 | 0.27 | 4 de 28 |
| **B · 21–22 h** | **17** | **47.2** | **35.9** | **31.6** | **−0.10** | **9 de 16** |
| C · 23–00 h | 9 | 46.4 | 36.2 | 60.3 | 0.32 | 1 de 9 |

El pre es casi igual en los tres, así que el conocimiento inicial no lo explica. La
diferencia de B en ganancia es grande frente a A (p ≈ 0.0001) y a C (p ≈ 0.002).

**Explicación del equipo:** A, B y C corresponden a tres clases, y B mostró mucha más apatía y
desinterés que las otras dos. Es una observación de quienes aplicaron la prueba, hecha después
de la sesión y no una medición, pero encaja con un post-test más bajo que el pre: quien
responde sin esfuerzo puede puntuar por debajo de lo que sabe. Por eso, el post de B se debe
leer como una medida poco fiable de lo aprendido, no como evidencia de que la herramienta
empeore el conocimiento. Queda por confirmar con la actividad registrada (acción 0.2), y no
se puede descartar que parte del desinterés venga de la propia herramienta.

**Qué cambia al separar a B:**

| Medida | Todas (60) | Clases con interés, A y C (42) | Conclusión |
|---|---|---|---|
| SUS | 56.4 | **59.3** (IC 95 %: 54.0–64.6) | Sigue por debajo de 68 |
| Aprendibilidad | 38.3 | 42.0 | Sigue siendo lo peor |
| Necesitó ayuda | 28 % | 24 % | Sigue alto |
| Ganancia de la clase | 0.19 | **0.31** | Pasa de baja a media |
| Diferencia pre → post | +12.4 | **+19.8** (IC 95 %: 12.4–27.2; 36 pares) | Aprendizaje claro |
| Ganancia negativa | 14 de 52 | 5 de 36 | Mucho menos frecuente |
| Post-test por debajo de 50 | 29 de 52 | 13 de 36 | Sigue siendo más de un tercio |

La respuesta de B no se elimina de los datos: en un aula real también habrá clases así. Lo que
cambia es qué se concluye. **La clase C tiene interés y aprende, pero su SUS es de 46.4**, igual
que el de B: la baja usabilidad afecta también a quienes sí quieren aprender. La muestra de C es
pequeña (9).

### Problemas señalados

| Pregunta | Sí | SUS de quienes dijeron sí / no |
|---|---|---|
| Necesitó ayuda de otra persona | 17 (28 %) | **42.4 / 61.9** (p ≈ 0.0002) |
| Dificultad para localizar algo | 15 (25 %) | **46.2 / 59.8** (p ≈ 0.01) |
| Visualización poco clara | 10 (17 %), y 7 más no las usaron | 50.8 / 57.5 |
| Problema de presentación | 20 (33 %) | textos 10 · superpuestos 5 · cortado 5 · animaciones 2 · otro 2 |

### Temas en los comentarios

Codificación manual de una sola persona, sobre 60 respuestas; una persona puede aparecer en
varios temas. Es orientativa y conviene que alguien más la revise.

| Tema | Personas | SUS medio |
|---|---|---|
| Laboratorio confuso, saturado o de flujo poco claro | 11 | 52.5 |
| Explicaciones complejas, que asumen conocimiento | 9 | **37.8** |
| Poco intuitiva, falta tutorial o guía | 8 | **40.0** |
| Legibilidad: tema, contraste, tamaño de letra | 7 | 58.6 |
| Navegación: volver al inicio, siguiente etapa, progreso | 7 | 58.6 |
| Ritmo y control de las animaciones | 6 | 61.7 |
| Más ejemplos, gráficos y analogías | 5 | 64.5 |
| Preguntas confusas o tardadas de responder | 5 | 58.0 |
| Encontrar o cargar el modelo | 4 | 63.8 |
| Fórmulas poco legibles | 2 | 43.8 |
| Tiempo insuficiente | 2 | 48.8 |
| Ventana cortada o scroll | 1 | 10.0 |

Los temas más ligados a una mala experiencia son las **explicaciones complejas** y la **falta
de guía**.

## 3. Plan de acción

Esfuerzo: **S** hasta 1 día · **M** de 2 a 5 días · **L** más de una semana. Son estimaciones
gruesas: ajústenlas según quién haga cada acción.

### Fase 0. Entender antes de cambiar (primero)

| # | Acción | Por qué | Esfuerzo |
|---|---|---|---|
| 0.1 | ~~Reconstruir qué pasó en el grupo B~~ **Respondido:** clase con mucha más apatía y desinterés que las otras dos | Se trata como una condición de la sesión. El resto del plan analiza con y sin esa clase | Hecho |
| 0.2 | **Descargar el JSON** (`/api/resultados.php?token=…&formato=json`) y analizar reactivos, conceptos y `actividad`: ciclos de laboratorio y comprobaciones por clase | El servidor lo guarda, pero el CSV no lo trae. Sirve para confirmar con datos que B practicó menos, y para saber qué conceptos y reactivos fallan en las clases con interés | S |
| 0.3 | **Revisar `201da22d` y `45d2c98d`** recalculando desde `reactivos_pre` y `reactivos_post` | Saber si hay un error en la aplicación o archivos editados | S |
| 0.4 | **Observar a 3–5 estudiantes** en su primer uso, pensando en voz alta, y registrar dónde se detienen | Da causas donde el CSV sólo da síntomas; varias quejas no se pudieron ubicar en el código (ver sección 5) | M |

**Hecho cuando** la actividad registrada confirme o matice lo observado en la clase B y exista
una lista de conceptos y reactivos con peor resultado en las clases con interés. Para esa lista
conviene usar sólo A y C: en B, un reactivo fallado puede no decir nada del reactivo. La
observación de 0.4 debe hacerse con estudiantes interesados, porque busca problemas de la
herramienta y no de motivación.

### Fase 1. Saber qué hacer a continuación

Atiende ayuda, localización y aprendibilidad, que son lo peor evaluado. Todo se aplica a los
ocho módulos, porque comparten componentes.

| # | Acción | Evidencia | Situación actual y dónde | Esf. | Hecho cuando |
|---|---|---|---|---|---|
| 1.1 | **Modelo listo al entrar al laboratorio**: cargar uno didáctico por defecto y dejar «crear» o «cambiar» como opción secundaria | `865728a2`, `3ebcece8`, `d3da88bf`, `b67a2d4c` | Hoy el alumno ve «Crear modelo» y «Usar modelo guardado» sin saber qué es (`ModuleLaboratoryScreen.qml`). Los modelos no se versionan (`*.tvismodel` no entra a git): hay que incluir uno en el instalador | M | El laboratorio abre analizando sin elegir nada |
| 1.2 | **Barra fija «Qué hago ahora»** en el laboratorio: paso actual del ciclo, siguiente acción y cuánto falta para el post-test | 11 sobre el laboratorio; `5a75d8e8`, `c42672c5`, `343ab6fb` | El estado existe (`practiceStatusText`), pero queda dentro de la página | M | En la observación, nadie pregunta qué sigue |
| 1.3 | **Explicar las reglas del ciclo antes de empezar**: que predecir no se califica, que la explicación correcta es lo que permite avanzar y qué cuenta como reto completado | `3ff030e8`, `8d6ad609`, `92fd9d5d` | El aviso sólo aparece dentro de la etapa (`LaboratoryDiscoveryCycle.qml`) | S | Sin preguntas sobre cómo avanzar |
| 1.4 | **Recorrido guiado de la interfaz** en el primer uso, con el resto sombreado, omitible y repetible | Lo propone `59663c5f`; 8 en el tema de guía | **No existe** ningún tutorial en la aplicación | M | Ayuda de otra persona ≤ 15 % |
| 1.5 | **Mostrar qué falta en el laboratorio**, en ambos niveles: operaciones o retos hechos y pendientes | `0b13aa20`, `45d2c98d` | El mensaje de estado sólo da un contador («X de 3 retos», «X de Y operaciones»), y el mapa de operaciones se oculta en nivel avanzado. Revisar también las marcas de completado de cada etapa | S | Se ve cuál falta sin buscar |
| 1.6 | **Botón «Inicio»** en todas las pantallas del módulo y **acceso directo** al post-test al desbloquearse | `0b9d4f7f`, `c42672c5` | Sólo hay «Volver», que retrocede una pantalla | S | Inicio en un clic desde cualquier pantalla |
| 1.7 | **Tema y letra**: preguntar el tema en el primer uso, suavizar el fondo claro y añadir tamaño de letra en Preferencias | 10 con textos difíciles de leer; `8d6ad609`, `8683574e`, `b67a2d4c`, `343ab6fb` | Claro por defecto, con fondo casi blanco (`#fffeff`). No hay ajuste de letra. Sólo hay un ⚙ sin rótulo. En la vista general, 19 de 22 tamaños bajan hasta 8–9 px | M | «Textos difíciles de leer» ≤ 5 % |

### Fase 2. Entender mejor el contenido

Atiende el tema con el SUS más bajo. La ganancia ya es media en las clases con interés, de modo
que esta fase busca subirla, no rescatarla: 13 de 36 siguen por debajo de 50 en el post-test.
Usar 0.2 para decidir por qué conceptos empezar. Ninguna de estas acciones se justifica con los
resultados de la clase B por sí solos.

| # | Acción | Evidencia | Situación actual y dónde | Esf. | Hecho cuando |
|---|---|---|---|---|---|
| 2.1 | **Simplificar la pantalla del laboratorio**: mostrar en «Esencial» sólo lo del paso actual y plegar lo demás | `8b31e154` («ocupamos como 10/100»), `27156a4b`, `5a75d8e8` | Controles, mapa, tarjeta de práctica y tres pestañas conviven en `ModuleLaboratoryScreen.qml` | L | Ítem 2 (complejo) con aporte ≥ 2.2 |
| 2.2 | **Definiciones al pasar el cursor** en los términos de la lección y panel lateral opcional | `d3da88bf`, `cce5d934` | Los términos sólo aparecen al inicio (`GuidedLessonView.qml`) | M | Se puede consultar un término sin volver arriba |
| 2.3 | **Dividir las lecciones en bloques más cortos y más ejemplos gráficos**, con revisión de quien no sepa del tema | `fd8d0cf3`, `0f86732e`, `3ca69089`, `b6b34870`, `60af8106` | Hoy es una columna larga por paso | L | Tema «explicaciones complejas» a la mitad |
| 2.4 | **Corregir la deuda del módulo 3**: unificar el ejemplo (3 frente a 4 tokens) y que `m3_l1` y `m3_l2` pidan el cálculo que evalúa el test | 13 de 36 terminan por debajo de 50 en las clases con interés; ver `docs/paridad_modulos.md` | Afecta al recorrido y al laboratorio, no al instrumento | M | Un solo ejemplo en todo el módulo |
| 2.5 | **Animaciones controlables en la vista general**: pausa, avance por pasos y ritmo | `d3da88bf`, `92fd9d5d`, `cc386662` | Hoy dura 3 s y sólo se puede repetir. «Animación detallada» sí tiene velocidad y deslizador: reutilizarlos | M | Sin quejas de ritmo |
| 2.6 | **Mostrar las fórmulas como matemáticas** | `f10553a5`, `a42a572d` | Hoy son texto plano. Sólo 2 personas lo piden, aunque ambas con bajo SUS: confirmar en 0.4 antes de invertir | M | Fórmulas sin barras ni exponentes en línea |
| 2.7 | **Agilizar los reactivos de ordenar** y revisar los peor resueltos | `67af6f50`, `a996b455`, `a42a572d` | **Cambiar reactivos cambia el instrumento**: requiere subir la versión (ver sección 4) | M | Reactivos con `D` < 0.2 revisados |

### Fase 3. Medir de nuevo

| # | Acción | Por qué | Esf. |
|---|---|---|---|
| 3.1 | **Validar el archivo en el servidor**: recalcular la ganancia, evitar envíos duplicados y descartar el relleno | Ya aparecieron un duplicado, una prueba y dos valores que no cuadran (`public/api/encuesta.php`) | S |
| 3.2 | **Añadir a la encuesta**: clase, conocimientos previos, tiempo disponible, **interés y esfuerzo que puso** y si la dificultad fue de la aplicación o del tema. Incluir `actividad` en el CSV | Para medir, en vez de deducir, lo que hoy se confunde en los ítems 4 y 10 y en la clase B | S |
| 3.3 | **Protocolo de sesión**: mismo tiempo mínimo, mismas instrucciones y misma guía en todas las clases, explicar para qué sirve la actividad, y una bitácora de quien aplica la prueba | Permite comparar clases y registrar la disposición del grupo en el momento | S |
| 3.5 | **Reportar siempre con y sin las clases de baja disposición**, definidas antes de ver los resultados con los datos de 3.2, y dejar constancia de que la exclusión de B se decidió después | Sacar a un grupo tras ver sus datos es un sesgo si no se declara. Es importante para el artículo o la tesis | S |
| 3.4 | **Repetir la prueba**, con el mismo SUS, y comparar | Único modo de saber si esto funcionó | M |

## 4. Metas para la siguiente prueba

Las metas se miden en las clases con interés, para que no dependan de qué clase toque, y se
reportan también con todas.

| Indicador | Todas | Clases con interés | Meta |
|---|---|---|---|
| SUS medio | 56.4 | 59.3 | **≥ 68** |
| Personas con SUS menor a 51 | 38 % | 33 % | ≤ 15 % |
| Aprendibilidad (ítems 4 y 10) | 38.3 | 42.0 | ≥ 55 |
| Necesitó ayuda de otra persona | 28 % | 24 % | ≤ 15 % |
| Dificultad para localizar | 25 % | 24 % | ≤ 10 % |
| Textos difíciles de leer | 17 % | 10 % | ≤ 5 % |
| Ganancia de la clase (Hake) | 0.19 | 0.31 | ≥ 0.40 |
| Personas con ganancia negativa | 27 % | 14 % | ≤ 10 % |
| Post-test por debajo de 50 | 56 % | 36 % | ≤ 20 % |

Las metas son una propuesta del plan, no un estándar, salvo el 68 de SUS.

**Cuidados para que la medición siga siendo válida:**

- **Instrumento.** Lo que cambie un reactivo del módulo 3 obliga a subir su versión en
  `VERSIONES_CONGELADAS`: un pre v14 no se compara con un post posterior.
  `test_el_instrumento_del_modulo_3_no_cambia_sin_subir_su_version` lo vigila. Cerrar antes
  cualquier toma de datos en curso.
- **Comparación.** Si cambian el recorrido y el laboratorio, la nueva cohorte mide una versión
  distinta: compárenla como cohorte, no por persona.
- **Otros módulos.** Esta prueba midió sólo el módulo 3. Los otros siete comparten sus
  componentes y ningún estudiante los ha probado; no deben darse por validados.

## 5. Lo que este plan no resuelve todavía

- **Ya cambió desde la prueba:** el arreglo global de la rueda del ratón, que responde a la
  queja de `b81e386f` sobre el scroll. Falta verificarlo en la app. El resto de los problemas
  sigue presente, salvo lo que indique cada acción.
- **Versión probada:** supongo que fue la del commit `560bb6f`, por las fechas. Conviene
  confirmarlo.
- **Quejas que no pude ubicar en el código:** los problemas de contenido superpuesto o cortado
  (5 cada uno, casi sin detalle y quizá según la pantalla), las «transiciones que se saltaban»
  (`cc386662`) y que una respuesta correcta «se queda muy poco tiempo» (`3ff030e8`; no encontré
  un temporizador en ese ciclo). Sólo la observación de 0.4 puede aclararlas.
- **Sobre qué no actuar:** el comentario de `178a873c` («que los alumnos expliquen mejor su
  modulo») parece referirse a quienes presentaron, no a la herramienta.
- **Límites del estudio:** muestra por conveniencia, sin grupo de control. La subida en
  pre/post puede deberse en parte a volver a responder un test parecido.
