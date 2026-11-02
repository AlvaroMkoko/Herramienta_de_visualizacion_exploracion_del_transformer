# Preguntas y respuestas correctas — Módulo 7: Generación de la salida

Generado por `tools/generar_preguntas_modulo.py`. Corresponde a la versión 16 del banco modular. El pre-test y el post-test tienen 25 reactivos disponibles cada uno; cada intento selecciona 15.

## Pregunta ancla

**Pregunta:** Si al final del decoder el modelo duda entre «perro», «gato» y «pez», ¿cómo decide qué palabra escribir y cómo cambia esa decisión con la temperatura?

**Ejemplo:** Logits [perro = 2.0, gato = 1.0, pez = 0.0]. Softmax con T = 1 ≈ [0.665, 0.245, 0.090]. Con T = 0.5 los logits pasan a [4, 2, 0] y softmax ≈ [0.867, 0.117, 0.016]: queda más concentrada. Con Top-K = 2 se elimina «pez» y se renormaliza: ≈ [0.731, 0.269]. El token elegido se añade al prefijo y el ciclo se repite.

**Cierre:** El modelo duda entre «perro», «gato» y «pez», y dividir los logits entre T cambia la distancia entre ellos. Al mover la temperatura, ¿qué cambia y qué no?

**Respuesta correcta:** Cambia la concentración de las probabilidades; el orden de los candidatos se mantiene

## Comprobaciones del recorrido guiado

### R1. Último estado del decoder

**Pregunta:** Para generar, el modelo sólo debe predecir qué token va después del prefijo. ¿Qué fila del estado del decoder usa?

**Respuesta correcta:** La última posición del prefijo

### R2. Proyección W_vocab

**Pregunta:** W_vocab produce un puntaje por cada token del vocabulario. Si h_t tiene 128 componentes y |V| = 5 000, ¿cuántos logits produce?

**Respuesta correcta:** 5 000

### R3. Escala de temperatura

**Pregunta:** La temperatura divide cada logit entre T. Los logits [2, 1] divididos entre T = 2 quedan en:

**Respuesta correcta:** [1, 0.5]

### R4. Filtro Top-K

**Pregunta:** Top-K conserva los K logits más altos. Con Top-K = 2 sobre los logits [3, 1, 2, 0], ¿qué candidatos sobreviven?

**Respuesta correcta:** El primero y el tercero

### R5. Filtro Top-P

**Pregunta:** Top-P acumula de mayor a menor hasta alcanzar p. Con probabilidades ordenadas [0.5, 0.3, 0.2] y p = 0.7, ¿cuántos candidatos conserva?

**Respuesta correcta:** 2

### R6. Softmax final

**Pregunta:** Softmax da probabilidades iguales a logits iguales, y su suma es 1. Para los logits [1, 1, 1], ¿qué probabilidades produce?

**Respuesta correcta:** [1/3, 1/3, 1/3]

### R7. Selección del token

**Pregunta:** La selección codiciosa (argmax) toma la mayor probabilidad. Sobre [0.2, 0.7, 0.1], ¿qué token se elige?

**Respuesta correcta:** El segundo

### R8. Bucle autoregresivo

**Pregunta:** El token elegido se agrega al prefijo antes de la siguiente vuelta. Si el prefijo tiene 4 tokens y se selecciona uno nuevo, ¿qué longitud tendrá en el paso siguiente?

**Respuesta correcta:** 5

## Pre-test

### PRE-B1

**Pregunta:** Contexto — Al terminar el decoder hay un vector por posición. Para escribir el siguiente token, el modelo parte de uno de ellos.

¿Qué descripción explica correctamente qué es el estado final?

- Es el vector de d_model números de la última posición, que resume el prefijo y la entrada.
- Multiplica el estado por W_vocab para dar un puntaje a cada token del vocabulario.
- Convierte los logits en probabilidades positivas que suman 1 sobre el vocabulario.
- Conserva una cantidad fija de candidatos: los K de mayor logit.

**Clave:** Es el vector de d_model números de la última posición, que resume el prefijo y la entrada.

### PRE-B2

**Pregunta:** Contexto — Antes de elegir una palabra, se puede ajustar qué tan marcada es la diferencia entre los candidatos.

¿Qué descripción explica correctamente qué hace la temperatura?

