import QtQuick
import QtQuick.Controls
import "../styles" as Style

// Botón discreto para navegación y acciones de apoyo.
//
// Se distingue de BotonPrincipal en la jerarquía visual, no en la función:
// BotonPrincipal lleva degradado y peso, y marca la acción destacada de una
// pantalla. Este se apoya en `superficie_alterna`, un solo escalón por
// encima de la tarjeta que lo contiene, para no competir con ella.
//
// La variante `peligro` es para acciones destructivas (eliminar, descartar).
Button {
    id: control

    property real sx: 1
    property real sy: 1
    // "normal" | "peligro"
    property string variante: "normal"

    readonly property bool esPeligro: variante === "peligro"
    readonly property color colorAcento: esPeligro ? Style.Theme.error : Style.Theme.acento

    implicitHeight: 34 * sy
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    font.pixelSize: Math.max(Style.Theme.smallSize, 12 * sy)

    background: Rectangle {
        radius: 8 * control.sx
        color: !control.enabled
               ? Style.Theme.superficie_alterna
               : (control.down || control.hovered
                  ? (control.esPeligro ? Style.Theme.error_fondo : Style.Theme.acento_fondo)
                  : Style.Theme.superficie_alterna)
        border.width: control.hovered || control.activeFocus ? 2 : 1
        border.color: control.hovered || control.activeFocus
                      ? control.colorAcento : Style.Theme.borde_suave
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    contentItem: Text {
        text: control.text
        // El texto toma el acento al pasar el cursor: refuerza la señal de
        // interacción sin cambiar el peso tipográfico, que causaría un
        // salto de ancho.
        color: !control.enabled
               ? Style.Theme.texto_terciario
               : (control.hovered
                  ? (control.esPeligro ? Style.Theme.error_texto : Style.Theme.acento_fuerte)
                  : Style.Theme.texto_primario)
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
