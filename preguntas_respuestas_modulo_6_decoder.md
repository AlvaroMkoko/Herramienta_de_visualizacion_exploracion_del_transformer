# Preguntas y respuestas correctas — Módulo 6: Decoder

Generado por `tools/generar_preguntas_modulo.py`. Corresponde a la versión 16 del banco modular. El pre-test y el post-test tienen 25 reactivos disponibles cada uno; cada intento selecciona 15.

## Pregunta ancla

**Pregunta:** Al traducir «the cat» a «el gato», ¿cómo predice el decoder «gato» sin espiar la respuesta y sin olvidar la frase en inglés?

**Ejemplo:** Objetivo [el, gato, EOS]; entrada desplazada [BOS, el, gato]. La máscara causal de T = 3 deja ver {0} en la fila 0, {0, 1} en la fila 1 y {0, 1, 2} en la fila 2: 6 de 9 celdas. La posición 1 («el») predice «gato» mirando sólo [BOS, el] y, mediante cross-attention, las 2 posiciones de la memoria de «the cat». Si se omiten los ejes de batch y cabeza, el mapa completo mide [3, 2].

**Cierre:** Al entrenar, el decoder recibe la frase desplazada, y la máscara causal oculta lo que aún no debe ver. Si se desactiva esa máscara al entrenar, ¿qué puede aprender el decoder?

**Respuesta correcta:** A copiar el token que debe predecir desde posiciones futuras

## Comprobaciones del recorrido guiado

### R1. Prefijo desplazado

**Pregunta:** La entrada del decoder empieza con BOS y no incluye el último objetivo. Para el objetivo [yo, como, EOS], ¿qué entrada desplazada recibe?

**Respuesta correcta:** [BOS, yo, como]

### R2. Máscara triangular

**Pregunta:** Una máscara causal permite, en cada fila, su propia posición y las anteriores. En una de T = 3, ¿cuántas celdas quedan visibles?

**Respuesta correcta:** 6

### R3. Masked Self-Attention

**Pregunta:** Con la máscara, cada posición usa sólo su lugar y los anteriores. Contando desde 0, ¿a qué posiciones atiende la posición 1?

**Respuesta correcta:** 0 y 1

### R4. Primer Add & Norm

**Pregunta:** Add & Norm suma la entrada de una subcapa con el resultado de esa subcapa. ¿Qué suma el primero del decoder?

**Respuesta correcta:** La entrada de la subcapa y su contexto causal

### R5. Cross-Attention

**Pregunta:** En cross-attention, las filas corresponden al destino y las columnas a la fuente. Con T_tgt = 3 y T_src = 4, ¿qué forma tiene el mapa de una cabeza?

**Respuesta correcta:** [3, 4]

### R6. Segundo Add & Norm

**Pregunta:** Ya se completaron self-attention y cross-attention, cada una con su Add & Norm. Al terminar esta etapa, ¿cuántos ha recorrido la capa?

**Respuesta correcta:** 2

### R7. FFN y tercer Add & Norm

**Pregunta:** Cada subcapa principal tiene su Add & Norm: self-attention, cross-attention y FFN. ¿Cuántas subcapas con Add & Norm tiene una capa completa?

**Respuesta correcta:** 3

### R8. Salida de la pila

**Pregunta:** Cada capa del decoder conserva la forma [B, T_tgt, d_model]. Tras N capas, ¿qué forma tiene la salida para B = 1, T_tgt = 5 y d_model = 128?

**Respuesta correcta:** [1, 5, 128]

## Pre-test

### PRE-B1

**Pregunta:** Contexto — A diferencia del encoder, el decoder debe producir una frase, y aprende a hacerlo recibiendo la frase de destino de una manera especial.

¿Qué descripción explica correctamente qué recibe el decoder como entrada?

- Es la frase de destino corrida un lugar y con BOS al inicio, de modo que cada posición deba predecir el token siguiente.
- Da contexto a cada posición usando sólo su lugar y los anteriores del prefijo.
- Conecta las dos partes del modelo: Q sale del decoder; K y V salen de la memoria del encoder.
- Son tres sumas Add & Norm, que rodean a self-attention, a cross-attention y a la FFN.

**Clave:** Es la frase de destino corrida un lugar y con BOS al inicio, de modo que cada posición deba predecir el token siguiente.

### PRE-B2

