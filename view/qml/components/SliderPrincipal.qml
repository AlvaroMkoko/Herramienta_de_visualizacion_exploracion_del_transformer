import QtQuick
import QtQuick.Controls
import "../styles" as Style

// Slider con la estética de la herramienta. Es SOLO el control: la
// etiqueta y el valor los pone quien lo use (ver SliderColumn). Así lo
// pueden compartir tanto las pantallas de configuración como los sliders
// sueltos de las escenas de visualización.
Slider {
    id: control

    property real sx: 1
    property real sy: 1

    // Permite que una escena conserve su color de identidad sin renunciar
    // al resto del estilo. Por defecto usa el acento de la marca.
    property color colorRelleno: Style.Theme.acento

    snapMode: Slider.SnapAlways
    implicitHeight: 24 * sy

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: 6 * control.sy
        radius: height / 2
        color: Style.Theme.divisor

        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: control.enabled ? control.colorRelleno : Style.Theme.texto_terciario
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: 22 * control.sx
        height: width
        radius: width / 2
        color: control.enabled ? control.colorRelleno : Style.Theme.texto_terciario
        // El borde del color de la superficie separa la perilla de la barra
        // en ambos temas, sin necesidad de una sombra.
        border.width: 3
        border.color: Style.Theme.surface

        scale: control.pressed ? 1.15 : (control.hovered ? 1.08 : 1.0)
        Behavior on scale { NumberAnimation { duration: 120 } }
    }
}