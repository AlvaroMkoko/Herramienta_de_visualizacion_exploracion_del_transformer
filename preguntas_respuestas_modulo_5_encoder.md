# Preguntas y respuestas correctas — Módulo 5: Encoder

Generado por `tools/generar_preguntas_modulo.py`. Corresponde a la versión 15 del banco modular. El pre-test y el post-test tienen 25 reactivos disponibles cada uno; cada intento selecciona 15.

## Pregunta ancla

**Pregunta:** Después de la atención, ¿cómo evita el encoder perder la información original de cada token y, al mismo tiempo, transformarla de forma no lineal?

**Ejemplo:** Un token con x = [1, 2] recibe la actualización de atención a = [0.5, −1]. Residual: x + a = [1.5, 1.0]. LayerNorm (media 1.25, desviación 0.25) → [1, −1]. Una FFN 2 → 8 → 2 con ReLU produce otra actualización f, y el segundo Add & Norm calcula Norm([1, −1] + f). La forma [T, 2] nunca cambia, así que la capa se puede apilar N veces.

**Cierre:** Después de la atención, cada token recibe una actualización y la capa debe evitar que se pierda lo que ya tenía. ¿Qué permite que la entrada original siga presente?

**Respuesta correcta:** La suma residual X + MHA(X)

## Comprobaciones del recorrido guiado

### R1. Entrada de capa

**Pregunta:** Cada capa del encoder recibe lo que entregó la capa anterior. La entrada de la capa 3, ¿de dónde proviene?

**Respuesta correcta:** De la salida de la capa 2

### R2. Multi-Head Self-Attention

**Pregunta:** El encoder sólo bloquea el relleno; no bloquea tokens posteriores. Sin padding, ¿a cuántas posiciones puede atender cada token de una frase de 6?

**Respuesta correcta:** A las 6

### R3. Primera suma residual

**Pregunta:** La suma residual se hace componente a componente. Con x = [1, 2] y MHA(x) = [0.5, −1], ¿cuánto vale?

**Respuesta correcta:** [1.5, 1]

### R4. Primera LayerNorm

**Pregunta:** LayerNorm resta a cada token la media de sus componentes y divide entre su desviación. Sobre [1.5, 1.0], sin γ ni β, ¿qué media tiene el resultado?

**Respuesta correcta:** 0

### R5. Expansión Feed Forward

**Pregunta:** La FFN lleva el ancho de cada token de d_model a d_ff. Con d_model = 128 y d_ff = 512, ¿qué tamaño tiene la activación oculta de un token?

**Respuesta correcta:** 512

### R6. Proyección Feed Forward

**Pregunta:** Después de la FFN, su resultado se suma con la entrada de esa subcapa. ¿Por qué la segunda lineal vuelve a d_model?

**Respuesta correcta:** Para poder sumarse en la residual

### R7. Segundo Add & Norm

**Pregunta:** Add & Norm suma celda por celda y normaliza sin agregar ejes. Tras el segundo Add & Norm, ¿cambia la forma [B, T, d_model]?

**Respuesta correcta:** No

### R8. Pila y memoria final

**Pregunta:** Cada capa conserva la forma, y la memoria tiene un vector por token de la fuente. Con N = 6 capas, ¿qué forma tiene para B = 2 y T_src = 9?

**Respuesta correcta:** [2, 9, d_model]

## Pre-test

### PRE-B1

**Pregunta:** Contexto — Una capa del encoder no es una sola operación: es un conjunto de subcapas que se aplican en un orden fijo.

¿Qué descripción explica correctamente cómo está organizada una capa?

- Una capa sigue este orden: self-attention, Add & Norm, FFN y un segundo Add & Norm.
- Permite que cada token consulte a todos los tokens reales de la entrada, incluidos los posteriores.
- Normaliza las componentes de cada token por separado para mantener los números en un rango estable.
- Suma la actualización de la FFN con su entrada y normaliza, sin cambiar la forma.

**Clave:** Una capa sigue este orden: self-attention, Add & Norm, FFN y un segundo Add & Norm.

### PRE-B2

**Pregunta:** Contexto — La atención mezcla información entre posiciones. Después, una segunda subcapa se encarga de transformar cada posición.

¿Qué descripción explica correctamente qué hace la Feed Forward Network?

