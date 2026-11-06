# Mejoras pedagógicas a partir de la prueba con estudiantes

Registro de los cambios hechos para responder a las críticas de la prueba piloto
del **Módulo 3 · Self-Attention**. Cada cambio dice qué se criticó, qué se hizo y
dónde vive. Está escrito para quien (persona o agente) continúe el trabajo.

**Estado.** Los módulos 1, 2 y 4–8 ya se llevaron a este estándar: el detalle, las
decisiones y lo que queda pendiente están en `docs/paridad_modulos.md`. Las
secciones siguientes conservan el registro original; donde discrepen, manda ese
documento y, antes que ambos, el código. En particular, las lecciones, los
contextos y los enunciados de B1–B4 y A3 son ahora datos de
`data/aprendizaje/alineacion.json`, y el instrumento va en la versión 15, con el
módulo 3 congelado en la 14 (`ModuleQuestionBank.VERSIONES_CONGELADAS`).

Regla general: los cambios de **componentes** (QML y banco de reactivos) ya
aplican a toda la herramienta, porque los ocho módulos comparten las mismas
piezas. Los cambios de **contenido** (lecciones del recorrido, retos del
laboratorio) sólo se escribieron para el módulo 3; los demás módulos siguen
viéndose como antes hasta que alguien escriba su contenido con el mismo formato.

| # | Crítica | Alcance actual | Pendiente para los demás módulos |
|---|---------|----------------|----------------------------------|
| 1 | Formas de tensor: no se sabe cómo escribirlas | Todos los módulos | Nada |
| 2 | Arrastrar fichas no funcionaba | Todos los módulos | Nada |
| 3 | No se puede «deseleccionar» el cuadro de texto | Todos los módulos | Nada |
| 4 | «¿Qué forma tiene el tensor producido por…?» es confusa | Todos los módulos | Nada |
| 5 | Relacionar sólo de izquierda a derecha | Todos los módulos | Nada |
| 6 | Respuestas abiertas ambiguas («Q» o «Query») | Todos los módulos | Nada |
| 7 | El recorrido no explica, asume conocimiento, tres ventanas | Todos los módulos | Nada |
| 8 | El laboratorio no prepara para el post-test | Todos los módulos | Decidir si `m3_l1` y `m3_l2` vuelven a pedir el cálculo |
| 9 | Exportar resultados al final del módulo | Todos los módulos | Nada |

La versión del instrumento se consulta por módulo
(`ModuleQuestionBank.version_de_modulo`). Un pre-test y un post-test de versiones
distintas no se comparan: la pantalla de resultados ya lo avisa. Si alguien hizo el
pre-test antes de actualizar, debe repetir el módulo completo.

---

## 1. Formas de tensor eje por eje (presentación `forma_tensor`)

**Crítica.** «Resuelve sin opciones: Q tiene [5,32] y K tiene [5,32]. ¿Qué forma
tiene QKᵀ?» No queda claro cómo escribirlo y el campo acepta cualquier cosa.

**Qué se hizo.** Toda respuesta corta cuya clave es una forma `[..]` (B8 y A1 en
casi todos los módulos) se dibuja con el componente nuevo
`view/qml/components/ReactivoForma.qml`:

- Una casilla por eje entre corchetes; cada casilla admite sólo un número o un
  símbolo (`[A-Za-z0-9_|]`, máximo 12 caracteres).
- Empieza con **dos** ejes y el estudiante agrega o quita (1 a 4). Mostrar el
  número correcto de casillas regalaría la mitad de la respuesta.
- Paleta con los símbolos que usa el recorrido del módulo (`simbolos`, p. ej.
  `B, T, d_model, d_k, d_v`). Lo escrito a mano se normaliza al símbolo oficial
  (`dmodel` → `d_model`), porque el calificador separa por signos.
- La respuesta sigue siendo `{"texto": "[5,5]"}`: el calificador no cambió. Sólo
  se entrega cuando no hay casillas vacías.

**Dónde.** `ModuleQuestionBank._text_question` decide la presentación;
`_shape_symbols` saca los símbolos de los `dimensions` de los pasos.
`EvaluationScreen.componentePara` registra `forma_tensor`.

## 2. Arrastrar y soltar fichas (ordenar y cestas)

