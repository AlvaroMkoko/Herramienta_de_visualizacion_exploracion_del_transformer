# Preguntas y respuestas correctas — Módulo 4: Multi-Head Attention

Generado por `tools/generar_preguntas_modulo.py`. Corresponde a la versión 15 del banco modular. El pre-test y el post-test tienen 25 reactivos disponibles cada uno; cada intento selecciona 15.

## Pregunta ancla

**Pregunta:** En «María le dio el libro a Ana porque ella lo pidió», ¿cómo puede el modelo seguir a la vez quién es «ella» y qué es «lo»?

**Ejemplo:** Con d_model = 8 y h = 2, las proyecciones Q, K y V conservan 8 componentes y luego se reorganizan en dos cabezas de d_head = 4. En un caso ilustrativo, el mapa de la cabeza 1 da más peso de «ella» a «Ana» y el de la cabeza 2, de «lo» a «libro». Cada cabeza produce [T, 4]; al concatenarlas se recupera [T, 8] y WO (8 × 8) integra ambas relaciones en una sola representación.

**Cierre:** En «María le dio el libro a Ana porque ella lo pidió» hay más de una relación que seguir a la vez. Cada cabeza calcula un mapa propio. ¿Por qué conviene tener varias?

**Respuesta correcta:** Cada una puede atender una relación distinta al mismo tiempo

## Comprobaciones del recorrido guiado

### R1. Proyección conjunta

**Pregunta:** La proyección conjunta conserva el ancho: WQ de [512, 512] convierte cada fila de 512 componentes en otra de 512. Con X [T, 512], ¿qué anchura tiene Q antes de dividirla?

**Respuesta correcta:** 512

### R2. Reorganizar en h cabezas

**Pregunta:** Las h cabezas reparten d_model por igual: d_head = d_model / h. Con d_model = 512 y h = 8, ¿qué anchura tiene cada cabeza?

**Respuesta correcta:** 64

### R3. Scores independientes

**Pregunta:** Cada cabeza calcula su propia tabla de scores [T, T]. Con h = 8 y T = 10, ¿cuántos mapas de scores [10, 10] se calculan por ejemplo?

**Respuesta correcta:** 8

### R4. Mapas por cabeza

**Pregunta:** Cada cabeza aplica softmax a sus propios scores, calculados con su porción de componentes. ¿Debe cada cabeza producir el mismo mapa de atención?

**Respuesta correcta:** No: cada una tiene su propio softmax y puede atender relaciones distintas

### R5. Contexto por cabeza

**Pregunta:** Una cabeza multiplica sus pesos por sus Values, y la T interna se suma. Con pesos [T, T] y V [T, 64], ¿qué forma produce?

**Respuesta correcta:** [T, 64]

### R6. Concatenación

**Pregunta:** Concatenar coloca las salidas una junto a otra por token, sumando sus anchos. 8 cabezas de [T, 64] concatenadas forman:

**Respuesta correcta:** [T, 512]

### R7. Proyección WO

**Pregunta:** Al concatenar, cada cabeza conserva su propio bloque de componentes. Después de eso, ¿qué aporta WO?

**Respuesta correcta:** Mezcla información entre cabezas

### R8. Salida multi-head

**Pregunta:** La suma residual combina MHA(X) y X celda por celda, así que deben coincidir. ¿Qué forma debe tener MHA(X) para sumarse con X [B, T, 512]?

**Respuesta correcta:** [B, T, 512]

## Pre-test

### PRE-B1

**Pregunta:** Contexto — Self-attention usa un solo mapa por frase. Multi-head reparte el trabajo entre varias cabezas que comparten el ancho del modelo.

¿Qué descripción explica correctamente qué hace la división en cabezas?

- Reparte las d_model componentes entre h cabezas: cada una trabaja con d_head = d_model / h.
- Da a cada cabeza su propio bloque contiguo de las componentes de Q, K y V.
- Permite que distintas cabezas se fijen a la vez en relaciones distintas de la misma frase.
- Es una matriz aprendida que mezcla componentes de todas las cabezas y conserva el ancho d_model.

**Clave:** Reparte las d_model componentes entre h cabezas: cada una trabaja con d_head = d_model / h.

### PRE-B2

**Pregunta:** Contexto — Al terminar, cada cabeza entrega su propio contexto, y esos resultados deben reunirse en un solo vector por token.

¿Qué descripción explica correctamente qué hace la concatenación?

