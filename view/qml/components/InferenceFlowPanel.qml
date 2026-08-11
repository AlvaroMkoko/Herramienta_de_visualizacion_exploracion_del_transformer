pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

Item {
    id: root

    property var snapshots: []
    property int selectedIndex: snapshots.length > 0 ? snapshots.length - 1 : -1
    property real sx: 1
    property real sy: 1
    property bool mostrarAtencionCruzada: true

    readonly property var currentSnapshot: (
        selectedIndex >= 0 && selectedIndex < snapshots.length
        ? snapshots[selectedIndex] : null
    )
    readonly property var stages: currentSnapshot && currentSnapshot.etapas
                                          ? currentSnapshot.etapas : []
    readonly property var attentionRows: currentSnapshot
        ? (mostrarAtencionCruzada ? currentSnapshot.foco_entrada
                                  : currentSnapshot.foco_decoder)
        : []
    readonly property var predictions: currentSnapshot && currentSnapshot.predicciones_top
                                                ? currentSnapshot.predicciones_top : []

    signal closeRequested()
    signal stepSelected(int index)

    function porcentaje(value) {
        return (Number(value || 0) * 100).toFixed(Number(value || 0) < 0.01 ? 2 : 1) + "%"
    }

    function maxAttention() {
        var maximo = 0
        for (var i = 0; i < root.attentionRows.length; ++i)
            maximo = Math.max(maximo, Number(root.attentionRows[i].peso || 0))
        return Math.max(maximo, 0.000001)
    }

    Rectangle {
        anchors.fill: parent
        color: "#F8FAFC"
        radius: 16 * root.sx
        border.color: "#CBD5E1"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20 * root.sx
            spacing: 13 * root.sy

            RowLayout {
                Layout.fillWidth: true
                spacing: 12 * root.sx

                Rectangle {
                    Layout.preferredWidth: 44 * root.sx
                    Layout.preferredHeight: 44 * root.sy
                    radius: 12 * root.sx
                    color: "#EDE9FE"

                    Text {
                        anchors.centerIn: parent
                        text: "⌁"
                        color: "#6D28D9"
                        font.bold: true
                        font.pixelSize: 25 * Math.min(root.sx, root.sy)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1 * root.sy

                    Text {
                        text: "Así construyó el Transformer su respuesta"
                        color: Style.Theme.texto_primario
                        font.bold: true
                        font.pixelSize: 23 * Math.min(root.sx, root.sy)
                    }
                    Text {
                        text: root.currentSnapshot
                              ? "Inspeccionando el token " + root.currentSnapshot.paso
                                + " de " + root.snapshots.length
                              : "Genera un token para comenzar el recorrido"
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 13 * Math.min(root.sx, root.sy)
                    }
                }

                Rectangle {
                    visible: root.currentSnapshot !== null
                    Layout.preferredWidth: 250 * root.sx
                    Layout.preferredHeight: 44 * root.sy
                    radius: 10 * root.sx
                    color: "#ECFDF5"
                    border.color: "#A7F3D0"

                    Row {
                        anchors.centerIn: parent
                        spacing: 8 * root.sx

                        Text {
                            text: "TOKEN ELEGIDO"
                            color: "#047857"
                            font.bold: true
                            font.pixelSize: 10 * Math.min(root.sx, root.sy)
                        }
                        Text {
                            text: root.currentSnapshot
                                  ? "“" + root.currentSnapshot.token_elegido.texto + "”" : ""
                            color: "#065F46"
                            font.bold: true
                            font.pixelSize: 17 * Math.min(root.sx, root.sy)
                        }
                        Text {
                            text: root.currentSnapshot
                                  ? root.porcentaje(root.currentSnapshot.token_elegido.probabilidad) : ""
                            color: "#047857"
                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                        }
                    }
                }

                Button {
                    Layout.preferredWidth: 42 * root.sx
                    Layout.preferredHeight: 42 * root.sy
                    text: "✕"
                    flat: true
                    font.pixelSize: 17 * Math.min(root.sx, root.sy)
                    onClicked: root.closeRequested()
                    ToolTip.visible: hovered
                    ToolTip.text: "Cerrar recorrido"
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "#E2E8F0"
            }

            Text {
                text: "RECORRIDO DE LOS DATOS · de izquierda a derecha"
                color: "#64748B"
                font.bold: true
                font.pixelSize: 10 * Math.min(root.sx, root.sy)
                font.letterSpacing: 1.1 * root.sx
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: 128 * root.sy
                clip: true
                contentWidth: flowRow.implicitWidth
                contentHeight: availableHeight
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                Row {
                    id: flowRow
                    spacing: 7 * root.sx

                    Repeater {
                        model: root.stages

                        delegate: Row {
                            id: stageDelegate
                            required property var modelData
                            required property int index
                            spacing: 7 * root.sx

                            Rectangle {
                                width: 237 * root.sx
                                height: 112 * root.sy
                                radius: 11 * root.sx
                                color: "#FFFFFF"
                                border.color: stageDelegate.modelData.color
                                border.width: stageDelegate.index === root.stages.length - 1 ? 2 : 1

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 10 * root.sx
                                    spacing: 3 * root.sy

                                    Row {
                                        width: parent.width
                                        spacing: 7 * root.sx
                                        Text {
                                            text: stageDelegate.modelData.numero
                                            color: stageDelegate.modelData.color
                                            font.bold: true
                                            font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                        }
                                        Text {
                                            text: stageDelegate.modelData.titulo
                                            color: "#0F172A"
                                            font.bold: true
                                            font.pixelSize: 14 * Math.min(root.sx, root.sy)
                                        }
                                    }
                                    Text {
                                        width: parent.width
                                        text: stageDelegate.modelData.dato
                                        color: stageDelegate.modelData.color
                                        font.bold: true
                                        font.pixelSize: 13 * Math.min(root.sx, root.sy)
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: stageDelegate.modelData.explicacion
                                        color: "#64748B"
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                        font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                    }
                                }
                            }

                            Text {
                                visible: stageDelegate.index < root.stages.length - 1
                                anchors.verticalCenter: parent.verticalCenter
                                text: "→"
                                color: "#94A3B8"
                                font.bold: true
                                font.pixelSize: 18 * Math.min(root.sx, root.sy)
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12 * root.sx

                Rectangle {
                    Layout.preferredWidth: 445 * root.sx
                    Layout.fillHeight: true
                    radius: 12 * root.sx
                    color: "#FFFFFF"
                    border.color: "#E2E8F0"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 13 * root.sx
                        spacing: 9 * root.sy

                        Text {
                            text: "1 · Qué entró y qué salió"
                            color: "#0F172A"
                            font.bold: true
                            font.pixelSize: 15 * Math.min(root.sx, root.sy)
                        }
                        Text {
                            text: "El prompt se codifica una vez; la salida crece un token por vuelta."
                            color: "#64748B"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            font.pixelSize: 11 * Math.min(root.sx, root.sy)
                        }

                        Text {
                            text: root.currentSnapshot
                                  ? "PROMPT · " + root.currentSnapshot.tokens_entrada_total + " tokens" : "PROMPT"
                            color: "#7C3AED"
                            font.bold: true
                            font.pixelSize: 10 * Math.min(root.sx, root.sy)
                        }
                        ListView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50 * root.sy
                            orientation: ListView.Horizontal
                            spacing: 5 * root.sx
                            clip: true
                            model: root.currentSnapshot ? root.currentSnapshot.tokens_entrada : []

                            delegate: Rectangle {
                                id: inputToken
                                required property var modelData
                                width: Math.max(55 * root.sx, inputLabel.implicitWidth + 18 * root.sx)
                                height: 40 * root.sy
                                radius: 7 * root.sx
                                color: "#F5F3FF"
                                border.color: "#DDD6FE"
                                Text {
                                    id: inputLabel
                                    anchors.centerIn: parent
                                    text: inputToken.modelData.texto
                                    color: "#5B21B6"
                                    font.bold: true
                                    font.pixelSize: 12 * Math.min(root.sx, root.sy)
                                }
                                ToolTip.visible: inputMouse.containsMouse
                                ToolTip.text: "posición " + inputToken.modelData.posicion
                                              + " · id " + inputToken.modelData.token_id
                                MouseArea { id: inputMouse; anchors.fill: parent; hoverEnabled: true }
                            }
                        }

                        Text {
                            text: "SALIDA · selecciona un token para reconstruir esa vuelta"
                            color: "#2563EB"
                            font.bold: true
                            font.pixelSize: 10 * Math.min(root.sx, root.sy)
                        }
                        ListView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 54 * root.sy
                            orientation: ListView.Horizontal
                            spacing: 5 * root.sx
                            clip: true
                            model: root.snapshots
                            currentIndex: root.selectedIndex

                            delegate: Rectangle {
                                id: outputToken
                                required property var modelData
                                required property int index
                                width: Math.max(55 * root.sx, outputLabel.implicitWidth + 18 * root.sx)
                                height: 42 * root.sy
                                radius: 8 * root.sx
                                color: outputToken.index === root.selectedIndex ? "#DBEAFE" : "#EFF6FF"
                                border.color: outputToken.index === root.selectedIndex ? "#2563EB" : "#BFDBFE"
                                border.width: outputToken.index === root.selectedIndex ? 2 : 1

                                Text {
                                    id: outputLabel
                                    anchors.centerIn: parent
                                    text: outputToken.modelData.token_elegido.texto
                                    color: "#1D4ED8"
                                    font.bold: true
                                    font.pixelSize: 12 * Math.min(root.sx, root.sy)
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.stepSelected(outputToken.index)
                                }
                                ToolTip.visible: outputMouse.containsMouse
                                ToolTip.text: "token " + (outputToken.index + 1)
                                MouseArea { id: outputMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: "#E2E8F0"
                        }

                        Text {
                            text: "LECTURA DE LAS CAPAS"
                            color: "#64748B"
                            font.bold: true
                            font.pixelSize: 10 * Math.min(root.sx, root.sy)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5 * root.sx

                            Repeater {
                                model: root.currentSnapshot ? [
                                    { name: "Encoder", rows: root.currentSnapshot.atencion_por_bloque.encoder, color: "#D97706" },
                                    { name: "Causal", rows: root.currentSnapshot.atencion_por_bloque.decoder, color: "#2563EB" },
                                    { name: "Cruzada", rows: root.currentSnapshot.atencion_por_bloque.cruzada, color: "#7C3AED" }
                                ] : []

                                delegate: Rectangle {
                                    id: layerSummary
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 69 * root.sy
                                    radius: 8 * root.sx
                                    color: "#F8FAFC"
                                    border.color: "#E2E8F0"

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 3 * root.sy
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: layerSummary.modelData.name
                                            color: layerSummary.modelData.color
                                            font.bold: true
                                            font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: layerSummary.modelData.rows.length + " capas"
                                            color: "#334155"
                                            font.bold: true
                                            font.pixelSize: 13 * Math.min(root.sx, root.sy)
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: layerSummary.modelData.rows.length
                                                  ? "pico " + Number(layerSummary.modelData.rows[layerSummary.modelData.rows.length - 1].pico).toFixed(2)
                                                  : "sin datos"
                                            color: "#64748B"
                                            font.pixelSize: 9 * Math.min(root.sx, root.sy)
                                        }
                                    }
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 520 * root.sx
                    radius: 12 * root.sx
                    color: "#FFFFFF"
                    border.color: "#E2E8F0"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 13 * root.sx
                        spacing: 8 * root.sy

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: "2 · De dónde tomó información"
                                color: "#0F172A"
                                font.bold: true
                                font.pixelSize: 15 * Math.min(root.sx, root.sy)
                            }
                            Button {
                                text: "Prompt"
                                checkable: true
                                checked: root.mostrarAtencionCruzada
                                onClicked: root.mostrarAtencionCruzada = true
                            }
                            Button {
                                text: "Salida previa"
                                checkable: true
                                checked: !root.mostrarAtencionCruzada
                                onClicked: root.mostrarAtencionCruzada = false
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.mostrarAtencionCruzada
                                  ? "Atención cruzada · cuánto pesó cada token del prompt en esta decisión."
                                  : "Atención causal · qué tokens ya generados podía consultar el decoder."
                            color: "#64748B"
                            wrapMode: Text.WordWrap
                            font.pixelSize: 11 * Math.min(root.sx, root.sy)
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 5 * root.sy
                            model: root.attentionRows

                            delegate: Item {
                                id: attentionDelegate
                                required property var modelData
                                width: ListView.view.width
                                height: 36 * root.sy

                                Text {
                                    id: attentionToken
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 92 * root.sx
                                    text: attentionDelegate.modelData.texto
                                    color: "#334155"
                                    font.bold: true
                                    elide: Text.ElideRight
                                    font.pixelSize: 11 * Math.min(root.sx, root.sy)
                                }
                                Rectangle {
                                    id: attentionTrack
                                    anchors.left: attentionToken.right
                                    anchors.right: attentionValue.left
                                    anchors.leftMargin: 8 * root.sx
                                    anchors.rightMargin: 8 * root.sx
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 13 * root.sy
                                    radius: height / 2
                                    color: "#EEF2FF"

                                    Rectangle {
                                        width: Math.max(2, parent.width * Number(attentionDelegate.modelData.peso) / root.maxAttention())
                                        height: parent.height
                                        radius: parent.radius
                                        color: root.mostrarAtencionCruzada ? "#8B5CF6" : "#3B82F6"
                                        Behavior on width { NumberAnimation { duration: 180 } }
                                    }
                                }
                                Text {
                                    id: attentionValue
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 58 * root.sx
                                    horizontalAlignment: Text.AlignRight
                                    text: root.porcentaje(attentionDelegate.modelData.peso)
                                    color: "#475569"
                                    font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 46 * root.sy
                            radius: 8 * root.sx
                            color: "#F5F3FF"
                            Text {
                                anchors.fill: parent
                                anchors.margins: 9 * root.sx
                                verticalAlignment: Text.AlignVCenter
                                text: "Las barras usan la última capa y promedian todas las cabezas. "
                                      + "No indican causalidad: muestran la mezcla de atención usada por el cálculo."
                                color: "#5B21B6"
                                wrapMode: Text.WordWrap
                                font.pixelSize: 9 * Math.min(root.sx, root.sy)
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 425 * root.sx
                    Layout.fillHeight: true
                    radius: 12 * root.sx
                    color: "#FFFFFF"
                    border.color: "#E2E8F0"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 13 * root.sx
                        spacing: 7 * root.sy

                        Text {
                            text: "3 · Cómo eligió el siguiente token"
                            color: "#0F172A"
                            font.bold: true
                            font.pixelSize: 15 * Math.min(root.sx, root.sy)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.currentSnapshot
                                  ? root.currentSnapshot.modo_muestreo + " · "
                                    + root.currentSnapshot.filtros : ""
                            color: "#64748B"
                            wrapMode: Text.WordWrap
                            font.pixelSize: 11 * Math.min(root.sx, root.sy)
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 4 * root.sy
                            model: root.predictions

                            delegate: Rectangle {
                                id: predictionDelegate
                                required property var modelData
                                width: ListView.view.width
                                height: 40 * root.sy
                                radius: 7 * root.sx
                                color: predictionDelegate.modelData.elegido ? "#ECFDF5" : "#F8FAFC"
                                border.color: predictionDelegate.modelData.elegido ? "#34D399" : "#E2E8F0"

                                Text {
                                    id: predictionToken
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8 * root.sx
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 78 * root.sx
                                    text: predictionDelegate.modelData.texto
                                    color: predictionDelegate.modelData.elegido ? "#047857" : "#334155"
                                    font.bold: true
                                    elide: Text.ElideRight
                                    font.pixelSize: 11 * Math.min(root.sx, root.sy)
                                }
                                Rectangle {
                                    anchors.left: predictionToken.right
                                    anchors.right: predictionProbability.left
                                    anchors.leftMargin: 7 * root.sx
                                    anchors.rightMargin: 7 * root.sx
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 11 * root.sy
                                    radius: height / 2
                                    color: "#E2E8F0"
                                    Rectangle {
                                        width: parent.width * Number(predictionDelegate.modelData.probabilidad)
                                        height: parent.height
                                        radius: parent.radius
                                        color: predictionDelegate.modelData.elegido ? "#10B981" : "#94A3B8"
                                    }
                                }
                                Text {
                                    id: predictionProbability
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8 * root.sx
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 58 * root.sx
                                    text: root.porcentaje(predictionDelegate.modelData.probabilidad)
                                    color: predictionDelegate.modelData.elegido ? "#047857" : "#475569"
                                    horizontalAlignment: Text.AlignRight
                                    font.bold: predictionDelegate.modelData.elegido
                                    font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 82 * root.sy
                            radius: 9 * root.sx
                            color: "#F0FDF4"
                            border.color: "#BBF7D0"
                            Column {
                                anchors.fill: parent
                                anchors.margins: 9 * root.sx
                                spacing: 3 * root.sy
                                Text {
                                    text: root.currentSnapshot
                                          ? "Elegido: “" + root.currentSnapshot.token_elegido.texto
                                            + "” · puesto #" + root.currentSnapshot.token_elegido.rango : ""
                                    color: "#166534"
                                    font.bold: true
                                    font.pixelSize: 12 * Math.min(root.sx, root.sy)
                                }
                                Text {
                                    text: root.currentSnapshot
                                          ? root.currentSnapshot.cantidad_candidatos + " candidatos tras filtros"
                                            + " · entropía " + Number(root.currentSnapshot.entropia_salida).toFixed(2) : ""
                                    color: "#15803D"
                                    font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                }
                                Text {
                                    width: parent.width
                                    text: "Al añadirse a la salida, este token se convierte en contexto de la siguiente vuelta."
                                    color: "#166534"
                                    wrapMode: Text.WordWrap
                                    font.pixelSize: 9 * Math.min(root.sx, root.sy)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
