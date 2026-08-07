// import QtQuick
// import QtQuick.Controls
// import "../styles" as Style
// import "../components"
// import QtQuick.Layouts
// PagePrincipal {
//     id:root


//     ListModel {
//         id: datasetsSeleccionadosModel
//     }

//     function actualizarDatasetsSeleccionados(lista) {
//         datasetsSeleccionadosModel.clear()
//         for (let i = 0; i < lista.length; ++i) {
//             datasetsSeleccionadosModel.append(lista[i])
//         }
//     }

//     function extraerdataId(lista) {
//         let idsSeleccionados = []
//         for (let i = 0; i < lista.count; ++i) {
//             idsSeleccionados.push(lista.get(i).id)
//         }
//         return idsSeleccionados
//     }






//     property bool mostrarTarjeta: false

//     // Preview en vivo (parámetros/memoria estimada) y errores de configuración
//     property int parametrosTotales: 0
//     property real memoriaEstimadaMb: 0
//     property string mensajeError: ""

//     // Hiperparámetros de ENTRENAMIENTO (no van a SetupController — se
//     // guardan acá y se pasan a TrainingScreen cuando el modelo esté listo)
//     property int epocas: 6
//     property real tasaAprendizaje: 0.0003
//     property int batchSize: 6

//     Component.onCompleted: {
//         mainViewModel.setupController.resumen_cambio.connect(function(resumen) {
//             root.parametrosTotales = resumen.parametros_totales
//             root.memoriaEstimadaMb = resumen.memoria_estimada_mb
//         })
//         mainViewModel.setupController.error_configuracion.connect(function(mensaje) {
//             root.mensajeError = mensaje
//         })
//         mainViewModel.errorDataset.connect(function(mensaje) {
//             root.mensajeError = mensaje
//         })
//     }

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

//     Rectangle{
        
//         property real size_width: 300
//         property real size_height:1000
//         width:size_width * sx
//         height:size_height * sy
//         // color: "transparent"
//         color:"blue"
//         // clip: true          

        
//         anchors.right: parent.right
//         anchors.verticalCenter: parent.verticalCenter   // opcional, si querés centrado vertical
//         anchors.rightMargin: 30

//         Column{
//             anchors.centerIn: parent
//             width: parent.size_width * sx

//             spacing: 60 * sy


//             anchors.horizontalCenter: parent.horizontalCenter
//             anchors.verticalCenter: parent.verticalCenter
//             anchors.verticalCenterOffset: -50 * sy
//             RectanglePrincipal {
                
//                 id: rectangulo_blanco_1
//                 width: parent.width
//                 height:500 * sy
//                 // anchors.verticalCenterOffset: -500 * sy

//                 sx: root.sx
//                 sy: root.sy

//                 ColumnLayout{
//                     // spacing: 10
//                     // width: parent.width-30
//                     // anchors.margins: 15 * sx
//                     anchors.fill: parent
//                     anchors.margins: 10 * sx

//                     spacing: 1 * sy 

//                      SliderColumn {
//                         // width: parent.width 
//                         // // anchors.fill: parent
//                         // anchors.margins: 30 * sx
//                         Layout.fillWidth:true
//                         Layout.fillHeight:true


//                         sx: root.sx
//                         sy: root.sy

//                         text: "Capas Encoder (Nx)"

//                         from: 1
//                         to: 12

//                         stepSize: 1
//                         value: 6

//                         onValueChanged: {
//                             mainViewModel.setupController.establecer_num_capas(value)
//                         }
//                     }
//                      SliderColumn {
//                         // width: parent.width 
//                         // // anchors.fill: parent
//                         // anchors.margins: 30 * sx
//                         Layout.fillWidth:true
//                         Layout.fillHeight:true



//                         sx: root.sx
//                         sy: root.sy

//                         text: "Dimension del Modelo"

//                         from: 32
//                         to: 512

//                         stepSize: 32
//                         value: 64

//                         onValueChanged: {
//                             mainViewModel.setupController.establecer_dimension_modelo(value)
//                         }
//                     }
//                      SliderColumn {
//                         // width: parent.width 
//                         // // anchors.fill: parent
//                         // anchors.margins: 30 * sx
//                         Layout.fillWidth:true
//                         Layout.fillHeight:true


//                         sx: root.sx
//                         sy: root.sy

//                         text: "Dimension-Feed Forward"

//                         from: 128
//                         to: 2048

