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
    readonly property bool compact: width < 850

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
    readonly property real candidateMaximumAbsoluteLogit: maximumCandidate("logit", true)

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
        var target = numeric >= 0
                ? Style.Theme.escala_div_pos2 : Style.Theme.escala_div_neg2
        return mixColor(Style.Theme.escala_div_cero, target, 0.24 + ratio * 0.76)
    }

    function mixColor(startColor, endColor, amount) {
        var ratio = Math.max(0, Math.min(1, amount))
        return Qt.rgba(
                    startColor.r + (endColor.r - startColor.r) * ratio,
                    startColor.g + (endColor.g - startColor.g) * ratio,
                    startColor.b + (endColor.b - startColor.b) * ratio,
                    1)
    }

    function linearColorChannel(channel) {
        return channel <= 0.04045
                ? channel / 12.92
                : Math.pow((channel + 0.055) / 1.055, 2.4)
    }

    function colorLuminance(color) {
        return 0.2126 * linearColorChannel(color.r)
                + 0.7152 * linearColorChannel(color.g)
                + 0.0722 * linearColorChannel(color.b)
    }

    function hiddenTextColor(value) {
        return colorLuminance(hiddenColor(value)) < 0.20
                ? Style.Theme.texto_sobre_color : "#111827"
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
                    Layout.fillWidth: true
                    text: "Del estado final a los logits del vocabulario"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    elide: Text.ElideRight
                    font.pixelSize: Math.max(18, 18 * Math.min(root.sx, root.sy))
                }
                Text {
                    Layout.fillWidth: true
                    text: "h_final · W_vocabᵀ + b → un puntaje real por token"
                    color: Style.Theme.texto_secundario
                    elide: Text.ElideRight
                    font.pixelSize: Math.max(11, 11 * root.sx)
                }
            }

            SceneButton {
                label: root.compact ? "↻" : "↻ Reproducir"
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
                Layout.minimumWidth: 0
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                number: "1"
                eyebrow: "ESTADO FINAL DEL DECODER"
                title: root.hiddenData && root.hiddenData.shape
                       ? String(root.hiddenData.shape) : "Sin captura"
                detail: root.finalHidden.length
                        ? root.finalHidden.length + " dims visibles · tras atender al encoder"
                        : "La última posición del decoder alimenta Linear"
                accent: Style.Theme.inferencia_contexto
                onAccent: Style.Theme.inferencia_sobre_contexto
                emphasized: true
                sx: root.sx
                sy: root.sy
            }

            FlowArrow {
                visible: !root.compact
                Layout.preferredWidth: visible ? 44 * root.sx : 0
                progress: root.reveal(0.10, 0.20)
                accent: Style.Theme.inferencia_contexto
                sx: root.sx
                sy: root.sy
            }

            PipelineCard {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                number: "2"
                eyebrow: "PROYECCIÓN LINEAL"
                title: "logits = h_final W_vocabᵀ + b"
                detail: "Los pesos no se copian a la vista"
                accent: Style.Theme.inferencia_transformacion
                onAccent: Style.Theme.inferencia_sobre_transformacion
                emphasized: root.progress >= 0.28
                sx: root.sx
                sy: root.sy
            }

            FlowArrow {
                visible: !root.compact
                Layout.preferredWidth: visible ? 44 * root.sx : 0
                progress: root.reveal(0.38, 0.20)
                accent: Style.Theme.inferencia_transformacion
                sx: root.sx
                sy: root.sy
            }

            PipelineCard {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                number: "3"
                eyebrow: "LOGITS"
                title: root.logitsData && root.logitsData.shape
                       ? String(root.logitsData.shape) : "Sin captura"
                detail: root.histogram && root.histogram.total !== undefined
                        ? root.histogram.total + " valores resumidos" : "Puntajes sin normalizar"
                accent: Style.Theme.inferencia_foco
                onAccent: Style.Theme.inferencia_sobre_foco
                emphasized: root.progress >= 0.58
                sx: root.sx
                sy: root.sy
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: parent.width
            Layout.fillHeight: true
            spacing: 10 * root.sx

            ColumnLayout {
                objectName: "outputDistributionColumn"
                Layout.minimumWidth: 300 * root.sx
                Layout.preferredWidth: 390 * root.sx
                Layout.maximumWidth: 430 * root.sx
                Layout.fillHeight: true
                spacing: 6 * root.sy

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58 * root.sy
                    radius: 12 * root.sx
                    color: Style.Theme.info_fondo
                    border.color: Style.Theme.inferencia_contexto

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 9 * root.sx
                        spacing: 5 * root.sy
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: "h FINAL DEL DECODER · TRAS ATENCIÓN AL ENCODER"
                                color: Style.Theme.inferencia_contexto
                                font.bold: true
                                font.pixelSize: Math.max(9, 9 * root.sx)
                            }
                            Text {
                                text: root.hiddenMatrix && root.hiddenMatrix.displayed_shape
                                      ? String(root.hiddenMatrix.displayed_shape) : "—"
                                color: Style.Theme.inferencia_contexto
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
                                width: 44 * root.sx
                                height: hiddenStrip.height
                                radius: 6 * root.sx
                                color: root.hiddenColor(modelData)
                                border.color: Number(modelData) >= 0
                                              ? Style.Theme.escala_div_pos2
                                              : Style.Theme.escala_div_neg2
                                opacity: root.reveal(Math.min(index, 18) * 0.012, 0.30)
                                Column {
                                    anchors.centerIn: parent
                                    width: parent.width - 4 * root.sx
                                    spacing: 2 * root.sy
                                    Text {
                                        width: parent.width
                                        text: "d" + hiddenCell.index
                                        color: root.hiddenTextColor(hiddenCell.modelData)
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        font.pixelSize: Math.max(9, 8.5 * root.sx)
                                    }
                                    Text {
                                        width: parent.width
                                        text: root.formatNumber(hiddenCell.modelData)
                                        color: root.hiddenTextColor(hiddenCell.modelData)
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        font.pixelSize: Math.max(9, 8.5 * root.sx)
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
                    border.color: Style.Theme.inferencia_foco

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6 * root.sx
                        spacing: 3 * root.sy

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: "HISTOGRAMA DE LOGITS"
                                color: Style.Theme.inferencia_foco
                                font.bold: true
                                font.pixelSize: 9 * root.sx
                            }
                            Text {
                                text: "altura = tokens · "
                                      + (root.logitsData && root.logitsData.dtype
                                         ? String(root.logitsData.dtype) : "—")
                                color: Style.Theme.inferencia_foco
                                font.pixelSize: Math.max(9, 9 * root.sx)
                            }
                        }

                        Item {
                            id: histogramPlot
                            objectName: "outputLogitsHistogram"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 28 * root.sy

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 16 * root.sy
                                height: 1
                                color: Qt.alpha(Style.Theme.inferencia_foco, 0.45)
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
                                    color: root.histogramEdges.length > index + 1
                                           && (Number(root.histogramEdges[index])
                                               + Number(root.histogramEdges[index + 1])) / 2 < 0
                                           ? Style.Theme.escala_div_neg2
                                           : Style.Theme.escala_div_pos2
                                    opacity: 0.82
                                }
                            }

                            Rectangle {
                                readonly property real minimumLogit: root.histogramEdges.length
                                        ? Number(root.histogramEdges[0]) : 0
                                readonly property real maximumLogit: root.histogramEdges.length
                                        ? Number(root.histogramEdges[root.histogramEdges.length - 1]) : 0
                                visible: root.histogramCounts.length > 0
                                         && minimumLogit < 0 && maximumLogit > 0
                                x: Math.max(0, Math.min(parent.width - width,
                                    (-minimumLogit / (maximumLogit - minimumLogit))
                                    * parent.width))
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 16 * root.sy
                                width: Math.max(1, root.sx)
                                color: Style.Theme.texto_primario
                                opacity: 0.7

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    anchors.topMargin: 2 * root.sy
                                    text: "0"
                                    color: Style.Theme.texto_primario
                                    font.bold: true
                                    font.pixelSize: Math.max(9, 8 * root.sx)
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 2 * root.sy
                                text: root.histogramEdges.length
                                      ? root.formatNumber(root.histogramEdges[0]) : "—"
                                color: Style.Theme.inferencia_foco
                                font.pixelSize: Math.max(9, 8 * root.sx)
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 2 * root.sy
                                text: root.histogramEdges.length
                                      ? root.formatNumber(root.histogramEdges[
                                          root.histogramEdges.length - 1]) : "—"
                                color: Style.Theme.inferencia_foco
                                font.pixelSize: Math.max(9, 8 * root.sx)
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 2 * root.sy
                                text: "eje x: valor del logit →"
                                color: Style.Theme.texto_secundario
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
                            Layout.preferredHeight: 28 * root.sy
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
                objectName: "outputCandidatePanel"
                Layout.minimumWidth: 300 * root.sx
                Layout.preferredWidth: 360 * root.sx
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
                            text: "LOGITS DE CANDIDATOS CAPTURADOS"
                            color: Style.Theme.inferencia_foco
                            font.bold: true
                            font.pixelSize: 9 * root.sx
                        }
                        Text {
                            text: "barra centrada en 0 · sin Softmax"
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
                            readonly property real logit: Number(modelData.logit)
                            readonly property real logitFraction: root.candidateMaximumAbsoluteLogit > 0
                                    ? Math.min(1, Math.abs(logit)
                                               / root.candidateMaximumAbsoluteLogit) : 0
                            width: ListView.view.width
                            height: 51 * root.sy
                            radius: 8 * root.sx
                            color: Style.Theme.surface
                            border.color: Style.Theme.borde_medio
                            border.width: 1
                            opacity: root.reveal(0.64 + Math.min(index, 8) * 0.025, 0.22)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6 * root.sx
                                spacing: 7 * root.sx

                                Rectangle {
                                    Layout.preferredWidth: 36 * root.sx
                                    Layout.preferredHeight: 28 * root.sy
                                    radius: 7 * root.sx
                                    color: Style.Theme.inferencia_estructura
                                    Text {
                                        anchors.centerIn: parent
                                        text: candidateRow.modelData.rango !== undefined
                                              ? "#" + candidateRow.modelData.rango
                                              : String(candidateRow.index + 1)
                                        color: Style.Theme.inferencia_sobre_estructura
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
                                            color: candidateRow.logit >= 0
                                                   ? Style.Theme.escala_div_pos2
                                                   : Style.Theme.escala_div_neg2
                                            font.bold: true
                                            font.pixelSize: Math.max(9, 9 * root.sx)
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: "preferencia cruda · no es %"
                                            color: Style.Theme.texto_secundario
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
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: Math.max(1, root.sx)
                                            height: parent.height
                                            color: Style.Theme.texto_primario
                                            opacity: 0.7
                                        }
                                        Rectangle {
                                            readonly property real animatedWidth:
                                                    (parent.width / 2 - 2 * root.sx)
                                                    * candidateRow.logitFraction
                                                    * root.reveal(0.64
                                                        + Math.min(candidateRow.index, 8) * 0.025,
                                                        0.22)
                                            x: candidateRow.logit >= 0
                                               ? parent.width / 2
                                               : parent.width / 2 - animatedWidth
                                            width: animatedWidth
                                            height: parent.height
                                            radius: height / 2
                                            color: candidateRow.logit >= 0
                                                   ? Style.Theme.escala_div_pos2
                                                   : Style.Theme.escala_div_neg2
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
            color: root.hasData ? Style.Theme.info_fondo : Style.Theme.superficie_alterna
            border.color: root.hasData ? Style.Theme.inferencia_estructura : Style.Theme.borde_suave
            Text {
                anchors.centerIn: parent
                width: parent.width - 20 * root.sx
                text: root.hasData
                      ? "Linear produce un logit por token: las barras muestran signo y magnitud desde 0. Todavía no hay probabilidades ni token elegido."
                      : "Aún no hay una captura de salida para este paso de inferencia."
                color: root.hasData ? Style.Theme.info_texto : Style.Theme.texto_secundario
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
        color: Style.Theme.inferencia_transformacion
        border.color: Style.Theme.inferencia_transformacion
        Text {
            id: buttonText
            anchors.centerIn: parent
            text: sceneButton.label
            color: Style.Theme.inferencia_sobre_transformacion
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
        property color accent: Style.Theme.inferencia_estructura
        property color onAccent: Style.Theme.inferencia_sobre_estructura
        property bool emphasized: false
        property real sx: 1
        property real sy: 1
        clip: true
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
                    color: pipelineCard.onAccent
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
        property color accent: Style.Theme.inferencia_estructura
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
        border.color: Style.Theme.inferencia_foco
        Column {
            anchors.centerIn: parent
            width: parent.width - 6 * metricChip.sx
            spacing: 0
            Text {
                width: parent.width
                text: metricChip.value
                color: Style.Theme.inferencia_foco
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