- Transforma cada posición por separado: expande su ancho, aplica una no linealidad y regresa al ancho original.
- Suma la actualización de la FFN con su entrada y normaliza, sin cambiar la forma.
- Es la representación final: un vector con contexto por cada token, que el decoder consultará como memoria.
- Permite que cada token consulte a todos los tokens reales de la entrada, incluidos los posteriores.

**Clave:** Transforma cada posición por separado: expande su ancho, aplica una no linealidad y regresa al ancho original.

### PRE-B3

**Pregunta:** Contexto — En el encoder, la frase de entrada se conoce completa antes de empezar a procesarla.

Lee la afirmación y decide si es verdadera o falsa:

La self-attention del encoder permite que cada token consulte a todos los tokens reales de la entrada.

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-B4

**Pregunta:** Contexto — Los números pueden crecer o moverse al pasar por las capas, y una operación los mantiene en un rango estable.

Lee la afirmación y decide si es verdadera o falsa:

LayerNorm cambia la longitud T y agrega tokens nuevos.

- Verdadero
- Falso

**Clave:** Falso

### PRE-B5

**Pregunta:** Contexto — Cada concepto de este módulo resuelve un problema distinto dentro de la capa. Revisa qué hace cada uno.

Selecciona las DOS asociaciones coherentes entre concepto y función.

- Conexión residual: Suma la entrada de una subcapa con su actualización, para que la información original siga presente.
- Segundo Add & Norm: Suma la actualización de la FFN con su entrada y normaliza, sin cambiar la forma.
- Conexión residual: Suma la actualización de la FFN con su entrada y normaliza, sin cambiar la forma.
- Segundo Add & Norm: Suma la entrada de una subcapa con su actualización, para que la información original siga presente.

**Clave:** Conexión residual: Suma la entrada de una subcapa con su actualización, para que la información original siga presente. · Segundo Add & Norm: Suma la actualización de la FFN con su entrada y normaliza, sin cambiar la forma.

### PRE-B6

**Pregunta:** Contexto — Una capa es una cadena: la salida de cada etapa alimenta a la siguiente.

Completa el flujo: Primera LayerNorm → ________ → Proyección Feed Forward.

**Clave:** Expansión Feed Forward

### PRE-B7

**Pregunta:** Contexto — Cada etapa resuelve un problema distinto: reunir contexto, conservar la señal, estabilizar o transformar.

Relaciona cada etapa con el motivo por el que se realiza.

**Clave:** Entrada de capa → Todas las capas reciben y entregan la misma forma, y por eso pueden encadenarse · Primera suma residual → Deja un camino directo para que pasen la información y los gradientes · Expansión Feed Forward → Añade capacidad no lineal a cada posición, sin mezclarla con las demás · Segundo Add & Norm → Integra lo que hizo la FFN sin perder el estado que ya se tenía

### PRE-B8

**Pregunta:** Contexto — En las formas, B es el número de ejemplos, T el de tokens, T_src el de tokens de la fuente, d_model el ancho y d_ff el ancho oculto de la FFN.

Al terminar el paso «Pila y memoria final», ¿qué forma (dimensiones) tiene el tensor que se obtiene? Escríbela eje por eje con los símbolos del recorrido.

**Clave:** [B,T_src,d_model]

### PRE-I1

**Pregunta:** Contexto — El punto de partida es la entrada de la capa. Ordena las operaciones usando la salida de una como entrada de la siguiente.

Ordena las etapas según el flujo real de información.

**Clave:** Entrada de capa → Multi-Head Self-Attention → Primera suma residual → Primera LayerNorm

### PRE-I2

**Pregunta:** Contexto — El punto de partida es el estado después de la atención. Ordena las operaciones que le siguen.

Ordena las etapas según el flujo real de información.

**Clave:** Expansión Feed Forward → Proyección Feed Forward → Segundo Add & Norm → Pila y memoria final

### PRE-I3

**Pregunta:** Contexto — Aquí debes relacionar cada transformación con el resultado inmediato que deja, no con el de pasos posteriores.

Relaciona cada transformación con la información que produce.

**Clave:** Entrada de capa → Entrada estable · Primera suma residual → X + MHA(X) · Expansión Feed Forward → Activación oculta · Segundo Add & Norm → Salida de capa

