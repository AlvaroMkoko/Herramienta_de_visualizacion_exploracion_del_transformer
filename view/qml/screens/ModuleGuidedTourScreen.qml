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

    // Predecir antes de ver: el resultado del paso se revela al intentar su
    // comprobación, y el paso cuenta como trabajado sólo entonces.
    property var guidedProgress: ({})
    property var checkResults: ({})
    readonly property bool currentHasCheck: root.currentStep.check !== undefined
    readonly property bool currentAttempted: root.stepAttempted(String(root.currentStep.id || ""))
    readonly property int maxReachableIndex: root.firstPendingIndex()
    readonly property var currentConceptDefinition: root.conceptDefinition(
                                                        String(root.currentStep.concept_id || ""))
    readonly property bool currentIsFocus: (root.guidedProgress.focus_step_ids || [])
                                           .indexOf(String(root.currentStep.id || "")) !== -1
    property string finishMessage: ""

    Component.onCompleted: {
        root.courseController.selectModule(root.moduleId)
        // Entrar cierra el pre-test del módulo (ver CourseController).
        root.courseController.enterGuidedTour(root.moduleId)
        root.refreshProgress()
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
            // La reproducción se detiene en cada predicción pendiente: avanzar
            // sola convertiría el recorrido otra vez en lectura pasiva.
            if (!root.currentAttempted)
                root.playing = false
            else if (root.currentIndex < root.steps.length - 1)
                root.goToStep(root.currentIndex + 1)
            else
                root.playing = false
        }
    }

    function refreshProgress() {
        root.guidedProgress = root.courseController.guidedProgress(root.moduleId) || ({})
    }

    function stepAttempted(stepId) {
        if (stepId.length === 0)
            return false
        var step = null
        for (var index = 0; index < root.steps.length; ++index) {
            if (String(root.steps[index].id) === stepId)
                step = root.steps[index]
        }
        if (step && step.check === undefined)
            return true
        if (root.checkResults[stepId] !== undefined)
            return true
        return (root.guidedProgress.attempted || []).indexOf(stepId) !== -1
    }

    function firstPendingIndex() {
        for (var index = 0; index < root.steps.length; ++index) {
            if (!root.stepAttempted(String(root.steps[index].id || "")))
                return index
        }
        return Math.max(0, root.steps.length - 1)
    }

    function conceptDefinition(conceptId) {
        var concepts = root.moduleData.concepts || []
        for (var index = 0; index < concepts.length; ++index) {
            if (String(concepts[index].id) === conceptId)
                return concepts[index]
        }
        return ({})
    }

    function submitCheck(optionIndex) {
        var stepId = String(root.currentStep.id || "")
        var result = root.courseController.recordGuidedCheck(root.moduleId, stepId, optionIndex)
        if (!result || result.correct === undefined)
            return
        var copy = Object.assign({}, root.checkResults)
        copy[stepId] = result
        root.checkResults = copy
        root.refreshProgress()
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
        // Hacia atrás siempre se puede; hacia adelante, sólo hasta la primera
        // predicción sin intentar.
        root.currentIndex = Math.max(0, Math.min(index, root.maxReachableIndex,
                                                 root.steps.length - 1))
    }

    function finishTour() {
        root.playing = false
        if (!root.courseController.completeGuidedTour(root.moduleId)) {
            var pending = (root.courseController.guidedProgress(root.moduleId).pending || []).length
            root.finishMessage = "Te faltan " + pending
                                 + " predicciones por intentar antes de terminar el recorrido."
            return
        }
        root.finishMessage = ""
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
                Text {
                    objectName: "moduleGuidedAnchorQuestion"
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: (root.moduleData.anchor && root.moduleData.anchor.question)
                          ? "Pregunta del módulo: " + root.moduleData.anchor.question : ""
                    color: Style.Theme.concepto_texto
                    font.pixelSize: 11 * root.uiScale
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
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
                        readonly property bool attempted: root.stepAttempted(
                                                              String(stepChip.modelData.id || ""))
                        readonly property bool reachable: stepChip.index <= root.maxReachableIndex
                        // El pre-test señaló este concepto como débil.
                        readonly property bool weakConcept: (root.guidedProgress.focus_step_ids || [])
                                                      .indexOf(String(stepChip.modelData.id || "")) !== -1
                        objectName: "moduleGuidedStepChip_" + stepChip.index
                        width: 146 * root.uiScale
                        height: 50 * root.uiScale
                        radius: 9 * root.uiScale
                        opacity: stepChip.reachable ? 1 : 0.45
                        color: index === root.currentIndex ? Style.Theme.acento
                               : (stepChip.attempted
                                  ? Style.Theme.exito_fondo : Style.Theme.chip_fondo)
                        border.width: stepChip.weakConcept ? 2 : 1
                        border.color: index === root.currentIndex
                                      ? Style.Theme.acento_alt
                                      : (stepChip.weakConcept ? Style.Theme.warning : Style.Theme.borde_suave)

                        Text {
                            anchors.fill: parent
                            anchors.margins: 7 * root.uiScale
                            text: (stepChip.weakConcept ? "★ " : "")
                                  + (stepChip.index + 1) + ". " + stepChip.modelData.title
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

                                // Definición oficial del concepto: es la misma
                                // redacción que usan los reactivos básicos.
                                Rectangle {
                                    objectName: "moduleGuidedDefinition"
                                    Layout.fillWidth: true
                                    visible: String(root.currentConceptDefinition.description || "").length > 0
                                    Layout.preferredHeight: definitionText.implicitHeight + 14 * root.uiScale
                                    radius: 8 * root.uiScale
                                    color: Style.Theme.concepto_fondo
                                    Text {
                                        id: definitionText
                                        anchors.fill: parent
                                        anchors.margins: 7 * root.uiScale
                                        text: "DEFINICIÓN · " + String(root.currentConceptDefinition.title || "")
                                              + ": " + String(root.currentConceptDefinition.description || "")
                                        color: Style.Theme.concepto_texto
                                        font.pixelSize: 10 * root.uiScale
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: root.currentIsFocus
                                    text: "★ En el pre-test fallaste reactivos de este concepto: tómate tu tiempo en este paso."
                                    color: Style.Theme.aviso_texto
                                    font.pixelSize: 10 * root.uiScale
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                }

                                PredictionCheck {
                                    id: stepCheck
                                    objectName: "moduleGuidedCheck"
                                    Layout.fillWidth: true
                                    visible: root.currentHasCheck
                                    sx: root.uiScale
                                    eyebrow: "PREDICE ANTES DE VER EL RESULTADO"
                                    check: root.currentStep.check || ({})
                                    result: root.checkResults[String(root.currentStep.id || "")] || ({})
                                    onSubmitted: function(optionIndex) { root.submitCheck(optionIndex) }
                                }

                                Connections {
                                    target: root
                                    function onCurrentIndexChanged() { stepCheck.selectedIndex = -1 }
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    rowSpacing: 7 * root.uiScale
                                    columnSpacing: 7 * root.uiScale

                                    Repeater {
                                        // CAMBIO y RESULTADO se revelan después
                                        // de predecir; antes darían la respuesta.
                                        model: [
                                            { "label": "ENTRADA", "value": root.currentStep.input || "", "fill": Style.Theme.concepto_fondo, "ink": Style.Theme.concepto_texto },
                                            { "label": "OPERACIÓN", "value": root.currentStep.operation || "", "fill": Style.Theme.formula_fondo, "ink": Style.Theme.formula_texto },
                                            { "label": "CAMBIO", "value": root.currentAttempted ? (root.currentStep.change || "") : "Se revela al comprobar tu predicción", "fill": Style.Theme.ejemplo_fondo, "ink": Style.Theme.ejemplo_texto },
                                            { "label": "RESULTADO", "value": root.currentAttempted ? (root.currentStep.output || "") : "Se revela al comprobar tu predicción", "fill": Style.Theme.proceso_fondo, "ink": Style.Theme.proceso_texto }
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
                objectName: "moduleGuidedNextButton"
                Layout.preferredWidth: 195 * root.uiScale
                Layout.fillHeight: true
                enabled: root.currentAttempted
                opacity: enabled ? 1 : 0.4
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

        Text {
            objectName: "moduleGuidedStatus"
            Layout.alignment: Qt.AlignHCenter
            text: root.finishMessage.length > 0 ? root.finishMessage
                  : (root.currentAttempted ? "" : "Responde la predicción del paso para continuar.")
            visible: text.length > 0
            color: root.finishMessage.length > 0 ? Style.Theme.aviso_texto : Style.Theme.texto_secundario
            font.pixelSize: 10 * root.uiScale
        }
    }
}
