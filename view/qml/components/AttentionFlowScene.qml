pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var attentionData: ({})
    property var queryTokens: []
    property var keyTokens: []
    property bool crossAttention: false
    property int headIndex: 0
    property bool active: false
    property bool reducedMotion: false
    property real sx: 1
    property real sy: 1
    property real threshold: 0.05
    property int focusedQuery: -1
    property bool showHeadGrid: false
    property real particlePhase: 0

    readonly property var flow: attentionData && attentionData.flujo
                                    ? attentionData.flujo : ({})
    readonly property var matrices: flow.matrices || []
    readonly property var matrix: matrices.length
                                  ? matrices[Math.max(0, Math.min(matrices.length - 1, headIndex))]
                                  : []
    readonly property int queryCount: matrix.length
    readonly property int keyCount: queryCount && matrix[0] ? matrix[0].length : 0
    readonly property int queryOffset: Number(flow.inicio_queries || 0)
    readonly property int keyOffset: Number(flow.inicio_keys || 0)
    readonly property var palettes: ["#0284C7", "#7C3AED", "#D97706", "#059669",
                                     "#DB2777", "#4F46E5", "#DC2626", "#0891B2",
                                     "#9333EA", "#65A30D", "#EA580C", "#0F766E"]

    signal headSelected(int index)

    function colorForHead(index) {
        return palettes[index % palettes.length]
    }

    function tokenFor(tokens, absolutePosition, fallbackPrefix) {
        for (var i = 0; i < tokens.length; ++i) {
            if (Number(tokens[i].posicion) === absolutePosition)
                return tokens[i]
        }
        var local = absolutePosition - (tokens.length ? Number(tokens[0].posicion || 0) : 0)
        return local >= 0 && local < tokens.length ? tokens[local]
                                                   : ({ texto: fallbackPrefix + (absolutePosition + 1), posicion: absolutePosition })
    }

    function queryToken(localIndex) {
        return tokenFor(queryTokens, queryOffset + localIndex, "Q")
    }

    function keyToken(localIndex) {
        return tokenFor(keyTokens, keyOffset + localIndex, "K")
    }

    function weightAt(q, k, sourceMatrix) {
        var data = sourceMatrix || matrix
        return data && data.length > q && data[q] && data[q].length > k
                ? Number(data[q][k] || 0) : 0
    }

    function maximum(sourceMatrix) {
        var result = 1e-9
        var data = sourceMatrix || matrix
        for (var q = 0; q < data.length; ++q)
            for (var k = 0; k < data[q].length; ++k)
                result = Math.max(result, Number(data[q][k] || 0))
        return result
    }

    function strongestTarget(q) {
        var best = -1
        var value = -1
        for (var k = 0; k < keyCount; ++k) {
            var candidate = weightAt(q, k)
            if (candidate > value) {
                value = candidate
                best = k
            }
        }
        return best
    }

    onParticlePhaseChanged: flowCanvas.requestPaint()
    onMatrixChanged: flowCanvas.requestPaint()
    onThresholdChanged: flowCanvas.requestPaint()
    onFocusedQueryChanged: flowCanvas.requestPaint()
    onCrossAttentionChanged: flowCanvas.requestPaint()

    NumberAnimation {
        target: root
        property: "particlePhase"
        from: 0
        to: 1
        duration: 2100
        loops: Animation.Infinite
        running: root.active && !root.reducedMotion && !root.showHeadGrid && root.matrix.length > 0
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 9 * root.sy

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48 * root.sy
            spacing: 8 * root.sx
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1 * root.sy
                Text {
                    text: root.crossAttention ? "Flujo de atención cruzada" : "Self-attention como flujo de información"
                    color: "#0F172A"
                    font.bold: true
                    font.pixelSize: 17 * Math.min(root.sx, root.sy)
                }
                Text {
                    text: root.showHeadGrid
                          ? "Mismo layout en cada tarjeta · una paleta por cabeza"
                          : "Capa capturada · H" + String(root.headIndex + 1).padStart(2, "0")
                            + " · grosor y opacidad = peso real"
                    color: root.colorForHead(root.headIndex)
                    font.bold: true
                    font.pixelSize: 10 * root.sx
                }
            }
            FlowButton {
                label: root.showHeadGrid ? "Vista linterna" : "Comparar heads"
                primary: root.showHeadGrid
                sx: root.sx; sy: root.sy
                onClicked: root.showHeadGrid = !root.showHeadGrid
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48 * root.sy
            radius: 10 * root.sx
            color: "#EFF6FF"
            border.color: "#BAE6FD"
            RowLayout {
                anchors.fill: parent
                anchors.margins: 8 * root.sx
                spacing: 10 * root.sx
                Text { text: "UMBRAL"; color: "#0369A1"; font.bold: true; font.pixelSize: 9 * root.sx }
                Slider {
                    id: thresholdSlider
                    Layout.preferredWidth: 260 * root.sx
                    from: 0.0; to: 0.35; stepSize: 0.005
                    value: root.threshold
                    onMoved: root.threshold = value
                    background: Rectangle {
                        x: thresholdSlider.leftPadding
                        y: thresholdSlider.topPadding + thresholdSlider.availableHeight / 2 - height / 2
                        width: thresholdSlider.availableWidth
                        height: 6 * root.sy
                        radius: height / 2
                        color: "#BAE6FD"
                        Rectangle { width: thresholdSlider.visualPosition * parent.width; height: parent.height; radius: parent.radius; color: "#0284C7" }
                    }
                    handle: Rectangle {
                        x: thresholdSlider.leftPadding + thresholdSlider.visualPosition * (thresholdSlider.availableWidth - width)
                        y: thresholdSlider.topPadding + thresholdSlider.availableHeight / 2 - height / 2
                        width: 18 * root.sx; height: 18 * root.sy; radius: width / 2
                        color: "white"; border.color: "#0284C7"; border.width: 3
                    }
                }
                Text { text: "≥ " + root.threshold.toFixed(3); color: "#075985"; font.bold: true; font.pixelSize: 10 * root.sx }
                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: "#BAE6FD" }
                Text {
                    Layout.fillWidth: true
                    text: root.focusedQuery >= 0
                          ? "🔦 Linterna: “" + (root.queryToken(root.focusedQuery).texto || "token")
                            + "” → destino principal “" + (root.keyToken(root.strongestTarget(root.focusedQuery)).texto || "token") + "”"
                          : "Pasa el cursor sobre una query para apagar las demás conexiones."
                    color: root.focusedQuery >= 0 ? "#0C4A6E" : "#475569"
                    font.bold: root.focusedQuery >= 0
                    elide: Text.ElideRight
                    font.pixelSize: 9 * root.sx
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.showHeadGrid ? 1 : 0

            Rectangle {
                radius: 12 * root.sx
                color: "#F8FAFC"
                border.color: "#D8E0EA"
                clip: true

                Canvas {
                    id: flowCanvas
                    anchors.fill: parent
                    anchors.margins: 5 * root.sx

                    function xFor(index, count) {
                        var left = 42 * root.sx
                        var usable = Math.max(1, width - 84 * root.sx)
                        return left + (index + 0.5) / Math.max(1, count) * usable
                    }

                    function queryY() { return height - 28 * root.sy }
                    function keyY() { return root.crossAttention ? 28 * root.sy : queryY() }

                    function quadraticPoint(startX, startY, controlX, controlY, endX, endY, t) {
                        var one = 1 - t
                        return { x: one * one * startX + 2 * one * t * controlX + t * t * endX,
                                 y: one * one * startY + 2 * one * t * controlY + t * t * endY }
                    }

                    function cubicPoint(x0, y0, x1, y1, x2, y2, x3, y3, t) {
                        var one = 1 - t
                        return { x: one * one * one * x0 + 3 * one * one * t * x1
                                    + 3 * one * t * t * x2 + t * t * t * x3,
                                 y: one * one * one * y0 + 3 * one * one * t * y1
                                    + 3 * one * t * t * y2 + t * t * t * y3 }
                    }

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var maximum = root.maximum(root.matrix)
                        var color = root.colorForHead(root.headIndex)
                        var qY = queryY()
                        var kY = keyY()

                        if (root.crossAttention) {
                            ctx.fillStyle = "#64748B"
                            ctx.font = "bold " + Math.max(8, 9 * root.sx) + "px sans-serif"
                            ctx.fillText("KEYS · prompt", 12 * root.sx, 14 * root.sy)
                            ctx.fillText("QUERIES · decoder", 12 * root.sx, height - 6 * root.sy)
                        }

                        for (var q = 0; q < root.queryCount; ++q) {
                            if (root.focusedQuery >= 0 && q !== root.focusedQuery)
                                continue
                            for (var k = 0; k < root.keyCount; ++k) {
                                var weight = root.weightAt(q, k)
                                if (weight < root.threshold)
                                    continue
                                var startX = xFor(q, root.queryCount)
                                var endX = xFor(k, root.keyCount)
                                var normalized = Math.max(0.08, weight / maximum)
                                ctx.beginPath()
                                if (root.crossAttention) {
                                    var c1y = qY - (qY - kY) * 0.42
                                    var c2y = kY + (qY - kY) * 0.42
                                    ctx.moveTo(startX, qY)
                                    ctx.bezierCurveTo(startX, c1y, endX, c2y, endX, kY)
                                } else {
                                    var lift = Math.max(24 * root.sy,
                                                        44 * root.sy + Math.abs(endX - startX) * 0.25)
                                    ctx.moveTo(startX, qY)
                                    ctx.quadraticCurveTo((startX + endX) / 2, qY - lift, endX, kY)
                                }
                                ctx.strokeStyle = Qt.alpha(color, 0.18 + normalized * 0.72)
                                ctx.lineWidth = (0.7 + normalized * 6.2) * root.sx
                                ctx.stroke()

                                if (!root.reducedMotion) {
                                    var t = (root.particlePhase + (q * 0.13 + k * 0.07)) % 1
                                    var point
                                    if (root.crossAttention) {
                                        point = cubicPoint(startX, qY, startX,
                                                           qY - (qY - kY) * 0.42,
                                                           endX, kY + (qY - kY) * 0.42,
                                                           endX, kY, t)
                                    } else {
                                        var curveLift = Math.max(24 * root.sy,
                                                                 44 * root.sy + Math.abs(endX - startX) * 0.25)
                                        point = quadraticPoint(startX, qY,
                                                               (startX + endX) / 2,
                                                               qY - curveLift, endX, kY, t)
                                    }
                                    ctx.beginPath()
                                    ctx.arc(point.x, point.y, (2.5 + normalized * 2.2) * root.sx,
                                            0, Math.PI * 2)
                                    ctx.fillStyle = color
                                    ctx.fill()
                                    ctx.strokeStyle = "#FFFFFF"
                                    ctx.lineWidth = 1
                                    ctx.stroke()
                                }
                            }
                        }

                        if (!root.queryCount) {
                            ctx.fillStyle = "#64748B"
                            ctx.textAlign = "center"
                            ctx.font = "bold " + Math.max(12, 14 * root.sx) + "px sans-serif"
                            ctx.fillText("No hay una matriz de atención disponible para esta selección.",
                                         width / 2, height / 2)
                            ctx.textAlign = "left"
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: 5 * root.sx
                    Repeater {
                        model: root.queryCount
                        delegate: Rectangle {
                            id: queryChip
                            required property int index
                            width: Math.max(34 * root.sx, queryLabel.implicitWidth + 10 * root.sx)
                            height: 30 * root.sy
                            x: 42 * root.sx + (index + 0.5) / Math.max(1, root.queryCount)
                               * (parent.width - 84 * root.sx) - width / 2
                            y: parent.height - 43 * root.sy
                            radius: 7 * root.sx
                            color: root.focusedQuery === index ? root.colorForHead(root.headIndex) : "#FFFFFF"
                            border.color: root.colorForHead(root.headIndex)
                            border.width: root.focusedQuery === index ? 2 : 1
                            z: 2
                            Text {
                                id: queryLabel
                                anchors.centerIn: parent
                                text: root.queryToken(queryChip.index).texto || "∅"
                                color: root.focusedQuery === queryChip.index ? "white" : "#0F172A"
                                font.bold: true
                                font.pixelSize: 8 * root.sx
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.focusedQuery = queryChip.index
                                onExited: root.focusedQuery = -1
                            }
                        }
                    }

                    Repeater {
                        model: root.crossAttention ? root.keyCount : 0
                        delegate: Rectangle {
                            id: keyChip
                            required property int index
                            width: Math.max(34 * root.sx, keyLabel.implicitWidth + 10 * root.sx)
                            height: 30 * root.sy
                            x: 42 * root.sx + (index + 0.5) / Math.max(1, root.keyCount)
                               * (parent.width - 84 * root.sx) - width / 2
                            y: 8 * root.sy
                            radius: 7 * root.sx
                            color: "#FFFFFF"
                            border.color: "#94A3B8"
                            z: 2
                            Text {
                                id: keyLabel
                                anchors.centerIn: parent
                                text: root.keyToken(keyChip.index).texto || "∅"
                                color: "#0F172A"
                                font.bold: true
                                font.pixelSize: 8 * root.sx
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            ScrollView {
                clip: true
                contentWidth: availableWidth
                Flow {
                    width: parent.width
                    spacing: 8 * root.sx
                    Repeater {
                        model: root.matrices.length
                        delegate: MiniHead {
                            required property int index
                            width: (parent.width - 16 * root.sx) / 3
                            height: 158 * root.sy
                            headNumber: index
                            matrix: root.matrices[index]
                            crossAttention: root.crossAttention
                            threshold: root.threshold
                            accent: root.colorForHead(index)
                            selected: root.headIndex === index
                            sx: root.sx; sy: root.sy
                            onClicked: {
                                root.headSelected(index)
                                root.showHeadGrid = false
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
                text: "Las conexiones bajo el umbral se ocultan para evitar saturación · la dirección es query → key."
                color: "#9A3412"
                font.pixelSize: 9 * root.sx
            }
        }
    }

    component FlowButton: Rectangle {
        id: flowButton
        property string label: ""
        property bool primary: false
        property real sx: 1
        property real sy: 1
        signal clicked()
        implicitWidth: buttonText.implicitWidth + 22 * sx
        implicitHeight: 32 * sy
        radius: 8 * sx
        color: primary ? "#0284C7" : "#FFFFFF"
        border.color: "#0284C7"
        Text { id: buttonText; anchors.centerIn: parent; text: flowButton.label; color: flowButton.primary ? "white" : "#0369A1"; font.bold: true; font.pixelSize: 9 * flowButton.sx }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: flowButton.clicked() }
    }

    component MiniHead: Rectangle {
        id: mini
        property int headNumber: 0
        property var matrix: []
        property bool crossAttention: false
        property real threshold: 0.05
        property color accent: "#0284C7"
        property bool selected: false
        property real sx: 1
        property real sy: 1
        signal clicked()
        radius: 10 * sx
        color: selected ? Qt.alpha(accent, 0.10) : "#F8FAFC"
        border.color: accent
        border.width: selected ? 2 : 1
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 7 * mini.sx
            spacing: 3 * mini.sy
            RowLayout {
                Layout.fillWidth: true
                Text { text: "H" + String(mini.headNumber + 1).padStart(2, "0"); color: mini.accent; font.bold: true; font.pixelSize: 10 * mini.sx }
                Item { Layout.fillWidth: true }
                Text { text: "clic para abrir"; color: "#64748B"; font.pixelSize: 7 * mini.sx }
            }
            Canvas {
                Layout.fillWidth: true
                Layout.fillHeight: true
                property var matrixValues: mini.matrix
                onMatrixValuesChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    var qCount = matrixValues.length
                    var kCount = qCount && matrixValues[0] ? matrixValues[0].length : 0
                    var qY = height - 10 * mini.sy
                    var kY = mini.crossAttention ? 10 * mini.sy : qY
                    var maxValue = 1e-9
                    for (var q = 0; q < qCount; ++q)
                        for (var k = 0; k < kCount; ++k)
                            maxValue = Math.max(maxValue, Number(matrixValues[q][k] || 0))
                    function xFor(i, count) { return (i + 0.5) / Math.max(1, count) * width }
                    for (var qi = 0; qi < qCount; ++qi) {
                        for (var ki = 0; ki < kCount; ++ki) {
                            var weight = Number(matrixValues[qi][ki] || 0)
                            if (weight < mini.threshold)
                                continue
                            var x0 = xFor(qi, qCount), x1 = xFor(ki, kCount)
                            ctx.beginPath(); ctx.moveTo(x0, qY)
                            if (mini.crossAttention)
                                ctx.bezierCurveTo(x0, height * 0.62, x1, height * 0.38, x1, kY)
                            else
                                ctx.quadraticCurveTo((x0 + x1) / 2,
                                                     qY - 15 * mini.sy - Math.abs(x1 - x0) * 0.22,
                                                     x1, kY)
                            ctx.strokeStyle = Qt.alpha(mini.accent, 0.2 + 0.7 * weight / maxValue)
                            ctx.lineWidth = (0.5 + 2.8 * weight / maxValue) * mini.sx
                            ctx.stroke()
                        }
                    }
                    for (var i = 0; i < qCount; ++i) {
                        ctx.beginPath(); ctx.arc(xFor(i, qCount), qY, 3 * mini.sx, 0, Math.PI * 2)
                        ctx.fillStyle = mini.accent; ctx.fill()
                    }
                    if (mini.crossAttention) {
                        for (var j = 0; j < kCount; ++j) {
                            ctx.beginPath(); ctx.arc(xFor(j, kCount), kY, 3 * mini.sx, 0, Math.PI * 2)
                            ctx.fillStyle = "#64748B"; ctx.fill()
                        }
                    }
                }
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mini.clicked() }
    }
}
