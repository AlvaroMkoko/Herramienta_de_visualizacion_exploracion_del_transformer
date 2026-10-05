import QtQuick
import QtQuick.Controls
import "../styles" as Style

// Pestaña con estado seleccionado explícito y los mismos estados de
// interacción que el resto de botones.
TabButton {
    id: control

    property bool bordePermanente: true
    property real radioResaltado: 8

    implicitHeight: Math.max(40,
                             (contentItem ? contentItem.implicitHeight : 0)
                             + topPadding + bottomPadding)
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    activeFocusOnTab: true

    Accessible.role: Accessible.PageTab
    Accessible.name: text
    Accessible.description: checked ? "Pestaña seleccionada" : "Abrir pestaña"

    background: Rectangle {
        radius: control.radioResaltado
        color: control.checked
               ? Style.Theme.acento_fondo
               : (control.hovered ? Style.Theme.boton : Style.Theme.surface)

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: control.checked ? 4 : 0
            radius: 2
            color: Style.Theme.acento
        }
    }

    contentItem: Text {
        text: control.text
        color: control.checked ? Style.Theme.acento_fuerte
                               : Style.Theme.texto_primario
        font.family: control.font.family
        font.pixelSize: control.font.pixelSize
        font.weight: control.checked ? Font.Bold : control.font.weight
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
