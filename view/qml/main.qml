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

    ThemeSwitch {
        z: 100
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
    }

    Component.onCompleted: {
        stack.push("screens/WelcomeScreen.qml", {
            "stackView": stack
        })
    }
}