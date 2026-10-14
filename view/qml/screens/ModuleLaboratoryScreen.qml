pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "../styles" as Style
import "../components"
import "../components/ValueKinds.js" as ValueKinds

PagePrincipal {
    id: root
    objectName: "moduleLaboratoryScreen"

    property string moduleId: "module_1"
    readonly property var courseController: mainViewModel.courseController
    readonly property var laboratoryController: mainViewModel.moduleLaboratoryController
    readonly property var modelLibraryController: mainViewModel.modelLibraryController
    // Solo cuenta modelos que la biblioteca puede cargar: si todos son
    // incompatibles, ofrecer «usar uno guardado» llevaría a tarjetas con los
    // botones deshabilitados, que es otro callejón sin salida.
    readonly property bool hasSavedModels: {
        var models = root.modelLibraryController
                     ? (root.modelLibraryController.modelos || []) : []
        for (var i = 0; i < models.length; ++i) {
            if (models[i] && models[i].compatible !== false)
                return true
        }
        return false
    }
    readonly property var moduleData: courseController.currentModule
    readonly property var laboratory: moduleData.laboratory || ({})
    readonly property var analysis: laboratoryController.result || ({})
    readonly property var steps: analysis.steps || []
    readonly property var tokens: analysis.tokens || []
    readonly property real uiScale: Math.max(0.82, Math.min(1.08,
                                                           Math.min(root.sx,
                                                                    root.sy)))
    // Tres modos evitan el salto brusco de tres columnas a una sola. En el
    // modo medio, los pasos ocupan la primera fila y la visualización conserva
    // todo el ancho. La explicación se mantiene en su propia ventana.
    readonly property bool wideLayout: root.width >= 1460
    readonly property bool mediumLayout: root.width >= 1120 && !root.wideLayout
    readonly property bool narrowLayout: root.width < 1120
    readonly property bool compactLayout: !root.wideLayout
    readonly property bool narrowControls: root.width < 760
    readonly property real workspacePreferredHeight: root.wideLayout
                                                    ? 590 * root.uiScale
                                                    : (root.mediumLayout
                                                       ? 832 * root.uiScale
                                                       : 1112 * root.uiScale)
    readonly property int safeStepIndex: Math.max(
        0, Math.min(root.currentStepIndex, Math.max(0, root.steps.length - 1)))
    readonly property var currentStep: {
        if (root.steps.length === 0)
            return ({})
        var candidate = root.steps[root.safeStepIndex]
        return candidate && typeof candidate === "object" ? candidate : ({})
    }
    readonly property var currentPanel: root.panelForKey(
                                            String(root.currentStep.panel_key || ""))
    readonly property int modelLayerCount: Math.max(
        1, Number((mainViewModel.modeloActualInfo || {}).num_capas || 1))
    readonly property int modelHeadCount: Math.max(
        1, Number((mainViewModel.modeloActualInfo || {}).num_cabezas || 1))
    readonly property var currentFormulaDemo: {
        var demos = root.analysis.formula_demos || ({})
        var demo = demos[String(root.currentStep.id || "")]
        return demo && typeof demo === "object" ? demo : ({})
    }
    readonly property bool advancedMode: root.learningLevel === "advanced"
    readonly property real laboratoryProgress: root.steps.length > 0
                                               ? (root.safeStepIndex + 1) / root.steps.length
                                               : 0
    readonly property int minutesPerOperation: root.advancedMode ? 3 : 2
    readonly property int estimatedMinutes: Math.max(
        1, root.steps.length * root.minutesPerOperation)
    readonly property int remainingMinutes: Math.max(
        0, (root.steps.length - root.safeStepIndex - 1) * root.minutesPerOperation)
    readonly property var overviewGroups: root.groupsForModule()
    readonly property string activeGroupId: root.groupForStep(
                                                       String(root.currentStep.id || ""))

    property string mode: "inference"
    property string learningLevel: "essential"
    // Una sola fuente de atención por vez: vista del componente, fórmula
    // animada o explicación. El contenido completo sigue disponible.
    property int workspaceSection: 1
    property int currentStepIndex: 0
    property bool playing: false
    property string errorMessage: ""
    property string inspectedKey: ""
    property string inspectedTitle: ""
    property var inspectedPanel: ({})
    property int valueOffset: 0
    property var pageValues: []
    // La explicación vive aparte para que la animación nunca pierda espacio.
    property bool guideDetached: false

    function panelForKey(key) {
        var panels = root.analysis.panels || []
        if (key !== "") {
            for (var index = 0; index < panels.length; ++index) {
                if (String(panels[index].key) === key)
                    return panels[index]
            }
        }
        return panels.length > 0 ? panels[Math.min(root.safeStepIndex,
                                                    panels.length - 1)] : ({})
    }

    function runAnalysis() {
        root.errorMessage = ""
        root.playing = false
        root.currentStepIndex = 0
        root.workspaceSection = 1
        root.laboratoryController.explore(
            root.moduleId, inputText.text, root.mode,
            Math.round(layerSlider.value), Math.round(headSlider.value),
            Math.round(tokenSlider.value), temperatureSlider.value,
            Math.round(topKSlider.value), topPSlider.value,
            causalSwitch.checked)
    }

    function chooseMode(nextMode) {
        if (root.mode === nextMode)
            return
        root.mode = nextMode
        root.currentStepIndex = 0
        root.workspaceSection = 1
        root.playing = false
        if (root.laboratoryController.modelReady
                && inputText.text.trim().length > 0)
            root.runAnalysis()
    }

    function previousStep() {
        root.playing = false
        root.currentStepIndex = Math.max(0, root.currentStepIndex - 1)
    }

    function nextStep() {
        root.playing = false
        root.currentStepIndex = Math.min(Math.max(0, root.steps.length - 1),
                                         root.currentStepIndex + 1)
    }

    function restartSteps() {
        root.playing = false
        root.currentStepIndex = 0
    }

    function togglePlayback() {
        if (root.steps.length < 2)
            return
        if (root.currentStepIndex >= root.steps.length - 1)
            root.currentStepIndex = 0
        root.playing = !root.playing
    }

    function showFormulaPane() {
        root.workspaceSection = 1
        formulaScene.replay()
    }

    function chooseLearningLevel(level) {
        root.learningLevel = level === "advanced" ? "advanced" : "essential"
        if (!root.advancedMode) {
            if (animationGuide.selectedSection === 3)
                animationGuide.selectedSection = 0
            if (root.guideDetached)
                root.closeDetachedGuide()
        }
    }

    function groupsForModule() {
        if (root.moduleId === "module_6")
            return [
                { id: "prepare", label: "Preparar prefijo", steps: ["decoder_prefix", "decoder_embedding"] },
                { id: "causal", label: "Atención causal", steps: ["causal_mask", "masked_attention", "decoder_residual_1"] },
                { id: "source", label: "Consultar encoder", steps: ["cross_attention", "decoder_residual_2"] },
                { id: "transform", label: "Transformar salida", steps: ["decoder_ffn", "decoder_output", "decoder_layers"] },
                { id: "learn", label: "Aprender", steps: ["backward", "update"] }
            ]
        if (root.moduleId === "module_8")
            return [
                { id: "prepare", label: "Preparar entrada", steps: ["full_tokens", "full_batch", "full_embedding"] },
                { id: "encode", label: "Codificar", steps: ["full_encoder"] },
                { id: "decode", label: "Decodificar", steps: ["full_decoder"] },
                { id: "generate", label: "Generar", steps: ["full_logits", "full_filters", "full_select", "full_feedback"] },
                { id: "learn", label: "Aprender", steps: ["full_loss", "full_backward", "full_update"] }
            ]
        return []
    }

    function groupForStep(stepId) {
        for (var groupIndex = 0; groupIndex < root.overviewGroups.length; ++groupIndex) {
            var group = root.overviewGroups[groupIndex]
            if ((group.steps || []).indexOf(stepId) !== -1)
                return String(group.id)
        }
        return ""
    }

    function goToGroup(group) {
        var ids = group && group.steps ? group.steps : []
        for (var index = 0; index < root.steps.length; ++index) {
            if (ids.indexOf(String(root.steps[index].id || "")) !== -1) {
                root.playing = false
                root.currentStepIndex = index
                root.workspaceSection = 1
                return
            }
        }
    }

    function toggleGuide() {
        if (root.guideDetached)
            root.closeDetachedGuide()
        else
            root.detachGuide()
    }

    function detachGuide() {
        root.guideDetached = true
        root.playing = false
        Qt.callLater(function() {
            detachedGuideWindow.raise()
            detachedGuideWindow.requestActivate()
        })
    }

    function closeDetachedGuide() {
        root.guideDetached = false
    }

    function openValues(panel) {
        if (!panel || !panel.key)
            return
        root.inspectedPanel = panel
        root.inspectedKey = String(panel.key)
        root.inspectedTitle = String(panel.title || "Valores")
        root.valueOffset = 0
        root.loadValuePage()
        valuesDialog.open()
    }

    function loadValuePage() {
        root.pageValues = root.laboratoryController.fullValues(
            root.inspectedKey, root.valueOffset, 128)
    }

    function valueCoordinate(localIndex) {
        var absoluteIndex = root.valueOffset + Number(localIndex)
        var shape = root.inspectedPanel.shape || []
        if (shape.length === 2 && Number(shape[1]) > 0) {
            var columns = Number(shape[1])
            return "F" + (Math.floor(absoluteIndex / columns) + 1)
                    + " · C" + (absoluteIndex % columns + 1)
        }
        return "Índice " + absoluteIndex
    }

    // `kind` es el value_kind del panel (ValueKinds.js). Un id va como entero
    // y antes que la notación científica (si no, 100278 salía 1.0028e+5); un
    // valor continuo conserva sus decimales aunque sea un entero exacto.
    function formattedValue(value, kind) {
        if (typeof value === "boolean")
            return value ? "True" : "False"
        var numeric = Number(value)
        if (!Number.isFinite(numeric))
            return String(value)
        if (ValueKinds.isDiscrete(kind) && Number.isInteger(numeric))
            return String(numeric)
        var absolute = Math.abs(numeric)
        if (absolute !== 0 && (absolute >= 1000 || absolute < 0.0001))
            return numeric.toExponential(4)
        return numeric.toFixed(6)
    }

    Component.onCompleted: {
        root.courseController.selectModule(root.moduleId)
        // El catálogo pudo cambiar desde que se construyó el controlador; sin
        // releerlo, el botón de modelos guardados podría quedar oculto aunque
        // existan, que es justo el síntoma que este botón resuelve.
        if (root.modelLibraryController)
            root.modelLibraryController.refrescar()
    }
    onVisibleChanged: if (!visible && guideDetached) closeDetachedGuide()

    Connections {
        target: root.laboratoryController
        function onError(message) {
            root.errorMessage = message
            root.playing = false
        }
        function onAnalysisCompleted(completedModuleId) {
            if (completedModuleId === root.moduleId) {
                root.currentStepIndex = 0
                root.playing = false
            }
        }
    }

    Timer {
        // En reproducción automática cada paso espera a que termine su
        // animación de fórmula para que se alcance a leer el cálculo.
        interval: root.workspaceSection === 1
                  ? Math.max(1700, formulaScene.cycleDuration + 900) : 1700
        repeat: true
        running: root.playing
        onTriggered: {
            if (root.currentStepIndex >= root.steps.length - 1) {
                root.playing = false
                return
            }
            root.currentStepIndex += 1
        }
    }

    ScrollView {
        id: pageScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            width: pageScroll.availableWidth
            spacing: 14 * root.uiScale

            Item { Layout.fillWidth: true; Layout.preferredHeight: 10 * root.uiScale }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24 * root.uiScale
                // La ventana principal mantiene el indicador de vista dual y
                // el botón de preferencias sobre la esquina superior derecha:
                // 150 + 8 + 34 + 12 = 204 en el peor caso (vista dual
                // visible), más 4 de holgura.
                Layout.rightMargin: 208 * root.uiScale
                spacing: 14 * root.uiScale

                BotonPrincipal {
                    Layout.preferredWidth: 150 * root.uiScale
                    Layout.preferredHeight: 40 * root.uiScale
                    text: "← Módulo"
                    onClicked: root.stackView.pop()
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 1
                    Text {
                        Layout.fillWidth: true
                        text: "LABORATORIO ESPECIALIZADO · MÓDULO "
                              + (root.moduleData.order || "")
                        color: Style.Theme.acento_fuerte
                        font.bold: true
                        font.pixelSize: 10 * root.uiScale
                        font.letterSpacing: 0.7
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.laboratory.title || "Laboratorio"
                        color: Style.Theme.texto_primario
                        font.bold: true
                        font.pixelSize: 24 * root.uiScale
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: !root.compactLayout
                        text: root.laboratory.description || ""
                        color: Style.Theme.texto_secundario_fuerte
                        font.pixelSize: 11 * root.uiScale
                        elide: Text.ElideRight
                    }
                }
                Rectangle {
                    objectName: "moduleLaboratoryModelStatus"
                    visible: !root.narrowLayout
                    Layout.preferredWidth: 150 * root.uiScale
                    Layout.preferredHeight: 36 * root.uiScale
                    radius: height / 2
                    color: root.laboratoryController.modelReady
                           ? Style.Theme.exito_fondo : Style.Theme.aviso_fondo
                    border.color: root.laboratoryController.modelReady
                                  ? Style.Theme.success : Style.Theme.warning
                    Text {
                        anchors.centerIn: parent
                        text: root.laboratoryController.modelReady
                              ? "● Modelo activo" : "○ Falta un modelo"
                        color: root.laboratoryController.modelReady
                               ? Style.Theme.exito_texto : Style.Theme.aviso_texto
                        font.bold: true
                        font.pixelSize: 10 * root.uiScale
                    }
                }
            }

            RectanglePrincipal {
                Layout.fillWidth: true
                Layout.leftMargin: 24 * root.uiScale
                Layout.rightMargin: 24 * root.uiScale
                Layout.preferredHeight: controlLayout.implicitHeight + 24 * root.uiScale
                sx: root.uiScale
                sy: root.uiScale

                ColumnLayout {
                    id: controlLayout
                    anchors.fill: parent
                    anchors.margins: 12 * root.uiScale
                    spacing: 10 * root.uiScale

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8 * root.uiScale

                        TabBar {
                            id: learningLevelTabs
                            objectName: "moduleLaboratoryLearningLevelTabs"
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredHeight: 44 * root.uiScale
                            currentIndex: root.advancedMode ? 1 : 0
                            spacing: 4 * root.uiScale
                            Accessible.name: "Nivel de detalle del laboratorio"
                            background: Rectangle {
                                radius: 9 * root.uiScale
                                color: Style.Theme.superficie_alterna
                                border.color: Style.Theme.borde_suave
                            }
                            PestanaAccesible {
                                objectName: "moduleLaboratoryEssentialLevel"
                                text: "Esencial para clase"
                                onClicked: root.chooseLearningLevel("essential")
                            }
                            PestanaAccesible {
                                objectName: "moduleLaboratoryAdvancedLevel"
                                text: "Exploración avanzada"
                                onClicked: root.chooseLearningLevel("advanced")
                            }
                        }

                        Rectangle {
                            objectName: "moduleLaboratoryLearningLevelSummaryCard"
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredHeight: Math.max(
                                                        44 * root.uiScale,
                                                        learningLevelSummary.implicitHeight
                                                        + 16 * root.uiScale)
                            radius: 9 * root.uiScale
                            color: root.advancedMode
                                   ? Style.Theme.formula_fondo
                                   : Style.Theme.exito_fondo
                            border.color: root.advancedMode
                                          ? Style.Theme.formula_texto
                                          : Style.Theme.success
                            Text {
                                id: learningLevelSummary
                                objectName: "moduleLaboratoryLearningLevelSummary"
                                anchors.fill: parent
                                anchors.margins: 8 * root.uiScale
                                text: root.advancedMode
                                      ? "Todos los controles, matrices y gradientes · ~"
                                        + root.estimatedMinutes + " min"
                                      : "Ruta guiada con una operación a la vez · ~"
                                        + root.estimatedMinutes + " min"
                                color: root.advancedMode
                                       ? Style.Theme.formula_texto
                                       : Style.Theme.exito_texto
                                font.pixelSize: Math.max(10, 11 * root.uiScale)
                                font.bold: true
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.narrowControls ? 1 : 2
                        columnSpacing: 10 * root.uiScale
                        rowSpacing: 10 * root.uiScale
                        TabBar {
                            id: modeTabs
                            objectName: "moduleLaboratoryModeTabs"
                            Layout.fillWidth: root.narrowControls
                            Layout.preferredWidth: root.narrowControls
                                                   ? 0 : 330 * root.uiScale
                            Layout.preferredHeight: 42 * root.uiScale
                            Layout.fillHeight: true
                            currentIndex: root.mode === "training" ? 0 : 1
                            background: Rectangle {
                                radius: 9 * root.uiScale
                                color: Style.Theme.superficie_alterna
                                border.color: Style.Theme.borde_suave
                            }
                            PestanaAccesible {
                                objectName: "moduleLaboratoryTrainingMode"
                                text: "Entrenamiento"
                                onClicked: root.chooseMode("training")
                            }
                            PestanaAccesible {
                                objectName: "moduleLaboratoryInferenceMode"
                                text: "Inferencia"
                                onClicked: root.chooseMode("inference")
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredHeight: Math.max(
                                                        42 * root.uiScale,
                                                        modeSummary.implicitHeight
                                                        + 16 * root.uiScale)
                            radius: 9 * root.uiScale
                            color: root.mode === "training"
                                   ? Style.Theme.aviso_fondo : Style.Theme.info_fondo
                            Text {
                                id: modeSummary
                                objectName: "moduleLaboratoryModeSummary"
                                anchors.fill: parent
                                anchors.margins: 8 * root.uiScale
                                text: root.mode === "training"
                                      ? "Forward + pérdida + gradientes reales · sin alterar los pesos"
                                      : "Forward real con parámetros fijos · observa cómo se usa lo aprendido"
                                color: root.mode === "training"
                                       ? Style.Theme.aviso_texto : Style.Theme.info_texto
                                font.pixelSize: 10 * root.uiScale
                                font.bold: true
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        // Una columna por control visible: los ocultos no ocupan
                        // celda, y con una de menos el último botón baja de fila.
                        columns: root.narrowControls
                                 ? 1 : (root.laboratoryController.modelReady
                                        ? 2 : (root.hasSavedModels ? 4 : 3))
                        columnSpacing: 10 * root.uiScale
                        rowSpacing: 10 * root.uiScale
                        CampoTextoPrincipal {
                            id: inputText
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredHeight: 42 * root.uiScale
                            sx: root.uiScale; sy: root.uiScale
                            text: "La atención conecta cada token con su contexto."
                            placeholderText: "Escribe un texto para inspeccionarlo"
                            onAccepted: if (analyzeButton.enabled) root.runAnalysis()
                        }
                        BotonPrincipal {
                            id: analyzeButton
                            objectName: "moduleLaboratoryAnalyzeButton"
                            Layout.fillWidth: root.narrowControls
                            Layout.preferredWidth: root.narrowControls
                                                   ? 0 : 185 * root.uiScale
                            Layout.preferredHeight: 42 * root.uiScale
                            text: root.analysis.module_id === root.moduleId
                                  ? "Actualizar experimento" : "Ejecutar experimento"
                            enabled: root.laboratoryController.modelReady
                                     && inputText.text.trim().length > 0
                            opacity: enabled ? 1 : 0.45
                            onClicked: root.runAnalysis()
                        }
                        BotonPrincipal {
                            objectName: "moduleLaboratoryCreateModelButton"
                            visible: !root.laboratoryController.modelReady
                            Layout.fillWidth: root.narrowControls
                            Layout.preferredWidth: root.narrowControls
                                                   ? 0 : 135 * root.uiScale
                            Layout.preferredHeight: 42 * root.uiScale
                            text: "Crear modelo"
                            onClicked: root.stackView.push(
                                "SetupScreen.qml", {
                                    "stackView": root.stackView,
                                    "regresarAlLaboratorio": true,
                                    "moduloRetornoLaboratorio": root.moduleId,
                                    "modoRetornoLaboratorio": root.mode
                                })
                        }
                        BotonPrincipal {
                            objectName: "moduleLaboratoryLoadModelButton"
                            // Sin modelos guardados la biblioteca estaría vacía:
                            // se oculta en vez de llevar a una pantalla sin salida.
                            visible: !root.laboratoryController.modelReady
                                     && root.hasSavedModels
                            Layout.fillWidth: root.narrowControls
                            Layout.preferredWidth: root.narrowControls
                                                   ? 0 : 185 * root.uiScale
                            Layout.preferredHeight: 42 * root.uiScale
                            text: "Usar modelo guardado"
                            onClicked: root.stackView.push(
                                "ModelLibraryScreen.qml", {
                                    "stackView": root.stackView,
                                    "regresarAlLaboratorio": true,
                                    "moduloRetornoLaboratorio": root.moduleId,
                                    "modoRetornoLaboratorio": root.mode
                                })
                        }
                    }

                    GridLayout {
                        objectName: "moduleLaboratoryAdvancedControls"
                        Layout.fillWidth: true
                        visible: root.advancedMode && root.moduleId !== "module_1"
                        columns: root.narrowLayout ? 2 : 5
                        columnSpacing: 14 * root.uiScale
                        rowSpacing: 6 * root.uiScale

                        LaboratorySlider {
                            id: layerSlider
                            objectName: "moduleLaboratoryLayerControl"
                            visible: ["module_3", "module_4", "module_5", "module_6", "module_8"]
                                     .indexOf(root.moduleId) !== -1
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            title: "Capa"
                            from: 0
                            to: root.modelLayerCount - 1
                            stepSize: 1
                            value: 0
                            displayOffset: 1
                            accent: Style.Theme.inferencia_contexto
                            sx: root.uiScale; sy: root.uiScale
                        }
                        LaboratorySlider {
                            id: headSlider
                            objectName: "moduleLaboratoryHeadControl"
                            visible: ["module_3", "module_4", "module_5", "module_6", "module_8"]
                                     .indexOf(root.moduleId) !== -1
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            title: "Cabeza"
                            from: 0
                            to: root.modelHeadCount - 1
                            stepSize: 1
                            value: 0
                            displayOffset: 1
                            accent: Style.Theme.matriz_query
                            sx: root.uiScale; sy: root.uiScale
                        }
                        LaboratorySlider {
                            id: tokenSlider
                            objectName: "moduleLaboratoryTokenControl"
                            visible: ["module_2", "module_3", "module_4", "module_5",
                                      "module_6", "module_7", "module_8"]
                                     .indexOf(root.moduleId) !== -1
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            title: root.moduleId === "module_7" ? "Posición" : "Token"
                            from: 0
                            to: Math.max(0, root.tokens.length - 1)
                            stepSize: 1
                            value: 0
                            displayOffset: 1
                            accent: Style.Theme.inferencia_foco
                            sx: root.uiScale; sy: root.uiScale
                        }
                        LaboratoryToggle {
                            id: causalSwitch
                            objectName: "moduleLaboratoryCausalControl"
                            visible: ["module_6", "module_8"].indexOf(root.moduleId) !== -1
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            title: "Máscara causal"
                            checked: true
                            checkedText: "Futuro bloqueado"
                            uncheckedText: "Contraste sin máscara"
                            accent: Style.Theme.inferencia_error
                            sx: root.uiScale; sy: root.uiScale
                        }
                        LaboratorySlider {
                            id: temperatureSlider
                            objectName: "moduleLaboratoryTemperatureControl"
                            visible: ["module_7", "module_8"].indexOf(root.moduleId) !== -1
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            title: "Temperatura"
                            from: 0.1
                            to: 2.0
                            value: 1.0
                            stepSize: 0.05
                            decimals: 2
                            accent: Style.Theme.inferencia_transformacion
                            sx: root.uiScale; sy: root.uiScale
                        }
                        LaboratorySlider {
                            id: topKSlider
                            objectName: "moduleLaboratoryTopKControl"
                            visible: ["module_7", "module_8"].indexOf(root.moduleId) !== -1
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            title: "Top-K"
                            from: 1
                            to: 100
                            value: 20
                            stepSize: 1
                            accent: Style.Theme.inferencia_contexto
                            sx: root.uiScale; sy: root.uiScale
                        }
                        LaboratorySlider {
                            id: topPSlider
                            objectName: "moduleLaboratoryTopPControl"
                            visible: ["module_7", "module_8"].indexOf(root.moduleId) !== -1
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            title: "Top-P"
                            from: 0.05
                            to: 1.0
                            value: 0.9
                            stepSize: 0.01
                            decimals: 2
                            accent: Style.Theme.inferencia_resultado
                            sx: root.uiScale; sy: root.uiScale
                        }
                    }
                }
            }

            Text {
                visible: root.errorMessage.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: 26 * root.uiScale
                Layout.rightMargin: 26 * root.uiScale
                text: "⚠ " + root.errorMessage
                color: Style.Theme.error_texto
                wrapMode: Text.WrapAnywhere
                font.pixelSize: 11 * root.uiScale
            }

            ListView {
                id: tokenStrip
                objectName: "moduleLaboratoryTokenStrip"
                visible: root.advancedMode && root.tokens.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: 24 * root.uiScale
                Layout.rightMargin: 24 * root.uiScale
                Layout.preferredHeight: 42 * root.uiScale
                orientation: ListView.Horizontal
                spacing: 6 * root.uiScale
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.tokens
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Rectangle {
                    id: tokenChip
                    required property int index
                    required property var modelData
                    width: Math.max(62 * root.uiScale,
                                    tokenLabel.implicitWidth + 18 * root.uiScale)
                    height: 34 * root.uiScale
                    radius: 8 * root.uiScale
                    color: Number(root.analysis.selected_token_index || 0) === index
                           ? Style.Theme.acento_fondo : Style.Theme.chip_fondo
                    border.color: Number(root.analysis.selected_token_index || 0) === index
                                  ? Style.Theme.acento : Style.Theme.chip_borde
                    Text {
                        id: tokenLabel
                        anchors.centerIn: parent
                        text: tokenChip.modelData.text + " · " + tokenChip.modelData.id
                        color: Style.Theme.chip_texto
                        font.family: Style.Theme.fuente_mono
                        font.pixelSize: 9 * root.uiScale
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            tokenSlider.value = tokenChip.index
                            if (root.laboratoryController.modelReady)
                                root.runAnalysis()
                        }
                    }
                }
            }

            Rectangle {
                visible: root.analysis.module_id !== root.moduleId
                Layout.fillWidth: true
                Layout.leftMargin: 24 * root.uiScale
                Layout.rightMargin: 24 * root.uiScale
                Layout.preferredHeight: 290 * root.uiScale
                radius: 14 * root.uiScale
                color: Style.Theme.surface
                border.color: Style.Theme.borde_suave
                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 40 * root.uiScale,
                                    620 * root.uiScale)
                    spacing: 12 * root.uiScale
                    Text { Layout.alignment: Qt.AlignHCenter; text: root.laboratoryController.modelReady ? "⌁" : "◇"; color: Style.Theme.acento; font.pixelSize: 36 * root.uiScale; font.bold: true }
                    Text {
                        Layout.fillWidth: true
                        text: root.laboratoryController.modelReady
                              ? "Explora este componente con datos reales"
                              : (root.hasSavedModels
                                 ? "Primero crea o carga un modelo"
                                 : "Primero crea un modelo")
                        color: Style.Theme.texto_primario
                        font.pixelSize: 20 * root.uiScale
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.laboratoryController.modelReady
                              ? "El experimento seguirá las operaciones internas del módulo, paso a paso. Podrás inspeccionar matrices, dimensiones y gradientes sin modificar el modelo."
                              : "El laboratorio necesita los pesos y dimensiones de un Transformer activo para mostrar cálculos auténticos."
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 11 * root.uiScale
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }

            RectanglePrincipal {
                objectName: "moduleLaboratoryProgressCard"
                visible: root.analysis.module_id === root.moduleId
                Layout.fillWidth: true
                Layout.leftMargin: 24 * root.uiScale
                Layout.rightMargin: 24 * root.uiScale
                Layout.preferredHeight: progressColumn.implicitHeight + 18 * root.uiScale
                sx: root.uiScale
                sy: root.uiScale

                ColumnLayout {
                    id: progressColumn
                    anchors.fill: parent
                    anchors.margins: 9 * root.uiScale
                    spacing: 6 * root.uiScale

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10 * root.uiScale
                        Text {
                            Layout.fillWidth: true
                            text: "OPERACIÓN " + (root.safeStepIndex + 1) + " DE "
                                  + root.steps.length + "  ·  "
                                  + String(root.currentStep.title || "Paso actual")
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: Math.max(11, 12 * root.uiScale)
                            elide: Text.ElideRight
                        }
                        Text {
                            text: root.remainingMinutes > 0
                                  ? "~" + root.remainingMinutes + " min restantes"
                                  : "Última operación"
                            color: Style.Theme.acento_fuerte
                            font.bold: true
                            font.pixelSize: Math.max(10, 11 * root.uiScale)
                        }
                    }

                    ProgressBar {
                        objectName: "moduleLaboratoryProgress"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 7 * root.uiScale
                        from: 0
                        to: 1
                        value: root.laboratoryProgress
                        Accessible.name: "Progreso del laboratorio"
                        Accessible.description: Math.round(root.laboratoryProgress * 100)
                                                + " por ciento"
                    }

                    Flickable {
                        objectName: "moduleLaboratoryOverviewMap"
                        visible: !root.advancedMode && root.overviewGroups.length > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? 34 * root.uiScale : 0
                        contentWidth: overviewRow.implicitWidth
                        contentHeight: height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Row {
                            id: overviewRow
                            spacing: 6 * root.uiScale
                            Repeater {
                                model: root.overviewGroups
                                delegate: Rectangle {
                                    id: groupChip
                                    required property int index
                                    required property var modelData
                                    readonly property bool active: String(modelData.id)
                                                                           === root.activeGroupId
                                    width: groupLabel.implicitWidth + 22 * root.uiScale
                                    height: 30 * root.uiScale
                                    radius: height / 2
                                    color: active ? Style.Theme.acento_fondo
                                                  : Style.Theme.chip_fondo
                                    border.width: active ? 2 : 1
                                    border.color: active ? Style.Theme.acento
                                                        : Style.Theme.chip_borde
                                    opacity: active ? 1 : 0.62
                                    Text {
                                        id: groupLabel
                                        anchors.centerIn: parent
                                        text: (groupChip.index + 1) + " · "
                                              + String(groupChip.modelData.label)
                                        color: groupChip.active
                                               ? Style.Theme.acento_texto
                                               : Style.Theme.chip_texto
                                        font.bold: groupChip.active
                                        font.pixelSize: Math.max(10, 11 * root.uiScale)
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.goToGroup(groupChip.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            GridLayout {
                id: workspace
                visible: root.analysis.module_id === root.moduleId
                objectName: "moduleLaboratoryWorkspace"
                Layout.fillWidth: true
                Layout.leftMargin: 24 * root.uiScale
                Layout.rightMargin: 24 * root.uiScale
                // El modo medio evita comprimir la escena: pasos arriba y la
                // animación a todo el ancho debajo.
                implicitHeight: root.workspacePreferredHeight
                Layout.preferredHeight: root.workspacePreferredHeight
                Layout.minimumHeight: root.workspacePreferredHeight
                Layout.maximumHeight: root.workspacePreferredHeight
                columns: root.wideLayout ? 2 : 1
                columnSpacing: 12 * root.uiScale
                rowSpacing: 12 * root.uiScale

                RectanglePrincipal {
                    objectName: "moduleLaboratoryStepPane"
                    Layout.fillWidth: !root.wideLayout
                    Layout.preferredWidth: root.wideLayout ? 255 * root.uiScale : 0
                    Layout.preferredHeight: root.wideLayout
                                            ? 590 * root.uiScale
                                            : (root.mediumLayout
                                               ? 230 * root.uiScale
                                               : 240 * root.uiScale)
                    Layout.fillHeight: root.wideLayout
                    sx: root.uiScale; sy: root.uiScale
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12 * root.uiScale
                        spacing: 8 * root.uiScale
                        Text {
                            Layout.fillWidth: true
                            text: root.advancedMode
                                  ? "OPERACIONES DEL MÓDULO"
                                  : "UNA OPERACIÓN A LA VEZ"
                            color: Style.Theme.acento_fuerte
                            font.bold: true
                            font.pixelSize: 9 * root.uiScale
                            font.letterSpacing: 0.6
                        }

                        Rectangle {
                            objectName: "moduleLaboratoryEssentialStepCard"
                            visible: !root.advancedMode
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 10 * root.uiScale
                            color: Style.Theme.superficie_alterna
                            border.color: Style.Theme.acento
                            border.width: 2

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12 * root.uiScale
                                spacing: 8 * root.uiScale

                                Text {
                                    visible: root.activeGroupId.length > 0
                                    Layout.fillWidth: true
                                    text: "BLOQUE ACTUAL  ·  " + root.activeGroupId.toUpperCase()
                                    color: Style.Theme.acento_fuerte
                                    font.bold: true
                                    font.pixelSize: Math.max(9, 10 * root.uiScale)
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: String(root.currentStep.title || "Operación")
                                    color: Style.Theme.texto_primario
                                    font.bold: true
                                    font.pixelSize: Math.max(16, 19 * root.uiScale)
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "ENTRA  ·  "
                                          + String(root.currentStep.input || "Datos del paso anterior")
                                    color: Style.Theme.inferencia_estructura
                                    font.bold: true
                                    font.pixelSize: Math.max(11, 12 * root.uiScale)
                                    wrapMode: Text.WordWrap
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    color: Style.Theme.divisor
                                }
                                Text {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    text: String(root.currentStep.explanation
                                                 || "Observa la transformación del paso actual.")
                                    color: Style.Theme.texto_secundario_fuerte
                                    font.pixelSize: Math.max(12, 14 * root.uiScale)
                                    lineHeight: 1.2
                                    wrapMode: Text.WordWrap
                                    verticalAlignment: Text.AlignTop
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "SALE  ·  "
                                          + String(root.currentStep.output || "Resultado")
                                    color: Style.Theme.inferencia_resultado
                                    font.bold: true
                                    font.pixelSize: Math.max(11, 12 * root.uiScale)
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                        ListView {
                            id: stepList
                            objectName: "moduleLaboratoryStepList"
                            visible: root.advancedMode
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            orientation: root.compactLayout
                                         ? ListView.Horizontal : ListView.Vertical
                            spacing: 6 * root.uiScale
                            clip: true
                            model: root.steps
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.horizontal: ScrollBar {
                                policy: root.compactLayout
                                        ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                            }
                            ScrollBar.vertical: ScrollBar {
                                policy: root.compactLayout
                                        ? ScrollBar.AlwaysOff : ScrollBar.AsNeeded
                            }
                            delegate: Rectangle {
                                id: stepDelegate
                                required property int index
                                required property var modelData
                                width: root.compactLayout ? 170 * root.uiScale : ListView.view.width
                                height: root.compactLayout ? ListView.view.height - 8 * root.uiScale : 68 * root.uiScale
                                radius: 9 * root.uiScale
                                color: stepDelegate.index === root.safeStepIndex ? Style.Theme.acento_fondo : Style.Theme.superficie_alterna
                                border.width: stepDelegate.index === root.safeStepIndex ? 2 : 1
                                border.color: stepDelegate.index === root.safeStepIndex ? Style.Theme.acento : Style.Theme.borde_suave
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8 * root.uiScale
                                    spacing: 8 * root.uiScale
                                    Rectangle {
                                        Layout.preferredWidth: 28 * root.uiScale
                                        Layout.preferredHeight: 28 * root.uiScale
                                        radius: width / 2
                                        color: stepDelegate.index <= root.safeStepIndex ? Style.Theme.acento : Style.Theme.chip_fondo
                                        Text { anchors.centerIn: parent; text: stepDelegate.index + 1; color: stepDelegate.index <= root.safeStepIndex ? Style.Theme.texto_sobre_acento : Style.Theme.texto_secundario; font.bold: true; font.pixelSize: 10 * root.uiScale }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        spacing: 1
                                        Text { Layout.fillWidth: true; text: stepDelegate.modelData.title || "Paso"; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: Math.max(11, 12 * root.uiScale); maximumLineCount: 2; elide: Text.ElideRight; wrapMode: Text.WordWrap }
                                        Text { Layout.fillWidth: true; visible: !root.compactLayout; text: stepDelegate.modelData.formula || ""; color: Style.Theme.texto_terciario; font.family: Style.Theme.fuente_mono; font.pixelSize: Math.max(9, 10 * root.uiScale); elide: Text.ElideRight }
                                    }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.playing = false; root.currentStepIndex = stepDelegate.index } }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5 * root.uiScale
                            BotonSecundario { objectName: "moduleLaboratoryRestartSteps"; Layout.preferredWidth: 36 * root.uiScale; Layout.preferredHeight: 34 * root.uiScale; sx: root.uiScale; sy: root.uiScale; text: "↺"; onClicked: root.restartSteps() }
                            BotonSecundario { objectName: "moduleLaboratoryPreviousStep"; Layout.fillWidth: true; Layout.preferredHeight: 34 * root.uiScale; sx: root.uiScale; sy: root.uiScale; text: "←"; enabled: root.safeStepIndex > 0; opacity: enabled ? 1 : 0.4; onClicked: root.previousStep() }
                            BotonPrincipal { objectName: "moduleLaboratoryPlaySteps"; Layout.fillWidth: true; Layout.preferredHeight: 34 * root.uiScale; text: root.playing ? "Ⅱ" : "▶"; onClicked: root.togglePlayback() }
                            BotonSecundario { objectName: "moduleLaboratoryNextStep"; Layout.fillWidth: true; Layout.preferredHeight: 34 * root.uiScale; sx: root.uiScale; sy: root.uiScale; text: "→"; enabled: root.safeStepIndex < root.steps.length - 1; opacity: enabled ? 1 : 0.4; onClicked: root.nextStep() }
                        }
                    }
                }

                RectanglePrincipal {
                    objectName: "moduleLaboratoryVisualPane"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: root.narrowLayout
                                            ? 860 * root.uiScale : 590 * root.uiScale
                    Layout.fillHeight: !root.narrowLayout
                    sx: root.uiScale; sy: root.uiScale
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12 * root.uiScale
                        spacing: 8 * root.uiScale
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8 * root.uiScale
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 1
                                Text { Layout.fillWidth: true; text: (root.safeStepIndex + 1) + " / " + root.steps.length + " · " + (root.currentStep.title || "Operación"); color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 15 * root.uiScale; elide: Text.ElideRight }
                                Text {
                                    objectName: "moduleLaboratoryCaptureSummary"
                                    Layout.fillWidth: true
                                    text: Boolean(root.currentPanel.key)
                                          ? String(root.currentPanel.title || "Tensor real")
                                            + " · forma ["
                                            + (root.currentPanel.shape || []).join(" × ") + "]"
                                          : String(root.currentStep.input || "Entrada")
                                            + " → " + String(root.currentStep.output || "Salida")
                                    color: Style.Theme.acento_fuerte
                                    font.family: Style.Theme.fuente_mono
                                    font.pixelSize: 10 * root.uiScale
                                    elide: Text.ElideRight
                                }
                            }
                            BotonSecundario {
                                objectName: "moduleLaboratoryDetachGuide"
                                visible: root.advancedMode
                                Layout.preferredWidth: 180 * root.uiScale
                                Layout.preferredHeight: 32 * root.uiScale
                                sx: root.uiScale; sy: root.uiScale
                                text: root.guideDetached
                                      ? "Cerrar explicación"
                                      : "Separar explicación ↗"
                                onClicked: root.toggleGuide()
                            }
                        }

                        TabBar {
                            id: workspaceTabs
                            objectName: "moduleLaboratoryWorkspaceTabs"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42 * root.uiScale
                            currentIndex: root.workspaceSection
                            spacing: 4 * root.uiScale
                            Accessible.name: "Contenido de la operación actual"
                            Accessible.description: "Muestra una vista a la vez"
                            onCurrentIndexChanged: {
                                root.workspaceSection = currentIndex
                                if (currentIndex === 1)
                                    formulaScene.replay()
                            }
                            background: Rectangle {
                                radius: 9 * root.uiScale
                                color: Style.Theme.superficie_alterna
                                border.color: Style.Theme.borde_suave
                            }
                            PestanaAccesible {
                                objectName: "moduleLaboratoryAnimationTab"
                                text: "Vista general"
                            }
                            PestanaAccesible {
                                objectName: "moduleLaboratoryFormulaTab"
                                text: "Animación detallada"
                            }
                            PestanaAccesible {
                                objectName: "moduleLaboratoryExplanationTab"
                                text: "Explicación"
                            }
                        }

                        StackLayout {
                            objectName: "moduleLaboratoryFocusStack"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            currentIndex: root.workspaceSection

                            ModuleLaboratoryVisualization {
                                id: visualization
                                objectName: "moduleLaboratoryVisualization"
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                moduleId: root.moduleId
                                analysis: root.analysis
                                step: root.currentStep
                                stepIndex: root.safeStepIndex
                                mode: root.mode
                                selectedLayer: Math.round(layerSlider.value)
                                selectedHead: Math.round(headSlider.value)
                                selectedToken: Math.round(tokenSlider.value)
                                showContextChrome: false
                                sx: root.uiScale; sy: root.uiScale
                                onInspectRequested: function(panel) { root.openValues(panel) }
                            }

                            FormulaAnimationScene {
                                id: formulaScene
                                objectName: "moduleLaboratoryFormulaScene"
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                step: root.currentStep
                                demo: root.currentFormulaDemo
                                formulaExplanation: animationGuide.formulaReadingText
                                essentialMode: !root.advancedMode
                                reducedMotion: Style.Theme.movimientoReducido
                                sx: root.uiScale; sy: root.uiScale
                            }

                            LaboratoryAnimationGuide {
                                id: animationGuide
                                objectName: "moduleLaboratoryAnimationGuide"
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                moduleId: root.moduleId
                                mode: root.mode
                                steps: root.steps
                                step: root.currentStep
                                panel: root.currentPanel
                                analysis: root.analysis
                                demo: root.currentFormulaDemo
                                stepIndex: root.safeStepIndex
                                essentialMode: !root.advancedMode
                                sx: root.uiScale
                                sy: root.uiScale
                                onInspectRequested: function(panel) { root.openValues(panel) }
                            }
                        }
                    }
                }

            }

            Item { Layout.fillWidth: true; Layout.preferredHeight: 18 * root.uiScale }
        }
    }

    Window {
        id: detachedGuideWindow
        objectName: "moduleLaboratoryDetachedGuideWindow"
        visible: root.guideDetached
        transientParent: root.Window.window
        modality: Qt.NonModal
        minimumWidth: 560
        minimumHeight: 640
        width: Math.max(minimumWidth, Math.min(820, root.width * 0.52))
        height: Math.max(minimumHeight, Math.min(920, root.height * 0.92))
        title: "Explicación · " + String(root.currentStep.title || "Etapa")
        color: Style.Theme.superficie_alterna

        Component.onCompleted: {
            if (typeof displayManager !== "undefined" && displayManager)
                displayManager.registerAuxiliaryWindow(detachedGuideWindow, true)
        }
        onVisibleChanged: {
            if (visible
                    && typeof displayManager !== "undefined"
                    && displayManager
                    && displayManager.hasSecondaryScreen)
                displayManager.placeAuxiliaryWindow(detachedGuideWindow, true)
        }
        onClosing: function(close) {
            if (root.guideDetached)
                root.closeDetachedGuide()
            close.accepted = true
        }
    }

    LaboratoryAnimationGuide {
        id: detachedAnimationGuide
        objectName: "moduleLaboratoryDetachedAnimationGuide"
        parent: detachedGuideWindow.contentItem
        anchors.fill: parent
        anchors.margins: 10
        visible: root.guideDetached
        moduleId: root.moduleId
        mode: root.mode
        steps: root.steps
        step: root.currentStep
        panel: root.currentPanel
        analysis: root.analysis
        demo: root.currentFormulaDemo
        stepIndex: root.safeStepIndex
        essentialMode: false
        sx: Math.max(0.96, Math.min(1.16,
                                   detachedGuideWindow.width / 700))
        sy: Math.max(0.96, Math.min(1.16,
                                   detachedGuideWindow.height / 820))
        onInspectRequested: function(panel) { root.openValues(panel) }
    }

    Dialog {
        id: valuesDialog
        modal: true
        anchors.centerIn: parent
        width: Math.min(root.width - 36, 920 * root.uiScale)
        height: Math.min(root.height - 36, 650 * root.uiScale)
        title: root.inspectedTitle + " · valores originales"
        standardButtons: Dialog.Close
        ColumnLayout {
            anchors.fill: parent
            spacing: 9 * root.uiScale
            Text {
                Layout.fillWidth: true
                text: "Forma original [" + (root.inspectedPanel.shape || []).join(" × ") + "] · elementos " + (root.valueOffset + 1) + "–" + Math.min(root.valueOffset + root.pageValues.length, root.laboratoryController.fullValueLength(root.inspectedKey)) + " de " + root.laboratoryController.fullValueLength(root.inspectedKey)
                color: Style.Theme.texto_secundario_fuerte
                font.pixelSize: 11 * root.uiScale
                wrapMode: Text.WordWrap
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 190 * root.uiScale
                radius: 9 * root.uiScale
                color: Style.Theme.superficie_alterna
                border.color: Style.Theme.borde_suave
                ScientificMatrix { anchors.fill: parent; anchors.margins: 10 * root.uiScale; matrix: root.inspectedPanel.matrix || []; valueKind: ValueKinds.of(root.inspectedPanel); colorMode: root.inspectedPanel.color_mode || "diverging"; localScale: true; alternativeText: "Vista matricial de " + root.inspectedTitle }
            }
            GridView {
                id: valueGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.pageValues
                cellWidth: Math.max(112 * root.uiScale,
                                    width / Math.max(1, Math.floor(
                                        width / (132 * root.uiScale))))
                cellHeight: 44 * root.uiScale
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Rectangle {
                    id: valueCell
                    required property int index
                    required property var modelData
                    width: valueGrid.cellWidth - 6 * root.uiScale
                    height: valueGrid.cellHeight - 6 * root.uiScale
                    radius: 7 * root.uiScale
                    color: Style.Theme.superficie_alterna
                    border.color: Style.Theme.borde_suave
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 12 * root.uiScale
                        spacing: 1
                        Text {
                            width: parent.width
                            text: root.valueCoordinate(valueCell.index)
                            color: Style.Theme.texto_terciario
                            font.pixelSize: 8 * root.uiScale
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: root.formattedValue(valueCell.modelData,
                                                      ValueKinds.of(root.inspectedPanel))
                            color: Style.Theme.texto_primario
                            font.family: Style.Theme.fuente_mono
                            font.bold: true
                            font.pixelSize: 9 * root.uiScale
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                BotonPrincipal { Layout.preferredWidth: 145 * root.uiScale; Layout.preferredHeight: 34 * root.uiScale; text: "← Anteriores"; enabled: root.valueOffset > 0; opacity: enabled ? 1 : 0.4; onClicked: { root.valueOffset = Math.max(0, root.valueOffset - 128); root.loadValuePage() } }
                BotonPrincipal { Layout.preferredWidth: 145 * root.uiScale; Layout.preferredHeight: 34 * root.uiScale; text: "Siguientes →"; enabled: root.valueOffset + root.pageValues.length < root.laboratoryController.fullValueLength(root.inspectedKey); opacity: enabled ? 1 : 0.4; onClicked: { root.valueOffset += 128; root.loadValuePage() } }
            }
        }
    }

}
