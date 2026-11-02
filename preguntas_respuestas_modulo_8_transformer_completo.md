# Preguntas y respuestas correctas — Módulo 8: Transformer completo

Generado por `tools/generar_preguntas_modulo.py`. Corresponde a la versión 16 del banco modular. El pre-test y el post-test tienen 25 reactivos disponibles cada uno; cada intento selecciona 15.

## Pregunta ancla

**Pregunta:** ¿Qué recorrido hace la frase «hola mundo» desde el texto hasta la primera palabra de la respuesta, y qué forma tiene la información en cada etapa?

**Ejemplo:** B = 1, fuente [hola, mundo] (T_src = 2), d_model = 128 y |V| = 8 000. Con IDs de ejemplo [31, 47] → embeddings + posición [1, 2, 128] → N capas encoder → memoria [1, 2, 128]. El decoder recibe el prefijo [BOS] → [1, 1, 128] → cross-attention con un mapa [1, 2] por cabeza → logits [1, 1, 8 000] → softmax → token «hello» → nuevo prefijo [BOS, hello], y el ciclo se repite.

**Cierre:** Mientras se genera la respuesta a «hola mundo», la frase de origen no cambia, pero se va escribiendo una frase nueva. ¿Qué se reutiliza en cada paso de generación y qué cambia?

**Respuesta correcta:** La memoria del encoder se reutiliza; el prefijo del decoder crece

## Comprobaciones del recorrido guiado

### R1. Preparar fuente y destino

**Pregunta:** Los IDs forman una tabla de forma [B, T_src]. La fuente tiene 4 tokens y el batch es 1. ¿Qué forma tienen src_ids?

**Respuesta correcta:** [1, 4]

### R2. Embeddings + posición

**Pregunta:** El embedding agrega un eje de d_model componentes a cada ID. Los IDs [1, 4] con d_model = 128 se convierten en:

**Respuesta correcta:** [1, 4, 128]

### R3. Recorrer encoder

**Pregunta:** Cada capa del encoder entrega la misma forma que recibe. Después de N capas, ¿cambia la forma [1, 4, 128]?

**Respuesta correcta:** No

### R4. Autoatención causal

**Pregunta:** En la atención causal, una posición ve su lugar y los anteriores. Con el prefijo [BOS, hello], ¿qué ve la posición de «hello»?

**Respuesta correcta:** BOS y hello

### R5. Cross-attention y FFN

**Pregunta:** En cross-attention, las filas son del decoder y las columnas, de la fuente. Si el decoder tiene 2 posiciones y la fuente 4, ¿qué forma tiene el mapa?

**Respuesta correcta:** [2, 4]

### R6. Logits y probabilidades

**Pregunta:** Softmax da una probabilidad por token del vocabulario. Con |V| = 8 000, ¿cuántas probabilidades hay para la posición que predice?

**Respuesta correcta:** 8 000

### R7. Token siguiente

**Pregunta:** Una vez elegido el candidato, el modelo debe escribirlo como texto. ¿Qué produce la selección del token?

**Respuesta correcta:** Un ID nuevo que se decodifica a texto

### R8. Ciclo completo

**Pregunta:** La frase de origen no cambia mientras se genera la respuesta. En el ciclo completo, ¿qué parte se calcula una sola vez por frase?

**Respuesta correcta:** La memoria del encoder

## Pre-test

### PRE-B1

**Pregunta:** Contexto — El recorrido completo empieza con texto, pero el modelo sólo puede calcular con números.

¿Qué descripción explica correctamente la primera parte del recorrido?

- Convierte la frase de origen y el prefijo en secuencias de enteros, con sus máscaras.
- Elige los embeddings y les suma la posición para formar X, la primera representación continua.
- Combina el prefijo, sin ver el futuro, con la memoria del encoder mediante N capas.
- Comprueba que la forma de cada salida sea la que espera la etapa siguiente.

**Clave:** Convierte la frase de origen y el prefijo en secuencias de enteros, con sus máscaras.

### PRE-B2

**Pregunta:** Contexto — Al final del recorrido, un estado interno debe convertirse en una palabra escrita.

¿Qué descripción explica correctamente qué ocurre en esa última parte?