### PRE-I4

**Pregunta:** Contexto — Sigue qué cambia realmente en cada etapa: pueden cambiar el ancho, los valores o la información que lleva cada token.

Relaciona cada etapa con el cambio observable que produce.

**Clave:** Multi-Head Self-Attention → Cada token recibe una actualización con información de los demás · Primera LayerNorm → Se controlan la media y la varianza de cada token · Proyección Feed Forward → La dimensión oculta se comprime de vuelta a d_model · Pila y memoria final → La forma se conserva en toda la pila y no se pierden posiciones

### PRE-I5

**Pregunta:** Contexto — Una justificación correcta explica para qué es necesaria una operación; no basta con repetir su nombre.

Selecciona las DOS explicaciones que justifican correctamente su etapa.

- Primera suma residual: Deja un camino directo para que pasen la información y los gradientes
- Proyección Feed Forward: Recupera el ancho que necesita la siguiente suma residual
- Primera suma residual: Recupera el ancho que necesita la siguiente suma residual
- Proyección Feed Forward: Deja un camino directo para que pasen la información y los gradientes

**Clave:** Primera suma residual: Deja un camino directo para que pasen la información y los gradientes · Proyección Feed Forward: Recupera el ancho que necesita la siguiente suma residual

### PRE-I6

**Pregunta:** Contexto — Para decidir si dos etapas son consecutivas, comprueba que la salida de la primera sea la entrada que necesita la segunda.

Lee la afirmación y decide si es verdadera o falsa:

En el flujo del módulo, después de «Multi-Head Self-Attention» ocurre «Primera suma residual».

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-I7

**Pregunta:** Contexto — La pregunta ya indica la entrada de una operación. Elige su salida inmediata, no el resultado final de la capa.

Completa: «Segundo Add & Norm» recibe El estado y la actualización de la FFN y produce ________.

**Clave:** Salida de capa

### PRE-I8

**Pregunta:** Contexto — El propósito explica por qué hace falta la operación; no es una descripción de sus pasos.

¿Por qué se realiza «Proyección Feed Forward»?

- Recupera el ancho que necesita la siguiente suma residual
- Reúne información de toda la secuencia, también de lo que viene después
- Deja un camino directo para que pasen la información y los gradientes
- Añade capacidad no lineal a cada posición, sin mezclarla con las demás

**Clave:** Recupera el ancho que necesita la siguiente suma residual

### PRE-I9

**Pregunta:** Contexto — Un par entrada→salida sólo es válido si ambos pertenecen a la misma etapa; no mezcles etapas.

Selecciona los DOS pares que describen la entrada y la salida de una misma etapa del recorrido.

- X, o la salida de la capa anterior → Entrada estable
- La salida de una capa → Memoria del encoder
- X, o la salida de la capa anterior → Memoria del encoder
- La salida de una capa → Entrada estable

**Clave:** X, o la salida de la capa anterior → Entrada estable · La salida de una capa → Memoria del encoder

### PRE-A1

**Pregunta:** Contexto — Para sumar celda por celda, dos tensores deben coincidir en todos sus ejes.

Resuelve sin opciones: La suma residual combina dos tensores celda por celda. Si X y MHA(X) tienen forma [2,5,128], ¿qué forma tiene su suma?

**Clave:** [2,5,128]

### PRE-A2

**Pregunta:** Contexto — La FFN actúa sobre cada token por separado y sólo cambia el ancho de su último eje.

La FFN cambia sólo el último eje, de d_model a d_ff. Con d_model=128, d_ff=512, B=2 y T=5, ¿qué forma tiene la activación oculta?

- [2,5,512]
- [2,5,128]
- [512,128]
- [10,128]

**Clave:** [2,5,512]

### PRE-A3

**Pregunta:** Contexto — Cada opción une un dato con su resultado. Evalúa cada una por separado.

Selecciona las DOS opciones en las que el dato y su resultado están emparejados correctamente.

- Encoder sin padding → el token 3 atiende a todas las posiciones.
- Después de LayerNorm → la media de un token queda cerca de 0.
- Encoder sin padding → el token 3 sólo atiende a las anteriores.
- Después de LayerNorm → la media de un token es d_model.

**Clave:** Encoder sin padding → el token 3 atiende a todas las posiciones. · Después de LayerNorm → la media de un token queda cerca de 0.

