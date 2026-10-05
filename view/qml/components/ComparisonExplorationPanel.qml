pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

Rectangle {
    id: root
    objectName: "comparisonExplorationPanel"

    property var snapshotsA: []
    property var snapshotsB: []
    property var infoA: ({})
    property var infoB: ({})
    property var detailA: ({})
    property var detailB: ({})
    property int detailIndexA: -1
    property int detailIndexB: -1
    property int selectedIndex: -1
    property int stageIndex: 0
    property int viewModeIndex: 0
    property int animationIndex: 0
    property int branchIndex: 0
    property int layerIndex: 0
    property int headIndex: 0
    property int attentionPhaseIndex: 0
    property int compactModelIndex: 0
    property bool residualUsesFfn: false
    property bool reducedMotion: false
    property bool stepMode: false
    property bool canGenerateNext: false
    property bool tokenProcessing: false
    property string stateA: "Listo"
    property string stateB: "Listo"
    property int tokenCountA: 0
    property int tokenCountB: 0
    property bool modelAActive: false
    property bool modelBActive: false
    property string nextTokenLabel: "Generar siguiente token"
    property real sx: 1
    property real sy: 1

    readonly property bool singleModelMode: width < 1680
    readonly property bool veryNarrow: width < 980
    readonly property bool denseHeight: height < 760
    readonly property real panelMargin: (denseHeight ? 11 : 18) * sx
    readonly property real panelSpacing: (denseHeight ? 6 : 11) * sy

    readonly property int stepCount: Math.max(snapshotsA.length, snapshotsB.length)
    readonly property int commonStepCount: Math.min(snapshotsA.length,
                                                    snapshotsB.length)
    readonly property int currentIndex: stepCount === 0 ? -1
            : Math.max(0, Math.min(stepCount - 1, selectedIndex))
    readonly property var currentA: currentIndex >= 0
            && currentIndex < snapshotsA.length ? snapshotsA[currentIndex] : ({})
    readonly property var currentB: currentIndex >= 0
            && currentIndex < snapshotsB.length ? snapshotsB[currentIndex] : ({})
    readonly property var animationLabels: [
        "Embeddings", "Posición", "Q/K/V y máscara", "Flujo de atención",
        "Multi-head", "Feed-forward", "Residual + Norm", "Capas",
        "Proyección", "Carrera Softmax"
    ]
    readonly property var attentionPhaseLabels: [
        "Q, K y V", "Scores QKᵀ", "Máscara", "Softmax + contexto"
    ]
    readonly property var branchLabels: [
        "Encoder", "Decoder causal", "Atención cruzada"
    ]
    readonly property bool outputAnimation: animationIndex >= 8
    readonly property int animationChapterIndex: outputAnimation ? 3 : branchIndex
    readonly property int mapIndex: viewModeIndex === 0
            ? stageIndex : animationChapterIndex
    readonly property int maxLayerCount: Math.max(
        1,
        Number(detailA && detailA.metadata ? detailA.metadata.num_layers : 0),
        Number(detailB && detailB.metadata ? detailB.metadata.num_layers : 0),
        Number(infoA ? (infoA.num_capas || infoA.encoder_layers || 0) : 0),
        Number(infoB ? (infoB.num_capas || infoB.encoder_layers || 0) : 0)
    )
    readonly property int maxHeadCount: Math.max(
        1,
        Number(detailA && detailA.metadata ? detailA.metadata.num_heads : 0),
        Number(detailB && detailB.metadata ? detailB.metadata.num_heads : 0),
        Number(infoA ? (infoA.num_cabezas || 0) : 0),
        Number(infoB ? (infoB.num_cabezas || 0) : 0)
    )
    readonly property string stepScope: {
        var hasA = currentIndex >= 0 && currentIndex < snapshotsA.length
        var hasB = currentIndex >= 0 && currentIndex < snapshotsB.length
        if (hasA && hasB && snapshotsA.length !== snapshotsB.length
                && currentIndex === commonStepCount - 1)
            return "último común"
        if (hasA && !hasB)
            return "solo A"
        if (!hasA && hasB)
            return "solo B"
        return ""
    }
    readonly property var chapters: [
        { "label": "Encoder", "caption": "autoatención" },
        { "label": "Decoder", "caption": "máscara causal" },
        { "label": "Cruce", "caption": "consulta al encoder" },
        { "label": "Salida", "caption": "probabilidad y token" }
    ]

    onMaxLayerCountChanged: layerIndex = Math.max(
            0, Math.min(maxLayerCount - 1, layerIndex === 0 ? maxLayerCount - 1 : layerIndex))
    onMaxHeadCountChanged: headIndex = Math.max(0, Math.min(maxHeadCount - 1, headIndex))

    function selectChapter(index) {
        if (viewModeIndex === 0) {
            stageIndex = index
            return
        }
        if (index < 3) {
            branchIndex = index
            if (animationIndex >= 8)
                animationIndex = 3
        } else if (animationIndex < 8) {
            animationIndex = 8
        }
    }

    function operationSupportsBranch() {
        return animationIndex < 8
    }

    function operationSupportsLayer() {
        return animationIndex >= 2 && animationIndex <= 7
    }

    function operationSupportsHead() {
        return animationIndex >= 2 && animationIndex <= 4
    }

    signal closeRequested()
    signal nextTokenRequested()
    signal stepSelected(int index)

    radius: 15 * Math.min(sx, sy)
    color: Style.Theme.fondo
    border.color: Style.Theme.borde_medio
    clip: true
    Accessible.name: "Explorador paralelo de los modelos A y B"
    Accessible.description: "Compara encoder, decoder, atención cruzada y salida para el mismo token generado."

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.panelMargin
        spacing: root.panelSpacing

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: (root.denseHeight ? 45 : 54) * root.sy
            spacing: 12 * root.sx

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 1 * root.sy

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: "Exploración paralela de los dos modelos"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 22 * Math.min(root.sx, root.sy)
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.viewModeIndex === 0
                          ? "Resumen del mismo paso con datos reales de cada inferencia."
                          : (root.singleModelMode
                             ? "Vista compacta: alterna modelos sin perder la operación seleccionada."
                             : "Diez animaciones internas sincronizadas para contrastar ambos modelos.")
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 12 * Math.min(root.sx, root.sy)
                    elide: Text.ElideRight
                }
            }

            SelectorPrincipal {
                objectName: "comparisonExplorerViewMode"
                Layout.preferredWidth: 188 * root.sx
                Layout.preferredHeight: 36 * root.sy
                model: ["Resumen esencial", "Animaciones internas"]
                currentIndex: root.viewModeIndex
                sx: root.sx
                sy: root.sy
                onActivated: function(index) { root.viewModeIndex = index }
            }

            BotonPrincipal {
                Layout.preferredWidth: 116 * root.sx
                Layout.preferredHeight: 38 * root.sy
                text: "Cerrar"
                size_text: 0.25
                onClicked: root.closeRequested()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: (root.denseHeight ? 32 : 38) * root.sy
            spacing: 8 * root.sx

            Text {
                visible: !root.veryNarrow
                text: "TOKEN GENERADO"
                color: Style.Theme.texto_secundario
                font.bold: true
                font.pixelSize: 10 * Math.min(root.sx, root.sy)
            }

            BotonAccesible {
                objectName: "comparisonPreviousTokenButton"
                Layout.preferredWidth: 38 * root.sx
                Layout.preferredHeight: 32 * root.sy
                text: "‹"
                enabled: root.currentIndex > 0
                onClicked: root.stepSelected(root.currentIndex - 1)
            }

            Text {
                Layout.preferredWidth: (root.veryNarrow ? 142 : 190) * root.sx
                text: root.stepCount > 0
                      ? "Paso " + (root.currentIndex + 1) + " de " + root.stepCount
                        + (root.stepScope ? " · " + root.stepScope : "")
                      : "Sin tokens"
                color: Style.Theme.acento_fuerte
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 12 * Math.min(root.sx, root.sy)
            }

            BotonAccesible {
                objectName: "comparisonNextTokenHistoryButton"
                Layout.preferredWidth: 38 * root.sx
                Layout.preferredHeight: 32 * root.sy
                text: "›"
                enabled: root.currentIndex >= 0 && root.currentIndex < root.stepCount - 1
                onClicked: root.stepSelected(root.currentIndex + 1)
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: !root.veryNarrow
                text: root.stepMode ? "MODO · TOKEN POR TOKEN" : "MODO · DE CORRIDO"
                color: root.stepMode ? Style.Theme.acento_fuerte
                                     : Style.Theme.info_texto
                font.bold: true
                font.pixelSize: 10 * Math.min(root.sx, root.sy)
            }

            BotonAcento {
                objectName: "comparisonExplorerNextTokenButton"
                visible: root.stepMode
                Layout.preferredWidth: (root.veryNarrow ? 190 : 238) * root.sx
                Layout.preferredHeight: 36 * root.sy
                text: root.tokenProcessing ? "Procesando…" : root.nextTokenLabel
                enabled: root.canGenerateNext && !root.tokenProcessing
                opacity: enabled ? 1 : 0.48
                onClicked: root.nextTokenRequested()
            }
        }

        InferenceProcessMap {
            objectName: "comparisonProcessMap"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: (root.denseHeight ? 58 : 78) * root.sy
            chapters: root.chapters
            currentIndex: root.mapIndex
            currentStep: root.currentIndex + 1
            currentStepCount: Math.max(1, root.stepCount)
            accent: Style.Theme.acento
            sx: root.sx
            sy: root.sy
            compact: true
            onChapterSelected: function(index) { root.selectChapter(index) }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 1
            currentIndex: root.viewModeIndex

            Item {
                implicitWidth: 0
                implicitHeight: 0
                clip: true

                RowLayout {
                    anchors.fill: parent
                    spacing: 14 * root.sx

                    ComparisonModelTrace {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        modelLabel: "MODELO A"
                        modelInfo: root.infoA
                        snapshot: root.currentA
                        lastSnapshot: root.snapshotsA.length
                                      ? root.snapshotsA[root.snapshotsA.length - 1] : ({})
                        generationStatus: root.stateA
                        generatedTokenCount: root.tokenCountA
                        generationActive: root.modelAActive
                        selectedStep: root.currentIndex + 1
                        stageIndex: root.stageIndex
                        accent: Style.Theme.acento
                        accentBackground: Style.Theme.acento_fondo
                        sx: root.sx
                        sy: root.sy
                    }

                    ComparisonModelTrace {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        modelLabel: "MODELO B"
                        modelInfo: root.infoB
                        snapshot: root.currentB
                        lastSnapshot: root.snapshotsB.length
                                      ? root.snapshotsB[root.snapshotsB.length - 1] : ({})
                        generationStatus: root.stateB
                        generatedTokenCount: root.tokenCountB
                        generationActive: root.modelBActive
                        selectedStep: root.currentIndex + 1
                        stageIndex: root.stageIndex
                        accent: Style.Theme.inferencia_estructura
                        accentBackground: Style.Theme.info_fondo
                        sx: root.sx
                        sy: root.sy
                    }
                }
            }

            Item {
                implicitWidth: 0
                implicitHeight: 0
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 7 * root.sy

                    RowLayout {
                        objectName: "comparisonAnimationControls"
                        Layout.fillWidth: true
                        Layout.preferredHeight: (root.denseHeight ? 32 : 38) * root.sy
                        spacing: 7 * root.sx

                        Text {
                            text: "Animación"
                            color: Style.Theme.texto_secundario
                            font.bold: true
                            font.pixelSize: 10 * Math.min(root.sx, root.sy)
                        }
                        SelectorPrincipal {
                            objectName: "comparisonAnimationSelector"
                            Layout.preferredWidth: 205 * root.sx
                            Layout.preferredHeight: 34 * root.sy
                            model: root.animationLabels
                            currentIndex: root.animationIndex
                            sx: root.sx
                            sy: root.sy
                            onActivated: function(index) { root.animationIndex = index }
                        }

                        SelectorPrincipal {
                            objectName: "comparisonCompactModelSelector"
                            visible: root.singleModelMode
                            Layout.preferredWidth: visible ? 152 * root.sx : 0
                            Layout.preferredHeight: 34 * root.sy
                            model: ["Ver Modelo A", "Ver Modelo B"]
                            currentIndex: root.compactModelIndex
                            sx: root.sx
                            sy: root.sy
                            onActivated: function(index) {
                                root.compactModelIndex = index
                            }
                        }

                        SelectorPrincipal {
                            objectName: "comparisonAttentionPhaseSelector"
                            visible: !root.singleModelMode
                                     && root.animationIndex === 2
                            Layout.preferredWidth: visible ? 165 * root.sx : 0
                            Layout.preferredHeight: 34 * root.sy
                            model: root.attentionPhaseLabels
                            currentIndex: root.attentionPhaseIndex
                            sx: root.sx
                            sy: root.sy
                            onActivated: function(index) { root.attentionPhaseIndex = index }
                        }

                        SelectorPrincipal {
                            objectName: "comparisonBranchSelector"
                            visible: !root.singleModelMode
                                     && root.operationSupportsBranch()
                            Layout.preferredWidth: visible ? 160 * root.sx : 0
                            Layout.preferredHeight: 34 * root.sy
                            model: root.branchLabels
                            currentIndex: root.branchIndex
                            sx: root.sx
                            sy: root.sy
                            onActivated: function(index) { root.branchIndex = index }
                        }

                        RowLayout {
                            visible: !root.singleModelMode
                                     && root.operationSupportsLayer()
                            spacing: 3 * root.sx
                            BotonAccesible {
                                Layout.preferredWidth: 30 * root.sx
                                Layout.preferredHeight: 30 * root.sy
                                text: "−"
                                enabled: root.layerIndex > 0
                                onClicked: root.layerIndex -= 1
                            }
                            Text {
                                Layout.preferredWidth: 73 * root.sx
                                text: "Capa " + (root.layerIndex + 1)
                                      + "/" + root.maxLayerCount
                                color: Style.Theme.texto_primario
                                horizontalAlignment: Text.AlignHCenter
                                font.bold: true
                                font.pixelSize: 10 * Math.min(root.sx, root.sy)
                            }
                            BotonAccesible {
                                Layout.preferredWidth: 30 * root.sx
                                Layout.preferredHeight: 30 * root.sy
                                text: "+"
                                enabled: root.layerIndex < root.maxLayerCount - 1
                                onClicked: root.layerIndex += 1
                            }
                        }

                        RowLayout {
                            visible: !root.singleModelMode
                                     && root.operationSupportsHead()
                            spacing: 3 * root.sx
                            BotonAccesible {
                                Layout.preferredWidth: 30 * root.sx
                                Layout.preferredHeight: 30 * root.sy
                                text: "−"
                                enabled: root.headIndex > 0
                                onClicked: root.headIndex -= 1
                            }
                            Text {
                                Layout.preferredWidth: 67 * root.sx
                                text: "H" + (root.headIndex + 1)
                                      + "/" + root.maxHeadCount
                                color: Style.Theme.texto_primario
                                horizontalAlignment: Text.AlignHCenter
                                font.bold: true
                                font.pixelSize: 10 * Math.min(root.sx, root.sy)
                            }
                            BotonAccesible {
                                Layout.preferredWidth: 30 * root.sx
                                Layout.preferredHeight: 30 * root.sy
                                text: "+"
                                enabled: root.headIndex < root.maxHeadCount - 1
                                onClicked: root.headIndex += 1
                            }
                        }

                        BotonAccesible {
                            visible: !root.singleModelMode
                                     && root.animationIndex === 6
                            Layout.preferredWidth: visible ? 148 * root.sx : 0
                            Layout.preferredHeight: 31 * root.sy
                            text: root.residualUsesFfn
                                  ? "Subcapa: FFN" : "Subcapa: atención"
                            onClicked: root.residualUsesFfn = !root.residualUsesFfn
                        }

                        Item { Layout.fillWidth: true }

                        CasillaPrincipal {
                            objectName: "comparisonReducedMotionToggle"
                            Layout.preferredWidth: 146 * root.sx
                            text: "Reducir movimiento"
                            checked: root.reducedMotion
                            font.pixelSize: 10 * Math.min(root.sx, root.sy)
                            onToggled: root.reducedMotion = checked
                        }
                    }

                    RowLayout {
                        id: compactAnimationControls
                        objectName: "comparisonCompactAnimationControls"
                        visible: root.singleModelMode
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible
                                                ? (root.denseHeight ? 30 : 34) * root.sy
                                                : 0
                        spacing: 7 * root.sx

                        Text {
                            text: "Detalle"
                            color: Style.Theme.texto_secundario
                            font.bold: true
                            font.pixelSize: 10 * Math.min(root.sx, root.sy)
                        }

                        SelectorPrincipal {
                            objectName: "comparisonCompactAttentionPhaseSelector"
                            visible: root.animationIndex === 2
                            Layout.preferredWidth: visible ? 165 * root.sx : 0
                            Layout.preferredHeight: 32 * root.sy
                            model: root.attentionPhaseLabels
                            currentIndex: root.attentionPhaseIndex
                            sx: root.sx
                            sy: root.sy
                            onActivated: function(index) {
                                root.attentionPhaseIndex = index
                            }
                        }

                        SelectorPrincipal {
                            objectName: "comparisonCompactBranchSelector"
                            visible: root.operationSupportsBranch()
                            Layout.preferredWidth: visible ? 160 * root.sx : 0
                            Layout.preferredHeight: 32 * root.sy
                            model: root.branchLabels
                            currentIndex: root.branchIndex
                            sx: root.sx
                            sy: root.sy
                            onActivated: function(index) {
                                root.branchIndex = index
                            }
                        }

                        RowLayout {
                            visible: root.operationSupportsLayer()
                            spacing: 3 * root.sx
                            BotonAccesible {
                                Layout.preferredWidth: 30 * root.sx
                                Layout.preferredHeight: 28 * root.sy
                                text: "−"
                                enabled: root.layerIndex > 0
                                onClicked: root.layerIndex -= 1
                            }
                            Text {
                                Layout.preferredWidth: 73 * root.sx
                                text: "Capa " + (root.layerIndex + 1)
                                      + "/" + root.maxLayerCount
                                color: Style.Theme.texto_primario
                                horizontalAlignment: Text.AlignHCenter
                                font.bold: true
                                font.pixelSize: 10 * Math.min(root.sx, root.sy)
                            }
                            BotonAccesible {
                                Layout.preferredWidth: 30 * root.sx
                                Layout.preferredHeight: 28 * root.sy
                                text: "+"
                                enabled: root.layerIndex < root.maxLayerCount - 1
                                onClicked: root.layerIndex += 1
                            }
                        }

                        RowLayout {
                            visible: root.operationSupportsHead()
                            spacing: 3 * root.sx
                            BotonAccesible {
                                Layout.preferredWidth: 30 * root.sx
                                Layout.preferredHeight: 28 * root.sy
                                text: "−"
                                enabled: root.headIndex > 0
                                onClicked: root.headIndex -= 1
                            }
                            Text {
                                Layout.preferredWidth: 67 * root.sx
                                text: "H" + (root.headIndex + 1)
                                      + "/" + root.maxHeadCount
                                color: Style.Theme.texto_primario
                                horizontalAlignment: Text.AlignHCenter
                                font.bold: true
                                font.pixelSize: 10 * Math.min(root.sx, root.sy)
                            }
                            BotonAccesible {
                                Layout.preferredWidth: 30 * root.sx
                                Layout.preferredHeight: 28 * root.sy
                                text: "+"
                                enabled: root.headIndex < root.maxHeadCount - 1
                                onClicked: root.headIndex += 1
                            }
                        }

                        BotonAccesible {
                            visible: root.animationIndex === 6
                            Layout.preferredWidth: visible ? 148 * root.sx : 0
                            Layout.preferredHeight: 29 * root.sy
                            text: root.residualUsesFfn
                                  ? "Subcapa: FFN" : "Subcapa: atención"
                            onClicked: root.residualUsesFfn = !root.residualUsesFfn
                        }

                        Item { Layout.fillWidth: true }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 0
                        Layout.minimumHeight: 0
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 1
                        spacing: 14 * root.sx
                        clip: true

                        ComparisonAnimationTrace {
                            visible: !root.singleModelMode
                                     || root.compactModelIndex === 0
                            Layout.fillWidth: visible
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: visible ? 1 : 0
                            Layout.maximumWidth: visible ? 16777215 : 0
                            Layout.fillHeight: true
                            modelLabel: "MODELO A"
                            modelInfo: root.infoA
                            snapshot: root.currentA
                            snapshots: root.snapshotsA
                            detailForward: root.detailA
                            detailIndex: root.detailIndexA
                            selectedIndex: root.currentIndex
                            animationIndex: root.animationIndex
                            branchIndex: root.branchIndex
                            layerIndex: root.layerIndex
                            headIndex: root.headIndex
                            attentionPhaseIndex: root.attentionPhaseIndex
                            residualUsesFfn: root.residualUsesFfn
                            reducedMotion: root.reducedMotion
                            accent: Style.Theme.acento
                            accentBackground: Style.Theme.acento_fondo
                            sx: root.sx
                            sy: root.sy
                            onStepSelected: function(index) { root.stepSelected(index) }
                        }

                        ComparisonAnimationTrace {
                            visible: !root.singleModelMode
                                     || root.compactModelIndex === 1
                            Layout.fillWidth: visible
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: visible ? 1 : 0
                            Layout.maximumWidth: visible ? 16777215 : 0
                            Layout.fillHeight: true
                            modelLabel: "MODELO B"
                            modelInfo: root.infoB
                            snapshot: root.currentB
                            snapshots: root.snapshotsB
                            detailForward: root.detailB
                            detailIndex: root.detailIndexB
                            selectedIndex: root.currentIndex
                            animationIndex: root.animationIndex
                            branchIndex: root.branchIndex
                            layerIndex: root.layerIndex
                            headIndex: root.headIndex
                            attentionPhaseIndex: root.attentionPhaseIndex
                            residualUsesFfn: root.residualUsesFfn
                            reducedMotion: root.reducedMotion
                            accent: Style.Theme.inferencia_estructura
                            accentBackground: Style.Theme.info_fondo
                            sx: root.sx
                            sy: root.sy
                            onStepSelected: function(index) { root.stepSelected(index) }
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: root.viewModeIndex === 0
                  ? "Los pesos de atención describen cómo cada modelo combinó información; no son por sí solos una medida de calidad."
                  : (root.singleModelMode
                     ? "Los controles quedan sincronizados al alternar A/B, de modo que comparas exactamente la misma operación, capa y cabeza."
                     : "Los controles son compartidos: ambos paneles muestran la misma operación, rama, capa y cabeza para que la comparación sea directa.")
            visible: !root.denseHeight
            color: Style.Theme.texto_secundario
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: 10 * Math.min(root.sx, root.sy)
        }
    }
}