- Divide los logits entre T para concentrar o repartir más la distribución, sin cambiar el orden de los candidatos.
- Conserva una cantidad fija de candidatos: los K de mayor logit.
- Elige un token, lo agrega al prefijo y repite el proceso hasta detenerse.
- Multiplica el estado por W_vocab para dar un puntaje a cada token del vocabulario.

**Clave:** Divide los logits entre T para concentrar o repartir más la distribución, sin cambiar el orden de los candidatos.

### PRE-B3

**Pregunta:** Contexto — Del estado final hay que pasar a un número por cada token que el modelo conoce.

Lee la afirmación y decide si es verdadera o falsa:

La proyección lineal multiplica el estado por W_vocab y da un puntaje a cada token del vocabulario.

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-B4

**Pregunta:** Contexto — Los puntajes de la capa lineal todavía no se pueden leer como probabilidades, y una función los convierte.

Lee la afirmación y decide si es verdadera o falsa:

Softmax mantiene los logits crudos y no realiza ninguna normalización.

- Verdadero
- Falso

**Clave:** Falso

### PRE-B5

**Pregunta:** Contexto — Cada concepto de este módulo resuelve un problema distinto. Revisa qué hace cada uno.

Selecciona las DOS asociaciones coherentes entre concepto y función.

- Logits: Son los puntajes crudos, de forma [B,T,|V|]: pueden ser negativos y no suman 1.
- Top-K: Conserva una cantidad fija de candidatos: los K de mayor logit.
- Logits: Conserva una cantidad fija de candidatos: los K de mayor logit.
- Top-K: Son los puntajes crudos, de forma [B,T,|V|]: pueden ser negativos y no suman 1.

**Clave:** Logits: Son los puntajes crudos, de forma [B,T,|V|]: pueden ser negativos y no suman 1. · Top-K: Conserva una cantidad fija de candidatos: los K de mayor logit.

### PRE-B6

**Pregunta:** Contexto — Generar una palabra es una cadena: la salida de cada etapa alimenta a la siguiente.

Completa el flujo: Filtro Top-K → ________ → Softmax final.

**Clave:** Filtro Top-P

### PRE-B7

**Pregunta:** Contexto — Cada etapa resuelve un problema distinto: puntuar, ajustar, filtrar, normalizar o elegir.

Relaciona cada etapa con el motivo por el que se realiza.

**Clave:** Último estado del decoder → Para generar sólo hace falta predecir un token: el siguiente · Escala de temperatura → Controla qué tan concentrada quedará la distribución · Filtro Top-P → Adapta el número de candidatos a la seguridad del modelo · Selección del token → Convierte las probabilidades en una sola decisión

### PRE-B8

**Pregunta:** Contexto — En las formas, B es el número de ejemplos, d_model el ancho del estado y |V| el tamaño del vocabulario.

Al terminar el paso «Selección del token», ¿qué forma (dimensiones) tiene el tensor que se obtiene? Escríbela eje por eje con los símbolos del recorrido.

**Clave:** [B,1]

### PRE-I1

**Pregunta:** Contexto — El punto de partida es el estado del decoder. Ordena las operaciones usando la salida de una como entrada de la siguiente.

Ordena las etapas según el flujo real de información.

**Clave:** Último estado del decoder → Proyección W_vocab → Escala de temperatura → Filtro Top-K

### PRE-I2

**Pregunta:** Contexto — El punto de partida son los logits ajustados. Ordena las operaciones que llevan hasta los candidatos finales.

Ordena las etapas según el flujo real de información.

**Clave:** Filtro Top-P → Softmax final → Selección del token → Bucle autoregresivo

### PRE-I3

**Pregunta:** Contexto — Aquí debes relacionar cada transformación con el resultado inmediato que deja, no con el de pasos posteriores.

Relaciona cada transformación con la información que produce.

**Clave:** Último estado del decoder → h_t · Escala de temperatura → Logits ajustados · Filtro Top-P → Núcleo · Selección del token → Token seleccionado

### PRE-I4

**Pregunta:** Contexto — Sigue qué cambia realmente en cada etapa: pueden cambiar los ejes, los valores o los candidatos disponibles.

Relaciona cada etapa con el cambio observable que produce.