**Pregunta:** Contexto — Después de las dos atenciones, cada posición del decoder pasa por una subcapa más, que trabaja por posición.

¿Qué descripción explica correctamente qué hace esa subcapa?

- Transforma cada posición, por separado y de forma no lineal, después de las dos atenciones.
- Son tres sumas Add & Norm, que rodean a self-attention, a cross-attention y a la FFN.
- Es un vector por posición de destino, todavía sin palabras, listo para proyectarse al vocabulario.
- Da contexto a cada posición usando sólo su lugar y los anteriores del prefijo.

**Clave:** Transforma cada posición, por separado y de forma no lineal, después de las dos atenciones.

### PRE-B3

**Pregunta:** Contexto — Dentro del decoder, cada posición puede atender a otras posiciones de la misma frase de destino.

Lee la afirmación y decide si es verdadera o falsa:

Masked self-attention da contexto a cada posición usando sólo el prefijo permitido.

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-B4

**Pregunta:** Contexto — El decoder también necesita información de la frase de origen, que ya procesó el encoder.

Lee la afirmación y decide si es verdadera o falsa:

En cross-attention, Q, K y V se obtienen sólo de posiciones futuras del decoder.

- Verdadero
- Falso

**Clave:** Falso

### PRE-B5

**Pregunta:** Contexto — Cada concepto de este módulo resuelve un problema distinto. Revisa qué hace cada uno.

Selecciona las DOS asociaciones coherentes entre concepto y función.

- Máscara causal: Bloquea las posiciones futuras para que, al entrenar, el decoder no pueda ver la respuesta que debe predecir.
- Tres conexiones residuales: Son tres sumas Add & Norm, que rodean a self-attention, a cross-attention y a la FFN.
- Máscara causal: Son tres sumas Add & Norm, que rodean a self-attention, a cross-attention y a la FFN.
- Tres conexiones residuales: Bloquea las posiciones futuras para que, al entrenar, el decoder no pueda ver la respuesta que debe predecir.

**Clave:** Máscara causal: Bloquea las posiciones futuras para que, al entrenar, el decoder no pueda ver la respuesta que debe predecir. · Tres conexiones residuales: Son tres sumas Add & Norm, que rodean a self-attention, a cross-attention y a la FFN.

### PRE-B6

**Pregunta:** Contexto — Una capa del decoder es una cadena: la salida de cada etapa alimenta a la siguiente.

Completa el flujo: Primer Add & Norm → ________ → Segundo Add & Norm.

**Clave:** Cross-Attention

### PRE-B7

**Pregunta:** Contexto — Cada etapa resuelve un problema distinto: no ver el futuro, consultar la fuente o conservar el estado.

Relaciona cada etapa con el motivo por el que se realiza.

**Clave:** Prefijo desplazado → Cada posición debe predecir el token que sigue, y no el que recibe · Masked Self-Attention → Construye el contexto de cada posición usando sólo el prefijo · Cross-Attention → Permite buscar en la frase de origen lo que se necesita para continuar · FFN y tercer Add & Norm → Procesa por posición toda la información que se reunió

### PRE-B8

**Pregunta:** Contexto — En las formas, B es el número de ejemplos, T_tgt el de posiciones del destino, T_src el de la fuente, h el de cabezas y d_model el ancho.

Al terminar el paso «Salida de la pila», ¿qué forma (dimensiones) tiene el tensor que se obtiene? Escríbela eje por eje con los símbolos del recorrido.

**Clave:** [B,T_tgt,d_model]

### PRE-I1

**Pregunta:** Contexto — El punto de partida es el prefijo del decoder. Ordena las operaciones usando la salida de una como entrada de la siguiente.

Ordena las etapas según el flujo real de información.

**Clave:** Prefijo desplazado → Máscara triangular → Masked Self-Attention → Primer Add & Norm

### PRE-I2

**Pregunta:** Contexto — El punto de partida es el estado tras la primera atención. Ordena las operaciones que le siguen.

Ordena las etapas según el flujo real de información.

**Clave:** Cross-Attention → Segundo Add & Norm → FFN y tercer Add & Norm → Salida de la pila

### PRE-I3

**Pregunta:** Contexto — Aquí debes relacionar cada transformación con el resultado inmediato que deja, no con el de pasos posteriores.

Relaciona cada transformación con la información que produce.

