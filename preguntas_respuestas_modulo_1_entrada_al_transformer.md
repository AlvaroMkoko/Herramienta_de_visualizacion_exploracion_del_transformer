# Preguntas y respuestas correctas — Módulo 1: Entrada al Transformer

Generado por `tools/generar_preguntas_modulo.py`. Corresponde a la versión 15 del banco modular. El pre-test y el post-test tienen 25 reactivos disponibles cada uno; cada intento selecciona 15.

## Pregunta ancla

**Pregunta:** ¿Cómo convierte el modelo la frase «el gato duerme» en algo que pueda calcular, y qué hace con una frase más corta que comparte el mismo batch?

**Ejemplo:** Vocabulario mínimo: PAD=0, BOS=1, EOS=2, el=7, gato=15, duerme=23, sol=9. Como entradas del encoder: «el gato duerme» → [7, 15, 23] y «el sol» → [7, 9], que con relleno queda [7, 9, 0]. El batch es [2, 3] y la máscara de la segunda fila es [True, True, False]. Si «el gato duerme» fuera la salida esperada, primero se forma [1, 7, 15, 23, 2]; con teacher forcing, el decoder recibe [1, 7, 15, 23] y el objetivo es [7, 15, 23, 2].

**Cierre:** Una frase corta como «el sol» recibe relleno para compartir batch con «el gato duerme», y la máscara marca esa posición. ¿Qué hace el modelo con la posición PAD de «el sol»?

**Respuesta correcta:** La conserva en la matriz [2, 3], pero la máscara impide usarla como clave

## Comprobaciones del recorrido guiado

### R1. Texto de entrada

**Pregunta:** El tokenizador trabaja sobre el texto escrito. Antes de tokenizar, ¿qué tiene el modelo en las manos?

**Respuesta correcta:** Una cadena de caracteres: todavía no hay números

### R2. Separación en tokens

**Pregunta:** El tokenizador sólo produce piezas que existen en su vocabulario. Si «gatos» no está completa, pero «gato» y «s» sí, ¿qué esperas que haga?

**Respuesta correcta:** Dividirla en «gato» + «s»

### R3. Consulta del vocabulario

**Pregunta:** El vocabulario guarda cada token en una fila. ¿Qué obtiene cada token al consultarlo?

**Respuesta correcta:** Un índice entero estable: su fila

### R4. Construcción de Token IDs

**Pregunta:** Un ID es el número de fila de un token y la secuencia respeta el orden de la frase. Con el=7, gato=15 y duerme=23, ¿qué secuencia corresponde a «gato duerme el»?

**Respuesta correcta:** [15, 23, 7]

### R5. Tokens especiales

**Pregunta:** Antes del desplazamiento, si la salida contiene [7, 15, 23] y agregas BOS=1 al inicio y EOS=2 al final, ¿qué longitud tiene la secuencia destino completa?

**Respuesta correcta:** 5

### R6. Formación de secuencias

**Pregunta:** El contexto máximo es la mayor longitud que admite el modelo. Si es 4 y la secuencia mide 6, ¿qué debe ocurrir?

**Respuesta correcta:** Se recorta para no superar 4 posiciones

### R7. Padding del batch

**Pregunta:** PAD rellena una frase hasta que mide como la más larga del batch. Con secuencias de longitud 5 y 3, ¿cuántos PAD recibe la más corta?

**Respuesta correcta:** 2

### R8. Máscara de padding

**Pregunta:** En la máscara, True indica una posición real y False, relleno. Para [1, 7, 9, 2, 0] con PAD=0, ¿qué máscara esperas?

**Respuesta correcta:** [T, T, T, T, F]

## Pre-test

### PRE-B1

**Pregunta:** Contexto — Antes de cualquier cálculo neuronal, el texto escrito debe pasar por el tokenizador, que trabaja con el vocabulario del modelo.

¿Qué descripción explica correctamente qué hace la tokenización?

