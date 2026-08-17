import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"
import Vispy 1.0
import QtQuick.Layouts




PagePrincipal {
    id:root

    Rectangle{
        anchors.fill: parent
        color: "transparent"


    Rectangle {
    width: 500 * sx
    height: 300 * sy
    color: "blue"

    anchors.centerIn: parent
    anchors.verticalCenterOffset: -320 * sy

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15 * sx
        spacing: 10 * sy

        // Estado**
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 200 * sx
            Layout.preferredHeight: 24 * sy

            radius: height / 2
            color: "#EAF7EE"

            Row {
                anchors.centerIn: parent
                spacing: 4 * sx

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8 * sx
                    height: 8 * sy
                    radius: width / 2
                    color: "#2E7D68"
                }

                Text {
                    text: "SISTEMA ACTIVO"
                    color: "#355D57"
                    font.bold: true
                    font.pixelSize: 11 * sy
                }
            }
        }

        // Título
        Text {
            Layout.fillWidth: true

            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.RichText
            text: "<font color='#111111'>Explorador </font><font color='#6A63E8'>Transformer</font>"

            font.bold: true
            font.pixelSize: 22 * sy
        }

        // Subtítulo
        Text {
            Layout.fillWidth: true

            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap

            text: "Entorno de simulación para entrenamiento y exploración de modelos Transformer."

            color: "#777777"
            font.pixelSize: 12 * sy
        }

        // Este Item absorbe el espacio restante
        Item {
            Layout.fillHeight: true
        }

        // Placeholder
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120 * sy

            radius: 8 * sx
            color: "#F6F6F6"

            border.width: 1 * sx
            border.color: "#CFCFCF"

            Text {
                anchors.centerIn: parent
                text: "Visualización del Transformer"
                color: "#8A8A8A"
                font.bold: true
                font.pixelSize: 14 * sy
            }
        }
    }
}
    Rectangle{
        color:"blue"
        anchors.centerIn: parent
        anchors.verticalCenterOffset:100 * sy
        
        width:1500 * sx
        height:350 * sy
        RowLayout {
                // anchors.centerIn: parent
                anchors.fill: parent
                // anchors.margins: 10 * sx

                // anchors.verticalCenterOffset:100 * sy

                
                spacing: 210 * sx

                /*
                ===== Tarjeta 1 =====
                */
                RectanglePrincipal {
                    Layout.fillWidth: true
                    id: rectangulo_blanco_1

                    sx: root.sx
                    sy: root.sy

                    // Layout.fillWidth: true
                    Layout.preferredWidth: 350*sx
                    Layout.preferredHeight: 350 * sy

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20 * sx

                        spacing: 20 * sy

                        Text {
                            Layout.fillWidth: true

                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap

                            text: "Entorno de simulación para entrenamiento\n y exploración de modelos Transformer."

                            color: "#777777"
                            font.pixelSize: 12 * sy
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        BotonPrincipal {
                            id: botonInicio
                            

                            Layout.alignment: Qt.AlignHCenter


                            // width: 300 * sx
                            // height: 60 * sy
                            Layout.preferredWidth: 300*sx
                            Layout.preferredHeight: 60 * sy

                            text: "Iniciar Entorno"

                            onClicked: {
                                stackView.push("SetupScreen.qml", {
                                    "stackView": stackView
                                })
                            }
                        }
                    }
                }

                /*
                ===== Tarjeta 2 =====
                */
                RectanglePrincipal {
                    Layout.fillWidth: true
                    id: rectangulo_blanco_2

                    sx: root.sx
                    sy: root.sy

                    // Layout.fillWidth: true
                    Layout.preferredWidth: 350*sx
                    Layout.preferredHeight: 350 * sy

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20 * sx

                        spacing: 20 * sy

                        Item {
                            Layout.fillHeight: true
                        }

                        BotonPrincipal {
                            id: botonModelo

                            Layout.alignment: Qt.AlignHCenter

                            Layout.preferredWidth: 300*sx
                            Layout.preferredHeight: 60 * sy

                            text: "Abrir Modelo"

                            onClicked: {
                                stackView.push("ModelLibraryScreen.qml", {
                                    "stackView": stackView
                                })
                            }
                        }
                    }
                }

                /*
                ===== Tarjeta 3 =====
                */
                RectanglePrincipal {
                    id: rectangulo_blanco_3
                    Layout.fillWidth: true

                    sx: root.sx
                    sy: root.sy

                    // Layout.fillWidth: true
                    Layout.preferredWidth: 350*sx
                    Layout.preferredHeight: 350 * sy

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20 * sx

                        spacing: 20 * sy

                        Item {
                            Layout.fillHeight: true
                        }

                        BotonPrincipal {
                            id: botonComparacion

                            Layout.alignment: Qt.AlignHCenter

                            Layout.preferredWidth: 300*sx
                            Layout.preferredHeight: 60 * sy
                            
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
    }
    



    Rectangle{
        // width:1280
        height:50 * sy
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.left: parent.left
        color:"white"
        radius:7

        border.color: Style.Theme.borde_cuadro  
        
        


        
        
        Row {
            spacing: 10

            Rectangle {
                width: 150 * sx
                height: 50 * sy
                color: "blue"

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenter: parent.verticalCenter

                    // TODO Se necesita poner funcion para saber el numero de proyectos 
                    text: "Proyectos" 
                    color: Style.Theme.texto_primario
                    font.pixelSize: Math.min(parent.width, parent.height) * 0.30
                    font.bold: false
                }
            }

            BotonPrincipal {
                id: botonCargarDataSet
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 1 * sy

                Layout.preferredWidth: 100*sx
                Layout.preferredHeight: 60 * sy
                

                text: "Cargar Dataset"

                onClicked: {
                    stackView.push("LoadDataSetScreen.qml", {
                        "stackView": stackView
                    })
                }
               
            }
        }

        
        
    }
    // Rectangle {

    //     anchors.fill: parent
    //     color: "transparent"
    //     z:10


    //     VispyItem {

    //         id: matriz

    //         anchors.centerIn: parent

    //         width: 400
    //         height: 400
    //     }


    //     Button {

    //         text: "Mostrar matriz"

    //         anchors.bottom: parent.bottom


    //         onClicked: {

    //             matriz.setMatrix([
    //                 [0,1,0,1],
    //                 [1,1,0,0],
    //                 [0,0,1,1],
    //                 [1,0,1,0]
    //             ])
    //         }
    //     }
    // }

    

    

    
}
}

