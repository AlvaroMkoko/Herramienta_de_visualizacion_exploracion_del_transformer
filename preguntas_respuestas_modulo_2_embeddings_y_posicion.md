# Preguntas y respuestas correctas — Módulo 2: Embeddings y posición

Generado por `tools/generar_preguntas_modulo.py`. Corresponde a la versión 15 del banco modular. El pre-test y el post-test tienen 25 reactivos disponibles cada uno; cada intento selecciona 15.

## Pregunta ancla

**Pregunta:** Si «gato» aparece al inicio y al final de una frase, ¿cómo sabe el modelo que es el mismo token y, a la vez, que ocupa lugares distintos?

**Ejemplo:** Con d_model=4, la fila E[15] de «gato» es [0.2, −0.1, 0.4, 0.0]. Al escalar por √4 = 2 queda [0.4, −0.2, 0.8, 0.0]. La posición 0 aporta P0 = [0, 1, 0, 1] y la posición 3 aporta P3 ≈ [0.14, −0.99, 0.03, 1.0]. Resultado: X(pos 0) = [0.4, 0.8, 0.8, 1.0] y X(pos 3) ≈ [0.54, −1.19, 0.83, 1.0]. Misma identidad, distinto orden.

**Cierre:** En «gato ve otro gato», la primera y la última palabra son el mismo token, en lugares distintos. ¿Cómo son su embedding de token y su X final?

**Respuesta correcta:** Embedding igual; X distinto por la suma posicional

## Comprobaciones del recorrido guiado

### R1. Recibir Token IDs

**Pregunta:** Un ID es válido si corresponde a una fila de la tabla, y las filas se numeran desde 0. Si el vocabulario tiene 1 000 filas (índices 0 a 999), ¿qué ID no puede consultarla?

**Respuesta correcta:** 1 000

### R2. Matriz de embeddings

**Pregunta:** Cada fila de la matriz de embeddings tiene d_model parámetros. Con |V| = 1 000 y d_model = 64, ¿cuántos parámetros tiene en total?

**Respuesta correcta:** 64 000

### R3. Selección de filas

**Pregunta:** E guarda un vector por fila y el ID indica cuál usar. Para el ID 15, ¿qué operación produce su vector?

**Respuesta correcta:** Tomar la fila 15 de E

### R4. Escalamiento por √d_model

**Pregunta:** Escalar significa multiplicar cada componente por √d_model. Con d_model = 16, ¿qué valor toma un componente 0.5?

**Respuesta correcta:** 2.0

### R5. Índices de posición

**Pregunta:** Las posiciones se numeran desde 0. Una secuencia de T = 5 tokens, ¿qué índices de posición recibe?

**Respuesta correcta:** 0 … 4

### R6. Vectores posicionales

**Pregunta:** La primera frecuencia usa sin(pos) y cos(pos). En la posición 0, ¿cuánto valen?

**Respuesta correcta:** sin = 0, cos = 1

### R7. Suma embedding + posición

**Pregunta:** Sumar componente a componente no agrega columnas. Si el embedding escalado [B, T, 64] se suma con P [1, T, 64], ¿qué forma resulta?

**Respuesta correcta:** [B, T, 64]

### R8. Representación de entrada

**Pregunta:** Dropout apaga componentes al azar sólo para entrenar, no al usar el modelo. En inferencia, ¿qué hace sobre X?

**Respuesta correcta:** No modifica X

## Pre-test

### PRE-B1

**Pregunta:** Contexto — Al llegar aquí, cada token ya es un ID. El modelo necesita convertirlo en un vector para poder calcular.

¿Qué descripción explica correctamente qué es el embedding de un token?

- Es un vector aprendido que representa a un token; el mismo token obtiene siempre el mismo vector, esté donde esté.
- Es una tabla aprendida de forma [|V|, d_model]: una fila por cada token del vocabulario.
- Es el número de componentes de cada vector, y se mantiene igual a lo largo de todo el Transformer.
- Suma componente a componente el significado y la posición, sin aumentar el ancho del vector.

**Clave:** Es un vector aprendido que representa a un token; el mismo token obtiene siempre el mismo vector, esté donde esté.

### PRE-B2

**Pregunta:** Contexto — Si sólo se usaran los embeddings de token, el modelo recibiría los tokens sin saber en qué lugar está cada uno.