- Corta el texto en las piezas que existen en el vocabulario; es lo primero que ocurre, antes de cualquier cálculo neuronal.
- Cambia cada token por un número entero: la fila donde ese token está guardado en el vocabulario.
- Guarda los IDs en el orden de la frase y fija cuántas posiciones va a procesar el modelo.
- Agrega posiciones de relleno, sin significado, para que todas las frases de un batch midan lo mismo.

**Clave:** Corta el texto en las piezas que existen en el vocabulario; es lo primero que ocurre, antes de cualquier cálculo neuronal.

### PRE-B2

**Pregunta:** Contexto — Además de los tokens que vienen del texto, el modelo usa algunos IDs reservados para organizar las secuencias.

¿Qué descripción explica correctamente para qué sirven estos IDs reservados?

- Son IDs reservados que no vienen del texto: BOS inicia la entrada del decoder, EOS marca el último objetivo y PAD rellena las filas cortas.
- Agrega posiciones de relleno, sin significado, para que todas las frases de un batch midan lo mismo.
- Organiza los IDs en una tabla de forma [B, T]: B frases en el batch y T posiciones por frase.
- Cambia cada token por un número entero: la fila donde ese token está guardado en el vocabulario.

**Clave:** Son IDs reservados que no vienen del texto: BOS inicia la entrada del decoder, EOS marca el último objetivo y PAD rellena las filas cortas.

### PRE-B3

**Pregunta:** Contexto — Una vez separado el texto, cada token debe convertirse en algo con lo que las capas puedan trabajar.

Lee la afirmación y decide si es verdadera o falsa:

Un Token ID es el número de la fila que un token ocupa en el vocabulario.

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-B4

**Pregunta:** Contexto — Una frase llega al modelo como una lista de IDs. Piensa qué información guarda esa lista por el simple hecho de estar ordenada.

Lee la afirmación y decide si es verdadera o falsa:

El orden de los IDs no afecta la secuencia: se pueden permutar sin consecuencias.

- Verdadero
- Falso

**Clave:** Falso

### PRE-B5

**Pregunta:** Contexto — Cada concepto de este módulo resuelve un problema distinto en la preparación de la entrada. Revisa qué hace cada uno.

Selecciona las DOS asociaciones coherentes entre concepto y función.

- Vocabulario: Es la lista de piezas que el modelo reconoce; a cada una le da un ID que no cambia, y ese ID seleccionará después su fila de embedding.
- Padding: Agrega posiciones de relleno, sin significado, para que todas las frases de un batch midan lo mismo.
- Vocabulario: Agrega posiciones de relleno, sin significado, para que todas las frases de un batch midan lo mismo.
- Padding: Es la lista de piezas que el modelo reconoce; a cada una le da un ID que no cambia, y ese ID seleccionará después su fila de embedding.

**Clave:** Vocabulario: Es la lista de piezas que el modelo reconoce; a cada una le da un ID que no cambia, y ese ID seleccionará después su fila de embedding. · Padding: Agrega posiciones de relleno, sin significado, para que todas las frases de un batch midan lo mismo.

### PRE-B6

**Pregunta:** Contexto — La preparación de la entrada es una cadena: la salida de cada etapa alimenta a la siguiente.

Completa el flujo: Construcción de Token IDs → ________ → Formación de secuencias.

**Clave:** Tokens especiales

### PRE-B7

**Pregunta:** Contexto — Cada etapa existe para resolver un problema concreto; identifica cuál resuelve cada una.

Relaciona cada etapa con el motivo por el que se realiza.

**Clave:** Texto de entrada → El tokenizador necesita partir de un texto concreto y bien definido · Consulta del vocabulario → Las capas sólo pueden calcular con números, no con texto · Tokens especiales → BOS le da al decoder un primer token de entrada y EOS le indica cuándo terminar · Padding del batch → Un batch se guarda como tabla, y una tabla necesita filas del mismo largo

### PRE-B8

**Pregunta:** Contexto — En las formas, B es el número de frases del batch, T el número de posiciones de una frase y T_max la longitud de la frase más larga.

