pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root
    objectName: "studentAnalysisScreen"

    required property string studentId
    readonly property var profileController: mainViewModel.profileController
    property var analysis: ({})

    function reload() {
        root.analysis = root.profileController.studentAnalysis(root.studentId)
    }

    Component.onCompleted: root.reload()

    Connections {
        target: root.profileController
        function onStudentsChanged() { root.reload() }
    }

    ScrollView {
        id: analysisScroll
        anchors.fill: parent
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: analysisScroll.availableWidth
            spacing: 18

            Item { Layout.fillWidth: true; Layout.preferredHeight: 24 }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 40
                Layout.rightMargin: 40
                spacing: 16
                BotonSecundario {
                    objectName: "studentAnalysisBackButton"
                    Layout.preferredWidth: 130
                    Layout.preferredHeight: 38
                    text: "← Volver"
                    onClicked: root.stackView.pop()
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: root.analysis.student ? root.analysis.student.nombre : "Análisis del alumno"
                        color: Style.Theme.texto_primario
                        font.pixelSize: 28
                        font.bold: true
                    }
                    Text {
                        text: root.analysis.student
                              ? "ID: " + (root.analysis.student.matricula || "—")
                                + (root.analysis.student.grupo ? "  ·  Grupo: " + root.analysis.student.grupo : "")
                              : ""
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 12
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 40
                Layout.rightMargin: 40
                columns: root.width < 850 ? 1 : 3
                columnSpacing: 14
                rowSpacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 112
                    radius: 12
                    color: Style.Theme.info_fondo
                    border.width: 1
                    border.color: Style.Theme.borde_suave
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 17
                        Text { text: "PRE-TEST"; color: Style.Theme.info_texto; font.pixelSize: 11; font.bold: true }
                        Text {
                            text: root.analysis.has_pre ? root.analysis.pre.percentage + "%" : "Pendiente"
                            color: Style.Theme.texto_primario
                            font.pixelSize: 27
                            font.bold: true
                        }
                        Text {
                            text: root.analysis.has_pre ? root.analysis.pre.puntaje + " de " + root.analysis.pre.maximo + " puntos" : "Sin resultado guardado"
                            color: Style.Theme.texto_secundario
                            font.pixelSize: 11
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 112
                    radius: 12
                    color: Style.Theme.acento_fondo
                    border.width: 1
                    border.color: Style.Theme.borde_suave
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 17
                        Text { text: "POST-TEST"; color: Style.Theme.acento_texto; font.pixelSize: 11; font.bold: true }
                        Text {
                            text: root.analysis.has_post ? root.analysis.post.percentage + "%" : "Pendiente"
                            color: Style.Theme.texto_primario
                            font.pixelSize: 27
                            font.bold: true
                        }
                        Text {
                            text: root.analysis.has_post ? root.analysis.post.puntaje + " de " + root.analysis.post.maximo + " puntos" : "Sin resultado guardado"
                            color: Style.Theme.texto_secundario
                            font.pixelSize: 11
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 112
                    radius: 12
                    color: Style.Theme.surface
                    border.width: 1
                    border.color: Style.Theme.borde_suave
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 17
                        Text { text: "CAMBIO TOTAL"; color: Style.Theme.texto_terciario; font.pixelSize: 11; font.bold: true }
                        Text {
                            readonly property real delta: root.analysis.student ? Number(root.analysis.student.improvement || 0) : 0
                            text: root.analysis.comparable ? (delta > 0 ? "+" : "") + delta + " pts" : "—"
                            color: delta >= 0 ? Style.Theme.success : Style.Theme.error
                            font.pixelSize: 27
                            font.bold: true
                        }
                        Text {
                            text: root.analysis.comparable ? "Diferencia post-test menos pre-test" : "Se requieren ambas evaluaciones"
                            color: Style.Theme.texto_secundario
                            font.pixelSize: 11
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 40
                Layout.rightMargin: 40
                Layout.preferredHeight: dimensionsColumn.implicitHeight + 36
                radius: 14
                color: Style.Theme.surface
                border.width: 1
                border.color: Style.Theme.borde_cuadro

                ColumnLayout {
                    id: dimensionsColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 18
                    spacing: 10

                    Text {
                        text: "Resultados por dimensión"
                        color: Style.Theme.texto_primario
                        font.pixelSize: 18
                        font.bold: true
                    }
                    Text {
                        visible: !root.analysis.dimensions || root.analysis.dimensions.length === 0
                        Layout.fillWidth: true
                        text: "No hay desglose por dimensiones disponible."
                        color: Style.Theme.texto_secundario
                    }

                    Repeater {
                        model: root.analysis.dimensions || []
                        delegate: Rectangle {
                            id: dimensionRow
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            radius: 9
                            color: Style.Theme.superficie_alterna
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 13
                                spacing: 14
                                Text {
                                    Layout.fillWidth: true
                                    text: dimensionRow.modelData.name
                                    color: Style.Theme.texto_primario
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.preferredWidth: 120
                                    text: "Pre: " + (dimensionRow.modelData.has_pre ? dimensionRow.modelData.pre_percentage + "%" : "—")
                                    color: Style.Theme.info_texto
                                    horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    Layout.preferredWidth: 120
                                    text: "Post: " + (dimensionRow.modelData.has_post ? dimensionRow.modelData.post_percentage + "%" : "—")
                                    color: Style.Theme.acento
                                    horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    Layout.preferredWidth: 105
                                    visible: root.analysis.comparable
                                             && dimensionRow.modelData.has_pre
                                             && dimensionRow.modelData.has_post
                                    text: (dimensionRow.modelData.improvement > 0 ? "+" : "") + dimensionRow.modelData.improvement + " pts"
                                    color: dimensionRow.modelData.improvement >= 0 ? Style.Theme.success : Style.Theme.error
                                    font.bold: true
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true; Layout.preferredHeight: 24 }
        }
    }
}
