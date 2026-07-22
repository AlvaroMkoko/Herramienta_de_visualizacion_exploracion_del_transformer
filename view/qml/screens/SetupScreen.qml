import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"

PagePrincipal {

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
                

                x: 40 * sx
                y: 480 * sy

                width: 250 * sx
                height: 60 * sy

                text: "Borrar"

                onClicked: {
                    stackView.pop()
                }
                
    }
}