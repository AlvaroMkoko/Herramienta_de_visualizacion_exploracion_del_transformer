pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

Item {
    id: root
    objectName: "moduleLaboratoryVisualization"

    property string moduleId: "module_1"
    property var analysis: ({})
    property var step: ({})
    property int stepIndex: 0
    property string mode: "inference"
    property int selectedLayer: 0
    property int selectedHead: 0
    property int selectedToken: 0
    property bool showContextChrome: true
    property real sx: 1
    property real sy: 1

    signal inspectRequested(var panel)

    readonly property real uiSx: Math.max(0.78, Math.min(1.12, sx))
    readonly property real uiSy: Math.max(0.74, Math.min(1.08, sy))
    readonly property bool compact: width < 840
    readonly property bool veryCompact: width < 640
    readonly property bool trainingMode: {
        var normalized = String(mode || "").toLowerCase()
        return normalized.indexOf("train") >= 0
                || normalized.indexOf("entren") >= 0
    }
    readonly property string activeViewKind: {
        switch (moduleId) {
        case "module_1": return "tokenization"
        case "module_2": return "embedding"
        case "module_3": return "attention"
        case "module_4": return "multi_head"
        case "module_5": return "encoder"
        case "module_6": return "decoder"
        case "module_7": return "output"
        case "module_8": return "transformer"
        default: return "tokenization"
        }
    }
    readonly property string specializationKind: activeViewKind
    readonly property var panels: analysis && analysis.panels
                                          ? analysis.panels : []
    readonly property var tokens: analysis && analysis.tokens
                                          ? analysis.tokens : []
    readonly property var forwardDetail: analysis && analysis.forward_detail
                                                 ? analysis.forward_detail : ({})
    readonly property var detailGlobal: forwardDetail && forwardDetail["global"]
                                                ? forwardDetail["global"] : ({})
    readonly property var inferenceSnapshot: analysis && analysis.inference_snapshot
                                                     ? analysis.inference_snapshot : ({})
    readonly property var trainingSnapshot: analysis && analysis.training
                                                    ? analysis.training : ({})
    readonly property var metadata: normalizedMetadata()
    readonly property string visualId: normalizedVisualId()

    function safeObject(value) {
        return value && typeof value === "object" ? value : ({})
    }

    function safeList(value) {
        return value && value.length !== undefined ? value : []
    }

    function textValue(value, fallback) {
        if (value === undefined || value === null || String(value).length === 0)
            return fallback === undefined ? "" : String(fallback)
        return String(value)
    }

    function normalizedVisualId() {
        var value = step ? step.visual : ""
        if (value && typeof value === "object")
            value = value.kind || value.id || value.type || ""
        var identifier = textValue(value, step ? step.id : "")
        return identifier.toLowerCase()
    }

    function tokenLabel(token, fallbackIndex) {
        var item = safeObject(token)
        var label = item.text
        if (label === undefined || label === null || String(label).length === 0)
            label = item.texto
        if (label === undefined || label === null || String(label).length === 0)
            label = item.token
        return textValue(label, "T" + (Number(fallbackIndex || 0) + 1))
    }

    function tokenId(token) {
        var item = safeObject(token)
        if (item.id !== undefined)
            return item.id
        if (item.token_id !== undefined)
            return item.token_id
        return "—"
    }

    function tokenPosition(token, fallbackIndex) {
        var item = safeObject(token)
        return Number(item.position !== undefined ? item.position
                                                   : (item.posicion !== undefined
                                                      ? item.posicion : fallbackIndex))
    }

    function normalizedTokens() {
        var result = []
        var source = safeList(tokens)
        for (var index = 0; index < source.length; ++index) {
            result.push({
                text: tokenLabel(source[index], index),
                texto: tokenLabel(source[index], index),
                id: tokenId(source[index]),
                token_id: tokenId(source[index]),
                position: tokenPosition(source[index], index),
                posicion: tokenPosition(source[index], index)
            })
        }
        return result
    }

    function panelFor(key) {
        var wanted = String(key || "")
        for (var index = 0; index < panels.length; ++index) {
            var panel = safeObject(panels[index])
            if (String(panel.key || "") === wanted)
                return panel
        }
        return ({})
    }

    function panelHasData(panel) {
        var item = safeObject(panel)
        return String(item.key || "").length > 0
                || matrixFrom(item).length > 0
    }

    function panelsByKeys(keys) {
        var result = []
        var seen = ({})
        var requested = safeList(keys)
        for (var index = 0; index < requested.length; ++index) {
            var panel = panelFor(requested[index])
            var key = String(panel.key || "")
            if (key.length && !seen[key]) {
                result.push(panel)
                seen[key] = true
            }
        }
        var stepKeys = []
        var declaredStepKeys = step && step.panel_keys ? safeList(step.panel_keys) : []
        for (var declaredIndex = 0; declaredIndex < declaredStepKeys.length;
             ++declaredIndex)
            stepKeys.push(declaredStepKeys[declaredIndex])
        if (step && step.panel_key)
            stepKeys.push(step.panel_key)
        for (var stepIndex = 0; stepIndex < stepKeys.length; ++stepIndex) {
            var currentKey = String(stepKeys[stepIndex] || "")
            if (!currentKey.length || seen[currentKey])
                continue
            var current = panelFor(currentKey)
            if (panelHasData(current)) {
                result.push(current)
                seen[currentKey] = true
            }
        }
        return result
    }

    function matrixFrom(value) {
        var candidate = value
        if (!candidate)
            return []
        if (candidate.matrix !== undefined)
            candidate = candidate.matrix
        if (candidate && candidate.valores !== undefined)
            candidate = candidate.valores
        if (candidate && candidate.values !== undefined)
            candidate = candidate.values
        if (!candidate || candidate.length === undefined || candidate.length === 0)
            return []
        if (candidate[0] && candidate[0].length !== undefined)
            return candidate
        return [candidate]
    }

    function matrixForPanel(key) {
        return matrixFrom(panelFor(key))
    }

    function shapeText(value) {
        var shape = value && value.shape !== undefined ? value.shape
                : (value && value.matrix && value.matrix.original_shape !== undefined
                   ? value.matrix.original_shape : value)
        if (shape === undefined || shape === null)
            return "forma no disponible"
        if (shape.length !== undefined && typeof shape !== "string")
            return "[" + Array.prototype.join.call(shape, " × ") + "]"
        var text = String(shape)
        return text.length ? text : "forma no disponible"
    }

    function statsText(panel) {
        var stats = panel && panel.stats ? panel.stats
                                         : (panel && panel.statistics
                                            ? panel.statistics : ({}))
        var mean = stats.media !== undefined ? stats.media : stats.mean
        var minimum = stats.minimo !== undefined ? stats.minimo : stats.min
        var maximum = stats.maximo !== undefined ? stats.maximo : stats.max
        var parts = []
        if (mean !== undefined)
            parts.push("μ " + formatNumber(mean))
        if (minimum !== undefined)
            parts.push("mín " + formatNumber(minimum))
        if (maximum !== undefined)
            parts.push("máx " + formatNumber(maximum))
        return parts.length ? parts.join(" · ") : "Valores de la captura activa"
    }

    function formatNumber(value) {
        var number = Number(value)
        if (!Number.isFinite(number))
            return "—"
        var absolute = Math.abs(number)
        if (absolute !== 0 && (absolute >= 1000 || absolute < 0.001))
            return number.toExponential(2)
        return number.toFixed(absolute >= 10 ? 2 : 4)
    }

    function normalizedMetadata() {
        var source = forwardDetail && forwardDetail.metadata
                ? forwardDetail.metadata
                : (analysis && analysis.model_dimensions
                   ? analysis.model_dimensions : ({}))
        return {
            num_layers: Number(source.num_layers || source.layers || source.capas || 1),
            num_heads: Number(source.num_heads || source.heads || source.cabezas || 1),
            d_model: Number(source.d_model || source.dimension_modelo || 1),
            d_head: Number(source.d_head || source.dimension_cabeza || 1),
            d_ff: Number(source.d_ff || source.dimension_ff || 1),
            vocabulary: Number(source.vocabulary || source.vocabulario || 0)
        }
    }

    function selectedEncoderLayer() {
        var layers = forwardDetail && forwardDetail.encoder
                ? forwardDetail.encoder : []
        if (!layers.length)
            return ({})
        var index = Math.max(0, Math.min(layers.length - 1, Number(selectedLayer)))
        return safeObject(layers[index])
    }

    function selectedDecoderLayer() {
        var layers = forwardDetail && forwardDetail.decoder
                ? forwardDetail.decoder : []
        if (!layers.length)
            return ({})
        var index = Math.max(0, Math.min(layers.length - 1, Number(selectedLayer)))
        return safeObject(layers[index])
    }

    function fallbackAttentionData() {
        return {
            q: matrixForPanel("q"),
            k: matrixForPanel("k"),
            v: matrixForPanel("v"),
            scores: matrixForPanel("scores"),
            scores_enmascarados: matrixForPanel("masked_scores"),
            mascara: matrixForPanel("causal_mask"),
            atencion: matrixForPanel("attention_weights").length
                      ? matrixForPanel("attention_weights")
                      : matrixForPanel("masked_attention"),
            contribuciones: matrixForPanel("contributions"),
            salida_cabezas: matrixForPanel("head_output"),
            salida_concatenada: matrixForPanel("concatenated").length
                                ? matrixForPanel("concatenated")[0] : [],
            salida_proyectada: matrixForPanel("projected").length
                               ? matrixForPanel("projected")[0]
                               : (matrixForPanel("attention_output").length
                                  ? matrixForPanel("attention_output")[0] : []),
            flujo: ({ matrices: [] })
        }
    }

    function attentionData(branch) {
        var layer = branch === 0 ? selectedEncoderLayer()
                                 : selectedDecoderLayer()
        var data = ({})
        if (branch === 0)
            data = safeObject(layer.atencion)
        else if (branch === 1)
            data = safeObject(layer.autoatencion)
        else
            data = safeObject(layer.atencion_cruzada)
        return Object.keys(data).length ? data : fallbackAttentionData()
    }

    function attentionPhase() {
        var visual = visualId
        if (visual.indexOf("mask") >= 0 || visual.indexOf("mascara") >= 0)
            return "mask"
        if (visual.indexOf("score") >= 0 || visual.indexOf("scale") >= 0
                || visual.indexOf("escal") >= 0 || visual.indexOf("qk") >= 0)
            return "scores"
        if (visual.indexOf("qkv") >= 0 || visual.indexOf("query") >= 0
                || visual.indexOf("key") >= 0 || visual.indexOf("value") >= 0)
            return "qkv"
        if (visual.indexOf("softmax") >= 0 || visual.indexOf("weight") >= 0
                || visual.indexOf("peso") >= 0 || visual.indexOf("output") >= 0
                || visual.indexOf("salida") >= 0 || visual.indexOf("context") >= 0
                || visual.indexOf("producto_por_v") >= 0)
            return "weighted"
        if (stepIndex <= 2)
            return "qkv"
        if (stepIndex <= 3)
            return "scores"
        if (stepIndex <= 4)
            return "mask"
        return "weighted"
    }

    function decoderBranch() {
        var visual = visualId
        return visual.indexOf("cross") >= 0 || visual.indexOf("cruz") >= 0
                || (visual.indexOf("residual") >= 0 && stepIndex >= 4) ? 2 : 1
    }

    function causalMaskData() {
        if (detailGlobal && detailGlobal.mascara_causal)
            return detailGlobal.mascara_causal
        var matrix = matrixForPanel("causal_mask")
        return { valores: matrix }
    }

    function tensorData(panelKey, detailKey) {
        if (detailKey && detailGlobal && detailGlobal[detailKey])
            return detailGlobal[detailKey]
        var panel = panelFor(panelKey)
        return {
            shape: panel.shape || (panel.matrix ? panel.matrix.original_shape : []),
            matriz: { valores: matrixFrom(panel) },
            estadisticas: panel.stats || panel.statistics || ({}),
            normas_tokens: panel.norms || panel.normas_tokens || []
        }
    }

    function positionalProjection() {
        if (detailGlobal && detailGlobal.proyeccion_posicional_encoder)
            return detailGlobal.proyeccion_posicional_encoder
        var embedding = matrixForPanel("embedding")
        var combined = matrixForPanel("embedding_plus_position")
        var count = Math.min(embedding.length, combined.length)
        var before = []
        var after = []
        for (var index = 0; index < count; ++index) {
            var first = embedding[index] || []
            var second = combined[index] || []
            before.push({ x: Number(first[0] || 0), y: Number(first[1] || 0) })
            after.push({ x: Number(second[0] || 0), y: Number(second[1] || 0) })
        }
        return { embedding: before, entrada: after, inicio_posicion: 0 }
    }

    function headMatrix() {
        var data = attentionData(0)
        var flow = data && data.flujo ? data.flujo : ({})
        var matrices = flow && flow.matrices ? flow.matrices : []
        if (matrices.length) {
            var index = Math.max(0, Math.min(matrices.length - 1,
                                             Number(selectedHead)))
            return matrices[index]
        }
        var panel = matrixForPanel("head_attention")
        if (panel.length && panel[0] && panel[0].length !== undefined)
            return panel
        return data && data.atencion && data.atencion.length
                ? data.atencion[Math.max(0, Math.min(data.atencion.length - 1,
                                                     Number(selectedHead)))] || []
                : []
    }

    function residualData(branch, useFfn) {
        var layer = branch === 0 ? selectedEncoderLayer()
                                 : selectedDecoderLayer()
        if (useFfn)
            return safeObject(layer.residual_ffn)
        if (branch === 0)
            return safeObject(layer.residual_atencion)
        if (branch === 1)
            return safeObject(layer.residual_autoatencion)
        return safeObject(layer.residual_cruzada)
    }

    function ffnData(branch) {
        var layer = branch === 0 ? selectedEncoderLayer()
                                 : selectedDecoderLayer()
        return safeObject(layer.ffn)
    }

    function encoderSceneIndex() {
        var visual = visualId
        if (visual.indexOf("ffn") >= 0 || visual.indexOf("feed") >= 0)
            return 2
        if (visual.indexOf("residual") >= 0 || visual.indexOf("norm") >= 0
                || visual.indexOf("add") >= 0)
            return 1
        if (visual.indexOf("layer") >= 0 || visual.indexOf("capa") >= 0
                || visual.indexOf("stack") >= 0 || visual.indexOf("pila") >= 0
                || visual.indexOf("memory") >= 0 || visual.indexOf("memoria") >= 0)
            return 3
        return 0
    }

    function encoderResidualUsesFfn() {
        return visualId.indexOf("ffn") >= 0
                || (visualId.indexOf("residual") >= 0 && stepIndex >= 6)
    }

    function decoderSceneIndex() {
        var visual = visualId
        if (visual.indexOf("ffn") >= 0 || visual.indexOf("feed") >= 0)
            return 2
        if (visual.indexOf("residual") >= 0 || visual.indexOf("norm") >= 0
                || visual.indexOf("add") >= 0)
            return 1
        if (visual.indexOf("layer") >= 0 || visual.indexOf("capa") >= 0
                || visual.indexOf("stack") >= 0 || visual.indexOf("pila") >= 0)
            return 3
        return 0
    }

    function normalizedCandidates() {
        var source = analysis && analysis.candidates ? analysis.candidates
                : (inferenceSnapshot && inferenceSnapshot.predicciones_top
                   ? inferenceSnapshot.predicciones_top : [])
        var result = []
        for (var index = 0; index < source.length; ++index) {
            var item = safeObject(source[index])
            result.push({
                id: item.id !== undefined ? item.id : item.token_id,
                token_id: item.token_id !== undefined ? item.token_id : item.id,
                text: textValue(item.text, item.texto),
                texto: textValue(item.texto, item.text),
                probability: Number(item.probability !== undefined
                                    ? item.probability : item.probabilidad || 0),
                probabilidad: Number(item.probabilidad !== undefined
                                     ? item.probabilidad : item.probability || 0),
                logit: Number(item.logit || 0),
                rank: Number(item.rank !== undefined ? item.rank
                                                     : item.rango || index + 1),
                chosen: Boolean(item.chosen !== undefined ? item.chosen
                                                          : item.elegido)
            })
        }
        return result
    }

    function outputSnapshot() {
        if (inferenceSnapshot && inferenceSnapshot.predicciones_top)
            return inferenceSnapshot
        var candidates = normalizedCandidates()
        var converted = []
        for (var index = 0; index < candidates.length; ++index) {
            var item = candidates[index]
            converted.push({
                token_id: item.token_id,
                texto: item.texto,
                probabilidad: item.probabilidad,
                logit: item.logit,
                rango: item.rank,
                elegido: item.chosen
            })
        }
        return { predicciones_top: converted }
    }

    function outputSceneIndex() {
        var visual = visualId
        if (trainingMode && (visual.indexOf("loss") >= 0
                             || visual.indexOf("gradient") >= 0
                             || visual.indexOf("gradiente") >= 0
                             || visual.indexOf("back") >= 0))
            return 2
        if (visual.indexOf("temperature") >= 0 || visual.indexOf("temperatura") >= 0
                || visual.indexOf("top") >= 0 || visual.indexOf("softmax") >= 0
                || visual.indexOf("select") >= 0 || visual.indexOf("seleccion") >= 0
                || visual.indexOf("sample") >= 0 || visual.indexOf("muestreo") >= 0
                || visual.indexOf("autoregressive") >= 0
                || visual.indexOf("autoregres") >= 0)
            return 1
        return 0
    }

    function moduleEightSceneIndex() {
        var visual = visualId
        if (visual.indexOf("embedding") >= 0 || visual.indexOf("position") >= 0
                || visual.indexOf("posicion") >= 0 || visual.indexOf("token") >= 0)
            return 0
        if (visual.indexOf("attention") >= 0 || visual.indexOf("atencion") >= 0
                || visual.indexOf("encoder") >= 0 || visual.indexOf("decoder") >= 0
                || visual.indexOf("mask") >= 0 || visual.indexOf("cross") >= 0)
            return 1
        if (visual.indexOf("logit") >= 0 || visual.indexOf("output") >= 0
                || visual.indexOf("salida") >= 0 || visual.indexOf("softmax") >= 0
                || visual.indexOf("select") >= 0 || visual.indexOf("seleccion") >= 0)
            return 2
        return Math.max(0, Math.min(2, Math.floor(Number(stepIndex) / 3)))
    }

    function transformerStages() {
        var provided = inferenceSnapshot && inferenceSnapshot.etapas
                ? inferenceSnapshot.etapas : []
        if (!trainingMode && provided.length)
            return provided
        if (trainingMode) {
            return [
                { numero: "01", titulo: "Batch", dato: "IDs + máscaras", color: Style.Theme.inferencia_estructura },
                { numero: "02", titulo: "Forward", dato: "activaciones reales", color: Style.Theme.inferencia_contexto },
                { numero: "03", titulo: "Pérdida", dato: "comparar objetivo", color: Style.Theme.inferencia_foco },
                { numero: "04", titulo: "Backward", dato: "propagar gradientes", color: Style.Theme.inferencia_transformacion },
                { numero: "05", titulo: "Actualización", dato: "Δθ hipotético, no aplicado", color: Style.Theme.inferencia_resultado }
            ]
        }
        return [
            { numero: "01", titulo: "Tokens", dato: "texto → IDs", color: Style.Theme.inferencia_estructura },
            { numero: "02", titulo: "Encoder", dato: "memoria contextual", color: Style.Theme.inferencia_contexto },
            { numero: "03", titulo: "Decoder", dato: "prefijo + fuente", color: Style.Theme.inferencia_transformacion },
            { numero: "04", titulo: "Logits", dato: "un score por token", color: Style.Theme.inferencia_foco },
            { numero: "05", titulo: "Selección", dato: "token siguiente", color: Style.Theme.inferencia_resultado }
        ]
    }

    function trainingMetric(names, fallback) {
        var source = trainingSnapshot
        for (var index = 0; index < names.length; ++index) {
            var key = names[index]
            if (source && source[key] !== undefined)
                return source[key]
            if (source && source.resumen && source.resumen[key] !== undefined)
                return source.resumen[key]
        }
        return fallback
    }

    function componentForModule() {
        switch (moduleId) {
        case "module_2": return embeddingComponent
        case "module_3": return attentionComponent
        case "module_4": return multiHeadComponent
        case "module_5": return encoderComponent
        case "module_6": return decoderComponent
        case "module_7": return outputComponent
        case "module_8": return transformerComponent
        default: return tokenizationComponent
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 9 * root.uiSy

        Rectangle {
            id: stepSummary
            objectName: "moduleLabStepSummary"
            visible: root.showContextChrome
            Layout.fillWidth: true
            implicitHeight: summaryColumn.implicitHeight + 18 * root.uiSy
            radius: 12 * root.uiSx
            color: Style.Theme.surface
            border.color: Style.Theme.borde_suave

            ColumnLayout {
                id: summaryColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 9 * root.uiSx
                spacing: 5 * root.uiSy

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8 * root.uiSx

                    Rectangle {
                        Layout.preferredWidth: 31 * root.uiSx
                        Layout.preferredHeight: 31 * root.uiSy
                        radius: height / 2
                        color: root.trainingMode
                               ? Style.Theme.inferencia_transformacion
                               : Style.Theme.inferencia_estructura

                        Text {
                            anchors.centerIn: parent
                            text: Number(root.stepIndex) + 1
                            color: root.trainingMode
                                   ? Style.Theme.inferencia_sobre_transformacion
                                   : Style.Theme.inferencia_sobre_estructura
                            font.bold: true
                            font.pixelSize: Math.max(11, 12 * root.uiSx)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: root.textValue(root.step ? root.step.title : "",
                                                 "Exploración interna del componente")
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: Math.max(15, 17 * root.uiSx)
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.textValue(root.step ? root.step.formula : "",
                                                 root.trainingMode
                                                 ? "forward → pérdida → backward → actualización"
                                                 : "entrada → transformación → salida")
                            color: Style.Theme.acento_fuerte
                            font.family: Style.Theme.fuente_mono
                            font.pixelSize: Math.max(10, 11 * root.uiSx)
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: modeText.implicitWidth + 20 * root.uiSx
                        Layout.preferredHeight: 29 * root.uiSy
                        radius: height / 2
                        color: root.trainingMode
                               ? Style.Theme.formula_fondo : Style.Theme.info_fondo
                        border.color: root.trainingMode
                                      ? Style.Theme.inferencia_transformacion
                                      : Style.Theme.inferencia_estructura

                        Text {
                            id: modeText
                            anchors.centerIn: parent
                            text: root.trainingMode ? "ENTRENAMIENTO" : "INFERENCIA"
                            color: root.trainingMode
                                   ? Style.Theme.formula_texto : Style.Theme.info_texto
                            font.bold: true
                            font.pixelSize: Math.max(9, 9 * root.uiSx)
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.textValue(root.step ? root.step.explanation : "", "")
                    color: Style.Theme.texto_secundario_fuerte
                    font.pixelSize: Math.max(10, 11 * root.uiSx)
                    wrapMode: Text.WordWrap
                    maximumLineCount: root.compact ? 2 : 1
                    elide: Text.ElideRight
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: root.compact ? 1 : 2
                    columnSpacing: 8 * root.uiSx
                    rowSpacing: 4 * root.uiSy

                    FlowFact {
                        Layout.fillWidth: true
                        label: "ENTRADA"
                        value: root.textValue(root.step ? root.step.input : "",
                                              "Datos del paso anterior")
                        accent: Style.Theme.inferencia_estructura
                        sx: root.uiSx
                        sy: root.uiSy
                    }
                    FlowFact {
                        Layout.fillWidth: true
                        label: "SALIDA"
                        value: root.textValue(root.step ? root.step.output : "",
                                              "Resultado para el paso siguiente")
                        accent: Style.Theme.inferencia_resultado
                        sx: root.uiSx
                        sy: root.uiSy
                    }
                }
            }
        }

        Loader {
            id: specializedLoader
            objectName: "moduleLabSpecializedLoader"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            sourceComponent: root.componentForModule()
        }

        TrainingEvidenceBar {
            objectName: "moduleLabTrainingEvidence"
            visible: root.showContextChrome && root.trainingMode
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 48 * root.uiSy : 0
            lossValue: root.trainingMetric(["loss", "perdida", "perdida_batch"], "—")
            gradientValue: root.trainingMetric(["gradient_norm", "norma_gradiente",
                                                 "norma_gradiente_global"], "—")
            updateValue: root.trainingMetric(["update_norm", "norma_actualizacion",
                                               "delta_norm"], "—")
            sx: root.uiSx
            sy: root.uiSy
        }
    }

    Component {
        id: tokenizationComponent

        Item {
            id: tokenizationView
            objectName: "moduleLabTokenizationView"

            ScrollView {
                anchors.fill: parent
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: parent.width
                    spacing: 10 * root.uiSy

                    TokenRibbon {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 58 * root.uiSy
                        tokens: root.normalizedTokens()
                        sx: root.uiSx
                        sy: root.uiSy
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: tokenizationView.width >= 920 ? 4
                                 : (tokenizationView.width >= 560 ? 2 : 1)
                        columnSpacing: 8 * root.uiSx
                        rowSpacing: 8 * root.uiSy

                        PipelineTile {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 92 * root.uiSy
                            number: "01"
                            title: "Segmentar"
                            detail: root.tokens.length + " piezas detectadas"
                            accent: Style.Theme.inferencia_estructura
                            sx: root.uiSx
                            sy: root.uiSy
                        }
                        PipelineTile {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 92 * root.uiSy
                            number: "02"
                            title: "Asignar IDs"
                            detail: root.shapeText(root.panelFor("token_ids"))
                            accent: Style.Theme.inferencia_contexto
                            sx: root.uiSx
                            sy: root.uiSy
                        }
                        PipelineTile {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 92 * root.uiSy
                            number: "03"
                            title: root.trainingMode ? "Formar batch" : "Ajustar contexto"
                            detail: root.trainingMode ? "padding + especiales" : "recorte al máximo"
                            accent: Style.Theme.inferencia_transformacion
                            sx: root.uiSx
                            sy: root.uiSy
                        }
                        PipelineTile {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 92 * root.uiSy
                            number: "04"
                            title: "Construir máscara"
                            detail: "1 visible · 0 bloqueado"
                            accent: Style.Theme.inferencia_resultado
                            sx: root.uiSx
                            sy: root.uiSy
                        }
                    }

                    TensorMatrixCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(205, 245 * root.uiSy)
                        panel: root.panelFor("padding_mask")
                        matrix: root.matrixForPanel("padding_mask")
                        fallbackTitle: "Máscara de padding"
                        fallbackDescription: "Distingue tokens reales de posiciones PAD antes de la atención."
                        colorMode: "mask"
                        rowPrefix: "B"
                        valueLabel: "visible"
                        sx: root.uiSx
                        sy: root.uiSy
                        onInspectRequested: function(panel) { root.inspectRequested(panel) }
                    }

                    InspectionStrip {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42 * root.uiSy
                        panels: root.panelsByKeys(["token_ids", "positions", "padding_mask"])
                        sx: root.uiSx
                        sy: root.uiSy
                        onRequested: function(panel) { root.inspectRequested(panel) }
                    }
                }
            }
        }
    }

    Component {
        id: embeddingComponent

        Item {
            id: embeddingView
            objectName: "moduleLabEmbeddingView"
            readonly property bool positionStep: root.visualId.indexOf("position") >= 0
                                                 || root.visualId.indexOf("posicion") >= 0
                                                 || root.visualId.indexOf("sum") >= 0
                                                 || root.visualId.indexOf("suma") >= 0
                                                 || root.stepIndex >= 4

            ColumnLayout {
                anchors.fill: parent
                spacing: 8 * root.uiSy

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: embeddingView.positionStep ? 1 : 0

                    TokenEmbeddingScene {
                        tensorData: root.tensorData("embedding", "embedding_encoder_escalado")
                        tokens: root.normalizedTokens()
                        active: StackLayout.isCurrentItem
                        reducedMotion: false
                        selectedRow: Math.max(0, Math.min(root.tokens.length - 1,
                                                          root.selectedToken))
                        sx: root.uiSx
                        sy: root.uiSy
                    }

                    EmbeddingPositionScene {
                        projection: root.positionalProjection()
                        tokens: root.normalizedTokens()
                        active: StackLayout.isCurrentItem
                        reducedMotion: false
                        sx: root.uiSx
                        sy: root.uiSy
                    }
                }

                InspectionStrip {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42 * root.uiSy
                    panels: root.panelsByKeys(["embedding", "position",
                                               "embedding_plus_position"])
                    sx: root.uiSx
                    sy: root.uiSy
                    onRequested: function(panel) { root.inspectRequested(panel) }
                }
            }
        }
    }

    Component {
        id: attentionComponent

        Item {
            id: attentionView
            objectName: "moduleLabAttentionView"

            ColumnLayout {
                anchors.fill: parent
                spacing: 7 * root.uiSy

                Flickable {
                    id: attentionViewport
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: Math.max(width, 720 * root.uiSx)
                    contentHeight: height
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

                    AttentionComputationScene {
                        width: attentionViewport.contentWidth
                        height: attentionViewport.height
                        attentionData: root.attentionData(0)
                        causalMaskData: root.causalMaskData()
                        phase: root.attentionPhase()
                        branchIndex: 0
                        headIndex: root.selectedHead
                        layerIndex: root.selectedLayer
                        active: true
                        reducedMotion: false
                        sx: root.uiSx
                        sy: root.uiSy
                    }
                }

                InspectionStrip {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42 * root.uiSy
                    panels: root.panelsByKeys(["q", "k", "v", "scores",
                                               "attention_weights", "attention_output"])
                    sx: root.uiSx
                    sy: root.uiSy
                    onRequested: function(panel) { root.inspectRequested(panel) }
                }
            }
        }
    }

    Component {
        id: multiHeadComponent

        Item {
            id: multiHeadView
            objectName: "moduleLabMultiHeadView"

            ColumnLayout {
                anchors.fill: parent
                spacing: 7 * root.uiSy

                SplitView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    orientation: multiHeadView.width >= 820
                                 ? Qt.Horizontal : Qt.Vertical

                    Item {
                        SplitView.fillWidth: true
                        SplitView.fillHeight: true
                        SplitView.minimumWidth: multiHeadView.width >= 820 ? 470 : 0
                        SplitView.minimumHeight: 210

                        MultiHeadSplitScene {
                            anchors.fill: parent
                            metadata: root.metadata
                            attentionData: root.attentionData(0)
                            active: true
                            reducedMotion: false
                            sx: root.uiSx
                            sy: root.uiSy
                        }
                    }

                    TensorMatrixCard {
                        SplitView.preferredWidth: multiHeadView.width >= 820
                                                  ? Math.max(290, multiHeadView.width * 0.34)
                                                  : multiHeadView.width
                        SplitView.preferredHeight: multiHeadView.width >= 820
                                                   ? multiHeadView.height
                                                   : Math.max(210, multiHeadView.height * 0.42)
                        SplitView.minimumWidth: multiHeadView.width >= 820 ? 260 : 0
                        SplitView.minimumHeight: 190
                        panel: root.panelFor("head_attention")
                        matrix: root.headMatrix()
                        fallbackTitle: "Mapa de la cabeza H"
                                       + String(root.selectedHead + 1).padStart(2, "0")
                        fallbackDescription: "Cada fila consulta las keys con una distribución distinta."
                        colorMode: "sequential"
                        rowPrefix: "Q"
                        valueLabel: "atención"
                        sx: root.uiSx
                        sy: root.uiSy
                        onInspectRequested: function(panel) { root.inspectRequested(panel) }
                    }
                }

                InspectionStrip {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42 * root.uiSy
                    panels: root.panelsByKeys(["head_attention", "head_output",
                                               "concatenated", "projected"])
                    sx: root.uiSx
                    sy: root.uiSy
                    onRequested: function(panel) { root.inspectRequested(panel) }
                }
            }
        }
    }

    Component {
        id: encoderComponent

        Item {
            id: encoderView
            objectName: "moduleLabEncoderView"
            readonly property int sceneIndex: root.encoderSceneIndex()

            ColumnLayout {
                anchors.fill: parent
                spacing: 7 * root.uiSy

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: encoderView.sceneIndex

                    AttentionComputationScene {
                        attentionData: root.attentionData(0)
                        causalMaskData: root.causalMaskData()
                        phase: root.attentionPhase()
                        branchIndex: 0
                        headIndex: root.selectedHead
                        layerIndex: root.selectedLayer
                        active: StackLayout.isCurrentItem
                        reducedMotion: false
                        sx: root.uiSx
                        sy: root.uiSy
                    }

                    ResidualLayerNormScene {
                        sceneData: root.residualData(0, root.encoderResidualUsesFfn())
                        sublayerLabel: root.encoderResidualUsesFfn()
                                       ? "FFN" : "Self-attention"
                        active: StackLayout.isCurrentItem
                        reducedMotion: false
                        sx: root.uiSx
                        sy: root.uiSy
                    }

                    FeedForwardExpansionScene {
                        sceneData: root.ffnData(0)
                        tokens: root.normalizedTokens()
                        active: StackLayout.isCurrentItem
                        reducedMotion: false
                        sx: root.uiSx
                        sy: root.uiSy
                    }

                    LayerSkyscraperScene {
                        trajectory: root.forwardDetail && root.forwardDetail.trayectorias
                                    ? root.forwardDetail.trayectorias.encoder || ({}) : ({})
                        tokens: root.normalizedTokens()
                        active: StackLayout.isCurrentItem
                        sx: root.uiSx
                        sy: root.uiSy
                    }
                }

                InspectionStrip {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42 * root.uiSy
                    panels: root.panelsByKeys(["encoder_input", "attention_residual",
                                               "ffn_hidden", "encoder_output"])
                    sx: root.uiSx
                    sy: root.uiSy
                    onRequested: function(panel) { root.inspectRequested(panel) }
                }
            }
        }
    }

    Component {
        id: decoderComponent

        Item {
            id: decoderView
            objectName: "moduleLabDecoderView"
            readonly property int branch: root.decoderBranch()
            readonly property int sceneIndex: root.decoderSceneIndex()

            ColumnLayout {
                anchors.fill: parent
                spacing: 7 * root.uiSy

                ModeDifferenceCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46 * root.uiSy
                    training: root.trainingMode
                    trainingText: "Teacher forcing: procesa todas las posiciones conocidas sin revelar el futuro."
                    inferenceText: "Prefijo autoregresivo: cada token elegido amplía el contexto del siguiente paso."
                    sx: root.uiSx
                    sy: root.uiSy
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: decoderView.sceneIndex

                    AttentionComputationScene {
                        attentionData: root.attentionData(decoderView.branch)
                        causalMaskData: root.causalMaskData()
                        phase: root.attentionPhase()
                        branchIndex: decoderView.branch
                        headIndex: root.selectedHead
                        layerIndex: root.selectedLayer
                        active: StackLayout.isCurrentItem
                        reducedMotion: false
                        sx: root.uiSx
                        sy: root.uiSy
                    }

                    ResidualLayerNormScene {
                        sceneData: root.residualData(decoderView.branch,
                                                     root.visualId.indexOf("ffn") >= 0)
                        sublayerLabel: decoderView.branch === 2
                                       ? "Cross-attention" : "Atención causal"
                        active: StackLayout.isCurrentItem
                        reducedMotion: false
                        sx: root.uiSx
                        sy: root.uiSy
                    }

                    FeedForwardExpansionScene {
                        sceneData: root.ffnData(1)
                        tokens: root.normalizedTokens()
                        active: StackLayout.isCurrentItem
                        reducedMotion: false
                        sx: root.uiSx
                        sy: root.uiSy
                    }

                    LayerSkyscraperScene {
                        trajectory: root.forwardDetail && root.forwardDetail.trayectorias
                                    ? root.forwardDetail.trayectorias.decoder || ({}) : ({})
                        tokens: root.inferenceSnapshot && root.inferenceSnapshot.tokens_decoder
                                ? root.inferenceSnapshot.tokens_decoder
                                : root.normalizedTokens()
                        active: StackLayout.isCurrentItem
                        sx: root.uiSx
                        sy: root.uiSy
                    }
                }

                InspectionStrip {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42 * root.uiSy
                    panels: root.panelsByKeys(["causal_mask", "masked_attention",
                                               "cross_attention", "decoder_output"])
                    sx: root.uiSx
                    sy: root.uiSy
                    onRequested: function(panel) { root.inspectRequested(panel) }
                }
            }
        }
    }

    Component {
        id: outputComponent

        Item {
            id: outputView
            objectName: "moduleLabOutputView"
            readonly property int sceneIndex: root.outputSceneIndex()

            ColumnLayout {
                anchors.fill: parent
                spacing: 7 * root.uiSy

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: outputView.sceneIndex

                    OutputProjectionScene {
                        snapshot: root.outputSnapshot()
                        logitsData: root.forwardDetail && root.forwardDetail.logits_lineales
                                    ? root.forwardDetail.logits_lineales
                                    : (root.forwardDetail.logits || ({}))
                        hiddenData: root.detailGlobal && root.detailGlobal.salida_decoder
                                    ? root.detailGlobal.salida_decoder
                                    : root.tensorData("decoder_output", "")
                        active: StackLayout.isCurrentItem
                        reducedMotion: false
                        sx: root.uiSx
                        sy: root.uiSy
                    }

                    CandidateBoard {
                        candidates: root.normalizedCandidates()
                        selectedToken: root.analysis && root.analysis.selected_token
                                       ? root.analysis.selected_token
                                       : (root.inferenceSnapshot.token_elegido || ({}))
                        sx: root.uiSx
                        sy: root.uiSy
                    }

                    LearningSignalBoard {
                        training: root.trainingSnapshot
                        sx: root.uiSx
                        sy: root.uiSy
                    }
                }

                InspectionStrip {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42 * root.uiSy
                    panels: root.panelsByKeys(["logits", "probabilities",
                                               "filtered_candidates", "selected_token"])
                    sx: root.uiSx
                    sy: root.uiSy
                    onRequested: function(panel) { root.inspectRequested(panel) }
                }
            }
        }
    }

    Component {
        id: transformerComponent

        Item {
            id: transformerView
            objectName: "moduleLabTransformerView"
            readonly property int sceneIndex: root.moduleEightSceneIndex()

            ColumnLayout {
                anchors.fill: parent
                spacing: 7 * root.uiSy

                ListView {
                    id: processRibbon
                    objectName: "moduleLabTransformerProcess"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70 * root.uiSy
                    orientation: ListView.Horizontal
                    spacing: 7 * root.uiSx
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.transformerStages()
                    ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: ProcessStageCard {
                        required property var modelData
                        required property int index
                        height: processRibbon.height - 8 * root.uiSy
                        width: Math.max(145 * root.uiSx,
                                        (processRibbon.width - 28 * root.uiSx)
                                        / Math.min(5, processRibbon.count))
                        number: root.textValue(modelData.numero,
                                               String(index + 1).padStart(2, "0"))
                        title: root.textValue(modelData.titulo, "Etapa")
                        detail: root.textValue(modelData.dato, "Datos reales")
                        accent: modelData.color || Style.Theme.acento
                        current: index === Math.max(0, Math.min(processRibbon.count - 1,
                                                                root.stepIndex))
                        sx: root.uiSx
                        sy: root.uiSy
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: transformerView.sceneIndex

                    TokenEmbeddingScene {
                        tensorData: root.tensorData("embedding", "entrada_encoder")
                        tokens: root.normalizedTokens()
                        active: StackLayout.isCurrentItem
                        reducedMotion: false
                        sx: root.uiSx
                        sy: root.uiSy
                    }

                    AttentionComputationScene {
                        attentionData: root.attentionData(root.visualId.indexOf("decoder") >= 0
                                                          ? root.decoderBranch() : 0)
                        causalMaskData: root.causalMaskData()
                        phase: root.attentionPhase()
                        branchIndex: root.visualId.indexOf("decoder") >= 0
                                     ? root.decoderBranch() : 0
                        headIndex: root.selectedHead
                        layerIndex: root.selectedLayer
                        active: StackLayout.isCurrentItem
                        reducedMotion: false
                        sx: root.uiSx
                        sy: root.uiSy
                    }

                    OutputProjectionScene {
                        snapshot: root.outputSnapshot()
                        logitsData: root.forwardDetail && root.forwardDetail.logits_lineales
                                    ? root.forwardDetail.logits_lineales
                                    : (root.forwardDetail.logits || ({}))
                        hiddenData: root.detailGlobal && root.detailGlobal.salida_decoder
                                    ? root.detailGlobal.salida_decoder
                                    : root.tensorData("decoder", "")
                        active: StackLayout.isCurrentItem
                        reducedMotion: false
                        sx: root.uiSx
                        sy: root.uiSy
                    }
                }

                InspectionStrip {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42 * root.uiSy
                    panels: root.panelsByKeys(["tokens", "embedding", "encoder",
                                               "decoder", "logits", "selected_token"])
                    sx: root.uiSx
                    sy: root.uiSy
                    onRequested: function(panel) { root.inspectRequested(panel) }
                }
            }
        }
    }

    component FlowFact: Rectangle {
        id: fact
        property string label: ""
        property string value: ""
        property color accent: Style.Theme.acento
        property real sx: 1
        property real sy: 1

        implicitHeight: Math.max(27, factRow.implicitHeight + 8 * sy)
        radius: 7 * sx
        color: Style.Theme.superficie_alterna
        border.color: Style.Theme.borde_suave

        RowLayout {
            id: factRow
            anchors.fill: parent
            anchors.leftMargin: 9 * fact.sx
            anchors.rightMargin: 9 * fact.sx
            spacing: 7 * fact.sx

            Text {
                text: fact.label
                color: fact.accent
                font.bold: true
                font.pixelSize: Math.max(9, 9 * fact.sx)
            }
            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: fact.value
                color: Style.Theme.texto_secundario_fuerte
                font.pixelSize: Math.max(9, 10 * fact.sx)
                elide: Text.ElideRight
            }
        }
    }

    component TokenRibbon: Rectangle {
        id: ribbon
        property var tokens: []
        property real sx: 1
        property real sy: 1

        radius: 10 * sx
        color: Style.Theme.surface
        border.color: Style.Theme.borde_suave

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8 * ribbon.sx
            spacing: 8 * ribbon.sx

            Text {
                text: "TEXTO → TOKENS"
                color: Style.Theme.inferencia_estructura
                font.bold: true
                font.pixelSize: Math.max(9, 10 * ribbon.sx)
            }

            ListView {
                id: tokenList
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: ListView.Horizontal
                spacing: 6 * ribbon.sx
                clip: true
                model: ribbon.tokens
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    id: tokenChip
                    required property var modelData
                    required property int index
                    width: Math.max(62 * ribbon.sx,
                                    chipText.implicitWidth + 18 * ribbon.sx)
                    height: tokenList.height - 5 * ribbon.sy
                    radius: 8 * ribbon.sx
                    color: Style.Theme.chip_fondo
                    border.color: Style.Theme.chip_borde

                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: ribbon.tokens[tokenChip.index].text + " · "
                              + ribbon.tokens[tokenChip.index].id
                        color: Style.Theme.chip_texto
                        font.family: Style.Theme.fuente_mono
                        font.pixelSize: Math.max(9, 10 * ribbon.sx)
                    }
                }
            }
        }
    }

    component PipelineTile: Rectangle {
        id: tile
        property string number: ""
        property string title: ""
        property string detail: ""
        property color accent: Style.Theme.acento
        property real sx: 1
        property real sy: 1

        radius: 11 * sx
        color: Style.Theme.surface
        border.color: accent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10 * tile.sx
            spacing: 3 * tile.sy

            RowLayout {
                Layout.fillWidth: true
                Rectangle {
                    Layout.preferredWidth: 27 * tile.sx
                    Layout.preferredHeight: 27 * tile.sy
                    radius: height / 2
                    color: tile.accent
                    Text {
                        anchors.centerIn: parent
                        text: tile.number
                        color: Style.Theme.texto_sobre_color
                        font.bold: true
                        font.pixelSize: Math.max(9, 9 * tile.sx)
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: tile.title
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: Math.max(11, 12 * tile.sx)
                    elide: Text.ElideRight
                }
            }
            Text {
                Layout.fillWidth: true
                text: tile.detail
                color: Style.Theme.texto_secundario
                font.pixelSize: Math.max(9, 10 * tile.sx)
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }

    component TensorMatrixCard: Rectangle {
        id: matrixCard
        property var panel: ({})
        property var matrix: []
        property string fallbackTitle: "Matriz"
        property string fallbackDescription: "Valores de la operación actual."
        property string colorMode: "diverging"
        property string rowPrefix: "R"
        property string valueLabel: "valor"
        property real sx: 1
        property real sy: 1

        signal inspectRequested(var panel)

        radius: 12 * sx
        color: Style.Theme.surface
        border.color: Style.Theme.borde_suave

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10 * matrixCard.sx
            spacing: 5 * matrixCard.sy

            RowLayout {
                Layout.fillWidth: true
                spacing: 7 * matrixCard.sx

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: root.textValue(matrixCard.panel.title,
                                             matrixCard.fallbackTitle)
                        color: Style.Theme.texto_primario
                        font.bold: true
                        font.pixelSize: Math.max(12, 13 * matrixCard.sx)
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.textValue(matrixCard.panel.description,
                                             matrixCard.fallbackDescription)
                        color: Style.Theme.texto_secundario
                        font.pixelSize: Math.max(9, 10 * matrixCard.sx)
                        elide: Text.ElideRight
                    }
                }

                BotonAccesible {
                    visible: root.panelHasData(matrixCard.panel)
                    Layout.preferredWidth: 112 * matrixCard.sx
                    Layout.preferredHeight: 32 * matrixCard.sy
                    text: "Inspeccionar"
                    font.pixelSize: Math.max(9, 10 * matrixCard.sx)
                    onClicked: matrixCard.inspectRequested(matrixCard.panel)
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ScientificMatrix {
                    anchors.fill: parent
                    visible: matrixCard.matrix.length > 0
                    matrix: matrixCard.matrix
                    colorMode: matrixCard.colorMode
                    localScale: matrixCard.colorMode === "diverging"
                    rowPrefix: matrixCard.rowPrefix
                    valueLabel: matrixCard.valueLabel
                    selectedRow: 0
                    selectedColumn: 0
                    alternativeText: root.textValue(matrixCard.panel.title,
                                                    matrixCard.fallbackTitle)
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 24 * matrixCard.sx
                    visible: matrixCard.matrix.length === 0
                    text: "Ejecuta el paso para cargar esta matriz real."
                    color: Style.Theme.texto_secundario
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.pixelSize: Math.max(10, 11 * matrixCard.sx)
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.panelHasData(matrixCard.panel)
                      ? root.shapeText(matrixCard.panel) + " · "
                        + root.statsText(matrixCard.panel)
                      : "Esperando datos del modelo"
                color: Style.Theme.texto_secundario
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.pixelSize: Math.max(9, 9 * matrixCard.sx)
            }
        }
    }

    component InspectionStrip: Rectangle {
        id: strip
        property var panels: []
        property real sx: 1
        property real sy: 1

        signal requested(var panel)

        radius: 9 * sx
        color: Style.Theme.superficie_alterna
        border.color: Style.Theme.borde_suave

        RowLayout {
            anchors.fill: parent
            anchors.margins: 5 * strip.sx
            spacing: 7 * strip.sx

            Text {
                text: "TENSORES"
                color: Style.Theme.texto_secundario
                font.bold: true
                font.pixelSize: Math.max(9, 9 * strip.sx)
            }

            ListView {
                id: panelList
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: ListView.Horizontal
                spacing: 6 * strip.sx
                clip: true
                model: strip.panels
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: BotonAccesible {
                    required property var modelData
                    height: panelList.height
                    width: Math.max(118 * strip.sx,
                                    Math.min(230 * strip.sx,
                                             implicitWidth + 10 * strip.sx))
                    text: "▦ " + root.textValue(modelData.title, modelData.key)
                    font.pixelSize: Math.max(9, 9 * strip.sx)
                    onClicked: strip.requested(modelData)
                }
            }

            Text {
                visible: strip.panels.length === 0
                Layout.fillWidth: true
                text: "Los tensores inspeccionables aparecerán al ejecutar el paso."
                color: Style.Theme.texto_terciario
                elide: Text.ElideRight
                font.pixelSize: Math.max(9, 9 * strip.sx)
            }
        }
    }

    component ModeDifferenceCard: Rectangle {
        id: difference
        property bool training: false
        property string trainingText: ""
        property string inferenceText: ""
        property real sx: 1
        property real sy: 1

        radius: 9 * sx
        color: training ? Style.Theme.formula_fondo : Style.Theme.info_fondo
        border.color: training ? Style.Theme.inferencia_transformacion
                               : Style.Theme.inferencia_estructura

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8 * difference.sx
            spacing: 8 * difference.sx

            Text {
                text: difference.training ? "↶" : "→"
                color: difference.training ? Style.Theme.formula_texto
                                           : Style.Theme.info_texto
                font.bold: true
                font.pixelSize: Math.max(14, 16 * difference.sx)
            }
            Text {
                Layout.fillWidth: true
                text: difference.training ? difference.trainingText
                                          : difference.inferenceText
                color: difference.training ? Style.Theme.formula_texto
                                           : Style.Theme.info_texto
                font.pixelSize: Math.max(10, 11 * difference.sx)
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }

    component CandidateBoard: Rectangle {
        id: candidateBoard
        property var candidates: []
        property var selectedToken: ({})
        property real sx: 1
        property real sy: 1
        readonly property real maximumProbability: {
            var maximum = 0
            for (var index = 0; index < candidates.length; ++index)
                maximum = Math.max(maximum, Number(candidates[index].probability || 0))
            return Math.max(maximum, 1e-9)
        }

        radius: 12 * sx
        color: Style.Theme.surface
        border.color: Style.Theme.borde_suave

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12 * candidateBoard.sx
            spacing: 8 * candidateBoard.sy

            Text {
                Layout.fillWidth: true
                text: "DISTRIBUCIÓN Y SELECCIÓN DEL SIGUIENTE TOKEN"
                color: Style.Theme.inferencia_foco
                font.bold: true
                font.pixelSize: Math.max(11, 12 * candidateBoard.sx)
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: "Las barras provienen de los logits filtrados; no son valores inventados."
                color: Style.Theme.texto_secundario
                font.pixelSize: Math.max(9, 10 * candidateBoard.sx)
                wrapMode: Text.WordWrap
            }

            ListView {
                id: candidateList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6 * candidateBoard.sy
                model: candidateBoard.candidates
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    id: candidateRow
                    required property var modelData
                    required property int index
                    width: candidateList.width
                    height: 42 * candidateBoard.sy
                    radius: 8 * candidateBoard.sx
                    color: modelData.chosen ? Style.Theme.exito_fondo
                                            : Style.Theme.superficie_alterna
                    border.color: modelData.chosen
                                  ? Style.Theme.inferencia_resultado
                                  : Style.Theme.borde_suave

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 7 * candidateBoard.sx
                        spacing: 8 * candidateBoard.sx

                        Text {
                            Layout.preferredWidth: 26 * candidateBoard.sx
                            text: candidateRow.modelData.rank
                            color: Style.Theme.texto_secundario
                            font.bold: true
                            font.pixelSize: Math.max(9, 10 * candidateBoard.sx)
                        }
                        Text {
                            Layout.preferredWidth: 105 * candidateBoard.sx
                            text: root.textValue(candidateRow.modelData.texto, "<token>")
                            color: Style.Theme.texto_primario
                            font.family: Style.Theme.fuente_mono
                            font.bold: candidateRow.modelData.chosen
                            elide: Text.ElideRight
                            font.pixelSize: Math.max(10, 11 * candidateBoard.sx)
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 10 * candidateBoard.sy
                            radius: height / 2
                            color: Style.Theme.borde_suave
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1,
                                      Number(candidateRow.modelData.probability || 0)
                                      / candidateBoard.maximumProbability))
                                height: parent.height
                                radius: height / 2
                                color: candidateRow.modelData.chosen
                                       ? Style.Theme.inferencia_resultado
                                       : Style.Theme.inferencia_foco
                            }
                        }
                        Text {
                            Layout.preferredWidth: 66 * candidateBoard.sx
                            text: (100 * Number(candidateRow.modelData.probability || 0)).toFixed(2) + "%"
                            color: candidateRow.modelData.chosen
                                   ? Style.Theme.exito_texto
                                   : Style.Theme.texto_secundario_fuerte
                            horizontalAlignment: Text.AlignRight
                            font.bold: true
                            font.pixelSize: Math.max(9, 10 * candidateBoard.sx)
                        }
                    }
                }
            }

            Text {
                visible: candidateBoard.candidates.length === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: "Ejecuta la inferencia para comparar los candidatos reales."
                color: Style.Theme.texto_secundario
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
                font.pixelSize: Math.max(11, 12 * candidateBoard.sx)
            }
        }
    }

    component LearningSignalBoard: Rectangle {
        id: learningBoard
        property var training: ({})
        property real sx: 1
        property real sy: 1

        radius: 12 * sx
        color: Style.Theme.surface
        border.color: Style.Theme.inferencia_transformacion

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14 * learningBoard.sx
            spacing: 10 * learningBoard.sy

            Text {
                Layout.fillWidth: true
                text: "SEÑAL DE APRENDIZAJE DEL COMPONENTE"
                color: Style.Theme.inferencia_transformacion
                font.bold: true
                font.pixelSize: Math.max(12, 13 * learningBoard.sx)
            }
            Text {
                Layout.fillWidth: true
                text: "Backward calcula sensibilidad; aquí se estima la actualización sin modificar el modelo."
                color: Style.Theme.texto_secundario_fuerte
                wrapMode: Text.WordWrap
                font.pixelSize: Math.max(10, 11 * learningBoard.sx)
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: learningBoard.width >= 650 ? 3 : 1
                columnSpacing: 10 * learningBoard.sx
                rowSpacing: 10 * learningBoard.sy

                MetricCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "PÉRDIDA"
                    value: root.formatNumber(root.trainingMetric(
                                ["loss", "perdida", "perdida_batch"], NaN))
                    detail: "Error usado como origen del backward"
                    accent: Style.Theme.inferencia_foco
                    sx: learningBoard.sx
                    sy: learningBoard.sy
                }
                MetricCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "GRADIENTE"
                    value: root.formatNumber(root.trainingMetric(
                                ["gradient_norm", "norma_gradiente",
                                 "norma_gradiente_global"], NaN))
                    detail: "Magnitud de ∂L/∂θ"
                    accent: Style.Theme.inferencia_transformacion
                    sx: learningBoard.sx
                    sy: learningBoard.sy
                }
                MetricCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "ACTUALIZACIÓN"
                    value: root.formatNumber(root.trainingMetric(
                                ["update_norm", "norma_actualizacion",
                                 "delta_norm"], NaN))
                    detail: "Cambio hipotético, no aplicado"
                    accent: Style.Theme.inferencia_resultado
                    sx: learningBoard.sx
                    sy: learningBoard.sy
                }
            }
        }
    }

    component MetricCard: Rectangle {
        id: metric
        property string label: ""
        property string value: "—"
        property string detail: ""
        property color accent: Style.Theme.acento
        property real sx: 1
        property real sy: 1

        radius: 10 * sx
        color: Style.Theme.superficie_alterna
        border.color: accent

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 20 * metric.sx
            spacing: 4 * metric.sy
            Text {
                Layout.fillWidth: true
                text: metric.label
                color: metric.accent
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Math.max(9, 10 * metric.sx)
            }
            Text {
                Layout.fillWidth: true
                text: metric.value
                color: Style.Theme.texto_primario
                font.bold: true
                font.family: Style.Theme.fuente_mono
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Math.max(17, 21 * metric.sx)
            }
            Text {
                Layout.fillWidth: true
                text: metric.detail
                color: Style.Theme.texto_secundario
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: Math.max(9, 9 * metric.sx)
            }
        }
    }

    component TrainingEvidenceBar: Rectangle {
        id: evidence
        property var lossValue: "—"
        property var gradientValue: "—"
        property var updateValue: "—"
        property real sx: 1
        property real sy: 1

        radius: 9 * sx
        color: Style.Theme.formula_fondo
        border.color: Style.Theme.inferencia_transformacion

        RowLayout {
            anchors.fill: parent
            anchors.margins: 7 * evidence.sx
            spacing: 9 * evidence.sx

            Text {
                text: "BACKWARD REAL"
                color: Style.Theme.formula_texto
                font.bold: true
                font.pixelSize: Math.max(9, 10 * evidence.sx)
            }
            EvidenceMetric {
                Layout.fillWidth: true
                label: "Pérdida"
                value: root.formatNumber(evidence.lossValue)
                sx: evidence.sx
            }
            EvidenceMetric {
                Layout.fillWidth: true
                label: "‖grad‖"
                value: root.formatNumber(evidence.gradientValue)
                sx: evidence.sx
            }
            EvidenceMetric {
                Layout.fillWidth: true
                label: "‖Δθ hipotético‖"
                value: root.formatNumber(evidence.updateValue)
                sx: evidence.sx
            }
        }
    }

    component EvidenceMetric: Text {
        property string label: ""
        property string value: "—"
        property real sx: 1
        text: label + "  " + value
        color: Style.Theme.formula_texto
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        font.family: Style.Theme.fuente_mono
        font.pixelSize: Math.max(9, 10 * sx)
    }

    component ProcessStageCard: Rectangle {
        id: processCard
        property string number: ""
        property string title: ""
        property string detail: ""
        property color accent: Style.Theme.acento
        property bool current: false
        property real sx: 1
        property real sy: 1

        radius: 9 * sx
        color: current ? Qt.alpha(accent, 0.14) : Style.Theme.surface
        border.color: current ? accent : Style.Theme.borde_suave
        border.width: current ? 2 : 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 7 * processCard.sx
            spacing: 7 * processCard.sx

            Rectangle {
                Layout.preferredWidth: 27 * processCard.sx
                Layout.preferredHeight: 27 * processCard.sy
                radius: height / 2
                color: processCard.accent
                Text {
                    anchors.centerIn: parent
                    text: processCard.number
                    color: Style.Theme.texto_sobre_color
                    font.bold: true
                    font.pixelSize: Math.max(8, 9 * processCard.sx)
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: processCard.title
                    color: processCard.current ? processCard.accent
                                               : Style.Theme.texto_primario
                    font.bold: true
                    elide: Text.ElideRight
                    font.pixelSize: Math.max(10, 11 * processCard.sx)
                }
                Text {
                    Layout.fillWidth: true
                    text: processCard.detail
                    color: Style.Theme.texto_secundario
                    elide: Text.ElideRight
                    font.pixelSize: Math.max(8, 9 * processCard.sx)
                }
            }
        }
    }
}