- Convierte el último estado en probabilidades y elige un Token ID.
- Comprueba que la forma de cada salida sea la que espera la etapa siguiente.
- Relaciona mapas, activaciones y probabilidades sin confundir qué mide cada uno.
- Elige los embeddings y les suma la posición para formar X, la primera representación continua.

**Clave:** Convierte el último estado en probabilidades y elige un Token ID.

### PRE-B3

**Pregunta:** Contexto — Los IDs por sí solos son símbolos: hay que convertirlos en vectores antes de entrar a las capas.

Lee la afirmación y decide si es verdadera o falsa:

Los embeddings y la posición convierten cada ID en un vector para formar X.

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-B4

**Pregunta:** Contexto — Dentro de la pila del decoder, cada posición usa dos fuentes de información.

Lee la afirmación y decide si es verdadera o falsa:

El decoder procesa el destino sin usar el prefijo causal ni la memoria del encoder.

- Verdadero
- Falso

**Clave:** Falso

### PRE-B5

**Pregunta:** Contexto — Cada concepto de este módulo describe una parte distinta del recorrido. Revisa qué hace cada uno.

Selecciona las DOS asociaciones coherentes entre concepto y función.

- Pila encoder: Da contexto a toda la frase de origen mediante N capas y produce la memoria.
- Rastreo de dimensiones: Comprueba que la forma de cada salida sea la que espera la etapa siguiente.
- Pila encoder: Comprueba que la forma de cada salida sea la que espera la etapa siguiente.
- Rastreo de dimensiones: Da contexto a toda la frase de origen mediante N capas y produce la memoria.

**Clave:** Pila encoder: Da contexto a toda la frase de origen mediante N capas y produce la memoria. · Rastreo de dimensiones: Comprueba que la forma de cada salida sea la que espera la etapa siguiente.

### PRE-B6

**Pregunta:** Contexto — El flujo completo es una cadena: la salida de cada etapa alimenta a la siguiente.

Completa el flujo: Autoatención causal → ________ → Logits y probabilidades.

**Clave:** Cross-attention y FFN

### PRE-B7

**Pregunta:** Contexto — Cada etapa resuelve un problema distinto a lo largo del recorrido.

Relaciona cada etapa con el motivo por el que se realiza.

**Clave:** Preparar fuente y destino → Deja entradas válidas para ambos lados del modelo · Recorrer encoder → Construye una memoria de la frase de origen con contexto en cada token · Cross-attention y FFN → Permite buscar en la frase de origen lo que hace falta para continuar · Token siguiente → Convierte las probabilidades en una palabra concreta

### PRE-B8

**Pregunta:** Contexto — En las formas, B es el número de ejemplos, T_src y T_tgt las longitudes de fuente y destino, d_model el ancho y |V| el tamaño del vocabulario.

Al terminar el paso «Logits y probabilidades», ¿qué forma (dimensiones) tiene el tensor que se obtiene? Escríbela eje por eje con los símbolos del recorrido.

**Clave:** [B,|V|]

### PRE-I1

**Pregunta:** Contexto — El punto de partida es el texto. Ordena las operaciones usando la salida de una como entrada de la siguiente.

Ordena las etapas según el flujo real de información.

**Clave:** Preparar fuente y destino → Embeddings + posición → Recorrer encoder → Autoatención causal

### PRE-I2

**Pregunta:** Contexto — El punto de partida son los vectores de entrada. Ordena las operaciones que llevan hasta el estado del decoder.

Ordena las etapas según el flujo real de información.

**Clave:** Cross-attention y FFN → Logits y probabilidades → Token siguiente → Ciclo completo

### PRE-I3

**Pregunta:** Contexto — Aquí debes relacionar cada transformación con el resultado inmediato que deja, no con el de pasos posteriores.

Relaciona cada transformación con la información que produce.

**Clave:** Preparar fuente y destino → src_ids y tgt_ids · Recorrer encoder → Memoria · Cross-attention y FFN → Salida de N capas · Token siguiente → Token y texto parcial

### PRE-I4

**Pregunta:** Contexto — Sigue qué cambia realmente en cada etapa: pueden cambiar los ejes, los valores o la información que llevan.

Relaciona cada etapa con el cambio observable que produce.

