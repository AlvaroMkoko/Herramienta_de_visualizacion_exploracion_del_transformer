# Paridad de módulos: llevar los demás al nivel del módulo 3

Instrucciones para que quien continúe (persona o agente) lleve los módulos 1, 2 y
4–8 al nivel de **Self-Attention (módulo 3)**. Enumera **todas** las diferencias
encontradas, incluidas las que `docs/mejoras_pedagogicas.md` no registra, y dice
qué hacer con cada una.

**Cómo se obtuvo.** Revisión del código y de los commits `d2daace`, `b75833e`,
`dfd44cc` y `560bb6f`, más una auditoría que ejecutó el banco y el catálogo reales
de los ocho módulos (2026-11-02, versión 14 del instrumento). Los documentos y las
pruebas no se tomaron como evidencia de lo que hace el código.

**Relación con `mejoras_pedagogicas.md`.** Ese documento sigue siendo la referencia
del formato de lecciones y de los componentes compartidos, pero **está
desactualizado** en los puntos de la sección 7. Si los dos discrepan, manda este,
y antes que ambos, el código.

---

## 0. Estado: aplicado (2026-11-02)

Las brechas G1–G17 ya se aplicaron a los módulos 1, 2 y 4–8. El resto de este
documento se conserva como registro del análisis: describe la situación **anterior**
a los cambios.

| Tema | Qué quedó | Dónde |
|---|---|---|
| Versión (D1) | Global 15; el módulo 3 sigue en 14, porque su instrumento no cambió | `VERSIONES_CONGELADAS`, `version_de_modulo` |
| Foco (D2) | **Sin cambios**: los estudiantes sólo ven el módulo 3 | `FOCUS_MODULE_ID` |
| Ruta avanzada (D3) | Ya cuenta en todos los módulos | `CourseController` |
| Retos (D4) | En los otros módulos, cada reto pide la operación de su reactivo, con otros números | `alineacion.json` |
| Textos del test (D5) | En datos: `question_text` por módulo | `alineacion.json` |
| Vista general (G10) | Escena genérica, con un catálogo por módulo y sus gráficos | `ModuleOverviewScene.qml`, `ModuleOverviewCatalog.js`, `ModuleOverviewPainters.js` |
| Ubicación | Cuatro momentos propios por módulo | `ModuleOverviewCatalog.js` |
| Datos del modelo | Un botón alterna con las visualizaciones técnicas, que antes ocupaban la pestaña | `ModuleLaboratoryVisualization.qml` |
| Experimentos (G11) | Tabla por paso | `LaboratoryExperiments.js` |
| Retos alcanzables (G17) | Los 8 índices aparecen; un paso puede rotar varios | `challengeForCurrentStep` |
| Documentos (G15) | Generador; los archivos se regeneran desde el banco | `tools/generar_preguntas_modulo.py` |
| Rueda del ratón | Encadenamiento global entre áreas anidadas | `viewmodel/encadenador_rueda.py` |

**Protección del módulo 3.** `test_el_instrumento_del_modulo_3_no_cambia_sin_subir_su_version`
guarda una huella de sus 50 reactivos. Si falla, no actualices la huella sin subir antes
su versión.

**Pendiente.**

1. Retirar el foco (D2) cuando el estudio del módulo 3 termine.
2. La deuda del módulo 3 en la sección 7: sus lecciones usan 3 tokens y su ancla, 4; y
   `m3_l1` y `m3_l2` no piden el cálculo de su reactivo. No se tocó para no cambiar lo que
   está en estudio. Lo único que cambió es la frase inicial de su laboratorio.
3. G12 se revisó sólo en parte: se corrigió el ancla del módulo 8, que ponía BOS y EOS en
   la fuente. Falta comparar el resto de los textos de `_module_steps` con `model/motor_llm/`.
4. El contenido nuevo no tiene validación con estudiantes.
5. `docs/medicion.md` y `docs/trampas.md` siguen sin existir.

---

## 1. Resumen de brechas

«Doc. previa» indica si `mejoras_pedagogicas.md` ya lo registra.

| ID | Brecha | Módulo 3 | Otros 7 | Doc. previa |
|----|--------|----------|---------|-------------|
| G1 | Lecciones del recorrido | 8 de 8 pasos | 0 de 8 | Sí (§7) |
| G2 | Contexto antes de cada reactivo | 25 de 25, pre y post | 0 de 25 | **No** |
| G3 | B1–B4 redactados a mano | Sí | Plantilla mecánica | **No** |
| G4 | A3 con casos breves | Opción de máx. 57 car. | «Caso 1 — … Respuesta propuesta: …», de 118 a 222 car. | **No** |
| G5 | Retos del test (`challenges`, `post_variants`, `transfer_items`) autoexplicativos | 147 car. de media | 65–85 car., símbolos sueltos | **No** |
| G6 | Descripción, objetivos, conceptos y pasos en lenguaje llano | Reescritos | Telegráficos | **No** |
| G7 | Comprobaciones del recorrido (`step_checks`) autoexplicativas | 130 car. de media | 60–82 car. | **No** |
| G8 | Pregunta de cierre y ejemplo ancla autónomos | Cierre de 224 car. | Cierre de 68–116 car.; «con lo que observaste…» | **No** |
| G9 | Retos de laboratorio sin pedir acciones imposibles | Con prueba | Sin revisar, sin prueba | Parcial (§8) |
| G10 | **Vista general** conceptual por etapa | Escena propia de 1 203 líneas | Visualización técnica anterior | **No** |
| G11 | Experimento adecuado a cada paso | Descriptores propios | Regla genérica, a veces sin sentido | **No** |
| G12 | Definición del paso fiel al modelo | `mask` corregido | Sin auditar | **No** |
| G13 | Preguntas propias en backward y update | Específicas | Plantilla genérica | **No** |
| G14 | Ruta avanzada que desbloquea el post-test | Sí | Bloqueada por código | **No** |
| G15 | Documento consolidado de preguntas y respuestas | Sí, con prueba | No existe | **No** |
| G16 | Pruebas que protegen todo lo anterior | Sí | Muchas fijadas a `module_3` | **No** |
| G17 | Todos los retos de laboratorio llegan al alumno | 8 de 8 (1 sólo en avanzado) | Se muestran de 3 a 6 de 8 | **No** |