- Coloca las salidas de las h cabezas una junto a otra, sobre el eje de componentes.
- Es una matriz aprendida que mezcla componentes de todas las cabezas y conserva el ancho d_model.
- Reúne en un solo vector lo que encontró cada cabeza, con la forma que necesita la suma residual.
- Da a cada cabeza su propio bloque contiguo de las componentes de Q, K y V.

**Clave:** Coloca las salidas de las h cabezas una junto a otra, sobre el eje de componentes.

### PRE-B3

**Pregunta:** Contexto — Tras la proyección conjunta, las componentes de Q, K y V se reparten entre las cabezas.

Lee la afirmación y decide si es verdadera o falsa:

Cada cabeza recibe su propio bloque contiguo de las componentes de Q, K y V.

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-B4

**Pregunta:** Contexto — La misma frase pasa por todas las cabezas. Piensa si sus mapas de atención tienen que coincidir.

Lee la afirmación y decide si es verdadera o falsa:

Todas las cabezas deben aprender exactamente el mismo mapa de atención.

- Verdadero
- Falso

**Clave:** Falso

### PRE-B5

**Pregunta:** Contexto — Cada concepto de este módulo resuelve un problema distinto. Revisa qué hace cada uno.

Selecciona las DOS asociaciones coherentes entre concepto y función.

- Atención independiente: Cada cabeza calcula sus scores, su softmax y su mezcla sin consultar a las demás.
- Proyección WO: Es una matriz aprendida que mezcla componentes de todas las cabezas y conserva el ancho d_model.
- Atención independiente: Es una matriz aprendida que mezcla componentes de todas las cabezas y conserva el ancho d_model.
- Proyección WO: Cada cabeza calcula sus scores, su softmax y su mezcla sin consultar a las demás.

**Clave:** Atención independiente: Cada cabeza calcula sus scores, su softmax y su mezcla sin consultar a las demás. · Proyección WO: Es una matriz aprendida que mezcla componentes de todas las cabezas y conserva el ancho d_model.

### PRE-B6

**Pregunta:** Contexto — Multi-head es una cadena: la salida de cada etapa alimenta a la siguiente.

Completa el flujo: Mapas por cabeza → ________ → Concatenación.

**Clave:** Contexto por cabeza

### PRE-B7

**Pregunta:** Contexto — Cada etapa resuelve un problema distinto: repartir el ancho, atender por separado o reunir los resultados.

Relaciona cada etapa con el motivo por el que se realiza.

**Clave:** Proyección conjunta → Una sola proyección grande es eficiente y equivale a preparar h proyecciones pequeñas · Scores independientes → Cada porción de componentes mide sus propias compatibilidades entre tokens · Contexto por cabeza → Recupera, por cabeza, la información que su mapa consideró útil · Proyección WO → Permite combinar lo que encontraron cabezas diferentes

### PRE-B8

**Pregunta:** Contexto — En las formas, B es el número de ejemplos, T el de tokens, h el de cabezas, d_head el ancho de una cabeza y d_model el ancho total.

Al terminar el paso «Salida multi-head», ¿qué forma (dimensiones) tiene el tensor que se obtiene? Escríbela eje por eje con los símbolos del recorrido.

**Clave:** [B,T,d_model]

### PRE-I1

**Pregunta:** Contexto — El punto de partida es la matriz X. Ordena las operaciones usando la salida de una como entrada de la siguiente.

Ordena las etapas según el flujo real de información.

**Clave:** Proyección conjunta → Reorganizar en h cabezas → Scores independientes → Mapas por cabeza

### PRE-I2

**Pregunta:** Contexto — El punto de partida son las cabezas ya separadas. Ordena las operaciones que las llevan a sus resultados.

Ordena las etapas según el flujo real de información.

**Clave:** Contexto por cabeza → Concatenación → Proyección WO → Salida multi-head

### PRE-I3

**Pregunta:** Contexto — Aquí debes relacionar cada transformación con el resultado inmediato que deja, no con el de pasos posteriores.

Relaciona cada transformación con la información que produce.

**Clave:** Proyección conjunta → Q/K/V conjuntos · Scores independientes → h matrices de scores · Contexto por cabeza → Salidas de cabezas · Proyección WO → Salida proyectada

### PRE-I4

**Pregunta:** Contexto — Sigue qué cambia realmente en cada etapa: pueden cambiar los ejes, los valores o la manera de agrupar las componentes.

