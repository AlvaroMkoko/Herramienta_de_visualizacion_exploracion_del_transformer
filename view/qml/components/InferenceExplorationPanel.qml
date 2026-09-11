pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
    property bool guideVisible: true

    // Las 31 operaciones siguen disponibles, pero la orientacion principal
    // se resume en cuatro etapas que corresponden al recorrido completo.
    readonly property var processChapters: [
        {
            id: "encoder",
            label: "Encoder",
            caption: "comprende el prompt",
            accent: "#2563EB"
        },
        {
            id: "decoder_causal",
            label: "Decoder causal",
            caption: "usa lo ya generado",
            accent: "#7C3AED"
        },
        {
            id: "cross_attention",
            label: "Decoder + contexto",
            caption: "consulta el prompt y refina",
            accent: "#B45309"
        },
        {
            id: "output",
            label: "Salida",
            caption: "elige el próximo token",
            accent: "#DC2626"
        }
    ]
    readonly property int processChapterIndex: chapterForOperation(operationIndex)
    readonly property var currentProcessChapter: processChapters[
        Math.max(0, Math.min(processChapters.length - 1, processChapterIndex))]
    readonly property int chapterStep: chapterStepForOperation(operationIndex)
    readonly property int chapterStepCount: chapterStepCountForOperation(operationIndex)
    readonly property color processAccent: currentProcessChapter.accent || "#4F46E5"

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
            accent: "#7C3AED",
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
            accent: "#0284C7",
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
            accent: "#D97706",
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
            accent: "#DB2777",
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
            accent: "#059669",
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
            accent: "#4F46E5",
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
            accent: "#DC2626",
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

    onMetadataChanged: clampSelections()
    onOperationIndexChanged: {
        synchronizeOperation()
        resetPedagogicalReading()
    }
    onGuideVisibleChanged: {
        if (!guideVisible)
            resetPedagogicalReading()
    }

    InferenceFlowSteps {
        id: flowModel
    }

    Timer {
        id: sequenceTimer
        running: root.sequencePlaying
        repeat: false
        interval: Math.max(1200, Number(root.operation.duration || 4200))
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

    Rectangle {
        anchors.fill: parent
        radius: 18 * root.sx
        color: "#F5F7FB"
        border.color: Style.Theme.borde_suave
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16 * root.sx
            spacing: 10 * root.sy

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 50 * root.sy
                spacing: 10 * root.sx

                Rectangle {
                    Layout.preferredWidth: 42 * root.sx
                    Layout.preferredHeight: 42 * root.sy
                    radius: 12 * Math.min(root.sx, root.sy)
                    color: root.stage.accent
                    Text {
                        anchors.centerIn: parent
                        text: "✦"
                        color: "white"
                        font.pixelSize: 20 * Math.min(root.sx, root.sy)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1 * root.sy
                    Text {
                        text: "Cómo se genera el siguiente token"
                        color: Style.Theme.texto_primario
                        font.bold: true
                        font.pixelSize: 23 * Math.min(root.sx, root.sy)
                    }
                    Text {
                        text: root.currentSnapshot
                              ? "Explicando el token " + root.currentSnapshot.paso + "/" + root.snapshots.length
                                + ": “" + root.currentSnapshot.token_elegido.texto + "”"
                              : "Genera un token para capturar su recorrido"
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 11 * Math.min(root.sx, root.sy)
                    }
                }

                Rectangle {
                    Layout.preferredWidth: dataChipText.implicitWidth + 24 * root.sx
                    Layout.preferredHeight: 32 * root.sy
                    radius: height / 2
                    color: root.operationDataAvailable ? "#DCFCE7" : "#FEF3C7"
                    border.color: root.operationDataAvailable ? "#86EFAC" : "#FCD34D"
                    Text {
                        id: dataChipText
                        anchors.centerIn: parent
                        text: root.operationDataAvailable ? "● Datos reales" : "Captura no disponible"
                        color: root.operationDataAvailable ? "#166534" : "#92400E"
                        font.bold: true
                        font.pixelSize: 10 * Math.min(root.sx, root.sy)
                    }
                }

                ActionPill {
                    objectName: "inferenceNextTokenButton"
                    visible: root.canGenerateNext || root.tokenProcessing
                    Layout.preferredWidth: 150 * root.sx
                    Layout.preferredHeight: 36 * root.sy
                    label: root.tokenProcessing ? "Calculando…" : "+ Siguiente token"
                    enabled: root.canGenerateNext && !root.tokenProcessing
                    accent: "#4F46E5"
                    onClicked: root.nextTokenRequested()
                }
                CheckBox {
                    objectName: "inferenceReducedMotionToggle"
                    Layout.preferredWidth: Math.max(142, 166 * root.sx)
                    text: "Reducir movimiento"
                    checked: root.reducedMotion
                    font.pixelSize: Math.max(10, 10 * root.sx)
                    onToggled: root.reducedMotion = checked
                    Accessible.description: "Detiene las transiciones decorativas de las escenas"
                }
                ActionPill {
                    objectName: "inferenceGuideToggle"
                    Layout.preferredWidth: Math.max(145, 190 * root.sx)
                    Layout.preferredHeight: 36 * root.sy
                    label: root.guideVisible
                           ? "Ocultar explicación"
                           : "Mostrar explicación"
                    accent: Style.Theme.texto_secundario
                    onClicked: root.guideVisible = !root.guideVisible
                }
                ActionPill {
                    objectName: "inferenceCloseButton"
                    Layout.preferredWidth: 42 * root.sx
                    Layout.preferredHeight: 36 * root.sy
                    label: "✕"
                    accent: "#DC2626"
                    onClicked: root.closeRequested()
                }
            }

            InferenceProcessMap {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(64, 96 * root.sy)
                chapters: root.processChapters
                currentIndex: root.processChapterIndex
                currentStep: root.chapterStep
                currentStepCount: root.chapterStepCount
                accent: root.processAccent
                sx: root.sx
                sy: root.sy
                onChapterSelected: function(index) { root.selectChapter(index) }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 58 * root.sy
                radius: 11 * root.sx
                color: "#FFFFFF"
                border.color: "#D8E0EA"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8 * root.sx
                    spacing: 8 * root.sx

                    Text {
                        text: "PROMPT"
                        color: Style.Theme.texto_secundario
                        font.bold: true
                        font.pixelSize: 9 * root.sx
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        orientation: ListView.Horizontal
                        spacing: 5 * root.sx
                        clip: true
                        model: root.currentSnapshot ? root.currentSnapshot.tokens_entrada : []
                        delegate: TokenChip {
                            required property var modelData
                            token: modelData
                            selected: false
                            accent: root.stage.accent
                            sx: root.sx
                            sy: root.sy
                        }
                    }
                    Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: "#D8E0EA" }
                    Text {
                        text: "SALIDA"
                        color: Style.Theme.texto_secundario
                        font.bold: true
                        font.pixelSize: 9 * root.sx
                    }
                    ListView {
                        Layout.preferredWidth: 430 * root.sx
                        Layout.fillHeight: true
                        orientation: ListView.Horizontal
                        layoutDirection: Qt.RightToLeft
                        spacing: 5 * root.sx
                        clip: true
                        model: root.snapshots
                        delegate: TokenChip {
                            required property var modelData
                            required property int index
                            token: modelData.token_elegido
                            selected: index === root.selectedIndex
                            interactive: true
                            accent: root.stage.accent
                            sx: root.sx
                            sy: root.sy
                            onClicked: root.selectSnapshot(index)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 48 * root.sy : 0
                visible: root.stageIndex >= 1 && root.stageIndex <= 4
                radius: 11 * root.sx
                color: "#FFFFFF"
                border.color: "#D8E0EA"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6 * root.sx
                    spacing: 7 * root.sx

                    Text {
                        text: "AJUSTA LA ANIMACIÓN"
                        color: Style.Theme.texto_secundario
                        font.bold: true
                        font.pixelSize: Math.max(9, 9 * root.sx)
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
                            font.pixelSize: Math.max(9, 9 * root.sx)
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: root.stageIndex >= 1 && root.stageIndex <= 4
                        text: "CAPA"
                        color: Style.Theme.texto_secundario
                        font.bold: true
                        font.pixelSize: 9 * root.sx
                    }
                    Stepper {
                        visible: root.stageIndex >= 1 && root.stageIndex <= 4
                        value: root.layerIndex + 1
                        minimum: 1
                        maximum: Math.max(1, Number(root.metadata.num_layers || 1))
                        accent: root.stage.accent
                        sx: root.sx
                        sy: root.sy
                        onValueRequested: function(value) { root.layerIndex = value - 1 }
                    }

                    Text {
                        visible: root.stageIndex === 1
                        text: "CABEZA"
                        color: Style.Theme.texto_secundario
                        font.bold: true
                        font.pixelSize: 9 * root.sx
                    }
                    Stepper {
                        visible: root.stageIndex === 1
                        value: root.headIndex + 1
                        minimum: 1
                        maximum: Math.max(1, Number(root.metadata.num_heads || 1))
                        accent: root.stage.accent
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

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 560 * root.sy
                spacing: 10 * root.sx

                Rectangle {
                    objectName: "inferenceAnimationViewport"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 1120 * root.sx
                    radius: 14 * root.sx
                    color: "#FFFFFF"
                    border.color: "#D8E0EA"
                    clip: true

                    StackLayout {
                        anchors.fill: parent
                        anchors.margins: 12 * root.sx
                        currentIndex: Number(root.operation.visualIndex || 0)

                        TokenEmbeddingScene {
                            tensorData: root.currentEmbeddingTensor
                            tokens: root.currentTokens
                            active: Number(root.operation.visualIndex) === 0 && root.detailAvailable
                            reducedMotion: root.reducedMotion
                            sx: root.sx
                            sy: root.sy
                        }

                        EmbeddingPositionScene {
                            projection: root.currentProjection
                            tokens: root.currentTokens
                            active: Number(root.operation.visualIndex) === 1 && root.detailAvailable
                            reducedMotion: root.reducedMotion
                            sx: root.sx
                            sy: root.sy
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
                            sx: root.sx
                            sy: root.sy
                        }
                        AttentionFlowScene {
                            attentionData: root.currentAttention
                            queryTokens: root.currentTokens
                            keyTokens: root.keyTokens
                            crossAttention: root.branchIndex === 2
                            headIndex: root.headIndex
                            active: Number(root.operation.visualIndex) === 3 && root.detailAvailable
                            reducedMotion: root.reducedMotion
                            sx: root.sx
                            sy: root.sy
                            onHeadSelected: function(index) { root.headIndex = index }
                        }
                        MultiHeadSplitScene {
                            metadata: root.metadata
                            attentionData: root.currentAttention
                            active: Number(root.operation.visualIndex) === 4 && root.detailAvailable
                            reducedMotion: root.reducedMotion
                            sx: root.sx
                            sy: root.sy
                        }
                        FeedForwardExpansionScene {
                            sceneData: root.currentFfn
                            tokens: root.currentTokens
                            active: Number(root.operation.visualIndex) === 5 && root.detailAvailable
                            reducedMotion: root.reducedMotion
                            sx: root.sx
                            sy: root.sy
                        }
                        ResidualLayerNormScene {
                            sceneData: root.currentResidual
                            active: Number(root.operation.visualIndex) === 6 && root.detailAvailable
                            reducedMotion: root.reducedMotion
                            sublayerLabel: root.residualUsesFfn ? "FFN" : "Atención"
                            sx: root.sx
                            sy: root.sy
                        }
                        LayerSkyscraperScene {
                            trajectory: root.currentTrajectory
                            tokens: root.currentTokens
                            active: Number(root.operation.visualIndex) === 7 && root.detailAvailable
                            sx: root.sx
                            sy: root.sy
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
                            sx: root.sx
                            sy: root.sy
                        }
                        SoftmaxRaceScene {
                            snapshots: root.snapshots
                            initialStep: root.selectedIndex
                            active: Number(root.operation.visualIndex) === 9
                            reducedMotion: root.reducedMotion
                            sx: root.sx
                            sy: root.sy
                            onStepSelected: function(index) { root.stepSelected(index) }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 12 * root.sx
                        visible: Boolean(root.operation.requiresDetail) && !root.detailAvailable
                        radius: 12 * root.sx
                        color: Style.Theme.superficie_alterna
                        border.color: "#F59E0B"
                        Column {
                            anchors.centerIn: parent
                            width: Math.min(parent.width - 40 * root.sx, 520 * root.sx)
                            spacing: 12 * root.sy
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "◷"
                                color: "#D97706"
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

                Rectangle {
                    id: guidePanel
                    objectName: "inferencePedagogicalGuide"
                    visible: root.guideVisible
                    Layout.preferredWidth: visible ? Math.max(300, 370 * root.sx) : 0
                    Layout.minimumWidth: visible ? Math.max(280, 330 * root.sx) : 0
                    Layout.maximumWidth: visible ? Math.max(320, 410 * root.sx) : 0
                    Layout.fillHeight: true
                    radius: 14 * root.sx
                    color: "#FFFFFF"
                    border.color: root.stage.accent
                    border.width: 1

                    ScrollView {
                        id: pedagogicalScroll
                        anchors.fill: parent
                        anchors.margins: 14 * root.sx
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
                                        font.pixelSize: Math.max(9, 9 * root.sx)
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.operation.title || root.stage.title
                                color: Style.Theme.texto_primario
                                font.bold: true
                                wrapMode: Text.WordWrap
                                font.pixelSize: Math.max(18, 21 * Math.min(root.sx, root.sy))
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
                                        font.pixelSize: Math.max(9, 9 * root.sx)
                                    }
                                    Text {
                                        objectName: "inferenceEssentialExplanation"
                                        Layout.fillWidth: true
                                        text: root.operation.operation || root.stage.concept
                                        color: Style.Theme.texto_secundario_fuerte
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.18
                                        font.pixelSize: Math.max(11, 11 * root.sx)
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: visualColumn.implicitHeight + 22 * root.sy
                                radius: 10 * root.sx
                                color: "#EFF6FF"
                                border.color: "#93C5FD"

                                ColumnLayout {
                                    id: visualColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 11 * root.sx
                                    spacing: 5 * root.sy

                                    Text {
                                        text: "QUÉ OBSERVAR EN LA ANIMACIÓN"
                                        color: "#1D4ED8"
                                        font.bold: true
                                        font.pixelSize: Math.max(9, 9 * root.sx)
                                    }
                                    Text {
                                        objectName: "inferenceVisualGuide"
                                        Layout.fillWidth: true
                                        text: root.operation.visualMeaning || root.stage.hint
                                        color: "#1E3A5F"
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.18
                                        font.pixelSize: Math.max(11, 11 * root.sx)
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: nextStepText.implicitHeight + 18 * root.sy
                                radius: 9 * root.sx
                                color: "#FFFBEB"
                                border.color: "#FCD34D"

                                Text {
                                    id: nextStepText
                                    objectName: "inferenceNextStepText"
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 9 * root.sx
                                    text: "DESPUÉS  →  " + (root.operation.nextStep || "—")
                                    color: "#92400E"
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.16
                                    font.pixelSize: Math.max(10, 10 * root.sx)
                                }
                            }

                            Button {
                                objectName: "inferenceDetailsToggle"
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(38, 42 * root.sy)
                                text: root.detailsExpanded
                                      ? "Ocultar detalle técnico  ▴"
                                      : "Profundizar: fórmula y datos  ▾"
                                font.bold: true
                                font.pixelSize: Math.max(11, 11 * root.sx)
                                onClicked: root.detailsExpanded = !root.detailsExpanded
                                Accessible.name: root.detailsExpanded
                                                 ? "Ocultar detalle técnico"
                                                 : "Mostrar fórmula, datos y mapa técnico"
                            }

                            ColumnLayout {
                                id: advancedDetails
                                objectName: "inferenceAdvancedDetails"
                                Layout.fillWidth: true
                                visible: root.detailsExpanded
                                spacing: 10 * root.sy

                                InfoCard {
                                    Layout.fillWidth: true
                                    eyebrow: "FÓRMULA"
                                    body: root.operation.formula || root.stage.formula
                                    bodyObjectName: "inferenceFormulaText"
                                    accent: root.stage.accent
                                    monospace: true
                                    sx: root.sx
                                }
                                InfoCard {
                                    Layout.fillWidth: true
                                    eyebrow: "POR QUÉ SE NECESITA"
                                    body: root.operation.purpose || "—"
                                    bodyObjectName: "inferencePurposeText"
                                    accent: "#7C3AED"
                                    sx: root.sx
                                }
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
                                    color: "#FFF7ED"
                                    border.color: "#FDBA74"
                                    Text {
                                        id: caveatText
                                        objectName: "inferenceCaveatText"
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 11 * root.sx
                                        text: "⚠  " + (root.operation.caveat || root.stage.caveat)
                                        color: "#9A3412"
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.18
                                        font.pixelSize: Math.max(10, 10 * root.sx)
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "UBICACIÓN TÉCNICA"
                                    color: Style.Theme.texto_secundario
                                    font.bold: true
                                    font.pixelSize: Math.max(9, 9 * root.sx)
                                }
                                TransformerMiniMap {
                                    objectName: "inferenceTransformerMiniMap"
                                    visible: root.detailsExpanded
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 272 * root.sy
                                    stageIndex: root.stageIndex
                                    branchIndex: root.branchIndex
                                    residualUsesFfn: root.residualUsesFfn
                                    operationId: String(root.operation.id || "")
                                    accent: root.stage.accent
                                    reducedMotion: root.reducedMotion
                                    sx: root.sx
                                    sy: root.sy
                                }

                                Button {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.max(38, 44 * root.sy)
                                    text: "ⓘ  Abrir explicación completa"
                                    font.bold: true
                                    font.pixelSize: Math.max(11, 11 * root.sx)
                                    onClicked: root.theoryRequested(root.operation.conceptId || root.stage.conceptId)
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Leer este concepto en una ventana amplia"
                                    Accessible.name: "Abrir explicación completa de "
                                                     + (root.operation.title || root.stage.title)
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(56, 76 * root.sy)
                radius: 12 * root.sx
                color: "#FFFFFF"
                border.color: "#D8E0EA"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 7 * root.sx
                    spacing: 8 * root.sx

                    ActionPill {
                        objectName: "inferencePreviousOperationButton"
                        Layout.preferredWidth: 96 * root.sx
                        Layout.preferredHeight: 38 * root.sy
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
                                font.pixelSize: Math.max(10, 10 * root.sx)
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "  " + (root.operationIndex + 1) + "/" + root.flowSteps.length
                                color: Style.Theme.texto_secundario_fuerte
                                font.bold: true
                                font.pixelSize: Math.max(10, 10 * root.sx)
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
                        Layout.preferredWidth: 116 * root.sx
                        Layout.preferredHeight: 38 * root.sy
                        label: root.sequencePlaying ? "\u23f8 Pausar" : "\u25b6 Reproducir"
                        selected: root.sequencePlaying
                        accent: "#4F46E5"
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

                    ComboBox {
                        id: operationSelector
                        objectName: "inferenceOperationSelector"
                        Layout.preferredWidth: Math.max(180, 240 * root.sx)
                        Layout.preferredHeight: Math.max(38, 40 * root.sy)
                        model: root.flowSteps
                        textRole: "short"
                        currentIndex: root.operationIndex
                        displayText: "Ir al paso " + (root.operationIndex + 1)
                        font.pixelSize: Math.max(10, 10 * root.sx)
                        onActivated: function(index) { root.selectOperation(index) }
                        Accessible.name: "Elegir cualquiera de las 31 operaciones"
                    }

                    ActionPill {
                        objectName: "inferenceNextOperationButton"
                        Layout.preferredWidth: 96 * root.sx
                        Layout.preferredHeight: 38 * root.sy
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
        property color accent: "#4F46E5"
        signal clicked()
        activeFocusOnTab: enabled && visible
        implicitWidth: pillText.implicitWidth + 24 * root.sx
        implicitHeight: 32 * root.sy
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
            anchors.centerIn: parent
            text: pill.label
            color: pill.selected ? "white" : (pill.enabled ? pill.accent : Style.Theme.texto_terciario)
            font.bold: true
            font.pixelSize: Math.max(10, 10 * Math.min(root.sx, root.sy))
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
        property color accent: "#4F46E5"
        property real sx: 1
        property real sy: 1
        signal clicked()
        activeFocusOnTab: interactive
        width: Math.max(42 * sx, tokenText.implicitWidth + 16 * sx)
        height: 34 * sy
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
            color: tokenChip.selected ? "white" : Style.Theme.texto_secundario_fuerte
            font.bold: tokenChip.selected
            font.pixelSize: Math.max(9, 10 * Math.min(tokenChip.sx, tokenChip.sy))
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
        property color accent: "#4F46E5"
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
            Text { anchors.centerIn: parent; text: stepper.value; color: "white"; font.bold: true; font.pixelSize: Math.max(9, 10 * stepper.sx) }
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

    component InfoCard: Rectangle {
        id: infoCard
        property string eyebrow: ""
        property string body: ""
        property string bodyObjectName: ""
        property color accent: "#4F46E5"
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
                font.pixelSize: Math.max(9, 9 * infoCard.sx)
            }
            Text {
                objectName: infoCard.bodyObjectName
                width: parent.width
                text: infoCard.body
                color: Style.Theme.texto_secundario_fuerte
                wrapMode: Text.WordWrap
                font.family: infoCard.monospace ? "monospace" : "sans-serif"
                font.pixelSize: Math.max(10, 10 * infoCard.sx)
            }
        }
    }
}