¿Qué descripción explica correctamente qué aporta la codificación posicional?

- Es un vector que depende sólo de la posición y permite distinguir frases con los mismos tokens en distinto orden.
- Suma componente a componente el significado y la posición, sin aumentar el ancho del vector.
- Es el tensor [B, T, d_model] con significado y posición que recibe el primer bloque.
- Es una tabla aprendida de forma [|V|, d_model]: una fila por cada token del vocabulario.

**Clave:** Es un vector que depende sólo de la posición y permite distinguir frases con los mismos tokens en distinto orden.

### PRE-B3

**Pregunta:** Contexto — La tabla que guarda los vectores de los tokens se ajusta durante el entrenamiento.

Lee la afirmación y decide si es verdadera o falsa:

La matriz de embeddings tiene una fila aprendida por cada token del vocabulario.

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-B4

**Pregunta:** Contexto — d_model aparece en muchas formas de este módulo. Piensa qué indica exactamente ese número.

Lee la afirmación y decide si es verdadera o falsa:

d_model indica cuántos tokens contiene el vocabulario.

- Verdadero
- Falso

**Clave:** Falso

### PRE-B5

**Pregunta:** Contexto — Cada concepto de este módulo aporta algo distinto a la representación final. Revisa qué hace cada uno.

Selecciona las DOS asociaciones coherentes entre concepto y función.

- Selección por ID: Usa el Token ID como índice para elegir una fila; el ID no se multiplica por ningún vector.
- Suma de señales: Suma componente a componente el significado y la posición, sin aumentar el ancho del vector.
- Selección por ID: Suma componente a componente el significado y la posición, sin aumentar el ancho del vector.
- Suma de señales: Usa el Token ID como índice para elegir una fila; el ID no se multiplica por ningún vector.

**Clave:** Selección por ID: Usa el Token ID como índice para elegir una fila; el ID no se multiplica por ningún vector. · Suma de señales: Suma componente a componente el significado y la posición, sin aumentar el ancho del vector.

### PRE-B6

**Pregunta:** Contexto — Construir la entrada es una cadena: la salida de cada etapa alimenta a la siguiente.

Completa el flujo: Escalamiento por √d_model → ________ → Vectores posicionales.

**Clave:** Índices de posición

### PRE-B7

**Pregunta:** Contexto — Cada etapa resuelve un problema distinto: consultar la tabla, equilibrar magnitudes o añadir orden.

Relaciona cada etapa con el motivo por el que se realiza.

**Clave:** Recibir Token IDs → Sólo un índice válido puede consultar la tabla de embeddings · Selección de filas → Convierte símbolos sueltos en vectores con los que se puede calcular · Índices de posición → La atención, por sí sola, no sabe en qué orden vienen los tokens · Suma embedding + posición → Reúne las dos señales conservando el ancho que exigen los residuales

### PRE-B8

**Pregunta:** Contexto — En las formas, B es el número de frases, T el número de tokens, |V| el tamaño del vocabulario y d_model el ancho de cada vector.

Al terminar el paso «Representación de entrada», ¿qué forma (dimensiones) tiene el tensor que se obtiene? Escríbela eje por eje con los símbolos del recorrido.

**Clave:** [B,T,d_model]

### PRE-I1

**Pregunta:** Contexto — El punto de partida son los IDs. Ordena las operaciones usando la salida de una como entrada de la siguiente.

Ordena las etapas según el flujo real de información.

**Clave:** Recibir Token IDs → Matriz de embeddings → Selección de filas → Escalamiento por √d_model

### PRE-I2

**Pregunta:** Contexto — El punto de partida son los embeddings. Ordena las operaciones que los llevan hasta la representación final.

Ordena las etapas según el flujo real de información.

**Clave:** Índices de posición → Vectores posicionales → Suma embedding + posición → Representación de entrada

### PRE-I3

**Pregunta:** Contexto — Aquí debes relacionar cada transformación con el resultado inmediato que deja, no con el de pasos posteriores.

Relaciona cada transformación con la información que produce.

**Clave:** Recibir Token IDs → Índices válidos · Selección de filas → Embeddings de tokens · Índices de posición → Posiciones · Suma embedding + posición → X

### PRE-I4

**Pregunta:** Contexto — Sigue qué cambia realmente en cada etapa: pueden cambiar los ejes, la magnitud de los números o la información que llevan.

