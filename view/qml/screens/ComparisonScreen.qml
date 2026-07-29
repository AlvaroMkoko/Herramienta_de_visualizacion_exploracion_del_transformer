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


    


    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 30 * sx
        anchors.topMargin: 80 * sy

        spacing: 10 * sy

        Rectangle {
            id: rectop

            property real size_width: 1800
            property real size_height: 200

            width: size_width * sx
            height: size_height * sy

            color: "blue"

            Column{

                anchors.fill: parent
                anchors.margins: 10 * sx
                spacing: 10
                Row{
                    width: parent.width
                    spacing: 10 * sx

                    RectanglePrincipal {
                        sx: root.sx
                        sy: root.sy

                        width: (parent.width - parent.spacing) / 2
                        height: (rectop.size_height/2) * sy
                    }


                    RectanglePrincipal {
                        sx: root.sx
                        sy: root.sy

                        width: (parent.width - parent.spacing) / 2
                        height: (rectop.size_height/2.4) * sy
                    }

                }

                RectanglePrincipal {
                        sx: root.sx
                        sy: root.sy

                        width: (parent.width - parent.spacing)
                        height: (rectop.size_height/3) * sy
                    }



            }


            
        }

        Rectangle {
            id: rec1

            property real size_width: 1740
            property real size_height: 740

            property real size_rec1: 140
            property real size_rec2: 370
            property real size_rec3: 200

            width: size_width * sx
            height: size_height * sy

            color: "blue"

            Column {
                anchors.fill: parent
                anchors.margins: 10 * sx

                spacing: 10 * sy

                Row {
                    width: parent.width
                    spacing: 10 * sx

                    RectanglePrincipal {
                        sx: root.sx
                        sy: root.sy

                        width: (parent.width - parent.spacing) / 2
                        height: rec1.size_rec1 * sy
                    }

                    RectanglePrincipal {
                        sx: root.sx
                        sy: root.sy

                        width: (parent.width - parent.spacing) / 2
                        height: rec1.size_rec1 * sy
                    }
                }

                Row {
                    width: parent.width
                    spacing: 10 * sx

                    RectanglePrincipal {
                        sx: root.sx
                        sy: root.sy

                        width: (parent.width - parent.spacing) / 2
                        height: rec1.size_rec2 * sy
                    }

                    RectanglePrincipal {
                        sx: root.sx
                        sy: root.sy

                        width: (parent.width - parent.spacing) / 2
                        height: rec1.size_rec2 * sy
                    }
                }

                Row {
                    width: parent.width
                    spacing: 10 * sx

                    RectanglePrincipal {
                        sx: root.sx
                        sy: root.sy

                        width: (parent.width - parent.spacing) / 2
                        height: rec1.size_rec3 * sy
                    }

                    RectanglePrincipal {
                        sx: root.sx
                        sy: root.sy

                        width: (parent.width - parent.spacing) / 2
                        height: rec1.size_rec3 * sy
                    }
                }
            }
        }
    }
    
    

    }
        
    
