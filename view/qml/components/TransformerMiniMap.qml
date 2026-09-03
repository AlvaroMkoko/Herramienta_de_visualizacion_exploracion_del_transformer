pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property int stageIndex: 0
    property int branchIndex: 0
    property bool residualUsesFfn: false
    property color accent: "#4F46E5"
    property bool reducedMotion: false
    property real sx: 1
    property real sy: 1

    // Esta propiedad documenta la intención del componente y permite
    // comprobarla desde las pruebas. El minimapa no contiene MouseArea.
    readonly property bool interactive: false
    readonly property var activeBlockIds: componentsForCurrentStage()
    readonly property string activeRegion: locationForCurrentStage()

    readonly property var encoderBlocks: [
        { ids: ["encoder_add_norm_ffn"], title: "Add & Norm · FFN", color: "#7664DD" },
        { ids: ["encoder_feed_forward"], title: "Feed Forward", color: "#258F6F" },
        { ids: ["encoder_add_norm_attention"], title: "Add & Norm · atención", color: "#7664DD" },
        { ids: ["encoder_self_attention"], title: "Self-attention", color: "#9A641B" },
        { ids: ["input_embedding", "encoder_positional_encoding"], title: "Embedding + posición", color: "#B64B59" }
    ]
    readonly property var decoderBlocks: [
        { ids: ["softmax"], title: "Softmax", color: "#258F6F" },
        { ids: ["linear"], title: "Linear", color: "#3979B7" },
        { ids: ["decoder_add_norm_ffn"], title: "Add & Norm · FFN", color: "#7664DD" },
        { ids: ["decoder_feed_forward"], title: "Feed Forward", color: "#258F6F" },
        { ids: ["decoder_add_norm_cross"], title: "Add & Norm · cruzada", color: "#7664DD" },
        { ids: ["decoder_cross_attention"], title: "Atención cruzada", color: "#9A641B" },
        { ids: ["decoder_add_norm_masked"], title: "Add & Norm · causal", color: "#7664DD" },
        { ids: ["decoder_masked_attention"], title: "Atención causal", color: "#A53F62" },
        { ids: ["output_embedding", "decoder_positional_encoding"], title: "Embedding + posición", color: "#B64B59" }
    ]

    implicitHeight: 272 * sy

    function attentionBlockId() {
        if (branchIndex === 0)
            return "encoder_self_attention"
        if (branchIndex === 1)
            return "decoder_masked_attention"
        return "decoder_cross_attention"
    }

    function componentsForCurrentStage() {
        if (stageIndex === 0) {
            return branchIndex === 0
                    ? ["input_embedding", "encoder_positional_encoding"]
                    : ["output_embedding", "decoder_positional_encoding"]
        }
        if (stageIndex === 1 || stageIndex === 2)
            return [attentionBlockId()]
        if (stageIndex === 3)
            return [branchIndex === 0 ? "encoder_feed_forward" : "decoder_feed_forward"]
        if (stageIndex === 4) {
            if (residualUsesFfn) {
                return [branchIndex === 0
                        ? "encoder_add_norm_ffn" : "decoder_add_norm_ffn"]
            }
            if (branchIndex === 0)
                return ["encoder_add_norm_attention"]
            if (branchIndex === 1)
                return ["decoder_add_norm_masked"]
            return ["decoder_add_norm_cross"]
        }
        if (stageIndex === 5) {
            return branchIndex === 0
                    ? ["encoder_self_attention", "encoder_add_norm_attention",
                       "encoder_feed_forward", "encoder_add_norm_ffn"]
                    : ["decoder_masked_attention", "decoder_add_norm_masked",
                       "decoder_cross_attention", "decoder_add_norm_cross",
                       "decoder_feed_forward", "decoder_add_norm_ffn"]
        }
        return ["linear", "softmax"]
    }

    function attentionLocation() {
        if (branchIndex === 0)
            return "Encoder · Self-attention"
        if (branchIndex === 1)
            return "Decoder · Atención causal"
        return "Decoder · Atención cruzada"
    }

    function locationForCurrentStage() {
        if (stageIndex === 0)
            return branchIndex === 0
                    ? "Encoder · Embedding + posición"
                    : "Decoder · Embedding + posición"
        if (stageIndex === 1)
            return attentionLocation()
        if (stageIndex === 2)
            return attentionLocation() + " · Multi-head"
        if (stageIndex === 3)
            return branchIndex === 0 ? "Encoder · Feed Forward" : "Decoder · Feed Forward"
        if (stageIndex === 4) {
            if (residualUsesFfn)
                return (branchIndex === 0 ? "Encoder" : "Decoder") + " · Add & Norm de FFN"
            if (branchIndex === 0)
                return "Encoder · Add & Norm de atención"
            if (branchIndex === 1)
                return "Decoder · Add & Norm causal"
            return "Decoder · Add & Norm de atención cruzada"
        }
        if (stageIndex === 5)
            return branchIndex === 0 ? "Pila completa del encoder" : "Pila completa del decoder"
        return "Salida · Linear + Softmax"
    }

    function containsAny(ids) {
        for (let i = 0; i < ids.length; ++i) {
            if (activeBlockIds.indexOf(ids[i]) !== -1)
                return true
        }
        return false
    }

    Rectangle {
        anchors.fill: parent
        radius: 11 * Math.min(root.sx, root.sy)
        color: "#F8FAFC"
        border.color: Qt.alpha(root.accent, 0.48)
        border.width: 1

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10 * root.sx
            anchors.top: parent.top
            anchors.topMargin: 8 * root.sy
            text: "MAPA DEL TRANSFORMER"
            color: "#475569"
            font.bold: true
            font.letterSpacing: 0.6
            font.pixelSize: 8.5 * Math.min(root.sx, root.sy)
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 8 * root.sx
            anchors.top: parent.top
            anchors.topMargin: 6 * root.sy
            width: passiveLabel.implicitWidth + 12 * root.sx
            height: 20 * root.sy
            radius: height / 2
            color: "#E2E8F0"

            Text {
                id: passiveLabel
                anchors.centerIn: parent
                text: "SOLO REFERENCIA"
                color: "#64748B"
                font.bold: true
                font.pixelSize: 7 * Math.min(root.sx, root.sy)
            }
        }

        Item {
            id: towers
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 31 * root.sy
            anchors.bottom: locationBadge.top
            anchors.bottomMargin: 7 * root.sy

            Text {
                anchors.left: encoderColumn.left
                anchors.right: encoderColumn.right
                anchors.top: parent.top
                text: "ENCODER  ↑"
                color: "#334155"
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 8 * Math.min(root.sx, root.sy)
            }
            Text {
                anchors.left: decoderColumn.left
                anchors.right: decoderColumn.right
                anchors.top: parent.top
                text: "DECODER  ↑"
                color: "#334155"
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 8 * Math.min(root.sx, root.sy)
            }

            Column {
                id: encoderColumn
                anchors.left: parent.left
                anchors.leftMargin: 9 * root.sx
                anchors.bottom: parent.bottom
                width: (parent.width - 30 * root.sx) / 2
                spacing: 2 * root.sy

                Repeater {
                    model: root.encoderBlocks
                    delegate: MiniBlock {
                        required property var modelData
                        width: encoderColumn.width
                        height: 18 * root.sy
                        title: modelData.title
                        baseColor: modelData.color
                        active: root.containsAny(modelData.ids)
                        accent: root.accent
                        reducedMotion: root.reducedMotion
                        textScale: Math.min(root.sx, root.sy)
                    }
                }
            }

            Column {
                id: decoderColumn
                anchors.right: parent.right
                anchors.rightMargin: 9 * root.sx
                anchors.bottom: parent.bottom
                width: (parent.width - 30 * root.sx) / 2
                spacing: 2 * root.sy

                Repeater {
                    model: root.decoderBlocks
                    delegate: MiniBlock {
                        required property var modelData
                        width: decoderColumn.width
                        height: 18 * root.sy
                        title: modelData.title
                        baseColor: modelData.color
                        active: root.containsAny(modelData.ids)
                        accent: root.accent
                        reducedMotion: root.reducedMotion
                        textScale: Math.min(root.sx, root.sy)
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 17 * root.sy
                text: "K,V →"
                color: (root.stageIndex === 1 || root.stageIndex === 2)
                       && root.branchIndex === 2 ? root.accent : "#94A3B8"
                font.bold: (root.stageIndex === 1 || root.stageIndex === 2)
                           && root.branchIndex === 2
                font.pixelSize: 7.5 * Math.min(root.sx, root.sy)
            }
        }

        Rectangle {
            id: locationBadge
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 8 * root.sx
            height: 30 * root.sy
            radius: 7 * Math.min(root.sx, root.sy)
            color: Qt.alpha(root.accent, 0.12)
            border.color: Qt.alpha(root.accent, 0.50)

            Text {
                anchors.fill: parent
                anchors.leftMargin: 8 * root.sx
                anchors.rightMargin: 8 * root.sx
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: "●  Estás aquí · " + root.activeRegion
                color: Qt.darker(root.accent, 1.35)
                font.bold: true
                font.pixelSize: 8 * Math.min(root.sx, root.sy)
                elide: Text.ElideRight
            }
        }
    }

    component MiniBlock: Item {
        id: block

        property string title: ""
        property color baseColor: "#64748B"
        property bool active: false
        property color accent: "#4F46E5"
        property bool reducedMotion: false
        property real textScale: 1

        readonly property color displayColor: active ? accent : baseColor

        opacity: active ? 1 : 0.50

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 3
            anchors.topMargin: 3
            radius: 3
            color: Qt.alpha(block.displayColor, block.active ? 0.38 : 0.16)
            border.color: block.displayColor
            border.width: block.active ? 1.5 : 0.8
        }
        Rectangle {
            anchors.fill: parent
            anchors.rightMargin: 3
            anchors.bottomMargin: 3
            radius: 3
            color: block.active ? Qt.alpha(block.displayColor, 0.27) : "#FFFFFF"
            border.color: block.displayColor
            border.width: block.active ? 1.7 : 0.8

            Text {
                anchors.fill: parent
                anchors.leftMargin: 3
                anchors.rightMargin: 3
                text: block.title
                color: block.active ? Qt.darker(block.displayColor, 1.45) : "#475569"
                font.bold: block.active
                font.pixelSize: 7 * block.textScale
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            visible: block.active
            radius: 5
            color: "transparent"
            border.color: Qt.alpha(block.accent, 0.70)
            border.width: 1
        }

        Behavior on opacity {
            NumberAnimation {
                duration: block.reducedMotion ? 0 : 160
                easing.type: Easing.OutCubic
            }
        }
    }
}