**Crítica.** En ordenar es un clic y otro clic; lo intuitivo es arrastrar, y el
arrastre no funcionaba.

**Causa.** Tres errores en `FichaAsignable.qml`:

1. `MouseArea` termina el arrastre al soltar el botón y el evento de soltar ya no
   llegaba a ningún `DropArea`. Se veía arrastrar, pero la ficha volvía al
   montón.
2. `drag.active` ya vale `false` en `onReleased`, así que cada arrastre se
   contaba además como un toque.
3. El `ScrollView` del examen se robaba el gesto y la ficha quedaba recortada
   por debajo de las ranuras.

**Qué se hizo.** El arrastre se inicia a mano, la ficha viaja en la capa
`Overlay.overlay` (encima de todo) y, al soltar, se entrega directamente al
área que tiene debajo (`Drag.target.recibir(elementoId)`). Cada `DropArea` de
`ReactivoOrdenar` y `ReactivoCestas` declara `function recibir(elementoId)` y
aplica el cambio con `Qt.callLater` (cambiar el modelo dentro del manejador del
arrastre destruía la ficha que se estaba arrastrando). `preventStealing: true`
evita que el desplazamiento se robe el gesto. Tocar sigue funcionando igual.

**Regla para componentes nuevos.** Un destino de arrastre debe declarar
`function recibir(elementoId)`. No uses `onDropped`: nunca se llama.

**Prueba.** `tests/view/test_reactivos_modulares.py::test_arrastrar_una_ficha_a_su_posicion_la_coloca`
arrastra con eventos de ratón reales.

## 3. Soltar el cuadro de texto

**Crítica.** En las preguntas abiertas no se puede deseleccionar el cuadro.

**Qué se hizo.** En `EvaluationScreen.qml`, un `TapHandler` en la tarjeta del
reactivo quita el foco al tocar fuera de una casilla. `Esc` y `Enter` también lo
quitan en `ReactivoTexto` y `ReactivoForma`.

## 4. Enunciado de B8

**Crítica.** «¿Qué forma tiene el tensor producido por «Salida contextualizada»?»
no queda clara.

**Qué se hizo.** El enunciado ahora es: «Al terminar el paso «X», ¿qué forma
(dimensiones) tiene el tensor que se obtiene? Escríbela eje por eje con los
símbolos del recorrido.» Con la paleta de símbolos (punto 1) el estudiante ve
qué notación se espera. El recorrido nuevo del módulo 3 explica qué es cada
símbolo (punto 7).

## 5. Relacionar en cualquier orden

**Crítica.** Se puede elegir primero la izquierda y luego la derecha, pero no al
revés.

**Qué se hizo.** `AsignacionBase` tiene `destinoEnMano` y `tomarDestino()`. En
`ReactivoRelacionar`, tocar una función libre la deja «en mano» y el siguiente
elemento tocado se empareja con ella. Tocar una función ocupada deshace su par.

## 6. Respuestas abiertas ambiguas

**Crítica.** «Completa el flujo: Escalamiento → ____ → Pesos × V». ¿Se escribe
abreviado? ¿«Q» o «Query»? ¿Y si lo sabe pero lo escribe mal?

**Qué se hizo.**

- Los reactivos de **completar** (B6 e I7) se contestan eligiendo del banco de
  opciones (`banco_opciones`): la respuesta y tres distractores tomados de otros
  pasos del mismo módulo. Los distractores evitan el paso siguiente, cuyo
  resultado suele refinar el pedido y dejaría dos opciones defendibles
  (`_distractor_indices`). Con esto pasan de evocar a reconocer (sigue siendo
  «Recordar» en Bloom), y por eso cambió la versión del instrumento.
- Las respuestas **numéricas** (A7 de transferencia, p. ej. «3») sólo admiten un
  número (`formato_respuesta: "numero"`); punto o coma decimal valen igual.
- Las **formas** usan casillas por eje (punto 1).
- Lo que queda como texto libre son pocos casos sin forma ni número; siguen
  aceptando mayúsculas, acentos y alias.

---

## 7. Recorrido guiado en una sola columna, con lecciones

**Críticas.**

- No explica bien los conceptos: suelta la matriz X sin contexto y pregunta por
  `d_model` sin decir qué es.
