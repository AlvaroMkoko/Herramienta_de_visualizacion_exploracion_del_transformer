pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root
    objectName: "evaluationScreen"

    property string assessmentType: "pre"
    readonly property var evaluationController: mainViewModel.evaluationController
    readonly property var currentQuestion: evaluationController.currentQuestion
    readonly property bool showingResult: evaluationController.finished
    property string errorMessage: ""

    function returnToLearningPath() {
        if (root.stackView.depth >= 3)
            root.stackView.pop(root.stackView.get(root.stackView.depth - 3))
        else
            root.stackView.pop()
    }

    Component.onCompleted: {
        if (!evaluationController.isActive && !evaluationController.finished)
            evaluationController.startEvaluation(assessmentType)
    }

    Connections {
        target: root.evaluationController
        function onError(message) { root.errorMessage = message }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 70 * root.sx
        anchors.rightMargin: 70 * root.sx
        anchors.topMargin: 30 * root.sy
        anchors.bottomMargin: 34 * root.sy
        spacing: 18 * root.sy

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 68 * root.sy
            spacing: 18 * root.sx

            BotonPrincipal {
                objectName: "evaluationExitButton"
                Layout.preferredWidth: 190 * root.sx
                Layout.preferredHeight: 42 * root.sy
                text: "← Salir"
                onClicked: root.stackView.pop()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2 * root.sy
                Text {
                    text: root.evaluationController.eyebrow
                    color: Style.Theme.acento_fuerte
                    font.pixelSize: 11 * root.sx
                    font.bold: true
                    font.letterSpacing: 0.8
                }
                Text {
                    text: root.evaluationController.title
                    color: Style.Theme.texto_primario
                    font.pixelSize: 26 * root.sx
                    font.bold: true
                }
            }

            Text {
                visible: !root.showingResult
                text: "Pregunta " + root.evaluationController.currentQuestionNumber
                      + " de " + root.evaluationController.totalQuestions
                color: Style.Theme.texto_secundario_fuerte
                font.pixelSize: 13 * root.sx
                font.bold: true
            }
        }

        Rectangle {
            visible: !root.showingResult
            Layout.fillWidth: true
            Layout.preferredHeight: 10 * root.sy
            radius: height / 2
            color: Style.Theme.divisor

            Rectangle {
                width: parent.width * root.evaluationController.progressFraction
                height: parent.height
                radius: parent.radius
                color: Style.Theme.acento
                Behavior on width { NumberAnimation { duration: 180 } }
            }
        }

        RectanglePrincipal {
            objectName: "evaluationQuestionCard"
            visible: !root.showingResult
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumWidth: 1300 * root.sx
            Layout.alignment: Qt.AlignHCenter
            sx: root.sx
            sy: root.sy

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 30 * root.sx
                spacing: 14 * root.sy

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10 * root.sx

                    Rectangle {
                        Layout.preferredWidth: dimensionText.implicitWidth + 22 * root.sx
                        Layout.preferredHeight: 30 * root.sy
                        radius: height / 2
                        color: Style.Theme.acento_fondo
                        Text {
                            id: dimensionText
                            anchors.centerIn: parent
                            text: root.currentQuestion.dimension_id === "tokenizacion"
                                  ? "Tokenización"
                                  : "Embeddings y posición"
                            color: Style.Theme.acento_fuerte
                            font.pixelSize: 10 * root.sx
                            font.bold: true
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: bloomText.implicitWidth + 22 * root.sx
                        Layout.preferredHeight: 30 * root.sy
                        radius: height / 2
                        color: Style.Theme.info_fondo
                        Text {
                            id: bloomText
                            anchors.centerIn: parent
                            text: root.currentQuestion.bloom_level || ""
                            color: Style.Theme.info_texto
                            font.pixelSize: 10 * root.sx
                            font.bold: true
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.currentQuestion.code || ""
                        color: Style.Theme.texto_terciario
                        font.pixelSize: 12 * root.sx
                        font.bold: true
                    }
                }

                Text {
                    objectName: "evaluationQuestionPrompt"
                    Layout.fillWidth: true
                    text: root.currentQuestion.prompt || ""
                    color: Style.Theme.texto_primario
                    font.pixelSize: 22 * root.sx
                    font.bold: true
                    lineHeight: 1.18
                    wrapMode: Text.WordWrap
                }

                Text {
                    text: "Selecciona una respuesta:"
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 12 * root.sx
                }

                Repeater {
                    id: optionsRepeater
                    objectName: "evaluationOptionsRepeater"
                    model: root.currentQuestion.options || []
                    delegate: Button {
                        id: optionButton
                        required property var modelData
                        readonly property bool selected:
                            root.evaluationController.selectedOptionId === modelData.id
                        objectName: "evaluationOption_" + modelData.id
                        Layout.fillWidth: true
                        Layout.preferredHeight: 68 * root.sy
                        hoverEnabled: true
                        focusPolicy: Qt.StrongFocus
                        Accessible.name: modelData.id.toUpperCase() + ". " + modelData.text
                        onClicked: root.evaluationController.selectAnswer(modelData.id)

                        background: Rectangle {
                            radius: 10 * root.sx
                            color: optionButton.selected
                                   ? Style.Theme.acento_fondo
                                   : (optionButton.hovered
                                      ? Style.Theme.superficie_alterna
                                      : Style.Theme.surface)
                            border.width: optionButton.selected ? 2 : 1
                            border.color: optionButton.selected
                                          ? Style.Theme.acento
                                          : Style.Theme.borde_medio
                        }

                        contentItem: RowLayout {
                            spacing: 13 * root.sx
                            Rectangle {
                                Layout.preferredWidth: 32 * root.sx
                                Layout.preferredHeight: 32 * root.sy
                                radius: width / 2
                                color: optionButton.selected
                                       ? Style.Theme.acento
                                       : Style.Theme.chip_fondo
                                border.color: optionButton.selected
                                              ? Style.Theme.acento
                                              : Style.Theme.chip_borde
                                Text {
                                    anchors.centerIn: parent
                                    text: optionButton.modelData.id.toUpperCase()
                                    color: optionButton.selected
                                           ? Style.Theme.texto_sobre_color
                                           : Style.Theme.texto_secundario_fuerte
                                    font.pixelSize: 12 * root.sx
                                    font.bold: true
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: optionButton.modelData.text
                                color: Style.Theme.texto_primario
                                font.pixelSize: 14 * root.sx
                                wrapMode: Text.WordWrap
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12 * root.sx

                    Text {
                        Layout.fillWidth: true
                        text: root.evaluationController.canContinue
                              ? "Respuesta seleccionada"
                              : "Selecciona una opción para continuar"
                        color: root.evaluationController.canContinue
                               ? Style.Theme.exito_texto
                               : Style.Theme.texto_secundario
                        font.pixelSize: 11 * root.sx
                    }

                    BotonPrincipal {
                        objectName: "evaluationNextButton"
                        Layout.preferredWidth: 250 * root.sx
                        Layout.preferredHeight: 48 * root.sy
                        minimum_text_size: 11
                        enabled: root.evaluationController.canContinue
                        opacity: enabled ? 1 : 0.45
                        text: root.evaluationController.currentQuestionNumber
                              === root.evaluationController.totalQuestions
                              ? "Finalizar evaluación"
                              : "Guardar y continuar →"
                        onClicked: root.evaluationController.submitCurrentAnswer()
                    }
                }

                Text {
                    visible: root.errorMessage !== ""
                    Layout.fillWidth: true
                    text: root.errorMessage
                    color: Style.Theme.error_texto
                    wrapMode: Text.WordWrap
                }
            }
        }

        RectanglePrincipal {
            objectName: "evaluationResultCard"
            visible: root.showingResult
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumWidth: 1150 * root.sx
            Layout.alignment: Qt.AlignHCenter
            sx: root.sx
            sy: root.sy

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 34 * root.sx
                spacing: 17 * root.sy

                Text {
                    Layout.fillWidth: true
                    text: "Evaluación completada"
                    color: Style.Theme.texto_primario
                    font.pixelSize: 28 * root.sx
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    objectName: "evaluationScoreText"
                    Layout.fillWidth: true
                    text: (root.evaluationController.result.correct || 0) + " / "
                          + (root.evaluationController.result.total || 0)
                    color: Style.Theme.acento_fuerte
                    font.pixelSize: 48 * root.sx
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: (root.evaluationController.result.percentage || 0) + "% de respuestas correctas"
                    color: Style.Theme.texto_secundario_fuerte
                    font.pixelSize: 15 * root.sx
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: root.evaluationController.resultMessage
                    color: Style.Theme.texto_secundario_fuerte
                    font.pixelSize: 14 * root.sx
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "RESULTADO POR DIMENSIÓN"
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 10 * root.sx
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                Repeater {
                    model: root.evaluationController.result.dimensions || []
                    delegate: Rectangle {
                        id: resultDimension
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72 * root.sy
                        radius: 10 * root.sx
                        color: Style.Theme.superficie_alterna
                        border.color: Style.Theme.borde_medio

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14 * root.sx
                            spacing: 12 * root.sx
                            Text {
                                Layout.fillWidth: true
                                text: resultDimension.modelData.name
                                color: Style.Theme.texto_primario
                                font.pixelSize: 14 * root.sx
                                font.bold: true
                                wrapMode: Text.WordWrap
                            }
                            ProgressBar {
                                Layout.preferredWidth: 300 * root.sx
                                from: 0
                                to: 100
                                value: resultDimension.modelData.percentage
                            }
                            Text {
                                text: resultDimension.modelData.correct + "/"
                                      + resultDimension.modelData.total
                                color: Style.Theme.acento_fuerte
                                font.pixelSize: 15 * root.sx
                                font.bold: true
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 14 * root.sx

                    BotonPrincipal {
                        objectName: "evaluationRepeatButton"
                        Layout.preferredWidth: 240 * root.sx
                        Layout.preferredHeight: 48 * root.sy
                        text: "Repetir evaluación"
                        onClicked: root.evaluationController.startEvaluation(root.assessmentType)
                    }
                    BotonPrincipal {
                        objectName: "evaluationReturnHomeButton"
                        Layout.preferredWidth: 250 * root.sx
                        Layout.preferredHeight: 48 * root.sy
                        text: "Volver al flujo formativo"
                        onClicked: root.returnToLearningPath()
                    }
                }
            }
        }
    }
}