**Clave:** Proyección W_vocab → El último eje deja de ser d_model y pasa a ser |V| · Filtro Top-K → Muchos tokens se quedan con probabilidad cero · Softmax final → Los valores quedan entre 0 y 1, y suman 1 · Bucle autoregresivo → La secuencia crece un token por cada vuelta

### PRE-I5

**Pregunta:** Contexto — Una justificación correcta explica para qué es necesaria una operación; no basta con repetir su nombre.

Selecciona las DOS explicaciones que justifican correctamente su etapa.

- Escala de temperatura: Controla qué tan concentrada quedará la distribución
- Softmax final: Para elegir un token hacen falta probabilidades
- Escala de temperatura: Para elegir un token hacen falta probabilidades
- Softmax final: Controla qué tan concentrada quedará la distribución

**Clave:** Escala de temperatura: Controla qué tan concentrada quedará la distribución · Softmax final: Para elegir un token hacen falta probabilidades

### PRE-I6

**Pregunta:** Contexto — Para decidir si dos etapas son consecutivas, comprueba que la salida de la primera sea la entrada que necesita la segunda.

Lee la afirmación y decide si es verdadera o falsa:

En el flujo del módulo, después de «Proyección W_vocab» ocurre «Escala de temperatura».

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-I7

**Pregunta:** Contexto — La pregunta ya indica la entrada de una operación. Elige su salida inmediata, no la palabra final.

Completa: «Selección del token» recibe La distribución de probabilidad y produce ________.

**Clave:** Token seleccionado

### PRE-I8

**Pregunta:** Contexto — El propósito explica por qué hace falta la operación; no es una descripción de sus pasos.

¿Por qué se realiza «Softmax final»?

- Para elegir un token hacen falta probabilidades
- Para generar sólo hace falta predecir un token: el siguiente
- Da un puntaje a cada uno de los tokens que se podrían escribir
- Limita cuántos candidatos pueden elegirse como máximo

**Clave:** Para elegir un token hacen falta probabilidades

### PRE-I9

**Pregunta:** Contexto — Un par entrada→salida sólo es válido si ambos pertenecen a la misma etapa; no mezcles etapas.

Selecciona los DOS pares que describen la entrada y la salida de una misma etapa del recorrido.

- La salida del decoder, con forma [B,T,d_model] → h_t
- El prefijo y el token recién elegido → Texto generado
- La salida del decoder, con forma [B,T,d_model] → Texto generado
- El prefijo y el token recién elegido → h_t

**Clave:** La salida del decoder, con forma [B,T,d_model] → h_t · El prefijo y el token recién elegido → Texto generado

### PRE-A1

**Pregunta:** Contexto — La capa lineal conserva cuántos ejemplos hay y cambia el significado del último eje.

Resuelve sin opciones: La proyección conserva el primer eje y cambia el último, de d_model a |V|. Dos ejemplos aportan un estado de 128 características y |V|=20 000. ¿Qué forma tienen los logits?

**Clave:** [2,20 000]

### PRE-A2

**Pregunta:** Contexto — Considera en qué punto aparecen las probabilidades y qué son los números antes de ese punto.

Un logit es el puntaje que da la capa lineal a un token, antes de aplicar softmax. Los logits pueden ser negativos y no sumar 1. ¿Es válido?

- Sí; son scores crudos y softmax los normaliza después
- No; deben ser probabilidades antes de softmax
- Sólo si Top-K=1
- Sólo durante entrenamiento

**Clave:** Sí; son scores crudos y softmax los normaliza después

### PRE-A3

**Pregunta:** Contexto — Cada opción une un dato con su resultado. Evalúa cada una por separado.

Selecciona las DOS opciones en las que el dato y su resultado están emparejados correctamente.

- T = 0.5 en lugar de T = 1 → la distribución se concentra.
- Top-K = 3 sobre 9 000 logits → quedan como máximo 3.
- T = 0.5 en lugar de T = 1 → la distribución se aplana.
- Top-K = 3 sobre 9 000 logits → quedan 8 997.

**Clave:** T = 0.5 en lugar de T = 1 → la distribución se concentra. · Top-K = 3 sobre 9 000 logits → quedan como máximo 3.

### PRE-A4

