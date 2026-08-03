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

                RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10 * sx
                            spacing: 12 * sx

                            Text {
                                text: "PROMPT COMPARTIDO"
                                font.pixelSize: 14 * sx
                                font.bold: true
                                color: "#7a5cff"

                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: implicitWidth   // ancho fijo, no crece
                            }

                            Text {
                                id: textoPrompt
                                //TODO: Este es el texto que estara generando el Modelo Transformer
                                text: "The cat sat ..."
                                font.pixelSize: 16 * sx
                                color: "black"

                                Layout.fillWidth: true                 // este absorbe todo el espacio sobrante
                                Layout.alignment: Qt.AlignVCenter
                                elide: Text.ElideRight                  // por si el texto es muy largo
                            }

                            BotonPrincipal {
                                id: botonGenerar
                                width: 120 * root.sx
                                height: 60 * root.sy

                                text: "▶ Generar ambos"
                                size_text: 0.20

                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: width             // ancho fijo, no crece
                                Layout.preferredHeight: height

                                // onClicked: {
                                //     stackView.push("SetupScreen.qml", {
                                //         "stackView": stackView
                                //     })
                                // }
                            }
                        }
            }

            RectanglePrincipal {
                id:rec_timeline
                sx: root.sx
                sy: root.sy
                width: (parent.width)
                height: (rec1.size_height/2.5) * sy
                TimeLine {
                    id: timeline
                    anchors.fill: parent
                    sx: root.sx
                    sy: root.sy

                    model: [
                        { title: "Tokens",   state: "done" },
                        { title: "Embeds",   state: "done" },
                        { title: "Atención", state: "running" },
                        { title: "FFN",      state: "pending" },
                        { title: "Norm+Res", state: "pending" },
                        { title: "Softmax",  state: "pending" }
                    ]
                }
                
        
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
        
    
