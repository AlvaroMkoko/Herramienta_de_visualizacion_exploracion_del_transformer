pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Actividad breve de descubrimiento guiado para una sola operación.
// La pantalla conserva el estado para que esta misma secuencia pueda abrir la
// animación, ejecutar un contrafactual real y regresar sin perder la respuesta.
Item {
    id: root
    objectName: "laboratoryDiscoveryCycle"

    property var challenge: ({})
    property var step: ({})
    property int stage: 0
    property int selectedPrediction: -1
    property int correctPrediction: -1
    property var predictionOptions: []
    property int selectedExplanation: -1
    property int correctExplanation: -1
    property var explanationOptions: []
    property string experimentTitle: "Modifica una condición"
    property string experimentSubtitle: "El cambio se aplica al cálculo real de esta operación."
    property string experimentInstruction: ""
    property string experimentActionLabel: "Probar cambio sugerido"
    property string observationPrompt: ""
    property string explanationHint: ""
    property real sx: 1
    property real sy: 1

    signal predictionSelected(int optionIndex)
    signal predictionConfirmed()
    signal experimentRequested()
    signal observationConfirmed()
    signal explanationSelected(int optionIndex)
    signal explanationChecked()
    signal explanationRequested()

    // El estado interno conserva experimento y feedback, pero la persona ve un
    // flujo corto y estable: predecir, observar y contestar.
    readonly property var stageLabels: ["Predecir", "Observar", "Contestar"]
    readonly property int flowStage: root.stage === 0 ? 0
                                     : (root.stage <= 2 ? 1 : 2)
    readonly property bool predictionIsCorrect: selectedPrediction === correctPrediction
    readonly property bool explanationIsCorrect: selectedExplanation === correctExplanation

    function value(source, key, fallback) {
        if (!source || source[key] === undefined || source[key] === null)
            return fallback
        return source[key]
    }

    ScrollView {
        id: discoveryScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: discoveryScroll.availableWidth
            spacing: 12 * root.sy

            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * root.sx

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2 * root.sy
                    Text {
                        Layout.fillWidth: true
                        text: "DESCUBRIMIENTO GUIADO"
                        color: Style.Theme.acento_fuerte
                        font.bold: true
                        font.letterSpacing: 0.6
                        font.pixelSize: Math.max(10, 11 * root.sx)
                    }
                    Text {
                        Layout.fillWidth: true
                        text: String(root.value(root.step, "title", "Operación actual"))
                        color: Style.Theme.texto_primario
                        font.bold: true
                        font.pixelSize: Math.max(18, 21 * root.sx)
                        wrapMode: Text.WordWrap
                    }
                }

                Rectangle {
                    Layout.preferredWidth: stageCounter.implicitWidth + 20 * root.sx
                    Layout.preferredHeight: 28 * root.sy
                    radius: height / 2
                    color: Style.Theme.acento_fondo
                    border.color: Style.Theme.acento
                    Text {
                        id: stageCounter
                        anchors.centerIn: parent
                        text: (root.flowStage + 1) + " / 3"
                        color: Style.Theme.acento_fuerte
                        font.bold: true
                        font.pixelSize: Math.max(10, 11 * root.sx)
                    }
                }
            }

            RowLayout {
                objectName: "laboratoryDiscoveryStages"
                Layout.fillWidth: true
                spacing: 5 * root.sx

                Repeater {
                    model: root.stageLabels
                    delegate: Rectangle {
                        id: stageChip
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 29 * root.sy
                        radius: height / 2
                        color: stageChip.index === root.flowStage
                               ? Style.Theme.acento
                               : (stageChip.index < root.flowStage
                                  ? Style.Theme.acento_fondo : Style.Theme.chip_fondo)
                        border.color: stageChip.index <= root.flowStage
                                      ? Style.Theme.acento : Style.Theme.chip_borde
                        opacity: stageChip.index <= root.flowStage ? 1 : 0.62

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 8 * root.sx
                            text: (stageChip.index + 1) + " · " + stageChip.modelData
                            color: stageChip.index === root.flowStage
                                   ? Style.Theme.texto_sobre_acento
                                   : Style.Theme.texto_secundario_fuerte
                            font.bold: stageChip.index === root.flowStage
                            font.pixelSize: Math.max(9, 10 * root.sx)
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Style.Theme.divisor
            }

            ColumnLayout {
                objectName: "laboratoryDiscoveryPrediction"
                visible: root.stage === 0
                Layout.fillWidth: true
                spacing: 10 * root.sy

                StageHeading {
                    Layout.fillWidth: true
                    number: "1"
                    title: "Predice antes de ver el resultado"
                    subtitle: "No se califica: sirve para hacer visible tu idea inicial."
                }

                Text {
                    Layout.fillWidth: true
                    text: String(root.value(root.challenge, "prompt",
                                            "¿Qué resultado esperas de esta operación?"))
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: Math.max(13, 15 * root.sx)
                    lineHeight: 1.18
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: root.predictionOptions
                    delegate: ChoiceButton {
                        required property int index
                        required property var modelData
                        objectName: "laboratoryDiscoveryPredictionOption" + index
                        Layout.fillWidth: true
                        label: String(modelData)
                        selected: root.selectedPrediction === index
                        sx: root.sx; sy: root.sy
                        onClicked: root.predictionSelected(index)
                    }
                }

                BotonPrincipal {
                    objectName: "laboratoryDiscoveryConfirmPrediction"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42 * root.sy
                    text: "Guardar predicción y preparar experimento"
                    enabled: root.selectedPrediction >= 0
                    opacity: enabled ? 1 : 0.45
                    onClicked: root.predictionConfirmed()
                }

            }

            ColumnLayout {
                objectName: "laboratoryDiscoveryExperiment"
                visible: root.stage === 1
                Layout.fillWidth: true
                spacing: 12 * root.sy

                StageHeading {
                    Layout.fillWidth: true
                    number: "2"
                    title: "Ejecuta y observa el cambio"
                    subtitle: root.experimentTitle + " · " + root.experimentSubtitle
                }

                InfoCard {
                    Layout.fillWidth: true
                    eyebrow: "QUÉ VAS A CAMBIAR"
                    body: root.experimentInstruction
                    sx: root.sx; sy: root.sy
                }

                BotonPrincipal {
                    objectName: "laboratoryDiscoveryRunExperiment"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44 * root.sy
                    text: root.experimentActionLabel + "  →"
                    onClicked: root.experimentRequested()
                }
            }

            ColumnLayout {
                objectName: "laboratoryDiscoveryObservation"
                visible: root.stage === 2
                Layout.fillWidth: true
                spacing: 12 * root.sy

                StageHeading {
                    Layout.fillWidth: true
                    number: "2"
                    title: "Observa la animación"
                    subtitle: "Busca la relación entre la entrada, la operación y la salida."
                }

                InfoCard {
                    Layout.fillWidth: true
                    eyebrow: "QUÉ DEBES BUSCAR"
                    body: root.observationPrompt
                    sx: root.sx; sy: root.sy
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8 * root.sx
                    BotonSecundario {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42 * root.sy
                        sx: root.sx; sy: root.sy
                        text: "Repetir experimento"
                        onClicked: root.experimentRequested()
                    }
                    BotonPrincipal {
                        objectName: "laboratoryDiscoveryConfirmObservation"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42 * root.sy
                        text: "Ya observé el cambio  →"
                        onClicked: root.observationConfirmed()
                    }
                }
            }

            ColumnLayout {
                objectName: "laboratoryDiscoveryExplanationCheck"
                visible: root.stage === 3
                Layout.fillWidth: true
                spacing: 10 * root.sy

                StageHeading {
                    Layout.fillWidth: true
                    number: "3"
                    title: "Contesta qué ocurrió"
                    subtitle: "Elige la explicación que corresponde a esta operación, no solo una frase plausible."
                }

                Text {
                    Layout.fillWidth: true
                    text: "¿Cuál explicación conecta correctamente la fórmula con el cambio observado?"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: Math.max(13, 15 * root.sx)
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: root.explanationOptions
                    delegate: ChoiceButton {
                        required property int index
                        required property var modelData
                        objectName: "laboratoryDiscoveryExplanationOption" + index
                        Layout.fillWidth: true
                        label: String(modelData)
                        selected: root.selectedExplanation === index
                        sx: root.sx; sy: root.sy
                        onClicked: root.explanationSelected(index)
                    }
                }

                Text {
                    objectName: "laboratoryDiscoveryExplanationHint"
                    visible: root.explanationHint.length > 0
                    Layout.fillWidth: true
                    text: root.explanationHint
                    color: Style.Theme.aviso_texto
                    font.bold: true
                    font.pixelSize: Math.max(11, 12 * root.sx)
                    wrapMode: Text.WordWrap
                }

                BotonPrincipal {
                    objectName: "laboratoryDiscoveryCheckExplanation"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42 * root.sy
                    text: "Comprobar respuesta"
                    enabled: root.selectedExplanation >= 0
                    opacity: enabled ? 1 : 0.45
                    onClicked: root.explanationChecked()
                }
            }

            ColumnLayout {
                objectName: "laboratoryDiscoveryFeedback"
                visible: root.stage === 4
                Layout.fillWidth: true
                spacing: 12 * root.sy

                StageHeading {
                    Layout.fillWidth: true
                    number: "✓"
                    title: "Operación completada"
                    subtitle: "Avanzarás automáticamente a la siguiente operación."
                }

                InfoCard {
                    Layout.fillWidth: true
                    eyebrow: root.predictionIsCorrect
                             ? "TU PREDICCIÓN COINCIDIÓ"
                             : "TU PREDICCIÓN CAMBIÓ"
                    body: (root.predictionIsCorrect
                           ? "La observación fue compatible con tu idea inicial. Ahora ya puedes justificarla con la operación matemática."
                           : "La evidencia no coincidió con tu idea inicial. La respuesta esperada era: «"
                             + String(root.predictionOptions[root.correctPrediction] || "—")
                             + "». Cambiar de explicación después de observar es parte del aprendizaje.")
                          + (String(root.value(root.challenge, "explanation", "")).length > 0
                             ? "  " + String(root.value(root.challenge, "explanation", "")) : "")
                    sx: root.sx; sy: root.sy
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: finalExplanation.implicitHeight + 24 * root.sy
                    radius: 10 * root.sx
                    color: Style.Theme.formula_fondo
                    border.color: Style.Theme.formula_texto

                    Text {
                        id: finalExplanation
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12 * root.sx
                        text: "EXPLICACIÓN CORRECTA  ·  "
                              + String(root.value(root.step, "explanation", "—"))
                        color: Style.Theme.texto_primario
                        font.bold: true
                        font.pixelSize: Math.max(12, 14 * root.sx)
                        lineHeight: 1.2
                        wrapMode: Text.WordWrap
                    }
                }

                BotonPrincipal {
                    objectName: "laboratoryDiscoveryShowExplanation"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44 * root.sy
                    text: "Continuar ahora  →"
                    onClicked: root.explanationRequested()
                }
            }
        }
    }

    component StageHeading: RowLayout {
        id: stageHeading
        property string number: "1"
        property string title: ""
        property string subtitle: ""

        spacing: 9 * root.sx
        Rectangle {
            Layout.preferredWidth: 34 * root.sx
            Layout.preferredHeight: 34 * root.sy
            radius: width / 2
            color: Style.Theme.acento
            Text {
                anchors.centerIn: parent
                text: stageHeading.number
                color: Style.Theme.texto_sobre_acento
                font.bold: true
                font.pixelSize: Math.max(12, 14 * root.sx)
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1 * root.sy
            Text {
                Layout.fillWidth: true
                text: stageHeading.title
                color: Style.Theme.texto_primario
                font.bold: true
                font.pixelSize: Math.max(15, 18 * root.sx)
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                text: stageHeading.subtitle
                color: Style.Theme.texto_secundario_fuerte
                font.pixelSize: Math.max(10, 12 * root.sx)
                wrapMode: Text.WordWrap
            }
        }
    }

    component ChoiceButton: BotonAccesible {
        id: choiceButton
        property string label: ""
        property bool selected: false
        property real sx: 1
        property real sy: 1

        Layout.preferredHeight: Math.max(44 * sy, choiceText.implicitHeight + 18 * sy)
        text: label
        background: Rectangle {
            radius: 9 * choiceButton.sx
            color: choiceButton.selected ? Style.Theme.acento_fondo : Style.Theme.surface
            border.width: choiceButton.selected ? 2 : 1
            border.color: choiceButton.selected ? Style.Theme.acento : Style.Theme.borde_suave
        }
        contentItem: Text {
            id: choiceText
            text: choiceButton.text
            color: Style.Theme.texto_primario
            font.bold: choiceButton.selected
            font.pixelSize: Math.max(11, 13 * choiceButton.sx)
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignVCenter
            leftPadding: 12 * choiceButton.sx
            rightPadding: 12 * choiceButton.sx
        }
    }

    component InfoCard: Rectangle {
        id: infoCard
        property string eyebrow: ""
        property string body: ""
        property real sx: 1
        property real sy: 1

        implicitHeight: infoColumn.implicitHeight + 22 * sy
        radius: 10 * sx
        color: Style.Theme.superficie_alterna
        border.color: Style.Theme.acento

        ColumnLayout {
            id: infoColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 11 * infoCard.sx
            spacing: 5 * infoCard.sy
            Text {
                Layout.fillWidth: true
                text: infoCard.eyebrow
                color: Style.Theme.acento_fuerte
                font.bold: true
                font.pixelSize: Math.max(10, 11 * infoCard.sx)
            }
            Text {
                Layout.fillWidth: true
                text: infoCard.body
                color: Style.Theme.texto_primario
                font.pixelSize: Math.max(12, 14 * infoCard.sx)
                lineHeight: 1.2
                wrapMode: Text.WordWrap
            }
        }
    }
}
