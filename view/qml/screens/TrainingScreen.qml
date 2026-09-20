pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root
    objectName: "trainingScreen"
    helpModalObjectName: "trainingTheoryModal"
    helpPanelObjectName: "trainingContextPanel"

    readonly property var viewModel: mainViewModel
    readonly property var trainingController: root.viewModel.trainingController

    property int epocasIniciales: 10
    property real tasaAprendizajeInicial: 0.0003
    property int batchSizeInicial: 16

    property int epocaActual: 0
    property int pasoGlobalActual: 0
    property int epocaSesionActual: 0
    property int epocasSesionActual: 0
    property int loteActual: 0
    property int lotesPorEpoca: 0
    property int pasosSesionCompletados: 0
    property int pasosSesionTotales: 0
    property real progresoFraccion: 0
    property real tiempoTranscurridoSegundos: 0
    property real etaSegundos: -1
    property bool progresoDeterminado: false
    property real perdidaActual: 0
    property real deltaPerdida: 0
    property real normaGradiente: 0
    property string lecturaPerdida: "Inicia el entrenamiento para ver datos reales."
    property string componenteRelevanteId: ""
    property string componenteRelevante: "Esperando el primer batch"
    property real intensidadRelevante: 0
    property var componentesSnapshot: ({})
    property var pedagogiaSnapshot: ({})
    property var prediccionesTop: []
    property var historialVisible: []
    property var teoriaActual: ({})

    property string mensajeError: ""
    property string mensajeCheckpoint: ""
    property bool entrenamientoTerminado: false
    property bool fueCancelado: false
    property bool advancedControlsVisible: false
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
            root.closeTheory()
            return
        }
        root.teoriaActual = root.openTheoryComponent(componentId)
    }

    function mostrarConceptoRelacionado(conceptId) {
        root.teoriaActual = root.openTheoryConcept(conceptId)
    }

    function conceptoParaMetrica(etiqueta) {
        var texto = String(etiqueta || "").toLowerCase()
        if (texto.indexOf("rms") !== -1)
            return "gradient_norm_rms"
        if (texto.indexOf("gradiente") !== -1)
            return "gradient_norm_l2"
        if (texto.indexOf("entrop") !== -1 || texto.indexOf("peso de atención") !== -1)
            return "interpretacion_pesos"
        if (texto.indexOf("norma de pesos") !== -1)
            return "weight_norm"
        if (texto.indexOf("parámetro") !== -1)
            return "parameter_count"
        if (texto.indexOf("logit") !== -1)
            return "logits"
        if (texto.indexOf("vocabulario") !== -1)
            return "tokenizacion"
        if (texto.indexOf("activación") !== -1)
            return "activation_functions"
        if (texto.indexOf("máscara") !== -1)
            return "por_que_mascara"
        if (texto.indexOf("token") !== -1)
            return "token_ids"
        if (texto.indexOf("forma") !== -1 || texto.indexOf("dimensión") !== -1
                || texto.indexOf("expansión") !== -1 || texto.indexOf("mapa") !== -1)
            return "tabla_dimensiones"
        return ""
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

    function formatearDuracion(segundos) {
        var total = Math.max(0, Math.round(Number(segundos) || 0))
        if (total < 60)
            return total + " s"
        var minutos = Math.floor(total / 60)
        var segundosRestantes = total % 60
        if (minutos < 60)
            return minutos + " min " + segundosRestantes + " s"
        var horas = Math.floor(minutos / 60)
        return horas + " h " + (minutos % 60) + " min"
    }

    function reiniciarProgresoSesion() {
        root.epocaSesionActual = 0
        root.epocasSesionActual = root.epocasIniciales
        root.loteActual = 0
        root.lotesPorEpoca = 0
        root.pasosSesionCompletados = 0
        root.pasosSesionTotales = 0
        root.progresoFraccion = 0
        root.tiempoTranscurridoSegundos = 0
        root.etaSegundos = -1
        root.progresoDeterminado = false
    }

    readonly property string textoProgresoEntrenamiento: {
        if (root.trainingController.detencionSolicitada)
            return "Detención solicitada · se aplicará al terminar el lote actual"
        if (root.trainingController.pausaSolicitada)
            return "Pausa solicitada · se aplicará al terminar el lote actual"
        if (root.trainingController.estaPausado)
            return "Entrenamiento pausado"
        if (root.pasosSesionCompletados > 0) {
            var texto = "Época " + root.epocaSesionActual + " / "
                        + root.epocasSesionActual + " · lote " + root.loteActual
            if (root.lotesPorEpoca > 0)
                texto += " / " + root.lotesPorEpoca
            if (root.progresoDeterminado)
                texto += " · " + Math.round(root.progresoFraccion * 100) + "%"
            texto += " · transcurrido "
                     + root.formatearDuracion(root.tiempoTranscurridoSegundos)
            if (root.etaSegundos >= 0)
                texto += " · restante aprox. " + root.formatearDuracion(root.etaSegundos)
            return texto
        }
        if (root.trainingController.estaEntrenando)
            return "Preparando el primer lote…"
        if (root.entrenamientoTerminado)
            return root.fueCancelado ? "Entrenamiento detenido" : "Entrenamiento completado"
        return "Listo para iniciar"
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
        root.epocaSesionActual = Number(paso.epoca_sesion || 0)
        root.epocasSesionActual = Number(paso.epocas_sesion || root.epocasIniciales)
        root.loteActual = Number(paso.lote_actual || 0)
        root.lotesPorEpoca = paso.lotes_por_epoca !== undefined
                              && paso.lotes_por_epoca !== null
                              ? Number(paso.lotes_por_epoca) : 0
        root.pasosSesionCompletados = Number(paso.pasos_sesion_completados || 0)
        root.pasosSesionTotales = paso.pasos_sesion_totales !== undefined
                                  && paso.pasos_sesion_totales !== null
                                  ? Number(paso.pasos_sesion_totales) : 0
        root.progresoDeterminado = paso.progreso_fraccion !== undefined
                                    && paso.progreso_fraccion !== null
                                    && root.pasosSesionTotales > 0
        root.progresoFraccion = root.progresoDeterminado
                                ? Math.max(0, Math.min(1, Number(paso.progreso_fraccion)))
                                : 0
        root.tiempoTranscurridoSegundos = Number(
            paso.tiempo_transcurrido_segundos || 0
        )
        root.etaSegundos = paso.eta_segundos !== undefined
                           && paso.eta_segundos !== null
                           ? Number(paso.eta_segundos) : -1
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
        if (visualizacion.pedagogia && visualizacion.pedagogia.disponible)
            root.pedagogiaSnapshot = visualizacion.pedagogia

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
                root.teoriaActual = root.previewTheoryComponent(componentId)
                root.closeTheory()
                // El detalle vive en el panel principal para no cubrir ni
                // comprimir el mapa del Transformer.
                barraPestanas.currentIndex = 2
            }
        }

        function clearSelection() {
            selectedId = ""
            root.teoriaActual = ({})
            root.closeTheory()
            if (barraPestanas.currentIndex === 2)
                barraPestanas.currentIndex = 0
        }

        function showOverview() {
            clearSelection()
        }
    }

    Shortcut {
        sequence: "Esc"
        enabled: localBridge.selectedId !== "" && !root.theoryModalOpened
        onActivated: localBridge.clearSelection()
    }

    Component.onCompleted: {
        var info = root.viewModel.modeloActualInfo || {}
        localBridge.numCapas = Number(info.num_capas || 1)

        root.trainingController.activarNubeEmbeddings(false)
        root.trainingController.activarVisualizacionPedagogica(true)
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
            root.epocasCompletadas = resultado.epocas_sesion !== undefined
                                     && resultado.epocas_sesion !== null
                                     ? Number(resultado.epocas_sesion)
                                     : (resultado.epoca !== undefined && resultado.epoca !== null
                                        ? Number(resultado.epoca) + 1 : 0)
            root.pasosFinales = Number(resultado.paso_global || 0)
            if (resultado.progreso_fraccion !== undefined
                    && resultado.progreso_fraccion !== null) {
                root.progresoDeterminado = true
                root.progresoFraccion = Number(resultado.progreso_fraccion)
            } else {
                // Mientras corria no habia denominador, pero el evento final
                // si permite representar que la ejecucion ya concluyo.
                root.progresoDeterminado = true
                root.progresoFraccion = 1
            }
            root.fueCancelado = false
            root.entrenamientoTerminado = true
        }

        function onEntrenamiento_cancelado(resultado) {
            var historial = resultado.historial_perdidas || []
            root.historialFinal = historial
            root.perdidaFinalObtenida = historial.length > 0 ? historial[historial.length - 1] : 0
            root.epocasCompletadas = root.epocaSesionActual
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

    background: Rectangle {
        gradient: Gradient {
            GradientStop { position: 0; color: Style.Theme.fondo }
            GradientStop { position: 1; color: Style.Theme.fondo_gradiente }
        }
    }

    LaboratoryProgress {
        id: laboratoryProgress
        objectName: "trainingLaboratoryProgress"
        anchors.top: parent.top
        anchors.topMargin: 10 * root.sy
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, parent.width - 600 * root.sx)
        currentStep: 1
        sx: root.sx
        sy: root.sy
        compact: true
    }

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: laboratoryProgress.bottom
        anchors.topMargin: 6 * root.sy
        height: 60 * root.sy

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
                font.pixelSize: 23 * Math.min(root.sx, root.sy)
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
            height: 30 * root.sy
            radius: height / 2
            color: root.trainingController.estaEntrenando
                   ? (root.trainingController.estaPausado ? Style.Theme.aviso_fondo : Style.Theme.exito_fondo)
                   : Style.Theme.chip_fondo

            Text {
                id: estadoTexto
                anchors.centerIn: parent
                text: root.trainingController.detencionSolicitada
                      ? "● Deteniendo"
                      : (root.trainingController.pausaSolicitada
                         ? "● Pausa solicitada"
                         : (root.trainingController.estaEntrenando
                            ? (root.trainingController.estaPausado
                               ? "● Pausado" : "● Entrenando")
                            : (root.entrenamientoTerminado
                               ? "✓ Finalizado" : "○ Preparado")))
                color: root.trainingController.detencionSolicitada
                       ? Style.Theme.aviso_texto
                       : (root.trainingController.estaEntrenando
                          ? (root.trainingController.estaPausado
                             ? Style.Theme.aviso_texto : Style.Theme.exito_texto)
                          : Style.Theme.texto_secundario)
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
        anchors.bottomMargin: 14 * root.sy
        spacing: 18 * root.sx

        RectanglePrincipal {
            id: mapaCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 720 * root.sx
            sx: root.sx
            sy: root.sy

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12 * root.sx
                spacing: 7 * root.sy

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56 * root.sy
                    Layout.minimumHeight: 56 * root.sy
                    Layout.maximumHeight: 56 * root.sy
                    spacing: 10 * root.sx

                    Repeater {
                        model: [
                            {
                                label: "PROGRESO",
                                value: "Época " + (root.epocaSesionActual || 0) + " / "
                                       + (root.epocasSesionActual || root.epocasIniciales),
                                detail: "Paso global " + root.pasoGlobalActual,
                                color: Style.Theme.acento,
                                help: "epoch_batch"
                            },
                            {
                                label: "PÉRDIDA",
                                value: root.numero(root.perdidaActual, 4),
                                detail: "Cambio " + (root.deltaPerdida > 0 ? "+" : "")
                                        + root.numero(root.deltaPerdida, 4),
                                color: root.deltaPerdida <= 0
                                       ? Style.Theme.exito_texto : Style.Theme.aviso_texto,
                                help: "cross_entropy"
                            },
                            {
                                label: "GRADIENTE L2",
                                value: root.numero(root.normaGradiente, 3),
                                detail: "Intensidad de actualización",
                                color: Style.Theme.aviso_texto,
                                help: "gradient_norm_l2"
                            }
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
                                spacing: 1 * root.sy
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 1 * root.sx
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: summaryMetric.modelData.label
                                        color: Style.Theme.texto_secundario
                                        font.bold: true
                                        font.pixelSize: 10 * root.sx
                                    }
                                    ConceptHelpButton {
                                        anchors.verticalCenter: parent.verticalCenter
                                        objectName: "trainingMetricHelp_"
                                                    + summaryMetric.modelData.help
                                        conceptId: summaryMetric.modelData.help
                                        conceptLabel: summaryMetric.modelData.label
                                        controlSize: Math.max(18, 19 * Math.min(root.sx,
                                                                               root.sy))
                                        onHelpRequested: function(conceptId) {
                                            root.openTheoryConcept(conceptId)
                                        }
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: summaryMetric.modelData.value
                                    color: summaryMetric.modelData.color
                                    font.bold: true
                                    font.pixelSize: 16 * root.sx
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: summaryMetric.modelData.detail
                                    color: Style.Theme.texto_secundario
                                    font.pixelSize: 10 * root.sx
                                }
                            }

                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46 * root.sy
                    Layout.minimumHeight: 46 * root.sy
                    Layout.maximumHeight: 46 * root.sy
                    radius: 9 * root.sx
                    color: Style.Theme.aviso_fondo
                    border.color: Style.Theme.warning

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14 * root.sx
                        anchors.rightMargin: 14 * root.sx
                        spacing: 12 * root.sx

                        Rectangle {
                            Layout.preferredWidth: 34 * root.sx
                            Layout.preferredHeight: 34 * root.sy
                            radius: 17 * root.sx
                            color: Style.Theme.aviso_fondo
                            border.color: Style.Theme.warning
                            Text { anchors.centerIn: parent; text: "↗"; font.bold: true; color: Style.Theme.aviso_texto }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: "Lectura del batch · " + root.componenteRelevante
                                color: Style.Theme.aviso_texto
                                font.bold: true
                                font.pixelSize: 12 * root.sx
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.lecturaPerdida + " Intensidad RMS: " + root.numero(root.intensidadRelevante, 5)
                                color: Style.Theme.aviso_texto
                                elide: Text.ElideRight
                                font.pixelSize: 10 * root.sx
                            }
                        }
                        ConceptHelpButton {
                            objectName: "trainingLossHelpButton"
                            conceptId: "cross_entropy"
                            controlSize: Math.max(24, 28 * Math.min(root.sx, root.sy))
                            onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8 * root.sy

                        TabBar {
                            id: barraPestanas
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34 * root.sy
                            Layout.minimumHeight: 34 * root.sy
                            Layout.maximumHeight: 34 * root.sy
                            spacing: 6 * root.sx
                            background: Rectangle { color: "transparent" }

                            onCurrentIndexChanged: {
                                root.trainingController.activarNubeEmbeddings(barraPestanas.currentIndex === 1)
                                root.trainingController.activarVisualizacionPedagogica(barraPestanas.currentIndex === 0)
                            }

                            TabButton {
                                id: guidedTab
                                text: "Vista guiada"
                                background: Rectangle {
                                    radius: 7 * root.sx
                                    color: guidedTab.checked
                                           ? Style.Theme.acento_fondo
                                           : Style.Theme.superficie_alterna
                                    border.color: guidedTab.checked
                                                  ? Style.Theme.acento
                                                  : Style.Theme.borde_medio
                                }
                                contentItem: Text {
                                    text: guidedTab.text
                                    color: guidedTab.checked
                                           ? Style.Theme.acento_fuerte
                                           : Style.Theme.texto_secundario
                                    font.bold: guidedTab.checked
                                    font.pixelSize: 12 * root.sx
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            TabButton {
                                id: embeddingsTab
                                text: "Espacio de embeddings"
                                background: Rectangle {
                                    radius: 7 * root.sx
                                    color: embeddingsTab.checked
                                           ? Style.Theme.acento_fondo
                                           : Style.Theme.superficie_alterna
                                    border.color: embeddingsTab.checked
                                                  ? Style.Theme.acento
                                                  : Style.Theme.borde_medio
                                }
                                contentItem: Text {
                                    text: embeddingsTab.text
                                    color: embeddingsTab.checked
                                           ? Style.Theme.acento_fuerte
                                           : Style.Theme.texto_secundario
                                    font.bold: embeddingsTab.checked
                                    font.pixelSize: 12 * root.sx
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            TabButton {
                                id: componentDetailTab
                                objectName: "trainingComponentDetailTab"
                                text: localBridge.selectedId === ""
                                      ? "Detalle del bloque"
                                      : "Detalle seleccionado"
                                enabled: localBridge.selectedId !== ""
                                opacity: enabled ? 1 : 0.5
                                background: Rectangle {
                                    radius: 7 * root.sx
                                    color: componentDetailTab.checked
                                           ? Style.Theme.acento_fondo
                                           : Style.Theme.superficie_alterna
                                    border.color: componentDetailTab.checked
                                                  ? Style.Theme.acento
                                                  : Style.Theme.borde_medio
                                }
                                contentItem: Text {
                                    text: componentDetailTab.text
                                    color: componentDetailTab.checked
                                           ? Style.Theme.acento_fuerte
                                           : Style.Theme.texto_secundario
                                    font.bold: componentDetailTab.checked
                                    font.pixelSize: 12 * root.sx
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        Item {
                            id: trainingViewStack
                            objectName: "trainingViewStack"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            property int currentIndex: barraPestanas.currentIndex

                            TrainingJourney {
                                anchors.fill: parent
                                visible: barraPestanas.currentIndex === 0
                                snapshot: root.pedagogiaSnapshot
                                lossHistory: root.historialVisible
                                epoch: root.epocaSesionActual
                                batch: root.loteActual
                                globalStep: root.pasoGlobalActual
                                numLayers: localBridge.numCapas
                                numHeads: Number((root.viewModel.modeloActualInfo || {}).num_cabezas || 1)
                                gradientNorm: root.normaGradiente
                                sx: root.sx
                                sy: root.sy
                            }

                            NubeEmbeddings3D {
                                anchors.fill: parent
                                visible: barraPestanas.currentIndex === 1
                                puntos: root.nubeEmbeddings.puntos || []
                                etiquetas: root.nubeEmbeddings.etiquetas || []
                                varianzaConservada: Number(root.nubeEmbeddings.varianza_conservada || 0)
                                varianzaPorComponente: root.nubeEmbeddings.varianza_por_componente || []
                                modo: root.nubeEmbeddings.modo || "pca"
                                dimensiones: root.nubeEmbeddings.dimensiones || []
                                // Solo rota sola cuando la pestaña esta visible,
                                // para no repintar un Canvas que nadie ve.
                                rotacionAutomatica: barraPestanas.currentIndex === 1
                                onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            objectName: "trainingSidebar"
            Layout.preferredWidth: 400 * root.sx
            Layout.minimumWidth: 340 * root.sx
            Layout.fillHeight: true
            spacing: 12 * root.sy

            RectanglePrincipal {
                objectName: "trainingArchitectureCard"
                Layout.fillWidth: true
                Layout.fillHeight: true
                sx: root.sx
                sy: root.sy

                ColumnLayout {
                    id: mapaPanelLayout
                    anchors.fill: parent
                    anchors.margins: 12 * root.sx
                    spacing: 8 * root.sy

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6 * root.sx
                        Text {
                            Layout.fillWidth: true
                            text: "MAPA DE ARQUITECTURA"
                            color: Style.Theme.acento_fuerte
                            font.bold: true
                            font.pixelSize: 10 * root.sx
                        }
                        ConceptHelpButton {
                            objectName: "trainingMapHelpButton"
                            conceptId: "arquitectura_transformer"
                            controlSize: Math.max(22, 25 * Math.min(root.sx, root.sy))
                            onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Selecciona un bloque; su detalle aparecerá en el panel grande."
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 10 * root.sx
                        wrapMode: Text.WordWrap
                    }

                    TransformerDiagram {
                        id: mapaArquitectura
                        objectName: "trainingTransformerDiagram"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        bridge: localBridge
                        trainingMode: true
                        highlightedComponentId: root.componenteRelevanteId
                    }
                }

                ScrollView {
                    id: componentDetailsScroll
                    objectName: "trainingComponentDetailPanel"
                    parent: trainingViewStack
                    visible: barraPestanas.currentIndex === 2
                    anchors.fill: parent
                    anchors.margins: 8 * root.sx
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    Column {
                        width: componentDetailsScroll.availableWidth
                        spacing: 12 * root.sy

                        Rectangle {
                            visible: !root.componenteActual
                            width: parent.width
                            height: vacioLayout.implicitHeight + 30 * root.sy
                            radius: 9 * root.sx
                            color: Style.Theme.acento_fondo

                            Column {
                                id: vacioLayout
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: 16 * root.sx
                                spacing: 8 * root.sy
                                Text {
                                    width: parent.width
                                    text: "Tu ruta en esta pantalla"
                                    color: Style.Theme.acento_texto
                                    font.bold: true
                                    font.pixelSize: 14 * root.sx
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    width: parent.width
                                    text: "Avanza en este orden; no necesitas observar todo al mismo tiempo."
                                    color: Style.Theme.texto_secundario
                                    font.pixelSize: 11 * root.sx
                                    wrapMode: Text.WordWrap
                                }
                                Repeater {
                                    model: root.pasosSesionCompletados > 0
                                           ? [
                                               "Lee la pérdida y el gradiente del batch.",
                                               "Recorre un paso a la vez en la vista guiada.",
                                               "Abre Arquitectura para inspeccionar un bloque."
                                           ]
                                           : [
                                               "Inicia un batch y observa la pérdida.",
                                               "Recorre un paso a la vez en la vista guiada.",
                                               "Abre Arquitectura para inspeccionar un bloque."
                                           ]
                                    delegate: Row {
                                        id: guideStep
                                        required property int index
                                        required property var modelData
                                        width: vacioLayout.width
                                        height: Math.max(28 * root.sy, guideStepText.implicitHeight)
                                        spacing: 9 * root.sx
                                        Rectangle {
                                            width: 24 * root.sx
                                            height: 24 * root.sy
                                            radius: width / 2
                                            color: Style.Theme.surface
                                            border.color: Style.Theme.acento_alt
                                            Text {
                                                anchors.centerIn: parent
                                                text: guideStep.index + 1
                                                color: Style.Theme.acento_fuerte
                                                font.bold: true
                                                font.pixelSize: 11 * root.sx
                                            }
                                        }
                                        Text {
                                            id: guideStepText
                                            width: guideStep.width - 33 * root.sx
                                            text: guideStep.modelData
                                            color: Style.Theme.texto_secundario_fuerte
                                            font.pixelSize: 11 * root.sx
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }
                            }
                        }

                        ConceptSummary {
                            objectName: "trainingConceptSummary"
                            openButtonObjectName: "trainingOpenTheoryButton"
                            visible: root.componenteActual
                            width: parent.width
                            height: visible ? implicitHeight : 0
                            sx: root.sx
                            sy: root.sy
                            concepto: root.teoriaActual
                            onOpenRequested: root.mostrarTeoriaComponente(localBridge.selectedId)
                            onCloseRequested: localBridge.clearSelection()
                        }

                        RowLayout {
                            visible: root.componenteActual
                            width: parent.width
                            spacing: 6 * root.sx
                            Text {
                                text: "DATOS REALES · BATCH ACTUAL"
                                color: Style.Theme.exito_texto
                                font.bold: true
                                font.pixelSize: 11 * root.sx
                            }
                            ConceptHelpButton {
                                conceptId: "epoch_batch"
                                controlSize: Math.max(22, 25 * Math.min(root.sx, root.sy))
                                onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                            }
                        }

                        Repeater {
                            model: root.componenteActual ? root.componenteActual.metricas : []
                            delegate: Rectangle {
                                id: metricDelegate
                                required property var modelData
                                width: parent.width
                                height: metricaLayout.implicitHeight + 16 * root.sy
                                radius: 7 * root.sx
                                color: Style.Theme.superficie_alterna
                                border.color: Style.Theme.divisor

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
                                            color: Style.Theme.texto_terciario
                                            font.pixelSize: 9 * root.sx
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                    ConceptHelpButton {
                                        readonly property string resolvedConceptId:
                                            String(metricDelegate.modelData.concepto_id || "") !== ""
                                            ? String(metricDelegate.modelData.concepto_id)
                                            : root.conceptoParaMetrica(metricDelegate.modelData.etiqueta)
                                        visible: resolvedConceptId !== ""
                                        conceptId: resolvedConceptId
                                        controlSize: Math.max(22, 25 * Math.min(root.sx, root.sy))
                                        onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
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

                            RowLayout {
                                width: parent.width
                                spacing: 6 * root.sx
                                Text {
                                    text: "ATENCIÓN POR CAPA"
                                    color: Style.Theme.aviso_texto
                                    font.bold: true
                                    font.pixelSize: 11 * root.sx
                                }
                                ConceptHelpButton {
                                    conceptId: "interpretacion_pesos"
                                    controlSize: Math.max(22, 25 * Math.min(root.sx, root.sy))
                                    onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                                }
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
                                        color: Style.Theme.aviso_texto
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
                            color: Style.Theme.info_texto
                            font.pixelSize: 10 * root.sx
                            wrapMode: Text.WordWrap
                        }
                    }
                }

            }

            RectanglePrincipal {
                objectName: "trainingControlsCard"
                Layout.fillWidth: true
                Layout.preferredHeight: controlesEntrenamiento.implicitHeight + 24 * root.sy
                sx: root.sx
                sy: root.sy

                ColumnLayout {
                    id: controlesEntrenamiento
                    anchors.fill: parent
                    anchors.margins: 12 * root.sx
                    spacing: 8 * root.sy

                    Text {
                        Layout.fillWidth: true
                        text: "CONTROL DEL ENTRENAMIENTO"
                        color: Style.Theme.acento_fuerte
                        font.bold: true
                        font.pixelSize: 10 * root.sx
                        horizontalAlignment: Text.AlignHCenter
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6 * root.sx

                        BusyIndicator {
                            objectName: "trainingBatchBusyIndicator"
                            Layout.preferredWidth: 22 * root.sy
                            Layout.preferredHeight: 22 * root.sy
                            running: root.trainingController.estaEntrenando
                                     && (!root.trainingController.estaPausado
                                         || root.trainingController.pausaSolicitada
                                         || root.trainingController.detencionSolicitada)
                            visible: running
                        }

                        Text {
                            Layout.fillWidth: true
                            objectName: "trainingGlobalProgressText"
                            text: root.textoProgresoEntrenamiento
                            color: root.trainingController.detencionSolicitada
                                   ? Style.Theme.aviso_texto : Style.Theme.texto_secundario
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            font.pixelSize: 10 * root.sx
                            font.bold: root.trainingController.pausaSolicitada
                                       || root.trainingController.detencionSolicitada
                        }
                    }

                    ProgressBar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12 * root.sy
                        objectName: "trainingGlobalProgressBar"
                        from: 0
                        to: 1
                        value: root.progresoDeterminado ? root.progresoFraccion : 0
                        indeterminate: root.trainingController.estaEntrenando
                                       && !root.trainingController.estaPausado
                                       && !root.progresoDeterminado
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8 * root.sx

                        BotonPrincipal {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42 * root.sy
                            enabled: !root.trainingController.detencionSolicitada
                            opacity: enabled ? 1 : 0.45
                            text: !root.trainingController.estaEntrenando
                                  ? "▶ Iniciar"
                                  : (root.trainingController.estaPausado ? "▶ Reanudar" : "Ⅱ Pausar")
                            onClicked: {
                                var controlador = root.trainingController
                                if (!controlador.estaEntrenando) {
                                    root.mensajeError = ""
                                    root.entrenamientoTerminado = false
                                    root.reiniciarProgresoSesion()
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
                                     && !root.trainingController.detencionSolicitada
                            opacity: enabled ? 1 : 0.45
                            onClicked: root.trainingController.detener()
                        }
                    }

                    BotonSecundario {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32 * root.sy
                        sx: root.sx
                        sy: root.sy
                        text: root.advancedControlsVisible
                              ? "Ocultar ajustes ↑"
                              : "Ajustes de ejecución ↓"
                        onClicked: root.advancedControlsVisible = !root.advancedControlsVisible
                    }

                    RowLayout {
                        visible: root.advancedControlsVisible
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
                        visible: root.advancedControlsVisible
                        Layout.fillWidth: true
                        text: "Velocidad: " + root.etiquetaVelocidad
                              + (root.velocidadActual > 0
                                 ? "  ·  " + Math.round(root.velocidadActual * 1000) + " ms/paso"
                                 : "")
                        color: Style.Theme.texto_secundario
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 10 * root.sx
                    }

                    RowLayout {
                        visible: root.advancedControlsVisible
                        Layout.fillWidth: true
                        spacing: 5 * root.sx
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "LR " + root.tasaAprendizajeInicial.toFixed(4)
                                  + "  ·  Batch " + root.batchSizeInicial
                                  + "  ·  " + root.epocasIniciales + " épocas"
                            color: Style.Theme.texto_secundario
                            font.pixelSize: 10 * root.sx
                        }
                        ConceptHelpButton {
                            conceptId: "learning_rate"
                            controlSize: Math.max(21, 24 * Math.min(root.sx, root.sy))
                            onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                        }
                        ConceptHelpButton {
                            conceptId: "epoch_batch"
                            controlSize: Math.max(21, 24 * Math.min(root.sx, root.sy))
                            onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    Text {
                        visible: root.mensajeError !== "" || root.mensajeCheckpoint !== ""
                        Layout.fillWidth: true
                        text: root.mensajeError !== "" ? "⚠ " + root.mensajeError : "✓ " + root.mensajeCheckpoint
                        color: root.mensajeError !== "" ? Style.Theme.error_texto : Style.Theme.exito_texto
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
