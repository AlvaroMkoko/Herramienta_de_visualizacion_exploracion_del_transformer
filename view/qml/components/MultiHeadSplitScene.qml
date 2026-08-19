pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var metadata: ({})
    property var attentionData: ({})
    property bool active: false
    property bool reducedMotion: false
    property real sx: 1
    property real sy: 1
    property real animationProgress: 0

    readonly property int numHeads: Math.max(1, Number(metadata.num_heads || 1))
    readonly property int dModel: Math.max(1, Number(metadata.d_model || 1))
    readonly property int dHead: Math.max(1, Number(metadata.d_head || Math.floor(dModel / numHeads)))
    readonly property var headOutputs: attentionData.salida_cabezas || []
    readonly property var concatenated: attentionData.salida_concatenada || []
    readonly property var projected: attentionData.salida_proyectada || []
    readonly property var palettes: ["#0284C7", "#7C3AED", "#D97706", "#059669",
                                     "#DB2777", "#4F46E5", "#DC2626", "#0891B2",
                                     "#9333EA", "#65A30D", "#EA580C", "#0F766E"]

    function colorAt(index) { return palettes[index % palettes.length] }
    function norm(values) {
        var sum = 0
        for (var i = 0; i < values.length; ++i)
            sum += Number(values[i] || 0) * Number(values[i] || 0)
        return Math.sqrt(sum)
    }
    function reveal(start, span) {
        if (reducedMotion)
            return 1
        return Math.max(0, Math.min(1, (animationProgress - start) / span))
    }
    function replay() {
        journey.stop()
        animationProgress = 0
        if (reducedMotion)
            animationProgress = 1
        else
            journey.start()
    }

    onActiveChanged: {
        if (active)
            replay()
        else
            journey.stop()
    }
    onAnimationProgressChanged: fanCanvas.requestPaint()
    onNumHeadsChanged: fanCanvas.requestPaint()

    NumberAnimation {
        id: journey
        target: root
        property: "animationProgress"
        from: 0
        to: 1
        duration: 4800
        easing.type: Easing.InOutCubic
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 9 * root.sy

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48 * root.sy
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1 * root.sy
                Text {
                    text: "Split → procesamiento independiente → concat → Wᴼ"
                    color: "#0F172A"
                    font.bold: true
                    font.pixelSize: 17 * Math.min(root.sx, root.sy)
                }
                Text {
                    text: root.dModel + " dimensiones = " + root.numHeads + " cabezas × " + root.dHead + " dimensiones"
                    color: "#D97706"
                    font.bold: true
                    font.pixelSize: 10 * root.sx
                }
            }
            ReplayButton { sx: root.sx; sy: root.sy; onClicked: root.replay() }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12 * root.sx
            color: "#FFFBEB"
            border.color: "#FCD34D"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 13 * root.sx
                spacing: 7 * root.sy

                Text {
                    text: "1 · VECTOR COMPLETO · d_model = " + root.dModel
                    color: "#92400E"
                    font.bold: true
                    font.pixelSize: 9 * root.sx
                }
                Row {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42 * root.sy
                    Repeater {
                        model: root.numHeads
                        delegate: Rectangle {
                            required property int index
                            width: parent.width / root.numHeads
                            height: parent.height
                            color: root.colorAt(index)
                            border.color: "#FFFFFF"
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: "H" + String(index + 1).padStart(2, "0")
                                color: "white"
                                font.bold: true
                                visible: parent.width > 34 * root.sx
                                font.pixelSize: 8 * root.sx
                            }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: "Los segmentos forman una partición contigua. Ninguna cabeza recibe una copia de las "
                          + root.dModel + " dimensiones."
                    color: "#78350F"
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 9 * root.sx
                }

                Canvas {
                    id: fanCanvas
                    Layout.fillWidth: true
                    Layout.preferredHeight: 55 * root.sy
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset()
                        var progress = root.reveal(0.08, 0.27)
                        for (var i = 0; i < root.numHeads; ++i) {
                            var x0 = (i + 0.5) / root.numHeads * width
                            var spread = Math.min(width - 20 * root.sx,
                                                  root.numHeads * 112 * root.sx)
                            var left = (width - spread) / 2
                            var x1 = left + (i + 0.5) / root.numHeads * spread
                            var endX = x0 + (x1 - x0) * progress
                            var endY = 8 * root.sy + (height - 12 * root.sy) * progress
                            ctx.beginPath(); ctx.moveTo(x0, 2 * root.sy)
                            ctx.bezierCurveTo(x0, height * 0.45, endX, height * 0.5, endX, endY)
                            ctx.strokeStyle = root.colorAt(i)
                            ctx.lineWidth = 2 * root.sx
                            ctx.stroke()
                        }
                    }
                }

                Text {
                    text: "2 · CABEZAS EN PARALELO · salida real de la query actual"
                    color: "#92400E"
                    font.bold: true
                    font.pixelSize: 9 * root.sx
                    opacity: root.reveal(0.18, 0.18)
                }
                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 105 * root.sy
                    contentWidth: headRow.implicitWidth
                    contentHeight: availableHeight
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                    Row {
                        id: headRow
                        height: parent.height
                        spacing: 6 * root.sx
                        Repeater {
                            model: root.numHeads
                            delegate: Rectangle {
                                id: headCard
                                required property int index
                                width: Math.max(94 * root.sx,
                                                (headRow.parent.width - (root.numHeads - 1) * 6 * root.sx)
                                                / Math.min(root.numHeads, 8))
                                height: headRow.height - 5 * root.sy
                                radius: 9 * root.sx
                                color: Qt.alpha(root.colorAt(index), 0.10)
                                border.color: root.colorAt(index)
                                opacity: root.reveal(0.18 + index / Math.max(1, root.numHeads) * 0.12, 0.18)
                                scale: 0.88 + opacity * 0.12
                                Behavior on opacity { NumberAnimation { duration: root.reducedMotion ? 0 : 180 } }
                                Column {
                                    anchors.centerIn: parent
                                    width: parent.width - 12 * root.sx
                                    spacing: 3 * root.sy
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "H" + String(headCard.index + 1).padStart(2, "0"); color: root.colorAt(headCard.index); font.bold: true; font.pixelSize: 12 * root.sx }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.dHead + " dims"; color: "#475569"; font.pixelSize: 8 * root.sx }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "‖z‖ " + root.norm(root.headOutputs.length > headCard.index ? root.headOutputs[headCard.index] : []).toFixed(3)
                                        color: "#0F172A"
                                        font.bold: true
                                        font.pixelSize: 9 * root.sx
                                    }
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: parent.width - 8 * root.sx; height: 7 * root.sy; radius: height / 2
                                        color: "#E2E8F0"
                                        Rectangle {
                                            width: parent.width * Math.min(1, root.norm(root.headOutputs.length > headCard.index ? root.headOutputs[headCard.index] : []) / 5)
                                            height: parent.height; radius: parent.radius; color: root.colorAt(headCard.index)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88 * root.sy
                    spacing: 10 * root.sx
                    opacity: root.reveal(0.52, 0.18)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4 * root.sy
                        Text { text: "3 · CONCAT · vuelve a d_model = " + root.dModel; color: "#92400E"; font.bold: true; font.pixelSize: 9 * root.sx }
                        Row {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34 * root.sy
                            Repeater {
                                model: root.numHeads
                                delegate: Rectangle {
                                    required property int index
                                    width: parent.width / root.numHeads; height: parent.height
                                    color: root.colorAt(index); border.color: "#FFFFFF"
                                }
                            }
                        }
                        Text { text: "‖concat real‖ " + root.norm(root.concatenated).toFixed(4); color: "#475569"; font.pixelSize: 8 * root.sx }
                    }

                    Text { text: "→"; color: "#D97706"; font.bold: true; font.pixelSize: 24 * root.sx }

                    Rectangle {
                        Layout.preferredWidth: 150 * root.sx
                        Layout.fillHeight: true
                        radius: 9 * root.sx
                        color: "#FFFFFF"
                        border.color: "#D97706"
                        Canvas {
                            anchors.fill: parent
                            anchors.margins: 8 * root.sx
                            onPaint: {
                                var ctx = getContext("2d"); ctx.reset()
                                for (var i = 0; i < 7; ++i) {
                                    ctx.beginPath(); ctx.moveTo(0, i / 6 * height)
                                    ctx.lineTo(width, ((i * 3) % 7) / 6 * height)
                                    ctx.strokeStyle = root.colorAt(i); ctx.globalAlpha = 0.65
                                    ctx.lineWidth = 1.4 * root.sx; ctx.stroke()
                                }
                                ctx.globalAlpha = 1
                            }
                        }
                        Text { anchors.centerIn: parent; text: "Wᴼ\nmezcla"; color: "#92400E"; font.bold: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 10 * root.sx }
                    }

                    Text { text: "→"; color: "#D97706"; font.bold: true; font.pixelSize: 24 * root.sx }

                    ColumnLayout {
                        Layout.preferredWidth: 215 * root.sx
                        spacing: 4 * root.sy
                        Text { text: "4 · SALIDA PROYECTADA"; color: "#92400E"; font.bold: true; font.pixelSize: 9 * root.sx }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 34 * root.sy; radius: 7 * root.sx
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: "#7C3AED" }
                                GradientStop { position: 0.45; color: "#D97706" }
                                GradientStop { position: 1; color: "#059669" }
                            }
                            Text { anchors.centerIn: parent; text: root.dModel + " dims mezcladas"; color: "white"; font.bold: true; font.pixelSize: 9 * root.sx }
                        }
                        Text { text: "‖Wᴼz‖ " + root.norm(root.projected).toFixed(4); color: "#475569"; font.pixelSize: 8 * root.sx }
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
                text: "Los colores identifican particiones durante split y concat; Wᴼ puede mezclar información entre todas ellas."
                color: "#9A3412"
                font.pixelSize: 9 * root.sx
            }
        }
    }

    component ReplayButton: Rectangle {
        id: button
        property real sx: 1
        property real sy: 1
        signal clicked()
        implicitWidth: 112 * sx; implicitHeight: 32 * sy; radius: 8 * sx
        color: "#D97706"
        Text { anchors.centerIn: parent; text: "↺ Reproducir"; color: "white"; font.bold: true; font.pixelSize: 9 * button.sx }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: button.clicked() }
    }
}
