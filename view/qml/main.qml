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
    visible: true
    width: 1280
    height: 800

     StackView {
        id: stackView
        anchors.fill: parent

        initialItem: "screens/HomeScreen.qml"
    }

    
}
