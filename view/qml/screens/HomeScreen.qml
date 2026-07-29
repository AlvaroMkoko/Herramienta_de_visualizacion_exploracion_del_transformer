import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"
import Vispy 1.0



PagePrincipal {
    id:root

    Rectangle{
        anchors.fill: parent
        color: "transparent"
   
        Row{
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 45 * sy



            spacing: 80*sx

            /*
            ===== COMPONENTE EN RectanglePrincipal===
            */
            RectanglePrincipal {
            id: rectangulo_blanco_1

            sx: root.sx
            sy: root.sy

            Column {
                anchors.centerIn: parent
                spacing: 20 * root.sy

                
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

                        width: 300 * root.sx
                        height: 60 * root.sy

                        text: "Iniciar Entorno"

                        onClicked: {
                            stackView.push("SetupScreen.qml", {
                                "stackView": stackView
                            })
                        }
                        
                    }
            }
        }
        RectanglePrincipal {
            id: rectangulo_blanco_2

            sx: root.sx
            sy: root.sy

            Column {
                anchors.centerIn: parent
                spacing: 20 * root.sy

                
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

                    width: 300 * root.sx
                    height: 60 * root.sy

                    text: "Abrir Modelo"

                    onClicked: {
                        stackView.push("SetupScreen.qml", {
                            "stackView": stackView
                        })
                    }
                    
                }
            }
        }

            RectanglePrincipal {
            id: rectangulo_blanco_3
            sx: root.sx
            sy: root.sy
                

            Column {
                anchors.centerIn: parent
                spacing: 20 * root.sy

                
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

                    width: 300 * root.sx
                    height: 60 * root.sy

                    text: "Abrir Comparación"

                    onClicked: {
                        stackView.push("ComparisonScreen.qml", {
                            "stackView": stackView
                        })
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
        
        


        
        
        Row {
            spacing: 10

            Rectangle {
                width: 150
                height: 50
                color: "blue"

                Text {
                    anchors.centerIn: parent

                    text: "Proyectos"
                    color: Style.Theme.texto_primario
                    font.pixelSize: Math.min(parent.width, parent.height) * 0.30
                    font.bold: false
                }
            }

            BotonPrincipal {
                id: botonCargarDataSet

                width: 120 * root.sy
                height: 35 * root.sy
                

                text: "Cargar Dataset"

                onClicked: {
                    stackView.push("SetupScreen.qml", {
                        "stackView": stackView
                    })
                }
               
            }
        }

        
        
    }

    Rectangle {

        anchors.fill: parent
        color: "transparent"
        z:10


        VispyItem {

            id: matriz

            anchors.centerIn: parent

            width: 400
            height: 400
        }


        Button {

            text: "Mostrar matriz"

            anchors.bottom: parent.bottom


            onClicked: {

                matriz.setMatrix([
                    [0,1,0,1],
                    [1,1,0,0],
                    [0,0,1,1],
                    [1,0,1,0]
                ])
            }
        }
    }

    

    

    
}
}

