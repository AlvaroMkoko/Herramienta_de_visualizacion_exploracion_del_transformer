import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root

    helpModalObjectName: "modelSetTheoryModal"
    helpPanelObjectName: "modelSetContextPanel"

    // Contrato público existente: el modelo puede seguir poblándose desde fuera.
    property alias datasetModel: setModel
    property alias markModel: markedModel

    function indexOfMark(modelId) {
        for (var i = 0; i < markedModel.count; ++i) {
            if (markedModel.get(i).datasetId === modelId)
                return i
        }
        return -1
    }

    function value(item, names, fallback) {
        if (item === undefined || item === null)
            return fallback
        for (var i = 0; i < names.length; ++i) {
            var candidate = item[names[i]]
            if (candidate !== undefined && candidate !== null && candidate !== "")
                return candidate
        }
        return fallback
    }

    function readableNumber(value) {
        var number = Number(value)
        if (value === undefined || value === null || value === "" || isNaN(number))
            return "\u2014"
        if (number >= 1000000000)
            return (number / 1000000000).toFixed(2) + " mil M"
        if (number >= 1000000)
            return (number / 1000000).toFixed(2) + " M"
        if (number >= 1000)
            return (number / 1000).toFixed(1) + " mil"
        return String(number)
    }

    ListModel {
        id: setModel
    }

    ListModel {
        id: markedModel
    }

    RowLayout {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 24 * root.sx
        height: 72 * root.sy
        spacing: 14 * root.sx

        BotonPrincipal {
            Layout.preferredWidth: 210 * root.sx
            Layout.preferredHeight: 44 * root.sy
            text: "\u21b6 Volver al inicio"
            size_text: 0.27
            onClicked: root.stackView.pop()
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2 * root.sy

            Text {
                text: "Modelos para inferencia"
                color: Style.Theme.texto_primario
                font.bold: true
                font.pixelSize: 27 * Math.min(root.sx, root.sy)
            }

            Text {
                text: setModel.count
                      + (setModel.count === 1 ? " modelo disponible" : " modelos disponibles")
                color: Style.Theme.texto_secundario
                font.pixelSize: 14 * Math.min(root.sx, root.sy)
            }
        }

        Rectangle {
            Layout.preferredWidth: Math.max(180 * root.sx,
                                            selectedText.implicitWidth + 28 * root.sx)
            Layout.preferredHeight: 36 * root.sy
            radius: height / 2
            color: markedModel.count > 0 ? Style.Theme.acento_fondo : Style.Theme.chip_fondo
            border.color: markedModel.count > 0 ? "#C4B5FD" : Style.Theme.borde_suave

            Text {
                id: selectedText
                anchors.centerIn: parent
                text: markedModel.count
                      + (markedModel.count === 1 ? " seleccionado" : " seleccionados")
                color: markedModel.count > 0 ? Style.Theme.acento_fuerte : Style.Theme.texto_secundario
                font.bold: true
                font.pixelSize: 12 * Math.min(root.sx, root.sy)
            }
        }
    }

    RectanglePrincipal {
        id: selectionSummary
        anchors.top: header.bottom
        anchors.topMargin: 8 * root.sy
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 30 * root.sx
        anchors.rightMargin: 30 * root.sx
        height: 70 * root.sy
        sx: root.sx
        sy: root.sy

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12 * root.sx
            spacing: 14 * root.sx

            Rectangle {
                Layout.preferredWidth: 38 * root.sx
                Layout.preferredHeight: 38 * root.sy
                radius: 10 * root.sx
                color: Style.Theme.acento_fondo

                Text {
                    anchors.centerIn: parent
                    text: "T"
                    color: Style.Theme.acento_fuerte
                    font.bold: true
                    font.pixelSize: 17 * Math.min(root.sx, root.sy)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1 * root.sy

                Text {
                    Layout.fillWidth: true
                    text: "Selecciona los modelos que quieres utilizar"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 15 * Math.min(root.sx, root.sy)
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: "La selección no carga ni modifica los modelos; solo prepara la elección visual."
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 12 * Math.min(root.sx, root.sy)
                    elide: Text.ElideRight
                }
            }
        }
    }

    ListView {
        id: modelList
        anchors.top: selectionSummary.bottom
        anchors.topMargin: 14 * root.sy
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 30 * root.sx
        anchors.rightMargin: 30 * root.sx
        anchors.bottomMargin: 24 * root.sy
        spacing: 14 * root.sy
        clip: true
        model: setModel
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        delegate: RectanglePrincipal {
            id: modelCard

            property var info: model
            property var dsModel: root.datasetModel
            property var mkModel: root.markModel
            property int rowIndex: index
            readonly property string modelId: String(root.value(
                                                         info,
                                                         ["id", "modelId", "modelo_id"],
                                                         rowIndex))
            readonly property string modelName: String(root.value(
                                                           info,
                                                           ["nombre", "name", "archivo"],
                                                           "Modelo sin nombre"))

            width: modelList.width - 14 * root.sx
            height: 174 * root.sy
            sx: root.sx
            sy: root.sy

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16 * root.sx
                spacing: 8 * root.sy

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 13 * root.sx

                    CheckBox {
                        id: check
                        checked: Boolean(root.value(modelCard.info, ["selected"], false))

                        onCheckedChanged: {
                            modelCard.dsModel.setProperty(modelCard.rowIndex, "selected", checked)

                            if (checked) {
                                if (root.indexOfMark(modelCard.modelId) === -1) {
                                    modelCard.mkModel.append({
                                        datasetId: modelCard.modelId,
                                        ruta: String(root.value(modelCard.info,
                                                                ["ruta", "path"], "")),
                                        nombre: modelCard.modelName
                                    })
                                }
                            } else {
                                let selectedIndex = root.indexOfMark(modelCard.modelId)
                                if (selectedIndex !== -1)
                                    modelCard.mkModel.remove(selectedIndex)
                            }
                        }

                        indicator: Rectangle {
                            implicitWidth: 22 * root.sx
                            implicitHeight: 22 * root.sy
                            radius: 5 * root.sx
                            color: check.checked ? Style.Theme.acento : Style.Theme.surface
                            border.width: 1.5
                            border.color: Style.Theme.acento

                            Text {
                                anchors.centerIn: parent
                                text: "\u2713"
                                visible: check.checked
                                color: Style.Theme.texto_sobre_color
                                font.pixelSize: 13 * Math.min(root.sx, root.sy)
                                font.bold: true
                            }
                        }

                        contentItem: Item {}
                    }

                    Rectangle {
                        Layout.preferredWidth: 42 * root.sx
                        Layout.preferredHeight: 42 * root.sy
                        radius: 10 * root.sx
                        color: check.checked ? Style.Theme.acento : Style.Theme.acento_fondo

                        Text {
                            anchors.centerIn: parent
                            text: "T"
                            color: check.checked ? Style.Theme.texto_sobre_color : Style.Theme.acento_fuerte
                            font.bold: true
                            font.pixelSize: 18 * Math.min(root.sx, root.sy)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2 * root.sy

                        Text {
                            Layout.fillWidth: true
                            text: modelCard.modelName
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: 19 * Math.min(root.sx, root.sy)
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: String(root.value(modelCard.info,
                                                    ["ruta", "path", "id"],
                                                    "Identificador no disponible"))
                            color: Style.Theme.texto_secundario
                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                            elide: Text.ElideMiddle
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: stateText.implicitWidth + 20 * root.sx
                        Layout.preferredHeight: 28 * root.sy
                        radius: height / 2
                        color: Style.Theme.exito_fondo
                        border.color: "#86EFAC"

                        Text {
                            id: stateText
                            anchors.centerIn: parent
                            text: String(root.value(modelCard.info,
                                                    ["estado", "status"],
                                                    "Listo para inferencia"))
                            color: Style.Theme.exito_texto
                            font.bold: true
                            font.pixelSize: 11 * Math.min(root.sx, root.sy)
                        }
                    }

                    BotonPrincipal {
                        Layout.preferredWidth: 150 * root.sx
                        Layout.preferredHeight: 38 * root.sy
                        text: "Eliminar modelo"
                        size_text: 0.22
                        onClicked: {
                            // Se conserva el manejador original sin añadir lógica.
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Style.Theme.divisor
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    columnSpacing: 10 * root.sx
                    rowSpacing: 4 * root.sy

                    Repeater {
                        model: [
                            {
                                label: "CAPAS",
                                help: "layer_count",
                                value: root.value(modelCard.info,
                                                  ["num_capas", "encoder_layers", "capas"], "\u2014")
                            },
                            {
                                label: "CABEZAS",
                                help: "cabeza_atencion",
                                value: root.value(modelCard.info,
                                                  ["num_cabezas", "heads", "nhead"], "\u2014")
                            },
                            {
                                label: "DIMENSIÓN",
                                help: "d_model",
                                value: root.value(modelCard.info,
                                                  ["dimension_modelo", "d_model", "dimension"], "\u2014")
                            },
                            {
                                label: "PARÁMETROS",
                                help: "parameter_count",
                                value: root.readableNumber(root.value(
                                                               modelCard.info,
                                                               ["parametros_totales", "parametros"], ""))
                            }
                        ]

                        delegate: Rectangle {
                            id: metric
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 54 * root.sy
                            radius: 8 * root.sx
                            color: "#F9FAFB"
                            border.color: Style.Theme.divisor

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12 * root.sx
                                anchors.rightMargin: 12 * root.sx
                                spacing: 8 * root.sx

                                Text {
                                    Layout.fillWidth: true
                                    text: metric.modelData.label
                                    color: Style.Theme.texto_secundario
                                    font.bold: true
                                    font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                    elide: Text.ElideRight
                                }

                                ConceptHelpButton {
                                    conceptId: String(metric.modelData.help)
                                    controlSize: Math.max(22, 27 * Math.min(root.sx,
                                                                          root.sy))
                                    onHelpRequested: function(conceptId) {
                                        root.openTheoryConcept(conceptId)
                                    }
                                }

                                Text {
                                    text: String(metric.modelData.value)
                                    color: Style.Theme.acento_fuerte
                                    font.bold: true
                                    font.pixelSize: 16 * Math.min(root.sx, root.sy)
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: modelList.count === 0
            width: Math.min(parent.width - 60 * root.sx, 620 * root.sx)
            text: "Aún no hay modelos disponibles.\nAgrega o entrena un modelo para utilizarlo en inferencia."
            color: Style.Theme.texto_secundario
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: 17 * Math.min(root.sx, root.sy)
        }
    }
}
