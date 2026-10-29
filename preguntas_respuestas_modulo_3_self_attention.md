# Preguntas y respuestas correctas — Módulo 3: Self-Attention

Este documento corresponde a la versión 15 del banco modular. El pre-test y el
post-test tienen 25 reactivos disponibles cada uno; cada intento selecciona 15.

## Pregunta ancla

**Pregunta:** En «el banco del río», ¿cómo puede el vector de «banco» incorporar
información de «río» para no confundirse con un banco de dinero?

**Respuesta correcta:** La Query de «banco» se compara con las Keys de todos los
tokens. Si es más compatible con la Key de «río», softmax asigna mayor peso a
esa posición y entra más del Value de «río» en la nueva representación de
«banco».

## Comprobaciones del recorrido guiado

### R1. Matriz X

**Pregunta:** X coloca un vector de d_model componentes en cada fila. Para una
frase de 5 tokens y d_model=64, ¿qué forma tiene X si omitimos el eje del batch?

**Respuesta correcta:** `[5,64]`.

### R2. Proyecciones Q, K y V

**Pregunta:** Q=XWQ. Si X contiene 5 tokens con 64 componentes y WQ proyecta de
64 a 16 componentes, ¿qué forma tiene Q?

**Respuesta correcta:** `[5,16]`.

### R3. Transponer K

**Pregunta:** K tiene una fila por cada uno de 5 tokens y 16 componentes por
Key: `[5,16]`. Al intercambiar filas y columnas, ¿qué forma tiene Kᵀ?

**Respuesta correcta:** `[16,5]`.

### R4. Producto punto

**Pregunta:** El score mide compatibilidad mediante el producto punto. Para
Query `q=[1,2]` y Key `k=[3,0]`, ¿qué score produce `1·3+2·0`?

**Respuesta correcta:** `3`.

### R5. Escalamiento

**Pregunta:** El score escalado se calcula como `score crudo/√d_k`. Con d_k=16
y score crudo=8, ¿qué valor se entrega a softmax?

**Respuesta correcta:** `2`.

### R6. Softmax

**Pregunta:** Softmax convierte cada fila de scores en pesos positivos que
suman 1. Si dos Keys reciben scores iguales `[0,0]`, ¿qué pesos obtiene la
Query?

**Respuesta correcta:** `[0.5,0.5]`.

### R7. Pesos × V

**Pregunta:** La salida es una suma ponderada de los Values. Si una Query asigna
pesos `[0.5,0.5]` a Values escalares `[2,6]`, ¿qué contexto obtiene?

**Respuesta correcta:** `4`.

### R8. Salida contextualizada

**Pregunta:** La atención conserva una salida por Query. Si entran T=5 Queries
y cada salida tiene d_v=16 componentes, ¿cuántos vectores contextualizados
entrega la cabeza?

**Respuesta correcta:** `5` vectores.

## Pre-test — banco de 25 reactivos

### PRE-B1. Entrada a atención

**Pregunta:** Contexto: la frase «el banco del río» ya fue convertida en
vectores. X es la tabla que recibe self-attention antes de calcular Q, K y V.
¿Qué descripción explica correctamente qué contiene X?

**Respuesta correcta:** La matriz X reúne la frase: cada fila es el vector de un
token y tiene d_model componentes.

### PRE-B2. Escalamiento por √d_k

**Pregunta:** Contexto: QKᵀ produce scores de compatibilidad. Si sus magnitudes
son muy grandes, softmax puede concentrar casi todo el peso en una sola Key.
¿Qué hace el escalamiento por √d_k para evitarlo?

**Respuesta correcta:** Divide cada compatibilidad entre √d_k para que softmax
no se vuelva una decisión extrema de todo o nada.

### PRE-B3. Matrices WQ, WK y WV

**Pregunta:** En Q=XWQ, K=XWK y V=XWV intervienen la entrada X de la frase y las
matrices W del modelo. Evalúa la afirmación: «WQ, WK y WV son parámetros
aprendidos que transforman X para obtener Q, K y V». ¿Es verdadera o falsa?

**Respuesta correcta:** Verdadero.

### PRE-B4. Producto QKᵀ

**Pregunta:** Self-attention primero obtiene una tabla T×T y después produce un
vector de contexto por token. Evalúa la afirmación: «QKᵀ mezcla directamente
los Values y produce el contexto final». ¿Es verdadera o falsa?

**Respuesta correcta:** Falso. QKᵀ produce scores de compatibilidad.

### PRE-B5. Asociaciones de conceptos

**Pregunta:** En una fila del mapa, la Query pertenece al token que busca
información. Cada columna corresponde a la Key de un token; su Value contiene
la información que podría aportar. Selecciona las dos asociaciones correctas.