**Clave:** Prefijo desplazado → Secuencia destino de entrada · Masked Self-Attention → Contexto causal · Cross-Attention → Contexto cruzado · FFN y tercer Add & Norm → Salida de capa

### PRE-I4

**Pregunta:** Contexto — Sigue qué cambia realmente en cada etapa: pueden cambiar las posiciones visibles, los valores o la fuente de información.

Relaciona cada etapa con el cambio observable que produce.

**Clave:** Máscara triangular → Cada fila queda limitada a su lugar y a los anteriores · Primer Add & Norm → Termina la primera subcapa, con la misma forma · Segundo Add & Norm → Termina la segunda subcapa, con la misma forma · Salida de la pila → La forma se mantiene igual en toda la pila

### PRE-I5

**Pregunta:** Contexto — Una justificación correcta explica para qué es necesaria una operación; no basta con repetir su nombre.

Selecciona las DOS explicaciones que justifican correctamente su etapa.

- Masked Self-Attention: Construye el contexto de cada posición usando sólo el prefijo
- Segundo Add & Norm: Reúne en un solo estado lo aportado por el prefijo y por la fuente
- Masked Self-Attention: Reúne en un solo estado lo aportado por el prefijo y por la fuente
- Segundo Add & Norm: Construye el contexto de cada posición usando sólo el prefijo

**Clave:** Masked Self-Attention: Construye el contexto de cada posición usando sólo el prefijo · Segundo Add & Norm: Reúne en un solo estado lo aportado por el prefijo y por la fuente

### PRE-I6

**Pregunta:** Contexto — Para decidir si dos etapas son consecutivas, comprueba que la salida de la primera sea la entrada que necesita la segunda.

Lee la afirmación y decide si es verdadera o falsa:

En el flujo del módulo, después de «Máscara triangular» ocurre «Masked Self-Attention».

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-I7

**Pregunta:** Contexto — La pregunta ya indica la entrada de una operación. Elige su salida inmediata, no el resultado final del decoder.

Completa: «FFN y tercer Add & Norm» recibe El estado integrado y produce ________.

**Clave:** Salida de capa

### PRE-I8

**Pregunta:** Contexto — El propósito explica por qué hace falta la operación; no es una descripción de sus pasos.

¿Por qué se realiza «Segundo Add & Norm»?

- Reúne en un solo estado lo aportado por el prefijo y por la fuente
- Cada posición debe predecir el token que sigue, y no el que recibe
- Evita copiar tokens futuros, que al generar todavía no existen
- Procesa por posición toda la información que se reunió

**Clave:** Reúne en un solo estado lo aportado por el prefijo y por la fuente

### PRE-I9

**Pregunta:** Contexto — Un par entrada→salida sólo es válido si ambos pertenecen a la misma etapa; no mezcles etapas.

Selecciona los DOS pares que describen la entrada y la salida de una misma etapa del recorrido.

- BOS y los tokens anteriores → Secuencia destino de entrada
- La salida de una capa → Estado final decoder
- BOS y los tokens anteriores → Estado final decoder
- La salida de una capa → Secuencia destino de entrada

**Clave:** BOS y los tokens anteriores → Secuencia destino de entrada · La salida de una capa → Estado final decoder

### PRE-A1

**Pregunta:** Contexto — La máscara causal forma un triángulo: cada fila permite una posición más que la anterior.

Resuelve sin opciones: En una máscara causal, la fila i permite i + 1 posiciones: la fila 0 permite 1, la fila 1 permite 2, y así sucesivamente. Para T=4, ¿cuántas quedan permitidas en total?

**Clave:** 10

### PRE-A2

**Pregunta:** Contexto — Las posiciones se cuentan desde 0, y una posición también puede consultarse a sí misma.

La máscara causal permite a cada posición consultar su lugar y los anteriores. Contando desde 0, ¿qué claves puede consultar la posición 2?

- 0, 1 y 2
- 2 y 3
- Sólo 0
- 0,1,2 y 3

**Clave:** 0, 1 y 2

### PRE-A3

**Pregunta:** Contexto — Cada opción une un dato con su resultado. Evalúa cada una por separado.

Selecciona las DOS opciones en las que el dato y su resultado están emparejados correctamente.

