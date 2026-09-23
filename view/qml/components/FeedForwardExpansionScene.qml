pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

Item {
    id: root
    objectName: "feedForwardExpansionScene"

    property var sceneData: ({})
    property var tokens: []
    property bool active: false
    property bool reducedMotion: false
    property real sx: 1
    property real sy: 1
    property real progress: 0
    readonly property bool compact: width < 850

    readonly property var tokenRows: sceneData.tokens || []
    readonly property string activationName: String(sceneData.activacion || "GELU")
    readonly property int inputDimension: tokenRows.length
                                                  ? Number(tokenRows[0].dimension_entrada || 0) : 0
    readonly property int hiddenDimension: tokenRows.length
                                                   ? Number(tokenRows[0].dimension_oculta || 0) : 0
    readonly property int outputDimension: tokenRows.length
                                                    ? Number(tokenRows[0].dimension_salida || 0) : 0
    // Conserva la relación d_ff/d_model sin permitir que una configuración
    // muy ancha expulse el resto del recorrido fuera de la escena.
    readonly property real hiddenVisualRatio: inputDimension > 0
                                                   ? Math.max(1, Math.min(2,
                                                       hiddenDimension / inputDimension))
                                                   : 1
    readonly property int renderedTokenCount: tokenRepeater.count
    readonly property real compactContentWidth: (
        70 + 112 + 112 * (1 + (hiddenVisualRatio - 1) * progress)
        + 92 + 112 + 4 * 4 + 10) * sx

    function tokenColor(index) {
        var palette = Style.Theme.identidades_inferencia
        return palette[Math.max(0, Number(index || 0)) % palette.length]
    }

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
                    Layout.fillWidth: true
                    text: "Expansión → " + root.activationName + " → compresión"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    elide: Text.ElideRight
                    font.pixelSize: Math.max(18, 18 * Math.min(root.sx, root.sy))
                }
                Text {
                    Layout.fillWidth: true
                    text: root.inputDimension + " → " + root.hiddenDimension + " → "
                          + root.outputDimension + " · la misma FFN se aplica por separado a cada token"
                    color: Style.Theme.inferencia_transformacion
                    font.bold: true
                    elide: Text.ElideRight
                    font.pixelSize: Math.max(11, 11 * root.sx)
                }
            }
            Rectangle {
                Layout.preferredWidth: (root.compact ? 38 : 112) * root.sx
                Layout.preferredHeight: 32 * root.sy
                radius: 8 * root.sx
                color: Style.Theme.inferencia_transformacion
                Text { anchors.centerIn: parent; text: root.compact ? "↺" : "↺ Respirar"; color: Style.Theme.inferencia_sobre_transformacion; font.bold: true; font.pixelSize: 9 * root.sx }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.replay() }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 54 * root.sy
            radius: 10 * root.sx
            color: Style.Theme.chip_fondo
            border.color: Style.Theme.inferencia_transformacion
            RowLayout {
                anchors.fill: parent
                anchors.margins: 8 * root.sx
                spacing: 8 * root.sx
                StageLabel { Layout.fillWidth: true; Layout.minimumWidth: 0; title: "ENTRADA"; subtitle: "d_model = " + root.inputDimension; accent: Style.Theme.inferencia_estructura; sx: root.sx }
                Text { visible: !root.compact; text: "→"; color: Style.Theme.texto_terciario; font.bold: true; font.pixelSize: 18 * root.sx }
                StageLabel { Layout.fillWidth: true; Layout.minimumWidth: 0; title: "EXPANSIÓN W₁"; subtitle: "d_ff = " + root.hiddenDimension; accent: Style.Theme.inferencia_transformacion; sx: root.sx }
                StageLabel { Layout.fillWidth: true; Layout.minimumWidth: 0; title: root.activationName.toUpperCase(); subtitle: root.activationName.toLowerCase().indexOf("relu") >= 0 ? "negativos → 0" : "atenuación suave"; accent: Style.Theme.inferencia_foco; sx: root.sx }
                Text { visible: !root.compact; text: "→"; color: Style.Theme.texto_terciario; font.bold: true; font.pixelSize: 18 * root.sx }
                StageLabel { Layout.fillWidth: true; Layout.minimumWidth: 0; title: "PROYECCIÓN W₂"; subtitle: "d_model = " + root.outputDimension; accent: Style.Theme.inferencia_resultado; sx: root.sx }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12 * root.sx
            color: Style.Theme.superficie_alterna
            border.color: Style.Theme.borde_medio

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12 * root.sx
                spacing: 9 * root.sy

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28 * root.sy
                    radius: 7 * root.sx
                    color: Style.Theme.acento_fondo
                    Text {
                        anchors.centerIn: parent
                        text: "PESOS COMPARTIDOS · W₁, b₁, " + root.activationName + ", W₂, b₂"
                        color: Style.Theme.inferencia_transformacion
                        font.bold: true
                        font.pixelSize: 9 * root.sx
                    }
                }

                Repeater {
                    id: tokenRepeater
                    model: root.tokenRows
                    delegate: Rectangle {
                        id: tokenRow
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 100 * root.sy
                        radius: 10 * root.sx
                        color: Style.Theme.surface
                        border.color: root.tokenColor(tokenRow.index)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: (root.compact ? 5 : 9) * root.sx
                            spacing: (root.compact ? 4 : 8) * root.sx

                            Rectangle {
                                Layout.preferredWidth: (root.compact ? 70 : 92) * root.sx
                                Layout.fillHeight: true
                                radius: 8 * root.sx
                                color: Qt.alpha(root.tokenColor(tokenRow.index), 0.10)
                                Column {
                                    anchors.centerIn: parent
                                    width: parent.width - 10 * root.sx
                                    spacing: 3 * root.sy
                                    Text {
                                        width: parent.width
                                        text: "“" + (root.tokenFor(tokenRow.modelData.posicion, tokenRow.index).texto || "token") + "”"
                                        color: Style.Theme.texto_primario
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        font.pixelSize: 11 * root.sx
                                    }
                                    Text { width: parent.width; text: "posición " + tokenRow.modelData.posicion; color: Style.Theme.texto_secundario; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; font.pixelSize: Math.max(9, 9 * root.sx) }
                                }
                            }

                            VectorStrip {
                                Layout.preferredWidth: (root.compact ? 112 : 150) * root.sx
                                Layout.fillHeight: true
                                values: tokenRow.modelData.entrada || []
                                dimension: tokenRow.modelData.dimension_entrada
                                normValue: Number(tokenRow.modelData.norma_entrada || 0)
                                label: "x"
                                accent: Style.Theme.inferencia_estructura
                                sx: root.sx; sy: root.sy
                            }

                            Text { visible: !root.compact; text: "→"; color: Style.Theme.texto_terciario; font.bold: true; font.pixelSize: 18 * root.sx }

                            VectorStrip {
                                Layout.preferredWidth: (root.compact ? 112 : 150) * (1 + (root.hiddenVisualRatio - 1)
                                                                 * root.progress) * root.sx
                                Layout.fillHeight: true
                                values: tokenRow.modelData.preactivacion || []
                                dimension: tokenRow.modelData.dimension_oculta
                                normValue: Number(tokenRow.modelData.norma_preactivacion || 0)
                                label: "W₁x+b₁"
                                accent: Style.Theme.inferencia_transformacion
                                sx: root.sx; sy: root.sy
                                Behavior on Layout.preferredWidth { NumberAnimation { duration: root.reducedMotion ? 0 : 380; easing.type: Easing.OutCubic } }
                            }

                            ActivationGate {
                                Layout.preferredWidth: (root.compact ? 92 : 128) * root.sx
                                Layout.fillHeight: true
                                activation: root.activationName
                                negativeFraction: Number(tokenRow.modelData.fraccion_negativa || 0)
                                zeroFraction: Number(tokenRow.modelData.fraccion_casi_cero || 0)
                                sx: root.sx; sy: root.sy
                                opacity: 0.25 + 0.75 * root.progress
                            }

                            Text { visible: !root.compact; text: "→"; color: Style.Theme.texto_terciario; font.bold: true; font.pixelSize: 18 * root.sx }

                            VectorStrip {
                                Layout.preferredWidth: (root.compact ? 112 : 150) * root.sx
                                Layout.fillHeight: true
                                values: tokenRow.modelData.salida || []
                                dimension: tokenRow.modelData.dimension_salida
                                normValue: Number(tokenRow.modelData.norma_salida || 0)
                                label: "W₂φ+b₂"
                                accent: Style.Theme.inferencia_resultado
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
                    color: Style.Theme.texto_secundario
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.bold: true
                    font.pixelSize: 13 * root.sx
                }
            }
        }

    }

    component StageLabel: Column {
        id: stageLabel
        property string title: ""
        property string subtitle: ""
        property color accent: Style.Theme.inferencia_transformacion
        property real sx: 1
        spacing: 1 * sx
        Text { width: parent.width; text: stageLabel.title; color: stageLabel.accent; font.bold: true; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; font.pixelSize: 9 * stageLabel.sx }
        Text { width: parent.width; text: stageLabel.subtitle; color: Style.Theme.texto_secundario; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; font.pixelSize: Math.max(9, 9 * stageLabel.sx) }
    }

    component VectorStrip: Rectangle {
        id: vectorStrip
        property var values: []
        property int dimension: 0
        property real normValue: 0
        property string label: ""
        property color accent: Style.Theme.inferencia_estructura
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
                Text { Layout.fillWidth: true; text: vectorStrip.label; color: vectorStrip.accent; font.bold: true; font.pixelSize: Math.max(9, 9 * vectorStrip.sx) }
                Text { text: vectorStrip.dimension + "d"; color: Style.Theme.texto_secundario; font.pixelSize: Math.max(9, 8 * vectorStrip.sx) }
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
                                ? Qt.alpha(Style.Theme.escala_div_pos2,
                                           0.16 + 0.84 * Math.abs(value) / maximum)
                                : Qt.alpha(Style.Theme.escala_div_neg2,
                                           0.16 + 0.84 * Math.abs(value) / maximum)
                        ctx.fillRect(j * cellWidth, 0, Math.max(1, cellWidth + 0.3), height)
                    }
                }
            }
            Text { Layout.fillWidth: true; text: "‖·‖ " + vectorStrip.normValue.toFixed(3); color: Style.Theme.texto_secundario; horizontalAlignment: Text.AlignRight; font.pixelSize: Math.max(9, 8 * vectorStrip.sx) }
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
        color: Style.Theme.aviso_fondo
        border.color: Style.Theme.inferencia_foco
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 5 * gate.sx
            Text { Layout.fillWidth: true; text: gate.activation; color: Style.Theme.aviso_texto; font.bold: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: Math.max(9, 9 * gate.sx) }
            Canvas {
                Layout.fillWidth: true; Layout.fillHeight: true
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    var midX = width / 2, midY = height / 2
                    ctx.strokeStyle = Style.Theme.borde_suave; ctx.lineWidth = 1
                    ctx.beginPath(); ctx.moveTo(0, midY); ctx.lineTo(width, midY); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(midX, 0); ctx.lineTo(midX, height); ctx.stroke()
                    ctx.strokeStyle = Style.Theme.inferencia_foco; ctx.lineWidth = 2 * gate.sx; ctx.beginPath()
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
                color: Style.Theme.aviso_texto
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Math.max(9, 8 * gate.sx)
            }
        }
    }
}
