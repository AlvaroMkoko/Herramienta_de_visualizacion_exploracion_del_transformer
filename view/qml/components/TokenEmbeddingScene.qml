pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Item {
    id: root
    objectName: "tokenEmbeddingScene"

    property var tensorData: ({})
    property var tokens: []
    property bool active: false
    property bool reducedMotion: false
    property real sx: 1
    property real sy: 1
    property real progress: 0
    property int selectedRow: 0
    property bool selectionPinned: false

    readonly property var matrixData: tensorData && tensorData.matriz
                                               ? tensorData.matriz : ({})
    readonly property var rows: matrixData && matrixData.valores
                                        ? matrixData.valores : []
    readonly property var norms: tensorData && tensorData.normas_tokens
                                         ? tensorData.normas_tokens : []
    readonly property var statistics: tensorData && tensorData.estadisticas
                                              ? tensorData.estadisticas : ({})
    readonly property int availableRows: Math.max(rows.length,
                                                   tokens ? tokens.length : 0)
    readonly property int safeRow: availableRows > 0
                                           ? Math.max(0, Math.min(availableRows - 1,
                                                                  selectedRow))
                                           : -1
    readonly property var selectedVector: vectorAt(safeRow)
    readonly property bool hasTensor: rows.length > 0
    readonly property real selectedNorm: normAt(safeRow)

    function tokenAt(row) {
        if (!tokens || !tokens.length || row < 0)
            return null
        var offset = Math.max(0, availableRows - tokens.length)
        var index = row - offset
        return index >= 0 && index < tokens.length ? tokens[index] : null
    }

    function vectorAt(row) {
        if (!rows || !rows.length || row < 0)
            return []
        var offset = Math.max(0, availableRows - rows.length)
        var index = row - offset
        return index >= 0 && index < rows.length ? (rows[index] || []) : []
    }

    function normAt(row) {
        if (!norms || !norms.length || row < 0)
            return NaN
        var offset = Math.max(0, availableRows - norms.length)
        var index = row - offset
        return index >= 0 && index < norms.length ? Number(norms[index]) : NaN
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

    function tokenText(token) {
        if (!token)
            return "Sin etiqueta"
        var text = token.texto !== undefined ? String(token.texto) : "Sin etiqueta"
        return text.length ? text : "∅"
    }

    function tokenIdText(token) {
        return token && token.token_id !== undefined ? String(token.token_id) : "—"
    }

    function maximumAbsolute(values) {
        var maximum = 0
        if (!values)
            return maximum
        for (var i = 0; i < values.length; ++i)
            maximum = Math.max(maximum, Math.abs(Number(values[i]) || 0))
        return maximum
    }

    function maximumNorm() {
        var maximum = 0
        for (var i = 0; i < norms.length; ++i) {
            var value = Number(norms[i])
            if (Number.isFinite(value))
                maximum = Math.max(maximum, Math.abs(value))
        }
        return maximum
    }

    function cellColor(value, maximum) {
        var numeric = Number(value)
        var ratio = maximum > 0 ? Math.min(1, Math.abs(numeric) / maximum) : 0
        return numeric >= 0
                ? Qt.rgba(0.15, 0.39, 0.92, 0.18 + ratio * 0.74)
                : Qt.rgba(0.88, 0.18, 0.31, 0.18 + ratio * 0.74)
    }

    function reveal(start, span) {
        if (reducedMotion)
            return 1
        return Math.max(0, Math.min(1, (progress - start) / Math.max(0.001, span)))
    }

    function replay() {
        lookupAnimation.stop()
        selectionPinned = false
        selectedRow = 0
        progress = 0
        if (reducedMotion)
            progress = 1
        else
            lookupAnimation.start()
    }

    onProgressChanged: {
        if (!selectionPinned && availableRows > 0)
            selectedRow = Math.min(availableRows - 1,
                                   Math.floor(progress * availableRows))
    }
    onActiveChanged: {
        if (active)
            replay()
        else
            lookupAnimation.stop()
    }
    onTensorDataChanged: {
        selectedRow = 0
        if (active)
            replay()
    }
    onTokensChanged: selectedRow = Math.max(0,
                                             Math.min(availableRows - 1, selectedRow))

    NumberAnimation {
        id: lookupAnimation
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 2400
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
                    text: "Del token discreto a un vector real"
                    color: "#0F172A"
                    font.bold: true
                    font.pixelSize: 17 * Math.min(root.sx, root.sy)
                }
                Text {
                    Layout.fillWidth: true
                    text: "lookup de embedding · escala √d_model · valores capturados del forward"
                    color: "#64748B"
                    elide: Text.ElideRight
                    font.pixelSize: 10 * root.sx
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
            Layout.preferredHeight: 78 * root.sy
            spacing: 8 * root.sx

            StageCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                step: "1"
                eyebrow: "TOKEN / ID"
                title: root.tokenText(root.tokenAt(root.safeRow))
                detail: "id " + root.tokenIdText(root.tokenAt(root.safeRow))
                accent: "#7C3AED"
                emphasized: true
                sx: root.sx
                sy: root.sy
            }

            FlowArrow {
                Layout.preferredWidth: 42 * root.sx
                progress: root.reveal(0.08, 0.22)
                sx: root.sx
                sy: root.sy
            }

            StageCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                step: "2"
                eyebrow: "LOOKUP + ESCALA"
                title: "Embedding(id) × √d_model"
                detail: "La fila aprendida se lleva a la escala del modelo"
                accent: "#DB2777"
                emphasized: root.progress >= 0.26
                sx: root.sx
                sy: root.sy
            }

            FlowArrow {
                Layout.preferredWidth: 42 * root.sx
                progress: root.reveal(0.36, 0.22)
                sx: root.sx
                sy: root.sy
            }

            StageCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                step: "3"
                eyebrow: "VECTOR REAL"
                title: root.tensorData && root.tensorData.shape
                       ? String(root.tensorData.shape) : "Sin captura"
                detail: Number.isFinite(root.selectedNorm)
                        ? "‖x‖₂ = " + root.formatNumber(root.selectedNorm)
                        : "Norma no disponible"
                accent: "#2563EB"
                emphasized: root.progress >= 0.55
                sx: root.sx
                sy: root.sy
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10 * root.sx

            Rectangle {
                Layout.preferredWidth: 280 * root.sx
                Layout.fillHeight: true
                radius: 12 * root.sx
                color: "#F8FAFC"
                border.color: "#D8E0EA"
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10 * root.sx
                    spacing: 6 * root.sy

                    Text {
                        Layout.fillWidth: true
                        text: "FILAS TOKEN × DIMENSIÓN"
                        color: "#64748B"
                        font.bold: true
                        font.pixelSize: 9 * root.sx
                    }

                    ListView {
                        id: tokenList
                        objectName: "tokenEmbeddingRows"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 5 * root.sy
                        model: root.availableRows

                        delegate: Rectangle {
                            id: tokenRow
                            required property int index
                            readonly property var rowToken: root.tokenAt(index)
                            readonly property real rowNorm: root.normAt(index)
                            width: ListView.view.width
                            height: 43 * root.sy
                            radius: 8 * root.sx
                            color: index === root.safeRow ? "#EDE9FE" : "#FFFFFF"
                            border.color: index === root.safeRow ? "#7C3AED" : "#E2E8F0"
                            border.width: index === root.safeRow ? 2 : 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6 * root.sx
                                spacing: 7 * root.sx

                                Rectangle {
                                    Layout.preferredWidth: 34 * root.sx
                                    Layout.preferredHeight: 28 * root.sy
                                    radius: 7 * root.sx
                                    color: tokenRow.index === root.safeRow ? "#7C3AED" : "#CBD5E1"
                                    Text {
                                        anchors.centerIn: parent
                                        text: tokenRow.rowToken
                                              && tokenRow.rowToken.posicion !== undefined
                                              ? "p" + tokenRow.rowToken.posicion : "—"
                                        color: "white"
                                        font.bold: true
                                        font.pixelSize: 8 * root.sx
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.tokenText(tokenRow.rowToken)
                                        color: "#0F172A"
                                        font.bold: true
                                        elide: Text.ElideRight
                                        font.pixelSize: 10 * root.sx
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: "id " + root.tokenIdText(tokenRow.rowToken)
                                        color: "#64748B"
                                        font.pixelSize: 8 * root.sx
                                    }
                                }

                                Text {
                                    text: Number.isFinite(tokenRow.rowNorm)
                                          ? "‖x‖ " + root.formatNumber(tokenRow.rowNorm) : "—"
                                    color: "#5B21B6"
                                    font.bold: true
                                    font.pixelSize: 8 * root.sx
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    lookupAnimation.stop()
                                    root.selectionPinned = true
                                    root.selectedRow = tokenRow.index
                                    root.progress = 1
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: root.availableRows === 0
                            text: "Los tokens aparecerán con una captura disponible."
                            color: "#64748B"
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            width: parent.width - 24 * root.sx
                            font.pixelSize: 10 * root.sx
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12 * root.sx
                color: "#FAFAFF"
                border.color: "#C4B5FD"
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 11 * root.sx
                    spacing: 8 * root.sy

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "VECTOR CAPTURADO · "
                                  + root.tokenText(root.tokenAt(root.safeRow))
                            color: "#312E81"
                            font.bold: true
                            elide: Text.ElideRight
                            font.pixelSize: 10 * root.sx
                        }
                        Text {
                            text: root.matrixData && root.matrixData.displayed_shape
                                  ? String(root.matrixData.displayed_shape) : "—"
                            color: "#6D28D9"
                            font.bold: true
                            font.pixelSize: 9 * root.sx
                        }
                    }

                    ListView {
                        id: vectorStrip
                        objectName: "tokenEmbeddingVector"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 112 * root.sy
                        orientation: ListView.Horizontal
                        clip: true
                        spacing: 4 * root.sx
                        model: root.selectedVector

                        delegate: Rectangle {
                            id: vectorCell
                            required property var modelData
                            required property int index
                            readonly property real maximum: root.maximumAbsolute(root.selectedVector)
                            width: 48 * root.sx
                            height: vectorStrip.height
                            radius: 7 * root.sx
                            color: root.cellColor(modelData, maximum)
                            border.color: Number(modelData) >= 0 ? "#60A5FA" : "#FB7185"
                            opacity: root.reveal(0.50 + Math.min(index, 20) * 0.012, 0.26)

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 6 * root.sx
                                spacing: 8 * root.sy
                                Text {
                                    width: parent.width
                                    text: "d" + vectorCell.index
                                    color: "#475569"
                                    horizontalAlignment: Text.AlignHCenter
                                    font.bold: true
                                    font.pixelSize: 8 * root.sx
                                }
                                Text {
                                    width: parent.width
                                    text: root.formatNumber(vectorCell.modelData)
                                    color: "#0F172A"
                                    horizontalAlignment: Text.AlignHCenter
                                    font.bold: true
                                    font.pixelSize: 8 * root.sx
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !root.selectedVector.length
                            text: "La fila del embedding aparecerá aquí."
                            color: "#64748B"
                            font.pixelSize: 11 * root.sx
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50 * root.sy
                        spacing: 7 * root.sx

                        MetricChip {
                            Layout.fillWidth: true
                            label: "MÍNIMO"
                            value: root.statistics.minimo !== undefined
                                   ? String(root.statistics.minimo) : "—"
                            sx: root.sx
                            sy: root.sy
                        }
                        MetricChip {
                            Layout.fillWidth: true
                            label: "MÁXIMO"
                            value: root.statistics.maximo !== undefined
                                   ? String(root.statistics.maximo) : "—"
                            sx: root.sx
                            sy: root.sy
                        }
                        MetricChip {
                            Layout.fillWidth: true
                            label: "MEDIA"
                            value: root.statistics.media !== undefined
                                   ? String(root.statistics.media) : "—"
                            sx: root.sx
                            sy: root.sy
                        }
                        MetricChip {
                            Layout.fillWidth: true
                            label: "NORMA L2"
                            value: root.statistics.norma_l2 !== undefined
                                   ? String(root.statistics.norma_l2) : "—"
                            sx: root.sx
                            sy: root.sy
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36 * root.sy
                        radius: 8 * root.sx
                        color: "#EFF6FF"
                        border.color: "#BFDBFE"
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8 * root.sx
                            spacing: 8 * root.sx
                            Text {
                                text: "NORMA DEL TOKEN"
                                color: "#1D4ED8"
                                font.bold: true
                                font.pixelSize: 8 * root.sx
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 7 * root.sy
                                radius: height / 2
                                color: "#DBEAFE"
                                Rectangle {
                                    width: parent.width
                                           * (root.maximumNorm() > 0
                                              && Number.isFinite(root.selectedNorm)
                                              ? Math.min(1, root.selectedNorm
                                                         / root.maximumNorm()) : 0)
                                           * root.reveal(0.62, 0.30)
                                    height: parent.height
                                    radius: parent.radius
                                    color: "#2563EB"
                                    Behavior on width {
                                        NumberAnimation {
                                            duration: root.reducedMotion ? 0 : 240
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                            Text {
                                text: root.formatNumber(root.selectedNorm)
                                color: "#1E3A8A"
                                font.bold: true
                                font.pixelSize: 9 * root.sx
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38 * root.sy
            radius: 9 * root.sx
            color: "#FFF7ED"
            border.color: "#FDBA74"
            Text {
                anchors.centerIn: parent
                width: parent.width - 20 * root.sx
                text: root.hasTensor
                      ? "Muestra exacta sin agregación · "
                        + String(root.matrixData.level_of_detail || "ventana capturada")
                        + " · los valores no visibles permanecen en Python."
                      : "Aún no hay una captura tensorial para este paso de inferencia."
                color: "#9A3412"
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
        color: "#7C3AED"
        border.color: "#6D28D9"
        Text {
            id: buttonText
            anchors.centerIn: parent
            text: sceneButton.label
            color: "white"
            font.bold: true
            font.pixelSize: 9 * sceneButton.sx
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sceneButton.clicked()
        }
    }

    component StageCard: Rectangle {
        id: stageCard
        property string step: ""
        property string eyebrow: ""
        property string title: ""
        property string detail: ""
        property color accent: "#7C3AED"
        property bool emphasized: false
        property real sx: 1
        property real sy: 1
        radius: 10 * sx
        color: emphasized ? Qt.alpha(accent, 0.12) : "#F8FAFC"
        border.color: emphasized ? accent : "#CBD5E1"
        border.width: emphasized ? 2 : 1
        opacity: emphasized ? 1 : 0.66
        Behavior on opacity {
            NumberAnimation { duration: root.reducedMotion ? 0 : 180 }
        }
        RowLayout {
            anchors.fill: parent
            anchors.margins: 8 * stageCard.sx
            spacing: 7 * stageCard.sx
            Rectangle {
                Layout.preferredWidth: 27 * stageCard.sx
                Layout.preferredHeight: 27 * stageCard.sy
                radius: height / 2
                color: stageCard.accent
                Text {
                    anchors.centerIn: parent
                    text: stageCard.step
                    color: "white"
                    font.bold: true
                    font.pixelSize: 9 * stageCard.sx
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: stageCard.eyebrow
                    color: stageCard.accent
                    font.bold: true
                    elide: Text.ElideRight
                    font.pixelSize: 8 * stageCard.sx
                }
                Text {
                    Layout.fillWidth: true
                    text: stageCard.title
                    color: "#0F172A"
                    font.bold: true
                    elide: Text.ElideRight
                    font.pixelSize: 10 * stageCard.sx
                }
                Text {
                    Layout.fillWidth: true
                    text: stageCard.detail
                    color: "#64748B"
                    elide: Text.ElideRight
                    font.pixelSize: 7.5 * stageCard.sx
                }
            }
        }
    }

    component FlowArrow: Item {
        id: flowArrow
        property real progress: 0
        property real sx: 1
        property real sy: 1
        Layout.fillHeight: true
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 8 * flowArrow.sx
            height: 3 * flowArrow.sy
            radius: height / 2
            color: "#C4B5FD"
            opacity: 0.35 + flowArrow.progress * 0.65
            Rectangle {
                width: parent.width * flowArrow.progress
                height: parent.height
                radius: parent.radius
                color: "#7C3AED"
            }
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "›"
            color: "#7C3AED"
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
        radius: 8 * sx
        color: "#FFFFFF"
        border.color: "#DDD6FE"
        Column {
            anchors.centerIn: parent
            width: parent.width - 8 * metricChip.sx
            spacing: 1 * metricChip.sy
            Text {
                width: parent.width
                text: metricChip.value
                color: "#312E81"
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.pixelSize: 10 * metricChip.sx
            }
            Text {
                width: parent.width
                text: metricChip.label
                color: "#64748B"
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 7 * metricChip.sx
            }
        }
    }
}
