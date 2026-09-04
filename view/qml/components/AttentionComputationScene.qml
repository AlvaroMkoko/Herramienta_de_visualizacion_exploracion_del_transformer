pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Item {
    id: root
    objectName: "attentionComputationScene"

    property var attentionData: ({})
    property var causalMaskData: ({})
    property string phase: "qkv" // qkv, scores, mask, weighted
    property int branchIndex: 0 // 0 encoder, 1 decoder causal, 2 cross-attention
    property int headIndex: 0
    property int layerIndex: 0
    property bool active: false
    property bool reducedMotion: false
    property real sx: 1
    property real sy: 1

    property int revealStep: 0

    readonly property string normalizedPhase: {
        var phases = ["qkv", "scores", "mask", "weighted"]
        return phases.indexOf(phase) >= 0 ? phase : "qkv"
    }
    readonly property int capturedHeadCount: Math.max(
        matrixRows(attentionData ? attentionData.q : []),
        matrixRows(attentionData ? attentionData.scores : []),
        matrixRows(attentionData ? attentionData.atencion : []),
        matrixRows(attentionData ? attentionData.salida_cabezas : [])
    )
    readonly property int selectedHead: Math.max(
        0,
        Math.min(Math.max(0, capturedHeadCount - 1),
                 Number(headIndex || 0))
    )
    readonly property string branchLabel: {
        var labels = ["Encoder · autoatención", "Decoder · atención causal",
                      "Decoder · atención cruzada"]
        return labels[Math.max(0, Math.min(labels.length - 1,
                                           Number(branchIndex || 0)))]
    }
    readonly property string phaseTitle: {
        if (normalizedPhase === "qkv")
            return "Proyecciones Query, Key y Value"
        if (normalizedPhase === "scores")
            return "Compatibilidad QKᵀ escalada"
        if (normalizedPhase === "mask")
            return "Aplicación de la máscara"
        return "Softmax, atención ponderada y contexto"
    }
    readonly property string phaseFormula: {
        if (normalizedPhase === "qkv")
            return "Q = XWQ   ·   K = XKVWK   ·   V = XKVWV"
        if (normalizedPhase === "scores")
            return "S = QKᵀ / √d_head"
        if (normalizedPhase === "mask")
            return "S'ᵢⱼ = Sᵢⱼ si está permitido; −∞ si está bloqueado"
        return "A = softmax(S')   ·   Zᵢ = Σⱼ AᵢⱼVⱼ"
    }
    readonly property string phaseExplanation: {
        if (normalizedPhase === "qkv")
            return "Muestra exacta del forward: Q pertenece a la última consulta; K y V pertenecen a la key destacada por la atención media."
        if (normalizedPhase === "scores")
            return "Los scores son compatibilidades firmadas, todavía no probabilidades. Cada fila corresponde a una cabeza."
        if (normalizedPhase === "mask")
            return "La máscara se aplica antes de Softmax. Las celdas bloqueadas pasan a −∞ para recibir probabilidad cero."
        return "Softmax produce los pesos A. Las contribuciones muestran ‖AᵢⱼVⱼ‖ y la salida por cabeza es el contexto Z de la query actual."
    }
    readonly property var phaseCards: buildPhaseCards()
    readonly property int totalRevealSteps: phaseCards.length
    readonly property bool hasAnyData: {
        for (var index = 0; index < phaseCards.length; ++index) {
            if (matrixHasValues(phaseCards[index].matrix))
                return true
        }
        return false
    }

    function safeMatrix(value) {
        return value && value.length !== undefined ? value : []
    }

    function matrixRows(value) {
        var matrix = safeMatrix(value)
        return matrix.length
    }

    function matrixColumns(value) {
        var matrix = safeMatrix(value)
        return matrix.length > 0 && matrix[0] && matrix[0].length !== undefined
                ? matrix[0].length : 0
    }

    function matrixHasValues(value) {
        return matrixRows(value) > 0 && matrixColumns(value) > 0
    }

    function buildPhaseCards() {
        var data = attentionData || ({})
        var key = Number(data.key_destacada || 0)
        var keyOffset = Number(data.inicio_keys || 0)

        if (normalizedPhase === "qkv") {
            return [
                {
                    id: "q",
                    title: "Q · última query",
                    subtitle: "Cabezas × componentes de la consulta actual",
                    matrix: safeMatrix(data.q),
                    mode: "diverging",
                    local: true,
                    valueLabel: "Q",
                    columnOffset: 0,
                    accent: "#2563EB"
                },
                {
                    id: "k",
                    title: "K · key destacada " + key,
                    subtitle: "Misma posición fuente en todas las cabezas",
                    matrix: safeMatrix(data.k),
                    mode: "diverging",
                    local: true,
                    valueLabel: "K",
                    columnOffset: 0,
                    accent: "#D97706"
                },
                {
                    id: "v",
                    title: "V · key destacada " + key,
                    subtitle: "Información transportada por esa misma key",
                    matrix: safeMatrix(data.v),
                    mode: "diverging",
                    local: true,
                    valueLabel: "V",
                    columnOffset: 0,
                    accent: "#7C3AED"
                }
            ]
        }

        if (normalizedPhase === "scores") {
            return [
                {
                    id: "scores",
                    title: "Scores crudos · query actual",
                    subtitle: "QKᵀ/√d_head antes de aplicar la máscara",
                    matrix: safeMatrix(data.scores),
                    mode: "diverging",
                    local: true,
                    valueLabel: "score",
                    columnOffset: keyOffset,
                    accent: "#0284C7"
                }
            ]
        }

        if (normalizedPhase === "mask") {
            return [
                {
                    id: "raw_scores",
                    title: "Scores antes de la máscara",
                    subtitle: "Compatibilidad original de la query actual",
                    matrix: safeMatrix(data.scores),
                    mode: "diverging",
                    local: true,
                    valueLabel: "score S",
                    columnOffset: keyOffset,
                    accent: "#0284C7"
                },
                {
                    id: "mask",
                    title: branchIndex === 1 ? "Máscara causal triangular" : "Máscara aplicada",
                    subtitle: "1 = permitido · 0 = bloqueado",
                    matrix: branchIndex === 1 && causalMaskData
                            && causalMaskData.valores
                            ? safeMatrix(causalMaskData.valores)
                            : safeMatrix(data.mascara),
                    mode: "mask",
                    local: false,
                    valueLabel: "permitido",
                    columnOffset: branchIndex === 1 ? 0 : keyOffset,
                    accent: "#DC2626"
                },
                {
                    id: "masked_scores",
                    title: "Scores enmascarados",
                    subtitle: "Las posiciones bloqueadas aparecen como −∞",
                    matrix: safeMatrix(data.scores_enmascarados),
                    mode: "diverging",
                    local: true,
                    valueLabel: "score S'",
                    columnOffset: keyOffset,
                    accent: "#B45309"
                }
            ]
        }

        return [
            {
                id: "attention",
                title: "Pesos A · Softmax",
                subtitle: "Distribución 0–1 de la query actual",
                matrix: safeMatrix(data.atencion),
                mode: "sequential",
                local: false,
                valueLabel: "Aᵢⱼ",
                columnOffset: keyOffset,
                accent: "#059669"
            },
            {
                id: "contributions",
                title: "Contribuciones ponderadas",
                subtitle: "Norma exacta ‖AᵢⱼVⱼ‖ por key",
                matrix: safeMatrix(data.contribuciones),
                mode: "sequential",
                local: true,
                valueLabel: "‖AᵢⱼVⱼ‖",
                columnOffset: keyOffset,
                accent: "#DB2777"
            },
            {
                id: "head_output",
                title: "Contexto Z por cabeza",
                subtitle: "Salida ponderada de la última query",
                matrix: safeMatrix(data.salida_cabezas),
                mode: "diverging",
                local: true,
                valueLabel: "Z",
                columnOffset: 0,
                accent: "#4F46E5"
            }
        ]
    }

    function replay() {
        revealTimer.stop()
        if (totalRevealSteps <= 0) {
            revealStep = 0
            return
        }
        if (reducedMotion) {
            revealStep = totalRevealSteps
            return
        }
        revealStep = 1
        if (totalRevealSteps > 1)
            revealTimer.start()
    }

    function settle() {
        revealTimer.stop()
        revealStep = totalRevealSteps
    }

    onActiveChanged: active ? replay() : settle()
    onPhaseChanged: active ? replay() : settle()
    onAttentionDataChanged: active ? replay() : settle()
    onReducedMotionChanged: reducedMotion ? settle() : (active ? replay() : settle())
    Component.onCompleted: active ? replay() : settle()

    Timer {
        id: revealTimer
        interval: 430
        repeat: true
        onTriggered: {
            root.revealStep += 1
            if (root.revealStep >= root.totalRevealSteps)
                stop()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 9 * root.sy

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 52 * root.sy
            spacing: 10 * root.sx

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1 * root.sy

                Text {
                    Layout.fillWidth: true
                    text: root.phaseTitle
                    color: "#0F172A"
                    font.bold: true
                    font.pixelSize: 17 * Math.min(root.sx, root.sy)
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: root.phaseFormula
                    color: "#475569"
                    font.family: "monospace"
                    font.pixelSize: 9 * root.sx
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                Layout.preferredWidth: branchText.implicitWidth + 24 * root.sx
                Layout.preferredHeight: 30 * root.sy
                radius: 8 * root.sx
                color: "#EFF6FF"
                border.color: "#93C5FD"

                Text {
                    id: branchText
                    anchors.centerIn: parent
                    text: root.branchLabel + " · capa " + (Number(root.layerIndex || 0) + 1)
                          + " · H" + String(root.selectedHead + 1).padStart(2, "0")
                    color: "#1D4ED8"
                    font.bold: true
                    font.pixelSize: 9 * root.sx
                }
            }

            Rectangle {
                Layout.preferredWidth: 112 * root.sx
                Layout.preferredHeight: 31 * root.sy
                radius: 8 * root.sx
                color: "#FFFFFF"
                border.color: "#0284C7"
                Accessible.role: Accessible.Button
                Accessible.name: "Reproducir cálculo de atención"

                Text {
                    anchors.centerIn: parent
                    text: "↺ Reproducir"
                    color: "#0369A1"
                    font.bold: true
                    font.pixelSize: 9 * root.sx
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.replay()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42 * root.sy
            radius: 9 * root.sx
            color: "#F8FAFC"
            border.color: "#CBD5E1"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12 * root.sx
                anchors.rightMargin: 12 * root.sx
                spacing: 9 * root.sx

                Rectangle {
                    Layout.preferredWidth: truthText.implicitWidth + 18 * root.sx
                    Layout.preferredHeight: 24 * root.sy
                    radius: height / 2
                    color: root.hasAnyData ? "#DCFCE7" : "#FEF3C7"
                    border.color: root.hasAnyData ? "#86EFAC" : "#FCD34D"
                    Text {
                        id: truthText
                        anchors.centerIn: parent
                        text: root.hasAnyData ? "● Captura real" : "Sin captura"
                        color: root.hasAnyData ? "#166534" : "#92400E"
                        font.bold: true
                        font.pixelSize: 8 * root.sx
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.phaseExplanation
                    color: "#334155"
                    font.pixelSize: 9 * root.sx
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.phaseCards.length >= 3 ? 3 : root.phaseCards.length
            columnSpacing: 8 * root.sx
            rowSpacing: 8 * root.sy

            Repeater {
                model: root.phaseCards

                delegate: Rectangle {
                    id: matrixCard
                    required property var modelData
                    required property int index

                    readonly property bool revealed: root.reducedMotion
                                                     || root.revealStep >= index + 1
                    readonly property bool hasValues: root.matrixHasValues(modelData.matrix)

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 220 * root.sx
                    Layout.minimumHeight: 210 * root.sy
                    radius: 11 * root.sx
                    color: "#FFFFFF"
                    border.color: revealed ? modelData.accent : "#CBD5E1"
                    border.width: revealed ? 1.5 : 1
                    opacity: revealed ? 1 : 0.16
                    scale: revealed ? 1 : 0.985

                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.reducedMotion ? 0 : 180
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: root.reducedMotion ? 0 : 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 9 * root.sx
                        spacing: 4 * root.sy

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36 * root.sy
                            spacing: 6 * root.sx

                            Rectangle {
                                Layout.preferredWidth: 22 * root.sx
                                Layout.preferredHeight: 22 * root.sy
                                radius: height / 2
                                color: matrixCard.modelData.accent
                                Text {
                                    anchors.centerIn: parent
                                    text: matrixCard.index + 1
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: 8 * root.sx
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    text: matrixCard.modelData.title
                                    color: "#0F172A"
                                    font.bold: true
                                    font.pixelSize: 10 * root.sx
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: matrixCard.modelData.subtitle
                                    color: "#64748B"
                                    font.pixelSize: 7 * root.sx
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ScientificMatrix {
                                anchors.fill: parent
                                visible: matrixCard.hasValues
                                matrix: matrixCard.modelData.matrix
                                colorMode: matrixCard.modelData.mode
                                localScale: matrixCard.modelData.local
                                globalMinimum: matrixCard.modelData.mode === "sequential" ? 0 : -1
                                globalMaximum: 1
                                rowPrefix: "H"
                                columnOffset: Number(matrixCard.modelData.columnOffset || 0)
                                valueLabel: matrixCard.modelData.valueLabel
                                layerNumber: Number(root.layerIndex || 0) + 1
                                queryLabel: "última query"
                                selectedRow: root.selectedHead
                                rawScores: root.safeMatrix(root.attentionData ? root.attentionData.scores : [])
                                maskMatrix: root.safeMatrix(root.attentionData ? root.attentionData.mascara : [])
                                attentionMatrix: root.safeMatrix(root.attentionData ? root.attentionData.atencion : [])
                                contributionMatrix: root.safeMatrix(root.attentionData ? root.attentionData.contribuciones : [])
                                reducedMotion: root.reducedMotion
                                alternativeText: matrixCard.modelData.title
                                                 + ", muestra numérica exacta por cabeza"
                            }

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 24 * root.sx
                                spacing: 6 * root.sy
                                visible: !matrixCard.hasValues

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "∅"
                                    color: "#94A3B8"
                                    font.pixelSize: 30 * Math.min(root.sx, root.sy)
                                }
                                Text {
                                    width: parent.width
                                    text: "No hay datos para esta operación en la captura seleccionada."
                                    color: "#64748B"
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    font.pixelSize: 9 * root.sx
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: matrixCard.hasValues
                                  ? root.matrixRows(matrixCard.modelData.matrix) + " cabezas × "
                                    + root.matrixColumns(matrixCard.modelData.matrix) + " valores mostrados"
                                  : "Sin matriz disponible"
                            color: "#64748B"
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 8 * root.sx
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34 * root.sy
            spacing: 8 * root.sx

            Row {
                spacing: 5 * root.sx
                Repeater {
                    model: root.totalRevealSteps
                    delegate: Rectangle {
                        required property int index
                        width: 9 * root.sx
                        height: 9 * root.sy
                        radius: Math.min(width, height) / 2
                        color: root.revealStep >= index + 1 ? "#0284C7" : "#CBD5E1"
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: {
                    var data = root.attentionData || ({})
                    var detail = String(data.level_of_detail || "muestra exacta capturada")
                    var shape = String(data.original_shape || "forma no disponible")
                    return detail + " · original " + shape
                }
                color: "#64748B"
                elide: Text.ElideRight
                font.pixelSize: 8 * root.sx
            }
            Text {
                text: root.hasAnyData ? "Sin valores sintéticos" : "Esperando forward"
                color: root.hasAnyData ? "#047857" : "#92400E"
                font.bold: true
                font.pixelSize: 8 * root.sx
            }
        }
    }
}
