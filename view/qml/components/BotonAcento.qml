import QtQuick
import QtQuick.Controls
import "../styles" as Style

// Llamada a la acción (CTA) de una pantalla: relleno de acento y texto claro.
//
// Regla de uso: como máximo UNO por vista. Si todo es primario, nada lo es.
// `enfasis: "medio"` lo baja a contorno de acento cuando la acción sigue
// siendo relevante pero ya no es la recomendada (p. ej. "Repasar la ruta"
// después de completarla).
Button {
    id: control

    // "alto" | "medio"
    property string enfasis: "alto"
    readonly property bool esAlto: enfasis === "alto"
    readonly property color colorTexto: !enabled
                                        ? Style.Theme.texto_terciario
                                        : (esAlto ? Style.Theme.texto_sobre_acento
                                                  : Style.Theme.acento_texto)

    implicitHeight: 46
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    font.pixelSize: 15
    font.bold: true
    font.family: Style.Theme.fuente_interfaz

    Accessible.role: Accessible.Button
    Accessible.name: text

    background: Rectangle {
        radius: 10
        color: {
            if (!control.enabled)
                return Style.Theme.chip_fondo
            if (control.esAlto)
                return control.down || control.hovered ? Style.Theme.acento_fuerte
                                                       : Style.Theme.acento
            return control.down || control.hovered ? Style.Theme.acento_fondo : "transparent"
        }
        border.width: control.esAlto ? 0 : 1.5
        border.color: Style.Theme.acento
        scale: control.down ? 0.985 : 1.0

        Behavior on color { ColorAnimation { duration: Style.Theme.duracionCorta } }
        Behavior on scale { NumberAnimation { duration: Style.Theme.duracionCorta } }

        // Anillo de foco solo con teclado (visualFocus), separado del botón
        // para que no se confunda con su propio borde.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: parent.radius + 4
            color: "transparent"
            border.width: 2
            border.color: Style.Theme.acento
            visible: control.visualFocus
        }
    }

    contentItem: Item {
        implicitWidth: fila.implicitWidth
        implicitHeight: fila.implicitHeight

        Row {
            id: fila
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: control.text
                font: control.font
                color: control.colorTexto
            }

            // La flecha avanza 3 px al pasar el cursor: dice "esto te lleva
            // a otro lugar" sin añadir texto.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "→"
                font: control.font
                color: control.colorTexto
                Accessible.ignored: true
                transform: Translate {
                    x: control.hovered ? 3 : 0
                    Behavior on x {
                        NumberAnimation {
                            duration: Style.Theme.duracionCorta
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
}