- Cross-attention con 3 destinos y 8 fuentes → mapa [3, 8].
- Q en cross-attention → sale del estado del decoder.
- Cross-attention con 3 destinos y 8 fuentes → mapa [8, 3].
- Q en cross-attention → sale de la máscara causal.

**Clave:** Cross-attention con 3 destinos y 8 fuentes → mapa [3, 8]. · Q en cross-attention → sale del estado del decoder.

### PRE-A4

**Pregunta:** Contexto — Las cuatro tarjetas forman una sola capa. Ordénalas de modo que la salida de cada una sirva a la siguiente.

Reconstruye el orden necesario para que la transformación sea válida.

**Clave:** Máscara triangular → Masked Self-Attention → Primer Add & Norm → Cross-Attention

### PRE-A5

**Pregunta:** Contexto — Resuelve cada situación por separado. Recuerda qué bloquea la máscara y de dónde viene cada matriz.

Relaciona cada situación con la conclusión correcta. Cada conclusión se usa una sola vez.

**Clave:** Al entrenar, la entrada desplazada contiene la respuesta de las posiciones siguientes; la máscara causal las oculta. Al desactivarla, ¿qué atajo puede aprender el decoder? → Copiar información del token que debe predecir · Cada subcapa principal termina con su Add & Norm: self-attention, cross-attention y FFN. ¿Cuántos bloques Add & Norm hay en una capa del decoder? → 3 · La entrada desplazada comienza con BOS y no incluye el último objetivo. Con objetivo [hola,mundo,EOS], ¿cuál es la entrada que recibe el decoder? → [BOS,hola,mundo]

### PRE-A6

**Pregunta:** Contexto — Identifica a qué secuencia corresponden las Keys, y a qué se le aplica realmente la máscara causal.

Lee la afirmación y decide si es verdadera o falsa:

Caso: en cross-attention, el número de columnas del mapa depende de la longitud de la frase fuente, no de la frase destino.

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-A7

**Pregunta:** Contexto — Una tabla T × T tiene T² celdas; las visibles forman un triángulo con la diagonal.

Responde sin opciones: En una máscara causal de T = 6 hay T × T celdas, y 1 + 2 + … + T quedan visibles. ¿Cuántas celdas quedan bloqueadas?

**Clave:** 15

### PRE-A8

**Pregunta:** Contexto — Compara qué es cada eje del estado final antes de pasar por la capa de salida.

El estado final tiene forma [B,T_tgt,d_model] y aún no pasa por la capa de salida. ¿Qué representa cada una de sus filas?

- Una posición destino contextualizada
- Una palabra fija del vocabulario
- Una cabeza completa
- Una máscara booleana

**Clave:** Una posición destino contextualizada

## Post-test

### POST-B1

**Pregunta:** Contexto — A diferencia del encoder, el decoder debe producir una frase, y aprende a hacerlo recibiendo la frase de destino de una manera especial.

¿Qué operación prepara la entrada del decoder?

- Preparar el prefijo que entrará al decoder
- Permitir la diagonal y las posiciones anteriores, y bloquear las posteriores
- Calcular los scores, bloquear los futuros y aplicar softmax
- Sumar el contexto causal con su entrada y normalizar

**Clave:** Preparar el prefijo que entrará al decoder

### POST-B2

**Pregunta:** Contexto — Después de las dos atenciones, cada posición del decoder pasa por una subcapa más, que trabaja por posición.

¿Qué operación se realiza en la última subcapa de la capa del decoder?

- Expandir, activar y proyectar cada posición; después sumar y normalizar
- Repetir la capa N veces, siempre con la misma memoria
- Preparar el prefijo que entrará al decoder
- Permitir la diagonal y las posiciones anteriores, y bloquear las posteriores

**Clave:** Expandir, activar y proyectar cada posición; después sumar y normalizar

### POST-B3

**Pregunta:** Contexto — Dentro del decoder, cada posición puede atender a otras posiciones de la misma frase de destino.

Lee la afirmación y decide si es verdadera o falsa:

Masked self-attention permite atender sin restricción a tokens futuros.

- Verdadero
- Falso

**Clave:** Falso

### POST-B4

**Pregunta:** Contexto — El decoder también necesita información de la frase de origen, que ya procesó el encoder.

Lee la afirmación y decide si es verdadera o falsa:

En cross-attention, Q viene del decoder; K y V, de la memoria del encoder.

- Verdadero
- Falso

**Clave:** Verdadero

### POST-B5