Relaciona cada etapa con el cambio observable que produce.

**Clave:** Matriz de embeddings → Existe un vector aprendido por cada una de las |V| entradas · Escalamiento por √d_model → La forma no cambia, pero los valores crecen por el mismo factor · Vectores posicionales → Cada número de posición se convierte en un vector de d_model componentes · Representación de entrada → La forma no cambia en ningún modo

### PRE-I5

**Pregunta:** Contexto — Una justificación correcta explica para qué es necesaria una operación; no basta con repetir su nombre.

Selecciona las DOS explicaciones que justifican correctamente su etapa.

- Selección de filas: Convierte símbolos sueltos en vectores con los que se puede calcular
- Vectores posicionales: Da un patrón distinto para cada lugar, sin agregar parámetros que aprender
- Selección de filas: Da un patrón distinto para cada lugar, sin agregar parámetros que aprender
- Vectores posicionales: Convierte símbolos sueltos en vectores con los que se puede calcular

**Clave:** Selección de filas: Convierte símbolos sueltos en vectores con los que se puede calcular · Vectores posicionales: Da un patrón distinto para cada lugar, sin agregar parámetros que aprender

### PRE-I6

**Pregunta:** Contexto — Para decidir si dos etapas son consecutivas, comprueba que la salida de la primera sea la entrada que necesita la segunda.

Lee la afirmación y decide si es verdadera o falsa:

En el flujo del módulo, después de «Matriz de embeddings» ocurre «Selección de filas».

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-I7

**Pregunta:** Contexto — La pregunta ya indica la entrada de una operación. Elige su salida inmediata, no el resultado final.

Completa: «Suma embedding + posición» recibe Embedding escalado y matriz de posiciones P y produce ________.

**Clave:** X

### PRE-I8

**Pregunta:** Contexto — El propósito explica por qué hace falta la operación; no es una descripción de sus pasos.

¿Por qué se realiza «Vectores posicionales»?

- Da un patrón distinto para cada lugar, sin agregar parámetros que aprender
- Sólo un índice válido puede consultar la tabla de embeddings
- Equilibra su tamaño con el de la señal de posición, que se sumará después
- Durante el entrenamiento evita depender demasiado de componentes concretas

**Clave:** Da un patrón distinto para cada lugar, sin agregar parámetros que aprender

### PRE-I9

**Pregunta:** Contexto — Un par entrada→salida sólo es válido si ambos pertenecen a la misma etapa; no mezcles etapas.

Selecciona los DOS pares que describen la entrada y la salida de una misma etapa del recorrido.

- Tabla de IDs con forma [B,T] → Índices válidos
- La representación X ya combinada → Entrada al encoder/decoder
- Tabla de IDs con forma [B,T] → Entrada al encoder/decoder
- La representación X ya combinada → Índices válidos

**Clave:** Tabla de IDs con forma [B,T] → Índices válidos · La representación X ya combinada → Entrada al encoder/decoder

### PRE-A1

**Pregunta:** Contexto — La matriz de embeddings tiene un eje por cada token posible y otro por cada componente de su vector.

Resuelve sin opciones: La matriz de embeddings tiene una fila por token del vocabulario y una columna por componente. Con |V|=10 000 y d_model=256, ¿qué forma tiene?

**Clave:** [10 000, 256]

### PRE-A2

**Pregunta:** Contexto — Un ID es un número entero y la matriz E es una tabla. Piensa qué papel juega ese número frente a la tabla.

La matriz E guarda el vector de cada token en una fila, y el Token ID es un índice. Para el ID 42, ¿qué operación produce su embedding?

- Selecciona la fila E[42]
- Multiplica 42 por toda E
- Selecciona la columna 42
- Calcula softmax(42)

**Clave:** Selecciona la fila E[42]

### PRE-A3

**Pregunta:** Contexto — Cada opción une un dato con su resultado. Para sumar, las celdas se combinan una a una; un ID elige una fila.

Selecciona las DOS opciones en las que el dato y su resultado están emparejados correctamente.

- Dos tensores [3, 6, 64] sumados celda a celda → [3, 6, 64].
- Sin señal posicional → se confunden frases en distinto orden.
- Dos tensores [3, 6, 64] sumados celda a celda → [3, 6, 128].
- Sin señal posicional → se confunden tokens con IDs distintos.