**Clave:** Embeddings + posición → Los enteros pasan a ser vectores de d_model números · Autoatención causal → Se forma un estado que sólo conoce lo ya escrito · Logits y probabilidades → El último eje pasa de d_model a |V| · Ciclo completo → Las transformaciones parciales se entienden como un solo flujo

### PRE-I5

**Pregunta:** Contexto — Una justificación correcta explica para qué es necesaria una operación; no basta con repetir su nombre.

Selecciona las DOS explicaciones que justifican correctamente su etapa.

- Recorrer encoder: Construye una memoria de la frase de origen con contexto en cada token
- Logits y probabilidades: Permite comparar todos los tokens que se podrían escribir
- Recorrer encoder: Permite comparar todos los tokens que se podrían escribir
- Logits y probabilidades: Construye una memoria de la frase de origen con contexto en cada token

**Clave:** Recorrer encoder: Construye una memoria de la frase de origen con contexto en cada token · Logits y probabilidades: Permite comparar todos los tokens que se podrían escribir

### PRE-I6

**Pregunta:** Contexto — Para decidir si dos etapas son consecutivas, comprueba que la salida de la primera sea la entrada que necesita la segunda.

Lee la afirmación y decide si es verdadera o falsa:

En el flujo del módulo, después de «Embeddings + posición» ocurre «Recorrer encoder».

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-I7

**Pregunta:** Contexto — La pregunta ya indica la entrada de una operación. Elige su salida inmediata, no el resultado final del modelo.

Completa: «Token siguiente» recibe La distribución de probabilidad y produce ________.

**Clave:** Token y texto parcial

### PRE-I8

**Pregunta:** Contexto — El propósito explica por qué hace falta la operación; no es una descripción de sus pasos.

¿Por qué se realiza «Logits y probabilidades»?

- Permite comparar todos los tokens que se podrían escribir
- Deja entradas válidas para ambos lados del modelo
- Construye una memoria de la frase de origen con contexto en cada token
- Convierte las probabilidades en una palabra concreta

**Clave:** Permite comparar todos los tokens que se podrían escribir

### PRE-I9

**Pregunta:** Contexto — Un par entrada→salida sólo es válido si ambos pertenecen a la misma etapa; no mezcles etapas.

Selecciona los DOS pares que describen la entrada y la salida de una misma etapa del recorrido.

- La frase de origen y el prefijo → src_ids y tgt_ids
- El registro de todas las etapas → Comprensión de extremo a extremo
- La frase de origen y el prefijo → Comprensión de extremo a extremo
- El registro de todas las etapas → src_ids y tgt_ids

**Clave:** La frase de origen y el prefijo → src_ids y tgt_ids · El registro de todas las etapas → Comprensión de extremo a extremo

### PRE-A1

**Pregunta:** Contexto — Cada eje de una forma tiene un significado. Identifica cuál cambia en la capa de salida y cuáles se conservan.

Resuelve sin opciones: La capa de salida cambia el último eje de d_model a |V|, y conserva los demás. ¿Qué forma produce a partir de [B,T,d_model]?

**Clave:** El último eje: [B,T,|V|]

### PRE-A2

**Pregunta:** Contexto — El encoder y el decoder se conectan mediante un solo tensor. Piensa qué lado lo produce.

En cross-attention, el decoder consulta una representación de la frase de origen ya procesada. ¿Qué componente produce esa memoria?

- La salida final del encoder
- Los logits finales
- La máscara causal
- Top-P

**Clave:** La salida final del encoder

### PRE-A3

**Pregunta:** Contexto — Cada opción une un dato con su resultado. Evalúa cada una por separado.

Selecciona las DOS opciones en las que el dato y su resultado están emparejados correctamente.

- Fuente con PAD y destino sin ver el futuro → padding y causal.
- Decoder en cross-attention → consulta la memoria del encoder.
- Fuente con PAD y destino sin ver el futuro → Top-P y Top-K.
- Decoder en cross-attention → consulta los logits finales.

**Clave:** Fuente con PAD y destino sin ver el futuro → padding y causal. · Decoder en cross-attention → consulta la memoria del encoder.

### PRE-A4

**Pregunta:** Contexto — Las cuatro tarjetas forman un solo recorrido. Ordénalas de modo que la salida de cada una sirva a la siguiente.