**Respuestas correctas:**

- Q, K y V → La Query expresa qué busca un token, la Key permite compararlo y
  el Value contiene la información que puede aportar.
- Softmax de atención → Convierte por separado cada fila de compatibilidades en
  pesos positivos que suman 1.

### PRE-B6. Completar el flujo

**Pregunta:** Los scores de QKᵀ aún no son pesos. Antes de normalizarlos se
controla su magnitud. Completa: `Producto QKᵀ → ________ → Softmax por fila`.

**Respuesta correcta:** Escalamiento.

### PRE-B7. Etapa y motivo

**Pregunta:** Cada etapa resuelve un problema distinto: conservar los tokens en
orden, comparar pares, controlar los scores o construir contexto. Relaciona
cada etapa con el motivo por el que se realiza.

**Respuesta correcta:**

- Matriz X → La atención necesita consultar la frase completa sin perder qué
  fila pertenece a cada token.
- Transponer K → Coloca una Key por columna para comparar todas las Queries y
  Keys con un solo producto.
- Escalamiento → Evita que softmax se concentre casi por completo en una sola
  Key cuando d_k es grande.
- Pesos × V → Construye el contexto con más aporte de los tokens que recibieron
  mayor peso.

### PRE-B8. Forma de la salida

**Pregunta:** B es el número de ejemplos, T el número de tokens y d_v el ancho
del contexto. ¿Qué forma tiene la salida contextualizada?

**Respuesta correcta:** `[B,T,d_v]`.

### PRE-I1. Primer tramo del flujo

**Pregunta:** Ordena las etapas para obtener las compatibilidades desde la
entrada X.

**Respuesta correcta:** Matriz X → Proyecciones Q, K y V → Transponer K →
Producto QKᵀ.

### PRE-I2. Segundo tramo del flujo

**Pregunta:** Ordena las etapas desde los scores crudos hasta la salida.

**Respuesta correcta:** Escalamiento → Softmax por fila → Pesos × V → Salida
contextualizada.

### PRE-I3. Transformación y resultado

**Pregunta:** Relaciona cada transformación con la información que produce.

**Respuesta correcta:**

- Matriz X → X: una fila por token.
- Transponer K → Matriz Kᵀ.
- Escalamiento → Scores escalados.
- Pesos × V → Contexto por token.

### PRE-I4. Cambios observables

**Pregunta:** Relaciona cada etapa con el cambio que produce.

**Respuesta correcta:**

- Proyecciones Q, K y V → Cada fila de X origina una Query, una Key y un Value.
- Producto QKᵀ → d_k se suma dentro de cada producto y queda una tabla T×T.
- Softmax por fila → Cada fila se convierte en pesos positivos que suman 1.
- Salida contextualizada → El significado aislado se vuelve dependiente del
  contexto.

### PRE-I5. Justificación de etapas

**Pregunta:** Selecciona las dos explicaciones que justifican correctamente su
etapa.

**Respuestas correctas:**

- Transponer K → Coloca una Key por columna para comparar todas las Queries y
  Keys con un solo producto.
- Softmax por fila → Cada Query debe repartir un total de 1 entre todas las
  Keys permitidas.

### PRE-I6. Secuencia

**Pregunta:** Después de «Proyecciones Q, K y V» ocurre «Transponer K».
¿Verdadero o falso?

**Respuesta correcta:** Verdadero.

### PRE-I7. Salida de pesos × V

**Pregunta:** «Pesos × V» recibe los pesos calculados por softmax y la matriz V.
¿Qué produce?

**Respuesta correcta:** Contexto por token.

### PRE-I8. Propósito de softmax

**Pregunta:** ¿Por qué se realiza softmax por fila?

**Respuesta correcta:** Porque cada Query debe repartir un total de 1 entre
todas las Keys permitidas.

### PRE-I9. Pares entrada–salida

**Pregunta:** Selecciona los dos pares que describen la entrada y la salida de
una misma etapa.

**Respuestas correctas:**

- Un vector con posición por token → X: una fila por token.
- Un vector de contexto por Query → `Attention(X)`, una fila contextualizada por
  token.

### PRE-A1. Forma de QKᵀ

**Pregunta:** Una frase tiene 5 tokens. Q y K tienen forma `[5,32]`. Al calcular
QKᵀ, ¿qué forma tiene la tabla que compara los 5 tokens entre sí?

**Respuesta correcta:** `[5,5]`.

### PRE-A2. Score escalado

**Pregunta:** Si d_k=64 y el score crudo vale 16, ¿qué score escalado se
entrega a softmax?

