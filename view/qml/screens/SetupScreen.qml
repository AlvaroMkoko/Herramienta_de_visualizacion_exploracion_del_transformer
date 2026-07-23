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

    Rectangle{
        
        width:500 * sx
        height:800 * sy
        color: "transparent"
        // color:"blue"
        // clip: true          // 👈 corta cualquier hijo que se salga del área

        
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter   // opcional, si querés centrado vertical
        anchors.rightMargin: 40

        Column{
            
            // anchors.centerIn: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: -100* sy
            spacing: 30
            RectanglePrincipal {
                
                id: rectangulo_blanco_1
                anchors.rightMargin: 400
                sx: root.sx
                sy: root.sy

                width: 300*sx
                Column{
                    spacing: 10
                    width: parent.width
                    // property real padding: 20 * sx
                    // leftPadding: padding
                    // rightPadding: padding
                    anchors.margins: 15 * sx


                     SliderColumn {
                        width: parent.width
                        // anchors.fill: parent
                        anchors.margins: 30 * sx

                        sx: root.sx
                        sy: root.sy

                        text: "Capas Encoder (Nx)"

                        from: 1
                        to: 24

                        stepSize: 1
                        value: 6

                        onValueChanged: {
                            console.log("Nuevo valor:", value)
                        }
                    }
                    SliderColumn {
                    // anchors.fill: parent
                    width: parent.width
                    anchors.margins: 15 * sx

                    sx: root.sx
                    sy: root.sy

                    text: "Capas Encoder (Nx)"

                    from: 1
                    to: 24

                    stepSize: 1
                    value: 6

                    onValueChanged: {
                        console.log("Nuevo valor:", value)
                    }
                }
                 SliderColumn {
                    // anchors.fill: parent
                    width: parent.width
                    anchors.margins: 15 * sx

                    sx: root.sx
                    sy: root.sy

                    text: "Capas Encoder (Nx)"

                    from: 1
                    to: 24

                    stepSize: 1
                    value: 6

                    onValueChanged: {
                        console.log("Nuevo valor:", value)
                    }
                }

                 SliderColumn {
                    // anchors.fill: parent
                    width: parent.width
                    anchors.margins: 15 * sx

                    sx: root.sx
                    sy: root.sy

                    text: "Capas Encoder (Nx)"

                    from: 1
                    to: 24

                    stepSize: 1
                    value: 6

                    onValueChanged: {
                        console.log("Nuevo valor:", value)
                    }
                }

                }
                
    
                
                

            }

            RectanglePrincipal{

                id: rectangulo_blanco_2
                anchors.rightMargin: 400
                sx: root.sx
                sy: root.sy
                width: 300*sx
                height: 200*sy

            }
        }
    }


    
    Rectangle{
        
        width:500 * sx
        height:700 * sy
        // color: "transparent"
        color:"blue"

        

        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 2 * sy
        anchors.left: parent.left
        anchors.leftMargin: 20 * sx

        Column{
            width: parent.width
            anchors.centerIn: parent.centerIn
            anchors.top: parent.top
            anchors.topMargin: 60 * sy
            spacing: 30


            RectanglePrincipal {
                
                id: rectangulo_blanco_3
                anchors.left: parent.left
                anchors.rightMargin: 400
                sx: root.sx
                sy: root.sy

                width: 300 * sx

                Column{
                    anchors.centerIn: parent

                    BotonPrincipal {
                        id: botonModelo
                        // anchors.bottom: parent
                        anchors.bottomMargin: 20


                        width: 200 * root.sx
                        height: 60 * root.sy

                        text: "Abrir Modelo"

                        onClicked: {
                            stackView.push("TrainingScreen.qml", {
                                "stackView": stackView
                            })
                        }
                    
                    }

                }


            }
                
    
                
                

            }

            
        }
    
}