Reconstruye el orden necesario para que la transformación sea válida.

**Clave:** Embeddings + posición → Recorrer encoder → Autoatención causal → Cross-attention y FFN

### PRE-A5

**Pregunta:** Contexto — Resuelve cada situación por separado. Recuerda qué mide cada número del modelo y en qué etapa aparece.

Relaciona cada situación con la conclusión correcta. Cada conclusión se usa una sola vez.

**Clave:** El flujo empieza con IDs enteros, que todavía son símbolos. ¿Cuál es la primera representación continua que aparece después de ellos? → Embedding escalado más posición · Un peso de atención reparte información entre tokens, y una probabilidad final puntúa el vocabulario. Un peso de atención alto, ¿significa directamente una probabilidad alta del token de salida? → No; operan en espacios y etapas distintas · La frase de salida se genera un token por vuelta, y la memoria de la fuente no cambia. ¿Qué realimenta el siguiente paso? → El prefijo del decoder

### PRE-A6

**Pregunta:** Contexto — Compara qué tiene disponible el decoder al generar y qué tiene al entrenar. Evalúa exactamente lo que afirma el caso.

Lee la afirmación y decide si es verdadera o falsa:

Caso: en inferencia autoregresiva, la memoria del encoder puede calcularse una sola vez y reutilizarse mientras el decoder genera token por token.

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-A7

**Pregunta:** Contexto — Los logits tienen tres ejes, y cada combinación de sus índices es un score.

Responde sin opciones: El total de scores es el producto de los ejes de los logits. Un ejemplo con T_tgt = 3 y |V| = 1 000 produce logits [1, 3, 1 000]. ¿Cuántos scores contiene?

**Clave:** 3 000

### PRE-A8

**Pregunta:** Contexto — Un peso de atención y una probabilidad del vocabulario se calculan en etapas distintas, sobre elementos distintos.

La memoria conserva un vector de d_model números por token de la fuente. Con B=1, T_src=6 y d_model=128, ¿qué forma tiene?

- [1,6,128]
- [1,128,6]
- [6,6]
- [1,6,|V|]

**Clave:** [1,6,128]

## Post-test

### POST-B1

**Pregunta:** Contexto — El recorrido completo empieza con texto, pero el modelo sólo puede calcular con números.

¿Qué operación convierte el texto en datos para el modelo?

- Tokenizar, agregar BOS y EOS al destino, rellenar y crear las máscaras
- Elegir su fila de embedding, escalarla y sumarle la posición
- Aplicar las N capas del encoder
- Dar contexto a cada posición usando sólo el prefijo

**Clave:** Tokenizar, agregar BOS y EOS al destino, rellenar y crear las máscaras

### POST-B2

**Pregunta:** Contexto — Al final del recorrido, un estado interno debe convertirse en una palabra escrita.

¿Qué operación convierte el estado final en una distribución?

- Proyectar al vocabulario, filtrar candidatos y aplicar softmax
- Elegir un ID y convertirlo de vuelta en texto
- Relacionar las formas, los valores y el propósito de cada etapa
- Tokenizar, agregar BOS y EOS al destino, rellenar y crear las máscaras

**Clave:** Proyectar al vocabulario, filtrar candidatos y aplicar softmax

### POST-B3

**Pregunta:** Contexto — Los IDs por sí solos son símbolos: hay que convertirlos en vectores antes de entrar a las capas.

Lee la afirmación y decide si es verdadera o falsa:

Los IDs enteros se envían directamente al encoder, sin embeddings ni posición.

- Verdadero
- Falso

**Clave:** Falso

### POST-B4

**Pregunta:** Contexto — Dentro de la pila del decoder, cada posición usa dos fuentes de información.

Lee la afirmación y decide si es verdadera o falsa:

El decoder combina el prefijo causal con la memoria del encoder mediante N capas.

- Verdadero
- Falso

**Clave:** Verdadero

### POST-B5

**Pregunta:** Contexto — Cada concepto de este módulo describe una parte distinta del recorrido. Revisa qué hace cada uno.

Selecciona las DOS asociaciones coherentes entre concepto y función.