**Respuesta correcta:** `2`.

### PRE-A3. Interpretación y mezcla

**Pregunta:** Selecciona las dos opciones en las que los pesos y su efecto están
emparejados correctamente.

**Respuestas correctas:**

- Pesos `[0.1,0.7,0.2]` → el segundo Value aporta más.
- Pesos `[0.25,0.75]` y Values `[4,8]` → salida `7`.

### PRE-A4. Orden matemático

**Pregunta:** Reconstruye el orden necesario para que la transformación sea
válida.

**Respuesta correcta:** Proyecciones Q, K y V → Transponer K → Producto QKᵀ →
Escalamiento.

### PRE-A5. Situación y conclusión

**Pregunta:** Relaciona cada situación con su conclusión.

**Respuesta correcta:**

- El vector de «banco» que expresa lo que busca y se compara con Keys → Query.
- Si cambia X pero WQ permanece fija → Q se recalcula a partir del nuevo X.
- Softmax se aplica por fila → los pesos de cada Query sobre todas las Keys
  suman 1.

### PRE-A6. Efecto de no escalar

**Pregunta:** Si d_k crece de 16 a 256 y los scores no se dividen entre √d_k,
su magnitud tiende a crecer y softmax puede concentrar casi todo el peso en una
sola Key. ¿Verdadero o falso?

**Respuesta correcta:** Verdadero.

### PRE-A7. Cálculo de contexto

**Pregunta:** Una Query mezcla Values `[10,0,2]` con pesos `[0.2,0.3,0.5]`.
¿Cuál es el contexto resultante?

**Respuesta correcta:** `3`.

### PRE-A8. Forma de pesos × V

**Pregunta:** Una cabeza procesa T=6 Queries y sus Values tienen ancho d_v=16.
¿Qué forma tiene su salida?

**Respuesta correcta:** `[6,16]`.

## Post-test — banco de 25 reactivos

### POST-B1. Operación de Matriz X

**Pregunta:** La frase «el banco del río» ya fue convertida en vectores. X es la
tabla que recibirá self-attention. ¿Qué operación construye la matriz X?

**Respuesta correcta:** Apilar un vector por token en el orden de la frase.

### POST-B2. Operación de escalamiento

**Pregunta:** QKᵀ produjo scores de compatibilidad. Si son muy grandes, softmax
puede concentrar casi todo el peso en una Key. ¿Qué operación se realiza durante
el escalamiento?

**Respuesta correcta:** Dividir cada score entre √d_k.

### POST-B3. Parámetros aprendidos

**Pregunta:** En Q=XWQ, K=XWK y V=XWV intervienen la entrada X y las matrices W
del modelo. Evalúa la afirmación: «WQ, WK y WV son máscaras fijas, no parámetros
aprendidos». ¿Es verdadera o falsa?

**Respuesta correcta:** Falso.

### POST-B4. Función de QKᵀ

**Pregunta:** Self-attention primero obtiene una tabla T×T y después produce un
contexto por token. Evalúa la afirmación: «QKᵀ compara la Query de cada token
con la Key de todos los tokens y produce scores de compatibilidad». ¿Es
verdadera o falsa?

**Respuesta correcta:** Verdadero.

### POST-B5. Asociaciones de operaciones

**Pregunta:** En una fila del mapa, la Query pertenece al token que busca
información. Cada columna corresponde a la Key de un token; su Value contiene
la información que podría aportar. Selecciona las dos asociaciones correctas.

**Respuestas correctas:**

- Producto QKᵀ → Compara la Query de cada token con la Key de todos los tokens.
- Mezcla ponderada de V → Multiplica cada Value por su peso y suma las
  contribuciones.

### POST-B6. Completar el flujo

**Pregunta:** Después de controlar la magnitud de los scores, cada fila debe
convertirse en pesos antes de mezclar V. Completa:
`Escalamiento → ________ → Pesos × V`.

**Respuesta correcta:** Softmax por fila.

### POST-B7. Etapa y propósito

**Pregunta:** Relaciona cada etapa con el motivo por el que se realiza.

**Respuesta correcta:**

- Proyecciones Q, K y V → Asigna a cada token los papeles de buscar, ser
  comparado y aportar contenido.
- Producto QKᵀ → Obtiene una compatibilidad para cada par de tokens.
- Softmax por fila → Cada Query reparte un total de 1 entre las Keys permitidas.
- Salida contextualizada → Cada token conserva su lugar e incorpora información
  de la frase.

### POST-B8. Forma de X

**Pregunta:** B es el número de ejemplos, T el número de tokens y d_model el
ancho de cada vector. ¿Qué forma tiene la matriz X?