### PRE-A4

**Pregunta:** Contexto — Las cuatro tarjetas forman una sola capa. Ordénalas de modo que la salida de cada una sirva a la siguiente.

Reconstruye el orden necesario para que la transformación sea válida.

**Clave:** Multi-Head Self-Attention → Primera suma residual → Primera LayerNorm → Expansión Feed Forward

### PRE-A5

**Pregunta:** Contexto — Resuelve cada situación por separado. Recuerda qué ocurre con la forma y qué ocurre con los valores en cada subcapa.

Relaciona cada situación con la conclusión correcta. Cada conclusión se usa una sola vez.

**Clave:** Cada capa del encoder entrega la misma forma que recibe. Después de 6 capas, ¿cambia necesariamente la forma [B,T,d_model]? → No; se conserva · La FFN tiene dos proyecciones lineales y, entre ellas, una activación. ¿Por qué incluye esa activación no lineal? → Modelar transformaciones no lineales complejas · La memoria conserva un vector por cada posición de la fuente. Si la entrada contiene 5 tokens reales, ¿cuántos vectores contextualizados entrega por ejemplo? → 5, una por token de entrada

### PRE-A6

**Pregunta:** Contexto — Considera qué aporta el camino directo de la residual, y evalúa exactamente lo que afirma el caso.

Lee la afirmación y decide si es verdadera o falsa:

Caso: si una subcapa del encoder produce una actualización cercana a cero, gracias a la residual su salida (antes de normalizar) conserva casi intacta la entrada X.

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-A7

**Pregunta:** Contexto — Cada matriz tiene tantos pesos como el producto de sus dos ejes.

Responde sin opciones: La FFN tiene dos matrices: una de [d_model, d_ff] y otra de [d_ff, d_model]. Expande de 64 a 256 y regresa a 64. Sin sesgos, ¿cuántos pesos tienen juntas?

**Clave:** 32 768

### PRE-A8

**Pregunta:** Contexto — Piensa cuántas posiciones tiene la entrada y si alguna capa las reduce.

En esta implementación, cada subcapa termina con su suma residual y normalización. ¿Cuál es el orden correcto dentro de la capa del encoder?

- MHA→Add&Norm→FFN→Add&Norm
- FFN→MHA→Softmax
- MHA→FFN→Tokenización
- LayerNorm→Logits→MHA

**Clave:** MHA→Add&Norm→FFN→Add&Norm

## Post-test

### POST-B1

**Pregunta:** Contexto — Una capa del encoder no es una sola operación: es un conjunto de subcapas que se aplican en un orden fijo.

¿Qué operación ocurre cuando una capa recibe su entrada?

- Recibir un tensor de forma [B,T,d_model]
- Dejar que cada token consulte a todos los tokens de la frase
- Sumar X y MHA(X), elemento a elemento
- Normalizar las componentes de cada token por separado

**Clave:** Recibir un tensor de forma [B,T,d_model]

### POST-B2

**Pregunta:** Contexto — La atención mezcla información entre posiciones. Después, una segunda subcapa se encarga de transformar cada posición.

¿Qué operación realiza la expansión de la FFN?

- Aplicar una proyección lineal d_model→d_ff y una activación
- Aplicar una proyección lineal d_ff→d_model
- Sumar la actualización de la FFN con su entrada y normalizar
- Repetir la misma estructura N veces, con parámetros propios

**Clave:** Aplicar una proyección lineal d_model→d_ff y una activación

### POST-B3

**Pregunta:** Contexto — En el encoder, la frase de entrada se conoce completa antes de empezar a procesarla.

Lee la afirmación y decide si es verdadera o falsa:

La self-attention del encoder sólo permite atender posiciones anteriores, mediante una máscara causal.

- Verdadero
- Falso

**Clave:** Falso

### POST-B4

**Pregunta:** Contexto — Los números pueden crecer o moverse al pasar por las capas, y una operación los mantiene en un rango estable.

Lee la afirmación y decide si es verdadera o falsa:

LayerNorm normaliza las componentes de cada token para estabilizar los números.

- Verdadero
- Falso

**Clave:** Verdadero

### POST-B5

**Pregunta:** Contexto — Cada concepto de este módulo resuelve un problema distinto dentro de la capa. Revisa qué hace cada uno.

