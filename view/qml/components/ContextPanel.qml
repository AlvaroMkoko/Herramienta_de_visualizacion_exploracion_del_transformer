pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

Rectangle {
    id: root

    property var concepto: ({})
    property string errorCarga: ""
    property real sx: 1.0
    property real sy: 1.0
    property bool closable: true

    signal closeRequested()
    signal conceptRequested(string conceptId)

    readonly property var relacionados: root.concepto && root.concepto.relacionados
                                        ? root.concepto.relacionados : []
    readonly property bool tieneConcepto: root.concepto
                                           && Object.keys(root.concepto).length > 0

    function texto(campo) {
        if (!root.concepto || root.concepto[campo] === undefined
                || root.concepto[campo] === null)
            return ""
        return String(root.concepto[campo])
    }

    function filasDimensiones() {
        var dimensiones = root.concepto ? root.concepto.dimensions : null
        if (!dimensiones)
            return []
        var resultado = []
        var claves = Object.keys(dimensiones)
        for (var i = 0; i < claves.length; ++i) {
            var clave = claves[i]
            resultado.push({ "nombre": clave, "valor": String(dimensiones[clave]) })
        }
        return resultado
    }

    implicitHeight: 390 * root.sy
    radius: 10 * root.sx
    color: "#FFFFFF"
    border.color: "#D8D2EC"
    border.width: 1
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14 * root.sx
        spacing: 9 * root.sy

        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * root.sx

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2 * root.sy

                Text {
                    Layout.fillWidth: true
                    text: root.tieneConcepto
                          ? root.texto("title") : "Teoría del componente"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 17 * Math.min(root.sx, root.sy)
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.texto("short_description")
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 11 * Math.min(root.sx, root.sy)
                    wrapMode: Text.WordWrap
                }
            }

            Button {
                visible: root.closable
                Layout.preferredWidth: 32 * root.sx
                Layout.preferredHeight: 32 * root.sy
                text: "×"
                flat: true
                font.bold: true
                font.pixelSize: 19 * Math.min(root.sx, root.sy)
                ToolTip.visible: hovered
                ToolTip.text: "Cerrar teoría y volver a la vista general"
                onClicked: root.closeRequested()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#E4E0F0"
        }

        ScrollView {
            id: theoryScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            Column {
                width: theoryScroll.availableWidth
                spacing: 10 * root.sy

                Rectangle {
                    visible: root.errorCarga !== ""
                    width: parent.width
                    height: visible ? errorText.implicitHeight + 18 * root.sy : 0
                    radius: 7 * root.sx
                    color: "#FEF2F2"
                    border.color: "#FCA5A5"

                    Text {
                        id: errorText
                        anchors.fill: parent
                        anchors.margins: 9 * root.sx
                        text: root.errorCarga
                        color: "#991B1B"
                        font.pixelSize: 10 * Math.min(root.sx, root.sy)
                        wrapMode: Text.WordWrap
                    }
                }

                Text {
                    width: parent.width
                    visible: root.tieneConcepto
                    text: root.texto("explanation")
                    color: Style.Theme.texto_primario
                    font.pixelSize: 12 * Math.min(root.sx, root.sy)
                    lineHeight: 1.18
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    visible: !root.tieneConcepto && root.errorCarga === ""
                    text: "Selecciona un bloque del Transformer para consultar su teoría."
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 12 * Math.min(root.sx, root.sy)
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    visible: root.texto("intuition") !== ""
                    text: "INTUICIÓN"
                    color: "#6C5FC3"
                    font.bold: true
                    font.pixelSize: 10 * Math.min(root.sx, root.sy)
                }
                Text {
                    width: parent.width
                    visible: root.texto("intuition") !== ""
                    text: root.texto("intuition")
                    color: "#514978"
                    font.italic: true
                    font.pixelSize: 11 * Math.min(root.sx, root.sy)
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    visible: root.texto("formula") !== "" || root.texto("mathematical") !== ""
                    width: parent.width
                    height: visible ? formulaColumn.implicitHeight + 20 * root.sy : 0
                    radius: 7 * root.sx
                    color: "#F5F3FB"
                    border.color: "#DDD7F1"

                    Column {
                        id: formulaColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 10 * root.sx
                        spacing: 6 * root.sy

                        Text {
                            width: parent.width
                            visible: root.texto("formula") !== ""
                            text: root.texto("formula")
                            color: "#433879"
                            font.family: "monospace"
                            font.pixelSize: 11 * Math.min(root.sx, root.sy)
                            wrapMode: Text.WrapAnywhere
                        }
                        Text {
                            width: parent.width
                            visible: root.texto("mathematical") !== ""
                            text: root.texto("mathematical")
                            color: Style.Theme.texto_secundario
                            font.pixelSize: 10 * Math.min(root.sx, root.sy)
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.texto("example") !== ""
                    text: "EJEMPLO"
                    color: "#3979B7"
                    font.bold: true
                    font.pixelSize: 10 * Math.min(root.sx, root.sy)
                }
                Text {
                    width: parent.width
                    visible: root.texto("example") !== ""
                    text: root.texto("example")
                    color: "#315F88"
                    font.pixelSize: 11 * Math.min(root.sx, root.sy)
                    wrapMode: Text.WordWrap
                }

                Column {
                    visible: root.concepto && root.concepto.steps
                             && root.concepto.steps.length > 0
                    width: parent.width
                    spacing: 4 * root.sy

                    Text {
                        width: parent.width
                        text: "PASOS"
                        color: "#258F6F"
                        font.bold: true
                        font.pixelSize: 10 * Math.min(root.sx, root.sy)
                    }
                    Repeater {
                        model: root.concepto && root.concepto.steps
                               ? root.concepto.steps : []
                        delegate: Text {
                            required property var modelData
                            width: parent.width
                            text: "• " + String(modelData)
                            color: Style.Theme.texto_primario
                            font.pixelSize: 10 * Math.min(root.sx, root.sy)
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Column {
                    visible: root.filasDimensiones().length > 0
                    width: parent.width
                    spacing: 4 * root.sy

                    Text {
                        width: parent.width
                        text: "DIMENSIONES"
                        color: "#9A641B"
                        font.bold: true
                        font.pixelSize: 10 * Math.min(root.sx, root.sy)
                    }
                    Repeater {
                        model: root.filasDimensiones()
                        delegate: RowLayout {
                            id: dimensionDelegate
                            required property var modelData
                            width: parent.width
                            spacing: 8 * root.sx
                            Text {
                                Layout.fillWidth: true
                                text: dimensionDelegate.modelData.nombre
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 9 * Math.min(root.sx, root.sy)
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                Layout.preferredWidth: parent.width * 0.42
                                text: dimensionDelegate.modelData.valor
                                color: Style.Theme.texto_primario
                                font.family: "monospace"
                                font.pixelSize: 9 * Math.min(root.sx, root.sy)
                                horizontalAlignment: Text.AlignRight
                                wrapMode: Text.WrapAnywhere
                            }
                        }
                    }
                }

                Column {
                    visible: root.relacionados.length > 0
                    width: parent.width
                    spacing: 5 * root.sy

                    Text {
                        width: parent.width
                        text: "PARA PROFUNDIZAR"
                        color: "#6C5FC3"
                        font.bold: true
                        font.pixelSize: 10 * Math.min(root.sx, root.sy)
                    }
                    Repeater {
                        model: root.relacionados
                        delegate: Rectangle {
                            id: relatedDelegate
                            required property var modelData
                            width: parent.width
                            height: relatedColumn.implicitHeight + 14 * root.sy
                            radius: 6 * root.sx
                            color: relatedMouse.containsMouse ? "#EEEAF8" : "#F8F7FC"
                            border.color: "#DED8F0"

                            Column {
                                id: relatedColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: 7 * root.sx
                                spacing: 2 * root.sy
                                Text {
                                    width: parent.width
                                    text: relatedDelegate.modelData.title || relatedDelegate.modelData.id
                                    color: "#51458D"
                                    font.bold: true
                                    font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    width: parent.width
                                    visible: text !== ""
                                    text: relatedDelegate.modelData.short_description || ""
                                    color: Style.Theme.texto_secundario
                                    font.pixelSize: 9 * Math.min(root.sx, root.sy)
                                    wrapMode: Text.WordWrap
                                }
                            }

                            MouseArea {
                                id: relatedMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.conceptRequested(String(relatedDelegate.modelData.id))
                            }
                        }
                    }
                }
            }
        }
    }
}