Tamaño del trabajo por módulo: 8 lecciones, 25 contextos, 8 enunciados para B1–B4,
9 textos para A3, hasta 8 retos del test y sus variantes post, 8 comprobaciones, 8
pasos y 8 conceptos, la pregunta de cierre y hasta 8 retos de laboratorio.

---

## 2. Decisiones que tomar antes de empezar

Estas decisiones cambian el trabajo. La recomendación es un punto de partida; las
toma el equipo.

**D1. Versión del instrumento: es global.** `VERSION_PREGUNTAS` vale para los ocho
módulos, y `CourseController._result` y `model/aula/analisis.py` sólo comparan
intentos de la misma versión. Subirla por cambiar el módulo 4 deja también al
**módulo 3** sin comparación entre un pre v14 y un post v15, y los intentos v14
quedan fuera de los análisis que sólo usan el instrumento vigente (`_primero_vigente`).
*Recomendación:* no subirla hasta cerrar la toma de datos del módulo 3. Después,
hacerlo **una sola vez**, con todos los módulos listos. Si hay que publicar antes,
primero cambiar a una versión por módulo; ese cambio toca los resultados, así que
aplica `docs/estandar_red.md`.

**D2. Acceso a los demás módulos.** Con `FOCUS_MODULE_ID = "module_3"` y sin modo
revisión, sólo el módulo 3 está disponible en el mapa
(`_module_available_in_map`), y al terminarlo el curso no avanza al siguiente.
Mejorar los otros módulos no los hace visibles a los estudiantes.
*Recomendación:* mantener el foco durante el trabajo y revisar con modo revisión;
quitarlo como último paso. Hacerlo obliga a actualizar
`test_el_estudio_abre_modulo_3_aunque_el_progreso_anterior_apunte_al_1`,
`test_mapa_modular_reserva_espacio_para_numero_de_etapas` y el valor por defecto de
`ModuleProgressRepository._empty`.

**D3. Ruta avanzada (G14).** Permite llegar al post-test con sólo **visitar** todas
las operaciones, más la pregunta de cierre; los ciclos guiados exigen predecir y
explicar. Extenderla baja el requisito en toda la herramienta.
*Recomendación:* extenderla por coherencia, y medir en la prueba piloto si quienes
la usan rinden distinto.

**D4. ¿Qué practican los retos del laboratorio?** `mejoras_pedagogicas.md` §8 pide
que cada reto practique la misma habilidad que su reactivo, con otros números. Pero
`b75833e` volvió cualitativos `m3_l1` y `m3_l2`: `m3_l1` ya no practica la forma de
QKᵀ, y `m3_l2` ya no pide calcular √d_k, aunque el test (`m3_a1`, `m3_a2`) sí lo
pide. La crítica original de la prueba piloto era justo esa.
*Recomendación:* que cada reto se **lea en la vista y además exija la operación del
reactivo**. Decidirlo antes de escribir, y corregir también `m3_l1` y `m3_l2` si se
adopta.

**D5. ¿Dónde vive el texto por módulo?** Hoy `MODULE_3_QUESTION_CONTEXTS` y los
enunciados de G3 y G4 están escritos en `module_question_bank.py` dentro de ramas
`if module["id"] == "module_3"`. Repetirlo para siete módulos añade cerca de mil líneas
de contenido al código.
*Recomendación:* moverlo a `alineacion.json`, como las lecciones. Ver G2.

---

## 3. Reglas que aplican a todas las brechas

1. **Cambios quirúrgicos en `alineacion.json` y `modules.json`.** Tienen sangrías
   hechas a mano: inserta sólo el fragmento del módulo (procedimiento en
   `mejoras_pedagogicas.md` §7). No toques `data/resultados/` ni `data/progreso/`.
2. **El contexto informa, no resuelve.** Da la situación y el significado de los
   símbolos, nunca la decisión que se pregunta. La versión 13 lo incumplió y hubo
   que rehacerla en la 14: «QKᵀ → escalamiento → softmax» regalaba B6.
3. **Nada de ensayo del test.** Lecciones, comprobaciones y laboratorio no usan los
   números ni la redacción de `challenges`, `post_variants` o `transfer_items`. El
   umbral de similitud es 0.58: si un texto no pasa, cambia el texto, no el umbral.
4. **Pre y post isomorfos.** Misma habilidad y dificultad, con otros casos.
5. **Define antes de usar.** Cada término se explica antes de aparecer. En el test,
   el contexto declara lo que significan los símbolos.
6. **Un solo ejemplo en todo el módulo.** La frase de la pregunta ancla se sigue en
   lecciones, vista general y laboratorio, con números que cuadren de paso a paso.
7. **No pidas lo que la pantalla no permite.** Ver G9.
8. **Sé honesto con los datos.** Lo hipotético se rotula como tal (la vista general
   escribe «PAD (ejemplo)» si la frase no trae relleno). No describas una animación
   sin comprobar que se ve así.
9. **Una lectura clara del paso:** primero la intuición sin fórmulas, luego la
   operación. Una sola columna y la pregunta al final.

`CLAUDE.md` exige `docs/medicion.md` y `docs/trampas.md` antes de tocar reactivos o
QML, pero **esos archivos no existen** en este árbol ni en el historial de git.
Mientras no aparezcan, las invariantes de medición sólo están en estas reglas, en
las pruebas y en los comentarios del banco. Conviene pedírselos al equipo.

---

## 4. Brechas e instrucciones

### Contenido del recorrido

#### G1. Lecciones

