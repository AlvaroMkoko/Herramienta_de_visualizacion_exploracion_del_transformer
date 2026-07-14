// Ventana principal / navegación raíz.
//
// TODO:
// - ApplicationWindow con StackView o similar para navegar entre
//   screens/ (Setup, Training, Inference, Comparison, Evaluation).
// - Conectar al MainViewModel expuesto desde main.py.

import QtQuick
import QtQuick.Controls

ApplicationWindow {
    visible: true
    width: 1280
    height: 800
    title: "Transformer Visualizer"

    // TODO: StackView { id: navStack; anchors.fill: parent }
}