Relaciona cada etapa con el cambio observable que produce.

**Clave:** Reorganizar en h cabezas → El ancho d_model se reparte como h bloques de d_head; los tokens no se cortan · Mapas por cabeza → En cada mapa, cada fila suma 1 · Concatenación → Desaparece el eje de cabezas y queda un solo vector por token · Salida multi-head → La salida se integra al flujo del bloque

### PRE-I5

**Pregunta:** Contexto — Una justificación correcta explica para qué es necesaria una operación; no basta con repetir su nombre.

Selecciona las DOS explicaciones que justifican correctamente su etapa.

- Scores independientes: Cada porción de componentes mide sus propias compatibilidades entre tokens
- Concatenación: Recupera el ancho completo del modelo antes de mezclar
- Scores independientes: Recupera el ancho completo del modelo antes de mezclar
- Concatenación: Cada porción de componentes mide sus propias compatibilidades entre tokens

**Clave:** Scores independientes: Cada porción de componentes mide sus propias compatibilidades entre tokens · Concatenación: Recupera el ancho completo del modelo antes de mezclar

### PRE-I6

**Pregunta:** Contexto — Para decidir si dos etapas son consecutivas, comprueba que la salida de la primera sea la entrada que necesita la segunda.

Lee la afirmación y decide si es verdadera o falsa:

En el flujo del módulo, después de «Reorganizar en h cabezas» ocurre «Scores independientes».

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-I7

**Pregunta:** Contexto — La pregunta ya indica la entrada de una operación. Elige su salida inmediata, no el resultado final de multi-head.

Completa: «Proyección WO» recibe El contexto concatenado y produce ________.

**Clave:** Salida proyectada

### PRE-I8

**Pregunta:** Contexto — El propósito explica por qué hace falta la operación; no es una descripción de sus pasos.

¿Por qué se realiza «Concatenación»?

- Recupera el ancho completo del modelo antes de mezclar
- Una sola proyección grande es eficiente y equivale a preparar h proyecciones pequeñas
- Cada cabeza necesita su propia porción de componentes para trabajar
- Cada porción de componentes mide sus propias compatibilidades entre tokens

**Clave:** Recupera el ancho completo del modelo antes de mezclar

### PRE-I9

**Pregunta:** Contexto — Un par entrada→salida sólo es válido si ambos pertenecen a la misma etapa; no mezcles etapas.

Selecciona los DOS pares que describen la entrada y la salida de una misma etapa del recorrido.

- La matriz X con forma [B,T,d_model] → Q/K/V conjuntos
- La salida proyectada por WO → MHA(X)
- La matriz X con forma [B,T,d_model] → MHA(X)
- La salida proyectada por WO → Q/K/V conjuntos

**Clave:** La matriz X con forma [B,T,d_model] → Q/K/V conjuntos · La salida proyectada por WO → MHA(X)

### PRE-A1

**Pregunta:** Contexto — El ancho del modelo se reparte por igual entre todas las cabezas.

Resuelve sin opciones: Las h cabezas reparten el ancho por igual: d_head = d_model / h. Con d_model=256 y h=8, ¿cuánto vale d_head?

**Clave:** 32

### PRE-A2

**Pregunta:** Contexto — Al separar, cada eje conserva un significado: ejemplos, cabezas, tokens y ancho de una cabeza, en ese orden.

Al separar Q en cabezas, sus ejes son [B, h, T, d_head]: ejemplos, cabezas, tokens y ancho. Con B=2, h=4, T=6 y d_head=16, ¿qué forma tiene Q separado?

- [2,4,6,16]
- [2,6,64]
- [4,2,16,6]
- [2,6,4]

**Clave:** [2,4,6,16]

### PRE-A3

**Pregunta:** Contexto — Cada opción une un dato con su resultado. Evalúa cada una por separado.

Selecciona las DOS opciones en las que el dato y su resultado están emparejados correctamente.

- 3 cabezas de [T, 20] concatenadas → ancho 60.
- Dos cabezas con mapas distintos → pueden ver relaciones distintas.
- 3 cabezas de [T, 20] concatenadas → ancho 20.
- Dos cabezas con mapas distintos → hay un error en el modelo.

**Clave:** 3 cabezas de [T, 20] concatenadas → ancho 60. · Dos cabezas con mapas distintos → pueden ver relaciones distintas.

### PRE-A4

**Pregunta:** Contexto — Las cuatro tarjetas forman un solo cálculo. Ordénalas de modo que la salida de cada una sirva a la siguiente.

