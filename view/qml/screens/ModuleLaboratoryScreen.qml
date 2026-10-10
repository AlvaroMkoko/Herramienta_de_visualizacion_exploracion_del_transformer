pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root
    objectName: "moduleLaboratoryScreen"

    property string moduleId: "module_1"
    readonly property var courseController: mainViewModel.courseController
    readonly property var laboratoryController: mainViewModel.moduleLaboratoryController
    readonly property var moduleData: courseController.currentModule
    readonly property var laboratory: moduleData.laboratory || ({})
    readonly property var analysis: laboratoryController.result || ({})
    readonly property var steps: analysis.steps || []
    readonly property var tokens: analysis.tokens || []
    readonly property real uiScale: Math.max(0.82, Math.min(1.08,
                                                           Math.min(root.sx,
                                                                    root.sy)))
    // Los paneles laterales consumen cerca de 560 px. Mantener tres columnas
    // antes de este umbral deja la visualización central por debajo de 840 px
    // y comprime matrices y escenas aunque la ventana parezca "ancha".
    readonly property bool compactLayout: root.width < 1460
    readonly property bool narrowControls: root.width < 760
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

    property string mode: "inference"
    property int currentStepIndex: 0
    property bool playing: false
    property string errorMessage: ""
    property string inspectedKey: ""
    property string inspectedTitle: ""
    property var inspectedPanel: ({})
    property int valueOffset: 0
    property var pageValues: []

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

    function formattedValue(value) {
        if (typeof value === "boolean")
            return value ? "True" : "False"
        var numeric = Number(value)
        if (!Number.isFinite(numeric))
            return String(value)
        var absolute = Math.abs(numeric)
        if (absolute !== 0 && (absolute >= 1000 || absolute < 0.0001))
            return numeric.toExponential(4)
        return numeric.toFixed(Number.isInteger(numeric) ? 0 : 6)
    }

    Component.onCompleted: root.courseController.selectModule(root.moduleId)

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
        interval: 1700
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
                Layout.rightMargin: 24 * root.uiScale
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
                            Layout.preferredHeight: 38 * root.uiScale
                            currentIndex: root.mode === "training" ? 0 : 1
                            background: Rectangle {
                                radius: 9 * root.uiScale
                                color: Style.Theme.superficie_alterna
                                border.color: Style.Theme.borde_suave
                            }
                            PestanaAccesible {
                                text: "Entrenamiento"
                                onClicked: root.chooseMode("training")
                            }
                            PestanaAccesible {
                                text: "Inferencia"
                                onClicked: root.chooseMode("inference")
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38 * root.uiScale
                            radius: 9 * root.uiScale
                            color: root.mode === "training"
                                   ? Style.Theme.aviso_fondo : Style.Theme.info_fondo
                            Text {
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
                                elide: Text.ElideRight
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.narrowControls
                                 ? 1 : (root.laboratoryController.modelReady ? 2 : 3)
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
                            visible: !root.laboratoryController.modelReady
                            Layout.fillWidth: root.narrowControls
                            Layout.preferredWidth: root.narrowControls
                                                   ? 0 : 135 * root.uiScale
                            Layout.preferredHeight: 42 * root.uiScale
                            text: "Crear modelo"
                            onClicked: root.stackView.push(
                                "SetupScreen.qml", { "stackView": root.stackView })
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        visible: root.moduleId !== "module_1"
                        columns: root.compactLayout ? 2 : 5
                        columnSpacing: 14 * root.uiScale
                        rowSpacing: 6 * root.uiScale

                        ColumnLayout {
                            visible: ["module_3", "module_4", "module_5", "module_6", "module_8"]
                                     .indexOf(root.moduleId) !== -1
                            Layout.fillWidth: true
                            Text { text: "Capa " + (Math.round(layerSlider.value) + 1); color: Style.Theme.texto_secundario_fuerte; font.pixelSize: 10 * root.uiScale }
                            Slider { id: layerSlider; Layout.fillWidth: true; from: 0; to: root.modelLayerCount - 1; stepSize: 1; value: 0 }
                        }
                        ColumnLayout {
                            visible: ["module_3", "module_4", "module_6", "module_8"]
                                     .indexOf(root.moduleId) !== -1
                            Layout.fillWidth: true
                            Text { text: "Cabeza " + (Math.round(headSlider.value) + 1); color: Style.Theme.texto_secundario_fuerte; font.pixelSize: 10 * root.uiScale }
                            Slider { id: headSlider; Layout.fillWidth: true; from: 0; to: root.modelHeadCount - 1; stepSize: 1; value: 0 }
                        }
                        ColumnLayout {
                            visible: ["module_2", "module_3", "module_4", "module_5",
                                      "module_6", "module_7", "module_8"]
                                     .indexOf(root.moduleId) !== -1
                            Layout.fillWidth: true
                            Text { text: (root.moduleId === "module_7" ? "Posición " : "Token ") + (Math.round(tokenSlider.value) + 1); color: Style.Theme.texto_secundario_fuerte; font.pixelSize: 10 * root.uiScale }
                            Slider { id: tokenSlider; Layout.fillWidth: true; from: 0; to: Math.max(0, root.tokens.length - 1); stepSize: 1; value: 0 }
                        }
                        RowLayout {
                            visible: ["module_6", "module_8"].indexOf(root.moduleId) !== -1
                            Layout.fillWidth: true
                            Text { text: "Máscara causal"; color: Style.Theme.texto_secundario_fuerte; font.pixelSize: 10 * root.uiScale }
                            Switch { id: causalSwitch; checked: true }
                        }
                        ColumnLayout {
                            visible: ["module_7", "module_8"].indexOf(root.moduleId) !== -1
                            Layout.fillWidth: true
                            Text { text: "Temperatura " + temperatureSlider.value.toFixed(2); color: Style.Theme.texto_secundario_fuerte; font.pixelSize: 10 * root.uiScale }
                            Slider { id: temperatureSlider; Layout.fillWidth: true; from: 0.1; to: 2.0; value: 1.0; stepSize: 0.05 }
                        }
                        ColumnLayout {
                            visible: ["module_7", "module_8"].indexOf(root.moduleId) !== -1
                            Layout.fillWidth: true
                            Text { text: "Top-K " + Math.round(topKSlider.value); color: Style.Theme.texto_secundario_fuerte; font.pixelSize: 10 * root.uiScale }
                            Slider { id: topKSlider; Layout.fillWidth: true; from: 1; to: 100; value: 20; stepSize: 1 }
                        }
                        ColumnLayout {
                            visible: ["module_7", "module_8"].indexOf(root.moduleId) !== -1
                            Layout.fillWidth: true
                            Text { text: "Top-P " + topPSlider.value.toFixed(2); color: Style.Theme.texto_secundario_fuerte; font.pixelSize: 10 * root.uiScale }
                            Slider { id: topPSlider; Layout.fillWidth: true; from: 0.05; to: 1.0; value: 0.9; stepSize: 0.01 }
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
                visible: root.tokens.length > 0
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
                              : "Primero crea o carga un modelo"
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

            GridLayout {
                id: workspace
                visible: root.analysis.module_id === root.moduleId
                objectName: "moduleLaboratoryWorkspace"
                Layout.fillWidth: true
                Layout.leftMargin: 24 * root.uiScale
                Layout.rightMargin: 24 * root.uiScale
                // En una sola columna, las escenas científicas necesitan altura
                // real para conservar matrices, leyendas y evidencia separadas.
                Layout.preferredHeight: root.compactLayout
                                        ? 1400 * root.uiScale : 590 * root.uiScale
                columns: root.compactLayout ? 1 : 3
                columnSpacing: 12 * root.uiScale
                rowSpacing: 12 * root.uiScale

                RectanglePrincipal {
                    objectName: "moduleLaboratoryStepPane"
                    Layout.fillWidth: root.compactLayout
                    Layout.preferredWidth: root.compactLayout ? 0 : 220 * root.uiScale
                    Layout.preferredHeight: root.compactLayout
                                            ? 190 * root.uiScale : 590 * root.uiScale
                    Layout.fillHeight: !root.compactLayout
                    sx: root.uiScale; sy: root.uiScale
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12 * root.uiScale
                        spacing: 8 * root.uiScale
                        Text { Layout.fillWidth: true; text: "OPERACIONES DEL MÓDULO"; color: Style.Theme.acento_fuerte; font.bold: true; font.pixelSize: 9 * root.uiScale; font.letterSpacing: 0.6 }
                        ListView {
                            id: stepList
                            objectName: "moduleLaboratoryStepList"
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
                                        ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
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
                                height: root.compactLayout ? ListView.view.height - 8 * root.uiScale : 58 * root.uiScale
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
                                        Text { Layout.fillWidth: true; text: stepDelegate.modelData.title || "Paso"; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 10 * root.uiScale; maximumLineCount: 2; elide: Text.ElideRight; wrapMode: Text.WordWrap }
                                        Text { Layout.fillWidth: true; visible: !root.compactLayout; text: stepDelegate.modelData.formula || ""; color: Style.Theme.texto_terciario; font.family: Style.Theme.fuente_mono; font.pixelSize: 8 * root.uiScale; elide: Text.ElideRight }
                                    }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.playing = false; root.currentStepIndex = stepDelegate.index } }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5 * root.uiScale
                            BotonSecundario { Layout.preferredWidth: 36 * root.uiScale; Layout.preferredHeight: 34 * root.uiScale; sx: root.uiScale; sy: root.uiScale; text: "↺"; onClicked: root.restartSteps() }
                            BotonSecundario { Layout.fillWidth: true; Layout.preferredHeight: 34 * root.uiScale; sx: root.uiScale; sy: root.uiScale; text: "←"; enabled: root.safeStepIndex > 0; opacity: enabled ? 1 : 0.4; onClicked: root.previousStep() }
                            BotonPrincipal { Layout.fillWidth: true; Layout.preferredHeight: 34 * root.uiScale; text: root.playing ? "Ⅱ" : "▶"; onClicked: root.togglePlayback() }
                            BotonSecundario { Layout.fillWidth: true; Layout.preferredHeight: 34 * root.uiScale; sx: root.uiScale; sy: root.uiScale; text: "→"; enabled: root.safeStepIndex < root.steps.length - 1; opacity: enabled ? 1 : 0.4; onClicked: root.nextStep() }
                        }
                    }
                }

                RectanglePrincipal {
                    objectName: "moduleLaboratoryVisualPane"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: root.compactLayout
                                            ? 860 * root.uiScale : 590 * root.uiScale
                    Layout.fillHeight: !root.compactLayout
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
                                Text { Layout.fillWidth: true; text: root.currentStep.formula || ""; color: Style.Theme.acento_fuerte; font.family: Style.Theme.fuente_mono; font.pixelSize: 10 * root.uiScale; elide: Text.ElideRight }
                            }
                            Rectangle {
                                Layout.preferredWidth: 96 * root.uiScale
                                Layout.preferredHeight: 28 * root.uiScale
                                radius: height / 2
                                color: root.mode === "training" ? Style.Theme.aviso_fondo : Style.Theme.info_fondo
                                Text { anchors.centerIn: parent; text: root.mode === "training" ? "ENTRENA" : "INFIERE"; color: root.mode === "training" ? Style.Theme.aviso_texto : Style.Theme.info_texto; font.bold: true; font.pixelSize: 9 * root.uiScale }
                            }
                        }
                        ModuleLaboratoryVisualization {
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
                            // El encabezado y el panel de evidencia de esta
                            // pantalla ya muestran paso, entrada/salida y
                            // gradientes. Evitamos repetirlos dentro de la
                            // escena para reservar el alto a los datos reales.
                            showContextChrome: false
                            sx: root.uiScale; sy: root.uiScale
                            onInspectRequested: function(panel) { root.openValues(panel) }
                        }
                    }
                }

                RectanglePrincipal {
                    objectName: "moduleLaboratoryEvidencePane"
                    Layout.fillWidth: root.compactLayout
                    Layout.preferredWidth: root.compactLayout ? 0 : 270 * root.uiScale
                    Layout.preferredHeight: root.compactLayout
                                            ? 320 * root.uiScale : 590 * root.uiScale
                    Layout.fillHeight: !root.compactLayout
                    sx: root.uiScale; sy: root.uiScale
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 12 * root.uiScale
                        clip: true
                        contentWidth: availableWidth
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ColumnLayout {
                            width: parent.width
                            spacing: 10 * root.uiScale
                            Text { Layout.fillWidth: true; text: "QUÉ OCURRE AQUÍ"; color: Style.Theme.acento_fuerte; font.bold: true; font.pixelSize: 9 * root.uiScale; font.letterSpacing: 0.6 }
                            Text { Layout.fillWidth: true; text: root.currentStep.explanation || ""; color: Style.Theme.texto_secundario_fuerte; font.pixelSize: 11 * root.uiScale; wrapMode: Text.WordWrap }
                            StepFact { Layout.fillWidth: true; label: "RECIBE"; value: String(root.currentStep.input || "—"); accent: Style.Theme.inferencia_estructura; sx: root.uiScale; sy: root.uiScale }
                            StepFact { Layout.fillWidth: true; label: "PRODUCE"; value: String(root.currentStep.output || "—"); accent: Style.Theme.inferencia_resultado; sx: root.uiScale; sy: root.uiScale }
                            Rectangle {
                                objectName: root.mode === "training" ? "moduleLaboratoryTrainingEvidence" : "moduleLaboratoryInferenceEvidence"
                                Layout.fillWidth: true
                                Layout.preferredHeight: modeColumn.implicitHeight + 20 * root.uiScale
                                radius: 10 * root.uiScale
                                color: root.mode === "training" ? Style.Theme.aviso_fondo : Style.Theme.info_fondo
                                border.color: root.mode === "training" ? Style.Theme.warning : Style.Theme.inferencia_estructura
                                ColumnLayout {
                                    id: modeColumn
                                    anchors.fill: parent
                                    anchors.margins: 10 * root.uiScale
                                    spacing: 5 * root.uiScale
                                    Text { Layout.fillWidth: true; text: root.mode === "training" ? "SEÑAL DE APRENDIZAJE" : "USO EN INFERENCIA"; color: root.mode === "training" ? Style.Theme.aviso_texto : Style.Theme.info_texto; font.bold: true; font.pixelSize: 9 * root.uiScale }
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.mode === "training"
                                              ? ((root.analysis.training || {}).trainable === false
                                                 ? String((root.analysis.behavior || {}).training || "Este componente prepara datos y no tiene pesos entrenables.")
                                                   + " " + String((root.analysis.experiment || {}).didactic_note || "")
                                                 : String((root.analysis.behavior || {}).training || "")
                                                   + " Loss " + Number((root.analysis.training || {}).loss || 0).toFixed(4)
                                                   + " · la actualización mostrada no se aplica al modelo. "
                                                   + String((root.analysis.experiment || {}).didactic_note || ""))
                                              : String((root.analysis.behavior || {}).inference || "Los parámetros permanecen fijos durante este cálculo.")
                                        color: Style.Theme.texto_secundario_fuerte
                                        font.pixelSize: 10 * root.uiScale
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                            ColumnLayout {
                                visible: root.mode === "training" && ((root.analysis.training || {}).gradients || []).length > 0
                                Layout.fillWidth: true
                                spacing: 5 * root.uiScale
                                Text { text: "Gradientes del componente"; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 10 * root.uiScale }
                                Repeater {
                                    model: ((root.analysis.training || {}).gradients || []).slice(0, 4)
                                    delegate: RowLayout {
                                        id: gradientRow
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Text { Layout.fillWidth: true; text: gradientRow.modelData.label || gradientRow.modelData.name; color: Style.Theme.texto_secundario; font.pixelSize: 9 * root.uiScale; elide: Text.ElideMiddle }
                                        Text { text: "L2 " + Number(gradientRow.modelData.norm_l2 || 0).toExponential(2); color: Style.Theme.aviso_texto; font.family: Style.Theme.fuente_mono; font.pixelSize: 8 * root.uiScale }
                                    }
                                }
                            }
                            Rectangle {
                                visible: Boolean(root.currentPanel.key)
                                Layout.fillWidth: true
                                Layout.preferredHeight: tensorInfo.implicitHeight + 18 * root.uiScale
                                radius: 9 * root.uiScale
                                color: Style.Theme.superficie_alterna
                                border.color: Style.Theme.borde_suave
                                ColumnLayout {
                                    id: tensorInfo
                                    anchors.fill: parent
                                    anchors.margins: 9 * root.uiScale
                                    spacing: 4 * root.uiScale
                                    Text { Layout.fillWidth: true; text: root.currentPanel.title || "Tensor real"; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 10 * root.uiScale; elide: Text.ElideRight }
                                    Text { Layout.fillWidth: true; text: "Forma [" + (root.currentPanel.shape || []).join(" × ") + "] · " + (root.currentPanel.full_length || 0) + " valores"; color: Style.Theme.acento_fuerte; font.family: Style.Theme.fuente_mono; font.pixelSize: 9 * root.uiScale; wrapMode: Text.WordWrap }
                                    BotonSecundario { Layout.fillWidth: true; Layout.preferredHeight: 32 * root.uiScale; sx: root.uiScale; sy: root.uiScale; text: "Inspeccionar valores"; onClicked: root.openValues(root.currentPanel) }
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true; Layout.preferredHeight: 18 * root.uiScale }
        }
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
                ScientificMatrix { anchors.fill: parent; anchors.margins: 10 * root.uiScale; matrix: root.inspectedPanel.matrix || []; colorMode: root.inspectedPanel.color_mode || "diverging"; localScale: true; alternativeText: "Vista matricial de " + root.inspectedTitle }
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
                            text: root.formattedValue(valueCell.modelData)
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

    component StepFact: Rectangle {
        id: fact
        property string label: ""
        property string value: ""
        property color accent: Style.Theme.acento
        property real sx: 1
        property real sy: 1
        implicitHeight: factContent.implicitHeight + 16 * sy
        radius: 9 * sx
        color: Qt.alpha(accent, 0.08)
        border.color: Qt.alpha(accent, 0.34)
        ColumnLayout {
            id: factContent
            anchors.fill: parent
            anchors.margins: 8 * fact.sx
            spacing: 2
            Text { Layout.fillWidth: true; text: fact.label; color: fact.accent; font.bold: true; font.pixelSize: 8 * fact.sx }
            Text { Layout.fillWidth: true; text: fact.value; color: Style.Theme.texto_secundario_fuerte; font.pixelSize: 10 * fact.sx; wrapMode: Text.WordWrap }
        }
    }
}
