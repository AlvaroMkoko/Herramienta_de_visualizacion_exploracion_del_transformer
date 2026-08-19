pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

Rectangle {
    id: root
    objectName: "guidedActivityCard"

    property var activity: ({})
    property int stage: 0
    property int selectedPrediction: -1
    property bool unitCompleted: false
    property real scaleFactor: 1.0

    signal predictionSelected(int optionIndex)
    signal observationRequested()
    signal explanationRequested()
    signal completionRequested(string explanation)

    function value(fieldName, fallbackValue) {
        if (!root.activity || root.activity[fieldName] === undefined
                || root.activity[fieldName] === null)
            return fallbackValue
        return root.activity[fieldName]
    }

    function options() {
        return root.value("options", [])
    }

    function trace() {
        return root.value("trace", [])
    }

    function predictionFeedback() {
        if (root.selectedPrediction < 0)
            return ""
        return root.selectedPrediction === Number(root.value("correctIndex", -1))
                ? root.value("correctFeedback", "Tu predicción coincide con la observación.")
                : root.value("revisionFeedback", "Contrasta tu predicción con la observación.")
    }

    radius: 14 * scaleFactor
    color: Style.Theme.surface
    border.width: 1
    border.color: stage === 3 ? "#86D1B4" : "#D8D2EC"
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16 * root.scaleFactor
        spacing: 10 * root.scaleFactor

        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * root.scaleFactor

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2 * root.scaleFactor

                Text {
                    Layout.fillWidth: true
                    text: "Actividad de la unidad"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 17 * root.scaleFactor
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }

                Text {
                    Layout.fillWidth: true
                    text: "Predice, observa y explica"
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 11 * root.scaleFactor
                }
            }

            Rectangle {
                Layout.preferredWidth: 28 * root.scaleFactor
                Layout.preferredHeight: 28 * root.scaleFactor
                radius: width / 2
                color: root.unitCompleted ? "#E5F7EF" : "#F0ECFA"

                Text {
                    anchors.centerIn: parent
                    text: root.unitCompleted ? "✓" : "?"
                    color: root.unitCompleted ? "#187455" : "#6254B8"
                    font.bold: true
                    font.pixelSize: 13 * root.scaleFactor
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 5 * root.scaleFactor

            Repeater {
                model: ["Predecir", "Observar", "Explicar"]

                delegate: Rectangle {
                    id: stageDelegate
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: 25 * root.scaleFactor
                    radius: height / 2
                    color: root.stage > stageDelegate.index || root.stage === 3
                           ? "#E5F7EF"
                           : root.stage === stageDelegate.index ? "#EDE8FA" : "#F3F4F6"
                    border.color: root.stage === stageDelegate.index ? "#A99BDD" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: stageDelegate.modelData
                        color: root.stage > stageDelegate.index || root.stage === 3
                               ? "#187455"
                               : root.stage === stageDelegate.index ? "#5946A3" : "#7A8290"
                        font.bold: root.stage === stageDelegate.index
                        font.pixelSize: 9 * root.scaleFactor
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#E8E4F1"
        }

        ScrollView {
            id: activityScroll
            objectName: "guidedActivityScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            Column {
                width: activityScroll.availableWidth
                spacing: 10 * root.scaleFactor

                Column {
                    visible: root.stage === 0
                    width: parent.width
                    spacing: 9 * root.scaleFactor

                    Text {
                        width: parent.width
                        text: "ANTES DE REVELAR"
                        color: "#8B651D"
                        font.bold: true
                        font.pixelSize: 10 * root.scaleFactor
                    }

                    Text {
                        width: parent.width
                        text: String(root.value("question", ""))
                        color: Style.Theme.texto_primario
                        font.pixelSize: 13 * root.scaleFactor
                        font.bold: true
                        lineHeight: 1.15
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: root.options()

                        delegate: Button {
                            id: optionDelegate
                            required property var modelData
                            required property int index
                            objectName: "guidedPredictionOption" + optionDelegate.index
                            width: parent.width
                            height: Math.max(42 * root.scaleFactor,
                                             optionText.implicitHeight + 18 * root.scaleFactor)
                            activeFocusOnTab: true
                            Accessible.name: "Opción " + (index + 1) + ": " + String(modelData)
                            Accessible.description: "Selecciona esta predicción"

                            background: Rectangle {
                                radius: 8 * root.scaleFactor
                                color: root.selectedPrediction === optionDelegate.index
                                       ? "#EDE8FA" : optionDelegate.hovered ? "#F7F5FC" : "#FFFFFF"
                                border.width: root.selectedPrediction === optionDelegate.index ? 2 : 1
                                border.color: root.selectedPrediction === optionDelegate.index
                                              ? "#7462C8" : "#D8DCE5"
                            }

                            contentItem: Text {
                                id: optionText
                                text: String(optionDelegate.modelData)
                                color: Style.Theme.texto_primario
                                font.pixelSize: 11 * root.scaleFactor
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 10 * root.scaleFactor
                                rightPadding: 8 * root.scaleFactor
                            }

                            onClicked: root.predictionSelected(index)
                        }
                    }

                    Button {
                        id: revealButton
                        objectName: "guidedObserveButton"
                        width: parent.width
                        height: 40 * root.scaleFactor
                        enabled: root.selectedPrediction >= 0
                        text: "Observar resultado"
                        activeFocusOnTab: true
                        Accessible.name: text
                        Accessible.description: enabled
                                                ? "Revela la observación de esta actividad"
                                                : "Selecciona primero una predicción"

                        background: Rectangle {
                            radius: 8 * root.scaleFactor
                            color: !revealButton.enabled ? "#ECEEF2"
                                   : revealButton.down ? "#51429D" : "#6856BA"
                        }

                        contentItem: Text {
                            text: revealButton.text
                            color: revealButton.enabled ? "#FFFFFF" : "#9399A5"
                            font.bold: true
                            font.pixelSize: 11 * root.scaleFactor
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: root.observationRequested()
                    }
                }

                Column {
                    visible: root.stage === 1
                    width: parent.width
                    spacing: 10 * root.scaleFactor

                    Rectangle {
                        id: observationPanel
                        objectName: "guidedObservationPanel"
                        width: parent.width
                        height: observationColumn.implicitHeight + 22 * root.scaleFactor
                        radius: 9 * root.scaleFactor
                        color: "#F1F8FC"
                        border.color: "#B9D9EA"

                        Column {
                            id: observationColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 11 * root.scaleFactor
                            spacing: 7 * root.scaleFactor

                            Text {
                                width: parent.width
                                text: "OBSERVACIÓN SIN MODELO NI DATASET"
                                color: "#2F7194"
                                font.bold: true
                                font.pixelSize: 9 * root.scaleFactor
                            }

                            GuidedDemoVisualization {
                                width: parent.width
                                visualType: String(root.value("visualType", "pipeline"))
                                scaleFactor: root.scaleFactor
                            }

                            Repeater {
                                model: root.trace()

                                delegate: RowLayout {
                                    id: traceDelegate
                                    required property var modelData
                                    required property int index
                                    width: parent.width
                                    spacing: 7 * root.scaleFactor

                                    Rectangle {
                                        Layout.preferredWidth: 21 * root.scaleFactor
                                        Layout.preferredHeight: 21 * root.scaleFactor
                                        radius: 6 * root.scaleFactor
                                        color: traceDelegate.index === root.trace().length - 1
                                               ? "#DDF3EA" : "#E3EEF7"

                                        Text {
                                            anchors.centerIn: parent
                                            text: String(traceDelegate.index + 1)
                                            color: "#2C6786"
                                            font.bold: true
                                            font.pixelSize: 9 * root.scaleFactor
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: String(traceDelegate.modelData)
                                        color: Style.Theme.texto_primario
                                        font.pixelSize: 10 * root.scaleFactor
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                text: String(root.value("observation", ""))
                                color: "#315F78"
                                font.pixelSize: 11 * root.scaleFactor
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: root.predictionFeedback()
                        color: root.selectedPrediction === Number(root.value("correctIndex", -1))
                               ? "#187455" : "#8B651D"
                        font.pixelSize: 11 * root.scaleFactor
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    Button {
                        id: explainButton
                        objectName: "guidedExplainButton"
                        width: parent.width
                        height: 40 * root.scaleFactor
                        text: "Explicar con mis palabras"
                        activeFocusOnTab: true
                        Accessible.name: text
                        onClicked: root.explanationRequested()
                    }
                }

                Column {
                    visible: root.stage === 2
                    width: parent.width
                    spacing: 9 * root.scaleFactor

                    Text {
                        width: parent.width
                        text: "EXPLICA LO OBSERVADO"
                        color: "#5F4BAA"
                        font.bold: true
                        font.pixelSize: 10 * root.scaleFactor
                    }

                    Text {
                        width: parent.width
                        text: String(root.value("explanationPrompt", ""))
                        color: Style.Theme.texto_primario
                        font.pixelSize: 12 * root.scaleFactor
                        wrapMode: Text.WordWrap
                    }

                    TextArea {
                        id: explanationInput
                        objectName: "guidedExplanationInput"
                        width: parent.width
                        height: 118 * root.scaleFactor
                        placeholderText: "Escribe al menos una idea completa…"
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        activeFocusOnTab: true
                        Accessible.name: "Explicación de la actividad"
                        Accessible.description: String(root.value("explanationPrompt", ""))
                        background: Rectangle {
                            radius: 8 * root.scaleFactor
                            color: "#FFFFFF"
                            border.color: explanationInput.activeFocus ? "#7968CA" : "#C9CED8"
                            border.width: explanationInput.activeFocus ? 2 : 1
                        }
                    }

                    Text {
                        width: parent.width
                        text: explanationInput.text.trim().length < 12
                              ? "Escribe al menos 12 caracteres para continuar."
                              : "Tu explicación está lista para revisar."
                        color: explanationInput.text.trim().length < 12
                               ? Style.Theme.texto_secundario : "#187455"
                        font.pixelSize: 9 * root.scaleFactor
                        wrapMode: Text.WordWrap
                    }

                    Button {
                        id: completeButton
                        objectName: "guidedCompleteActivityButton"
                        width: parent.width
                        height: 40 * root.scaleFactor
                        enabled: explanationInput.text.trim().length >= 12
                        text: "Recibir retroalimentación"
                        activeFocusOnTab: true
                        Accessible.name: text
                        onClicked: root.completionRequested(explanationInput.text)
                    }
                }

                Rectangle {
                    id: feedbackPanel
                    objectName: "guidedFeedbackPanel"
                    visible: root.stage === 3
                    width: parent.width
                    height: visible ? feedbackColumn.implicitHeight + 24 * root.scaleFactor : 0
                    radius: 10 * root.scaleFactor
                    color: "#ECF8F2"
                    border.color: "#9BD5BD"

                    Column {
                        id: feedbackColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 12 * root.scaleFactor
                        spacing: 7 * root.scaleFactor

                        Text {
                            width: parent.width
                            text: "UNIDAD COMPLETADA"
                            color: "#187455"
                            font.bold: true
                            font.pixelSize: 10 * root.scaleFactor
                        }

                        Text {
                            width: parent.width
                            text: root.selectedPrediction < 0
                                  ? "Ya completaste esta actividad. Puedes repasar sus conceptos cuando quieras."
                                  : root.predictionFeedback()
                            color: "#245F4C"
                            font.pixelSize: 11 * root.scaleFactor
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            text: String(root.value("modelExplanation", ""))
                            color: "#315D50"
                            font.pixelSize: 11 * root.scaleFactor
                            lineHeight: 1.15
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            text: "Puedes comparar esta explicación con la tuya; no se califica la redacción."
                            color: "#527268"
                            font.italic: true
                            font.pixelSize: 9 * root.scaleFactor
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