//                         stepSize: 128
//                         value: 256

//                         onValueChanged: {
//                             mainViewModel.setupController.establecer_dimension_ff(value)
//                         }
//                     }
//                      SliderColumn {
//                         // width: parent.width 
//                         // // anchors.fill: parent
//                         // anchors.margins: 30 * sx
//                         Layout.fillWidth:true
//                         Layout.fillHeight:true


//                         sx: root.sx
//                         sy: root.sy

//                         text: "Longitud Maxima de Secuencia"

//                         from: 16
//                         to: 512

//                         stepSize: 16
//                         value: 64

//                         onValueChanged: {
//                             mainViewModel.setupController.establecer_longitud_maxima_secuencia(value)
//                         }
//                     }
                    
                    

//                     SliderColumn {
//                     // // anchors.fill: parent
//                     // width: parent.width
//                     // anchors.margins: 15 * sx
//                     Layout.fillWidth:true
//                     Layout.fillHeight:true

//                     sx: root.sx
//                     sy: root.sy

//                     text: "Épocas"

//                     from: 1
//                     to: 24

//                     stepSize: 1
//                     value: 6

//                     onValueChanged: {
//                         root.epocas = value
//                     }
//                 }
//                  SliderColumn {
//                     // // anchors.fill: parent
//                     // width: parent.width
//                     // anchors.margins: 15 * sx
//                     Layout.fillWidth:true
//                     Layout.fillHeight:true

//                     sx: root.sx
//                     sy: root.sy

//                     text: "Learning Rate"
//                     from: 0
//                     to: 0.01
//                     stepSize: 0.0001
//                     value: 0.0003

//                     tipo_dato:"decimal"

//                     onValueChanged: {
//                         root.tasaAprendizaje = value
//                     }
//                 }

//                  SliderColumn {
//                     // width: parent.width
//                     // anchors.margins: 15 * sx
//                     Layout.fillWidth:true
//                     sx: root.sx
//                     sy: root.sy

//                     text: "Batch Size"

//                     from: 1
//                     to: 24

//                     stepSize: 1
//                     value: 6

//                     onValueChanged: {
//                         root.batchSize = value
//                     }
//                 }

//                 }
                
//             }

//             RectanglePrincipal{

//                 id: rectangulo_blanco_2
//                 width: parent.width 
//                 // anchors.rightMargin: 400
//                 sx: root.sx
//                 sy: root.sy
//                 // width: 300*sx
//                 height: 200*sy

//                 ColumnLayout {
//                     anchors.fill: parent
//                     anchors.margins: 15 * sx
//                     spacing: 6 * sy

//                     Text {
//                         Layout.alignment: Qt.AlignHCenter
//                         text: "Parámetros: " + root.parametrosTotales.toLocaleString()
//                             + "  (~" + root.memoriaEstimadaMb + " MB)"
//                         color: Style.Theme.texto_primario
//                         font.pixelSize: 14 * root.sx
//                     }

//                     Text {
//                         Layout.alignment: Qt.AlignHCenter
//                         visible: root.mensajeError !== ""
//                         text: root.mensajeError
//                         color: "red"
//                         wrapMode: Text.WordWrap
//                         Layout.preferredWidth: parent.width
//                         horizontalAlignment: Text.AlignHCenter
//                         font.pixelSize: 12 * root.sx
//                     }
//                 }

//             }

//             BotonPrincipal {
//                         id: botonIniciarEntrenamiento
//                         anchors.horizontalCenter: parent.horizontalCenter
//                         width: 200 * root.sx
//                         height: 50 * root.sy
//                         anchors.margins: 20

//                         text: "Iniciar Entrenamiento"

//                         onClicked: {
//                             root.mensajeError = ""

//                             if (datasetsSeleccionadosModel.count === 0) {
//                                 root.mensajeError = "Selecciona al menos un dataset para continuar."
//                                 return
//                             }
//                             mainViewModel.setupController.crear_modelo()

//                             if (root.mensajeError !== "") return

//                             let idsSeleccionados = extraerdataId(datasetsSeleccionadosModel)
//                             mainViewModel.cargarDatasetsParaEntrenar(idsSeleccionados)
//                             if (root.mensajeError !== "") return

//                             if (root.mensajeError === "") {
//                                 stackView.push("TrainingScreen.qml", {
//                                     "stackView": stackView,
//                                     "epocasIniciales": root.epocas,
//                                     "tasaAprendizajeInicial": root.tasaAprendizaje,
//                                     "batchSizeInicial": root.batchSize
//                                 })
//                             }
//                         }
                    
