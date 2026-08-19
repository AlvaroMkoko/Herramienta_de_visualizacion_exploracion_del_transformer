pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root
    objectName: "trainingScreen"

    readonly property var viewModel: mainViewModel
    readonly property var trainingController: root.viewModel.trainingController

    property int epocasIniciales: 10
    property real tasaAprendizajeInicial: 0.0003
    property int batchSizeInicial: 16

    property int epocaActual: 0
    property int pasoGlobalActual: 0
    property real perdidaActual: 0
    property real deltaPerdida: 0
    property real normaGradiente: 0
    property string lecturaPerdida: "Inicia el entrenamiento para ver datos reales."
    property string componenteRelevanteId: ""
    property string componenteRelevante: "Esperando el primer batch"
    property real intensidadRelevante: 0
    property var componentesSnapshot: ({})
    property var prediccionesTop: []
    property var historialVisible: []
    property var teoriaActual: ({})

    property string mensajeError: ""
    property string mensajeCheckpoint: ""
    property bool entrenamientoTerminado: false
    property bool fueCancelado: false
    property var historialFinal: []
    property real perdidaFinalObtenida: 0
    property int epocasCompletadas: 0
    property int pasosFinales: 0

    readonly property var componenteActual: {
        if (localBridge.selectedId === "")
            return null
        var datosReales = root.componentesSnapshot
                          ? root.componentesSnapshot[localBridge.selectedId]
                          : null
        return datosReales || root.componenteBase(localBridge.selectedId)
    }

    function mostrarTeoriaComponente(componentId) {
        if (!componentId) {
            root.teoriaActual = ({})
            return
        }
        root.teoriaActual = root.viewModel.theoryController.obtenerTeoriaDeComponente(componentId)
    }

    function mostrarConceptoRelacionado(conceptId) {
        var concepto = root.viewModel.theoryController.obtenerConcepto(conceptId)
        var resultado = ({})
        for (var clave in concepto)
            resultado[clave] = concepto[clave]
        resultado.relacionados = root.viewModel.theoryController.obtenerRelacionados(conceptId)
        resultado.componente_id = localBridge.selectedId
        root.teoriaActual = resultado
    }

    // Velocidad de entrenamiento: retardo en segundos entre pasos.
    // Ralentizar no mejora el modelo — sirve para poder observar cómo
    // cambian las métricas y los mapas de atención paso a paso.
    readonly property var velocidadesDisponibles: [
        { segundos: 0.0,  etiqueta: "Máxima" },
        { segundos: 0.05, etiqueta: "Rápida" },
        { segundos: 0.15, etiqueta: "Media" },
        { segundos: 0.4,  etiqueta: "Lenta" },
        { segundos: 1.0,  etiqueta: "Paso a paso" }
    ]
    property int indiceVelocidad: 0
    readonly property real velocidadActual: root.velocidadesDisponibles[root.indiceVelocidad].segundos
    readonly property string etiquetaVelocidad: root.velocidadesDisponibles[root.indiceVelocidad].etiqueta

    function cambiarVelocidad(delta) {
        var nuevo = Math.max(0, Math.min(root.velocidadesDisponibles.length - 1,
                                         root.indiceVelocidad + delta))
        if (nuevo === root.indiceVelocidad)
            return
        root.indiceVelocidad = nuevo

        // establecer_velocidad solo alcanza a un trabajador ya corriendo.
        // Si no hay entrenamiento activo, el valor se aplica al iniciar,
        // vía el cuarto argumento de iniciar_entrenamiento_ui.
        if (root.trainingController.estaEntrenando)
            root.trainingController.establecer_velocidad(root.velocidadActual)
    }

    function numero(valor, decimales) {
        var numeroReal = Number(valor)
        return isFinite(numeroReal) ? numeroReal.toFixed(decimales) : "—"
    }

    function componenteBase(componentId) {
        return {
            "titulo": root.teoriaActual && root.teoriaActual.title
                      ? root.teoriaActual.title : "Componente del Transformer",
            "metricas": [{
                "etiqueta": "Datos reales",
                "valor": "Esperando",
                "detalle": "Inicia el entrenamiento; esta sección se actualizará al terminar el primer batch."
            }],
            "capas": []
        }
    }

    property var nubeEmbeddings: ({})

    function registrarPaso(paso) {
        root.epocaActual = Number(paso.epoca || 0)
        root.pasoGlobalActual = Number(paso.paso_global || 0)
        root.perdidaActual = Number(paso.perdida || 0)

        var visualizacion = paso.visualizacion || {}
        var resumen = visualizacion.resumen || {}
        root.deltaPerdida = Number(resumen.delta_perdida || 0)
        root.normaGradiente = Number(resumen.norma_gradiente_global || 0)
        root.lecturaPerdida = resumen.lectura_perdida || ""
        root.componenteRelevanteId = resumen.componente_relevante_id || ""
        root.componenteRelevante = resumen.componente_relevante || "Sin señal"
        root.intensidadRelevante = Number(resumen.intensidad_relevante || 0)
        root.prediccionesTop = resumen.predicciones_top || []
        root.componentesSnapshot = visualizacion.componentes || ({})

        var siguiente = root.historialVisible.slice(Math.max(0, root.historialVisible.length - 39))
        siguiente.push(root.perdidaActual)
        root.historialVisible = siguiente

        if (paso.nube_embeddings !== undefined)
            root.nubeEmbeddings = paso.nube_embeddings
    }

    QtObject {
        id: localBridge
        property string selectedId: ""
        property int numCapas: 1

        function selectComponent(componentId) {
            if (selectedId === componentId)
                clearSelection()
            else {
                selectedId = componentId
                root.mostrarTeoriaComponente(componentId)
            }
        }

        function clearSelection() {
            selectedId = ""
            root.teoriaActual = ({})
        }

        function showOverview() {
            clearSelection()
        }
    }

    Shortcut {
        sequence: "Esc"
        enabled: localBridge.selectedId !== ""
        onActivated: localBridge.clearSelection()
    }

    Component.onCompleted: {
        var info = root.viewModel.modeloActualInfo || {}
        localBridge.numCapas = Number(info.num_capas || 1)

        root.trainingController.activarNubeEmbeddings(false)
        root.trainingController.configurarNubeEmbeddings("pca", [0,1,2], 10)
    }

    Connections {
        target: root.trainingController
        ignoreUnknownSignals: true

        function onPaso_entrenamiento(paso) {
            root.registrarPaso(paso)
        }

        function onEntrenamiento_completo(resultado) {
            root.historialFinal = resultado.historial_perdidas || []
            root.perdidaFinalObtenida = Number(resultado.perdida_final || 0)
            root.epocasCompletadas = resultado.epoca !== undefined && resultado.epoca !== null
                                     ? Number(resultado.epoca) + 1 : 0
            root.pasosFinales = Number(resultado.paso_global || 0)
            root.fueCancelado = false
            root.entrenamientoTerminado = true
        }

        function onEntrenamiento_cancelado(resultado) {
            var historial = resultado.historial_perdidas || []
            root.historialFinal = historial
            root.perdidaFinalObtenida = historial.length > 0 ? historial[historial.length - 1] : 0
            root.epocasCompletadas = root.epocaActual + 1
            root.pasosFinales = root.pasoGlobalActual
            root.fueCancelado = true
            root.entrenamientoTerminado = true
        }

        function onError(mensaje) {
            root.mensajeError = mensaje
        }

        function onCheckpoint_guardado(ruta) {
            root.mensajeCheckpoint = "Guardado: " + ruta
            root.mensajeError = ""
        }
    }

    Connections {
        target: root.viewModel.theoryController
        ignoreUnknownSignals: true

        function onTeoriaRecargada() {
            root.mostrarTeoriaComponente(localBridge.selectedId)
        }
    }

    background: Rectangle {
        gradient: Gradient {
            GradientStop { position: 0; color: Style.Theme.fondo }
            GradientStop { position: 1; color: Style.Theme.fondo_gradiente }
        }
    }

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 78 * root.sy

        BotonPrincipal {
            anchors.left: parent.left
            anchors.leftMargin: 22 * root.sx
            anchors.verticalCenter: parent.verticalCenter
            width: 220 * root.sx
            height: 42 * root.sy
            text: "← Volver"
            onClicked: root.stackView.pop()
        }

        Column {
            anchors.centerIn: parent
            spacing: 2 * root.sy

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Entrenamiento del Transformer"
                color: Style.Theme.texto_primario
                font.bold: true
                font.pixelSize: 25 * Math.min(root.sx, root.sy)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Selecciona un bloque para seguir sus datos reales"
                color: Style.Theme.texto_secundario
                font.pixelSize: 13 * Math.min(root.sx, root.sy)
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 26 * root.sx
            anchors.verticalCenter: parent.verticalCenter
            width: estadoTexto.implicitWidth + 28 * root.sx
            height: 34 * root.sy
            radius: height / 2
            color: root.trainingController.estaEntrenando
                   ? (root.trainingController.estaPausado ? "#FFF4D6" : "#E4F7EB")
                   : "#EEF0F5"

            Text {
                id: estadoTexto
                anchors.centerIn: parent
                text: root.trainingController.estaEntrenando
                      ? (root.trainingController.estaPausado ? "● Pausado" : "● Entrenando")
                      : (root.entrenamientoTerminado ? "✓ Finalizado" : "○ Preparado")
                color: root.trainingController.estaEntrenando
                       ? (root.trainingController.estaPausado ? "#9A641B" : "#258F6F")
                       : Style.Theme.texto_secundario
                font.bold: true
                font.pixelSize: 12 * root.sx
            }
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 22 * root.sx
        anchors.rightMargin: 22 * root.sx
        anchors.bottomMargin: 22 * root.sy
        spacing: 18 * root.sx

        RectanglePrincipal {
            id: mapaCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 850 * root.sx
            sx: root.sx
            sy: root.sy

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18 * root.sx
                spacing: 10 * root.sy

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 78 * root.sy
                    Layout.minimumHeight: 78 * root.sy
                    Layout.maximumHeight: 78 * root.sy
                    spacing: 10 * root.sx

                    Repeater {
                        model: [
                            { label: "ÉPOCA", value: (root.epocaActual + 1) + " / " + root.epocasIniciales, color: "#6C5FC3" },
                            { label: "PASO", value: String(root.pasoGlobalActual), color: "#3979B7" },
                            { label: "PÉRDIDA", value: root.numero(root.perdidaActual, 4), color: "#258F6F" },
                            { label: "Δ PÉRDIDA", value: (root.deltaPerdida > 0 ? "+" : "") + root.numero(root.deltaPerdida, 4), color: root.deltaPerdida <= 0 ? "#258F6F" : "#B25D35" },
                            { label: "GRADIENTE", value: root.numero(root.normaGradiente, 3), color: "#9A641B" }
                        ]

                        delegate: Rectangle {
                            id: summaryMetric
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8 * root.sx
                            color: Qt.alpha(summaryMetric.modelData.color, 0.08)
                            border.color: Qt.alpha(summaryMetric.modelData.color, 0.28)

                            Column {
                                anchors.centerIn: parent
                                spacing: 3 * root.sy
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: summaryMetric.modelData.label
                                    color: Style.Theme.texto_secundario
                                    font.bold: true
                                    font.pixelSize: 10 * root.sx
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: summaryMetric.modelData.value
                                    color: summaryMetric.modelData.color
                                    font.bold: true
                                    font.pixelSize: 18 * root.sx
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62 * root.sy
                    Layout.minimumHeight: 62 * root.sy
                    Layout.maximumHeight: 62 * root.sy
                    radius: 9 * root.sx
                    color: "#FFF9E8"
                    border.color: "#E7CD78"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14 * root.sx
                        anchors.rightMargin: 14 * root.sx
                        spacing: 12 * root.sx

                        Rectangle {
                            Layout.preferredWidth: 34 * root.sx
                            Layout.preferredHeight: 34 * root.sy
                            radius: 17 * root.sx
                            color: "#E7CD78"
                            Text { anchors.centerIn: parent; text: "↗"; font.bold: true; color: "#594A1C" }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: "Cambio más relevante · " + root.componenteRelevante
                                color: "#594A1C"
                                font.bold: true
                                font.pixelSize: 12 * root.sx
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.lecturaPerdida + " Intensidad RMS: " + root.numero(root.intensidadRelevante, 5)
                                color: "#766529"
                                elide: Text.ElideRight
                                font.pixelSize: 10 * root.sx
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 560 * root.sy

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8 * root.sy

                        TabBar {
                            id: barraPestanas
                            Layout.fillWidth: true

                            onCurrentIndexChanged: {
                                root.trainingController.activarNubeEmbeddings(barraPestanas.currentIndex === 1)
                            }

                            TabButton { text: "Arquitectura" }
                            TabButton { text: "Embeddings 3D" }
                        }

                        StackLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            currentIndex: barraPestanas.currentIndex

                            TransformerDiagram {
                                objectName: "trainingTransformerDiagram"
                                bridge: localBridge
                                trainingMode: true
                                highlightedComponentId: root.componenteRelevanteId
                            }

                            NubeEmbeddings3D {
                                puntos: root.nubeEmbeddings.puntos || []
                                etiquetas: root.nubeEmbeddings.etiquetas || []
                                varianzaConservada: Number(root.nubeEmbeddings.varianza_conservada || 0)
                                varianzaPorComponente: root.nubeEmbeddings.varianza_por_componente || []
                                modo: root.nubeEmbeddings.modo || "pca"
                                dimensiones: root.nubeEmbeddings.dimensiones || []
                                // Solo rota sola cuando la pestaña esta visible,
                                // para no repintar un Canvas que nadie ve.
                                rotacionAutomatica: barraPestanas.currentIndex === 1
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.preferredWidth: 500 * root.sx
            Layout.minimumWidth: 430 * root.sx
            Layout.fillHeight: true
            spacing: 12 * root.sy

            RectanglePrincipal {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sx: root.sx
                sy: root.sy

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 16 * root.sx
                    clip: true
                    contentWidth: availableWidth

                    Column {
                        width: parent.width
                        spacing: 12 * root.sy

                        Rectangle {
                            visible: !root.componenteActual
                            width: parent.width
                            height: vacioLayout.implicitHeight + 30 * root.sy
                            radius: 9 * root.sx
                            color: "#F5F3FB"

                            Column {
                                id: vacioLayout
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: 16 * root.sx
                                spacing: 8 * root.sy
                                Text {
                                    width: parent.width
                                    text: "Haz clic en cualquier componente del mapa."
                                    color: "#5B4FA3"
                                    font.bold: true
                                    font.pixelSize: 14 * root.sx
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    width: parent.width
                                    text: "Verás qué operación realiza, qué recibe, qué entrega y cómo están cambiando sus pesos durante el batch actual. El punto pulsante marca el bloque con mayor gradiente RMS."
                                    color: Style.Theme.texto_secundario
                                    font.pixelSize: 12 * root.sx
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        ContextPanel {
                            objectName: "trainingContextPanel"
                            visible: root.componenteActual
                            width: parent.width
                            height: visible ? 360 * root.sy : 0
                            sx: root.sx
                            sy: root.sy
                            concepto: root.teoriaActual
                            errorCarga: root.viewModel.theoryController.errorCarga
                            onCloseRequested: localBridge.clearSelection()
                            onConceptRequested: function(conceptId) {
                                root.mostrarConceptoRelacionado(conceptId)
                            }
                        }

                        Text {
                            visible: root.componenteActual
                            text: "DATOS REALES · BATCH ACTUAL"
                            color: "#258F6F"
                            font.bold: true
                            font.pixelSize: 11 * root.sx
                        }

                        Repeater {
                            model: root.componenteActual ? root.componenteActual.metricas : []
                            delegate: Rectangle {
                                id: metricDelegate
                                required property var modelData
                                width: parent.width
                                height: metricaLayout.implicitHeight + 16 * root.sy
                                radius: 7 * root.sx
                                color: "#FAFBFC"
                                border.color: "#E3E6EA"

                                RowLayout {
                                    id: metricaLayout
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: 9 * root.sx
                                    spacing: 8 * root.sx
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            Layout.fillWidth: true
                                            text: metricDelegate.modelData.etiqueta
                                            color: Style.Theme.texto_secundario
                                            font.pixelSize: 10 * root.sx
                                            wrapMode: Text.WordWrap
                                        }
                                        Text {
                                            visible: metricDelegate.modelData.detalle !== ""
                                            Layout.fillWidth: true
                                            text: metricDelegate.modelData.detalle
                                            color: "#9297A1"
                                            font.pixelSize: 9 * root.sx
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                    Text {
                                        text: metricDelegate.modelData.valor
                                        color: Style.Theme.texto_primario
                                        font.bold: true
                                        font.pixelSize: 13 * root.sx
                                    }
                                }
                            }
                        }

                        Column {
                            visible: root.componenteActual && root.componenteActual.capas.length > 0
                            width: parent.width
                            spacing: 6 * root.sy

                            Text {
                                text: "ATENCIÓN POR CAPA"
                                color: "#9A641B"
                                font.bold: true
                                font.pixelSize: 11 * root.sx
                            }
                            Repeater {
                                model: root.componenteActual ? root.componenteActual.capas : []
                                delegate: RowLayout {
                                    id: layerDelegate
                                    required property var modelData
                                    width: parent.width
                                    height: 24 * root.sy
                                    Text {
                                        text: "Capa " + layerDelegate.modelData.capa
                                        color: Style.Theme.texto_secundario
                                        font.pixelSize: 10 * root.sx
                                        Layout.preferredWidth: 55 * root.sx
                                    }
                                    ProgressBar {
                                        Layout.fillWidth: true
                                        from: 0
                                        to: 1
                                        value: Math.min(1, Number(layerDelegate.modelData.pico || 0))
                                    }
                                    Text {
                                        text: "pico " + root.numero(layerDelegate.modelData.pico, 3)
                                        color: "#7A5B28"
                                        font.pixelSize: 9 * root.sx
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.prediccionesTop.length > 0 && localBridge.selectedId === "softmax"
                            width: parent.width
                            text: "Top actual: " + root.prediccionesTop.map(function(item) {
                                return "“" + item.texto + "” " + Math.round(item.probabilidad * 100) + "%"
                            }).join("  ·  ")
                            color: "#3979B7"
                            font.pixelSize: 10 * root.sx
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            RectanglePrincipal {
                Layout.fillWidth: true
                Layout.preferredHeight: 184 * root.sy
                sx: root.sx
                sy: root.sy

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12 * root.sx
                    spacing: 8 * root.sy

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8 * root.sx

                        BotonPrincipal {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42 * root.sy
                            text: !root.trainingController.estaEntrenando
                                  ? "▶ Iniciar"
                                  : (root.trainingController.estaPausado ? "▶ Reanudar" : "Ⅱ Pausar")
                            onClicked: {
                                var controlador = root.trainingController
                                if (!controlador.estaEntrenando) {
                                    root.mensajeError = ""
                                    root.entrenamientoTerminado = false
                                    localBridge.clearSelection()
                                    controlador.iniciar_entrenamiento_ui(
                                        root.epocasIniciales,
                                        root.tasaAprendizajeInicial,
                                        root.batchSizeInicial,
                                        root.velocidadActual
                                    )
                                } else if (controlador.estaPausado) {
                                    controlador.reanudar()
                                } else {
                                    controlador.pausar()
                                }
                            }
                        }

                        BotonPrincipal {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42 * root.sy
                            text: "■ Detener"
                            enabled: root.trainingController.estaEntrenando
                            opacity: enabled ? 1 : 0.45
                            onClicked: root.trainingController.detener()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8 * root.sx

                        BotonPrincipal {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36 * root.sy
                            size_text: 0.18
                            text: "🐇 Más rápido"
                            enabled: root.indiceVelocidad > 0
                            opacity: enabled ? 1 : 0.45
                            onClicked: root.cambiarVelocidad(-1)
                        }

                        BotonPrincipal {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36 * root.sy
                            size_text: 0.18
                            text: "🐢 Más lento"
                            enabled: root.indiceVelocidad < root.velocidadesDisponibles.length - 1
                            opacity: enabled ? 1 : 0.45
                            onClicked: root.cambiarVelocidad(1)
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Velocidad: " + root.etiquetaVelocidad
                              + (root.velocidadActual > 0
                                 ? "  ·  " + Math.round(root.velocidadActual * 1000) + " ms/paso"
                                 : "")
                        color: Style.Theme.texto_secundario
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 10 * root.sx
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "LR " + root.tasaAprendizajeInicial.toFixed(4)
                              + "  ·  Batch " + root.batchSizeInicial
                              + "  ·  " + root.epocasIniciales + " épocas"
                        color: Style.Theme.texto_secundario
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 10 * root.sx
                    }

                    Text {
                        visible: root.mensajeError !== "" || root.mensajeCheckpoint !== ""
                        Layout.fillWidth: true
                        text: root.mensajeError !== "" ? "⚠ " + root.mensajeError : "✓ " + root.mensajeCheckpoint
                        color: root.mensajeError !== "" ? "#D32F2F" : "#2E7D32"
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.pixelSize: 10 * root.sx
                    }

                    BotonPrincipal {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42 * root.sy
                        text: root.fueCancelado ? "Ver resumen parcial →" : "Finalizar entrenamiento →"
                        enabled: root.entrenamientoTerminado && !root.trainingController.estaEntrenando
                        opacity: enabled ? 1 : 0.45
                        onClicked: root.stackView.push("ResultsScreen.qml", {
                            "stackView": root.stackView,
                            "historialPerdidas": root.historialFinal,
                            "perdidaFinal": root.perdidaFinalObtenida,
                            "epocasCompletadas": root.epocasCompletadas,
                            "pasosTotales": root.pasosFinales,
                            "fueCancelado": root.fueCancelado
                        })
                    }
                }
            }
        }
    }
}
