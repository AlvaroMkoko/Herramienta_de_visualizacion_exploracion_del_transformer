pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var sceneData: ({})
    property var tokens: []
    property bool active: false
    property bool reducedMotion: false
    property real sx: 1
    property real sy: 1
    property real progress: 0

    readonly property var tokenRows: sceneData.tokens || []
    readonly property string activationName: String(sceneData.activacion || "GELU")
    readonly property int inputDimension: tokenRows.length
                                                  ? Number(tokenRows[0].dimension_entrada || 0) : 0
    readonly property int hiddenDimension: tokenRows.length
                                                   ? Number(tokenRows[0].dimension_oculta || 0) : 0
    readonly property int outputDimension: tokenRows.length
                                                   ? Number(tokenRows[0].dimension_salida || 0) : 0

    function tokenFor(position, fallbackIndex) {
        for (var i = 0; i < tokens.length; ++i) {
            if (Number(tokens[i].posicion) === Number(position))
                return tokens[i]
        }
        return fallbackIndex < tokens.length ? tokens[fallbackIndex]
                                             : ({ texto: "T" + (Number(position) + 1) })
    }

    function replay() {
        breath.stop()
        progress = 0
        if (reducedMotion)
            progress = 1
        else
            breath.start()
    }

    onActiveChanged: {
        if (active)
            replay()
        else
            breath.stop()
    }

    NumberAnimation {
        id: breath
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 2600
        easing.type: Easing.OutCubic
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 9 * root.sy

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 49 * root.sy
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1 * root.sy
                Text {
                    text: "Expansión → " + root.activationName + " → compresión"
                    color: "#0F172A"
                    font.bold: true
                    font.pixelSize: 17 * Math.min(root.sx, root.sy)
                }
                Text {
                    text: root.inputDimension + " → " + root.hiddenDimension + " → "
                          + root.outputDimension + " · la misma FFN se aplica por separado a cada token"
                    color: "#DB2777"
                    font.bold: true
                    font.pixelSize: 10 * root.sx
                }
            }
            Rectangle {
                Layout.preferredWidth: 112 * root.sx
                Layout.preferredHeight: 32 * root.sy
                radius: 8 * root.sx
                color: "#DB2777"
                Text { anchors.centerIn: parent; text: "↺ Respirar"; color: "white"; font.bold: true; font.pixelSize: 9 * root.sx }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.replay() }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 54 * root.sy
            radius: 10 * root.sx
            color: "#FDF2F8"
            border.color: "#F9A8D4"
            RowLayout {
                anchors.fill: parent
                anchors.margins: 8 * root.sx
                spacing: 8 * root.sx
                StageLabel { Layout.preferredWidth: 154 * root.sx; title: "ENTRADA"; subtitle: "d_model = " + root.inputDimension; accent: "#0284C7"; sx: root.sx }
                Text { text: "→"; color: "#94A3B8"; font.bold: true; font.pixelSize: 18 * root.sx }
                StageLabel { Layout.fillWidth: true; title: "EXPANSIÓN W₁"; subtitle: "d_ff = " + root.hiddenDimension; accent: "#DB2777"; sx: root.sx }
                StageLabel { Layout.preferredWidth: 150 * root.sx; title: root.activationName.toUpperCase(); subtitle: root.activationName.toLowerCase().indexOf("relu") >= 0 ? "negativos → 0" : "atenuación suave"; accent: "#D97706"; sx: root.sx }
                Text { text: "→"; color: "#94A3B8"; font.bold: true; font.pixelSize: 18 * root.sx }
                StageLabel { Layout.preferredWidth: 154 * root.sx; title: "PROYECCIÓN W₂"; subtitle: "d_model = " + root.outputDimension; accent: "#059669"; sx: root.sx }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12 * root.sx
            color: "#FAFAFC"
            border.color: "#E2E8F0"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12 * root.sx
                spacing: 9 * root.sy

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28 * root.sy
                    radius: 7 * root.sx
                    color: "#FCE7F3"
                    Text {
                        anchors.centerIn: parent
                        text: "PESOS COMPARTIDOS · W₁, b₁, " + root.activationName + ", W₂, b₂"
                        color: "#9D174D"
                        font.bold: true
                        font.pixelSize: 9 * root.sx
                    }
                }

                Repeater {
                    model: root.tokenRows
                    delegate: Rectangle {
                        id: tokenRow
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 100 * root.sy
                        radius: 10 * root.sx
                        color: "#FFFFFF"
                        border.color: ["#7DD3FC", "#F9A8D4", "#86EFAC"][tokenRow.index % 3]

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 9 * root.sx
                            spacing: 8 * root.sx

                            Rectangle {
                                Layout.preferredWidth: 92 * root.sx
                                Layout.fillHeight: true
                                radius: 8 * root.sx
                                color: ["#E0F2FE", "#FCE7F3", "#DCFCE7"][tokenRow.index % 3]
                                Column {
                                    anchors.centerIn: parent
                                    width: parent.width - 10 * root.sx
                                    spacing: 3 * root.sy
                                    Text {
                                        width: parent.width
                                        text: "“" + (root.tokenFor(tokenRow.modelData.posicion, tokenRow.index).texto || "token") + "”"
                                        color: "#0F172A"
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        font.pixelSize: 11 * root.sx
                                    }
                                    Text { width: parent.width; text: "posición " + tokenRow.modelData.posicion; color: "#64748B"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 8 * root.sx }
                                }
                            }

                            VectorStrip {
                                Layout.preferredWidth: 150 * root.sx
                                Layout.fillHeight: true
                                values: tokenRow.modelData.entrada || []
                                dimension: tokenRow.modelData.dimension_entrada
                                normValue: Number(tokenRow.modelData.norma_entrada || 0)
                                label: "x"
                                accent: "#0284C7"
                                sx: root.sx; sy: root.sy
                            }

                            Text { text: "→"; color: "#94A3B8"; font.bold: true; font.pixelSize: 18 * root.sx }

                            VectorStrip {
                                Layout.preferredWidth: (150 + 150 * root.progress) * root.sx
                                Layout.fillHeight: true
                                values: tokenRow.modelData.preactivacion || []
                                dimension: tokenRow.modelData.dimension_oculta
                                normValue: Number(tokenRow.modelData.norma_preactivacion || 0)
                                label: "W₁x+b₁"
                                accent: "#DB2777"
                                sx: root.sx; sy: root.sy
                                Behavior on Layout.preferredWidth { NumberAnimation { duration: root.reducedMotion ? 0 : 380; easing.type: Easing.OutCubic } }
                            }

                            ActivationGate {
                                Layout.preferredWidth: 128 * root.sx
                                Layout.fillHeight: true
                                activation: root.activationName
                                negativeFraction: Number(tokenRow.modelData.fraccion_negativa || 0)
                                zeroFraction: Number(tokenRow.modelData.fraccion_casi_cero || 0)
                                sx: root.sx; sy: root.sy
                                opacity: 0.25 + 0.75 * root.progress
                            }

                            Text { text: "→"; color: "#94A3B8"; font.bold: true; font.pixelSize: 18 * root.sx }

                            VectorStrip {
                                Layout.preferredWidth: 150 * root.sx
                                Layout.fillHeight: true
                                values: tokenRow.modelData.salida || []
                                dimension: tokenRow.modelData.dimension_salida
                                normValue: Number(tokenRow.modelData.norma_salida || 0)
                                label: "W₂φ+b₂"
                                accent: "#059669"
                                sx: root.sx; sy: root.sy
                                opacity: 0.18 + 0.82 * root.progress
                            }
                        }
                    }
                }

                Text {
                    visible: !root.tokenRows.length
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: "No hay activaciones FFN en esta captura."
                    color: "#64748B"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.bold: true
                    font.pixelSize: 13 * root.sx
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38 * root.sy
            radius: 9 * root.sx
            color: "#FFF7ED"
            border.color: "#FDBA74"
            Text {
                anchors.centerIn: parent
                text: root.activationName.toLowerCase().indexOf("relu") >= 0
                      ? "ReLU recorta exactamente a cero las preactivaciones negativas."
                      : "GELU atenúa de forma suave: una entrada negativa pequeña puede conservar una salida negativa pequeña."
                color: "#9A3412"
                font.pixelSize: 9 * root.sx
            }
        }
    }

    component StageLabel: Column {
        id: stageLabel
        property string title: ""
        property string subtitle: ""
        property color accent: "#DB2777"
        property real sx: 1
        spacing: 1 * sx
        Text { width: parent.width; text: stageLabel.title; color: stageLabel.accent; font.bold: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 9 * stageLabel.sx }
        Text { width: parent.width; text: stageLabel.subtitle; color: "#64748B"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 8 * stageLabel.sx }
    }

    component VectorStrip: Rectangle {
        id: vectorStrip
        property var values: []
        property int dimension: 0
        property real normValue: 0
        property string label: ""
        property color accent: "#0284C7"
        property real sx: 1
        property real sy: 1
        radius: 8 * sx
        color: Qt.alpha(accent, 0.07)
        border.color: accent
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 5 * vectorStrip.sx
            spacing: 3 * vectorStrip.sy
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: vectorStrip.label; color: vectorStrip.accent; font.bold: true; font.pixelSize: 8 * vectorStrip.sx }
                Text { text: vectorStrip.dimension + "d"; color: "#475569"; font.pixelSize: 7 * vectorStrip.sx }
            }
            Canvas {
                Layout.fillWidth: true
                Layout.fillHeight: true
                property var cellValues: vectorStrip.values
                onCellValuesChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    if (!cellValues.length)
                        return
                    var maximum = 1e-9
                    for (var i = 0; i < cellValues.length; ++i)
                        maximum = Math.max(maximum, Math.abs(Number(cellValues[i] || 0)))
                    var cellWidth = width / cellValues.length
                    for (var j = 0; j < cellValues.length; ++j) {
                        var value = Number(cellValues[j] || 0)
                        ctx.fillStyle = value >= 0
                                ? Qt.alpha("#F97316", 0.16 + 0.84 * Math.abs(value) / maximum)
                                : Qt.alpha("#0284C7", 0.16 + 0.84 * Math.abs(value) / maximum)
                        ctx.fillRect(j * cellWidth, 0, Math.max(1, cellWidth + 0.3), height)
                    }
                }
            }
            Text { Layout.fillWidth: true; text: "‖·‖ " + vectorStrip.normValue.toFixed(3); color: "#475569"; horizontalAlignment: Text.AlignRight; font.pixelSize: 7 * vectorStrip.sx }
        }
    }

    component ActivationGate: Rectangle {
        id: gate
        property string activation: "GELU"
        property real negativeFraction: 0
        property real zeroFraction: 0
        property real sx: 1
        property real sy: 1
        radius: 8 * sx
        color: "#FFFBEB"
        border.color: "#D97706"
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 5 * gate.sx
            Text { Layout.fillWidth: true; text: gate.activation; color: "#B45309"; font.bold: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 8 * gate.sx }
            Canvas {
                Layout.fillWidth: true; Layout.fillHeight: true
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    var midX = width / 2, midY = height / 2
                    ctx.strokeStyle = "#CBD5E1"; ctx.lineWidth = 1
                    ctx.beginPath(); ctx.moveTo(0, midY); ctx.lineTo(width, midY); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(midX, 0); ctx.lineTo(midX, height); ctx.stroke()
                    ctx.strokeStyle = "#D97706"; ctx.lineWidth = 2 * gate.sx; ctx.beginPath()
                    for (var i = 0; i <= 48; ++i) {
                        var x = -3 + i / 48 * 6
                        var y
                        if (gate.activation.toLowerCase().indexOf("relu") >= 0)
                            y = Math.max(0, x)
                        else
                            y = 0.5 * x * (1 + Math.tanh(0.79788456 * (x + 0.044715 * x * x * x)))
                        var px = i / 48 * width
                        var py = midY - y / 3 * (height * 0.45)
                        if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py)
                    }
                    ctx.stroke()
                }
            }
            Text {
                Layout.fillWidth: true
                text: gate.activation.toLowerCase().indexOf("relu") >= 0
                      ? (gate.zeroFraction * 100).toFixed(1) + "% → 0"
                      : (gate.negativeFraction * 100).toFixed(1) + "% preactivación < 0"
                color: "#92400E"
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 7 * gate.sx
            }
        }
    }
}