Al terminar el paso «Padding del batch», ¿qué forma (dimensiones) tiene el tensor que se obtiene? Escríbela eje por eje con los símbolos del recorrido.

**Clave:** [B, T_max]

### PRE-I1

**Pregunta:** Contexto — El punto de partida es el texto escrito. Ordena las operaciones usando la salida de una como entrada de la siguiente.

Ordena las etapas según el flujo real de información.

**Clave:** Texto de entrada → Separación en tokens → Consulta del vocabulario → Construcción de Token IDs

### PRE-I2

**Pregunta:** Contexto — El punto de partida son los IDs de una frase. Ordena las operaciones que los llevan hasta estar listos para un batch.

Ordena las etapas según el flujo real de información.

**Clave:** Tokens especiales → Formación de secuencias → Padding del batch → Máscara de padding

### PRE-I3

**Pregunta:** Contexto — Aquí debes relacionar cada transformación con el resultado inmediato que deja, no con el de pasos posteriores.

Relaciona cada transformación con la información que produce.

**Clave:** Texto de entrada → Texto listo para tokenizar · Consulta del vocabulario → Relación token ↔ fila · Tokens especiales → Secuencia destino completa con BOS y EOS · Padding del batch → Matriz de IDs

### PRE-I4

**Pregunta:** Contexto — Sigue qué cambia realmente en cada etapa: la forma de los datos, su tipo o las posiciones disponibles.

Relaciona cada etapa con el cambio observable que produce.

**Clave:** Separación en tokens → Una sola cadena pasa a ser una lista ordenada de tokens · Construcción de Token IDs → La secuencia deja de ser texto y pasa a ser una lista de enteros · Formación de secuencias → La longitud queda dentro del máximo que admite el modelo · Máscara de padding → Se añaden ejes a la máscara para que pueda aplicarse a los scores de atención

### PRE-I5

**Pregunta:** Contexto — Una justificación correcta explica para qué hace falta una operación; no basta con repetir su nombre.

Selecciona las DOS explicaciones que justifican correctamente su etapa.

- Consulta del vocabulario: Las capas sólo pueden calcular con números, no con texto
- Formación de secuencias: El lugar de cada ID cambia lo que dice la frase
- Consulta del vocabulario: El lugar de cada ID cambia lo que dice la frase
- Formación de secuencias: Las capas sólo pueden calcular con números, no con texto

**Clave:** Consulta del vocabulario: Las capas sólo pueden calcular con números, no con texto · Formación de secuencias: El lugar de cada ID cambia lo que dice la frase

### PRE-I6

**Pregunta:** Contexto — Para decidir si dos etapas son consecutivas, comprueba que la salida de la primera sea la entrada que necesita la segunda.

Lee la afirmación y decide si es verdadera o falsa:

En el flujo del módulo, después de «Separación en tokens» ocurre «Consulta del vocabulario».

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-I7

**Pregunta:** Contexto — La pregunta ya indica la entrada de una operación. Elige su salida inmediata, no el resultado final de la preparación.

Completa: «Padding del batch» recibe Secuencias de longitudes distintas y produce ________.

**Clave:** Matriz de IDs

### PRE-I8

**Pregunta:** Contexto — El propósito explica por qué hace falta la operación; no es una descripción de sus pasos.

¿Por qué se realiza «Formación de secuencias»?

- El lugar de cada ID cambia lo que dice la frase
- El tokenizador necesita partir de un texto concreto y bien definido
- Permite representar palabras conocidas, y también desconocidas, con piezas reutilizables
- Las capas sólo pueden calcular con números, no con texto

**Clave:** El lugar de cada ID cambia lo que dice la frase

### PRE-I9

**Pregunta:** Contexto — Un par entrada→salida sólo es válido si ambos pertenecen a la misma etapa; no mezcles etapas.

Selecciona los DOS pares que describen la entrada y la salida de una misma etapa del recorrido.

