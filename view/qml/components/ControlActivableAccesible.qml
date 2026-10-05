import QtQuick
import QtQuick.Controls

// Base para controles especializados construidos directamente sobre
// AbstractButton (por ejemplo, tarjetas de acción y el selector de tema).
AbstractButton {
    id: control

    property bool bordePermanente: true
    property real radioResaltado: 10

    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: text

    ResaltadoInteraccion {
        control: control
        bordePermanente: control.bordePermanente
        radio: control.radioResaltado
    }
}
