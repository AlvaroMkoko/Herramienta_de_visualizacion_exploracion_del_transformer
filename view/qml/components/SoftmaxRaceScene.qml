pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../styles" as Style

Item {
    id: root
    objectName: "softmaxRaceScene"

    property var snapshots: []
    property int initialStep: -1
    property bool active: false
    property bool reducedMotion: false
    property real sx: 1
    property real sy: 1
    property int stepIndex: initialStep >= 0 ? initialStep : Math.max(0, snapshots.length - 1)
    property bool playing: false
    property real revealProgress: 0
    property int candidateRevision: 0

    readonly property var snapshot: stepIndex >= 0 && stepIndex < snapshots.length
                                        ? snapshots[stepIndex] : null
    readonly property real topSum: probabilitySum()
    readonly property real maxProbability: currentMaximum()
    readonly property int candidateCount: raceModel.count
    readonly property real probabilityReveal: phaseReveal(0.08, 0.50)
    readonly property real selectionReveal: phaseReveal(0.58, 0.22)
    readonly property real returnReveal: phaseReveal(0.82, 0.18)
    readonly property bool chosenCandidateVisible: candidateRevision >= 0
                                                   && snapshot && snapshot.token_elegido
                                                   ? raceContains(snapshot.token_elegido.token_id)
                                                   : false

    signal stepSelected(int index)

    function phaseReveal(start, span) {
        if (reducedMotion)
            return 1
        return Math.max(0, Math.min(1, (revealProgress - start)
                                      / Math.max(0.001, span)))
    }

    function replaySelection() {
        revealAnimation.stop()
        revealProgress = 0
        if (reducedMotion)
            revealProgress = 1
        else
            revealAnimation.start()
    }

    function snapshotForCurrentStep() {
        return stepIndex >= 0 && stepIndex < snapshots.length
                ? snapshots[stepIndex] : null
    }

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
        var selected = result.slice(0, 10)
        var currentSnapshot = snapshotForCurrentStep()
        var chosenId = currentSnapshot && currentSnapshot.token_elegido
                ? Number(currentSnapshot.token_elegido.token_id) : -1
        var chosenIncluded = false
        var chosenSpec = null
        for (var resultIndex = 0; resultIndex < result.length; ++resultIndex) {
            if (Number(result[resultIndex].tokenId) === chosenId) {
                chosenSpec = result[resultIndex]
                break
            }
        }
        for (var selectedIndex = 0; selectedIndex < selected.length; ++selectedIndex)
            chosenIncluded = chosenIncluded
                    || Number(selected[selectedIndex].tokenId) === chosenId
        if (chosenSpec && !chosenIncluded) {
            if (selected.length >= 10)
                selected[selected.length - 1] = chosenSpec
            else
                selected.push(chosenSpec)
        }
        return selected
    }

    function raceContains(tokenId) {
        for (var i = 0; i < raceModel.count; ++i) {
            if (Number(raceModel.get(i).tokenId) === Number(tokenId))
                return true
        }
        return false
    }

    function predictionFor(tokenId) {
        var currentSnapshot = snapshotForCurrentStep()
        if (!currentSnapshot || !currentSnapshot.predicciones_top)
            return null
        for (var i = 0; i < currentSnapshot.predicciones_top.length; ++i) {
            if (Number(currentSnapshot.predicciones_top[i].token_id) === Number(tokenId))
                return currentSnapshot.predicciones_top[i]
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
        if (!snapshotForCurrentStep())
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
        candidateRevision += 1
    }

    function setStep(index, notify) {
        var bounded = Math.max(0, Math.min(snapshots.length - 1, index))
        stepIndex = bounded
        var currentSnapshot = snapshotForCurrentStep()
        var chosenId = currentSnapshot && currentSnapshot.token_elegido
                ? Number(currentSnapshot.token_elegido.token_id) : -1
        if (chosenId >= 0 && !raceContains(chosenId))
            rebuildRaceModel()
        else
            refreshRaceModel()
        if (active)
            replaySelection()
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

    function nextContextText() {
        if (!snapshot)
            return "—"
        var output = snapshot.tokens_salida || []
        if (!output.length)
            return "<inicio>"
        var words = []
        for (var i = 0; i < output.length; ++i)
            words.push(output[i].texto)
        return "<inicio> " + words.join(" ")
    }

    onSnapshotsChanged: {
        stepIndex = Math.max(0, Math.min(snapshots.length - 1,
                                        initialStep >= 0 ? initialStep : snapshots.length - 1))
        rebuildRaceModel()
        if (active)
            replaySelection()
    }
    onInitialStepChanged: {
        if (initialStep >= 0 && initialStep < snapshots.length)
            setStep(initialStep, false)
    }
    onActiveChanged: {
        if (!active)
            playing = false
        else
            replaySelection()
    }
    onReducedMotionChanged: if (active) replaySelection()
    Component.onCompleted: rebuildRaceModel()

    NumberAnimation {
        id: revealAnimation
        target: root
        property: "revealProgress"
        from: 0
        to: 1
        duration: 2300
        easing.type: Easing.InOutCubic
    }

    Timer {
        interval: root.reducedMotion ? 900 : 2700
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
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: Math.max(18, 18 * Math.min(root.sx, root.sy))
                }
                Text {
                    Layout.fillWidth: true
                    text: root.snapshots.length < 2
                          ? "Primera distribución: genera otro token para comparar cómo cambia."
                          : "Contexto usado para esta predicción:  " + root.contextText()
                    color: Style.Theme.texto_secundario
                    elide: Text.ElideLeft
                    font.pixelSize: Math.max(11, 11 * root.sx)
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
            color: Style.Theme.chip_fondo
            border.color: Style.Theme.inferencia_foco
            RowLayout {
                anchors.fill: parent
                anchors.margins: 8 * root.sx
                Text {
                    text: "CONTEXTO " + (root.stepIndex + 1) + " / " + root.snapshots.length
                    color: Style.Theme.inferencia_foco
                    font.bold: true
                    font.pixelSize: 10 * root.sx
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 6 * root.sy; radius: height / 2; color: Style.Theme.aviso_fondo
                    Rectangle {
                        width: parent.width * (root.snapshots.length ? (root.stepIndex + 1) / root.snapshots.length : 0)
                        height: parent.height
                        radius: parent.radius
                        color: Style.Theme.inferencia_foco
                        Behavior on width { NumberAnimation { duration: root.reducedMotion ? 0 : 360; easing.type: Easing.InOutCubic } }
                    }
                }
                Text {
                    text: root.snapshot ? root.snapshot.modo_muestreo + " · " + root.snapshot.filtros : "—"
                    color: Style.Theme.inferencia_foco
                    font.pixelSize: 9 * root.sx
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: parent.width
            Layout.fillHeight: true
            spacing: 12 * root.sx

            Rectangle {
                objectName: "softmaxCandidatesPanel"
                Layout.minimumWidth: 360 * root.sx
                Layout.preferredWidth: 600 * root.sx
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12 * root.sx
                color: Style.Theme.superficie_alterna
                border.color: Style.Theme.borde_medio

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12 * root.sx
                    spacing: 7 * root.sy

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "RANGO"; Layout.preferredWidth: 54 * root.sx; color: Style.Theme.texto_secundario; font.bold: true; font.pixelSize: Math.max(9, 9 * root.sx) }
                        Text { text: "CANDIDATO"; Layout.preferredWidth: 125 * root.sx; color: Style.Theme.texto_secundario; font.bold: true; font.pixelSize: Math.max(9, 9 * root.sx) }
                        Text { text: "BARRA RELATIVA AL MÁX."; Layout.fillWidth: true; color: Style.Theme.texto_secundario; font.bold: true; font.pixelSize: Math.max(9, 9 * root.sx) }
                        Text { text: "PROB. REAL / ESTADO"; Layout.preferredWidth: 106 * root.sx; color: Style.Theme.texto_secundario; font.bold: true; horizontalAlignment: Text.AlignRight; font.pixelSize: Math.max(9, 9 * root.sx) }
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
                            readonly property real chosenAmount: chosen ? root.selectionReveal : 0
                            width: ListView.view.width
                            height: 42 * root.sy
                            radius: 8 * root.sx
                            color: horseRow.chosenAmount > 0
                                   ? Qt.tint(Style.Theme.surface,
                                             Qt.alpha(Style.Theme.inferencia_resultado,
                                                      0.16 * horseRow.chosenAmount))
                                   : Style.Theme.surface
                            border.color: horseRow.chosenAmount > 0
                                          ? Style.Theme.inferencia_resultado
                                          : Style.Theme.borde_medio
                            border.width: 1 + horseRow.chosenAmount

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6 * root.sx
                                spacing: 7 * root.sx
                                Rectangle {
                                    Layout.preferredWidth: 42 * root.sx
                                    Layout.preferredHeight: 27 * root.sy
                                    radius: 7 * root.sx
                                    color: horseRow.captured
                                           ? Style.Theme.inferencia_estructura
                                           : Style.Theme.borde_suave
                                    Text {
                                        anchors.centerIn: parent
                                        text: horseRow.captured ? "#" + horseRow.rank : "—"
                                        color: horseRow.captured
                                               ? Style.Theme.inferencia_sobre_estructura
                                               : Style.Theme.texto_terciario
                                        font.bold: true
                                        font.pixelSize: 9 * root.sx
                                    }
                                }
                                Text {
                                    Layout.preferredWidth: 125 * root.sx
                                    text: "“" + horseRow.tokenText + "”"
                                    color: Style.Theme.texto_primario
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
                                        color: Style.Theme.borde_medio
                                    }
                                    Rectangle {
                                        width: parent.width
                                               * Math.min(1, horseRow.probability / root.maxProbability)
                                               * root.probabilityReveal
                                        height: parent.height
                                        radius: height / 2
                                        color: Qt.tint(
                                                   Style.Theme.inferencia_estructura,
                                                   Qt.alpha(Style.Theme.inferencia_resultado,
                                                            horseRow.chosenAmount))
                                    }
                                }
                                Text {
                                    Layout.preferredWidth: 106 * root.sx
                                    text: horseRow.captured
                                          ? (horseRow.chosenAmount > 0.55 ? "✓ " : "")
                                            + (horseRow.probability * 100).toFixed(
                                                  horseRow.probability < 0.01 ? 2 : 1) + "%"
                                          : "fuera del top"
                                    color: horseRow.chosenAmount > 0.55
                                           ? Style.Theme.exito_texto
                                           : (horseRow.captured
                                              ? Style.Theme.texto_primario
                                              : Style.Theme.texto_terciario)
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
                objectName: "softmaxSelectionColumn"
                Layout.minimumWidth: 220 * root.sx
                Layout.preferredWidth: 250 * root.sx
                Layout.maximumWidth: 280 * root.sx
                Layout.fillHeight: true
                spacing: 9 * root.sy

                Rectangle {
                    objectName: "softmaxChosenTokenCard"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120 * root.sy
                    radius: 12 * root.sx
                    color: Qt.tint(Style.Theme.superficie_alterna,
                                   Qt.alpha(Style.Theme.inferencia_resultado,
                                            0.14 * root.selectionReveal))
                    border.color: root.selectionReveal > 0
                                  ? Style.Theme.inferencia_resultado
                                  : Style.Theme.borde_medio
                    border.width: 1 + root.selectionReveal

                    Text {
                        anchors.centerIn: parent
                        text: "Comparando probabilidades…"
                        color: Style.Theme.inferencia_foco
                        font.bold: true
                        opacity: Math.max(0, 1 - root.selectionReveal * 2)
                        font.pixelSize: 10 * root.sx
                    }

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 24 * root.sx
                        spacing: 5 * root.sy
                        opacity: root.selectionReveal
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "TOKEN ELEGIDO"; color: Style.Theme.exito_texto; font.bold: true; font.pixelSize: 9 * root.sx }
                        Text {
                            width: parent.width
                            text: root.snapshot ? "“" + root.snapshot.token_elegido.texto + "”" : "—"
                            color: Style.Theme.exito_texto
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
                            color: Style.Theme.exito_texto
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 10 * root.sx
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 85 * root.sy
                    radius: 12 * root.sx
                    color: Style.Theme.aviso_fondo
                    border.color: Style.Theme.inferencia_foco
                    opacity: 0.45 + 0.55 * root.probabilityReveal
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 22 * root.sx
                        spacing: 4 * root.sy
                        Text { text: "MASA FUERA DEL TOP"; color: Style.Theme.inferencia_foco; font.bold: true; font.pixelSize: 9 * root.sx }
                        Text { text: ((1 - root.topSum) * 100).toFixed(2) + "%"; color: Style.Theme.aviso_texto; font.bold: true; font.pixelSize: 20 * root.sx }
                        Text { width: parent.width; text: "Completa la distribución hasta Σp = 1."; color: Style.Theme.aviso_texto; elide: Text.ElideRight; font.pixelSize: 9 * root.sx }
                    }
                }

                Rectangle {
                    objectName: "softmaxReturnToDecoder"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 66 * root.sy
                    radius: 12 * root.sx
                    color: Qt.tint(Style.Theme.superficie_alterna,
                                   Qt.alpha(Style.Theme.inferencia_contexto,
                                            0.12 * root.returnReveal))
                    border.color: root.returnReveal > 0
                                  ? Style.Theme.inferencia_contexto
                                  : Style.Theme.borde_suave
                    border.width: 1 + root.returnReveal
                    opacity: 0.35 + 0.65 * root.returnReveal

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 9 * root.sx
                        spacing: 5 * root.sy
                        Text {
                            text: "SIGUIENTE ITERACIÓN"
                            color: Style.Theme.inferencia_contexto
                            font.bold: true
                            font.pixelSize: 9 * root.sx
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5 * root.sx
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 27 * root.sy
                                radius: 7 * root.sx
                                color: Style.Theme.inferencia_resultado
                                Text {
                                    anchors.centerIn: parent
                                    width: parent.width - 8 * root.sx
                                    text: root.snapshot
                                          ? String(root.snapshot.token_elegido.texto) : "—"
                                    color: Style.Theme.inferencia_sobre_resultado
                                    font.bold: true
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: 9 * root.sx
                                }
                            }
                            Text {
                                text: "→"
                                color: Style.Theme.inferencia_contexto
                                font.bold: true
                                font.pixelSize: 17 * root.sx
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 27 * root.sy
                                radius: 7 * root.sx
                                color: Style.Theme.inferencia_contexto
                                Text {
                                    anchors.centerIn: parent
                                    text: "CONTEXTO DECODER"
                                    color: Style.Theme.inferencia_sobre_contexto
                                    font.bold: true
                                    font.pixelSize: Math.max(8, 7.5 * root.sx)
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Se añade: " + root.nextContextText()
                            color: Style.Theme.texto_secundario
                            elide: Text.ElideLeft
                            font.pixelSize: 9 * root.sx
                        }
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
        color: !enabled ? Style.Theme.superficie_alterna
                        : (primary ? Style.Theme.inferencia_foco : Style.Theme.surface)
        border.color: !enabled ? Style.Theme.borde_suave : Style.Theme.inferencia_foco
        opacity: enabled ? 1 : 0.55
        Text {
            anchors.centerIn: parent
            text: raceButton.label
            color: raceButton.primary && raceButton.enabled
                   ? Style.Theme.inferencia_sobre_foco
                   : (raceButton.enabled ? Style.Theme.inferencia_foco
                                         : Style.Theme.texto_terciario)
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