- Una cadena de texto legible → Texto listo para tokenizar
- Tabla de IDs que contiene PAD → IDs + máscara
- Una cadena de texto legible → IDs + máscara
- Tabla de IDs que contiene PAD → Texto listo para tokenizar

**Clave:** Una cadena de texto legible → Texto listo para tokenizar · Tabla de IDs que contiene PAD → IDs + máscara

### PRE-A1

**Pregunta:** Contexto — Una forma se escribe con un número por eje, de izquierda a derecha: primero las frases del batch y luego las posiciones.

Resuelve sin opciones: Un batch reúne varias frases en una tabla: una fila por frase y una columna por posición. Si contiene 3 secuencias rellenadas a 7 posiciones, ¿qué forma tiene el tensor de IDs?

**Clave:** [3, 7]

### PRE-A2

**Pregunta:** Contexto — La máscara tiene un valor por posición y sigue el mismo orden que la secuencia. El enunciado indica qué significa cada valor.

La máscara de claves marca con True las posiciones que la atención puede consultar y con False el relleno. Para la secuencia [18, 42, PAD, PAD], ¿qué fila lógica le corresponde?

- [True, True, False, False]
- [False, False, True, True]
- [True, False, True, False]
- [True, True, True, True]

**Clave:** [True, True, False, False]

### PRE-A3

**Pregunta:** Contexto — Cada opción une una situación de preparación de datos con un resultado. Evalúa cada una por separado.

Selecciona las DOS opciones en las que la situación y su resultado están emparejados correctamente.

- Palabra ausente, pero con piezas conocidas → se divide en subpalabras.
- Secuencias de 3 y 7 posiciones → la corta recibe 4 PAD.
- Palabra ausente, pero con piezas conocidas → se elimina de la frase.
- Secuencias de 3 y 7 posiciones → la corta recibe 7 PAD.

**Clave:** Palabra ausente, pero con piezas conocidas → se divide en subpalabras. · Secuencias de 3 y 7 posiciones → la corta recibe 4 PAD.

### PRE-A4

**Pregunta:** Contexto — Las cuatro tarjetas forman una sola preparación. Ordénalas de modo que cada una reciba lo que produjo la anterior.

Reconstruye el orden necesario para que la transformación sea válida.

**Clave:** Separación en tokens → Consulta del vocabulario → Construcción de Token IDs → Tokens especiales

### PRE-A5

**Pregunta:** Contexto — Resuelve cada situación por separado. Recuerda que un ID sólo señala una fila y que PAD no tiene significado.

Relaciona cada situación con la conclusión correcta. Cada conclusión se usa una sola vez.

**Clave:** Una secuencia es una lista de IDs en el orden de la frase. Si se intercambian los IDs de dos tokens, ¿qué propiedad cambia antes de añadir posición? → El orden de la secuencia · El vocabulario es una tabla donde cada token ocupa una fila. Si tiene 30 000 entradas, ¿qué indica el ID 172? → Selecciona la fila 172 asociada al token · La máscara detecta el relleno comparando cada ID con el de PAD. ¿Por qué PAD necesita un ID reservado, distinto del de cualquier token de contenido? → La máscara no podría distinguir relleno de contenido

### PRE-A6

**Pregunta:** Contexto — Piensa qué impide realmente que el relleno participe en la atención: su valor numérico o la máscara.

Lee la afirmación y decide si es verdadera o falsa:

Caso: en un batch [2, 6], una fila tiene 2 posiciones PAD. Si se olvida la máscara de padding, la atención puede repartir peso hacia esas dos posiciones de relleno.

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-A7

**Pregunta:** Contexto — Cada frase recibe tantos PAD como posiciones le falten para igualar a la más larga; el total suma los de todas.

Responde sin opciones: Un batch tiene 3 frases de longitudes 4, 6 y 2, rellenadas a la mayor. ¿Cuántos PAD hay en total?

**Clave:** 6

### PRE-A8