**Clave:** Dos tensores [3, 6, 64] sumados celda a celda → [3, 6, 64]. · Sin señal posicional → se confunden frases en distinto orden.

### PRE-A4

**Pregunta:** Contexto — Las cuatro tarjetas forman un solo cálculo. Ordénalas de modo que la salida de cada una sirva a la siguiente.

Reconstruye el orden necesario para que la transformación sea válida.

**Clave:** Matriz de embeddings → Selección de filas → Escalamiento por √d_model → Índices de posición

### PRE-A5

**Pregunta:** Contexto — Resuelve cada situación por separado. Recuerda qué depende del token y qué depende de la posición.

Relaciona cada situación con la conclusión correcta. Cada conclusión se usa una sola vez.

**Clave:** La representación de una frase es una tabla con T filas y d_model columnas. Con d_model=64 y T=6, ¿cuántos valores contiene? → 384 · El embedding se multiplica por √d_model. Si d_model=64, ¿por qué factor se escala? → 8 · La tabla de embeddings devuelve una fila según el ID. El mismo token aparece en las posiciones 1 y 4, antes de sumar posición. ¿Cómo son sus embeddings? → Son iguales

### PRE-A6

**Pregunta:** Contexto — Considera de qué datos depende el vector posicional. Evalúa exactamente lo que afirma el caso.

Lee la afirmación y decide si es verdadera o falsa:

Caso: la codificación sinusoidal de la posición 3 es la misma en cualquier frase, sin importar qué token ocupe esa posición.

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-A7

**Pregunta:** Contexto — Cada fila de la matriz de embeddings aporta tantos parámetros como componentes tiene.

Responde sin opciones: La matriz de embeddings tiene |V| filas y d_model columnas, y cada celda es un parámetro. Con |V| = 5 000 y d_model = 128, ¿cuántos parámetros tiene?

**Clave:** 640 000

### PRE-A8

**Pregunta:** Contexto — La misma representación se suma con otras en las capas siguientes. Piensa qué exige esa suma.

Dentro del Transformer, varias subcapas suman su entrada con su salida. ¿Por qué la representación final conserva el ancho d_model?

- Para permitir sumas residuales y proyecciones compatibles
- Para que el vocabulario no cambie
- Para evitar usar softmax
- Para fijar T= d_model

**Clave:** Para permitir sumas residuales y proyecciones compatibles

## Post-test

### POST-B1

**Pregunta:** Contexto — Al llegar aquí, cada token ya es un ID. El modelo necesita convertirlo en un vector para poder calcular.

¿Qué operación produce el embedding de cada token de la frase?

- Copiar la fila E[id] para cada posición de la frase
- Multiplicar cada componente por √d_model
- Numerar las posiciones de 0 a T−1
- Calcular senos y cosenos de distinta frecuencia en cada posición

**Clave:** Copiar la fila E[id] para cada posición de la frase

### POST-B2

**Pregunta:** Contexto — Si sólo se usaran los embeddings de token, el modelo recibiría los tokens sin saber en qué lugar está cada uno.

¿Qué operación da a cada token un número de posición?

- Numerar las posiciones de 0 a T−1
- Calcular senos y cosenos de distinta frecuencia en cada posición
- Sumar embedding y posición, componente a componente
- Aplicar dropout durante el entrenamiento y dejar X igual durante la inferencia

**Clave:** Numerar las posiciones de 0 a T−1

### POST-B3

**Pregunta:** Contexto — La tabla que guarda los vectores de los tokens se ajusta durante el entrenamiento.

Lee la afirmación y decide si es verdadera o falsa:

La matriz de embeddings tiene una sola probabilidad por token y no usa el eje d_model.

- Verdadero
- Falso

**Clave:** Falso

### POST-B4

**Pregunta:** Contexto — d_model aparece en muchas formas de este módulo. Piensa qué indica exactamente ese número.

Lee la afirmación y decide si es verdadera o falsa:

d_model es el ancho común de los vectores que atraviesan el Transformer.

- Verdadero
- Falso

**Clave:** Verdadero

### POST-B5

**Pregunta:** Contexto — Cada concepto de este módulo aporta algo distinto a la representación final. Revisa qué hace cada uno.

Selecciona las DOS asociaciones coherentes entre concepto y función.