- Pila decoder: Combina el prefijo, sin ver el futuro, con la memoria del encoder mediante N capas.
- Inferencia autoregresiva: Al generar, agrega cada token elegido al prefijo y repite el ciclo sin consultar posiciones futuras.
- Pila decoder: Al generar, agrega cada token elegido al prefijo y repite el ciclo sin consultar posiciones futuras.
- Inferencia autoregresiva: Combina el prefijo, sin ver el futuro, con la memoria del encoder mediante N capas.

**Clave:** Pila decoder: Combina el prefijo, sin ver el futuro, con la memoria del encoder mediante N capas. · Inferencia autoregresiva: Al generar, agrega cada token elegido al prefijo y repite el ciclo sin consultar posiciones futuras.

### POST-B6

**Pregunta:** Contexto — El flujo completo es una cadena: la salida de cada etapa alimenta a la siguiente.

Completa el flujo: Cross-attention y FFN → ________ → Token siguiente.

**Clave:** Logits y probabilidades

### POST-B7

**Pregunta:** Contexto — Cada etapa resuelve un problema distinto a lo largo del recorrido.

Relaciona cada etapa con el motivo por el que se realiza.

**Clave:** Embeddings + posición → Da a cada token su identidad, su lugar y un vector con el cual calcular · Autoatención causal → Evita usar información futura que al generar aún no existe · Logits y probabilidades → Permite comparar todos los tokens que se podrían escribir · Ciclo completo → Reúne las piezas en una explicación de causa y efecto

### POST-B8

**Pregunta:** Contexto — En las formas, B es el número de ejemplos, T_src y T_tgt las longitudes de fuente y destino, d_model el ancho y |V| el tamaño del vocabulario.

Al terminar el paso «Embeddings + posición», ¿qué forma (dimensiones) tiene el tensor que se obtiene? Escríbela eje por eje con los símbolos del recorrido.

**Clave:** [B,T,d_model]

### POST-I1

**Pregunta:** Contexto — El punto de partida es el texto. Ordena las operaciones usando la salida de una como entrada de la siguiente.

Ordena las etapas según el flujo real de información.

**Clave:** Embeddings + posición → Recorrer encoder → Autoatención causal → Cross-attention y FFN

### POST-I2

**Pregunta:** Contexto — El punto de partida son los vectores de entrada. Ordena las operaciones que llevan hasta el estado del decoder.

Ordena las etapas según el flujo real de información.

**Clave:** Autoatención causal → Cross-attention y FFN → Logits y probabilidades → Token siguiente

### POST-I3

**Pregunta:** Contexto — Aquí debes relacionar cada transformación con el resultado inmediato que deja, no con el de pasos posteriores.

Relaciona cada transformación con la información que produce.

**Clave:** Embeddings + posición → X_src y X_tgt · Autoatención causal → Estado decoder parcial · Logits y probabilidades → Distribución · Ciclo completo → Comprensión de extremo a extremo

### POST-I4

**Pregunta:** Contexto — Sigue qué cambia realmente en cada etapa: pueden cambiar los ejes, los valores o la información que llevan.

Relaciona cada etapa con el cambio observable que produce.

**Clave:** Preparar fuente y destino → El texto pasa a ser IDs enteros · Recorrer encoder → Cada token de la fuente incorpora información de los demás · Cross-attention y FFN → El estado del decoder incorpora información de la fuente · Token siguiente → La secuencia generada crece un token

### POST-I5

**Pregunta:** Contexto — Una justificación correcta explica para qué es necesaria una operación; no basta con repetir su nombre.

Selecciona las DOS explicaciones que justifican correctamente su etapa.

- Embeddings + posición: Da a cada token su identidad, su lugar y un vector con el cual calcular
- Token siguiente: Convierte las probabilidades en una palabra concreta
- Embeddings + posición: Convierte las probabilidades en una palabra concreta
- Token siguiente: Da a cada token su identidad, su lugar y un vector con el cual calcular

**Clave:** Embeddings + posición: Da a cada token su identidad, su lugar y un vector con el cual calcular · Token siguiente: Convierte las probabilidades en una palabra concreta

### POST-I6

**Pregunta:** Contexto — Para decidir si dos etapas son consecutivas, comprueba que la salida de la primera sea la entrada que necesita la segunda.

Lee la afirmación y decide si es verdadera o falsa:

En el flujo del módulo, después de «Embeddings + posición» ocurre «Cross-attention y FFN».

- Verdadero
- Falso

**Clave:** Falso

### POST-I7

**Pregunta:** Contexto — La pregunta ya indica la entrada de una operación. Elige su salida inmediata, no el resultado final del modelo.

Completa: «Cross-attention y FFN» recibe El estado causal y la memoria y produce ________.

**Clave:** Salida de N capas

### POST-I8

**Pregunta:** Contexto — El propósito explica por qué hace falta la operación; no es una descripción de sus pasos.

¿Por qué se realiza «Recorrer encoder»?

- Construye una memoria de la frase de origen con contexto en cada token
- Deja entradas válidas para ambos lados del modelo
- Da a cada token su identidad, su lugar y un vector con el cual calcular
- Evita usar información futura que al generar aún no existe

**Clave:** Construye una memoria de la frase de origen con contexto en cada token

### POST-I9

**Pregunta:** Contexto — Un par entrada→salida sólo es válido si ambos pertenecen a la misma etapa; no mezcles etapas.

Selecciona los DOS pares que describen la entrada y la salida de una misma etapa del recorrido.

- Los IDs de ambos lados → X_src y X_tgt
- La distribución de probabilidad → Token y texto parcial
- Los IDs de ambos lados → Token y texto parcial
- La distribución de probabilidad → X_src y X_tgt

**Clave:** Los IDs de ambos lados → X_src y X_tgt · La distribución de probabilidad → Token y texto parcial

### POST-A1

**Pregunta:** Contexto — Cada eje de una forma tiene un significado. Identifica cuál cambia en la capa de salida y cuáles se conservan.

Resuelve sin opciones: La capa de salida cambia el último eje de d_model a |V|, y conserva los demás. Con B = 2, T = 5, d_model = 256 y |V| = 1 000, ¿qué forma tienen los logits?

**Clave:** [2,5,1 000]

### POST-A2

**Pregunta:** Contexto — El encoder y el decoder se conectan mediante un solo tensor. Piensa qué lado lo produce.

En cross-attention, el decoder consulta repetidamente una representación de la frase de origen. Durante una traducción, ¿qué tensor es?

- La salida final del encoder
- Los logits finales
- La máscara causal
- Top-P

**Clave:** La salida final del encoder

### POST-A3

**Pregunta:** Contexto — Cada opción une un dato con su resultado. Evalúa cada una por separado.

Selecciona las DOS opciones en las que el dato y su resultado están emparejados correctamente.

- Relleno en la fuente → máscara de padding en la fuente.
- Enlace entre encoder y decoder → la salida final del encoder.
- Relleno en la fuente → máscara causal en la fuente.
- Enlace entre encoder y decoder → la máscara causal.

**Clave:** Relleno en la fuente → máscara de padding en la fuente. · Enlace entre encoder y decoder → la salida final del encoder.

### POST-A4

**Pregunta:** Contexto — Las cuatro tarjetas forman un solo recorrido. Ordénalas de modo que la salida de cada una sirva a la siguiente.

Reconstruye el orden necesario para que la transformación sea válida.

**Clave:** Recorrer encoder → Autoatención causal → Cross-attention y FFN → Logits y probabilidades

### POST-A5

**Pregunta:** Contexto — Resuelve cada situación por separado. Recuerda qué mide cada número del modelo y en qué etapa aparece.

Relaciona cada situación con la conclusión correcta. Cada conclusión se usa una sola vez.

**Clave:** Los IDs enteros todavía son símbolos, sin vectores con los cuales calcular. Entre ellos y la primera capa del encoder, ¿qué tensor aparece? → Embedding escalado más posición · Un peso de atención reparte información entre tokens, y la probabilidad final puntúa el vocabulario. Una cabeza asigna 0.9 de atención a «gato»; un estudiante concluye que será la siguiente palabra. ¿Es correcto? → No; operan en espacios y etapas distintas · La salida se genera un token por vuelta, y la memoria de la fuente no cambia. Tras elegir el token «hello», ¿qué entrada cambia en la siguiente iteración? → El prefijo del decoder

### POST-A6

**Pregunta:** Contexto — Compara qué tiene disponible el decoder al generar y qué tiene al entrenar. Evalúa exactamente lo que afirma el caso.