Reconstruye el orden necesario para que la transformación sea válida.

**Clave:** Reorganizar en h cabezas → Scores independientes → Mapas por cabeza → Contexto por cabeza

### PRE-A5

**Pregunta:** Contexto — Resuelve cada situación por separado. Recuerda qué parte calcula cada cabeza y qué parte combina WO.

Relaciona cada situación con la conclusión correcta. Cada conclusión se usa una sola vez.

**Clave:** La concatenación deja los resultados en bloques separados, y después WO multiplica ese vector. ¿Qué se perdería al omitir WO? → Mezclar componentes aportados por cabezas diferentes · Después de concatenar, WO combina las cabezas. Antes de ese punto, ¿puede la cabeza 1 usar directamente la salida de la cabeza 2? → No; operan independientemente · Después de Multi-Head Attention, la suma residual combina MHA(X) con X, celda por celda. ¿Por qué la salida de MHA debe volver a d_model? → Ambos tensores deben tener la misma forma

### PRE-A6

**Pregunta:** Contexto — Compara el ancho antes y después de WO con el que usa una sola cabeza. Evalúa exactamente lo que afirma el caso.

Lee la afirmación y decide si es verdadera o falsa:

Caso: con h = 4 y d_model = 256, la concatenación tiene 256 componentes por token antes de WO, y WO conserva esa anchura.

- Verdadero
- Falso

**Clave:** Verdadero

### PRE-A7

**Pregunta:** Contexto — Multiplicar el número de cabezas por el ancho de cada una da el ancho total.

Responde sin opciones: El ancho total se reparte por igual, así que d_model = h × d_head. Un modelo tiene d_model = 384 y d_head = 64. ¿Cuántas cabezas usa?

**Clave:** 6

### PRE-A8

**Pregunta:** Contexto — El reparto se hace en bloques del mismo tamaño. Piensa qué condición debe cumplir d_model para hacerlo.

Esta implementación reparte d_model en h bloques iguales. Si d_model no es divisible por h, ¿qué operación falla conceptualmente?

- No puede repartirse en cabezas iguales
- Softmax no acepta decimales
- El vocabulario queda vacío
- No puede añadirse posición

**Clave:** No puede repartirse en cabezas iguales

## Post-test

### POST-B1

**Pregunta:** Contexto — Self-attention usa un solo mapa por frase. Multi-head reparte el trabajo entre varias cabezas que comparten el ancho del modelo.

¿Qué operación crea las cabezas a partir de Q, K y V completas?

- Reorganizar el último eje en h bloques y dejar el eje de cabezas al frente
- Calcular QKᵀ/√d_head en cada cabeza, en paralelo
- Aplicar softmax por separado en cada cabeza
- Multiplicar los pesos de atención por V en cada cabeza

**Clave:** Reorganizar el último eje en h bloques y dejar el eje de cabezas al frente

### POST-B2

**Pregunta:** Contexto — Al terminar, cada cabeza entrega su propio contexto, y esos resultados deben reunirse en un solo vector por token.

¿Qué operación reúne los resultados de todas las cabezas?

- Colocar los contextos uno junto a otro por cada token
- Multiplicar por la matriz aprendida WO
- Entregar el resultado a la etapa Add & Norm
- Calcular Q, K y V con todo su ancho d_model

**Clave:** Colocar los contextos uno junto a otro por cada token

### POST-B3

**Pregunta:** Contexto — Tras la proyección conjunta, las componentes de Q, K y V se reparten entre las cabezas.

Lee la afirmación y decide si es verdadera o falsa:

Todas las cabezas están obligadas a usar exactamente el mismo bloque de componentes.

- Verdadero
- Falso

**Clave:** Falso

### POST-B4

**Pregunta:** Contexto — La misma frase pasa por todas las cabezas. Piensa si sus mapas de atención tienen que coincidir.

Lee la afirmación y decide si es verdadera o falsa:

Varias cabezas permiten atender al mismo tiempo relaciones distintas de la misma frase.

- Verdadero
- Falso

**Clave:** Verdadero

### POST-B5

**Pregunta:** Contexto — Cada concepto de este módulo resuelve un problema distinto. Revisa qué hace cada uno.

Selecciona las DOS asociaciones coherentes entre concepto y función.

