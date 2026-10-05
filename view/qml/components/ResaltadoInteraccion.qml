import QtQuick
import "../styles" as Style

// Contorno compartido para cualquier control pulsable.
//
// El borde permanece visible en reposo para que el control no se confunda
// con el fondo. Hover y foco de teclado incrementan grosor y contraste sin
// depender solamente de un cambio de color en el relleno.
Rectangle {
    id: root

    required property var control
    property bool bordePermanente: true
    property real radio: Math.min(10, Math.max(5, height * 0.22))
    property color colorBase: Style.Theme.borde_boton

    anchors.fill: parent
    anchors.margins: control.visualFocus ? -3 : 0
    z: 1000
    radius: radio + (control.visualFocus ? 3 : 0)
    color: "transparent"
    visible: bordePermanente || control.hovered || control.visualFocus
    opacity: control.enabled ? 1 : 0.6
    border.width: control.enabled
                  ? (control.visualFocus ? 2.5 : (control.hovered ? 2 : 1))
                  : 1
    border.color: !control.enabled
                  ? Style.Theme.borde_suave
                  : (control.visualFocus
                  ? Style.Theme.acento_fuerte
                  : (control.hovered ? Style.Theme.acento : colorBase))

    Behavior on border.color {
        ColorAnimation { duration: Style.Theme.duracionCorta }
    }
    Behavior on opacity {
        NumberAnimation { duration: Style.Theme.duracionCorta }
    }

    // No recibe eventos: su única función es comunicar que el elemento es
    // interactivo y dónde quedó el foco del teclado.
    Accessible.ignored: true
}