**Pregunta:** Contexto — Las cuatro tarjetas forman un solo cálculo. Ordénalas de modo que la salida de cada una sirva a la siguiente.

Reconstruye el orden necesario para que la transformación sea válida.

**Clave:** Proyección W_vocab → Escala de temperatura → Filtro Top-K → Filtro Top-P

### PRE-A5

**Pregunta:** Contexto — Resuelve cada situación por separado. Recuerda qué depende de una cantidad fija y qué depende de la masa acumulada.

Relaciona cada situación con la conclusión correcta. Cada conclusión se usa una sola vez.

**Clave:** Top-P acumula probabilidades de mayor a menor y se detiene al alcanzar p. Con probabilidades ordenadas [0.6,0.25,0.1,0.05] y p=0.8, ¿qué núcleo mínimo se conserva? → Los dos primeros · Softmax convierte los logits en probabilidades que suman 1, y a logits iguales les da probabilidades iguales. ¿Qué distribución producen los logits [0,0]? → [0.5,0.5] · Se genera un token por vuelta, y el decoder recibe en cada una lo que ya se escribió. Después de seleccionar un token, ¿qué ocurre antes de predecir el siguiente? → Se añade al prefijo del decoder

### PRE-A6

**Pregunta:** Contexto — Dividir todos los logits entre un mismo valor positivo mantiene quién es mayor que quién. Evalúa lo que afirma el caso.

Lee la afirmación y decide si es verdadera o falsa:

Caso: con selección codiciosa (argmax), cambiar la temperatura de 1.0 a 0.5 no cambia el token elegido.

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-A7

**Pregunta:** Contexto — Cuenta primero cuántos candidatos conserva el filtro; los demás quedan fuera.

Responde sin opciones: Top-K conserva los K logits mayores y deja a los demás con probabilidad cero. Logits [4, 1, 3, 0, 2] con Top-K = 3. ¿Cuántos candidatos quedan en cero?

**Clave:** 2

### PRE-A8

**Pregunta:** Contexto — Si los logits son iguales, nada los distingue. Piensa qué exige la normalización.

La generación repite un ciclo que, sin un criterio de parada, nunca terminaría. ¿Qué dos condiciones típicas lo detienen?

- Emitir EOS o alcanzar el máximo de tokens
- Tener T=1
- Usar más de una cabeza
- Obtener un logit negativo

**Clave:** Emitir EOS o alcanzar el máximo de tokens

## Post-test

### POST-B1

**Pregunta:** Contexto — Al terminar el decoder hay un vector por posición. Para escribir el siguiente token, el modelo parte de uno de ellos.

¿Qué operación se hace primero con la salida del decoder?

- Tomar la fila de la posición que debe predecir
- Aplicar una proyección lineal d_model→|V|
- Dividir todos los logits entre T, con T mayor que 0
- Poner en −∞ todos los logits, salvo los K mayores

**Clave:** Tomar la fila de la posición que debe predecir

### POST-B2

**Pregunta:** Contexto — Antes de elegir una palabra, se puede ajustar qué tan marcada es la diferencia entre los candidatos.

¿Qué operación realiza la temperatura?

- Dividir todos los logits entre T, con T mayor que 0
- Poner en −∞ todos los logits, salvo los K mayores
- Conservar el grupo mínimo que alcanza la probabilidad acumulada p
- Convertir los logits en probabilidades sobre el vocabulario

**Clave:** Dividir todos los logits entre T, con T mayor que 0

### POST-B3

**Pregunta:** Contexto — Del estado final hay que pasar a un número por cada token que el modelo conoce.

Lee la afirmación y decide si es verdadera o falsa:

La proyección lineal convierte por sí sola los logits en probabilidades que suman uno.

- Verdadero
- Falso

**Clave:** Falso

### POST-B4

**Pregunta:** Contexto — Los puntajes de la capa lineal todavía no se pueden leer como probabilidades, y una función los convierte.

Lee la afirmación y decide si es verdadera o falsa:

Softmax convierte los logits en probabilidades positivas que suman 1.

- Verdadero
- Falso

**Clave:** Verdadero

### POST-B5

**Pregunta:** Contexto — Cada concepto de este módulo resuelve un problema distinto. Revisa qué hace cada uno.

Selecciona las DOS asociaciones coherentes entre concepto y función.