**Módulo 3.** `alineacion.json → modules.module_3.lessons` tiene los 8 pasos y se
dibuja con `GuidedLessonView.qml`. Esta vista y `_merge_lessons` son genéricas; la
activación depende sólo de los datos.

**Qué hacer.** Escribe `lessons` con el formato y las reglas de
`mejoras_pedagogicas.md` §7. El paso 1 trae el vocabulario de los módulos anteriores
si el módulo puede tomarse solo.

**Trampa: son las 8 o ninguna.** `lessonMode` sólo mira
`root.steps[0].lesson`, y `_merge_lessons` acepta módulos parciales. Con lecciones
incompletas, el validador no se queja y los pasos sin lección entran a la vista
nueva sin contenido. Escríbelas juntas y agrega una prueba que lo exija.

**Hecho cuando** el módulo tiene 8 lecciones completas y el recorrido se abre en
modo lección con `moduleGuidedCheck` al final.

#### G6. Descripción, objetivos, conceptos y pasos

**Módulo 3 (`b75833e`, `modules.json`).** Se reescribieron `description`,
`objectives`, los 8 `concepts[].description` y los campos `input`, `operation`,
`why` y `change` de los 8 `guided_steps`.

| Campo | Antes | Ahora |
|---|---|---|
| Concepto `qkv` | «Consultas preguntan, claves identifican y valores aportan información.» | «La Query expresa qué busca un token, la Key permite compararlo y el Value contiene la información que puede aportar.» |
| `why` de Escalamiento | «Evita distribuciones excesivamente extremas» | «Evita que softmax se concentre casi por completo en una sola Key cuando d_k es grande» |

**Otros módulos.** Longitud media de `why`: 78 caracteres en el 3 y 33–54 en el
resto. Ejemplos a corregir: «Controla concentración de la distribución» (módulo 7),
«Cada subespacio mide compatibilidades propias» (módulo 4).

**Qué hacer.** Reescribe como oraciones completas, sin símbolos sin explicar,
diciendo el porqué en términos del problema que resuelve el paso.

**Atención.** Estos campos alimentan B1, B2, B7, I1–I9 y el «Resumen del paso», así
que cambiarlos **cambia el instrumento** (D1). Vigila que los distractores tomados
de otros pasos sigan siendo plausibles y de longitud parecida a la respuesta: si la
correcta es la más larga, se delata.

#### G7. Comprobaciones del recorrido

**Módulo 3.** Cada `step_checks` enuncia la definición o la fórmula que necesita:

- Antes: «K tiene forma [5, 16]. ¿Qué forma tiene Kᵀ?»
- Ahora: «K tiene una fila por cada uno de 5 tokens y 16 componentes por Key: [5,16].
  Al intercambiar filas y columnas, ¿qué forma tiene Kᵀ?»

**Qué hacer.** Igual en los demás. Candidatos claros: «Los IDs [1, 4] con d_model =
128 se convierten en:» (módulo 8), «Con X [T, 512] y una proyección conjunta WQ
[512, 512]…» (módulo 4). No uses números de `challenges` ni de los ejemplos de la
lección de ese paso.

### Instrumento de evaluación

Todo lo de este bloque cambia el instrumento: revisa D1.

#### G2. Contexto antes de cada reactivo

**Módulo 3.** `_contextualize_module_questions` antepone `Contexto — …\n\n` a los 25
códigos, en pre y post, y **lanza un error** si falta uno.

**Otros módulos.** La función sale de inmediato. Un alumno lee, por ejemplo,
«B=2,h=4,T=6,d_head=16. ¿Qué forma tiene Q separado?» sin más.

**Qué hacer.**

1. Mueve los contextos a datos (D5), por ejemplo:

   ```json
   "question_contexts": { "B1": "…", "B2": "…", "…": "…", "A8": "…" }
   ```

   Generaliza la función para que lea `module["question_contexts"]`, y haz que sea
   obligatorio con los 25 códigos: B1–B8, I1–I9, A1–A8. Un catálogo sin archivo de
   alineación debe seguir funcionando
   (`test_catalogo_sin_archivo_de_alineacion_conserva_el_contrato_anterior`). Migra
   primero el módulo 3 comprobando que su salida no cambia ni un carácter.
2. Escribe los 25 de cada módulo, con los mismos tipos de encuadre del módulo 3:

   | Código | Qué debe aportar |
   |---|---|
   | B1–B8 | Situación y símbolos; B8 define cada eje de la forma |
   | I1, I2, A4 | Punto de partida y resultado buscado de la secuencia |
   | I3, I4, I7, I9 | Qué significa «resultado inmediato» o «misma etapa» |
   | I5, I8 | Qué cuenta como justificación, no repetir el nombre |
   | I6 | Cómo decidir si dos etapas son consecutivas |
   | A1, A2, A7, A8 | Fórmula o regla necesaria, sin hacer el cálculo |
   | A3, A5, A6 | Datos del caso y lo que se debe evaluar |

**Atención.**

- El mismo contexto se muestra en pre y post, y los reactivos se escogen al azar:
  debe servir para **ambas formas** y para cualquier variante de pregunta.
- Un contexto no debe resolver otro reactivo del mismo intento.
- Los enunciados pasan de unos 70–85 a unos 223 caracteres de mediana: el examen se
  alarga. Mantén los contextos en una o dos oraciones.
- Más texto en el test puede subir la similitud con los retos del laboratorio.
  Corre `test_los_retos_del_laboratorio_no_aparecen_en_la_evaluacion`.

#### G3. Enunciados de B1–B4

**Módulo 3.** Ramas propias en `_build_questions`:

| Código | Plantilla de los otros | Módulo 3 |
|---|---|---|
| B1, B2 pre | «¿Qué descripción corresponde a «X»?» | «¿Qué descripción explica correctamente qué contiene X?» |
| B1, B2 post | «¿Qué operación se realiza durante «X»?» | «¿Qué operación construye la matriz X?» |
| B3, B4 | «La función específica de «X» es: …» | «WQ, WK y WV son parámetros aprendidos que transforman X…» |