**Pregunta:** Contexto — Los IDs identifican tokens y guardan su orden. Considera qué información todavía no existe en este punto.

Cada token se cambia por el número de su fila: los tokens [«la», «casa»] se mapean a [31, 805]. ¿Qué conserva esa lista?

- Identidad y orden discretos
- Significado contextual completo
- Pesos de atención
- Probabilidades del siguiente token

**Clave:** Identidad y orden discretos

## Post-test

### POST-B1

**Pregunta:** Contexto — Antes de cualquier cálculo neuronal, el texto escrito debe pasar por el tokenizador, que trabaja con el vocabulario del modelo.

¿Qué ocurre en la primera etapa, antes de separar nada?

- Recibir el texto como una cadena de caracteres, sin separarlo todavía
- Cortar el texto en piezas usando el vocabulario de subpalabras
- Buscar cada token en el vocabulario para encontrar su fila
- Sustituir cada token por el índice de su fila

**Clave:** Recibir el texto como una cadena de caracteres, sin separarlo todavía

### POST-B2

**Pregunta:** Contexto — Además de los tokens que vienen del texto, el modelo usa algunos IDs reservados para organizar las secuencias.

¿Qué operación agrega los tokens reservados a la secuencia de destino?

- Construir [BOS] + IDs + [EOS] antes del desplazamiento
- Conservar el orden de los IDs y recortar lo que exceda el contexto máximo
- Completar las frases cortas con PAD hasta medir como la más larga
- Marcar cuáles posiciones son reales y cuáles están bloqueadas

**Clave:** Construir [BOS] + IDs + [EOS] antes del desplazamiento

### POST-B3

**Pregunta:** Contexto — Una vez separado el texto, cada token debe convertirse en algo con lo que las capas puedan trabajar.

Lee la afirmación y decide si es verdadera o falsa:

Un Token ID contiene por sí solo el vector contextual completo de su token.

- Verdadero
- Falso

**Clave:** Falso

### POST-B4

**Pregunta:** Contexto — Una frase llega al modelo como una lista de IDs. Piensa qué información guarda esa lista por el simple hecho de estar ordenada.

Lee la afirmación y decide si es verdadera o falsa:

Una secuencia conserva el orden de los IDs y determina cuántas posiciones procesará el modelo.

- Verdadero
- Falso

**Clave:** Verdadero

### POST-B5

**Pregunta:** Contexto — Cada concepto de este módulo resuelve un problema distinto en la preparación de la entrada. Revisa qué hace cada uno.

Selecciona las DOS asociaciones coherentes entre concepto y función.

- Secuencias: Guarda los IDs en el orden de la frase y fija cuántas posiciones va a procesar el modelo.
- Máscara de padding: Indica qué posiciones son relleno para que la atención no las consulte como claves ni tome información de ellas.
- Secuencias: Indica qué posiciones son relleno para que la atención no las consulte como claves ni tome información de ellas.
- Máscara de padding: Guarda los IDs en el orden de la frase y fija cuántas posiciones va a procesar el modelo.

**Clave:** Secuencias: Guarda los IDs en el orden de la frase y fija cuántas posiciones va a procesar el modelo. · Máscara de padding: Indica qué posiciones son relleno para que la atención no las consulte como claves ni tome información de ellas.

### POST-B6

**Pregunta:** Contexto — La preparación de la entrada es una cadena: la salida de cada etapa alimenta a la siguiente.

Completa el flujo: Tokens especiales → ________ → Padding del batch.

**Clave:** Formación de secuencias

### POST-B7

**Pregunta:** Contexto — Cada etapa existe para resolver un problema concreto; identifica cuál resuelve cada una.

Relaciona cada etapa con el motivo por el que se realiza.

**Clave:** Separación en tokens → Permite representar palabras conocidas, y también desconocidas, con piezas reutilizables · Construcción de Token IDs → Ese número seleccionará después la fila correcta de la tabla de embeddings · Formación de secuencias → El lugar de cada ID cambia lo que dice la frase · Máscara de padding → El relleno no debe consultarse como clave ni aportar contenido a otras posiciones

