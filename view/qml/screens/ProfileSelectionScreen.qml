pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root
    objectName: "profileSelectionScreen"

    readonly property var profileController: mainViewModel.profileController

    function openStudent() {
        root.profileController.seleccionarRol("student")
        root.stackView.push("HomeScreen.qml", { "stackView": root.stackView })
    }

    function openLaboratories() {
        root.profileController.seleccionarRol("student")
        root.stackView.push("WelcomeScreen.qml", { "stackView": root.stackView })
    }

    function openTeacher() {
        root.profileController.seleccionarRol("teacher")
        root.stackView.push("TeacherDashboardScreen.qml", { "stackView": root.stackView })
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(960, parent.width - 80)
        spacing: 28

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "Visualizador de Transformers"
                color: Style.Theme.texto_primario
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 36
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: "Selecciona cómo quieres utilizar la herramienta"
                color: Style.Theme.texto_secundario
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: root.width < 820 ? 1 : 2
            columnSpacing: 24
            rowSpacing: 20

            Rectangle {
                id: studentCard
                objectName: "studentProfileCard"
                Layout.fillWidth: true
                Layout.preferredHeight: 340
                radius: 16
                color: Style.Theme.surface
                border.width: studentHover.hovered ? 2 : 1
                border.color: studentHover.hovered ? Style.Theme.acento : Style.Theme.borde_cuadro

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 58
                        Layout.preferredHeight: 58
                        radius: 16
                        color: Style.Theme.acento_fondo
                        Text {
                            anchors.centerIn: parent
                            text: "E"
                            color: Style.Theme.acento
                            font.pixelSize: 26
                            font.bold: true
                        }
                    }
                    Text {
                        text: "Soy estudiante"
                        color: Style.Theme.texto_primario
                        font.pixelSize: 23
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Entra a la ruta de aprendizaje, realiza el pre-test, explora el recorrido y completa el post-test."
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                    }
                    Item { Layout.fillHeight: true }
                    BotonPrincipal {
                        objectName: "studentProfileButton"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        text: "Entrar al recorrido"
                        onClicked: root.openStudent()
                    }

                    BotonSecundario {
                        objectName: "studentLaboratoryButton"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        text: "Entrar al laboratorio"
                        onClicked: root.openLaboratories()
                    }
                }

                HoverHandler { id: studentHover }
            }

            Rectangle {
                id: teacherCard
                objectName: "teacherProfileCard"
                Layout.fillWidth: true
                Layout.preferredHeight: 340
                radius: 16
                color: Style.Theme.surface
                border.width: teacherArea.containsMouse ? 2 : 1
                border.color: teacherArea.containsMouse ? Style.Theme.info : Style.Theme.borde_cuadro

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 58
                        Layout.preferredHeight: 58
                        radius: 16
                        color: Style.Theme.info_fondo
                        Text {
                            anchors.centerIn: parent
                            text: "P"
                            color: Style.Theme.info_texto
                            font.pixelSize: 26
                            font.bold: true
                        }
                    }
                    Text {
                        text: "Soy profesor"
                        color: Style.Theme.texto_primario
                        font.pixelSize: 23
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Aplica evaluaciones, consulta a todos los alumnos y compara sus resultados de pre-test y post-test."
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                    }
                    Item { Layout.fillHeight: true }
                    BotonPrincipal {
                        objectName: "teacherProfileButton"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        text: "Abrir panel docente"
                        onClicked: root.openTeacher()
                    }
                }

                MouseArea {
                    id: teacherArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openTeacher()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Los resultados se guardan localmente en este equipo."
            color: Style.Theme.texto_terciario
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
