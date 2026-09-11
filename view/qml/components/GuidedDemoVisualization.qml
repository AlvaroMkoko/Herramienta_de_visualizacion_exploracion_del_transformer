pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../styles" as Style

Rectangle {
    id: root
    objectName: "guidedDemoVisualization"

    property string visualType: "pipeline"
    property real scaleFactor: 1.0

    readonly property string accessibleSummary: {
        if (visualType === "dataset_pairs")
            return "Un registro aporta instruction y context al encoder; response entra al decoder desplazada entre los tokens BOS y EOS para convertirse en el objetivo."
        if (visualType === "token_position")
            return "Dos tokens iguales se combinan con posiciones distintas y producen vectores distintos."
        if (visualType === "attention")
            return "Una matriz asigna 72 por ciento de atención a gato, 18 a duerme y 10 al punto."
        if (visualType === "causal_mask")
            return "Matriz triangular: cada fila permite el pasado y bloquea el futuro."
        if (visualType === "training")
            return "La pérdida produce gradientes, el optimizador los aplica y los parámetros cambian."
        return "Flujo de entrenamiento: el dataset aporta instruction, context y response; la aplicación tokeniza, el encoder y el decoder predicen, y la pérdida compara la predicción con la response esperada."
    }

    implicitHeight: 170 * scaleFactor
    radius: 9 * scaleFactor
    color: Style.Theme.fondo
    border.color: Style.Theme.borde_suave
    Accessible.name: "Demostración didáctica con datos precalculados"
    Accessible.description: accessibleSummary

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 9 * root.scaleFactor
        spacing: 7 * root.scaleFactor

        RowLayout {
            Layout.fillWidth: true
            spacing: 6 * root.scaleFactor

            Rectangle {
                Layout.preferredWidth: 7 * root.scaleFactor
                Layout.preferredHeight: 7 * root.scaleFactor
                radius: width / 2
                color: "#2F91C2"
            }
            Text {
                Layout.fillWidth: true
                text: "TRAZA DIDÁCTICA · DATOS PRECALCULADOS"
                color: Style.Theme.texto_secundario
                font.bold: true
                font.pixelSize: 8 * root.scaleFactor
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: root.visualType === "dataset_pairs" ? datasetPairsDemo
                             : root.visualType === "token_position" ? tokenPositionDemo
                             : root.visualType === "attention" ? attentionDemo
                             : root.visualType === "causal_mask" ? causalMaskDemo
                             : root.visualType === "training" ? trainingDemo
                             : pipelineDemo
        }
    }

    component DemoBlock: Rectangle {
        id: demoBlock
        property string label: ""
        property string detail: ""
        property color fillColor: Style.Theme.acento_fondo
        radius: 7 * root.scaleFactor
        color: fillColor
        border.color: Qt.darker(fillColor, 1.1)

        Column {
            anchors.centerIn: parent
            width: parent.width - 6 * root.scaleFactor
            spacing: 3 * root.scaleFactor
            Text {
                width: parent.width
                text: demoBlock.label
                color: Style.Theme.texto_primario
                font.bold: true
                font.pixelSize: 8 * root.scaleFactor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                text: demoBlock.detail
                color: Style.Theme.acento_fuerte
                font.pixelSize: 8 * root.scaleFactor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }

    Component {
        id: pipelineDemo
        Item {
            RowLayout {
                anchors.fill: parent
                spacing: 3 * root.scaleFactor
                DemoBlock {
                    objectName: "guidedPipelineDatasetBlock"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "Dataset"
                    detail: "instruction\n+ context\n+ response"
                    fillColor: Style.Theme.borde_medio
                }
                Text { text: "→"; color: Style.Theme.acento; font.bold: true }
                DemoBlock {
                    objectName: "guidedPipelineTokenizationBlock"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "Tokenización"
                    detail: "IDs +\nBOS / EOS"
                }
                Text { text: "→"; color: Style.Theme.acento; font.bold: true }
                DemoBlock {
                    objectName: "guidedPipelineTransformerBlock"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "Transformer"
                    detail: "encoder\n+ decoder"
                    fillColor: Style.Theme.aviso_fondo
                }
                Text { text: "→"; color: Style.Theme.acento; font.bold: true }
                DemoBlock {
                    objectName: "guidedPipelineLearningBlock"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "Aprendizaje"
                    detail: "predicción\nvs. objetivo"
                    fillColor: Style.Theme.exito_fondo
                }
            }
        }
    }

    Component {
        id: datasetPairsDemo
        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 5 * root.scaleFactor

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4 * root.scaleFactor
                    DemoBlock {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: "instruction"
                        detail: "Resume el texto"
                        fillColor: Style.Theme.borde_medio
                    }
                    Text { text: "+"; color: Style.Theme.acento; font.bold: true }
                    DemoBlock {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: "context (opcional)"
                        detail: "Texto fuente"
                        fillColor: Style.Theme.acento_fondo
                    }
                    Text { text: "→"; color: Style.Theme.acento; font.bold: true }
                    DemoBlock {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: "Encoder"
                        detail: "entrada"
                        fillColor: Style.Theme.exito_fondo
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4 * root.scaleFactor
                    DemoBlock {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: "response"
                        detail: "Un resumen"
                        fillColor: Style.Theme.aviso_fondo
                    }
                    Text { text: "→"; color: Style.Theme.acento; font.bold: true }
                    DemoBlock {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: "Decoder recibe"
                        detail: "BOS · Un resumen"
                        fillColor: Style.Theme.acento_fondo
                    }
                    Text { text: "→"; color: Style.Theme.acento; font.bold: true }
                    DemoBlock {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: "Objetivo"
                        detail: "Un resumen · EOS"
                        fillColor: Style.Theme.exito_fondo
                    }
                }
            }
        }
    }

    Component {
        id: tokenPositionDemo
        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 6 * root.scaleFactor
                Text {
                    Layout.fillWidth: true
                    text: "Mismo token, distinta posición"
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 8 * root.scaleFactor
                }
                Repeater {
                    model: [
                        { "position": "P₁", "vector": "v = [0.8, 0.2]" },
                        { "position": "P₄", "vector": "v = [0.3, 0.9]" }
                    ]
                    delegate: RowLayout {
                        id: positionDelegate
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 4 * root.scaleFactor
                        DemoBlock { Layout.preferredWidth: 55 * root.scaleFactor; Layout.fillHeight: true; label: "Token"; detail: "banco"; fillColor: Style.Theme.borde_medio }
                        Text { text: "+"; color: Style.Theme.texto_secundario }
                        DemoBlock { Layout.preferredWidth: 42 * root.scaleFactor; Layout.fillHeight: true; label: "Pos."; detail: positionDelegate.modelData.position }
                        Text { text: "→"; color: Style.Theme.acento }
                        DemoBlock { Layout.fillWidth: true; Layout.fillHeight: true; label: "Vector"; detail: positionDelegate.modelData.vector; fillColor: Style.Theme.exito_fondo }
                    }
                }
            }
        }
    }

    Component {
        id: attentionDemo
        Item {
            RowLayout {
                anchors.fill: parent
                spacing: 9 * root.scaleFactor
                ColumnLayout {
                    Layout.preferredWidth: 101 * root.scaleFactor
                    Layout.fillHeight: true
                    Text { Layout.fillWidth: true; text: "Matriz 3 × 3"; color: Style.Theme.texto_secundario; font.pixelSize: 8 * root.scaleFactor; horizontalAlignment: Text.AlignHCenter }
                    GridLayout {
                        Layout.alignment: Qt.AlignHCenter
                        columns: 3
                        rowSpacing: 2 * root.scaleFactor
                        columnSpacing: 2 * root.scaleFactor
                        Repeater {
                            model: [0.72, 0.18, 0.10, 0.21, 0.63, 0.16, 0.14, 0.24, 0.62]
                            delegate: Rectangle {
                                id: attentionCell
                                required property real modelData
                                Layout.preferredWidth: 28 * root.scaleFactor
                                Layout.preferredHeight: 28 * root.scaleFactor
                                radius: 4 * root.scaleFactor
                                color: Qt.rgba(0.40, 0.33, 0.73, 0.14 + modelData * 0.75)
                                Text { anchors.centerIn: parent; text: attentionCell.modelData.toFixed(2); color: attentionCell.modelData > 0.5 ? "white" : Style.Theme.acento_fuerte; font.pixelSize: 7 * root.scaleFactor }
                            }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Text { Layout.fillWidth: true; text: "Atención desde «duerme»"; color: Style.Theme.texto_secundario; font.pixelSize: 8 * root.scaleFactor }
                    Repeater {
                        model: [{ "label": "gato", "value": 0.72 }, { "label": "duerme", "value": 0.18 }, { "label": ".", "value": 0.10 }]
                        delegate: ColumnLayout {
                            id: barDelegate
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 1 * root.scaleFactor
                            RowLayout {
                                Layout.fillWidth: true
                                Text { Layout.fillWidth: true; text: barDelegate.modelData.label; color: Style.Theme.texto_primario; font.pixelSize: 8 * root.scaleFactor }
                                Text { text: Math.round(barDelegate.modelData.value * 100) + "%"; color: Style.Theme.acento_fuerte; font.bold: true; font.pixelSize: 8 * root.scaleFactor }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 7 * root.scaleFactor
                                radius: height / 2
                                color: Style.Theme.divisor
                                Rectangle { width: parent.width * barDelegate.modelData.value; height: parent.height; radius: height / 2; color: Style.Theme.acento }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: causalMaskDemo
        Item {
            RowLayout {
                anchors.fill: parent
                spacing: 11 * root.scaleFactor
                GridLayout {
                    columns: 4
                    rowSpacing: 3 * root.scaleFactor
                    columnSpacing: 3 * root.scaleFactor
                    Repeater {
                        model: 16
                        delegate: Rectangle {
                            id: maskCell
                            required property int index
                            readonly property int row: Math.floor(index / 4)
                            readonly property int column: index % 4
                            readonly property bool allowed: column <= row
                            Layout.preferredWidth: 27 * root.scaleFactor
                            Layout.preferredHeight: 27 * root.scaleFactor
                            radius: 4 * root.scaleFactor
                            color: allowed ? Style.Theme.exito_fondo : Style.Theme.acento_fondo
                            border.color: allowed ? "#9BD5BD" : Style.Theme.error_fondo
                            Text { anchors.centerIn: parent; text: maskCell.allowed ? "✓" : "×"; color: maskCell.allowed ? Style.Theme.exito_texto : "#A45D60"; font.bold: true; font.pixelSize: 10 * root.scaleFactor }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: "Máscara causal"; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 10 * root.scaleFactor }
                    Text { Layout.fillWidth: true; text: "✓ pasado visible\n× futuro bloqueado"; color: Style.Theme.texto_secundario; font.pixelSize: 9 * root.scaleFactor; lineHeight: 1.3 }
                    Text { Layout.fillWidth: true; text: "La fila crece un token en cada paso."; color: Style.Theme.acento_fuerte; font.pixelSize: 8 * root.scaleFactor; wrapMode: Text.WordWrap }
                }
            }
        }
    }

    Component {
        id: trainingDemo
        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 5 * root.scaleFactor
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 3 * root.scaleFactor
                    DemoBlock { Layout.fillWidth: true; Layout.fillHeight: true; label: "Pérdida"; detail: "1.84"; fillColor: Style.Theme.aviso_fondo }
                    Text { text: "→"; color: Style.Theme.acento }
                    DemoBlock { Layout.fillWidth: true; Layout.fillHeight: true; label: "Gradiente"; detail: "∂L/∂θ" }
                    Text { text: "→"; color: Style.Theme.acento }
                    DemoBlock { Layout.fillWidth: true; Layout.fillHeight: true; label: "Optimizador"; detail: "−η · g"; fillColor: Style.Theme.borde_medio }
                    Text { text: "→"; color: Style.Theme.acento }
                    DemoBlock { Layout.fillWidth: true; Layout.fillHeight: true; label: "Parámetros"; detail: "θ nuevo"; fillColor: Style.Theme.exito_fondo }
                }
                Text { Layout.fillWidth: true; text: "Ejemplo fijo: η = 0.001 · no ejecuta entrenamiento real"; color: Style.Theme.texto_secundario; font.pixelSize: 7 * root.scaleFactor; horizontalAlignment: Text.AlignHCenter }
            }
        }
    }
}
