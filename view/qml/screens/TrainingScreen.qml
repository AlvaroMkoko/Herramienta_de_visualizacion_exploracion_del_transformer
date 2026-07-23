import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"

PagePrincipal {
    id:root

    // required property StackView stackView


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
    
    // BotonPrincipal {
    //     text: "Volver"
    //     x:20
    //     y:600

    //     onClicked: {
    //         stackView.pop()
    //     }
    // }

    BotonPrincipal {
                
                anchors.left: parent.left
                anchors.leftMargin: 10 * sx
                anchors.top: parent.top
                anchors.topMargin: 10 * sy
                width: 250 * sx
                height: 40 * sy

                text: " ↶ Volever al inicio"

                onClicked: {
                    stackView.pop()
                }
                
    }

}