**Pregunta:** Contexto — Cada concepto de este módulo resuelve un problema distinto. Revisa qué hace cada uno.

Selecciona las DOS asociaciones coherentes entre concepto y función.

- Cross-Attention: Conecta las dos partes del modelo: Q sale del decoder; K y V salen de la memoria del encoder.
- Pila decoder: Repite la capa N veces y conserva la forma [B,T_tgt,d_model].
- Cross-Attention: Repite la capa N veces y conserva la forma [B,T_tgt,d_model].
- Pila decoder: Conecta las dos partes del modelo: Q sale del decoder; K y V salen de la memoria del encoder.

**Clave:** Cross-Attention: Conecta las dos partes del modelo: Q sale del decoder; K y V salen de la memoria del encoder. · Pila decoder: Repite la capa N veces y conserva la forma [B,T_tgt,d_model].

### POST-B6

**Pregunta:** Contexto — Una capa del decoder es una cadena: la salida de cada etapa alimenta a la siguiente.

Completa el flujo: Cross-Attention → ________ → FFN y tercer Add & Norm.

**Clave:** Segundo Add & Norm

### POST-B7

**Pregunta:** Contexto — Cada etapa resuelve un problema distinto: no ver el futuro, consultar la fuente o conservar el estado.

Relaciona cada etapa con el motivo por el que se realiza.

**Clave:** Máscara triangular → Evita copiar tokens futuros, que al generar todavía no existen · Primer Add & Norm → Conserva el estado que ya se tenía antes de esta atención · Segundo Add & Norm → Reúne en un solo estado lo aportado por el prefijo y por la fuente · Salida de la pila → Refina poco a poco el estado con el que se hará la predicción

### POST-B8

**Pregunta:** Contexto — En las formas, B es el número de ejemplos, T_tgt el de posiciones del destino, T_src el de la fuente, h el de cabezas y d_model el ancho.

Al terminar el paso «Prefijo desplazado», ¿qué forma (dimensiones) tiene el tensor que se obtiene? Escríbela eje por eje con los símbolos del recorrido.

**Clave:** [B,T_tgt]

### POST-I1

**Pregunta:** Contexto — El punto de partida es el prefijo del decoder. Ordena las operaciones usando la salida de una como entrada de la siguiente.

Ordena las etapas según el flujo real de información.

**Clave:** Máscara triangular → Masked Self-Attention → Primer Add & Norm → Cross-Attention

### POST-I2

**Pregunta:** Contexto — El punto de partida es el estado tras la primera atención. Ordena las operaciones que le siguen.

Ordena las etapas según el flujo real de información.

**Clave:** Primer Add & Norm → Cross-Attention → Segundo Add & Norm → FFN y tercer Add & Norm

### POST-I3

**Pregunta:** Contexto — Aquí debes relacionar cada transformación con el resultado inmediato que deja, no con el de pasos posteriores.

Relaciona cada transformación con la información que produce.

**Clave:** Máscara triangular → Máscara causal · Primer Add & Norm → Estado causal · Segundo Add & Norm → Estado integrado · Salida de la pila → Estado final decoder

### POST-I4

**Pregunta:** Contexto — Sigue qué cambia realmente en cada etapa: pueden cambiar las posiciones visibles, los valores o la fuente de información.

Relaciona cada etapa con el cambio observable que produce.

**Clave:** Prefijo desplazado → La entrada y el objetivo quedan corridos una posición entre sí · Masked Self-Attention → Los pesos hacia posiciones futuras quedan en cero · Cross-Attention → El estado incorpora información que viene del encoder · FFN y tercer Add & Norm → Termina una capa completa del decoder

### POST-I5

**Pregunta:** Contexto — Una justificación correcta explica para qué es necesaria una operación; no basta con repetir su nombre.

Selecciona las DOS explicaciones que justifican correctamente su etapa.

- Máscara triangular: Evita copiar tokens futuros, que al generar todavía no existen
- FFN y tercer Add & Norm: Procesa por posición toda la información que se reunió
- Máscara triangular: Procesa por posición toda la información que se reunió
- FFN y tercer Add & Norm: Evita copiar tokens futuros, que al generar todavía no existen

**Clave:** Máscara triangular: Evita copiar tokens futuros, que al generar todavía no existen · FFN y tercer Add & Norm: Procesa por posición toda la información que se reunió