- Diferencias entre cabezas: Permite que distintas cabezas se fijen a la vez en relaciones distintas de la misma frase.
- Dimensiones multi-head: Por dentro se trabaja con [B,h,T,d_head]; por fuera, la forma sigue siendo [B,T,d_model].
- Diferencias entre cabezas: Por dentro se trabaja con [B,h,T,d_head]; por fuera, la forma sigue siendo [B,T,d_model].
- Dimensiones multi-head: Permite que distintas cabezas se fijen a la vez en relaciones distintas de la misma frase.

**Clave:** Diferencias entre cabezas: Permite que distintas cabezas se fijen a la vez en relaciones distintas de la misma frase. · Dimensiones multi-head: Por dentro se trabaja con [B,h,T,d_head]; por fuera, la forma sigue siendo [B,T,d_model].

### POST-B6

**Pregunta:** Contexto — Multi-head es una cadena: la salida de cada etapa alimenta a la siguiente.

Completa el flujo: Contexto por cabeza → ________ → Proyección WO.

**Clave:** Concatenación

### POST-B7

**Pregunta:** Contexto — Cada etapa resuelve un problema distinto: repartir el ancho, atender por separado o reunir los resultados.

Relaciona cada etapa con el motivo por el que se realiza.

**Clave:** Reorganizar en h cabezas → Cada cabeza necesita su propia porción de componentes para trabajar · Mapas por cabeza → Evita que todas tengan que compartir una sola relación entre tokens · Concatenación → Recupera el ancho completo del modelo antes de mezclar · Salida multi-head → Debe tener la misma forma que X para poder sumarse a ella

### POST-B8

**Pregunta:** Contexto — En las formas, B es el número de ejemplos, T el de tokens, h el de cabezas, d_head el ancho de una cabeza y d_model el ancho total.

Al terminar el paso «Proyección conjunta», ¿qué forma (dimensiones) tiene el tensor que se obtiene? Escríbela eje por eje con los símbolos del recorrido.

**Clave:** [B,T,d_model]

### POST-I1

**Pregunta:** Contexto — El punto de partida es la matriz X. Ordena las operaciones usando la salida de una como entrada de la siguiente.

Ordena las etapas según el flujo real de información.

**Clave:** Reorganizar en h cabezas → Scores independientes → Mapas por cabeza → Contexto por cabeza

### POST-I2

**Pregunta:** Contexto — El punto de partida son las cabezas ya separadas. Ordena las operaciones que las llevan a sus resultados.

Ordena las etapas según el flujo real de información.

**Clave:** Mapas por cabeza → Contexto por cabeza → Concatenación → Proyección WO

### POST-I3

**Pregunta:** Contexto — Aquí debes relacionar cada transformación con el resultado inmediato que deja, no con el de pasos posteriores.

Relaciona cada transformación con la información que produce.

**Clave:** Reorganizar en h cabezas → Q/K/V por cabeza · Mapas por cabeza → Pesos multi-head · Concatenación → Contexto concatenado · Salida multi-head → MHA(X)

### POST-I4

**Pregunta:** Contexto — Sigue qué cambia realmente en cada etapa: pueden cambiar los ejes, los valores o la manera de agrupar las componentes.

Relaciona cada etapa con el cambio observable que produce.

**Clave:** Proyección conjunta → Una entrada da lugar a tres matrices, todavía sin separar · Scores independientes → Cada cabeza obtiene su propia tabla de scores de T×T · Contexto por cabeza → Cada cabeza pasa de un mapa T×T a un contexto de T×d_head · Proyección WO → Las cabezas dejan de ser bloques aislados dentro del vector

### POST-I5

**Pregunta:** Contexto — Una justificación correcta explica para qué es necesaria una operación; no basta con repetir su nombre.

Selecciona las DOS explicaciones que justifican correctamente su etapa.

- Reorganizar en h cabezas: Cada cabeza necesita su propia porción de componentes para trabajar
- Proyección WO: Permite combinar lo que encontraron cabezas diferentes
- Reorganizar en h cabezas: Permite combinar lo que encontraron cabezas diferentes
- Proyección WO: Cada cabeza necesita su propia porción de componentes para trabajar

**Clave:** Reorganizar en h cabezas: Cada cabeza necesita su propia porción de componentes para trabajar · Proyección WO: Permite combinar lo que encontraron cabezas diferentes

### POST-I6

**Pregunta:** Contexto — Para decidir si dos etapas son consecutivas, comprueba que la salida de la primera sea la entrada que necesita la segunda.

