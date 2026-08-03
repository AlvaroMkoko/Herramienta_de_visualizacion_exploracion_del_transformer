import QtQuick
import QtQuick.Controls
import "../styles" as Style


    Button {
        
        /*
        Boton lo que esta comentado es lo que se tiene que poner
        cuando uses el modulo dentro de una Pagina
        El "text: "hola"
        onClicked: {
            stackView.push("SetupScreen.qml", {
                "stackView": stackView
            })
        }
        */
        property real size_text: 0.30

        id: button
        
        //x: 0
        //y: 0
        implicitWidth: 120
        implicitHeight: 25
        
        // text: "Iniciar"

        hoverEnabled: true

        background: Rectangle {
            anchors.fill: parent
            radius: 9

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: button.down
                           ? Style.Theme.boton_presionado
                           : Style.Theme.boton
                }

                GradientStop {
                    position: 1.0
                    color: button.down
                           ? Style.Theme.boton_presionado
                           : Style.Theme.boton_gradiente
                }
            }

            border.width: button.hovered ? 1.72 : 1
            border.color: button.hovered ? Style.Theme.borde : Style.Theme.borde_boton

            Behavior on border.width {
                NumberAnimation { duration: 150 }
            }

            Behavior on scale {
                NumberAnimation { duration: 120 }
            }

            scale: button.down ? 0.97 : 1.0
        }

        contentItem: Text {
            text: button.text
            color: Style.Theme.texto_primario
            // font.pixelSize: Math.min(button.width, button.height) * button.size_text
            font.pixelSize: button.height * button.size_text
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        // onClicked: {
        //     stackView.push("SetupScreen.qml", {
        //         "stackView": stackView
        //     })
        // }
    }