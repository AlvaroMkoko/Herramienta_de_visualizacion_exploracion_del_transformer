import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"
import QtQuick.Layouts

PagePrincipal {
    id: root

    // --- Datos recibidos desde TrainingScreen al navegar aquí ---
    property var historialPerdidas: []
    property real perdidaFinal: 0
    property int epocasCompletadas: 0
    property int pasosTotales: 0
    // true si el usuario detuvo el entrenamiento en vez de dejarlo terminar
    property bool fueCancelado: false

    property string mensajeError: ""
    property string mensajeGuardado: ""

    readonly property real perdidaInicial: historialPerdidas.length > 0 ? historialPerdidas[0] : 0
    readonly property real mejoraPorcentual: porcentajeMejora(perdidaInicial, perdidaFinal)

    readonly property bool guardadoDisponible: {
        var tc = mainViewModel.trainingController
        return tc !== null && tc !== undefined
                && (!tc.estaEntrenando || tc.estaPausado)
                && (tc.guardando === undefined || !tc.guardando)
    }

    function porcentajeMejora(inicial, final) {
        if (!inicial || inicial <= 0) return 0
        return Math.round((1 - final / inicial) * 1000) / 10
    }

    // Dibujar 5000 puntos en un canvas de ~600px no aporta nada visible y
    // vuelve lento el repintado: se reduce a ~200 conservando SIEMPRE el
    // primero y el último (la pérdida final no puede perderse por muestreo).
    function submuestrear(datos, maximo) {
        if (datos.length <= maximo) return datos
        var paso = datos.length / maximo
        var resultado = []
        for (var i = 0; i < maximo; ++i) {
            resultado.push(datos[Math.floor(i * paso)])
        }
        resultado.push(datos[datos.length - 1])
        return resultado
    }

    function guardarModeloPortable(nombre) {
        var tc = mainViewModel.trainingController
        if (typeof tc.guardarModeloPortableConNombre === "function") {
            tc.guardarModeloPortableConNombre(nombre)
        } else {
            tc.guardarCheckpointConNombre(nombre)
        }
    }

    function guardarCheckpointReanudable(nombre) {
        var tc = mainViewModel.trainingController
        if (typeof tc.guardarCheckpointReanudableConNombre === "function") {
            tc.guardarCheckpointReanudableConNombre(nombre)
        } else {
            tc.guardarCheckpointConNombre(nombre)
        }
    }

    background: Rectangle {
        gradient: Gradient {
            GradientStop { position: 0; color: Style.Theme.fondo }
            GradientStop { position: 1; color: Style.Theme.fondo_gradiente }
        }
    }

    Component.onCompleted: {
        campoNombre.text = mainViewModel.trainingController.sugerirNombreCheckpoint()
    }

    Connections {
        target: mainViewModel.trainingController

        function onCheckpoint_guardado(ruta) {
            root.mensajeError = ""
            root.mensajeGuardado = "Guardado: " + ruta
        }

        function onError(mensaje) {
            root.mensajeGuardado = ""
            root.mensajeError = mensaje
        }
    }

    BotonPrincipal {
        anchors.left: parent.left
        anchors.leftMargin: 10 * sx
        anchors.top: parent.top
        anchors.topMargin: 10 * sy
        width: 250 * sx
        height: 40 * sy
        z: 10
        text: " ↶ Volver al entrenamiento"
        onClicked: stackView.pop()
    }

    // ------------------------------------------------------------------
    // Encabezado
    // ------------------------------------------------------------------
    Text {
        id: titulo
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 20 * sy
        text: root.fueCancelado ? "Entrenamiento detenido" : "Entrenamiento completado"
        color: Style.Theme.texto_primario
        font.pixelSize: 26 * sx
        font.bold: true
    }

    Text {
        id: subtitulo
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: titulo.bottom
        anchors.topMargin: 4 * sy
        visible: root.fueCancelado
        text: "Se detuvo antes de terminar todas las épocas. El modelo se puede guardar igual."
        color: "#E8A33D"
        font.pixelSize: 12 * sx
    }

    // ------------------------------------------------------------------
    // Panel izquierdo: métricas + curva de pérdida
    // ------------------------------------------------------------------
    RectanglePrincipal {
        id: panelMetricas
        sx: root.sx
        sy: root.sy

        anchors.left: parent.left
        anchors.leftMargin: 40 * sx
        anchors.top: subtitulo.bottom
        anchors.topMargin: 25 * sy
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40 * sy

        width: 620 * sx

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20 * sx
            spacing: 15 * sy

            Text {
                text: "Resumen"
                color: Style.Theme.texto_primario
                font.pixelSize: 18 * root.sx
                font.bold: true
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 10 * root.sy
                columnSpacing: 20 * root.sx

                Text {
                    text: "Pérdida inicial"
                    color: Style.Theme.texto_primario
                    font.pixelSize: 13 * root.sx
                }
                Text {
                    text: root.perdidaInicial.toFixed(4)
                    color: Style.Theme.texto_primario
                    font.pixelSize: 13 * root.sx
                    font.bold: true
                }

                Text {
                    text: "Pérdida final"
                    color: Style.Theme.texto_primario
                    font.pixelSize: 13 * root.sx
                }
                Text {
                    text: root.perdidaFinal.toFixed(4)
                    color: Style.Theme.texto_primario
                    font.pixelSize: 13 * root.sx
                    font.bold: true
                }

                Text {
                    text: "Mejora"
                    color: Style.Theme.texto_primario
                    font.pixelSize: 13 * root.sx
                }
                Text {
                    text: (root.mejoraPorcentual >= 0 ? "▼ " : "▲ ") + Math.abs(root.mejoraPorcentual) + "%"
                    color: root.mejoraPorcentual >= 0 ? "#4CAF50" : "#E05252"
                    font.pixelSize: 13 * root.sx
                    font.bold: true
                }

                Text {
                    text: "Épocas completadas"
                    color: Style.Theme.texto_primario
                    font.pixelSize: 13 * root.sx
                }
                Text {
                    text: String(root.epocasCompletadas)
                    color: Style.Theme.texto_primario
                    font.pixelSize: 13 * root.sx
                    font.bold: true
                }

                Text {
                    text: "Pasos totales"
                    color: Style.Theme.texto_primario
                    font.pixelSize: 13 * root.sx
                }
                Text {
                    text: String(root.pasosTotales)
                    color: Style.Theme.texto_primario
                    font.pixelSize: 13 * root.sx
                    font.bold: true
                }
            }

            // Una mejora negativa o nula suele indicar learning rate mal
            // elegido: conviene decirlo aquí y no dejar que el usuario lo
            // descubra recién al ver que la inferencia no tiene sentido.
            Text {
                Layout.fillWidth: true
                visible: root.mejoraPorcentual <= 0
                wrapMode: Text.WordWrap
                text: "La pérdida no bajó durante el entrenamiento. Suele deberse a un "
                    + "learning rate demasiado alto o demasiado bajo, o a muy pocas épocas "
                    + "para el tamaño del dataset."
                color: "#E8A33D"
                font.pixelSize: 11 * root.sx
            }

            Text {
                text: "Curva de pérdida"
                color: Style.Theme.texto_primario
                font.pixelSize: 15 * root.sx
                font.bold: true
                Layout.topMargin: 10 * root.sy
            }

            Canvas {
                id: curva
                Layout.fillWidth: true
                Layout.fillHeight: true

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()

                    var datos = root.submuestrear(root.historialPerdidas, 200)
                    if (datos.length < 2) {
                        ctx.fillStyle = "#888888"
                        ctx.font = "12px sans-serif"
                        ctx.fillText("Sin datos suficientes para graficar", 10, height / 2)
                        return
                    }

                    var minimo = Math.min.apply(null, datos)
                    var maximo = Math.max.apply(null, datos)
                    var rango = (maximo - minimo) || 1

                    var margen = 4
                    var anchoUtil = width - margen * 2
                    var altoUtil = height - margen * 2

                    // Rejilla horizontal de referencia
                    ctx.strokeStyle = "#3A3A55"
                    ctx.lineWidth = 1
                    for (var g = 0; g <= 4; ++g) {
                        var yg = margen + (altoUtil / 4) * g
                        ctx.beginPath()
                        ctx.moveTo(margen, yg)
                        ctx.lineTo(width - margen, yg)
                        ctx.stroke()
                    }

                    ctx.strokeStyle = "#6A63E8"
                    ctx.lineWidth = 2
                    ctx.beginPath()
                    for (var i = 0; i < datos.length; ++i) {
                        var x = margen + (i / (datos.length - 1)) * anchoUtil
                        var y = margen + altoUtil - ((datos[i] - minimo) / rango) * altoUtil
                        if (i === 0) ctx.moveTo(x, y)
                        else ctx.lineTo(x, y)
                    }
                    ctx.stroke()

                    ctx.fillStyle = "#888888"
                    ctx.font = "10px sans-serif"
                    ctx.fillText(maximo.toFixed(3), margen + 2, margen + 10)
                    ctx.fillText(minimo.toFixed(3), margen + 2, height - margen - 2)
                }

                Component.onCompleted: requestPaint()
            }
        }
    }

    // ------------------------------------------------------------------
    // Panel derecho: guardar y siguiente paso
    // ------------------------------------------------------------------
    ColumnLayout {
        anchors.left: panelMetricas.right
        anchors.leftMargin: 25 * sx
        anchors.right: parent.right
        anchors.rightMargin: 40 * sx
        anchors.top: panelMetricas.top
        spacing: 20 * sy

        RectanglePrincipal {
            id: panelGuardar
            Layout.fillWidth: true
            Layout.preferredHeight: layoutGuardar.implicitHeight + 30 * root.sy
            sx: root.sx
            sy: root.sy

            ColumnLayout {
                id: layoutGuardar
                anchors.fill: parent
                anchors.margins: 15 * root.sx
                spacing: 10 * root.sy

                Text {
                    text: "Guardar modelo"
                    color: Style.Theme.texto_primario
                    font.pixelSize: 16 * root.sx
                    font.bold: true
                }

                TextField {
                    id: campoNombre
                    Layout.fillWidth: true
                    Layout.preferredHeight: 35 * root.sy
                    placeholderText: "Nombre del modelo"
                }

                BotonPrincipal {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42 * root.sy
                    text: "Guardar modelo portable"
                    enabled: root.guardadoDisponible
                    opacity: enabled ? 1.0 : 0.55
                    onClicked: {
                        root.mensajeError = ""
                        root.mensajeGuardado = ""
                        root.guardarModeloPortable(campoNombre.text)
                    }
                }

                BotonPrincipal {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42 * root.sy
                    text: "Guardar para reanudar"
                    enabled: root.guardadoDisponible
                    opacity: enabled ? 1.0 : 0.55
                    onClicked: {
                        root.mensajeError = ""
                        root.mensajeGuardado = ""
                        root.guardarCheckpointReanudable(campoNombre.text)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: "«Portable» guarda solo el modelo, listo para inferencia. "
                        + "«Reanudar» incluye además el estado del optimizador para "
                        + "seguir entrenando después."
                    color: "#9A9AB0"
                    font.pixelSize: 10 * root.sx
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.mensajeGuardado !== ""
                    wrapMode: Text.WordWrap
                    text: root.mensajeGuardado
                    color: "#4CAF50"
                    font.pixelSize: 11 * root.sx
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.mensajeError !== ""
                    wrapMode: Text.WordWrap
                    text: root.mensajeError
                    color: "#E05252"
                    font.pixelSize: 11 * root.sx
                }
            }
        }

        RectanglePrincipal {
            Layout.fillWidth: true
            Layout.preferredHeight: layoutSiguiente.implicitHeight + 30 * root.sy
            sx: root.sx
            sy: root.sy

            ColumnLayout {
                id: layoutSiguiente
                anchors.fill: parent
                anchors.margins: 15 * root.sx
                spacing: 10 * root.sy

                Text {
                    text: "Siguiente paso"
                    color: Style.Theme.texto_primario
                    font.pixelSize: 16 * root.sx
                    font.bold: true
                }

                BotonPrincipal {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45 * root.sy
                    text: "Probar el modelo →"
                    onClicked: {
                        stackView.push("InferenceScreen.qml", {
                            "stackView": stackView
                        })
                    }
                }

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: "Genera texto con el modelo recién entrenado. No hace falta "
                        + "guardarlo antes: sigue cargado en memoria."
                    color: "#9A9AB0"
                    font.pixelSize: 10 * root.sx
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}