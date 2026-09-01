
import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"
import QtQuick.Layouts

PagePrincipal {
    id: root
    objectName: "setupScreen"
    helpModalObjectName: "setupTheoryModal"
    helpPanelObjectName: "setupContextPanel"

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
    property var teoriaActual: ({})

    readonly property var configuracionActual: mainViewModel.setupController.configuracionActual
    readonly property string mensajeErrorVisible: root.mensajeError !== ""
                                                  ? root.mensajeError
                                                  : mainViewModel.setupController.errorConfiguracion

    property int epocas: 6
    property real tasaAprendizaje: 0.0003
    property int batchSize: 6
    property bool inicioEntrenamientoPendiente: false
    property var datasetsInicioPendientes: []

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

        function onErrorDataset(mensaje) {
            root.mensajeError = mensaje
        }
    }

    Connections {
        target: mainViewModel.setupController
        ignoreUnknownSignals: true

        function onResumen_cambio(resumen) {
            root.parametrosTotales = Number(resumen.parametros_totales || 0)
            root.memoriaEstimadaMb = Number(resumen.memoria_estimada_mb || 0)
        }

        function onError_configuracion(mensaje) {
            root.inicioEntrenamientoPendiente = false
        }
    }

    Component.onCompleted: {
        if (root.usarModeloActual && mainViewModel.modeloListo) {
            var infoActual = mainViewModel.modeloActualInfo
            root.parametrosTotales = Number(infoActual.parametros_totales || 0)
            root.memoriaEstimadaMb = Math.round(root.parametrosTotales * 4 / 1048576 * 10) / 10
            localBridge.numCapas = Number(infoActual.num_capas || 0)
        } else {
            localBridge.numCapas = Number(root.configuracionActual.num_capas || 1)
        }
    }

    // --- OBJETO PUENTE (BRIDGE) PARA EL DIAGRAMA ---
    // Guarda el ID del componente seleccionado en el TransformerDiagram
    QtObject {
        id: localBridge
        property string selectedId: ""
        property int numCapas: 6
        function selectComponent(id) {
            if (selectedId === id)
                clearSelection()
            else {
                selectedId = id
                root.teoriaActual = root.previewTheoryComponent(id)
                root.closeTheory()
            }
        }
        function clearSelection() {
            selectedId = ""
            root.teoriaActual = ({})
            root.closeTheory()
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
            objectName: "setupTransformerDiagram"
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

        ScrollView {
            id: panelScroll
            anchors.fill: parent
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                width: panelScroll.availableWidth
                spacing: 14 * sy

                ConceptSummary {
                    objectName: "setupConceptSummary"
                    openButtonObjectName: "setupOpenTheoryButton"
                    width: parent.width
                    height: visible ? implicitHeight : 0
                    visible: localBridge.selectedId !== ""
                    sx: root.sx
                    sy: root.sy
                    concepto: root.teoriaActual
                    onOpenRequested: root.mostrarTeoriaComponente(localBridge.selectedId)
                    onCloseRequested: localBridge.clearSelection()
                }

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
                        helpConceptId: "layer_count"
                        onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                        enabled: !root.usarModeloActual
                        opacity: enabled ? 1.0 : 0.55
                        from: 1
                        to: Math.max(12, Number(mainViewModel.modeloActualInfo.num_capas || 0))
                        stepSize: 1
                        value: root.usarModeloActual
                               ? Number(mainViewModel.modeloActualInfo.num_capas || 1)
                               : Number(root.configuracionActual.num_capas || 6)
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
                        helpConceptId: "d_model"
                        onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                        enabled: !root.usarModeloActual
                        opacity: enabled ? 1.0 : 0.55
                        from: 32
                        to: Math.max(512, Number(mainViewModel.modeloActualInfo.dimension_modelo || 0))
                        stepSize: 32
                        value: root.usarModeloActual
                               ? Number(mainViewModel.modeloActualInfo.dimension_modelo || 32)
                               : Number(root.configuracionActual.dimension_modelo || 64)
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
                        helpConceptId: "context_window"
                        onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                        enabled: !root.usarModeloActual
                        opacity: enabled ? 1.0 : 0.55
                        from: 16
                        to: Math.max(512, Number(mainViewModel.modeloActualInfo.longitud_maxima_secuencia || 0))
                        stepSize: 16
                        value: root.usarModeloActual
                               ? Number(mainViewModel.modeloActualInfo.longitud_maxima_secuencia || 16)
                               : Number(root.configuracionActual.longitud_maxima_secuencia || 64)
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
                        helpConceptId: "dimension_d_ff"
                        onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                        enabled: !root.usarModeloActual
                        opacity: enabled ? 1.0 : 0.55
                        from: 128
                        to: Math.max(2048, Number(mainViewModel.modeloActualInfo.dimension_ff || 0))
                        stepSize: 128
                        value: root.usarModeloActual
                               ? Number(mainViewModel.modeloActualInfo.dimension_ff || 128)
                               : Number(root.configuracionActual.dimension_ff || 256)
                        onValueChanged: {
                            if (!root.usarModeloActual)
                                mainViewModel.setupController.establecer_dimension_ff(value)
                        }
                    }

                    // --- Selector de Activación (Feed Forward) ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: localBridge.selectedId.indexOf("feed_forward") !== -1
                        spacing: 4 * root.sy

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6 * root.sx

                            Text {
                                Layout.fillWidth: true
                                text: "Función de Activación"
                                color: Style.Theme.texto_primario
                                font.pixelSize: 13 * root.sx
                            }
                            ConceptHelpButton {
                                conceptId: "activation_functions"
                                controlSize: Math.max(24, 27 * Math.min(root.sx, root.sy))
                                onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                            }
                        }

                        ComboBox {
                            id: comboActivacion
                            Layout.fillWidth: true
                            Layout.preferredHeight: 35 * root.sy
                            enabled: !root.usarModeloActual
                            opacity: enabled ? 1.0 : 0.55

                            model: ["relu", "gelu", "swish"]
                            currentIndex: Math.max(0, model.indexOf(String(
                                root.usarModeloActual
                                ? (mainViewModel.modeloActualInfo.activacion || "relu")
                                : (root.configuracionActual.activacion || "relu"))))

                            onActivated: {
                                if (!root.usarModeloActual) {
                                    mainViewModel.setupController.establecer_activacion(currentValue)
                                }
                            }
                        }
                    }

                    // --- Toggle de Máscara Causal (Masked Multi-Head Attention) ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: localBridge.selectedId.indexOf("masked") !== -1
                        spacing: 4 * root.sy

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "Máscara Causal"
                                color: Style.Theme.texto_primario
                                font.pixelSize: 13 * root.sx
                                Layout.fillWidth: true
                            }

                            ConceptHelpButton {
                                conceptId: "por_que_mascara"
                                controlSize: Math.max(24, 27 * Math.min(root.sx, root.sy))
                                onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                            }

                            Switch {
                                id: switchMascaraCausal
                                enabled: !root.usarModeloActual
                                opacity: enabled ? 1.0 : 0.55
                                checked: root.usarModeloActual
                                         ? (mainViewModel.modeloActualInfo.usar_mascara_causal !== false)
                                         : (root.configuracionActual.usar_mascara_causal !== false)
                                onToggled: {
                                    if (!root.usarModeloActual)
                                        mainViewModel.setupController.establecer_usar_mascara_causal(checked)
                                }
                            }
                        }

                        Text {
                            visible: !switchMascaraCausal.checked
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "Sin máscara causal el decoder puede ver tokens futuros. La pérdida "
                                + "bajará más rápido de lo normal (está copiando la respuesta), pero el "
                                + "texto generado será incoherente. Útil solo para experimentar."
                            color: "#E8A33D"
                            font.pixelSize: 11 * root.sx
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
                        helpConceptId: "cabeza_atencion"
                        onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                        enabled: !root.usarModeloActual
                        opacity: enabled ? 1.0 : 0.55
                        from: 1
                        to: Math.max(12, Number(mainViewModel.modeloActualInfo.num_cabezas || 0))
                        stepSize: 1
                        value: root.usarModeloActual
                               ? Number(mainViewModel.modeloActualInfo.num_cabezas || 1)
                               : Number(root.configuracionActual.num_cabezas || 4)
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
                        helpConceptId: "dropout"
                        onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                        enabled: !root.usarModeloActual
                        opacity: enabled ? 1.0 : 0.55
                        from: 0
                        to: Math.max(0.5, Number(mainViewModel.modeloActualInfo.dropout || 0))
                        stepSize: 0.05
                        value: root.usarModeloActual
                               ? Number(mainViewModel.modeloActualInfo.dropout || 0)
                               : Number(root.configuracionActual.dropout || 0.1)
                        tipo_dato: "decimal"
                        onValueChanged: {
                            if (!root.usarModeloActual)
                                mainViewModel.setupController.establecer_dropout(value)
                        }
                    }

                }
            }

                RectanglePrincipal {
                    id: rectanguloEntrenamiento
                    objectName: "trainingParametersCard"
                    width: parent.width
                    height: layoutEntrenamiento.implicitHeight + 30 * root.sy
                    sx: root.sx
                    sy: root.sy

                    ColumnLayout {
                        id: layoutEntrenamiento
                        anchors.fill: parent
                        anchors.margins: 15 * root.sx
                        spacing: 5 * root.sy

                        Text {
                            text: "Entrenamiento"
                            color: Style.Theme.texto_primario
                            font.pixelSize: 16 * root.sx
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                            Layout.bottomMargin: 8 * root.sy
                        }

                        SliderColumn {
                            Layout.fillWidth: true
                            sx: root.sx
                            sy: root.sy
                            text: "Épocas / iteraciones"
                            helpConceptId: "epoch_batch"
                            onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                            from: 1; to: 24; stepSize: 1; value: root.epocas
                            onValueChanged: root.epocas = value
                        }
                        SliderColumn {
                            Layout.fillWidth: true
                            sx: root.sx
                            sy: root.sy
                            text: "Learning Rate"
                            helpConceptId: "learning_rate"
                            onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                            from: 0; to: 0.01; stepSize: 0.0001
                            value: root.tasaAprendizaje
                            tipo_dato: "decimal"
                            onValueChanged: root.tasaAprendizaje = value
                        }
                        SliderColumn {
                            Layout.fillWidth: true
                            sx: root.sx
                            sy: root.sy
                            text: "Batch Size"
                            helpConceptId: "epoch_batch"
                            onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                            from: 1; to: 24; stepSize: 1; value: root.batchSize
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

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6 * root.sx

                        Text {
                            text: "Parámetros: " + root.parametrosTotales.toLocaleString()
                                + "  (~" + root.memoriaEstimadaMb + " MB)"
                            color: Style.Theme.texto_primario
                            font.pixelSize: 14 * root.sx
                        }
                        ConceptHelpButton {
                            conceptId: "parameter_count"
                            controlSize: Math.max(24, 27 * Math.min(root.sx, root.sy))
                            onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: root.mensajeErrorVisible !== ""
                        text: root.mensajeErrorVisible
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
                enabled: root.usarModeloActual || mainViewModel.setupController.configuracionValida
                opacity: enabled ? 1.0 : 0.5

                onClicked: {
                    root.mensajeError = ""

                    if (!root.usarModeloActual
                            && !mainViewModel.setupController.configuracionValida)
                        return

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

                Item {
                    width: 1
                    height: 12 * root.sy
                }
            }
        }
    }
}
