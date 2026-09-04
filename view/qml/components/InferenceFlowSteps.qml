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
            "La capa Linear asigna un score crudo a cada token del vocabulario.",
            "La escena conecta el ultimo estado real del decoder con el histograma completo y los candidatos del mismo forward. Los logits se capturan antes de excluir IDs reservados.",
            "Esta proyeccion cambia el ancho d_model por |V| alternativas comparables.",
            "Luego se excluyen IDs reservados y, si estan activos, se aplican temperatura, top-k o top-p.",
            "Un logit no es una probabilidad; se interpreta en relacion con los demas candidatos.",
            4500, true),
        step(
            "output_softmax", "output", "Softmax + token", 6, 1, 9, "", false,
            "seleccion_token", "La distribucion elige el siguiente token",
            "p = softmax(filtros(logits / T)); token \u223c p",
            "Softmax convierte los logits elegibles en probabilidades y el modo configurado selecciona un token.",
            "Las barras usan probabilidades reales del top capturado; 'resto' completa la masa y el token elegido conserva su rango.",
            "La distribucion permite elegir por argmax en greedy o muestrear cuando esa opcion esta activa.",
            "El token elegido se anade al contexto del decoder y comienza otra vuelta autoregresiva.",
            "Temperatura, top-k y top-p solo intervienen cuando estan activos y no son capas aprendidas.",
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
        return "Atencion cruzada"
    }

    function embeddingStep(id, branch) {
        var encoder = branch === 0
        return step(
            id, sectionForBranch(branch), encoder ? "Embedding entrada" : "Embedding salida",
            0, branch, 0, "", false, encoder ? "embeddings" : "entrada_decoder",
            encoder ? "Los IDs se convierten en vectores" : "El decoder representa su contexto",
            "E = W_embed[token_ids] \u00b7 \u221ad_model",
            encoder
                ? "Cada token_id del prompt consulta una fila aprendida de W_embed y se escala por \u221ad_model."
                : "El token de inicio y los tokens ya generados consultan la tabla de embeddings del decoder.",
            "Cada tarjeta conserva token e ID; la tira de color contiene componentes reales del vector escalado y la barra resume su norma L2.",
            encoder
                ? "La atencion necesita representaciones continuas y no puede operar directamente sobre IDs discretos."
                : "El decoder debe volver a representar numericamente el prefijo disponible en esta iteracion.",
            encoder
                ? "E se suma con la codificacion posicional del encoder."
                : "E se suma con la codificacion posicional del decoder.",
            "Una coordenada aislada no posee un significado semantico estable; el significado reside en el vector completo.",
            4200, true)
    }

    function positionStep(id, branch) {
        var encoder = branch === 0
        return step(
            id, sectionForBranch(branch), encoder ? "Posicion encoder" : "Posicion decoder",
            0, branch, 1, "", false, "combinacion_embedding_pe",
            encoder ? "El encoder incorpora el orden" : "El decoder incorpora el orden conocido",
            encoder ? "X\u2080 = E + PE" : "X_tgt = E_tgt + PE_tgt",
            "Una senal sinusoidal distinta se suma, componente a componente, en cada posicion.",
            "Cada punto se desplaza desde E hasta E + PE usando un unico PCA para ambos estados. PCA solo proyecta el resultado y no forma parte del Transformer.",
            "Sin informacion posicional, self-attention no distingue permutaciones de los mismos tokens.",
            encoder
                ? "X\u2080 alimenta Q, K y V de la primera capa del encoder."
                : "X_tgt alimenta Q, K y V de la autoatencion causal.",
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
                : "La misma representacion se proyecta con tres matrices aprendidas y se divide por cabezas."
            visual = "La captura muestra la ultima query y, para K/V, la key mas atendida por cada cabeza; son valores exactos recortados a las dimensiones visibles."
            purpose = cross
                ? "Separar los origenes permite que la generacion consulte la memoria codificada del prompt."
                : "Q expresa que se busca, K con que se compara y V que informacion puede transferirse."
            next = "Q y K se multiplican para formar los scores escalados."
            caveat = "K y V son la key destacada, no todas las posiciones del tensor completo."
            concept = cross ? "origen_qkv_cross" : "query_key_value"
        } else if (phase === "scores") {
            shortLabel = cross ? "Scores cruzados" : (causal ? "Scores causales" : "Scores encoder")
            title = label + ": calcula compatibilidades"
            formula = "S = QK\u1d40 / \u221ad_head"
            operation = "Cada query se compara con las keys y el producto se escala por la raiz de d_head."
            visual = "El mapa divergente contiene scores reales firmados de la query actual: el color indica signo y magnitud, no probabilidad."
            purpose = "El escalamiento evita valores extremos que saturarian el Softmax."
            next = causal
                ? "La mascara causal bloquea el futuro antes de Softmax."
                : "Los scores validos se normalizan mediante Softmax."
            caveat = "La ventana conserva las keys finales cuando la secuencia supera el limite visual."
            concept = "producto_qk"
        } else if (phase === "mask") {
            shortLabel = "Mascara causal"
            title = "El futuro queda bloqueado"
            formula = "S'\u1d62\u2c7c = S\u1d62\u2c7c si j\u2264i; -\u221e si j>i"
            operation = "La mascara triangular sustituye por -\u221e los scores que apuntan a posiciones futuras."
            visual = "El tramado marca celdas bloqueadas de la mascara real y se compara con los scores crudos y enmascarados."
            purpose = "Impide que el decoder use el token que intenta predecir y conserva la generacion autoregresiva."
            next = "Softmax asigna peso cero a lo bloqueado y normaliza solo las posiciones permitidas."
            caveat = "Bloqueado no significa que el score original fuera cero; se fuerza a -\u221e antes de normalizar."
            concept = "por_que_mascara"
        } else if (phase === "softmax") {
            shortLabel = cross ? "Softmax cruzado" : (causal ? "Softmax causal" : "Softmax atencion")
            title = label + ": normaliza los scores"
            formula = "A = softmax(S + mascara)"
            operation = "Softmax transforma cada fila permitida en pesos no negativos cuya suma es uno."
            visual = cross
                ? "Las queries del decoder aparecen abajo y las keys del prompt arriba; grosor, opacidad y particulas siguen pesos reales."
                : "Las curvas se vuelven mas gruesas y opacas cuanto mayor es el peso real de la cabeza seleccionada."
            purpose = "Los coeficientes comparables permiten decidir cuanto usar de cada Value."
            next = "Cada A\u1d62\u2c7c pondera V\u2c7c y las contribuciones se suman."
            caveat = "El umbral solo oculta curvas para evitar saturacion visual; no modifica el calculo."
            concept = "softmax_attention"
            visualIndex = 3
        } else {
            shortLabel = cross ? "A cruzada \u00b7 V" : (causal ? "A causal \u00b7 V" : "A \u00b7 V")
            title = label + ": combina los Values"
            formula = "Z\u1d62 = \u03a3\u2c7c A\u1d62\u2c7cV\u2c7c"
            operation = "Cada Value se pondera con A y las contribuciones se suman para formar el contexto de la query."
            visual = "La matriz distingue pesos A, normas \u2016A\u1d62\u2c7cV\u2c7c\u2016 y la salida real por cabeza."
            purpose = cross
                ? "El resultado incorpora al decoder la informacion del prompt relevante para esta prediccion."
                : "El resultado incorpora informacion de las posiciones accesibles al estado actual."
            next = "Las salidas de las cabezas se concatenan y atraviesan W\u1d3c."
            caveat = "Se muestran normas de contribucion, no el vector completo ni una atribucion causal."
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
            "Las h salidas paralelas se concatenan y una proyeccion aprendida las mezcla de nuevo en d_model.",
            "Cada color sigue una cabeza real desde d_head hasta concat; la malla final representa W\u1d3c.",
            "Varias cabezas permiten modelar relaciones distintas sin aumentar el ancho final del bloque.",
            "La actualizacion MHA entra a su conexion residual y LayerNorm.",
            "Las cabezas se calculan en paralelo; el orden animado es una explicacion visual.",
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
            "La actualizacion se suma a la entrada de la subcapa y despues se normaliza; este modelo usa post-norm.",
            "Las particulas recorren la rama principal y el atajo; las tarjetas inferiores contienen fases reales de LayerNorm.",
            "La ruta residual protege informacion previa y LayerNorm controla la escala del siguiente estado.",
            usesFfn
                ? (branch === 0 ? "El resultado alimenta la siguiente capa o la memoria final del encoder." : "El resultado alimenta la siguiente capa o Linear en la ultima.")
                : (branch === 0 ? "El estado entra a la FFN del encoder." : (cross ? "El estado entra a la FFN del decoder." : "El estado se convierte en Query de la atencion cruzada.")),
            "La suma residual no concatena vectores; las metricas corresponden al ultimo token capturado.",
            4800, true)
    }

    function ffnStep(id, branch) {
        var encoder = branch === 0
        return step(
            id, sectionForBranch(branch), encoder ? "FFN encoder" : "FFN decoder",
            3, branch, 5, "", false, "que_es_ffn",
            (encoder ? "Encoder" : "Decoder") + ": cada posicion pasa por la misma FFN",
            "FFN(x)=W\u2082\u03c6(W\u2081x+b\u2081)+b\u2082",
            "La red expande cada token de d_model a d_ff, aplica la activacion configurada y comprime de vuelta.",
            "Las filas comparan tokens reales que comparten pesos y muestran entrada, preactivacion, activacion y salida.",
            "La atencion mezcla posiciones; la FFN transforma de manera independiente la representacion de cada una.",
            "La salida FFN entra a la segunda conexion residual del encoder o a la tercera del decoder.",
            "ReLU y GELU no tratan igual los negativos; la escena usa la activacion configurada.",
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
                ? "El bloque de atencion, residual, FFN y residual se repite L veces con parametros distintos."
                : "Cada capa repite atencion causal, atencion cruzada y FFN con sus tres Add & Norm.",
            "El rascacielos sigue el mismo token mediante un PCA conjunto de estados reales de cada capa.",
            "La profundidad refina progresivamente la representacion antes de entregarla al siguiente modulo.",
            encoder
                ? "La salida final queda disponible como memoria K/V para la atencion cruzada."
                : "El estado de la ultima posicion de la ultima capa entra a Linear.",
            "Esta escena es una recapitulacion: PCA no es una capa ni una operacion del Transformer.",
            5300, true)
    }
}