Lee la afirmación y decide si es verdadera o falsa:

En el flujo del módulo, después de «Reorganizar en h cabezas» ocurre «Contexto por cabeza».

- Verdadero
- Falso

**Clave:** Falso

### POST-I7

**Pregunta:** Contexto — La pregunta ya indica la entrada de una operación. Elige su salida inmediata, no el resultado final de multi-head.

Completa: «Contexto por cabeza» recibe Pesos y Values de cada cabeza y produce ________.

**Clave:** Salidas de cabezas

### POST-I8

**Pregunta:** Contexto — El propósito explica por qué hace falta la operación; no es una descripción de sus pasos.

¿Por qué se realiza «Scores independientes»?

- Cada porción de componentes mide sus propias compatibilidades entre tokens
- Una sola proyección grande es eficiente y equivale a preparar h proyecciones pequeñas
- Recupera el ancho completo del modelo antes de mezclar
- Permite combinar lo que encontraron cabezas diferentes

**Clave:** Cada porción de componentes mide sus propias compatibilidades entre tokens

### POST-I9

**Pregunta:** Contexto — Un par entrada→salida sólo es válido si ambos pertenecen a la misma etapa; no mezcles etapas.

Selecciona los DOS pares que describen la entrada y la salida de una misma etapa del recorrido.

- Q, K y V completas → Q/K/V por cabeza
- El contexto concatenado → Salida proyectada
- Q, K y V completas → Salida proyectada
- El contexto concatenado → Q/K/V por cabeza

**Clave:** Q, K y V completas → Q/K/V por cabeza · El contexto concatenado → Salida proyectada

### POST-A1

**Pregunta:** Contexto — El ancho del modelo se reparte por igual entre todas las cabezas.

Resuelve sin opciones: Las cabezas reparten el ancho por igual: d_head = d_model / h. Con d_model = 768 y h = 12, ¿cuánto vale d_head?

**Clave:** 64

### POST-A2

**Pregunta:** Contexto — Al separar, cada eje conserva un significado: ejemplos, cabezas, tokens y ancho de una cabeza, en ese orden.

Al separar en cabezas, los ejes son [B, h, T, d_head]. Con B=3, h=8, T=5 y d_head=32, ¿qué forma tiene K después de separarla?

- [3,8,5,32]
- [3,5,256]
- [8,3,32,5]
- [3,5,8]

**Clave:** [3,8,5,32]

### POST-A3

**Pregunta:** Contexto — Cada opción une un dato con su resultado. Evalúa cada una por separado.

Selecciona las DOS opciones en las que el dato y su resultado están emparejados correctamente.

- 5 cabezas de [T, 12] concatenadas → ancho 60.
- Una cabeza sigue un rasgo y otra, otro → pueden especializarse.
- 5 cabezas de [T, 12] concatenadas → ancho 17.
- Una cabeza sigue un rasgo y otra, otro → WO dejó de existir.

**Clave:** 5 cabezas de [T, 12] concatenadas → ancho 60. · Una cabeza sigue un rasgo y otra, otro → pueden especializarse.

### POST-A4

**Pregunta:** Contexto — Las cuatro tarjetas forman un solo cálculo. Ordénalas de modo que la salida de cada una sirva a la siguiente.

Reconstruye el orden necesario para que la transformación sea válida.

**Clave:** Scores independientes → Mapas por cabeza → Contexto por cabeza → Concatenación

### POST-A5

**Pregunta:** Contexto — Resuelve cada situación por separado. Recuerda qué parte calcula cada cabeza y qué parte combina WO.

Relaciona cada situación con la conclusión correcta. Cada conclusión se usa una sola vez.

**Clave:** La concatenación deja cada cabeza en su bloque y WO multiplica ese vector. Un compañero elimina WO y deja sólo la concatenación. ¿Qué capacidad pierde el bloque? → Mezclar componentes aportados por cabezas diferentes · WO reúne las cabezas al final. Mientras la cabeza 3 calcula sus scores y su softmax, ¿usa los pesos de la cabeza 1? → No; operan independientemente · La suma residual combina dos tensores celda por celda. La salida de MHA se suma con su entrada X [2, 6, 128]. ¿Qué condición de forma exige? → MHA(X) también debe ser [2, 6, 128]

### POST-A6

**Pregunta:** Contexto — Compara el ancho antes y después de WO con el que usa una sola cabeza. Evalúa exactamente lo que afirma el caso.

