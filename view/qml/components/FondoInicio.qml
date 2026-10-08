import QtQuick
import "../styles" as Style

// Fondo ambiental para las pantallas que funcionan como puerta de entrada.
// La red es puramente decorativa: su contraste bajo conserva la legibilidad
// y no participa en el orden de foco ni en el árbol de accesibilidad.
Item {
    id: root

    property real intensidad: 1.0
    property bool mostrarRed: true

    clip: true
    Accessible.ignored: true

    Rectangle {
        width: Math.max(360, Math.min(610, root.width * 0.48))
        height: width
        radius: width / 2
        x: root.width - width * 0.72
        y: -height * 0.46
        color: Style.Theme.acento_fondo
        opacity: (Style.Theme.modoOscuro ? 0.34 : 0.62) * root.intensidad
    }

    Rectangle {
        width: Math.max(260, Math.min(440, root.width * 0.34))
        height: width
        radius: width / 2
        x: -width * 0.50
        y: root.height - height * 0.48
        color: Style.Theme.info_fondo
        opacity: (Style.Theme.modoOscuro ? 0.22 : 0.42) * root.intensidad
    }

    // Halo secundario que enlaza visualmente los dos acentos de la interfaz.
    Rectangle {
        width: Math.max(180, Math.min(300, root.width * 0.24))
        height: width
        radius: width / 2
        x: root.width * 0.58
        y: root.height - height * 0.34
        color: Style.Theme.proceso_fondo
        opacity: (Style.Theme.modoOscuro ? 0.16 : 0.30) * root.intensidad
    }

    Canvas {
        id: conexiones
        visible: root.mostrarRed
        anchors.right: parent.right
        anchors.top: parent.top
        width: Math.min(root.width * 0.46, 590)
        height: Math.min(root.height * 0.42, 330)
        opacity: (Style.Theme.modoOscuro ? 0.34 : 0.44) * root.intensidad

        property color colorLinea: Style.Theme.acento
        property color colorNodo: Style.Theme.acento_alt

        onColorLineaChanged: requestPaint()
        onColorNodoChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.lineWidth = 1.2
            ctx.strokeStyle = colorLinea.toString()

            var puntos = [
                [0.12, 0.22], [0.34, 0.10], [0.38, 0.42],
                [0.62, 0.24], [0.69, 0.62], [0.88, 0.40], [0.92, 0.78]
            ]
            var enlaces = [[0,1], [0,2], [1,3], [2,3], [2,4],
                            [3,4], [3,5], [4,5], [4,6], [5,6]]

            for (var i = 0; i < enlaces.length; ++i) {
                var a = puntos[enlaces[i][0]]
                var b = puntos[enlaces[i][1]]
                ctx.beginPath()
                ctx.moveTo(a[0] * width, a[1] * height)
                ctx.lineTo(b[0] * width, b[1] * height)
                ctx.stroke()
            }

            ctx.fillStyle = colorNodo.toString()
            for (var j = 0; j < puntos.length; ++j) {
                ctx.beginPath()
                ctx.arc(puntos[j][0] * width, puntos[j][1] * height,
                        j === 3 ? 5.5 : 3.5, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }

    // Trama casi imperceptible que evita grandes superficies planas.
    Grid {
        anchors.left: parent.left
        anchors.leftMargin: Math.max(28, root.width * 0.035)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
        columns: 7
        rowSpacing: 12
        columnSpacing: 12
        opacity: (Style.Theme.modoOscuro ? 0.20 : 0.28) * root.intensidad

        Repeater {
            model: 28
            Rectangle {
                required property int index
                width: index % 8 === 0 ? 4 : 3
                height: width
                radius: width / 2
                color: Style.Theme.acento
            }
        }
    }
}
