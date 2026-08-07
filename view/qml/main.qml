// Ventana principal / navegación raíz.

import QtQuick
import QtQuick.Controls
import "styles" as Style

ApplicationWindow {
    id: window
    visible: true
    width: Style.Theme.baseWidth
    height: Style.Theme.baseHeight

    StackView {
        id: stack
        anchors.fill: parent
    }

    Component.onCompleted: {
        stack.push("screens/HomeScreen.qml", {
            "stackView": stack
        })
    }
}