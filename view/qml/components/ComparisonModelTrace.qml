pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

Rectangle {
    id: root
    objectName: "comparisonModelTrace" + modelLabel.slice(-1)

    property string modelLabel: "MODELO A"
    property var modelInfo: ({})
    property var snapshot: ({})
    property var lastSnapshot: ({})
    property string generationStatus: "Listo"
    property int generatedTokenCount: 0
    property bool generationActive: false
    property int selectedStep: 0
    property int stageIndex: 0
    property color accent: Style.Theme.acento
    property color accentBackground: Style.Theme.acento_fondo
    property real sx: 1
    property real sy: 1

    readonly property bool hasSnapshot: snapshot
                                                && snapshot.token_elegido !== undefined
    readonly property bool generationFinished: !generationActive
            && (generationStatus === "Completada"
                || generationStatus === "Detenida"
                || generationStatus.indexOf("Error") === 0)
    readonly property string fullModelName: String(
            root.modelValue(["nombre", "name"], "Modelo"))
    readonly property string compactModelName: root.compactName(fullModelName)
    readonly property var stageEntries: {
        if (!hasSnapshot)
            return []
        if (stageIndex === 0)
            return snapshot.foco_encoder || []
        if (stageIndex === 1)
            return snapshot.foco_decoder || []
        if (stageIndex === 2)
            return snapshot.foco_entrada || []
        return snapshot.predicciones_top || []
    }
    readonly property string stageTitle: [
        "Encoder · autoatención",
        "Decoder · atención causal",
        "Decoder · atención cruzada",
        "Salida · candidatos"
    ][Math.max(0, Math.min(3, stageIndex))]
    readonly property string baseStageExplanation: [
        "La última posición del prompt combina información de todos los tokens. Las barras muestran la atención media de la última capa.",
        "El decoder solo puede mirar el inicio y los tokens ya generados; nunca ve tokens futuros.",
        "El decoder consulta la memoria del encoder. Una barra mayor indica más atención sobre ese token del prompt.",
        "La proyección final y Softmax producen candidatos. El borde resalta el token que este modelo eligió."
    ][Math.max(0, Math.min(3, stageIndex))]
    readonly property bool trivialAttention: hasSnapshot && stageIndex < 3
                                               && stageEntries.length === 1
    readonly property string stageExplanation: baseStageExplanation
            + (trivialAttention
               ? " Solo hay una posición disponible; por eso recibe 100 % de atención. No representa una preferencia entre varios tokens."
               : "")
    readonly property string lastTokenText: lastSnapshot
            && lastSnapshot.token_elegido !== undefined
            ? String(lastSnapshot.token_elegido.texto) : ""
    readonly property string terminalTitle: {
        if (generationStatus === "Completada")
            return "Generación finalizada"
        if (generationStatus === "Detenida")
            return "Generación detenida"
        if (generationStatus.indexOf("Error") === 0)
            return "La generación encontró un error"
        if (generationActive)
            return "Esperando este paso"
        return "Sin traza para este paso"
    }
    readonly property string terminalDetail: {
        if (generationFinished) {
            var countText = generatedTokenCount + (generatedTokenCount === 1
                                                    ? " token" : " tokens")
            var detail = "Este modelo produjo " + countText
                    + " y terminó antes del paso " + selectedStep + "."
            if (lastTokenText)
                detail += " Su último token fue “" + lastTokenText + "”."
            return detail
        }
        if (generationActive)
            return "El otro modelo llegó primero. Este panel se actualizará cuando este modelo complete el paso."
        return "Este modelo no produjo un token alineado con el paso seleccionado."
    }
    readonly property var metrics: root.metricItems()

    function modelValue(names, fallback) {
        for (var i = 0; i < names.length; ++i) {
            var value = root.modelInfo ? root.modelInfo[names[i]] : undefined
            if (value !== undefined && value !== null && value !== "")
                return value
        }
        return fallback
    }

    function compactName(name) {
        var text = String(name)
        if (text.length <= 54)
            return text
        return text.substring(0, 33) + "…"
                + text.substring(text.length - 18)
    }

    function attentionLayers(kind) {
        if (!root.hasSnapshot || !root.snapshot.atencion_por_bloque)
            return []
        return root.snapshot.atencion_por_bloque[kind] || []
    }

    function lastAttention(kind) {
        var layers = root.attentionLayers(kind)
        return layers.length ? layers[layers.length - 1] : ({})
    }

    function decimal(value, digits) {
        var number = Number(value)
        return isFinite(number) ? number.toFixed(digits) : "—"
    }

    function percentage(value) {
        var number = Number(value)
        return isFinite(number) ? (number * 100).toFixed(number < 0.01 ? 2 : 1) + "%" : "—"
    }

    function metricItems() {
        if (!root.hasSnapshot)
            return []
        if (root.stageIndex === 3) {
            return [
                { "label": "CANDIDATOS", "value": root.snapshot.cantidad_candidatos || 0 },
                { "label": "ENTROPÍA", "value": root.decimal(root.snapshot.entropia_salida, 2) },
                { "label": "ELEGIDO", "value": root.percentage(root.snapshot.token_elegido.probabilidad) }
            ]
        }
        var kind = root.stageIndex === 0 ? "encoder"
                 : (root.stageIndex === 1 ? "decoder" : "cruzada")
        var layers = root.attentionLayers(kind)
        var last = root.lastAttention(kind)
        return [
            { "label": "CAPAS", "value": layers.length },
            { "label": "PICO", "value": root.percentage(last.pico) },
            { "label": "ENTROPÍA", "value": root.decimal(last.entropia, 2) }
        ]
    }

    function entryText(entry) {
        if (!entry)
            return "—"
        return String(entry.texto === undefined ? "—" : entry.texto)
    }

    function entryValue(entry) {
        if (!entry)
            return 0
        return Number(root.stageIndex === 3 ? entry.probabilidad : entry.peso) || 0
    }

    function entryDetail(entry) {
        if (!entry)
            return ""
        if (root.stageIndex === 3)
            return "#" + String(entry.rango || "—") + " · " + root.percentage(entry.probabilidad)
        return "pos. " + String(Number(entry.posicion || 0) + 1)
                + " · " + root.percentage(entry.peso)
    }

    radius: 13 * Math.min(sx, sy)
    color: Style.Theme.surface
    border.width: 1
    border.color: root.accent
    clip: true
    Accessible.name: root.modelLabel + ": "
                     + String(root.modelValue(["nombre", "name"], "Modelo"))
    Accessible.description: root.hasSnapshot
            ? root.stageTitle + ". Token elegido "
              + String(root.snapshot.token_elegido.texto)
            : "Sin traza para el paso seleccionado"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15 * root.sx
        spacing: 10 * root.sy

        RowLayout {
            Layout.fillWidth: true
            spacing: 9 * root.sx

            Rectangle {
                Layout.preferredWidth: 84 * root.sx
                Layout.preferredHeight: 27 * root.sy
                radius: height / 2
                color: root.accentBackground

                Text {
                    anchors.centerIn: parent
                    text: root.modelLabel
                    color: root.accent
                    font.bold: true
                    font.pixelSize: 10 * Math.min(root.sx, root.sy)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    id: modelName
                    Layout.fillWidth: true
                    text: root.compactModelName
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 17 * Math.min(root.sx, root.sy)
                    elide: Text.ElideRight
                    ToolTip.visible: modelNameMouse.containsMouse
                    ToolTip.text: root.fullModelName

                    MouseArea {
                        id: modelNameMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "L" + root.modelValue(["num_capas", "encoder_layers"], "—")
                          + " · H" + root.modelValue(["num_cabezas"], "—")
                          + " · d=" + root.modelValue(["dimension_modelo"], "—")
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 11 * Math.min(root.sx, root.sy)
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                visible: root.hasSnapshot
                Layout.preferredWidth: Math.max(92 * root.sx,
                                                chosenToken.implicitWidth + 18 * root.sx)
                Layout.preferredHeight: 34 * root.sy
                radius: 9 * root.sx
                color: Style.Theme.exito_fondo
                border.color: Style.Theme.exito_texto

                Text {
                    id: chosenToken
                    anchors.centerIn: parent
                    text: root.hasSnapshot
                          ? "Token: “" + root.snapshot.token_elegido.texto + "”" : ""
                    color: Style.Theme.exito_texto
                    font.bold: true
                    font.pixelSize: 11 * Math.min(root.sx, root.sy)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Style.Theme.divisor
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                visible: root.hasSnapshot
                anchors.fill: parent
                spacing: 8 * root.sy

                Text {
                    Layout.fillWidth: true
                    text: root.stageTitle
                    color: root.accent
                    font.bold: true
                    font.pixelSize: 15 * Math.min(root.sx, root.sy)
                }

                Text {
                    Layout.fillWidth: true
                    text: root.stageExplanation
                    color: Style.Theme.texto_secundario_fuerte
                    wrapMode: Text.WordWrap
                    lineHeight: 1.08
                    font.pixelSize: 11 * Math.min(root.sx, root.sy)
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48 * root.sy
                    Layout.minimumHeight: 48 * root.sy
                    Layout.maximumHeight: 48 * root.sy
                    spacing: 7 * root.sx

                    Repeater {
                        model: root.metrics

                        delegate: Rectangle {
                            id: metricCard
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 7 * root.sx
                            color: root.accentBackground

                            Column {
                                anchors.centerIn: parent
                                spacing: 1 * root.sy
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: String(metricCard.modelData.value)
                                    color: root.accent
                                    font.bold: true
                                    font.pixelSize: 14 * Math.min(root.sx, root.sy)
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: metricCard.modelData.label
                                    color: Style.Theme.texto_secundario
                                    font.bold: true
                                    font.pixelSize: 8 * Math.min(root.sx, root.sy)
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.stageIndex === 3
                          ? "Distribución después de los filtros de generación"
                          : "Peso medio de atención · última consulta"
                    color: Style.Theme.texto_secundario
                    font.bold: true
                    font.pixelSize: 10 * Math.min(root.sx, root.sy)
                }

                ListView {
                    id: valuesList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 5 * root.sy
                    model: root.stageEntries
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        id: valueRow
                        required property var modelData
                        required property int index
                        readonly property real amount: Math.max(
                            0, Math.min(1, root.entryValue(modelData)))
                        readonly property bool chosen: root.stageIndex === 3
                                                       && Boolean(modelData.elegido)

                        width: valuesList.width - 7 * root.sx
                        height: 38 * root.sy
                        radius: 7 * root.sx
                        color: chosen ? Style.Theme.exito_fondo
                                      : Style.Theme.superficie_alterna
                        border.width: chosen ? 2 : 1
                        border.color: chosen ? Style.Theme.exito_texto
                                             : Style.Theme.borde_suave

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 9 * root.sx
                            anchors.rightMargin: 9 * root.sx
                            spacing: 8 * root.sx

                            Text {
                                Layout.preferredWidth: 112 * root.sx
                                text: "“" + root.entryText(valueRow.modelData) + "”"
                                color: valueRow.chosen ? Style.Theme.exito_texto
                                                       : Style.Theme.texto_primario
                                font.bold: valueRow.chosen
                                elide: Text.ElideRight
                                font.pixelSize: 11 * Math.min(root.sx, root.sy)
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 9 * root.sy
                                radius: height / 2
                                color: Style.Theme.borde_medio

                                Rectangle {
                                    width: parent.width * valueRow.amount
                                    height: parent.height
                                    radius: height / 2
                                    color: valueRow.chosen ? Style.Theme.exito_texto
                                                           : root.accent
                                }
                            }

                            Text {
                                Layout.preferredWidth: 104 * root.sx
                                text: root.entryDetail(valueRow.modelData)
                                color: Style.Theme.texto_secundario
                                horizontalAlignment: Text.AlignRight
                                font.pixelSize: 10 * Math.min(root.sx, root.sy)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: valuesList.count === 0
                        text: "Esta traza no contiene datos para la etapa."
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 12 * Math.min(root.sx, root.sy)
                    }
                }
            }

            Rectangle {
                visible: !root.hasSnapshot
                anchors.centerIn: parent
                width: Math.min(parent.width - 30 * root.sx, 480 * root.sx)
                height: emptyState.implicitHeight + 34 * root.sy
                radius: 12 * root.sx
                color: root.generationFinished ? Style.Theme.exito_fondo
                                               : Style.Theme.info_fondo
                border.color: root.generationFinished ? Style.Theme.exito_texto
                                                      : root.accent

                Column {
                    id: emptyState
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 20 * root.sx
                    anchors.rightMargin: 20 * root.sx
                    spacing: 7 * root.sy

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.generationFinished ? "✓" : "…"
                        color: root.generationFinished ? Style.Theme.exito_texto
                                                      : root.accent
                        font.bold: true
                        font.pixelSize: 28 * Math.min(root.sx, root.sy)
                    }
                    Text {
                        width: parent.width
                        text: root.terminalTitle
                        color: Style.Theme.texto_primario
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.pixelSize: 15 * Math.min(root.sx, root.sy)
                    }
                    Text {
                        width: parent.width
                        text: root.terminalDetail
                        color: Style.Theme.texto_secundario
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12 * Math.min(root.sx, root.sy)
                    }
                }
            }
        }
    }
}
