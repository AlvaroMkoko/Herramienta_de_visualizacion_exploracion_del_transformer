import QtQuick
import QtQuick.Controls
import "../styles" as Style

// Variante compacta para cerrar, ayuda y acciones iconográficas.
ToolButton {
    id: control

    property bool bordePermanente: true
    property real radioResaltado: 8

    implicitWidth: Math.max(34,
                            (contentItem ? contentItem.implicitWidth : 0)
                            + leftPadding + rightPadding)
    implicitHeight: Math.max(34,
                             (contentItem ? contentItem.implicitHeight : 0)
                             + topPadding + bottomPadding)
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: text

    background: Rectangle {
        radius: control.radioResaltado
        color: !control.enabled
               ? Style.Theme.chip_fondo
               : (control.down
                  ? Style.Theme.boton_presionado
                  : (control.hovered ? Style.Theme.acento_fondo
                                     : Style.Theme.boton))
        Behavior on color {
            ColorAnimation { duration: Style.Theme.duracionCorta }
        }
    }

    contentItem: Text {
        text: control.text
        color: control.enabled ? Style.Theme.texto_primario
                               : Style.Theme.texto_terciario
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    ResaltadoInteraccion {
        control: control
        bordePermanente: control.bordePermanente
        radio: control.radioResaltado
    }
}