Selecciona las DOS asociaciones coherentes entre concepto y función.

- Layer Normalization: Normaliza las componentes de cada token por separado para mantener los números en un rango estable.
- Pila de capas: Entrega la salida de una capa como entrada de la siguiente, con los mismos ejes.
- Layer Normalization: Entrega la salida de una capa como entrada de la siguiente, con los mismos ejes.
- Pila de capas: Normaliza las componentes de cada token por separado para mantener los números en un rango estable.

**Clave:** Layer Normalization: Normaliza las componentes de cada token por separado para mantener los números en un rango estable. · Pila de capas: Entrega la salida de una capa como entrada de la siguiente, con los mismos ejes.

### POST-B6

**Pregunta:** Contexto — Una capa es una cadena: la salida de cada etapa alimenta a la siguiente.

Completa el flujo: Expansión Feed Forward → ________ → Segundo Add & Norm.

**Clave:** Proyección Feed Forward

### POST-B7

**Pregunta:** Contexto — Cada etapa resuelve un problema distinto: reunir contexto, conservar la señal, estabilizar o transformar.

Relaciona cada etapa con el motivo por el que se realiza.

**Clave:** Multi-Head Self-Attention → Reúne información de toda la secuencia, también de lo que viene después · Primera LayerNorm → Mantiene el tamaño y el centro de los números en un rango estable · Proyección Feed Forward → Recupera el ancho que necesita la siguiente suma residual · Pila y memoria final → Refina poco a poco las representaciones, una capa tras otra

### POST-B8

**Pregunta:** Contexto — En las formas, B es el número de ejemplos, T el de tokens, T_src el de tokens de la fuente, d_model el ancho y d_ff el ancho oculto de la FFN.

Al terminar el paso «Entrada de capa», ¿qué forma (dimensiones) tiene el tensor que se obtiene? Escríbela eje por eje con los símbolos del recorrido.

**Clave:** [B,T,d_model]

### POST-I1

**Pregunta:** Contexto — El punto de partida es la entrada de la capa. Ordena las operaciones usando la salida de una como entrada de la siguiente.

Ordena las etapas según el flujo real de información.

**Clave:** Multi-Head Self-Attention → Primera suma residual → Primera LayerNorm → Expansión Feed Forward

### POST-I2

**Pregunta:** Contexto — El punto de partida es el estado después de la atención. Ordena las operaciones que le siguen.

Ordena las etapas según el flujo real de información.

**Clave:** Primera LayerNorm → Expansión Feed Forward → Proyección Feed Forward → Segundo Add & Norm

### POST-I3

**Pregunta:** Contexto — Aquí debes relacionar cada transformación con el resultado inmediato que deja, no con el de pasos posteriores.

Relaciona cada transformación con la información que produce.

**Clave:** Multi-Head Self-Attention → Actualización de atención · Primera LayerNorm → Estado normalizado · Proyección Feed Forward → Actualización FFN · Pila y memoria final → Memoria del encoder

### POST-I4

**Pregunta:** Contexto — Sigue qué cambia realmente en cada etapa: pueden cambiar el ancho, los valores o la información que lleva cada token.

Relaciona cada etapa con el cambio observable que produce.

**Clave:** Entrada de capa → La representación entra a la capa sin cambiar de forma · Primera suma residual → Entrada y actualización quedan reunidas en un mismo tensor · Expansión Feed Forward → El ancho crece de manera temporal; el número de filas no cambia · Segundo Add & Norm → Termina una capa y su forma es la misma que al inicio

### POST-I5

**Pregunta:** Contexto — Una justificación correcta explica para qué es necesaria una operación; no basta con repetir su nombre.

Selecciona las DOS explicaciones que justifican correctamente su etapa.

- Multi-Head Self-Attention: Reúne información de toda la secuencia, también de lo que viene después
- Segundo Add & Norm: Integra lo que hizo la FFN sin perder el estado que ya se tenía
- Multi-Head Self-Attention: Integra lo que hizo la FFN sin perder el estado que ya se tenía
- Segundo Add & Norm: Reúne información de toda la secuencia, también de lo que viene después

**Clave:** Multi-Head Self-Attention: Reúne información de toda la secuencia, también de lo que viene después · Segundo Add & Norm: Integra lo que hizo la FFN sin perder el estado que ya se tenía

