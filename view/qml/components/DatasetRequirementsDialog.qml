pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

Dialog {
    id: root
    objectName: "datasetRequirementsDialog"

    readonly property real viewportWidth: Overlay.overlay
                                                ? Overlay.overlay.width
                                                : (parent ? parent.width : 1280)
    readonly property real viewportHeight: Overlay.overlay
                                                 ? Overlay.overlay.height
                                                 : (parent ? parent.height : 820)
    readonly property real contentMargin: width < 720 ? 16 : 26

    function mostrar() {
        open()
    }

    parent: Overlay.overlay
    anchors.centerIn: Overlay.overlay
    width: Math.max(1, Math.min(940, viewportWidth - 32))
    height: Math.max(1, Math.min(790, viewportHeight - 32))
    padding: 0
    modal: true
    dim: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    Overlay.modal: Rectangle {
        color: "#990F172A"
    }

    background: Rectangle {
        color: Style.Theme.surface
        radius: 16
        border.width: 1
        border.color: Style.Theme.borde_medio
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.contentMargin
        spacing: 14
        Accessible.name: "Guía de formato para datasets"
        Accessible.description: "Explica los campos y formatos que admite la aplicación"

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Label {
                    Layout.fillWidth: true
                    text: "Cómo debe ser el dataset"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: root.width < 720 ? 21 : 26
                    wrapMode: Text.WordWrap
                    Accessible.role: Accessible.Heading
                }

                Label {
                    Layout.fillWidth: true
                    text: "El formato define qué texto lee el encoder y qué respuesta aprende a producir el decoder."
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                }
            }

            ToolButton {
                id: closeButton
                objectName: "datasetRequirementsCloseButton"
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                text: "×"
                focusPolicy: Qt.StrongFocus
                Accessible.name: "Cerrar guía de formato"
                ToolTip.visible: hovered
                ToolTip.text: "Cerrar (Esc)"
                onClicked: root.close()

                background: Rectangle {
                    radius: 9
                    color: closeButton.down
                           ? Style.Theme.boton_presionado
                           : (closeButton.hovered || closeButton.activeFocus
                              ? Style.Theme.acento_fondo : "transparent")
                    border.width: closeButton.activeFocus ? 2 : 0
                    border.color: Style.Theme.acento
                }

                contentItem: Text {
                    text: closeButton.text
                    color: Style.Theme.texto_primario
                    font.pixelSize: 26
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Style.Theme.divisor
        }

        ScrollView {
            id: guideScroll
            objectName: "datasetRequirementsScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: guideScroll.availableWidth
                spacing: 14

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: whyContent.implicitHeight + 24
                    radius: 11
                    color: Style.Theme.info_fondo
                    border.width: 1
                    border.color: Style.Theme.info

                    ColumnLayout {
                        id: whyContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 6

                        Label {
                            Layout.fillWidth: true
                            text: "Por qué se necesitan pares entrada → respuesta"
                            color: Style.Theme.info_texto
                            font.bold: true
                            font.pixelSize: 16
                            wrapMode: Text.WordWrap
                        }

                        Label {
                            Layout.fillWidth: true
                            text: "Este Transformer es encoder-decoder: el encoder recibe una entrada y el decoder aprende una salida objetivo. Durante el entrenamiento, la respuesta se desplaza una posición para que el decoder prediga el siguiente token; la aplicación compara esa predicción con la respuesta correcta y ajusta el modelo. Sin una salida esperada no hay una referencia directa para calcular ese error."
                            color: Style.Theme.texto_primario
                            font.pixelSize: 13
                            lineHeight: 1.15
                            wrapMode: Text.WordWrap
                        }

                        Label {
                            Layout.fillWidth: true
                            text: "Importante: los nombres instruction, response y context son el contrato de esta aplicación; no son nombres universales exigidos por todos los Transformers."
                            color: Style.Theme.info_texto
                            font.bold: true
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: "Campos para datos emparejados"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 18
                    Accessible.role: Accessible.Heading
                }

                Repeater {
                    model: [
                        {
                            "name": "instruction  ·  obligatorio",
                            "detail": "La pregunta, orden o texto que recibe el encoder. Debe ser texto y no puede estar vacío.",
                            "example": "Ejemplo: Traduce al inglés: Hola"
                        },
                        {
                            "name": "response  ·  obligatorio",
                            "detail": "La salida correcta que el decoder debe aprender a generar. Debe ser texto y no puede estar vacía.",
                            "example": "Ejemplo: Hello"
                        },
                        {
                            "name": "context  ·  opcional",
                            "detail": "Información adicional para resolver la instrucción. En JSONL, JSON y CSV, si tiene contenido, la aplicación la concatena a instruction antes de tokenizar.",
                            "example": "Ejemplo: El saludo se usa al encontrarse con alguien."
                        },
                        {
                            "name": "category  ·  opcional",
                            "detail": "Etiqueta para organizar y resumir los ejemplos. Se muestra en el catálogo, pero no se usa como respuesta de entrenamiento.",
                            "example": "Ejemplo: traducción"
                        }
                    ]

                    delegate: Rectangle {
                        id: fieldCard
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: fieldContent.implicitHeight + 20
                        radius: 10
                        color: Style.Theme.superficie_alterna
                        border.width: 1
                        border.color: Style.Theme.borde_medio

                        ColumnLayout {
                            id: fieldContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 3

                            Label {
                                Layout.fillWidth: true
                                text: fieldCard.modelData.name
                                color: Style.Theme.texto_primario
                                font.bold: true
                                font.family: Qt.platform.os === "windows" ? "Consolas" : "monospace"
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                            }

                            Label {
                                Layout.fillWidth: true
                                text: fieldCard.modelData.detail
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                            }

                            Label {
                                Layout.fillWidth: true
                                text: fieldCard.modelData.example
                                color: Style.Theme.acento_texto
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: "Formatos exactos admitidos"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 18
                    Accessible.role: Accessible.Heading
                }

                Repeater {
                    model: [
                        {
                            "title": "JSONL · recomendado y usado por el creador",
                            "description": "Un objeto JSON completo por línea, sin corchetes ni comas entre líneas. Admite context.",
                            "code": "{\"instruction\":\"Traduce: Hola\",\"context\":\"\",\"response\":\"Hello\",\"category\":\"traducción\"}\n{\"instruction\":\"Traduce: Adiós\",\"context\":\"\",\"response\":\"Goodbye\"}"
                        },
                        {
                            "title": "JSON",
                            "description": "Una lista de objetos. Cada objeto necesita instruction y response; context y category son opcionales.",
                            "code": "[{\"instruction\":\"2 + 2\",\"context\":\"Responde solo con el resultado\",\"response\":\"4\"}]"
                        },
                        {
                            "title": "CSV",
                            "description": "Archivo separado por comas con encabezados obligatorios instruction,response. Puede incluir context y category; las comas o saltos dentro del texto deben ir entre comillas.",
                            "code": "instruction,context,response,category\n¿Cuánto es 2 + 2?,Responde solo con el resultado,4,matemáticas"
                        }
                    ]

                    delegate: Rectangle {
                        id: formatCard
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: formatContent.implicitHeight + 22
                        radius: 10
                        color: Style.Theme.surface
                        border.width: 1
                        border.color: Style.Theme.borde_medio

                        ColumnLayout {
                            id: formatContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 11
                            spacing: 5

                            Label {
                                Layout.fillWidth: true
                                text: formatCard.modelData.title
                                color: Style.Theme.texto_primario
                                font.bold: true
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                            }

                            Label {
                                Layout.fillWidth: true
                                text: formatCard.modelData.description
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: codeText.implicitHeight + 18
                                radius: 7
                                color: Style.Theme.chip_fondo

                                Text {
                                    id: codeText
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 9
                                    text: formatCard.modelData.code
                                    textFormat: Text.PlainText
                                    color: Style.Theme.chip_texto
                                    font.family: Qt.platform.os === "windows" ? "Consolas" : "monospace"
                                    font.pixelSize: 12
                                    wrapMode: Text.WrapAnywhere
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: corpusContent.implicitHeight + 24
                    radius: 11
                    color: Style.Theme.aviso_fondo
                    border.width: 1
                    border.color: Style.Theme.warning

                    ColumnLayout {
                        id: corpusContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 5

                        Label {
                            Layout.fillWidth: true
                            text: "Alternativa: TXT o PDF como corpus continuo"
                            color: Style.Theme.aviso_texto
                            font.bold: true
                            font.pixelSize: 15
                            wrapMode: Text.WordWrap
                        }

                        Label {
                            Layout.fillWidth: true
                            text: "También puedes importar texto corrido. La aplicación lo divide en ventanas de aproximadamente 128 tokens y empareja cada ventana con la siguiente; así el modelo aprende continuación de texto, no preguntas y respuestas. Necesita suficiente contenido para formar al menos dos ventanas completas (por defecto, alrededor de 256 tokens). El PDF debe contener texto seleccionable; los documentos escaneados necesitan OCR y no se pueden leer aquí. La compatibilidad final se confirma al tokenizar con el modelo activo."
                            color: Style.Theme.texto_primario
                            font.pixelSize: 13
                            lineHeight: 1.15
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: checklistContent.implicitHeight + 24
                    radius: 11
                    color: Style.Theme.acento_fondo
                    border.width: 1
                    border.color: Style.Theme.acento

                    ColumnLayout {
                        id: checklistContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 5

                        Label {
                            Layout.fillWidth: true
                            text: "Antes de entrenar"
                            color: Style.Theme.acento_texto
                            font.bold: true
                            font.pixelSize: 15
                        }

                        Label {
                            Layout.fillWidth: true
                            text: "• Usa respuestas correctas, claras y coherentes con la instrucción.\n• Evita ejemplos duplicados, contradictorios o con datos sensibles.\n• Incluye variedad suficiente: un solo ejemplo es válido para probar el flujo, pero no basta para que el modelo generalice.\n• Los ejemplos más largos que el contexto del modelo se truncarán.\n• Separa datos de entrenamiento y evaluación para medir con ejemplos que el modelo no haya visto; la aplicación no realiza esa separación automáticamente."
                            color: Style.Theme.texto_primario
                            font.pixelSize: 13
                            lineHeight: 1.15
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 2
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Label {
                Layout.fillWidth: true
                visible: root.width >= 560
                text: "Puedes volver a consultar esta guía desde la biblioteca."
                color: Style.Theme.texto_secundario
                font.pixelSize: 12
            }

            Button {
                id: understoodButton
                objectName: "datasetRequirementsUnderstoodButton"
                Layout.preferredWidth: 150
                Layout.preferredHeight: 40
                text: "Entendido"
                focusPolicy: Qt.StrongFocus
                Accessible.name: "Cerrar guía de formato"
                onClicked: root.close()

                background: Rectangle {
                    radius: 9
                    color: understoodButton.down
                           ? Style.Theme.boton_presionado
                           : (understoodButton.hovered
                              ? Style.Theme.acento_fondo : Style.Theme.boton)
                    border.width: understoodButton.activeFocus ? 2 : 1
                    border.color: understoodButton.activeFocus
                                  ? Style.Theme.acento : Style.Theme.borde_boton
                }

                contentItem: Text {
                    text: understoodButton.text
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    onOpened: closeButton.forceActiveFocus()
}
