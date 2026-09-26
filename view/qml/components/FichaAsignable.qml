pragma ComponentBehavior: Bound

import QtQuick
import "../styles" as Style

// Ficha de un reactivo de asignación: el rectángulo con el texto de un elemento,
// que se puede tocar y arrastrar. La usan las tres disposiciones (ordenar,
// cestas, relacionar) para que una ficha se vea y se comporte igual en todas.
//
// El arrastre mueve un hijo interno, no la ficha: la ficha la posiciona el
// Layout que la contiene, y moverla directamente pelearía con el layout y la
// dejaría saltando. Al soltar, el hijo vuelve a su sitio y quien decide qué
// pasó es el DropArea del destino.
Item {
    id: ficha

    property string elementoId: ""
    property string texto: ""
    property string insignia: ""      // número de orden, letra de par…
    property color colorInsignia: Style.Theme.acento
    property bool seleccionada: false
    property bool colocada: false
    property bool arrastrable: true
    property real sx: 1
    property real sy: 1

    signal tocada()

    implicitHeight: Math.max(46 * ficha.sy, etiqueta.implicitHeight + 22 * ficha.sy)

    Rectangle {
        id: cuerpo
        width: ficha.width
        height: ficha.height
        radius: 10 * ficha.sx
        z: arrastre.drag.active ? 10 : 0

        color: ficha.seleccionada
               ? Style.Theme.acento_fondo
               : (arrastre.containsMouse
                  ? Style.Theme.superficie_alterna : Style.Theme.surface)
        border.width: ficha.seleccionada ? 2 : 1
        border.color: ficha.seleccionada
                      ? Style.Theme.acento
                      : (arrastre.containsMouse
                         ? Style.Theme.acento_alt : Style.Theme.borde_suave)
        opacity: arrastre.drag.active ? 0.85 : 1

        Behavior on color { ColorAnimation { duration: 110 } }

        Drag.active: arrastre.drag.active
        Drag.source: ficha
        Drag.hotSpot.x: cuerpo.width / 2
        Drag.hotSpot.y: cuerpo.height / 2

        Rectangle {
            id: insignia
            anchors.left: parent.left
            anchors.leftMargin: 11 * ficha.sx
            anchors.verticalCenter: parent.verticalCenter
            visible: ficha.insignia !== ""
            width: visible ? 26 * ficha.sx : 0
            height: 26 * ficha.sx
            radius: width / 2
            color: ficha.colorInsignia

            Text {
                anchors.centerIn: parent
                text: ficha.insignia
                color: Style.Theme.texto_sobre_acento
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 12 * ficha.sx
                font.bold: true
            }
        }

        Text {
            id: etiqueta
            anchors.left: insignia.visible ? insignia.right : parent.left
            anchors.leftMargin: insignia.visible ? 10 * ficha.sx : 14 * ficha.sx
            anchors.right: parent.right
            anchors.rightMargin: 14 * ficha.sx
            anchors.verticalCenter: parent.verticalCenter
            text: ficha.texto
            color: Style.Theme.texto_primario
            font.family: Style.Theme.fuente_interfaz
            font.pixelSize: 14 * ficha.sx
            lineHeight: 1.2
            wrapMode: Text.WordWrap
        }

        MouseArea {
            id: arrastre
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            drag.target: ficha.arrastrable ? cuerpo : null
            drag.smoothed: true

            // El clic no debe dispararse al terminar un arrastre, así que se
            // usa onReleased y se distingue por si el arrastre estaba activo.
            onReleased: {
                var arrastraba = arrastre.drag.active
                cuerpo.x = 0
                cuerpo.y = 0
                if (!arrastraba)
                    ficha.tocada()
            }
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: ficha.texto
    Accessible.description: ficha.colocada ? "Colocada. Actívala para devolverla."
                                           : "Sin colocar. Actívala para tomarla."
    Accessible.onPressAction: ficha.tocada()
}
