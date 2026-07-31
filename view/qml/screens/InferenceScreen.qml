import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"
import QtQuick.Layouts

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
    
    BotonPrincipal{
        
                
                anchors.left: parent.left
                anchors.leftMargin: 10 * sx
                anchors.top: parent.top
                anchors.topMargin: 10 * sy
                width: 250 * sx
                height: 40 * sy
                text: " ↶ Volver al inicio"

                onClicked: {
                    stackView.pop()
                }
                
    }
    Rectangle{
        id:rec1
        property real size_width: 1600
        property real size_height:180
        width:size_width * sx
        height:size_height * sy
        color:"blue"
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: 20

        Column{
            anchors.centerIn: parent
            width: parent.size_width *sx
            spacing: 10

            RectanglePrincipal {
                sx: root.sx
                sy: root.sy
                width: (parent.width)
                height: (rec1.size_height/2) * sy
                anchors.margins: 5 * sx
            }

            RectanglePrincipal {
                sx: root.sx
                sy: root.sy
                width: (parent.width)
                height: (rec1.size_height/3) * sy
            }
        }
    }

    Rectangle{
        
        property real size_width: 280
        property real size_height:800
        width:size_width * sx
        height:size_height * sy
        // color: "transparent"
        color:"blue"          
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter   // opcional, si querés centrado vertical
        anchors.rightMargin: 40
        anchors.verticalCenterOffset: 45 * sy

        Column{
            anchors.centerIn: parent
            width: parent.size_width *sx
            spacing: 30

            RectanglePrincipal {    
                id: rectangulo_blanco_1
                width: parent.width 
                sx: root.sx
                sy: root.sy

                ColumnLayout{
                    // spacing: 30
                    // width: parent.width-30
                    // height:rectangulo_blanco_1.heigth
                    // anchors.margins: 15 * sx
                    // Layout.fillWidth: true
                    // Layout.fillHeight:true
                    anchors.fill: parent
                    anchors.margins: 15 * sx
                    spacing: 8 * sy
                    SliderColumn {
                        Layout.fillWidth: true


                        // width: parent.width 
                        // anchors.fill: parent
                        // anchors.margins: 30 * sx
                        sx: root.sx
                        sy: root.sy
                        text: "Temperatura"
                        from: 1
                        to: 3
                        stepSize: 0.01
                        value: 3
                        tipo_dato:"decimal"

                        onValueChanged: {
                            console.log("Nuevo valor:", value)
                        }
                    }

                    SliderColumn {
                    // anchors.fill: parent
                    // width: parent.width
                    // anchors.margins: 15 * sx
                    Layout.fillWidth: true

                    sx: root.sx
                    sy: root.sy
                    text: "Top-K"
                    from: 1
                    to: 5
                    stepSize: 0.1
                    value: 6
                    tipo_dato:"decimal"

                    onValueChanged: {
                        console.log("Nuevo valor:", value)
                    }
                }
                SliderColumn {
                    // anchors.fill: parent
                    // width: parent.width
                    // anchors.margins: 15 * sx
                    Layout.fillWidth: true


                    sx: root.sx
                    sy: root.sy
                    text: "Top-P"
                    from: 0
                    to: 1
                    stepSize: 0.01
                    value: 0.25
                    tipo_dato:"decimal"

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

            RectanglePrincipal{
                    id: rectangulo_blanco_3
                    width: parent.width 
                    // anchors.rightMargin: 400
                    sx: root.sx
                    sy: root.sy
                    // width: 300*sx
                    height: 100*sy
            }
        }
    }
}
        
    
