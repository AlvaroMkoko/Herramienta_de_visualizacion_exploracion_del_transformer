// import QtQuick
// import QtQuick.Controls
// import "../styles" as Style
// import "../components"

// PagePrincipal {
//     id:root

//     property bool mostrarTarjeta: false


//     // background: Rectangle {
//     //     gradient: Gradient {
//     //         GradientStop {
//     //             position: 0
//     //             color: Style.Theme.fondo
//     //         }

//     //         GradientStop {
//     //             position: 1
//     //             color: Style.Theme.fondo_gradiente
//     //         }
//     //     }
//     // }
    

//     BotonPrincipal {
                
//                 anchors.left: parent.left
//                 anchors.leftMargin: 10 * sx
//                 anchors.top: parent.top
//                 anchors.topMargin: 10 * sy
//                 width: 250 * sx
//                 height: 40 * sy

//                 text: " ↶ Volver al inicio"

//                 onClicked: {
//                     stackView.pop()
//                 }
                
//     }


    


//     Column {
//         anchors.left: parent.left
//         anchors.top: parent.top
//         anchors.leftMargin: 30 * sx
//         anchors.topMargin: 80 * sy

//         spacing: 10 * sy

//         Rectangle {
//             id: rectop

//             property real size_width: 1800
//             property real size_height: 200

//             width: size_width * sx
//             height: size_height * sy

//             color: "blue"

//             Column{

//                 anchors.fill: parent
//                 anchors.margins: 10 * sx
//                 spacing: 10
//                 Row{
//                     width: parent.width
//                     spacing: 10 * sx

//                     RectanglePrincipal {
//                         sx: root.sx
//                         sy: root.sy

//                         width: (parent.width - parent.spacing) / 2
//                         height: (rectop.size_height/2) * sy
//                     }


//                     RectanglePrincipal {
//                         sx: root.sx
//                         sy: root.sy

//                         width: (parent.width - parent.spacing) / 2
//                         height: (rectop.size_height/2.4) * sy
//                     }

//                 }

//                 RectanglePrincipal {
//                         sx: root.sx
//                         sy: root.sy

//                         width: (parent.width - parent.spacing)
//                         height: (rectop.size_height/3) * sy
//                     }



//             }


            
//         }

//         Rectangle {
//             id: rec1

//             property real size_width: 1740
//             property real size_height: 740

//             property real size_rec1: 140
//             property real size_rec2: 370
//             property real size_rec3: 200

//             width: size_width * sx
//             height: size_height * sy

//             color: "blue"

//             Column {
//                 anchors.fill: parent
//                 anchors.margins: 10 * sx

//                 spacing: 10 * sy

//                 Row {
//                     width: parent.width
//                     spacing: 10 * sx

//                     RectanglePrincipal {
//                         sx: root.sx
//                         sy: root.sy

//                         width: (parent.width - parent.spacing) / 2
//                         height: rec1.size_rec1 * sy
//                     }

//                     RectanglePrincipal {
//                         sx: root.sx
//                         sy: root.sy

//                         width: (parent.width - parent.spacing) / 2
//                         height: rec1.size_rec1 * sy
//                     }
//                 }

//                 Row {
//                     width: parent.width
//                     spacing: 10 * sx

//                     RectanglePrincipal {
//                         sx: root.sx
//                         sy: root.sy

//                         width: (parent.width - parent.spacing) / 2
//                         height: rec1.size_rec2 * sy
//                     }

//                     RectanglePrincipal {
//                         sx: root.sx
//                         sy: root.sy

//                         width: (parent.width - parent.spacing) / 2
//                         height: rec1.size_rec2 * sy
//                     }
//                 }

//                 Row {
//                     width: parent.width
//                     spacing: 10 * sx

//                     RectanglePrincipal {
//                         sx: root.sx
//                         sy: root.sy

//                         width: (parent.width - parent.spacing) / 2
//                         height: rec1.size_rec3 * sy
//                     }

//                     RectanglePrincipal {
//                         sx: root.sx
//                         sy: root.sy

//                         width: (parent.width - parent.spacing) / 2
//                         height: rec1.size_rec3 * sy
//                     }
//                 }
//             }
//         }
//     }
    
    