Lee la afirmación y decide si es verdadera o falsa:

Caso: con h = 4 y d_model = 256, WO reduce la concatenación a 64 componentes, la anchura de una cabeza.

- Verdadero
- Falso

**Clave:** Falso

### POST-A7

**Pregunta:** Contexto — Multiplicar el número de cabezas por el ancho de cada una da el ancho total.

Responde sin opciones: El ancho total se reparte por igual, así que d_model = h × d_head. Un modelo tiene d_model = 640 y d_head = 80. ¿Cuántas cabezas usa?

**Clave:** 8

### POST-A8

**Pregunta:** Contexto — El reparto se hace en bloques del mismo tamaño. Piensa qué condición debe cumplir d_model para hacerlo.

Esta implementación reparte d_model en h bloques iguales. Se intenta usar d_model = 100 con h = 8. ¿Qué falla?

- No puede repartirse en cabezas iguales
- Softmax no acepta decimales
- El vocabulario queda vacío
- No puede añadirse posición

**Clave:** No puede repartirse en cabezas iguales

## Retos del laboratorio

### LAB-m4_l1

**Pregunta:** Ejemplo de reparto: con d_model = 40 y h = 5, cada cabeza recibe una porción de Q, K y V ya proyectados. ¿Cuántas componentes le tocan, y qué pasa con los tokens?

**Respuesta correcta:** 8 componentes; todas las cabezas ven los mismos tokens

**Explicación:** 40 / 5 = 8. La anchura se reparte en bloques; los tokens no se cortan.

### LAB-m4_l2

**Pregunta:** En el paso de separación, cambia de cabeza con su selector. Si B=1, h=2, T=3 y d_head=4, ¿qué forma tiene Q separado, y qué eje recorre el selector?

**Respuesta correcta:** [1,2,3,4]; el selector recorre el eje de cabezas

**Explicación:** Los ejes son [B, h, T, d_head]. El selector recorre h; los ejemplos y las posiciones no cambian.

### LAB-m4_l3

**Pregunta:** Ejemplo de concatenación: 2 cabezas producen [T, 12]. Los bloques quedan uno junto a otro. ¿Qué ancho resulta, y qué operación falta todavía?

**Respuesta correcta:** 24; falta mezclarlos con WO

**Explicación:** 2 × 12 = 24. Concatenar sólo une bloques; WO aprende después a combinarlos.

### LAB-m4_l4

**Pregunta:** Compara los mapas al cambiar de cabeza: una parece seguir relaciones locales en este ejemplo. ¿Qué conviene comprobar antes de afirmar que se especializó?

**Respuesta correcta:** Que el patrón se repita en varias entradas

**Explicación:** Un mapa aislado sugiere una hipótesis; observar el patrón en distintos ejemplos aporta evidencia de especialización.

### LAB-m4_l5

**Pregunta:** En el paso de WO, la cuadrícula conserva su tamaño, pero cada componente de salida puede depender de varios bloques. ¿Qué evidencia aporta?

**Respuesta correcta:** WO aprendió a mezclar información entre los bloques concatenados

**Explicación:** WO mantiene la interfaz d_model, pero cada componente de salida puede combinar aportes de distintas cabezas.

### LAB-m4_l6

**Pregunta:** En el paso del contexto por cabeza, selecciona otra cabeza: aparece otro mapa, sin copiar el patrón anterior. ¿Qué propiedad evidencia?

**Respuesta correcta:** Las cabezas calculan su atención de forma independiente

**Explicación:** Antes de concatenarse, cada cabeza obtiene scores y pesos con sus propias proyecciones.

### LAB-m4_l7

**Pregunta:** La salida de WO entra a la suma residual sin adaptadores adicionales, porque ambos tensores miden [1, 3, 40]. ¿Qué permite esa suma directa?

**Respuesta correcta:** Que cada celda de salida tiene una celda correspondiente en X

**Explicación:** WO devuelve una representación compatible con X, por lo que la residual puede sumarlas elemento a elemento.

### LAB-m4_l8

**Pregunta:** En la proyección conjunta aún no hay cabezas; después, cada una toma su bloque. Con d_model = 12 y h = 3, ¿qué componentes usa la cabeza 0?

**Respuesta correcta:** Un bloque contiguo: de la 0 a la 3

**Explicación:** 12 / 3 = 4 componentes por cabeza. La reorganización asigna a cada una un bloque contiguo del eje de componentes.
