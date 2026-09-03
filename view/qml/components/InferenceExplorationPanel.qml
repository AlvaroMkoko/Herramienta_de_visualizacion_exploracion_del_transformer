pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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
    property int branchIndex: 0 // 0 encoder · 1 decoder causal · 2 cross-attention
    property int layerIndex: Math.max(0, Number(metadata.num_layers || 1) - 1)
    property int headIndex: 0
    property bool residualUsesFfn: false
    property bool reducedMotion: false

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
    readonly property var stage: stages[stageIndex]

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
        stageIndex = Math.max(0, Math.min(stages.length - 1, index))
        if (stageIndex === 0 || stageIndex === 3 || stageIndex === 5)
            branchIndex = Math.min(branchIndex, 1)
    }

    function setBranch(index) {
        branchIndex = index
        clampSelections()
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

    onMetadataChanged: clampSelections()

    Rectangle {
        anchors.fill: parent
        radius: 18 * root.sx
        color: "#F5F7FB"
        border.color: "#CBD5E1"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16 * root.sx
            spacing: 10 * root.sy

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 54 * root.sy
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
                        text: "Exploración visual de la inferencia"
                        color: "#0F172A"
                        font.bold: true
                        font.pixelSize: 23 * Math.min(root.sx, root.sy)
                    }
                    Text {
                        text: root.currentSnapshot
                              ? "Forward real · token " + root.currentSnapshot.paso + "/" + root.snapshots.length
                                + " · elegido “" + root.currentSnapshot.token_elegido.texto + "”"
                              : "Genera un token para capturar su recorrido"
                        color: "#64748B"
                        font.pixelSize: 11 * Math.min(root.sx, root.sy)
                    }
                }

                Rectangle {
                    Layout.preferredWidth: dataChipText.implicitWidth + 24 * root.sx
                    Layout.preferredHeight: 32 * root.sy
                    radius: height / 2
                    color: root.detailAvailable || root.stageIndex === 6 ? "#DCFCE7" : "#FEF3C7"
                    border.color: root.detailAvailable || root.stageIndex === 6 ? "#86EFAC" : "#FCD34D"
                    Text {
                        id: dataChipText
                        anchors.centerIn: parent
                        text: root.detailAvailable || root.stageIndex === 6 ? "● Datos reales" : "Captura no disponible"
                        color: root.detailAvailable || root.stageIndex === 6 ? "#166534" : "#92400E"
                        font.bold: true
                        font.pixelSize: 10 * Math.min(root.sx, root.sy)
                    }
                }

                ActionPill {
                    Layout.preferredWidth: 150 * root.sx
                    Layout.preferredHeight: 36 * root.sy
                    label: root.tokenProcessing ? "Calculando…" : "+ Siguiente token"
                    enabled: root.canGenerateNext && !root.tokenProcessing
                    accent: "#4F46E5"
                    onClicked: root.nextTokenRequested()
                }
                ActionPill {
                    Layout.preferredWidth: 126 * root.sx
                    Layout.preferredHeight: 36 * root.sy
                    label: root.reducedMotion ? "Movimiento: no" : "Movimiento: sí"
                    selected: !root.reducedMotion
                    accent: "#64748B"
                    onClicked: root.reducedMotion = !root.reducedMotion
                }
                ActionPill {
                    Layout.preferredWidth: 42 * root.sx
                    Layout.preferredHeight: 36 * root.sy
                    label: "✕"
                    accent: "#DC2626"
                    onClicked: root.closeRequested()
                }
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
                        color: "#64748B"
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
                        color: "#64748B"
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
                            accent: root.stage.accent
                            sx: root.sx
                            sy: root.sy
                            onClicked: root.stepSelected(index)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48 * root.sy
                radius: 11 * root.sx
                color: "#FFFFFF"
                border.color: "#D8E0EA"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6 * root.sx
                    spacing: 7 * root.sx

                    Text {
                        text: "CONTROLES SINCRONIZADOS"
                        color: "#64748B"
                        font.bold: true
                        font.pixelSize: 9 * root.sx
                    }

                    Repeater {
                        model: root.stageIndex === 1 || root.stageIndex === 2 || root.stageIndex === 4
                               ? ["Encoder", "Decoder causal", "Cruzada"]
                               : (root.stageIndex < 6 ? ["Encoder", "Decoder"] : [])
                        delegate: ActionPill {
                            required property string modelData
                            required property int index
                            Layout.preferredWidth: Math.max(88 * root.sx, implicitWidth)
                            Layout.preferredHeight: 32 * root.sy
                            label: modelData
                            selected: root.branchIndex === index
                            accent: root.stage.accent
                            onClicked: root.setBranch(index)
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: root.stageIndex >= 1 && root.stageIndex <= 4
                        text: "CAPA"
                        color: "#64748B"
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
                        color: "#64748B"
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
                        visible: root.stageIndex === 4
                        Layout.preferredWidth: 132 * root.sx
                        Layout.preferredHeight: 32 * root.sy
                        label: root.residualUsesFfn ? "Subcapa: FFN" : "Subcapa: atención"
                        selected: root.residualUsesFfn
                        accent: root.stage.accent
                        onClicked: root.residualUsesFfn = !root.residualUsesFfn
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 560 * root.sy
                spacing: 10 * root.sx

                Rectangle {
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
                        currentIndex: root.stageIndex

                        EmbeddingPositionScene {
                            projection: root.currentProjection
                            tokens: root.currentTokens
                            active: root.stageIndex === 0 && root.detailAvailable
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
                            active: root.stageIndex === 1 && root.detailAvailable
                            reducedMotion: root.reducedMotion
                            sx: root.sx
                            sy: root.sy
                            onHeadSelected: function(index) { root.headIndex = index }
                        }
                        MultiHeadSplitScene {
                            metadata: root.metadata
                            attentionData: root.currentAttention
                            active: root.stageIndex === 2 && root.detailAvailable
                            reducedMotion: root.reducedMotion
                            sx: root.sx
                            sy: root.sy
                        }
                        FeedForwardExpansionScene {
                            sceneData: root.currentFfn
                            tokens: root.currentTokens
                            active: root.stageIndex === 3 && root.detailAvailable
                            reducedMotion: root.reducedMotion
                            sx: root.sx
                            sy: root.sy
                        }
                        ResidualLayerNormScene {
                            sceneData: root.currentResidual
                            active: root.stageIndex === 4 && root.detailAvailable
                            reducedMotion: root.reducedMotion
                            sublayerLabel: root.residualUsesFfn ? "FFN" : "Atención"
                            sx: root.sx
                            sy: root.sy
                        }
                        LayerSkyscraperScene {
                            trajectory: root.currentTrajectory
                            tokens: root.currentTokens
                            active: root.stageIndex === 5 && root.detailAvailable
                            sx: root.sx
                            sy: root.sy
                        }
                        SoftmaxRaceScene {
                            snapshots: root.snapshots
                            initialStep: root.selectedIndex
                            active: root.stageIndex === 6
                            reducedMotion: root.reducedMotion
                            sx: root.sx
                            sy: root.sy
                            onStepSelected: function(index) { root.stepSelected(index) }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 12 * root.sx
                        visible: root.stageIndex < 6 && !root.detailAvailable
                        radius: 12 * root.sx
                        color: "#F8FAFC"
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
                                color: "#0F172A"
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                font.pixelSize: 19 * Math.min(root.sx, root.sy)
                            }
                            Text {
                                width: parent.width
                                text: "Selecciona el último token de la cinta superior. El historial anterior conserva probabilidades para la carrera softmax, pero no duplica todos los tensores."
                                color: "#64748B"
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                font.pixelSize: 12 * Math.min(root.sx, root.sy)
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 350 * root.sx
                    Layout.minimumWidth: 320 * root.sx
                    Layout.maximumWidth: 370 * root.sx
                    Layout.fillHeight: true
                    radius: 14 * root.sx
                    color: "#FFFFFF"
                    border.color: root.stage.accent
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14 * root.sx
                        spacing: 10 * root.sy

                        TransformerMiniMap {
                            objectName: "inferenceTransformerMiniMap"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 272 * root.sy
                            stageIndex: root.stageIndex
                            branchIndex: root.branchIndex
                            residualUsesFfn: root.residualUsesFfn
                            accent: root.stage.accent
                            reducedMotion: root.reducedMotion
                            sx: root.sx
                            sy: root.sy
                        }

                    ScrollView {
                        id: pedagogicalScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: availableWidth

                        ColumnLayout {
                            width: pedagogicalScroll.availableWidth
                            spacing: 12 * root.sy

                            Text {
                                Layout.fillWidth: true
                                text: root.stage.eyebrow
                                color: root.stage.accent
                                font.bold: true
                                font.letterSpacing: 0.7
                                font.pixelSize: 10 * root.sx
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.stage.title
                                color: "#0F172A"
                                font.bold: true
                                wrapMode: Text.WordWrap
                                font.pixelSize: 23 * Math.min(root.sx, root.sy)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.stage.concept
                                color: "#334155"
                                wrapMode: Text.WordWrap
                                lineHeight: 1.22
                                font.pixelSize: 12 * root.sx
                            }
                            Button {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(38, 44 * root.sy)
                                text: "ⓘ  Abrir explicación completa"
                                font.bold: true
                                font.pixelSize: Math.max(12, 12 * root.sx)
                                onClicked: root.theoryRequested(root.stage.conceptId)
                                ToolTip.visible: hovered
                                ToolTip.text: "Leer este concepto en una ventana amplia"
                                Accessible.name: "Abrir explicación completa de " + root.stage.title
                            }
                            InfoCard {
                                Layout.fillWidth: true
                                eyebrow: "OPERACIÓN"
                                body: root.stage.formula
                                accent: root.stage.accent
                                monospace: true
                                sx: root.sx
                            }
                            InfoCard {
                                Layout.fillWidth: true
                                eyebrow: "PRUEBA A HACER"
                                body: root.stage.hint
                                accent: "#0284C7"
                                sx: root.sx
                            }
                            InfoCard {
                                Layout.fillWidth: true
                                eyebrow: "DATOS DE ESTA CAPTURA"
                                body: root.evidenceText()
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
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 11 * root.sx
                                    text: "⚠  " + root.stage.caveat
                                    color: "#9A3412"
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.18
                                    font.pixelSize: 10 * root.sx
                                }
                            }
                        }
                    }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 74 * root.sy
                radius: 12 * root.sx
                color: "#FFFFFF"
                border.color: "#D8E0EA"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 7 * root.sx
                    spacing: 6 * root.sx

                    Repeater {
                        model: root.stages
                        delegate: Rectangle {
                            id: stageButton
                            required property var modelData
                            required property int index
                            objectName: "inferenceSceneButton" + index
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 9 * root.sx
                            color: root.stageIndex === index ? modelData.accent : "#F8FAFC"
                            border.color: root.stageIndex === index ? modelData.accent : "#D8E0EA"
                            border.width: root.stageIndex === index ? 2 : 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 7 * root.sx
                                spacing: 7 * root.sx
                                Rectangle {
                                    Layout.preferredWidth: 26 * root.sx
                                    Layout.preferredHeight: 26 * root.sy
                                    radius: height / 2
                                    color: root.stageIndex === stageButton.index ? "#33FFFFFF" : stageButton.modelData.accent
                                    Text {
                                        anchors.centerIn: parent
                                        text: stageButton.index + 1
                                        color: "white"
                                        font.bold: true
                                        font.pixelSize: 10 * root.sx
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: stageButton.modelData.short
                                    color: root.stageIndex === stageButton.index ? "white" : "#334155"
                                    font.bold: root.stageIndex === stageButton.index
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    font.pixelSize: 9 * root.sx
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setStage(stageButton.index)
                            }
                        }
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
        implicitWidth: pillText.implicitWidth + 24 * root.sx
        implicitHeight: 32 * root.sy
        radius: height / 2
        color: !enabled ? "#F1F5F9" : (selected ? accent : "#FFFFFF")
        border.color: !enabled ? "#CBD5E1" : accent
        opacity: enabled ? 1 : 0.55
        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            color: pill.selected ? "white" : (pill.enabled ? pill.accent : "#94A3B8")
            font.bold: true
            font.pixelSize: 10 * Math.min(root.sx, root.sy)
        }
        MouseArea {
            anchors.fill: parent
            enabled: pill.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    component TokenChip: Rectangle {
        id: tokenChip
        required property var token
        property bool selected: false
        property color accent: "#4F46E5"
        property real sx: 1
        property real sy: 1
        signal clicked()
        width: Math.max(42 * sx, tokenText.implicitWidth + 16 * sx)
        height: 34 * sy
        radius: 8 * sx
        color: selected ? accent : "#F8FAFC"
        border.color: selected ? accent : "#CBD5E1"
        border.width: selected ? 2 : 1
        Text {
            id: tokenText
            anchors.centerIn: parent
            text: tokenChip.token && tokenChip.token.texto !== undefined
                  ? tokenChip.token.texto : "—"
            color: tokenChip.selected ? "white" : "#1E293B"
            font.bold: tokenChip.selected
            font.pixelSize: 10 * Math.min(tokenChip.sx, tokenChip.sy)
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tokenChip.clicked()
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
            width: 28 * stepper.sx; height: 28 * stepper.sy; radius: 7 * stepper.sx
            color: "#F8FAFC"; border.color: stepper.accent
            Text { anchors.centerIn: parent; text: "−"; color: stepper.accent; font.bold: true; font.pixelSize: 15 * stepper.sx }
            MouseArea { anchors.fill: parent; enabled: stepper.value > stepper.minimum; onClicked: stepper.valueRequested(stepper.value - 1); cursorShape: Qt.PointingHandCursor }
        }
        Rectangle {
            width: 38 * stepper.sx; height: 28 * stepper.sy; radius: 7 * stepper.sx
            color: stepper.accent
            Text { anchors.centerIn: parent; text: stepper.value; color: "white"; font.bold: true; font.pixelSize: 10 * stepper.sx }
        }
        Rectangle {
            width: 28 * stepper.sx; height: 28 * stepper.sy; radius: 7 * stepper.sx
            color: "#F8FAFC"; border.color: stepper.accent
            Text { anchors.centerIn: parent; text: "+"; color: stepper.accent; font.bold: true; font.pixelSize: 13 * stepper.sx }
            MouseArea { anchors.fill: parent; enabled: stepper.value < stepper.maximum; onClicked: stepper.valueRequested(stepper.value + 1); cursorShape: Qt.PointingHandCursor }
        }
    }

    component InfoCard: Rectangle {
        id: infoCard
        property string eyebrow: ""
        property string body: ""
        property color accent: "#4F46E5"
        property bool monospace: false
        property real sx: 1
        implicitHeight: infoColumn.implicitHeight + 20 * sx
        radius: 10 * sx
        color: "#F8FAFC"
        border.color: accent
        Column {
            id: infoColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10 * infoCard.sx
            spacing: 5 * infoCard.sx
            Text { text: infoCard.eyebrow; color: infoCard.accent; font.bold: true; font.pixelSize: 9 * infoCard.sx }
            Text {
                width: parent.width
                text: infoCard.body
                color: "#1E293B"
                wrapMode: Text.WordWrap
                font.family: infoCard.monospace ? "monospace" : "sans-serif"
                font.pixelSize: 10 * infoCard.sx
            }
        }
    }
}
