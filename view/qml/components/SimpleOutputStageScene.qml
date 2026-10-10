pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../styles" as Style

Item {
    id: root
    objectName: "simpleOutputStageScene"

    property var step: ({})
    property var candidates: []
    property var selectedToken: ({})
    property var panel: ({})
    property var training: ({})
    property bool active: false
    property bool reducedMotion: false
    property real sx: 1
    property real sy: 1
    property real progress: 1

    readonly property string visualId: String(step && step.visual || step && step.id || "").toLowerCase()
    readonly property var definition: stageDefinition()
    readonly property var visibleCandidates: candidates && candidates.slice
                                                     ? candidates.slice(0, 5) : []
    readonly property var vectorValues: panel && panel.preview && panel.preview.slice
                                                ? panel.preview.slice(0, 8) : []
    readonly property real maximumCandidateValue: candidateMaximum()

    function stageDefinition() {
        var id = visualId
        var stepId = String(step && step.id || "").toLowerCase()
        if (id.indexOf("update") >= 0)
            return stage("training", "Parámetros θ", "− η · gradiente", "Cambio θ′", "Cambio no aplicado")
        if (id.indexOf("backward") >= 0 || id.indexOf("gradient") >= 0)
            return stage("training", "Pérdida L", "Backward", "Gradiente ∂L/∂θ", "Sensibilidad del parámetro")
        if (id.indexOf("loss") >= 0)
            return stage("training", "Logits + objetivo", "Cross-entropy", "Pérdida L", "Error escalar")
        if (id.indexOf("target") >= 0)
            return stage("selected", "Logits", "Comparar", "Token objetivo", "Respuesta esperada")
        if (id.indexOf("feedback") >= 0 || id.indexOf("autoregressive") >= 0)
            return stage("selected", "Token elegido", "Añadir al prefijo", "Nuevo contexto", "Comienza otra vuelta")
        if (id.indexOf("select") >= 0)
            return stage("selected", "Probabilidades", "Elegir", "Siguiente token", "Resultado de la etapa")
        if (stepId === "full_filters")
            return stage("candidates", "Logits", "Temperatura → Top-K → Top-P", "Logits filtrados", "Solo continúan los candidatos permitidos")
        if (id.indexOf("softmax") >= 0)
            return stage("candidates", "Logits filtrados", "Softmax", "Probabilidades", "Suman 1")
        if (id.indexOf("top_p") >= 0)
            return stage("candidates", "Candidatos", "Acumular hasta P", "Núcleo Top-P", "Solo queda la masa útil")
        if (id.indexOf("top_k") >= 0)
            return stage("candidates", "Logits", "Conservar K", "Top-K", "Se eliminan los demás")
        if (id.indexOf("temperature") >= 0)
            return stage("candidates", "Logits", "Dividir entre T", "Logits ajustados", "Cambia la concentración")
        if (id.indexOf("linear") >= 0 || id.indexOf("projection") >= 0
                || id.indexOf("logit") >= 0)
            return stage("logits", "h_final", "W_vocab + b", "Logits", "Un puntaje por token")
        if (id.indexOf("output_hidden") >= 0)
            return stage("vector", "Salida del decoder", "Elegir posición", "h_final", "Resumen del contexto")
        return stage("process",
                     textValue(step && step.input, "Entrada"),
                     textValue(step && step.title, "Transformación"),
                     textValue(step && step.output, "Salida"),
                     textValue(step && step.explanation,
                               "Resultado preparado para el siguiente paso"))
    }

    function textValue(value, fallback) {
        if (value === undefined || value === null || String(value).trim().length === 0)
            return String(fallback || "")
        return String(value)
    }

    function stage(kind, first, operation, last, takeaway) {
        return {
            kind: kind,
            first: first,
            operation: operation,
            last: last,
            takeaway: takeaway
        }
    }

    function candidateMaximum() {
        var maximum = 0
        var logits = definition.kind === "logits"
        for (var index = 0; index < visibleCandidates.length; ++index) {
            var candidate = visibleCandidates[index] || ({})
            var value = logits ? Math.abs(Number(candidate.logit || 0))
                               : Number(candidate.probability !== undefined
                                        ? candidate.probability
                                        : candidate.probabilidad || 0)
            maximum = Math.max(maximum, value)
        }
        return Math.max(maximum, 1e-9)
    }

    function candidateValue(candidate) {
        if (definition.kind === "logits")
            return Number(candidate && candidate.logit || 0)
        return Number(candidate && candidate.probability !== undefined
                      ? candidate.probability
                      : candidate && candidate.probabilidad || 0)
    }

    function candidateLabel(candidate) {
        var value = candidateValue(candidate)
        if (definition.kind === "logits")
            return "logit " + value.toFixed(3)
        return (value * 100).toFixed(2) + "%"
    }

    function tokenText(candidate) {
        if (!candidate)
            return "<token>"
        return String(candidate.text !== undefined ? candidate.text
                      : candidate.texto !== undefined ? candidate.texto
                      : candidate.token !== undefined ? candidate.token : "<token>")
    }

    function selectedText() {
        if (visualId.indexOf("target") >= 0
                && panel && panel.preview && panel.preview.length)
            return "ID " + String(panel.preview[0])
        if (selectedToken && (selectedToken.text !== undefined
                              || selectedToken.texto !== undefined))
            return tokenText(selectedToken)
        for (var index = 0; index < visibleCandidates.length; ++index) {
            if (Boolean(visibleCandidates[index].chosen
                        || visibleCandidates[index].elegido))
                return tokenText(visibleCandidates[index])
        }
        return visibleCandidates.length ? tokenText(visibleCandidates[0]) : "—"
    }

    function metricValue(names) {
        for (var index = 0; index < names.length; ++index) {
            var key = names[index]
            if (training && training[key] !== undefined)
                return Number(training[key])
            if (training && training.resumen && training.resumen[key] !== undefined)
                return Number(training.resumen[key])
        }
        return NaN
    }

    function formatMetric(value) {
        var number = Number(value)
        if (!Number.isFinite(number))
            return "—"
        var absolute = Math.abs(number)
        return absolute !== 0 && (absolute < 0.001 || absolute >= 1000)
                ? number.toExponential(2) : number.toFixed(4)
    }

    function replay() {
        stageAnimation.stop()
        progress = reducedMotion ? 1 : 0
        if (!reducedMotion)
            stageAnimation.start()
    }

    onActiveChanged: if (active) replay()
    onStepChanged: if (active) replay()
    onCandidatesChanged: if (active) replay()
    onReducedMotionChanged: if (active) replay()

    NumberAnimation {
        id: stageAnimation
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 1500
        easing.type: Easing.InOutCubic
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10 * root.sx
        spacing: 14 * root.sy

        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * root.sx

            Text {
                Layout.fillWidth: true
                text: "UNA TRANSFORMACIÓN A LA VEZ"
                color: Style.Theme.texto_secundario_fuerte
                font.bold: true
                font.letterSpacing: 0.5
                font.pixelSize: Math.max(10, 10 * root.sx)
            }
            BotonAccesible {
                Layout.preferredWidth: 104 * root.sx
                Layout.preferredHeight: 32 * root.sy
                text: "↻ Repetir"
                font.bold: true
                onClicked: root.replay()
            }
        }

        RowLayout {
            objectName: "simpleOutputFlow"
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(112, 132 * root.sy)
            spacing: 12 * root.sx

            StageNode {
                Layout.fillWidth: true
                Layout.fillHeight: true
                number: "1"
                label: root.definition.first
                accent: Style.Theme.inferencia_contexto
                emphasized: root.progress >= 0.05
                sx: root.sx; sy: root.sy
            }
            Text {
                text: "→"
                color: root.progress >= 0.30
                       ? Style.Theme.inferencia_transformacion
                       : Style.Theme.borde_medio
                font.bold: true
                font.pixelSize: Math.max(24, 30 * root.sx)
                opacity: root.progress >= 0.25 ? 1 : 0.25
            }
            StageNode {
                Layout.fillWidth: true
                Layout.fillHeight: true
                number: "2"
                label: root.definition.operation
                accent: Style.Theme.inferencia_transformacion
                emphasized: root.progress >= 0.36
                sx: root.sx; sy: root.sy
            }
            Text {
                text: "→"
                color: root.progress >= 0.63
                       ? Style.Theme.inferencia_resultado
                       : Style.Theme.borde_medio
                font.bold: true
                font.pixelSize: Math.max(24, 30 * root.sx)
                opacity: root.progress >= 0.58 ? 1 : 0.25
            }
            StageNode {
                Layout.fillWidth: true
                Layout.fillHeight: true
                number: "3"
                label: root.definition.last
                accent: Style.Theme.inferencia_resultado
                emphasized: root.progress >= 0.70
                sx: root.sx; sy: root.sy
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 13 * root.sx
            color: Style.Theme.superficie_alterna
            border.color: Style.Theme.borde_suave
            clip: true

            Loader {
                anchors.fill: parent
                anchors.margins: 14 * root.sx
                sourceComponent: root.definition.kind === "vector" ? vectorComponent
                                 : (root.definition.kind === "training"
                                    ? trainingComponent
                                    : (root.definition.kind === "selected"
                                       ? selectedComponent
                                       : ((root.definition.kind === "candidates"
                                           || root.definition.kind === "logits")
                                          ? candidatesComponent
                                          : processComponent)))
            }
        }

        Text {
            Layout.fillWidth: true
            text: "RESULTADO · " + root.definition.takeaway
            color: Style.Theme.inferencia_resultado
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: Math.max(11, 12 * root.sx)
            opacity: root.progress >= 0.78 ? 1 : 0.15
        }
    }

    Component {
        id: processComponent
        ColumnLayout {
            spacing: 12 * root.sy
            Item { Layout.fillHeight: true }
            Text {
                Layout.fillWidth: true
                text: root.textValue(root.step && root.step.formula,
                                     "entrada → transformación → salida")
                color: Style.Theme.inferencia_transformacion
                font.family: "Cambria Math"
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: Math.max(20, 25 * root.sx)
                opacity: root.progress >= 0.38 ? 1 : 0.18
            }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(parent.width, 520 * root.sx)
                Layout.preferredHeight: 7 * root.sy
                radius: height / 2
                color: Style.Theme.borde_suave
                Rectangle {
                    width: parent.width * root.progress
                    height: parent.height
                    radius: height / 2
                    color: Style.Theme.inferencia_resultado
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.textValue(root.step && root.step.explanation,
                                     root.definition.takeaway)
                color: Style.Theme.texto_secundario_fuerte
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                font.pixelSize: Math.max(11, 13 * root.sx)
                opacity: root.progress >= 0.68 ? 1 : 0.18
            }
            Item { Layout.fillHeight: true }
        }
    }

    Component {
        id: vectorComponent
        ColumnLayout {
            spacing: 12 * root.sy
            Text {
                Layout.fillWidth: true
                text: "h_final · una sola representación del contexto"
                color: Style.Theme.inferencia_contexto
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Math.max(13, 15 * root.sx)
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6 * root.sx
                Repeater {
                    model: root.vectorValues
                    delegate: Rectangle {
                        id: vectorCell
                        required property var modelData
                        required property int index
                        Layout.preferredWidth: 58 * root.sx
                        Layout.preferredHeight: 64 * root.sy
                        radius: 9 * root.sx
                        color: Number(modelData) >= 0
                               ? Style.Theme.info_fondo : Style.Theme.formula_fondo
                        border.color: Number(modelData) >= 0
                                      ? Style.Theme.inferencia_estructura
                                      : Style.Theme.inferencia_transformacion
                        opacity: root.progress >= 0.45 + Math.min(index, 7) * 0.04 ? 1 : 0.15
                        Column {
                            anchors.centerIn: parent
                            spacing: 4 * root.sy
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "d" + vectorCell.index; color: Style.Theme.texto_secundario; font.bold: true }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.formatMetric(vectorCell.modelData); color: Style.Theme.texto_primario; font.family: Style.Theme.fuente_mono; font.pixelSize: Math.max(9, 10 * root.sx) }
                        }
                    }
                }
            }
            Text {
                visible: root.vectorValues.length === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: "Ejecuta el experimento para ver una muestra del vector."
                color: Style.Theme.texto_secundario
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Component {
        id: candidatesComponent
        ColumnLayout {
            spacing: 7 * root.sy
            Text {
                Layout.fillWidth: true
                text: root.definition.kind === "logits"
                      ? "Solo los cinco logits principales"
                      : "Solo los cinco candidatos principales"
                color: Style.Theme.inferencia_foco
                font.bold: true
                font.pixelSize: Math.max(12, 13 * root.sx)
            }
            Repeater {
                model: root.visibleCandidates
                delegate: RowLayout {
                    id: candidateRow
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42 * root.sy
                    spacing: 9 * root.sx
                    opacity: root.progress >= 0.42 + index * 0.06 ? 1 : 0.12
                    Text {
                        Layout.preferredWidth: 110 * root.sx
                        text: root.tokenText(candidateRow.modelData)
                        color: Style.Theme.texto_primario
                        font.family: Style.Theme.fuente_mono
                        font.bold: Boolean(candidateRow.modelData.chosen
                                           || candidateRow.modelData.elegido)
                        elide: Text.ElideRight
                        font.pixelSize: Math.max(10, 11 * root.sx)
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 14 * root.sy
                        radius: height / 2
                        color: Style.Theme.borde_suave
                        Rectangle {
                            width: parent.width * Math.max(0.04, Math.min(1,
                                   Math.abs(root.candidateValue(candidateRow.modelData))
                                   / root.maximumCandidateValue))
                            height: parent.height
                            radius: height / 2
                            color: Boolean(candidateRow.modelData.chosen
                                           || candidateRow.modelData.elegido)
                                   ? Style.Theme.inferencia_resultado
                                   : Style.Theme.inferencia_foco
                        }
                    }
                    Text {
                        Layout.preferredWidth: 92 * root.sx
                        text: root.candidateLabel(candidateRow.modelData)
                        color: Style.Theme.texto_secundario_fuerte
                        horizontalAlignment: Text.AlignRight
                        font.bold: true
                        font.pixelSize: Math.max(9, 10 * root.sx)
                    }
                }
            }
            Text {
                visible: root.visibleCandidates.length === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: "Ejecuta el experimento para mostrar los candidatos reales."
                color: Style.Theme.texto_secundario
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Component {
        id: selectedComponent
        ColumnLayout {
            spacing: 15 * root.sy
            Item { Layout.fillHeight: true }
            Text {
                Layout.fillWidth: true
                text: root.definition.last
                color: Style.Theme.texto_secundario_fuerte
                horizontalAlignment: Text.AlignHCenter
                font.bold: true
                font.pixelSize: Math.max(13, 15 * root.sx)
            }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.max(220 * root.sx, selectedLabel.implicitWidth + 70 * root.sx)
                Layout.preferredHeight: 92 * root.sy
                radius: 20 * root.sx
                color: Style.Theme.exito_fondo
                border.color: Style.Theme.inferencia_resultado
                border.width: 3
                scale: 0.82 + 0.18 * Math.max(0, (root.progress - 0.58) / 0.42)
                Text {
                    id: selectedLabel
                    anchors.centerIn: parent
                    text: "✓  " + root.selectedText()
                    color: Style.Theme.exito_texto
                    font.bold: true
                    font.pixelSize: Math.max(22, 26 * root.sx)
                }
            }
            Item { Layout.fillHeight: true }
        }
    }

    Component {
        id: trainingComponent
        RowLayout {
            spacing: 12 * root.sx
            MetricTile {
                Layout.fillWidth: true; Layout.fillHeight: true
                label: "PÉRDIDA"
                value: root.formatMetric(root.metricValue(["loss", "perdida", "perdida_batch"]))
                accent: Style.Theme.inferencia_foco
                emphasized: root.visualId.indexOf("loss") >= 0
                sx: root.sx; sy: root.sy
            }
            MetricTile {
                Layout.fillWidth: true; Layout.fillHeight: true
                label: "GRADIENTE"
                value: root.formatMetric(root.metricValue(["gradient_norm", "norma_gradiente", "norma_gradiente_global"]))
                accent: Style.Theme.inferencia_transformacion
                emphasized: root.visualId.indexOf("backward") >= 0
                            || root.visualId.indexOf("gradient") >= 0
                sx: root.sx; sy: root.sy
            }
            MetricTile {
                Layout.fillWidth: true; Layout.fillHeight: true
                label: "CAMBIO HIPOTÉTICO"
                value: root.formatMetric(root.metricValue(["update_norm", "norma_actualizacion", "delta_norm"]))
                accent: Style.Theme.inferencia_resultado
                emphasized: root.visualId.indexOf("update") >= 0
                sx: root.sx; sy: root.sy
            }
        }
    }

    component StageNode: Rectangle {
        id: node
        property string number: ""
        property string label: ""
        property color accent: Style.Theme.acento
        property bool emphasized: false
        property real sx: 1
        property real sy: 1
        radius: 14 * sx
        color: emphasized ? Qt.alpha(accent, 0.14) : Style.Theme.surface
        border.color: emphasized ? accent : Style.Theme.borde_suave
        border.width: emphasized ? 2 : 1
        opacity: emphasized ? 1 : 0.55
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 18 * node.sx
            spacing: 7 * node.sy
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 30 * node.sx
                Layout.preferredHeight: 30 * node.sy
                radius: height / 2
                color: node.accent
                Text { anchors.centerIn: parent; text: node.number; color: Style.Theme.texto_sobre_color; font.bold: true }
            }
            Text {
                Layout.fillWidth: true
                text: node.label
                color: node.emphasized ? node.accent : Style.Theme.texto_secundario_fuerte
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.pixelSize: Math.max(11, 13 * node.sx)
            }
        }
    }

    component MetricTile: Rectangle {
        id: metric
        property string label: ""
        property string value: "—"
        property color accent: Style.Theme.acento
        property bool emphasized: false
        property real sx: 1
        property real sy: 1
        radius: 13 * sx
        color: emphasized ? Qt.alpha(accent, 0.14) : Style.Theme.surface
        border.color: emphasized ? accent : Style.Theme.borde_suave
        border.width: emphasized ? 2 : 1
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 18 * metric.sx
            spacing: 8 * metric.sy
            Text { Layout.fillWidth: true; text: metric.label; color: metric.accent; font.bold: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.pixelSize: Math.max(10, 11 * metric.sx) }
            Text { Layout.fillWidth: true; text: metric.value; color: Style.Theme.texto_primario; font.bold: true; font.family: Style.Theme.fuente_mono; horizontalAlignment: Text.AlignHCenter; font.pixelSize: Math.max(18, 22 * metric.sx) }
        }
    }
}
