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
    readonly property var analysis: laboratoryController.result
    property string errorMessage: ""
    property string inspectedKey: ""
    property string inspectedTitle: ""
    property int valueOffset: 0
    property var pageValues: []

    Component.onCompleted: root.courseController.selectModule(root.moduleId)

    Connections {
        target: root.laboratoryController
        function onError(message) { root.errorMessage = message }
    }

    function runAnalysis() {
        root.errorMessage = ""
        root.laboratoryController.analyze(
            root.moduleId,
            inputText.text,
            Math.round(headSlider.value),
            temperatureSlider.value,
            Math.round(topKSlider.value),
            topPSlider.value,
            causalSwitch.checked
        )
    }

    function openValues(panel) {
        root.inspectedKey = String(panel.key || "")
        root.inspectedTitle = String(panel.title || "Valores")
        root.valueOffset = 0
        root.loadValuePage()
        valuesDialog.open()
    }

    function loadValuePage() {
        root.pageValues = root.laboratoryController.fullValues(
            root.inspectedKey, root.valueOffset, 128)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 26 * root.sx
        spacing: 13 * root.sy

        RowLayout {
            Layout.fillWidth: true
            BotonPrincipal {
                Layout.preferredWidth: 160 * root.sx
                Layout.preferredHeight: 42 * root.sy
                text: "← Módulo"
                onClicked: root.stackView.pop()
            }
            ColumnLayout {
                Layout.fillWidth: true
                Text {
                    text: "LABORATORIO · MÓDULO " + (root.moduleData.order || "")
                    color: Style.Theme.acento_fuerte
                    font.bold: true
                    font.pixelSize: 12 * root.sx
                }
                Text {
                    text: root.laboratory.title || "Laboratorio"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 27 * root.sx
                }
                Text {
                    text: root.laboratory.description || ""
                    color: Style.Theme.texto_secundario_fuerte
                    font.pixelSize: 13 * root.sx
                }
            }
            Rectangle {
                Layout.preferredWidth: 175 * root.sx
                Layout.preferredHeight: 42 * root.sy
                radius: height / 2
                color: root.laboratoryController.modelReady
                       ? Style.Theme.exito_fondo : Style.Theme.aviso_fondo
                Text {
                    anchors.centerIn: parent
                    text: root.laboratoryController.modelReady ? "Modelo activo" : "Falta un modelo"
                    color: root.laboratoryController.modelReady
                           ? Style.Theme.exito_texto : Style.Theme.aviso_texto
                    font.bold: true
                    font.pixelSize: 12 * root.sx
                }
            }
        }

        RectanglePrincipal {
            Layout.fillWidth: true
            Layout.preferredHeight: controlsColumn.implicitHeight + 28 * root.sy
            sx: root.sx
            sy: root.sy
            ColumnLayout {
                id: controlsColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14 * root.sx
                spacing: 9 * root.sy

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10 * root.sx
                    TextField {
                        id: inputText
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42 * root.sy
                        text: "La atención conecta cada token con su contexto."
                        placeholderText: "Escribe un texto para inspeccionarlo"
                        color: Style.Theme.texto_primario
                        font.pixelSize: 13 * root.sx
                    }
                    BotonPrincipal {
                        Layout.preferredWidth: 190 * root.sx
                        Layout.preferredHeight: 42 * root.sy
                        text: "Analizar datos reales"
                        enabled: root.laboratoryController.modelReady && inputText.text.trim().length > 0
                        opacity: enabled ? 1 : 0.45
                        onClicked: root.runAnalysis()
                    }
                    BotonPrincipal {
                        visible: !root.laboratoryController.modelReady
                        Layout.preferredWidth: 170 * root.sx
                        Layout.preferredHeight: 42 * root.sy
                        text: "Crear modelo"
                        onClicked: root.stackView.push("SetupScreen.qml", { "stackView": root.stackView })
                    }
                }

                RowLayout {
                    visible: root.moduleId === "module_4" || root.moduleId === "module_6" || root.moduleId === "module_7"
                    Layout.fillWidth: true
                    spacing: 16 * root.sx

                    ColumnLayout {
                        visible: root.moduleId === "module_4"
                        Layout.fillWidth: true
                        Text { text: "Cabeza: " + (Math.round(headSlider.value) + 1); color: Style.Theme.texto_secundario_fuerte; font.pixelSize: 12 * root.sx }
                        Slider {
                            id: headSlider
                            Layout.fillWidth: true
                            from: 0
                            to: Math.max(0, Number(mainViewModel.modeloActualInfo.num_cabezas || 1) - 1)
                            stepSize: 1
                            value: 0
                        }
                    }
                    RowLayout {
                        visible: root.moduleId === "module_6"
                        Layout.fillWidth: true
                        Text { text: "Máscara causal"; color: Style.Theme.texto_secundario_fuerte; font.pixelSize: 13 * root.sx }
                        Switch { id: causalSwitch; checked: true }
                        Text {
                            text: causalSwitch.checked ? "Futuro bloqueado" : "Futuro visible (comparación)"
                            color: causalSwitch.checked ? Style.Theme.exito_texto : Style.Theme.aviso_texto
                            font.pixelSize: 12 * root.sx
                        }
                    }
                    RowLayout {
                        visible: root.moduleId === "module_7"
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            Text { text: "Temperature " + temperatureSlider.value.toFixed(2); color: Style.Theme.texto_secundario_fuerte; font.pixelSize: 11 * root.sx }
                            Slider { id: temperatureSlider; Layout.fillWidth: true; from: 0.1; to: 2.0; value: 1.0; stepSize: 0.05 }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Text { text: "Top-K " + Math.round(topKSlider.value); color: Style.Theme.texto_secundario_fuerte; font.pixelSize: 11 * root.sx }
                            Slider { id: topKSlider; Layout.fillWidth: true; from: 1; to: 100; value: 20; stepSize: 1 }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Text { text: "Top-P " + topPSlider.value.toFixed(2); color: Style.Theme.texto_secundario_fuerte; font.pixelSize: 11 * root.sx }
                            Slider { id: topPSlider; Layout.fillWidth: true; from: 0.05; to: 1.0; value: 0.9; stepSize: 0.01 }
                        }
                    }
                }
            }
        }

        Text {
            visible: root.errorMessage.length > 0
            Layout.fillWidth: true
            text: root.errorMessage
            color: Style.Theme.error_texto
            wrapMode: Text.WordWrap
            font.pixelSize: 13 * root.sx
        }

        RowLayout {
            visible: root.analysis.tokens && root.analysis.tokens.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 48 * root.sy
            spacing: 6 * root.sx
            Text { text: "Tokens:"; color: Style.Theme.texto_secundario; font.bold: true; font.pixelSize: 12 * root.sx }
            Repeater {
                model: root.analysis.tokens || []
                delegate: Rectangle {
                    id: tokenChip
                    required property var modelData
                    Layout.preferredWidth: Math.max(60, tokenLabel.implicitWidth + 18) * root.sx
                    Layout.fillHeight: true
                    radius: 8 * root.sx
                    color: Style.Theme.chip_fondo
                    border.color: Style.Theme.chip_borde
                    Text {
                        id: tokenLabel
                        anchors.centerIn: parent
                        text: tokenChip.modelData.text + " · " + tokenChip.modelData.id
                        color: Style.Theme.chip_texto
                        font.family: Style.Theme.fuente_mono
                        font.pixelSize: 10 * root.sx
                    }
                }
            }
        }

        ScrollView {
            id: panelsScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            GridLayout {
                width: panelsScroll.availableWidth
                columns: width > 950 ? 3 : 2
                columnSpacing: 10 * root.sx
                rowSpacing: 10 * root.sy
                Repeater {
                    model: root.analysis.panels || []
                    delegate: Rectangle {
                        id: panelCard
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 174 * root.sy
                        radius: 12 * root.sx
                        color: Style.Theme.surface
                        border.color: Style.Theme.borde_suave
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 13 * root.sx
                            spacing: 6 * root.sy
                            Text { Layout.fillWidth: true; text: panelCard.modelData.title; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 15 * root.sx; wrapMode: Text.WordWrap }
                            Text { Layout.fillWidth: true; text: panelCard.modelData.description; color: Style.Theme.texto_secundario; font.pixelSize: 11 * root.sx; wrapMode: Text.WordWrap }
                            Text { Layout.fillWidth: true; text: "Forma: [" + (panelCard.modelData.shape || []).join(", ") + "]"; color: Style.Theme.acento_fuerte; font.family: Style.Theme.fuente_mono; font.pixelSize: 11 * root.sx }
                            Text { Layout.fillWidth: true; Layout.fillHeight: true; text: JSON.stringify(panelCard.modelData.preview || []); color: Style.Theme.texto_secundario_fuerte; font.family: Style.Theme.fuente_mono; font.pixelSize: 10 * root.sx; wrapMode: Text.WrapAnywhere }
                            BotonPrincipal {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32 * root.sy
                                text: "Inspeccionar " + panelCard.modelData.full_length + " valores"
                                onClicked: root.openValues(panelCard.modelData)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: root.analysis.selected_token && root.analysis.selected_token.id !== undefined
            Layout.fillWidth: true
            Layout.preferredHeight: 48 * root.sy
            radius: 10 * root.sx
            color: Style.Theme.exito_fondo
            Text {
                anchors.centerIn: parent
                text: "Token seleccionado: “" + (root.analysis.selected_token.text || "")
                      + "” · ID " + root.analysis.selected_token.id
                color: Style.Theme.exito_texto
                font.bold: true
                font.pixelSize: 14 * root.sx
            }
        }
    }

    Dialog {
        id: valuesDialog
        modal: true
        anchors.centerIn: parent
        width: Math.min(root.width * 0.76, 920 * root.sx)
        height: Math.min(root.height * 0.72, 590 * root.sy)
        title: root.inspectedTitle + " · valores originales"
        standardButtons: Dialog.Close

        ColumnLayout {
            anchors.fill: parent
            spacing: 10 * root.sy
            Text {
                Layout.fillWidth: true
                text: "Elementos " + (root.valueOffset + 1) + "–"
                      + Math.min(root.valueOffset + root.pageValues.length,
                                 root.laboratoryController.fullValueLength(root.inspectedKey))
                      + " de " + root.laboratoryController.fullValueLength(root.inspectedKey)
                color: Style.Theme.texto_secundario_fuerte
                font.pixelSize: 12 * root.sx
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                TextArea {
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.WrapAnywhere
                    text: JSON.stringify(root.pageValues)
                    color: Style.Theme.texto_primario
                    font.family: Style.Theme.fuente_mono
                    font.pixelSize: 12 * root.sx
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                BotonPrincipal {
                    Layout.preferredWidth: 150 * root.sx
                    Layout.preferredHeight: 36 * root.sy
                    text: "← Anteriores"
                    enabled: root.valueOffset > 0
                    opacity: enabled ? 1 : 0.4
                    onClicked: { root.valueOffset = Math.max(0, root.valueOffset - 128); root.loadValuePage() }
                }
                BotonPrincipal {
                    Layout.preferredWidth: 150 * root.sx
                    Layout.preferredHeight: 36 * root.sy
                    text: "Siguientes →"
                    enabled: root.valueOffset + root.pageValues.length
                             < root.laboratoryController.fullValueLength(root.inspectedKey)
                    opacity: enabled ? 1 : 0.4
                    onClicked: { root.valueOffset += 128; root.loadValuePage() }
                }
            }
        }
    }
}
