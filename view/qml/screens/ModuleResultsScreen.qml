pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root
    objectName: "moduleResultsScreen"

    property string moduleId: "module_1"
    readonly property var courseController: mainViewModel.courseController
    property var results: ({})

    Component.onCompleted: {
        root.results = root.courseController.moduleResults(root.moduleId)
        if (root.results.available)
            root.courseController.markResultsViewed(root.moduleId)
    }

    function formatTime(seconds) {
        var total = Math.round(Number(seconds) || 0)
        return Math.floor(total / 60) + " min " + (total % 60) + " s"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28 * root.sx
        spacing: 14 * root.sy

        RowLayout {
            Layout.fillWidth: true
            BotonPrincipal {
                Layout.preferredWidth: 160 * root.sx
                Layout.preferredHeight: 42 * root.sy
                text: "← Volver"
                onClicked: root.stackView.pop()
            }
            ColumnLayout {
                Layout.fillWidth: true
                Text {
                    text: "RESULTADOS DEL MÓDULO"
                    color: Style.Theme.acento_fuerte
                    font.bold: true
                    font.pixelSize: 12 * root.sx
                }
                Text {
                    text: root.results.module_title || "Resultados"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 28 * root.sx
                }
            }
            Text {
                text: root.formatTime(root.results.duration_seconds)
                color: Style.Theme.texto_secundario_fuerte
                font.pixelSize: 14 * root.sx
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 112 * root.sy
            spacing: 12 * root.sx
            Repeater {
                model: [
                    { label: "PRE-TEST", value: (root.results.pre_percentage || 0) + "%", color: Style.Theme.info_fondo, textColor: Style.Theme.info_texto },
                    { label: "POST-TEST", value: (root.results.post_percentage || 0) + "%", color: Style.Theme.exito_fondo, textColor: Style.Theme.exito_texto },
                    { label: "DIFERENCIA", value: root.results.comparable ? (((root.results.delta_percentage || 0) >= 0 ? "+" : "") + (root.results.delta_percentage || 0) + " pts") : "—", color: Style.Theme.acento_fondo, textColor: Style.Theme.acento_fuerte },
                    { label: "MEJORA RELATIVA", value: root.results.comparable ? ((root.results.relative_improvement || 0) + "%") : "—", color: Style.Theme.formula_fondo, textColor: Style.Theme.formula_texto }
                ]
                delegate: Rectangle {
                    id: metricCard
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12 * root.sx
                    color: metricCard.modelData.color
                    Column {
                        anchors.centerIn: parent
                        spacing: 5
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: metricCard.modelData.value; color: metricCard.modelData.textColor; font.bold: true; font.pixelSize: 28 * root.sx }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: metricCard.modelData.label; color: metricCard.modelData.textColor; font.bold: true; font.pixelSize: 11 * root.sx }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14 * root.sx

            RectanglePrincipal {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sx: root.sx
                sy: root.sy
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16 * root.sx
                    spacing: 8 * root.sy
                    Text { text: "Rendimiento por concepto"; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 17 * root.sx }
                    ScrollView {
                        id: conceptScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: availableWidth
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ColumnLayout {
                            width: conceptScroll.availableWidth
                            spacing: 7 * root.sy
                            Repeater {
                                model: root.results.concepts || []
                                delegate: Rectangle {
                                    id: conceptRow
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 58 * root.sy
                                    radius: 8 * root.sx
                                    color: Style.Theme.superficie_alterna
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 9 * root.sx
                                        Text { Layout.preferredWidth: 190 * root.sx; text: conceptRow.modelData.name; color: Style.Theme.texto_primario; font.pixelSize: 12 * root.sx; wrapMode: Text.WordWrap }
                                        ProgressBar { Layout.fillWidth: true; from: 0; to: 100; value: conceptRow.modelData.post_percentage }
                                        Text { Layout.preferredWidth: 52 * root.sx; text: conceptRow.modelData.assessed_post ? conceptRow.modelData.post_percentage + "%" : "—"; color: Style.Theme.acento_fuerte; font.bold: true; horizontalAlignment: Text.AlignRight; font.pixelSize: 12 * root.sx }
                                        Text { Layout.preferredWidth: 58 * root.sx; text: conceptRow.modelData.comparable ? ((conceptRow.modelData.delta_percentage >= 0 ? "+" : "") + conceptRow.modelData.delta_percentage) : "—"; color: conceptRow.modelData.delta_percentage >= 0 ? Style.Theme.exito_texto : Style.Theme.error_texto; horizontalAlignment: Text.AlignRight; font.pixelSize: 11 * root.sx }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.preferredWidth: 390 * root.sx
                Layout.fillHeight: true
                spacing: 10 * root.sy
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12 * root.sx
                    color: Style.Theme.exito_fondo
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14 * root.sx
                        Text { text: "Conceptos dominados"; color: Style.Theme.exito_texto; font.bold: true; font.pixelSize: 15 * root.sx }
                        Text { Layout.fillWidth: true; Layout.fillHeight: true; text: (root.results.mastered || []).length ? (root.results.mastered || []).join(" · ") : "Aún no hay conceptos evaluados por encima de 80%."; color: Style.Theme.exito_texto; wrapMode: Text.WordWrap; font.pixelSize: 12 * root.sx }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12 * root.sx
                    color: Style.Theme.aviso_fondo
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14 * root.sx
                        Text { text: "Necesitan refuerzo"; color: Style.Theme.aviso_texto; font.bold: true; font.pixelSize: 15 * root.sx }
                        Text { Layout.fillWidth: true; Layout.fillHeight: true; text: (root.results.needs_reinforcement || []).length ? (root.results.needs_reinforcement || []).join(" · ") : "Ningún concepto evaluado quedó por debajo de 70%."; color: Style.Theme.aviso_texto; wrapMode: Text.WordWrap; font.pixelSize: 12 * root.sx }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 90 * root.sy
                    radius: 12 * root.sx
                    color: Style.Theme.acento_fondo
                    Text {
                        anchors.fill: parent
                        anchors.margins: 13 * root.sx
                        text: root.results.recommendation || ""
                        color: Style.Theme.acento_fuerte
                        font.bold: true
                        font.pixelSize: 12 * root.sx
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12 * root.sx
            BotonPrincipal {
                Layout.preferredWidth: 230 * root.sx
                Layout.preferredHeight: 46 * root.sy
                text: "Ver todos los módulos"
                onClicked: root.stackView.push("ModuleMapScreen.qml", { "stackView": root.stackView })
            }
            BotonPrincipal {
                visible: root.moduleId !== "module_8"
                Layout.preferredWidth: 240 * root.sx
                Layout.preferredHeight: 46 * root.sy
                text: "Continuar al siguiente módulo →"
                onClicked: root.stackView.push("ModuleScreen.qml", {
                    "stackView": root.stackView,
                    "moduleId": root.courseController.currentModuleId
                })
            }
        }
    }
}