- Softmax final: Convierte los logits en probabilidades positivas que suman 1 sobre el vocabulario.
- Top-P: Conserva el grupo más pequeño de candidatos cuya probabilidad acumulada alcanza p.
- Softmax final: Conserva el grupo más pequeño de candidatos cuya probabilidad acumulada alcanza p.
- Top-P: Convierte los logits en probabilidades positivas que suman 1 sobre el vocabulario.

**Clave:** Softmax final: Convierte los logits en probabilidades positivas que suman 1 sobre el vocabulario. · Top-P: Conserva el grupo más pequeño de candidatos cuya probabilidad acumulada alcanza p.

### POST-B6

**Pregunta:** Contexto — Generar una palabra es una cadena: la salida de cada etapa alimenta a la siguiente.

Completa el flujo: Filtro Top-P → ________ → Selección del token.

**Clave:** Softmax final

### POST-B7

**Pregunta:** Contexto — Cada etapa resuelve un problema distinto: puntuar, ajustar, filtrar, normalizar o elegir.

Relaciona cada etapa con el motivo por el que se realiza.

**Clave:** Proyección W_vocab → Da un puntaje a cada uno de los tokens que se podrían escribir · Filtro Top-K → Limita cuántos candidatos pueden elegirse como máximo · Softmax final → Para elegir un token hacen falta probabilidades · Bucle autoregresivo → Cada elección condiciona la predicción siguiente

### POST-B8

**Pregunta:** Contexto — En las formas, B es el número de ejemplos, d_model el ancho del estado y |V| el tamaño del vocabulario.

Al terminar el paso «Último estado del decoder», ¿qué forma (dimensiones) tiene el tensor que se obtiene? Escríbela eje por eje con los símbolos del recorrido.

**Clave:** [B,d_model]

### POST-I1

**Pregunta:** Contexto — El punto de partida es el estado del decoder. Ordena las operaciones usando la salida de una como entrada de la siguiente.

Ordena las etapas según el flujo real de información.

**Clave:** Proyección W_vocab → Escala de temperatura → Filtro Top-K → Filtro Top-P

### POST-I2

**Pregunta:** Contexto — El punto de partida son los logits ajustados. Ordena las operaciones que llevan hasta los candidatos finales.

Ordena las etapas según el flujo real de información.

**Clave:** Filtro Top-K → Filtro Top-P → Softmax final → Selección del token

### POST-I3

**Pregunta:** Contexto — Aquí debes relacionar cada transformación con el resultado inmediato que deja, no con el de pasos posteriores.

Relaciona cada transformación con la información que produce.

**Clave:** Proyección W_vocab → Logits · Filtro Top-K → K candidatos · Softmax final → Distribución · Bucle autoregresivo → Texto generado

### POST-I4

**Pregunta:** Contexto — Sigue qué cambia realmente en cada etapa: pueden cambiar los ejes, los valores o los candidatos disponibles.

Relaciona cada etapa con el cambio observable que produce.

**Clave:** Último estado del decoder → De toda la tabla queda sólo una fila · Escala de temperatura → El orden se conserva; cambian las distancias entre candidatos · Filtro Top-P → La cantidad de candidatos varía según la distribución · Selección del token → De |V| candidatos queda un solo ID

### POST-I5

**Pregunta:** Contexto — Una justificación correcta explica para qué es necesaria una operación; no basta con repetir su nombre.

Selecciona las DOS explicaciones que justifican correctamente su etapa.

- Proyección W_vocab: Da un puntaje a cada uno de los tokens que se podrían escribir
- Selección del token: Convierte las probabilidades en una sola decisión
- Proyección W_vocab: Convierte las probabilidades en una sola decisión
- Selección del token: Da un puntaje a cada uno de los tokens que se podrían escribir

**Clave:** Proyección W_vocab: Da un puntaje a cada uno de los tokens que se podrían escribir · Selección del token: Convierte las probabilidades en una sola decisión

### POST-I6

**Pregunta:** Contexto — Para decidir si dos etapas son consecutivas, comprueba que la salida de la primera sea la entrada que necesita la segunda.

Lee la afirmación y decide si es verdadera o falsa:

En el flujo del módulo, después de «Proyección W_vocab» ocurre «Filtro Top-P».

- Verdadero
- Falso

