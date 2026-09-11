pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

Rectangle {
    id: root
    objectName: "guidedConceptReader"

    property var concept: ({})
    property var relatedConcepts: []
    property string loadError: ""
    property real scaleFactor: 1.0

    signal deepDiveRequested(string conceptId)

    function textFor(fieldName) {
        if (!root.concept || root.concept[fieldName] === undefined
                || root.concept[fieldName] === null)
            return ""
        return String(root.concept[fieldName])
    }

    function stepsForConcept() {
        if (!root.concept || !root.concept.steps)
            return []
        return root.concept.steps
    }

    radius: 14 * scaleFactor
    color: Style.Theme.surface
    border.width: 1
    border.color: Style.Theme.acento_fondo
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18 * root.scaleFactor
        spacing: 10 * root.scaleFactor

        RowLayout {
            Layout.fillWidth: true
            spacing: 10 * root.scaleFactor

            Rectangle {
                Layout.preferredWidth: 36 * root.scaleFactor
                Layout.preferredHeight: 36 * root.scaleFactor
                radius: 10 * root.scaleFactor
                color: Style.Theme.acento_fondo

                Text {
                    anchors.centerIn: parent
                    text: "Aa"
                    color: Style.Theme.acento_fuerte
                    font.bold: true
                    font.pixelSize: 13 * root.scaleFactor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2 * root.scaleFactor

                Text {
                    Layout.fillWidth: true
                    text: root.textFor("title") || "Concepto no disponible"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 20 * root.scaleFactor
                    wrapMode: Text.WordWrap
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.textFor("short_description")
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 12 * root.scaleFactor
                    wrapMode: Text.WordWrap
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Style.Theme.acento_fondo
        }

        ScrollView {
            id: readingScroll
            objectName: "guidedConceptScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            Column {
                width: readingScroll.availableWidth
                spacing: 12 * root.scaleFactor

                Rectangle {
                    visible: root.loadError !== ""
                    width: parent.width
                    height: visible ? errorLabel.implicitHeight + 22 * root.scaleFactor : 0
                    radius: 8 * root.scaleFactor
                    color: Style.Theme.chip_fondo
                    border.color: "#FCA5A5"

                    Text {
                        id: errorLabel
                        anchors.fill: parent
                        anchors.margins: 11 * root.scaleFactor
                        text: root.loadError
                        color: Style.Theme.error_texto
                        font.pixelSize: 11 * root.scaleFactor
                        wrapMode: Text.WordWrap
                    }
                }

                Text {
                    width: parent.width
                    text: root.textFor("explanation")
                    color: Style.Theme.texto_primario
                    font.pixelSize: 14 * root.scaleFactor
                    lineHeight: 1.22
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    visible: root.textFor("intuition") !== ""
                    width: parent.width
                    height: visible ? intuitionColumn.implicitHeight + 22 * root.scaleFactor : 0
                    radius: 9 * root.scaleFactor
                    color: Style.Theme.acento_fondo
                    border.color: Style.Theme.acento_fondo

                    Column {
                        id: intuitionColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 11 * root.scaleFactor
                        spacing: 5 * root.scaleFactor

                        Text {
                            width: parent.width
                            text: "IDEA CLAVE"
                            color: Style.Theme.acento
                            font.bold: true
                            font.pixelSize: 10 * root.scaleFactor
                        }

                        Text {
                            width: parent.width
                            text: root.textFor("intuition")
                            color: Style.Theme.acento_fuerte
                            font.italic: true
                            font.pixelSize: 12 * root.scaleFactor
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Rectangle {
                    visible: root.textFor("formula") !== ""
                             || root.textFor("mathematical") !== ""
                    width: parent.width
                    height: visible ? formulaColumn.implicitHeight + 22 * root.scaleFactor : 0
                    radius: 9 * root.scaleFactor
                    color: Style.Theme.superficie_alterna
                    border.color: Style.Theme.borde_medio

                    Column {
                        id: formulaColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 11 * root.scaleFactor
                        spacing: 6 * root.scaleFactor

                        Text {
                            width: parent.width
                            visible: root.textFor("formula") !== ""
                            text: root.textFor("formula")
                            color: Style.Theme.acento_fuerte
                            font.family: "monospace"
                            font.pixelSize: 12 * root.scaleFactor
                            wrapMode: Text.WrapAnywhere
                        }

                        Text {
                            width: parent.width
                            visible: root.textFor("mathematical") !== ""
                            text: root.textFor("mathematical")
                            color: Style.Theme.texto_secundario
                            font.pixelSize: 11 * root.scaleFactor
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Column {
                    visible: root.stepsForConcept().length > 0
                    width: parent.width
                    spacing: 6 * root.scaleFactor

                    Text {
                        width: parent.width
                        text: "PASO A PASO"
                        color: "#25846A"
                        font.bold: true
                        font.pixelSize: 10 * root.scaleFactor
                    }

                    Repeater {
                        model: root.stepsForConcept()

                        delegate: RowLayout {
                            id: stepDelegate
                            required property var modelData
                            required property int index
                            width: parent.width
                            spacing: 8 * root.scaleFactor

                            Rectangle {
                                Layout.preferredWidth: 22 * root.scaleFactor
                                Layout.preferredHeight: 22 * root.scaleFactor
                                radius: width / 2
                                color: Style.Theme.chip_fondo

                                Text {
                                    anchors.centerIn: parent
                                    text: String(stepDelegate.index + 1)
                                    color: "#26725D"
                                    font.bold: true
                                    font.pixelSize: 10 * root.scaleFactor
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: String(stepDelegate.modelData)
                                color: Style.Theme.texto_primario
                                font.pixelSize: 11 * root.scaleFactor
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                Column {
                    visible: root.textFor("example") !== ""
                    width: parent.width
                    spacing: 5 * root.scaleFactor

                    Text {
                        width: parent.width
                        text: "EJEMPLO"
                        color: "#3979B7"
                        font.bold: true
                        font.pixelSize: 10 * root.scaleFactor
                    }

                    Text {
                        width: parent.width
                        text: root.textFor("example")
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 11 * root.scaleFactor
                        wrapMode: Text.WordWrap
                    }
                }

                Button {
                    id: deepDiveButton
                    objectName: "guidedDeepDiveButton"
                    width: parent.width
                    height: 42 * root.scaleFactor
                    text: root.relatedConcepts.length > 0
                          ? "Profundizar y ver relacionados (" + root.relatedConcepts.length + ")"
                          : "Profundizar en este concepto"
                    activeFocusOnTab: true
                    Accessible.name: text
                    Accessible.description: "Abre detalles y conexiones adicionales del concepto actual"

                    background: Rectangle {
                        radius: 8 * root.scaleFactor
                        color: deepDiveButton.down ? Style.Theme.acento_fondo
                                                   : deepDiveButton.hovered ? Style.Theme.acento_fondo : Style.Theme.acento_fondo
                        border.color: Style.Theme.acento_fondo
                    }

                    contentItem: Text {
                        text: deepDiveButton.text
                        color: Style.Theme.acento_fuerte
                        font.bold: true
                        font.pixelSize: 11 * root.scaleFactor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: root.deepDiveRequested(root.textFor("id"))
                }
            }
        }
    }
}