### POST-B8

**Pregunta:** Contexto — En las formas, B es el número de frases del batch, T el número de posiciones de una frase y T_max la longitud de la frase más larga.

Al terminar el paso «Construcción de Token IDs», ¿qué forma (dimensiones) tiene el tensor que se obtiene? Escríbela eje por eje con los símbolos del recorrido.

**Clave:** [T]

### POST-I1

**Pregunta:** Contexto — El punto de partida es el texto escrito. Ordena las operaciones usando la salida de una como entrada de la siguiente.

Ordena las etapas según el flujo real de información.

**Clave:** Separación en tokens → Consulta del vocabulario → Construcción de Token IDs → Tokens especiales

### POST-I2

**Pregunta:** Contexto — El punto de partida son los IDs de una frase. Ordena las operaciones que los llevan hasta estar listos para un batch.

Ordena las etapas según el flujo real de información.

**Clave:** Construcción de Token IDs → Tokens especiales → Formación de secuencias → Padding del batch

### POST-I3

**Pregunta:** Contexto — Aquí debes relacionar cada transformación con el resultado inmediato que deja, no con el de pasos posteriores.

Relaciona cada transformación con la información que produce.

**Clave:** Separación en tokens → Tokens visibles · Construcción de Token IDs → Secuencia de IDs · Formación de secuencias → Secuencia del ejemplo · Máscara de padding → IDs + máscara

### POST-I4

**Pregunta:** Contexto — Sigue qué cambia realmente en cada etapa: la forma de los datos, su tipo o las posiciones disponibles.

Relaciona cada etapa con el cambio observable que produce.

**Clave:** Texto de entrada → Todavía no hay tokens ni números: sólo letras y espacios · Consulta del vocabulario → Cada pieza de texto obtiene una dirección dentro de la tabla · Tokens especiales → La secuencia de destino gana dos posiciones antes de desplazarse · Padding del batch → Aparecen posiciones de relleno que no vienen del texto

### POST-I5

**Pregunta:** Contexto — Una justificación correcta explica para qué hace falta una operación; no basta con repetir su nombre.

Selecciona las DOS explicaciones que justifican correctamente su etapa.

- Separación en tokens: Permite representar palabras conocidas, y también desconocidas, con piezas reutilizables
- Padding del batch: Un batch se guarda como tabla, y una tabla necesita filas del mismo largo
- Separación en tokens: Un batch se guarda como tabla, y una tabla necesita filas del mismo largo
- Padding del batch: Permite representar palabras conocidas, y también desconocidas, con piezas reutilizables

**Clave:** Separación en tokens: Permite representar palabras conocidas, y también desconocidas, con piezas reutilizables · Padding del batch: Un batch se guarda como tabla, y una tabla necesita filas del mismo largo

### POST-I6

**Pregunta:** Contexto — Para decidir si dos etapas son consecutivas, comprueba que la salida de la primera sea la entrada que necesita la segunda.

Lee la afirmación y decide si es verdadera o falsa:

En el flujo del módulo, después de «Separación en tokens» ocurre «Tokens especiales».

- Verdadero
- Falso

**Clave:** Falso

### POST-I7

**Pregunta:** Contexto — La pregunta ya indica la entrada de una operación. Elige su salida inmediata, no el resultado final de la preparación.

Completa: «Tokens especiales» recibe IDs de la frase de destino y produce ________.

**Clave:** Secuencia destino completa con BOS y EOS

### POST-I8

**Pregunta:** Contexto — El propósito explica por qué hace falta la operación; no es una descripción de sus pasos.

¿Por qué se realiza «Consulta del vocabulario»?

- Las capas sólo pueden calcular con números, no con texto
- El tokenizador necesita partir de un texto concreto y bien definido
- BOS le da al decoder un primer token de entrada y EOS le indica cuándo terminar
- El relleno no debe consultarse como clave ni aportar contenido a otras posiciones

