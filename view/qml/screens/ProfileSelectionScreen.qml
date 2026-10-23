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
            // El margen superior deja libre el menú global de preferencias
            // incluso en el tamaño mínimo de ventana.
            y: Math.max(64, (desplazamiento.height - implicitHeight) * 0.46)
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 24

                Image {
                    Layout.preferredWidth: 104
                    Layout.preferredHeight: 104
                    source: "../../assets/icono_grande.svg"
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    Accessible.role: Accessible.Graphic
                    Accessible.name: "Símbolo de Transformer Visualizer"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: "VISUALIZA  ·  EXPLORA  ·  COMPRENDE"
                        color: Style.Theme.acento_texto
                        font.family: Style.Theme.fuente_interfaz
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.7
                    }

                    Text {
                        objectName: "applicationNameText"
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        text: "Transformer Visualizer"
                        color: Style.Theme.texto_primario
                        font.family: Style.Theme.fuente_interfaz
                        font.pixelSize: Math.max(32, Math.min(44, root.width * 0.038))
                        font.bold: true
                        lineHeight: 1
                        wrapMode: Text.WordWrap
                        Accessible.role: Accessible.Heading
                    }

                    Text {
                        objectName: "projectTitleText"
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        text: "“Herramienta de visualización y exploración interactiva de una arquitectura tipo Transformer”"
                        color: Style.Theme.texto_secundario_fuerte
                        font.family: Style.Theme.fuente_interfaz
                        font.pixelSize: 15
                        lineHeight: 1.25
                        wrapMode: Text.WordWrap
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 14
                spacing: 8

                Repeater {
                    model: ["Ruta guiada", "Laboratorios interactivos", "Progreso local"]

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
                Layout.topMargin: 22
                text: "ELIGE CÓMO ENTRAR"
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
                    Layout.preferredHeight: 254

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
                            anchors.topMargin: 20
                            anchors.bottomMargin: 18
                            spacing: 0

                            RowLayout {
                                Layout.fillWidth: true

                                Rectangle {
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 44
                                    radius: 15
                                    color: Style.Theme.acento_fondo
                                    Text {
                                        anchors.centerIn: parent
                                        text: "E"
                                        color: Style.Theme.acento
                                        font.pixelSize: 21
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
                                Layout.topMargin: 12
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
                                Layout.topMargin: 9
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
                    Layout.preferredHeight: 254

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
                            anchors.topMargin: 20
                            anchors.bottomMargin: 18
                            spacing: 0

                            RowLayout {
                                Layout.fillWidth: true

                                Rectangle {
                                    Layout.preferredWidth: 44
                                    Layout.preferredHeight: 44
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
                                Layout.topMargin: 12
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
                                Layout.topMargin: 9
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
                Layout.topMargin: 16
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

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 34
                text: "CRÉDITOS DEL PROYECTO"
                color: Style.Theme.texto_terciario
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1.5
            }

            Rectangle {
                objectName: "institutionalHeader"
                Layout.fillWidth: true
                Layout.topMargin: 10
                Layout.preferredHeight: 76
                radius: 18
                color: Style.Theme.surface
                border.width: 1
                border.color: Style.Theme.borde_medio
                Accessible.role: Accessible.Grouping
                Accessible.name: "Instituto Politécnico Nacional, Escuela Superior de Cómputo"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    anchors.topMargin: 12
                    anchors.bottomMargin: 12
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 50
                        radius: 14
                        color: Style.Theme.modoOscuro ? "#8F365A" : "#6C1D45"

                        Text {
                            anchors.centerIn: parent
                            text: "IPN"
                            color: "#FFFFFF"
                            font.family: Style.Theme.fuente_interfaz
                            font.pixelSize: 15
                            font.bold: true
                            font.letterSpacing: 0.5
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            objectName: "institutionNameText"
                            Layout.fillWidth: true
                            text: "INSTITUTO POLITÉCNICO NACIONAL"
                            color: Style.Theme.texto_primario
                            font.family: Style.Theme.fuente_interfaz
                            font.pixelSize: 14
                            font.bold: true
                            font.letterSpacing: 0.9
                            elide: Text.ElideRight
                        }
                        Text {
                            objectName: "schoolNameText"
                            Layout.fillWidth: true
                            text: "ESCUELA SUPERIOR DE CÓMPUTO  ·  ESCOM"
                            color: Style.Theme.texto_secundario_fuerte
                            font.family: Style.Theme.fuente_interfaz
                            font.pixelSize: 12
                            font.bold: true
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 148
                        Layout.preferredHeight: 48
                        radius: 12
                        color: Style.Theme.acento_fondo
                        border.width: 1
                        border.color: Style.Theme.acento

                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "TRABAJO TERMINAL"
                                color: Style.Theme.acento_texto
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 0.8
                            }
                            Text {
                                objectName: "projectKeyText"
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "2026-B056"
                                color: Style.Theme.texto_primario
                                font.pixelSize: 17
                                font.bold: true
                            }
                        }
                    }
                }
            }

            Rectangle {
                objectName: "presentersPanel"
                Layout.fillWidth: true
                Layout.topMargin: 12
                Layout.preferredHeight: 78
                radius: 16
                color: Style.Theme.superficie_alterna
                border.width: 1
                border.color: Style.Theme.borde_suave
                Accessible.role: Accessible.Grouping
                Accessible.name: "Presentan: Martinez Contreras Leonardo; Salazar Bravo Alejandro Román; Velázquez Matus Álvaro Alexander"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    anchors.topMargin: 12
                    anchors.bottomMargin: 12
                    spacing: 18

                    ColumnLayout {
                        Layout.preferredWidth: 86
                        spacing: 2
                        Text {
                            text: "PRESENTAN"
                            color: Style.Theme.texto_terciario
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.2
                        }
                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 3
                            radius: 2
                            color: Style.Theme.acento
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        color: Style.Theme.divisor
                    }

                    Repeater {
                        model: [
                            "Martinez Contreras\nLeonardo",
                            "Salazar Bravo\nAlejandro Román",
                            "Velázquez Matus\nÁlvaro Alexander"
                        ]

                        Text {
                            required property string modelData
                            Layout.fillWidth: true
                            text: modelData
                            color: Style.Theme.texto_primario
                            font.family: Style.Theme.fuente_interfaz
                            font.pixelSize: 13
                            font.bold: true
                            lineHeight: 1.15
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