- d_model: Es el número de componentes de cada vector, y se mantiene igual a lo largo de todo el Transformer.
- Escalamiento del embedding: Multiplica el embedding por √d_model para que su tamaño quede en equilibrio con la señal de posición.
- d_model: Multiplica el embedding por √d_model para que su tamaño quede en equilibrio con la señal de posición.
- Escalamiento del embedding: Es el número de componentes de cada vector, y se mantiene igual a lo largo de todo el Transformer.

**Clave:** d_model: Es el número de componentes de cada vector, y se mantiene igual a lo largo de todo el Transformer. · Escalamiento del embedding: Multiplica el embedding por √d_model para que su tamaño quede en equilibrio con la señal de posición.

### POST-B6

**Pregunta:** Contexto — Construir la entrada es una cadena: la salida de cada etapa alimenta a la siguiente.

Completa el flujo: Índices de posición → ________ → Suma embedding + posición.

**Clave:** Vectores posicionales

### POST-B7

**Pregunta:** Contexto — Cada etapa resuelve un problema distinto: consultar la tabla, equilibrar magnitudes o añadir orden.

Relaciona cada etapa con el motivo por el que se realiza.

**Clave:** Matriz de embeddings → Cada token necesita un vector propio que se pueda ajustar al entrenar · Escalamiento por √d_model → Equilibra su tamaño con el de la señal de posición, que se sumará después · Vectores posicionales → Da un patrón distinto para cada lugar, sin agregar parámetros que aprender · Representación de entrada → Durante el entrenamiento evita depender demasiado de componentes concretas

### POST-B8

**Pregunta:** Contexto — En las formas, B es el número de frases, T el número de tokens, |V| el tamaño del vocabulario y d_model el ancho de cada vector.

Al terminar el paso «Recibir Token IDs», ¿qué forma (dimensiones) tiene el tensor que se obtiene? Escríbela eje por eje con los símbolos del recorrido.

**Clave:** [B,T]

### POST-I1

**Pregunta:** Contexto — El punto de partida son los IDs. Ordena las operaciones usando la salida de una como entrada de la siguiente.

Ordena las etapas según el flujo real de información.

**Clave:** Matriz de embeddings → Selección de filas → Escalamiento por √d_model → Índices de posición

### POST-I2

**Pregunta:** Contexto — El punto de partida son los embeddings. Ordena las operaciones que los llevan hasta la representación final.

Ordena las etapas según el flujo real de información.

**Clave:** Escalamiento por √d_model → Índices de posición → Vectores posicionales → Suma embedding + posición

### POST-I3

**Pregunta:** Contexto — Aquí debes relacionar cada transformación con el resultado inmediato que deja, no con el de pasos posteriores.

Relaciona cada transformación con la información que produce.

**Clave:** Matriz de embeddings → E ∈ R^{|V|×d_model} · Escalamiento por √d_model → Embeddings escalados · Vectores posicionales → P ∈ R^{T×d_model} · Representación de entrada → Entrada al encoder/decoder

### POST-I4

**Pregunta:** Contexto — Sigue qué cambia realmente en cada etapa: pueden cambiar los ejes, la magnitud de los números o la información que llevan.

Relaciona cada etapa con el cambio observable que produce.

**Clave:** Recibir Token IDs → Los datos no cambian: se confirma que la búsqueda es posible · Selección de filas → Cada ID se reemplaza por un vector y aparece el eje d_model · Índices de posición → Cada fila de la frase obtiene un número de posición · Suma embedding + posición → Cada vector contiene ahora identidad y lugar en la frase

### POST-I5

**Pregunta:** Contexto — Una justificación correcta explica para qué es necesaria una operación; no basta con repetir su nombre.

Selecciona las DOS explicaciones que justifican correctamente su etapa.

- Matriz de embeddings: Cada token necesita un vector propio que se pueda ajustar al entrenar
- Suma embedding + posición: Reúne las dos señales conservando el ancho que exigen los residuales
- Matriz de embeddings: Reúne las dos señales conservando el ancho que exigen los residuales
- Suma embedding + posición: Cada token necesita un vector propio que se pueda ajustar al entrenar

**Clave:** Matriz de embeddings: Cada token necesita un vector propio que se pueda ajustar al entrenar · Suma embedding + posición: Reúne las dos señales conservando el ancho que exigen los residuales

### POST-I6