**Clave:** Las capas sólo pueden calcular con números, no con texto

### POST-I9

**Pregunta:** Contexto — Un par entrada→salida sólo es válido si ambos pertenecen a la misma etapa; no mezcles etapas.

Selecciona los DOS pares que describen la entrada y la salida de una misma etapa del recorrido.

- Texto listo para tokenizar → Tokens visibles
- Secuencias de longitudes distintas → Matriz de IDs
- Texto listo para tokenizar → Matriz de IDs
- Secuencias de longitudes distintas → Tokens visibles

**Clave:** Texto listo para tokenizar → Tokens visibles · Secuencias de longitudes distintas → Matriz de IDs

### POST-A1

**Pregunta:** Contexto — Una forma se escribe con un número por eje, de izquierda a derecha: primero las frases del batch y luego las posiciones.

Resuelve sin opciones: Un batch es una tabla con una fila por frase y una columna por posición. Reúne 4 frases y todas quedan rellenadas a 9 posiciones. ¿Qué forma tiene el tensor de Token IDs?

**Clave:** [4, 9]

### POST-A2

**Pregunta:** Contexto — La máscara tiene un valor por posición y sigue el mismo orden que la secuencia. El enunciado indica qué significa cada valor.

En la máscara de claves, True indica una posición que se puede consultar y False, relleno. Para [64, 12, 9, PAD], ¿qué fila lógica le corresponde?

- [True, True, True, False]
- [False, False, False, True]
- [True, False, True, False]
- [True, True, True, True]

**Clave:** [True, True, True, False]

### POST-A3

**Pregunta:** Contexto — Cada opción une una situación de preparación de datos con un resultado. Evalúa cada una por separado.

Selecciona las DOS opciones en las que la situación y su resultado están emparejados correctamente.

- Palabra nueva formada con piezas conocidas → salen esas piezas.
- Secuencias de 5 y 9 posiciones → la corta recibe 4 PAD.
- Palabra nueva formada con piezas conocidas → sale un vector al azar.
- Secuencias de 5 y 9 posiciones → la corta recibe 9 PAD.

**Clave:** Palabra nueva formada con piezas conocidas → salen esas piezas. · Secuencias de 5 y 9 posiciones → la corta recibe 4 PAD.

### POST-A4

**Pregunta:** Contexto — Las cuatro tarjetas forman una sola preparación. Ordénalas de modo que cada una reciba lo que produjo la anterior.

Reconstruye el orden necesario para que la transformación sea válida.

**Clave:** Consulta del vocabulario → Construcción de Token IDs → Tokens especiales → Formación de secuencias

### POST-A5

**Pregunta:** Contexto — Resuelve cada situación por separado. Recuerda que un ID sólo señala una fila y que PAD no tiene significado.

Relaciona cada situación con la conclusión correcta. Cada conclusión se usa una sola vez.

**Clave:** «perro muerde hombre» y «hombre muerde perro» usan los mismos tres IDs. Antes de añadir posición, ¿qué propiedad las distingue? → El orden de la secuencia · El vocabulario guarda cada token en una fila. En uno de 50 000 entradas, el token «río» tiene el ID 2 931. ¿Qué indica ese número? → Selecciona la fila 2 931 asociada al token · La máscara reconoce el relleno por su ID. Un equipo reutiliza el ID de la palabra «the» como PAD. ¿Qué problema aparece? → La máscara no podría distinguir relleno de contenido

### POST-A6

**Pregunta:** Contexto — Piensa qué impide realmente que el relleno participe en la atención: su valor numérico o la máscara.

Lee la afirmación y decide si es verdadera o falsa:

Caso: un batch [3, 8] contiene filas con PAD. Aunque no exista máscara, la atención nunca asigna peso al relleno porque su ID es 0.

- Verdadero
- Falso

**Clave:** Falso

### POST-A7

