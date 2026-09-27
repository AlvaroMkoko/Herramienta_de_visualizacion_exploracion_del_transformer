pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root
    objectName: "studentRegistrationScreen"

    readonly property var profileController: mainViewModel.profileController
    property string errorMessage: ""

    function continueToAssessment() {
        root.errorMessage = ""
        var registered = root.profileController.registrarAlumno(
            nameField.text,
            idField.text,
            groupField.text,
            ageField.text,
            emailField.text
        )
        if (!registered)
            return
        var assessment = assessmentSelector.currentIndex === 0 ? "pre" : "post"
        root.stackView.push("EvaluationIntroScreen.qml", {
            "stackView": root.stackView,
            "assessmentType": assessment
        })
    }

    Connections {
        target: root.profileController
        function onError(message) { root.errorMessage = message }
    }

    ScrollView {
        id: formScroll
        anchors.fill: parent
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: formScroll.availableWidth
            spacing: 18

            Item { Layout.fillWidth: true; Layout.preferredHeight: 24 }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 40
                Layout.rightMargin: 40
                BotonSecundario {
                    objectName: "studentRegistrationBackButton"
                    Layout.preferredWidth: 130
                    Layout.preferredHeight: 38
                    text: "← Volver"
                    onClicked: root.stackView.pop()
                }
                Item { Layout.fillWidth: true }
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(700, root.width - 80)
                Layout.preferredHeight: formColumn.implicitHeight + 56
                radius: 16
                color: Style.Theme.surface
                border.width: 1
                border.color: Style.Theme.borde_cuadro

                ColumnLayout {
                    id: formColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 28
                    spacing: 13

                    Text {
                        Layout.fillWidth: true
                        text: "Datos del alumno"
                        color: Style.Theme.texto_primario
                        font.pixelSize: 26
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Esta información se guardará junto con el resultado para poder comparar el pre-test y el post-test."
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }

                    Item { Layout.fillWidth: true; Layout.preferredHeight: 4 }

                    Text { text: "Nombre completo *"; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 12 }
                    CampoTextoPrincipal {
                        id: nameField
                        objectName: "studentNameField"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        placeholderText: "Ej. Ana López García"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: "Matrícula o identificador *"; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 12 }
                            CampoTextoPrincipal {
                                id: idField
                                objectName: "studentIdField"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 42
                                placeholderText: "Ej. A01234567"
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: "Grupo *"; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 12 }
                            CampoTextoPrincipal {
                                id: groupField
                                objectName: "studentGroupField"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 42
                                placeholderText: "Ej. 3° B"
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        ColumnLayout {
                            Layout.preferredWidth: 160
                            spacing: 6
                            Text { text: "Edad (opcional)"; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 12 }
                            CampoTextoPrincipal {
                                id: ageField
                                objectName: "studentAgeField"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 42
                                placeholderText: "Ej. 20"
                                inputMethodHints: Qt.ImhDigitsOnly
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: "Correo (opcional)"; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 12 }
                            CampoTextoPrincipal {
                                id: emailField
                                objectName: "studentEmailField"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 42
                                placeholderText: "alumno@escuela.edu"
                                inputMethodHints: Qt.ImhEmailCharactersOnly
                            }
                        }
                    }

                    Text { text: "Evaluación que se aplicará *"; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 12 }
                    SelectorPrincipal {
                        id: assessmentSelector
                        objectName: "assessmentTypeSelector"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        model: ["Pre-test (diagnóstico)", "Post-test (evaluación final)"]
                    }

                    Text {
                        visible: root.errorMessage !== ""
                        Layout.fillWidth: true
                        text: root.errorMessage
                        color: Style.Theme.error_texto
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }

                    BotonPrincipal {
                        objectName: "studentRegistrationContinueButton"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        text: "Continuar a la evaluación"
                        onClicked: root.continueToAssessment()
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "* Campos obligatorios. Usa siempre la misma matrícula para asociar ambas evaluaciones."
                        color: Style.Theme.texto_terciario
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Item { Layout.fillWidth: true; Layout.preferredHeight: 24 }
        }
    }
}
