pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root
    objectName: "teacherDashboardScreen"

    readonly property var profileController: mainViewModel.profileController

    function newAssessment() {
        root.profileController.limpiarAlumnoActivo()
        root.stackView.push("StudentRegistrationScreen.qml", {
            "stackView": root.stackView
        })
    }

    FondoInicio {
        anchors.fill: parent
        intensidad: 0.56
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 34
        spacing: 18

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 112
            radius: 20
            color: Style.Theme.surface
            border.width: 1
            border.color: Style.Theme.borde_medio

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 6
                radius: 3
                color: Style.Theme.info
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 20
                spacing: 14

                BotonSecundario {
                    objectName: "teacherBackButton"
                    Layout.preferredWidth: root.width < 1100 ? 136 : 150
                    Layout.preferredHeight: 38
                    text: "← Cambiar perfil"
                    onClicked: root.stackView.pop()
                }

                Rectangle {
                    visible: root.width >= 1100
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: 15
                    color: Style.Theme.info_fondo
                    Text {
                        anchors.centerIn: parent
                        text: "P"
                        color: Style.Theme.info_texto
                        font.pixelSize: 21
                        font.bold: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "ESPACIO DOCENTE"
                        color: Style.Theme.info_texto
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.3
                    }
                    Text {
                        text: "Panel del profesor"
                        color: Style.Theme.texto_primario
                        font.pixelSize: root.width < 1100 ? 25 : 29
                        font.bold: true
                    }
                    Text {
                        text: "Seguimiento de pre-test y post-test por alumno"
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 13
                    }
                }

                BotonSecundario {
                    objectName: "teacherClassroomButton"
                    Layout.preferredWidth: root.width < 1100 ? 156 : 190
                    Layout.preferredHeight: 46
                    text: mainViewModel.classroomHostController.activa
                          ? "● Clase en red abierta" : "Clase en red"
                    onClicked: root.stackView.push("ClassroomSetupScreen.qml", {
                        "stackView": root.stackView
                    })
                }

                BotonPrincipal {
                    objectName: "teacherNewAssessmentButton"
                    Layout.preferredWidth: root.width < 1100 ? 180 : 210
                    Layout.preferredHeight: 46
                    text: "+ Aplicar evaluación"
                    onClicked: root.newAssessment()
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 14

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 94
                radius: 16
                color: Style.Theme.surface
                border.width: 1
                border.color: Style.Theme.borde_suave
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 5
                    radius: 3
                    color: Style.Theme.acento
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    Text {
                        text: String(root.profileController.studentCount)
                        color: Style.Theme.acento
                        font.pixelSize: 30
                        font.bold: true
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: "Alumnos con resultados"; color: Style.Theme.texto_primario; font.bold: true }
                        Text { text: "Identificados por matrícula"; color: Style.Theme.texto_secundario; font.pixelSize: 11 }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 94
                radius: 16
                color: Style.Theme.surface
                border.width: 1
                border.color: Style.Theme.borde_suave
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 5
                    radius: 3
                    color: Style.Theme.info
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    Text {
                        text: String(root.profileController.resultCount)
                        color: Style.Theme.info
                        font.pixelSize: 30
                        font.bold: true
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: "Evaluaciones guardadas"; color: Style.Theme.texto_primario; font.bold: true }
                        Text { text: "Intentos de pre-test y post-test"; color: Style.Theme.texto_secundario; font.pixelSize: 11 }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 20
            color: Style.Theme.surface
            border.width: 1
            border.color: Style.Theme.borde_cuadro

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Alumnos evaluados"
                        color: Style.Theme.texto_primario
                        font.pixelSize: 18
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "Pre-test   ·   Post-test   ·   Cambio"
                        color: Style.Theme.texto_terciario
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    visible: root.profileController.studentCount === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: Style.Theme.superficie_alterna
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.min(460, parent.width - 40)
                        spacing: 10
                        Text {
                            Layout.fillWidth: true
                            text: "Aún no hay alumnos evaluados"
                            color: Style.Theme.texto_primario
                            font.pixelSize: 20
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Pulsa “Aplicar evaluación”, registra los datos del alumno y completa su primer test."
                            color: Style.Theme.texto_secundario
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                ListView {
                    id: studentsList
                    objectName: "teacherStudentsList"
                    visible: root.profileController.studentCount > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 10
                    model: root.profileController.students
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        id: studentRow
                        required property var modelData
                        width: studentsList.width
                        height: 126
                        radius: 11
                        color: Style.Theme.superficie_alterna
                        border.width: 1
                        border.color: Style.Theme.borde_suave

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 18

                            Rectangle {
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 46
                                radius: 23
                                color: Style.Theme.acento_fondo
                                Text {
                                    anchors.centerIn: parent
                                    text: String(studentRow.modelData.nombre || "A").charAt(0).toUpperCase()
                                    color: Style.Theme.acento
                                    font.pixelSize: 19
                                    font.bold: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                Text {
                                    Layout.fillWidth: true
                                    text: studentRow.modelData.nombre
                                    color: Style.Theme.texto_primario
                                    font.pixelSize: 16
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "ID: " + (studentRow.modelData.matricula || "—")
                                          + (studentRow.modelData.grupo ? "  ·  Grupo: " + studentRow.modelData.grupo : "")
                                    color: Style.Theme.texto_secundario
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: studentRow.modelData.status + "  ·  " + studentRow.modelData.tests_count + " intento(s)"
                                    color: Style.Theme.texto_terciario
                                    font.pixelSize: 11
                                }
                            }

                            ColumnLayout {
                                Layout.preferredWidth: 92
                                spacing: 2
                                Text { text: "PRE-TEST"; color: Style.Theme.texto_terciario; font.pixelSize: 10; font.bold: true }
                                Text {
                                    text: studentRow.modelData.pre_completed ? studentRow.modelData.pre_percentage + "%" : "Pendiente"
                                    color: studentRow.modelData.pre_completed ? Style.Theme.info_texto : Style.Theme.texto_terciario
                                    font.pixelSize: 17
                                    font.bold: true
                                }
                            }

                            ColumnLayout {
                                Layout.preferredWidth: 92
                                spacing: 2
                                Text { text: "POST-TEST"; color: Style.Theme.texto_terciario; font.pixelSize: 10; font.bold: true }
                                Text {
                                    text: studentRow.modelData.post_completed ? studentRow.modelData.post_percentage + "%" : "Pendiente"
                                    color: studentRow.modelData.post_completed ? Style.Theme.acento : Style.Theme.texto_terciario
                                    font.pixelSize: 17
                                    font.bold: true
                                }
                            }

                            ColumnLayout {
                                Layout.preferredWidth: 82
                                visible: studentRow.modelData.comparable
                                spacing: 2
                                Text { text: "CAMBIO"; color: Style.Theme.texto_terciario; font.pixelSize: 10; font.bold: true }
                                Text {
                                    text: (studentRow.modelData.improvement > 0 ? "+" : "") + studentRow.modelData.improvement + " pts"
                                    color: studentRow.modelData.improvement >= 0 ? Style.Theme.success : Style.Theme.error
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                            }

                            BotonSecundario {
                                objectName: "studentAnalysisButton"
                                Layout.preferredWidth: 110
                                Layout.preferredHeight: 38
                                text: "Ver análisis"
                                onClicked: root.stackView.push("StudentAnalysisScreen.qml", {
                                    "stackView": root.stackView,
                                    "studentId": studentRow.modelData.id
                                })
                            }
                        }
                    }
                }
            }
        }
    }
}
