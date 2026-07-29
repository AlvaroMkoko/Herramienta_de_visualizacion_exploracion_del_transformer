import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"

PagePrincipal {
    id:root

    property bool mostrarTarjeta: false


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
        
        property real size_width: 350
        property real size_height:800
        width:size_width * sx
        height:size_height * sy
        // color: "transparent"
        color:"blue"
        // clip: true          

        
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter   // opcional, si querés centrado vertical
        anchors.rightMargin: 40

        Column{
            anchors.centerIn: parent
            width: parent.size_width *sx

            spacing: 30
            RectanglePrincipal {
                
                id: rectangulo_blanco_1
                width: parent.width 
                sx: root.sx
                sy: root.sy

                

                Column{
                    spacing: 10
                    width: parent.width-30
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

                    text: "Épocas"

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

                    text: "Learning Rate"
                    from: 0
                    to: 0.01
                    stepSize: 0.0001
                    value: 0.25

                    tipo_dato:"decimal"

                    onValueChanged: {
                        console.log("Nuevo valor:", value)
                    }
                }

                 SliderColumn {
                    width: parent.width
                    anchors.margins: 15 * sx

                    sx: root.sx
                    sy: root.sy

                    text: "Batch Size"

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
                width: parent.width 
                // anchors.rightMargin: 400
                sx: root.sx
                sy: root.sy
                // width: 300*sx
                height: 200*sy

            }

            BotonPrincipal {
                        id: botonIniciarEntrenamiento
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 200 * root.sx
                        height: 50 * root.sy
                        anchors.margins: 20

                        text: "Guardar Modelo"

                        onClicked: {
                            stackView.push("TrainingScreen.qml", {
                                "stackView": stackView
                            })
                        }
                    
            }

            

            BotonPrincipal {
                        id: botonPrediccion
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 200 * root.sx
                        height: 50 * root.sy
                        anchors.margins: 20

                        text: "Predicción"

                        onClicked: {
                            stackView.push("InferenceScreen.qml", {
                                "stackView": stackView
                            })
                        }
                    
            }
        }
    }


    
    // Rectangle{
        
    //     width:300 * sx
    //     height:700 * sy
    //     // color: "transparent"
    //     color:"blue"

        

    //     anchors.verticalCenter: parent.verticalCenter
    //     anchors.verticalCenterOffset: 2 * sy
    //     anchors.left: parent.left
    //     anchors.leftMargin: 20 * sx

    //     Column{
    //         width: parent.width
    //         anchors.centerIn: parent.centerIn
    //         anchors.top: parent.top
    //         anchors.topMargin: 60 * sy
    //         spacing: 30


    //         RectanglePrincipal {
                
    //             id: rectangulo_blanco_4
    //             anchors.left: parent.left
    //             anchors.rightMargin: 400
    //             sx: root.sx
    //             sy: root.sy

    //             width: 300 * sx

    //             Column{
    //                 anchors.centerIn: parent

    //                 BotonPrincipal {
    //                     id: botonModelo
    //                     // anchors.bottom: parent
    //                     anchors.bottomMargin: 20


    //                     width: 200 * root.sx
    //                     height: 60 * root.sy

    //                     text: "Gestionar DataSet"

    //                     // onClicked: {
    //                     //     stackView.push("TrainingScreen.qml", {
    //                     //         "stackView": stackView
    //                     //     })
    //                     // }
    //                     onClicked: {
    //                         root.mostrarTarjeta = !root.mostrarTarjeta
    //                     }
                    
    //                 }

    //             }


    //         }
   
    //     }

            
    // }

    // Rectangle{
    //     property real size_width: 300
    //     width:size_width * sx
    //     height:700 * sy
    //     // color: "transparent"
    //     color:"transparent"

        

    //     anchors.verticalCenter: parent.verticalCenter
    //     anchors.centerIn: parent

    //     visible: opacity > 0
    //     opacity: root.mostrarTarjeta ? 1 : 0

    //     Behavior on opacity {
    //         NumberAnimation {
    //             duration: 300
    //         }
    //     }
    //     RectanglePrincipal{
    //         id: rectangulo_blanco_5
    //         anchors.left: parent.left
    //         // anchors.rightMargin: 400
    //         sx: root.sx
    //         sy: root.sy

    //         width: parent.size_width * sx
    //         // width: 300 * sx
    //         Column{
    //                 spacing: 10
    //                 width: parent.width-30
    //                 anchors.margins: 15 * sx


    //                  SliderColumn {
    //                         width: parent.width 
    //                         // anchors.fill: parent
    //                         anchors.margins: 30 * sx

    //                         sx: root.sx
    //                         sy: root.sy

    //                         text: "Capas Encoder (Nx)"

    //                         from: 1
    //                         to: 24

    //                         stepSize: 1
    //                         value: 6

    //                         onValueChanged: {
    //                             console.log("Nuevo valor:", value)
    //                         }
    //                     }

    //                 SliderColumn {
    //                 // anchors.fill: parent
    //                     width: parent.width
    //                     anchors.margins: 15 * sx

    //                     sx: root.sx
    //                     sy: root.sy

    //                     text: "Épocas"

    //                     from: 1
    //                     to: 24

    //                     stepSize: 1
    //                     value: 6

    //                     onValueChanged: {
    //                         console.log("Nuevo valor:", value)
    //                     }
    //                 }
                 
    //             }

    //             }


    //     }

    }
        
    