//     }
        
    
import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"
import QtQuick.Layouts

PagePrincipal {
    id:root

    property bool mostrarTarjeta: false


    // background: Rectangle {
    //     gradient: Gradient {
    //         GradientStop {
    //             position: 0
    //             color: Style.Theme.fondo
    //         }

    //         GradientStop {
    //             position: 1
    //             color: Style.Theme.fondo_gradiente
    //         }
    //     }
    // }
    

    BotonPrincipal {
                
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


    


    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 30 * sx
        anchors.topMargin: 80 * sy

        spacing: 10 * sy

        Rectangle {
            id: rectop

            property real size_width: 1880
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

                    // ---- PROMPT COMPARTIDO ----
                    RectanglePrincipal {
                        sx: root.sx
                        sy: root.sy

                        width: (parent.width - parent.spacing) / 2
                        height: (rectop.size_height/2) * sy

                        
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

                                onClicked: {
                                    stackView.push("SetupScreen.qml", {
                                        "stackView": stackView
                                    })
                                }
                            }
                        }
                    }


                    // ---- PARAMS COMPARTIDOS ----
                    RectanglePrincipal {
                        id: rectanguloParams
                        sx: root.sx
                        sy: root.sy

                        width: (parent.width - parent.spacing) / 2
                        height: (rectop.size_height/2) * sy

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10 * sx
                            spacing: 10 * sy

                            Text {
                                text: "Params compartidos"
                                font.pixelSize: 14 * sx
                                font.bold: true
                                color: "#b5891f"
                            }


                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 5 * sx

                                SliderColumn {
                                    Layout.fillWidth: true
                                    // Layout.alignment: Qt.AlignVCenter

                                    sx: root.sx
                                    sy: root.sy
                                    text: "Temperatura"
                                    from: 1
                                    to: 3
                                    stepSize: 0.01
                                    value: 3
                                    tipo_dato: "decimal"
                                }

                                SliderColumn {
                                    Layout.fillWidth: true
                                    // Layout.alignment: Qt.AlignVCenter

                                    sx: root.sx
                                    sy: root.sy
                                    text: "Top-K"
                                    from: 1
                                    to: 5
                                    stepSize: 0.1
                                    value: 5
                                    tipo_dato: "decimal"
                                }

                                SliderColumn {
                                    Layout.fillWidth: true
                                    // Layout.alignment: Qt.AlignVCenter

                                    sx: root.sx
                                    sy: root.sy
                                    text: "Top-P"
                                    from: 0
                                    to: 1
                                    stepSize: 0.01
                                    value: 0.25
                                    tipo_dato: "decimal"
                                }

                            }
                        }
                    }

                }

                // ---- PIPELINE: Tokens - Embeds - Atención - FFN - Norm - Softmax ----
                RectanglePrincipal {
                    sx: root.sx
                    sy: root.sy

                    width: (parent.width - parent.spacing)
                    height: (rectop.size_height/2.5) * sy

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10 * sx
                        spacing: 0

                        // ---- Paso 1: Tokens (completado) ----
                        Column {
                            spacing: 6 * sy
                            Layout.alignment: Qt.AlignHCenter

                            Rectangle {
                                width: 34 * sx
                                height: 34 * sx
                                radius: width / 2
                                color: "#6c4cf5"
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "white"
                                    font.pixelSize: 14 * sx
                                    font.bold: true
                                }
                            }

                            Text {
                                text: "Tokens"
                                font.pixelSize: 12 * sx
                                color: "#555555"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        // ---- conector (se estira) ----
                        Item {
                            Layout.fillWidth: true
                            height: 2
                            Rectangle {
                                anchors.fill: parent
                                color: "#6c4cf5"
                            }
                        }

                        // ---- Paso 2: Embeds (completado) ----
                        Column {
                            spacing: 6 * sy
                            Layout.alignment: Qt.AlignHCenter

                            Rectangle {
                                width: 34 * sx
                                height: 34 * sx
                                radius: width / 2
                                color: "#6c4cf5"
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "white"
                                    font.pixelSize: 14 * sx
                                    font.bold: true
                                }
                            }

                            Text {
                                text: "Embeds"
                                font.pixelSize: 12 * sx
                                color: "#555555"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            height: 2
                            Rectangle {
                                anchors.fill: parent
                                color: "#6c4cf5"
                            }
                        }

                        // ---- Paso 3: Atención (activo) ----
                        Column {
                            spacing: 6 * sy
                            Layout.alignment: Qt.AlignHCenter

                            Rectangle {
                                width: 40 * sx
                                height: 40 * sx
                                radius: width / 2
                                color: "#4b2fc9"
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "white"
                                    font.pixelSize: 16 * sx
                                    font.bold: true
                                }
                            }

                            Text {
                                text: "Atención"
                                font.pixelSize: 13 * sx
                                font.bold: true
                                color: "#4b2fc9"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            height: 2
                            Rectangle {
                                anchors.fill: parent
                                color: "#d8d3f5"
                            }
                        }

                        // ---- Paso 4: FFN (pendiente) ----
                        Column {
                            spacing: 6 * sy
                            Layout.alignment: Qt.AlignHCenter

                            Rectangle {
                                width: 34 * sx
                                height: 34 * sx
                                radius: width / 2
                                color: "#e6e1fb"
                                border.color: "#c3b9f7"
                                border.width: 1
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "#b6a8ef"
                                    font.pixelSize: 14 * sx
                                }
                            }

                            Text {
                                text: "FFN"
                                font.pixelSize: 12 * sx
                                color: "#999999"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            height: 2
                            Rectangle {
                                anchors.fill: parent
                                color: "#d8d3f5"
                            }
                        }

                        // ---- Paso 5: Norm (pendiente) ----
                        Column {
                            spacing: 6 * sy
                            Layout.alignment: Qt.AlignHCenter

                            Rectangle {
                                width: 34 * sx
                                height: 34 * sx
                                radius: width / 2
                                color: "#e6e1fb"
                                border.color: "#c3b9f7"
                                border.width: 1
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "#b6a8ef"
                                    font.pixelSize: 14 * sx
                                }
                            }

                            Text {
                                text: "Norm"
                                font.pixelSize: 12 * sx
                                color: "#999999"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            height: 2
                            Rectangle {
                                anchors.fill: parent
                                color: "#d8d3f5"
                            }
                        }

                        // ---- Paso 6: Softmax (siguiente) ----
                        Column {
                            spacing: 6 * sy
                            Layout.alignment: Qt.AlignHCenter

                            Rectangle {
                                width: 34 * sx
                                height: 34 * sx
                                radius: width / 2
                                color: "#e6e1fb"
                                border.color: "#c3b9f7"
                                border.width: 1
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "▷"
                                    color: "#8a76e8"
                                    font.pixelSize: 14 * sx
                                }
                            }

                            Text {
                                text: "Softmax"
                                font.pixelSize: 12 * sx
                                color: "#999999"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
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

                // ---- FILA 1: Encabezados Modelo A / Modelo B ----
                Row {
                    width: parent.width
                    spacing: 10 * sx

                    RectanglePrincipal {
                        sx: root.sx
                        sy: root.sy

                        width: (parent.width - parent.spacing) / 2
                        height: rec1.size_rec1 * sy

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10 * sx
                            spacing: 4 * sy

                            Text {
                                text: "Modelo A"
                                font.pixelSize: 18 * sx
                                font.bold: true
                            }
                            Text {
                                text: "L4 · H8 · d=512 · FFN=2048"
                                font.pixelSize: 13 * sx
                                color: "#555555"
                            }
                            Row {
                                spacing: 20 * sx
                                Text { text: "Latencia 12ms";   font.pixelSize: 13 * sx }
                                Text { text: "Precisión 98.4%"; font.pixelSize: 13 * sx }
                            }
                        }
                    }

                    RectanglePrincipal {
                        sx: root.sx
                        sy: root.sy

                        width: (parent.width - parent.spacing) / 2
                        height: rec1.size_rec1 * sy

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10 * sx
                            spacing: 4 * sy

                            Text {
                                text: "Modelo B"
                                font.pixelSize: 18 * sx
                                font.bold: true
                            }
                            Text {
                                text: "L6 · H12 · d=768 · FFN=3072"
                                font.pixelSize: 13 * sx
                                color: "#555555"
                            }
                            Row {
                                spacing: 20 * sx
                                Text { text: "Latencia 24ms";   font.pixelSize: 13 * sx }
                                Text { text: "Precisión 99.1%"; font.pixelSize: 13 * sx }
                            }
                        }

                        

                    }
                }

                // ---- FILA 2: Visualización de Atención ----
                Row {
                    width: parent.width
                    spacing: 10 * sx

                    RectanglePrincipal {
                        sx: root.sx
                        sy: root.sy

                        width: (parent.width - parent.spacing) / 2
                        height: rec1.size_rec2 * sy

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10 * sx
                            spacing: 8 * sy

                            Text {
                                text: "Multi-Head Attention (H8)"
                                font.pixelSize: 16 * sx
                                font.bold: true
                            }
                            Text {
                                text: "8 cabezas · head_dim=64 · d=512 · clic →"
                                font.pixelSize: 12 * sx
                                color: "#555555"
                            }

                            Row {
                                spacing: 20 * sx
                                anchors.horizontalCenter: parent.horizontalCenter
                                Text { text: "The" }
                                Text { text: "cat" }
                                Text { text: "sat"; font.bold: true }
                                Text { text: "on" }
                            }

                            Text {
                                text: "0.55 · cat 0.25 · on 0.10 · The 0.10"
                                font.pixelSize: 12 * sx
                            }

                            Text {
                                text: "Menos focalizado que Modelo B (8 vs 12 cabezas)"
                                font.pixelSize: 11 * sx
                                color: "#777777"
                            }
                        }
                    }

                    RectanglePrincipal {
                        sx: root.sx
                        sy: root.sy

                        width: (parent.width - parent.spacing) / 2
                        height: rec1.size_rec2 * sy

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10 * sx
                            spacing: 8 * sy

                            Text {
                                text: "Multi-Head Attention (H12)"
                                font.pixelSize: 16 * sx
                                font.bold: true
                            }
                            Text {
                                text: "12 cabezas · head_dim=64 · d=768 · clic →"
                                font.pixelSize: 12 * sx
                                color: "#555555"
                            }

                            Row {
                                spacing: 20 * sx
                                anchors.horizontalCenter: parent.horizontalCenter
                                Text { text: "The" }
                                Text { text: "cat" }
                                Text { text: "sat"; font.bold: true }
                                Text { text: "on" }
                            }

                            Text {
                                text: "0.61 · cat 0.27 · on 0.07 · The 0.05"
                                font.pixelSize: 12 * sx
                            }

                            Text {
                                text: "Más focalizado: 12 cabezas vs 8 del Modelo A"
                                font.pixelSize: 11 * sx
                                color: "#777777"
                            }
                        }
                    }
                }

                // ---- FILA 3: Predicción (placeholder para gráfica) ----
                Row {
                    width: parent.width
                    spacing: 10 * sx

                    RectanglePrincipal {
                        sx: root.sx
                        sy: root.sy

                        width: (parent.width - parent.spacing) / 2
                        height: rec1.size_rec3 * sy

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10 * sx
                            spacing: 6 * sy

                            Text {
                                text: "Predicción Modelo A"
                                font.pixelSize: 15 * sx
                                font.bold: true
                            }

                            // Aquí va la gráfica de barras (se hace aparte)
                            Item {
                                id: graficaA
                                width: parent.width
                                height: parent.height - 60 * sy
                            }

                            Text {
                                text: "Siguiente: \"the\"   12ms"
                                font.pixelSize: 13 * sx
                            }
                        }
                    }

                    RectanglePrincipal {
                        sx: root.sx
                        sy: root.sy

                        width: (parent.width - parent.spacing) / 2
                        height: rec1.size_rec3 * sy

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10 * sx
                            spacing: 6 * sy

                            Text {
                                text: "Predicción Modelo B"
                                font.pixelSize: 15 * sx
                                font.bold: true
                            }

                            // Aquí va la gráfica de barras (se hace aparte)
                            Item {
                                id: graficaB
                                width: parent.width
                                height: parent.height - 60 * sy
                            }

                            Text {
                                text: "Siguiente: \"the\"   24ms"
                                font.pixelSize: 13 * sx
                            }
                        }
                    }
                }
            }
        }
    }
    
    

    }