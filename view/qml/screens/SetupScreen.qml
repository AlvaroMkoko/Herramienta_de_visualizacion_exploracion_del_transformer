import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"
import QtQuick.Layouts
PagePrincipal {
    id:root

    property bool mostrarTarjeta: false

    // Preview en vivo (parámetros/memoria estimada) y errores de configuración
    property int parametrosTotales: 0
    property real memoriaEstimadaMb: 0
    property string mensajeError: ""

    // Hiperparámetros de ENTRENAMIENTO (no van a SetupController — se
    // guardan acá y se pasan a TrainingScreen cuando el modelo esté listo)
    property int epocas: 6
    property real tasaAprendizaje: 0.0003
    property int batchSize: 6

    Component.onCompleted: {
<<<<<<< HEAD
    console.log("mainViewModel =", mainViewModel)
}
=======
        mainViewModel.setupController.resumen_cambio.connect(function(resumen) {
            root.parametrosTotales = resumen.parametros_totales
            root.memoriaEstimadaMb = resumen.memoria_estimada_mb
        })
        mainViewModel.setupController.error_configuracion.connect(function(mensaje) {
            root.mensajeError = mensaje
        })
    }
>>>>>>> 35bc3c3434751fd3080d56fecb216464bb0c504b

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

    Rectangle{
        
        property real size_width: 300
        property real size_height:1000
        width:size_width * sx
        height:size_height * sy
        // color: "transparent"
        color:"blue"
        // clip: true          

        
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter   // opcional, si querés centrado vertical
        anchors.rightMargin: 30

        Column{
            anchors.centerIn: parent
            width: parent.size_width * sx

            spacing: 60 * sy


            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -50 * sy
            RectanglePrincipal {
                
                id: rectangulo_blanco_1
                width: parent.width
                height:500 * sy
                // anchors.verticalCenterOffset: -500 * sy

                sx: root.sx
                sy: root.sy

                ColumnLayout{
                    // spacing: 10
                    // width: parent.width-30
                    // anchors.margins: 15 * sx
                    anchors.fill: parent
                    anchors.margins: 10 * sx

                    spacing: 1 * sy 

                     SliderColumn {
                        // width: parent.width 
                        // // anchors.fill: parent
                        // anchors.margins: 30 * sx
                        Layout.fillWidth:true
                        Layout.fillHeight:true


                        sx: root.sx
                        sy: root.sy

                        text: "Capas Encoder (Nx)"

                        from: 1
                        to: 12

                        stepSize: 1
                        value: 6

                        onValueChanged: {
<<<<<<< HEAD
                            // console.log("Nuevo valor:", value)
                            mainViewModel.setupController.establecer_num_capas(value)
                        

=======
                            mainViewModel.setupController.establecer_num_capas(value)
>>>>>>> 35bc3c3434751fd3080d56fecb216464bb0c504b
                        }
                    }
                     SliderColumn {
                        // width: parent.width 
                        // // anchors.fill: parent
                        // anchors.margins: 30 * sx
                        Layout.fillWidth:true
                        Layout.fillHeight:true



                        sx: root.sx
                        sy: root.sy

                        text: "Dimension del Modelo"

                        from: 32
                        to: 512

                        stepSize: 32
                        value: 64

                        onValueChanged: {
<<<<<<< HEAD
                            // console.log("Nuevo valor:", value)
                            mainViewModel.setupController.establecer_num_capas(value)
                        

=======
                            mainViewModel.setupController.establecer_dimension_modelo(value)
>>>>>>> 35bc3c3434751fd3080d56fecb216464bb0c504b
                        }
                    }
                     SliderColumn {
                        // width: parent.width 
                        // // anchors.fill: parent
                        // anchors.margins: 30 * sx
                        Layout.fillWidth:true
                        Layout.fillHeight:true


                        sx: root.sx
                        sy: root.sy

                        text: "Dimension-Feed Forward"

                        from: 128
                        to: 2048

                        stepSize: 128
                        value: 256

                        onValueChanged: {
<<<<<<< HEAD
                            // console.log("Nuevo valor:", value)
                            mainViewModel.setupController.establecer_num_capas(value)
                        

=======
                            mainViewModel.setupController.establecer_dimension_ff(value)
>>>>>>> 35bc3c3434751fd3080d56fecb216464bb0c504b
                        }
                    }
                     SliderColumn {
                        // width: parent.width 
                        // // anchors.fill: parent
                        // anchors.margins: 30 * sx
                        Layout.fillWidth:true
                        Layout.fillHeight:true


                        sx: root.sx
                        sy: root.sy

                        text: "Longitud Maxima de Secuencia"

                        from: 16
                        to: 512

                        stepSize: 16
                        value: 64

                        onValueChanged: {
<<<<<<< HEAD
                            // console.log("Nuevo valor:", value)
                            mainViewModel.setupController.establecer_num_capas(value)
                        

=======
                            mainViewModel.setupController.establecer_longitud_maxima_secuencia(value)
>>>>>>> 35bc3c3434751fd3080d56fecb216464bb0c504b
                        }
                    }
                    
                    

                    SliderColumn {
                    // // anchors.fill: parent
                    // width: parent.width
                    // anchors.margins: 15 * sx
                    Layout.fillWidth:true
                    Layout.fillHeight:true

                    sx: root.sx
                    sy: root.sy

                    text: "Épocas"

                    from: 1
                    to: 24

                    stepSize: 1
                    value: 6

                    onValueChanged: {
                        root.epocas = value
                    }
                }
                 SliderColumn {
                    // // anchors.fill: parent
                    // width: parent.width
                    // anchors.margins: 15 * sx
                    Layout.fillWidth:true
                    Layout.fillHeight:true

                    sx: root.sx
                    sy: root.sy

                    text: "Learning Rate"
                    from: 0
                    to: 0.01
                    stepSize: 0.0001
                    value: 0.0003

                    tipo_dato:"decimal"

                    onValueChanged: {
                        root.tasaAprendizaje = value
                    }
                }

                 SliderColumn {
                    // width: parent.width
                    // anchors.margins: 15 * sx
                    Layout.fillWidth:true
                    sx: root.sx
                    sy: root.sy

                    text: "Batch Size"

                    from: 1
                    to: 24

                    stepSize: 1
                    value: 6

                    onValueChanged: {
                        root.batchSize = value
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

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15 * sx
                    spacing: 6 * sy

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Parámetros: " + root.parametrosTotales.toLocaleString()
                            + "  (~" + root.memoriaEstimadaMb + " MB)"
                        color: Style.Theme.texto_primario
                        font.pixelSize: 14 * root.sx
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: root.mensajeError !== ""
                        text: root.mensajeError
                        color: "red"
                        wrapMode: Text.WordWrap
                        Layout.preferredWidth: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 12 * root.sx
                    }
                }

            }

            BotonPrincipal {
                        id: botonIniciarEntrenamiento
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 200 * root.sx
                        height: 50 * root.sy
                        anchors.margins: 20

                        text: "Iniciar Entrenamiento"

                        onClicked: {
                            root.mensajeError = ""
                            mainViewModel.setupController.crear_modelo()

                            // Solo navega si crear_modelo() NO disparo error_configuracion
                            // (la conexion de Component.onCompleted ya actualizo
                            // root.mensajeError de forma sincronica antes de esta linea)
                            if (root.mensajeError === "") {
                                stackView.push("TrainingScreen.qml", {
                                    "stackView": stackView,
                                    "epocasIniciales": root.epocas,
                                    "tasaAprendizajeInicial": root.tasaAprendizaje,
                                    "batchSizeInicial": root.batchSize
                                })
                            }
                        }
                    
            }
        }
    }


Rectangle {
    id: rec_left

    width: 250 * sx
    height: 700 * sy
    color: "blue"

    anchors.left: parent.left
    anchors.leftMargin: 20 * sx
    anchors.verticalCenter: parent.verticalCenter

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6 * sx

        spacing: 30 * sy

        RectanglePrincipal {
            id: rectangulo_blanco_3

            Layout.fillWidth: true
            Layout.preferredHeight: 400 * sy

            sx: root.sx
            sy: root.sy

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15 * sx

                Item {
                    Layout.fillHeight: true
                }

                BotonPrincipal {
                    id: botonModelo

                    Layout.alignment: Qt.AlignHCenter

                    Layout.preferredWidth: 160 * sx
                    Layout.preferredHeight: 50 * sy

                    text: "Gestionar DataSet"

                    onClicked: {
                        // root.mostrarTarjeta = !root.mostrarTarjeta
                        stackView.push("DataSetScreen.qml", {
                                "stackView": stackView
                            })
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}

    Rectangle{
        property real size_width: 250
        width:size_width * sx
        height:700 * sy
        color:"transparent"

        anchors.verticalCenter: parent.verticalCenter
        anchors.centerIn: parent

        // NOTA: antes esta tarjeta estaba condicionada a
        // "root.mostrarTarjeta", pero nada en el archivo lo ponia en
        // true — "Numero de Cabezas" y "Drop-out" quedaban invisibles
        // sin ninguna forma de mostrarlos. Se deja siempre visible; si
        // la idea era un toggle, hace falta un boton que cambie
        // root.mostrarTarjeta explicitamente.

        RectanglePrincipal{
            id: rectangulo_blanco_4
            anchors.left: parent.left
            // anchors.rightMargin: 400
            sx: root.sx
            sy: root.sy

            width: parent.size_width * sx
            // width: 300 * sx
            ColumnLayout{
                    // width: parent.width-30
                    anchors.fill: parent 
                    anchors.margins: 10 * sx

                    spacing: 10 * sx
                    
                     SliderColumn {
                            Layout.fillWidth:true
                            
                            // width: parent.width 
                            // anchors.fill: parent

                            sx: root.sx
                            sy: root.sy

                            text: "Numero de Cabezas (Heads)"

                            from: 1
                            to: 12

                            stepSize: 1
                            value: 6

                            onValueChanged: {
<<<<<<< HEAD
                                // console.log("Nuevo valor:", value)
=======
>>>>>>> 35bc3c3434751fd3080d56fecb216464bb0c504b
                                mainViewModel.setupController.establecer_num_cabezas(value)
                            }
                        }

                    SliderColumn {
                    // anchors.fill: parent
                        // width: parent.width
                        // anchors.margins: 15 * sx
                        Layout.fillWidth:true

                        sx: root.sx
                        sy: root.sy

                        text: "Drop-out"

                        from: 0
                        to: 0.5

                        stepSize: 0.05
                        value: 0.1
                        tipo_dato:"decimal"
                        onValueChanged: {
<<<<<<< HEAD
                            console.log("Nuevo valor:", value)
=======
>>>>>>> 35bc3c3434751fd3080d56fecb216464bb0c504b
                            mainViewModel.setupController.establecer_dropout(value)
                        }
                    }
                 
                }

                }


        }

    }