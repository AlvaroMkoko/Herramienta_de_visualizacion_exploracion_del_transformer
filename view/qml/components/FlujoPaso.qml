

import QtQuick
import QtQuick.Layouts
import "../styles" as Style

/*
    FlujoLista.qml
    ---------------
    Componente unico y autocontenido. Solo lo llamas, le pasas el
    "model" y los factores de escala (sx, sy) y arma toda la lista
    de pasos (circulo indicador + titulo) usando un Repeater interno.
    No necesitas ningun otro archivo.

    Uso:

        FlujoLista {
            width: parent.width
            sx: root.sx
            sy: root.sy
            model: [
                { title: "Tokens",   state: "done" },
                { title: "Embeds",   state: "done" },
                { title: "Atención", state: "running" },
                { title: "FFN",      state: "pending" },
                { title: "Norm",     state: "pending" },
                { title: "Softmax",  state: "pending" }
            ]
        }

    Estados soportados por item: "done", "running", "pending", "error".
*/

Item {
    id: root

    // ---- API pública ----
    property var model: []
    property real sx: 1
    property real sy: 1
    property real itemSpacing: 20

    implicitWidth: 220 * sx
    implicitHeight: column.implicitHeight

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: root.itemSpacing * root.sy

        Repeater {
            model: root.model

            // --- delegate: circulo indicador + titulo, definido inline ---
            delegate: Item {
                id: stepItem

                readonly property string stepTitle: modelData.title
                readonly property string stepState: modelData.state

                width: column.width
                implicitHeight: 34 * root.sy

                readonly property color indicatorColor: {
                    switch (stepState) {
                    case "done":    return Style.Theme.acento_fuerte
                    case "running": return "#C58B2B"
                    case "error":   return Style.Theme.error
                    default:        return Style.Theme.acento_fondo
                    }
                }

                readonly property color borderColor:
                    stepState === "pending" ? Style.Theme.acento_alt : "transparent"

                readonly property color textColor: {
                    switch (stepState) {
                    case "running": return "#C58B2B"
                    case "pending": return Style.Theme.texto_terciario
                    case "error":   return Style.Theme.error
                    default:        return Style.Theme.chip_texto
                    }
                }

                readonly property string icon: {
                    switch (stepState) {
                    case "done":    return "✓"
                    case "running": return "!"
                    case "error":   return "✕"
                    default:        return "•"
                    }
                }

                Rectangle {
                    id: indicator

                    width: 28 * root.sy
                    height: width

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    radius: width / 2

                    color: stepItem.indicatorColor
                    border.width: stepItem.stepState === "pending" ? Math.max(1, 1 * root.sx) : 0
                    border.color: stepItem.borderColor

                    Behavior on color { ColorAnimation { duration: 200 } }

                    Text {
                        anchors.centerIn: parent
                        text: stepItem.icon
                        color: stepItem.stepState === "pending" ? Style.Theme.acento_alt : "white"
                        font.bold: true
                        font.pixelSize: parent.width * 0.55
                    }
                }

                Text {
                    anchors.left: indicator.right
                    anchors.leftMargin: 12 * root.sx
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    text: stepItem.stepTitle
                    color: stepItem.textColor
                    font.bold: stepItem.stepState === "running"
                    font.pixelSize: 16 * root.sx

                    elide: Text.ElideRight
                }
            }
        }
    }
}
