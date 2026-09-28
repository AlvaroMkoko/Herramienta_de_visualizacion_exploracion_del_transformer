// Ventana principal / navegación raíz.

import QtQuick
import QtQuick.Controls
import "styles" as Style
import "components"

ApplicationWindow {
    id: window
    visible: true
    width: Style.Theme.baseWidth
    height: Style.Theme.baseHeight
    minimumWidth: Style.Theme.baseWidth
    minimumHeight: Style.Theme.baseHeight
    title: "Visualizador de Transformers"

    StackView {
        id: stack
        objectName: "mainNavigation"
        anchors.fill: parent

        // Transición única para TODAS las pantallas: la nueva aparece y sube
        // un poco; al volver (pop), la que se va baja y se desvanece. La
        // dirección del movimiento dice "avanzo" o "regreso" sin palabras.
        // Se usan NumberAnimation y no OpacityAnimator/YAnimator: los Animator
        // dependen del hilo de render y, si la ventana aún no pinta (primer
        // push), la página puede quedarse congelada en opacidad 0.
        readonly property int _dur: Style.Theme.movimientoReducido ? 0 : Style.Theme.duracionEntrada
        readonly property int _durSalida: Style.Theme.movimientoReducido ? 0 : Style.Theme.duracionMedia
        readonly property real _dist: Style.Theme.movimientoReducido ? 0 : 18

        pushEnter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: stack._dur; easing.type: Easing.OutCubic }
                NumberAnimation { property: "y"; from: stack._dist; to: 0; duration: stack._dur; easing.type: Easing.OutCubic }
            }
        }
        pushExit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: stack._durSalida; easing.type: Easing.OutCubic }
        }
        popEnter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: stack._dur; easing.type: Easing.OutCubic }
        }
        popExit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: stack._durSalida; easing.type: Easing.InCubic }
                NumberAnimation { property: "y"; from: 0; to: stack._dist; duration: stack._durSalida; easing.type: Easing.InCubic }
            }
        }
        replaceEnter: pushEnter
        replaceExit: pushExit
    }

    ThemeSwitch {
        z: 100
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
    }

    Component.onCompleted: {
        // La primera pantalla aparece sin transición: no hay de dónde venir.
        stack.push("screens/ProfileSelectionScreen.qml", {
            "stackView": stack
        }, StackView.Immediate)
    }
}