**Respuesta correcta:** `[B,T,d_model]`.

### POST-I1. Orden hasta escalamiento

**Pregunta:** Ordena las etapas según el flujo real.

**Respuesta correcta:** Proyecciones Q, K y V → Transponer K → Producto QKᵀ →
Escalamiento.

### POST-I2. Orden desde QKᵀ hasta V

**Pregunta:** Ordena las etapas desde las compatibilidades hasta el contexto.

**Respuesta correcta:** Producto QKᵀ → Escalamiento → Softmax por fila → Pesos ×
V.

### POST-I3. Transformación y salida

**Pregunta:** Relaciona cada transformación con lo que produce.

**Respuesta correcta:**

- Proyecciones Q, K y V → Matrices Q, K y V.
- Producto QKᵀ → Scores crudos de compatibilidad.
- Softmax por fila → Pesos de atención.
- Salida contextualizada → `Attention(X)`, una fila contextualizada por token.

### POST-I4. Cambios observables

**Pregunta:** Relaciona cada etapa con el cambio que produce.

**Respuesta correcta:**

- Matriz X → T tokens forman T filas de ancho d_model.
- Transponer K → K pasa de `[T,d_k]` a `[d_k,T]` sin cambiar sus valores.
- Escalamiento → Los valores se reducen, pero conservan su orden y forma T×T.
- Pesos × V → La dimensión de Keys se suma y queda un vector d_v por Query.

### POST-I5. Justificación de etapas

**Pregunta:** Selecciona las dos explicaciones correctas.

**Respuestas correctas:**

- Proyecciones Q, K y V → Asigna a cada token tres papeles: buscar, ser
  comparado y aportar contenido.
- Pesos × V → Construye el contexto con más aporte de los tokens que recibieron
  mayor peso.

### POST-I6. Secuencia incorrecta

**Pregunta:** Después de «Proyecciones Q, K y V» ocurre «Escalamiento».
¿Verdadero o falso?

**Respuesta correcta:** Falso. Primero se transpone K y se calcula QKᵀ.

### POST-I7. Salida del escalamiento

**Pregunta:** «Escalamiento» recibe scores crudos de QKᵀ. ¿Qué produce?

**Respuesta correcta:** Scores escalados.

### POST-I8. Propósito de transponer K

**Pregunta:** ¿Por qué se transpone K?

**Respuesta correcta:** Para colocar una Key por columna y comparar todas las
Queries y Keys con un solo producto matricial.

### POST-I9. Pares entrada–salida

**Pregunta:** Selecciona los dos pares que pertenecen a una misma etapa.

**Respuestas correctas:**

- X y los parámetros WQ, WK y WV → Matrices Q, K y V.
- Pesos calculados por softmax y matriz V → Contexto por token.

### POST-A1. Forma de scores

**Pregunta:** Una frase tiene 7 tokens. Q y K tienen forma `[7,64]`. ¿Qué forma
tiene QKᵀ?

**Respuesta correcta:** `[7,7]`.

### POST-A2. Escalamiento numérico

**Pregunta:** Con d_k=16 y un producto punto Query–Key de 12, ¿qué score
escalado se entrega a softmax?

**Respuesta correcta:** `3`.

### POST-A3. Interpretación y mezcla

**Pregunta:** Selecciona las dos opciones en las que los pesos y su efecto están
emparejados correctamente.

**Respuestas correctas:**

- Pesos `[0.5,0.1,0.4]` → el primer Value aporta más.
- Values `[5,10]` con pesos `[0.6,0.4]` → salida `7`.

### POST-A4. Orden hasta softmax

**Pregunta:** Reconstruye el orden necesario para obtener pesos válidos.

**Respuesta correcta:** Transponer K → Producto QKᵀ → Escalamiento → Softmax
por fila.

### POST-A5. Situación y conclusión

**Pregunta:** Relaciona cada situación con su conclusión.

**Respuesta correcta:**

- El vector de «banco» que expresa lo que busca → Query.
- Dos matrices X distintas con la misma WQ → producen Queries distintas.
- En un mapa `[T,T]`, después de softmax → cada fila suma 1.

### POST-A6. Orden después de escalar

**Pregunta:** Dividir todos los scores de una fila entre la misma constante
positiva √d_k cambia cuál Key tiene el score más alto. ¿Verdadero o falso?

**Respuesta correcta:** Falso. Reduce la magnitud, pero conserva el orden.

### POST-A7. Cálculo de contexto

**Pregunta:** Una Query mezcla Values `[4,8,0]` con pesos `[0.5,0.25,0.25]`.
¿Cuál es el contexto resultante?

