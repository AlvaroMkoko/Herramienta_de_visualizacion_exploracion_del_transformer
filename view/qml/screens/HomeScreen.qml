import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"

Page {

    required property StackView stackView

    // anchors.fill: parent

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

    BotonPrincipal{
        text: "Iniciar"


        onClicked: {
            stackView.push("SetupScreen.qml", {
                "stackView": stackView
            })
        }
    }

}