//             }
//         }
//     }


// Rectangle {
//     id: rec_left

//     width: 250 * sx
//     height: 700 * sy
//     color: "blue"

//     anchors.left: parent.left
//     anchors.leftMargin: 20 * sx
//     anchors.verticalCenter: parent.verticalCenter

//     ColumnLayout {
//         anchors.fill: parent
//         anchors.margins: 6 * sx

//         spacing: 30 * sy

//         RectanglePrincipal {
//             id: rectangulo_blanco_3

//             Layout.fillWidth: true
//             Layout.preferredHeight: 400 * sy

//             sx: root.sx
//             sy: root.sy

//             ColumnLayout {
//                 anchors.fill: parent
//                 anchors.margins: 15 * sx

//                 Item {
//                     Layout.fillHeight: true
//                 }

//                 BotonPrincipal {
//                     id: botonModelo

//                     Layout.alignment: Qt.AlignHCenter

//                     Layout.preferredWidth: 160 * sx
//                     Layout.preferredHeight: 50 * sy

//                     text: "Gestionar DataSet"

//                     onClicked: {
//                         // root.mostrarTarjeta = !root.mostrarTarjeta
//                         stackView.push("DataSetScreen.qml", {
//                                 "stackView": stackView
//                             })
//                     }
//                 }

//                  Repeater {
//                     model: datasetsSeleccionadosModel
//                     delegate: Rectangle {
//                         Layout.alignment: Qt.AlignHCenter
//                         Layout.preferredWidth: 180 * sx
//                         Layout.preferredHeight: 30 * sy
//                         radius: 6
//                         color: "#6A63E8"

//                         Text {
//                             anchors.centerIn: parent
//                             text: nombre
//                             color: "white"
//                             font.pixelSize: 12 * sy
//                             elide: Text.ElideRight
//                             width: parent.width - 10
//                             horizontalAlignment: Text.AlignHCenter
//                         }
//                     }
//                 }
//             }
//         }

//         Item {
//             Layout.fillHeight: true
//         }
//     }
// }

//     Rectangle{
//         property real size_width: 250
//         width:size_width * sx
//         height:700 * sy
//         color:"transparent"

//         anchors.verticalCenter: parent.verticalCenter
//         anchors.centerIn: parent

//         // NOTA: antes esta tarjeta estaba condicionada a
//         // "root.mostrarTarjeta", pero nada en el archivo lo ponia en
//         // true — "Numero de Cabezas" y "Drop-out" quedaban invisibles
//         // sin ninguna forma de mostrarlos. Se deja siempre visible; si
//         // la idea era un toggle, hace falta un boton que cambie
//         // root.mostrarTarjeta explicitamente.

//         RectanglePrincipal{
//             id: rectangulo_blanco_4
//             anchors.left: parent.left
//             // anchors.rightMargin: 400
//             sx: root.sx
//             sy: root.sy

//             width: parent.size_width * sx
//             // width: 300 * sx
//             ColumnLayout{
//                     // width: parent.width-30
//                     anchors.fill: parent 
//                     anchors.margins: 10 * sx

//                     spacing: 10 * sx
                    
//                      SliderColumn {
//                             Layout.fillWidth:true
                            
//                             // width: parent.width 
//                             // anchors.fill: parent

//                             sx: root.sx
//                             sy: root.sy

//                             text: "Numero de Cabezas (Heads)"

//                             from: 1
//                             to: 12

//                             stepSize: 1
//                             value: 6

//                             onValueChanged: {
//                                 mainViewModel.setupController.establecer_num_cabezas(value)
//                             }
//                         }

//                     SliderColumn {
//                     // anchors.fill: parent
//                         // width: parent.width
//                         // anchors.margins: 15 * sx
//                         Layout.fillWidth:true

//                         sx: root.sx
//                         sy: root.sy

//                         text: "Drop-out"

//                         from: 0
//                         to: 0.5

//                         stepSize: 0.05
//                         value: 0.1
//                         tipo_dato:"decimal"
//                         onValueChanged: {
//                             mainViewModel.setupController.establecer_dropout(value)
//                         }
//                     }
                 
//                 }

//                 }


//         }

//     }



import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"
import QtQuick.Layouts

