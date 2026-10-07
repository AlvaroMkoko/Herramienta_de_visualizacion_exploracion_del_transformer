.pragma library

// Catálogo visual del recorrido modular. Cada paso declara una transformación
// breve y un glifo pedagógico; ningún paso depende del diagrama genérico.
var stepVisuals = {
    "m1_s1": {
        title: "El recorrido comienza con texto, no con números",
        caption: "La cadena conserva caracteres y espacios; todavía no contiene tokens, IDs ni vectores.",
        before: "Caracteres", focus: "Texto plano", after: "Tokenizador", kind: "text"
    },
    "m1_s2": {
        title: "La oración se separa en piezas reutilizables",
        caption: "Los límites no siempre coinciden con palabras completas: una palabra rara puede dividirse en subpalabras.",
        before: "Texto", focus: "Separar piezas", after: "Tokens", kind: "tokens"
    },
    "m1_s3": {
        title: "Cada token consulta una entrada del vocabulario",
        caption: "La pieza funciona como clave de búsqueda; la fila encontrada aporta un identificador estable.",
        before: "Token", focus: "Buscar en |V|", after: "Fila", kind: "lookup"
    },
    "m1_s4": {
        title: "Los tokens se convierten en IDs ordenados",
        caption: "El valor del ID identifica una fila; su magnitud no expresa cercanía semántica.",
        before: "Tokens", focus: "Asignar IDs", after: "[51, 804, 219]", kind: "ids"
    },
    "m1_s5": {
        title: "Los tokens reservados delimitan la secuencia",
        caption: "BOS marca el inicio, EOS el final y PAD se reserva para igualar longitudes sin confundirse con contenido.",
        before: "IDs", focus: "Añadir BOS/EOS", after: "Secuencia", kind: "special"
    },
    "m1_s6": {
        title: "La posición de cada ID forma la secuencia",
        caption: "Los mismos IDs en otro orden representan otra entrada; la lista conserva esa estructura discreta.",
        before: "IDs sueltos", focus: "Conservar orden", after: "[T]", kind: "sequence"
    },
    "m1_s7": {
        title: "PAD convierte longitudes distintas en un batch",
        caption: "Sólo se agregan posiciones artificiales hasta alcanzar T_max; los tokens reales no cambian.",
        before: "T desigual", focus: "Agregar PAD", after: "[B, T_max]", kind: "padding"
    },
    "m1_s8": {
        title: "La máscara separa contenido real y relleno",
        caption: "Las posiciones PAD permanecen en el tensor rectangular, pero quedan marcadas para no aportar información.",
        before: "IDs + PAD", focus: "Marcar claves", after: "Máscara", kind: "padding_mask"
    },

    "m2_s1": {
        title: "Los IDs llegan como índices discretos",
        caption: "Cada posición contiene un entero válido del vocabulario; el significado continuo aparece en el siguiente paso.",
        before: "[B, T]", focus: "Validar IDs", after: "Índices", kind: "ids"
    },
    "m2_s2": {
        title: "La tabla guarda un vector por token",
        caption: "W_embed tiene una fila aprendida por entrada del vocabulario y d_model columnas por fila.",
        before: "|V| tokens", focus: "W_embed", after: "d_model", kind: "embedding_table"
    },
    "m2_s3": {
        title: "El ID selecciona una fila; no la multiplica",
        caption: "Para cada posición se recupera exactamente el vector situado en la fila indicada por su Token ID.",
        before: "ID 804", focus: "Elegir fila 804", after: "Vector", kind: "lookup_vector"
    },
    "m2_s4": {
        title: "El embedding se escala por √d_model",
        caption: "El factor ajusta su magnitud antes de sumarlo con la señal posicional y conserva la misma forma.",
        before: "Embedding", focus: "× √d_model", after: "Escalado", kind: "scale_vector"
    },
    "m2_s5": {
        title: "Cada token recibe un índice de posición",
        caption: "Los índices 0, 1, 2… permiten construir una señal diferente para cada lugar de la secuencia.",
        before: "Longitud T", focus: "0 · 1 · 2 · 3", after: "Posiciones", kind: "position_index"
    },
    "m2_s6": {
        title: "Cada posición produce un patrón vectorial",
        caption: "Las ondas seno y coseno generan vectores distinguibles sin cambiar la anchura d_model.",
        before: "Posición i", focus: "Seno + coseno", after: "Pᵢ", kind: "position_wave"
    },
    "m2_s7": {
        title: "Identidad y posición se suman coordenada a coordenada",
        caption: "Embedding y señal posicional tienen la misma forma, por lo que producen una sola representación X.",
        before: "E token", focus: "E + P", after: "X", kind: "vector_sum"
    },
    "m2_s8": {
        title: "La entrada continua queda lista para el Transformer",
        caption: "El resultado conserva batch, secuencia y d_model: un vector con identidad y posición por token.",
        before: "E + P", focus: "Organizar tensor", after: "[B,T,d_model]", kind: "representation"
    },

    "m3_s1": {
        title: "X aporta un vector por token",
        caption: "La atención recibe todas las representaciones de la secuencia en una matriz común.",
        before: "Tokens", focus: "Matriz X", after: "Proyecciones", kind: "attention_input"
    },
    "m3_s2": {
        title: "La misma X origina Query, Key y Value",
        caption: "Tres proyecciones aprendidas asignan a cada token los papeles de buscar, identificarse y entregar contenido.",
        before: "X", focus: "WQ · WK · WV", after: "Q · K · V", kind: "qkv"
    },
    "m3_s3": {
        title: "K se transpone para alinear el producto",
        caption: "Las dimensiones d_k quedan enfrentadas y las posiciones de las claves pasan a las columnas.",
        before: "K [T,d_k]", focus: "Transponer", after: "Kᵀ [d_k,T]", kind: "transpose"
    },
    "m3_s4": {
        title: "Cada Query se compara con todas las Keys",
        caption: "QKᵀ produce una matriz T×T: cada celda es un score entre una consulta y una clave.",
        before: "Q y Kᵀ", focus: "Producto matricial", after: "Scores", kind: "score_matrix"
    },
    "m3_s5": {
        title: "Los scores se dividen por √d_k",
        caption: "El escalamiento reduce magnitudes extremas antes de Softmax, sin alterar la forma de la matriz.",
        before: "Scores", focus: "÷ √d_k", after: "Scores estables", kind: "scale_scores"
    },
    "m3_s6": {
        title: "Softmax convierte cada fila en pesos",
        caption: "Los valores quedan entre 0 y 1 y cada Query reparte un total de 1 entre todas las Keys.",
        before: "Scores", focus: "Softmax por fila", after: "Pesos A", kind: "softmax_row"
    },
    "m3_s7": {
        title: "Cada peso regula cuánto aporta su Value",
        caption: "No se elige una sola clave: las contribuciones AᵢⱼVⱼ se suman para construir contexto.",
        before: "A y V", focus: "Ponderar + sumar", after: "Contexto", kind: "weighted_values"
    },
    "m3_s8": {
        title: "La salida queda contextualizada por token",
        caption: "Cada fila conserva su posición, pero ahora incorpora información seleccionada del resto de la secuencia.",
        before: "Q · K · V", focus: "Attention", after: "Z [T,d_v]", kind: "attention_output"
    },

    "m4_s1": {
        title: "Una proyección conjunta prepara Q, K y V",
        caption: "La operación parte de X y calcula todos los componentes antes de reorganizarlos por cabeza.",
        before: "X", focus: "Proyectar QKV", after: "Q · K · V", kind: "joint_qkv"
    },
    "m4_s2": {
        title: "d_model se reparte entre h cabezas",
        caption: "Cada cabeza recibe un subespacio de anchura d_head; juntas conservan la capacidad total.",
        before: "d_model", focus: "Dividir en h", after: "h × d_head", kind: "split_heads"
    },
    "m4_s3": {
        title: "Cada cabeza calcula sus propios scores",
        caption: "Las comparaciones QKᵀ ocurren en paralelo y no se mezclan todavía entre cabezas.",
        before: "Q/K por cabeza", focus: "h productos", after: "h scores", kind: "head_scores"
    },
    "m4_s4": {
        title: "Las cabezas pueden aprender mapas distintos",
        caption: "Una puede concentrarse en cercanía, otra en referencias y otra en relaciones sintácticas.",
        before: "Mismos tokens", focus: "Mapas diversos", after: "Relaciones", kind: "head_maps"
    },
    "m4_s5": {
        title: "Cada cabeza produce su propio contexto",
        caption: "Sus pesos mezclan Values dentro del subespacio correspondiente y generan una salida independiente.",
        before: "Pesos + V", focus: "Mezclar por cabeza", after: "h contextos", kind: "head_context"
    },
    "m4_s6": {
        title: "Las salidas se concatenan por características",
        caption: "Los segmentos de las h cabezas se colocan uno junto a otro para recuperar la anchura total.",
        before: "h contextos", focus: "Concatenar", after: "h·d_head", kind: "concat"
    },
    "m4_s7": {
        title: "Wᴼ mezcla la información de todas las cabezas",
        caption: "La proyección final combina los segmentos concatenados y devuelve una representación de ancho d_model.",
        before: "Concat", focus: "× Wᴼ", after: "d_model", kind: "output_projection"
    },
    "m4_s8": {
        title: "Multi-Head entrega una representación compatible",
        caption: "La salida reúne perspectivas distintas y mantiene la forma necesaria para la conexión residual.",
        before: "h cabezas", focus: "MHA", after: "[B,T,d_model]", kind: "multihead_output"
    },

    "m5_s1": {
        title: "Cada capa recibe un estado con forma estable",
        caption: "La interfaz [B,T,d_model] permite apilar bloques sin perder la correspondencia entre posiciones.",
        before: "X anterior", focus: "Entrada de capa", after: "Self-Attention", kind: "encoder_input"
    },
    "m5_s2": {
        title: "Self-Attention reúne información de toda la fuente",
        caption: "Cada token del encoder puede consultar todas las posiciones reales, sin una máscara causal.",
        before: "X", focus: "MHA completa", after: "Actualización", kind: "encoder_attention"
    },
    "m5_s3": {
        title: "La residual conserva un camino directo",
        caption: "La actualización de atención se suma a X; ninguna de las dos ramas sustituye por completo a la otra.",
        before: "X + MHA(X)", focus: "Suma residual", after: "Estado", kind: "residual"
    },
    "m5_s4": {
        title: "LayerNorm estabiliza las características de cada token",
        caption: "La normalización actúa sobre d_model y conserva batch, longitud y anchura.",
        before: "Estado", focus: "Normalizar", after: "Escala estable", kind: "layer_norm"
    },
    "m5_s5": {
        title: "La FFN expande cada posición a d_ff",
        caption: "La primera proyección y la activación no lineal aumentan la capacidad sin mezclar tokens entre sí.",
        before: "d_model", focus: "Expandir + activar", after: "d_ff", kind: "ffn_expand"
    },
    "m5_s6": {
        title: "La FFN vuelve de d_ff a d_model",
        caption: "La segunda proyección recupera la anchura requerida para sumar otra conexión residual.",
        before: "d_ff", focus: "Proyectar", after: "d_model", kind: "ffn_project"
    },
    "m5_s7": {
        title: "El segundo Add & Norm integra la FFN",
        caption: "La salida local se suma al estado anterior y se normaliza sin cambiar la forma del bloque.",
        before: "Estado + FFN", focus: "Add & Norm", after: "Salida capa", kind: "residual_norm"
    },
    "m5_s8": {
        title: "La pila produce la memoria del encoder",
        caption: "N capas refinan las mismas posiciones hasta obtener representaciones que el decoder consultará como Keys y Values.",
        before: "Capa 1", focus: "Apilar N capas", after: "H_enc", kind: "encoder_stack"
    },

    "m6_s1": {
        title: "El decoder recibe el objetivo desplazado",
        caption: "BOS ocupa la primera posición y cada token previo sirve para practicar la predicción del siguiente.",
        before: "Objetivo", focus: "Desplazar + BOS", after: "Prefijo", kind: "shifted_prefix"
    },
    "m6_s2": {
        title: "La máscara triangular bloquea el futuro",
        caption: "La diagonal y el pasado están permitidos; las columnas futuras quedan excluidas para cada Query.",
        before: "T_tgt", focus: "Triángulo causal", after: "Máscara", kind: "causal_mask"
    },
    "m6_s3": {
        title: "Masked Self-Attention sólo usa el prefijo",
        caption: "Cada posición construye contexto con tokens ya disponibles y nunca observa la respuesta futura.",
        before: "Prefijo", focus: "Atención causal", after: "Contexto", kind: "masked_attention"
    },
    "m6_s4": {
        title: "El primer Add & Norm conserva el estado causal",
        caption: "La actualización enmascarada se integra con su entrada mediante una ruta residual.",
        before: "X + MHA", focus: "Add & Norm", after: "Estado causal", kind: "residual_norm"
    },
    "m6_s5": {
        title: "El decoder consulta la memoria del encoder",
        caption: "Q se compara con todas las K de H_enc; sus pesos combinan las V para producir el contexto fuente.",
        before: "Q dec. + K/V enc.", focus: "Cross-Attention", after: "Contexto fuente", kind: "cross_attention"
    },
    "m6_s6": {
        title: "El segundo Add & Norm integra fuente y prefijo",
        caption: "La información recuperada del encoder se suma al estado causal y se normaliza.",
        before: "Causal + fuente", focus: "Add & Norm", after: "Estado integrado", kind: "residual_norm"
    },
    "m6_s7": {
        title: "La FFN procesa cada posición y cierra la capa",
        caption: "La transformación d_model→d_ff→d_model termina con la tercera conexión residual del decoder.",
        before: "Estado", focus: "FFN + Add&Norm", after: "Salida capa", kind: "decoder_ffn"
    },
    "m6_s8": {
        title: "La pila entrega un estado final por posición",
        caption: "Tras N bloques, cada posición destino queda lista para proyectarse sobre el vocabulario.",
        before: "N capas", focus: "Estado decoder", after: "h_final", kind: "decoder_stack"
    },

    "m7_s1": {
        title: "La última posición resume el prefijo actual",
        caption: "Para generar el siguiente token se toma el vector d_model correspondiente al extremo del decoder.",
        before: "[B,T,d_model]", focus: "Elegir posición T", after: "h_t", kind: "last_state"
    },
    "m7_s2": {
        title: "W_vocab produce un score por token posible",
        caption: "La capa Linear cambia d_model por |V|; los valores resultantes son logits y aún no son probabilidades.",
        before: "h_t", focus: "Linear W_vocab", after: "|V| logits", kind: "vocab_projection"
    },
    "m7_s3": {
        title: "La temperatura cambia la concentración",
        caption: "T baja amplía diferencias entre logits; T alta las reduce antes de calcular probabilidades.",
        before: "Logits", focus: "Dividir por T", after: "Ajustados", kind: "temperature"
    },
    "m7_s4": {
        title: "Top-K conserva una cantidad fija de candidatos",
        caption: "Sólo los K logits mayores continúan; el resto queda fuera antes del muestreo.",
        before: "|V| candidatos", focus: "Elegir K mayores", after: "K candidatos", kind: "top_k"
    },
    "m7_s5": {
        title: "Top-P conserva un núcleo de masa acumulada",
        caption: "Se ordenan las probabilidades y se toma el conjunto mínimo que alcanza el umbral p.",
        before: "Probabilidades", focus: "Acumular hasta p", after: "Núcleo", kind: "top_p"
    },
    "m7_s6": {
        title: "Softmax convierte logits en probabilidades",
        caption: "Los valores quedan no negativos y suman 1 sobre el conjunto de candidatos disponible.",
        before: "Logits", focus: "Softmax", after: "Distribución", kind: "final_softmax"
    },
    "m7_s7": {
        title: "Una regla selecciona el siguiente token",
        caption: "Argmax elige el mayor; el muestreo usa la distribución. El token elegido se vuelve parte del prefijo.",
        before: "Distribución", focus: "Elegir candidato", after: "Token", kind: "select_token"
    },
    "m7_s8": {
        title: "El token elegido realimenta la siguiente vuelta",
        caption: "El prefijo crece una posición y el ciclo se repite hasta EOS o el límite máximo.",
        before: "Prefijo", focus: "+ token y repetir", after: "EOS / límite", kind: "generation_loop"
    },

    "m8_s1": {
        title: "Fuente y destino se preparan con papeles distintos",
        caption: "La fuente alimenta al encoder; el prefijo desplazado alimenta al decoder durante el entrenamiento.",
        before: "Texto fuente/objetivo", focus: "Tokenizar + máscara", after: "src_ids / tgt_ids", kind: "source_target"
    },
    "m8_s2": {
        title: "Ambos lados reciben identidad y posición",
        caption: "Los IDs fuente y destino se convierten en vectores X_src y X_tgt de anchura d_model.",
        before: "IDs", focus: "Embedding + P", after: "X_src / X_tgt", kind: "dual_embeddings"
    },
    "m8_s3": {
        title: "El encoder construye memoria contextual",
        caption: "La fuente recorre N capas y produce H_enc, que permanece disponible durante la generación.",
        before: "X_src", focus: "Encoder × N", after: "H_enc", kind: "encoder_stack"
    },
    "m8_s4": {
        title: "El decoder primero protege la causalidad",
        caption: "Masked Self-Attention procesa el prefijo sin permitir conexiones hacia posiciones futuras.",
        before: "X_tgt", focus: "Atención causal", after: "Estado causal", kind: "masked_attention"
    },
    "m8_s5": {
        title: "Cross-Attention une destino y fuente",
        caption: "Q se compara con todas las K de H_enc; el contexto ΣαV resultante pasa después por la FFN.",
        before: "Estado + H_enc", focus: "Cross-Attn + FFN", after: "Salida decoder", kind: "cross_ffn"
    },
    "m8_s6": {
        title: "La salida interna se proyecta al vocabulario",
        caption: "Linear produce logits y Softmax los normaliza para obtener una distribución sobre tokens.",
        before: "h_final", focus: "Linear + Softmax", after: "p(token)", kind: "logits_probabilities"
    },
    "m8_s7": {
        title: "La distribución se materializa en un token",
        caption: "La estrategia de selección escoge un ID, lo decodifica y lo agrega al texto parcial.",
        before: "p(token)", focus: "Seleccionar", after: "Token + texto", kind: "select_token"
    },
    "m8_s8": {
        title: "El Transformer completo forma un ciclo coherente",
        caption: "Tokens, vectores, atención, memoria y probabilidades mantienen formas compatibles hasta completar la salida.",
        before: "Texto", focus: "Encoder ↔ Decoder", after: "Texto generado", kind: "full_transformer"
    }
}

function stepVisual(stepId) {
    return stepVisuals[String(stepId)] || null
}

