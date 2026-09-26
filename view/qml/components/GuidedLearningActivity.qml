pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

Rectangle {
    id: root
    objectName: "guidedActivityCard"

    property var activity: ({})
    property int stage: 0
    property int selectedPrediction: -1
    property var optionOrder: []
    property bool unitCompleted: false
    property real scaleFactor: 1.0
    readonly property var stageLabels: ["1 · Pregunta", "2 · Observa"]

    signal predictionSelected(int optionIndex)
    signal observationRequested()

    function value(fieldName, fallbackValue) {
        if (!root.activity || root.activity[fieldName] === undefined
                || root.activity[fieldName] === null)
            return fallbackValue
        return root.activity[fieldName]
    }

    function options() {
        return root.value("options", [])
    }

    function optionAt(visibleIndex) {
        var opciones = root.options()
        var real = root.optionOrder.length > visibleIndex
                   ? root.optionOrder[visibleIndex] : visibleIndex
        return opciones[real]
    }

    function realIndex(visibleIndex) {
        return root.optionOrder.length > visibleIndex
               ? root.optionOrder[visibleIndex] : visibleIndex
    }

    function trace() {
        return root.value("trace", [])
    }

    function stageBackground(index) {
        return [Style.Theme.formula_fondo,
                Style.Theme.ejemplo_fondo,
                Style.Theme.concepto_fondo][Math.max(0, Math.min(2, index))]
    }

    function stageAccent(index) {
        return [Style.Theme.formula_texto,
                Style.Theme.ejemplo_texto,
                Style.Theme.concepto_texto][Math.max(0, Math.min(2, index))]
    }

    function traceBackground(index) {
        var total = root.trace().length
        if (index === total - 1)
            return Style.Theme.proceso_fondo
        return [Style.Theme.ejemplo_fondo,
                Style.Theme.concepto_fondo,
                Style.Theme.formula_fondo][index % 3]
    }

    function traceAccent(index) {
        var total = root.trace().length
        if (index === total - 1)
            return Style.Theme.proceso_texto
        return [Style.Theme.ejemplo_texto,
                Style.Theme.concepto_texto,
                Style.Theme.formula_texto][index % 3]
    }

        function predictionFeedback() {
        if (root.selectedPrediction < 0)
            return ""
        if (root.selectedPrediction === Number(root.value("correctIndex", -1)))
            return root.value("correctFeedback", "Tu predicción coincide con la observación.")
            
        var porOpcion = root.value("optionFeedback", null)
        if (porOpcion && porOpcion.length > root.selectedPrediction) {
            var especifico = porOpcion[root.selectedPrediction]
            if (especifico)
                return especifico
        }
        return root.value("revisionFeedback", "Contrasta tu predicción con la observación.")
    }

    radius: 14 * scaleFactor
    color: Style.Theme.surface
    border.width: 1
    border.color: stage === 1 && unitCompleted
                  ? Style.Theme.proceso_texto : Style.Theme.borde_medio
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16 * root.scaleFactor
        spacing: 10 * root.scaleFactor

        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * root.scaleFactor

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2 * root.scaleFactor

                Text {
                    Layout.fillWidth: true
                    text: "Comprueba lo aprendido"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 17 * root.scaleFactor
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }

                Text {
                    Layout.fillWidth: true
                    text: "Pregunta y observa"
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 11 * root.scaleFactor
                }
            }

            Rectangle {
                Layout.preferredWidth: 28 * root.scaleFactor
                Layout.preferredHeight: 28 * root.scaleFactor
                radius: width / 2
                color: root.unitCompleted ? Style.Theme.chip_fondo : Style.Theme.acento_fondo

                Text {
                    anchors.centerIn: parent
                    text: root.unitCompleted ? "✓" : "?"
                    color: root.unitCompleted ? Style.Theme.exito_texto : Style.Theme.acento_fuerte
                    font.bold: true
                    font.pixelSize: 13 * root.scaleFactor
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 5 * root.scaleFactor

            Repeater {
                model: root.stageLabels

                delegate: Rectangle {
                    id: stageDelegate
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: 25 * root.scaleFactor
                    radius: height / 2
                    color: root.stage > stageDelegate.index
                           ? Style.Theme.proceso_fondo
                           : root.stage === stageDelegate.index
                             ? root.stageBackground(stageDelegate.index) : Style.Theme.chip_fondo
                    border.color: root.stage === stageDelegate.index
                                  ? root.stageAccent(stageDelegate.index) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: stageDelegate.modelData
                        color: root.stage > stageDelegate.index
                               ? Style.Theme.proceso_texto
                               : root.stage === stageDelegate.index
                                 ? root.stageAccent(stageDelegate.index) : Style.Theme.texto_secundario
                        font.bold: root.stage === stageDelegate.index
                        font.pixelSize: 9 * root.scaleFactor
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Style.Theme.acento_fondo
        }

        ScrollView {
            id: activityScroll
            objectName: "guidedActivityScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            Column {
                width: activityScroll.availableWidth
                spacing: 10 * root.scaleFactor

                Column {
                    objectName: "guidedQuestionPanel"
                    visible: root.stage === 0
                    width: parent.width
                    spacing: 9 * root.scaleFactor

                    Text {
                        width: parent.width
                        text: "ANTES DE REVELAR"
                        color: "#8B651D"
                        font.bold: true
                        font.pixelSize: 10 * root.scaleFactor
                    }

                    Text {
                        objectName: "guidedQuestionText"
                        width: parent.width
                        text: String(root.value("question", ""))
                        color: Style.Theme.texto_primario
                        font.pixelSize: 13 * root.scaleFactor
                        font.bold: true
                        lineHeight: 1.15
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: root.options()

                                                delegate: Button {
                            id: optionDelegate
                            required property var modelData
                            required property int index

                            // El índice REAL de esta posición visible. Se calcula
                            // una vez y se reutiliza: `selectedPrediction` guarda
                            // índices reales, así que todas las comparaciones
                            // deben hacerse contra este valor, no contra `index`.
                            readonly property int realOptionIndex: root.realIndex(optionDelegate.index)
                            readonly property bool seleccionada: root.selectedPrediction === optionDelegate.realOptionIndex

                            objectName: "guidedPredictionOption" + optionDelegate.index
                            width: parent.width
                            height: Math.max(42 * root.scaleFactor,
                                             optionText.implicitHeight + 18 * root.scaleFactor)
                            activeFocusOnTab: true

                            // `modelData` viene del modelo SIN barajar: usar
                            // optionAt() para que texto y accesibilidad
                            // coincidan con lo que registra el clic.
                            text: root.optionAt(optionDelegate.index)

                            Accessible.name: "Opción " + (optionDelegate.index + 1) + ": " + optionDelegate.text
                            Accessible.description: "Selecciona esta predicción"

                            background: Rectangle {
                                radius: 8 * root.scaleFactor
                                color: optionDelegate.seleccionada
                                       ? Style.Theme.acento_fondo
                                       : optionDelegate.hovered
                                         ? Style.Theme.superficie_alterna
                                         : Style.Theme.surface
                                border.width: optionDelegate.seleccionada ? 2 : 1
                                border.color: optionDelegate.seleccionada
                                              ? Style.Theme.acento
                                              : Style.Theme.borde_suave
                            }

                            contentItem: Text {
                                id: optionText
                                text: optionDelegate.text
                                color: Style.Theme.texto_primario
                                font.pixelSize: 11 * root.scaleFactor
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 10 * root.scaleFactor
                                rightPadding: 8 * root.scaleFactor
                            }

                            onClicked: root.predictionSelected(optionDelegate.realOptionIndex)
                        }
                    }

                    Button {
                        id: revealButton
                        objectName: "guidedObserveButton"
                        width: parent.width
                        height: 40 * root.scaleFactor
                        enabled: root.selectedPrediction >= 0
                        text: "Observar resultado"
                        activeFocusOnTab: true
                        Accessible.name: text
                        Accessible.description: enabled
                                                ? "Revela la observación de esta actividad"
                                                : "Selecciona primero una predicción"

                        background: Rectangle {
                            radius: 8 * root.scaleFactor
                            color: !revealButton.enabled ? Style.Theme.chip_fondo
                                   : revealButton.down ? Style.Theme.acento_fuerte : Style.Theme.acento
                        }

                        contentItem: Text {
                            text: revealButton.text
                            color: revealButton.enabled ? "#FFFFFF" : Style.Theme.texto_terciario
                            font.bold: true
                            font.pixelSize: 11 * root.scaleFactor
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: root.observationRequested()
                    }
                }

                Column {
                    objectName: "guidedObservePanel"
                    visible: root.stage === 1
                    width: parent.width
                    spacing: 10 * root.scaleFactor

                    Rectangle {
                        id: observationPanel
                        objectName: "guidedObservationPanel"
                        width: parent.width
                        height: observationColumn.implicitHeight + 22 * root.scaleFactor
                        radius: 9 * root.scaleFactor
                        color: Style.Theme.ejemplo_fondo
                        border.color: Qt.alpha(Style.Theme.ejemplo_texto, 0.38)

                        Column {
                            id: observationColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 11 * root.scaleFactor
                            spacing: 7 * root.scaleFactor

                            Text {
                                width: parent.width
                                text: "OBSERVACIÓN SIN MODELO NI DATASET"
                                color: Style.Theme.ejemplo_texto
                                font.bold: true
                                font.pixelSize: 9 * root.scaleFactor
                            }

                            GuidedDemoVisualization {
                                width: parent.width
                                visualType: String(root.value("visualType", "pipeline"))
                                scaleFactor: root.scaleFactor
                            }

                            Repeater {
                                model: root.trace()

                                delegate: RowLayout {
                                    id: traceDelegate
                                    required property var modelData
                                    required property int index
                                    width: parent.width
                                    spacing: 7 * root.scaleFactor

                                    Rectangle {
                                        Layout.preferredWidth: 21 * root.scaleFactor
                                        Layout.preferredHeight: 21 * root.scaleFactor
                                        radius: 6 * root.scaleFactor
                                        color: root.traceBackground(traceDelegate.index)
                                        border.color: Qt.alpha(root.traceAccent(traceDelegate.index), 0.52)

                                        Text {
                                            anchors.centerIn: parent
                                            text: String(traceDelegate.index + 1)
                                            color: root.traceAccent(traceDelegate.index)
                                            font.bold: true
                                            font.pixelSize: 9 * root.scaleFactor
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: String(traceDelegate.modelData)
                                        color: Style.Theme.texto_primario
                                        font.pixelSize: 10 * root.scaleFactor
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                text: String(root.value("observation", ""))
                                color: Style.Theme.chip_texto
                                font.pixelSize: 11 * root.scaleFactor
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: root.selectedPrediction < 0
                              ? "Esta unidad ya está completada; vuelve a observar el mecanismo cuando quieras."
                              : root.predictionFeedback()
                        color: root.selectedPrediction === Number(root.value("correctIndex", -1))
                               ? Style.Theme.proceso_texto : Style.Theme.formula_texto
                        font.pixelSize: 11 * root.scaleFactor
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        id: pedagogicalExplanation
                        objectName: "guidedPedagogicalExplanation"
                        width: parent.width
                        height: explanationColumn.implicitHeight + 24 * root.scaleFactor
                        radius: 10 * root.scaleFactor
                        color: Style.Theme.proceso_fondo
                        border.color: Qt.alpha(Style.Theme.proceso_texto, 0.48)

                        Column {
                            id: explanationColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 12 * root.scaleFactor
                            spacing: 7 * root.scaleFactor

                            Text {
                                width: parent.width
                                text: "POR QUÉ FUNCIONA"
                                color: Style.Theme.proceso_texto
                                font.bold: true
                                font.pixelSize: 10 * root.scaleFactor
                            }

                            Text {
                                width: parent.width
                                text: String(root.value("modelExplanation", ""))
                                color: Style.Theme.texto_primario
                                font.pixelSize: 11 * root.scaleFactor
                                lineHeight: 1.18
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: completionText.implicitHeight + 18 * root.scaleFactor
                        radius: 8 * root.scaleFactor
                        color: Style.Theme.exito_fondo
                        border.color: Style.Theme.success
                        Text {
                            id: completionText
                            anchors.fill: parent
                            anchors.margins: 9 * root.scaleFactor
                            text: "✓ Observación completada · ya puedes continuar con la siguiente unidad."
                            color: Style.Theme.exito_texto
                            font.bold: true
                            font.pixelSize: 10 * root.scaleFactor
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
