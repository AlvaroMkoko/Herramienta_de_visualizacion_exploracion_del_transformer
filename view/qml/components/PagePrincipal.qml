import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"

Page {

    id: root

    required property StackView stackView

    // Resolución base del diseño
    readonly property real baseWidth: 1920
    readonly property real baseHeight: 1080

    // Factores de escala
    readonly property real sx: width / baseWidth
    readonly property real sy: height / baseHeight

    background: Rectangle {
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Style.Theme.fondo
            }

            GradientStop {
                position: 1
                color: Style.Theme.fondo_gradiente
            }
        }
    }

}