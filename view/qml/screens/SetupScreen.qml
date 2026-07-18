import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"

Page {

    required property StackView stackView

    BotonPrincipal {
        text: "Volver"

        onClicked: {
            stackView.pop()
        }
    }
}