**Pregunta:** Contexto — Cada frase recibe tantos PAD como posiciones le falten para igualar a la más larga; el total suma los de todas.

Responde sin opciones: Un batch tiene 4 frases de longitudes 5, 7, 6 y 3, rellenadas a la mayor. ¿Cuántos PAD hay en total?

**Clave:** 7

### POST-A8

**Pregunta:** Contexto — Los IDs identifican tokens y guardan su orden. Considera qué información todavía no existe en este punto.

Cada token se cambia por el número de su fila: [«sol», «de», «mayo»] se mapean a [412, 9, 1077]. ¿Qué información contiene ya esa lista?

- Identidad y orden discretos
- Significado contextual completo
- Pesos de atención
- Probabilidades del siguiente token

**Clave:** Identidad y orden discretos

## Retos del laboratorio

### LAB-m1_l1

**Pregunta:** Ejemplo de batch: 2 frases quedan rellenadas a 5 posiciones, cada frase en una fila. ¿Cómo se escribe la forma de esa tabla de IDs?

**Respuesta correcta:** [2, 5]

**Explicación:** La forma se lee [B, T]: 2 filas (frases) y 5 columnas (posiciones). El relleno ocupa sólo las celdas sobrantes.

### LAB-m1_l2

**Pregunta:** Ejemplo con relleno: la fila [11, 25, 40, PAD] va a la atención. Si True significa que se puede consultar, ¿qué máscara le toca?

**Respuesta correcta:** [True, True, True, False]

**Explicación:** Las tres posiciones reales quedan permitidas y PAD queda bloqueada, para que el relleno no aporte información.

### LAB-m1_l3

**Pregunta:** Observa los chips de la etapa de tokenización: una palabra larga puede quedar repartida en varios chips consecutivos. ¿Qué interpretación es coherente?

**Respuesta correcta:** El tokenizador encontró varias piezas conocidas para representarla

**Explicación:** Los chips muestran subpalabras del vocabulario que, juntas y en orden, representan la palabra.

### LAB-m1_l4

**Pregunta:** Ejemplo de padding: en un batch, una frase mide 3 y la más larga mide 8. ¿Cuántos PAD recibe la corta, y qué pasa con sus tokens reales?

**Respuesta correcta:** 5 PAD al final; sus tokens y su orden no cambian

**Explicación:** 8 − 3 = 5. Padding extiende la fila por la derecha, sin sustituir ni reordenar su contenido.

### LAB-m1_l5

**Pregunta:** Compara dos frases escritas con las mismas palabras en distinto orden: cada palabra conserva su ID, pero cambia de columna. ¿Qué demuestra esto?

**Respuesta correcta:** La identidad se conserva, pero la secuencia cambia

**Explicación:** Mover un token no cambia su entrada de vocabulario; cambia su lugar dentro de la secuencia.

### LAB-m1_l6

**Pregunta:** Observa el paso de consulta del vocabulario: dos apariciones de una misma palabra señalan la misma fila. ¿Qué puede variar más adelante?

**Respuesta correcta:** Su representación contextual por estar rodeadas de tokens distintos

**Explicación:** El ID es estable; posición y atención harán que cada aparición adquiera un contexto diferente.

### LAB-m1_l7

**Pregunta:** BOS, EOS y PAD usan IDs reservados: nunca coinciden con una palabra del texto. Si PAD compartiera ID con «casa», ¿qué dejaría de ser posible?

**Respuesta correcta:** Que la máscara distinga el relleno de un token real

**Explicación:** La máscara se calcula comparando IDs con el de PAD: si coincide con una palabra, esa palabra también quedaría bloqueada.

### LAB-m1_l8

**Pregunta:** Ejemplo: «banco» recibe el mismo ID en «el banco del río» y en «el banco cerró». ¿Dónde deberá resolverse la diferencia de sentido?

**Respuesta correcta:** En las representaciones contextuales construidas por la atención

**Explicación:** El ID identifica texto, no sentido; la atención incorpora las palabras vecinas para desambiguarlo.