### POST-I6

**Pregunta:** Contexto — Para decidir si dos etapas son consecutivas, comprueba que la salida de la primera sea la entrada que necesita la segunda.

Lee la afirmación y decide si es verdadera o falsa:

En el flujo del módulo, después de «Máscara triangular» ocurre «Cross-Attention».

- Verdadero
- Falso

**Clave:** Falso

### POST-I7

**Pregunta:** Contexto — La pregunta ya indica la entrada de una operación. Elige su salida inmediata, no el resultado final del decoder.

Completa: «Cross-Attention» recibe Q del decoder; K y V de la memoria del encoder y produce ________.

**Clave:** Contexto cruzado

### POST-I8

**Pregunta:** Contexto — El propósito explica por qué hace falta la operación; no es una descripción de sus pasos.

¿Por qué se realiza «Masked Self-Attention»?

- Construye el contexto de cada posición usando sólo el prefijo
- Cada posición debe predecir el token que sigue, y no el que recibe
- Conserva el estado que ya se tenía antes de esta atención
- Procesa por posición toda la información que se reunió

**Clave:** Construye el contexto de cada posición usando sólo el prefijo

### POST-I9

**Pregunta:** Contexto — Un par entrada→salida sólo es válido si ambos pertenecen a la misma etapa; no mezcles etapas.

Selecciona los DOS pares que describen la entrada y la salida de una misma etapa del recorrido.

- La longitud T_tgt del prefijo → Máscara causal
- El estado integrado → Salida de capa
- La longitud T_tgt del prefijo → Salida de capa
- El estado integrado → Máscara causal

**Clave:** La longitud T_tgt del prefijo → Máscara causal · El estado integrado → Salida de capa

### POST-A1

**Pregunta:** Contexto — La máscara causal forma un triángulo: cada fila permite una posición más que la anterior.

Resuelve sin opciones: En una máscara causal, la fila i permite i + 1 posiciones, de modo que el total es 1 + 2 + … + T. Para T = 5, ¿cuántas quedan permitidas?

**Clave:** 15

### POST-A2

**Pregunta:** Contexto — Las posiciones se cuentan desde 0, y una posición también puede consultarse a sí misma.

La máscara causal permite a cada posición su lugar y los anteriores. En una secuencia de 5, contando desde 0, ¿qué claves permite a la posición 3?

- 0, 1, 2 y 3
- 3 y 4
- Sólo 0
- 0, 1, 2, 3 y 4

**Clave:** 0, 1, 2 y 3

### POST-A3

**Pregunta:** Contexto — Cada opción une un dato con su resultado. Evalúa cada una por separado.

Selecciona las DOS opciones en las que el dato y su resultado están emparejados correctamente.

- Cross-attention con 2 destinos y 6 fuentes → mapa [2, 6].
- K y V en cross-attention → salen de la memoria del encoder.
- Cross-attention con 2 destinos y 6 fuentes → mapa [2, 2].
- K y V en cross-attention → salen sólo de WO.

**Clave:** Cross-attention con 2 destinos y 6 fuentes → mapa [2, 6]. · K y V en cross-attention → salen de la memoria del encoder.

### POST-A4

**Pregunta:** Contexto — Las cuatro tarjetas forman una sola capa. Ordénalas de modo que la salida de cada una sirva a la siguiente.

Reconstruye el orden necesario para que la transformación sea válida.

**Clave:** Masked Self-Attention → Primer Add & Norm → Cross-Attention → Segundo Add & Norm

### POST-A5

**Pregunta:** Contexto — Resuelve cada situación por separado. Recuerda qué bloquea la máscara y de dónde viene cada matriz.

Relaciona cada situación con la conclusión correcta. Cada conclusión se usa una sola vez.

**Clave:** La máscara causal oculta la respuesta que contiene la entrada desplazada. Un modelo se entrenó sin ella: su pérdida es casi cero, pero genera texto incoherente. ¿Qué atajo aprendió? → Copiar información del token que debía predecir · Cada subcapa principal termina con su Add & Norm: self-attention, cross-attention y FFN. Al dibujar una capa del decoder, ¿cuántos bloques debes incluir? → 3 · La entrada desplazada comienza con BOS y no incluye el último objetivo. Con objetivo [buenos, días, EOS], ¿qué recibe el decoder durante el entrenamiento? → [BOS,buenos,días]