La auditoría encuentra «La función específica» en 2 reactivos por forma en cada uno
de los otros 7 módulos, y 0 en el 3. Esa plantilla produce frases sin sentido, como
«La función específica de «d_model» es: Indica cuántos tokens contiene el
vocabulario».

**Qué hacer.** Escribe B1 y B2 (pre y post) y B3 y B4 (pre y post) en lenguaje
natural, en datos. Las afirmaciones falsas de `FALSE_CONCEPT_CLAIMS` sirven de base.
El anexo lista el concepto de cada uno.

**Brecha relacionada: pre y post no miden lo mismo.** B1 y B2 usan `concepts[0]` y
`concepts[4]` en el pre, y `guided_steps[0]` y `guided_steps[4]` en el post. En el
módulo 3 coinciden en concepto. En otros no (el anexo marca cuáles), lo que incumple
la regla 4. Corrígelo eligiendo índices o enunciados que apunten al mismo concepto.

#### G4. Reactivo A3

**Módulo 3.** Cuatro afirmaciones cortas, cada una con su efecto («Pesos [0.1, 0.7,
0.2] → el segundo Value aporta más.»). La más larga tiene 57 caracteres y la prueba
exige menos de 90.

**Otros módulos.** Concatena enunciado y respuesta dos veces: «Caso 1 — … Respuesta
propuesta: …». Sus opciones más largas van de 118 a 222 caracteres, y son dos reactivos en uno.

**Qué hacer.** Para cada módulo escribe, en datos, `paired_prompt` y 4 casos por
forma, a partir de `challenges[2]` y `challenges[3]`. Deben ser 2 correctos y 2
falsos, de longitud parecida, y con números distintos entre pre y post.

#### G5. Retos del test

**Módulo 3 (`b75833e`).** Cada `challenges`, `post_variants` y `transfer_items`
incluye el dato o la fórmula y dice qué representan los símbolos:

- Antes: «d_k=64 y un producto punto vale 16. ¿Cuál es el score escalado?»
- Ahora: «El score escalado se calcula como score crudo/√d_k. Si d_k=64 y el score
  crudo vale 16, ¿cuál es el resultado?»

**Qué hacer.** Reescribe los 8 retos y sus variantes de cada módulo, más los 2 de
transferencia. Conserva `id`, `concept_id` y clave. Pre y post deben quedar igual de explicados: en
el módulo 3 miden 147 y 137 caracteres de media. **Vigila un efecto del módulo 3:**
`A7` y otros enunciados ya escriben la operación («Calcula 0.2·10+0.3·0+0.5·2»), lo
que reduce la demanda cognitiva del reactivo. Decide si eso se desea antes de copiarlo.

#### G8. Pregunta de cierre y ejemplo ancla

**Módulo 3.** El cierre explica el mecanismo antes de preguntar, sin depender de la
memoria de lo observado. El ejemplo se amplió a la frase completa de cuatro tokens.

**Otros módulos.** Cierres como «Con lo que observaste al mover la temperatura, ¿qué
cambia y qué no?» (68 caracteres) dependen de haber hecho una acción concreta. Con la
ruta avanzada o sin haber movido ese control, la pregunta queda sin base.

**Qué hacer.** Reescribe `anchor.closing` para que se entienda solo. Comprueba que
`anchor.example` use la frase de `anchor.question`, y que sus números cuadren.

### Laboratorio

#### G9. Retos que se pueden hacer

**Módulo 3.** `test_retos_de_self_attention_no_piden_controles_inexistentes` prohíbe
«Alterna la máscara», «Incrementa el peso», «Cambia una palabra», etc.

**Qué controles existen** (`ModuleLaboratoryScreen`, según `controlRelevant`): campo
de texto y botón de análisis; capa, cabeza y token; interruptor causal (sólo módulo 6
y 8, ciertos pasos); temperatura, Top-K y Top-P (sólo módulo 7 y 8, ciertos pasos); y
reproducir o avanzar la animación. **No existe** editar matrices, pesos, máscaras ni
componentes de un vector. Además, el módulo 1 no tiene control de token, y en
inferencia normalmente no hay PAD. Cambiar una palabra sí es posible con el campo de
texto, pero la prueba del módulo 3 prohíbe esa frase; si un reto lo necesita, di la
acción completa: «escribe otra frase en el campo de texto y vuelve a analizar».

**Qué hacer.**

1. Para cada reto del anexo, comprueba en la app, **en el paso al que lo asigna el
   mapa** de `challengeForCurrentStep` y en los dos modos, que lo que pide o describe
   existe.
2. Si no existe, reescribe como lectura de un ejemplo: «Ejemplo de una fila…». El
   módulo 3 usa ese recurso en `m3_l3` y `m3_l4`.
3. Conserva `concept_id` igual al del reto del mismo índice (ya coinciden en 8 de 8).
4. Aplica la decisión D4.
5. Actualiza el índice del mapa si un reto cambia de habilidad.

#### G10. Vista general conceptual

La mayor diferencia visible y no documentada.

**Módulo 3.** `SelfAttentionOverviewScene.qml` (commits `dfd44cc` y `560bb6f`) sustituye
a la visualización técnica en la pestaña **Vista general**. El cálculo numérico queda
en **Animación detallada**. `usesSelfAttentionOverview()` devuelve `true` sólo para
`module_3`. Cada etapa (`definitionFor`) declara `kind`, `phase`, `title`, `purpose`,
`question`, `inputTitle/Detail/Items`, `actionTitle/Detail`, `visualLabel`,
`outputTitle/Detail/Items` y `takeaway`, con estas propiedades:

| Elemento | Qué aporta |
|---|---|
| Pregunta de la etapa | Dice qué buscar antes de ver nada |
| Tres tarjetas entra → pasa → sale | Misma estructura de lectura en todas las etapas |
| Indicación de lectura | «LEE DE IZQUIERDA A DERECHA · 1 qué entra → 2 qué pasa → 3 qué sale» |
| Narración que sigue a la animación | «Primero observa qué entra…» |
| Gráfico propio por tipo | Dibujado en `paintStage` |
| Mapa global del módulo | Fases ENTRADA, Q/K/V, ATENCIÓN, CONTEXTO, marcado como «no es un botón» |
| Ejemplo y token en foco | «EJEMPLO VISIBLE · «…» · TOKEN EN FOCO · «…»» |
| Idea final (`takeaway`) | Una frase para llevarse, y aclara errores comunes |
| Datos reales con respaldo | Usa los tokens y pesos capturados; si no hay, usa el ejemplo |
| Rotula lo hipotético | «PAD (ejemplo)» |
| Adaptable | 4 columnas o 1 según el ancho (`compact`, `veryCompact`) |
| Reduce movimiento | `reducedMotion` y botón de repetir |

**Otros módulos.** `componentForModule` les da la visualización técnica anterior, y en
algunos pasos `usesSimpleStageOverride` da tres tarjetas simples.

**Qué hacer.** **No copies** el archivo siete veces. Recomendado:

1. Extrae la estructura a un componente genérico, por ejemplo `ModuleOverviewScene`:
   encabezado, mapa, pregunta, tarjetas, narración e idea final, que reciba
   `globalMoments` y un catálogo de definiciones. El módulo 3 debe verse igual después.
2. Cada módulo aporta su catálogo y su `paintStage` en un archivo propio, o los tipos
   de gráfico se comparten cuando apliquen (por ejemplo, máscara y mapa de atención).
3. Cubre **todos** los pasos de `_module_steps(module_id, mode)`, en inferencia y
   entrenamiento. El anexo los lista. Son diferentes a los `guided_steps`.
4. Sustituye `usesSelfAttentionOverview()` por una tabla de módulos, y activa cada uno
   al quedar completo.
5. Revisa `animationDescriptionForStep` y la guía, para que describan la vista nueva.
6. Mantén la frontera: **conceptual en la vista general, números en la animación
   detallada**. `FormulaAnimationScene` ya cubre los ocho módulos.

**No pierdas lo que ya existe.** Las visualizaciones técnicas de cada módulo dejan de
verse al activar la escena. En el módulo 3, `attentionComponent` (con
`AttentionComputationScene` y `LayerSkyscraperScene`) quedó inalcanzable desde
`componentForModule`. Antes de sustituir `tokenizationComponent`, `embeddingComponent`,
`multiHeadComponent`, etc., decide si cada una debe conservarse en otra pestaña.

**Requisito para el ejemplo.** Ver sección 7, sobre el texto inicial del laboratorio.

**Hecho cuando** cada paso de cada modo tiene definición propia y distinta, no se
enciman las tarjetas a 4 y 1 columnas, y hay prueba como las de G16.

#### G11. Experimento adecuado a cada paso

**Módulo 3 (`buildExperimentDescriptor`).** Se corrigió la regla genérica donde el
experimento no tenía sentido:

- `mask`: en vez de «Comparar otra cabeza», «Comprueba qué hace mask(S)» y reproducir
  la animación. Con el texto: «Aquí no se inventa un interruptor».
- `attention_input`, `qkv`, `output`: «Observar otro token».
- Título y subtítulo propios por paso (`experimentTitle`, ya disponibles para todos).

**Otros módulos.** Regla genérica, resultado calculado para cada paso en el anexo.
Problemas más claros:

- **Módulo 4:** todos los pasos dicen «Selecciona otra cabeza y compara qué relaciones
  entre tokens reciben mayor peso». No tiene sentido en `project`, antes de que existan
  las cabezas, ni en `concat`, `wo`, `backward` o `update`.
- **Módulo 5:** `residual_1`, `norm_1`, `ffn_*` y `norm_2` dicen «Cambia de capa y
  observa cómo la representación ya contextualizada vuelve a transformarse».
- **Módulo 1:** todos los pasos usan «Recorrer la fórmula», porque sin control de
  token no hay otra acción. Aprovecha el campo de texto (por ejemplo, palabras nuevas o
  frases de distinta longitud), con cuidado de no prometer PAD en inferencia.
- **Módulos 2, 6, 7 y 8:** muchos pasos dicen «Cambiar el token observado», aunque en
  `backward`, `update`, `loss` o `select` no es lo que enseña el paso.
- El módulo 3 tampoco está resuelto: `weights`, `backward` y `update` caen en «Comparar
  otra cabeza».

**Qué hacer.** Para cada paso define `{title, subtitle, label, instruction}` y su acción
en `applySuggestedExperiment`. Pasa la tabla a datos en lugar de añadir ramas por `moduleId`.
Regla: el cambio debe producir una diferencia visible y relacionada con ese paso. Si no
hay nada que variar, usa «Recorrer la fórmula», es honesto.

#### G12. Definición del paso fiel al modelo

**Módulo 3 (`b75833e`).** El paso `mask` decía «Las posiciones no permitidas reciben −∞»
y su reto pedía «Activa la máscara», un control que no existe. Ahora se llama «Máscara de padding», dice qué hace
este encoder en concreto y aclara qué ocurre si no hay PAD, en tres lugares a la vez:
`_module_steps`, `LaboratoryAnimationGuide.qml` y `m3_l7`.

**Qué hacer.** Compara cada `_step` y cada texto de la guía con
`model/motor_llm/`, para confirmar lo que ejecuta esta implementación, y no lo que hace
un Transformer de libro. Prioriza módulo 1 (`mask`, `batch` en cada modo), módulo 5 y 8
(PAD en el encoder), módulo 6 (`causal_mask`, cuando se apaga, es un contrafactual) y
módulo 7 (`select`, `feedback`).

#### G13. Preguntas de backward y update

**Módulo 3.** `lab_m3_backward` y `lab_m3_update` explican antes de preguntar («W es el
peso actual, g es su gradiente y η indica el tamaño del paso…») y mencionan WQ, WK y WV.
`lab_m3_attention_input` también explica X.

