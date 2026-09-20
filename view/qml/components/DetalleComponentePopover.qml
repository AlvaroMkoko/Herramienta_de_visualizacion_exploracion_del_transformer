pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

Popup {
    id: root

    property real sx: 1.0
    property real sy: 1.0
    property string componenteId: ""
    property var concepto: ({})
    property var datosComponente: null
    property var prediccionesTop: []
    property string openButtonObjectName: "trainingOpenTheoryButton"

    signal abrirTeoriaSolicitada()
    signal cerrarSolicitado()

    visible: root.componenteId !== ""
    modal: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 10 * root.sx
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 }
    }
    onClosed: root.cerrarSolicitado()

    background: Rectangle {
        radius: 12 * root.sx
        color: Style.Theme.surface
        border.color: Style.Theme.borde_medio
        border.width: 1
    }

    contentItem: ScrollView {
        id: detalleScroll
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        Column {
            id: contenido
            width: detalleScroll.availableWidth
            spacing: 10 * root.sy

            RowLayout {
                width: parent.width
                spacing: 8 * root.sx

                Text {
                    Layout.fillWidth: true
                    text: root.datosComponente && root.datosComponente.titulo
                          ? root.datosComponente.titulo
                          : (root.concepto.title || "Componente seleccionado")
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 14 * root.sx
                    wrapMode: Text.WordWrap
                }

                ToolButton {
                    id: cerrarButton
                    objectName: "detalleComponenteCerrarButton"
                    Layout.preferredWidth: 30 * root.sx
                    Layout.preferredHeight: 30 * root.sy
                    text: "×"
                    Accessible.name: "Cerrar detalle del componente"
                    ToolTip.visible: hovered || activeFocus
                    ToolTip.text: "Cerrar detalle"
                    onClicked: root.cerrarSolicitado()
                }
            }

            ConceptSummary {
                objectName: "trainingConceptSummary"
                width: parent.width
                sx: root.sx
                sy: root.sy
                concepto: root.concepto
                openButtonObjectName: root.openButtonObjectName
                onOpenRequested: root.abrirTeoriaSolicitada()
                onCloseRequested: root.cerrarSolicitado()
            }

            RowLayout {
                width: parent.width
                spacing: 6 * root.sx
                Text {
                    text: "DATOS REALES · BATCH ACTUAL"
                    color: Style.Theme.exito_texto
                    font.bold: true
                    font.pixelSize: 11 * root.sx
                }
                ConceptHelpButton {
                    conceptId: "epoch_batch"
                    controlSize: Math.max(22, 25 * Math.min(root.sx, root.sy))
                    onHelpRequested: function(conceptId) { root.abrirTeoriaSolicitada() }
                }
            }

            Repeater {
                model: root.datosComponente ? root.datosComponente.metricas : []
                delegate: Rectangle {
                    id: metricaDelegate
                    required property var modelData
                    width: contenido.width
                    height: metricaLayout.implicitHeight + 16 * root.sy
                    radius: 7 * root.sx
                    color: Style.Theme.superficie_alterna
                    border.color: Style.Theme.divisor

                    RowLayout {
                        id: metricaLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 9 * root.sx
                        spacing: 8 * root.sx

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: metricaDelegate.modelData.etiqueta || ""
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 10 * root.sx
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                visible: String(metricaDelegate.modelData.detalle || "") !== ""
                                Layout.fillWidth: true
                                text: metricaDelegate.modelData.detalle || ""
                                color: Style.Theme.texto_terciario
                                font.pixelSize: 9 * root.sx
                                wrapMode: Text.WordWrap
                            }
                        }
                        ConceptHelpButton {
                            visible: String(metricaDelegate.modelData.concepto_id || "") !== ""
                            conceptId: String(metricaDelegate.modelData.concepto_id || "")
                            controlSize: Math.max(22, 25 * Math.min(root.sx, root.sy))
                            onHelpRequested: function(conceptId) { root.abrirTeoriaSolicitada() }
                        }
                        Text {
                            text: metricaDelegate.modelData.valor || ""
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: 13 * root.sx
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 6 * root.sy
                visible: root.datosComponente
                         && root.datosComponente.capas
                         && root.datosComponente.capas.length > 0

                RowLayout {
                    width: parent.width
                    spacing: 6 * root.sx
                    Text {
                        text: "ATENCIÓN POR CAPA"
                        color: Style.Theme.aviso_texto
                        font.bold: true
                        font.pixelSize: 11 * root.sx
                    }
                    ConceptHelpButton {
                        conceptId: "interpretacion_pesos"
                        controlSize: Math.max(22, 25 * Math.min(root.sx, root.sy))
                        onHelpRequested: function(conceptId) { root.abrirTeoriaSolicitada() }
                    }
                }

                Repeater {
                    model: root.datosComponente ? root.datosComponente.capas : []
                    delegate: RowLayout {
                        id: capaDelegate
                        required property var modelData
                        width: parent.width
                        height: 24 * root.sy
                        Text {
                            text: "Capa " + capaDelegate.modelData.capa
                            color: Style.Theme.texto_secundario
                            font.pixelSize: 10 * root.sx
                            Layout.preferredWidth: 55 * root.sx
                        }
                        ProgressBar {
                            Layout.fillWidth: true
                            from: 0
                            to: 1
                            value: Math.min(1, Number(capaDelegate.modelData.pico || 0))
                        }
                        Text {
                            text: "pico " + Number(capaDelegate.modelData.pico || 0).toFixed(3)
                            color: Style.Theme.aviso_texto
                            font.pixelSize: 9 * root.sx
                        }
                    }
                }
            }

            Text {
                visible: root.prediccionesTop.length > 0 && root.componenteId === "softmax"
                width: parent.width
                text: "Top actual: " + root.prediccionesTop.map(function(item) {
                    return "“" + item.texto + "” " + Math.round(item.probabilidad * 100) + "%"
                }).join("  ·  ")
                color: Style.Theme.info_texto
                font.pixelSize: 10 * root.sx
                wrapMode: Text.WordWrap
            }
        }
    }
}
