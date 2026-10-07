pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root
    objectName: "moduleGuidedTourScreen"

    property string moduleId: "module_1"
    readonly property var courseController: mainViewModel.courseController
    readonly property var moduleData: courseController.currentModule
    readonly property var steps: moduleData.guided_steps || []
    readonly property real uiScale: Math.max(0.82, Math.min(width / 1280, height / 820))
    property int currentIndex: 0
    property bool playing: false
    property var currentConcept: ({})
    property var currentRelatedConcepts: []
    readonly property var currentStep: steps.length > currentIndex ? steps[currentIndex] : ({})

    // Cada módulo declara qué contenido amplio corresponde a sus pasos. La
    // vista sigue siendo genérica y un módulo nuevo sólo modifica datos.
    readonly property var currentTheorySequence: moduleData.theory_sequence || []
    readonly property string currentTheoryConceptId:
        currentTheorySequence.length > currentIndex
        ? String(currentTheorySequence[currentIndex])
        : String(currentStep.concept_id || "")

    Component.onCompleted: {
        root.courseController.selectModule(root.moduleId)
        root.refreshConcept()
    }

    onCurrentTheoryConceptIdChanged: refreshConcept()

    Connections {
        target: typeof mainViewModel !== "undefined" && mainViewModel
                ? mainViewModel.theoryController : null
        ignoreUnknownSignals: true
        function onTeoriaRecargada() { root.refreshConcept() }
    }

    Timer {
        interval: 9000
        running: root.playing
        repeat: true
        onTriggered: {
            if (root.currentIndex < root.steps.length - 1)
                root.goToStep(root.currentIndex + 1)
            else
                root.playing = false
        }
    }

    function refreshConcept() {
        if (!root.currentTheoryConceptId) {
            root.currentConcept = ({})
            root.currentRelatedConcepts = []
            return
        }
        if (typeof mainViewModel === "undefined" || !mainViewModel.theoryController) {
            root.currentConcept = ({
                "id": root.currentTheoryConceptId,
                "title": root.currentStep.title || "Contenido no disponible",
                "short_description": root.currentStep.why || "",
                "explanation": "No se pudo acceder al contenido teórico."
            })
            root.currentRelatedConcepts = []
            return
        }
        root.currentConcept = mainViewModel.theoryController.obtenerConcepto(
                    root.currentTheoryConceptId)
        root.currentRelatedConcepts = mainViewModel.theoryController.obtenerRelacionados(
                    root.currentTheoryConceptId)
    }

    function goToStep(index) {
        if (root.steps.length === 0)
            return
        root.currentIndex = Math.max(0, Math.min(index, root.steps.length - 1))
        if (root.currentStep.id)
            root.courseController.completeGuidedStep(root.moduleId, root.currentStep.id)
    }

    function finishTour() {
        root.playing = false
        root.courseController.completeGuidedTour(root.moduleId)
        root.stackView.pop()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24 * root.uiScale
        spacing: 11 * root.uiScale

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 58 * root.uiScale
            spacing: 16 * root.uiScale

            BotonPrincipal {
                Layout.preferredWidth: 155 * root.uiScale
                Layout.preferredHeight: 42 * root.uiScale
                text: "← Módulo"
                onClicked: root.stackView.pop()
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2 * root.uiScale
                Text {
                    Layout.fillWidth: true
                    text: "RECORRIDO GUIADO · MÓDULO " + (root.moduleData.order || "")
                    color: Style.Theme.acento_fuerte
                    font.bold: true
                    font.pixelSize: 11 * root.uiScale
                }
                Text {
                    Layout.fillWidth: true
                    text: root.moduleData.title || ""
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 25 * root.uiScale
                    elide: Text.ElideRight
                }
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 1 * root.uiScale
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: "PASO " + (root.currentIndex + 1) + " DE " + root.steps.length
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 10 * root.uiScale
                    font.bold: true
                }
                Text {
                    text: root.currentStep.title || ""
                    color: Style.Theme.texto_secundario_fuerte
                    font.bold: true
                    font.pixelSize: 14 * root.uiScale
                }
            }
        }

        ScrollView {
            id: stepScroll
            Layout.fillWidth: true
            Layout.preferredHeight: 62 * root.uiScale
            contentHeight: availableHeight
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff
            ScrollBar.horizontal.policy: ScrollBar.AsNeeded

            Row {
                spacing: 7 * root.uiScale
                Repeater {
                    model: root.steps
                    delegate: Rectangle {
                        id: stepChip
                        required property var modelData
                        required property int index
                        width: 146 * root.uiScale
                        height: 50 * root.uiScale
                        radius: 9 * root.uiScale
                        color: index === root.currentIndex ? Style.Theme.acento
                               : (index < root.currentIndex
                                  ? Style.Theme.exito_fondo : Style.Theme.chip_fondo)
                        border.color: index === root.currentIndex
                                      ? Style.Theme.acento_alt : Style.Theme.borde_suave

                        Text {
                            anchors.fill: parent
                            anchors.margins: 7 * root.uiScale
                            text: (stepChip.index + 1) + ". " + stepChip.modelData.title
                            color: stepChip.index === root.currentIndex
                                   ? Style.Theme.texto_sobre_color
                                   : Style.Theme.texto_secundario_fuerte
                            font.bold: stepChip.index === root.currentIndex
                            font.pixelSize: 9 * root.uiScale
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.goToStep(stepChip.index)
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14 * root.uiScale

            ColumnLayout {
                Layout.preferredWidth: Math.max(360 * root.uiScale,
                                                Math.min(500 * root.uiScale,
                                                         root.width * 0.39))
                Layout.minimumWidth: 360 * root.uiScale
                Layout.fillHeight: true
                spacing: 10 * root.uiScale

                GuidedDemoVisualization {
                    objectName: "moduleGuidedVisualization"
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(260 * root.uiScale,
                                                     Math.max(220 * root.uiScale,
                                                              root.height * 0.31))
                    Layout.minimumHeight: 190 * root.uiScale
                    conceptId: root.currentTheoryConceptId
                    stepId: String(root.currentStep.id || "")
                    scaleFactor: root.uiScale
                }

                RectanglePrincipal {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sx: root.uiScale
                    sy: root.uiScale

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 13 * root.uiScale
                        spacing: 8 * root.uiScale

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: "TRAZA DEL PASO"
                                color: Style.Theme.acento_fuerte
                                font.bold: true
                                font.pixelSize: 10 * root.uiScale
                                font.letterSpacing: 0.8
                            }
                            Text {
                                text: root.currentStep.dimensions || ""
                                color: Style.Theme.formula_texto
                                font.family: Style.Theme.fuente_mono
                                font.bold: true
                                font.pixelSize: 10 * root.uiScale
                            }
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: availableWidth
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            ColumnLayout {
                                width: parent.width
                                spacing: 7 * root.uiScale

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    rowSpacing: 7 * root.uiScale
                                    columnSpacing: 7 * root.uiScale

                                    Repeater {
                                        model: [
                                            { "label": "ENTRADA", "value": root.currentStep.input || "", "fill": Style.Theme.concepto_fondo, "ink": Style.Theme.concepto_texto },
                                            { "label": "OPERACIÓN", "value": root.currentStep.operation || "", "fill": Style.Theme.formula_fondo, "ink": Style.Theme.formula_texto },
                                            { "label": "CAMBIO", "value": root.currentStep.change || "", "fill": Style.Theme.ejemplo_fondo, "ink": Style.Theme.ejemplo_texto },
                                            { "label": "RESULTADO", "value": root.currentStep.output || "", "fill": Style.Theme.proceso_fondo, "ink": Style.Theme.proceso_texto }
                                        ]
                                        delegate: Rectangle {
                                            id: flowCard
                                            required property var modelData
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 180 * root.uiScale
                                            Layout.preferredHeight: 72 * root.uiScale
                                            radius: 8 * root.uiScale
                                            color: flowCard.modelData.fill

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: 8 * root.uiScale
                                                spacing: 3 * root.uiScale
                                                Text {
                                                    text: flowCard.modelData.label
                                                    color: flowCard.modelData.ink
                                                    font.bold: true
                                                    font.pixelSize: 8 * root.uiScale
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    text: flowCard.modelData.value
                                                    color: Style.Theme.texto_primario
                                                    font.pixelSize: 9 * root.uiScale
                                                    wrapMode: Text.WordWrap
                                                    maximumLineCount: 3
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "¿POR QUÉ?  " + (root.currentStep.why || "")
                                    color: Style.Theme.texto_secundario_fuerte
                                    font.pixelSize: 10 * root.uiScale
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Siguiente: " + (root.currentStep.next || "fin del recorrido")
                                    color: Style.Theme.texto_secundario
                                    font.pixelSize: 9 * root.uiScale
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }

            GuidedConceptReader {
                id: conceptReader
                objectName: "moduleGuidedConceptReader"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 500 * root.uiScale
                concept: root.currentConcept
                relatedConcepts: root.currentRelatedConcepts
                loadError: typeof mainViewModel !== "undefined" && mainViewModel
                           ? mainViewModel.theoryController.errorCarga : ""
                scaleFactor: root.uiScale
                showVisualization: false
                onDeepDiveRequested: function(conceptId) {
                    root.openTheoryConcept(conceptId)
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 44 * root.uiScale
            spacing: 9 * root.uiScale

            BotonPrincipal {
                Layout.preferredWidth: 150 * root.uiScale
                Layout.fillHeight: true
                text: "← Anterior"
                enabled: root.currentIndex > 0
                opacity: enabled ? 1 : 0.4
                onClicked: root.goToStep(root.currentIndex - 1)
            }
            BotonSecundario {
                Layout.preferredWidth: 170 * root.uiScale
                Layout.fillHeight: true
                sx: root.uiScale
                sy: root.uiScale
                text: root.playing ? "Pausar recorrido" : "Reproducir recorrido"
                onClicked: root.playing = !root.playing
            }
            BotonSecundario {
                Layout.preferredWidth: 120 * root.uiScale
                Layout.fillHeight: true
                sx: root.uiScale
                sy: root.uiScale
                text: "Reiniciar"
                onClicked: { root.playing = false; root.goToStep(0) }
            }
            BotonPrincipal {
                Layout.preferredWidth: 195 * root.uiScale
                Layout.fillHeight: true
                text: root.currentIndex === root.steps.length - 1
                      ? "Finalizar recorrido" : "Siguiente →"
                onClicked: {
                    if (root.currentIndex === root.steps.length - 1)
                        root.finishTour()
                    else
                        root.goToStep(root.currentIndex + 1)
                }
            }
        }
    }
}
