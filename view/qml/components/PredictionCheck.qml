pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../styles" as Style

// Pregunta formativa de una sola respuesta: el alumno elige, comprueba y
// recibe retroalimentación. La calificación vive en el ViewModel y llega como
// `result`; este componente sólo presenta y emite la elección, para que la
// clave nunca se decida en QML.
//
// No es un reactivo de evaluación: no lo usan el pre-test ni el post-test.
Rectangle {
    id: root

    property real sx: 1
    property string eyebrow: "PREDICE ANTES DE VER"
    property string submitLabel: "Comprobar"
    // { prompt, options }
    property var check: ({})
    // { correct, correct_index, feedback } — vacío mientras no se comprueba.
    property var result: ({})
    property int selectedIndex: -1
    readonly property var options: root.check && root.check.options ? root.check.options : []
    readonly property bool answered: root.result !== undefined && root.result !== null
                                     && root.result.correct !== undefined
    readonly property int correctIndex: root.answered ? Number(root.result.correct_index) : -1

    signal submitted(int optionIndex)

    implicitHeight: content.implicitHeight + 22 * root.sx
    radius: 10 * root.sx
    color: Style.Theme.info_fondo
    border.width: root.answered ? 2 : 1
    border.color: !root.answered ? Style.Theme.borde_suave
                                 : (root.result.correct ? Style.Theme.success : Style.Theme.warning)

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 11 * root.sx
        spacing: 7 * root.sx

        Text {
            Layout.fillWidth: true
            text: root.eyebrow
            color: Style.Theme.info_texto
            font.bold: true
            font.pixelSize: Math.max(9, 9.5 * root.sx)
            font.letterSpacing: 0.7
        }

        Text {
            objectName: root.objectName + "Prompt"
            Layout.fillWidth: true
            text: String(root.check && root.check.prompt || "")
            color: Style.Theme.texto_primario
            font.bold: true
            font.pixelSize: Math.max(11, 12 * root.sx)
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.options
            delegate: Rectangle {
                id: option
                required property var modelData
                required property int index
                readonly property bool selected: root.selectedIndex === option.index
                readonly property bool isCorrect: root.answered && option.index === root.correctIndex
                readonly property bool isWrongChoice: root.answered && option.selected
                                                      && option.index !== root.correctIndex
                objectName: root.objectName + "Option" + option.index
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(30 * root.sx, optionText.implicitHeight + 12 * root.sx)
                radius: 7 * root.sx
                color: option.isCorrect ? Style.Theme.exito_fondo
                       : (option.isWrongChoice ? Style.Theme.aviso_fondo
                          : (option.selected ? Style.Theme.acento_fondo : Style.Theme.surface))
                border.width: option.selected || option.isCorrect ? 2 : 1
                border.color: option.isCorrect ? Style.Theme.success
                              : (option.selected ? Style.Theme.acento : Style.Theme.borde_suave)
                Accessible.role: Accessible.RadioButton
                Accessible.name: String(option.modelData)
                Accessible.checked: option.selected

                Text {
                    id: optionText
                    anchors.fill: parent
                    anchors.leftMargin: 10 * root.sx
                    anchors.rightMargin: 10 * root.sx
                    text: (option.isCorrect ? "✓  " : (option.isWrongChoice ? "✗  " : ""))
                          + String(option.modelData)
                    color: option.isCorrect ? Style.Theme.exito_texto
                           : (option.isWrongChoice ? Style.Theme.aviso_texto : Style.Theme.texto_primario)
                    font.pixelSize: Math.max(10, 11 * root.sx)
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.answered
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.selectedIndex = option.index
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !root.answered
            Item { Layout.fillWidth: true }
            BotonSecundario {
                objectName: root.objectName + "Submit"
                sx: root.sx
                sy: root.sx
                Layout.preferredWidth: 130 * root.sx
                text: root.submitLabel
                enabled: root.selectedIndex >= 0
                onClicked: root.submitted(root.selectedIndex)
            }
        }

        Text {
            objectName: root.objectName + "Feedback"
            Layout.fillWidth: true
            visible: root.answered
            text: root.answered
                  ? ((root.result.correct ? "Correcto. " : "Tu predicción no coincidió. ")
                     + String(root.result.feedback || ""))
                  : ""
            color: root.answered && root.result.correct ? Style.Theme.exito_texto
                                                        : Style.Theme.aviso_texto
            font.pixelSize: Math.max(10, 11 * root.sx)
            wrapMode: Text.WordWrap
        }
    }
}