**Clave:** Falso

### POST-I7

**Pregunta:** Contexto — La pregunta ya indica la entrada de una operación. Elige su salida inmediata, no la palabra final.

Completa: «Filtro Top-P» recibe Los candidatos, ordenados de mayor a menor y produce ________.

**Clave:** Núcleo

### POST-I8

**Pregunta:** Contexto — El propósito explica por qué hace falta la operación; no es una descripción de sus pasos.

¿Por qué se realiza «Escala de temperatura»?

- Controla qué tan concentrada quedará la distribución
- Para generar sólo hace falta predecir un token: el siguiente
- Adapta el número de candidatos a la seguridad del modelo
- Convierte las probabilidades en una sola decisión

**Clave:** Controla qué tan concentrada quedará la distribución

### POST-I9

**Pregunta:** Contexto — Un par entrada→salida sólo es válido si ambos pertenecen a la misma etapa; no mezcles etapas.

Selecciona los DOS pares que describen la entrada y la salida de una misma etapa del recorrido.

- El estado h_t y la matriz W_vocab → Logits
- La distribución de probabilidad → Token seleccionado
- El estado h_t y la matriz W_vocab → Token seleccionado
- La distribución de probabilidad → Logits

**Clave:** El estado h_t y la matriz W_vocab → Logits · La distribución de probabilidad → Token seleccionado

### POST-A1

**Pregunta:** Contexto — La capa lineal conserva cuántos ejemplos hay y cambia el significado del último eje.

Resuelve sin opciones: La proyección conserva el primer eje y cambia el último, de d_model a |V|. Tres ejemplos aportan un estado de 256 características y hay 50 000 tokens. ¿Qué forma tienen los logits?

**Clave:** [3,50 000]

### POST-A2

**Pregunta:** Contexto — Considera en qué punto aparecen las probabilidades y qué son los números antes de ese punto.

Un logit es el puntaje que da la capa lineal a un token, antes de softmax. Un modelo produce los logits [−3.1, 0.4, 5.0]: hay negativos y no suman 1. ¿Es válido?

- Sí; son scores crudos y softmax los normaliza después
- No; deben ser probabilidades antes de softmax
- Sólo si Top-K=1
- Sólo durante entrenamiento

**Clave:** Sí; son scores crudos y softmax los normaliza después

### POST-A3

**Pregunta:** Contexto — Cada opción une un dato con su resultado. Evalúa cada una por separado.

Selecciona las DOS opciones en las que el dato y su resultado están emparejados correctamente.

- T = 3 en lugar de T = 1 → los candidatos se acercan.
- Top-K = 4 sobre 7 000 logits → quedan como máximo 4.
- T = 3 en lugar de T = 1 → cambia el orden de los candidatos.
- Top-K = 4 sobre 7 000 logits → quedan 6 996.

**Clave:** T = 3 en lugar de T = 1 → los candidatos se acercan. · Top-K = 4 sobre 7 000 logits → quedan como máximo 4.

### POST-A4

**Pregunta:** Contexto — Las cuatro tarjetas forman un solo cálculo. Ordénalas de modo que la salida de cada una sirva a la siguiente.

Reconstruye el orden necesario para que la transformación sea válida.

**Clave:** Escala de temperatura → Filtro Top-K → Filtro Top-P → Softmax final

### POST-A5

**Pregunta:** Contexto — Resuelve cada situación por separado. Recuerda qué depende de una cantidad fija y qué depende de la masa acumulada.

Relaciona cada situación con la conclusión correcta. Cada conclusión se usa una sola vez.

**Clave:** Top-P acumula probabilidades de mayor a menor hasta alcanzar p. Con probabilidades ordenadas [0.4, 0.3, 0.2, 0.1] y p = 0.8, ¿qué núcleo mínimo se conserva? → Los tres primeros · Softmax da probabilidades iguales a logits iguales, y su suma es 1. Tres candidatos tienen los logits [5, 5, 5]. ¿Qué probabilidades reciben? → [1/3, 1/3, 1/3] · Se genera un token por vuelta. El modelo acaba de elegir «mundo» después de «hola». ¿Qué ocurre antes de predecir el siguiente token? → «mundo» se añade al prefijo del decoder

### POST-A6

