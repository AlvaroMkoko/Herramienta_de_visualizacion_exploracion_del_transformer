import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

Rectangle {
    id: root

    property string message: ""
    property real sx: 1
    property real sy: 1

    readonly property string savedPath: {
        var value = String(root.message || "")
        return value.replace(/^\s*(?:✓\s*)?Guardado:\s*/i, "")
    }
    readonly property string fileName: {
        var normalized = root.savedPath.replace(/\\/g, "/")
        var parts = normalized.split("/")
        return parts.length > 0 ? parts[parts.length - 1] : normalized
    }

    implicitHeight: 52 * sy
    radius: 9 * sx
    color: Style.Theme.exito_fondo
    border.color: Qt.alpha(Style.Theme.exito_texto, 0.42)
    visible: message !== ""

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10 * root.sx
        anchors.rightMargin: 10 * root.sx
        anchors.topMargin: 7 * root.sy
        anchors.bottomMargin: 7 * root.sy
        spacing: 9 * root.sx

        Rectangle {
            Layout.preferredWidth: 28 * root.sx
            Layout.preferredHeight: 28 * root.sy
            radius: width / 2
            color: Qt.alpha(Style.Theme.exito_texto, 0.13)
            border.color: Qt.alpha(Style.Theme.exito_texto, 0.48)

            Text {
                anchors.centerIn: parent
                text: "✓"
                color: Style.Theme.exito_texto
                font.bold: true
                font.pixelSize: 14 * Math.min(root.sx, root.sy)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 1

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Modelo guardado"
                color: Style.Theme.exito_texto
                font.bold: true
                font.pixelSize: 10 * root.sx
            }

            Text {
                id: fileNameText
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: root.fileName || root.savedPath
                color: Style.Theme.texto_secundario_fuerte
                font.pixelSize: 9 * root.sx
                elide: Text.ElideMiddle
                maximumLineCount: 1
            }
        }
    }

    HoverHandler { id: hoverHandler }

    ToolTip.visible: hoverHandler.hovered && root.savedPath !== ""
    ToolTip.text: root.savedPath
    ToolTip.delay: 450
}
