import QtQuick
import QtQuick.Controls
import "../styles" as Style

SpinBox {
    id: control

    property real sx: 1
    property real sy: 1

    implicitHeight: 34 * sy
    implicitWidth: 120 * sx
    editable: true

    background: Rectangle {
        radius: 8 * control.sx
        color: control.enabled ? Style.Theme.surface : Style.Theme.superficie_alterna
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Style.Theme.acento : Style.Theme.borde_suave
    }

    contentItem: TextInput {
        text: control.displayText
        color: control.enabled ? Style.Theme.texto_primario : Style.Theme.texto_terciario
        font.pixelSize: 12 * control.sy
        font.bold: true
        selectionColor: Style.Theme.acento
        selectedTextColor: Style.Theme.texto_sobre_acento
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter
        readOnly: !control.editable
        validator: control.validator
        inputMethodHints: Qt.ImhFormattedNumbersOnly
    }

    up.indicator: Rectangle {
        x: control.width - width - 3 * control.sx
        y: 3 * control.sy
        height: control.height - 6 * control.sy
        width: 26 * control.sx
        radius: 6 * control.sx
        color: control.up.pressed ? Style.Theme.acento_fondo
               : (control.up.hovered ? Style.Theme.superficie_alterna : "transparent")
        Text {
            anchors.centerIn: parent
            text: "+"
            // Atenuar al llegar al límite evita que el usuario insista con
            // un control que ya no responde.
            color: control.value < control.to
                   ? Style.Theme.texto_secundario : Style.Theme.texto_terciario
            font.pixelSize: 14 * control.sx
            font.bold: true
        }
    }

    down.indicator: Rectangle {
        x: 3 * control.sx
        y: 3 * control.sy
        height: control.height - 6 * control.sy
        width: 26 * control.sx
        radius: 6 * control.sx
        color: control.down.pressed ? Style.Theme.acento_fondo
               : (control.down.hovered ? Style.Theme.superficie_alterna : "transparent")
        Text {
            anchors.centerIn: parent
            text: "−"
            color: control.value > control.from
                   ? Style.Theme.texto_secundario : Style.Theme.texto_terciario
            font.pixelSize: 14 * control.sx
            font.bold: true
        }
    }
}