**Pregunta:** Contexto — Dividir todos los logits entre un mismo valor positivo mantiene quién es mayor que quién. Evalúa lo que afirma el caso.

Lee la afirmación y decide si es verdadera o falsa:

Caso: aumentar la temperatura cambia cuál es el candidato con el logit más alto.

- Verdadero
- Falso

**Clave:** Falso

### POST-A7

**Pregunta:** Contexto — Cuenta primero cuántos candidatos conserva el filtro; los demás quedan fuera.

Responde sin opciones: Top-K conserva los K logits mayores y deja a los demás con probabilidad cero. Logits [0, 5, 2, 1, 4, 3] con Top-K = 2. ¿Cuántos candidatos quedan en cero?

**Clave:** 4

### POST-A8

**Pregunta:** Contexto — Si los logits son iguales, nada los distingue. Piensa qué exige la normalización.

La generación repite un ciclo hasta que algo la detiene. Un generador nunca se detiene. ¿Qué criterio de parada le falta?

- Emitir EOS o alcanzar un máximo de tokens
- Tener T=1
- Usar más de una cabeza
- Obtener un logit negativo

**Clave:** Emitir EOS o alcanzar un máximo de tokens

## Retos del laboratorio

### LAB-m7_l1

**Pregunta:** Ejemplo de la proyección: un solo ejemplo con un estado de 32 componentes y un vocabulario de 900 tokens. ¿Qué forma tienen los logits, y qué representan?

**Respuesta correcta:** [1, 900]; un puntaje para cada candidato posible

**Explicación:** La capa lineal cambia el último eje a |V|. La selección ocurre más adelante.

### LAB-m7_l2

**Pregunta:** Compara las barras antes y después de softmax. Los logits [−1.5, 0.2, 3.0] tienen un valor negativo y no suman 1. ¿Es un error?

**Respuesta correcta:** No: son puntajes crudos, y softmax conserva su orden

**Explicación:** Los logits son puntajes sin normalizar. Softmax los convierte en probabilidades sin cambiar cuál supera a cuál.

### LAB-m7_l3

**Pregunta:** En el paso de temperatura, baja T con su control: el ganador no cambia, pero se separa de las demás barras. ¿Qué se modificó?

**Respuesta correcta:** El contraste de la distribución

**Explicación:** La temperatura reescala diferencias: una T menor concentra la masa sin reordenar los candidatos.

### LAB-m7_l4

**Pregunta:** Ejemplo: Top-K = 2 sobre 800 logits, y reduce K con su control. ¿Cuántos candidatos pueden sobrevivir, y qué criterio sigue el filtro?

**Respuesta correcta:** 2; descarta primero los puntajes más bajos

**Explicación:** Top-K ordena por puntaje y mantiene la parte superior de la clasificación.

### LAB-m7_l5

**Pregunta:** Ejemplo de Top-P: probabilidades ordenadas [0.7, 0.2, 0.05, 0.05] y p = 0.85. ¿Qué núcleo se conserva, y qué lo determina?

**Respuesta correcta:** Los dos primeros; corta al alcanzar la masa acumulada

**Explicación:** 0.7 no alcanza 0.85; 0.7 + 0.2 = 0.9 sí. Una distribución plana puede necesitar más candidatos.

### LAB-m7_l6

**Pregunta:** Con Top-K = 1, sólo sobrevive un candidato y luego se normaliza con softmax. ¿Qué probabilidad recibe?

**Respuesta correcta:** 1, toda la probabilidad disponible

**Explicación:** Softmax reparte un total de 1; si sólo sobrevive un candidato, se lo lleva completo.

### LAB-m7_l7

**Pregunta:** En el paso de realimentación, el token elegido vuelve a la entrada del decoder. ¿Qué elemento puede reutilizarse sin recalcularse?

**Respuesta correcta:** La memoria de la fuente

**Explicación:** El prefijo crece y vuelve al decoder, mientras la codificación de la fuente puede mantenerse.

### LAB-m7_l8

**Pregunta:** Ejemplo: el modelo emite EOS en el paso 6, aunque el límite es de 20 tokens. ¿Qué indica ese evento?

**Respuesta correcta:** El modelo señaló que la secuencia terminó

**Explicación:** EOS es una condición semántica de parada; el límite máximo sólo actúa como protección adicional.
