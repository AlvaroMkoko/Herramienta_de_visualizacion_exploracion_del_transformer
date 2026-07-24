// Ventana principal / navegación raíz.
//
// TODO:
// - ApplicationWindow con StackView o similar para navegar entre
//   screens/ (Setup, Training, Inference, Comparison, Evaluation).
// - Conectar al MainViewModel expuesto desde main.py.

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

        // initialItem: "screens/HomeScreen.qml"
        initialItem: Qt.resolvedUrl("screens/HomeScreen.qml")
    }

    Component.onCompleted: {
        stack.push("screens/HomeScreen.qml", {
            "stackView": stack
        })
    }

    

    
}
