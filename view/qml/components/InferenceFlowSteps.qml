pragma ComponentBehavior: Bound

import QtQuick
import "../styles" as Style

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
            "Sigue el vector h_final hacia W_vocab: al otro lado aparece una barra por candidato. Su altura es el logit real, todavía no una probabilidad.",
            "Esta proyección convierte un único vector de ancho d_model en |V| alternativas que pueden compararse.",
            "Después se excluyen los IDs reservados y, si están activos, se aplican temperatura, top-k o top-p.",
            "Un logit solo indica preferencia relativa: todavía puede ser negativo y no tiene que sumar uno.",
            4500, true),
        step(
            "output_softmax", "output", "Softmax + token", 6, 1, 9, "", false,
            "seleccion_token", "La distribución elige el siguiente token",
            "p = softmax(filtros(logits / T)); token \u223c p",
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
            requiresDetail: requiresDetail
        }
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
            visual = "Compara las tres tiras: Q representa lo que busca la posición actual; K y V pertenecen a la key destacada. Los colores son valores reales, recortados a las dimensiones visibles."
            purpose = cross
                ? "Separar los orígenes permite que la generación consulte la memoria codificada del prompt."
                : "Q expresa qué se busca, K con qué se compara y V qué información puede transferirse."
            next = "Q y K se multiplican para formar los scores escalados."
            caveat = "K y V son la key destacada, no todas las posiciones del tensor completo."
            concept = cross ? "origen_qkv_cross" : "query_key_value"
        } else if (phase === "scores") {
            shortLabel = cross ? "Scores cruzados" : (causal ? "Scores causales" : "Scores encoder")
            title = label + ": calcula compatibilidades"
            formula = "S = QK\u1d40 / \u221ad_head"
            operation = "Cada query se compara con las keys y el producto se escala por la raíz de d_head."
            visual = "Lee cada celda como una compatibilidad Q↔K. El color indica signo y magnitud del score real; todavía no representa una probabilidad."
            purpose = "El escalamiento evita valores extremos que saturarían Softmax."
            next = causal
                ? "La máscara causal bloquea el futuro antes de Softmax."
                : "Los scores válidos se normalizan mediante Softmax."
            caveat = "La ventana conserva las keys finales cuando la secuencia supera el límite visual."
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
            "Sigue el mismo color de abajo arriba: cada piso es el estado real del mismo token después de otra capa. La cercanía 2D es una aproximación de PCA.",
            "La profundidad refina progresivamente la representación antes de entregarla al siguiente módulo.",
            encoder
                ? "La salida final queda disponible como memoria K/V para la atención cruzada."
                : "El estado de la última posición de la última capa entra a Linear.",
            "Esta escena es una recapitulación: PCA no es una capa ni una operación del Transformer.",
            5300, true)
    }
}