### POST-A6

**Pregunta:** Contexto — Identifica a qué secuencia corresponden las Keys, y a qué se le aplica realmente la máscara causal.

Lee la afirmación y decide si es verdadera o falsa:

Caso: en cross-attention se aplica la máscara causal sobre la memoria del encoder para que el decoder no vea las palabras fuente posteriores.

- Verdadero
- Falso

**Clave:** Falso

### POST-A7

**Pregunta:** Contexto — Una tabla T × T tiene T² celdas; las visibles forman un triángulo con la diagonal.

Responde sin opciones: En una máscara causal de T = 7 hay T × T celdas, y 1 + 2 + … + T quedan visibles. ¿Cuántas celdas quedan bloqueadas?

**Clave:** 21

### POST-A8

**Pregunta:** Contexto — Compara qué es cada eje del estado final antes de pasar por la capa de salida.

El estado final tiene forma [B, T_tgt, d_model] y aún no pasa por la capa de salida. ¿Qué representa la fila de la posición 2?

- Esa posición destino, contextualizada por su prefijo y por la fuente
- Una palabra fija del vocabulario
- Una cabeza completa
- Una máscara booleana

**Clave:** Esa posición destino, contextualizada por su prefijo y por la fuente

## Retos del laboratorio

### LAB-m6_l1

**Pregunta:** En el mapa causal, cada fila permite su lugar y los anteriores. Para T = 2, ¿cuántas celdas quedan permitidas, y por qué se bloquean las demás?

**Respuesta correcta:** 3; las posiciones posteriores aún no existen al generar

**Explicación:** 1 + 2 = 3. Una posición puede usar su propio estado y el pasado, pero no información futura.

### LAB-m6_l2

**Pregunta:** Lee un mapa causal de 6 filas: la primera tiene una sola celda permitida y la última, seis. ¿Cuáles están permitidas en la fila numerada 4?

**Respuesta correcta:** 0, 1, 2, 3 y 4

**Explicación:** La región permitida crece con el prefijo: cada fila llega hasta su propia posición.

### LAB-m6_l3

**Pregunta:** Selecciona un token de salida y mira su fila, que recorre la frase de origen. Si hay 2 tokens de salida y 9 de entrada, ¿cómo se escribe el tamaño del mapa, y qué dice cada celda?

**Respuesta correcta:** [2, 9]; cuánto consulta ese destino a cada posición fuente

**Explicación:** Cada fila parte de una Query del decoder y recorre las Keys de la memoria del encoder.

### LAB-m6_l4

**Pregunta:** Observa el paso de cross-attention. Las Queries permanecen en el decoder. ¿De dónde llegan las Keys y los Values?

**Respuesta correcta:** De la memoria: las posiciones de la fuente

**Explicación:** En cross-attention, K y V provienen de la memoria del encoder.

### LAB-m6_l5

**Pregunta:** Con el interruptor de máscara causal apagado aparecen pesos hacia la derecha de la diagonal. ¿Por qué esa vista es sólo un contraste?

**Respuesta correcta:** Permite usar información futura que no existe al generar

**Explicación:** Las celdas futuras pueden recibir peso sin máscara, pero una inferencia autoregresiva no dispone de esos tokens.

### LAB-m6_l6

**Pregunta:** Las tres rutas de atajo del decoder rodean subcapas distintas. ¿Qué actualizaciones se reincorporan al estado?

**Respuesta correcta:** Contexto causal, contexto de fuente y transformación FFN

**Explicación:** Cada subcapa principal aporta una actualización que se suma a su entrada mediante un atajo residual.

### LAB-m6_l7

**Pregunta:** Ejemplo: con objetivo [muy, bien, EOS], el decoder recibe [BOS, muy, bien]. ¿Qué tarea aprende la posición de «muy»?

**Respuesta correcta:** Predecir «bien» a partir del prefijo conocido

**Explicación:** El desplazamiento alinea cada prefijo de entrada con el token que debe predecirse a continuación.

### LAB-m6_l8

**Pregunta:** En el paso de la pila, la salida final aún son estados y no probabilidades. ¿Qué operación falta para puntuar palabras?

**Respuesta correcta:** La proyección desde d_model hacia el vocabulario

**Explicación:** Los estados del decoder deben pasar por la capa de salida antes de convertirse en logits por token posible.
