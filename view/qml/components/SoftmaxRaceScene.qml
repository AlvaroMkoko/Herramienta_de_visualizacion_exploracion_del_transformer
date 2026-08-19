pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var snapshots: []
    property int initialStep: -1
    property bool active: false
    property bool reducedMotion: false
    property real sx: 1
    property real sy: 1
    property int stepIndex: initialStep >= 0 ? initialStep : Math.max(0, snapshots.length - 1)
    property bool playing: false

    readonly property var snapshot: stepIndex >= 0 && stepIndex < snapshots.length
                                        ? snapshots[stepIndex] : null
    readonly property real topSum: probabilitySum()
    readonly property real maxProbability: currentMaximum()

    signal stepSelected(int index)

    function probabilitySum() {
        if (!snapshot || !snapshot.predicciones_top)
            return 0
        var result = 0
        for (var i = 0; i < snapshot.predicciones_top.length; ++i)
            result += Number(snapshot.predicciones_top[i].probabilidad || 0)
        return Math.min(1, result)
    }

    function currentMaximum() {
        if (!snapshot || !snapshot.predicciones_top || !snapshot.predicciones_top.length)
            return 1
        var result = 0
        for (var i = 0; i < snapshot.predicciones_top.length; ++i)
            result = Math.max(result, Number(snapshot.predicciones_top[i].probabilidad || 0))
        return Math.max(result, 1e-9)
    }

    function candidateSpecs() {
        var byId = ({})
        for (var step = 0; step < snapshots.length; ++step) {
            var predictions = snapshots[step].predicciones_top || []
            for (var i = 0; i < predictions.length; ++i) {
                var prediction = predictions[i]
                var key = String(prediction.token_id)
                if (!byId[key])
                    byId[key] = {
                        tokenId: Number(prediction.token_id),
                        text: String(prediction.texto),
                        peak: Number(prediction.probabilidad || 0)
                    }
                else
                    byId[key].peak = Math.max(byId[key].peak,
                                              Number(prediction.probabilidad || 0))
            }
        }
        var result = []
        for (var key in byId)
            result.push(byId[key])
        result.sort(function(a, b) { return b.peak - a.peak })
        return result.slice(0, 10)
    }

    function predictionFor(tokenId) {
        if (!snapshot || !snapshot.predicciones_top)
            return null
        for (var i = 0; i < snapshot.predicciones_top.length; ++i) {
            if (Number(snapshot.predicciones_top[i].token_id) === Number(tokenId))
                return snapshot.predicciones_top[i]
        }
        return null
    }

    function rebuildRaceModel() {
        raceModel.clear()
        var candidates = candidateSpecs()
        for (var i = 0; i < candidates.length; ++i) {
            raceModel.append({
                tokenId: candidates[i].tokenId,
                tokenText: candidates[i].text,
                probability: 0,
                rank: 9999,
                chosen: false,
                captured: false
            })
        }
        refreshRaceModel()
    }

    function refreshRaceModel() {
        if (!snapshot)
            return
        for (var i = 0; i < raceModel.count; ++i) {
            var row = raceModel.get(i)
            var prediction = predictionFor(row.tokenId)
            raceModel.setProperty(i, "probability",
                                  prediction ? Number(prediction.probabilidad || 0) : 0)
            raceModel.setProperty(i, "rank", prediction ? Number(prediction.rango || 9999) : 9999)
            raceModel.setProperty(i, "chosen", Boolean(prediction && prediction.elegido))
            raceModel.setProperty(i, "captured", Boolean(prediction))
        }
        var desired = []
        for (var j = 0; j < raceModel.count; ++j)
            desired.push(Number(raceModel.get(j).tokenId))
        desired.sort(function(a, b) {
            var pa = predictionFor(a)
            var pb = predictionFor(b)
            return Number(pb ? pb.probabilidad : 0) - Number(pa ? pa.probabilidad : 0)
        })
        for (var target = 0; target < desired.length; ++target) {
            var source = target
            while (source < raceModel.count
                   && Number(raceModel.get(source).tokenId) !== desired[target])
                ++source
            if (source < raceModel.count && source !== target)
                raceModel.move(source, target, 1)
        }
    }

    function setStep(index, notify) {
        var bounded = Math.max(0, Math.min(snapshots.length - 1, index))
        stepIndex = bounded
        refreshRaceModel()
        if (notify)
            stepSelected(bounded)
    }

    function contextText() {
        if (!snapshot)
            return "—"
        var output = snapshot.tokens_salida || []
        if (output.length <= 1)
            return "<inicio>"
        var words = []
        for (var i = 0; i < output.length - 1; ++i)
            words.push(output[i].texto)
        return "<inicio> " + words.join(" ")
    }

    onSnapshotsChanged: {
        stepIndex = Math.max(0, Math.min(snapshots.length - 1,
                                        initialStep >= 0 ? initialStep : snapshots.length - 1))
        rebuildRaceModel()
    }
    onInitialStepChanged: {
        if (initialStep >= 0 && initialStep < snapshots.length)
            setStep(initialStep, false)
    }
    onActiveChanged: {
        if (!active)
            playing = false
        else
            refreshRaceModel()
    }
    Component.onCompleted: rebuildRaceModel()

    Timer {
        interval: root.reducedMotion ? 900 : 1450
        running: root.active && root.playing && root.snapshots.length > 1
        repeat: true
        onTriggered: {
            if (root.stepIndex >= root.snapshots.length - 1) {
                root.playing = false
            } else {
                root.setStep(root.stepIndex + 1, true)
            }
        }
    }

    ListModel { id: raceModel }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10 * root.sy

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 58 * root.sy
            spacing: 8 * root.sx

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2 * root.sy
                Text {
                    text: "Probabilidad del siguiente token"
                    color: "#0F172A"
                    font.bold: true
                    font.pixelSize: 17 * Math.min(root.sx, root.sy)
                }
                Text {
                    Layout.fillWidth: true
                    text: "Contexto hasta aquí:  " + root.contextText()
                    color: "#64748B"
                    elide: Text.ElideLeft
                    font.pixelSize: 10 * root.sx
                }
            }

            RaceButton {
                label: "◀"
                enabled: root.stepIndex > 0
                sx: root.sx; sy: root.sy
                onClicked: root.setStep(root.stepIndex - 1, true)
            }
            RaceButton {
                label: root.playing ? "Pausa" : "▶ Carrera"
                primary: true
                enabled: root.snapshots.length > 1
                sx: root.sx; sy: root.sy
                onClicked: {
                    if (!root.playing && root.stepIndex >= root.snapshots.length - 1)
                        root.setStep(0, true)
                    root.playing = !root.playing
                }
            }
            RaceButton {
                label: "▶"
                enabled: root.stepIndex < root.snapshots.length - 1
                sx: root.sx; sy: root.sy
                onClicked: root.setStep(root.stepIndex + 1, true)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44 * root.sy
            radius: 10 * root.sx
            color: "#FEF2F2"
            border.color: "#FCA5A5"
            RowLayout {
                anchors.fill: parent
                anchors.margins: 8 * root.sx
                Text {
                    text: "CONTEXTO " + (root.stepIndex + 1) + " / " + root.snapshots.length
                    color: "#B91C1C"
                    font.bold: true
                    font.pixelSize: 10 * root.sx
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 6 * root.sy; radius: height / 2; color: "#FEE2E2"
                    Rectangle {
                        width: parent.width * (root.snapshots.length ? (root.stepIndex + 1) / root.snapshots.length : 0)
                        height: parent.height
                        radius: parent.radius
                        color: "#DC2626"
                        Behavior on width { NumberAnimation { duration: root.reducedMotion ? 0 : 360; easing.type: Easing.InOutCubic } }
                    }
                }
                Text {
                    text: root.snapshot ? root.snapshot.modo_muestreo + " · " + root.snapshot.filtros : "—"
                    color: "#7F1D1D"
                    font.pixelSize: 9 * root.sx
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12 * root.sx

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12 * root.sx
                color: "#F8FAFC"
                border.color: "#D8E0EA"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12 * root.sx
                    spacing: 7 * root.sy

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "RANGO"; Layout.preferredWidth: 54 * root.sx; color: "#64748B"; font.bold: true; font.pixelSize: 8 * root.sx }
                        Text { text: "CANDIDATO"; Layout.preferredWidth: 125 * root.sx; color: "#64748B"; font.bold: true; font.pixelSize: 8 * root.sx }
                        Text { text: "PROBABILIDAD REAL"; Layout.fillWidth: true; color: "#64748B"; font.bold: true; font.pixelSize: 8 * root.sx }
                        Text { text: "%"; Layout.preferredWidth: 58 * root.sx; color: "#64748B"; font.bold: true; horizontalAlignment: Text.AlignRight; font.pixelSize: 8 * root.sx }
                    }

                    ListView {
                        id: raceList
                        objectName: "softmaxRaceList"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 5 * root.sy
                        model: raceModel
                        displaced: Transition {
                            NumberAnimation {
                                properties: "y"
                                duration: root.reducedMotion ? 0 : 520
                                easing.type: Easing.InOutCubic
                            }
                        }
                        delegate: Rectangle {
                            id: horseRow
                            required property int index
                            required property int tokenId
                            required property string tokenText
                            required property real probability
                            required property int rank
                            required property bool chosen
                            required property bool captured
                            width: ListView.view.width
                            height: 42 * root.sy
                            radius: 8 * root.sx
                            color: horseRow.chosen ? "#DCFCE7" : "#FFFFFF"
                            border.color: horseRow.chosen ? "#22C55E" : "#E2E8F0"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6 * root.sx
                                spacing: 7 * root.sx
                                Rectangle {
                                    Layout.preferredWidth: 42 * root.sx
                                    Layout.preferredHeight: 27 * root.sy
                                    radius: 7 * root.sx
                                    color: horseRow.captured ? "#DC2626" : "#CBD5E1"
                                    Text {
                                        anchors.centerIn: parent
                                        text: horseRow.captured ? "#" + horseRow.rank : "—"
                                        color: "white"
                                        font.bold: true
                                        font.pixelSize: 9 * root.sx
                                    }
                                }
                                Text {
                                    Layout.preferredWidth: 125 * root.sx
                                    text: "“" + horseRow.tokenText + "”"
                                    color: "#0F172A"
                                    font.bold: true
                                    elide: Text.ElideRight
                                    font.pixelSize: 10 * root.sx
                                }
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 18 * root.sy
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: height / 2
                                        color: "#E2E8F0"
                                    }
                                    Rectangle {
                                        width: parent.width * Math.min(1, horseRow.probability / root.maxProbability)
                                        height: parent.height
                                        radius: height / 2
                                        color: horseRow.chosen ? "#16A34A" : "#DC2626"
                                        Behavior on width {
                                            NumberAnimation {
                                                duration: root.reducedMotion ? 0 : 620
                                                easing.type: Easing.InOutCubic
                                            }
                                        }
                                    }
                                }
                                Text {
                                    Layout.preferredWidth: 58 * root.sx
                                    text: (horseRow.probability * 100).toFixed(horseRow.probability < 0.01 ? 2 : 1) + "%"
                                    color: horseRow.captured ? "#0F172A" : "#94A3B8"
                                    font.bold: true
                                    horizontalAlignment: Text.AlignRight
                                    font.pixelSize: 10 * root.sx
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.preferredWidth: 250 * root.sx
                Layout.fillHeight: true
                spacing: 9 * root.sy

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 142 * root.sy
                    radius: 12 * root.sx
                    color: "#ECFDF5"
                    border.color: "#6EE7B7"
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 24 * root.sx
                        spacing: 5 * root.sy
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "TOKEN ELEGIDO"; color: "#047857"; font.bold: true; font.pixelSize: 9 * root.sx }
                        Text {
                            width: parent.width
                            text: root.snapshot ? "“" + root.snapshot.token_elegido.texto + "”" : "—"
                            color: "#065F46"
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            font.pixelSize: 23 * Math.min(root.sx, root.sy)
                        }
                        Text {
                            width: parent.width
                            text: root.snapshot
                                  ? "rango #" + root.snapshot.token_elegido.rango + " · "
                                    + (Number(root.snapshot.token_elegido.probabilidad || 0) * 100).toFixed(2) + "%"
                                  : ""
                            color: "#047857"
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 10 * root.sx
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 104 * root.sy
                    radius: 12 * root.sx
                    color: "#FFF7ED"
                    border.color: "#FDBA74"
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 22 * root.sx
                        spacing: 4 * root.sy
                        Text { text: "MASA FUERA DEL TOP"; color: "#C2410C"; font.bold: true; font.pixelSize: 9 * root.sx }
                        Text { text: ((1 - root.topSum) * 100).toFixed(2) + "%"; color: "#9A3412"; font.bold: true; font.pixelSize: 24 * root.sx }
                        Text { width: parent.width; text: "Completa la distribución hasta Σp = 1."; color: "#9A3412"; wrapMode: Text.WordWrap; font.pixelSize: 9 * root.sx }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12 * root.sx
                    color: "#F8FAFC"
                    border.color: "#CBD5E1"
                    Text {
                        anchors.fill: parent
                        anchors.margins: 12 * root.sx
                        text: "Las barras usan probabilidades del softmax real. Un candidato que desaparece queda en 0 porque ya no pertenece al top capturado; no significa probabilidad matemática exactamente cero."
                        color: "#475569"
                        wrapMode: Text.WordWrap
                        lineHeight: 1.2
                        font.pixelSize: 9 * root.sx
                    }
                }
            }
        }
    }

    component RaceButton: Rectangle {
        id: raceButton
        property string label: ""
        property bool primary: false
        property real sx: 1
        property real sy: 1
        signal clicked()
        implicitWidth: primary ? 98 * sx : 38 * sx
        implicitHeight: 32 * sy
        radius: 8 * sx
        color: !enabled ? "#F1F5F9" : (primary ? "#DC2626" : "#FFFFFF")
        border.color: !enabled ? "#CBD5E1" : "#DC2626"
        opacity: enabled ? 1 : 0.55
        Text {
            anchors.centerIn: parent
            text: raceButton.label
            color: raceButton.primary && raceButton.enabled ? "white" : (raceButton.enabled ? "#B91C1C" : "#94A3B8")
            font.bold: true
            font.pixelSize: 9 * raceButton.sx
        }
        MouseArea {
            anchors.fill: parent
            enabled: raceButton.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: raceButton.clicked()
        }
    }
}
