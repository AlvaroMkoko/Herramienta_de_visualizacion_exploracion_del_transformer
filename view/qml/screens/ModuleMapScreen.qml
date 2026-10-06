pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root
    objectName: "moduleMapScreen"

    readonly property var courseController: mainViewModel.courseController

    function statusLabel(status) {
        switch (String(status)) {
        case "completed": return "Completado"
        case "review_recommended": return "Recomendado repasar"
        case "in_progress": return "En progreso"
        case "locked": return "Bloqueado"
        default: return "No iniciado"
        }
    }

    function statusColor(status) {
        switch (String(status)) {
        case "completed": return Style.Theme.exito_texto
        case "review_recommended": return Style.Theme.aviso_texto
        case "in_progress": return Style.Theme.acento_fuerte
        case "locked": return Style.Theme.texto_terciario
        default: return Style.Theme.texto_secundario
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 30 * root.sx
        spacing: 16 * root.sy

        RowLayout {
            Layout.fillWidth: true
            spacing: 16 * root.sx

            BotonPrincipal {
                objectName: "moduleMapBackButton"
                Layout.preferredWidth: 170 * root.sx
                Layout.preferredHeight: 44 * root.sy
                text: "← Volver"
                onClicked: root.stackView.pop()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: "CURSO INTERACTIVO PROGRESIVO"
                    color: Style.Theme.acento_fuerte
                    font.bold: true
                    font.pixelSize: 12 * root.sx
                    font.letterSpacing: 1
                }
                Text {
                    text: "Transformer: de tokens a generación"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 30 * root.sx
                }
                Text {
                    text: "Cada módulo contiene diagnóstico, explicación, práctica, comprobación y resultados."
                    color: Style.Theme.texto_secundario_fuerte
                    font.pixelSize: 14 * root.sx
                }
            }

            Rectangle {
                Layout.preferredWidth: 230 * root.sx
                Layout.preferredHeight: 70 * root.sy
                radius: 12 * root.sx
                color: Style.Theme.acento_fondo
                border.color: Style.Theme.acento_alt
                Column {
                    anchors.centerIn: parent
                    spacing: 3
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.courseController.globalProgressPercent + "%"
                        color: Style.Theme.acento_fuerte
                        font.bold: true
                        font.pixelSize: 26 * root.sx
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.courseController.completedModulesCount + " de "
                              + root.courseController.totalModules + " módulos"
                        color: Style.Theme.texto_secundario_fuerte
                        font.pixelSize: 12 * root.sx
                    }
                }
            }
        }

        ProgressBar {
            Layout.fillWidth: true
            from: 0
            to: 100
            value: root.courseController.globalProgressPercent
        }

        Rectangle {
            visible: root.courseController.reviewMode
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 46 * root.sy : 0
            radius: 10 * root.sx
            color: Style.Theme.aviso_fondo
            border.color: Style.Theme.warning
            Text {
                anchors.centerIn: parent
                text: "Modo de revisión activo: todos los módulos y etapas están desbloqueados temporalmente."
                color: Style.Theme.aviso_texto
                font.bold: true
                font.pixelSize: 12 * root.sx
            }
        }

        ScrollView {
            id: moduleScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            GridLayout {
                width: moduleScroll.availableWidth
                columns: width >= 1050 ? 4 : (width >= 700 ? 2 : 1)
                columnSpacing: 14 * root.sx
                rowSpacing: 14 * root.sy

                Repeater {
                    model: root.courseController.modules
                    delegate: Rectangle {
                        id: moduleCard
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 250 * root.sy
                        radius: 14 * root.sx
                        color: modelData.available ? Style.Theme.surface : Style.Theme.superficie_alterna
                        border.width: modelData.id === root.courseController.currentModuleId ? 2 : 1
                        border.color: modelData.id === root.courseController.currentModuleId
                                      ? Style.Theme.acento : Style.Theme.borde_suave
                        opacity: modelData.available ? 1 : 0.62

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16 * root.sx
                            spacing: 9 * root.sy

                            RowLayout {
                                Layout.fillWidth: true
                                Rectangle {
                                    Layout.preferredWidth: 38 * root.sx
                                    Layout.preferredHeight: 38 * root.sy
                                    radius: width / 2
                                    color: moduleCard.modelData.available
                                           ? Style.Theme.acento_fondo : Style.Theme.chip_fondo
                                    Text {
                                        anchors.centerIn: parent
                                        text: moduleCard.modelData.order
                                        color: moduleCard.modelData.available
                                               ? Style.Theme.acento_fuerte : Style.Theme.texto_terciario
                                        font.bold: true
                                        font.pixelSize: 16 * root.sx
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: root.statusLabel(moduleCard.modelData.status)
                                    color: root.statusColor(moduleCard.modelData.status)
                                    font.bold: true
                                    font.pixelSize: 11 * root.sx
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: moduleCard.modelData.title
                                color: Style.Theme.texto_primario
                                font.bold: true
                                font.pixelSize: 20 * root.sx
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: moduleCard.modelData.description
                                color: Style.Theme.texto_secundario_fuerte
                                font.pixelSize: 13 * root.sx
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                Layout.fillWidth: true
                                text: moduleCard.modelData.completed_stages + " / "
                                      + moduleCard.modelData.total_stages + " etapas"
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 11 * root.sx
                            }
                            ProgressBar {
                                Layout.fillWidth: true
                                from: 0
                                to: 100
                                value: moduleCard.modelData.progress_percent
                            }
                            BotonPrincipal {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38 * root.sy
                                enabled: Boolean(moduleCard.modelData.available)
                                opacity: enabled ? 1 : 0.45
                                text: moduleCard.modelData.status === "in_progress"
                                      ? "Continuar módulo"
                                      : (moduleCard.modelData.status === "completed"
                                         || moduleCard.modelData.status === "review_recommended"
                                         ? "Repasar módulo" : "Comenzar módulo")
                                onClicked: {
                                    root.courseController.selectModule(moduleCard.modelData.id)
                                    root.stackView.push("ModuleScreen.qml", {
                                        "stackView": root.stackView,
                                        "moduleId": moduleCard.modelData.id
                                    })
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
