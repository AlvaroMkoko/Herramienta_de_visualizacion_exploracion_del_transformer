import QtQuick
import QtQuick.Controls
import "../styles" as Style

TextField {
    id: control

    property real sx: 1
    property real sy: 1

    implicitHeight: 38 * sy
    leftPadding: 12 * sx
    rightPadding: 12 * sx
    selectByMouse: true

    color: control.enabled ? Style.Theme.texto_primario : Style.Theme.texto_terciario
    placeholderTextColor: Style.Theme.texto_terciario
    selectionColor: Style.Theme.acento
    selectedTextColor: Style.Theme.texto_sobre_acento
    font.pixelSize: 12 * sy

    background: Rectangle {
        radius: 8 * control.sx
        color: control.enabled ? Style.Theme.surface : Style.Theme.superficie_alterna
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus
                      ? Style.Theme.acento
                      : (control.hovered ? Style.Theme.texto_terciario : Style.Theme.borde_suave)
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }
}