**Otros módulos.** Los pasos marcados `G` en el anexo reciben la plantilla: «En «X»,
¿qué representa θ′ = θ − ηg?», con el distractor «La salida definitiva de softmax», que
no encaja en todos los módulos. Son módulos 2, 4, 5, 6, 7 y 8; el 1 no tiene estos pasos.

**Qué hacer.** Añade una entrada `"module_N:backward"` y `"module_N:update"` (o sus
equivalentes `embedding_update`, `full_backward`, `full_update`) que nombre los
parámetros reales de `_component_parameters`. Revisa también las demás preguntas `E`, para
que definan sus términos.

#### G14. Ruta avanzada

**Módulo 3 (`560bb6f`).** En nivel avanzado, visitar todas las operaciones de un modo
cuenta como práctica. Sigue siendo obligatoria la pregunta de cierre.

**Qué hacer** (sujeto a D3). Quita la restricción en estos cuatro lugares:

- `CourseController._advanced_path_completed`
- `CourseController.recordAdvancedLaboratoryStep`
- `CourseController.stageBlockReason`
- `ModuleLaboratoryScreen`: `recordAdvancedVisit` y `practiceStatusText`

Reemplaza `test_ruta_avanzada_de_desbloqueo_es_exclusiva_del_modulo_3` por una prueba
parametrizada que sí desbloquee. La prueba actual falla a propósito con este cambio.

#### G17. Que cada reto llegue al alumno

`challengeForCurrentStep` da prioridad a la pregunta específica del paso (E), y sólo usa
`lab_challenges` si no hay una. **En el módulo 3 esto no deja retos fuera**, porque su
mapa reparte los ocho, aunque `m3_l6` sólo aparece en nivel avanzado (por el paso
`weights`). **En los otros módulos, varios retos nunca se muestran en el laboratorio:**
sus preguntas específicas o la plantilla genérica los tapan.

| Módulo | Índices de `lab_challenges` que nunca se muestran | Cuántos se muestran |
|---|---|---|
| 1 | 0, 3, 4, 5, 7 | 3 |
| 2 | 0, 4, 6 | 5 |
| 4 | 1, 3, 6, 7 | 4 |
| 5 | 6, 7 | 6 |
| 6 | 1, 3, 5 | 5 |
| 7 | 0, 7 | 6 |
| 8 | 0, 2, 5, 6, 7 | 3 |

Como `lab_challenges[i]` prepara el reactivo `challenges[i]`, las habilidades de esos
índices no se practican. Los índices 1, 4 y 7 sí se usan en el repaso espaciado
(`REVIEW_ITEM_INDICES`), que hoy no se ve mientras siga el foco de D2.

**Qué hacer.** Decide el mapa paso → reto de cada módulo, de modo que los 8 índices
aparezcan en nivel esencial si es posible. Donde una pregunta **E** tape un reto, conviene
quitar la **E** o moverla a otro paso. Hazlo **después** de G9, y agrega una prueba
parametrizada con esta misma cuenta.

### Documentación y pruebas

#### G15. Documento consolidado

El módulo 3 tiene `preguntas_respuestas_modulo_3_self_attention.md`: pregunta ancla, 8
comprobaciones, 25 PRE, 25 POST y 11 LAB, verificado por
`test_archivo_consolidado_del_modulo_3_esta_actualizado`. Sirve para que el equipo
revise el instrumento completo.

**No hay un generador en `scripts/` ni en `tools/`.** En lugar de escribir siete archivos
a mano, crea un generador que parta del banco real y compruebe que el documento coincide.
Así no se desfasa. El recuento de LAB varía según el módulo: no copies el 11.

#### G16. Pruebas

Parametriza por módulo lo que hoy sólo cubre el 3:

| Prueba actual | Qué hacer |
|---|---|
| `test_todos_los_reactivos_de_self_attention_explican_su_contexto` | Parametrizar con los 8 módulos |
| `test_reactivos_de_self_attention_no_adelantan_la_respuesta_y_son_concisos` | Parametrizar; cada módulo aporta sus frases prohibidas |
| `test_retos_de_self_attention_no_piden_controles_inexistentes` | Parametrizar con la lista prohibida común |
| `test_vista_general_de_self_attention_cubre_todo_el_modulo_y_es_adaptable` | Parametrizar sobre `_module_steps`; `SPECIALIZATIONS` cambia de `objectName` |
| `test_vista_general_de_self_attention_se_reordena_y_respeta_mascara_causal` | Conservar y agregar el caso compacto por módulo |
| `test_ruta_avanzada_de_desbloqueo_es_exclusiva_del_modulo_3` | Reemplazar (G14) |
| `test_archivo_consolidado_del_modulo_3_esta_actualizado` | Parametrizar (G15) |
| Host de `test_module_screens.py` fijado a `module_3` | Agregar recorrido de otro módulo en modo lección |

Pruebas nuevas:

- Un módulo tiene 0 u 8 lecciones, nunca intermedio (G1).
- B1 y B2 miden el mismo concepto en pre y post (G3).
- A3 no contiene «Respuesta propuesta», y B3 y B4 no contienen «La función específica»,
  en ningún módulo (G3, G4).
- Cada paso de cada módulo y modo tiene un experimento propio (G11).
- Ningún ejemplo de lección usa los números de su propia comprobación ni del test.
- Todo índice de `lab_challenges` es alcanzable desde algún paso (G17).

Al quedar los ocho en modo lección, el recorrido de tres paneles
(`ModuleGuidedTourScreen.qml`) queda sin usar: decide si se conserva para catálogos sin
lecciones. `test_catalogo_sin_archivo_de_alineacion_conserva_el_contrato_anterior`
indica que ese contrato aún importa.

---

## 5. Ya es igual en todos los módulos: no lo rehagas

Verificado en el código o ejecutando el banco de los ocho módulos.