Lee la afirmación y decide si es verdadera o falsa:

Caso: en inferencia, el decoder recibe la respuesta completa desde el primer paso, igual que con teacher forcing.

- Verdadero
- Falso

**Clave:** Falso

### POST-A7

**Pregunta:** Contexto — Los logits tienen tres ejes, y cada combinación de sus índices es un score.

Responde sin opciones: El total de scores es el producto de los ejes de los logits. Un batch con B = 2, T_tgt = 4 y |V| = 500 produce logits [2, 4, 500]. ¿Cuántos scores contiene?

**Clave:** 4 000

### POST-A8

**Pregunta:** Contexto — Un peso de atención y una probabilidad del vocabulario se calculan en etapas distintas, sobre elementos distintos.

La memoria conserva un vector de d_model números por token de la fuente. Con B=2, T_src=9 y d_model=64, ¿qué forma tiene?

- [2,9,64]
- [2,64,9]
- [9,9]
- [2,9,|V|]

**Clave:** [2,9,64]

## Retos del laboratorio

### LAB-m8_l1

**Pregunta:** Observa la última proyección: la capa lineal transforma el último eje de d_model al vocabulario. Un lote de 3 frases con 2 posiciones, vectores de 40 números y 600 palabras posibles. ¿Cómo queda el tensor de logits?

**Respuesta correcta:** [3, 2, 600]

**Explicación:** La capa de salida conserva el batch y las posiciones, y sustituye las componentes por un eje de candidatos.

### LAB-m8_l2

**Pregunta:** Escribe otra palabra en la frase, con el campo de texto, y vuelve a analizar: varias filas de la memoria cambian antes de iniciar el decoder. ¿Qué muestra ese efecto?

**Respuesta correcta:** El encoder contextualiza cada posición usando el resto de la fuente

**Explicación:** La autoatención propaga el cambio por la fuente y produce una memoria contextual antes de decodificar.

### LAB-m8_l3

**Pregunta:** Observa las dos máscaras del batch: una actúa sobre la fuente y otra sobre el destino. ¿Por qué se usan dos patrones distintos?

**Respuesta correcta:** Uno elimina relleno y el otro impide anticipar la salida

**Explicación:** La máscara fuente protege contra PAD; la destino además respeta la generación causal.

### LAB-m8_l4

**Pregunta:** En el decoder hay un mapa de destino × destino y otro de destino × fuente. ¿Cuál corresponde a la consulta de la memoria?

**Respuesta correcta:** El mapa destino×fuente

**Explicación:** Cross-attention usa Queries destino y Keys fuente, por eso sus dos ejes recorren secuencias distintas.

### LAB-m8_l5

**Pregunta:** En la etapa de embeddings, los IDs enteros se vuelven filas de celdas y se les añade posición. ¿Qué cambio conceptual ocurrió?

**Respuesta correcta:** Cada símbolo discreto se convirtió en un vector continuo con orden

**Explicación:** Embedding aporta una representación continua y la señal posicional incorpora el orden de cada fila.

### LAB-m8_l6

**Pregunta:** En el encoder o el decoder, al cambiar la cabeza seleccionada aparece otro mapa. Sólo estás inspeccionando una parte del modelo. ¿Qué interpretación es prudente?

**Respuesta correcta:** Un mapa aislado aporta evidencia local, no una explicación completa de la predicción

**Explicación:** La salida combina muchas cabezas, capas, residuales y la proyección final; una vista aislada sólo describe un componente.

### LAB-m8_l7

**Pregunta:** Observa el paso de realimentación: los candidatos descartados desaparecen. ¿Qué dato concreto regresa al decoder?

**Respuesta correcta:** El ID del único token elegido

**Explicación:** La generación compromete una elección por paso y añade su ID al prefijo.

### LAB-m8_l8

**Pregunta:** Ejemplo: con B = 1, T_src = 3 y d_model = 16, la memoria mide [1, 3, 16]. Si cambias una palabra por otra de un solo token, ¿qué se mantiene?

**Respuesta correcta:** La forma [1, 3, 16]: una fila por posición y el mismo ancho

**Explicación:** Cambiar el contenido modifica los valores de la memoria, no la forma con la que el decoder la consulta.
