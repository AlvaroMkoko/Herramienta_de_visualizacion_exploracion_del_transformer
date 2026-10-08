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
        root.stackView.push("WelcomeScreen.qml", { "stackView": root.stackView })
    }

    function openTeacher() {
        root.profileController.seleccionarRol("teacher")
        root.stackView.push("TeacherDashboardScreen.qml", { "stackView": root.stackView })
    }

    FondoInicio {
        anchors.fill: parent
        intensidad: 0.9
    }

    Flickable {
        id: desplazamiento
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, contenido.implicitHeight + 96)
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: contenido
            width: Math.min(1060, desplazamiento.width - 64)
            x: (desplazamiento.width - width) / 2
            y: Math.max(44, (desplazamiento.height - implicitHeight) * 0.46)
            spacing: 0

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 10
                    color: Style.Theme.acento

                    Text {
                        anchors.centerIn: parent
                        text: "T"
                        color: Style.Theme.texto_sobre_color
                        font.family: Style.Theme.fuente_interfaz
                        font.pixelSize: 17
                        font.bold: true
                    }
                }

                Text {
                    text: "TRANSFORMER LAB"
                    color: Style.Theme.acento_texto
                    font.family: Style.Theme.fuente_interfaz
                    font.pixelSize: 12
                    font.bold: true
                    font.letterSpacing: 1.8
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 14
                text: "Explora cómo aprende\nun Transformer"
                color: Style.Theme.texto_primario
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: Math.max(34, Math.min(46, root.width * 0.036))
                font.bold: true
                lineHeight: 0.98
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Accessible.role: Accessible.Heading
                Accessible.name: "Explora cómo aprende un Transformer"
            }

            Text {
                Layout.fillWidth: true
                Layout.maximumWidth: 660
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 12
                text: "Una experiencia visual para comprender la arquitectura, experimentar con modelos y observar tu progreso."
                color: Style.Theme.texto_secundario_fuerte
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 16
                lineHeight: 1.3
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 18
                spacing: 8

                Repeater {
                    model: ["Ruta guiada", "Laboratorios reales", "Progreso local"]

                    Rectangle {
                        required property string modelData
                        implicitWidth: etiqueta.implicitWidth + 24
                        implicitHeight: 28
                        radius: height / 2
                        color: Style.Theme.surface
                        border.width: 1
                        border.color: Style.Theme.borde_suave

                        Text {
                            id: etiqueta
                            anchors.centerIn: parent
                            text: "•  " + parent.modelData
                            color: Style.Theme.texto_secundario_fuerte
                            font.family: Style.Theme.fuente_interfaz
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 28
                text: "ELIGE TU EXPERIENCIA"
                color: Style.Theme.texto_terciario
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1.5
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10
                columns: root.width < 820 ? 1 : 2
                columnSpacing: 22
                rowSpacing: 18

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 294

                    Rectangle {
                        anchors.fill: studentCard
                        anchors.topMargin: 7
                        radius: studentCard.radius
                        color: Style.Theme.modoOscuro ? "#08080D" : "#CBD5E1"
                        opacity: Style.Theme.modoOscuro ? 0.38 : 0.42
                    }

                    Rectangle {
                        id: studentCard
                        AparicionSuave { objetivo: studentCard; orden: 0 }
                        objectName: "studentProfileCard"
                        anchors.fill: parent
                        anchors.bottomMargin: 7
                        radius: 20
                        color: Style.Theme.surface
                        border.width: studentHover.hovered ? 2 : 1
                        border.color: studentHover.hovered ? Style.Theme.acento : Style.Theme.borde_medio
                        scale: studentHover.hovered ? 1.008 : 1
                        transformOrigin: Item.Center
                        Accessible.role: Accessible.Grouping
                        Accessible.name: "Perfil de estudiante"
                        Accessible.description: "Ruta guiada, laboratorios y seguimiento del progreso"

                        Behavior on scale { NumberAnimation { duration: Style.Theme.duracionCorta; easing.type: Easing.OutCubic } }
                        Behavior on border.color { ColorAnimation { duration: Style.Theme.duracionCorta } }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 6
                            radius: 3
                            color: Style.Theme.acento
                        }

                        HoverHandler { id: studentHover; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openStudent()
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 30
                            anchors.rightMargin: 26
                            anchors.topMargin: 24
                            anchors.bottomMargin: 22
                            spacing: 0

                            RowLayout {
                                Layout.fillWidth: true

                                Rectangle {
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    radius: 15
                                    color: Style.Theme.acento_fondo
                                    Text {
                                        anchors.centerIn: parent
                                        text: "E"
                                        color: Style.Theme.acento
                                        font.pixelSize: 23
                                        font.bold: true
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    implicitWidth: alumnoTag.implicitWidth + 18
                                    implicitHeight: 25
                                    radius: height / 2
                                    color: Style.Theme.acento_fondo
                                    Text {
                                        id: alumnoTag
                                        anchors.centerIn: parent
                                        text: "APRENDER"
                                        color: Style.Theme.acento_texto
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.letterSpacing: 0.8
                                    }
                                }
                            }

                            Text {
                                Layout.topMargin: 16
                                text: "Soy estudiante"
                                color: Style.Theme.texto_primario
                                font.pixelSize: 23
                                font.bold: true
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                text: "Comprende la arquitectura paso a paso y pon a prueba cada concepto."
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 14
                                lineHeight: 1.25
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.topMargin: 12
                                text: "✓  Diagnóstico  ·  Ruta guiada  ·  Laboratorio"
                                color: Style.Theme.acento_texto
                                font.pixelSize: 12
                                font.bold: true
                                wrapMode: Text.WordWrap
                            }
                            Item { Layout.fillHeight: true }
                            BotonPrincipal {
                                objectName: "studentProfileButton"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                text: "Entrar como estudiante   →"
                                onClicked: root.openStudent()
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 294

                    Rectangle {
                        anchors.fill: teacherCard
                        anchors.topMargin: 7
                        radius: teacherCard.radius
                        color: Style.Theme.modoOscuro ? "#08080D" : "#CBD5E1"
                        opacity: Style.Theme.modoOscuro ? 0.38 : 0.42
                    }

                    Rectangle {
                        id: teacherCard
                        AparicionSuave { objetivo: teacherCard; orden: 1 }
                        objectName: "teacherProfileCard"
                        anchors.fill: parent
                        anchors.bottomMargin: 7
                        radius: 20
                        color: Style.Theme.surface
                        border.width: teacherHover.hovered ? 2 : 1
                        border.color: teacherHover.hovered ? Style.Theme.info : Style.Theme.borde_medio
                        scale: teacherHover.hovered ? 1.008 : 1
                        transformOrigin: Item.Center
                        Accessible.role: Accessible.Grouping
                        Accessible.name: "Perfil de profesor"
                        Accessible.description: "Evaluaciones, seguimiento de alumnos y comparativas"

                        Behavior on scale { NumberAnimation { duration: Style.Theme.duracionCorta; easing.type: Easing.OutCubic } }
                        Behavior on border.color { ColorAnimation { duration: Style.Theme.duracionCorta } }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 6
                            radius: 3
                            color: Style.Theme.info
                        }

                        HoverHandler { id: teacherHover; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openTeacher()
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 30
                            anchors.rightMargin: 26
                            anchors.topMargin: 24
                            anchors.bottomMargin: 22
                            spacing: 0

                            RowLayout {
                                Layout.fillWidth: true

                                Rectangle {
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    radius: 15
                                    color: Style.Theme.info_fondo
                                    Text {
                                        anchors.centerIn: parent
                                        text: "P"
                                        color: Style.Theme.info_texto
                                        font.pixelSize: 23
                                        font.bold: true
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    implicitWidth: docenteTag.implicitWidth + 18
                                    implicitHeight: 25
                                    radius: height / 2
                                    color: Style.Theme.info_fondo
                                    Text {
                                        id: docenteTag
                                        anchors.centerIn: parent
                                        text: "ACOMPAÑAR"
                                        color: Style.Theme.info_texto
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.letterSpacing: 0.8
                                    }
                                }
                            }

                            Text {
                                Layout.topMargin: 16
                                text: "Soy profesor"
                                color: Style.Theme.texto_primario
                                font.pixelSize: 23
                                font.bold: true
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                text: "Aplica evaluaciones y convierte los resultados de tu grupo en decisiones claras."
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 14
                                lineHeight: 1.25
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.topMargin: 12
                                text: "✓  Evaluaciones  ·  Seguimiento  ·  Comparativas"
                                color: Style.Theme.info_texto
                                font.pixelSize: 12
                                font.bold: true
                                wrapMode: Text.WordWrap
                            }
                            Item { Layout.fillHeight: true }
                            BotonPrincipal {
                                objectName: "teacherProfileButton"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                text: "Abrir panel docente   →"
                                onClicked: root.openTeacher()
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 20
                spacing: 7

                Text {
                    text: "●"
                    color: Style.Theme.success
                    font.pixelSize: 10
                }
                Text {
                    text: "Tus datos y resultados permanecen en este equipo."
                    color: Style.Theme.texto_terciario
                    font.pixelSize: 12
                }
            }
        }
    }
}
