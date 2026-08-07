import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"
import QtQuick.Layouts

PagePrincipal {
    id:root

    //--- TODO PENDIENTE LA TARJETA SE MUESTRA CUANDO HACES "CLICK" EN EL ELEMENTO SELECCIONADO -----
    property bool mostrarTarjeta: false

    // Hiperparámetros recibidos desde SetupScreen.qml al navegar acá
    property int epocasIniciales: 10
    property real tasaAprendizajeInicial: 0.0003
    property int batchSizeInicial: 16

    // Estado de progreso, alimentado por las señales de trainingController
    property int epocaActual: 0
    property int pasoGlobalActual: 0
    property real perdidaActual: 0
    property string mensajeError: ""
    property string mensajeCheckpoint: ""

    // Un snapshot solo es consistente cuando no hay un optimizer.step() en
    // curso. El controlador también lo valida, pero reflejarlo aquí evita que
    // el usuario inicie un guardado que necesariamente será rechazado.
    readonly property bool guardadoDisponible: {
        var tc = mainViewModel.trainingController
        return tc !== null && tc !== undefined
                && (!tc.estaEntrenando || tc.estaPausado)
                && (tc.guardando === undefined || !tc.guardando)
    }

    function guardarModeloPortable(nombre) {
        var tc = mainViewModel.trainingController
        if (typeof tc.guardarModeloPortableConNombre === "function") {
            tc.guardarModeloPortableConNombre(nombre)
        } else {
            // Compatibilidad temporal con controladores anteriores.
            tc.guardarCheckpointConNombre(nombre)
        }
    }

    function guardarCheckpointReanudable(nombre) {
        var tc = mainViewModel.trainingController
        if (typeof tc.guardarCheckpointReanudableConNombre === "function") {
            tc.guardarCheckpointReanudableConNombre(nombre)
        } else {
            // Un controlador antiguo solo puede conservar pesos y metadatos.
            tc.guardarCheckpointConNombre(nombre)
        }
    }

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

    Component.onCompleted: {
        mainViewModel.trainingController.paso_entrenamiento.connect(function(paso) {
            root.epocaActual = paso.epoca
            root.pasoGlobalActual = paso.paso_global
            root.perdidaActual = paso.perdida
        })
        mainViewModel.trainingController.entrenamiento_completo.connect(function(resultado) {
            console.log("Entrenamiento completo. Perdida final:", resultado.perdida_final)
        })
        mainViewModel.trainingController.entrenamiento_cancelado.connect(function(resultado) {
            console.log("Entrenamiento detenido por el usuario.")
        })
        mainViewModel.trainingController.error.connect(function(mensaje) {
            root.mensajeError = mensaje
        })
        mainViewModel.trainingController.checkpoint_guardado.connect(function(ruta) {
            root.mensajeCheckpoint = "Guardado: " + ruta
            root.mensajeError = ""
        })
    }

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
        property real size_height:900
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

            spacing: 30 * sy



            RectanglePrincipal {
                id: rectangulo_blanco_1

                sx: root.sx
                sy: root.sy

                width: parent.width
                height: 500 * sy

                // Escala respecto al tamaño original (350x400)
                property real scale: Math.min(width / 350, height / 500)
                property var flowModel: [
                    { title: "Input Emb + PE", state: "done" },
                    { title: "Encoder L1-3", state: "done" },
                    { title: "Multi-Head Attention", state: "running" },
                    { title: "Encoder L4-6", state: "pending" },
                    { title: "Decoder + Salida", state: "pending" },
                    { title: "Loss", state: "pending" }
                ]

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20 * rectangulo_blanco_1.scale

                    spacing: 18 * rectangulo_blanco_1.scale

                    Text {
                        Layout.fillWidth: true

                        text: "Flujo de datos"

                        horizontalAlignment: Text.AlignHCenter

                        color: "#4B4B8F"

                        font.bold: true
                        font.pixelSize: 22 * rectangulo_blanco_1.scale
                    }

                    

                // Repeater {

                //     model: rectangulo_blanco_1.flowModel

                //     delegate: FlujoPaso {
                //         width: parent.width

                //         scale: rectangulo_blanco_1.scale

                //         title: modelData.title

                //         state: modelData.state
                //     }
                // }
                    FlujoPaso {
                        width: parent.width
                        sx: root.sx
                        sy: root.sy
                        model: [
                            { title: "Tokens",   state: "done" },
                            { title: "Embeds",   state: "done" },
                            { title: "Atención", state: "running" },
                            { title: "FFN",      state: "pending" },
                            { title: "Norm",     state: "pending" },
                            { title: "Softmax",  state: "pending" }
                        ]
                    }

                    // Item {
                    //     Layout.fillHeight: true
                    // }

                    RowLayout {

                        Layout.fillWidth: true

                        spacing: 10 * rectangulo_blanco_1.scale

                        BotonPrincipal {

                            Layout.fillWidth: true
                            Layout.preferredHeight: 45 * rectangulo_blanco_1.scale

                            text: "⏮ Detener"
                            enabled: mainViewModel.trainingController.estaEntrenando

                            onClicked: {
                                mainViewModel.trainingController.detener()
                            }
                        }

                        BotonPrincipal {

                            Layout.fillWidth: true
                            Layout.preferredHeight: 45 * rectangulo_blanco_1.scale

                            text: !mainViewModel.trainingController.estaEntrenando
                                    ? "▶ Iniciar"
                                    : (mainViewModel.trainingController.estaPausado ? "▶ Reanudar" : "⏸ Pausar")

                            onClicked: {
                                var tc = mainViewModel.trainingController
                                if (!tc.estaEntrenando) {
                                    root.mensajeError = ""
                                    tc.iniciar_entrenamiento_ui(
                                        root.epocasIniciales,
                                        root.tasaAprendizajeInicial,
                                        root.batchSizeInicial
                                    )
                                    // mainViewModel.trainingController.iniciar_entrenamiento_ui(root.epocasIniciales, root.tasaAprendizajeInicial,  root.batchSizeInicial)
                                } else if (tc.estaPausado) {
                                    tc.reanudar()
                                } else {
                                    tc.pausar()
                                }
                            }
                        }

                        BotonPrincipal {

                            Layout.fillWidth: true
                            Layout.preferredHeight: 45 * rectangulo_blanco_1.scale

                            text: "⏭"
                            // TODO: sin mapeo claro todavia (no existe un
                            // concepto de "avanzar manualmente" en el bucle
                            // de entrenamiento actual). Deshabilitado por
                            // ahora para no prometer algo que no hace nada.
                            enabled: false
                            opacity: 0.4

                            onClicked: {}
                        }
                    }
                }
            }




            // RectanglePrincipal{

            //     id: rectangulo_blanco_2
            //     width: parent.width 
            //     // anchors.rightMargin: 400
            //     sx: root.sx
            //     sy: root.sy
            //     // width: 300*sx
            //     height: 200*sy

            //     ColumnLayout {
            //         anchors.fill: parent
            //         anchors.margins: 15 * sx
            //         spacing: 3 * sy

            //         Text {
            //             Layout.alignment: Qt.AlignHCenter
            //             text: "Época " + root.epocaActual + " · Paso " + root.pasoGlobalActual
            //             color: Style.Theme.texto_primario
            //             font.pixelSize: 14 * root.sx
            //         }
            //         Text {
            //             Layout.alignment: Qt.AlignHCenter
            //             text: "Pérdida: " + root.perdidaActual.toFixed(4)
            //             color: Style.Theme.texto_primario
            //             font.pixelSize: 14 * root.sx
            //         }
            //         Text {
            //             Layout.alignment: Qt.AlignHCenter
            //             visible: root.mensajeError !== ""
            //             text: root.mensajeError
            //             color: "red"
            //             wrapMode: Text.WordWrap
            //             Layout.preferredWidth: parent.width
            //             horizontalAlignment: Text.AlignHCenter
            //         }
            //         Text {
            //             Layout.alignment: Qt.AlignHCenter
            //             visible: root.mensajeCheckpoint !== ""
            //             text: root.mensajeCheckpoint
            //             color: "green"
            //         }
            //     }

            // }

            RectanglePrincipal {
                id: rectangulo_blanco_2

                width: parent.width
                height: 200 * sy

                sx: root.sx
                sy: root.sy

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18 * sx
                    spacing: 12 * sy

                    Text {
                        Layout.fillWidth: true

                        text: "Estado del entrenamiento"
                        horizontalAlignment: Text.AlignHCenter

                        color: Style.Theme.texto_primario
                        font.bold: true
                        font.pixelSize: 18 * Math.min(root.sx, root.sy)
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: "#DDDDDD"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 20 * sx

                        ColumnLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "ÉPOCA"
                                color: "#7A7A7A"
                                font.bold: true
                                font.pixelSize: 11 * root.sx
                            }

                            Text {
                                text: root.epocaActual
                                color: Style.Theme.texto_primario
                                font.bold: true
                                font.pixelSize: 24 * root.sx
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "PASO"
                                color: "#7A7A7A"
                                font.bold: true
                                font.pixelSize: 11 * root.sx
                            }

                            Text {
                                text: root.pasoGlobalActual
                                color: Style.Theme.texto_primario
                                font.bold: true
                                font.pixelSize: 24 * root.sx
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "LOSS"
                                color: "#7A7A7A"
                                font.bold: true
                                font.pixelSize: 11 * root.sx
                            }

                            Text {
                                text: root.perdidaActual.toFixed(4)
                                color: "#2196F3"
                                font.bold: true
                                font.pixelSize: 24 * root.sx
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    Text {
                        Layout.fillWidth: true

                        visible: root.mensajeError !== ""

                        text: "⚠ " + root.mensajeError

                        color: "#D32F2F"
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12 * root.sx
                    }

                    Text {
                        Layout.fillWidth: true

                        visible: root.mensajeCheckpoint !== ""

                        text: "✓ " + root.mensajeCheckpoint

                        color: "#2E7D32"
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12 * root.sx
                    }
                }
            }

            TextField {
                id: campoNombre
                Component.onCompleted: text = mainViewModel.trainingController.sugerirNombreCheckpoint()
                width: 300 * sx
                height: 50 * sy
            }

            RowLayout {
                width: parent.width
                height: 50 * root.sy
                spacing: 8 * root.sx

                BotonPrincipal {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50 * root.sy
                    size_text: 0.20
                    enabled: root.guardadoDisponible
                    opacity: enabled ? 1.0 : 0.45

                    text: "Guardar portable"

                    ToolTip.visible: hovered
                    ToolTip.text: enabled
                                  ? "Modelo autocontenido, listo para cargar y compartir"
                                  : "Pausa el entrenamiento antes de guardar"

                    onClicked: root.guardarModeloPortable(campoNombre.text)
                }

                BotonPrincipal {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50 * root.sy
                    size_text: 0.18
                    enabled: root.guardadoDisponible
                    opacity: enabled ? 1.0 : 0.45

                    text: "Guardar reanudable"

                    ToolTip.visible: hovered
                    ToolTip.text: enabled
                                  ? "Incluye el estado necesario para continuar entrenando"
                                  : "Pausa el entrenamiento antes de guardar"

                    onClicked: root.guardarCheckpointReanudable(campoNombre.text)
                }
            }

            

            BotonPrincipal {
                        id: botonPrediccion
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 200 * root.sx
                        height: 50 * root.sy
                        anchors.margins: 20

                        text: "Predicción"
                        enabled: !mainViewModel.trainingController.estaEntrenando
                        opacity: enabled ? 1.0 : 0.45

                        ToolTip.visible: hovered
                        ToolTip.text: enabled
                                      ? "Usar el modelo activo para generar texto"
                                      : "Detén el entrenamiento antes de abrir inferencia"

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
