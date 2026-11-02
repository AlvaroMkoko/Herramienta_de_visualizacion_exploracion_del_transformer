pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// Regresa de un clic al mapa de módulos, sin pulsar «Volver» varias veces.
BotonSecundario {
    id: control

    required property StackView stackView

    objectName: "homeButton"
    text: "⌂ Inicio"
    Accessible.description: "Regresa al mapa de módulos"

    function irAlInicio() {
        var mapa = control.stackView.find(function (item) {
            return item.objectName === "moduleMapScreen"
        })
        if (mapa)
            control.stackView.pop(mapa)
        else
            control.stackView.push("../screens/ModuleMapScreen.qml",
                                   { "stackView": control.stackView })
    }

    onClicked: control.irAlInicio()
}
