pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../styles" as Style

// Ficha de un reactivo de asignación: el rectángulo con el texto de un elemento,
// que se puede tocar y arrastrar. La usan las tres disposiciones (ordenar,
// cestas, relacionar) para que una ficha se vea y se comporte igual en todas.
//
// El arrastre mueve un hijo interno, no la ficha: la ficha la posiciona el
// Layout que la contiene, y moverla directamente pelearía con el layout y la
// dejaría saltando. Al soltar, el hijo vuelve a su sitio y quien decide qué
// pasó es el DropArea del destino.
//
// Mientras se arrastra, el cuerpo se muda a la capa superior de la ventana:
// dentro del ScrollView del examen quedaba recortado y por debajo de las
// ranuras. Al soltar, la ficha se entrega a mano al área que tiene debajo
// (`Drag.target`, que debe declarar `function recibir(elementoId)`). Ni
// `Drag.drop()` ni `onDropped` sirven aquí: MouseArea termina el arrastre al
// soltar el botón y el evento de soltar ya no llega a ningún DropArea, así que
// el destino nunca recibía la ficha y el arrastre sólo «parecía» funcionar.
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

    // Capa donde viaja la ficha mientras se arrastra.
    readonly property Item capaArrastre: Overlay.overlay
    property bool huboArrastre: false

    function soltar() {
        var destino = cuerpo.Drag.target
        cuerpo.Drag.active = false
        if (destino && typeof destino.recibir === "function")
            destino.recibir(ficha.elementoId)
    }

    implicitHeight: Math.max(46 * ficha.sy, etiqueta.implicitHeight + 22 * ficha.sy)

    Rectangle {
        id: cuerpo
        width: ficha.width
        height: ficha.height
        radius: 10 * ficha.sx
        z: cuerpo.Drag.active ? 10 : 0

        color: ficha.seleccionada
               ? Style.Theme.acento_fondo
               : (arrastre.containsMouse
                  ? Style.Theme.superficie_alterna : Style.Theme.surface)
        border.width: ficha.seleccionada ? 2 : 1
        border.color: ficha.seleccionada
                      ? Style.Theme.acento
                      : (arrastre.containsMouse
                         ? Style.Theme.acento_alt : Style.Theme.borde_suave)
        opacity: cuerpo.Drag.active ? 0.9 : 1
        scale: cuerpo.Drag.active ? 1.03 : 1

        Behavior on color { ColorAnimation { duration: 110 } }

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
            // El ScrollView del examen no debe robarse el gesto para desplazar.
            preventStealing: true

            drag.onActiveChanged: {
                if (arrastre.drag.active) {
                    ficha.huboArrastre = true
                    cuerpo.Drag.active = true
                } else if (cuerpo.Drag.active) {
                    ficha.soltar()
                }
            }

            onPressed: ficha.huboArrastre = false
            // Un arrastre terminado no cuenta como toque.
            onReleased: {
                cuerpo.x = 0
                cuerpo.y = 0
                if (!ficha.huboArrastre)
                    ficha.tocada()
            }
            onCanceled: {
                cuerpo.Drag.cancel()
                cuerpo.x = 0
                cuerpo.y = 0
            }
        }

        states: State {
            name: "arrastrando"
            when: cuerpo.Drag.active && ficha.capaArrastre !== null
            ParentChange { target: cuerpo; parent: ficha.capaArrastre }
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: ficha.texto
    Accessible.description: ficha.colocada ? "Colocada. Actívala para devolverla."
                                           : "Sin colocar. Actívala para tomarla."
    Accessible.onPressAction: ficha.tocada()
}