**Pregunta:** Contexto — Para decidir si dos etapas son consecutivas, comprueba que la salida de la primera sea la entrada que necesita la segunda.

Lee la afirmación y decide si es verdadera o falsa:

En el flujo del módulo, después de «Matriz de embeddings» ocurre «Índices de posición».

- Verdadero
- Falso

**Clave:** Falso

### POST-I7

**Pregunta:** Contexto — La pregunta ya indica la entrada de una operación. Elige su salida inmediata, no el resultado final.

Completa: «Índices de posición» recibe La longitud T de la frase y produce ________.

**Clave:** Posiciones

### POST-I8

**Pregunta:** Contexto — El propósito explica por qué hace falta la operación; no es una descripción de sus pasos.

¿Por qué se realiza «Selección de filas»?

- Convierte símbolos sueltos en vectores con los que se puede calcular
- Equilibra su tamaño con el de la señal de posición, que se sumará después
- La atención, por sí sola, no sabe en qué orden vienen los tokens
- Durante el entrenamiento evita depender demasiado de componentes concretas

**Clave:** Convierte símbolos sueltos en vectores con los que se puede calcular

### POST-I9

**Pregunta:** Contexto — Un par entrada→salida sólo es válido si ambos pertenecen a la misma etapa; no mezcles etapas.

Selecciona los DOS pares que describen la entrada y la salida de una misma etapa del recorrido.

- Parámetros que el modelo aprende al entrenar → E ∈ R^{|V|×d_model}
- Embedding escalado y matriz de posiciones P → X
- Parámetros que el modelo aprende al entrenar → X
- Embedding escalado y matriz de posiciones P → E ∈ R^{|V|×d_model}

**Clave:** Parámetros que el modelo aprende al entrenar → E ∈ R^{|V|×d_model} · Embedding escalado y matriz de posiciones P → X

### POST-A1

**Pregunta:** Contexto — La matriz de embeddings tiene un eje por cada token posible y otro por cada componente de su vector.

Resuelve sin opciones: La matriz de embeddings tiene una fila por token y una columna por componente. Un modelo usa un vocabulario de 32 000 tokens y d_model = 512. ¿Qué forma tiene?

**Clave:** [32 000, 512]

### POST-A2

**Pregunta:** Contexto — Un ID es un número entero y la matriz E es una tabla. Piensa qué papel juega ese número frente a la tabla.

E guarda un vector por fila y el Token ID es un índice. El token «luna» tiene el ID 907. ¿Cómo obtiene el modelo su vector inicial?

- Selecciona la fila E[907]
- Multiplica 907 por toda E
- Selecciona la columna 907
- Calcula softmax(907)

**Clave:** Selecciona la fila E[907]

### POST-A3

**Pregunta:** Contexto — Cada opción une un dato con su resultado. Para sumar, las celdas se combinan una a una; un ID elige una fila.

Selecciona las DOS opciones en las que el dato y su resultado están emparejados correctamente.

- Dos tensores [5, 8, 32] sumados celda a celda → [5, 8, 32].
- Sólo con embeddings de token → se pierde el orden de la frase.
- Dos tensores [5, 8, 32] sumados celda a celda → [10, 16, 32].
- Sólo con embeddings de token → cambia el tamaño del vocabulario.

**Clave:** Dos tensores [5, 8, 32] sumados celda a celda → [5, 8, 32]. · Sólo con embeddings de token → se pierde el orden de la frase.

### POST-A4

**Pregunta:** Contexto — Las cuatro tarjetas forman un solo cálculo. Ordénalas de modo que la salida de cada una sirva a la siguiente.

Reconstruye el orden necesario para que la transformación sea válida.

**Clave:** Selección de filas → Escalamiento por √d_model → Índices de posición → Vectores posicionales

### POST-A5

**Pregunta:** Contexto — Resuelve cada situación por separado. Recuerda qué depende del token y qué depende de la posición.

Relaciona cada situación con la conclusión correcta. Cada conclusión se usa una sola vez.

**Clave:** La representación de una frase tiene T filas y d_model columnas. Con T = 10 tokens y d_model = 32, ¿cuántos valores contiene? → 320 · El embedding se escala por √d_model. Si d_model = 256, ¿por qué factor se multiplica? → 16 · La tabla devuelve una fila según el ID. «sol» aparece en las posiciones 2 y 7 de una frase. Antes de sumar posición, ¿cómo son sus dos embeddings de token? → Son iguales

