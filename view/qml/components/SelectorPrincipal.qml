import QtQuick
import QtQuick.Controls
import "../styles" as Style

ComboBox {
    id: control

    property real sx: 1
    property real sy: 1

    implicitHeight: 34 * sy

    background: Rectangle {
        radius: 8 * control.sx
        color: control.enabled ? Style.Theme.surface : Style.Theme.superficie_alterna
        border.width: control.activeFocus || control.hovered ? 2 : 1
        border.color: control.activeFocus || control.hovered
                      ? Style.Theme.acento : Style.Theme.borde_suave
    }

    contentItem: Text {
        leftPadding: 11 * control.sx
        rightPadding: control.indicator.width + 6 * control.sx
        text: control.displayText
        color: control.enabled ? Style.Theme.texto_primario : Style.Theme.texto_terciario
        font.pixelSize: 12 * control.sy
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    // Flecha propia: la del estilo por defecto no conoce el tema y
    // desaparece sobre fondo oscuro.
    indicator: Canvas {
        x: control.width - width - 10 * control.sx
        y: control.height / 2 - height / 2
        width: 11 * control.sx
        height: 7 * control.sx
        contextType: "2d"

        // Un Canvas no se repinta solo al cambiar el tema: hay que pedirlo.
        Connections {
            target: Style.Theme
            function onModoOscuroChanged() { control.indicator.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.moveTo(0, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width / 2, height)
            ctx.closePath()
            ctx.fillStyle = Style.Theme.texto_secundario
            ctx.fill()
        }
    }

    popup: Popup {
        y: control.height + 3
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight, 220 * control.sy)
        padding: 4 * control.sx

        background: Rectangle {
            radius: 8 * control.sx
            color: Style.Theme.surface
            border.width: 1
            border.color: Style.Theme.borde_suave
        }

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator { }
        }
    }

    delegate: ItemDelegate {
        id: opcion
        required property var modelData
        required property int index

        width: control.width - 8 * control.sx
        height: 32 * control.sy

        background: Rectangle {
            radius: 6 * control.sx
            color: control.highlightedIndex === opcion.index
                   ? Style.Theme.acento_fondo : "transparent"
        }

        contentItem: Text {
            leftPadding: 8 * control.sx
            text: control.textRole
                  ? opcion.modelData[control.textRole]
                  : opcion.modelData
            color: control.currentIndex === opcion.index
                   ? Style.Theme.acento : Style.Theme.texto_primario
            font.pixelSize: 12 * control.sy
            font.bold: control.currentIndex === opcion.index
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }
}