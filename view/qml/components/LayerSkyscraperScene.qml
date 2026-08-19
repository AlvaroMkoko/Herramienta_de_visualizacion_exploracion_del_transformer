pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var trajectory: ({})
    property var tokens: []
    property bool active: false
    property real sx: 1
    property real sy: 1
    property int selectedToken: 0

    readonly property var floors: trajectory && trajectory.capas ? trajectory.capas : []
    readonly property int positionOffset: Number(trajectory.inicio_posicion || 0)

    function pointX(point) {
        return point && point.x !== undefined ? Number(point.x)
                                                  : Number(point && point.length ? point[0] : 0)
    }

    function pointY(point) {
        return point && point.y !== undefined ? Number(point.y)
                                                  : Number(point && point.length > 1 ? point[1] : 0)
    }

    function bounds() {
        var result = { minX: 1e30, maxX: -1e30, minY: 1e30, maxY: -1e30 }
        for (var layer = 0; layer < floors.length; ++layer) {
            var points = floors[layer].puntos || []
            for (var i = 0; i < points.length; ++i) {
                result.minX = Math.min(result.minX, pointX(points[i]))
                result.maxX = Math.max(result.maxX, pointX(points[i]))
                result.minY = Math.min(result.minY, pointY(points[i]))
                result.maxY = Math.max(result.maxY, pointY(points[i]))
            }
        }
        if (result.minX > result.maxX)
            return { minX: -1, maxX: 1, minY: -1, maxY: 1 }
        if (Math.abs(result.maxX - result.minX) < 1e-9) {
            result.minX -= 1
            result.maxX += 1
        }
        if (Math.abs(result.maxY - result.minY) < 1e-9) {
            result.minY -= 1
            result.maxY += 1
        }
        return result
    }

    function reversedFloors() {
        var result = []
        for (var i = floors.length - 1; i >= 0; --i)
            result.push(floors[i])
        return result
    }

    function tokenForPoint(localIndex) {
        var absolutePosition = positionOffset + localIndex
        for (var i = 0; i < tokens.length; ++i) {
            if (Number(tokens[i].posicion) === absolutePosition)
                return tokens[i]
        }
        return localIndex < tokens.length ? tokens[localIndex] : ({ texto: "T" + (absolutePosition + 1) })
    }

    function tokenColor(localIndex, total) {
        var ratio = total <= 1 ? 0 : localIndex / (total - 1)
        return Qt.hsla(0.72 - 0.62 * ratio, 0.70, 0.50, 1)
    }

    onTrajectoryChanged: {
        var count = floors.length && floors[0].puntos ? floors[0].puntos.length : 0
        selectedToken = Math.max(0, Math.min(count - 1, selectedToken))
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 9 * root.sy

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 54 * root.sy
            spacing: 9 * root.sx

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1 * root.sy
                Text {
                    text: "Rascacielos de representaciones"
                    color: "#0F172A"
                    font.bold: true
                    font.pixelSize: 17 * Math.min(root.sx, root.sy)
                }
                Text {
                    text: "Cada piso usa hidden states reales · todos comparten los mismos ejes PCA"
                    color: "#64748B"
                    font.pixelSize: 10 * root.sx
                }
            }

            Text {
                text: "SIGUE UN TOKEN"
                color: "#4F46E5"
                font.bold: true
                font.pixelSize: 9 * root.sx
            }
            ListView {
                Layout.preferredWidth: 430 * root.sx
                Layout.fillHeight: true
                orientation: ListView.Horizontal
                spacing: 5 * root.sx
                clip: true
                model: root.floors.length && root.floors[0].puntos
                       ? root.floors[0].puntos.length : 0
                delegate: Rectangle {
                    id: tokenChoice
                    required property int index
                    width: Math.max(42 * root.sx, choiceText.implicitWidth + 14 * root.sx)
                    height: 32 * root.sy
                    radius: 8 * root.sx
                    color: root.selectedToken === index ? root.tokenColor(index, ListView.view.count) : "#F8FAFC"
                    border.color: root.tokenColor(index, ListView.view.count)
                    border.width: root.selectedToken === index ? 2 : 1
                    Text {
                        id: choiceText
                        anchors.centerIn: parent
                        text: root.tokenForPoint(tokenChoice.index).texto || "∅"
                        color: root.selectedToken === tokenChoice.index ? "white" : "#334155"
                        font.bold: true
                        font.pixelSize: 9 * root.sx
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedToken = tokenChoice.index
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38 * root.sy
            radius: 9 * root.sx
            color: "#EEF2FF"
            border.color: "#A5B4FC"
            RowLayout {
                anchors.fill: parent
                anchors.margins: 8 * root.sx
                Text { text: "↕"; color: "#4F46E5"; font.bold: true; font.pixelSize: 15 * root.sx }
                Text {
                    Layout.fillWidth: true
                    text: "Desplázate para subir de capa. El halo identifica “"
                          + (root.tokenForPoint(root.selectedToken).texto || "token") + "” en todos los pisos."
                    color: "#3730A3"
                    font.pixelSize: 10 * root.sx
                }
                Text {
                    text: "varianza conservada "
                          + (Number(root.trajectory.varianza_conservada || 0) * 100).toFixed(1) + "%"
                    color: "#4F46E5"
                    font.bold: true
                    font.pixelSize: 9 * root.sx
                }
            }
        }

        ScrollView {
            id: buildingScroll
            objectName: "layerSkyscraperScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            ColumnLayout {
                width: buildingScroll.availableWidth
                spacing: 10 * root.sy

                Repeater {
                    model: root.reversedFloors()
                    delegate: Rectangle {
                        id: floorCard
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 154 * root.sy
                        radius: 12 * root.sx
                        color: floorCard.index === 0 ? "#EEF2FF" : "#F8FAFC"
                        border.color: floorCard.index === 0 ? "#6366F1" : "#CBD5E1"
                        border.width: floorCard.index === 0 ? 2 : 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10 * root.sx
                            spacing: 12 * root.sx

                            Rectangle {
                                Layout.preferredWidth: 104 * root.sx
                                Layout.fillHeight: true
                                radius: 10 * root.sx
                                color: floorCard.index === 0 ? "#4F46E5" : "#E0E7FF"
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4 * root.sy
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: floorCard.modelData.capa === 0 ? "ENTRADA" : "CAPA"
                                        color: floorCard.index === 0 ? "#C7D2FE" : "#6366F1"
                                        font.bold: true
                                        font.pixelSize: 9 * root.sx
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: floorCard.modelData.capa === 0 ? "X₀" : floorCard.modelData.capa
                                        color: floorCard.index === 0 ? "white" : "#3730A3"
                                        font.bold: true
                                        font.pixelSize: 30 * Math.min(root.sx, root.sy)
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: (floorCard.modelData.puntos || []).length + " tokens"
                                        color: floorCard.index === 0 ? "#E0E7FF" : "#4F46E5"
                                        font.pixelSize: 9 * root.sx
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 9 * root.sx
                                color: "#FFFFFF"
                                border.color: "#D8E0EA"
                                Canvas {
                                    id: scatterCanvas
                                    anchors.fill: parent
                                    anchors.margins: 8 * root.sx
                                    property var points: floorCard.modelData.puntos || []
                                    property var sharedBounds: root.bounds()
                                    onPointsChanged: requestPaint()
                                    onSharedBoundsChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.reset()
                                        var pad = 18 * root.sx
                                        var plotW = Math.max(1, width - 2 * pad)
                                        var plotH = Math.max(1, height - 2 * pad)
                                        ctx.strokeStyle = "#E2E8F0"
                                        ctx.lineWidth = 1
                                        for (var grid = 1; grid < 4; ++grid) {
                                            var gx = pad + plotW * grid / 4
                                            var gy = pad + plotH * grid / 4
                                            ctx.beginPath(); ctx.moveTo(gx, pad); ctx.lineTo(gx, pad + plotH); ctx.stroke()
                                            ctx.beginPath(); ctx.moveTo(pad, gy); ctx.lineTo(pad + plotW, gy); ctx.stroke()
                                        }
                                        for (var i = 0; i < points.length; ++i) {
                                            var x = pad + (root.pointX(points[i]) - sharedBounds.minX)
                                                    / (sharedBounds.maxX - sharedBounds.minX) * plotW
                                            var y = pad + (1 - (root.pointY(points[i]) - sharedBounds.minY)
                                                    / (sharedBounds.maxY - sharedBounds.minY)) * plotH
                                            if (i === root.selectedToken) {
                                                ctx.beginPath()
                                                ctx.arc(x, y, 10 * root.sx, 0, Math.PI * 2)
                                                ctx.fillStyle = "#334F46E5"
                                                ctx.fill()
                                                ctx.strokeStyle = "#4F46E5"
                                                ctx.lineWidth = 2.5 * root.sx
                                                ctx.stroke()
                                            }
                                            ctx.beginPath()
                                            ctx.arc(x, y, (i === root.selectedToken ? 5.5 : 4) * root.sx,
                                                    0, Math.PI * 2)
                                            ctx.fillStyle = root.tokenColor(i, points.length)
                                            ctx.fill()
                                            ctx.strokeStyle = "#FFFFFF"
                                            ctx.lineWidth = 1.2 * root.sx
                                            ctx.stroke()
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.preferredWidth: 190 * root.sx
                                Layout.fillHeight: true
                                spacing: 4 * root.sy
                                Text {
                                    Layout.fillWidth: true
                                    text: floorCard.index === 0 ? "Estado contextual final" : "Representación intermedia"
                                    color: "#0F172A"
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                    font.pixelSize: 11 * root.sx
                                }
                                Text {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    text: "“" + (root.tokenForPoint(root.selectedToken).texto || "token")
                                          + "” mantiene su identidad; cambia su posición relativa frente a los demás tokens."
                                    color: "#64748B"
                                    wrapMode: Text.WordWrap
                                    font.pixelSize: 9 * root.sx
                                }
                                Text {
                                    text: "PCA conjunto · ejes fijos"
                                    color: "#4F46E5"
                                    font.bold: true
                                    font.pixelSize: 9 * root.sx
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
