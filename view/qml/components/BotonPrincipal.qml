import QtQuick
import QtQuick.Controls
import "../styles" as Style


    Button {
        id: button
        anchors.centerIn: parent

        width: 120
        height: 25
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
            font.pixelSize: 14
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