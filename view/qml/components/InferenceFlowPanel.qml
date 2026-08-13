pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var snapshots: []
    property var detailForward: ({})
    property int selectedIndex: snapshots.length > 0 ? snapshots.length - 1 : -1
    property real sx: 1
    property real sy: 1
    property bool canGenerateNext: false
    property bool tokenProcessing: false

    property int densityMode: 0 // Student, Developer, Researcher
    property int sceneIndex: 0
    property int branchIndex: 1 // Encoder, decoder causal, cross-attention
    property int layerIndex: Math.max(0, Number(metadata.num_layers || 1) - 1)
    property int headIndex: 0
    property int comparisonLayer: 0
    property bool comparisonEnabled: false
    property bool localScale: false
    property bool reducedMotion: false
    property bool playing: false
    property int speedIndex: 2
    property string exportStatus: ""
    property real keyRangeStart: 0
    property real keyRangeEnd: Math.max(0, attentionColumns - 1)
    property string detailEyebrow: ""
    property string detailTitle: ""
    property string detailSummary: ""
    property string detailBody: ""
    property string detailExample: ""
    property color detailAccent: "#0072B2"

    readonly property var currentSnapshot: (
        selectedIndex >= 0 && selectedIndex < snapshots.length
        ? snapshots[selectedIndex] : null
    )
    readonly property bool detailAvailable: currentSnapshot !== null
        && selectedIndex === snapshots.length - 1
        && detailForward && detailForward.metadata !== undefined
    readonly property var metadata: detailAvailable ? detailForward.metadata : ({})
    readonly property var globalData: detailAvailable && detailForward["global"]
                                              ? detailForward["global"] : ({})
    readonly property var branchLayers: {
        if (!detailAvailable)
            return []
        if (branchIndex === 0)
            return detailForward.encoder || []
        return detailForward.decoder || []
    }
    readonly property var layerData: branchLayers.length
        ? branchLayers[Math.max(0, Math.min(branchLayers.length - 1, layerIndex))] : ({})
    readonly property var comparisonData: branchLayers.length
        ? branchLayers[Math.max(0, Math.min(branchLayers.length - 1, comparisonLayer))] : ({})
    readonly property var attentionData: attentionFromLayer(layerData)
    readonly property var comparisonAttention: attentionFromLayer(comparisonData)
    readonly property var residualAttention: residualFromLayer(layerData)
    readonly property var ffnData: layerData.ffn || ({})
    readonly property var residualFfn: layerData.residual_ffn || ({})
    readonly property int attentionColumns: attentionData.atencion && attentionData.atencion.length
        ? attentionData.atencion[0].length : 0
    readonly property var scene: sceneDefinitions[sceneIndex]
    readonly property var speeds: [0.25, 0.5, 1, 2, 4]

    readonly property var sceneDefinitions: [
        { title: "Texto → tokens", short: "Tokens", duration: 1500,
          concept: "El tokenizador segmenta el texto en unidades discretas. Cada token conserva una identidad estable, su ID, posición y offsets cuando el tokenizer los expone.",
          formula: "texto → tokenizer(texto) = [id₀, …, idₙ]", input: "texto · string", output: "token_ids · [T] · int64" },
        { title: "Embeddings", short: "Embedding", duration: 1500,
          concept: "Cada ID indexa una fila aprendida de la tabla de embeddings. La matriz mostrada contiene valores reales del forward; las barras resumen su norma L2 por token.",
          formula: "E = W_embed[token_ids] · √d_model", input: "token_ids · [B,T] · int64", output: "E · [B,T,d_model] · float" },
        { title: "Señal posicional", short: "Posición", duration: 1000,
          concept: "Este modelo usa codificación sinusoidal aditiva. Se muestran por separado contenido, posición y la suma que entra al primer bloque.",
          formula: "X₀ = E·√d_model + PE", input: "E y PE · [B,T,d_model]", output: "X₀ · [B,T,d_model]" },
        { title: "Proyecciones Q, K y V", short: "Q/K/V", duration: 2000,
          concept: "Cada cabeza proyecta la representación en consultas, llaves y valores. Q busca; K permite comparar; V contiene la información que después se mezcla.",
          formula: "Q=XWQ,  K=XKVWK,  V=XKVWV", input: "X · [B,T,d_model]", output: "Q,K,V · [B,H,T,d_head]" },
        { title: "Scores escalados", short: "QKᵀ", duration: 2000,
          concept: "El producto consulta–llave mide compatibilidad interna. Es un score firmado, no una probabilidad, por eso usa una escala divergente centrada en cero.",
          formula: "S = QKᵀ / √d_head", input: "Q · [B,H,Tq,D], K · [B,H,Tk,D]", output: "S · [B,H,Tq,Tk]" },
        { title: "Aplicación de máscara", short: "Máscara", duration: 1000,
          concept: "Las posiciones prohibidas se sustituyen por −∞ antes de softmax. El tramado significa bloqueado; no significa que el score numérico fuera cero.",
          formula: "S'ᵢⱼ = Sᵢⱼ si permitido; −∞ si bloqueado", input: "scores + máscara booleana", output: "scores enmascarados" },
        { title: "Softmax de atención", short: "Atención", duration: 2000,
          concept: "Softmax convierte cada fila válida en una distribución 0–1. Estos pesos describen mezcla interna y por sí solos no demuestran una causa de la predicción.",
          formula: "A = softmax(S')", input: "S' · [B,H,Tq,Tk]", output: "A · [B,H,Tq,Tk]" },
        { title: "Atención ponderada A·V", short: "A·V", duration: 2000,
          concept: "El peso Aᵢⱼ y la contribución ‖AᵢⱼVⱼ‖ son magnitudes distintas. Esta vista muestra explícitamente la norma de la contribución vectorial.",
          formula: "Zᵢ = Σⱼ AᵢⱼVⱼ", input: "A y V", output: "Z · [B,H,Tq,d_head]" },
        { title: "Multi-head y proyección Wᴼ", short: "Multi-head", duration: 2000,
          concept: "Las salidas de las cabezas se concatenan y una proyección aprendida las devuelve a d_model. Cada cabeza mantiene su etiqueta H01, H02… además del color.",
          formula: "MHA = Concat(Z₁,…,Zₕ)Wᴼ", input: "Z · [B,H,T,d_head]", output: "MHA · [B,T,d_model]" },
        { title: "Residual y normalización", short: "Add+Norm", duration: 3000,
          concept: "La actualización se suma a la entrada y después se normaliza: esta arquitectura es post-norm. Se comparan ‖x‖, ‖Δx‖, su ratio y el coseno.",
          formula: "y = LayerNorm(x + Dropout(Δx))", input: "x y Δx · [B,T,d_model]", output: "y · [B,T,d_model]" },
        { title: "Feed-forward", short: "FFN", duration: 3000,
          concept: "La red feed-forward procesa cada posición de forma independiente, expande a d_ff, aplica la activación real y proyecta de vuelta.",
          formula: "FFN(x)=W₂·φ(W₁x+b₁)+b₂", input: "x · [B,T,d_model]", output: "FFN(x) · [B,T,d_model]" },
        { title: "Residual final del bloque", short: "Add+Norm", duration: 3000,
          concept: "La salida del FFN vuelve a entrar por una conexión residual post-norm. El resultado alimenta la siguiente capa o la proyección final.",
          formula: "xₗ₊₁ = LayerNorm(y + Dropout(FFN(y)))", input: "y y FFN(y)", output: "xₗ₊₁" },
        { title: "Trayectoria por capas", short: "Capas", duration: 6000,
          concept: "La misma identidad de token se sigue por todas las capas. Las tarjetas comparan concentración de atención y magnitud relativa de la actualización residual.",
          formula: "x₀ → bloque₁(x₀) → … → bloque_L", input: "estado de capa 0", output: "estado final de capa L" },
        { title: "Proyección y logits", short: "Logits", duration: 2000,
          concept: "La capa lineal asigna un logit a cada elemento del vocabulario. Los logits son scores sin normalizar; el histograma usa todo el vocabulario finito.",
          formula: "logits = h_final W_vocabᵀ + b", input: "h_final · [B,d_model]", output: "logits · [B,|V|]" },
        { title: "Probabilidades y selección", short: "Salida", duration: 2000,
          concept: "Temperatura y filtros se aplican solo si están activos. El token seleccionado se añade al contexto del decoder y comienza otra vuelta autoregresiva.",
          formula: "p=softmax(filter(logits/T));  token∼p", input: "logits + parámetros de generación", output: "token_id y nuevo contexto" }
    ]

    signal closeRequested()
    signal stepSelected(int index)
    signal nextTokenRequested()

    function attentionFromLayer(layer) {
        if (!layer)
            return ({})
        if (branchIndex === 0)
            return layer.atencion || ({})
        if (branchIndex === 1)
            return layer.autoatencion || ({})
        return layer.atencion_cruzada || ({})
    }

    function residualFromLayer(layer) {
        if (!layer)
            return ({})
        if (branchIndex === 0)
            return layer.residual_atencion || ({})
        if (branchIndex === 1)
            return layer.residual_autoatencion || ({})
        return layer.residual_cruzada || ({})
    }

    function branchName() {
        return ["Encoder · autoatención", "Decoder · atención causal",
                "Decoder · atención cruzada"][branchIndex]
    }

    function percentage(value) {
        return (Number(value || 0) * 100).toFixed(Number(value || 0) < 0.01 ? 2 : 1) + "%"
    }

    function setScene(index) {
        var bounded = Math.max(0, Math.min(sceneDefinitions.length - 1, index))
        if (bounded === sceneIndex)
            return
        mainVisualization.opacity = reducedMotion ? 1 : 0
        sceneIndex = bounded
        fadeTimer.restart()
    }

    function resetView() {
        playing = false
        sceneIndex = 0
        branchIndex = 1
        layerIndex = Math.max(0, Number(metadata.num_layers || 1) - 1)
        headIndex = 0
        localScale = false
        comparisonEnabled = false
        keyRangeStart = 0
        keyRangeEnd = Math.max(0, attentionColumns - 1)
    }

    function openDetail(eyebrow, title, summary, body, example, accent) {
        detailEyebrow = eyebrow
        detailTitle = title
        detailSummary = summary
        detailBody = body
        detailExample = example || ""
        detailAccent = accent || "#0072B2"
        detailCard.open()
    }

    function sliced(matrix) {
        if (!matrix || matrix.length === 0)
            return []
        var first = Math.max(0, Math.floor(keyRangeStart))
        var last = Math.max(first + 1, Math.floor(keyRangeEnd) + 1)
        var result = []
        for (var row = 0; row < matrix.length; ++row)
            result.push(matrix[row].slice(first, last))
        return result
    }

    function histogramMaximum(histogram) {
        var maximum = 1
        if (!histogram || !histogram.conteos)
            return maximum
        for (var i = 0; i < histogram.conteos.length; ++i)
            maximum = Math.max(maximum, Number(histogram.conteos[i]))
        return maximum
    }

    function currentInputShape() {
        if (!detailAvailable)
            return "Captura detallada disponible para el token más reciente."
        if (sceneIndex === 1 || sceneIndex === 2)
            return (globalData.embedding_encoder || {}).shape || "—"
        if (sceneIndex >= 3 && sceneIndex <= 8)
            return attentionData.shape_q || "—"
        if (sceneIndex === 9)
            return residualAttention.shape || "—"
        if (sceneIndex === 10)
            return ffnData.shape_entrada || "—"
        if (sceneIndex === 11)
            return residualFfn.shape || "—"
        if (sceneIndex === 13)
            return detailForward.logits ? detailForward.logits.shape : "—"
        return currentSnapshot ? currentSnapshot.tokens_entrada_total + " tokens" : "—"
    }

    function currentOutputShape() {
        if (sceneIndex >= 3 && sceneIndex <= 8)
            return attentionData.original_shape || "—"
        if (sceneIndex === 10)
            return ffnData.shape_salida || "—"
        if (sceneIndex === 14 && currentSnapshot)
            return "token_id=" + currentSnapshot.token_elegido.token_id
        return currentInputShape()
    }

    function exportView() {
        exportStatus = "Exportando…"
        root.grabToImage(function(result) {
            var name = "inferencia_token_" + (currentSnapshot ? currentSnapshot.paso : 0)
                       + "_escena_" + (sceneIndex + 1) + ".png"
            exportStatus = result.saveToFile(name) ? "PNG guardado: " + name
                                                    : "No se pudo guardar el PNG"
        }, Qt.size(1920, 1080))
    }

    onAttentionColumnsChanged: {
        keyRangeStart = 0
        keyRangeEnd = Math.max(0, attentionColumns - 1)
    }
    onLayerIndexChanged: {
        keyRangeStart = 0
        keyRangeEnd = Math.max(0, attentionColumns - 1)
    }

    Timer {
        id: playbackTimer
        running: root.playing
        repeat: false
        interval: Math.max(120, root.scene.duration / root.speeds[root.speedIndex])
        onTriggered: {
            if (root.sceneIndex < root.sceneDefinitions.length - 1) {
                root.setScene(root.sceneIndex + 1)
                restart()
            } else {
                root.playing = false
            }
        }
    }

    Timer {
        id: fadeTimer
        interval: root.reducedMotion ? 0 : 30
        onTriggered: mainVisualization.opacity = 1
    }

    Rectangle {
        anchors.fill: parent
        radius: 15 * root.sx
        color: "#F8FAFC"
        border.color: "#CBD5E1"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16 * root.sx
            spacing: 9 * root.sy

            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * root.sx

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        text: "Laboratorio de inferencia · forward pass real"
                        color: "#111111"
                        font.bold: true
                        font.pixelSize: 21 * Math.min(root.sx, root.sy)
                    }
                    Text {
                        text: root.currentSnapshot
                              ? "Token " + root.currentSnapshot.paso + "/" + root.snapshots.length
                                + " · seleccionado “" + root.currentSnapshot.token_elegido.texto + "”"
                              : "Genera texto para capturar el forward pass"
                        color: "#475569"
                        font.pixelSize: 11 * Math.min(root.sx, root.sy)
                    }
                }

                Repeater {
                    model: ["Student", "Developer", "Researcher"]
                    delegate: Button {
                        id: modeButton
                        required property string modelData
                        required property int index
                        text: modelData
                        checkable: true
                        checked: root.densityMode === index
                        onClicked: root.densityMode = index
                        Accessible.name: "Modo " + text
                    }
                }

                Button {
                    text: root.tokenProcessing ? "Generando token…" : "▶ Siguiente token"
                    enabled: root.canGenerateNext && !root.tokenProcessing
                    onClicked: root.nextTokenRequested()
                    Accessible.name: "Generar el siguiente token"
                    ToolTip.visible: hovered
                    ToolTip.text: "Ejecuta un nuevo paso autoregresivo y carga su forward pass"
                }
                Button { text: "↺ Reset"; onClicked: root.resetView() }
                Button { text: "⇩ Exportar"; onClicked: root.exportView() }
                Button {
                    text: "✕"
                    flat: true
                    onClicked: root.closeRequested()
                    Accessible.name: "Cerrar laboratorio de inferencia"
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#E2E8F0" }

            // Zona superior: tokens, selección y playback.
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 83 * root.sy
                Layout.minimumHeight: 83 * root.sy
                Layout.maximumHeight: 83 * root.sy
                spacing: 10 * root.sx

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 9 * root.sx
                    color: "#FFFFFF"
                    border.color: "#D7DEE8"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 7 * root.sx
                        spacing: 3 * root.sy
                        Text {
                            text: "TOKENS · identidad estable · clic en salida para cambiar la query"
                            color: "#475569"
                            font.bold: true
                            font.pixelSize: 9 * Math.min(root.sx, root.sy)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 7 * root.sx
                            ListView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                orientation: ListView.Horizontal
                                spacing: 4 * root.sx
                                clip: true
                                model: root.currentSnapshot ? root.currentSnapshot.tokens_entrada : []
                                delegate: Rectangle {
                                    id: promptToken
                                    required property var modelData
                                    width: Math.max(46 * root.sx, promptTokenText.implicitWidth + 14 * root.sx)
                                    height: 36 * root.sy
                                    radius: 6 * root.sx
                                    color: ["#FFF3D6", "#DFF3FF", "#DCF7EE", "#FCE4F2"][promptToken.modelData.posicion % 4]
                                    border.color: "#475569"
                                    Text {
                                        id: promptTokenText
                                        anchors.centerIn: parent
                                        text: promptToken.modelData.texto
                                        color: "#111111"
                                        font.bold: true
                                        font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                    }
                                    ToolTip.visible: promptHover.containsMouse
                                    ToolTip.text: "posición " + promptToken.modelData.posicion
                                                  + " · ID " + promptToken.modelData.token_id
                                                  + (promptToken.modelData.offset_inicio >= 0
                                                     ? " · offsets [" + promptToken.modelData.offset_inicio
                                                       + ", " + promptToken.modelData.offset_fin + ")" : "")
                                    MouseArea { id: promptHover; anchors.fill: parent; hoverEnabled: true }
                                }
                            }
                            Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: "#CBD5E1" }
                            ListView {
                                Layout.preferredWidth: 310 * root.sx
                                Layout.fillHeight: true
                                orientation: ListView.Horizontal
                                spacing: 4 * root.sx
                                clip: true
                                model: root.snapshots
                                delegate: Rectangle {
                                    id: generatedToken
                                    required property var modelData
                                    required property int index
                                    width: Math.max(43 * root.sx, generatedText.implicitWidth + 13 * root.sx)
                                    height: 36 * root.sy
                                    radius: 6 * root.sx
                                    color: generatedToken.index === root.selectedIndex ? "#BFE3F6" : "#E8F5FC"
                                    border.color: generatedToken.index === root.selectedIndex ? "#0072B2" : "#56B4E9"
                                    border.width: generatedToken.index === root.selectedIndex ? 2 : 1
                                    Text {
                                        id: generatedText
                                        anchors.centerIn: parent
                                        text: generatedToken.modelData.token_elegido.texto
                                        color: "#111111"
                                        font.bold: true
                                        font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.stepSelected(generatedToken.index)
                                    }
                                    ToolTip.visible: generatedHover.containsMouse
                                    ToolTip.text: "query/token " + (generatedToken.index + 1)
                                    MouseArea { id: generatedHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 610 * root.sx
                    Layout.minimumWidth: 610 * root.sx
                    Layout.maximumWidth: 610 * root.sx
                    Layout.fillHeight: true
                    radius: 9 * root.sx
                    color: "#FFFFFF"
                    border.color: "#D7DEE8"
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 7 * root.sx
                        spacing: 6 * root.sx
                        ComboBox {
                            visible: root.sceneIndex >= 3 && root.sceneIndex <= 12
                            Layout.preferredWidth: 150 * root.sx
                            Layout.minimumWidth: 150 * root.sx
                            Layout.maximumWidth: 150 * root.sx
                            model: ["Encoder", "Decoder causal", "Cross-attention"]
                            currentIndex: root.branchIndex
                            onActivated: function(index) { root.branchIndex = index }
                            Accessible.name: "Seleccionar rama del Transformer"
                        }
                        ColumnLayout {
                            visible: root.sceneIndex >= 3 && root.sceneIndex <= 12
                            Layout.fillWidth: true; spacing: 0
                            Text { text: "CAPA " + (root.layerIndex + 1); color: "#475569"; font.bold: true; font.pixelSize: 9 * root.sx }
                            Slider {
                                Layout.fillWidth: true
                                from: 0; to: Math.max(0, Number(root.metadata.num_layers || 1) - 1)
                                stepSize: 1; snapMode: Slider.SnapAlways
                                value: root.layerIndex
                                onMoved: root.layerIndex = Math.round(value)
                                Accessible.name: "Capa " + (root.layerIndex + 1)
                            }
                        }
                        SpinBox {
                            visible: root.sceneIndex >= 3 && root.sceneIndex <= 12
                            Layout.preferredWidth: 76 * root.sx
                            Layout.minimumWidth: 76 * root.sx
                            Layout.maximumWidth: 76 * root.sx
                            from: 1; to: Math.max(1, Number(root.metadata.num_heads || 1))
                            value: root.headIndex + 1
                            onValueModified: root.headIndex = value - 1
                            Accessible.name: "Cabeza de atención"
                        }
                        ToolButton {
                            Layout.preferredWidth: 38 * root.sx
                            Layout.minimumWidth: 38 * root.sx
                            Layout.maximumWidth: 38 * root.sx
                            text: "◀"
                            onClicked: root.setScene(root.sceneIndex - 1)
                            Accessible.name: "Paso anterior"
                        }
                        ToolButton {
                            Layout.preferredWidth: 38 * root.sx
                            Layout.minimumWidth: 38 * root.sx
                            Layout.maximumWidth: 38 * root.sx
                            text: root.playing ? "❚❚" : "▶"
                            onClicked: root.playing = !root.playing
                            Accessible.name: root.playing ? "Pausar animación" : "Reproducir animación"
                        }
                        ToolButton {
                            Layout.preferredWidth: 38 * root.sx
                            Layout.minimumWidth: 38 * root.sx
                            Layout.maximumWidth: 38 * root.sx
                            text: "▶|"
                            onClicked: root.setScene(root.sceneIndex + 1)
                            Accessible.name: "Paso siguiente"
                        }
                        ComboBox {
                            Layout.preferredWidth: 68 * root.sx
                            Layout.minimumWidth: 68 * root.sx
                            Layout.maximumWidth: 68 * root.sx
                            model: ["0.25×", "0.5×", "1×", "2×", "4×"]
                            currentIndex: root.speedIndex
                            onActivated: function(index) { root.speedIndex = index }
                            Accessible.name: "Velocidad de animación"
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 480 * root.sy
                spacing: 10 * root.sx

                // Centro: visualización principal del paso actual.
                Rectangle {
                    id: mainVisualization
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 1040 * root.sx
                    radius: 11 * root.sx
                    color: "#FFFFFF"
                    border.color: "#CBD5E1"
                    Behavior on opacity { NumberAnimation { duration: root.reducedMotion ? 0 : 220; easing.type: Easing.InOutCubic } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12 * root.sx
                        spacing: 7 * root.sy

                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Text {
                                    text: (root.sceneIndex + 1) + "/" + root.sceneDefinitions.length + " · " + root.scene.title
                                    color: "#111111"; font.bold: true
                                    font.pixelSize: 18 * Math.min(root.sx, root.sy)
                                }
                                Text {
                                    text: root.sceneIndex === 1
                                          ? "Entrada del encoder · antes de sumar la posición"
                                          : root.branchName() + " · capa " + (root.layerIndex + 1)
                                            + " · H" + String(root.headIndex + 1).padStart(2, "0")
                                    color: "#0072B2"; font.bold: true
                                    font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                }
                            }
                            CheckBox {
                                visible: root.sceneIndex === 1 || root.densityMode >= 1
                                text: "Escala local"
                                checked: root.localScale
                                onToggled: root.localScale = checked
                                ToolTip.visible: hovered
                                ToolTip.text: checked ? "La escala se ajusta a esta vista" : "Escala global compartida"
                            }
                            CheckBox {
                                visible: root.densityMode === 2
                                text: "Comparar capa"
                                checked: root.comparisonEnabled
                                onToggled: root.comparisonEnabled = checked
                            }
                            SpinBox {
                                visible: root.densityMode === 2 && root.comparisonEnabled
                                from: 1; to: Math.max(1, Number(root.metadata.num_layers || 1))
                                value: root.comparisonLayer + 1
                                onValueModified: root.comparisonLayer = value - 1
                                Accessible.name: "Capa de comparación"
                            }
                        }

                        Rectangle {
                            visible: !root.detailAvailable && root.sceneIndex > 0 && root.sceneIndex < 14
                            Layout.fillWidth: true
                            Layout.preferredHeight: 45 * root.sy
                            radius: 7 * root.sx
                            color: "#FFF7ED"
                            border.color: "#E69F00"
                            Text {
                                anchors.centerIn: parent
                                text: "El detalle tensorial se conserva para el token más reciente. Selecciónalo para inspeccionar el forward real."
                                color: "#7C2D12"; font.bold: true
                                font.pixelSize: 10 * Math.min(root.sx, root.sy)
                            }
                        }

                        StackLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            currentIndex: root.sceneIndex

                            // 0 · Tokenización
                            ScrollView {
                                clip: true
                                Flow {
                                    width: parent.width
                                    spacing: 10 * root.sx
                                    Repeater {
                                        model: root.currentSnapshot ? root.currentSnapshot.tokens_entrada : []
                                        delegate: Rectangle {
                                            id: tokenCard
                                            required property var modelData
                                            width: 145 * root.sx; height: 88 * root.sy; radius: 9 * root.sx
                                            color: ["#FFF3D6", "#DFF3FF", "#DCF7EE", "#FCE4F2"][tokenCard.modelData.posicion % 4]
                                            border.color: "#475569"
                                            Column {
                                                anchors.centerIn: parent; spacing: 3 * root.sy
                                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "“" + tokenCard.modelData.texto + "”"; color: "#111111"; font.bold: true; font.pixelSize: 14 * root.sx }
                                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "ID " + tokenCard.modelData.token_id + " · pos " + tokenCard.modelData.posicion; color: "#334155"; font.pixelSize: 10 * root.sx }
                                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: tokenCard.modelData.offset_inicio >= 0 ? "offset [" + tokenCard.modelData.offset_inicio + ", " + tokenCard.modelData.offset_fin + ")" : "offset no disponible"; color: "#64748B"; font.pixelSize: 9 * root.sx }
                                            }
                                        }
                                    }
                                }
                            }

                            // 1 · Embeddings
                            EmbeddingScene {
                                tensorData: root.globalData.embedding_encoder_escalado || ({})
                                tokens: root.currentSnapshot ? root.currentSnapshot.tokens_entrada : []
                                localScale: root.localScale
                                sx: root.sx
                                sy: root.sy
                            }

                            // 2 · Posición: tres vistas sincronizadas
                            RowLayout {
                                spacing: 7 * root.sx
                                Repeater {
                                    model: [
                                        { title: "Contenido E·√d", data: root.globalData.embedding_encoder_escalado || ({}) },
                                        { title: "+ posición PE", data: root.globalData.posicion_encoder || ({}) },
                                        { title: "= entrada X₀", data: root.globalData.entrada_encoder || ({}) }
                                    ]
                                    delegate: Rectangle {
                                        id: positionalPart
                                        required property var modelData
                                        Layout.fillWidth: true; Layout.fillHeight: true
                                        radius: 8 * root.sx; color: "#F8FAFC"; border.color: "#CBD5E1"
                                        ColumnLayout {
                                            anchors.fill: parent; anchors.margins: 7 * root.sx
                                            Text { text: positionalPart.modelData.title; color: "#111111"; font.bold: true; font.pixelSize: 11 * root.sx }
                                            ScientificMatrix {
                                                Layout.fillWidth: true; Layout.fillHeight: true
                                                matrix: (positionalPart.modelData.data.matriz || {}).valores || []
                                                colorMode: "diverging"; localScale: root.localScale
                                                rowPrefix: "T"; valueLabel: "valor"
                                                alternativeText: positionalPart.modelData.title + " como matriz token por dimensión"
                                            }
                                            Text { Layout.fillWidth: true; text: (positionalPart.modelData.data.matriz || {}).level_of_detail || ""; color: "#64748B"; wrapMode: Text.WordWrap; font.pixelSize: 8 * root.sx }
                                        }
                                    }
                                }
                            }

                            // 3 · Q K V
                            RowLayout {
                                spacing: 7 * root.sx
                                Repeater {
                                    model: [
                                        { title: "Q · query actual", matrix: root.attentionData.q || [] },
                                        { title: "K · key destacada " + Number(root.attentionData.key_destacada || 0), matrix: root.attentionData.k || [] },
                                        { title: "V · misma key", matrix: root.attentionData.v || [] }
                                    ]
                                    delegate: Rectangle {
                                        id: qkvPart
                                        required property var modelData
                                        Layout.fillWidth: true; Layout.fillHeight: true
                                        radius: 8 * root.sx; color: "#F8FAFC"; border.color: "#CBD5E1"
                                        ColumnLayout {
                                            anchors.fill: parent; anchors.margins: 7 * root.sx
                                            Text { text: qkvPart.modelData.title; color: "#111111"; font.bold: true; font.pixelSize: 11 * root.sx }
                                            ScientificMatrix {
                                                Layout.fillWidth: true; Layout.fillHeight: true
                                                matrix: qkvPart.modelData.matrix; colorMode: "diverging"
                                                localScale: root.localScale; selectedRow: root.headIndex
                                                rowPrefix: "H"; valueLabel: "componente"
                                                alternativeText: qkvPart.modelData.title + ", cabezas por dimensión"
                                            }
                                        }
                                    }
                                }
                            }

                            // 4 · Scores
                            AttentionScene { matrix: root.sliced(root.attentionData.scores || []); comparisonMatrix: root.sliced(root.comparisonAttention.scores || []); rawScores: root.sliced(root.attentionData.scores || []); maskMatrix: root.sliced(root.attentionData.mascara || []); attentionMatrix: root.sliced(root.attentionData.atencion || []); contributionMatrix: root.sliced(root.attentionData.contribuciones || []); comparisonEnabled: root.comparisonEnabled; selectedHead: root.headIndex; layerNumber: root.layerIndex + 1; columnOffset: Number(root.attentionData.inicio_keys || 0) + Math.floor(root.keyRangeStart); colorMode: "diverging"; localScale: root.localScale; valueLabel: "score"; title: "QKᵀ/√dₖ · scores crudos"; sx: root.sx; sy: root.sy }

                            // 5 · Máscara
                            AttentionScene { matrix: root.branchIndex === 1 ? ((root.globalData.mascara_causal || {}).valores || []) : (root.attentionData.mascara || []); maskMatrix: root.branchIndex === 1 ? ((root.globalData.mascara_causal || {}).valores || []) : (root.attentionData.mascara || []); comparisonEnabled: false; selectedHead: root.branchIndex === 1 ? 0 : root.headIndex; layerNumber: root.layerIndex + 1; rowPrefix: root.branchIndex === 1 ? "Q" : "H"; columnOffset: 0; colorMode: "mask"; localScale: false; valueLabel: "permitido"; title: root.branchIndex === 1 ? "Máscara causal completa · tramado = bloqueado" : "Máscara aplicada · 1 permitido / 0 bloqueado"; sx: root.sx; sy: root.sy }

                            // 6 · Softmax atención
                            AttentionScene { matrix: root.sliced(root.attentionData.atencion || []); comparisonMatrix: root.sliced(root.comparisonAttention.atencion || []); rawScores: root.sliced(root.attentionData.scores || []); maskMatrix: root.sliced(root.attentionData.mascara || []); attentionMatrix: root.sliced(root.attentionData.atencion || []); contributionMatrix: root.sliced(root.attentionData.contribuciones || []); comparisonEnabled: root.comparisonEnabled; selectedHead: root.headIndex; layerNumber: root.layerIndex + 1; columnOffset: Number(root.attentionData.inicio_keys || 0) + Math.floor(root.keyRangeStart); colorMode: "sequential"; localScale: root.localScale; valueLabel: "Aᵢⱼ"; title: "Pesos de atención 0–1 · query actual"; sx: root.sx; sy: root.sy }

                            // 7 · A·V contribución
                            AttentionScene { matrix: root.sliced(root.attentionData.contribuciones || []); comparisonMatrix: root.sliced(root.comparisonAttention.contribuciones || []); rawScores: root.sliced(root.attentionData.scores || []); maskMatrix: root.sliced(root.attentionData.mascara || []); attentionMatrix: root.sliced(root.attentionData.atencion || []); contributionMatrix: root.sliced(root.attentionData.contribuciones || []); comparisonEnabled: root.comparisonEnabled; selectedHead: root.headIndex; layerNumber: root.layerIndex + 1; columnOffset: Number(root.attentionData.inicio_keys || 0) + Math.floor(root.keyRangeStart); colorMode: "sequential"; localScale: true; valueLabel: "‖AᵢⱼVⱼ‖"; title: "Norma de contribución vectorial · distinta de Aᵢⱼ"; sx: root.sx; sy: root.sy }

                            // 8 · Salida multi-head
                            MatrixScene { title: "Salida por cabeza → concatenación → Wᴼ"; matrixData: ({ values: root.attentionData.salida_cabezas || [], valores: root.attentionData.salida_cabezas || [], level_of_detail: "query actual · primeras dimensiones" }); norms: []; histogram: ({}); localScale: true; colorMode: "diverging"; sx: root.sx; sy: root.sy }

                            // 9 · Residual atención
                            ResidualScene { sceneData: root.residualAttention; title: "Residual de " + root.branchName(); sx: root.sx; sy: root.sy }

                            // 10 · Feed-forward
                            FfnScene { sceneData: root.ffnData; sx: root.sx; sy: root.sy }

                            // 11 · Residual FFN
                            ResidualScene { sceneData: root.residualFfn; title: "Residual posterior al feed-forward"; sx: root.sx; sy: root.sy }

                            // 12 · Trayectoria capas
                            LayerTrajectory { layers: root.branchLayers; branchIndex: root.branchIndex; sx: root.sx; sy: root.sy }

                            // 13 · Logits
                            LogitsScene { snapshot: root.currentSnapshot; logits: root.detailAvailable ? root.detailForward.logits : ({}); showProbabilities: false; sx: root.sx; sy: root.sy }

                            // 14 · Distribución/salida
                            LogitsScene { snapshot: root.currentSnapshot; logits: root.detailAvailable ? root.detailForward.logits : ({}); showProbabilities: true; sx: root.sx; sy: root.sy }
                        }

                        RowLayout {
                            visible: root.sceneIndex >= 4 && root.sceneIndex <= 7 && root.attentionColumns > 1
                            Layout.fillWidth: true
                            Text { text: "Rango de keys"; color: "#475569"; font.pixelSize: 9 * root.sx }
                            RangeSlider {
                                Layout.fillWidth: true
                                from: 0; to: Math.max(1, root.attentionColumns - 1)
                                first.value: root.keyRangeStart
                                second.value: root.keyRangeEnd
                                first.onMoved: root.keyRangeStart = first.value
                                second.onMoved: root.keyRangeEnd = second.value
                                Accessible.name: "Rango de tokens key mostrado"
                            }
                            Text { text: Math.floor(root.keyRangeStart) + "–" + Math.floor(root.keyRangeEnd); color: "#111111"; font.bold: true; font.pixelSize: 9 * root.sx }
                        }
                    }
                }

                // Lateral: capas de información científica.
                Rectangle {
                    Layout.preferredWidth: 485 * root.sx
                    Layout.fillHeight: true
                    radius: 11 * root.sx
                    color: "#FFFFFF"
                    border.color: "#CBD5E1"

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 10 * root.sx
                        clip: true
                        ColumnLayout {
                            width: parent.width
                            spacing: 8 * root.sy

                            Text {
                                visible: root.sceneIndex === 1
                                Layout.fillWidth: true
                                text: "EMBEDDINGS · EXPLORA SIN SATURARTE"
                                color: "#475569"
                                font.bold: true
                                font.pixelSize: 9 * root.sx
                            }
                            Text {
                                visible: root.sceneIndex === 1
                                Layout.fillWidth: true
                                text: "La vista mantiene solo lo esencial. Pulsa una tarjeta o una celda de la matriz para profundizar."
                                color: "#334155"
                                wrapMode: Text.WordWrap
                                font.pixelSize: 10 * root.sx
                            }
                            DetailLaunchCard {
                                visible: root.sceneIndex === 1
                                title: "¿Qué es un embedding?"
                                preview: "Un vector aprendido que representa un token."
                                accent: "#0072B2"; sx: root.sx
                                onActivated: root.openDetail(
                                    "IDEA FUNDAMENTAL", "El token se convierte en un vector",
                                    "El modelo no procesa directamente palabras ni IDs: consulta una fila aprendida de su tabla de embeddings.",
                                    "Cada fila de la matriz corresponde a un token y cada columna a una dimensión latente. Una dimensión aislada normalmente no tiene una etiqueta humana como «género» o «tema»; el significado se distribuye entre muchas coordenadas y se aprende durante el entrenamiento. Tokens usados en contextos parecidos pueden terminar con patrones vectoriales parecidos, pero esta vista por sí sola no demuestra equivalencia semántica.",
                                    "Ruta mostrada: token_id → fila de W_embed → vector de d_model componentes → multiplicación por √d_model.",
                                    "#0072B2")
                            }
                            DetailLaunchCard {
                                visible: root.sceneIndex === 1
                                title: "¿Cómo leo la matriz?"
                                preview: "Fila = token · columna = dimensión."
                                accent: "#009E73"; sx: root.sx
                                onActivated: root.openDetail(
                                    "LECTURA", "Filas, columnas y celdas",
                                    "Una celda es una sola coordenada del vector de un token.",
                                    "Las filas T01, T02… siguen el orden de los tokens de entrada. Las columnas 0, 1, 2… son dimensiones internas. El número de columnas total es d_model; si el tensor es grande, la visualización puede enseñar una muestra de hasta 32 dimensiones y lo indica como nivel de detalle. Pulsa cualquier celda para ver su valor exacto y su interpretación.",
                                    "T02, dimensión 7 = −0.42 significa que la coordenada 7 del segundo token tiene valor negativo 0.42; no significa que el token sea «negativo».",
                                    "#009E73")
                            }
                            DetailLaunchCard {
                                visible: root.sceneIndex === 1
                                title: "Escala azul–blanco–naranja"
                                preview: "Signo e intensidad, no importancia."
                                accent: "#D55E00"; sx: root.sx
                                onActivated: root.openDetail(
                                    "COLOR", "Qué significa cada color",
                                    "Azul representa valores negativos, blanco valores cercanos a cero y naranja valores positivos.",
                                    "Cuanto más intenso es el azul o el naranja, mayor es la magnitud absoluta respecto al rango de la escala. El color no mide atención, probabilidad, calidad ni importancia del token. Con escala global, el rango permanece fijo para facilitar comparaciones; con escala local, los extremos se ajustan a esta matriz y resaltan diferencias pequeñas, pero ya no son directamente comparables con otras vistas.",
                                    "Naranja intenso = valor positivo grande dentro de la escala. Azul intenso = valor negativo grande en magnitud. Ambos pueden ser igualmente fuertes.",
                                    "#D55E00")
                            }
                            DetailLaunchCard {
                                visible: root.sceneIndex === 1
                                title: "¿Qué es la norma L2?"
                                preview: "Resume la magnitud del vector completo."
                                accent: "#CC79A7"; sx: root.sx
                                onActivated: root.openDetail(
                                    "MÉTRICA", "Norma L2 por token",
                                    "Combina todas las dimensiones en una sola medida de tamaño: √(x₁² + ··· + x_d²).",
                                    "Una norma mayor indica un vector de mayor magnitud antes de sumar la señal posicional. No dice por sí sola que el token sea más relevante, más frecuente o que recibirá más atención. Sirve para detectar diferencias de escala y valores atípicos. En la escena principal se muestra solo la norma del token seleccionado para reducir carga visual.",
                                    "Dos embeddings pueden tener la misma norma y apuntar en direcciones completamente diferentes; por eso la norma no sustituye al vector.",
                                    "#CC79A7")
                            }

                            InfoSection { visible: root.sceneIndex !== 1; title: "CONCEPTO"; body: root.scene.concept; accent: "#0072B2"; sx: root.sx }
                            InfoSection { visible: root.sceneIndex !== 1; title: "FÓRMULA"; body: root.scene.formula; accent: "#009E73"; monospace: true; sx: root.sx }
                            InfoSection {
                                visible: root.sceneIndex !== 1
                                title: "INPUT"; accent: "#E69F00"; sx: root.sx
                                body: root.scene.input + "\nshape capturado: " + root.currentInputShape()
                            }
                            InfoSection {
                                visible: root.sceneIndex !== 1
                                title: "OUTPUT"; accent: "#D55E00"; sx: root.sx
                                body: root.scene.output + "\nshape capturado: " + root.currentOutputShape()
                            }

                            InfoSection {
                                visible: root.sceneIndex !== 1 && root.densityMode >= 1
                                title: "CAPTURA / LOD"; accent: "#CC79A7"; sx: root.sx
                                body: root.attentionData.level_of_detail
                                      ? "original: " + root.attentionData.original_shape
                                        + "\nmostrado: " + root.attentionData.displayed_shape
                                        + "\nreducción: " + root.attentionData.aggregation_method
                                        + "\nLOD: " + root.attentionData.level_of_detail
                                      : "Sin reducción aplicable en esta escena."
                            }

                            Rectangle {
                                visible: root.sceneIndex !== 1 && root.densityMode >= 1 && root.attentionData.cabezas
                                Layout.fillWidth: true
                                Layout.preferredHeight: 104 * root.sy
                                radius: 8 * root.sx; color: "#F8FAFC"; border.color: "#CBD5E1"
                                Column {
                                    anchors.fill: parent; anchors.margins: 8 * root.sx; spacing: 4 * root.sy
                                    Text { text: "MÉTRICAS · H" + String(root.headIndex + 1).padStart(2, "0"); color: "#111111"; font.bold: true; font.pixelSize: 9 * root.sx }
                                    Text {
                                        width: parent.width
                                        text: root.attentionData.cabezas && root.attentionData.cabezas.length > root.headIndex
                                              ? "entropía " + root.attentionData.cabezas[root.headIndex].entropia
                                                + " · máximo " + root.attentionData.cabezas[root.headIndex].maximo
                                                + "\nmasa top-3 " + root.attentionData.cabezas[root.headIndex].masa_top3
                                                + " · soporte efectivo " + root.attentionData.cabezas[root.headIndex].soporte_efectivo
                                              : "No aplicable"
                                        color: "#334155"; wrapMode: Text.WordWrap; font.pixelSize: 9 * root.sx
                                    }
                                }
                            }

                            InfoSection {
                                visible: root.sceneIndex !== 1 && root.densityMode === 2
                                title: "VALIDACIÓN"; accent: "#009E73"; sx: root.sx
                                body: root.attentionData.validacion
                                      ? "✓ sin NaN: " + root.attentionData.validacion.sin_nan
                                        + "\n✓ filas Σ≈1: " + root.attentionData.validacion.filas_suman_uno
                                        + " (error máx. " + root.attentionData.validacion.error_max_suma + ")"
                                        + "\n✓ enmascarados≈0: " + root.attentionData.validacion.enmascarados_cero
                                      : (root.currentSnapshot && root.currentSnapshot.validacion
                                         ? "probabilidades Σ=1: " + root.currentSnapshot.validacion.probabilidades_suman_uno
                                           + "\nlogits sin NaN: " + root.currentSnapshot.validacion.logits_sin_nan
                                         : "No aplicable")
                            }

                            Rectangle {
                                visible: root.sceneIndex !== 1
                                Layout.fillWidth: true
                                Layout.preferredHeight: 72 * root.sy
                                radius: 8 * root.sx
                                color: "#FFF7ED"
                                border.color: "#E69F00"
                                Text {
                                    anchors.fill: parent; anchors.margins: 8 * root.sx
                                    text: root.sceneIndex === 6 || root.sceneIndex === 7
                                          ? "⚠ Atención y ‖AᵢⱼVⱼ‖ son estados internos distintos. Ninguno prueba por sí solo una relación causal con la predicción."
                                          : "Datos reales capturados del forward pass. No se muestran gradientes: pertenecen a un modo de atribución/backward separado."
                                    color: "#7C2D12"; wrapMode: Text.WordWrap
                                    font.pixelSize: 9 * root.sx
                                }
                            }

                            CheckBox {
                                text: "Reducir movimiento"
                                checked: root.reducedMotion
                                onToggled: root.reducedMotion = checked
                                Accessible.name: "Reducir movimiento de las transiciones"
                            }
                            Text {
                                visible: root.exportStatus.length > 0
                                Layout.fillWidth: true
                                text: root.exportStatus; color: "#047857"; wrapMode: Text.WordWrap
                                font.pixelSize: 9 * root.sx
                            }
                        }
                    }
                }
            }

            // Timeline inferior: pipeline completo y navegación por teclado.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 80 * root.sy
                Layout.minimumHeight: 80 * root.sy
                Layout.maximumHeight: 80 * root.sy
                radius: 9 * root.sx
                color: "#FFFFFF"
                border.color: "#CBD5E1"
                ScrollView {
                    anchors.fill: parent; anchors.margins: 6 * root.sx
                    contentWidth: timelineRow.implicitWidth
                    contentHeight: availableHeight
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                    Row {
                        id: timelineRow
                        spacing: 4 * root.sx
                        Repeater {
                            model: root.sceneDefinitions
                            delegate: Button {
                                id: timelineStep
                                required property var modelData
                                required property int index
                                width: 104 * root.sx; height: 57 * root.sy
                                text: (timelineStep.index + 1) + "\n" + timelineStep.modelData.short
                                checkable: true; checked: root.sceneIndex === timelineStep.index
                                onClicked: root.setScene(timelineStep.index)
                                Accessible.name: "Paso " + (timelineStep.index + 1) + ": " + timelineStep.modelData.title
                                ToolTip.visible: hovered
                                ToolTip.text: timelineStep.modelData.title
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: detailCard
        x: Math.max(12 * root.sx, (root.width - width) / 2)
        y: Math.max(12 * root.sy, (root.height - height) / 2)
        width: Math.min(root.width - 24 * root.sx, 650 * root.sx)
        height: Math.min(root.height - 24 * root.sy, 500 * root.sy)
        modal: true
        dim: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        Overlay.modal: Rectangle { color: "#73111B2E" }
        background: Rectangle {
            radius: 16 * root.sx
            color: "#FFFFFF"
            border.color: root.detailAccent
            border.width: 2
        }
        contentItem: ColumnLayout {
            spacing: 12 * root.sy
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3 * root.sy
                    Text {
                        Layout.fillWidth: true; text: root.detailEyebrow
                        color: root.detailAccent; font.bold: true
                        font.pixelSize: 10 * root.sx
                    }
                    Text {
                        Layout.fillWidth: true; text: root.detailTitle
                        color: "#0F172A"; font.bold: true
                        wrapMode: Text.WordWrap; font.pixelSize: 22 * root.sx
                    }
                }
                Button {
                    text: "✕"; flat: true
                    onClicked: detailCard.close()
                    Accessible.name: "Cerrar explicación"
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#E2E8F0" }
            ScrollView {
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                ColumnLayout {
                    width: parent.width; spacing: 14 * root.sy
                    Text {
                        Layout.fillWidth: true; text: root.detailSummary
                        color: "#1E293B"; font.bold: true
                        wrapMode: Text.WordWrap; font.pixelSize: 15 * root.sx
                    }
                    Text {
                        Layout.fillWidth: true; text: root.detailBody
                        color: "#334155"; wrapMode: Text.WordWrap
                        font.pixelSize: 13 * root.sx; lineHeight: 1.25
                    }
                    Rectangle {
                        visible: root.detailExample.length > 0
                        Layout.fillWidth: true
                        implicitHeight: exampleColumn.implicitHeight + 20 * root.sy
                        radius: 9 * root.sx; color: "#F8FAFC"; border.color: "#CBD5E1"
                        Column {
                            id: exampleColumn
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top; anchors.margins: 10 * root.sx
                            spacing: 5 * root.sy
                            Text { text: "EJEMPLO / LÍMITE"; color: root.detailAccent; font.bold: true; font.pixelSize: 9 * root.sx }
                            Text { width: parent.width; text: root.detailExample; color: "#334155"; wrapMode: Text.WordWrap; font.pixelSize: 12 * root.sx }
                        }
                    }
                }
            }
            Button {
                Layout.alignment: Qt.AlignRight
                text: "Entendido"
                onClicked: detailCard.close()
            }
        }
    }

    // Componentes de escena reutilizados por el StackLayout.
    component DetailLaunchCard: Rectangle {
        id: launchCard
        required property string title
        required property string preview
        property color accent: "#0072B2"
        property real sx: 1
        signal activated()
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        implicitWidth: 0
        implicitHeight: launchContent.implicitHeight + 18 * sx
        radius: 9 * sx
        color: launchMouse.containsMouse ? "#F1F5F9" : "#F8FAFC"
        border.color: accent
        border.width: launchMouse.containsMouse ? 2 : 1
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: title + ". " + preview + ". Abrir explicación detallada."
        Keys.onReturnPressed: launchCard.activated()
        Keys.onEnterPressed: launchCard.activated()
        Keys.onSpacePressed: launchCard.activated()
        Column {
            id: launchContent
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.margins: 9 * launchCard.sx
            spacing: 3 * launchCard.sx
            Row {
                width: parent.width; spacing: 6 * launchCard.sx
                Text { text: launchCard.title; width: parent.width - moreLabel.width - 8 * launchCard.sx; color: "#0F172A"; font.bold: true; font.pixelSize: 10 * launchCard.sx; elide: Text.ElideRight }
                Text { id: moreLabel; text: "Más →"; color: launchCard.accent; font.bold: true; font.pixelSize: 9 * launchCard.sx }
            }
            Text { width: parent.width; text: launchCard.preview; color: "#475569"; wrapMode: Text.WordWrap; font.pixelSize: 9 * launchCard.sx }
        }
        MouseArea {
            id: launchMouse; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: launchCard.activated()
        }
    }

    component InfoSection: Rectangle {
        id: infoSection
        required property string title
        required property string body
        property color accent: "#0072B2"
        property bool monospace: false
        property real sx: 1
        Layout.fillWidth: true
        implicitHeight: sectionColumn.implicitHeight + 16 * sx
        radius: 7 * sx; color: "#F8FAFC"; border.color: accent
        Column {
            id: sectionColumn
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.margins: 8 * infoSection.sx
            spacing: 3 * infoSection.sx
            Text { text: infoSection.title; color: infoSection.accent; font.bold: true; font.pixelSize: 9 * infoSection.sx }
            Text { width: parent.width; text: infoSection.body; color: "#1E293B"; wrapMode: Text.WordWrap; font.family: infoSection.monospace ? "monospace" : "sans-serif"; font.pixelSize: 9 * infoSection.sx }
        }
    }

    component EmbeddingScene: Item {
        id: embeddingScene
        property var tensorData: ({})
        property var tokens: []
        property bool localScale: false
        property real sx: 1
        property real sy: 1
        property int selectedRow: 0
        property int selectedColumn: 0
        readonly property var matrixData: tensorData.matriz || ({})
        readonly property var values: matrixData.valores || matrixData.values || []
        readonly property var norms: tensorData.normas_tokens || []
        readonly property var stats: tensorData.estadisticas || ({})
        readonly property real selectedValue: values.length > selectedRow
                                                   && values[selectedRow].length > selectedColumn
                                               ? Number(values[selectedRow][selectedColumn]) : 0
        readonly property real selectedNorm: norms.length > selectedRow
                                                  ? Number(norms[selectedRow]) : 0

        function tokenName(row) {
            var offset = Math.max(0, tokens.length - values.length)
            var tokenIndex = offset + row
            if (tokens && tokens.length > tokenIndex && tokens[tokenIndex].texto !== undefined)
                return "“" + tokens[tokenIndex].texto + "”"
            return "T" + String(tokenIndex + 1).padStart(2, "0")
        }

        ColumnLayout {
            anchors.fill: parent; spacing: 9 * embeddingScene.sy
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Embedding escalado · token × dimensión"
                    color: "#0F172A"; font.bold: true; font.pixelSize: 15 * embeddingScene.sx
                }
                Text {
                    text: "Pulsa cualquier dato para entenderlo"
                    color: "#64748B"; font.pixelSize: 9 * embeddingScene.sx
                }
            }
            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10 * embeddingScene.sx
                Rectangle {
                    objectName: "embeddingMatrixContainer"
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.minimumWidth: 600 * embeddingScene.sx
                    Layout.preferredWidth: 850 * embeddingScene.sx
                    radius: 10 * embeddingScene.sx; color: "#FFFFFF"; border.color: "#CBD5E1"
                    clip: true
                    ScientificMatrix {
                        id: embeddingHeatmap
                        anchors.fill: parent; anchors.margins: 8 * embeddingScene.sx
                        matrix: embeddingScene.values
                        colorMode: "diverging"; localScale: embeddingScene.localScale
                        rowPrefix: "T"
                        rowOffset: Math.max(0, embeddingScene.tokens.length - embeddingScene.values.length)
                        valueLabel: "componente del embedding"
                        alternativeText: "Embedding interactivo: filas por token y columnas por dimensión"
                        onCellSelected: function(row, column, value) {
                            embeddingScene.selectedRow = row
                            embeddingScene.selectedColumn = column
                            root.openDetail(
                                "CELDA SELECCIONADA",
                                embeddingScene.tokenName(row) + " · dimensión " + column,
                                "Valor exacto: " + Number(value).toFixed(6),
                                "Esta celda es una coordenada del embedding escalado del token. El signo indica en qué dirección aporta sobre este eje latente y la magnitud indica cuánto se aleja de cero. La dimensión no posee necesariamente un significado humano aislado: el Transformer utiliza el patrón completo y sus combinaciones posteriores.",
                                "Color " + (Number(value) > 0 ? "naranja = positivo" : (Number(value) < 0 ? "azul = negativo" : "blanco = cero")) + ". No representa probabilidad, atención ni importancia.",
                                Number(value) >= 0 ? "#D55E00" : "#0072B2")
                        }
                    }
                }
                ColumnLayout {
                    objectName: "embeddingMetricCards"
                    Layout.preferredWidth: 265 * embeddingScene.sx
                    Layout.minimumWidth: 265 * embeddingScene.sx
                    Layout.maximumWidth: 265 * embeddingScene.sx
                    Layout.fillHeight: true; spacing: 7 * embeddingScene.sy

                    DetailLaunchCard {
                        title: "Escala de color"
                        preview: embeddingScene.localScale ? "Local · ajustada a esta matriz" : "Global · −1 a +1"
                        accent: "#D55E00"; sx: embeddingScene.sx
                        onActivated: root.openDetail(
                            "LEYENDA", "Azul ← cero → naranja",
                            "El tono codifica el signo; la intensidad codifica la magnitud.",
                            "Azul: valor negativo. Blanco: valor cercano a cero. Naranja: valor positivo. Los valores que exceden el extremo de la escala usan el color más intenso. La escala global fija −1, 0 y +1 para comparar vistas; la escala local usa los mínimos y máximos de esta matriz para revelar variaciones pequeñas.",
                            "Más naranja no significa «mejor» ni «más importante». Un azul intenso y un naranja intenso tienen signos opuestos pero magnitudes comparables.",
                            "#D55E00")
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 42 * embeddingScene.sy
                        radius: 7 * embeddingScene.sx; border.color: "#CBD5E1"
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#0072B2" }
                            GradientStop { position: 0.5; color: "#FFFFFF" }
                            GradientStop { position: 1.0; color: "#D55E00" }
                        }
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 5 * embeddingScene.sx
                            Text { text: embeddingScene.localScale ? Number(embeddingHeatmap.dataMinimum).toFixed(2) : "−1"; color: "#FFFFFF"; font.bold: true; font.pixelSize: 9 * embeddingScene.sx }
                            Text { Layout.fillWidth: true; text: "0"; color: "#0F172A"; horizontalAlignment: Text.AlignHCenter; font.bold: true; font.pixelSize: 9 * embeddingScene.sx }
                            Text { text: embeddingScene.localScale ? Number(embeddingHeatmap.dataMaximum).toFixed(2) : "+1"; color: "#FFFFFF"; font.bold: true; font.pixelSize: 9 * embeddingScene.sx }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.openDetail(
                                "LEYENDA", "Cómo se transforma un número en color",
                                "La escala es divergente y está centrada en cero.",
                                "Para cada celda se divide su valor entre el mayor extremo absoluto del rango. El resultado se limita a [−1, +1] y se interpola desde blanco hacia azul si es negativo o hacia naranja si es positivo. Así, el signo nunca se confunde con la intensidad.",
                                "La saturación visual facilita detectar patrones, pero siempre debes consultar el número antes de comparar diferencias pequeñas.", "#D55E00")
                        }
                    }
                    DetailLaunchCard {
                        title: "Tensor " + (embeddingScene.tensorData.shape || "—")
                        preview: "batch × tokens × d_model"
                        accent: "#009E73"; sx: embeddingScene.sx
                        onActivated: root.openDetail(
                            "FORMA", "Qué significa " + (embeddingScene.tensorData.shape || "la forma"),
                            "Los tres ejes son lote, secuencia y dimensión del modelo.",
                            "El primer eje es el número de ejemplos procesados juntos; aquí normalmente es 1. El segundo es la cantidad de tokens del prompt. El tercero es d_model: cuántos números forman cada embedding. La matriz 2D elimina visualmente el eje batch y muestra token × dimensión.",
                            embeddingScene.matrixData.level_of_detail || "Se conserva una muestra cuando el tensor supera el espacio disponible.", "#009E73")
                    }
                    DetailLaunchCard {
                        title: "Celda seleccionada"
                        preview: embeddingScene.tokenName(embeddingScene.selectedRow) + " · d" + embeddingScene.selectedColumn + " = " + embeddingScene.selectedValue.toFixed(4)
                        accent: embeddingScene.selectedValue >= 0 ? "#D55E00" : "#0072B2"; sx: embeddingScene.sx
                        onActivated: root.openDetail(
                            "VALOR", embeddingScene.tokenName(embeddingScene.selectedRow) + " · dimensión " + embeddingScene.selectedColumn,
                            "Componente: " + embeddingScene.selectedValue.toFixed(6),
                            "Es una coordenada real utilizada en este forward pass. Debe interpretarse junto con las demás dimensiones, no como una etiqueta semántica independiente.",
                            "Selecciona otra celda en la matriz para actualizar este dato.", embeddingScene.selectedValue >= 0 ? "#D55E00" : "#0072B2")
                    }
                    DetailLaunchCard {
                        title: "Norma L2 del token"
                        preview: embeddingScene.tokenName(embeddingScene.selectedRow) + " · " + embeddingScene.selectedNorm.toFixed(4)
                        accent: "#CC79A7"; sx: embeddingScene.sx
                        onActivated: root.openDetail(
                            "MÉTRICA", "Magnitud del vector seleccionado",
                            "Norma L2 = " + embeddingScene.selectedNorm.toFixed(6),
                            "Se calcula elevando al cuadrado todas las coordenadas del token, sumándolas y tomando la raíz cuadrada. Resume tamaño, no dirección. Es útil para comparar escalas entre tokens, pero no mide relevancia, certeza ni atención.",
                            "Rango global observado: mínimo " + (embeddingScene.stats.minimo || "—") + " · máximo " + (embeddingScene.stats.maximo || "—") + ". Estos extremos son componentes individuales, no normas.", "#CC79A7")
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    component MatrixScene: Item {
        id: matrixScene
        required property string title
        property var matrixData: ({})
        property var norms: []
        property var histogram: ({})
        property bool localScale: false
        property string colorMode: "diverging"
        property real sx: 1
        property real sy: 1
        RowLayout {
            anchors.fill: parent; spacing: 8 * matrixScene.sx
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Text { text: matrixScene.title; color: "#111111"; font.bold: true; font.pixelSize: 11 * matrixScene.sx }
                ScientificMatrix {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    matrix: matrixScene.matrixData.valores || matrixScene.matrixData.values || []
                    colorMode: matrixScene.colorMode; localScale: matrixScene.localScale
                    rowPrefix: "T"; valueLabel: "activación"
                    alternativeText: matrixScene.title
                }
                Text { Layout.fillWidth: true; text: matrixScene.matrixData.level_of_detail || ""; color: "#64748B"; wrapMode: Text.WordWrap; font.pixelSize: 8 * matrixScene.sx }
            }
            ColumnLayout {
                Layout.preferredWidth: 230 * matrixScene.sx; Layout.fillHeight: true
                Text { text: "Norma L2 por token"; color: "#334155"; font.bold: true; font.pixelSize: 9 * matrixScene.sx }
                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 3 * matrixScene.sy
                    model: matrixScene.norms
                    delegate: Rectangle {
                        id: normBar
                        required property real modelData
                        width: ListView.view.width; height: 15 * matrixScene.sy
                        color: "#E2E8F0"; radius: height / 2
                        Rectangle { width: parent.width * Math.min(1, normBar.modelData / 30); height: parent.height; radius: parent.radius; color: "#56B4E9" }
                        Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: 4; text: Number(normBar.modelData).toFixed(3); color: "#111111"; font.pixelSize: 8 * matrixScene.sx }
                    }
                }
            }
        }
    }

    component AttentionScene: Item {
        id: attentionScene
        property var matrix: []
        property var comparisonMatrix: []
        property bool comparisonEnabled: false
        property int selectedHead: 0
        property int columnOffset: 0
        property string colorMode: "sequential"
        property bool localScale: false
        property string valueLabel: "valor"
        property string title: ""
        property string rowPrefix: "H"
        property int layerNumber: 0
        property var rawScores: []
        property var maskMatrix: []
        property var attentionMatrix: []
        property var contributionMatrix: []
        property real sx: 1
        property real sy: 1
        RowLayout {
            anchors.fill: parent; spacing: 8 * attentionScene.sx
            Repeater {
                model: attentionScene.comparisonEnabled ? 2 : 1
                delegate: ColumnLayout {
                    id: comparisonColumn
                    required property int index
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Text { text: attentionScene.title + (comparisonColumn.index === 1 ? " · comparación" : ""); color: "#111111"; font.bold: true; font.pixelSize: 11 * attentionScene.sx }
                    ScientificMatrix {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        matrix: comparisonColumn.index === 0 ? attentionScene.matrix : attentionScene.comparisonMatrix
                        colorMode: attentionScene.colorMode
                        localScale: attentionScene.localScale
                        selectedRow: attentionScene.selectedHead
                        rowPrefix: attentionScene.rowPrefix
                        layerNumber: attentionScene.layerNumber
                        columnOffset: attentionScene.columnOffset
                        valueLabel: attentionScene.valueLabel
                        rawScores: comparisonColumn.index === 0 ? attentionScene.rawScores : []
                        maskMatrix: comparisonColumn.index === 0 ? attentionScene.maskMatrix : []
                        attentionMatrix: comparisonColumn.index === 0 ? attentionScene.attentionMatrix : []
                        contributionMatrix: comparisonColumn.index === 0 ? attentionScene.contributionMatrix : []
                        alternativeText: attentionScene.title
                    }
                }
            }
        }
    }

    component ResidualScene: Item {
        id: residualScene
        property var sceneData: ({})
        property string title: "Residual"
        property real sx: 1
        property real sy: 1
        ColumnLayout {
            anchors.fill: parent; spacing: 10 * residualScene.sy
            Text { text: residualScene.title; color: "#111111"; font.bold: true; font.pixelSize: 12 * residualScene.sx }
            RowLayout {
                Layout.fillWidth: true; Layout.preferredHeight: 115 * residualScene.sy; spacing: 8 * residualScene.sx
                Repeater {
                    model: [
                        { label: "‖x‖ entrada", value: Number(residualScene.sceneData.norma_entrada || 0), color: "#0072B2" },
                        { label: "‖Δx‖ actualización", value: Number(residualScene.sceneData.norma_actualizacion || 0), color: "#E69F00" },
                        { label: "‖resultado‖", value: Number(residualScene.sceneData.norma_resultado || 0), color: "#009E73" }
                    ]
                    delegate: Rectangle {
                        id: residualMetric
                        required property var modelData
                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 9 * residualScene.sx
                        color: "#F8FAFC"; border.color: residualMetric.modelData.color
                        Column { anchors.centerIn: parent; spacing: 5
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: residualMetric.modelData.label; color: residualMetric.modelData.color; font.bold: true; font.pixelSize: 10 * residualScene.sx }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: residualMetric.modelData.value.toFixed(5); color: "#111111"; font.bold: true; font.pixelSize: 18 * residualScene.sx }
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: "ratio ‖Δx‖/‖x‖ = " + Number(residualScene.sceneData.ratio_actualizacion || 0).toFixed(5); color: "#334155"; font.pixelSize: 10 * residualScene.sx }
                Text { text: "cos(x, Δx) = " + Number(residualScene.sceneData.coseno || 0).toFixed(5); color: "#334155"; font.pixelSize: 10 * residualScene.sx }
            }
            Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; radius: 8 * residualScene.sx; color: "#F8FAFC"; border.color: "#CBD5E1"
                Text { anchors.centerIn: parent; width: parent.width - 20; text: "LayerNorm post-norm\nantes: μ=" + Number(residualScene.sceneData.media_antes || 0).toFixed(5) + " · σ=" + Number(residualScene.sceneData.desviacion_antes || 0).toFixed(5) + "\ndespués: μ=" + Number(residualScene.sceneData.media_despues || 0).toFixed(5) + " · σ=" + Number(residualScene.sceneData.desviacion_despues || 0).toFixed(5) + " · ε=" + Number(residualScene.sceneData.epsilon || 0); color: "#111111"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 11 * residualScene.sx }
            }
        }
    }

    component FfnScene: Item {
        id: ffnScene
        property var sceneData: ({})
        property real sx: 1
        property real sy: 1
        RowLayout {
            anchors.fill: parent; spacing: 10 * ffnScene.sx
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Text { text: "Histograma de activaciones · " + (ffnScene.sceneData.activacion || ""); color: "#111111"; font.bold: true; font.pixelSize: 11 * ffnScene.sx }
                Row {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 3 * ffnScene.sx
                    Repeater {
                        model: (ffnScene.sceneData.histograma_activacion || {}).conteos || []
                        delegate: Rectangle {
                            id: activationBar
                            required property int modelData
                            width: Math.max(4, (parent.parent.width - 50) / Math.max(1, ((ffnScene.sceneData.histograma_activacion || {}).conteos || []).length))
                            height: parent.parent.height * activationBar.modelData / root.histogramMaximum(ffnScene.sceneData.histograma_activacion)
                            anchors.bottom: parent.bottom; color: "#CC79A7"; border.color: "#111111"
                        }
                    }
                }
            }
            ColumnLayout {
                Layout.preferredWidth: 300 * ffnScene.sx; Layout.fillHeight: true
                Text { text: "Top unidades por |activación|"; color: "#111111"; font.bold: true; font.pixelSize: 10 * ffnScene.sx }
                Repeater {
                    model: ffnScene.sceneData.unidades_top || []
                    delegate: Rectangle {
                        id: ffnUnit
                        required property var modelData
                        Layout.fillWidth: true; Layout.preferredHeight: 29 * ffnScene.sx; radius: 5 * ffnScene.sx; color: "#F8FAFC"; border.color: "#CBD5E1"
                        RowLayout { anchors.fill: parent; anchors.margins: 5
                            Text { Layout.fillWidth: true; text: "unidad " + ffnUnit.modelData.unidad; color: "#334155"; font.pixelSize: 9 * ffnScene.sx }
                            Text { text: Number(ffnUnit.modelData.valor).toFixed(5); color: "#111111"; font.bold: true; font.pixelSize: 9 * ffnScene.sx }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }

    component LayerTrajectory: Item {
        id: trajectoryScene
        property var layers: []
        property int branchIndex: 0
        property real sx: 1
        property real sy: 1
        ScrollView {
            anchors.fill: parent; clip: true
            Row {
                spacing: 8 * trajectoryScene.sx
                Repeater {
                    model: trajectoryScene.layers
                    delegate: Rectangle {
                        id: layerCard
                        required property var modelData
                        width: 190 * trajectoryScene.sx; height: 260 * trajectoryScene.sy
                        radius: 9 * trajectoryScene.sx; color: "#F8FAFC"; border.color: "#0072B2"
                        property var att: root.attentionFromLayer(modelData)
                        property var res: root.residualFromLayer(modelData)
                        Column { anchors.fill: parent; anchors.margins: 10 * root.sx; spacing: 8 * root.sy
                            Text { text: "CAPA " + layerCard.modelData.capa; color: "#0072B2"; font.bold: true; font.pixelSize: 13 * root.sx }
                            Text { width: parent.width; text: layerCard.att.cabezas && layerCard.att.cabezas.length ? "entropía media H01: " + layerCard.att.cabezas[0].entropia + "\npico H01: " + layerCard.att.cabezas[0].maximo : "atención no disponible"; color: "#334155"; wrapMode: Text.WordWrap; font.pixelSize: 10 * root.sx }
                            Rectangle { width: parent.width; height: 1; color: "#CBD5E1" }
                            Text { width: parent.width; text: "‖x‖ " + Number(layerCard.res.norma_entrada || 0).toFixed(4) + "\n‖Δx‖ " + Number(layerCard.res.norma_actualizacion || 0).toFixed(4) + "\nratio " + Number(layerCard.res.ratio_actualizacion || 0).toFixed(4); color: "#334155"; font.pixelSize: 10 * root.sx }
                        }
                    }
                }
            }
        }
    }

    component LogitsScene: Item {
        id: logitsScene
        property var snapshot: null
        property var logits: ({})
        property bool showProbabilities: false
        property real sx: 1
        property real sy: 1
        RowLayout {
            anchors.fill: parent; spacing: 10 * logitsScene.sx
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Text { text: logitsScene.showProbabilities ? "Probabilidades top-k y acumulada" : "Histograma del vocabulario completo"; color: "#111111"; font.bold: true; font.pixelSize: 11 * logitsScene.sx }
                Row {
                    visible: !logitsScene.showProbabilities
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 3 * logitsScene.sx
                    Repeater {
                        model: (logitsScene.logits.histograma || {}).conteos || []
                        delegate: Rectangle {
                            id: logitsBar
                            required property int modelData
                            width: Math.max(5, (parent.parent.width - 30) / Math.max(1, ((logitsScene.logits.histograma || {}).conteos || []).length))
                            height: parent.parent.height * logitsBar.modelData / root.histogramMaximum(logitsScene.logits.histograma)
                            anchors.bottom: parent.bottom; color: "#56B4E9"; border.color: "#111111"
                        }
                    }
                }
                Text { visible: !logitsScene.showProbabilities; text: "shape " + (logitsScene.logits.shape || "—") + " · dtype " + (logitsScene.logits.dtype || "—"); color: "#475569"; font.pixelSize: 9 * logitsScene.sx }
                ListView {
                    visible: logitsScene.showProbabilities
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 5 * logitsScene.sy
                    model: logitsScene.snapshot ? logitsScene.snapshot.predicciones_top : []
                    delegate: Rectangle {
                        id: predictionRow
                        required property var modelData
                        width: ListView.view.width; height: 38 * logitsScene.sy; radius: 6 * logitsScene.sx
                        color: predictionRow.modelData.elegido ? "#DCF7EE" : "#F8FAFC"; border.color: predictionRow.modelData.elegido ? "#009E73" : "#CBD5E1"
                        RowLayout { anchors.fill: parent; anchors.margins: 6
                            Text { Layout.preferredWidth: 80 * logitsScene.sx; text: "#" + predictionRow.modelData.rango + "  “" + predictionRow.modelData.texto + "”"; color: "#111111"; font.bold: true; elide: Text.ElideRight; font.pixelSize: 9 * logitsScene.sx }
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 10 * logitsScene.sy; radius: height / 2; color: "#E2E8F0"; Rectangle { width: parent.width * Number(predictionRow.modelData.probabilidad); height: parent.height; radius: parent.radius; color: predictionRow.modelData.elegido ? "#009E73" : "#0072B2" } }
                            Text { Layout.preferredWidth: 155 * logitsScene.sx; text: root.percentage(predictionRow.modelData.probabilidad) + " · acum " + root.percentage(predictionRow.modelData.probabilidad_acumulada) + " · logit " + Number(predictionRow.modelData.logit).toFixed(3); color: "#334155"; font.pixelSize: 8 * logitsScene.sx }
                        }
                    }
                }
            }
            Rectangle {
                Layout.preferredWidth: 280 * logitsScene.sx; Layout.fillHeight: true; radius: 9 * logitsScene.sx
                color: "#F0FDF4"; border.color: "#009E73"
                Text { anchors.centerIn: parent; width: parent.width - 24; text: logitsScene.snapshot ? "TOKEN ELEGIDO\n“" + logitsScene.snapshot.token_elegido.texto + "”\nID " + logitsScene.snapshot.token_elegido.token_id + " · rango #" + logitsScene.snapshot.token_elegido.rango + "\n" + root.percentage(logitsScene.snapshot.token_elegido.probabilidad) + "\n\n" + logitsScene.snapshot.modo_muestreo + "\n" + logitsScene.snapshot.filtros : "—"; color: "#065F46"; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.bold: true; font.pixelSize: 11 * logitsScene.sx }
            }
        }
    }
}
