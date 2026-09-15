pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../styles" as Style

Item {
    id: root
    objectName: "outputProjectionScene"

    property var snapshot: null
    property var logitsData: ({})
    property var hiddenData: ({})
    property bool active: false
    property bool reducedMotion: false
    property real sx: 1
    property real sy: 1
    property real progress: 0

    readonly property var hiddenMatrix: hiddenData && hiddenData.matriz
                                                ? hiddenData.matriz : ({})
    readonly property var hiddenRows: hiddenMatrix && hiddenMatrix.valores
                                              ? hiddenMatrix.valores : []
    readonly property var finalHidden: hiddenRows.length
                                              ? (hiddenRows[hiddenRows.length - 1] || []) : []
    readonly property var histogram: logitsData && logitsData.histograma
                                             ? logitsData.histograma : ({})
    readonly property var histogramCounts: histogram && histogram.conteos
                                                   ? histogram.conteos : []
    readonly property var histogramEdges: histogram && histogram.bordes
                                                  ? histogram.bordes : []
    readonly property var logitsStatistics: logitsData && logitsData.estadisticas
                                                    ? logitsData.estadisticas : ({})
    readonly property var candidates: snapshot && snapshot.predicciones_top
                                              ? snapshot.predicciones_top : []
    readonly property bool hasData: finalHidden.length > 0
                                    || histogramCounts.length > 0
                                    || candidates.length > 0
    readonly property real histogramMaximum: maximum(histogramCounts, false)
    readonly property real candidateMaximumProbability: maximumCandidate("probabilidad", false)

    function maximum(values, absolute) {
        var result = 0
        if (!values)
            return result
        for (var i = 0; i < values.length; ++i) {
            var value = Number(values[i])
            if (!Number.isFinite(value))
                continue
            result = Math.max(result, absolute ? Math.abs(value) : value)
        }
        return result
    }

    function maximumCandidate(field, absolute) {
        var result = 0
        for (var i = 0; i < candidates.length; ++i) {
            var value = Number(candidates[i][field])
            if (!Number.isFinite(value))
                continue
            result = Math.max(result, absolute ? Math.abs(value) : value)
        }
        return result
    }

    function formatNumber(value) {
        var number = Number(value)
        if (!Number.isFinite(number))
            return "—"
        var absolute = Math.abs(number)
        if (absolute !== 0 && (absolute >= 1000 || absolute < 0.001))
            return number.toExponential(2)
        return number.toFixed(absolute >= 10 ? 2 : 4)
    }

    function reveal(start, span) {
        if (reducedMotion)
            return 1
        return Math.max(0, Math.min(1, (progress - start) / Math.max(0.001, span)))
    }

    function hiddenColor(value) {
        var maximumValue = maximum(finalHidden, true)
        var numeric = Number(value)
        var ratio = maximumValue > 0 ? Math.min(1, Math.abs(numeric) / maximumValue) : 0
        return numeric >= 0
                ? Qt.rgba(0.15, 0.39, 0.92, 0.18 + ratio * 0.72)
                : Qt.rgba(0.88, 0.18, 0.31, 0.18 + ratio * 0.72)
    }

    function replay() {
        projectionAnimation.stop()
        progress = 0
        if (reducedMotion)
            progress = 1
        else
            projectionAnimation.start()
    }

    onActiveChanged: {
        if (active)
            replay()
        else
            projectionAnimation.stop()
    }
    onSnapshotChanged: {
        if (active)
            replay()
    }
    onLogitsDataChanged: {
        if (active)
            replay()
    }
    onHiddenDataChanged: {
        if (active)
            replay()
    }

    NumberAnimation {
        id: projectionAnimation
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 2500
        easing.type: Easing.InOutCubic
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 9 * root.sy

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 50 * root.sy
            spacing: 9 * root.sx

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1 * root.sy
                Text {
                    text: "Del estado final a los logits del vocabulario"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: Math.max(18, 18 * Math.min(root.sx, root.sy))
                }
                Text {
                    Layout.fillWidth: true
                    text: "h_final · W_vocab + b → un puntaje real por token"
                    color: Style.Theme.texto_secundario
                    elide: Text.ElideRight
                    font.pixelSize: Math.max(11, 11 * root.sx)
                }
            }

            SceneButton {
                label: "↻ Reproducir"
                sx: root.sx
                sy: root.sy
                onClicked: root.replay()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 83 * root.sy
            spacing: 8 * root.sx

            PipelineCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                number: "1"
                eyebrow: "ESTADO FINAL DEL DECODER"
                title: root.hiddenData && root.hiddenData.shape
                       ? String(root.hiddenData.shape) : "Sin captura"
                detail: root.finalHidden.length
                        ? root.finalHidden.length + " dimensiones visibles"
                        : "La última posición alimenta Linear"
                accent: Style.Theme.acento
                emphasized: true
                sx: root.sx
                sy: root.sy
            }

            FlowArrow {
                Layout.preferredWidth: 44 * root.sx
                progress: root.reveal(0.10, 0.20)
                accent: Style.Theme.acento
                sx: root.sx
                sy: root.sy
            }

            PipelineCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                number: "2"
                eyebrow: "PROYECCIÓN LINEAL"
                title: "z = hW_vocab + b"
                detail: "Los pesos no se copian a la vista"
                accent: "#2563EB"
                emphasized: root.progress >= 0.28
                sx: root.sx
                sy: root.sy
            }

            FlowArrow {
                Layout.preferredWidth: 44 * root.sx
                progress: root.reveal(0.38, 0.20)
                accent: "#2563EB"
                sx: root.sx
                sy: root.sy
            }

            PipelineCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                number: "3"
                eyebrow: "LOGITS"
                title: root.logitsData && root.logitsData.shape
                       ? String(root.logitsData.shape) : "Sin captura"
                detail: root.histogram && root.histogram.total !== undefined
                        ? root.histogram.total + " valores resumidos" : "Puntajes sin normalizar"
                accent: Style.Theme.error
                emphasized: root.progress >= 0.58
                sx: root.sx
                sy: root.sy
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10 * root.sx

            ColumnLayout {
                Layout.preferredWidth: 390 * root.sx
                Layout.fillHeight: true
                spacing: 8 * root.sy

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 92 * root.sy
                    radius: 12 * root.sx
                    color: Style.Theme.acento_fondo
                    border.color: Style.Theme.acento_alt

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 9 * root.sx
                        spacing: 5 * root.sy
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: "h FINAL · MUESTRA EXACTA"
                                color: Style.Theme.acento_fuerte
                                font.bold: true
                                font.pixelSize: Math.max(9, 9 * root.sx)
                            }
                            Text {
                                text: root.hiddenMatrix && root.hiddenMatrix.displayed_shape
                                      ? String(root.hiddenMatrix.displayed_shape) : "—"
                                color: Style.Theme.acento
                                font.pixelSize: Math.max(9, 9 * root.sx)
                            }
                        }
                        ListView {
                            id: hiddenStrip
                            objectName: "outputHiddenVector"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            orientation: ListView.Horizontal
                            clip: true
                            spacing: 3 * root.sx
                            model: root.finalHidden
                            delegate: Rectangle {
                                id: hiddenCell
                                required property var modelData
                                required property int index
                                width: 38 * root.sx
                                height: hiddenStrip.height
                                radius: 6 * root.sx
                                color: root.hiddenColor(modelData)
                                border.color: Number(modelData) >= 0 ? Style.Theme.acento_alt : "#FB7185"
                                opacity: root.reveal(Math.min(index, 18) * 0.012, 0.30)
                                Column {
                                    anchors.centerIn: parent
                                    width: parent.width - 4 * root.sx
                                    spacing: 2 * root.sy
                                    Text {
                                        width: parent.width
                                        text: "d" + hiddenCell.index
                                        color: Style.Theme.texto_secundario
                                        horizontalAlignment: Text.AlignHCenter
                                        font.pixelSize: Math.max(9, 8 * root.sx)
                                    }
                                    Text {
                                        width: parent.width
                                        text: root.formatNumber(hiddenCell.modelData)
                                        color: Style.Theme.texto_primario
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        font.pixelSize: Math.max(9, 8 * root.sx)
                                    }
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !root.finalHidden.length
                                text: "Estado oculto no disponible"
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 9 * root.sx
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12 * root.sx
                    color: Style.Theme.fondo
                    border.color: "#FCA5A5"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10 * root.sx
                        spacing: 7 * root.sy

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: "DISTRIBUCIÓN DE LOGITS"
                                color: Style.Theme.error_texto
                                font.bold: true
                                font.pixelSize: 9 * root.sx
                            }
                            Text {
                                text: root.logitsData && root.logitsData.dtype
                                      ? String(root.logitsData.dtype) : "—"
                                color: Style.Theme.error_texto
                                font.pixelSize: Math.max(9, 9 * root.sx)
                            }
                        }

                        Item {
                            id: histogramPlot
                            objectName: "outputLogitsHistogram"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 120 * root.sy

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: "#FCA5A5"
                            }

                            Repeater {
                                model: root.histogramCounts
                                delegate: Rectangle {
                                    id: histogramBar
                                    required property var modelData
                                    required property int index
                                    readonly property real fraction: root.histogramMaximum > 0
                                            ? Number(modelData) / root.histogramMaximum : 0
                                    x: index * histogramPlot.width
                                       / Math.max(1, root.histogramCounts.length) + 1 * root.sx
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 16 * root.sy
                                    width: Math.max(2 * root.sx,
                                                    histogramPlot.width
                                                    / Math.max(1, root.histogramCounts.length)
                                                    - 3 * root.sx)
                                    height: Math.max(1,
                                                     (histogramPlot.height - 18 * root.sy)
                                                     * fraction
                                                     * root.reveal(0.46
                                                         + Math.min(index, 16) * 0.012,
                                                         0.28))
                                    radius: 3 * root.sx
                                    color: Style.Theme.error
                                    opacity: 0.82
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 2 * root.sy
                                text: root.histogramEdges.length
                                      ? root.formatNumber(root.histogramEdges[0]) : "—"
                                color: Style.Theme.error_texto
                                font.pixelSize: Math.max(9, 8 * root.sx)
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 2 * root.sy
                                text: root.histogramEdges.length
                                      ? root.formatNumber(root.histogramEdges[
                                          root.histogramEdges.length - 1]) : "—"
                                color: Style.Theme.error_texto
                                font.pixelSize: Math.max(9, 8 * root.sx)
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !root.histogramCounts.length
                                text: "Histograma no disponible"
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 10 * root.sx
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 45 * root.sy
                            spacing: 5 * root.sx
                            MetricChip {
                                Layout.fillWidth: true
                                label: "MÍN."
                                value: root.logitsStatistics.minimo !== undefined
                                       ? String(root.logitsStatistics.minimo) : "—"
                                sx: root.sx
                                sy: root.sy
                            }
                            MetricChip {
                                Layout.fillWidth: true
                                label: "MÁX."
                                value: root.logitsStatistics.maximo !== undefined
                                       ? String(root.logitsStatistics.maximo) : "—"
                                sx: root.sx
                                sy: root.sy
                            }
                            MetricChip {
                                Layout.fillWidth: true
                                label: "MEDIA"
                                value: root.logitsStatistics.media !== undefined
                                       ? String(root.logitsStatistics.media) : "—"
                                sx: root.sx
                                sy: root.sy
                            }
                            MetricChip {
                                Layout.fillWidth: true
                                label: "DESV."
                                value: root.logitsStatistics.desviacion !== undefined
                                       ? String(root.logitsStatistics.desviacion) : "—"
                                sx: root.sx
                                sy: root.sy
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12 * root.sx
                color: Style.Theme.superficie_alterna
                border.color: Style.Theme.borde_medio
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10 * root.sx
                    spacing: 7 * root.sy

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "TOP CAPTURADO"
                            color: Style.Theme.texto_secundario
                            font.bold: true
                            font.pixelSize: 9 * root.sx
                        }
                        Text {
                            text: "logit de Linear · probabilidad posterior"
                            color: Style.Theme.texto_secundario
                            font.pixelSize: Math.max(9, 9 * root.sx)
                        }
                    }

                    ListView {
                        id: candidateList
                        objectName: "outputProjectionCandidates"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 5 * root.sy
                        model: root.candidates

                        delegate: Rectangle {
                            id: candidateRow
                            required property var modelData
                            required property int index
                            readonly property bool chosen: Boolean(modelData.elegido)
                            readonly property real logit: Number(modelData.logit)
                            readonly property real probability: Number(modelData.probabilidad || 0)
                            width: ListView.view.width
                            height: 51 * root.sy
                            radius: 8 * root.sx
                            color: chosen ? Style.Theme.exito_fondo : "#FFFFFF"
                            border.color: chosen ? Style.Theme.success : Style.Theme.borde_medio
                            border.width: chosen ? 2 : 1
                            opacity: root.reveal(0.64 + Math.min(index, 8) * 0.025, 0.22)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6 * root.sx
                                spacing: 7 * root.sx

                                Rectangle {
                                    Layout.preferredWidth: 36 * root.sx
                                    Layout.preferredHeight: 28 * root.sy
                                    radius: 7 * root.sx
                                    color: candidateRow.chosen ? Style.Theme.success : Style.Theme.error
                                    Text {
                                        anchors.centerIn: parent
                                        text: candidateRow.modelData.rango !== undefined
                                              ? "#" + candidateRow.modelData.rango
                                              : String(candidateRow.index + 1)
                                        color: Style.Theme.texto_sobre_color
                                        font.bold: true
                                        font.pixelSize: Math.max(9, 9 * root.sx)
                                    }
                                }

                                ColumnLayout {
                                    Layout.preferredWidth: 112 * root.sx
                                    spacing: 0
                                    Text {
                                        Layout.fillWidth: true
                                        text: candidateRow.modelData.texto !== undefined
                                              ? "“" + String(candidateRow.modelData.texto) + "”"
                                              : "Sin etiqueta"
                                        color: Style.Theme.texto_primario
                                        font.bold: true
                                        elide: Text.ElideRight
                                        font.pixelSize: 10 * root.sx
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: candidateRow.modelData.token_id !== undefined
                                              ? "id " + candidateRow.modelData.token_id : "id —"
                                        color: Style.Theme.texto_secundario
                                        font.pixelSize: Math.max(9, 9 * root.sx)
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2 * root.sy
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: "logit " + root.formatNumber(candidateRow.logit)
                                            color: candidateRow.logit >= 0 ? Style.Theme.info_texto : "#BE123C"
                                            font.bold: true
                                            font.pixelSize: Math.max(9, 9 * root.sx)
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: (candidateRow.probability * 100).toFixed(
                                                      candidateRow.probability < 0.01 ? 2 : 1) + "%"
                                            color: candidateRow.chosen ? Style.Theme.exito_texto : Style.Theme.texto_secundario
                                            font.bold: true
                                            font.pixelSize: Math.max(9, 9 * root.sx)
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 12 * root.sy
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: height / 2
                                            color: Style.Theme.borde_medio
                                        }
                                        Rectangle {
                                            width: parent.width
                                                   * (root.candidateMaximumProbability > 0
                                                      ? Math.min(1,
                                                         candidateRow.probability
                                                         / root.candidateMaximumProbability) : 0)
                                            height: parent.height
                                            radius: height / 2
                                            color: candidateRow.chosen ? Style.Theme.success : "#2563EB"
                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: root.reducedMotion ? 0 : 400
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !root.candidates.length
                            text: "Los candidatos aparecerán después de proyectar el estado final."
                            color: Style.Theme.texto_secundario
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            width: parent.width - 30 * root.sx
                            font.pixelSize: 10 * root.sx
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40 * root.sy
            radius: 9 * root.sx
            color: root.hasData ? Style.Theme.aviso_fondo : Style.Theme.superficie_alterna
            border.color: root.hasData ? "#FDBA74" : Style.Theme.borde_suave
            Text {
                anchors.centerIn: parent
                width: parent.width - 20 * root.sx
                text: root.hasData
                      ? "El histograma resume todos los logits; el top conserva logits reales y probabilidades posteriores. Linear aún no elige el token."
                      : "Aún no hay una captura de salida para este paso de inferencia."
                color: root.hasData ? Style.Theme.aviso_texto : Style.Theme.texto_secundario
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.pixelSize: 9 * root.sx
            }
        }
    }

    component SceneButton: Rectangle {
        id: sceneButton
        property string label: ""
        property real sx: 1
        property real sy: 1
        signal clicked()
        implicitWidth: buttonText.implicitWidth + 22 * sx
        implicitHeight: 32 * sy
        radius: 8 * sx
        color: Style.Theme.error
        border.color: Style.Theme.error_texto
        Text {
            id: buttonText
            anchors.centerIn: parent
            text: sceneButton.label
            color: Style.Theme.texto_sobre_color
            font.bold: true
            font.pixelSize: 9 * sceneButton.sx
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sceneButton.clicked()
        }
    }

    component PipelineCard: Rectangle {
        id: pipelineCard
        property string number: ""
        property string eyebrow: ""
        property string title: ""
        property string detail: ""
        property color accent: "#2563EB"
        property bool emphasized: false
        property real sx: 1
        property real sy: 1
        radius: 10 * sx
        color: emphasized ? Qt.alpha(accent, 0.11) : Style.Theme.superficie_alterna
        border.color: emphasized ? accent : Style.Theme.borde_suave
        border.width: emphasized ? 2 : 1
        opacity: emphasized ? 1 : 0.64
        Behavior on opacity {
            NumberAnimation { duration: root.reducedMotion ? 0 : 180 }
        }
        RowLayout {
            anchors.fill: parent
            anchors.margins: 8 * pipelineCard.sx
            spacing: 7 * pipelineCard.sx
            Rectangle {
                Layout.preferredWidth: 27 * pipelineCard.sx
                Layout.preferredHeight: 27 * pipelineCard.sy
                radius: height / 2
                color: pipelineCard.accent
                Text {
                    anchors.centerIn: parent
                    text: pipelineCard.number
                    color: Style.Theme.texto_sobre_color
                    font.bold: true
                    font.pixelSize: 9 * pipelineCard.sx
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: pipelineCard.eyebrow
                    color: pipelineCard.accent
                    font.bold: true
                    elide: Text.ElideRight
                    font.pixelSize: Math.max(9, 9 * pipelineCard.sx)
                }
                Text {
                    Layout.fillWidth: true
                    text: pipelineCard.title
                    color: Style.Theme.texto_primario
                    font.bold: true
                    elide: Text.ElideRight
                    font.pixelSize: 10 * pipelineCard.sx
                }
                Text {
                    Layout.fillWidth: true
                    text: pipelineCard.detail
                    color: Style.Theme.texto_secundario
                    elide: Text.ElideRight
                    font.pixelSize: Math.max(9, 8.5 * pipelineCard.sx)
                }
            }
        }
    }

    component FlowArrow: Item {
        id: flowArrow
        property real progress: 0
        property color accent: "#2563EB"
        property real sx: 1
        property real sy: 1
        Layout.fillHeight: true
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 8 * flowArrow.sx
            height: 3 * flowArrow.sy
            radius: height / 2
            color: Qt.alpha(flowArrow.accent, 0.28)
            Rectangle {
                width: parent.width * flowArrow.progress
                height: parent.height
                radius: parent.radius
                color: flowArrow.accent
            }
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "›"
            color: flowArrow.accent
            opacity: 0.35 + flowArrow.progress * 0.65
            font.bold: true
            font.pixelSize: 23 * flowArrow.sx
        }
    }

    component MetricChip: Rectangle {
        id: metricChip
        property string label: ""
        property string value: "—"
        property real sx: 1
        property real sy: 1
        radius: 7 * sx
        color: Style.Theme.surface
        border.color: Style.Theme.error_fondo
        Column {
            anchors.centerIn: parent
            width: parent.width - 6 * metricChip.sx
            spacing: 0
            Text {
                width: parent.width
                text: metricChip.value
                color: Style.Theme.error_texto
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.pixelSize: 9 * metricChip.sx
            }
            Text {
                width: parent.width
                text: metricChip.label
                color: Style.Theme.texto_secundario
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Math.max(9, 8 * metricChip.sx)
            }
        }
    }
}