### POST-I6

**Pregunta:** Contexto — Para decidir si dos etapas son consecutivas, comprueba que la salida de la primera sea la entrada que necesita la segunda.

Lee la afirmación y decide si es verdadera o falsa:

En el flujo del módulo, después de «Multi-Head Self-Attention» ocurre «Expansión Feed Forward».

- Verdadero
- Falso

**Clave:** Falso

### POST-I7

**Pregunta:** Contexto — La pregunta ya indica la entrada de una operación. Elige su salida inmediata, no el resultado final de la capa.

Completa: «Expansión Feed Forward» recibe El estado normalizado y produce ________.

**Clave:** Activación oculta

### POST-I8

**Pregunta:** Contexto — El propósito explica por qué hace falta la operación; no es una descripción de sus pasos.

¿Por qué se realiza «Primera suma residual»?

- Deja un camino directo para que pasen la información y los gradientes
- Reúne información de toda la secuencia, también de lo que viene después
- Añade capacidad no lineal a cada posición, sin mezclarla con las demás
- Refina poco a poco las representaciones, una capa tras otra

**Clave:** Deja un camino directo para que pasen la información y los gradientes

### POST-I9

**Pregunta:** Contexto — Un par entrada→salida sólo es válido si ambos pertenecen a la misma etapa; no mezcles etapas.

Selecciona los DOS pares que describen la entrada y la salida de una misma etapa del recorrido.

- La representación X de la capa → Actualización de atención
- El estado y la actualización de la FFN → Salida de capa
- La representación X de la capa → Salida de capa
- El estado y la actualización de la FFN → Actualización de atención

**Clave:** La representación X de la capa → Actualización de atención · El estado y la actualización de la FFN → Salida de capa

### POST-A1

**Pregunta:** Contexto — Para sumar celda por celda, dos tensores deben coincidir en todos sus ejes.

Resuelve sin opciones: La suma residual combina dos tensores celda por celda. Si X y MHA(X) tienen forma [4,12,256], ¿qué forma tiene su suma?

**Clave:** [4,12,256]

### POST-A2

**Pregunta:** Contexto — La FFN actúa sobre cada token por separado y sólo cambia el ancho de su último eje.

La FFN cambia sólo el último eje, de d_model a d_ff. Con d_model = 256, d_ff = 1024, B = 3 y T = 8, ¿qué forma tiene la activación oculta?

- [3,8,1024]
- [3,8,256]
- [1024,256]
- [24,256]

**Clave:** [3,8,1024]

### POST-A3

**Pregunta:** Contexto — Cada opción une un dato con su resultado. Evalúa cada una por separado.

Selecciona las DOS opciones en las que el dato y su resultado están emparejados correctamente.

- Encoder sin PAD → el token 1 puede ver también los posteriores.
- LayerNorm en cada token → usa sus propias componentes.
- Encoder sin PAD → el token 1 sólo puede verse a sí mismo.
- LayerNorm en cada token → usa todo el vocabulario.

**Clave:** Encoder sin PAD → el token 1 puede ver también los posteriores. · LayerNorm en cada token → usa sus propias componentes.

### POST-A4

**Pregunta:** Contexto — Las cuatro tarjetas forman una sola capa. Ordénalas de modo que la salida de cada una sirva a la siguiente.

Reconstruye el orden necesario para que la transformación sea válida.

**Clave:** Primera suma residual → Primera LayerNorm → Expansión Feed Forward → Proyección Feed Forward

### POST-A5

**Pregunta:** Contexto — Resuelve cada situación por separado. Recuerda qué ocurre con la forma y qué ocurre con los valores en cada subcapa.

Relaciona cada situación con la conclusión correcta. Cada conclusión se usa una sola vez.

**Clave:** Cada capa entrega la misma forma que recibe. Un encoder apila 12 bloques que conservan [B,T,d_model]. ¿Cómo es la forma de salida? → Igual: [B,T,d_model] · La FFN tiene una activación entre sus dos proyecciones lineales. Si se elimina esa activación, ¿qué capacidad se pierde? → Modelar transformaciones no lineales · La memoria conserva un vector por cada posición de la fuente. Si la frase tiene 8 tokens reales, ¿cuántos vectores contextualizados entrega por ejemplo? → 8, uno por token de entrada

