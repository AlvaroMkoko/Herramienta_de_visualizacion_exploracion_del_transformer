pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "ValueKinds.js" as ValueKinds

Item {
    id: root
    objectName: "moduleLaboratoryAnimationGuide"

    property string moduleId: "module_1"
    property string mode: "inference"
    property var steps: []
    property var step: ({})
    property var panel: ({})
    property var analysis: ({})
    property var demo: ({})
    property int stepIndex: 0
    property string animationDescription: ""
    property real sx: 1
    property real sy: 1
    property bool detailsExpanded: false
    // Una sola categoría visible reduce la cantidad de información que el
    // estudiante debe procesar a la vez. La selección se conserva al cambiar
    // de operación para poder comparar, por ejemplo, solo las fórmulas.
    property int selectedSection: 0

    signal inspectRequested(var panel)

    readonly property bool trainingMode: String(mode).toLowerCase().indexOf("train") >= 0
    readonly property string visualId: String(step && step.visual || step && step.id || "").toLowerCase()
    readonly property color accent: moduleAccent()
    readonly property color onAccent: moduleOnAccent()
    readonly property string formulaReadingText: formulaReading()
    readonly property string observationReadingText: observationText()

    function semanticRole() {
        var id = visualId
        if (id.indexOf("select") >= 0 || id.indexOf("feedback") >= 0
                || id.indexOf("autoregressive") >= 0 || id.indexOf("update") >= 0)
            return "result"
        if (id.indexOf("logit") >= 0 || id.indexOf("loss") >= 0
                || id.indexOf("temperature") >= 0 || id.indexOf("top_") >= 0
                || ((moduleId === "module_7" || moduleId === "module_8")
                    && id.indexOf("softmax") >= 0)
                || (moduleId === "module_7"
                    && (id.indexOf("projection") >= 0
                        || id.indexOf("hidden") >= 0)))
            return "focus"
        if (id.indexOf("token") >= 0 || id.indexOf("embedding") >= 0
                || id.indexOf("position") >= 0 || id.indexOf("input") >= 0
                || id.indexOf("layer") >= 0 || id.indexOf("stack") >= 0)
            return "structure"
        if (id.indexOf("ffn") >= 0 || id.indexOf("activation") >= 0
                || id.indexOf("residual") >= 0 || id.indexOf("norm") >= 0
                || id.indexOf("multihead") >= 0 || id.indexOf("backward") >= 0
                || id.indexOf("gradient") >= 0 || id.indexOf("decoder") >= 0)
            return "transformation"
        if (id.indexOf("attention") >= 0 || id.indexOf("score") >= 0
                || id.indexOf("mask") >= 0 || id.indexOf("context") >= 0
                || id.indexOf("weighted") >= 0 || id.indexOf("qk") >= 0
                || id.indexOf("encoder") >= 0)
            return "context"
        if (id.indexOf("output") >= 0)
            return "result"
        return "structure"
    }

    function moduleAccent() {
        switch (semanticRole()) {
        case "context": return Style.Theme.inferencia_contexto
        case "transformation": return Style.Theme.inferencia_transformacion
        case "focus": return Style.Theme.inferencia_foco
        case "result": return Style.Theme.inferencia_resultado
        default: return Style.Theme.inferencia_estructura
        }
    }

    function moduleOnAccent() {
        switch (semanticRole()) {
        case "context": return Style.Theme.inferencia_sobre_contexto
        case "transformation": return Style.Theme.inferencia_sobre_transformacion
        case "focus": return Style.Theme.inferencia_sobre_foco
        case "result": return Style.Theme.inferencia_sobre_resultado
        default: return Style.Theme.inferencia_sobre_estructura
        }
    }

    function valueOr(value, fallback) {
        if (value === undefined || value === null || String(value).trim().length === 0)
            return fallback
        return String(value)
    }

    function stepAt(index) {
        if (!steps || index < 0 || index >= steps.length)
            return ({})
        return steps[index] || ({})
    }

    function titleAt(index, fallback) {
        return valueOr(stepAt(index).title, fallback)
    }

    function shapeText() {
        var shape = panel && panel.shape !== undefined ? panel.shape : []
        if (shape && shape.length !== undefined && typeof shape !== "string")
            return "[" + Array.prototype.join.call(shape, " × ") + "]"
        return valueOr(shape, "—")
    }

    // `kind` es el value_kind del dato (ValueKinds.js): solo un id se escribe
    // como entero; un valor continuo conserva sus decimales.
    function numberText(value, kind) {
        var number = Number(value)
        if (!Number.isFinite(number))
            return "—"
        if (ValueKinds.isDiscrete(kind) && Number.isInteger(number))
            return String(number)
        var absolute = Math.abs(number)
        if (absolute !== 0 && (absolute >= 1000 || absolute < 0.001))
            return number.toExponential(2)
        return number.toFixed(absolute >= 10 ? 2 : 4)
    }

    function displayedFormula() {
        return valueOr(step && step.formula,
                       "entrada → transformación → salida").replace(/;\s*/g, ";\n")
    }

    function formulaPointSize() {
        var length = valueOr(step && step.formula, "").length
        if (length > 62)
            return Math.max(18, 19 * sx)
        if (length > 40)
            return Math.max(19, 21 * sx)
        return Math.max(21, 23 * sx)
    }

    function captureText() {
        if (!panel || !panel.key)
            return "La escena conserva el resultado real del forward asociado a este paso."
        var result = "● Datos reales · " + valueOr(panel.title, "Tensor del paso")
                + "\nforma " + shapeText()
                + " · " + Number(panel.full_length || 0) + " valores"
        var stats = panel.stats || ({})
        var kind = ValueKinds.of(panel)
        // La media de unos ids no significa nada: son etiquetas, no medidas.
        if (ValueKinds.isTokenIds(kind))
            result += "\nids de token: categóricos, sin media ni escala"
        else if (stats.mean !== undefined || stats.min !== undefined || stats.max !== undefined)
            result += "\nmedia " + numberText(stats.mean, kind)
                    + " · mín. " + numberText(stats.min, kind)
                    + " · máx. " + numberText(stats.max, kind)
        if (Boolean(panel.matrix_truncated))
            result += "\nLa matriz visible es una muestra; el cálculo usa el tensor completo."
        return result
    }

    function observationLead() {
        var id = visualId
        if (moduleId === "module_1")
            return "Sigue cómo el texto se convierte en piezas, IDs, posiciones y máscaras sin perder el orden."
        if (moduleId === "module_7") {
            if (id.indexOf("hidden") >= 0 || id.indexOf("linear") >= 0
                    || id.indexOf("projection") >= 0 || id.indexOf("logit") >= 0)
                return "Distingue el estado oculto, los logits crudos y los candidatos concretos; todavía no son probabilidades."
            if (id.indexOf("loss") >= 0 || id.indexOf("backward") >= 0
                    || id.indexOf("gradient") >= 0 || id.indexOf("update") >= 0)
                return "Sigue la señal desde el objetivo y la pérdida hacia el gradiente y el cambio hipotético de parámetros."
            return "Compara cómo temperatura, Top-K, Top-P y Softmax cambian la competencia hasta elegir el siguiente token."
        }
        if (moduleId === "module_8") {
            if (id.indexOf("token") >= 0 || id.indexOf("embedding") >= 0)
                return "Sigue el prompt desde sus IDs hasta las representaciones con contenido y orden."
            if (id.indexOf("encoder") >= 0 || id.indexOf("decoder") >= 0)
                return "Ubica cómo el encoder crea memoria y cómo el decoder combina esa memoria con el prefijo disponible."
            if (id.indexOf("loss") >= 0 || id.indexOf("backward") >= 0
                    || id.indexOf("update") >= 0)
                return "Sigue la señal de aprendizaje a través del Transformer completo sin modificar el modelo activo."
            return "Sigue los logits, los filtros y el token que vuelve al decoder para iniciar otra iteración."
        }
        if (id.indexOf("position") >= 0 || id.indexOf("posicion") >= 0)
            return "Compara el vector antes y después de sumar la posición; el token conserva su identidad y adquiere orden."
        if (id.indexOf("embedding") >= 0)
            return "Relaciona cada ID con su vector y observa signo, magnitud y forma; una coordenada aislada no tiene significado humano propio."
        if (id.indexOf("qkv") >= 0 || id.indexOf("query") >= 0
                || id.indexOf("projection") >= 0 || id.indexOf("project") >= 0)
            return "Distingue Q, K y V: Q busca, K permite comparar y V transporta la información que puede mezclarse."
        if (id.indexOf("score") >= 0 || id.indexOf("scale") >= 0
                || id.indexOf("qk") >= 0)
            return "Lee cada celda como compatibilidad entre una query y una key; todavía no es una probabilidad."
        if (id.indexOf("mask") >= 0 || id.indexOf("causal") >= 0)
            return "Comprueba qué posiciones quedan permitidas y cuáles se excluyen antes de Softmax."
        if (id.indexOf("softmax") >= 0 || id.indexOf("weight") >= 0)
            return "Observa cómo los scores permitidos se convierten en pesos entre 0 y 1 que suman aproximadamente uno."
        if (id.indexOf("context") >= 0 || id.indexOf("weighted") >= 0)
            return "Sigue cómo cada peso escala su Value y cómo las contribuciones se suman para formar contexto."
        if (id.indexOf("concat") >= 0 || id.indexOf("multihead") >= 0
                || id.indexOf("head") >= 0 || id.indexOf("wo") >= 0)
            return "Sigue cada cabeza desde su subespacio hasta la concatenación y la mezcla aprendida de Wᴼ."
        if (id.indexOf("residual") >= 0 || id.indexOf("norm") >= 0)
            return "Compara la ruta identidad con la actualización: se suman coordenada a coordenada y después se normalizan."
        if (id.indexOf("ffn") >= 0 || id.indexOf("activation") >= 0)
            return "Observa la expansión a d_ff, la no linealidad y el regreso a d_model para cada token por separado."
        if (id.indexOf("layer") >= 0 || id.indexOf("stack") >= 0)
            return "Sigue el mismo token entre capas; cambia su representación, no su identidad."
        if (moduleId === "module_5" && id.indexOf("attention") >= 0)
            return "Observa cómo self-attention añade contexto al token antes de que el residual conserve también su entrada."
        if (moduleId === "module_6" && id.indexOf("attention") >= 0)
            return id.indexOf("cross") >= 0
                    ? "Sigue cómo las queries del decoder consultan las keys y Values de la memoria del encoder."
                    : "Sigue cómo cada posición del decoder mezcla únicamente el prefijo permitido por la máscara causal."
        if (id.indexOf("loss") >= 0 || id.indexOf("backward") >= 0
                || id.indexOf("gradient") >= 0 || id.indexOf("update") >= 0)
            return "Sigue la señal desde la pérdida hacia el gradiente y el cambio hipotético de parámetros."
        return "Relaciona la entrada visible, la transformación animada y el resultado que continúa al siguiente paso."
    }

    function observationText() {
        var lead = valueOr(demo && demo.animation_explanation,
                           valueOr(animationDescription, observationLead()))
        var caption = valueOr(demo && demo.caption, "")
        if (caption.length && lead.indexOf(caption) < 0)
            return lead + " " + caption
        return lead
    }

    function formulaReading() {
        var sid = String(step && step.id || "")

        if (moduleId === "module_1") {
            if (sid === "text") return "La flecha indica que el texto Unicode se divide en segmentos candidatos; todavía no hay vectores ni atención."
            if (sid === "tokens") return "t₀…tₙ son los tokens en su orden original; el subíndice indica posición, no importancia."
            if (sid === "ids") return "Cada token consulta el vocabulario y recibe un índice entero. El número identifica una fila, no codifica significado."
            if (sid === "specials") return "BOS se antepone para abrir la secuencia y EOS se añade para marcar su cierre cuando corresponde."
            if (sid === "batch") return trainingMode
                    ? "Las secuencias de longitudes distintas se alinean en una matriz B×T y las posiciones sobrantes se rellenan con PAD."
                    : "[:Tmax] conserva como máximo las primeras Tmax posiciones del contexto; no añade contenido nuevo."
            if (sid === "mask") return "La comparación ids ≠ PAD produce 1 en tokens reales y 0 en relleno; esos ceros se bloquearán en atención."
            if (sid === "no_grad") return "∅ significa que el tokenizador no posee parámetros diferenciables: prepara datos, pero el backward no lo actualiza."
        }

        if (moduleId === "module_2") {
            if (sid === "lookup") return "E[idᵢ] selecciona exactamente la fila de la tabla aprendida E asociada con el ID del token i."
            if (sid === "scale") return "El vector eᵢ se multiplica coordenada a coordenada por el escalar √d_model para ajustar su magnitud."
            if (sid === "position") return "pos es la posición, i identifica el par de dimensiones y d_model es el ancho del vector. El exponente asigna una frecuencia distinta a cada par seno/coseno."
            if (sid === "sum") return "La suma es coordenada a coordenada: ẽᵢ aporta contenido y PEᵢ aporta orden, ambos con ancho d_model."
            if (sid === "dropout") return trainingMode
                    ? "Dropout anula aleatoriamente algunas coordenadas y reescala las restantes solo durante entrenamiento."
                    : "En inferencia Dropout está desactivado, por eso la salida x̃ es exactamente igual a x."
            if (sid === "embedding_gradient") return "La derivada mide cómo cambiaría la pérdida al variar la fila E[id] que participó en el forward."
            if (sid === "embedding_update") return "η escala el gradiente g y E′ resta ese cambio a E; el laboratorio calcula E′ sin guardarlo."
        }

        if (moduleId === "module_3") {
            if (sid === "attention_input") return "T es el número de posiciones y d el ancho de cada representación; cada fila de X corresponde a un token."
            if (sid === "weights") return "WQ, WK y WV son tres matrices aprendidas de d×d; todavía no dependen de un token concreto."
            if (sid === "qkv") return "La misma X se multiplica por tres matrices distintas: Q formula consultas, K permite compararlas y V lleva contenido."
            if (sid === "dot") return "La celda (i,j) de QKᵀ es el producto punto entre la query i y la key j: una compatibilidad sin normalizar."
            if (sid === "scale") return "Dividir S₀ entre √d_k controla su magnitud y evita que Softmax se vuelva excesivamente extrema."
            if (sid === "mask") return "mask(S) conserva scores permitidos y sustituye los bloqueados por −∞ antes de normalizar."
            if (sid === "softmax") return "Softmax se aplica por fila: convierte los scores permitidos en pesos A entre 0 y 1 que suman uno."
            if (sid === "weighted") return "AV multiplica cada Value por su peso de atención y suma las contribuciones para formar contexto."
            if (sid === "output") return "Concat reúne los contextos de todas las cabezas y Wᴼ los mezcla de regreso al ancho d_model."
            if (sid === "backward") return "Cada derivada indica la sensibilidad de L respecto de WQ, WK o WV y se obtiene recorriendo el cálculo en sentido inverso."
            if (sid === "update") return "El optimizador restaría η veces el gradiente a W; aquí W′ es una comparación hipotética y no se aplica."
        }

        if (moduleId === "module_4") {
            if (sid === "project") return "Q, K y V conservan la forma B×T×d_model antes de reorganizar su última dimensión en cabezas."
            if (sid === "split") return "d_model se reorganiza como h bloques de d_head; no se cortan tokens y debe cumplirse d_model=h·d_head."
            if (sid === "maps") return "Cada cabeza h calcula su propia matriz A_h con sus Q_h y K_h; las distribuciones pueden ser distintas."
            if (sid === "contexts") return "A_hV_h produce un contexto C_h independiente por cabeza y por posición."
            if (sid === "concat") return "Concat coloca C₁…Cₕ uno junto a otro y recupera un vector de ancho d_model."
            if (sid === "wo") return "Wᴼ mezcla las coordenadas concatenadas; no es un promedio fijo entre cabezas."
            if (sid === "backward") return "La notación entre llaves resume los gradientes que llegan a las proyecciones de cada cabeza y a Wᴼ."
            if (sid === "update") return "θ representa todas esas matrices; θ′ resta ηg sin modificar los parámetros del modelo activo."
        }

        if (moduleId === "module_5") {
            if (sid === "encoder_input") return "Xₗ es la representación que entra a la capa l; para l>0 proviene de la capa anterior."
            if (sid === "encoder_attention") return "MHA aplica atención multi-head a Xₗ y produce una actualización contextual del mismo ancho."
            if (sid === "residual_1") return "La suma es coordenada a coordenada entre Xₗ y la actualización MHA(Xₗ); no es concatenación."
            if (sid === "norm_1") return "LayerNorm calcula μ y σ² sobre las coordenadas de cada token, normaliza y después aplica γ y β aprendidos."
            if (sid === "ffn_expand") return "W₁ proyecta cada token de d_model a d_ff y b₁ desplaza la preactivación H."
            if (sid === "ffn_activation") return "φ se aplica elemento a elemento sobre H e introduce la no linealidad que una sola proyección no tendría."
            if (sid === "ffn_project") return "W₂ comprime A de d_ff a d_model; así F puede sumarse con N₁ en el siguiente residual."
            if (sid === "norm_2") return "N₁ funciona como atajo, F como actualización y LayerNorm entrega X_{l+1}."
            if (sid === "stack") return "Encoder₁ transforma X₀; cada capa siguiente recibe la salida anterior hasta producir X_N."
            if (sid === "backward") return "θ_l agrupa atención, FFN, γ y β de la capa l; el gradiente de la pérdida llega a todos ellos."
            if (sid === "update") return "ηg_l es el cambio propuesto para la capa l; θ_l′ solo se calcula con fines didácticos."
        }

        if (moduleId === "module_6") {
            if (sid === "decoder_prefix") return trainingMode
                    ? "Teacher forcing desplaza la secuencia: BOS y las respuestas previas entran; el token siguiente funciona como objetivo."
                    : "En el paso t solo están disponibles BOS y los tokens ŷ ya generados; el futuro aún no existe para el decoder."
            if (sid === "decoder_embedding") return "Cada ID del prefijo selecciona E_out y se suma con PE para obtener Z₀ con contenido y orden."
            if (sid === "causal_mask") return "M[i,j] vale 1 únicamente cuando j≤i; una posición puede mirar su presente y pasado, nunca el futuro."
            if (sid === "masked_attention") return "Attention usa Z como Q, K y V, pero M fuerza a cero los pesos correspondientes a posiciones futuras."
            if (sid === "decoder_residual_1") return "Z conserva el atajo y A_self aporta contexto causal; LayerNorm produce N₁."
            if (sid === "cross_attention") return "Q nace del decoder N₁, mientras K y V se proyectan desde la memoria del encoder."
            if (sid === "decoder_residual_2") return "N₁ conserva el estado del decoder y A_cross añade información recuperada de la fuente."
            if (sid === "decoder_ffn") return "W₁ expande N₂, φ introduce no linealidad y W₂ devuelve cada token a d_model."
            if (sid === "decoder_output") return "La tercera suma residual combina N₂ y F; LayerNorm entrega la salida de esta capa."
            if (sid === "decoder_layers") return "Cada Decoder_l refina el prefijo usando atención causal, memoria del encoder y FFN hasta Z_N."
            if (sid === "backward") return "θ_decoder reúne los parámetros de atención y FFN; ∂L indica la sensibilidad de la pérdida a cada uno."
            if (sid === "update") return "θ′ resta ηg al decoder completo; el resultado se muestra, pero no se escribe en el modelo."
        }

        if (moduleId === "module_7") {
            if (sid === "hidden") return "h_t es el vector contextual de la posición elegida y tiene d_model coordenadas."
            if (sid === "linear") return "W_vocab compara h_t con una fila por token y b añade un sesgo; cada componente de z es un logit."
            if (sid === "target") return "y_t es el ID correcto aportado por el batch mediante teacher forcing; no es el token predicho."
            if (sid === "loss") return "Softmax asigna probabilidad al objetivo y −log penaliza con mayor fuerza cuando esa probabilidad es pequeña."
            if (sid === "backward") return "g contiene la derivada de L respecto de W_vocab e indica en qué dirección aumentaría la pérdida."
            if (sid === "update") return "SGD propondría W′ restando ηg; el laboratorio no reemplaza W_vocab."
            if (sid === "temperature") return "Cada logit se divide entre T: T<1 amplía diferencias y T>1 las reduce antes de Softmax."
            if (sid === "top_k") return "Se ordenan los logits y solo los K mayores siguen compitiendo; los demás quedan descartados."
            if (sid === "top_p") return "Se ordenan candidatos por probabilidad y se conserva el conjunto mínimo cuya masa acumulada alcanza P."
            if (sid === "softmax") return "Softmax exponencia y normaliza los logits supervivientes para obtener una distribución cuya suma es uno."
            if (sid === "select") return "argmax elige de forma determinista el índice con mayor probabilidad p."
            if (sid === "feedback") return "⊕ significa anexar ŷ_t al prefijo; ese prefijo ampliado alimentaría la siguiente iteración."
        }

        if (moduleId === "module_8") {
            if (sid === "full_tokens" || sid === "full_batch") return trainingMode
                    ? "src, tgt_in, tgt_out y M son los tensores discretos y máscaras que necesita el forward de entrenamiento."
                    : "El tokenizer convierte el texto en IDs discretos que el modelo puede consultar en su tabla de embeddings."
            if (sid === "full_embedding") return "Cada ID selecciona un embedding, √d ajusta su escala y PE añade información de posición."
            if (sid === "full_encoder") return "Encoder aplica su pila a X y produce Mem, la memoria contextual que consultará el decoder."
            if (sid === "full_decoder") return trainingMode
                    ? "Decoder combina el objetivo desplazado Y, la memoria Mem y la máscara causal para producir todos los estados H."
                    : "En el paso t, Decoder combina el prefijo disponible con Mem y produce el estado H_t."
            if (sid === "full_logits") return "W_vocab proyecta H o h_t al vocabulario y b añade el sesgo; el resultado todavía son scores."
            if (sid === "full_filters") return "Temperatura reescala los logits; Top-K descarta por rango y Top-P usa masa de probabilidad acumulada para decidir qué logits conservar. La salida sigue siendo logits filtrados."
            if (sid === "full_select") return "argmax de Softmax selecciona de forma reproducible el token con mayor probabilidad."
            if (sid === "full_feedback") return "El token ŷ_t se anexa al prefijo y cierra una iteración autoregresiva antes de comenzar la siguiente."
            if (sid === "full_loss") return "CE compara los logits Z de posiciones válidas con tgt_out y los resume en la pérdida escalar L."
            if (sid === "full_backward") return "Autograd propaga la derivada de L desde la salida hacia decoder, encoder y embeddings."
            if (sid === "full_update") return "θ representa todos los parámetros entrenables; θ′ es el cambio hipotético θ−ηg y no se aplica."
        }

        return "Lee la expresión de izquierda a derecha: «"
                + valueOr(step && step.input, "entrada") + "» se transforma en «"
                + valueOr(step && step.output, "salida") + "»."
    }

    function purposeText() {
        var output = valueOr(step && step.output, "el resultado del paso")
        var next = titleAt(stepIndex + 1, "")
        return next.length
                ? "Produce «" + output + "» para continuar con «" + next + "»."
                : "Produce «" + output + "», el resultado final de este recorrido del módulo."
    }

    function caveatText() {
        switch (moduleId) {
        case "module_1":
            return "Un ID solo identifica una entrada del vocabulario; su valor numérico no expresa significado ni importancia."
        case "module_2":
            return "El color representa signo y magnitud. Una dimensión aislada no equivale a un concepto humano ni a importancia."
        case "module_3":
            return "Un peso de atención describe una mezcla interna; por sí solo no demuestra causalidad ni explica toda la predicción."
        case "module_4":
            return "Las cabezas ocupan subespacios distintos, pero no tienen obligatoriamente una función humana fija."
        case "module_5":
            return "Residual suma vectores del mismo ancho; no concatena. Esta arquitectura aplica LayerNorm después de la suma."
        case "module_6":
            return "La máscara causal bloquea información futura. Desactivarla sirve como contraste, no como inferencia autoregresiva válida."
        case "module_7":
            return "Los logits no son probabilidades. Temperatura, Top-K y Top-P son reglas de generación, no capas aprendidas."
        default:
            return "La animación resume una captura real del forward; las flechas y colores ayudan a leerla, pero no son cálculos adicionales."
        }
    }

    function modeEvidenceText() {
        var behavior = analysis && analysis.behavior ? analysis.behavior : ({})
        if (!trainingMode)
            return valueOr(behavior.inference,
                           "Los parámetros permanecen fijos mientras se calcula esta salida.")
        var text = valueOr(behavior.training,
                           "La pérdida permite calcular gradientes para los parámetros entrenables.")
        var training = analysis && analysis.training ? analysis.training : ({})
        if (training.trainable !== false && training.loss !== undefined)
            text += " Pérdida capturada: " + Number(training.loss).toFixed(4) + "."
        text += " La actualización mostrada no modifica el modelo activo."
        var experiment = analysis && analysis.experiment ? analysis.experiment : ({})
        if (experiment.didactic_note)
            text += " " + String(experiment.didactic_note)
        return text
    }

    function gradientsText() {
        var training = analysis && analysis.training ? analysis.training : ({})
        var gradients = training.gradients || []
        if (!gradients.length)
            return "Este componente no expone gradientes en la captura actual."
        var lines = []
        for (var index = 0; index < Math.min(4, gradients.length); ++index) {
            var gradient = gradients[index] || ({})
            lines.push(valueOr(gradient.label || gradient.name, "Parámetro")
                       + " · L2 " + numberText(gradient.norm_l2))
        }
        return lines.join("\n")
    }

    ScrollView {
        id: guideScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: guideScroll.availableWidth
            spacing: 10 * root.sy

            RowLayout {
                Layout.fillWidth: true
                spacing: 6 * root.sx

                Text {
                    Layout.fillWidth: true
                    text: "EXPLICACIÓN"
                    color: root.accent
                    font.bold: true
                    font.letterSpacing: 0.5
                    font.pixelSize: Math.max(11, 12 * root.sx)
                }
                Text {
                    text: "Operación " + (root.stepIndex + 1) + " de " + root.steps.length
                    color: Style.Theme.texto_secundario_fuerte
                    font.bold: true
                    font.pixelSize: Math.max(11, 12 * root.sx)
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.valueOr(root.step && root.step.title, "Operación del módulo")
                color: Style.Theme.texto_primario
                font.bold: true
                wrapMode: Text.WordWrap
                font.pixelSize: Math.max(22, 25 * root.sx)
            }

            TabBar {
                id: explanationTabs
                objectName: "moduleLaboratoryGuideTabs"
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(44, 48 * root.sy)
                currentIndex: root.selectedSection
                spacing: 4 * root.sx
                Accessible.name: "Categorías de la explicación"
                Accessible.description: "Muestra una categoría a la vez"
                onCurrentIndexChanged: root.selectedSection = currentIndex

                background: Rectangle {
                    radius: 10 * root.sx
                    color: Style.Theme.surface
                    border.color: Style.Theme.borde_suave
                }

                PestanaAccesible {
                    objectName: "moduleLaboratoryGuideIdeaTab"
                    text: "Idea clave"
                    font.pixelSize: Math.max(11, 13 * root.sx)
                }
                PestanaAccesible {
                    objectName: "moduleLaboratoryGuideFormulaTab"
                    text: "Fórmula"
                    font.pixelSize: Math.max(11, 13 * root.sx)
                }
                PestanaAccesible {
                    objectName: "moduleLaboratoryGuideAnimationTab"
                    text: "Animación"
                    font.pixelSize: Math.max(11, 13 * root.sx)
                }
                PestanaAccesible {
                    objectName: "moduleLaboratoryGuideDataTab"
                    text: "Datos"
                    font.pixelSize: Math.max(11, 13 * root.sx)
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.selectedSection === 0
                      ? "Comprende el propósito y el lugar de esta operación."
                      : (root.selectedSection === 1
                         ? "Lee la fórmula, sus símbolos y el resultado que produce."
                         : (root.selectedSection === 2
                            ? "Concéntrate únicamente en lo que cambia dentro de la animación."
                            : "Consulta las dimensiones, estadísticas y valores reales capturados."))
                color: Style.Theme.texto_secundario_fuerte
                wrapMode: Text.WordWrap
                font.pixelSize: Math.max(11, 13 * root.sx)
            }

            Rectangle {
                objectName: "moduleLaboratoryGuideLocalContext"
                visible: root.selectedSection === 0
                Layout.fillWidth: true
                implicitHeight: localContextColumn.implicitHeight + 20 * root.sy
                radius: 10 * root.sx
                color: Style.Theme.superficie_alterna
                border.color: Style.Theme.borde_medio

                ColumnLayout {
                    id: localContextColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10 * root.sx
                    spacing: 7 * root.sy

                    Text {
                        text: "HILO DEL CÁLCULO"
                        color: Style.Theme.texto_secundario_fuerte
                        font.bold: true
                        font.pixelSize: Math.max(10, 11 * root.sx)
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4 * root.sx
                        ContextCell {
                            Layout.fillWidth: true
                            eyebrow: "ANTES"
                            value: root.titleAt(root.stepIndex - 1, "Entrada del módulo")
                            accent: Style.Theme.texto_secundario
                            sx: root.sx; sy: root.sy
                        }
                        Text { text: "→"; color: Style.Theme.texto_terciario; font.bold: true }
                        ContextCell {
                            Layout.fillWidth: true
                            eyebrow: "AHORA"
                            value: root.valueOr(root.step && root.step.title, "Paso actual")
                            accent: root.accent
                            highlighted: true
                            sx: root.sx; sy: root.sy
                        }
                        Text { text: "→"; color: Style.Theme.texto_terciario; font.bold: true }
                        ContextCell {
                            Layout.fillWidth: true
                            eyebrow: "DESPUÉS"
                            value: root.titleAt(root.stepIndex + 1, "Salida del módulo")
                            accent: Style.Theme.texto_secundario
                            sx: root.sx; sy: root.sy
                        }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Style.Theme.divisor }
                    Text {
                        objectName: "moduleLaboratoryGuideInputOutput"
                        Layout.fillWidth: true
                        text: "ENTRA  " + root.valueOr(root.step && root.step.input, "—")
                              + "   →   SALE  " + root.valueOr(root.step && root.step.output, "—")
                        color: Style.Theme.texto_secundario_fuerte
                        font.bold: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: Math.max(12, 14 * root.sx)
                    }
                }
            }

            GuideCard {
                objectName: "moduleLaboratoryGuideIdea"
                visible: root.selectedSection === 0
                Layout.fillWidth: true
                eyebrow: "IDEA CLAVE"
                body: root.valueOr(root.step && root.step.explanation,
                                   "Este paso transforma la entrada y prepara la siguiente operación.")
                footer: "QUÉ DEBES RECORDAR · "
                        + root.valueOr(root.step && root.step.output,
                                       "resultado del paso")
                accent: root.accent
                sx: root.sx; sy: root.sy
            }

            GuideCard {
                objectName: "moduleLaboratoryGuideObservation"
                visible: root.selectedSection === 2
                Layout.fillWidth: true
                eyebrow: "QUÉ OBSERVAR AHORA"
                body: root.observationText()
                accent: Style.Theme.inferencia_estructura
                fillColor: Style.Theme.info_fondo
                footer: "AL FINAL DEBES VER · "
                        + root.valueOr(root.step && root.step.output, "el resultado del paso")
                sx: root.sx; sy: root.sy
            }

            Rectangle {
                objectName: "moduleLaboratoryGuideFormula"
                visible: root.selectedSection === 1
                Layout.fillWidth: true
                implicitHeight: formulaColumn.implicitHeight + 24 * root.sy
                radius: 11 * root.sx
                color: Style.Theme.formula_fondo
                border.color: Style.Theme.formula_texto
                border.width: 2

                ColumnLayout {
                    id: formulaColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12 * root.sx
                    spacing: 7 * root.sy

                    Text {
                        text: "FÓRMULA CLAVE DE ESTE PASO"
                        color: Style.Theme.formula_texto
                        font.bold: true
                        font.letterSpacing: 0.5
                        font.pixelSize: Math.max(10, 11 * root.sx)
                    }
                    Text {
                        objectName: "moduleLaboratoryGuideFormulaText"
                        Layout.fillWidth: true
                        text: root.displayedFormula()
                        color: Style.Theme.formula_texto
                        font.family: "Cambria Math"
                        font.weight: Font.DemiBold
                        font.pixelSize: root.formulaPointSize()
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        lineHeight: 1.14
                    }
                    Text {
                        objectName: "moduleLaboratoryGuideFormulaReading"
                        Layout.fillWidth: true
                        text: "CÓMO LEERLA  ·  " + root.formulaReadingText
                        color: Style.Theme.texto_primario
                        wrapMode: Text.WordWrap
                        lineHeight: 1.22
                        font.pixelSize: Math.max(13, 15 * root.sx)
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(Style.Theme.formula_texto, 0.42) }
                    Text {
                        text: "POR QUÉ IMPORTA AQUÍ"
                        color: Style.Theme.formula_texto
                        font.bold: true
                        font.pixelSize: Math.max(10, 11 * root.sx)
                    }
                    Text {
                        objectName: "moduleLaboratoryGuidePurpose"
                        Layout.fillWidth: true
                        text: root.purposeText()
                        color: Style.Theme.texto_primario
                        wrapMode: Text.WordWrap
                        lineHeight: 1.22
                        font.pixelSize: Math.max(13, 15 * root.sx)
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: guideFormulaResult.implicitHeight + 16 * root.sy
                        radius: 7 * root.sx
                        color: Style.Theme.proceso_fondo
                        border.color: Style.Theme.inferencia_resultado

                        Text {
                            id: guideFormulaResult
                            objectName: "moduleLaboratoryGuideFormulaResult"
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8 * root.sx
                            text: "RESULTADO CLAVE  ·  "
                                  + root.valueOr(root.step && root.step.output,
                                                 "salida del paso")
                            color: Style.Theme.proceso_texto
                            font.bold: true
                            wrapMode: Text.WordWrap
                            font.pixelSize: Math.max(11, 13 * root.sx)
                        }
                    }
                }
            }

            GuideCard {
                visible: root.selectedSection === 3
                Layout.fillWidth: true
                eyebrow: root.trainingMode ? "SEÑAL DE APRENDIZAJE" : "USO EN INFERENCIA"
                body: root.modeEvidenceText()
                accent: root.trainingMode
                        ? Style.Theme.inferencia_transformacion
                        : Style.Theme.inferencia_contexto
                fillColor: root.trainingMode
                           ? Style.Theme.formula_fondo : Style.Theme.exito_fondo
                sx: root.sx; sy: root.sy
            }

            BotonAccesible {
                objectName: "moduleLaboratoryGuideDetailsToggle"
                visible: false
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(36, 40 * root.sy)
                text: root.detailsExpanded ? "Ocultar datos técnicos  ▴" : "Ver datos técnicos  ▾"
                font.bold: true
                font.pixelSize: Math.max(12, 14 * root.sx)
                onClicked: root.detailsExpanded = !root.detailsExpanded
            }

            ColumnLayout {
                objectName: "moduleLaboratoryGuideTechnicalDetails"
                Layout.fillWidth: true
                visible: root.selectedSection === 3
                spacing: 9 * root.sy

                GuideCard {
                    objectName: "moduleLaboratoryGuideEvidence"
                    Layout.fillWidth: true
                    eyebrow: "DATOS DE ESTA CAPTURA"
                    body: root.captureText()
                    accent: Style.Theme.inferencia_resultado
                    sx: root.sx; sy: root.sy
                }
                BotonAccesible {
                    visible: Boolean(root.panel && root.panel.key)
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(34, 38 * root.sy)
                    text: "Inspeccionar valores originales"
                    font.bold: true
                    onClicked: root.inspectRequested(root.panel)
                }
                GuideCard {
                    visible: root.trainingMode
                             && ((root.analysis.training || {}).gradients || []).length > 0
                    Layout.fillWidth: true
                    eyebrow: "GRADIENTES REALES DEL COMPONENTE"
                    body: root.gradientsText()
                    accent: Style.Theme.inferencia_transformacion
                    sx: root.sx; sy: root.sy
                }
                GuideCard {
                    Layout.fillWidth: true
                    eyebrow: "LEE EL ELEMENTO VISUAL"
                    body: root.valueOr(root.panel && root.panel.description,
                                       "Los números provienen del forward; el color y las flechas ayudan a representarlos.")
                    accent: Style.Theme.inferencia_contexto
                    sx: root.sx; sy: root.sy
                }
            }

            Rectangle {
                visible: root.selectedSection === 0
                Layout.fillWidth: true
                implicitHeight: caveatText.implicitHeight + 20 * root.sy
                radius: 9 * root.sx
                color: Style.Theme.aviso_fondo
                border.color: Style.Theme.warning

                Text {
                    id: caveatText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10 * root.sx
                    text: "⚠  " + root.caveatText()
                    color: Style.Theme.aviso_texto
                    wrapMode: Text.WordWrap
                    lineHeight: 1.18
                    font.pixelSize: Math.max(12, 14 * root.sx)
                }
            }
        }
    }

    component ContextCell: Rectangle {
        id: contextCell
        property string eyebrow: ""
        property string value: ""
        property color accent: Style.Theme.acento
        property bool highlighted: false
        property real sx: 1
        property real sy: 1

        implicitHeight: 54 * sy
        radius: 7 * sx
        color: highlighted ? Qt.alpha(accent, 0.12) : Style.Theme.surface
        border.color: highlighted ? accent : Style.Theme.borde_suave

        Column {
            anchors.fill: parent
            anchors.margins: 6 * contextCell.sx
            spacing: 2 * contextCell.sy
            Text {
                width: parent.width
                text: contextCell.eyebrow
                color: contextCell.accent
                font.bold: true
                font.pixelSize: Math.max(9, 10 * contextCell.sx)
            }
            Text {
                width: parent.width
                text: contextCell.value
                color: Style.Theme.texto_primario
                font.bold: contextCell.highlighted
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.pixelSize: Math.max(10, 11 * contextCell.sx)
            }
        }
    }

    component GuideCard: Rectangle {
        id: guideCard
        property string eyebrow: ""
        property string body: ""
        property string footer: ""
        property color accent: Style.Theme.acento
        property color fillColor: Style.Theme.superficie_alterna
        property real sx: 1
        property real sy: 1

        implicitHeight: guideColumn.implicitHeight + 20 * sy
        radius: 10 * sx
        color: fillColor
        border.color: Qt.alpha(accent, 0.62)

        ColumnLayout {
            id: guideColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10 * guideCard.sx
            spacing: 5 * guideCard.sy

            Text {
                text: guideCard.eyebrow
                color: guideCard.accent
                font.bold: true
                font.pixelSize: Math.max(10, 11 * guideCard.sx)
            }
            Text {
                Layout.fillWidth: true
                text: guideCard.body
                color: Style.Theme.texto_secundario_fuerte
                wrapMode: Text.WordWrap
                lineHeight: 1.20
                font.pixelSize: Math.max(12, 14 * guideCard.sx)
            }
            Text {
                visible: guideCard.footer.length > 0
                Layout.fillWidth: true
                text: guideCard.footer
                color: guideCard.accent
                font.bold: true
                wrapMode: Text.WordWrap
                font.pixelSize: Math.max(10, 12 * guideCard.sx)
            }
        }
    }
}
