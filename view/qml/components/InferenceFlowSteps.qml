pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    readonly property var steps: [
        embeddingStep("encoder_embedding", 0),
        positionStep("encoder_position", 0),
        attentionStep("encoder_qkv", 0, "qkv"),
        attentionStep("encoder_scores", 0, "scores"),
        attentionStep("encoder_softmax", 0, "softmax"),
        attentionStep("encoder_weighted", 0, "weighted"),
        multiHeadStep("encoder_multihead", 0),
        residualStep("encoder_addnorm_attention", 0, false),
        ffnStep("encoder_ffn", 0),
        residualStep("encoder_addnorm_ffn", 0, true),
        layersStep("encoder_layers", 0),

        embeddingStep("decoder_embedding", 1),
        positionStep("decoder_position", 1),
        attentionStep("decoder_masked_qkv", 1, "qkv"),
        attentionStep("decoder_masked_scores", 1, "scores"),
        attentionStep("decoder_masked_mask", 1, "mask"),
        attentionStep("decoder_masked_softmax", 1, "softmax"),
        attentionStep("decoder_masked_weighted", 1, "weighted"),
        multiHeadStep("decoder_masked_multihead", 1),
        residualStep("decoder_addnorm_masked", 1, false),

        attentionStep("decoder_cross_qkv", 2, "qkv"),
        attentionStep("decoder_cross_scores", 2, "scores"),
        attentionStep("decoder_cross_softmax", 2, "softmax"),
        attentionStep("decoder_cross_weighted", 2, "weighted"),
        multiHeadStep("decoder_cross_multihead", 2),
        residualStep("decoder_addnorm_cross", 2, false),
        ffnStep("decoder_ffn", 1),
        residualStep("decoder_addnorm_ffn", 1, true),
        layersStep("decoder_layers", 1),

        step(
            "linear_logits", "output", "Linear \u2192 logits", 6, 1, 8, "", false,
            "capa_linear_salida", "El estado se proyecta al vocabulario",
            "logits = h_final W_vocab\u1d40 + b",
            "Linear toma el último estado del decoder y calcula un score crudo para cada token del vocabulario.",
            "Sigue h_final desde el decoder hacia W_vocab: cada barra nace en cero y su longitud representa un logit real, todavía no una probabilidad.",
            "Esta proyección convierte un único vector de ancho d_model en |V| alternativas que pueden compararse.",
            "Después se excluyen los IDs reservados y, si están activos, se aplican temperatura, top-k o top-p.",
            "Un logit solo indica preferencia relativa: todavía puede ser negativo y no tiene que sumar uno.",
            4500, true),
        step(
            "output_softmax", "output", "Softmax + token", 6, 1, 9, "", false,
            "seleccion_token", "La distribución elige el siguiente token",
            "p = softmax(filtros(logits / T)); token = argmax(p) o token \u223c p",
            "Softmax convierte los logits elegibles en probabilidades; el modo configurado decide cómo sale el token final.",
            "Compara la longitud de las barras y localiza la marca de token elegido. «Resto» reúne la probabilidad que no cabe en el top visible.",
            "La distribución permite elegir el máximo en modo greedy o muestrear cuando esa opción está activa.",
            "El token elegido se añade al contexto del decoder y comienza otra vuelta autoregresiva.",
            "Temperatura, top-k y top-p solo intervienen cuando están activos; son reglas de generación, no capas aprendidas.",
            5600, false)
    ]

    function step(id, section, shortLabel, stageIndex, branchIndex, visualIndex,
                  phase, residualUsesFfn, conceptId, title, formula, operation,
                  visualMeaning, purpose, nextStep, caveat, duration,
                  requiresDetail) {
        return {
            id: id,
            section: section,
            short: shortLabel,
            stageIndex: stageIndex,
            branchIndex: branchIndex,
            visualIndex: visualIndex,
            phase: phase,
            residualUsesFfn: residualUsesFfn,
            conceptId: conceptId,
            title: title,
            formula: formula,
            operation: operation,
            visualMeaning: visualMeaning,
            purpose: purpose,
            nextStep: nextStep,
            caveat: caveat,
            duration: duration,
            requiresDetail: requiresDetail,
            visualElements: visualElementsFor(id, branchIndex, phase, residualUsesFfn),
            symbolGlossary: symbolGlossaryFor(id, branchIndex, phase, residualUsesFfn),
            interactionHelp: interactionHelpFor(id, phase)
        }
    }

    function guideItem(term, explanation) {
        return { term: term, explanation: explanation }
    }

    function visualElementsFor(id, branch, phase, residualUsesFfn) {
        var cross = branch === 2
        if (id.indexOf("embedding") !== -1) {
            return [
                guideItem("Token e ID", "El texto es legible para ti; el ID es el entero que realmente entra al modelo."),
                guideItem("Consulta de W_embed", "El ID selecciona una fila aprendida de la tabla de embeddings; no se multiplica como una cantidad."),
                guideItem("Celdas d0, d1, …", "Son coordenadas del vector del token. El color resume signo y magnitud, no una palabra o concepto aislado."),
                guideItem("Forma tokens × d_model", "Indica cuántos tokens hay y cuántas coordenadas tiene cada representación."),
                guideItem("Norma y métricas", "‖E‖₂ resume el tamaño del vector; mínimo, máximo y media ayudan a comprobar su escala.")
            ]
        }
        if (id.indexOf("position") !== -1) {
            return [
                guideItem("Círculo tenue", "Ubicación 2D aproximada del embedding antes de añadir posición."),
                guideItem("Cuadrado", "Destino aproximado del mismo token después de sumar su señal posicional."),
                guideItem("Flecha discontinua", "Desplazamiento producido por PE; une al mismo token antes y después de la suma."),
                guideItem("Punto sólido", "Estado interpolado por la animación; al 100 % coincide con E + PE."),
                guideItem("PC1, PC2 y color", "PC1/PC2 son ejes de PCA usados solo para dibujar; el color conserva la identidad de la posición.")
            ]
        }
        if (phase === "qkv") {
            return [
                guideItem("Tarjeta Q", cross
                          ? "Consulta de la última posición del decoder: expresa qué necesita encontrar en el prompt."
                          : "Consulta de la última posición: expresa qué información busca."),
                guideItem("Tarjeta K", cross
                          ? "Clave destacada de la memoria del encoder: es el vector con el que se compara Q."
                          : "Clave destacada de la secuencia: es el vector con el que se compara Q."),
                guideItem("Tarjeta V", "Contenido asociado a esa misma clave; esto es lo que puede transferirse si recibe peso."),
                guideItem("Filas H01, H02, …", "Cada fila es una cabeza de atención con sus propias proyecciones aprendidas."),
                guideItem("Color y número de celda", "Muestran el valor firmado de una coordenada real; no son probabilidades.")
            ]
        }
        if (phase === "scores") {
            return [
                guideItem("Fila H", "Compatibilidades calculadas por una cabeza para la última query."),
                guideItem("Columna K", "Posición fuente que la query está evaluando; su índice es absoluto aunque se muestre una ventana."),
                guideItem("Celda de score", "Producto Q·K escalado. Positivo favorece la compatibilidad y negativo la reduce, pero aún no es probabilidad."),
                guideItem("Escala de color", "Compara signo y magnitud dentro de la matriz; el número de la celda es el dato preciso."),
                guideItem("Forma original / valores mostrados", "Aclara cuándo ves una muestra de una matriz mayor y evita confundir recorte con cálculo.")
            ]
        }
        if (phase === "mask") {
            return [
                guideItem("Scores antes", "Compatibilidades originales; todavía incluyen posiciones futuras."),
                guideItem("Máscara triangular", "1 permite mirar esa posición y 0 la bloquea. La diagonal está permitida."),
                guideItem("Scores enmascarados", "Copia usada por Softmax: cada posición prohibida se sustituye por −∞."),
                guideItem("Triángulo bloqueado", "Representa j > i: una posición del futuro respecto de la query actual."),
                guideItem("Tres tarjetas consecutivas", "Permiten comprobar que la máscara cambia la competencia, no los vectores Q, K o V.")
            ]
        }
        if (phase === "softmax" && id !== "output_softmax") {
            return [
                guideItem("Nodo query", "Token que está consultando; desde él salen las conexiones."),
                guideItem("Nodo key", cross ? "Token del prompt que puede aportar contexto." : "Token accesible con el que se compara la query."),
                guideItem("Curva query → key", "Su grosor y opacidad representan el peso Aᵢⱼ calculado por Softmax."),
                guideItem("Umbral", "Solo oculta curvas pequeñas para despejar el dibujo; no modifica los pesos ni el modelo."),
                guideItem("Linterna y comparación de heads", "La linterna aísla una query; la cuadrícula permite comparar patrones de distintas cabezas.")
            ]
        }
        if (phase === "weighted") {
            return [
                guideItem("Pesos A", "Distribución 0–1 que decide cuánto participa cada Value para la última query."),
                guideItem("Contribuciones ‖AᵢⱼVⱼ‖", "Tamaño de cada Value después de escalarlo por su peso; no es el vector completo."),
                guideItem("Contexto Z", "Suma vectorial de todas las contribuciones de una cabeza."),
                guideItem("Filas H", "Cada cabeza realiza su propia mezcla y produce un contexto distinto."),
                guideItem("Secuencia 1 → 2 → 3", "Se muestra peso, efecto sobre V y resultado para no confundir atención con selección de una sola key.")
            ]
        }
        if (id.indexOf("multihead") !== -1) {
            return [
                guideItem("Proyección d_model", "Ancho total ya proyectado que se reorganiza en cabezas; no es un corte directo del embedding crudo."),
                guideItem("Franjas H01, H02, …", "Particiones de ancho d_head; los colores mantienen su identidad durante split y concat."),
                guideItem("‖z‖ por cabeza", "Tamaño de la salida real de esa cabeza para la query actual."),
                guideItem("Concat", "Coloca las salidas una junto a otra y recupera d_model; todavía no mezcla sus coordenadas."),
                guideItem("Malla Wᴼ", "Proyección aprendida que sí combina información entre cabezas y produce la actualización MHA.")
            ]
        }
        if (id.indexOf("addnorm") !== -1) {
            return [
                guideItem("Ruta identidad x", "Atajo que conserva la entrada de la subcapa sin transformarla."),
                guideItem("Ruta de subcapa Δx", residualUsesFfn
                          ? "Cambio calculado por la FFN para la misma representación."
                          : "Cambio calculado por la atención para la misma representación."),
                guideItem("Nodo +", "Suma x y Δx coordenada a coordenada; no concatena ni promedia."),
                guideItem("Caja LayerNorm", "Normaliza cada token a través de sus d_model coordenadas después de la suma: por eso es post-norm."),
                guideItem("Cuatro tarjetas", "Muestran la distribución tras sumar, centrar, estandarizar y aplicar la transformación aprendida."),
                guideItem("Puntos y eje cero", "Cada punto es una coordenada del vector; todas las tarjetas comparten escala para poder comparar el cambio."),
                guideItem("μ y σ bajo cada tarjeta", "Son la media y la desviación del vector en esa fase; permiten comprobar el centrado y la estandarización."),
                guideItem("γ media, β media y ε", "γ y β tienen un valor aprendido por coordenada; la cabecera resume sus medias. ε es una constante fija de estabilidad.")
            ]
        }
        if (id.indexOf("ffn") !== -1) {
            return [
                guideItem("Una fila por token", "Cada token se procesa por separado; la FFN no mezcla posiciones."),
                guideItem("Tira x", "Vector contextualizado de entrada con ancho d_model."),
                guideItem("Expansión W₁x+b₁", "Proyección a d_ff, normalmente más ancho, que crea espacio para transformar rasgos."),
                guideItem("Puerta de activación", "ReLU pone negativos en cero; GELU los atenúa suavemente. La escena usa la opción configurada."),
                guideItem("Compresión W₂φ+b₂", "Regresa a d_model para que la conexión residual pueda sumar vectores del mismo tamaño."),
                guideItem("Pesos compartidos", "Todos los tokens usan W₁, b₁, W₂ y b₂ iguales, aunque sus resultados sean distintos."),
                guideItem("Franjas y ‖·‖", "Las franjas son coordenadas visibles del vector; ‖·‖ resume su tamaño completo en esa etapa.")
            ]
        }
        if (id.indexOf("layers") !== -1) {
            return [
                guideItem("Piso X₀", "Representación que entra a la pila antes del primer bloque."),
                guideItem("Pisos de capa", "Estado real de todos los tokens después de cada bloque Transformer."),
                guideItem("Mismo color", "Identifica al mismo token a lo largo de la profundidad; no significa magnitud."),
                guideItem("Halo", "Destaca el token elegido para seguir su trayectoria entre pisos."),
                guideItem("PCA conjunto", "Todos los pisos comparten ejes 2D para comparar movimiento; PCA es una vista, no una capa."),
                guideItem("Varianza conservada", "Porcentaje de información geométrica aproximada que retienen los dos ejes dibujados.")
            ]
        }
        if (id === "linear_logits") {
            return [
                guideItem("h_final", "Estado de la última posición del decoder; resume el contexto disponible para esta predicción."),
                guideItem("W_vocab + b", "Capa aprendida que produce un score por cada ID del vocabulario."),
                guideItem("Histograma", "Resume todos los logits por intervalos; no es una distribución de probabilidades."),
                guideItem("Mín., máx., media y desv.", "Describen rango, centro y dispersión de los scores para comprobar su escala."),
                guideItem("Candidatos visibles", "Tokens capturados para inspección; en esta escena solo se representa su logit crudo."),
                guideItem("Logit numérico", "Es la preferencia cruda de Linear: puede ser negativa y no tiene que sumar uno."),
                guideItem("Barra de logit", "Nace en el cero central: va a la izquierda si el logit es negativo y a la derecha si es positivo.")
            ]
        }
        return [
            guideItem("Contexto", "Iteración autoregresiva seleccionada; cada contexto incluye un token más que el anterior."),
            guideItem("Barra de probabilidad", "Valor real posterior a temperatura, filtros y Softmax para ese candidato."),
            guideItem("Rango", "Posición del candidato al ordenar el top capturado de mayor a menor probabilidad."),
            guideItem("Token elegido", "Resultado que se añade al contexto; puede ser el máximo o una muestra según el modo."),
            guideItem("Masa fuera del top", "Probabilidad conjunta de los candidatos no listados; completa la suma hasta uno."),
            guideItem("Filtros", "Indican las reglas activas de generación; no son capas aprendidas del Transformer.")
        ]
    }

    function symbolGlossaryFor(id, branch, phase, residualUsesFfn) {
        var cross = branch === 2
        if (id.indexOf("embedding") !== -1)
            return [guideItem("token_id", "entero asignado por el tokenizer"),
                    guideItem("W_embed[token_id]", "fila aprendida elegida por ese ID"),
                    guideItem("E", "vector de embedding escalado"),
                    guideItem("d_model", "número de coordenadas de cada representación"),
                    guideItem("√d_model", "factor que ajusta la escala del embedding"),
                    guideItem("‖E‖₂", "longitud euclidiana del vector")]
        if (id.indexOf("position") !== -1)
            return [guideItem("E", "embedding que aporta identidad del token"),
                    guideItem("PE", "vector que codifica su posición"),
                    guideItem("X₀ / X_tgt", "resultado E + PE que entra al bloque"),
                    guideItem("p", "índice de posición del token"),
                    guideItem("PC1, PC2", "componentes principales usadas solo para visualizar")]
        if (phase === "qkv")
            return [guideItem("Q", "Query: lo que busca la posición actual"),
                    guideItem("K", "Key: descripción usada para comparar posiciones"),
                    guideItem("V", "Value: contenido que puede transferirse"),
                    guideItem("Wᑫ, Wᵏ, Wᵛ", "matrices aprendidas que generan Q, K y V"),
                    guideItem("H01…Hh", "índices de las cabezas de atención"),
                    guideItem("d_head", "coordenadas que procesa cada cabeza"),
                    guideItem("X / Y_dec / H_enc", cross
                              ? "orígenes: estado del decoder y memoria del encoder"
                              : "representación de entrada de la subcapa")]
        if (phase === "scores")
            return [guideItem("Sᵢⱼ", "score entre query i y key j"),
                    guideItem("QKᵀ", "todos los productos query–key"),
                    guideItem("ᵀ", "transposición de K para alinear el producto"),
                    guideItem("i", "posición que consulta"),
                    guideItem("j", "posición consultada"),
                    guideItem("√d_head", "escala que evita scores excesivos")]
        if (phase === "mask")
            return [guideItem("i", "posición de la query"),
                    guideItem("j", "posición de la key"),
                    guideItem("j ≤ i", "pasado y posición actual permitidos"),
                    guideItem("j > i", "futuro bloqueado"),
                    guideItem("−∞", "valor que Softmax transforma en peso cero"),
                    guideItem("S'", "scores después de aplicar la máscara")]
        if (phase === "softmax" && id !== "output_softmax")
            return [guideItem("Aᵢⱼ", "peso desde la query i hacia la key j"),
                    guideItem("Softmax", "normalización exponencial por fila"),
                    guideItem("Σⱼ Aᵢⱼ = 1", "todos los pesos accesibles de una query suman uno"),
                    guideItem("0 ≤ Aᵢⱼ ≤ 1", "rango de cada peso"),
                    guideItem("H", "cabeza cuyo patrón se visualiza")]
        if (phase === "weighted")
            return [guideItem("Aᵢⱼ", "peso asignado al Value j para la query i"),
                    guideItem("Vⱼ", "contenido de la posición j"),
                    guideItem("AᵢⱼVⱼ", "contribución vectorial ponderada"),
                    guideItem("Zᵢ", "contexto resultante para la query i"),
                    guideItem("Σⱼ", "suma sobre todas las keys accesibles"),
                    guideItem("‖·‖₂", "tamaño de una contribución, no su dirección")]
        if (id.indexOf("multihead") !== -1)
            return [guideItem("h", "número total de cabezas"),
                    guideItem("d_head", "ancho de una cabeza: d_model / h"),
                    guideItem("Z₁…Zₕ", "salidas de contexto de las cabezas"),
                    guideItem("Concat", "unión por la dimensión de características"),
                    guideItem("Wᴼ", "proyección de salida aprendida"),
                    guideItem("MHA", "resultado final de la atención multi-head")]
        if (id.indexOf("addnorm") !== -1)
            return [guideItem("x", "entrada original de la subcapa"),
                    guideItem("Δx", "actualización producida por atención o FFN"),
                    guideItem("μ", "media de las coordenadas de x + Δx"),
                    guideItem("σ", "desviación estándar de esas coordenadas"),
                    guideItem("ε", "constante pequeña que evita dividir entre cero"),
                    guideItem("x̂", "vector centrado y estandarizado"),
                    guideItem("γ", "escala aprendida por coordenada"),
                    guideItem("β", "desplazamiento aprendido por coordenada"),
                    guideItem("‖x‖₂ / ‖Δx‖₂", "tamaños de entrada y actualización"),
                    guideItem("ratio", "‖Δx‖₂ dividido entre ‖x‖₂")]
        if (id.indexOf("ffn") !== -1)
            return [guideItem("x", "vector de un token"),
                    guideItem("W₁, b₁", "proyección y sesgo de expansión"),
                    guideItem("d_ff", "ancho interno de la FFN"),
                    guideItem("φ", "activación ReLU o GELU configurada"),
                    guideItem("W₂, b₂", "proyección y sesgo de compresión"),
                    guideItem("d_model", "ancho de entrada y salida")]
        if (id.indexOf("layers") !== -1)
            return [guideItem("X₀", "estado antes de la primera capa"),
                    guideItem("bloqueₗ", "capa Transformer número l"),
                    guideItem("L", "cantidad total de capas"),
                    guideItem("hidden state", "representación contextual de un token"),
                    guideItem("PCA", "proyección visual a dos dimensiones")]
        if (id === "linear_logits")
            return [guideItem("h_final", "último estado del decoder"),
                    guideItem("W_vocab", "matriz que puntúa cada token del vocabulario"),
                    guideItem("b", "sesgo aprendido de cada token"),
                    guideItem("|V|", "tamaño del vocabulario"),
                    guideItem("logit", "score crudo previo a Softmax"),
                    guideItem("desv.", "desviación estándar de los logits")]
        return [guideItem("T", "temperatura; reescala logits antes de Softmax"),
                guideItem("top-k", "conserva solo los k candidatos con mayor logit"),
                guideItem("top-p", "conserva el conjunto mínimo cuya probabilidad acumulada alcanza p"),
                guideItem("p(token|contexto)", "probabilidad condicional del siguiente token"),
                guideItem("Σp = 1", "la masa total de probabilidad"),
                guideItem("∼ p", "muestreo aleatorio según la distribución")]
    }

    function interactionHelpFor(id, phase) {
        if (id.indexOf("embedding") !== -1)
            return "Pulsa Reproducir para repetir el lookup y selecciona una fila de token para inspeccionar su vector y sus métricas."
        if (id.indexOf("position") !== -1)
            return "Arrastra el porcentaje de PE, alterna las dos nubes y pasa el cursor por un punto para identificar el token."
        if (phase === "softmax" && id !== "output_softmax")
            return "Ajusta el umbral solo para despejar curvas; pasa el cursor por una query para usar la linterna o abre Comparar heads."
        if (phase === "qkv" || phase === "scores" || phase === "mask" || phase === "weighted")
            return "Pulsa Reproducir para revelar las tarjetas en orden. Los selectores superiores cambian capa y cabeza sin alterar el significado de la escena."
        if (id.indexOf("multihead") !== -1)
            return "Pulsa Reproducir y sigue un mismo color desde la partición, pasando por su cabeza, hasta Concat y Wᴼ."
        if (id.indexOf("addnorm") !== -1)
            return "Activa o desactiva el atajo para comparar y selecciona cualquiera de las cuatro tarjetas para leer qué hace esa fase."
        if (id.indexOf("ffn") !== -1)
            return "Pulsa Respirar para repetir la expansión y compara filas: cambian los datos, pero los parámetros son compartidos."
        if (id.indexOf("layers") !== -1)
            return "Elige un token por su color y desplázate verticalmente para seguir su halo desde X₀ hasta la capa final."
        if (id === "linear_logits")
            return "Pulsa Reproducir para seguir h_final → Linear → logits y compara el histograma con el top capturado."
        return "Usa ◀, ▶ o Carrera para cambiar de contexto; observa cómo el nuevo token modifica las probabilidades de la siguiente vuelta."
    }

    function sectionForBranch(branch) {
        return branch === 0 ? "encoder" : "decoder"
    }

    function branchLabel(branch) {
        if (branch === 0)
            return "Encoder"
        if (branch === 1)
            return "Decoder causal"
        return "Atención cruzada"
    }

    function embeddingStep(id, branch) {
        var encoder = branch === 0
        return step(
            id, sectionForBranch(branch), encoder ? "Embedding entrada" : "Embedding salida",
            0, branch, 0, "", false, encoder ? "embeddings" : "entrada_decoder",
            encoder ? "Los IDs se convierten en vectores" : "El decoder representa su contexto",
            "E = W_embed[token_ids] \u00b7 \u221ad_model",
            encoder
                ? "Cada token_id del prompt selecciona una fila aprendida de W_embed y la escala por \u221ad_model."
                : "El token de inicio y los tokens ya generados seleccionan filas de la tabla de embeddings del decoder.",
            "Lee la escena de izquierda a derecha: ID discreto → fila de W_embed → vector escalado. Las franjas son componentes reales y la barra resume la norma L2.",
            encoder
                ? "La atención necesita representaciones continuas y no puede operar directamente sobre IDs discretos."
                : "El decoder debe representar numéricamente el prefijo disponible en esta iteración.",
            encoder
                ? "E se suma con la codificación posicional del encoder."
                : "E se suma con la codificación posicional del decoder.",
            "Una coordenada aislada no posee un significado semántico estable; el significado reside en el vector completo.",
            4200, true)
    }

    function positionStep(id, branch) {
        var encoder = branch === 0
        return step(
            id, sectionForBranch(branch), encoder ? "Posición encoder" : "Posición decoder",
            0, branch, 1, "", false, "combinacion_embedding_pe",
            encoder ? "El encoder incorpora el orden" : "El decoder incorpora el orden conocido",
            encoder ? "X\u2080 = E + PE" : "X_tgt = E_tgt + PE_tgt",
            "Una señal sinusoidal distinta se suma, componente a componente, en cada posición.",
            "Sigue cada punto desde E hasta E + PE: ese desplazamiento es el efecto del orden. PCA solo permite dibujarlo en 2D y no forma parte del Transformer.",
            "Sin información posicional, self-attention no distingue permutaciones de los mismos tokens.",
            encoder
                ? "X\u2080 alimenta Q, K y V de la primera capa del encoder."
                : "X_tgt alimenta Q, K y V de la autoatención causal.",
            "Las distancias 2D son aproximadas; la suma real ocurre en d_model dimensiones.",
            4300, true)
    }

    function attentionStep(id, branch, phase) {
        var label = branchLabel(branch)
        var section = sectionForBranch(branch)
        var cross = branch === 2
        var causal = branch === 1
        var title = ""
        var shortLabel = ""
        var formula = ""
        var operation = ""
        var visual = ""
        var purpose = ""
        var next = ""
        var caveat = ""
        var concept = "formula_attention_completa"
        var visualIndex = 2

        if (phase === "qkv") {
            shortLabel = cross ? "Q dec / K,V enc" : "Q / K / V"
            title = label + ": genera Query, Key y Value"
            formula = cross
                ? "Q=Y_decW\u1d3a; K=H_encW\u1d4f; V=H_encW\u1d5b"
                : "Q=XW\u1d3a; K=XW\u1d4f; V=XW\u1d5b"
            operation = cross
                ? "Q procede del decoder, mientras K y V se proyectan desde la salida final del encoder."
                : "La misma representación se proyecta con tres matrices aprendidas y se divide por cabezas."
            visual = "La escena amplía una muestra: Q es la última query y K/V pertenecen a una key destacada. El cálculo real proyecta todas las posiciones; los colores son coordenadas reales visibles."
            purpose = cross
                ? "Separar los orígenes permite que la generación consulte la memoria codificada del prompt."
                : "Q expresa qué se busca, K con qué se compara y V qué información puede transferirse."
            next = "Q y K se multiplican para formar los scores escalados."
            caveat = "Es una ampliación, no una restricción del modelo: se calculan todas las queries, keys y values; aquí se muestra una query y una key."
            concept = cross ? "origen_qkv_cross" : "query_key_value"
        } else if (phase === "scores") {
            shortLabel = cross ? "Scores cruzados" : (causal ? "Scores causales" : "Scores encoder")
            title = label + ": calcula compatibilidades"
            formula = "S = QK\u1d40 / \u221ad_head"
            operation = "Cada query se compara con las keys y el producto se escala por la raíz de d_head."
            visual = "La escena amplía la fila de la última query: cada celda es su compatibilidad con una key. El color indica signo y magnitud; todavía no es probabilidad."
            purpose = "El escalamiento evita valores extremos que saturarían Softmax."
            next = causal
                ? "La máscara causal bloquea el futuro antes de Softmax."
                : "Los scores válidos se normalizan mediante Softmax."
            caveat = "El modelo calcula una fila por cada query. La escena amplía la última y conserva las keys finales cuando la secuencia supera el límite visual."
            concept = "producto_qk"
        } else if (phase === "mask") {
            shortLabel = "Máscara causal"
            title = "El futuro queda bloqueado"
            formula = "S'\u1d62\u2c7c = S\u1d62\u2c7c si j\u2264i; -\u221e si j>i"
            operation = "La máscara triangular sustituye por -\u221e los scores que apuntan a posiciones futuras."
            visual = "Compara antes y después: las celdas tramadas son conexiones hacia el futuro y dejan de competir al recibir -\u221e."
            purpose = "Impide que el decoder use el token que intenta predecir y conserva la generación autoregresiva."
            next = "Softmax asigna peso cero a lo bloqueado y normaliza solo las posiciones permitidas."
            caveat = "Bloqueado no significa que el score original fuera cero; se fuerza a -\u221e antes de normalizar."
            concept = "por_que_mascara"
        } else if (phase === "softmax") {
            shortLabel = cross ? "Softmax cruzado" : (causal ? "Softmax causal" : "Softmax atención")
            title = label + ": normaliza los scores"
            formula = "A = softmax(S + máscara)"
            operation = "Softmax transforma cada fila permitida en pesos no negativos cuya suma es uno."
            visual = cross
                ? "Sigue una query del decoder hacia las keys del prompt: una curva más gruesa y opaca significa mayor peso real."
                : "Sigue una query hacia las keys accesibles: una curva más gruesa y opaca significa mayor peso real de atención."
            purpose = "Los coeficientes comparables permiten decidir cuánto usar de cada Value."
            next = "Cada A\u1d62\u2c7c pondera V\u2c7c y las contribuciones se suman."
            caveat = "El umbral solo oculta curvas para evitar saturación visual; no modifica el cálculo."
            concept = "softmax_attention"
            visualIndex = 3
        } else {
            shortLabel = cross ? "A cruzada \u00b7 V" : (causal ? "A causal \u00b7 V" : "A \u00b7 V")
            title = label + ": combina los Values"
            formula = "Z\u1d62 = \u03a3\u2c7c A\u1d62\u2c7cV\u2c7c"
            operation = "Cada Value se pondera con A y las contribuciones se suman para formar el contexto de la query."
            visual = "Recorre una fila: primero ves el peso A, después la magnitud de A·V y finalmente la suma Z. No se elige una sola key; se mezclan todas."
            purpose = cross
                ? "El resultado incorpora al decoder la información del prompt relevante para esta predicción."
                : "El resultado incorpora información de las posiciones accesibles al estado actual."
            next = "Las salidas de las cabezas se concatenan y atraviesan W\u1d3c."
            caveat = "Se muestran normas de contribución, no el vector completo ni una atribución causal."
            concept = "producto_por_v"
        }

        return step(id, section, shortLabel, 1, branch, visualIndex, phase, false,
                    concept, title, formula, operation, visual, purpose, next,
                    caveat, phase === "softmax" ? 4700 : 4100, true)
    }

    function multiHeadStep(id, branch) {
        var label = branchLabel(branch)
        return step(
            id, sectionForBranch(branch), "Concat + W\u1d3c", 2, branch, 4, "", false,
            "problema_multi_head", label + ": las cabezas vuelven a reunirse",
            "MHA = Concat(Z\u2081,...,Z\u2095)W\u1d3c",
            "Las h salidas paralelas se concatenan y una proyección aprendida las mezcla de nuevo en d_model.",
            "Sigue los colores: cada franja es una cabeza de ancho d_head; Concat las alinea y la malla Wᴼ mezcla sus componentes para producir una sola salida.",
            "Varias cabezas permiten modelar relaciones distintas sin aumentar el ancho final del bloque.",
            "La actualización MHA entra a su conexión residual y LayerNorm.",
            "Las cabezas se calculan en paralelo; el orden animado solo ayuda a seguir el recorrido.",
            5200, true)
    }

    function residualStep(id, branch, usesFfn) {
        var label = branchLabel(branch)
        var cross = branch === 2
        var inputName = usesFfn ? "U" : (cross ? "Y" : "X")
        var updateName = usesFfn ? "FFN(" + inputName + ")" : "MHA(" + inputName + ")"
        return step(
            id, sectionForBranch(branch), usesFfn ? "Add + Norm FFN" : "Add + Norm",
            4, branch, 6, "", usesFfn, "flujo_add_norm",
            label + (usesFfn ? ": cierra la capa" : ": conserva y estabiliza"),
            "salida = LayerNorm(" + inputName + " + Dropout(" + updateName + "))",
            "La actualización se suma a la entrada de la subcapa y después se normaliza; este modelo usa post-norm.",
            "Sigue las dos rutas: el atajo conserva la entrada y la rama principal aporta el cambio. Ambas se suman antes de las cuatro fases de LayerNorm.",
            "La ruta residual protege información previa y LayerNorm controla la escala del siguiente estado.",
            usesFfn
                ? (branch === 0 ? "El resultado alimenta la siguiente capa o la memoria final del encoder." : "El resultado alimenta la siguiente capa o Linear en la última.")
                : (branch === 0 ? "El estado entra a la FFN del encoder." : (cross ? "El estado entra a la FFN del decoder." : "El estado se convierte en Query de la atención cruzada.")),
            "La suma residual no concatena vectores; las métricas corresponden al último token capturado.",
            4800, true)
    }

    function ffnStep(id, branch) {
        var encoder = branch === 0
        return step(
            id, sectionForBranch(branch), encoder ? "FFN encoder" : "FFN decoder",
            3, branch, 5, "", false, "que_es_ffn",
            (encoder ? "Encoder" : "Decoder") + ": cada posición pasa por la misma FFN",
            "FFN(x)=W\u2082\u03c6(W\u2081x+b\u2081)+b\u2082",
            "La red expande cada token de d_model a d_ff, aplica la activación configurada y comprime de vuelta.",
            "Lee cada fila de izquierda a derecha: entrada → preactivación → activación → salida. Las filas comparten pesos, pero cada token produce valores distintos.",
            "La atención mezcla posiciones; la FFN transforma de manera independiente la representación de cada una.",
            "La salida FFN entra a la segunda conexión residual del encoder o a la tercera del decoder.",
            "ReLU y GELU no tratan igual los negativos; la escena usa la activación configurada.",
            5100, true)
    }

    function layersStep(id, branch) {
        var encoder = branch === 0
        return step(
            id, sectionForBranch(branch), encoder ? "Capas encoder" : "Capas decoder",
            5, branch, 7, "", false,
            encoder ? "contextualizacion" : "estructura_decoder",
            (encoder ? "El encoder" : "El decoder") + " recorre todas sus capas",
            "X\u2080 \u2192 bloque\u2081 \u2192 ... \u2192 bloque_L",
            encoder
                ? "El bloque de atención, residual, FFN y residual se repite L veces con parámetros distintos."
                : "Cada capa repite atención causal, atención cruzada y FFN con sus tres Add & Norm.",
            "Empieza en X₀ y avanza hacia la capa final: cada piso muestra el estado real del mismo token después de otro bloque. La cercanía 2D es una aproximación de PCA.",
            "La profundidad refina progresivamente la representación antes de entregarla al siguiente módulo.",
            encoder
                ? "La salida final queda disponible como memoria K/V para la atención cruzada."
                : "El estado de la última posición de la última capa entra a Linear.",
            "Esta escena es una recapitulación: PCA no es una capa ni una operación del Transformer.",
            5300, true)
    }
}