- Componentes de reactivos: `forma_tensor`, banco de opciones y formato numérico. Los
  conteos varían según el contenido; los módulos 2, 5 y 8 no tienen reactivos numéricos.
- Arrastrar y soltar, soltar el foco del cuadro de texto, relacionar en cualquier orden.
- Paleta de símbolos, generada de los `dimensions` de cada módulo. **Revísala** al
  reescribir G6: el módulo 1 ofrece `T_contenido + 2` y el 4 `h·d_head`, que no cumplen
  el validador de la casilla (`[A-Za-z0-9_|]{0,12}`). Ninguna clave actual los necesita,
  pero sí se pueden colocar con un toque y no se pueden escribir a mano.
- Enunciado nuevo de B8.
- Exportar resultados (`resultados_<module_id>.tvresultados.json`).
- `GuidedLessonView`, `_merge_lessons` y el cambio automático en el recorrido.
- Rediseño de tarjetas del mapa, tarjeta de práctica movida en nivel avanzado, títulos
  configurables de `LaboratoryDiscoveryCycle`.
- `FormulaAnimationScene` y `formula_demos.py`, que ya tienen los ocho módulos.
- `concept_id` entre `lab_challenges[i]` y `challenges[i]`: coinciden en 8 de 8.

---

## 6. Orden de trabajo recomendado

**Fase A. Una vez, con el módulo 3 como control** (el módulo 3 no debe cambiar):

1. Tomar las decisiones D1–D5 y resolver la deuda de la sección 7.
2. Mover los textos del banco a datos (D5).
3. Extraer la vista general genérica (G10).
4. Pasar experimentos a datos (G11).
5. Parametrizar las pruebas (G16) y crear el generador (G15).

**Fase B. Por módulo.** Empieza por el **4**: es el más cercano al 3 y puede reutilizar
sus gráficos de atención. Deja el **8** al final, porque integra a todos.
Sigue este orden dentro de cada módulo:

- [ ] G12: fijar lo que hace el modelo real
- [ ] G6: conceptos y pasos
- [ ] G1: 8 lecciones, con un solo ejemplo
- [ ] G7: comprobaciones
- [ ] G5: retos, variantes y transferencia
- [ ] G3 y G4: B1–B4 y A3
- [ ] G2: 25 contextos
- [ ] G8: ancla y cierre
- [ ] G9, G13 y G17: retos, preguntas del laboratorio y su mapa
- [ ] G10: vista general, en los dos modos
- [ ] G11: experimentos
- [ ] G15: documento consolidado regenerado
- [ ] Revisar a mano, en la app, las etapas completas del módulo

**Fase C. Al final, una vez:**

1. Subir `VERSION_PREGUNTAS` con su comentario (D1).
2. Aplicar G14 (si D3 lo aprueba) y retirar el foco (D2).
3. Actualizar `mejoras_pedagogicas.md`, `docs/architecture.md` y el README.
4. Volver a probar con estudiantes: los módulos nuevos no tienen validación piloto.

**Verificación en cada entrega:** suite completa comparada con la línea base;
`pyside6-qmllint` en cada QML tocado (`docs/architecture.md`); invariante de medición
revisada, y dicha, si toca un reactivo. Importa `tests.conftest` antes de construir
`MainViewModel`, para no reescribir `data/progreso/`.

---

## 7. Deuda en el módulo 3: no copiarla

Son incoherencias del propio módulo modelo. Corrígelas antes de usarlo como plantilla.

**Contenido**

1. **Lecciones y ancla usan ejemplos distintos.** `m3_s1` dice «T = 3» con «el», «banco»,
   «río», y sus números son [0, 1, 2] → salida ≈ 3.8. El ancla, la vista general y las
   pruebas usan 4 tokens, «el banco del río», [0, 1, 0, 2] → salida ≈ 3.39. `b75833e`
   actualizó el ancla, pero no las lecciones. Incumple la regla 6.
2. **Texto inicial del laboratorio ajeno al ejemplo.** `inputText` arranca con «La
   atención conecta cada token con su contexto.», mientras que `m3_l1` pide seguir la
   fila de «banco» hasta la columna de «río», que no existen en esa frase. Haz que el
   texto inicial salga de un dato del módulo y use la frase del ancla.
3. **`m3_l1` y `m3_l2` ya no preparan su reactivo** (D4).
4. **`weights`, `backward` y `update` sin experimento adecuado** (G11).

**Estado del repositorio**

5. **`REVIEW_MODE_UNLOCK_ALL = True` sin confirmar** en
   `viewmodel/course_controller.py`, un cambio local sobre `560bb6f`. El comentario del
   propio código dice que debe ser `False` con estudiantes: invalida la comparación
   pre/post. También hace fallar 11 pruebas de `test_module_screens.py`,
   `test_module_course.py` y `test_classroom_network.py`, que pasan si se fuerza a `False`.
6. **`test_resultados_muestran_cuantas_veces_se_tomo_cada_evaluacion` falla aparte**,
   también con `False`: indexa directamente un `QJSValue`, cuando `tests/CLAUDE.md` pide
   normalizarlo con `.toVariant()`.
7. **`docs/medicion.md` y `docs/trampas.md` no existen**, y `CLAUDE.md` los exige.
8. **`docs/` está ignorado por completo en `.gitignore`.** Este documento y
   `mejoras_pedagogicas.md` no entran al control de versiones sin una excepción.

**`mejoras_pedagogicas.md` desactualizado**

9. Dice versión 12; el código está en la 14.
10. La tabla de §8 describe `m3_l1` («4 × 4») y `m3_l2` («d_k = 25 → 2»), que ya no son así.
11. §7 cita «scores [0, 1, 2] … salida ≈ 3.8» como cuadrando en todo el módulo.
12. No registra nada de lo marcado «No» en la sección 1.

---

## Anexo. Datos por módulo

### A. Conceptos de B1–B4

