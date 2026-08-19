pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var sceneData: ({})
    property bool active: false
    property bool reducedMotion: false
    property string sublayerLabel: "Atención"
    property real sx: 1
    property real sy: 1
    property bool useShortcut: true
    property real particleProgress: 0
    property int selectedPhase: 0

    readonly property var layerNorm: sceneData.layernorm || ({})
    readonly property var phases: layerNorm.fases || []

    function valuesBounds() {
        var minimum = 1e30, maximum = -1e30
        for (var phase = 0; phase < phases.length; ++phase) {
            var values = phases[phase].valores || []
            for (var i = 0; i < values.length; ++i) {
                minimum = Math.min(minimum, Number(values[i]))
                maximum = Math.max(maximum, Number(values[i]))
            }
        }
        if (minimum > maximum)
            return { minimum: -1, maximum: 1 }
        if (Math.abs(maximum - minimum) < 1e-9)
            return { minimum: minimum - 1, maximum: maximum + 1 }
        var margin = (maximum - minimum) * 0.08
        return { minimum: minimum - margin, maximum: maximum + margin }
    }

    onParticleProgressChanged: residualCanvas.requestPaint()
    onUseShortcutChanged: residualCanvas.requestPaint()

    NumberAnimation {
        target: root
        property: "particleProgress"
        from: 0
        to: 1
        duration: 2100
        loops: Animation.Infinite
        running: root.active && !root.reducedMotion
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 9 * root.sy

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48 * root.sy
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1 * root.sy
                Text {
                    text: "Carril residual + LayerNorm post-norm"
                    color: "#0F172A"
                    font.bold: true
                    font.pixelSize: 17 * Math.min(root.sx, root.sy)
                }
                Text {
                    text: "La entrada x toma dos rutas y converge mediante una suma, no mediante concat."
                    color: "#64748B"
                    font.pixelSize: 10 * root.sx
                }
            }
            Rectangle {
                Layout.preferredWidth: 190 * root.sx
                Layout.preferredHeight: 32 * root.sy
                radius: 8 * root.sx
                color: root.useShortcut ? "#059669" : "#FFFFFF"
                border.color: "#059669"
                Text {
                    anchors.centerIn: parent
                    text: root.useShortcut ? "✓ Con atajo residual" : "Sin atajo · comparar"
                    color: root.useShortcut ? "white" : "#047857"
                    font.bold: true
                    font.pixelSize: 9 * root.sx
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.useShortcut = !root.useShortcut }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 205 * root.sy
            radius: 12 * root.sx
            color: "#F0FDF4"
            border.color: "#86EFAC"

            Canvas {
                id: residualCanvas
                anchors.fill: parent
                anchors.margins: 9 * root.sx
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    var startX = 68 * root.sx
                    var splitX = 190 * root.sx
                    var mergeX = width - 250 * root.sx
                    var normX = width - 112 * root.sx
                    var upperY = 55 * root.sy
                    var lowerY = 140 * root.sy
                    var middleY = 98 * root.sy

                    ctx.lineCap = "round"
                    ctx.lineWidth = 4 * root.sx
                    ctx.strokeStyle = "#059669"
                    ctx.beginPath(); ctx.moveTo(startX, middleY); ctx.lineTo(splitX, middleY); ctx.stroke()

                    ctx.globalAlpha = root.useShortcut ? 1 : 0.12
                    ctx.beginPath(); ctx.moveTo(splitX, middleY)
                    ctx.bezierCurveTo(splitX + 35 * root.sx, middleY,
                                      splitX + 45 * root.sx, upperY, splitX + 82 * root.sx, upperY)
                    ctx.lineTo(mergeX - 42 * root.sx, upperY)
                    ctx.bezierCurveTo(mergeX - 14 * root.sx, upperY,
                                      mergeX - 22 * root.sx, middleY, mergeX, middleY)
                    ctx.stroke()
                    ctx.globalAlpha = 1

                    ctx.strokeStyle = "#D97706"
                    ctx.beginPath(); ctx.moveTo(splitX, middleY)
                    ctx.bezierCurveTo(splitX + 35 * root.sx, middleY,
                                      splitX + 45 * root.sx, lowerY, splitX + 82 * root.sx, lowerY)
                    ctx.lineTo(mergeX - 42 * root.sx, lowerY)
                    ctx.bezierCurveTo(mergeX - 14 * root.sx, lowerY,
                                      mergeX - 22 * root.sx, middleY, mergeX, middleY)
                    ctx.stroke()

                    ctx.strokeStyle = "#4F46E5"
                    ctx.beginPath(); ctx.moveTo(mergeX + 18 * root.sx, middleY)
                    ctx.lineTo(normX - 62 * root.sx, middleY); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(normX + 46 * root.sx, middleY)
                    ctx.lineTo(width - 24 * root.sx, middleY); ctx.stroke()

                    function particle(x0, y0, x1, y1, progress, color, alpha) {
                        ctx.globalAlpha = alpha
                        ctx.beginPath(); ctx.arc(x0 + (x1 - x0) * progress,
                                                y0 + (y1 - y0) * progress,
                                                5 * root.sx, 0, Math.PI * 2)
                        ctx.fillStyle = color; ctx.fill()
                        ctx.strokeStyle = "#FFFFFF"; ctx.lineWidth = 1.5; ctx.stroke()
                        ctx.globalAlpha = 1
                    }
                    if (!root.reducedMotion) {
                        particle(splitX + 82 * root.sx, upperY, mergeX - 42 * root.sx, upperY,
                                 root.particleProgress, "#059669", root.useShortcut ? 1 : 0.12)
                        particle(splitX + 82 * root.sx, lowerY, mergeX - 42 * root.sx, lowerY,
                                 root.particleProgress, "#D97706", 1)
                    }

                    ctx.fillStyle = "#0F172A"
                    ctx.font = "bold " + Math.max(9, 10 * root.sx) + "px sans-serif"
                    ctx.textAlign = "center"
                    ctx.fillText("x", startX, middleY - 14 * root.sy)
                    ctx.fillStyle = root.useShortcut ? "#047857" : "#94A3B8"
                    ctx.fillText(root.useShortcut ? "RUTA IDENTIDAD · x intacto" : "RUTA IDENTIDAD APAGADA",
                                 (splitX + mergeX) / 2, upperY - 14 * root.sy)
                    ctx.fillStyle = "#B45309"
                    ctx.fillText("SUBCAPA " + root.sublayerLabel.toUpperCase() + " · Δx",
                                 (splitX + mergeX) / 2, lowerY + 24 * root.sy)

                    ctx.beginPath(); ctx.arc(mergeX + 9 * root.sx, middleY, 19 * root.sx, 0, Math.PI * 2)
                    ctx.fillStyle = root.useShortcut ? "#059669" : "#D97706"; ctx.fill()
                    ctx.fillStyle = "#FFFFFF"; ctx.font = "bold " + Math.max(15, 20 * root.sx) + "px sans-serif"
                    ctx.fillText(root.useShortcut ? "+" : "→", mergeX + 9 * root.sx, middleY + 7 * root.sy)

                    ctx.fillStyle = "#4F46E5"
                    ctx.fillRect(normX - 56 * root.sx, middleY - 27 * root.sy,
                                 112 * root.sx, 54 * root.sy)
                    ctx.fillStyle = "#FFFFFF"
                    ctx.font = "bold " + Math.max(9, 10 * root.sx) + "px sans-serif"
                    ctx.fillText("LayerNorm", normX, middleY - 2 * root.sy)
                    ctx.font = Math.max(8, 8 * root.sx) + "px sans-serif"
                    ctx.fillText("μ · σ · γ · β", normX, middleY + 14 * root.sy)
                    ctx.textAlign = "left"
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 10 * root.sx
                width: metricsText.implicitWidth + 18 * root.sx
                height: 31 * root.sy
                radius: 7 * root.sx
                color: "#FFFFFF"
                border.color: "#86EFAC"
                Text {
                    id: metricsText
                    anchors.centerIn: parent
                    text: "‖x‖ " + Number(root.sceneData.norma_entrada || 0).toFixed(3)
                          + "   ·   ‖Δx‖ " + Number(root.sceneData.norma_actualizacion || 0).toFixed(3)
                          + "   ·   ratio " + Number(root.sceneData.ratio_actualizacion || 0).toFixed(3)
                    color: "#166534"
                    font.bold: true
                    font.pixelSize: 8 * root.sx
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34 * root.sy
            Text { text: "LAYER NORM · CUATRO FASES REALES"; color: "#4F46E5"; font.bold: true; font.pixelSize: 9 * root.sx }
            Item { Layout.fillWidth: true }
            Text {
                text: "γ media " + Number(root.layerNorm.gamma_media || 0).toFixed(4)
                      + " · β media " + Number(root.layerNorm.beta_media || 0).toFixed(4)
                      + " · ε " + Number(root.sceneData.epsilon || 0)
                color: "#475569"
                font.pixelSize: 9 * root.sx
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8 * root.sx

            Repeater {
                model: root.phases
                delegate: Rectangle {
                    id: phaseCard
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 11 * root.sx
                    color: root.selectedPhase === index ? "#EEF2FF" : "#F8FAFC"
                    border.color: root.selectedPhase === index ? "#4F46E5" : "#CBD5E1"
                    border.width: root.selectedPhase === index ? 2 : 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8 * root.sx
                        spacing: 4 * root.sy
                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle {
                                Layout.preferredWidth: 23 * root.sx; Layout.preferredHeight: 23 * root.sy
                                radius: height / 2; color: "#4F46E5"
                                Text { anchors.centerIn: parent; text: phaseCard.index + 1; color: "white"; font.bold: true; font.pixelSize: 8 * root.sx }
                            }
                            Text { Layout.fillWidth: true; text: phaseCard.modelData.nombre; color: "#312E81"; font.bold: true; elide: Text.ElideRight; font.pixelSize: 9 * root.sx }
                        }

                        Canvas {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            property var values: phaseCard.modelData.valores || []
                            property var sharedBounds: root.valuesBounds()
                            onValuesChanged: requestPaint()
                            onSharedBoundsChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d"); ctx.reset()
                                ctx.strokeStyle = "#CBD5E1"; ctx.lineWidth = 1
                                ctx.beginPath(); ctx.moveTo(6 * root.sx, height / 2)
                                ctx.lineTo(width - 6 * root.sx, height / 2); ctx.stroke()
                                var zeroX = 6 * root.sx + (0 - sharedBounds.minimum)
                                            / (sharedBounds.maximum - sharedBounds.minimum)
                                            * (width - 12 * root.sx)
                                ctx.strokeStyle = "#94A3B8"; ctx.setLineDash([3, 3])
                                ctx.beginPath(); ctx.moveTo(zeroX, 4 * root.sy); ctx.lineTo(zeroX, height - 4 * root.sy); ctx.stroke()
                                ctx.setLineDash([])
                                for (var i = 0; i < values.length; ++i) {
                                    var x = 6 * root.sx + (Number(values[i]) - sharedBounds.minimum)
                                            / (sharedBounds.maximum - sharedBounds.minimum)
                                            * (width - 12 * root.sx)
                                    var jitter = ((i * 37) % 11 - 5) / 5 * Math.min(18 * root.sy, height * 0.28)
                                    ctx.beginPath(); ctx.arc(x, height / 2 + jitter, 2.7 * root.sx, 0, Math.PI * 2)
                                    ctx.fillStyle = Qt.alpha("#4F46E5", 0.62); ctx.fill()
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "μ " + Number(phaseCard.modelData.media || 0).toFixed(4)
                                  + "  ·  σ " + Number(phaseCard.modelData.desviacion || 0).toFixed(4)
                            color: "#475569"
                            horizontalAlignment: Text.AlignHCenter
                            font.bold: true
                            font.pixelSize: 8 * root.sx
                        }
                        Text {
                            Layout.fillWidth: true
                            text: phaseCard.modelData.operacion
                            color: "#64748B"
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            font.pixelSize: 7 * root.sx
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedPhase = phaseCard.index }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38 * root.sy
            radius: 9 * root.sx
            color: root.useShortcut ? "#ECFDF5" : "#FFF7ED"
            border.color: root.useShortcut ? "#6EE7B7" : "#FDBA74"
            Text {
                anchors.centerIn: parent
                text: root.useShortcut
                      ? "Con atajo, la información original x sigue disponible en x + Δx antes de normalizar."
                      : "Sin atajo, solo quedaría Δx: la ruta identidad y su información original desaparecen."
                color: root.useShortcut ? "#047857" : "#9A3412"
                font.bold: true
                font.pixelSize: 9 * root.sx
            }
        }
    }
}
