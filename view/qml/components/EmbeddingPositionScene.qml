pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var projection: ({})
    property var tokens: []
    property bool active: false
    property bool reducedMotion: false
    property real sx: 1
    property real sy: 1
    property real progress: 0
    property bool showBothClouds: true
    property int hoveredIndex: -1

    readonly property var embeddingPoints: projection && projection.embedding
                                                   ? projection.embedding : []
    readonly property var positionedPoints: projection && projection.entrada
                                                    ? projection.entrada : []
    readonly property int count: Math.min(embeddingPoints.length, positionedPoints.length)
    readonly property int positionOffset: Number(projection.inicio_posicion || 0)

    function px(point) {
        return point && point.x !== undefined ? Number(point.x)
                                                  : Number(point && point.length ? point[0] : 0)
    }

    function py(point) {
        return point && point.y !== undefined ? Number(point.y)
                                                  : Number(point && point.length > 1 ? point[1] : 0)
    }

    function allBounds() {
        var result = { minX: 1e30, maxX: -1e30, minY: 1e30, maxY: -1e30 }
        for (var i = 0; i < count; ++i) {
            var candidates = [embeddingPoints[i], positionedPoints[i]]
            for (var j = 0; j < candidates.length; ++j) {
                result.minX = Math.min(result.minX, px(candidates[j]))
                result.maxX = Math.max(result.maxX, px(candidates[j]))
                result.minY = Math.min(result.minY, py(candidates[j]))
                result.maxY = Math.max(result.maxY, py(candidates[j]))
            }
        }
        if (result.minX > result.maxX)
            return { minX: -1, maxX: 1, minY: -1, maxY: 1 }
        var marginX = Math.max(1e-6, (result.maxX - result.minX) * 0.12)
        var marginY = Math.max(1e-6, (result.maxY - result.minY) * 0.16)
        if (Math.abs(result.maxX - result.minX) < 1e-8)
            marginX = 1
        if (Math.abs(result.maxY - result.minY) < 1e-8)
            marginY = 1
        result.minX -= marginX
        result.maxX += marginX
        result.minY -= marginY
        result.maxY += marginY
        return result
    }

    function tokenAt(localIndex) {
        var absolute = positionOffset + localIndex
        for (var i = 0; i < tokens.length; ++i) {
            if (Number(tokens[i].posicion) === absolute)
                return tokens[i]
        }
        return localIndex < tokens.length ? tokens[localIndex]
                                          : ({ texto: "T" + (absolute + 1), posicion: absolute })
    }

    function colorAt(localIndex) {
        var ratio = count <= 1 ? 0 : localIndex / (count - 1)
        return Qt.hsla(0.74 - ratio * 0.66, 0.72, 0.50, 1)
    }

    function replay() {
        travel.stop()
        progress = 0
        if (reducedMotion)
            progress = 1
        else
            travel.start()
    }

    onActiveChanged: {
        if (active)
            replay()
        else
            travel.stop()
    }
    onProjectionChanged: {
        progress = 0
        plot.requestPaint()
        if (active)
            replay()
    }
    onProgressChanged: plot.requestPaint()
    onShowBothCloudsChanged: plot.requestPaint()
    onHoveredIndexChanged: plot.requestPaint()

    NumberAnimation {
        id: travel
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 1800
        easing.type: Easing.InOutCubic
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 9 * root.sy

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 46 * root.sy
            spacing: 9 * root.sx
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1 * root.sy
                Text {
                    text: "Embedding puro  →  embedding + posición"
                    color: "#0F172A"
                    font.bold: true
                    font.pixelSize: 17 * Math.min(root.sx, root.sy)
                }
                Text {
                    text: "PCA calculado una sola vez sobre origen y destino · cada flecha es una suma vectorial real"
                    color: "#64748B"
                    font.pixelSize: 10 * root.sx
                }
            }
            SceneButton {
                label: "↺ Reproducir"
                primary: true
                sx: root.sx; sy: root.sy
                onClicked: root.replay()
            }
            SceneButton {
                label: root.showBothClouds ? "Nubes: ambas" : "Nube: actual"
                selected: root.showBothClouds
                sx: root.sx; sy: root.sy
                onClicked: root.showBothClouds = !root.showBothClouds
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50 * root.sy
            radius: 10 * root.sx
            color: "#F5F3FF"
            border.color: "#C4B5FD"
            RowLayout {
                anchors.fill: parent
                anchors.margins: 9 * root.sx
                spacing: 10 * root.sx
                Text { text: "E · √d"; color: "#6D28D9"; font.bold: true; font.pixelSize: 10 * root.sx }
                Slider {
                    id: progressSlider
                    Layout.fillWidth: true
                    from: 0; to: 1; value: root.progress
                    onMoved: {
                        travel.stop()
                        root.progress = value
                    }
                    background: Rectangle {
                        x: progressSlider.leftPadding
                        y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                        width: progressSlider.availableWidth
                        height: 7 * root.sy
                        radius: height / 2
                        color: "#DDD6FE"
                        Rectangle {
                            width: progressSlider.visualPosition * parent.width
                            height: parent.height
                            radius: parent.radius
                            color: "#7C3AED"
                        }
                    }
                    handle: Rectangle {
                        x: progressSlider.leftPadding + progressSlider.visualPosition
                           * (progressSlider.availableWidth - width)
                        y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                        width: 20 * root.sx; height: 20 * root.sy
                        radius: width / 2
                        color: "#FFFFFF"
                        border.color: "#7C3AED"
                        border.width: 3
                    }
                }
                Text {
                    text: "+ " + Math.round(root.progress * 100) + "% PE"
                    color: "#7C3AED"
                    font.bold: true
                    font.pixelSize: 10 * root.sx
                }
                Text { text: "X₀"; color: "#5B21B6"; font.bold: true; font.pixelSize: 10 * root.sx }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12 * root.sx
            color: "#FAFAFF"
            border.color: "#DDD6FE"
            clip: true

            Canvas {
                id: plot
                anchors.fill: parent
                anchors.margins: 8 * root.sx

                function screenPoint(point, bounds) {
                    var left = 42 * root.sx
                    var top = 32 * root.sy
                    var usableW = Math.max(1, width - left - 30 * root.sx)
                    var usableH = Math.max(1, height - top - 42 * root.sy)
                    return {
                        x: left + (root.px(point) - bounds.minX) / (bounds.maxX - bounds.minX) * usableW,
                        y: top + (1 - (root.py(point) - bounds.minY) / (bounds.maxY - bounds.minY)) * usableH
                    }
                }

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var bounds = root.allBounds()
                    var left = 42 * root.sx
                    var top = 32 * root.sy
                    var right = width - 30 * root.sx
                    var bottom = height - 42 * root.sy

                    ctx.strokeStyle = "#E2E8F0"
                    ctx.lineWidth = 1
                    for (var grid = 0; grid <= 5; ++grid) {
                        var gx = left + (right - left) * grid / 5
                        var gy = top + (bottom - top) * grid / 5
                        ctx.beginPath(); ctx.moveTo(gx, top); ctx.lineTo(gx, bottom); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(left, gy); ctx.lineTo(right, gy); ctx.stroke()
                    }
                    ctx.fillStyle = "#64748B"
                    ctx.font = Math.max(9, 9 * root.sx) + "px sans-serif"
                    ctx.fillText("PC2", left - 32 * root.sx, top)
                    ctx.fillText("PC1", right - 18 * root.sx, bottom + 26 * root.sy)

                    for (var i = 0; i < root.count; ++i) {
                        var start = screenPoint(root.embeddingPoints[i], bounds)
                        var end = screenPoint(root.positionedPoints[i], bounds)
                        var current = {
                            x: start.x + (end.x - start.x) * root.progress,
                            y: start.y + (end.y - start.y) * root.progress
                        }
                        var color = root.colorAt(i)

                        if (root.showBothClouds) {
                            ctx.setLineDash([4 * root.sx, 4 * root.sx])
                            ctx.beginPath(); ctx.moveTo(start.x, start.y); ctx.lineTo(end.x, end.y)
                            ctx.strokeStyle = Qt.alpha(color, i === root.hoveredIndex ? 0.9 : 0.42)
                            ctx.lineWidth = (i === root.hoveredIndex ? 2.6 : 1.2) * root.sx
                            ctx.stroke()
                            ctx.setLineDash([])

                            ctx.beginPath(); ctx.arc(start.x, start.y, 4.5 * root.sx, 0, Math.PI * 2)
                            ctx.fillStyle = Qt.alpha(color, 0.24); ctx.fill()
                            ctx.strokeStyle = color; ctx.lineWidth = 1.1 * root.sx; ctx.stroke()

                            ctx.beginPath(); ctx.rect(end.x - 4 * root.sx, end.y - 4 * root.sx,
                                                    8 * root.sx, 8 * root.sx)
                            ctx.fillStyle = Qt.alpha(color, 0.18); ctx.fill()
                            ctx.strokeStyle = color; ctx.stroke()
                        }

                        ctx.beginPath();
                        ctx.arc(current.x, current.y,
                                (i === root.hoveredIndex ? 8 : 6) * root.sx, 0, Math.PI * 2)
                        ctx.fillStyle = color; ctx.fill()
                        ctx.strokeStyle = "#FFFFFF"; ctx.lineWidth = 2 * root.sx; ctx.stroke()

                        if (i === root.hoveredIndex || root.count <= 10) {
                            var token = root.tokenAt(i)
                            ctx.fillStyle = "#0F172A"
                            ctx.font = (i === root.hoveredIndex ? "bold " : "")
                                       + Math.max(9, 9 * root.sx) + "px sans-serif"
                            ctx.fillText(String(token.texto || "∅") + " · p" + Number(token.posicion),
                                         current.x + 9 * root.sx, current.y - 8 * root.sy)
                        }
                    }

                    if (!root.count) {
                        ctx.fillStyle = "#64748B"
                        ctx.font = "bold " + Math.max(12, 14 * root.sx) + "px sans-serif"
                        ctx.textAlign = "center"
                        ctx.fillText("La proyección aparecerá con la captura del token más reciente.",
                                     width / 2, height / 2)
                        ctx.textAlign = "left"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onPositionChanged: function(mouse) {
                        var bounds = root.allBounds()
                        var best = -1
                        var bestDistance = 18 * root.sx
                        for (var i = 0; i < root.count; ++i) {
                            var start = plot.screenPoint(root.embeddingPoints[i], bounds)
                            var end = plot.screenPoint(root.positionedPoints[i], bounds)
                            var x = start.x + (end.x - start.x) * root.progress
                            var y = start.y + (end.y - start.y) * root.progress
                            var distance = Math.sqrt(Math.pow(mouse.x - x, 2) + Math.pow(mouse.y - y, 2))
                            if (distance < bestDistance) {
                                bestDistance = distance
                                best = i
                            }
                        }
                        root.hoveredIndex = best
                    }
                    onExited: root.hoveredIndex = -1
                }
            }

            Row {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 14 * root.sx
                spacing: 16 * root.sx
                LegendMark { label: "Embedding puro"; square: false; sx: root.sx }
                LegendMark { label: "Embedding + posición"; square: true; sx: root.sx }
                Text {
                    text: "color = posición 0 → " + Math.max(0, root.count - 1)
                    color: "#64748B"
                    font.pixelSize: 9 * root.sx
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
                text: "Proyección PCA 2D · las distancias pueden distorsionarse; no son distancias exactas del espacio de "
                      + Number(root.projection.dimension_original || 0) + " dimensiones."
                color: "#9A3412"
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 9 * root.sx
            }
        }
    }

    component SceneButton: Rectangle {
        id: sceneButton
        property string label: ""
        property bool primary: false
        property bool selected: false
        property real sx: 1
        property real sy: 1
        signal clicked()
        implicitWidth: buttonText.implicitWidth + 22 * sx
        implicitHeight: 32 * sy
        radius: 8 * sx
        color: primary || selected ? "#7C3AED" : "#FFFFFF"
        border.color: "#7C3AED"
        Text { id: buttonText; anchors.centerIn: parent; text: sceneButton.label; color: sceneButton.primary || sceneButton.selected ? "white" : "#6D28D9"; font.bold: true; font.pixelSize: 9 * sceneButton.sx }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sceneButton.clicked() }
    }

    component LegendMark: Row {
        id: legend
        property string label: ""
        property bool square: false
        property real sx: 1
        spacing: 5 * sx
        Canvas {
            width: 13 * legend.sx; height: 13 * legend.sx
            onPaint: {
                var ctx = getContext("2d"); ctx.reset(); ctx.strokeStyle = "#7C3AED"; ctx.fillStyle = "#337C3AED"; ctx.lineWidth = 1.5
                if (legend.square) { ctx.fillRect(2, 2, width - 4, height - 4); ctx.strokeRect(2, 2, width - 4, height - 4) }
                else { ctx.beginPath(); ctx.arc(width / 2, height / 2, width / 2 - 2, 0, Math.PI * 2); ctx.fill(); ctx.stroke() }
            }
        }
        Text { text: legend.label; color: "#475569"; font.pixelSize: 9 * legend.sx }
    }
}
