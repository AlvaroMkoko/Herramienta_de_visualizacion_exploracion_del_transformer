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

    StackView {
        id: stack
        anchors.fill: parent
    }

    BotonPrincipal {
        id: botonTema
        z: 100
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        width: 150
        height: 36
        size_text: 0.30
        text: Style.Theme.modoOscuro ? "☀ Modo claro" : "🌙 Modo oscuro"
        onClicked: Style.Theme.alternarModo()
    }

    Component.onCompleted: {
        stack.push("screens/HomeScreen.qml", {
            "stackView": stack
        })
    }
}