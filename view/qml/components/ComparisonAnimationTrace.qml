pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

Rectangle {
    id: root
    objectName: "comparisonAnimationTrace" + modelLabel.slice(-1)

    // Cada escena tiene un diagrama con un ancho implícito diferente. La
    // traza debe obedecer el espacio asignado por la comparación, sin hacer
    // crecer el panel cuando el usuario cambia de animación.
    implicitWidth: 0
    implicitHeight: 0

    property string modelLabel: "MODELO A"
    property var modelInfo: ({})
    property var snapshot: ({})
    property var snapshots: []
    property var detailForward: ({})
    property int detailIndex: -1
    property int selectedIndex: -1
    property int animationIndex: 0
    property int branchIndex: 0
    property int layerIndex: 0
    property int headIndex: 0
    property int attentionPhaseIndex: 0
    property bool residualUsesFfn: false
    property bool reducedMotion: false
    property color accent: Style.Theme.acento
    property color accentBackground: Style.Theme.acento_fondo
    property real sx: 1
    property real sy: 1

    readonly property int animationCount: 10
    readonly property bool hasSnapshot: snapshot
                                                && snapshot.token_elegido !== undefined
    readonly property bool hasDetail: detailIndex === selectedIndex
                                      && detailForward
                                      && detailForward.metadata !== undefined
    readonly property bool requiresDetail: animationIndex < 9
    readonly property var metadata: hasDetail ? detailForward.metadata : ({})
    readonly property var globalData: hasDetail && detailForward["global"]
                                              ? detailForward["global"] : ({})
    readonly property var branchLayers: !hasDetail ? []
            : (branchIndex === 0 ? (detailForward.encoder || [])
                                 : (detailForward.decoder || []))
    readonly property int localLayerIndex: branchLayers.length
            ? Math.max(0, Math.min(branchLayers.length - 1, layerIndex)) : 0
    readonly property int localHeadIndex: Math.max(
            0, Math.min(Math.max(0, Number(metadata.num_heads || 1) - 1), headIndex))
    readonly property var currentLayer: branchLayers.length
            ? branchLayers[localLayerIndex] : ({})
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
    readonly property var currentTokens: !hasSnapshot ? []
            : (branchIndex === 0 ? (snapshot.tokens_entrada || [])
                                 : (snapshot.tokens_decoder || snapshot.tokens_salida || []))
    readonly property var keyTokens: branchIndex === 2 && hasSnapshot
            ? (snapshot.tokens_entrada || []) : currentTokens
    readonly property var currentEmbeddingTensor: !hasDetail ? ({})
            : (branchIndex === 0
               ? (globalData.embedding_encoder_escalado || ({}))
               : (globalData.embedding_decoder_escalado || ({})))
    readonly property var currentProjection: !hasDetail ? ({})
            : (branchIndex === 0
               ? (globalData.proyeccion_posicional_encoder || ({}))
               : (globalData.proyeccion_posicional_decoder || ({})))
    readonly property var currentTrajectory: !hasDetail
            || !detailForward.trayectorias ? ({})
            : (branchIndex === 0
               ? (detailForward.trayectorias.encoder || ({}))
               : (detailForward.trayectorias.decoder || ({})))
    readonly property var currentHiddenTensor: hasDetail
            ? (globalData.salida_decoder || ({})) : ({})
    readonly property string attentionPhase: ["qkv", "scores", "mask", "weighted"][
            Math.max(0, Math.min(3, attentionPhaseIndex))]
    readonly property string locationText: {
        if (animationIndex >= 8)
            return "Salida del decoder"
        var branches = ["Encoder", "Decoder causal", "Atención cruzada"]
        var result = branches[Math.max(0, Math.min(2, branchIndex))]
        if (animationIndex >= 2 && animationIndex <= 7)
            result += " · capa " + (localLayerIndex + 1) + "/"
                    + Math.max(1, branchLayers.length)
        if (animationIndex >= 2 && animationIndex <= 4)
            result += " · H" + (localHeadIndex + 1) + "/"
                    + Math.max(1, Number(metadata.num_heads || 1))
        return result
    }
    readonly property string fullModelName: String(
            root.modelValue(["nombre", "name"], "Modelo"))

    signal stepSelected(int index)

    function modelValue(names, fallback) {
        for (var index = 0; index < names.length; ++index) {
            var value = root.modelInfo ? root.modelInfo[names[index]] : undefined
            if (value !== undefined && value !== null && value !== "")
                return value
        }
        return fallback
    }

    function compactName(name) {
        var text = String(name)
        if (text.length <= 50)
            return text
        return text.substring(0, 30) + "…" + text.substring(text.length - 17)
    }

    radius: 13 * Math.min(sx, sy)
    color: Style.Theme.surface
    border.width: 1
    border.color: root.accent
    clip: true
    Accessible.name: root.modelLabel + ": animación interna de " + root.fullModelName
    Accessible.description: root.hasDetail
            ? "Captura tensorial real del paso seleccionado"
            : "La captura tensorial no está disponible para este paso"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10 * root.sx
        spacing: 7 * root.sy

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38 * root.sy
            spacing: 8 * root.sx

            Rectangle {
                Layout.preferredWidth: 78 * root.sx
                Layout.preferredHeight: 25 * root.sy
                radius: height / 2
                color: root.accentBackground
                Text {
                    anchors.centerIn: parent
                    text: root.modelLabel
                    color: root.accent
                    font.bold: true
                    font.pixelSize: 9 * Math.min(root.sx, root.sy)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    id: modelName
                    Layout.fillWidth: true
                    text: root.compactName(root.fullModelName)
                    color: Style.Theme.texto_primario
                    font.bold: true
                    elide: Text.ElideRight
                    font.pixelSize: 13 * Math.min(root.sx, root.sy)
                    ToolTip.visible: modelNameMouse.containsMouse
                    ToolTip.text: root.fullModelName
                    MouseArea {
                        id: modelNameMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.locationText
                    color: root.accent
                    font.bold: true
                    elide: Text.ElideRight
                    font.pixelSize: 8 * Math.min(root.sx, root.sy)
                }
            }

            Rectangle {
                Layout.preferredWidth: Math.max(92 * root.sx,
                                                animationToken.implicitWidth + 16 * root.sx)
                Layout.preferredHeight: 28 * root.sy
                radius: 8 * root.sx
                color: root.hasDetail ? Style.Theme.exito_fondo
                                      : Style.Theme.aviso_fondo
                border.color: root.hasDetail ? Style.Theme.exito_texto
                                             : Style.Theme.aviso_texto
                Text {
                    id: animationToken
                    anchors.centerIn: parent
                    text: root.hasSnapshot
                          ? "Token: “" + root.snapshot.token_elegido.texto + "”"
                          : "Sin token"
                    color: root.hasDetail ? Style.Theme.exito_texto
                                          : Style.Theme.aviso_texto
                    font.bold: true
                    font.pixelSize: 9 * Math.min(root.sx, root.sy)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Style.Theme.divisor
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.minimumHeight: 0
            Layout.preferredWidth: 1
            Layout.preferredHeight: 1
            clip: true

            StackLayout {
                anchors.fill: parent
                implicitWidth: 0
                implicitHeight: 0
                currentIndex: Math.max(0, Math.min(root.animationCount - 1,
                                                   root.animationIndex))

                TokenEmbeddingScene {
                    tensorData: root.currentEmbeddingTensor
                    tokens: root.currentTokens
                    active: root.animationIndex === 0 && root.hasDetail
                    reducedMotion: root.reducedMotion
                    sx: root.sx
                    sy: root.sy
                }

                EmbeddingPositionScene {
                    projection: root.currentProjection
                    tokens: root.currentTokens
                    active: root.animationIndex === 1 && root.hasDetail
                    reducedMotion: root.reducedMotion
                    sx: root.sx
                    sy: root.sy
                }

                AttentionComputationScene {
                    attentionData: root.currentAttention
                    causalMaskData: root.globalData.mascara_causal || ({})
                    phase: root.attentionPhase
                    branchIndex: root.branchIndex
                    headIndex: root.localHeadIndex
                    layerIndex: root.localLayerIndex
                    active: root.animationIndex === 2 && root.hasDetail
                    reducedMotion: root.reducedMotion
                    sx: root.sx
                    sy: root.sy
                }

                AttentionFlowScene {
                    attentionData: root.currentAttention
                    queryTokens: root.currentTokens
                    keyTokens: root.keyTokens
                    crossAttention: root.branchIndex === 2
                    headIndex: root.localHeadIndex
                    active: root.animationIndex === 3 && root.hasDetail
                    reducedMotion: root.reducedMotion
                    sx: root.sx
                    sy: root.sy
                }

                MultiHeadSplitScene {
                    metadata: root.metadata
                    attentionData: root.currentAttention
                    active: root.animationIndex === 4 && root.hasDetail
                    reducedMotion: root.reducedMotion
                    sx: root.sx
                    sy: root.sy
                }

                FeedForwardExpansionScene {
                    sceneData: root.currentFfn
                    tokens: root.currentTokens
                    active: root.animationIndex === 5 && root.hasDetail
                    reducedMotion: root.reducedMotion
                    sx: root.sx
                    sy: root.sy
                }

                ResidualLayerNormScene {
                    sceneData: root.currentResidual
                    active: root.animationIndex === 6 && root.hasDetail
                    reducedMotion: root.reducedMotion
                    sublayerLabel: root.residualUsesFfn ? "FFN" : "Atención"
                    sx: root.sx
                    sy: root.sy
                }

                LayerSkyscraperScene {
                    trajectory: root.currentTrajectory
                    tokens: root.currentTokens
                    active: root.animationIndex === 7 && root.hasDetail
                    sx: root.sx
                    sy: root.sy
                }

                OutputProjectionScene {
                    snapshot: root.hasSnapshot ? root.snapshot : null
                    logitsData: root.hasDetail
                                ? (root.detailForward.logits_lineales
                                   || root.detailForward.logits || ({})) : ({})
                    hiddenData: root.currentHiddenTensor
                    active: root.animationIndex === 8 && root.hasDetail
                    reducedMotion: root.reducedMotion
                    sx: root.sx
                    sy: root.sy
                }

                SoftmaxRaceScene {
                    snapshots: root.snapshots
                    initialStep: root.selectedIndex
                    active: root.animationIndex === 9 && root.hasSnapshot
                    reducedMotion: root.reducedMotion
                    sx: root.sx
                    sy: root.sy
                    onStepSelected: function(index) { root.stepSelected(index) }
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 12 * root.sx
                visible: !root.hasSnapshot
                         || (root.requiresDetail && !root.hasDetail)
                radius: 12 * root.sx
                color: Style.Theme.superficie_alterna
                border.color: root.accent

                Column {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 36 * root.sx, 440 * root.sx)
                    spacing: 8 * root.sy
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.hasSnapshot ? "◷" : "○"
                        color: root.accent
                        font.pixelSize: 30 * Math.min(root.sx, root.sy)
                    }
                    Text {
                        width: parent.width
                        text: root.hasSnapshot
                              ? "Captura interna no disponible para este paso"
                              : "Este modelo no produjo un token en este paso"
                        color: Style.Theme.texto_primario
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.pixelSize: 15 * Math.min(root.sx, root.sy)
                    }
                    Text {
                        width: parent.width
                        text: root.hasSnapshot
                              ? "La animación completa se conserva para el último paso sincronizado. La carrera Softmax sí mantiene todo el historial."
                              : "Selecciona un paso común o revisa el resumen de finalización."
                        color: Style.Theme.texto_secundario
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11 * Math.min(root.sx, root.sy)
                    }
                }
            }
        }
    }
}