### POST-A6

**Pregunta:** Contexto — Considera de qué datos depende el vector posicional. Evalúa exactamente lo que afirma el caso.

Lee la afirmación y decide si es verdadera o falsa:

Caso: la codificación posicional de la posición 3 cambia según qué token ocupe esa posición.

- Verdadero
- Falso

**Clave:** Falso

### POST-A7

**Pregunta:** Contexto — Cada fila de la matriz de embeddings aporta tantos parámetros como componentes tiene.

Responde sin opciones: La matriz de embeddings tiene |V| filas y d_model columnas, y cada celda es un parámetro. Con |V| = 8 000 y d_model = 64, ¿cuántos parámetros tiene?

**Clave:** 512 000

### POST-A8

**Pregunta:** Contexto — La misma representación se suma con otras en las capas siguientes. Piensa qué exige esa suma.

Cada subcapa suma su entrada X con su salida. ¿Qué exige esto de la representación de entrada?

- Conservar la anchura d_model para que las sumas residuales sean posibles
- Que el vocabulario no cambie
- Evitar usar softmax
- Fijar T = d_model

**Clave:** Conservar la anchura d_model para que las sumas residuales sean posibles

## Retos del laboratorio

### LAB-m2_l1

**Pregunta:** Ejemplo de tabla: un vocabulario de 2 000 tokens y vectores de 32 componentes. ¿Qué forma tiene E, y qué conservan todas sus filas?

**Respuesta correcta:** [2 000, 32]; todas sus filas tienen 32 componentes

**Explicación:** Una fila por token y una columna por componente. Cada ID elige valores distintos, pero el ancho es siempre d_model.

### LAB-m2_l2

**Pregunta:** Observa el paso de consulta: una sola fila se resalta y sus celdas aparecen a la derecha. Si el ID fuera 58, ¿qué se copiaría?

**Respuesta correcta:** La fila E[58]

**Explicación:** El ID es un índice: el resaltado sigue al índice y la salida reproduce los valores guardados en esa fila.

### LAB-m2_l3

**Pregunta:** Ejemplo de la suma: un embedding [1, 2, 32] y su señal de posición [1, 2, 32] se combinan celda con celda. ¿Qué forma tiene el resultado?

**Respuesta correcta:** [1, 2, 32]

**Explicación:** Cada celda se combina con la del mismo lugar: no aparecen filas ni columnas nuevas.

### LAB-m2_l4

**Pregunta:** Observa un mismo token en dos posiciones distintas de la frase, con el selector de token. ¿Qué parte de su representación cambia?

**Respuesta correcta:** El vector posicional

**Explicación:** La fila del token es fija; el vector posicional depende de dónde aparece.

### LAB-m2_l5

**Pregunta:** Ejemplo de conteo: una frase de T = 4 tokens con d_model = 16 forma una tabla de 4 filas y 16 columnas. ¿Cuántos números contiene?

**Respuesta correcta:** 64

**Explicación:** 4 × 16 = 64. Cada token aporta una fila; d_model fija el ancho y no depende de la longitud de la frase.

### LAB-m2_l6

**Pregunta:** Ejemplo de escalamiento: si d_model = 100, cada componente se multiplica por √100. ¿Qué factor es, y qué se conserva?

**Respuesta correcta:** 10; se conservan los signos y las proporciones

**Explicación:** √100 = 10. Multiplicar todo por la misma constante cambia la escala, no el patrón de las componentes.

### LAB-m2_l7

**Pregunta:** En «gato ve otro gato», las dos apariciones de «gato» parten de filas iguales, pero sus sumas finales difieren. ¿Qué señal produjo la diferencia?

**Respuesta correcta:** La codificación posicional

**Explicación:** El lookup es igual para el mismo ID; al sumar posiciones distintas se obtienen representaciones distintas.

### LAB-m2_l8

**Pregunta:** Observa las capas que vienen después: cada subcapa suma su entrada y su salida. Si la representación mide [1, 3, 8], ¿qué ancho debe tener lo que se le sume?

**Respuesta correcta:** 8, el mismo ancho d_model

**Explicación:** Sólo se pueden sumar vectores del mismo ancho: por eso d_model se conserva a lo largo del Transformer.