### POST-A6

**Pregunta:** Contexto — Considera qué aporta el camino directo de la residual, y evalúa exactamente lo que afirma el caso.

Lee la afirmación y decide si es verdadera o falsa:

Caso: sin conexiones residuales, la información de X llega intacta a la última capa aunque cada subcapa la transforme.

- Verdadero
- Falso

**Clave:** Falso

### POST-A7

**Pregunta:** Contexto — Cada matriz tiene tantos pesos como el producto de sus dos ejes.

Responde sin opciones: La FFN tiene dos matrices: una de [d_model, d_ff] y otra de [d_ff, d_model]. Expande de 32 a 128 y regresa a 32. Sin sesgos, ¿cuántos pesos tienen juntas?

**Clave:** 8 192

### POST-A8

**Pregunta:** Contexto — Piensa cuántas posiciones tiene la entrada y si alguna capa las reduce.

En esta implementación, cada subcapa termina con suma residual y normalización. Un compañero describe la capa del encoder. ¿Qué orden de subcapas es correcto?

- Atención → suma y normalización → FFN → suma y normalización
- FFN → atención → softmax de salida
- Atención → FFN → tokenización
- Normalización → logits → atención

**Clave:** Atención → suma y normalización → FFN → suma y normalización

## Retos del laboratorio

### LAB-m5_l1

**Pregunta:** Ejemplo de la ruta residual: si X = [1, 1, 1] mide [1, 3] y la atención aportara justo [0, 0, 0], ¿qué forma y qué valores saldrían antes de normalizar?

**Respuesta correcta:** [1, 3] con los mismos valores de X

**Explicación:** X + 0 = X, con la misma forma: el atajo evita perder la entrada.

### LAB-m5_l2

**Pregunta:** Ejemplo de la expansión: con B = 1, T = 4, d_model = 8 y d_ff = 32, aparecen más columnas pero no más filas. ¿Qué forma tiene la activación oculta?

**Respuesta correcta:** [1, 4, 32]

**Explicación:** Sólo crece el último eje, de 8 a 32. La FFN procesa cada fila de token por separado.

### LAB-m5_l3

**Pregunta:** En el paso de self-attention, el mapa del encoder no tiene la sombra triangular del decoder. En una frase sin PAD, ¿qué lectura es correcta?

**Respuesta correcta:** Todas las posiciones de contenido pueden relacionarse entre sí

**Explicación:** El encoder procesa la fuente completa y sólo necesita ocultar relleno, no el futuro.

### LAB-m5_l4

**Pregunta:** Observa un token en el paso de LayerNorm. ¿Qué esperas de la media de sus componentes, antes de aplicar γ y β?

**Respuesta correcta:** Cercana a 0

**Explicación:** LayerNorm centra y escala cada token sobre sus características.

### LAB-m5_l5

**Pregunta:** Cambia de capa con su selector y compara los mapas de activación. ¿Qué combinación es normal?

**Respuesta correcta:** La cuadrícula conserva sus dimensiones, pero cambian sus valores

**Explicación:** Las capas usan una interfaz común para poder apilarse, aunque cada una refine la representación.

### LAB-m5_l6

**Pregunta:** Observa la activación oculta: con ReLU, todo valor negativo se convierte en cero. ¿Qué esperas encontrar?

**Respuesta correcta:** Muchos valores exactamente en cero

**Explicación:** ReLU convierte en cero todo valor negativo.

### LAB-m5_l7

**Pregunta:** Ejemplo: escribe otra palabra en la frase, en el campo de texto, y vuelve a analizar. Con 4 tokens, ¿cuántas filas tiene la memoria y qué pasa con las de otros tokens?

**Respuesta correcta:** 4 filas; también pueden variar las de otros tokens

**Explicación:** Hay una fila por token. Self-attention hace que cambiar una posición afecte a las representaciones de las demás.

### LAB-m5_l8

**Pregunta:** Recorre con la animación la etapa que sigue a self-attention. ¿Qué bloque debe completar esa actualización antes de entrar a la FFN?

**Respuesta correcta:** La primera suma residual y su normalización

**Explicación:** En el bloque post-norm, cada subcapa entrega su actualización a Add & Norm antes de continuar.
