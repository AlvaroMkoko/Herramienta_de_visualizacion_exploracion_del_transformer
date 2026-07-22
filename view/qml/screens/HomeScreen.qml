import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"
import "../components"

PagePrincipal {


    Rectangle{
        anchors.fill: parent
        color: "transparent"
        // anchors.centerIn: parent
        // anchors.horizontalCenter: parent.horizontalCenter
        // anchors.verticalCenter: parent.verticalCenter

        Row{
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -300



            // width: 800; height: 400
            
            // anchors.horizontalCenter: parent.horizontalCenter
            // anchors.verticalCenter: parent.verticalCenter
            // anchors.verticalCenterOffset: -80   // Baja 80 píxeles


            spacing: 80


            Rectangle {
            id: rectangulo_blanco_1

            x: 200 * sx
            y: 550 * sy

            width: 350 * sx
            height: 350 * sy

            radius: 10 * sx

            color: "white"
            border.color: Style.Theme.borde_cuadro

            Column {
                anchors.centerIn: parent
                spacing: 20 * sy

                
                // Text {
                //     anchors.top: parent
                //     text: "Books"
                //     font.pixelSize: 24 * sx
                // }
            
            
                // Text {
                //     anchors.centerIn: parent
                //     text: "Music"
                //     font.pixelSize: 24 * sx
                // }
                
            // BotonPrincipal.qml
            BotonPrincipal {
                    id: botonInicio
                    // anchors.bottom: parent
                    anchors.bottomMargin: 20

                    // x: 129 * sx
                    // y: 480 * sy

                    width: 300 * sx
                    height: 60 * sy

                    text: "Iniciar Entorno"

                    onClicked: {
                        stackView.push("SetupScreen.qml", {
                            "stackView": stackView
                        })
                    }
                    
                }
            }
        }
        Rectangle {
            id: rectangulo_blanco_2

            x: 200 * sx
            y: 550 * sy

            width: 350 * sx
            height: 350 * sy

            radius: 10 * sx

            color: "white"
            border.color: Style.Theme.borde_cuadro

            Column {
                anchors.centerIn: parent
                spacing: 20 * sy

                
                // Text {
                //     anchors.top: parent
                //     text: "Books"
                //     font.pixelSize: 24 * sx
                // }
            
            
                // Text {
                //     anchors.centerIn: parent
                //     text: "Music"
                //     font.pixelSize: 24 * sx
                // }
                
            
            // BotonPrincipal.qml
            BotonPrincipal {
                    id: botonModelo
                    // anchors.bottom: parent
                    anchors.bottomMargin: 20

                    // x: 129 * sx
                    // y: 480 * sy

                    width: 300 * sx
                    height: 60 * sy

                    text: "Abrir Modelo"

                    onClicked: {
                        stackView.push("SetupScreen.qml", {
                            "stackView": stackView
                        })
                    }
                    
                }
            }
        }

            Rectangle {
            id: rectangulo_blanco_3

            x: 200 * sx
            y: 550 * sy

            width: 350 * sx
            height: 350 * sy

            radius: 10 * sx

            color: "white"
            border.color: Style.Theme.borde_cuadro

            Column {
                anchors.centerIn: parent
                spacing: 20 * sy

                
                // Text {
                //     anchors.top: parent
                //     text: "Books"
                //     font.pixelSize: 24 * sx
                // }
            
            
                // Text {
                //     anchors.centerIn: parent
                //     text: "Music"
                //     font.pixelSize: 24 * sx
                // }
                
            // BotonPrincipal.qml
            BotonPrincipal {
                    id: botonComparacion
                    // anchors.bottom: parent
                    anchors.bottomMargin: 20

                    // x: 129 * sx
                    // y: 480 * sy

                    width: 300 * sx
                    height: 60 * sy

                    text: "Abrir Comparación"

                    onClicked: {
                        stackView.push("SetupScreen.qml", {
                            "stackView": stackView
                        })
                    }
                    
                }
            }
        }

        }

    }



    Rectangle{
        // width:1280
        height:50
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.left: parent.left
        color:"white"
        radius:7

        border.color: Style.Theme.borde_cuadro


        BotonPrincipal {
                    id: botonCargarDataSet
                    anchors.bottom: parent.bottom
                    anchors.left : parent.left
                    anchors.centerIn: parent
                    // anchors.bottom: parent
                    // anchors.bottomMargin: 

                    // x: 129 * sx
                    // y: 480 * sy

                    width: 100 * sx
                    height: 35 * sy

                    text: "Cargar Dataset"

                    onClicked: {
                        stackView.push("SetupScreen.qml", {
                            "stackView": stackView
                        })
                    }
                    
                }
        
    }

    

    

    
}