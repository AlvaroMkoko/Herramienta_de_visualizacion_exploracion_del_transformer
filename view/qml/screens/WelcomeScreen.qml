pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root
    objectName: "welcomeScreen"

    readonly property real pageMargin: Math.max(20, Math.min(40, width * 0.032))

    // ─────────────────────────────────────────────────────────────
    // CONFIGURACIÓN: si es true, el laboratorio queda bloqueado hasta
    // completar el recorrido guiado, igual que en HomeScreen. Ponerlo en
    // false abre el acceso directo (útil en desarrollo y demostraciones).
    //
    // Debe coincidir con `requireGuidedBeforeLabs` de HomeScreen: si aquí
    // fuera false y allá true, esta pantalla sería una puerta trasera al
    // laboratorio que el resto de la aplicación intenta bloquear.
    readonly property bool requireGuidedBeforeLabs: false
    // ─────────────────────────────────────────────────────────────

    readonly property var learningController: (typeof mainViewModel !== "undefined"
                                               && mainViewModel
                                               && mainViewModel.learningController)
                                              ? mainViewModel.learningController
                                              : null
    property int guidedProgressRevision: 0

    readonly property int completedUnitsCount: {
        var dependency = root.guidedProgressRevision
        return root.learningController
               ? Number(root.learningController.completedUnitsCount) : 0
    }
    readonly property int totalUnitsCount: root.learningController
                                           ? Number(root.learningController.totalUnits) : 0
    readonly property bool guidedCompleted: totalUnitsCount > 0
                                            && completedUnitsCount >= totalUnitsCount
    readonly property bool labsUnlocked: !root.requireGuidedBeforeLabs || root.guidedCompleted
    readonly property bool learningStarted: completedUnitsCount > 0

    Connections {
        target: root.learningController
        ignoreUnknownSignals: true
        function onProgressChanged() { root.guidedProgressRevision += 1 }
    }

    function abrirRuta() {
        root.stackView.push("HomeScreen.qml", { "stackView": root.stackView })
    }

    function abrirLaboratorio(pantalla) {
        if (!root.labsUnlocked)
            return
        root.stackView.push(pantalla, { "stackView": root.stackView })
    }

    ScrollView {
        id: pageScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            width: pageScroll.availableWidth
            spacing: 16

            Item { Layout.fillWidth: true; Layout.preferredHeight: 40 }

            // ── Encabezado ──────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: root.pageMargin
                Layout.rightMargin: root.pageMargin
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Herramienta de Visualización del Transformer"
                    color: Style.Theme.texto_primario
                    font.pixelSize: Math.max(26, Math.min(38, root.width * 0.03))
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Accessible.name: text
                }

                Text {
                    Layout.fillWidth: true
                    text: "Elige cómo quieres empezar."
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }

            Item { Layout.fillWidth: true; Layout.preferredHeight: 14 }

            // ── Las dos opciones ────────────────────────────────────
            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: root.pageMargin
                Layout.rightMargin: root.pageMargin
                // Una columna cuando la ventana es angosta, para que las
                // tarjetas no se compriman hasta volverse ilegibles.
                columns: root.width < 900 ? 1 : 2
                columnSpacing: 22
                rowSpacing: 22

                // ── Ruta de aprendizaje ─────────────────────────────
                Rectangle {
                    id: tarjetaRuta
                    objectName: "welcomeLearningCard"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 300
                    radius: 14
                    color: Style.Theme.surface
                    border.width: 1
                    border.color: Style.Theme.borde_cuadro

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 46
                            radius: 12
                            color: Style.Theme.acento_fondo
                            Text {
                                anchors.centerIn: parent
                                text: "◆"
                                color: Style.Theme.acento
                                font.family: Style.Theme.fuente_simbolos
                                font.pixelSize: 22
                                font.bold: true
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Ruta de aprendizaje"
                            color: Style.Theme.texto_primario
                            font.pixelSize: 21
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Recorrido guiado por la arquitectura, en orden: diagnóstico, "
                                  + "aprendizaje, práctica, evaluación y seguimiento."
                            color: Style.Theme.texto_secundario
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }

                        Item { Layout.fillHeight: true }

                        // Progreso, solo si ya empezó
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.learningStarted
                            spacing: 5

                            Text {
                                text: root.completedUnitsCount + " de " + root.totalUnitsCount + " unidades"
                                color: Style.Theme.texto_terciario
                                font.pixelSize: 11
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 6
                                radius: 3
                                color: Style.Theme.divisor
                                Rectangle {
                                    width: root.totalUnitsCount > 0
                                           ? parent.width * (root.completedUnitsCount / root.totalUnitsCount)
                                           : 0
                                    height: parent.height
                                    radius: 3
                                    color: Style.Theme.acento
                                }
                            }
                        }

                        Button {
                            id: botonRuta
                            objectName: "welcomeLearningButton"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42
                            focusPolicy: Qt.StrongFocus
                            text: root.learningStarted ? "Continuar recorrido" : "Comenzar recorrido"
                            Accessible.description: "Abre la ruta de aprendizaje"
                            onClicked: root.abrirRuta()

                            background: Rectangle {
                                radius: 9
                                color: botonRuta.down
                                       ? Style.Theme.acento_fuerte
                                       : (botonRuta.hovered ? Style.Theme.acento_fuerte : Style.Theme.acento)
                            }
                            contentItem: Text {
                                text: botonRuta.text
                                color: Style.Theme.texto_sobre_color
                                font.pixelSize: 14
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                // ── Laboratorio ─────────────────────────────────────
                Rectangle {
                    id: tarjetaLab
                    objectName: "welcomeLabCard"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 300
                    radius: 14
                    color: Style.Theme.surface
                    border.width: 1
                    border.color: Style.Theme.borde_cuadro
                    opacity: root.labsUnlocked ? 1.0 : 0.62

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 46
                                radius: 12
                                color: Style.Theme.chip_fondo
                                Text {
                                    anchors.centerIn: parent
                                    text: root.labsUnlocked ? "▤" : "🔒"
                                    color: Style.Theme.chip_texto
                                    font.family: root.labsUnlocked
                                                 ? Style.Theme.fuente_simbolos
                                                 : Style.Theme.fuente_emoji
                                    font.pixelSize: 20
                                    font.bold: true
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                visible: !root.labsUnlocked
                                Layout.preferredWidth: bloqueoTexto.implicitWidth + 16
                                Layout.preferredHeight: 24
                                radius: 12
                                color: Style.Theme.aviso_fondo
                                Text {
                                    id: bloqueoTexto
                                    anchors.centerIn: parent
                                    text: "Bloqueado"
                                    color: Style.Theme.aviso_texto
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Laboratorio"
                            color: Style.Theme.texto_primario
                            font.pixelSize: 21
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.labsUnlocked
                                  ? "Entrena modelos propios, abre los que ya guardaste y compáralos entre sí."
                                  : "Completa el recorrido guiado para desbloquear el laboratorio."
                            color: Style.Theme.texto_secundario
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }

                        Item { Layout.fillHeight: true }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 7

                            Button {
                                id: botonEntrenar
                                objectName: "welcomeTrainingButton"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                text: "Entrenar / configurar"
                                focusPolicy: Qt.StrongFocus
                                enabled: root.labsUnlocked
                                Accessible.description: "Abre el laboratorio de configuración y entrenamiento"
                                onClicked: root.abrirLaboratorio("SetupScreen.qml")
                                background: Rectangle {
                                    radius: 8
                                    color: botonEntrenar.down
                                           ? Style.Theme.boton_presionado
                                           : (botonEntrenar.hovered ? Style.Theme.acento_fondo : Style.Theme.boton)
                                    border.width: 1
                                    border.color: Style.Theme.borde_boton
                                }

                                
                                contentItem: Text {
                                    text: botonEntrenar.text
                                    color: Style.Theme.texto_primario
                                    font.pixelSize: 13
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                            }

                            Button {
                                id: botonAbrir
                                objectName: "welcomeLibraryButton"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                text: "Abrir modelo"
                                focusPolicy: Qt.StrongFocus
                                enabled: root.labsUnlocked
                                Accessible.description: "Abre la biblioteca de modelos"
                                onClicked: root.abrirLaboratorio("ModelLibraryScreen.qml")
                                background: Rectangle {
                                    radius: 8
                                    color: botonAbrir.down
                                           ? Style.Theme.boton_presionado
                                           : (botonAbrir.hovered ? Style.Theme.acento_fondo : Style.Theme.boton)
                                    border.width: 1
                                    border.color: Style.Theme.borde_boton
                                }

                                contentItem: Text {
                                    text: botonAbrir.text
                                    color: Style.Theme.texto_primario
                                    font.pixelSize: 13
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                            }

                            Button {
                                id: botonComparar
                                objectName: "welcomeComparisonButton"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                text: "Comparar modelos"
                                focusPolicy: Qt.StrongFocus
                                enabled: root.labsUnlocked
                                Accessible.description: "Abre el laboratorio de comparación"
                                onClicked: root.abrirLaboratorio("ComparisonScreen.qml")
                                background: Rectangle {
                                    radius: 8
                                    color: botonComparar.down
                                           ? Style.Theme.boton_presionado
                                           : (botonComparar.hovered ? Style.Theme.acento_fondo : Style.Theme.boton)
                                    border.width: 1
                                    border.color: Style.Theme.borde_boton
                                }
                                contentItem: Text {
                                    text: botonComparar.text
                                    color: Style.Theme.texto_primario
                                    font.pixelSize: 13
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true; Layout.preferredHeight: 10 }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: root.pageMargin
                Layout.rightMargin: root.pageMargin
                text: "La ruta de aprendizaje también da acceso al laboratorio en su etapa correspondiente."
                color: Style.Theme.texto_terciario
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillWidth: true; Layout.preferredHeight: 24 }
        }
    }
}
