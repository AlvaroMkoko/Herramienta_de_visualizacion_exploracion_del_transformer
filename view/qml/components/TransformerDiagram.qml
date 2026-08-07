pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../styles" as Style

Item {
    id: root

    property var bridge
    property color flowColor: "#666577"
    property color attentionColor: "#9a641b"
    property color residualColor: "#6c5fc3"

    readonly property real designWidth: 820
    readonly property real designHeight: 900

    Item {
        id: stage
        width: root.designWidth
        height: root.designHeight
        anchors.centerIn: parent
        transformOrigin: Item.Center
        scale: Math.min(root.width / width, root.height / height)

        Canvas {
            id: connections
            anchors.fill: parent

            function arrowHead(ctx, x1, y1, x2, y2, color, size) {
                const angle = Math.atan2(y2 - y1, x2 - x1)
                const arrowSize = size || 8
                ctx.beginPath()
                ctx.fillStyle = color
                ctx.moveTo(x2, y2)
                ctx.lineTo(x2 - arrowSize * Math.cos(angle - Math.PI / 6),
                           y2 - arrowSize * Math.sin(angle - Math.PI / 6))
                ctx.lineTo(x2 - arrowSize * Math.cos(angle + Math.PI / 6),
                           y2 - arrowSize * Math.sin(angle + Math.PI / 6))
                ctx.closePath()
                ctx.fill()
            }

            function arrow(ctx, x1, y1, x2, y2, color, width, size) {
                ctx.beginPath()
                ctx.strokeStyle = color
                ctx.lineWidth = width || 1.5
                ctx.moveTo(x1, y1)
                ctx.lineTo(x2, y2)
                ctx.stroke()
                arrowHead(ctx, x1, y1, x2, y2, color, size)
            }

            function polyArrow(ctx: var, points: var, color: color, width: real, size: real) {
                ctx.beginPath()
                ctx.strokeStyle = color
                ctx.lineWidth = width || 1.5
                ctx.moveTo(points[0][0], points[0][1])
                for (let i = 1; i < points.length; ++i)
                    ctx.lineTo(points[i][0], points[i][1])
                ctx.stroke()
                const before = points[points.length - 2]
                const end = points[points.length - 1]
                arrowHead(ctx, before[0], before[1], end[0], end[1], color, size)
            }

            function bracket(ctx, x, top, bottom, opensRight, color) {
                const tick = opensRight ? 11 : -11
                ctx.beginPath()
                ctx.strokeStyle = color
                ctx.lineWidth = 2
                ctx.moveTo(x + tick, top)
                ctx.lineTo(x, top)
                ctx.lineTo(x, bottom)
                ctx.lineTo(x + tick, bottom)
                ctx.stroke()
            }

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.lineCap = "round"
                ctx.lineJoin = "round"

                const encX = 202
                const decX = 598
                const encLeft = 82
                const encRight = 322
                const decLeft = 478
                const decRight = 718
                const grey = root.flowColor
                const residual = root.residualColor

                // Encoder main flow: Inputs → embedding → positional addition.
                arrow(ctx, encX, 855, encX, 839, grey, 1.7)                         // 1
                arrow(ctx, encX, 775, encX, 737, grey, 1.7)                         // 2
                arrow(ctx, 150, 720, 185, 720, residual, 1.5)                       // 3

                // Three Q/K/V inputs to encoder self-attention.
                arrow(ctx, encX, 703, encX, 652, grey, 1.7)                         // 4
                polyArrow(ctx, [[encX, 680], [142, 680], [142, 652]], grey, 1.5)    // 5
                polyArrow(ctx, [[encX, 680], [262, 680], [262, 652]], grey, 1.5)    // 6

                // Encoder attention, residual, feed-forward, and residual.
                arrow(ctx, encX, 580, encX, 538, grey, 1.7)                         // 7
                polyArrow(ctx, [[encX, 690], [50, 690], [50, 508], [encLeft, 508]], residual, 1.7) // 8 This one
                arrow(ctx, encX, 490, encX, 462, grey, 1.7)                         // 9
                arrow(ctx, encX, 400, encX, 358, grey, 1.7)                         // 10
                polyArrow(ctx, [[encX, 472], [61, 472], [61, 328], [encLeft, 328]], residual, 1.7) // 11

                // Encoder output provides K and V to decoder cross-attention.
                polyArrow(ctx, [[encX, 310], [encX, 248], [403, 248], [403, 492], [548, 492], [548, 472]], root.attentionColor, 1.8) // 12
                polyArrow(ctx, [[encX, 310], [encX, 236], [442, 236], [442, 504], [648, 504], [648, 472]], root.attentionColor, 1.8) // 13

                // Decoder main flow: shifted outputs → embedding → addition.
                arrow(ctx, decX, 855, decX, 839, grey, 1.7)                         // 14
                arrow(ctx, decX, 775, decX, 737, grey, 1.7)                         // 15
                arrow(ctx, 670, 720, 615, 720, residual, 1.5)                       // 16

                // Three inputs to masked self-attention.
                arrow(ctx, decX, 703, decX, 662, grey, 1.7)                         // 17
                polyArrow(ctx, [[decX, 682], [538, 682], [538, 662]], grey, 1.5)    // 18
                polyArrow(ctx, [[decX, 682], [658, 682], [658, 662]], grey, 1.5)    // 19

                // Masked attention and its residual path.
                arrow(ctx, decX, 590, decX, 568, grey, 1.7)                         // 20
                polyArrow(ctx, [[decX, 690], [756, 690], [756, 538], [decRight, 538]], residual, 1.7) // 21

                // Decoder query into cross-attention (K/V are arrows 12 and 13).
                arrow(ctx, decX, 520, decX, 472, grey, 1.7)                         // 22
                arrow(ctx, decX, 410, decX, 388, grey, 1.7)                         // 23
                polyArrow(ctx, [[decX, 516], [756, 516], [756, 358], [decRight, 358]], residual, 1.7) // 24

                // Decoder feed-forward and final residual.
                arrow(ctx, decX, 340, decX, 322, grey, 1.7)                         // 25
                arrow(ctx, decX, 260, decX, 238, grey, 1.7)                         // 26
                polyArrow(ctx, [[decX, 330], [756, 330], [756, 208], [decRight, 208]], residual, 1.7) // 27

                // Projection to output probabilities.
                arrow(ctx, decX, 190, decX, 168, grey, 1.7)                         // 28
                arrow(ctx, decX, 120, decX, 103, grey, 1.7)                         // 29
                arrow(ctx, decX, 55, decX, 28, grey, 1.7)                           // 30

                bracket(ctx, 30, 290, 665, true, "#d0a93b")
                bracket(ctx, 790, 170, 675, false, root.residualColor)
            }
        }

        Text {
            x: 6; y: 465
            text: root.bridge && root.bridge.numCapas > 0 ? root.bridge.numCapas + "×" : "N×"
            color: "#8b7b49"; font.pixelSize: 15
        }
        Text {
            x: 795; y: 420
            text: root.bridge && root.bridge.numCapas > 0 ? root.bridge.numCapas + "×" : "N×"
            color: root.residualColor; font.pixelSize: 15
        }
        Text { x: 368; y: 216; text: "encoder K, V"; color: root.attentionColor; font.pixelSize: 9 }

        Repeater {
            model: [
                { id: "encoder_add_norm_ffn", x: 82, y: 310, h: 36, title: "Add & Norm", sub: "click → ε, γ, β", color: "#7664dd" },
                { id: "encoder_feed_forward", x: 82, y: 400, h: 50, title: "Feed Forward", sub: "click → dimension, activation", color: "#258f6f" },
                { id: "encoder_add_norm_attention", x: 82, y: 490, h: 36, title: "Add & Norm", sub: "", color: "#7664dd" },
                { id: "encoder_self_attention", x: 82, y: 580, h: 60, title: "Multi-Head Attention", sub: "click → heads, dropout", color: "#9a641b" },
                { id: "input_embedding", x: 82, y: 775, h: 52, title: "Input Embedding", sub: "click → vocabulary, max length", color: "#b64b59" },

                { id: "softmax", x: 478, y: 55, h: 36, title: "Softmax", sub: "", color: "#258f6f" },
                { id: "linear", x: 478, y: 120, h: 36, title: "Linear", sub: "", color: "#3979b7" },
                { id: "decoder_add_norm_ffn", x: 478, y: 190, h: 36, title: "Add & Norm", sub: "", color: "#7664dd" },
                { id: "decoder_feed_forward", x: 478, y: 260, h: 50, title: "Feed Forward", sub: "click → dimension, activation", color: "#258f6f" },
                { id: "decoder_add_norm_cross", x: 478, y: 340, h: 36, title: "Add & Norm", sub: "", color: "#7664dd" },
                { id: "decoder_cross_attention", x: 478, y: 410, h: 50, title: "Multi-Head Attention (cross)", sub: "click → heads, dropout", color: "#9a641b" },
                { id: "decoder_add_norm_masked", x: 478, y: 520, h: 36, title: "Add & Norm", sub: "", color: "#7664dd" },
                { id: "decoder_masked_attention", x: 478, y: 590, h: 60, title: "Masked Multi-Head Attention", sub: "click → causal mask, heads", color: "#a53f62" },
                { id: "output_embedding", x: 478, y: 775, h: 52, title: "Output Embedding", sub: "click → vocabulary, max length", color: "#b64b59" }
            ]

            delegate: PrismBlock {
                id: prismDelegate
                required property var modelData
                x: modelData.x
                y: modelData.y
                blockWidth: 240
                blockHeight: modelData.h
                componentId: modelData.id
                title: modelData.title
                subtitle: modelData.sub
                accentColor: modelData.color
                selected: root.bridge !== null && root.bridge !== undefined
                          && root.bridge.selectedId === prismDelegate.componentId
                onClicked: function(componentId) {
                    if (root.bridge)
                        root.bridge.selectComponent(componentId)
                }
            }
        }

        // The plus nodes sit on the main stream; the PE nodes feed them from the side.
        AddNode {
            x: 182; y: 700
            componentId: "encoder_positional_encoding"
            selected: root.bridge !== null && root.bridge !== undefined
                      && root.bridge.selectedId === componentId
            onClicked: function(componentId) {
                if (root.bridge)
                    root.bridge.selectComponent(componentId)
            }
        }
        PositionNode {
            x: 105; y: 696
            componentId: "encoder_positional_encoding"
            selected: root.bridge !== null && root.bridge !== undefined
                      && root.bridge.selectedId === componentId
            onClicked: function(componentId) {
                if (root.bridge)
                    root.bridge.selectComponent(componentId)
            }
        }
        Text { x: 67; y: 748; text: "Positional Encoding"; color: "#77758b"; font.pixelSize: 10 }

        AddNode {
            x: 578; y: 700
            componentId: "decoder_positional_encoding"
            selected: root.bridge !== null && root.bridge !== undefined
                      && root.bridge.selectedId === componentId
            onClicked: function(componentId) {
                if (root.bridge)
                    root.bridge.selectComponent(componentId)
            }
        }
        PositionNode {
            x: 667; y: 696
            componentId: "decoder_positional_encoding"
            selected: root.bridge !== null && root.bridge !== undefined
                      && root.bridge.selectedId === componentId
            onClicked: function(componentId) {
                if (root.bridge)
                    root.bridge.selectComponent(componentId)
            }
        }
        Text { x: 654; y: 748; text: "Positional Encoding"; color: "#77758b"; font.pixelSize: 10 }

        Text { x: 178; y: 860; text: "Inputs"; color: "#77758b"; font.pixelSize: 12 }
        Text { x: 536; y: 860; text: "Outputs (shifted right)"; color: "#77758b"; font.pixelSize: 12 }
        Text { x: 542; y: 0; text: "Output probabilities ↑"; color: "#77758b"; font.pixelSize: 12 }
    }
}
