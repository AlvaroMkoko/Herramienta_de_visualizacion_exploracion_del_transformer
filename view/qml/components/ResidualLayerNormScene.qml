pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../styles" as Style

Item {
    id: root
    objectName: "residualLayerNormScene"

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
    readonly property var selectedPhaseGuide: phaseGuide(selectedPhase)
    readonly property string phasePedagogicalExplanation: selectedPhaseGuide.explanation

    function phaseGuide(index) {
        if (index === 0) {
            return {
                title: "1 · Sumar x + Δx",
                formula: "u = x + Δx",
                explanation: "Une la señal original x con la actualización Δx coordenada a coordenada. Esta tarjeta todavía no normaliza: muestra el vector que LayerNorm recibirá."
            }
        }
        if (index === 1) {
            return {
                title: "2 · Centrar restando μ",
                formula: "c = u − μ",
                explanation: "μ es la media de las coordenadas de u. Restarla desplaza toda la nube para que quede centrada alrededor de cero sin cambiar su dispersión."
            }
        }
        if (index === 2) {
            return {
                title: "3 · Estandarizar con σ y ε",
                formula: "x̂ = c / √(var(u) + ε)",
                explanation: "La división lleva la dispersión cerca de uno. σ resume esa dispersión y ε es una constante pequeña que evita una división por cero."
            }
        }
        return {
            title: "4 · Aplicar γ y β",
            formula: "y = γ · x̂ + β",
            explanation: "γ vuelve a escalar y β desplaza cada coordenada. Ambos parámetros se aprenden, así que el modelo conserva la capacidad de elegir la escala y el centro útiles."
        }
    }

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
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: Math.max(18, 18 * Math.min(root.sx, root.sy))
                }
                Text {
                    text: "La entrada x toma dos rutas y converge mediante una suma, no mediante concat."
                    color: Style.Theme.texto_secundario
                    font.pixelSize: Math.max(11, 11 * root.sx)
                }
            }
            Rectangle {
                Layout.preferredWidth: 190 * root.sx
                Layout.preferredHeight: 32 * root.sy
                radius: 8 * root.sx
                color: root.useShortcut ? Style.Theme.inferencia_resultado : Style.Theme.surface
                border.color: Style.Theme.inferencia_resultado
                Text {
                    anchors.centerIn: parent
                    text: root.useShortcut ? "✓ Con atajo residual" : "Sin atajo · comparar"
                    color: root.useShortcut
                           ? Style.Theme.inferencia_sobre_resultado
                           : Style.Theme.exito_texto
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
            color: Style.Theme.surface
            border.color: Style.Theme.inferencia_resultado

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
                    ctx.strokeStyle = Style.Theme.inferencia_estructura
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

                    ctx.strokeStyle = Style.Theme.inferencia_transformacion
                    ctx.beginPath(); ctx.moveTo(splitX, middleY)
                    ctx.bezierCurveTo(splitX + 35 * root.sx, middleY,
                                      splitX + 45 * root.sx, lowerY, splitX + 82 * root.sx, lowerY)
                    ctx.lineTo(mergeX - 42 * root.sx, lowerY)
                    ctx.bezierCurveTo(mergeX - 14 * root.sx, lowerY,
                                      mergeX - 22 * root.sx, middleY, mergeX, middleY)
                    ctx.stroke()

                    ctx.strokeStyle = Style.Theme.inferencia_foco
                    ctx.beginPath(); ctx.moveTo(mergeX + 18 * root.sx, middleY)
                    ctx.lineTo(normX - 62 * root.sx, middleY); ctx.stroke()
                    ctx.strokeStyle = Style.Theme.inferencia_resultado
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
                                 root.particleProgress, Style.Theme.inferencia_estructura,
                                 root.useShortcut ? 1 : 0.12)
                        particle(splitX + 82 * root.sx, lowerY, mergeX - 42 * root.sx, lowerY,
                                 root.particleProgress, Style.Theme.inferencia_transformacion, 1)
                    }

                    ctx.fillStyle = Style.Theme.texto_primario
                    ctx.font = "bold " + Math.max(9, 10 * root.sx) + "px sans-serif"
                    ctx.textAlign = "center"
                    ctx.fillText("x", startX, middleY - 14 * root.sy)
                    ctx.fillStyle = root.useShortcut
                                    ? Style.Theme.inferencia_estructura
                                    : Style.Theme.texto_terciario
                    ctx.fillText(root.useShortcut ? "RUTA IDENTIDAD · x intacto" : "RUTA IDENTIDAD APAGADA",
                                 (splitX + mergeX) / 2, upperY - 14 * root.sy)
                    ctx.fillStyle = Style.Theme.inferencia_transformacion
                    ctx.fillText("SUBCAPA " + root.sublayerLabel.toUpperCase() + " · Δx",
                                 (splitX + mergeX) / 2, lowerY + 24 * root.sy)

                    ctx.beginPath(); ctx.arc(mergeX + 9 * root.sx, middleY, 19 * root.sx, 0, Math.PI * 2)
                    ctx.fillStyle = Style.Theme.inferencia_foco; ctx.fill()
                    ctx.fillStyle = Style.Theme.inferencia_sobre_foco
                    ctx.font = "bold " + Math.max(15, 20 * root.sx) + "px sans-serif"
                    ctx.fillText(root.useShortcut ? "+" : "→", mergeX + 9 * root.sx, middleY + 7 * root.sy)

                    ctx.fillStyle = Style.Theme.inferencia_transformacion
                    ctx.fillRect(normX - 56 * root.sx, middleY - 27 * root.sy,
                                 112 * root.sx, 54 * root.sy)
                    ctx.fillStyle = Style.Theme.inferencia_sobre_transformacion
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
                color: Style.Theme.surface
                border.color: Style.Theme.inferencia_resultado
                Text {
                    id: metricsText
                    anchors.centerIn: parent
                    text: "‖x‖ " + Number(root.sceneData.norma_entrada || 0).toFixed(3)
                          + "   ·   ‖Δx‖ " + Number(root.sceneData.norma_actualizacion || 0).toFixed(3)
                          + "   ·   ratio " + Number(root.sceneData.ratio_actualizacion || 0).toFixed(3)
                    color: Style.Theme.exito_texto
                    font.bold: true
                    font.pixelSize: Math.max(9, 9 * root.sx)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34 * root.sy
            Text { text: "LAYER NORM · CUATRO FASES REALES"; color: Style.Theme.inferencia_transformacion; font.bold: true; font.pixelSize: 9 * root.sx }
            Item { Layout.fillWidth: true }
            Text {
                text: "γ media " + Number(root.layerNorm.gamma_media || 0).toFixed(4)
                      + " · β media " + Number(root.layerNorm.beta_media || 0).toFixed(4)
                      + " · ε " + Number(root.sceneData.epsilon || 0)
                color: Style.Theme.texto_secundario
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
                    color: root.selectedPhase === index ? Style.Theme.aviso_fondo : Style.Theme.superficie_alterna
                    border.color: root.selectedPhase === index
                                  ? Style.Theme.inferencia_foco : Style.Theme.borde_suave
                    border.width: root.selectedPhase === index ? 2 : 1
                    Accessible.role: Accessible.Button
                    Accessible.name: root.phaseGuide(phaseCard.index).title
                    Accessible.description: root.phaseGuide(phaseCard.index).explanation

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8 * root.sx
                        spacing: 4 * root.sy
                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle {
                                Layout.preferredWidth: 23 * root.sx; Layout.preferredHeight: 23 * root.sy
                                radius: height / 2; color: root.selectedPhase === phaseCard.index
                                                               ? Style.Theme.inferencia_foco
                                                               : Style.Theme.inferencia_transformacion
                                Text { anchors.centerIn: parent; text: phaseCard.index + 1; color: root.selectedPhase === phaseCard.index ? Style.Theme.inferencia_sobre_foco : Style.Theme.inferencia_sobre_transformacion; font.bold: true; font.pixelSize: Math.max(9, 9 * root.sx) }
                            }
                            Text { Layout.fillWidth: true; text: phaseCard.modelData.nombre; color: root.selectedPhase === phaseCard.index ? Style.Theme.inferencia_foco : Style.Theme.inferencia_transformacion; font.bold: true; elide: Text.ElideRight; font.pixelSize: 9 * root.sx }
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
                                ctx.strokeStyle = Style.Theme.borde_suave; ctx.lineWidth = 1
                                ctx.beginPath(); ctx.moveTo(6 * root.sx, height / 2)
                                ctx.lineTo(width - 6 * root.sx, height / 2); ctx.stroke()
                                var zeroX = 6 * root.sx + (0 - sharedBounds.minimum)
                                            / (sharedBounds.maximum - sharedBounds.minimum)
                                            * (width - 12 * root.sx)
                                ctx.strokeStyle = Style.Theme.texto_terciario; ctx.setLineDash([3, 3])
                                ctx.beginPath(); ctx.moveTo(zeroX, 4 * root.sy); ctx.lineTo(zeroX, height - 4 * root.sy); ctx.stroke()
                                ctx.setLineDash([])
                                for (var i = 0; i < values.length; ++i) {
                                    var x = 6 * root.sx + (Number(values[i]) - sharedBounds.minimum)
                                            / (sharedBounds.maximum - sharedBounds.minimum)
                                            * (width - 12 * root.sx)
                                    var jitter = ((i * 37) % 11 - 5) / 5 * Math.min(18 * root.sy, height * 0.28)
                                    ctx.beginPath(); ctx.arc(x, height / 2 + jitter, 2.7 * root.sx, 0, Math.PI * 2)
                                    ctx.fillStyle = Qt.alpha(Style.Theme.inferencia_transformacion, 0.62); ctx.fill()
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "μ " + Number(phaseCard.modelData.media || 0).toFixed(4)
                                  + "  ·  σ " + Number(phaseCard.modelData.desviacion || 0).toFixed(4)
                            color: Style.Theme.texto_secundario
                            horizontalAlignment: Text.AlignHCenter
                            font.bold: true
                            font.pixelSize: Math.max(9, 9 * root.sx)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: phaseCard.modelData.operacion
                            color: Style.Theme.texto_secundario
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            font.pixelSize: Math.max(9, 8 * root.sx)
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedPhase = phaseCard.index }
                }
            }
        }

        Rectangle {
            objectName: "layerNormSelectedPhaseExplanation"
            Layout.fillWidth: true
            implicitHeight: selectedPhaseGuideColumn.implicitHeight + 18 * root.sy
            radius: 9 * root.sx
            color: Style.Theme.aviso_fondo
            border.color: Style.Theme.inferencia_foco

            ColumnLayout {
                id: selectedPhaseGuideColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 9 * root.sx
                spacing: 3 * root.sy

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: root.selectedPhaseGuide.title
                        color: Style.Theme.inferencia_foco
                        font.bold: true
                        font.pixelSize: Math.max(10, 10 * root.sx)
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.selectedPhaseGuide.formula
                        color: Style.Theme.inferencia_transformacion
                        font.family: "Cambria Math"
                        font.bold: true
                        font.pixelSize: Math.max(11, 11 * root.sx)
                    }
                }
                Text {
                    objectName: "layerNormSelectedPhaseText"
                    Layout.fillWidth: true
                    text: root.phasePedagogicalExplanation
                    color: Style.Theme.texto_secundario_fuerte
                    wrapMode: Text.WordWrap
                    lineHeight: 1.15
                    font.pixelSize: Math.max(10, 10 * root.sx)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38 * root.sy
            radius: 9 * root.sx
            color: root.useShortcut ? Style.Theme.superficie_alterna : Style.Theme.aviso_fondo
            border.color: root.useShortcut
                          ? Style.Theme.inferencia_resultado
                          : Style.Theme.inferencia_foco
            Text {
                anchors.centerIn: parent
                text: root.useShortcut
                      ? "Con atajo, la información original x sigue disponible en x + Δx antes de normalizar."
                      : "Sin atajo, solo quedaría Δx: la ruta identidad y su información original desaparecen."
                color: root.useShortcut ? Style.Theme.exito_texto : Style.Theme.aviso_texto
                font.bold: true
                font.pixelSize: 9 * root.sx
            }
        }
    }
}
