import QtQuick
import QtQuick.Controls
import "../styles" as Style

// Variante multilínea. Cuando va dentro de un ScrollView, TextArea no
// dibuja su marco: en ese caso el borde lo pone el contenedor y este
// background queda como respaldo para el uso suelto.
TextArea {
    id: control

    property real sx: 1
    property real sy: 1

    padding: 10 * sx
    selectByMouse: true
    wrapMode: TextArea.Wrap

    color: control.enabled ? Style.Theme.texto_primario : Style.Theme.texto_terciario
    placeholderTextColor: Style.Theme.texto_terciario
    selectionColor: Style.Theme.acento
    selectedTextColor: Style.Theme.texto_sobre_acento
    font.pixelSize: 12 * sy

    background: Rectangle {
        radius: 8 * control.sx
        color: control.enabled ? Style.Theme.surface : Style.Theme.superficie_alterna
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Style.Theme.acento : Style.Theme.borde_suave
    }
}