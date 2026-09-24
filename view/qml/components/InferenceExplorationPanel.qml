pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "../styles" as Style

Item {
    id: root
    objectName: "inferenceExplorationPanel"

    property var snapshots: []
    property var detailForward: ({})
    property int selectedIndex: snapshots.length > 0 ? snapshots.length - 1 : -1
    property bool canGenerateNext: false
    property bool tokenProcessing: false
    property real sx: 1
    property real sy: 1

    property int stageIndex: 0
    property int operationIndex: 0
    property int branchIndex: 0 // 0 encoder · 1 decoder causal · 2 cross-attention
    property int layerIndex: Math.max(0, Number(metadata.num_layers || 1) - 1)
    property int headIndex: 0
    property bool residualUsesFfn: false
    property bool reducedMotion: false
    property bool sequencePlaying: false
    property bool detailsExpanded: false
    // La transformacion abre como protagonista. La explicacion y su minimapa
    // siguen disponibles, pero ya no compiten por espacio hasta solicitarlos.
    property bool guideVisible: false
    property bool locationMapVisible: false
    property bool guideDetached: false
    // La escala efectiva nace del espacio real del panel, no de una
    // resolucion de escritorio asumida. Los limites conservan legibilidad.
    readonly property bool condensedWidth: width < 1100
    readonly property bool compactWidth: width < 840
    readonly property bool veryCompactWidth: width < 680
    readonly property bool denseHeight: height < 700
    readonly property bool veryShortHeight: height < 560
    property bool compactGuideOpen: false
    readonly property bool effectiveGuideVisible: guideVisible
                                                       && (guideDetached
                                                           || !compactWidth
                                                           || compactGuideOpen)
    readonly property real uiSx: Math.max(0.72, Math.min(1, sx, width / 1230))
    readonly property real uiSy: Math.max(0.68, Math.min(1, sy, height / 772))
    readonly property real sceneSx: Math.max(
        0.68, Math.min(1, uiSx,
                       animationViewport.width > 0 ? animationViewport.width / 820 : 1))
    readonly property real sceneSy: Math.max(
        0.60, Math.min(1, uiSy,
                       animationViewport.height > 0 ? animationViewport.height / 500 : 1))
    readonly property real tokenChipHeight: Math.max(30, 34 * uiSy)
    readonly property real tokenRibbonHeight: veryShortHeight
                                                   ? Math.max(44, 46 * uiSy)
                                                   : Math.max(52, 56 * uiSy)
    readonly property bool tokenRibbonFits: promptTokenList.height + 0.5 >= tokenChipHeight
                                                   && outputTokenList.height + 0.5 >= tokenChipHeight
    readonly property int guidedStepDuration: 9000
    readonly property var pedagogicalColors: [
        { label: "Estructura / flujo", mark: "→", accent: Style.Theme.inferencia_estructura, onAccent: Style.Theme.inferencia_sobre_estructura },
        { label: "Contexto", mark: "↔", accent: Style.Theme.inferencia_contexto, onAccent: Style.Theme.inferencia_sobre_contexto },
        { label: "Transformación", mark: "⚙", accent: Style.Theme.inferencia_transformacion, onAccent: Style.Theme.inferencia_sobre_transformacion },
        { label: "Foco / selección", mark: "◆", accent: Style.Theme.inferencia_foco, onAccent: Style.Theme.inferencia_sobre_foco },
        { label: "Resultado", mark: "✓", accent: Style.Theme.inferencia_resultado, onAccent: Style.Theme.inferencia_sobre_resultado },
        { label: "Solo error", mark: "!", accent: Style.Theme.inferencia_error, onAccent: Style.Theme.inferencia_sobre_error }
    ]

    // Las 31 operaciones siguen disponibles, pero la orientacion principal
    // se resume en cuatro etapas que corresponden al recorrido completo.
    readonly property var processChapters: [
        {
            id: "encoder",
            label: "Encoder",
            caption: "comprende el prompt",
            accent: Style.Theme.inferencia_estructura,
            onAccent: Style.Theme.inferencia_sobre_estructura
        },
        {
            id: "decoder_causal",
            label: "Decoder causal",
            caption: "usa lo ya generado",
            accent: Style.Theme.inferencia_transformacion,
            onAccent: Style.Theme.inferencia_sobre_transformacion
        },
        {
            id: "cross_attention",
            label: "Decoder + contexto",
            caption: "consulta el prompt y refina",
            accent: Style.Theme.inferencia_contexto,
            onAccent: Style.Theme.inferencia_sobre_contexto
        },
        {
            id: "output",
            label: "Salida",
            caption: "elige el próximo token",
            accent: Style.Theme.inferencia_foco,
            onAccent: Style.Theme.inferencia_sobre_foco
        }
    ]
    readonly property int processChapterIndex: chapterForOperation(operationIndex)
    readonly property var currentProcessChapter: processChapters[
        Math.max(0, Math.min(processChapters.length - 1, processChapterIndex))]
    readonly property int chapterStep: chapterStepForOperation(operationIndex)
    readonly property int chapterStepCount: chapterStepCountForOperation(operationIndex)
    readonly property color processAccent: currentProcessChapter.accent || Style.Theme.acento

    readonly property var currentSnapshot: selectedIndex >= 0 && selectedIndex < snapshots.length
                                                   ? snapshots[selectedIndex] : null
    readonly property bool detailAvailable: currentSnapshot !== null
                                               && selectedIndex === snapshots.length - 1
                                               && detailForward
                                               && detailForward.metadata !== undefined
    readonly property var metadata: detailAvailable ? detailForward.metadata : ({})
    readonly property var globalData: detailAvailable && detailForward["global"]
                                               ? detailForward["global"] : ({})
    readonly property var currentLayers: {
        if (!detailAvailable)
            return []
        return branchIndex === 0 ? (detailForward.encoder || [])
                                 : (detailForward.decoder || [])
    }
    readonly property var currentLayer: currentLayers.length
                                            ? currentLayers[Math.max(0, Math.min(currentLayers.length - 1,
                                                                                 layerIndex))]
                                            : ({})
    readonly property var currentAttention: {
        if (!currentLayer)
            return ({})
        if (branchIndex === 0)
            return currentLayer.atencion || ({})
        if (branchIndex === 1)
            return currentLayer.autoatencion || ({})
        return currentLayer.atencion_cruzada || ({})
    }
    readonly property var currentFfn: currentLayer && currentLayer.ffn
                                           ? currentLayer.ffn : ({})
    readonly property var currentResidual: {
        if (!currentLayer)
            return ({})
        if (residualUsesFfn)
            return currentLayer.residual_ffn || ({})
        if (branchIndex === 0)
            return currentLayer.residual_atencion || ({})
        if (branchIndex === 1)
            return currentLayer.residual_autoatencion || ({})
        return currentLayer.residual_cruzada || ({})
    }
    readonly property var currentTokens: {
        if (!currentSnapshot)
            return []
        if (branchIndex === 0)
            return currentSnapshot.tokens_entrada || []
        return currentSnapshot.tokens_decoder || currentSnapshot.tokens_salida || []
    }
    readonly property var keyTokens: branchIndex === 2 && currentSnapshot
                                         ? (currentSnapshot.tokens_entrada || [])
                                         : currentTokens
    readonly property var currentProjection: {
        if (!detailAvailable)
            return ({})
        return branchIndex === 0
                ? (globalData.proyeccion_posicional_encoder || ({}))
                : (globalData.proyeccion_posicional_decoder || ({}))
    }
    readonly property var currentEmbeddingTensor: {
        if (!detailAvailable)
            return ({})
        return branchIndex === 0
                ? (globalData.embedding_encoder_escalado || ({}))
                : (globalData.embedding_decoder_escalado || ({}))
    }
    readonly property var currentHiddenTensor: detailAvailable
                                                   ? (globalData.salida_decoder || ({}))
                                                   : ({})
    readonly property var currentTrajectory: {
        if (!detailAvailable || !detailForward.trayectorias)
            return ({})
        return branchIndex === 0
                ? (detailForward.trayectorias.encoder || ({}))
                : (detailForward.trayectorias.decoder || ({}))
    }

    readonly property var stages: [
        {
            short: "Embeddings + posición",
            conceptId: "combinacion_embedding_pe",
            eyebrow: "01 · DEL ID AL VECTOR",
            title: "El orden deforma el significado",
            accent: Style.Theme.inferencia_estructura,
            onAccent: Style.Theme.inferencia_sobre_estructura,
            concept: "Cada token parte de su embedding escalado. Al sumar el encoding posicional, el vector se desplaza de verdad: no recibe una etiqueta aparte.",
            formula: "X₀ = E · √d_model + PE",
            hint: "Reproduce la transición o arrastra el control. El color sigue el índice posicional.",
            caveat: "PCA es una proyección 2D: puede distorsionar distancias y no representa exactamente el espacio original."
        },
        {
            short: "Flujo de atención",
            conceptId: "formula_attention_completa",
            eyebrow: "02 · SELF-ATTENTION",
            title: "La información viaja entre tokens",
            accent: Style.Theme.inferencia_contexto,
            onAccent: Style.Theme.inferencia_sobre_contexto,
            concept: "Cada curva sale de una query y llega a la key que consulta. El grosor y la opacidad provienen del peso de atención real de la cabeza elegida.",
            formula: "A = softmax(QKᵀ / √d_head + máscara)",
            hint: "Pasa el cursor sobre un token para activar la vista linterna. También puedes comparar todas las cabezas.",
            caveat: "Un peso de atención describe una mezcla interna; por sí solo no demuestra causalidad."
        },
        {
            short: "Split + merge",
            conceptId: "problema_multi_head",
            eyebrow: "03 · MULTI-HEAD",
            title: "Una partición, no varias copias",
            accent: Style.Theme.inferencia_transformacion,
            onAccent: Style.Theme.inferencia_sobre_transformacion,
            concept: "d_model se divide en h subespacios de d_head dimensiones. Las cabezas trabajan en paralelo, se concatenan y Wᴼ vuelve a mezclar sus resultados.",
            formula: "MHA = Concat(head₁ … headₕ) Wᴼ",
            hint: "Sigue un color desde el segmento original hasta concat; la malla final representa Wᴼ.",
            caveat: "Concat recupera d_model, pero la salida todavía pasa por una proyección lineal aprendida."
        },
        {
            short: "FFN",
            conceptId: "que_es_ffn",
            eyebrow: "04 · EXPANDIR Y COMPRIMIR",
            title: "La misma red, respuestas distintas",
            accent: Style.Theme.inferencia_transformacion,
            onAccent: Style.Theme.inferencia_sobre_transformacion,
            concept: "Cada token atraviesa de forma independiente los mismos pesos: primero se expande a d_ff, aplica la activación real y vuelve a d_model.",
            formula: "FFN(x) = W₂ φ(W₁x + b₁) + b₂",
            hint: "Compara hasta tres tokens en paralelo y observa cómo cambia su patrón aunque compartan la red.",
            caveat: "ReLU recorta negativos; GELU los atenúa de forma suave. La escena usa la activación configurada."
        },
        {
            short: "Residual + Norm",
            conceptId: "flujo_add_norm",
            eyebrow: "05 · CONSERVAR Y ESTABILIZAR",
            title: "Un atajo para la señal original",
            accent: Style.Theme.inferencia_resultado,
            onAccent: Style.Theme.inferencia_sobre_resultado,
            concept: "La ruta identidad conserva x mientras la subcapa calcula Δx. Se suman —no se concatenan— y LayerNorm recentra, reescala y aplica γ y β.",
            formula: "y = LayerNorm(x + Dropout(Δx))",
            hint: "Alterna el atajo para comparar. Debajo, recorre las cuatro fases reales de LayerNorm.",
            caveat: "Este modelo usa post-norm: la normalización ocurre después de la suma residual."
        },
        {
            short: "Rascacielos",
            conceptId: "contextualizacion",
            eyebrow: "06 · TRAYECTORIA POR CAPAS",
            title: "El contexto reorganiza cada piso",
            accent: Style.Theme.inferencia_estructura,
            onAccent: Style.Theme.inferencia_sobre_estructura,
            concept: "Cada piso proyecta los hidden states de una capa. Selecciona un token y síguelo mientras cambia su vecindario a través del Transformer.",
            formula: "X₀ → bloque₁(X₀) → … → bloque_L(X)",
            hint: "Desplázate verticalmente; el token resaltado conserva identidad y color en todos los pisos.",
            caveat: "Todos los pisos comparten un único PCA alineado. Aun así, las distancias 2D siguen siendo una aproximación."
        },
        {
            short: "Carrera softmax",
            conceptId: "seleccion_token",
            eyebrow: "07 · SIGUIENTE TOKEN",
            title: "El contexto cambia la clasificación",
            accent: Style.Theme.inferencia_foco,
            onAccent: Style.Theme.inferencia_sobre_foco,
            concept: "Cada vuelta autoregresiva produce una nueva distribución. Las barras cambian de longitud y rango cuando el contexto favorece candidatos distintos.",
            formula: "p(token | contexto) = softmax(logits filtrados)",
            hint: "Reproduce el historial o avanza contexto por contexto para seguir a cada candidato.",
            caveat: "Las barras muestran el top capturado; «resto» completa la masa de probabilidad hasta 1."
        }
    ]
    readonly property var flowSteps: flowModel.steps
    readonly property var operation: flowSteps.length
                                             ? flowSteps[Math.max(0, Math.min(flowSteps.length - 1,
                                                                              operationIndex))]
                                             : ({})
    readonly property bool operationDataAvailable: detailAvailable
                                                       || !Boolean(operation.requiresDetail)
    readonly property var stage: stages[Math.max(0, Math.min(stages.length - 1,
                                                             stageIndex))]

    signal closeRequested()
    signal stepSelected(int index)
    signal nextTokenRequested()
    signal theoryRequested(string conceptId)

    function clampSelections() {
        var layers = Math.max(1, Number(metadata.num_layers || 1))
        var heads = Math.max(1, Number(metadata.num_heads || 1))
        layerIndex = Math.max(0, Math.min(layers - 1, layerIndex))
        headIndex = Math.max(0, Math.min(heads - 1, headIndex))
    }

    function setStage(index) {
        var bounded = Math.max(0, Math.min(stages.length - 1, index))
        for (var preferred = 0; preferred < flowSteps.length; ++preferred) {
            if (Number(flowSteps[preferred].stageIndex) === bounded
                    && Number(flowSteps[preferred].branchIndex) === branchIndex) {
                selectOperation(preferred)
                return
            }
        }
        for (var fallback = 0; fallback < flowSteps.length; ++fallback) {
            if (Number(flowSteps[fallback].stageIndex) === bounded) {
                selectOperation(fallback)
                return
            }
        }
    }

    function chapterForStep(flowStep) {
        var operationId = String(flowStep && flowStep.id || "")
        if (operationId.indexOf("encoder_") === 0)
            return 0
        if (operationId.indexOf("linear_") === 0
                || operationId.indexOf("output_") === 0)
            return 3
        if (operationId.indexOf("decoder_cross_") === 0
                || operationId.indexOf("decoder_addnorm_cross") === 0
                || operationId === "decoder_ffn"
                || operationId === "decoder_addnorm_ffn"
                || operationId === "decoder_layers")
            return 2
        return 1
    }

    function chapterForOperation(index) {
        if (!flowSteps.length)
            return 0
        var bounded = Math.max(0, Math.min(flowSteps.length - 1, index))
        return chapterForStep(flowSteps[bounded])
    }

    function chapterStepForOperation(index) {
        if (!flowSteps.length)
            return 0
        var bounded = Math.max(0, Math.min(flowSteps.length - 1, index))
        var chapter = chapterForOperation(bounded)
        var count = 0
        for (var stepIndex = 0; stepIndex <= bounded; ++stepIndex) {
            if (chapterForStep(flowSteps[stepIndex]) === chapter)
                count += 1
        }
        return count
    }

    function chapterStepCountForOperation(index) {
        var chapter = chapterForOperation(index)
        var count = 0
        for (var stepIndex = 0; stepIndex < flowSteps.length; ++stepIndex) {
            if (chapterForStep(flowSteps[stepIndex]) === chapter)
                count += 1
        }
        return count
    }

    function firstOperationForChapter(chapter) {
        for (var stepIndex = 0; stepIndex < flowSteps.length; ++stepIndex) {
            if (chapterForStep(flowSteps[stepIndex]) === chapter)
                return stepIndex
        }
        return -1
    }

    function selectChapter(index) {
        var bounded = Math.max(0, Math.min(processChapters.length - 1, index))
        var firstOperation = firstOperationForChapter(bounded)
        if (firstOperation >= 0)
            selectOperation(firstOperation)
    }

    function selectSnapshot(index) {
        stepSelected(index)
        // Los snapshots historicos conservan la distribucion de salida, no
        // todos los tensores. Abrirlos directamente en Softmax evita una
        // pantalla de bloqueo que podia parecer un error del usuario.
        if (index >= 0 && index < snapshots.length - 1)
            selectOperation(flowSteps.length - 1)
    }

    function resetPedagogicalReading() {
        detailsExpanded = false
        Qt.callLater(function() {
            if (pedagogicalScroll.contentItem)
                pedagogicalScroll.contentItem.contentY = 0
        })
    }

    function setBranch(index) {
        var bounded = Math.max(0, Math.min(2, index))
        var kind = operationKind(operation.id || "")
        for (var candidate = 0; candidate < flowSteps.length; ++candidate) {
            if (Number(flowSteps[candidate].branchIndex) === bounded
                    && operationKind(flowSteps[candidate].id) === kind) {
                selectOperation(candidate)
                return
            }
        }
        for (var first = 0; first < flowSteps.length; ++first) {
            if (Number(flowSteps[first].branchIndex) === bounded) {
                selectOperation(first)
                return
            }
        }
        branchIndex = bounded
        clampSelections()
    }

    function operationKind(operationId) {
        var value = String(operationId || "")
        if (value.indexOf("addnorm_ffn") !== -1)
            return "addnorm_ffn"
        if (value.indexOf("addnorm") !== -1)
            return "addnorm_attention"
        var kinds = ["embedding", "position", "qkv", "scores", "mask",
                     "softmax", "weighted", "multihead", "ffn", "layers"]
        for (var index = 0; index < kinds.length; ++index) {
            if (value.indexOf(kinds[index]) !== -1)
                return kinds[index]
        }
        return value
    }

    function synchronizeOperation() {
        if (!flowSteps.length)
            return
        var selectedOperation = flowSteps[Math.max(
            0, Math.min(flowSteps.length - 1, operationIndex))]
        if (!selectedOperation || selectedOperation.id === undefined)
            return
        stageIndex = Number(selectedOperation.stageIndex || 0)
        branchIndex = Number(selectedOperation.branchIndex || 0)
        residualUsesFfn = Boolean(selectedOperation.residualUsesFfn)
        clampSelections()
    }

    function setOperation(index) {
        var bounded = Math.max(0, Math.min(flowSteps.length - 1, index))
        if (operationIndex === bounded)
            synchronizeOperation()
        else
            operationIndex = bounded
    }

    function selectOperation(index) {
        sequencePlaying = false
        setOperation(index)
    }

    function previousOperation() {
        selectOperation(operationIndex - 1)
    }

    function nextOperation() {
        selectOperation(operationIndex + 1)
    }

    function toggleResidualStep() {
        var wantedFfn = !residualUsesFfn
        for (var index = 0; index < flowSteps.length; ++index) {
            var candidate = flowSteps[index]
            if (Number(candidate.branchIndex) === branchIndex
                    && Number(candidate.stageIndex) === 4
                    && Boolean(candidate.residualUsesFfn) === wantedFfn) {
                selectOperation(index)
                return
            }
        }
    }

    function sectionLabel(section) {
        if (section === "encoder")
            return "ENCODER"
        if (section === "decoder")
            return "DECODER"
        return "SALIDA"
    }

    function sectionProgress() {
        var section = operation.section || ""
        var current = 0
        var total = 0
        for (var index = 0; index < flowSteps.length; ++index) {
            if (flowSteps[index].section === section) {
                total += 1
                if (index <= operationIndex)
                    current += 1
            }
        }
        return current + "/" + total
    }

    function branchLabel() {
        return ["Encoder", "Decoder causal", "Atención cruzada"][branchIndex]
    }

    function evidenceText() {
        if (!detailAvailable && stageIndex < 6)
            return "Selecciona el token más reciente para recuperar su captura tensorial."
        if (stageIndex === 0)
            return "d_model " + Number(metadata.d_model || 0)
                    + " · varianza PCA "
                    + (Number(currentProjection.varianza_conservada || 0) * 100).toFixed(1) + "%"
        if (stageIndex === 1)
            return branchLabel() + " · capa " + (layerIndex + 1)
                    + " · cabeza H" + String(headIndex + 1).padStart(2, "0")
        if (stageIndex === 2)
            return Number(metadata.num_heads || 0) + " cabezas × "
                    + Number(metadata.d_head || 0) + " dims = d_model "
                    + Number(metadata.d_model || 0)
        if (stageIndex === 3)
            return (currentFfn.shape_entrada || "—") + " → "
                    + (currentFfn.shape_oculta || "—") + " → "
                    + (currentFfn.shape_salida || "—")
        if (stageIndex === 4)
            return (residualUsesFfn ? "Residual FFN" : "Residual atención")
                    + " · capa " + (layerIndex + 1) + " · post-norm"
        if (stageIndex === 5)
            return "PCA conjunto · " + ((currentTrajectory.capas || []).length) + " pisos"
        if (!currentSnapshot)
            return "Genera al menos un token para iniciar la carrera."
        return snapshots.length + " contextos · Σp = "
                + Number(currentSnapshot.validacion ? currentSnapshot.validacion.suma_probabilidades : 0).toFixed(4)
    }

    function operationEvidenceText() {
        if (Boolean(operation.requiresDetail) && !detailAvailable)
            return "Selecciona el token mas reciente para recuperar su captura tensorial."
        var operationId = String(operation.id || "")
        if (operationId.indexOf("embedding") !== -1)
            return (currentEmbeddingTensor.shape || "-") + " \u00b7 d_model "
                    + Number(metadata.d_model || 0) + " \u00b7 valores reales"
        if (operationId.indexOf("position") !== -1)
            return "d_model " + Number(metadata.d_model || 0)
                    + " \u00b7 varianza PCA "
                    + (Number(currentProjection.varianza_conservada || 0) * 100).toFixed(1) + "%"
        if (operationId.indexOf("qkv") !== -1)
            return "Q " + (currentAttention.shape_q || "-") + " \u00b7 K "
                    + (currentAttention.shape_k || "-") + " \u00b7 V "
                    + (currentAttention.shape_v || "-")
        if (operationId.indexOf("scores") !== -1)
            return branchLabel() + " \u00b7 capa " + (layerIndex + 1)
                    + " \u00b7 captura " + (currentAttention.displayed_shape || "-")
        if (operationId.indexOf("mask") !== -1 && operationId.indexOf("addnorm") === -1)
            return "Bloqueado " + Number((currentAttention.validacion || {}).porcentaje_bloqueado || 0).toFixed(1)
                    + "% \u00b7 peso maximo prohibido "
                    + Number((currentAttention.validacion || {}).maximo_peso_enmascarado || 0).toExponential(2)
        if (operationId.indexOf("softmax") !== -1 && operationId !== "output_softmax")
            return branchLabel() + " \u00b7 H" + String(headIndex + 1).padStart(2, "0")
                    + " \u00b7 error maximo \u03a3A "
                    + Number((currentAttention.validacion || {}).error_max_suma || 0).toExponential(2)
        if (operationId.indexOf("weighted") !== -1)
            return branchLabel() + " \u00b7 "
                    + ((currentAttention.contribuciones || []).length) + " cabezas capturadas"
        if (stageIndex === 2)
            return Number(metadata.num_heads || 0) + " cabezas \u00d7 "
                    + Number(metadata.d_head || 0) + " dims = d_model "
                    + Number(metadata.d_model || 0)
        if (stageIndex === 3)
            return (currentFfn.shape_entrada || "-") + " \u2192 "
                    + (currentFfn.shape_oculta || "-") + " \u2192 "
                    + (currentFfn.shape_salida || "-")
        if (stageIndex === 4)
            return (residualUsesFfn ? "Residual FFN" : "Residual atencion")
                    + " \u00b7 capa " + (layerIndex + 1) + " \u00b7 post-norm"
        if (stageIndex === 5)
            return "PCA conjunto \u00b7 " + ((currentTrajectory.capas || []).length) + " pisos"
        if (operationId === "linear_logits") {
            var linearData = detailForward.logits_lineales || detailForward.logits || ({})
            return (linearData.shape || "-") + " \u00b7 " + (linearData.dtype || "-")
                    + " \u00b7 finitos " + Boolean(linearData.sin_nan && linearData.sin_inf)
        }
        if (!currentSnapshot)
            return "Genera al menos un token para iniciar la carrera."
        return snapshots.length + " contextos \u00b7 \u03a3p = "
                + Number(currentSnapshot.validacion ? currentSnapshot.validacion.suma_probabilidades : 0).toFixed(4)
    }

    function shortStepAt(index, fallback) {
        if (index < 0 || index >= flowSteps.length)
            return fallback
        return flowSteps[index].short || fallback
    }

    function previousStepLabel() {
        return shortStepAt(operationIndex - 1, "Prompt tokenizado")
    }

    function nextStepLabel() {
        return shortStepAt(operationIndex + 1, "Token vuelve al decoder")
    }

    function operationInputLabel() {
        var operationId = String(operation.id || "")
        if (operationId.indexOf("embedding") !== -1)
            return "IDs de los tokens"
        if (operationId.indexOf("position") !== -1)
            return "embedding y se\u00f1al posicional"
        if (operationId.indexOf("qkv") !== -1)
            return branchIndex === 2
                    ? "estado del decoder y memoria del encoder"
                    : "representaciones de los tokens"
        if (operationId.indexOf("scores") !== -1)
            return "matrices Q y K"
        if (operationId === "decoder_masked_mask")
            return "scores y m\u00e1scara causal"
        if (operationId.indexOf("softmax") !== -1)
            return operationId === "output_softmax" ? "logits filtrados" : "scores permitidos"
        if (operationId.indexOf("weighted") !== -1)
            return "pesos A y vectores V"
        if (operationId.indexOf("multihead") !== -1)
            return "salidas de todas las cabezas"
        if (operationId.indexOf("addnorm") !== -1)
            return "entrada y actualizaci\u00f3n de la subcapa"
        if (operationId.indexOf("ffn") !== -1)
            return "vector contextualizado de cada token"
        if (operationId.indexOf("layers") !== -1)
            return "estado de la capa anterior"
        if (operationId === "linear_logits")
            return "\u00faltimo estado del decoder"
        return "estado del paso anterior"
    }

    function operationOutputLabel() {
        var operationId = String(operation.id || "")
        if (operationId.indexOf("embedding") !== -1)
            return "embeddings escalados"
        if (operationId.indexOf("position") !== -1)
            return "vectores que ya contienen orden"
        if (operationId.indexOf("qkv") !== -1)
            return "Q, K y V separados por cabeza"
        if (operationId.indexOf("scores") !== -1)
            return "scores de compatibilidad"
        if (operationId === "decoder_masked_mask")
            return "futuro bloqueado con \u2212\u221e"
        if (operationId.indexOf("softmax") !== -1)
            return operationId === "output_softmax"
                    ? "probabilidades y token elegido"
                    : "pesos de atenci\u00f3n A"
        if (operationId.indexOf("weighted") !== -1)
            return "contexto Z de cada cabeza"
        if (operationId.indexOf("multihead") !== -1)
            return "actualizaci\u00f3n MHA en d_model"
        if (operationId.indexOf("addnorm") !== -1)
            return "estado residual normalizado"
        if (operationId.indexOf("ffn") !== -1)
            return "vector transformado por la FFN"
        if (operationId.indexOf("layers") !== -1)
            return branchIndex === 0 ? "memoria final del encoder" : "estado final del decoder"
        if (operationId === "linear_logits")
            return "un logit por token del vocabulario"
        return "entrada del paso siguiente"
    }

    function formulaReading() {
        var operationId = String(operation.id || "")
        if (operationId.indexOf("embedding") !== -1)
            return "W_embed selecciona la fila del token; √d_model ajusta su escala."
        if (operationId.indexOf("position") !== -1)
            return "E aporta identidad y PE aporta posición; la suma produce el vector que usa la atención."
        if (operationId.indexOf("qkv") !== -1)
            return "Cada W es una matriz aprendida: Q pregunta, K permite comparar y V transporta información."
        if (operationId.indexOf("scores") !== -1)
            return "QKᵀ mide compatibilidad; dividir entre √d_head mantiene los valores en una escala estable."
        if (operationId === "decoder_masked_mask")
            return "i es la posición que consulta y j la consultada; j > i identifica el futuro prohibido."
        if (operationId === "output_softmax")
            return "T y los filtros cambian qué logits compiten; Softmax los convierte en una distribución p."
        if (operationId.indexOf("softmax") !== -1)
            return "Softmax convierte cada fila de scores en pesos A entre 0 y 1 cuya suma es 1."
        if (operationId.indexOf("weighted") !== -1)
            return "Cada peso Aᵢⱼ escala su Value Vⱼ; la suma forma el contexto Zᵢ de la query."
        if (operationId.indexOf("multihead") !== -1)
            return "Concat reúne las cabezas y Wᴼ aprende cómo volver a mezclar sus subespacios."
        if (operationId.indexOf("addnorm") !== -1)
            return "La entrada conserva un atajo; la actualización se suma y LayerNorm estabiliza el resultado."
        if (operationId.indexOf("ffn") !== -1)
            return "W₁ expande, φ introduce no linealidad y W₂ devuelve el vector a d_model."
        if (operationId.indexOf("layers") !== -1)
            return "Cada flecha aplica un bloque completo con parámetros propios al estado de la capa anterior."
        if (operationId === "linear_logits")
            return "h_final resume el contexto; W_vocab produce un score independiente para cada token posible."
        return "La expresión resume la transformación numérica que la escena está animando."
    }

    function detachGuide() {
        guideVisible = true
        guideDetached = true
        compactGuideOpen = false
        sequencePlaying = false
        Qt.callLater(function() {
            detachedGuideWindow.raise()
            detachedGuideWindow.requestActivate()
        })
    }

    function dockGuide() {
        guideDetached = false
        guideVisible = true
        compactGuideOpen = compactWidth
    }

    function closeDetachedGuide() {
        guideDetached = false
        guideVisible = false
        compactGuideOpen = false
    }

    onMetadataChanged: clampSelections()
    onOperationIndexChanged: {
        synchronizeOperation()
        resetPedagogicalReading()
        compactGuideOpen = false
    }
    onGuideVisibleChanged: {
        if (!guideVisible) {
            guideDetached = false
            compactGuideOpen = false
            resetPedagogicalReading()
        }
    }

    InferenceFlowSteps {
        id: flowModel
    }

    Timer {
        id: sequenceTimer
        running: root.sequencePlaying
        repeat: false
        // Nueve segundos dejan completar la animacion y leer el hilo local
        // antes de cambiar de operacion.
        interval: Math.max(root.guidedStepDuration,
                           Number(root.operation.duration || root.guidedStepDuration))
        onTriggered: {
            if (root.operationIndex >= root.flowSteps.length - 1) {
                root.sequencePlaying = false
                return
            }
            root.setOperation(root.operationIndex + 1)
            restart()
        }
    }

    Component.onCompleted: synchronizeOperation()

    Window {
        id: detachedGuideWindow
        objectName: "inferenceDetachedGuideWindow"
        visible: root.guideDetached
        transientParent: root.Window.window
        modality: Qt.NonModal
        minimumWidth: 430
        minimumHeight: 520
        width: Math.max(minimumWidth, Math.min(700, root.width * 0.46))
        height: Math.max(minimumHeight, Math.min(860, root.height * 0.90))
        title: "Explicación · " + (root.operation.title || root.stage.title)
        color: Style.Theme.superficie_alterna

        onClosing: function(close) {
            if (root.guideDetached)
                root.closeDetachedGuide()
            close.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 18 * root.uiSx
        color: Style.Theme.superficie_alterna
        border.color: Style.Theme.borde_suave
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: (root.denseHeight ? 10 : 12) * root.uiSx
            spacing: (root.denseHeight ? 4 : 6) * root.uiSy

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: (root.denseHeight ? 40 : 44) * root.uiSy
                spacing: 8 * root.uiSx

                Rectangle {
                    visible: !root.veryCompactWidth
                    Layout.preferredWidth: visible ? 38 * root.uiSx : 0
                    Layout.preferredHeight: 38 * root.uiSy
                    radius: 11 * Math.min(root.uiSx, root.uiSy)
                    color: root.stage.accent
                    Text {
                        anchors.centerIn: parent
                        text: "✦"
                        color: root.stage.onAccent || Style.Theme.texto_sobre_acento
                        font.family: Style.Theme.fuente_simbolos
                        font.pixelSize: Math.max(16, 19 * Math.min(root.uiSx, root.uiSy))
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    spacing: 1 * root.uiSy
                    Text {
                        Layout.fillWidth: true
                        text: "Cómo se genera el siguiente token"
                        color: Style.Theme.texto_primario
                        font.bold: true
                        elide: Text.ElideRight
                        font.pixelSize: Math.max(18, 22 * Math.min(root.uiSx, root.uiSy))
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.currentSnapshot
                              ? "Explicando el token " + root.currentSnapshot.paso + "/" + root.snapshots.length
                                + ": “" + root.currentSnapshot.token_elegido.texto + "”"
                              : "Genera un token para capturar su recorrido"
                        color: Style.Theme.texto_secundario
                        elide: Text.ElideRight
                        font.pixelSize: Math.max(11, 12 * Math.min(root.uiSx, root.uiSy))
                    }
                }

                Rectangle {
                    visible: !root.condensedWidth
                    Layout.preferredWidth: Math.min(180, dataChipText.implicitWidth + 24 * root.sx)
                    Layout.minimumWidth: visible ? 130 : 0
                    Layout.maximumWidth: 180
                    Layout.preferredHeight: 30 * root.uiSy
                    radius: height / 2
                    color: root.operationDataAvailable ? Style.Theme.exito_fondo : Style.Theme.aviso_fondo
                    border.color: root.operationDataAvailable ? "#86EFAC" : "#FCD34D"
                    clip: true
                    Text {
                        id: dataChipText
                        anchors.fill: parent
                        anchors.leftMargin: 10 * root.sx
                        anchors.rightMargin: 10 * root.sx
                        text: root.operationDataAvailable ? "● Datos reales" : "Captura no disponible"
                        color: root.operationDataAvailable ? Style.Theme.exito_texto : Style.Theme.aviso_texto
                        font.bold: true
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Math.max(11, 11 * Math.min(root.sx, root.sy))
                    }
                }

                ActionPill {
                    objectName: "inferenceNextTokenButton"
                    visible: root.canGenerateNext || root.tokenProcessing
                    Layout.preferredWidth: (root.condensedWidth ? 132 : 150) * root.uiSx
                    Layout.minimumWidth: (root.condensedWidth ? 118 : 130) * root.uiSx
                    Layout.maximumWidth: 150 * root.sx
                    Layout.preferredHeight: 34 * root.uiSy
                    label: root.tokenProcessing ? "Calculando…" : "+ Siguiente token"
                    enabled: root.canGenerateNext && !root.tokenProcessing
                    accent: Style.Theme.acento
                    onClicked: root.nextTokenRequested()
                }
                CasillaPrincipal {
                    objectName: "inferenceReducedMotionToggle"
                    visible: !root.veryCompactWidth
                    Layout.preferredWidth: visible
                                           ? Math.max(122, (root.condensedWidth ? 132 : 158) * root.uiSx)
                                           : 0
                    Layout.minimumWidth: visible ? 122 : 0
                    Layout.maximumWidth: visible ? 158 : 0
                    text: "Reducir movimiento"
                    checked: root.reducedMotion
                    font.pixelSize: Math.max(11, 11 * root.sx)
                    onToggled: root.reducedMotion = checked
                    Accessible.description: "Detiene las transiciones decorativas de las escenas"
                }
                ActionPill {
                    objectName: "inferenceGuideToggle"
                    Layout.preferredWidth: root.condensedWidth ? 120 * root.uiSx
                                                               : 176 * root.uiSx
                    Layout.minimumWidth: root.condensedWidth ? 108 : 140
                    Layout.maximumWidth: root.condensedWidth ? 130 : 176
                    Layout.preferredHeight: 34 * root.uiSy
                    label: root.guideDetached
                           ? "Cerrar ventana"
                           : (root.compactWidth
                              ? (root.compactGuideOpen ? "Ver animación" : "Explicación")
                              : (root.guideVisible ? "Ocultar explicación"
                                                   : "Mostrar explicación"))
                    accent: Style.Theme.texto_secundario
                    onClicked: {
                        if (root.guideDetached) {
                            root.closeDetachedGuide()
                            return
                        }
                        if (root.compactWidth) {
                            if (root.compactGuideOpen) {
                                root.compactGuideOpen = false
                                root.guideVisible = false
                            } else {
                                root.guideVisible = true
                                root.compactGuideOpen = true
                            }
                        } else {
                            root.guideVisible = !root.guideVisible
                        }
                    }
                }
                ActionPill {
                    objectName: "inferenceCloseButton"
                    Layout.preferredWidth: 38 * root.uiSx
                    Layout.minimumWidth: 36 * root.uiSx
                    Layout.maximumWidth: 38 * root.uiSx
                    Layout.preferredHeight: 34 * root.uiSy
                    label: "✕"
                    accent: Style.Theme.error
                    onClicked: root.closeRequested()
                }
            }

            InferenceProcessMap {
                Layout.fillWidth: true
                Layout.preferredHeight: root.veryShortHeight ? 44 * root.uiSy
                                                            : 54 * root.uiSy
                compact: true
                chapters: root.processChapters
                currentIndex: root.processChapterIndex
                currentStep: root.chapterStep
                currentStepCount: root.chapterStepCount
                accent: root.processAccent
                accentText: root.currentProcessChapter.onAccent
                sx: root.uiSx
                sy: root.uiSy
                onChapterSelected: function(index) { root.selectChapter(index) }
            }

            Rectangle {
                id: tokenRibbon
                objectName: "inferenceTokenRibbon"
                visible: true
                Layout.fillWidth: true
                Layout.minimumHeight: visible ? root.tokenRibbonHeight : 0
                Layout.preferredHeight: visible ? root.tokenRibbonHeight : 0
                Layout.maximumHeight: visible ? root.tokenRibbonHeight : 0
                radius: 11 * root.sx
                color: Style.Theme.surface
                border.color: Style.Theme.borde_medio

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: (root.veryShortHeight ? 4 : 6) * root.uiSx
                    spacing: 7 * root.uiSx

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: "PROMPT"
                        color: Style.Theme.texto_secundario
                        font.bold: true
                        font.pixelSize: Math.max(11, 10 * root.uiSx)
                    }
                    ListView {
                        id: promptTokenList
                        objectName: "inferencePromptTokens"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 1
                        orientation: ListView.Horizontal
                        spacing: 5 * root.uiSx
                        clip: true
                        model: root.currentSnapshot ? root.currentSnapshot.tokens_entrada : []
                        delegate: TokenChip {
                            required property var modelData
                            token: modelData
                            selected: false
                            accent: Style.Theme.inferencia_estructura
                            onAccent: Style.Theme.inferencia_sobre_estructura
                            sx: root.uiSx
                            sy: root.uiSy
                        }
                    }
                    Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Style.Theme.borde_medio }
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: "SALIDA"
                        color: Style.Theme.texto_secundario
                        font.bold: true
                        font.pixelSize: Math.max(11, 10 * root.uiSx)
                    }
                    ListView {
                        id: outputTokenList
                        objectName: "inferenceOutputTokens"
                        Layout.minimumWidth: root.compactWidth ? 110 : 180
                        Layout.preferredWidth: root.compactWidth
                                               ? Math.max(120 * root.uiSx, parent.width * 0.38)
                                               : Math.max(210 * root.uiSx, parent.width * 0.36)
                        Layout.fillHeight: true
                        orientation: ListView.Horizontal
                        layoutDirection: Qt.RightToLeft
                        spacing: 5 * root.uiSx
                        clip: true
                        model: root.snapshots
                        delegate: TokenChip {
                            required property var modelData
                            required property int index
                            token: modelData.token_elegido
                            selected: index === root.selectedIndex
                            interactive: true
                            accent: Style.Theme.inferencia_resultado
                            onAccent: Style.Theme.inferencia_sobre_resultado
                            sx: root.uiSx
                            sy: root.uiSy
                            onClicked: root.selectSnapshot(index)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 38 * root.uiSy : 0
                visible: root.stageIndex >= 1 && root.stageIndex <= 4
                radius: 11 * root.sx
                color: Style.Theme.surface
                border.color: Style.Theme.borde_medio

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6 * root.sx
                    spacing: 7 * root.sx

                    Text {
                        text: "AJUSTA LA ANIMACIÓN"
                        color: Style.Theme.texto_secundario
                        font.bold: true
                        font.pixelSize: Math.max(11, 10 * root.sx)
                    }

                    Rectangle {
                        Layout.preferredWidth: branchText.implicitWidth + 20 * root.sx
                        Layout.preferredHeight: 30 * root.sy
                        radius: height / 2
                        color: Qt.alpha(root.stage.accent, 0.10)
                        border.color: Qt.alpha(root.stage.accent, 0.45)

                        Text {
                            id: branchText
                            anchors.centerIn: parent
                            text: root.branchLabel()
                            color: root.stage.accent
                            font.bold: true
                            font.pixelSize: Math.max(11, 10 * root.sx)
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: root.stageIndex >= 1 && root.stageIndex <= 4
                        text: "CAPA"
                        color: Style.Theme.texto_secundario
                        font.bold: true
                        font.pixelSize: Math.max(11, 10 * root.sx)
                    }
                    Stepper {
                        visible: root.stageIndex >= 1 && root.stageIndex <= 4
                        value: root.layerIndex + 1
                        minimum: 1
                        maximum: Math.max(1, Number(root.metadata.num_layers || 1))
                        accent: root.stage.accent
                        foreground: root.stage.onAccent
                        sx: root.sx
                        sy: root.sy
                        onValueRequested: function(value) { root.layerIndex = value - 1 }
                    }

                    Text {
                        visible: root.stageIndex === 1
                        text: "CABEZA"
                        color: Style.Theme.texto_secundario
                        font.bold: true
                        font.pixelSize: Math.max(11, 10 * root.sx)
                    }
                    Stepper {
                        visible: root.stageIndex === 1
                        value: root.headIndex + 1
                        minimum: 1
                        maximum: Math.max(1, Number(root.metadata.num_heads || 1))
                        accent: root.stage.accent
                        foreground: root.stage.onAccent
                        sx: root.sx
                        sy: root.sy
                        onValueRequested: function(value) { root.headIndex = value - 1 }
                    }

                    ActionPill {
                        visible: root.stageIndex === 4 && root.branchIndex < 2
                        Layout.preferredWidth: 132 * root.sx
                        Layout.preferredHeight: 32 * root.sy
                        label: root.residualUsesFfn ? "Subcapa: FFN" : "Subcapa: atención"
                        selected: root.residualUsesFfn
                        accent: root.stage.accent
                        onClicked: root.toggleResidualStep()
                    }
                }
            }

            Rectangle {
                objectName: "inferenceColorLegend"
                // La leyenda repetia significados ya rotulados dentro de cada
                // escena. Se conserva el modelo semantico para accesibilidad y
                // pruebas de contraste, sin sumar otra franja visual fija.
                visible: false
                Layout.fillWidth: true
                Layout.preferredHeight: 0
                radius: 9 * root.sx
                color: Style.Theme.superficie_alterna
                border.color: Style.Theme.borde_suave
                Accessible.name: "Código de color pedagógico de la inferencia"
                Accessible.description: "Azul estructura, turquesa contexto, violeta transformación, naranja foco, verde resultado y rojo solo error"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10 * root.sx
                    anchors.rightMargin: 10 * root.sx
                    spacing: 8 * root.uiSx

                    Text {
                        text: "COLOR = FUNCIÓN"
                        color: Style.Theme.texto_secundario_fuerte
                        font.bold: true
                        font.pixelSize: Math.max(9, 9 * root.sx)
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 16 * root.sy
                        color: Style.Theme.divisor
                    }

                    Repeater {
                        objectName: "inferenceColorLegendRepeater"
                        model: root.pedagogicalColors
                        delegate: RowLayout {
                            id: colorRole
                            required property var modelData
                            required property int index
                            spacing: 4 * root.sx

                            Rectangle {
                                Layout.preferredWidth: 15 * root.uiSx
                                Layout.preferredHeight: 15 * root.uiSy
                                radius: 5 * root.sx
                                color: colorRole.modelData.accent
                                Text {
                                    anchors.centerIn: parent
                                    text: colorRole.modelData.mark
                                    color: colorRole.modelData.onAccent
                                    font.bold: true
                                    font.pixelSize: Math.max(9, 9 * root.sx)
                                }
                            }
                            Text {
                                text: colorRole.modelData.label
                                color: Style.Theme.texto_secundario_fuerte
                                font.bold: colorRole.index === 3 || colorRole.index === 4
                                font.pixelSize: Math.max(9, 9 * root.sx)
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                // La altura restante pertenece a la escena. El minimo reducido
                // permite que el contenido se reescale sin expulsar el pie.
                Layout.minimumHeight: 220 * root.uiSy
                spacing: 8 * root.uiSx

                Rectangle {
                    id: animationViewport
                    objectName: "inferenceAnimationViewport"
                    visible: !root.compactWidth || !root.compactGuideOpen
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    // La guia comparte la fila con la escena. Este minimo permite
                    // que ambas se contraigan sin solaparse en la ventana base.
                    Layout.minimumWidth: 0
                    radius: 14 * root.uiSx
                    color: Style.Theme.surface
                    border.color: Style.Theme.borde_medio
                    clip: true

                    StackLayout {
                        anchors.fill: parent
                        anchors.margins: (root.denseHeight ? 8 : 10) * root.uiSx
                        currentIndex: Number(root.operation.visualIndex || 0)

                        TokenEmbeddingScene {
                            tensorData: root.currentEmbeddingTensor
                            tokens: root.currentTokens
                            active: Number(root.operation.visualIndex) === 0 && root.detailAvailable
                            reducedMotion: root.reducedMotion
                            sx: root.sceneSx
                            sy: root.sceneSy
                        }

                        EmbeddingPositionScene {
                            projection: root.currentProjection
                            tokens: root.currentTokens
                            active: Number(root.operation.visualIndex) === 1 && root.detailAvailable
                            reducedMotion: root.reducedMotion
                            sx: root.sceneSx
                            sy: root.sceneSy
                        }
                        AttentionComputationScene {
                            attentionData: root.currentAttention
                            causalMaskData: root.globalData.mascara_causal || ({})
                            phase: String(root.operation.phase || "qkv")
                            branchIndex: root.branchIndex
                            headIndex: root.headIndex
                            layerIndex: root.layerIndex
                            active: Number(root.operation.visualIndex) === 2 && root.detailAvailable
                            reducedMotion: root.reducedMotion
                            sx: root.sceneSx
                            sy: root.sceneSy
                        }
                        AttentionFlowScene {
                            attentionData: root.currentAttention
                            queryTokens: root.currentTokens
                            keyTokens: root.keyTokens
                            crossAttention: root.branchIndex === 2
                            headIndex: root.headIndex
                            active: Number(root.operation.visualIndex) === 3 && root.detailAvailable
                            reducedMotion: root.reducedMotion
                            sx: root.sceneSx
                            sy: root.sceneSy
                            onHeadSelected: function(index) { root.headIndex = index }
                        }
                        MultiHeadSplitScene {
                            metadata: root.metadata
                            attentionData: root.currentAttention
                            active: Number(root.operation.visualIndex) === 4 && root.detailAvailable
                            reducedMotion: root.reducedMotion
                            sx: root.sceneSx
                            sy: root.sceneSy
                        }
                        FeedForwardExpansionScene {
                            sceneData: root.currentFfn
                            tokens: root.currentTokens
                            active: Number(root.operation.visualIndex) === 5 && root.detailAvailable
                            reducedMotion: root.reducedMotion
                            sx: root.sceneSx
                            sy: root.sceneSy
                        }
                        ResidualLayerNormScene {
                            sceneData: root.currentResidual
                            active: Number(root.operation.visualIndex) === 6 && root.detailAvailable
                            reducedMotion: root.reducedMotion
                            sublayerLabel: root.residualUsesFfn ? "FFN" : "Atención"
                            sx: root.sceneSx
                            sy: root.sceneSy
                        }
                        LayerSkyscraperScene {
                            trajectory: root.currentTrajectory
                            tokens: root.currentTokens
                            active: Number(root.operation.visualIndex) === 7 && root.detailAvailable
                            sx: root.sceneSx
                            sy: root.sceneSy
                        }
                        OutputProjectionScene {
                            snapshot: root.currentSnapshot
                            logitsData: root.detailAvailable
                                        ? (root.detailForward.logits_lineales
                                           || root.detailForward.logits || ({}))
                                        : ({})
                            hiddenData: root.currentHiddenTensor
                            active: Number(root.operation.visualIndex) === 8 && root.detailAvailable
                            reducedMotion: root.reducedMotion
                            sx: root.sceneSx
                            sy: root.sceneSy
                        }
                        SoftmaxRaceScene {
                            snapshots: root.snapshots
                            initialStep: root.selectedIndex
                            active: Number(root.operation.visualIndex) === 9
                            reducedMotion: root.reducedMotion
                            sx: root.sceneSx
                            sy: root.sceneSy
                            onStepSelected: function(index) { root.stepSelected(index) }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 12 * root.sx
                        visible: Boolean(root.operation.requiresDetail) && !root.detailAvailable
                        radius: 12 * root.sx
                        color: Style.Theme.superficie_alterna
                        border.color: Style.Theme.warning
                        Column {
                            anchors.centerIn: parent
                            width: Math.min(parent.width - 40 * root.sx, 520 * root.sx)
                            spacing: 12 * root.sy
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "◷"
                                color: Style.Theme.warning
                                font.pixelSize: 42 * Math.min(root.sx, root.sy)
                            }
                            Text {
                                width: parent.width
                                text: "La captura tensorial pertenece al token más reciente"
                                color: Style.Theme.texto_primario
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                font.pixelSize: 19 * Math.min(root.sx, root.sy)
                            }
                            Text {
                                width: parent.width
                                text: "Selecciona el último token de la cinta superior. El historial anterior conserva probabilidades para la carrera softmax, pero no duplica todos los tensores."
                                color: Style.Theme.texto_secundario
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                font.pixelSize: 12 * Math.min(root.sx, root.sy)
                            }
                        }
                    }
                }

                Item {
                    id: guideDock
                    objectName: "inferencePedagogicalGuideDock"
                    visible: root.effectiveGuideVisible && !root.guideDetached
                    Layout.fillWidth: root.compactWidth && visible
                    Layout.preferredWidth: visible
                                           ? (root.compactWidth
                                              ? 1
                                              : Math.max(310, Math.min(390, root.width * 0.27)))
                                           : 0
                    Layout.minimumWidth: visible && !root.compactWidth ? 300 : 0
                    Layout.maximumWidth: visible && !root.compactWidth ? 390 : 16777215
                    Layout.fillHeight: true

                    Rectangle {
                    id: guidePanel
                    objectName: "inferencePedagogicalGuide"
                    parent: root.guideDetached
                            ? detachedGuideWindow.contentItem
                            : guideDock
                    anchors.fill: parent
                    readonly property real mapPreferredHeight: root.locationMapVisible
                                                                ? Math.max(
                                                                      root.compactWidth ? 190 : 220,
                                                                      Math.min(
                                                                          root.compactWidth ? 280 : 340,
                                                                          height * 0.42))
                                                                : 0
                    visible: root.effectiveGuideVisible
                    radius: 14 * root.sx
                    color: Style.Theme.surface
                    border.color: root.stage.accent
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 11 * root.uiSx
                        spacing: 6 * root.uiSy

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(30, 32 * root.sy)
                            spacing: 6 * root.sx

                            Text {
                                Layout.minimumWidth: 0
                                Layout.fillWidth: true
                                text: "EXPLICACIÓN"
                                color: root.stage.accent
                                font.bold: true
                                elide: Text.ElideRight
                                font.letterSpacing: 0.5
                                font.pixelSize: Math.max(11, 10 * root.sx)
                            }

                            Button {
                                objectName: "inferenceDetachGuideButton"
                                Layout.preferredHeight: Math.max(28, 30 * root.sy)
                                text: root.guideDetached ? "Acoplar" : "Abrir aparte"
                                flat: true
                                font.bold: true
                                font.pixelSize: Math.max(10, 10 * root.sx)
                                onClicked: root.guideDetached
                                           ? root.dockGuide()
                                           : root.detachGuide()
                                Accessible.name: root.guideDetached
                                                 ? "Volver a acoplar la explicación"
                                                 : "Abrir la explicación en otra ventana"
                                ToolTip.visible: hovered
                                ToolTip.text: root.guideDetached
                                              ? "Devuelve la explicación junto a la animación"
                                              : "Libera espacio y mantiene la explicación en otra ventana"
                            }

                            Button {
                                objectName: "inferenceLocationMapToggle"
                                Layout.preferredHeight: Math.max(28, 30 * root.sy)
                                text: root.locationMapVisible ? "Ocultar mapa" : "Mostrar mapa"
                                flat: true
                                font.bold: true
                                font.pixelSize: Math.max(11, 10 * root.sx)
                                onClicked: root.locationMapVisible = !root.locationMapVisible
                                Accessible.name: text
                                ToolTip.visible: hovered
                                ToolTip.text: root.locationMapVisible
                                              ? "Deja más espacio para leer la explicación"
                                              : "Mantiene visible tu ubicación durante el recorrido"
                            }
                        }

                        TransformerMiniMap {
                            objectName: "inferenceTransformerMiniMap"
                            visible: root.locationMapVisible
                            Layout.fillWidth: true
                            implicitHeight: guidePanel.mapPreferredHeight
                            Layout.preferredHeight: guidePanel.mapPreferredHeight
                            Layout.minimumHeight: root.locationMapVisible
                                                  ? (root.compactWidth ? 175 : 210)
                                                  : 0
                            Layout.maximumHeight: root.locationMapVisible
                                                  ? (root.compactWidth ? 280 : 340)
                                                  : 0
                            stageIndex: root.stageIndex
                            branchIndex: root.branchIndex
                            residualUsesFfn: root.residualUsesFfn
                            operationId: String(root.operation.id || "")
                            accent: root.stage.accent
                            reducedMotion: root.reducedMotion
                            sx: root.uiSx
                            sy: root.uiSy
                        }

                        ScrollView {
                            id: pedagogicalScroll
                            objectName: "inferencePedagogicalScroll"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: availableWidth
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                            ColumnLayout {
                                width: pedagogicalScroll.availableWidth
                                spacing: 10 * root.sy

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6 * root.sx

                                Rectangle {
                                    Layout.preferredWidth: chapterLabel.implicitWidth + 18 * root.sx
                                    Layout.preferredHeight: Math.max(25, 27 * root.sy)
                                    radius: height / 2
                                    color: Qt.alpha(root.stage.accent, 0.11)
                                    border.color: Qt.alpha(root.stage.accent, 0.48)

                                    Text {
                                        id: chapterLabel
                                        anchors.centerIn: parent
                                        text: root.currentProcessChapter.label
                                        color: root.stage.accent
                                        font.bold: true
                                        font.pixelSize: Math.max(11, 10 * root.sx)
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "Operación " + (root.operationIndex + 1)
                                          + " de " + root.flowSteps.length
                                    color: Style.Theme.texto_secundario_fuerte
                                    font.bold: true
                                    font.pixelSize: Math.max(11, 11 * root.sx)
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.operation.title || root.stage.title
                                color: Style.Theme.texto_primario
                                font.bold: true
                                wrapMode: Text.WordWrap
                                font.pixelSize: Math.max(20, 23 * Math.min(root.sx, root.sy))
                            }

                            Rectangle {
                                objectName: "inferenceLocalContext"
                                Layout.fillWidth: true
                                implicitHeight: localContextColumn.implicitHeight + 22 * root.sy
                                radius: 11 * root.sx
                                color: Style.Theme.superficie_alterna
                                border.color: Style.Theme.borde_medio

                                ColumnLayout {
                                    id: localContextColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 11 * root.sx
                                    spacing: 7 * root.sy

                                    Text {
                                        text: "HILO DEL CÁLCULO"
                                        color: Style.Theme.texto_secundario_fuerte
                                        font.bold: true
                                        font.letterSpacing: 0.5
                                        font.pixelSize: Math.max(11, 10 * root.sx)
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4 * root.sx

                                        ContextStep {
                                            objectName: "inferencePreviousStepText"
                                            Layout.fillWidth: true
                                            eyebrow: "ANTES"
                                            stepText: root.previousStepLabel()
                                            accent: Style.Theme.texto_secundario
                                            sx: root.sx
                                            sy: root.sy
                                        }
                                        Text {
                                            text: "→"
                                            color: Style.Theme.texto_terciario
                                            font.bold: true
                                            font.pixelSize: Math.max(13, 14 * root.sx)
                                        }
                                        ContextStep {
                                            objectName: "inferenceCurrentStepText"
                                            Layout.fillWidth: true
                                            eyebrow: "AHORA"
                                            stepText: root.operation.short || root.stage.short
                                            accent: root.stage.accent
                                            highlighted: true
                                            sx: root.sx
                                            sy: root.sy
                                        }
                                        Text {
                                            text: "→"
                                            color: Style.Theme.texto_terciario
                                            font.bold: true
                                            font.pixelSize: Math.max(13, 14 * root.sx)
                                        }
                                        ContextStep {
                                            objectName: "inferenceFollowingStepText"
                                            Layout.fillWidth: true
                                            eyebrow: "DESPUÉS"
                                            stepText: root.nextStepLabel()
                                            accent: Style.Theme.texto_secundario
                                            sx: root.sx
                                            sy: root.sy
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 1
                                        color: Style.Theme.divisor
                                    }

                                    Text {
                                        objectName: "inferenceInputOutputText"
                                        Layout.fillWidth: true
                                        text: "ENTRA  " + root.operationInputLabel()
                                              + "   →   SALE  " + root.operationOutputLabel()
                                        color: Style.Theme.texto_secundario_fuerte
                                        font.bold: true
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.15
                                        font.pixelSize: Math.max(12, 12 * root.sx)
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: essentialColumn.implicitHeight + 22 * root.sy
                                radius: 10 * root.sx
                                color: Style.Theme.superficie_alterna
                                border.color: Style.Theme.borde_suave

                                ColumnLayout {
                                    id: essentialColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 11 * root.sx
                                    spacing: 5 * root.sy

                                    Text {
                                        text: "IDEA CLAVE"
                                        color: root.stage.accent
                                        font.bold: true
                                        font.pixelSize: Math.max(11, 10 * root.sx)
                                    }
                                    Text {
                                        objectName: "inferenceEssentialExplanation"
                                        Layout.fillWidth: true
                                        text: root.operation.operation || root.stage.concept
                                        color: Style.Theme.texto_secundario_fuerte
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.24
                                        font.pixelSize: Math.max(13, 13 * root.sx)
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: visualColumn.implicitHeight + 22 * root.sy
                                radius: 10 * root.sx
                                color: Style.Theme.chip_fondo
                                border.color: "#93C5FD"

                                ColumnLayout {
                                    id: visualColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 11 * root.sx
                                    spacing: 5 * root.sy

                                    Text {
                                        text: "QUÉ OBSERVAR AHORA"
                                        color: Style.Theme.info_texto
                                        font.bold: true
                                        font.pixelSize: Math.max(11, 10 * root.sx)
                                    }
                                    Text {
                                        objectName: "inferenceVisualGuide"
                                        Layout.fillWidth: true
                                        text: root.operation.visualMeaning || root.stage.hint
                                        color: Style.Theme.texto_secundario_fuerte
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.24
                                        font.pixelSize: Math.max(13, 13 * root.sx)
                                    }

                                    Text {
                                        objectName: "inferenceAnimationTakeaway"
                                        Layout.fillWidth: true
                                        text: "AL FINAL DEBES VER  ·  "
                                              + root.operationOutputLabel()
                                        color: Style.Theme.info_texto
                                        font.bold: true
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.18
                                        font.pixelSize: Math.max(12, 12 * root.sx)
                                    }
                                }
                            }

                            Rectangle {
                                objectName: "inferenceFormulaCard"
                                Layout.fillWidth: true
                                implicitHeight: formulaColumn.implicitHeight + 26 * root.sy
                                radius: 12 * root.sx
                                color: Qt.alpha(root.stage.accent, 0.08)
                                border.color: root.stage.accent
                                border.width: 2

                                ColumnLayout {
                                    id: formulaColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 13 * root.sx
                                    spacing: 7 * root.sy

                                    Text {
                                        text: "FÓRMULA CLAVE DE ESTE PASO"
                                        color: root.stage.accent
                                        font.bold: true
                                        font.letterSpacing: 0.5
                                        font.pixelSize: Math.max(11, 10 * root.sx)
                                    }

                                    Text {
                                        objectName: "inferenceFormulaText"
                                        Layout.fillWidth: true
                                        text: root.operation.formula || root.stage.formula
                                        color: Style.Theme.texto_primario
                                        font.family: "Cambria Math"
                                        font.weight: Font.DemiBold
                                        font.pixelSize: Math.max(17, 18 * root.sx)
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.Wrap
                                        lineHeight: 1.16
                                    }

                                    Text {
                                        objectName: "inferenceFormulaExplanation"
                                        Layout.fillWidth: true
                                        text: "CÓMO LEERLA  ·  " + root.formulaReading()
                                        color: Style.Theme.texto_secundario_fuerte
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.20
                                        font.pixelSize: Math.max(12, 12 * root.sx)
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 1
                                        color: Qt.alpha(root.stage.accent, 0.28)
                                    }

                                    Text {
                                        text: "POR QUÉ IMPORTA AQUÍ"
                                        color: root.stage.accent
                                        font.bold: true
                                        font.pixelSize: Math.max(10, 10 * root.sx)
                                    }
                                    Text {
                                        objectName: "inferencePurposeText"
                                        Layout.fillWidth: true
                                        text: root.operation.purpose || "—"
                                        color: Style.Theme.texto_secundario_fuerte
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.22
                                        font.pixelSize: Math.max(13, 13 * root.sx)
                                    }
                                }
                            }

                            Button {
                                id: fullExplanationButton
                                objectName: "inferenceFullExplanationButton"
                                property string targetConceptId: String(
                                    root.operation.conceptId || root.stage.conceptId || "")
                                Layout.fillWidth: true
                                implicitHeight: fullExplanationContent.implicitHeight + 22 * root.sy
                                padding: 11 * root.sx
                                hoverEnabled: true
                                onClicked: {
                                    root.sequencePlaying = false
                                    root.theoryRequested(fullExplanationButton.targetConceptId)
                                }
                                ToolTip.visible: hovered || activeFocus
                                ToolTip.text: "Abre teoría, fórmula, pasos, dimensiones y ejemplos"
                                Accessible.name: "Abrir explicación completa de "
                                                 + (root.operation.title || root.stage.title)
                                Accessible.description: "Incluye la teoría y la fórmula relacionadas con esta animación"

                                background: Rectangle {
                                    radius: 11 * root.sx
                                    color: fullExplanationButton.down
                                           ? Qt.alpha(root.stage.accent, 0.20)
                                           : Qt.alpha(root.stage.accent, 0.09)
                                    border.color: root.stage.accent
                                    border.width: fullExplanationButton.activeFocus ? 2 : 1
                                }

                                contentItem: RowLayout {
                                    id: fullExplanationContent
                                    spacing: 10 * root.sx

                                    Rectangle {
                                        Layout.preferredWidth: 34 * root.sx
                                        Layout.preferredHeight: 34 * root.sy
                                        radius: height / 2
                                        color: root.stage.accent
                                        Text {
                                            anchors.centerIn: parent
                                            text: "ⓘ"
                                            color: root.stage.onAccent || Style.Theme.texto_sobre_acento
                                            font.bold: true
                                            font.pixelSize: Math.max(14, 15 * root.sx)
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2 * root.sy
                                        Text {
                                            Layout.fillWidth: true
                                            text: "ABRIR EXPLICACIÓN COMPLETA"
                                            color: root.stage.accent
                                            font.bold: true
                                            font.pixelSize: Math.max(11, 10 * root.sx)
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: "Teoría, fórmula, pasos y dimensiones de «"
                                                  + (root.operation.short || root.stage.short) + "»"
                                            color: Style.Theme.texto_secundario_fuerte
                                            wrapMode: Text.WordWrap
                                            font.pixelSize: Math.max(11, 11 * root.sx)
                                        }
                                    }
                                    Text {
                                        text: "→"
                                        color: root.stage.accent
                                        font.bold: true
                                        font.pixelSize: Math.max(18, 20 * root.sx)
                                    }
                                }
                            }

                            Rectangle {
                                objectName: "inferenceVisualDictionary"
                                Layout.fillWidth: true
                                implicitHeight: visualDictionaryColumn.implicitHeight + 24 * root.sy
                                radius: 12 * root.sx
                                color: Style.Theme.surface
                                border.color: Qt.alpha(root.stage.accent, 0.55)
                                border.width: 1

                                ColumnLayout {
                                    id: visualDictionaryColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 12 * root.sx
                                    spacing: 8 * root.sy

                                    Text {
                                        Layout.fillWidth: true
                                        text: "ENTIENDE TODO LO QUE VES"
                                        color: root.stage.accent
                                        font.bold: true
                                        font.letterSpacing: 0.5
                                        font.pixelSize: Math.max(11, 10 * root.sx)
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: "Cada elemento cumple una función en el cálculo o ayuda a leer datos reales:"
                                        color: Style.Theme.texto_secundario_fuerte
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.18
                                        font.pixelSize: Math.max(12, 12 * root.sx)
                                    }
                                    Text {
                                        objectName: "inferenceRealDataExplanation"
                                        Layout.fillWidth: true
                                        text: "● Datos reales = números capturados del forward del token seleccionado; colores, tamaños y flechas solo ayudan a representarlos."
                                        color: Style.Theme.exito_texto
                                        font.bold: true
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.18
                                        font.pixelSize: Math.max(11, 11 * root.sx)
                                    }

                                    Repeater {
                                        objectName: "inferenceVisualElementsRepeater"
                                        model: root.operation.visualElements || []

                                        delegate: RowLayout {
                                            id: visualElementRow
                                            required property var modelData
                                            Layout.fillWidth: true
                                            spacing: 7 * root.sx

                                            Rectangle {
                                                Layout.preferredWidth: Math.max(104, 112 * root.sx)
                                                Layout.preferredHeight: Math.max(28, visualTerm.implicitHeight + 10 * root.sy)
                                                radius: 7 * root.sx
                                                color: Qt.alpha(root.stage.accent, 0.10)
                                                border.color: Qt.alpha(root.stage.accent, 0.35)

                                                Text {
                                                    id: visualTerm
                                                    anchors.fill: parent
                                                    anchors.margins: 5 * root.sx
                                                    text: visualElementRow.modelData.term
                                                    color: root.stage.accent
                                                    font.bold: true
                                                    wrapMode: Text.WordWrap
                                                    verticalAlignment: Text.AlignVCenter
                                                    font.pixelSize: Math.max(10, 10 * root.sx)
                                                }
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: visualElementRow.modelData.explanation
                                                color: Style.Theme.texto_secundario_fuerte
                                                wrapMode: Text.WordWrap
                                                lineHeight: 1.18
                                                font.pixelSize: Math.max(11, 11 * root.sx)
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 1
                                        color: Style.Theme.divisor
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: "SÍMBOLOS Y ABREVIATURAS"
                                        color: Style.Theme.texto_secundario_fuerte
                                        font.bold: true
                                        font.pixelSize: Math.max(11, 10 * root.sx)
                                    }

                                    Repeater {
                                        objectName: "inferenceSymbolGlossaryRepeater"
                                        model: root.operation.symbolGlossary || []

                                        delegate: RowLayout {
                                            id: symbolGlossaryRow
                                            required property var modelData
                                            Layout.fillWidth: true
                                            spacing: 7 * root.sx

                                            Text {
                                                Layout.preferredWidth: Math.max(108, 118 * root.sx)
                                                text: symbolGlossaryRow.modelData.term
                                                color: root.stage.accent
                                                font.family: "Cambria Math"
                                                font.bold: true
                                                wrapMode: Text.WordWrap
                                                font.pixelSize: Math.max(12, 12 * root.sx)
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: "= " + symbolGlossaryRow.modelData.explanation
                                                color: Style.Theme.texto_secundario_fuerte
                                                wrapMode: Text.WordWrap
                                                lineHeight: 1.18
                                                font.pixelSize: Math.max(11, 11 * root.sx)
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: interactionHelpText.implicitHeight + 16 * root.sy
                                        radius: 8 * root.sx
                                        color: Style.Theme.info_fondo
                                        border.color: "#93C5FD"

                                        Text {
                                            id: interactionHelpText
                                            objectName: "inferenceInteractionHelp"
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 8 * root.sx
                                            text: "PRUÉBALO  ·  " + (root.operation.interactionHelp || "Observa el cambio paso a paso.")
                                            color: Style.Theme.info_texto
                                            font.bold: true
                                            wrapMode: Text.WordWrap
                                            lineHeight: 1.18
                                            font.pixelSize: Math.max(11, 11 * root.sx)
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: nextStepText.implicitHeight + 18 * root.sy
                                radius: 9 * root.sx
                                color: Style.Theme.aviso_fondo
                                border.color: "#FCD34D"

                                Text {
                                    id: nextStepText
                                    objectName: "inferenceNextStepText"
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 9 * root.sx
                                    text: "DESPUÉS  →  " + (root.operation.nextStep || "—")
                                    color: Style.Theme.aviso_texto
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.20
                                    font.pixelSize: Math.max(12, 12 * root.sx)
                                }
                            }

                            Button {
                                objectName: "inferenceDetailsToggle"
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(38, 42 * root.sy)
                                text: root.detailsExpanded
                                      ? "Ocultar detalle técnico  ▴"
                                      : "Ver datos técnicos  ▾"
                                font.bold: true
                                font.pixelSize: Math.max(12, 12 * root.sx)
                                onClicked: {
                                    root.detailsExpanded = !root.detailsExpanded
                                    if (root.detailsExpanded)
                                        root.sequencePlaying = false
                                }
                                Accessible.name: root.detailsExpanded
                                                 ? "Ocultar detalle técnico"
                                                 : "Mostrar datos técnicos"
                            }

                            ColumnLayout {
                                id: advancedDetails
                                objectName: "inferenceAdvancedDetails"
                                Layout.fillWidth: true
                                visible: root.detailsExpanded
                                spacing: 10 * root.sy

                                InfoCard {
                                    Layout.fillWidth: true
                                    eyebrow: "DATOS DE ESTA CAPTURA"
                                    body: root.operationEvidenceText()
                                    bodyObjectName: "inferenceEvidenceText"
                                    accent: "#059669"
                                    sx: root.sx
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: caveatText.implicitHeight + 22 * root.sy
                                    radius: 10 * root.sx
                                    color: Style.Theme.aviso_fondo
                                    border.color: "#FDBA74"
                                    Text {
                                        id: caveatText
                                        objectName: "inferenceCaveatText"
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 11 * root.sx
                                        text: "⚠  " + (root.operation.caveat || root.stage.caveat)
                                        color: Style.Theme.aviso_texto
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.22
                                        font.pixelSize: Math.max(12, 12 * root.sx)
                                    }
                                }

                            }
                        }
                    }
                    }
                }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(48, 52 * root.uiSy)
                radius: 12 * root.sx
                color: Style.Theme.surface
                border.color: Style.Theme.borde_medio

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 7 * root.sx
                    spacing: 8 * root.sx

                    ActionPill {
                        objectName: "inferencePreviousOperationButton"
                        Layout.preferredWidth: (root.condensedWidth ? 84 : 96) * root.uiSx
                        Layout.preferredHeight: 36 * root.uiSy
                        label: "\u2190 Anterior"
                        enabled: root.operationIndex > 0
                        accent: root.stage.accent
                        onClicked: root.previousOperation()
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 5 * root.sy

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: root.operation.short || ""
                                color: root.stage.accent
                                font.bold: true
                                font.pixelSize: Math.max(12, 12 * root.sx)
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "  " + (root.operationIndex + 1) + "/" + root.flowSteps.length
                                color: Style.Theme.texto_secundario_fuerte
                                font.bold: true
                                font.pixelSize: Math.max(12, 12 * root.sx)
                            }
                        }

                        ProgressBar {
                            objectName: "inferenceOperationProgress"
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(7, 8 * root.sy)
                            from: 0
                            to: Math.max(1, root.flowSteps.length - 1)
                            value: root.operationIndex
                            Accessible.name: "Progreso del recorrido de inferencia"
                        }
                    }

                    ActionPill {
                        objectName: "inferencePlaySequenceButton"
                        visible: !root.condensedWidth
                        Layout.preferredWidth: 150 * root.sx
                        Layout.preferredHeight: 38 * root.sy
                        label: root.sequencePlaying ? "\u23f8 Pausar lectura" : "\u25b6 Recorrido guiado"
                        selected: root.sequencePlaying
                        accent: Style.Theme.acento
                        onClicked: {
                            if (root.sequencePlaying) {
                                root.sequencePlaying = false
                                return
                            }
                            if (root.operationIndex >= root.flowSteps.length - 1)
                                root.setOperation(0)
                            root.sequencePlaying = true
                            sequenceTimer.restart()
                        }
                    }

                    SelectorPrincipal {
                        id: operationSelector
                        objectName: "inferenceOperationSelector"
                        visible: !root.veryCompactWidth
                        Layout.preferredWidth: visible
                                               ? Math.max(160, (root.condensedWidth ? 180 : 220) * root.uiSx)
                                               : 0
                        Layout.preferredHeight: Math.max(38, 40 * root.sy)
                        model: root.flowSteps
                        sx: root.sx
                        sy: root.sy
                        textRole: "short"
                        currentIndex: root.operationIndex
                        displayText: "Ir al paso " + (root.operationIndex + 1)
                        font.pixelSize: Math.max(11, 11 * root.sx)
                        onActivated: function(index) { root.selectOperation(index) }
                        Accessible.name: "Elegir cualquiera de las 31 operaciones"
                    }

                    ActionPill {
                        objectName: "inferenceNextOperationButton"
                        Layout.preferredWidth: (root.condensedWidth ? 84 : 96) * root.uiSx
                        Layout.preferredHeight: 36 * root.uiSy
                        label: "Siguiente \u2192"
                        enabled: root.operationIndex < root.flowSteps.length - 1
                        accent: root.stage.accent
                        onClicked: root.nextOperation()
                    }
                }
            }
        }
    }

    component ActionPill: Rectangle {
        id: pill
        property string label: ""
        property bool selected: false
        property color accent: Style.Theme.acento
        signal clicked()
        activeFocusOnTab: enabled && visible
        implicitWidth: pillText.implicitWidth + 24 * root.sx
        implicitHeight: 32 * root.sy
        clip: true
        radius: height / 2
        color: !enabled ? Style.Theme.superficie_alterna : (selected ? accent : "#FFFFFF")
        border.color: !enabled ? Style.Theme.borde_suave : accent
        border.width: activeFocus ? 2 : 1
        opacity: enabled ? 1 : 0.55
        Accessible.role: Accessible.Button
        Accessible.name: label
        Accessible.ignored: !visible
        Accessible.onPressAction: if (pill.enabled) pill.clicked()
        Keys.onPressed: function(event) {
            if (pill.enabled && (event.key === Qt.Key_Return
                                 || event.key === Qt.Key_Enter
                                 || event.key === Qt.Key_Space)) {
                pill.clicked()
                event.accepted = true
            }
        }
        Text {
            id: pillText
            anchors.fill: parent
            anchors.leftMargin: 8 * root.sx
            anchors.rightMargin: 8 * root.sx
            text: pill.label
            color: pill.selected ? Style.Theme.texto_sobre_acento
                                 : (pill.enabled ? pill.accent : Style.Theme.texto_terciario)
            font.bold: true
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: Math.max(11, 11 * Math.min(root.sx, root.sy))
        }
        MouseArea {
            anchors.fill: parent
            enabled: pill.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                pill.forceActiveFocus()
                pill.clicked()
            }
        }
    }

    component TokenChip: Rectangle {
        id: tokenChip
        required property var token
        property bool selected: false
        property bool interactive: false
        property color accent: Style.Theme.acento
        property color onAccent: Style.Theme.texto_sobre_acento
        property real sx: 1
        property real sy: 1
        signal clicked()
        activeFocusOnTab: interactive
        width: Math.max(42 * sx, tokenText.implicitWidth + 16 * sx)
        height: Math.max(30, 34 * sy)
        radius: 8 * sx
        color: selected ? accent : Style.Theme.superficie_alterna
        border.color: selected ? accent : Style.Theme.borde_suave
        border.width: activeFocus || selected ? 2 : 1
        Accessible.role: Accessible.Button
        Accessible.name: "Seleccionar token " + (token && token.texto !== undefined
                                                   ? token.texto : "")
        Accessible.ignored: !interactive
        Accessible.onPressAction: if (tokenChip.interactive) tokenChip.clicked()
        Keys.onPressed: function(event) {
            if (tokenChip.interactive && (event.key === Qt.Key_Return
                                          || event.key === Qt.Key_Enter
                                          || event.key === Qt.Key_Space)) {
                tokenChip.clicked()
                event.accepted = true
            }
        }
        Text {
            id: tokenText
            anchors.centerIn: parent
            text: tokenChip.token && tokenChip.token.texto !== undefined
                  ? tokenChip.token.texto : "—"
            color: tokenChip.selected ? tokenChip.onAccent : Style.Theme.texto_secundario_fuerte
            font.bold: tokenChip.selected
            font.pixelSize: Math.max(11, 11 * Math.min(tokenChip.sx, tokenChip.sy))
        }
        MouseArea {
            anchors.fill: parent
            enabled: tokenChip.interactive
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                tokenChip.forceActiveFocus()
                tokenChip.clicked()
            }
        }
    }

    component Stepper: Row {
        id: stepper
        property int value: 1
        property int minimum: 1
        property int maximum: 1
        property color accent: Style.Theme.acento
        property color foreground: Style.Theme.texto_sobre_acento
        property real sx: 1
        property real sy: 1
        signal valueRequested(int value)
        spacing: 3 * sx
        Rectangle {
            id: decrementButton
            width: Math.max(26, 28 * stepper.sx); height: Math.max(26, 28 * stepper.sy); radius: 7 * stepper.sx
            color: Style.Theme.superficie_alterna; border.color: stepper.accent
            border.width: activeFocus ? 2 : 1
            opacity: enabled ? 1 : 0.45
            enabled: stepper.value > stepper.minimum
            activeFocusOnTab: enabled
            Accessible.role: Accessible.Button
            Accessible.name: "Valor anterior"
            Accessible.onPressAction: if (decrementButton.enabled) stepper.valueRequested(stepper.value - 1)
            Keys.onPressed: function(event) {
                if (decrementButton.enabled && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                || event.key === Qt.Key_Space)) {
                    stepper.valueRequested(stepper.value - 1)
                    event.accepted = true
                }
            }
            Text { anchors.centerIn: parent; text: "−"; color: stepper.accent; font.bold: true; font.pixelSize: Math.max(13, 15 * stepper.sx) }
            MouseArea {
                anchors.fill: parent
                enabled: decrementButton.enabled
                onClicked: {
                    decrementButton.forceActiveFocus()
                    stepper.valueRequested(stepper.value - 1)
                }
                cursorShape: Qt.PointingHandCursor
            }
        }
        Rectangle {
            width: Math.max(34, 38 * stepper.sx); height: Math.max(26, 28 * stepper.sy); radius: 7 * stepper.sx
            color: stepper.accent
            Text { anchors.centerIn: parent; text: stepper.value; color: stepper.foreground; font.bold: true; font.pixelSize: Math.max(11, 11 * stepper.sx) }
        }
        Rectangle {
            id: incrementButton
            width: Math.max(26, 28 * stepper.sx); height: Math.max(26, 28 * stepper.sy); radius: 7 * stepper.sx
            color: Style.Theme.superficie_alterna; border.color: stepper.accent
            border.width: activeFocus ? 2 : 1
            opacity: enabled ? 1 : 0.45
            enabled: stepper.value < stepper.maximum
            activeFocusOnTab: enabled
            Accessible.role: Accessible.Button
            Accessible.name: "Valor siguiente"
            Accessible.onPressAction: if (incrementButton.enabled) stepper.valueRequested(stepper.value + 1)
            Keys.onPressed: function(event) {
                if (incrementButton.enabled && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                || event.key === Qt.Key_Space)) {
                    stepper.valueRequested(stepper.value + 1)
                    event.accepted = true
                }
            }
            Text { anchors.centerIn: parent; text: "+"; color: stepper.accent; font.bold: true; font.pixelSize: Math.max(12, 13 * stepper.sx) }
            MouseArea {
                anchors.fill: parent
                enabled: incrementButton.enabled
                onClicked: {
                    incrementButton.forceActiveFocus()
                    stepper.valueRequested(stepper.value + 1)
                }
                cursorShape: Qt.PointingHandCursor
            }
        }
    }

    component ContextStep: Rectangle {
        id: contextStep
        property string eyebrow: ""
        property string stepText: ""
        property color accent: Style.Theme.texto_secundario
        property bool highlighted: false
        property real sx: 1
        property real sy: 1

        implicitWidth: 94 * sx
        implicitHeight: contextStepColumn.implicitHeight + 14 * sy
        radius: 8 * sx
        color: highlighted ? Qt.alpha(accent, 0.12) : Style.Theme.surface
        border.color: highlighted ? accent : Style.Theme.borde_suave
        border.width: highlighted ? 2 : 1

        ColumnLayout {
            id: contextStepColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 7 * contextStep.sx
            spacing: 2 * contextStep.sy

            Text {
                Layout.fillWidth: true
                text: contextStep.eyebrow
                color: contextStep.accent
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Math.max(9, 9 * contextStep.sx)
            }
            Text {
                Layout.fillWidth: true
                text: contextStep.stepText
                color: contextStep.highlighted
                       ? Style.Theme.texto_primario : Style.Theme.texto_secundario_fuerte
                font.bold: contextStep.highlighted
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                lineHeight: 1.12
                font.pixelSize: Math.max(10, 10 * contextStep.sx)
            }
        }
    }

    component InfoCard: Rectangle {
        id: infoCard
        property string eyebrow: ""
        property string body: ""
        property string bodyObjectName: ""
        property color accent: Style.Theme.acento
        property bool monospace: false
        property real sx: 1
        implicitHeight: infoColumn.implicitHeight + 20 * sx
        radius: 10 * sx
        color: Style.Theme.superficie_alterna
        border.color: accent
        Column {
            id: infoColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10 * infoCard.sx
            spacing: 5 * infoCard.sx
            Text {
                text: infoCard.eyebrow
                color: infoCard.accent
                font.bold: true
                font.pixelSize: Math.max(11, 10 * infoCard.sx)
            }
            Text {
                objectName: infoCard.bodyObjectName
                width: parent.width
                text: infoCard.body
                color: Style.Theme.texto_secundario_fuerte
                wrapMode: Text.WordWrap
                font.family: infoCard.monospace
                             ? Style.Theme.fuente_mono
                             : Style.Theme.fuente_interfaz
                lineHeight: 1.20
                font.pixelSize: Math.max(12, 12 * infoCard.sx)
            }
        }
    }
}
