pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

Rectangle {
    id: root

    property var concepto: ({})
    // Cuando se proporciona, esta lista prevalece sobre concepto.relacionados.
    // Esto evita mutar los QVariantMap devueltos por TheoryController.
    property var relatedConcepts: null
    property string errorCarga: ""
    property real sx: 1.0
    property real sy: 1.0
    property bool closable: true
    property bool expanded: false

    signal closeRequested()
    signal conceptRequested(string conceptId)

    readonly property real contentScale: Math.max(
                                                   0.55,
                                                   Math.min(1.15, Math.min(root.sx, root.sy))
                                               )
    readonly property var relacionados: root.relatedConcepts !== null
                                        && root.relatedConcepts !== undefined
                                        ? root.relatedConcepts
                                        : (root.concepto && root.concepto.relacionados
                                           ? root.concepto.relacionados : [])
    readonly property bool tieneConcepto: root.concepto
                                           && Object.keys(root.concepto).length > 0

    function texto(campo) {
        if (!root.concepto || root.concepto[campo] === undefined
                || root.concepto[campo] === null)
            return ""
        return String(root.concepto[campo])
    }

    function filasDimensiones() {
        var dimensiones = root.concepto ? root.concepto.dimensions : null
        if (!dimensiones)
            return []
        var resultado = []
        var claves = Object.keys(dimensiones)
        for (var i = 0; i < claves.length; ++i) {
            var clave = claves[i]
            resultado.push({ "nombre": clave, "valor": String(dimensiones[clave]) })
        }
        return resultado
    }

    function prepareForOpen() {
        if (theoryScroll.ScrollBar.vertical)
            theoryScroll.ScrollBar.vertical.position = 0
        if (closeButton.visible)
            closeButton.forceActiveFocus()
    }

    implicitHeight: (root.expanded ? 620 : 390) * root.contentScale
    radius: (root.expanded ? 16 : 10) * root.contentScale
    color: "#FFFFFF"
    border.color: "#D8D2EC"
    border.width: 1
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: (root.expanded ? 24 : 14) * root.contentScale
        spacing: (root.expanded ? 14 : 9) * root.contentScale

        RowLayout {
            Layout.fillWidth: true
            spacing: 10 * root.contentScale

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4 * root.contentScale

                Text {
                    Layout.fillWidth: true
                    text: root.tieneConcepto
                          ? root.texto("title") : "Teoría del componente"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: (root.expanded ? 26 : 17) * root.contentScale
                    wrapMode: Text.WordWrap
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.texto("short_description")
                    color: Style.Theme.texto_secundario
                    font.pixelSize: (root.expanded ? 14 : 11) * root.contentScale
                    wrapMode: Text.WordWrap
                }
            }

            Button {
                id: closeButton

                visible: root.closable
                Layout.preferredWidth: (root.expanded ? 42 : 32) * root.contentScale
                Layout.preferredHeight: (root.expanded ? 42 : 32) * root.contentScale
                text: "×"
                flat: true
                font.bold: true
                font.pixelSize: (root.expanded ? 24 : 19) * root.contentScale
                activeFocusOnTab: true
                Accessible.name: "Cerrar explicación"
                ToolTip.visible: hovered || activeFocus
                ToolTip.text: "Cerrar teoría y volver a la vista general"
                onClicked: root.closeRequested()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#E4E0F0"
        }

        ScrollView {
            id: theoryScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            Column {
                width: theoryScroll.availableWidth
                spacing: (root.expanded ? 16 : 10) * root.contentScale

                Rectangle {
                    visible: root.errorCarga !== ""
                    width: parent.width
                    height: visible ? errorText.implicitHeight
                                      + (root.expanded ? 24 : 18) * root.contentScale : 0
                    radius: (root.expanded ? 9 : 7) * root.contentScale
                    color: "#FEF2F2"
                    border.color: "#FCA5A5"

                    Text {
                        id: errorText
                        anchors.fill: parent
                        anchors.margins: (root.expanded ? 12 : 9) * root.contentScale
                        text: root.errorCarga
                        color: "#991B1B"
                        font.pixelSize: (root.expanded ? 14 : 10) * root.contentScale
                        wrapMode: Text.WordWrap
                    }
                }

                Text {
                    width: parent.width
                    visible: root.tieneConcepto
                    text: root.texto("explanation")
                    color: Style.Theme.texto_primario
                    font.pixelSize: (root.expanded ? 16 : 12) * root.contentScale
                    lineHeight: root.expanded ? 1.30 : 1.18
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    visible: !root.tieneConcepto && root.errorCarga === ""
                    text: "Selecciona un bloque del Transformer para consultar su teoría."
                    color: Style.Theme.texto_secundario
                    font.pixelSize: (root.expanded ? 16 : 12) * root.contentScale
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    visible: root.texto("intuition") !== ""
                    text: "INTUICIÓN"
                    color: "#6C5FC3"
                    font.bold: true
                    font.pixelSize: (root.expanded ? 12 : 10) * root.contentScale
                }
                Text {
                    width: parent.width
                    visible: root.texto("intuition") !== ""
                    text: root.texto("intuition")
                    color: "#514978"
                    font.italic: true
                    font.pixelSize: (root.expanded ? 14 : 11) * root.contentScale
                    lineHeight: root.expanded ? 1.25 : 1.0
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    visible: root.texto("formula") !== "" || root.texto("mathematical") !== ""
                    width: parent.width
                    height: visible ? formulaColumn.implicitHeight
                                      + (root.expanded ? 28 : 20) * root.contentScale : 0
                    radius: (root.expanded ? 10 : 7) * root.contentScale
                    color: "#F5F3FB"
                    border.color: "#DDD7F1"

                    Column {
                        id: formulaColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: (root.expanded ? 14 : 10) * root.contentScale
                        spacing: (root.expanded ? 9 : 6) * root.contentScale

                        Text {
                            width: parent.width
                            visible: root.texto("formula") !== ""
                            text: root.texto("formula")
                            color: "#433879"
                            font.family: "monospace"
                            font.pixelSize: (root.expanded ? 14 : 11) * root.contentScale
                            wrapMode: Text.WrapAnywhere
                        }
                        Text {
                            width: parent.width
                            visible: root.texto("mathematical") !== ""
                            text: root.texto("mathematical")
                            color: Style.Theme.texto_secundario
                            font.pixelSize: (root.expanded ? 13 : 10) * root.contentScale
                            lineHeight: root.expanded ? 1.22 : 1.0
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.texto("example") !== ""
                    text: "EJEMPLO"
                    color: "#3979B7"
                    font.bold: true
                    font.pixelSize: (root.expanded ? 12 : 10) * root.contentScale
                }
                Text {
                    width: parent.width
                    visible: root.texto("example") !== ""
                    text: root.texto("example")
                    color: "#315F88"
                    font.pixelSize: (root.expanded ? 14 : 11) * root.contentScale
                    lineHeight: root.expanded ? 1.25 : 1.0
                    wrapMode: Text.WordWrap
                }

                Column {
                    visible: Boolean(root.concepto && root.concepto.steps
                                     && root.concepto.steps.length > 0)
                    width: parent.width
                    spacing: (root.expanded ? 7 : 4) * root.contentScale

                    Text {
                        width: parent.width
                        text: "PASOS"
                        color: "#258F6F"
                        font.bold: true
                        font.pixelSize: (root.expanded ? 12 : 10) * root.contentScale
                    }
                    Repeater {
                        model: root.concepto && root.concepto.steps
                               ? root.concepto.steps : []
                        delegate: Text {
                            required property var modelData
                            width: parent.width
                            text: "• " + String(modelData)
                            color: Style.Theme.texto_primario
                            font.pixelSize: (root.expanded ? 13 : 10) * root.contentScale
                            lineHeight: root.expanded ? 1.22 : 1.0
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Column {
                    visible: root.filasDimensiones().length > 0
                    width: parent.width
                    spacing: (root.expanded ? 7 : 4) * root.contentScale

                    Text {
                        width: parent.width
                        text: "DIMENSIONES"
                        color: "#9A641B"
                        font.bold: true
                        font.pixelSize: (root.expanded ? 12 : 10) * root.contentScale
                    }
                    Repeater {
                        model: root.filasDimensiones()
                        delegate: RowLayout {
                            id: dimensionDelegate
                            required property var modelData
                            width: parent.width
                            spacing: (root.expanded ? 12 : 8) * root.contentScale
                            Text {
                                Layout.fillWidth: true
                                text: dimensionDelegate.modelData.nombre
                                color: Style.Theme.texto_secundario
                                font.pixelSize: (root.expanded ? 13 : 9) * root.contentScale
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                Layout.preferredWidth: parent.width * 0.42
                                text: dimensionDelegate.modelData.valor
                                color: Style.Theme.texto_primario
                                font.family: "monospace"
                                font.pixelSize: (root.expanded ? 13 : 9) * root.contentScale
                                horizontalAlignment: Text.AlignRight
                                wrapMode: Text.WrapAnywhere
                            }
                        }
                    }
                }

                Column {
                    visible: root.relacionados.length > 0
                    width: parent.width
                    spacing: (root.expanded ? 8 : 5) * root.contentScale

                    Text {
                        width: parent.width
                        text: "PARA PROFUNDIZAR"
                        color: "#6C5FC3"
                        font.bold: true
                        font.pixelSize: (root.expanded ? 12 : 10) * root.contentScale
                    }
                    Repeater {
                        model: root.relacionados
                        delegate: Button {
                            id: relatedDelegate
                            required property var modelData
                            width: parent.width
                            implicitHeight: relatedColumn.implicitHeight
                                            + (root.expanded ? 22 : 14) * root.contentScale
                            padding: (root.expanded ? 11 : 7) * root.contentScale
                            activeFocusOnTab: true
                            Accessible.name: "Abrir concepto relacionado: "
                                             + String(modelData.title || modelData.id)

                            background: Rectangle {
                                radius: (root.expanded ? 8 : 6) * root.contentScale
                                color: relatedDelegate.down ? "#E5DFF5"
                                      : relatedDelegate.hovered || relatedDelegate.activeFocus
                                        ? "#EEEAF8" : "#F8F7FC"
                                border.color: relatedDelegate.activeFocus
                                              ? "#7B68C8" : "#DED8F0"
                                border.width: relatedDelegate.activeFocus ? 2 : 1
                            }

                            contentItem: Column {
                                id: relatedColumn
                                spacing: (root.expanded ? 4 : 2) * root.contentScale
                                Text {
                                    width: parent.width
                                    text: relatedDelegate.modelData.title || relatedDelegate.modelData.id
                                    color: "#51458D"
                                    font.bold: true
                                    font.pixelSize: (root.expanded ? 14 : 10) * root.contentScale
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    width: parent.width
                                    visible: text !== ""
                                    text: relatedDelegate.modelData.short_description || ""
                                    color: Style.Theme.texto_secundario
                                    font.pixelSize: (root.expanded ? 12 : 9) * root.contentScale
                                    lineHeight: root.expanded ? 1.20 : 1.0
                                    wrapMode: Text.WordWrap
                                }
                            }

                            onClicked: root.conceptRequested(
                                           String(relatedDelegate.modelData.id))
                        }
                    }
                }
            }
        }
    }
}