✗ indica que el pre y el post de ese reactivo miden conceptos distintos (G3).

| Módulo | B1 pre / post | B2 pre / post | B3 | B4 |
|---|---|---|---|---|
| 1 | `tokenizacion` | `tokens_especiales` | Token IDs | Secuencias |
| 2 | `token_embedding` / `seleccion_id` ✗ | `positional_encoding` | Matriz de embeddings | d_model |
| 4 | `division_cabezas` / `qkv_por_cabeza` ✗ | `concatenacion` / `atencion_independiente` ✗ | Q, K y V por cabeza | Diferencias entre cabezas |
| 5 | `flujo_encoder` | `ffn_encoder` | Self-Attention del encoder | Layer Normalization |
| 6 | `entrada_decoder` | `ffn_decoder` / `cross_attention` ✗ | Masked Self-Attention | Cross-Attention |
| 7 | `estado_decoder_final` | `temperature` / `top_p` ✗ | Proyección lineal | Softmax final |
| 8 | `flujo_texto_ids` | `flujo_salida` / `flujo_decoder_completo` ✗ | IDs a representaciones | Pila decoder |

### B. Pasos del laboratorio (G10, G11, G13)

Son los pasos que necesitan una definición en la vista general. Están calculados con
`_module_steps` y las reglas actuales, suponiendo más de una cabeza, capa y token.

Fuente de la pregunta: **E** propia, **G** plantilla genérica, **L** `lab_challenges`.

| Módulo | Inferencia | Solo entrenamiento | Experimento genérico actual |
|---|---|---|---|
| 1 | `text`ᴱ `tokens`ᴸ `ids`ᴱ `specials`ᴸ `batch`ᴱ `mask`ᴸ `no_grad`ᴱ | Los mismos | Todos: recorrer |
| 2 | `lookup`ᴸ `scale`ᴸ `position`ᴸ `sum`ᴸ `dropout`ᴱ | `embedding_gradient`ᴱ `embedding_update`ᴳ | Todos: token |
| 4 | `project`ᴱ `split`ᴸ `maps`ᴸ `contexts`ᴱ `concat`ᴸ `wo`ᴸ | `backward`ᴳ `update`ᴳ | Todos: cabeza |
| 5 | `encoder_input`ᴱ `encoder_attention`ᴸ `residual_1`ᴸ `norm_1`ᴸ `ffn_expand`ᴸ `ffn_activation`ᴸ `ffn_project`ᴱ `norm_2`ᴸ `stack`ᴸ | `backward`ᴳ `update`ᴳ | `encoder_attention`: cabeza; `stack`: token; resto: capa |
| 6 | `decoder_prefix`ᴱ `decoder_embedding`ᴱ `causal_mask`ᴸ `masked_attention`ᴸ `decoder_residual_1`ᴱ `cross_attention`ᴸ `decoder_residual_2`ᴱ `decoder_ffn`ᴱ `decoder_output`ᴸ `decoder_layers`ᴱ | `backward`ᴳ `update`ᴳ | Prefijo, embedding, `decoder_layers`, backward y update: token; máscara y masked: causal; cross: cabeza; resto: capa |
| 7 | `hidden`ᴱ `linear`ᴸ `temperature`ᴸ `top_k`ᴸ `top_p`ᴸ `softmax`ᴸ `select`ᴱ `feedback`ᴸ | Sin filtros: `hidden`ᴱ `linear`ᴸ `target`ᴱ `loss`ᴱ `backward`ᴳ `update`ᴳ | Filtros: propio; resto: token |
| 8 | `full_tokens`ᴱ `full_embedding`ᴸ `full_encoder`ᴸ `full_decoder`ᴸ `full_logits`ᴱ `full_filters`ᴱ `full_select`ᴱ `full_feedback`ᴱ | Sin filtros ni selección: `full_batch`ᴱ `full_loss`ᴱ `full_backward`ᴳ `full_update`ᴳ | Encoder: cabeza; decoder: causal; filtros: propio; resto: token |

En el módulo 6, `decoder_prefix` es **E** en inferencia y **L** en entrenamiento.

### C. Retos de laboratorio que revisar primero (G9)

Son candidatos encontrados por lectura; compruébalos en la app. No es una lista cerrada.

| Reto | Texto | Duda |
|---|---|---|
| `m2_l3` | «Fija el embedding y cambia una componente del vector posicional» | **No hay control para eso** |
| `m1_l5` | «Tras intercambiar dos palabras…» | Requiere editar el texto; el reto no lo dice |
| `m1_l2`, `m1_l4` | «atenúa una celda PAD», «aparecen nuevas celdas PAD» | En inferencia normalmente no hay PAD |
| `m1_l1` | «ambas frases terminan como filas alineadas» | Una sola secuencia en inferencia |
| `m2_l5` | «Añade un token al texto y vuelve a ejecutar» | Posible con el campo de texto; ¿se ve el cambio descrito? |
| `m5_l7`, `m8_l2`, `m8_l8` | «Cambia una palabra…» | Posible, pero es una frase prohibida en la prueba del módulo 3 |
| `m5_l8` | «Detén la animación justo después de self-attention» | ¿En qué vista y con qué control? |
| `m4_l2` | «Activa otra cabeza en Q separado» | ¿Se ve el panel «Q separado»? |
| `m6_l3`, `m6_l4` | «flechas de cross-attention», «chips de la fuente» | ¿Coinciden con lo que se dibuja? |
| `m7_l5` | «dos distribuciones… al aplicar Top-P» | Sólo se ve una por ejecución |
| `m7_l7` | Flecha de realimentación | ¿Se dibuja así? |
| `m7_l8` | «recibe EOS antes de agotar el límite» | EOS puede no llegar; además, hoy no se muestra (G17) |
| `m8_l3` | «sombrea PAD en la fuente» | Depende de que haya PAD |
| `m8_l6` | «Al cambiar la cabeza seleccionada» | El control sólo aparece en `full_encoder` y `full_decoder` |