**Respuesta correcta:** `4`.

### POST-A8. Forma de la salida

**Pregunta:** Una cabeza procesa T=9 Queries y sus Values tienen ancho d_v=32.
¿Qué forma tiene su salida?

**Respuesta correcta:** `[9,32]`.

## Preguntas del laboratorio

### LAB-1. Entrada X

**Pregunta:** Self-attention comienza con la matriz X: una tabla que conserva
los tokens en el orden de la frase. ¿Qué representa cada fila antes de calcular
Q, K y V?

**Respuesta correcta:** La representación de un token.

### LAB-2. Parámetros WQ, WK y WV

**Pregunta:** Compara dos frases que difieren en una palabra. Como Q=XWQ,
K=XWK y V=XWV, cambia X; las matrices W son parámetros fijos durante esta
exploración. ¿Qué cambia y qué queda igual?

**Respuesta correcta:** Cambian Q, K y V; WQ, WK y WV quedan iguales.

### LAB-3. Papeles de Q, K y V

**Pregunta:** «río» le ofrece información a «banco». ¿Qué vector de «río» se
compara con la Query de «banco» y cuál se mezcla en la salida?

**Respuesta correcta:** Se compara la Key de «río» y se mezcla su Value.

### LAB-4. Celda de QKᵀ

**Pregunta:** En la vista QKᵀ, sigue la fila de la Query de «banco» hasta la
columna de la Key de «río». ¿Qué representa la celda donde se cruzan?

**Respuesta correcta:** Un score de compatibilidad entre lo que busca «banco» y
lo que identifica a «río».

### LAB-5. Escalamiento

**Pregunta:** La animación compara una fila antes y después de dividir entre
√d_k: `[0,5,10]` pasa a `[0,1,2]`. ¿Qué cambió y qué se conservó?

**Respuesta correcta:** Bajó la magnitud, pero el tercer score siguió siendo el
mayor.

### LAB-6. Máscara de padding

**Pregunta:** Algunas frases se completan con el token especial PAD para que
tengan la misma longitud. En el encoder, `mask(S)` impide atender esas columnas:
cambia su score a −∞ antes de softmax. Si una columna contiene PAD, ¿qué peso
recibe? Después de excluirla, ¿cuánto suman los pesos de los tokens reales de
esa fila?

**Respuesta correcta:** PAD recibe peso 0 y los pesos de los tokens reales
siguen sumando 1. Si no existe PAD, `mask(S)` no cambia ninguna celda.

### LAB-7. Softmax

**Pregunta:** Una Query asigna pesos `[0.2,0.2,0.6]` a tres Values. ¿Qué Value
domina la mezcla y cuánto suman los pesos?

**Respuesta correcta:** El tercer Value; los pesos suman 1.

### LAB-8. Mezcla ponderada

**Pregunta:** Una Query asigna 40 % al Value 5 y 60 % al Value 10. ¿Qué contexto
escalar produce `0.4·5+0.6·10`?

**Respuesta correcta:** `8`.

### LAB-9. Forma del contexto

**Pregunta:** Pesos×V produce un vector de d_v componentes para cada Query. Con
T=4 tokens y d_v=8, ¿qué forma tiene el contexto de una cabeza?

**Respuesta correcta:** `[4,8]`.

### LAB-10. Backward

**Pregunta:** Durante entrenamiento, backward recorre el cálculo en sentido
inverso para identificar qué parámetros influyeron en la pérdida L. Si Q=XWQ,
K=XWK y V=XWV, ¿hasta qué matrices debe llegar el gradiente?

**Respuesta correcta:** Hasta WQ, WK y WV, siguiendo en reversa las operaciones
que produjeron Q, K y V; así se obtienen ∂L/∂WQ, ∂L/∂WK y ∂L/∂WV.

### LAB-11. Actualización hipotética

**Pregunta:** En `W′=W−ηg`, W es el peso actual, g es su gradiente y η indica el
tamaño del paso. El laboratorio sólo simula el cálculo y no modifica el modelo.
¿Qué representa W′?

**Respuesta correcta:** El valor que tendría W después de un paso hipotético
guiado por el gradiente.

## Pregunta de cierre del laboratorio

**Pregunta:** En self-attention, el token que pregunta usa su Query para
compararse con la Key de cada token. Después softmax convierte esas
comparaciones en pesos. ¿Qué determina cuánta información de otro token entra
en la mezcla final?

**Respuesta correcta:** La compatibilidad entre la Query del token que pregunta
y la Key del otro token, normalizada por softmax. Ese peso determina cuánto del
Value correspondiente entra en la salida.