- Asume conocimiento que no se tiene. El alumno puede hacer *sólo* este módulo.
- Tres ventanas (imagen, explicación, pregunta) y no se sabe a qué atender.
- Debería empezar intuitivo, ir paso a paso y terminar con la pregunta.

**Qué se hizo.**

- Contenido nuevo por paso, en `data/aprendizaje/alineacion.json` →
  `modules.module_3.lessons.<id del paso>`:

  ```json
  {
    "intuicion": "Analogía en lenguaje cotidiano (obligatoria).",
    "terminos": [{"termino": "d_model", "definicion": "…"}],
    "pasos": [{"texto": "Qué se hace (obligatorio).", "formula": "opcional"}],
    "ejemplo": {"titulo": "…", "lineas": ["…", "…"]},
    "clave": "Una frase para recordar."
  }
  ```

  `LearningModuleCatalog._merge_lessons` lo valida y lo copia a
  `step["lesson"]`.
- Vista nueva `view/qml/components/GuidedLessonView.qml`, una sola columna
  desplazable que se lee de arriba abajo:
  1. La idea
  2. Términos que necesitas
  3. Míralo (la visualización de siempre)
  4. Paso a paso
  5. Con números
  6. Resumen del paso (recibe, operación, por qué, qué cambia, produce, forma)
  7. Comprueba lo que entendiste (la pregunta va **al final**)
- `ModuleGuidedTourScreen.qml` decide por módulo (`lessonMode`). Con lecciones
  usa la vista nueva; sin ellas, el recorrido de tres paneles de antes (dentro
  de un `Loader`). En modo lección se oculta «Reproducir recorrido», porque
  avanzar solo cada 9 s no deja leer.
- El módulo 3 introduce **toda** la terminología que usa: token, vector,
  embedding, posición, matriz, T, d_model, B, la forma `[B, T, d_model]`,
  producto de matrices y su regla de formas, Q/K/V, d_k/d_v, transpuesta,
  producto punto, score, √d_k, saturar, exponencial, softmax, suma ponderada,
  contexto y cabeza. Todos los ejemplos siguen «el banco del río» con números
  que cuadran de un paso al siguiente (scores [0, 1, 2] → [0, 0.5, 1] →
  pesos ≈ [0.19, 0.31, 0.51] → salida ≈ 3.8).
- El «Resumen del paso» muestra los mismos campos del paso (`operation`, `why`,
  `change`, `output`, `dimensions`) con los que el banco arma los reactivos B y
  I. Antes, «Cambio» y «Resultado» se ocultaban hasta responder la predicción.

**Reglas para escribir las lecciones de otro módulo.**

- Ningún ejemplo de la lección debe usar los números de su propia comprobación
  (`step_checks`), ni los del pre o el post (`challenges`, `post_variants`,
  `transfer_items`). La lección enseña el procedimiento; la comprobación y los
  tests lo miden con otros números.
- Define cada término **antes** de usarlo. Si el módulo puede tomarse solo,
  el paso 1 debe traer el vocabulario de los módulos anteriores que se necesite.
- La intuición va primero y sin fórmulas; las fórmulas van en «Paso a paso».
- Para escribir el contenido sin reformatear `alineacion.json` (tiene sangrías
  hechas a mano), inserta sólo el fragmento del módulo, como hizo el script
  del módulo 3: buscar `"module_N": {`, reemplazar `"lab_challenges": [...]` con
  `json.JSONDecoder().raw_decode` y agregar `"lessons"` justo después.

## 8. Un laboratorio que prepara para el post-test

**Críticas.** El laboratorio debería ayudar a mejorar en el post-test y no lo
hace. Las preguntas son buenas, pero ni el seguimiento ni el laboratorio
preparan para responderlas.

**Causa.** Los `lab_challenges` del módulo 3 eran cualitativos («¿qué se suaviza
al escalar?»), mientras que el post-test pide calcular: la forma de QKᵀ, un
score escalado, una suma ponderada, la forma de la salida.

**Qué se hizo.** Los ocho retos del laboratorio del módulo 3 ahora practican
**la misma habilidad** que el reto del mismo índice en el test, con números
propios:

| Reto | Habilidad (igual que el reactivo) | Números del laboratorio |
|---|---|---|
| m3_l1 | Forma del mapa QKᵀ | 4 consultas × 4 claves de 8 → 4 × 4 |
| m3_l2 | Escalar por √d_k | d_k = 25, score 10 → 2 |
| m3_l3 | Leer una fila de pesos | 0.2, 0.2, 0.6 → el tercero; suman 1 |
| m3_l4 | Suma ponderada | 40 % y 60 % de 5 y 10 → 8 |
| m3_l5 | Papeles de Q, K y V | se compara la Key; se mezcla el Value |
| m3_l6 | W fijas, Q/K/V cambian | cambia la frase → cambian Q, K y V |
| m3_l7 | Softmax por fila con máscara | −∞ → peso 0; la fila suma 1 |
| m3_l8 | Forma de la salida | T = 4, d_v = 8 → [4, 8] |

Cada `explanation` resuelve el ejercicio paso a paso. Los números no aparecen
en el pre, el post ni en las comprobaciones del recorrido, y la redacción pasa
la prueba anti-ensayo
(`test_los_retos_del_laboratorio_no_aparecen_en_la_evaluacion`: similitud
< 0.58 con cualquier enunciado del test). Si un reto nuevo no pasa esa prueba,
cambia la redacción y no el umbral: el umbral evita que el laboratorio se
convierta en un ensayo de las respuestas.

**Para los otros módulos.** Revisa cada `challenges[i]` (lo que mide el test) y
escribe `lab_challenges[i]` con la misma operación, otros números y otra
redacción. El `concept_id` debe coincidir con el del reto del mismo índice: el
laboratorio elige el reto por índice según el paso que se observa (mapa en
`ModuleLaboratoryScreen.challengeForCurrentStep`).

## 9. Exportar los resultados al terminar el módulo

**Crítica.** Al final del módulo debería haber un botón para guardar un archivo
ligero con los resultados: sirve si falla la red y se puede subir a la página
web donde se aplica el SUS.

**Qué se hizo.**

- Botón **Exportar mis resultados** en `ModuleResultsScreen.qml`. Abre un diálogo
  de guardado en Documentos con el nombre
  `resultados_module_3.tvresultados.json`.
- `CourseController.exportarResultados(module_id, destino, apodo)` arma el
  archivo con `model/aprendizaje/exportacion_resultados.py`, sin Qt. Pesa unos
  6–7 KB y contiene:
  - el estudiante (nombre, matrícula y el apodo de la clase si está en una)
  - el módulo
  - pre y post: porcentaje, instrumento y, por reactivo, código, concepto,
    nivel, Bloom y puntaje
  - si son comparables, la diferencia y la ganancia normalizada
  - el porcentaje por concepto
  - la actividad en el recorrido y el laboratorio

  No lleva enunciados ni respuestas escritas.
- **Página web** (`Pagina_web`): la encuesta tiene una «Parte III · opcional»
  para subir ese archivo. El navegador lo lee y envía sólo los puntajes, sin
  nombre ni apodo. `api/encuesta.php` lo vuelve a filtrar campo por campo
  (`resultados_herramienta`) y lo guarda en el registro como `herramienta`.
  `api/resultados.php` agrega al CSV las columnas `herramienta_modulo`, `_pre`,
  `_post`, `_ganancia` y `_comparable`; el JSON trae todo.

**Para desplegar.** Recompila la página (`npm.cmd run build`) y sube
`dist/encuesta/` y `public/api/encuesta.php` y `resultados.php` a `/www`.
No toques `api/datos/` ni `config.php`.

---

## Verificación

- `tests/view/test_reactivos_modulares.py` cubre la forma por ejes, el banco de
  opciones, el número, relacionar en cualquier orden y el arrastre con eventos
  de ratón reales.
- `tests/viewmodel/test_module_course.py::test_exportar_resultados_genera_un_archivo_ligero_sin_enunciados`
  cubre la exportación.
- Las pruebas de vista del recorrido (`test_module_screens.py`) siguen
  encontrando `moduleGuidedCheck`, `moduleGuidedDefinition` y
  `moduleGuidedVisualization` en el modo lección.
- **Para revisar la vista sin tocar los datos reales**, importa
  `tests.conftest` antes que cualquier módulo del proyecto (redirige `data/` y
  `QSettings` a un temporal). Construir `MainViewModel()` sin esa guarda
  reescribe `data/progreso/progreso_modular.json`.
