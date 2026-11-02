.pragma library
// Qué puede probar el alumno en cada paso del laboratorio. La regla: el cambio
// debe producir una diferencia visible y relacionada con ese paso. Donde no hay
// nada que variar se recorre la fórmula, en vez de sugerir un control sin efecto
// (por ejemplo, «otra cabeza» cuando las cabezas todavía no existen).
//
// `action`: replay, token, head, layer, causal, temperature, top_k, top_p, filters
// o rerun. Si el control no está disponible, la pantalla recurre a replay.

var REPLAY_TITLE = "Recorre la operación"
var REPLAY_SUBTITLE = "En este paso no hay un control que cambiar: se observa lo que hace."

function replay(label, instruction) {
    return { action: "replay", title: REPLAY_TITLE, subtitle: REPLAY_SUBTITLE,
             label: label, instruction: instruction }
}

function token(instruction) {
    return { action: "token", label: "Observar otro token", instruction: instruction }
}

function head(instruction) {
    return { action: "head", label: "Comparar otra cabeza", instruction: instruction }
}

function layer(instruction) {
    return { action: "layer", label: "Comparar otra capa", instruction: instruction }
}

function causal(instruction) {
    return { action: "causal", label: "Alternar la máscara causal", instruction: instruction }
}

var RECORRER_GRADIENTE = replay("Recorrer el regreso del error",
    "Reproduce la animación y sigue la señal desde la pérdida hasta los parámetros. Identifica a cuáles llega.")
var RECORRER_AJUSTE = replay("Recorrer el ajuste",
    "Reproduce la animación y compara el parámetro antes y después. Recuerda que el laboratorio no modifica el modelo.")