PagePrincipal {
    id: root

    // La biblioteca usa esta pantalla solo para elegir datasets y
    // parametros de la nueva sesion, conservando arquitectura y pesos.
    property bool usarModeloActual: false

    ListModel {
        id: datasetsSeleccionadosModel
    }

    function actualizarDatasetsSeleccionados(lista) {
        datasetsSeleccionadosModel.clear()
        for (let i = 0; i < lista.length; ++i) {
            datasetsSeleccionadosModel.append(lista[i])
        }
    }

    function extraerdataId(lista) {
        let idsSeleccionados = []
        for (let i = 0; i < lista.count; ++i) {
            idsSeleccionados.push(lista.get(i).id)
        }
        return idsSeleccionados
    }

    property bool mostrarTarjeta: false

    property int parametrosTotales: 0
    property real memoriaEstimadaMb: 0
    property string mensajeError: ""

    property int epocas: 6
    property real tasaAprendizaje: 0.0003
    property int batchSize: 6
    property bool inicioEntrenamientoPendiente: false
    property var datasetsInicioPendientes: []

    function completarInicioEntrenamiento() {
        if (!root.inicioEntrenamientoPendiente || !mainViewModel.modeloListo)
            return
        root.inicioEntrenamientoPendiente = false
        root.mensajeError = ""
        mainViewModel.cargarDatasetsParaEntrenar(root.datasetsInicioPendientes)
        if (root.mensajeError !== "")
            return
        root.stackView.push("TrainingScreen.qml", {
            "stackView": root.stackView,
            "epocasIniciales": root.epocas,
            "tasaAprendizajeInicial": root.tasaAprendizaje,
            "batchSizeInicial": root.batchSize
        })
    }

    Connections {
        target: mainViewModel
        ignoreUnknownSignals: true

        function onModeloListoCambio() {
            root.completarInicioEntrenamiento()
        }
    }

    Component.onCompleted: {
        if (root.usarModeloActual && mainViewModel.modeloListo) {
            var infoActual = mainViewModel.modeloActualInfo
            root.parametrosTotales = Number(infoActual.parametros_totales || 0)
            root.memoriaEstimadaMb = Math.round(root.parametrosTotales * 4 / 1048576 * 10) / 10
            localBridge.numCapas = Number(infoActual.num_capas || 0)
        }
        mainViewModel.setupController.resumen_cambio.connect(function(resumen) {
            root.parametrosTotales = resumen.parametros_totales
            root.memoriaEstimadaMb = resumen.memoria_estimada_mb
        })
        mainViewModel.setupController.error_configuracion.connect(function(mensaje) {
            root.inicioEntrenamientoPendiente = false
            root.mensajeError = mensaje
        })
        mainViewModel.errorDataset.connect(function(mensaje) {
            root.mensajeError = mensaje
        })
    }

    // --- OBJETO PUENTE (BRIDGE) PARA EL DIAGRAMA ---
    // Guarda el ID del componente seleccionado en el TransformerDiagram
    QtObject {
        id: localBridge
        property string selectedId: ""
        property int numCapas: 6
        function selectComponent(id) {
            // Si el usuario da clic al mismo componente, lo deseleccionamos
            if (selectedId === id) {
                selectedId = ""
            } else {
                selectedId = id
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
        text: " ↶ Volver al inicio"
        z: 10
        onClicked: {
            stackView.pop()
        }
    }

    // --- PANEL IZQUIERDO: DATASETS ---
    Rectangle {
        id: rec_left
        width: 250 * sx
        height: 700 * sy
        color: "transparent"

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

                    Item { Layout.fillHeight: true }

                    BotonPrincipal {
                        id: botonModelo
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 160 * sx
                        Layout.preferredHeight: 50 * sy
                        text: "Gestionar DataSet"
                        onClicked: {
                            stackView.push("DataSetScreen.qml", {
                                "stackView": stackView
                            })
                        }
                    }

                    Repeater {
                        model: datasetsSeleccionadosModel
                        delegate: Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 200 * sx
                            Layout.preferredHeight: 60 * sy
                            radius: 6
                            color: "#6A63E8"

                            Text {
                                anchors.centerIn: parent
                                text: nombre
                                color: "white"
                                font.pixelSize: 15 * sy
                                elide: Text.ElideRight
                                width: parent.width - 10
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // --- ZONA CENTRAL: DIAGRAMA DEL TRANSFORMER ---
    Item {
        id: centerArea
        anchors.left: rec_left.right
        anchors.right: rightPanel.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 20 * sx

        // Instanciamos el diagrama puro sin la UI externa y le pasamos el puente local
        TransformerDiagram {
            anchors.fill: parent
            bridge: localBridge
        }
    }

    // --- PANEL DERECHO: TUS SLIDERS DE CONFIGURACIÓN ---
    Rectangle {
        id: rightPanel
        property real size_width: 320
        width: size_width * sx
        height: parent.height
        color: "transparent"
        
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 20 * sx

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: 20 * sy

            RectanglePrincipal {
                id: rectangulo_configuracion
                width: parent.width
                // Altura dinámica que se ajusta a cuántos sliders sean visibles
                height: layoutConfig.implicitHeight + 30 * sy
                sx: root.sx
                sy: root.sy

                ColumnLayout {
                    id: layoutConfig
                    anchors.fill: parent
                    anchors.margins: 15 * sx
                    spacing: 5 * sy

                    Text {
                        text: root.usarModeloActual
                              ? "Modelo cargado · arquitectura bloqueada"
                              : (localBridge.selectedId === "" ? "Configuración General" : "Parámetros del Componente")
                        color: Style.Theme.texto_primario
                        font.pixelSize: 16 * root.sx
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 10 * sy
                    }

                    // --- Sliders de Arquitectura General ---
                    SliderColumn {
                        Layout.fillWidth: true
                        visible: localBridge.selectedId === ""
                        sx: root.sx
                        sy: root.sy
                        text: "Capas Encoder (Nx)"
                        enabled: !root.usarModeloActual
                        opacity: enabled ? 1.0 : 0.55
                        from: 1
                        to: Math.max(12, Number(mainViewModel.modeloActualInfo.num_capas || 0))
                        stepSize: 1
                        value: root.usarModeloActual ? Number(mainViewModel.modeloActualInfo.num_capas || 1) : 6
                        onValueChanged: {
                            localBridge.numCapas = value
                            if (!root.usarModeloActual)
                                mainViewModel.setupController.establecer_num_capas(value)
                        }
                    }
                    SliderColumn {
                        Layout.fillWidth: true
                        visible: localBridge.selectedId === "" || localBridge.selectedId.indexOf("embedding") !== -1 || localBridge.selectedId.indexOf("feed_forward") !== -1
                        sx: root.sx
                        sy: root.sy
                        text: "Dimensión del Modelo"
                        enabled: !root.usarModeloActual
                        opacity: enabled ? 1.0 : 0.55
                        from: 32
                        to: Math.max(512, Number(mainViewModel.modeloActualInfo.dimension_modelo || 0))
                        stepSize: 32
                        value: root.usarModeloActual ? Number(mainViewModel.modeloActualInfo.dimension_modelo || 32) : 64
                        onValueChanged: {
                            if (!root.usarModeloActual)
                                mainViewModel.setupController.establecer_dimension_modelo(value)
                        }
                    }

                    // --- Sliders de Embedding ---
                    SliderColumn {
                        Layout.fillWidth: true
                        visible: localBridge.selectedId.indexOf("embedding") !== -1 || localBridge.selectedId.indexOf("positional") !== -1
                        sx: root.sx
                        sy: root.sy
                        text: "Longitud Máxima de Secuencia"
                        enabled: !root.usarModeloActual
                        opacity: enabled ? 1.0 : 0.55
                        from: 16
                        to: Math.max(512, Number(mainViewModel.modeloActualInfo.longitud_maxima_secuencia || 0))
                        stepSize: 16
                        value: root.usarModeloActual ? Number(mainViewModel.modeloActualInfo.longitud_maxima_secuencia || 16) : 64
                        onValueChanged: {
                            if (!root.usarModeloActual)
                                mainViewModel.setupController.establecer_longitud_maxima_secuencia(value)
                        }
                    }

                    // --- Sliders de Feed Forward ---
                    SliderColumn {
                        Layout.fillWidth: true
                        visible: localBridge.selectedId.indexOf("feed_forward") !== -1
                        sx: root.sx
                        sy: root.sy
                        text: "Dimensión Feed-Forward"
                        enabled: !root.usarModeloActual
                        opacity: enabled ? 1.0 : 0.55
                        from: 128
                        to: Math.max(2048, Number(mainViewModel.modeloActualInfo.dimension_ff || 0))
                        stepSize: 128
                        value: root.usarModeloActual ? Number(mainViewModel.modeloActualInfo.dimension_ff || 128) : 256
                        onValueChanged: {
                            if (!root.usarModeloActual)
                                mainViewModel.setupController.establecer_dimension_ff(value)
                        }
                    }

                    // --- Sliders de Atención ---
                    SliderColumn {
                        Layout.fillWidth: true
                        // Se muestra si es atención, pero NO si es un bloque add_norm
                        visible: localBridge.selectedId.indexOf("attention") !== -1 && localBridge.selectedId.indexOf("add_norm") === -1
                        sx: root.sx
                        sy: root.sy
                        text: "Número de Cabezas (Heads)"
                        enabled: !root.usarModeloActual
                        opacity: enabled ? 1.0 : 0.55
                        from: 1
                        to: Math.max(12, Number(mainViewModel.modeloActualInfo.num_cabezas || 0))
                        stepSize: 1
                        value: root.usarModeloActual ? Number(mainViewModel.modeloActualInfo.num_cabezas || 1) : 4
                        onValueChanged: {
                            if (!root.usarModeloActual)
                                mainViewModel.setupController.establecer_num_cabezas(value)
                        }
                    }
                    SliderColumn {
                        Layout.fillWidth: true
                        // Se muestra si es atención, pero NO si es un bloque add_norm
                        visible: localBridge.selectedId.indexOf("attention") !== -1 && localBridge.selectedId.indexOf("add_norm") === -1
                        sx: root.sx
                        sy: root.sy
                        text: "Drop-out"
                        enabled: !root.usarModeloActual
                        opacity: enabled ? 1.0 : 0.55
                        from: 0
                        to: Math.max(0.5, Number(mainViewModel.modeloActualInfo.dropout || 0))
                        stepSize: 0.05
                        value: root.usarModeloActual ? Number(mainViewModel.modeloActualInfo.dropout || 0) : 0.1
                        tipo_dato: "decimal"
                        onValueChanged: {
                            if (!root.usarModeloActual)
                                mainViewModel.setupController.establecer_dropout(value)
                        }
                    }

                    // --- Sliders de Hiperparámetros de Entrenamiento (General) ---
                    SliderColumn {
                        Layout.fillWidth: true
                        visible: localBridge.selectedId === ""
                        sx: root.sx
                        sy: root.sy
                        text: "Épocas"
                        from: 1; to: 24; stepSize: 1; value: 6
                        onValueChanged: root.epocas = value
                    }
                    SliderColumn {
                        Layout.fillWidth: true
                        visible: localBridge.selectedId === ""
                        sx: root.sx
                        sy: root.sy
                        text: "Learning Rate"
                        from: 0; to: 0.01; stepSize: 0.0001; value: 0.0003; tipo_dato: "decimal"
                        onValueChanged: root.tasaAprendizaje = value
                    }
                    SliderColumn {
                        Layout.fillWidth: true
                        visible: localBridge.selectedId === ""
                        sx: root.sx
                        sy: root.sy
                        text: "Batch Size"
                        from: 1; to: 24; stepSize: 1; value: 6
                        onValueChanged: root.batchSize = value
                    }
                }
            }

            RectanglePrincipal {
                id: rectangulo_resumen
                width: parent.width 
                height: layoutResumen.implicitHeight + 20 * sy
                sx: root.sx
                sy: root.sy

                ColumnLayout {
                    id: layoutResumen
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
                text: root.usarModeloActual ? "Continuar Entrenamiento" : "Iniciar Entrenamiento"

                onClicked: {
                    root.mensajeError = ""

                    if (datasetsSeleccionadosModel.count === 0) {
                        root.mensajeError = "Selecciona al menos un dataset para continuar."
                        return
                    }
                    let idsSeleccionados = extraerdataId(datasetsSeleccionadosModel)
                    root.datasetsInicioPendientes = idsSeleccionados
                    root.inicioEntrenamientoPendiente = true

                    if (!root.usarModeloActual) {
                        mainViewModel.setupController.crear_modelo()
                    } else if (!mainViewModel.modeloListo) {
                        root.inicioEntrenamientoPendiente = false
                        root.mensajeError = "El modelo cargado ya no esta disponible."
                        return
                    }

                    if (root.mensajeError !== "") {
                        root.inicioEntrenamientoPendiente = false
                        return
                    }
                    root.completarInicioEntrenamiento()
                }
            }
        }
    }
}
