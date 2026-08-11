pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property var matrix: []
    property string colorMode: "sequential" // sequential, diverging, mask
    property bool localScale: false
    property real globalMinimum: colorMode === "sequential" ? 0 : -1
    property real globalMaximum: 1
    property string rowPrefix: "H"
    property int columnOffset: 0
    property string valueLabel: "valor"
    property int layerNumber: 0
    property string queryLabel: "query actual"
    property var rawScores: []
    property var maskMatrix: []
    property var attentionMatrix: []
    property var contributionMatrix: []
    property string alternativeText: "Matriz científica interactiva"
    property int selectedRow: 0
    property int selectedColumn: 0
    property bool reducedMotion: false

    readonly property int rows: matrix ? matrix.length : 0
    readonly property int columns: rows > 0 && matrix[0] ? matrix[0].length : 0
    readonly property real dataMinimum: calculateMinimum()
    readonly property real dataMaximum: calculateMaximum()

    signal cellSelected(int row, int column, real value)

    Accessible.role: Accessible.Table
    Accessible.name: alternativeText
    activeFocusOnTab: true

    function calculateMinimum() {
        var result = Number.POSITIVE_INFINITY
        for (var row = 0; row < root.rows; ++row)
            for (var column = 0; column < root.columns; ++column)
                result = Math.min(result, Number(root.matrix[row][column]))
        return isFinite(result) ? result : 0
    }

    function calculateMaximum() {
        var result = Number.NEGATIVE_INFINITY
        for (var row = 0; row < root.rows; ++row)
            for (var column = 0; column < root.columns; ++column)
                result = Math.max(result, Number(root.matrix[row][column]))
        return isFinite(result) ? result : 1
    }

    function mix(a, b, amount) {
        return Math.round(a + (b - a) * Math.max(0, Math.min(1, amount)))
    }

    function rgb(r, g, b) {
        return "rgb(" + r + "," + g + "," + b + ")"
    }

    function colorFor(value) {
        if (root.colorMode === "mask")
            return Number(value) > 0 ? "#FFFFFF" : "#CBD5E1"

        var minimum = root.localScale ? root.dataMinimum : root.globalMinimum
        var maximum = root.localScale ? root.dataMaximum : root.globalMaximum
        if (root.colorMode === "diverging") {
            var limit = Math.max(Math.abs(minimum), Math.abs(maximum), 1e-12)
            var signed = Math.max(-1, Math.min(1, Number(value) / limit))
            if (signed < 0) {
                var negative = -signed
                return root.rgb(root.mix(255, 0, negative),
                                root.mix(255, 114, negative),
                                root.mix(255, 178, negative))
            }
            return root.rgb(root.mix(255, 213, signed),
                            root.mix(255, 94, signed),
                            root.mix(255, 0, signed))
        }

        var normalized = (Number(value) - minimum) / Math.max(maximum - minimum, 1e-12)
        return root.rgb(root.mix(255, 0, normalized),
                        root.mix(255, 114, normalized),
                        root.mix(255, 178, normalized))
    }

    function choose(row, column) {
        if (root.rows === 0 || root.columns === 0)
            return
        root.selectedRow = Math.max(0, Math.min(root.rows - 1, row))
        root.selectedColumn = Math.max(0, Math.min(root.columns - 1, column))
        canvas.requestPaint()
        root.cellSelected(root.selectedRow, root.selectedColumn,
                          Number(root.matrix[root.selectedRow][root.selectedColumn]))
    }

    function auxiliaryValue(auxiliary, fallback) {
        if (!auxiliary || auxiliary.length <= selectedRow
                || !auxiliary[selectedRow]
                || auxiliary[selectedRow].length <= selectedColumn)
            return fallback
        return Number(auxiliary[selectedRow][selectedColumn]).toFixed(6)
    }

    onMatrixChanged: canvas.requestPaint()
    onLocalScaleChanged: canvas.requestPaint()
    onColorModeChanged: canvas.requestPaint()
    onSelectedRowChanged: canvas.requestPaint()
    onSelectedColumnChanged: canvas.requestPaint()

    Keys.onLeftPressed: choose(selectedRow, selectedColumn - 1)
    Keys.onRightPressed: choose(selectedRow, selectedColumn + 1)
    Keys.onUpPressed: choose(selectedRow - 1, selectedColumn)
    Keys.onDownPressed: choose(selectedRow + 1, selectedColumn)
    Keys.onReturnPressed: choose(selectedRow, selectedColumn)
    Keys.onEnterPressed: choose(selectedRow, selectedColumn)

    Canvas {
        id: canvas
        anchors.fill: parent
        anchors.leftMargin: 34
        anchors.bottomMargin: 20
        renderTarget: Canvas.FramebufferObject

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (root.rows === 0 || root.columns === 0)
                return

            var cellWidth = width / root.columns
            var cellHeight = height / root.rows
            ctx.font = "10px sans-serif"
            ctx.textAlign = "right"
            ctx.textBaseline = "middle"

            for (var row = 0; row < root.rows; ++row) {
                ctx.fillStyle = "#475569"
                ctx.fillText(root.rowPrefix + String(row + 1).padStart(2, "0"),
                             -5, row * cellHeight + cellHeight / 2)
                for (var column = 0; column < root.columns; ++column) {
                    var value = Number(root.matrix[row][column])
                    var x = column * cellWidth
                    var y = row * cellHeight
                    ctx.fillStyle = root.colorFor(value)
                    ctx.fillRect(x, y, cellWidth + 0.4, cellHeight + 0.4)

                    if (root.colorMode === "mask" && value <= 0) {
                        ctx.strokeStyle = "#64748B"
                        ctx.lineWidth = 0.7
                        ctx.beginPath()
                        ctx.moveTo(x, y + cellHeight)
                        ctx.lineTo(x + cellWidth, y)
                        ctx.stroke()
                    }
                    if (row === root.selectedRow && column === root.selectedColumn) {
                        ctx.strokeStyle = "#111111"
                        ctx.lineWidth = 2
                        ctx.strokeRect(x + 1, y + 1, Math.max(0, cellWidth - 2),
                                       Math.max(0, cellHeight - 2))
                    }
                }
            }

            ctx.fillStyle = "#64748B"
            ctx.textAlign = "center"
            ctx.textBaseline = "top"
            var labelStep = Math.max(1, Math.ceil(root.columns / 8))
            for (var col = 0; col < root.columns; col += labelStep)
                ctx.fillText(String(root.columnOffset + col),
                             col * cellWidth + cellWidth / 2, height + 4)
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.CrossCursor
            onPositionChanged: function(event) {
                if (root.rows === 0 || root.columns === 0)
                    return
                var column = Math.max(0, Math.min(root.columns - 1,
                    Math.floor(event.x / Math.max(canvas.width / root.columns, 1))))
                var row = Math.max(0, Math.min(root.rows - 1,
                    Math.floor(event.y / Math.max(canvas.height / root.rows, 1))))
                root.selectedRow = row
                root.selectedColumn = column
            }
            onClicked: function(event) {
                var column = Math.floor(event.x / Math.max(canvas.width / root.columns, 1))
                var row = Math.floor(event.y / Math.max(canvas.height / root.rows, 1))
                root.choose(row, column)
                root.forceActiveFocus()
            }
        }
    }

    Rectangle {
        visible: mouse.containsMouse && root.rows > 0 && root.columns > 0
        x: Math.min(root.width - width, Math.max(0, mouse.mouseX + 14))
        y: Math.min(root.height - height, Math.max(0, mouse.mouseY + 14))
        width: tooltipText.implicitWidth + 18
        height: tooltipText.implicitHeight + 13
        radius: 6
        color: "#0F172A"
        z: 10

        Text {
            id: tooltipText
            anchors.centerIn: parent
            text: (root.layerNumber > 0 ? "capa " + root.layerNumber + " · " : "")
                  + root.rowPrefix + String(root.selectedRow + 1).padStart(2, "0")
                  + "\n" + root.queryLabel + " → key "
                  + (root.columnOffset + root.selectedColumn)
                  + "\n" + root.valueLabel + ": "
                  + (root.rows && root.columns
                     ? Number(root.matrix[root.selectedRow][root.selectedColumn]).toFixed(6)
                     : "—")
                  + (root.rawScores.length ? "\nscore: " + root.auxiliaryValue(root.rawScores, "—") : "")
                  + (root.maskMatrix.length ? "\npermitido: " + (root.auxiliaryValue(root.maskMatrix, "1") !== "0.000000") : "")
                  + (root.attentionMatrix.length ? "\natención Aᵢⱼ: " + root.auxiliaryValue(root.attentionMatrix, "—") : "")
                  + (root.contributionMatrix.length ? "\n‖AᵢⱼVⱼ‖: " + root.auxiliaryValue(root.contributionMatrix, "—") : "")
            color: "#FFFFFF"
            font.pixelSize: 10
        }
    }
}
