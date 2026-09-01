pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Resumen compacto para conservar la seleccion sin volver a ocupar el panel
// lateral con todo el articulo. El padre controla su visibilidad y decide que
// hacer al reabrir o cerrar.
Rectangle {
    id: root

    property var concepto: ({})
    property real sx: 1.0
    property real sy: 1.0
    property string openButtonObjectName: "openSelectedTheoryButton"
    property bool showDescription: false

    signal openRequested()
    signal closeRequested()

    function textFor(fieldName) {
        if (!root.concepto || root.concepto[fieldName] === undefined
                || root.concepto[fieldName] === null)
            return ""
        return String(root.concepto[fieldName])
    }

    function requestOpen() {
        root.openRequested()
    }

    readonly property real contentScale: Math.max(
                                                   0.60,
                                                   Math.min(1.10, Math.min(root.sx, root.sy))
                                               )

    implicitHeight: summaryLayout.implicitHeight + 24 * root.contentScale
    radius: 10 * root.contentScale
    color: "#F8F6FC"
    border.color: "#D7D0EB"
    border.width: 1

    ColumnLayout {
        id: summaryLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 12 * root.contentScale
        spacing: 8 * root.contentScale

        RowLayout {
            Layout.fillWidth: true
            spacing: 9 * root.contentScale

            Text {
                Layout.fillWidth: true
                text: root.textFor("title") || "Concepto seleccionado"
                color: Style.Theme.texto_primario
                font.bold: true
                font.pixelSize: 14 * root.contentScale
                wrapMode: Text.WordWrap
                Accessible.role: Accessible.Heading
                Accessible.name: text
            }

            ToolButton {
                Layout.preferredWidth: 30 * root.contentScale
                Layout.preferredHeight: 30 * root.contentScale
                text: "×"
                flat: true
                activeFocusOnTab: true
                Accessible.name: "Cerrar selección del concepto"
                ToolTip.visible: hovered || activeFocus
                ToolTip.text: "Cerrar selección"
                onClicked: root.closeRequested()
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.showDescription && text !== ""
            text: root.textFor("short_description")
            color: Style.Theme.texto_secundario
            font.pixelSize: 11 * root.contentScale
            lineHeight: 1.18
            wrapMode: Text.WordWrap
        }

        Button {
            id: openButton

            objectName: root.openButtonObjectName

            Layout.fillWidth: true
            Layout.preferredHeight: 38 * root.contentScale
            text: "Abrir explicación completa"
            activeFocusOnTab: true
            Accessible.name: text
            Accessible.description: "Vuelve a abrir el lector educativo del concepto seleccionado."

            background: Rectangle {
                radius: 7 * root.contentScale
                color: openButton.down ? "#DED7F4"
                                      : openButton.hovered ? "#EDE8F8" : "#F4F1FA"
                border.color: "#BFB5DF"
            }

            contentItem: Text {
                text: openButton.text
                color: "#5B4AA5"
                font.bold: true
                font.pixelSize: 11 * root.contentScale
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: root.requestOpen()
        }
    }
}
