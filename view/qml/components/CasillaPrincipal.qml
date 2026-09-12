import QtQuick
import QtQuick.Controls
import "../styles" as Style

CheckBox {
    id: control

    property real sx: 1
    property real sy: 1

    spacing: 9 * sx

    indicator: Rectangle {
        implicitWidth: 20 * control.sx
        implicitHeight: 20 * control.sx
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: 5 * control.sx
        color: control.checked ? Style.Theme.acento : Style.Theme.surface
        border.width: control.checked ? 0 : (control.hovered ? 2 : 1.5)
        border.color: control.hovered ? Style.Theme.acento : Style.Theme.borde_suave
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            visible: control.checked
            text: "✓"
            // `texto_sobre_acento` y no `texto_sobre_color`: el acento se
            // aclara en modo oscuro, así que la palomita debe invertirse.
            color: Style.Theme.texto_sobre_acento
            font.pixelSize: 13 * control.sx
            font.bold: true
        }
    }

    contentItem: Text {
        text: control.text
        color: control.enabled ? Style.Theme.texto_primario : Style.Theme.texto_terciario
        font.pixelSize: 12 * control.sy
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator.width + control.spacing
        wrapMode: Text.WordWrap
    }
}