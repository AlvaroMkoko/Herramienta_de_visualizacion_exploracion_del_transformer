pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "../styles" as Style
import "../components"
import "../components/ValueKinds.js" as ValueKinds

PagePrincipal {
    id: root
    objectName: "moduleLaboratoryScreen"

    property string moduleId: "module_1"
    readonly property var courseController: mainViewModel.courseController
    readonly property var laboratoryController: mainViewModel.moduleLaboratoryController
    readonly property var modelLibraryController: mainViewModel.modelLibraryController
    // Solo cuenta modelos que la biblioteca puede cargar: si todos son
    // incompatibles, ofrecer «usar uno guardado» llevaría a tarjetas con los
    // botones deshabilitados, que es otro callejón sin salida.
    readonly property bool hasSavedModels: {
        var models = root.modelLibraryController
                     ? (root.modelLibraryController.modelos || []) : []
        for (var i = 0; i < models.length; ++i) {
            if (models[i] && models[i].compatible !== false)
                return true
        }
        return false
    }
    readonly property var moduleData: courseController.currentModule
    readonly property var laboratory: moduleData.laboratory || ({})
    readonly property var analysis: laboratoryController.result || ({})
    readonly property var allSteps: analysis.steps || []
    readonly property var steps: root.allSteps
    readonly property var tokens: analysis.tokens || []
    readonly property real uiScale: Math.max(0.82, Math.min(1.08,
                                                           Math.min(root.sx,
                                                                    root.sy)))
    // Tres modos evitan el salto brusco de tres columnas a una sola. En el
    // modo medio, los pasos ocupan la primera fila y la visualización conserva
    // todo el ancho. La explicación se mantiene en su propia ventana.
    readonly property bool wideLayout: root.width >= 1460
    readonly property bool mediumLayout: root.width >= 1120 && !root.wideLayout
    readonly property bool narrowLayout: root.width < 1120
    readonly property bool compactLayout: !root.wideLayout
    readonly property bool narrowControls: root.width < 760
    readonly property real workspacePreferredHeight: root.wideLayout
                                                    ? 590 * root.uiScale
                                                    : (root.mediumLayout
                                                       ? 832 * root.uiScale
                                                       : 1112 * root.uiScale)
    readonly property int safeStepIndex: Math.max(
        0, Math.min(root.currentStepIndex, Math.max(0, root.steps.length - 1)))
    readonly property var currentStep: {
        if (root.steps.length === 0)
            return ({})
        var candidate = root.steps[root.safeStepIndex]
        return candidate && typeof candidate === "object" ? candidate : ({})
    }
    readonly property var currentPanel: root.panelForKey(
                                            String(root.currentStep.panel_key || ""))
    readonly property int modelLayerCount: Math.max(
        1, Number((mainViewModel.modeloActualInfo || {}).num_capas || 1))
    readonly property int modelHeadCount: Math.max(
        1, Number((mainViewModel.modeloActualInfo || {}).num_cabezas || 1))
    readonly property var currentFormulaDemo: {
        var demos = root.analysis.formula_demos || ({})
        var demo = demos[String(root.currentStep.id || "")]
        return demo && typeof demo === "object" ? demo : ({})
    }
    readonly property var discoveryChallenge: root.challengeForCurrentStep()
    readonly property var predictionBundle: root.buildPredictionBundle()
    readonly property var explanationBundle: root.buildExplanationBundle()
    readonly property var experimentDescriptor: root.buildExperimentDescriptor()
    readonly property bool advancedMode: true
    readonly property real laboratoryProgress: root.steps.length > 0
                                               ? (root.safeStepIndex + 1) / root.steps.length
                                               : 0
    readonly property var overviewGroups: root.groupsForModule()
    readonly property string activeGroupId: root.groupForStep(
                                                       String(root.currentStep.id || ""))

    property string mode: "inference"
    readonly property string learningLevel: "advanced"
    // Una sola fuente de atención por vez: vista del componente, fórmula
    // animada o explicación. El contenido completo sigue disponible.
    property int workspaceSection: 2
    property int currentStepIndex: 0
    property int discoveryStage: 0
    property int discoveryPrediction: -1
    property int discoveryExplanation: -1
    property string discoveryHint: ""
    // Evidencia del ciclo que se reporta al CourseController al cerrarlo.
    property int discoveryExplanationAttempts: 0
    property bool discoveryPredictionCorrect: false
    property bool discoveryExperimentDone: false
    property var labProgress: ({})
    property string errorMessage: ""
    property string inspectedKey: ""
    property string inspectedTitle: ""
    property var inspectedPanel: ({})
    property int valueOffset: 0
    property var pageValues: []
    property string pendingStepId: ""
    property bool pendingStepRestore: false
    // La explicación vive aparte para que la animación nunca pierda espacio.
    property bool guideDetached: false

    function labQuestion(id, prompt, correct, distractorA, distractorB, explanation) {
        return ({
            "id": id,
            "prompt": prompt,
            "options": [correct, distractorA, distractorB],
            "correct_index": 0,
            "explanation": explanation
        })
    }

    function challengeForCurrentStep() {
        // Retos propios del laboratorio: los `challenges` alimentan el pre y el
        // post-test, y practicarlos aquí sería ensayar las respuestas.
        var challenges = root.moduleData.lab_challenges || root.moduleData.challenges || []
        var sid = String(root.currentStep && root.currentStep.id || "")
        var key = root.moduleId + ":" + sid
        var specific = {
            "module_1:text": root.labQuestion(
                "lab_m1_text", "¿Qué recibe el tokenizador al comenzar esta animación?",
                "Texto Unicode todavía sin convertir en vectores", "Embeddings contextualizados", "Probabilidades del vocabulario",
                "La entrada inicial es texto. Los tokens, IDs y vectores aparecen en operaciones posteriores."),
            "module_1:ids": root.labQuestion(
                "lab_m1_ids", "Al consultar el vocabulario, ¿qué debe reemplazar a cada token?",
                "Un ID entero estable para ese token", "Un vector contextual completo", "Una probabilidad del siguiente token",
                "El vocabulario realiza una correspondencia discreta token→ID; todavía no crea embeddings."),
            "module_1:batch:training": root.labQuestion(
                "lab_m1_batch_training", "Si las secuencias del batch tienen distinta longitud, ¿cómo se obtiene una matriz rectangular?",
                "Se añade PAD a las secuencias más cortas", "Se mezclan todas las frases en una sola", "Se aumenta d_model",
                "En entrenamiento, cada fila se rellena hasta la longitud común del batch."),
            "module_1:batch:inference": root.labQuestion(
                "lab_m1_batch_inference", "Si el texto supera el contexto máximo durante inferencia, ¿qué debe hacer este ajuste?",
                "Recortar la secuencia al contexto admitido", "Añadir PAD hasta duplicar su longitud", "Cambiar el vocabulario",
                "En inferencia se limita la longitud sin inventar contenido nuevo."),
            "module_1:no_grad": root.labQuestion(
                "lab_m1_no_grad", "Después de tokenizar, rellenar y crear la máscara, ¿qué parte de esta preparación aprende por gradiente?",
                "Ninguna: son operaciones de datos", "Los IDs se vuelven parámetros", "La máscara aprende qué columnas bloquear",
                "Estas operaciones preparan la entrada; no contienen parámetros que el optimizador pueda actualizar."),
            "module_2:dropout:inference": root.labQuestion(
                "lab_m2_dropout_inference", "¿Qué debe ocurrir con dropout durante inferencia?",
                "Queda desactivado y conserva todas las activaciones", "Elimina tokens completos", "Cambia d_model en cada ejecución",
                "Dropout regulariza el entrenamiento; al inferir se utiliza la representación completa y determinista."),
            "module_2:embedding_gradient": root.labQuestion(
                "lab_m2_embedding_gradient", "Si el batch consultó solo algunos IDs, ¿qué filas de la tabla reciben gradiente directo en esta animación?",
                "Las filas de los IDs consultados", "Todas las filas por igual", "Solo la primera fila de la tabla",
                "El lookup conecta la pérdida directamente con las filas utilizadas por el batch."),
            "module_3:attention_input": root.labQuestion(
                "lab_m3_attention_input", "Self-attention comienza con la matriz X: una tabla que conserva los tokens en el orden de la frase. ¿Qué representa cada fila antes de calcular Q, K y V?",
                "La representación de un token", "Una cabeza de atención completa", "Un token del vocabulario de salida",
                "X conserva una fila de d_model componentes por posición de la secuencia."),
            "module_3:backward": root.labQuestion(
                "lab_m3_backward", "Durante entrenamiento, backward recorre el cálculo en sentido inverso para identificar qué parámetros influyeron en la pérdida L. Si Q=XWQ, K=XWK y V=XWV, ¿hasta qué matrices debe llegar el gradiente?",
                "Hasta WQ, WK y WV, siguiendo en reversa las operaciones de Q, K y V", "Sólo hasta el texto original, sin pasar por las operaciones", "Debe detenerse en softmax y no llegar a los parámetros",
                "El gradiente atraviesa en reversa las operaciones que produjeron Q, K y V; así se obtienen ∂L/∂WQ, ∂L/∂WK y ∂L/∂WV."),
            "module_3:update": root.labQuestion(
                "lab_m3_update", "En W′=W−ηg, W es el peso actual, g es su gradiente y η indica el tamaño del paso. El laboratorio sólo simula el cálculo y no modifica el modelo. ¿Qué representa W′?",
                "El valor que tendría W después de un paso hipotético guiado por el gradiente", "Una nueva matriz de pesos de atención que debe sumar 1", "La salida contextual definitiva de la frase",
                "W′ es el posible valor siguiente del parámetro si se aplicara ese paso de optimización."),
            "module_4:project": root.labQuestion(
                "lab_m4_project", "¿Qué producen XWQ, XWK y XWV antes de separar las cabezas?",
                "Q, K y V completos con anchura d_model", "Un único mapa T×T", "Los IDs de la secuencia",
                "Primero se calculan las proyecciones completas; después se reorganizan en h bloques de d_head."),
            "module_4:contexts": root.labQuestion(
                "lab_m4_contexts", "¿Cómo obtiene cada cabeza su vector de contexto?",
                "Combina sus Values con sus propios pesos de atención", "Copia directamente la salida de otra cabeza", "Promedia todas las matrices WQ",
                "Cada cabeza calcula C_h=A_hV_h dentro de su propio subespacio."),
            "module_5:encoder_input": root.labQuestion(
                "lab_m5_encoder_input", "Al seleccionar una capa del encoder, ¿qué recibe como X_l?",
                "La salida de la capa anterior", "Los logits finales del vocabulario", "El objetivo desplazado del decoder",
                "La primera capa recibe embeddings posicionados; las siguientes reciben la representación de la capa previa."),
            "module_5:ffn_project": root.labQuestion(
                "lab_m5_ffn_project", "Después de la activación en d_ff, ¿qué debe hacer la segunda proyección de la FFN?",
                "Regresar de d_ff a d_model", "Expandir otra vez el número de tokens", "Convertir la salida en probabilidades",
                "La salida vuelve a d_model para que pueda sumarse mediante la conexión residual."),
            "module_6:decoder_prefix:inference": root.labQuestion(
                "lab_m6_prefix_inference", "Durante inferencia, ¿qué información puede formar el prefijo del decoder?",
                "BOS y los tokens generados hasta ahora", "Toda la respuesta futura", "Los logits de todas las capas",
                "La generación es autoregresiva: solo dispone de los tokens ya producidos."),
            "module_6:decoder_embedding": root.labQuestion(
                "lab_m6_decoder_embedding", "¿Qué se añade a los embeddings del prefijo antes de la atención?",
                "La codificación de sus posiciones", "Las probabilidades Top-P", "La pérdida del batch",
                "El decoder necesita representar tanto la identidad de cada token como su orden."),
            "module_6:decoder_residual_1": root.labQuestion(
                "lab_m6_residual_1", "¿Qué combina la primera conexión residual del decoder?",
                "El estado de entrada y el contexto causal", "La memoria del encoder y los logits", "Dos máscaras de padding",
                "La primera Add & Norm conserva el estado previo mientras incorpora masked self-attention."),
            "module_6:decoder_residual_2": root.labQuestion(
                "lab_m6_residual_2", "¿Qué incorpora la segunda conexión residual del decoder?",
                "El contexto recuperado de la fuente", "Un token elegido por Top-K", "La pérdida de entrenamiento",
                "La segunda Add & Norm integra la salida de cross-attention con el estado del decoder."),
            "module_6:decoder_ffn": root.labQuestion(
                "lab_m6_ffn", "Después de las dos atenciones, ¿cómo actúa la FFN del decoder?",
                "Transforma cada posición por separado", "Mezcla posiciones futuras sin máscara", "Selecciona directamente el siguiente token",
                "La FFN procesa las características de cada posición; la mezcla entre tokens ya ocurrió en las atenciones."),
            "module_6:decoder_layers": root.labQuestion(
                "lab_m6_layers", "Al avanzar por la pila del decoder, ¿qué permanece y qué cambia?",
                "Se conserva la forma y cambian los valores con parámetros de cada capa", "Aumenta un token en cada capa", "Todas las capas producen valores idénticos",
                "Las capas comparten la interfaz [B,T,d_model], pero cada una aprende parámetros distintos."),
            "module_7:hidden": root.labQuestion(
                "lab_m7_hidden", "¿Qué representación alimenta la predicción asociada a la posición observada?",
                "Su estado final del decoder", "La matriz completa del vocabulario", "El ID sin convertir a vector",
                "La capa de salida recibe un vector d_model del decoder y lo proyecta al vocabulario."),
            "module_7:select": root.labQuestion(
                "lab_m7_select", "En esta animación reproducible, ¿qué candidato se seleccionará?",
                "El de mayor probabilidad entre los supervivientes", "Siempre el primer ID del vocabulario", "Todos los candidatos a la vez",
                "El laboratorio usa selección determinista para que el mismo experimento produzca el mismo resultado."),
            "module_7:target": root.labQuestion(
                "lab_m7_target", "Durante entrenamiento, ¿para qué se muestra el token objetivo junto a los logits?",
                "Para indicar la respuesta que debe recibir mayor probabilidad", "Para sustituir todos los logits", "Para aplicar Top-K antes de la pérdida",
                "Teacher forcing aporta el ID correcto con el que se calculará la pérdida."),
            "module_7:loss": root.labQuestion(
                "lab_m7_loss", "¿Qué datos debe comparar cross-entropy en esta animación?",
                "Los logits crudos y el token objetivo", "Los pesos de atención y Top-P", "El token elegido y la máscara causal",
                "La pérdida de entrenamiento se calcula antes de Top-K, Top-P o muestreo."),
            "module_8:full_tokens": root.labQuestion(
                "lab_m8_tokens", "¿Qué debe producir primero el Transformer a partir del texto para poder consultar embeddings?",
                "Una secuencia ordenada de IDs", "Probabilidades del vocabulario", "Pesos de cross-attention",
                "El tokenizador segmenta el texto y el vocabulario convierte cada token en un índice."),
            "module_8:full_batch": root.labQuestion(
                "lab_m8_batch", "¿Qué necesita preparar el batch antes del recorrido de entrenamiento?",
                "Entradas, objetivos desplazados y máscaras", "Solo el último token generado", "Top-K y temperatura",
                "El entrenamiento requiere tensores alineados y máscaras que oculten padding y futuro."),
            "module_8:full_logits": root.labQuestion(
                "lab_m8_logits", "Al proyectar cada estado de d_model al vocabulario, ¿qué esperas obtener?",
                "Un vector de puntuaciones, una por token posible", "Una sola probabilidad ya normalizada", "Una nueva máscara de padding",
                "La proyección final cambia el último eje de d_model a |V| y todavía produce logits."),
            "module_8:full_filters": root.labQuestion(
                "lab_m8_filters", "¿Qué debería cambiar al aplicar temperatura, Top-K y Top-P a los logits?",
                "La concentración y el conjunto de candidatos", "Los IDs del texto fuente", "Los parámetros ya aprendidos del encoder",
                "Estos controles modifican la distribución usada para generar, no los pesos ni la entrada fuente."),
            "module_8:full_select": root.labQuestion(
                "lab_m8_select", "Después de normalizar los candidatos supervivientes, ¿qué produce la selección?",
                "El siguiente token", "La memoria del encoder", "Un nuevo vocabulario",
                "La distribución final permite escoger un único token para continuar el ciclo."),
            "module_8:full_feedback": root.labQuestion(
                "lab_m8_feedback", "¿Qué ocurrirá con el token recién seleccionado en el ciclo autoregresivo?",
                "Se añadirá al prefijo para el siguiente paso", "Reemplazará la memoria del encoder", "Se convertirá en una cabeza de atención",
                "El prefijo crece un token y vuelve a entrar al decoder; la memoria de la fuente se conserva."),
            "module_8:full_loss": root.labQuestion(
                "lab_m8_loss", "¿Qué resume el escalar de pérdida mostrado en el flujo completo?",
                "El desacuerdo entre logits y objetivos válidos", "El número de capas del decoder", "La cantidad de candidatos Top-K",
                "Cross-entropy resume el error de las posiciones válidas del batch." )
        }
        var selectedSpecific = specific[key + ":" + root.mode] || specific[key]
        if (selectedSpecific !== undefined)
            return selectedSpecific
        if (sid === "backward" || sid === "full_backward")
            return root.labQuestion(
                "lab_" + root.moduleId + "_" + sid,
                "En «" + String(root.currentStep.title || "Backward") + "», ¿hacia dónde debe viajar la señal de la pérdida?",
                "Hacia las operaciones y parámetros que participaron", "Solo hacia los tokens de texto", "Directamente hacia Top-K sin pasar por el modelo",
                "Autograd recorre en sentido inverso las operaciones utilizadas en este módulo.")
        if (sid === "update" || sid === "embedding_update" || sid === "full_update")
            return root.labQuestion(
                "lab_" + root.moduleId + "_" + sid,
                "En «" + String(root.currentStep.title || "Actualización") + "», ¿qué representa θ′ = θ − ηg?",
                "Un cambio hipotético guiado por el gradiente", "Una modificación del vocabulario", "La salida definitiva de softmax",
                "El laboratorio visualiza el paso de SGD, pero no modifica los parámetros activos.")
        if (!challenges.length)
            return ({})
        var maps = {
            "module_1": { "text": 2, "tokens": 2, "ids": 7, "specials": 6,
                          "batch": 3, "mask": 1, "no_grad": 0 },
            "module_2": { "lookup": 1, "scale": 5, "position": 3, "sum": 2,
                          "dropout": 7, "embedding_gradient": 6, "embedding_update": 6 },
            "module_3": { "attention_input": 4, "weights": 5, "qkv": 4, "dot": 0,
                          "scale": 1, "mask": 6, "softmax": 2, "weighted": 3,
                          "output": 7, "backward": 5, "update": 5 },
            "module_4": { "project": 7, "split": 0, "maps": 5, "contexts": 3,
                          "concat": 2, "wo": 4, "backward": 6, "update": 6 },
            "module_5": { "encoder_input": 7, "encoder_attention": 2, "residual_1": 0,
                          "norm_1": 3, "ffn_expand": 1, "ffn_activation": 5,
                          "ffn_project": 1, "norm_2": 3, "stack": 4,
                          "backward": 6, "update": 6 },
            "module_6": { "decoder_prefix": 6, "decoder_embedding": 6, "causal_mask": 0,
                          "masked_attention": 4, "decoder_residual_1": 5,
                          "cross_attention": 2, "decoder_residual_2": 5,
                          "decoder_ffn": 5, "decoder_output": 7, "decoder_layers": 7,
                          "backward": 5, "update": 5 },
            "module_7": { "hidden": 0, "linear": 1, "temperature": 2, "top_k": 3,
                          "top_p": 4, "softmax": 5, "select": 6, "feedback": 6,
                          "target": 6, "loss": 5, "backward": 1, "update": 1 },
            "module_8": { "full_tokens": 2, "full_batch": 0, "full_embedding": 4,
                          "full_encoder": 1, "full_decoder": 3, "full_logits": 6,
                          "full_filters": 6, "full_loss": 5, "full_select": 6,
                          "full_feedback": 7, "full_backward": 5, "full_update": 5 }
        }
        var moduleMap = maps[root.moduleId] || ({})
        var mapped = moduleMap[sid]
        var index = mapped === undefined
                    ? root.safeStepIndex % challenges.length : Number(mapped)
        return challenges[Math.max(0, Math.min(challenges.length - 1, index))] || ({})
    }

    function rotatedBundle(options, correctIndex, offset) {
        var source = options || []
        var count = source.length
        if (!count)
            return ({ "options": [], "correct": -1 })
        var shift = ((Number(offset) % count) + count) % count
        var ordered = []
        var displayedCorrect = -1
        for (var index = 0; index < count; ++index) {
            var sourceIndex = (index + shift) % count
            ordered.push(String(source[sourceIndex]))
            if (sourceIndex === Number(correctIndex))
                displayedCorrect = index
        }
        return ({ "options": ordered, "correct": displayedCorrect })
    }

    function buildPredictionBundle() {
        var challenge = root.discoveryChallenge || ({})
        var options = challenge.options || []
        var moduleNumber = Number(String(root.moduleId).split("_")[1]) || 0
        return root.rotatedBundle(options, Number(challenge.correct_index || 0),
                                  root.safeStepIndex + moduleNumber)
    }

    function buildExplanationBundle() {
        var correct = String(root.currentStep && root.currentStep.explanation || "")
        var candidates = [correct]
        var offsets = [-1, 1, -2, 2]
        for (var offsetIndex = 0; offsetIndex < offsets.length; ++offsetIndex) {
            var index = root.safeStepIndex + offsets[offsetIndex]
            if (index < 0 || index >= root.steps.length)
                continue
            var text = String(root.steps[index] && root.steps[index].explanation || "")
            if (text.length && candidates.indexOf(text) === -1)
                candidates.push(text)
            if (candidates.length === 3)
                break
        }
        var fallbacks = [
            "La salida aparece sin depender de la entrada ni de los parámetros del modelo.",
            "Esta operación cambia el tamaño del vocabulario y vuelve a entrenar todo el Transformer."
        ]
        for (var fallbackIndex = 0; candidates.length < 3; ++fallbackIndex)
            candidates.push(fallbacks[fallbackIndex % fallbacks.length])
        return root.rotatedBundle(candidates, 0,
                                  root.safeStepIndex + root.steps.length)
    }

    function buildExperimentDescriptor() {
        var sid = String(root.currentStep && root.currentStep.id || "")
        if (sid === "temperature")
            return ({ "label": "Cambiar la temperatura",
                      "instruction": "Cambia T y compara si las probabilidades se concentran o se reparten entre más candidatos." })
        if (sid === "top_k")
            return ({ "label": "Reducir Top-K",
                      "instruction": "Reduce K y observa cuántos candidatos sobreviven antes de normalizar." })
        if (sid === "top_p")
            return ({ "label": "Cambiar Top-P",
                      "instruction": "Cambia P y observa cómo el tamaño del núcleo depende de la masa acumulada." })
        if (sid === "full_filters")
            return ({ "label": "Cambiar los filtros",
                      "instruction": "Modifica temperatura, Top-K y Top-P juntos y compara el conjunto final de candidatos." })
        if (["causal_mask", "masked_attention", "full_decoder"].indexOf(sid) !== -1)
            return ({ "label": "Alternar la máscara causal",
                      "instruction": "Contrasta el cálculo con y sin bloqueo del futuro. Busca qué celdas dejan de participar." })
        if (root.moduleId === "module_3" && sid === "mask")
            return ({ "title": "Comprueba qué hace mask(S)",
                      "subtitle": "Aquí no se inventa un interruptor: se observa la máscara de padding que realmente usa el encoder.",
                      "label": "Ver el caso de padding",
                      "instruction": "Reproduce la animación detallada. En el encoder sólo se excluye PAD: si la frase no tiene relleno, todas las celdas permanecen permitidas; una columna PAD recibiría −∞ y después peso 0." })
        if (root.moduleId === "module_3"
                && ["attention_input", "qkv", "output"].indexOf(sid) !== -1
                && root.tokens.length > 1)
            return ({ "label": "Observar otro token",
                      "instruction": "Cambia el token observado. Comprueba que cambia la fila que se sigue, mientras cada posición conserva su lugar dentro de la frase." })
        if (root.controlRelevant("head") && root.modelHeadCount > 1)
            return ({ "label": "Comparar otra cabeza",
                      "instruction": "Selecciona otra cabeza y compara qué relaciones entre tokens reciben mayor peso." })
        if (root.controlRelevant("layer") && root.modelLayerCount > 1)
            return ({ "label": "Comparar otra capa",
                      "instruction": "Cambia de capa y observa cómo la representación ya contextualizada vuelve a transformarse." })
        if (root.controlRelevant("token") && root.tokens.length > 1)
            return ({ "label": "Cambiar el token observado",
                      "instruction": "Selecciona el token siguiente y compara qué fila, vector o distribución le corresponde." })
        return ({ "label": "Recorrer la fórmula",
                  "instruction": "Reproduce la animación y mueve su control de avance: identifica entrada, transformación y resultado sin saltar fases." })
    }

    function discoveryStageLabel() {
        if (root.discoveryStage === 0)
            return "Predecir"
        if (root.discoveryStage <= 2)
            return "Observar"
        if (root.discoveryStage === 3)
            return "Contestar"
        return "Completado"
    }

    function resetDiscovery(openChallenge) {
        discoveryAdvanceTimer.stop()
        root.discoveryStage = 0
        root.discoveryPrediction = -1
        root.discoveryExplanation = -1
        root.discoveryHint = ""
        root.discoveryExplanationAttempts = 0
        root.discoveryPredictionCorrect = false
        root.discoveryExperimentDone = false
        if (openChallenge === true)
            root.workspaceSection = 2
    }

    function refreshLabProgress() {
        root.labProgress = root.courseController.laboratoryProgress(root.moduleId) || ({})
    }

    function advancedStepIds() {
        var identifiers = []
        for (var index = 0; index < root.steps.length; ++index) {
            var identifier = String(root.steps[index] && root.steps[index].id || "")
            if (identifier.length && identifiers.indexOf(identifier) === -1)
                identifiers.push(identifier)
        }
        return identifiers
    }

    function recordAdvancedCompletion() {
        if (root.moduleId !== "module_3"
                || root.analysis.module_id !== root.moduleId
                || String(root.analysis.mode || "") !== root.mode
                || root.steps.length === 0)
            return
        var identifier = String(root.currentStep && root.currentStep.id || "")
        if (!identifier.length)
            return
        var updated = root.courseController.recordAdvancedLaboratoryStep(
                    root.moduleId, root.mode, identifier,
                    root.advancedStepIds()) || ({})
        if (updated.advanced_required !== undefined)
            root.labProgress = updated
    }

    function practiceStatusText() {
        if (root.labProgress.completed)
            return "PRÁCTICA COMPLETA ✓  ·  Ya puedes presentar el post-test."
        if (root.moduleId === "module_3") {
            var visited = Number(root.labProgress.advanced_steps || 0)
            var required = Number(root.labProgress.advanced_required || root.steps.length)
            if (root.labProgress.advanced_completed)
                return "EXPLORACIÓN AVANZADA COMPLETA ✓  ·  Post-test desbloqueado."
            return "EXPLORACIÓN AVANZADA  ·  " + visited + " de " + required
                    + " operaciones revisadas  ·  recorre todas para completar esta ruta"
        }
        return "TU PRÁCTICA  ·  " + Number(root.labProgress.cycles || 0) + " de "
                + Number(root.labProgress.required_cycles || 3)
                + " retos guiados en operaciones distintas"
                + (root.labProgress.closing_answered
                   ? "" : "  ·  pregunta del módulo pendiente")
    }

    function controlRelevant(controlName) {
        var sid = String(root.currentStep && root.currentStep.id || "")
        var module = root.moduleId
        if (controlName === "layer") {
            if (["module_3", "module_4"].indexOf(module) !== -1)
                return true
            if (module === "module_5")
                return sid !== "stack"
            if (module === "module_6")
                return ["masked_attention", "decoder_residual_1", "cross_attention",
                        "decoder_residual_2", "decoder_ffn", "decoder_output"]
                       .indexOf(sid) !== -1
            return module === "module_8"
                    && ["full_encoder", "full_decoder"].indexOf(sid) !== -1
        }
        if (controlName === "head") {
            if (["module_3", "module_4"].indexOf(module) !== -1)
                return true
            if (module === "module_5")
                return sid === "encoder_attention"
            if (module === "module_6")
                return ["masked_attention", "cross_attention"].indexOf(sid) !== -1
            return module === "module_8"
                    && ["full_encoder", "full_decoder"].indexOf(sid) !== -1
        }
        if (controlName === "token")
            return module !== "module_1"
        if (controlName === "causal")
            return (module === "module_6"
                    && ["causal_mask", "masked_attention"].indexOf(sid) !== -1)
                    || (module === "module_8"
                        && ["full_decoder", "full_logits", "full_filters",
                            "full_select", "full_feedback"].indexOf(sid) !== -1)
        if (controlName === "temperature")
            return (module === "module_7"
                    && ["temperature", "top_k", "top_p", "softmax", "select", "feedback"]
                       .indexOf(sid) !== -1)
                    || (module === "module_8"
                        && ["full_filters", "full_select", "full_feedback"]
                           .indexOf(sid) !== -1)
        if (controlName === "top_k")
            return (module === "module_7"
                    && ["top_k", "top_p", "softmax", "select", "feedback"]
                       .indexOf(sid) !== -1)
                    || (module === "module_8"
                        && ["full_filters", "full_select", "full_feedback"]
                           .indexOf(sid) !== -1)
        if (controlName === "top_p")
            return (module === "module_7"
                    && ["top_p", "softmax", "select", "feedback"].indexOf(sid) !== -1)
                    || (module === "module_8"
                        && ["full_filters", "full_select", "full_feedback"]
                           .indexOf(sid) !== -1)
        return false
    }

    function hasRelevantAdvancedControl() {
        return ["layer", "head", "token", "causal", "temperature", "top_k", "top_p"]
               .some(function(name) { return root.controlRelevant(name) })
    }

    function panelForKey(key) {
        var panels = root.analysis.panels || []
        if (key !== "") {
            for (var index = 0; index < panels.length; ++index) {
                if (String(panels[index].key) === key)
                    return panels[index]
            }
        }
        return panels.length > 0 ? panels[Math.min(root.safeStepIndex,
                                                    panels.length - 1)] : ({})
    }

    function runAnalysis(preserveCurrentStep, keepDiscovery) {
        var preserve = preserveCurrentStep === undefined
                       ? true : Boolean(preserveCurrentStep)
        var preserveDiscovery = keepDiscovery === true
        if (!preserveDiscovery)
            root.resetDiscovery(false)
        root.pendingStepId = preserve
                             ? String(root.currentStep && root.currentStep.id || "")
                             : ""
        root.pendingStepRestore = true
        root.errorMessage = ""
        if (!preserve)
            root.currentStepIndex = 0
        root.workspaceSection = preserveDiscovery ? 1 : 2
        root.laboratoryController.explore(
            root.moduleId, inputText.text, root.mode,
            Math.round(layerSlider.value), Math.round(headSlider.value),
            Math.round(tokenSlider.value), temperatureSlider.value,
            Math.round(topKSlider.value), topPSlider.value,
            causalSwitch.checked)
    }

    function restorePendingStep() {
        var stepId = root.pendingStepId
        root.pendingStepId = ""
        root.pendingStepRestore = false
        if (stepId.length === 0) {
            root.currentStepIndex = 0
            return
        }
        for (var index = 0; index < root.steps.length; ++index) {
            if (String(root.steps[index] && root.steps[index].id || "") === stepId) {
                root.currentStepIndex = index
                return
            }
        }
        root.currentStepIndex = 0
    }

    function chooseMode(nextMode) {
        if (root.mode === nextMode)
            return
        root.mode = nextMode
        root.currentStepIndex = 0
        root.resetDiscovery(true)
        if (root.laboratoryController.modelReady
                && inputText.text.trim().length > 0)
            root.runAnalysis(false)
    }

    function previousStep() {
        root.currentStepIndex = Math.max(0, root.currentStepIndex - 1)
        root.resetDiscovery(true)
    }

    function nextStep() {
        root.currentStepIndex = Math.min(Math.max(0, root.steps.length - 1),
                                         root.currentStepIndex + 1)
        root.resetDiscovery(true)
    }

    function restartSteps() {
        root.currentStepIndex = 0
        root.resetDiscovery(true)
    }

    function showFormulaPane() {
        root.workspaceSection = 1
        formulaScene.replay()
    }

    function groupsForModule() {
        if (root.moduleId === "module_6")
            return [
                { id: "prepare", label: "Preparar prefijo", steps: ["decoder_prefix", "decoder_embedding"] },
                { id: "causal", label: "Atención causal", steps: ["causal_mask", "masked_attention", "decoder_residual_1"] },
                { id: "source", label: "Consultar encoder", steps: ["cross_attention", "decoder_residual_2"] },
                { id: "transform", label: "Transformar salida", steps: ["decoder_ffn", "decoder_output", "decoder_layers"] },
                { id: "learn", label: "Aprender", steps: ["backward", "update"] }
            ]
        if (root.moduleId === "module_8")
            return [
                { id: "prepare", label: "Preparar entrada", steps: ["full_tokens", "full_batch", "full_embedding"] },
                { id: "encode", label: "Codificar", steps: ["full_encoder"] },
                { id: "decode", label: "Decodificar", steps: ["full_decoder"] },
                { id: "generate", label: "Generar", steps: ["full_logits", "full_filters", "full_select", "full_feedback"] },
                { id: "learn", label: "Aprender", steps: ["full_loss", "full_backward", "full_update"] }
            ]
        return []
    }

    function groupForStep(stepId) {
        for (var groupIndex = 0; groupIndex < root.overviewGroups.length; ++groupIndex) {
            var group = root.overviewGroups[groupIndex]
            if ((group.steps || []).indexOf(stepId) !== -1)
                return String(group.id)
        }
        return ""
    }

    function goToGroup(group) {
        var ids = group && group.steps ? group.steps : []
        for (var index = 0; index < root.steps.length; ++index) {
            if (ids.indexOf(String(root.steps[index].id || "")) !== -1) {
                root.currentStepIndex = index
                root.resetDiscovery(true)
                return
            }
        }
    }

    function confirmDiscoveryPrediction() {
        if (root.discoveryPrediction < 0)
            return
        root.discoveryPredictionCorrect =
                root.discoveryPrediction === Number(root.predictionBundle.correct)
        root.discoveryStage = 1
    }

    function applySuggestedExperiment() {
        var sid = String(root.currentStep && root.currentStep.id || "")
        root.discoveryStage = 2
        root.discoveryHint = ""
        root.discoveryExperimentDone = true

        if (sid === "temperature") {
            temperatureSlider.value = temperatureSlider.value <= 0.6 ? 1.4 : 0.5
            root.runAnalysis(true, true)
            return
        }
        if (sid === "top_k") {
            topKSlider.value = topKSlider.value <= 5 ? 12 : 3
            root.runAnalysis(true, true)
            return
        }
        if (sid === "top_p") {
            topPSlider.value = topPSlider.value <= 0.65 ? 0.95 : 0.55
            root.runAnalysis(true, true)
            return
        }
        if (sid === "full_filters") {
            temperatureSlider.value = temperatureSlider.value <= 0.7 ? 1.35 : 0.55
            topKSlider.value = topKSlider.value <= 6 ? 12 : 5
            topPSlider.value = topPSlider.value <= 0.7 ? 0.92 : 0.62
            root.runAnalysis(true, true)
            return
        }
        if (["causal_mask", "masked_attention", "full_decoder"].indexOf(sid) !== -1) {
            causalSwitch.checked = !causalSwitch.checked
            root.runAnalysis(true, true)
            return
        }
        if (root.moduleId === "module_3" && sid === "mask") {
            root.workspaceSection = 1
            formulaScene.replay()
            return
        }
        if (root.moduleId === "module_3"
                && ["attention_input", "qkv", "output"].indexOf(sid) !== -1
                && root.tokens.length > 1) {
            tokenSlider.value = (Math.round(tokenSlider.value) + 1) % root.tokens.length
            root.runAnalysis(true, true)
            return
        }
        if (root.controlRelevant("head") && root.modelHeadCount > 1) {
            headSlider.value = (Math.round(headSlider.value) + 1) % root.modelHeadCount
            root.runAnalysis(true, true)
            return
        }
        if (root.controlRelevant("layer") && root.modelLayerCount > 1) {
            layerSlider.value = (Math.round(layerSlider.value) + 1) % root.modelLayerCount
            root.runAnalysis(true, true)
            return
        }
        if (root.controlRelevant("token") && root.tokens.length > 1) {
            tokenSlider.value = (Math.round(tokenSlider.value) + 1) % root.tokens.length
            root.runAnalysis(true, true)
            return
        }
        root.workspaceSection = 1
        formulaScene.replay()
    }

    function confirmDiscoveryObservation() {
        if (root.discoveryStage === 2) {
            root.discoveryStage = 3
            root.workspaceSection = 2
        }
    }

    function checkDiscoveryExplanation() {
        if (root.discoveryExplanation < 0)
            return
        root.discoveryExplanationAttempts += 1
        if (root.discoveryExplanation === Number(root.explanationBundle.correct)) {
            root.discoveryHint = ""
            root.discoveryStage = 4
            // Un ciclo cuenta cuando hubo predicción, experimento y una
            // explicación correcta; no basta con abrir el reto.
            if (root.discoveryExperimentDone) {
                root.courseController.recordDiscoveryCycle(
                            root.moduleId, String(root.currentStep.id || ""),
                            root.discoveryPredictionCorrect,
                            root.discoveryExplanationAttempts)
                root.refreshLabProgress()
                root.recordAdvancedCompletion()
            }
            discoveryAdvanceTimer.restart()
            return
        }
        root.discoveryHint = "Todavía no. Contrasta la fórmula «"
                             + String(root.currentStep.formula || "—")
                             + "» con lo que entra y lo que sale; puedes cambiar tu respuesta."
    }

    function revealDiscoveryExplanation() {
        discoveryAdvanceTimer.stop()
        root.advanceAfterDiscovery()
    }

    function advanceAfterDiscovery() {
        if (root.discoveryStage < 4)
            return
        if (root.safeStepIndex < root.steps.length - 1) {
            root.currentStepIndex = root.safeStepIndex + 1
            root.resetDiscovery(true)
            return
        }
        root.discoveryStage = 5
        root.workspaceSection = 2
        root.refreshLabProgress()
    }

    function toggleGuide() {
        if (root.guideDetached)
            root.closeDetachedGuide()
        else
            root.detachGuide()
    }

    function detachGuide() {
        root.guideDetached = true
        Qt.callLater(function() {
            detachedGuideWindow.raise()
            detachedGuideWindow.requestActivate()
        })
    }

    function closeDetachedGuide() {
        root.guideDetached = false
    }

    function openValues(panel) {
        if (!panel || !panel.key)
            return
        root.inspectedPanel = panel
        root.inspectedKey = String(panel.key)
        root.inspectedTitle = String(panel.title || "Valores")
        root.valueOffset = 0
        root.loadValuePage()
        valuesDialog.open()
    }

    function loadValuePage() {
        root.pageValues = root.laboratoryController.fullValues(
            root.inspectedKey, root.valueOffset, 128)
    }

    function valueCoordinate(localIndex) {
        var absoluteIndex = root.valueOffset + Number(localIndex)
        var shape = root.inspectedPanel.shape || []
        if (shape.length === 2 && Number(shape[1]) > 0) {
            var columns = Number(shape[1])
            return "F" + (Math.floor(absoluteIndex / columns) + 1)
                    + " · C" + (absoluteIndex % columns + 1)
        }
        return "Índice " + absoluteIndex
    }

    // `kind` es el value_kind del panel (ValueKinds.js). Un id va como entero
    // y antes que la notación científica (si no, 100278 salía 1.0028e+5); un
    // valor continuo conserva sus decimales aunque sea un entero exacto.
    function formattedValue(value, kind) {
        if (typeof value === "boolean")
            return value ? "True" : "False"
        var numeric = Number(value)
        if (!Number.isFinite(numeric))
            return String(value)
        if (ValueKinds.isDiscrete(kind) && Number.isInteger(numeric))
            return String(numeric)
        var absolute = Math.abs(numeric)
        if (absolute !== 0 && (absolute >= 1000 || absolute < 0.0001))
            return numeric.toExponential(4)
        return numeric.toFixed(6)
    }

    Timer {
        id: discoveryAdvanceTimer
        interval: 1400
        repeat: false
        onTriggered: root.advanceAfterDiscovery()
    }

    Component.onCompleted: {
        root.courseController.selectModule(root.moduleId)
        // El catálogo pudo cambiar desde que se construyó el controlador; sin
        // releerlo, el botón de modelos guardados podría quedar oculto aunque
        // existan, que es justo el síntoma que este botón resuelve.
        if (root.modelLibraryController)
            root.modelLibraryController.refrescar()
        root.refreshLabProgress()
    }
    onVisibleChanged: if (!visible && guideDetached) closeDetachedGuide()

    Connections {
        target: root.laboratoryController
        function onError(message) {
            root.pendingStepId = ""
            root.pendingStepRestore = false
            root.errorMessage = message
        }
        function onAnalysisCompleted(completedModuleId) {
            if (completedModuleId !== root.moduleId)
                return
            if (root.pendingStepRestore)
                Qt.callLater(root.restorePendingStep)
            else {
                root.currentStepIndex = 0
                root.resetDiscovery(true)
            }
        }
    }

    ScrollView {
        id: pageScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            width: pageScroll.availableWidth
            spacing: 14 * root.uiScale

            Item { Layout.fillWidth: true; Layout.preferredHeight: 10 * root.uiScale }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24 * root.uiScale
                // La ventana principal mantiene el indicador de vista dual y
                // el botón de preferencias sobre la esquina superior derecha:
                // 150 + 8 + 34 + 12 = 204 en el peor caso (vista dual
                // visible), más 4 de holgura.
                Layout.rightMargin: 208 * root.uiScale
                spacing: 14 * root.uiScale

                BotonPrincipal {
                    Layout.preferredWidth: 150 * root.uiScale
                    Layout.preferredHeight: 40 * root.uiScale
                    text: "← Módulo"
                    onClicked: root.stackView.pop()
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 1
                    Text {
                        Layout.fillWidth: true
                        text: "LABORATORIO ESPECIALIZADO · MÓDULO "
                              + (root.moduleData.order || "")
                        color: Style.Theme.acento_fuerte
                        font.bold: true
                        font.pixelSize: 10 * root.uiScale
                        font.letterSpacing: 0.7
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.laboratory.title || "Laboratorio"
                        color: Style.Theme.texto_primario
                        font.bold: true
                        font.pixelSize: 24 * root.uiScale
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: !root.compactLayout
                        text: root.laboratory.description || ""
                        color: Style.Theme.texto_secundario_fuerte
                        font.pixelSize: 11 * root.uiScale
                        elide: Text.ElideRight
                    }
                }
                Rectangle {
                    objectName: "moduleLaboratoryModelStatus"
                    visible: !root.narrowLayout
                    Layout.preferredWidth: 150 * root.uiScale
                    Layout.preferredHeight: 36 * root.uiScale
                    radius: height / 2
                    color: root.laboratoryController.modelReady
                           ? Style.Theme.exito_fondo : Style.Theme.aviso_fondo
                    border.color: root.laboratoryController.modelReady
                                  ? Style.Theme.success : Style.Theme.warning
                    Text {
                        anchors.centerIn: parent
                        text: root.laboratoryController.modelReady
                              ? "● Modelo activo" : "○ Falta un modelo"
                        color: root.laboratoryController.modelReady
                               ? Style.Theme.exito_texto : Style.Theme.aviso_texto
                        font.bold: true
                        font.pixelSize: 10 * root.uiScale
                    }
                }
            }

            RectanglePrincipal {
                Layout.fillWidth: true
                Layout.leftMargin: 24 * root.uiScale
                Layout.rightMargin: 24 * root.uiScale
                Layout.preferredHeight: controlLayout.implicitHeight + 24 * root.uiScale
                sx: root.uiScale
                sy: root.uiScale

                ColumnLayout {
                    id: controlLayout
                    anchors.fill: parent
                    anchors.margins: 12 * root.uiScale
                    spacing: 10 * root.uiScale

                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.narrowControls ? 1 : 2
                        columnSpacing: 10 * root.uiScale
                        rowSpacing: 10 * root.uiScale
                        TabBar {
                            id: modeTabs
                            objectName: "moduleLaboratoryModeTabs"
                            Layout.fillWidth: root.narrowControls
                            Layout.preferredWidth: root.narrowControls
                                                   ? 0 : 330 * root.uiScale
                            Layout.preferredHeight: 42 * root.uiScale
                            Layout.fillHeight: true
                            currentIndex: root.mode === "training" ? 0 : 1
                            background: Rectangle {
                                radius: 9 * root.uiScale
                                color: Style.Theme.superficie_alterna
                                border.color: Style.Theme.borde_suave
                            }
                            PestanaAccesible {
                                objectName: "moduleLaboratoryTrainingMode"
                                text: "Entrenamiento"
                                onClicked: root.chooseMode("training")
                            }
                            PestanaAccesible {
                                objectName: "moduleLaboratoryInferenceMode"
                                text: "Inferencia"
                                onClicked: root.chooseMode("inference")
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredHeight: Math.max(
                                                        42 * root.uiScale,
                                                        modeSummary.implicitHeight
                                                        + 16 * root.uiScale)
                            radius: 9 * root.uiScale
                            color: root.mode === "training"
                                   ? Style.Theme.aviso_fondo : Style.Theme.info_fondo
                            Text {
                                id: modeSummary
                                objectName: "moduleLaboratoryModeSummary"
                                anchors.fill: parent
                                anchors.margins: 8 * root.uiScale
                                text: root.mode === "training"
                                      ? "Forward + pérdida + gradientes reales · sin alterar los pesos"
                                      : "Forward real con parámetros fijos · observa cómo se usa lo aprendido"
                                color: root.mode === "training"
                                       ? Style.Theme.aviso_texto : Style.Theme.info_texto
                                font.pixelSize: 10 * root.uiScale
                                font.bold: true
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        // Una columna por control visible: los ocultos no ocupan
                        // celda, y con una de menos el último botón baja de fila.
                        columns: root.narrowControls
                                 ? 1 : (root.laboratoryController.modelReady
                                        ? 2 : (root.hasSavedModels ? 4 : 3))
                        columnSpacing: 10 * root.uiScale
                        rowSpacing: 10 * root.uiScale
                        CampoTextoPrincipal {
                            id: inputText
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredHeight: 42 * root.uiScale
                            sx: root.uiScale; sy: root.uiScale
                            text: "La atención conecta cada token con su contexto."
                            placeholderText: "Escribe un texto para inspeccionarlo"
                            onAccepted: if (analyzeButton.enabled) root.runAnalysis()
                        }
                        BotonPrincipal {
                            id: analyzeButton
                            objectName: "moduleLaboratoryAnalyzeButton"
                            Layout.fillWidth: root.narrowControls
                            Layout.preferredWidth: root.narrowControls
                                                   ? 0 : 185 * root.uiScale
                            Layout.preferredHeight: 42 * root.uiScale
                            text: root.analysis.module_id === root.moduleId
                                  ? "Actualizar experimento" : "Ejecutar experimento"
                            enabled: root.laboratoryController.modelReady
                                     && inputText.text.trim().length > 0
                            opacity: enabled ? 1 : 0.45
                            onClicked: root.runAnalysis()
                        }
                        BotonPrincipal {
                            objectName: "moduleLaboratoryCreateModelButton"
                            visible: !root.laboratoryController.modelReady
                            Layout.fillWidth: root.narrowControls
                            Layout.preferredWidth: root.narrowControls
                                                   ? 0 : 135 * root.uiScale
                            Layout.preferredHeight: 42 * root.uiScale
                            text: "Crear modelo"
                            onClicked: root.stackView.push(
                                "SetupScreen.qml", {
                                    "stackView": root.stackView,
                                    "regresarAlLaboratorio": true,
                                    "moduloRetornoLaboratorio": root.moduleId,
                                    "modoRetornoLaboratorio": root.mode
                                })
                        }
                        BotonPrincipal {
                            objectName: "moduleLaboratoryLoadModelButton"
                            // Sin modelos guardados la biblioteca estaría vacía:
                            // se oculta en vez de llevar a una pantalla sin salida.
                            visible: !root.laboratoryController.modelReady
                                     && root.hasSavedModels
                            Layout.fillWidth: root.narrowControls
                            Layout.preferredWidth: root.narrowControls
                                                   ? 0 : 185 * root.uiScale
                            Layout.preferredHeight: 42 * root.uiScale
                            text: "Usar modelo guardado"
                            onClicked: root.stackView.push(
                                "ModelLibraryScreen.qml", {
                                    "stackView": root.stackView,
                                    "regresarAlLaboratorio": true,
                                    "moduloRetornoLaboratorio": root.moduleId,
                                    "modoRetornoLaboratorio": root.mode
                                })
                        }
                    }

                    GridLayout {
                        objectName: "moduleLaboratoryAdvancedControls"
                        Layout.fillWidth: true
                        visible: root.advancedMode && root.hasRelevantAdvancedControl()
                        columns: root.narrowLayout ? 2 : 5
                        columnSpacing: 14 * root.uiScale
                        rowSpacing: 6 * root.uiScale

                        LaboratorySlider {
                            id: layerSlider
                            objectName: "moduleLaboratoryLayerControl"
                            visible: root.advancedMode && root.controlRelevant("layer")
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            title: "Capa"
                            from: 0
                            to: root.modelLayerCount - 1
                            stepSize: 1
                            value: 0
                            displayOffset: 1
                            accent: Style.Theme.acento
                            sx: root.uiScale; sy: root.uiScale
                        }
                        LaboratorySlider {
                            id: headSlider
                            objectName: "moduleLaboratoryHeadControl"
                            visible: root.advancedMode && root.controlRelevant("head")
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            title: "Cabeza"
                            from: 0
                            to: root.modelHeadCount - 1
                            stepSize: 1
                            value: 0
                            displayOffset: 1
                            accent: Style.Theme.acento
                            sx: root.uiScale; sy: root.uiScale
                        }
                        LaboratorySlider {
                            id: tokenSlider
                            objectName: "moduleLaboratoryTokenControl"
                            visible: root.advancedMode && root.controlRelevant("token")
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            title: root.moduleId === "module_7" ? "Posición" : "Token"
                            from: 0
                            to: Math.max(0, root.tokens.length - 1)
                            stepSize: 1
                            value: 0
                            displayOffset: 1
                            accent: Style.Theme.acento
                            sx: root.uiScale; sy: root.uiScale
                        }
                        LaboratoryToggle {
                            id: causalSwitch
                            objectName: "moduleLaboratoryCausalControl"
                            visible: root.advancedMode && root.controlRelevant("causal")
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            title: "Máscara causal"
                            checked: true
                            checkedText: "Futuro bloqueado"
                            uncheckedText: "Contraste sin máscara"
                            accent: Style.Theme.acento
                            sx: root.uiScale; sy: root.uiScale
                        }
                        LaboratorySlider {
                            id: temperatureSlider
                            objectName: "moduleLaboratoryTemperatureControl"
                            visible: root.advancedMode && root.controlRelevant("temperature")
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            title: "Temperatura"
                            from: 0.1
                            to: 2.0
                            value: 1.0
                            stepSize: 0.05
                            decimals: 2
                            accent: Style.Theme.acento
                            sx: root.uiScale; sy: root.uiScale
                        }
                        LaboratorySlider {
                            id: topKSlider
                            objectName: "moduleLaboratoryTopKControl"
                            visible: root.advancedMode && root.controlRelevant("top_k")
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            title: "Top-K"
                            from: 1
                            to: 100
                            value: 20
                            stepSize: 1
                            accent: Style.Theme.acento
                            sx: root.uiScale; sy: root.uiScale
                        }
                        LaboratorySlider {
                            id: topPSlider
                            objectName: "moduleLaboratoryTopPControl"
                            visible: root.advancedMode && root.controlRelevant("top_p")
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            title: "Top-P"
                            from: 0.05
                            to: 1.0
                            value: 0.9
                            stepSize: 0.01
                            decimals: 2
                            accent: Style.Theme.acento
                            sx: root.uiScale; sy: root.uiScale
                        }
                    }
                }
            }

            Text {
                visible: root.errorMessage.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: 26 * root.uiScale
                Layout.rightMargin: 26 * root.uiScale
                text: "⚠ " + root.errorMessage
                color: Style.Theme.error_texto
                wrapMode: Text.WrapAnywhere
                font.pixelSize: 11 * root.uiScale
            }

            ListView {
                id: tokenStrip
                objectName: "moduleLaboratoryTokenStrip"
                visible: root.advancedMode && root.tokens.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: 24 * root.uiScale
                Layout.rightMargin: 24 * root.uiScale
                Layout.preferredHeight: 42 * root.uiScale
                orientation: ListView.Horizontal
                spacing: 6 * root.uiScale
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.tokens
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Rectangle {
                    id: tokenChip
                    required property int index
                    required property var modelData
                    width: Math.max(62 * root.uiScale,
                                    tokenLabel.implicitWidth + 18 * root.uiScale)
                    height: 34 * root.uiScale
                    radius: 8 * root.uiScale
                    color: Number(root.analysis.selected_token_index || 0) === index
                           ? Style.Theme.acento_fondo : Style.Theme.chip_fondo
                    border.color: Number(root.analysis.selected_token_index || 0) === index
                                  ? Style.Theme.acento : Style.Theme.chip_borde
                    Text {
                        id: tokenLabel
                        anchors.centerIn: parent
                        text: tokenChip.modelData.text + " · " + tokenChip.modelData.id
                        color: Style.Theme.chip_texto
                        font.family: Style.Theme.fuente_mono
                        font.pixelSize: 9 * root.uiScale
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            tokenSlider.value = tokenChip.index
                            if (root.laboratoryController.modelReady)
                                root.runAnalysis()
                        }
                    }
                }
            }

            Rectangle {
                visible: root.analysis.module_id !== root.moduleId
                Layout.fillWidth: true
                Layout.leftMargin: 24 * root.uiScale
                Layout.rightMargin: 24 * root.uiScale
                Layout.preferredHeight: 290 * root.uiScale
                radius: 14 * root.uiScale
                color: Style.Theme.surface
                border.color: Style.Theme.borde_suave
                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 40 * root.uiScale,
                                    620 * root.uiScale)
                    spacing: 12 * root.uiScale
                    Text { Layout.alignment: Qt.AlignHCenter; text: root.laboratoryController.modelReady ? "⌁" : "◇"; color: Style.Theme.acento; font.pixelSize: 36 * root.uiScale; font.bold: true }
                    Text {
                        Layout.fillWidth: true
                        text: root.laboratoryController.modelReady
                              ? "Explora este componente con datos reales"
                              : (root.hasSavedModels
                                 ? "Primero crea o carga un modelo"
                                 : "Primero crea un modelo")
                        color: Style.Theme.texto_primario
                        font.pixelSize: 20 * root.uiScale
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.laboratoryController.modelReady
                              ? "El experimento seguirá las operaciones internas del módulo, paso a paso. Podrás inspeccionar matrices, dimensiones y gradientes sin modificar el modelo."
                              : "El laboratorio necesita los pesos y dimensiones de un Transformer activo para mostrar cálculos auténticos."
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 11 * root.uiScale
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }

            RectanglePrincipal {
                id: practiceCard
                objectName: "moduleLaboratoryPracticeCard"
                parent: advancedPracticeHost
                visible: root.analysis.module_id === root.moduleId
                anchors.fill: parent
                implicitHeight: practiceColumn.implicitHeight + 18 * root.uiScale
                sx: root.uiScale
                sy: root.uiScale

                ColumnLayout {
                    id: practiceColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 9 * root.uiScale
                    spacing: 6 * root.uiScale

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8 * root.uiScale
                        Text {
                            objectName: "moduleLaboratoryPracticeStatus"
                            Layout.fillWidth: true
                            text: root.practiceStatusText()
                            color: root.labProgress.completed ? Style.Theme.exito_texto : Style.Theme.acento_fuerte
                            font.bold: true
                            font.pixelSize: Math.max(10, 11 * root.uiScale)
                            wrapMode: Text.WordWrap
                        }
                    }

                    BotonPrincipal {
                        objectName: "moduleLaboratoryOpenPosttest"
                        visible: root.labProgress.completed === true
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? 42 * root.uiScale : 0
                        text: "Continuar al post-test  →"
                        onClicked: root.stackView.push(
                            "EvaluationIntroScreen.qml", {
                                "stackView": root.stackView,
                                "moduleId": root.moduleId,
                                "assessmentType": "post"
                            })
                    }
                }
            }

            RectanglePrincipal {
                objectName: "moduleLaboratoryProgressCard"
                visible: root.analysis.module_id === root.moduleId
                Layout.fillWidth: true
                Layout.leftMargin: 24 * root.uiScale
                Layout.rightMargin: 24 * root.uiScale
                Layout.preferredHeight: progressColumn.implicitHeight + 18 * root.uiScale
                sx: root.uiScale
                sy: root.uiScale

                ColumnLayout {
                    id: progressColumn
                    anchors.fill: parent
                    anchors.margins: 9 * root.uiScale
                    spacing: 6 * root.uiScale

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8 * root.uiScale
                        Text {
                            Layout.fillWidth: true
                            text: "OPERACIÓN " + (root.safeStepIndex + 1) + " DE "
                                  + root.steps.length
                                  + (!root.advancedMode
                                     ? "  ·  " + String(root.currentStep.title || "Paso actual")
                                     : "")
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: Math.max(11, 12 * root.uiScale)
                            wrapMode: Text.WordWrap
                        }
                        BotonSecundario {
                            objectName: "moduleLaboratoryDiscoveryButton"
                            Layout.preferredWidth: 190 * root.uiScale
                            Layout.preferredHeight: 30 * root.uiScale
                            sx: root.uiScale; sy: root.uiScale
                            text: root.discoveryStage < 5
                                  ? "Reto guiado · " + root.discoveryStageLabel()
                                  : "Explicación revisada ✓"
                            Accessible.name: text
                            onClicked: root.workspaceSection = 2
                        }
                        BotonSecundario { objectName: "moduleLaboratoryRestartSteps"; Layout.preferredWidth: 36 * root.uiScale; Layout.preferredHeight: 30 * root.uiScale; sx: root.uiScale; sy: root.uiScale; text: "↺"; Accessible.name: "Reiniciar operaciones"; onClicked: root.restartSteps() }
                        BotonSecundario { objectName: "moduleLaboratoryPreviousStep"; Layout.preferredWidth: 46 * root.uiScale; Layout.preferredHeight: 30 * root.uiScale; sx: root.uiScale; sy: root.uiScale; text: "←"; Accessible.name: "Operación anterior"; enabled: root.safeStepIndex > 0; opacity: enabled ? 1 : 0.4; onClicked: root.previousStep() }
                        BotonSecundario { objectName: "moduleLaboratoryNextStep"; Layout.preferredWidth: 46 * root.uiScale; Layout.preferredHeight: 30 * root.uiScale; sx: root.uiScale; sy: root.uiScale; text: "→"; Accessible.name: "Operación siguiente"; enabled: root.safeStepIndex < root.steps.length - 1; opacity: enabled ? 1 : 0.4; onClicked: root.nextStep() }
                    }

                    Text {
                        visible: !root.advancedMode
                        Layout.fillWidth: true
                        text: "ENTRA  ·  " + String(root.currentStep.input || "Datos del paso anterior")
                              + "     →     SALE  ·  "
                              + String(root.currentStep.output || "Resultado")
                        color: Style.Theme.texto_secundario_fuerte
                        font.bold: true
                        font.pixelSize: Math.max(10, 11 * root.uiScale)
                        wrapMode: Text.WordWrap
                    }

                    ProgressBar {
                        objectName: "moduleLaboratoryProgress"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 7 * root.uiScale
                        from: 0
                        to: 1
                        value: root.laboratoryProgress
                        Accessible.name: "Progreso del laboratorio"
                        Accessible.description: Math.round(root.laboratoryProgress * 100)
                                                + " por ciento"
                    }

                    Flickable {
                        objectName: "moduleLaboratoryOverviewMap"
                        visible: !root.advancedMode && root.overviewGroups.length > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? 34 * root.uiScale : 0
                        contentWidth: overviewRow.implicitWidth
                        contentHeight: height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Row {
                            id: overviewRow
                            spacing: 6 * root.uiScale
                            Repeater {
                                model: root.overviewGroups
                                delegate: Rectangle {
                                    id: groupChip
                                    required property int index
                                    required property var modelData
                                    readonly property bool active: String(modelData.id)
                                                                           === root.activeGroupId
                                    width: groupLabel.implicitWidth + 22 * root.uiScale
                                    height: 30 * root.uiScale
                                    radius: height / 2
                                    color: active ? Style.Theme.acento_fondo
                                                  : Style.Theme.chip_fondo
                                    border.width: active ? 2 : 1
                                    border.color: active ? Style.Theme.acento
                                                        : Style.Theme.chip_borde
                                    opacity: active ? 1 : 0.62
                                    Text {
                                        id: groupLabel
                                        anchors.centerIn: parent
                                        text: (groupChip.index + 1) + " · "
                                              + String(groupChip.modelData.label)
                                        color: groupChip.active
                                               ? Style.Theme.acento_texto
                                               : Style.Theme.chip_texto
                                        font.bold: groupChip.active
                                        font.pixelSize: Math.max(10, 11 * root.uiScale)
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.goToGroup(groupChip.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            GridLayout {
                id: workspace
                visible: root.analysis.module_id === root.moduleId
                objectName: "moduleLaboratoryWorkspace"
                Layout.fillWidth: true
                Layout.leftMargin: 24 * root.uiScale
                Layout.rightMargin: 24 * root.uiScale
                // El modo medio evita comprimir la escena: pasos arriba y la
                // animación a todo el ancho debajo.
                implicitHeight: root.workspacePreferredHeight
                Layout.preferredHeight: root.workspacePreferredHeight
                Layout.minimumHeight: root.workspacePreferredHeight
                Layout.maximumHeight: root.workspacePreferredHeight
                columns: root.wideLayout && root.advancedMode ? 2 : 1
                columnSpacing: 12 * root.uiScale
                rowSpacing: 12 * root.uiScale

                RectanglePrincipal {
                    objectName: "moduleLaboratoryStepPane"
                    visible: root.advancedMode
                    Layout.fillWidth: !root.wideLayout
                    Layout.preferredWidth: root.wideLayout ? 255 * root.uiScale : 0
                    Layout.preferredHeight: root.wideLayout
                                            ? 590 * root.uiScale
                                            : (root.mediumLayout
                                               ? 230 * root.uiScale
                                               : 240 * root.uiScale)
                    Layout.fillHeight: root.wideLayout
                    sx: root.uiScale; sy: root.uiScale
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12 * root.uiScale
                        spacing: 8 * root.uiScale
                        Text {
                            Layout.fillWidth: true
                            text: "OPERACIONES DEL MÓDULO"
                            color: Style.Theme.acento_fuerte
                            font.bold: true
                            font.pixelSize: 9 * root.uiScale
                            font.letterSpacing: 0.6
                        }

                        ListView {
                            id: stepList
                            objectName: "moduleLaboratoryStepList"
                            visible: root.advancedMode
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            orientation: root.compactLayout
                                         ? ListView.Horizontal : ListView.Vertical
                            spacing: 6 * root.uiScale
                            clip: true
                            model: root.steps
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.horizontal: ScrollBar {
                                policy: root.compactLayout
                                        ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                            }
                            ScrollBar.vertical: ScrollBar {
                                policy: root.compactLayout
                                        ? ScrollBar.AlwaysOff : ScrollBar.AsNeeded
                            }
                            delegate: Rectangle {
                                id: stepDelegate
                                required property int index
                                required property var modelData
                                width: root.compactLayout ? 170 * root.uiScale : ListView.view.width
                                height: root.compactLayout ? ListView.view.height - 8 * root.uiScale : 68 * root.uiScale
                                radius: 9 * root.uiScale
                                color: stepDelegate.index === root.safeStepIndex ? Style.Theme.acento_fondo : Style.Theme.superficie_alterna
                                border.width: stepDelegate.index === root.safeStepIndex ? 2 : 1
                                border.color: stepDelegate.index === root.safeStepIndex ? Style.Theme.acento : Style.Theme.borde_suave
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8 * root.uiScale
                                    spacing: 8 * root.uiScale
                                    Rectangle {
                                        Layout.preferredWidth: 28 * root.uiScale
                                        Layout.preferredHeight: 28 * root.uiScale
                                        radius: width / 2
                                        color: stepDelegate.index <= root.safeStepIndex ? Style.Theme.acento : Style.Theme.chip_fondo
                                        Text { anchors.centerIn: parent; text: stepDelegate.index + 1; color: stepDelegate.index <= root.safeStepIndex ? Style.Theme.texto_sobre_acento : Style.Theme.texto_secundario; font.bold: true; font.pixelSize: 10 * root.uiScale }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        spacing: 1
                                        Text { Layout.fillWidth: true; text: stepDelegate.modelData.title || "Paso"; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: Math.max(11, 12 * root.uiScale); maximumLineCount: 2; elide: Text.ElideRight; wrapMode: Text.WordWrap }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentStepIndex = stepDelegate.index
                                        root.resetDiscovery(false)
                                    }
                                }
                            }
                        }
                    }
                }

                RectanglePrincipal {
                    objectName: "moduleLaboratoryVisualPane"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: root.narrowLayout
                                            ? 860 * root.uiScale : 590 * root.uiScale
                    Layout.fillHeight: !root.narrowLayout
                    sx: root.uiScale; sy: root.uiScale
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12 * root.uiScale
                        spacing: 8 * root.uiScale
                        RowLayout {
                            visible: root.advancedMode
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? 32 * root.uiScale : 0
                            spacing: 8 * root.uiScale
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 1
                                Text {
                                    objectName: "moduleLaboratoryCaptureSummary"
                                    visible: root.advancedMode
                                    Layout.fillWidth: true
                                    text: Boolean(root.currentPanel.key)
                                          ? String(root.currentPanel.title || "Tensor real")
                                            + " · forma ["
                                            + (root.currentPanel.shape || []).join(" × ") + "]"
                                          : String(root.currentStep.input || "Entrada")
                                            + " → " + String(root.currentStep.output || "Salida")
                                    color: Style.Theme.acento_fuerte
                                    font.family: Style.Theme.fuente_mono
                                    font.pixelSize: 10 * root.uiScale
                                    elide: Text.ElideRight
                                }
                            }
                            BotonSecundario {
                                objectName: "moduleLaboratoryDetachGuide"
                                visible: root.advancedMode
                                Layout.preferredWidth: 180 * root.uiScale
                                Layout.preferredHeight: 32 * root.uiScale
                                sx: root.uiScale; sy: root.uiScale
                                text: root.guideDetached
                                      ? "Cerrar explicación"
                                      : "Separar explicación ↗"
                                onClicked: root.toggleGuide()
                            }
                        }

                        TabBar {
                            id: workspaceTabs
                            objectName: "moduleLaboratoryWorkspaceTabs"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42 * root.uiScale
                            currentIndex: root.workspaceSection
                            spacing: 4 * root.uiScale
                            Accessible.name: "Contenido de la operación actual"
                            Accessible.description: "Muestra una vista a la vez"
                            onCurrentIndexChanged: {
                                root.workspaceSection = currentIndex
                                if (currentIndex === 1)
                                    formulaScene.replay()
                            }
                            background: Rectangle {
                                radius: 9 * root.uiScale
                                color: Style.Theme.superficie_alterna
                                border.color: Style.Theme.borde_suave
                            }
                            PestanaAccesible {
                                objectName: "moduleLaboratoryAnimationTab"
                                text: "Vista general"
                            }
                            PestanaAccesible {
                                objectName: "moduleLaboratoryFormulaTab"
                                text: "Animación detallada"
                            }
                            PestanaAccesible {
                                objectName: "moduleLaboratoryExplanationTab"
                                text: root.discoveryStage < 5
                                      ? "Reto guiado" : "Explicación"
                            }
                        }

                        StackLayout {
                            objectName: "moduleLaboratoryFocusStack"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            currentIndex: root.workspaceSection

                            ModuleLaboratoryVisualization {
                                id: visualization
                                objectName: "moduleLaboratoryVisualization"
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                moduleId: root.moduleId
                                analysis: root.analysis
                                step: root.currentStep
                                stepIndex: root.safeStepIndex
                                mode: root.mode
                                selectedLayer: Math.round(layerSlider.value)
                                selectedHead: Math.round(headSlider.value)
                                selectedToken: Math.round(tokenSlider.value)
                                showContextChrome: false
                                sx: root.uiScale; sy: root.uiScale
                                onInspectRequested: function(panel) { root.openValues(panel) }
                            }

                            FormulaAnimationScene {
                                id: formulaScene
                                objectName: "moduleLaboratoryFormulaScene"
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                step: root.currentStep
                                demo: root.currentFormulaDemo
                                formulaExplanation: animationGuide.formulaReadingText
                                reducedMotion: Style.Theme.movimientoReducido
                                sx: root.uiScale; sy: root.uiScale
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                LaboratoryDiscoveryCycle {
                                    id: discoveryCycle
                                    anchors.fill: parent
                                    visible: root.discoveryStage < 5
                                    challenge: root.discoveryChallenge
                                    step: root.currentStep
                                    stage: root.discoveryStage
                                    selectedPrediction: root.discoveryPrediction
                                    correctPrediction: Number(root.predictionBundle.correct)
                                    predictionOptions: root.predictionBundle.options || []
                                    selectedExplanation: root.discoveryExplanation
                                    correctExplanation: Number(root.explanationBundle.correct)
                                    explanationOptions: root.explanationBundle.options || []
                                    experimentTitle: String(root.experimentDescriptor.title
                                                            || "Modifica una condición")
                                    experimentSubtitle: String(root.experimentDescriptor.subtitle
                                                               || "El cambio se aplica al cálculo real de esta operación.")
                                    experimentInstruction: String(root.experimentDescriptor.instruction || "")
                                    experimentActionLabel: String(root.experimentDescriptor.label || "Probar cambio")
                                    observationPrompt: "Sigue «"
                                                       + String(root.currentStep.input || "la entrada")
                                                       + "» hasta «"
                                                       + String(root.currentStep.output || "la salida")
                                                       + "». Identifica en qué fase actúa "
                                                       + String(root.currentStep.formula || "la fórmula") + "."
                                    explanationHint: root.discoveryHint
                                    sx: root.uiScale; sy: root.uiScale
                                    onPredictionSelected: function(optionIndex) {
                                        root.discoveryPrediction = optionIndex
                                    }
                                    onPredictionConfirmed: root.confirmDiscoveryPrediction()
                                    onExperimentRequested: root.applySuggestedExperiment()
                                    onObservationConfirmed: root.confirmDiscoveryObservation()
                                    onExplanationSelected: function(optionIndex) {
                                        root.discoveryExplanation = optionIndex
                                        root.discoveryHint = ""
                                    }
                                    onExplanationChecked: root.checkDiscoveryExplanation()
                                    onExplanationRequested: root.revealDiscoveryExplanation()
                                }

                                LaboratoryAnimationGuide {
                                    id: animationGuide
                                    objectName: "moduleLaboratoryAnimationGuide"
                                    anchors.fill: parent
                                    visible: root.discoveryStage >= 5
                                    moduleId: root.moduleId
                                    mode: root.mode
                                    steps: root.steps
                                    step: root.currentStep
                                    panel: root.currentPanel
                                    analysis: root.analysis
                                    demo: root.currentFormulaDemo
                                    stepIndex: root.safeStepIndex
                                    essentialMode: !root.advancedMode
                                    sx: root.uiScale
                                    sy: root.uiScale
                                    onInspectRequested: function(panel) { root.openValues(panel) }
                                }
                            }
                        }
                    }
                }

            }

            Item {
                id: advancedPracticeHost
                objectName: "moduleLaboratoryAdvancedPracticeHost"
                visible: root.analysis.module_id === root.moduleId
                Layout.fillWidth: true
                Layout.leftMargin: 24 * root.uiScale
                Layout.rightMargin: 24 * root.uiScale
                Layout.preferredHeight: visible ? practiceCard.implicitHeight : 0
            }

            Item { Layout.fillWidth: true; Layout.preferredHeight: 18 * root.uiScale }
        }
    }

    Window {
        id: detachedGuideWindow
        objectName: "moduleLaboratoryDetachedGuideWindow"
        visible: root.guideDetached
        transientParent: root.Window.window
        modality: Qt.NonModal
        minimumWidth: 560
        minimumHeight: 640
        width: Math.max(minimumWidth, Math.min(820, root.width * 0.52))
        height: Math.max(minimumHeight, Math.min(920, root.height * 0.92))
        title: "Explicación · " + String(root.currentStep.title || "Etapa")
        color: Style.Theme.superficie_alterna

        Component.onCompleted: {
            if (typeof displayManager !== "undefined" && displayManager)
                displayManager.registerAuxiliaryWindow(detachedGuideWindow, true)
        }
        onVisibleChanged: {
            if (visible
                    && typeof displayManager !== "undefined"
                    && displayManager
                    && displayManager.hasSecondaryScreen)
                displayManager.placeAuxiliaryWindow(detachedGuideWindow, true)
        }
        onClosing: function(close) {
            if (root.guideDetached)
                root.closeDetachedGuide()
            close.accepted = true
        }
    }

    LaboratoryAnimationGuide {
        id: detachedAnimationGuide
        objectName: "moduleLaboratoryDetachedAnimationGuide"
        parent: detachedGuideWindow.contentItem
        anchors.fill: parent
        anchors.margins: 10
        visible: root.guideDetached
        moduleId: root.moduleId
        mode: root.mode
        steps: root.steps
        step: root.currentStep
        panel: root.currentPanel
        analysis: root.analysis
        demo: root.currentFormulaDemo
        stepIndex: root.safeStepIndex
        essentialMode: false
        sx: Math.max(0.96, Math.min(1.16,
                                   detachedGuideWindow.width / 700))
        sy: Math.max(0.96, Math.min(1.16,
                                   detachedGuideWindow.height / 820))
        onInspectRequested: function(panel) { root.openValues(panel) }
    }

    Dialog {
        id: valuesDialog
        modal: true
        anchors.centerIn: parent
        width: Math.min(root.width - 36, 920 * root.uiScale)
        height: Math.min(root.height - 36, 650 * root.uiScale)
        title: root.inspectedTitle + " · valores originales"
        standardButtons: Dialog.Close
        ColumnLayout {
            anchors.fill: parent
            spacing: 9 * root.uiScale
            Text {
                Layout.fillWidth: true
                text: "Forma original [" + (root.inspectedPanel.shape || []).join(" × ") + "] · elementos " + (root.valueOffset + 1) + "–" + Math.min(root.valueOffset + root.pageValues.length, root.laboratoryController.fullValueLength(root.inspectedKey)) + " de " + root.laboratoryController.fullValueLength(root.inspectedKey)
                color: Style.Theme.texto_secundario_fuerte
                font.pixelSize: 11 * root.uiScale
                wrapMode: Text.WordWrap
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 190 * root.uiScale
                radius: 9 * root.uiScale
                color: Style.Theme.superficie_alterna
                border.color: Style.Theme.borde_suave
                ScientificMatrix { anchors.fill: parent; anchors.margins: 10 * root.uiScale; matrix: root.inspectedPanel.matrix || []; valueKind: ValueKinds.of(root.inspectedPanel); colorMode: root.inspectedPanel.color_mode || "diverging"; localScale: true; alternativeText: "Vista matricial de " + root.inspectedTitle }
            }
            GridView {
                id: valueGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.pageValues
                cellWidth: Math.max(112 * root.uiScale,
                                    width / Math.max(1, Math.floor(
                                        width / (132 * root.uiScale))))
                cellHeight: 44 * root.uiScale
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Rectangle {
                    id: valueCell
                    required property int index
                    required property var modelData
                    width: valueGrid.cellWidth - 6 * root.uiScale
                    height: valueGrid.cellHeight - 6 * root.uiScale
                    radius: 7 * root.uiScale
                    color: Style.Theme.superficie_alterna
                    border.color: Style.Theme.borde_suave
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 12 * root.uiScale
                        spacing: 1
                        Text {
                            width: parent.width
                            text: root.valueCoordinate(valueCell.index)
                            color: Style.Theme.texto_terciario
                            font.pixelSize: 8 * root.uiScale
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: root.formattedValue(valueCell.modelData,
                                                      ValueKinds.of(root.inspectedPanel))
                            color: Style.Theme.texto_primario
                            font.family: Style.Theme.fuente_mono
                            font.bold: true
                            font.pixelSize: 9 * root.uiScale
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                BotonPrincipal { Layout.preferredWidth: 145 * root.uiScale; Layout.preferredHeight: 34 * root.uiScale; text: "← Anteriores"; enabled: root.valueOffset > 0; opacity: enabled ? 1 : 0.4; onClicked: { root.valueOffset = Math.max(0, root.valueOffset - 128); root.loadValuePage() } }
                BotonPrincipal { Layout.preferredWidth: 145 * root.uiScale; Layout.preferredHeight: 34 * root.uiScale; text: "Siguientes →"; enabled: root.valueOffset + root.pageValues.length < root.laboratoryController.fullValueLength(root.inspectedKey); opacity: enabled ? 1 : 0.4; onClicked: { root.valueOffset += 128; root.loadValuePage() } }
            }
        }
    }

}