var TABLE = {
    module_1: {
        text: replay("Recorrer la entrada", "Reproduce la animación: observa que aquí sólo hay caracteres, sin tokens ni números todavía."),
        tokens: replay("Recorrer el corte", "Reproduce la animación e identifica dónde se corta el texto. Después puedes escribir otra frase y volver a analizar."),
        ids: replay("Recorrer la consulta", "Reproduce la animación y sigue un token hasta su fila. Comprueba que un token repetido señala la misma fila."),
        specials: replay("Recorrer el desplazamiento", "Reproduce la animación y compara la entrada del decoder con el objetivo: cada posición debe predecir el token siguiente."),
        batch: replay("Recorrer el ajuste de longitud", "Reproduce la animación. Al entrenar, identifica qué celdas son relleno; en inferencia, comprueba si la frase hubo que recortarla."),
        mask: replay("Recorrer la máscara", "Reproduce la animación y compara cada ID con su valor en la máscara. Si la frase no tiene PAD, toda la máscara queda permitida."),
        no_grad: replay("Recorrer la preparación", "Reproduce la animación y comprueba que ninguna de estas operaciones tiene parámetros que aprender.")
    },
    module_2: {
        lookup: token("Cambia el token observado y comprueba que se resalta otra fila, con el mismo número de componentes."),
        scale: replay("Recorrer el escalamiento", "Reproduce la animación y compara los valores antes y después: cambia su tamaño, no sus signos ni sus proporciones."),
        position: token("Cambia el token observado y compara su vector posicional: depende del lugar, no de qué token esté ahí."),
        sum: token("Cambia el token observado y comprueba que cada celda de la suma combina sólo las dos celdas de su mismo lugar."),
        dropout: { action: "rerun", label: "Repetir el cálculo",
                   instruction: "Repite el cálculo y compara. Al entrenar puede cambiar qué componentes quedan en cero; en inferencia, la salida es igual a la entrada." },
        embedding_gradient: token("Cambia el token observado y compara el gradiente de su fila."),
        embedding_update: RECORRER_AJUSTE
    },
    module_4: {
        project: replay("Recorrer la proyección", "Reproduce la animación: aquí aún no hay cabezas, sólo Q, K y V con todo su ancho."),
        split: head("Selecciona otra cabeza y comprueba qué bloque de componentes usa. Los tokens son los mismos."),
        maps: head("Selecciona otra cabeza y compara su mapa con el anterior: pueden fijarse en relaciones distintas."),
        contexts: head("Selecciona otra cabeza y compara su contexto: sale de su propio mapa y de sus propios Values."),
        concat: replay("Recorrer la concatenación", "Reproduce la animación: los bloques se colocan uno junto a otro y todavía no se mezclan."),
        wo: replay("Recorrer la mezcla", "Reproduce la animación y compara antes y después de WO: el ancho no cambia, pero cada salida combina varias cabezas."),
        backward: RECORRER_GRADIENTE,
        update: RECORRER_AJUSTE
    },
    module_5: {
        encoder_input: layer("Cambia de capa y compara: los valores cambian, pero la forma es la misma."),
        encoder_attention: head("Selecciona otra cabeza y comprueba que no hay sombra triangular: la frase completa está disponible."),
        residual_1: token("Observa otro token y compara su entrada con la suma: el atajo conserva lo que había."),
        norm_1: token("Observa otro token y comprueba que sus componentes quedan centradas, sin cambiar la forma."),
        ffn_expand: token("Observa otro token y comprueba que crecen las columnas, no las filas."),
        ffn_activation: token("Observa otro token y busca qué valores quedaron exactamente en cero."),
        ffn_project: replay("Recorrer la proyección", "Reproduce la animación: el ancho regresa a d_model para poder sumarse con la entrada de la subcapa."),
        norm_2: layer("Cambia de capa y comprueba que todas terminan con la misma forma."),
        stack: replay("Recorrer la pila", "Reproduce la animación y sigue la salida de cada capa como entrada de la siguiente."),
        backward: layer("Cambia de capa y compara qué tan fuerte llega el gradiente a cada una."),
        update: RECORRER_AJUSTE
    },
    module_6: {
        decoder_prefix: token("Cambia de posición y compara el token que recibe con el que debe predecir."),
        decoder_embedding: token("Cambia de posición y comprueba que cada una recibe su propia señal de lugar."),
        causal_mask: causal("Contrasta el cálculo con y sin bloqueo del futuro. Busca qué celdas dejan de participar."),
        masked_attention: causal("Contrasta el cálculo con y sin máscara. Sin ella se usarían tokens que al generar aún no existen."),
        decoder_residual_1: replay("Recorrer el primer Add & Norm", "Reproduce la animación y sigue el atajo alrededor de la atención causal."),
        cross_attention: head("Selecciona otra cabeza: las filas son del decoder y las columnas, de la fuente."),
        decoder_residual_2: replay("Recorrer el segundo Add & Norm", "Reproduce la animación: aquí se suma lo que se consultó de la fuente."),
        decoder_ffn: layer("Cambia de capa y compara los valores: cada posición se transforma por separado."),
        decoder_output: layer("Cambia de capa y comprueba que todas terminan con la misma forma."),
        decoder_layers: replay("Recorrer la pila", "Reproduce la animación: cada capa consulta la misma memoria."),
        backward: RECORRER_GRADIENTE,
        update: RECORRER_AJUSTE
    },
    module_7: {
        hidden: token("Observa otra posición y compara su estado con el anterior."),
        linear: token("Observa otra posición y comprueba que cambian los puntajes de todo el vocabulario."),
        temperature: { action: "temperature", label: "Cambiar la temperatura",
                       instruction: "Cambia T y compara si las probabilidades se concentran o se reparten. Comprueba que el orden no cambia." },
        top_k: { action: "top_k", label: "Reducir Top-K",
                 instruction: "Reduce K y observa cuántos candidatos sobreviven antes de normalizar." },
        top_p: { action: "top_p", label: "Cambiar Top-P",
                 instruction: "Cambia P y observa cómo el tamaño del núcleo depende de la masa acumulada." },
        softmax: { action: "temperature", label: "Cambiar la temperatura",
                   instruction: "Cambia T y comprueba que las barras siguen sumando 100 %." },
        select: { action: "temperature", label: "Cambiar la temperatura",
                  instruction: "Cambia T y comprueba si cambia el candidato elegido con argmax." },
        feedback: replay("Recorrer el ciclo", "Reproduce la animación y sigue el token elegido hasta la entrada del decoder."),
        target: token("Observa otra posición y compara qué token era el correcto en cada una."),
        loss: token("Observa otra posición: cuanto menor es la probabilidad del token correcto, mayor es la pérdida."),
        backward: RECORRER_GRADIENTE,
        update: RECORRER_AJUSTE
    },
    module_8: {
        full_tokens: replay("Recorrer el inicio", "Reproduce la animación: del texto se obtiene la lista de IDs."),
        full_batch: replay("Recorrer la preparación", "Reproduce la animación e identifica la entrada, el objetivo desplazado y las máscaras."),
        full_embedding: token("Observa otro token: su vector combina identidad y posición."),
        full_encoder: head("Selecciona otra cabeza: sólo es una parte de lo que produce la memoria."),
        full_decoder: causal("Contrasta el cálculo con y sin bloqueo del futuro, sin perder de vista la memoria."),
        full_logits: token("Observa otra posición y comprueba que cambian los puntajes de todo el vocabulario."),
        full_filters: { action: "filters", label: "Cambiar los filtros",
                        instruction: "Modifica temperatura, Top-K y Top-P juntos y compara el conjunto final de candidatos." },
        full_select: { action: "temperature", label: "Cambiar la temperatura",
                       instruction: "Cambia T y comprueba si cambia el candidato elegido con argmax." },
        full_feedback: replay("Recorrer el ciclo", "Reproduce la animación: el prefijo crece y la memoria se reutiliza."),
        full_loss: replay("Recorrer la pérdida", "Reproduce la animación y comprueba que PAD no cuenta."),
        full_backward: RECORRER_GRADIENTE,
        full_update: RECORRER_AJUSTE
    }
}

function descriptor(moduleId, stepId) {
    var table = TABLE[moduleId]
    return table ? (table[stepId] || null) : null
}
