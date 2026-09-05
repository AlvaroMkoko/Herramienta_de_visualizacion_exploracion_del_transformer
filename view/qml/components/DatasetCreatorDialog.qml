pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

Dialog {
    id: root
    objectName: "datasetCreatorDialog"

    property var datasetController: null
    property string validationMessage: ""
    readonly property int exampleCount: examplesModel.count
    readonly property real viewportWidth: Overlay.overlay
                                                ? Overlay.overlay.width
                                                : (parent ? parent.width : 1280)
    readonly property real viewportHeight: Overlay.overlay
                                                 ? Overlay.overlay.height
                                                 : (parent ? parent.height : 820)
    readonly property real contentMargin: width < 720 ? 14 : 24

    signal datasetCreated(var dataset)

    function clean(value) {
        return value === undefined || value === null
                ? "" : String(value).trim()
    }

    function draftHasContent() {
        return clean(instructionField.text) !== ""
                || clean(contextField.text) !== ""
                || clean(responseField.text) !== ""
                || clean(categoryField.text) !== ""
    }

    function draftIsValid() {
        return clean(instructionField.text) !== ""
                && clean(responseField.text) !== ""
    }

    function clearDraft() {
        instructionField.clear()
        contextField.clear()
        responseField.clear()
        categoryField.clear()
    }

    function resetForm() {
        nameField.clear()
        clearDraft()
        examplesModel.clear()
        validationMessage = ""
    }

    function mostrar() {
        resetForm()
        open()
    }

    function addCurrentExample() {
        validationMessage = ""
        if (clean(instructionField.text) === "") {
            validationMessage = "Escribe la entrada obligatoria (instruction)."
            instructionField.forceActiveFocus()
            return false
        }
        if (clean(responseField.text) === "") {
            validationMessage = "Escribe la respuesta esperada obligatoria (response)."
            responseField.forceActiveFocus()
            return false
        }

        examplesModel.append({
            "instruction": clean(instructionField.text),
            "context": clean(contextField.text),
            "response": clean(responseField.text),
            "category": clean(categoryField.text)
        })
        clearDraft()
        instructionField.forceActiveFocus()
        Qt.callLater(function() {
            creatorScroll.ScrollBar.vertical.position = 1.0
        })
        return true
    }

    function removeExample(exampleIndex) {
        if (exampleIndex < 0 || exampleIndex >= examplesModel.count)
            return
        examplesModel.remove(exampleIndex)
        validationMessage = ""
    }

    function recordsAsArray() {
        var records = []
        for (var i = 0; i < examplesModel.count; ++i) {
            var example = examplesModel.get(i)
            records.push({
                "instruction": example.instruction,
                "context": example.context,
                "response": example.response,
                "category": example.category
            })
        }
        return records
    }

    function createDataset() {
        validationMessage = ""
        var visibleName = clean(nameField.text)
        if (visibleName === "") {
            validationMessage = "Escribe un nombre para identificar el dataset."
            nameField.forceActiveFocus()
            return
        }

        // No obliga al usuario a pulsar "Agregar ejemplo" antes de crear.
        // Si dejó un borrador válido, se incorpora automáticamente.
        if (draftHasContent() && !addCurrentExample())
            return
        if (examplesModel.count === 0) {
            validationMessage = "Agrega al menos un ejemplo con instruction y response."
            instructionField.forceActiveFocus()
            return
        }
        if (!datasetController || !datasetController.crearDatasetManual) {
            validationMessage = "El administrador de datasets no está disponible."
            return
        }

        var result = datasetController.crearDatasetManual(
                    visibleName, recordsAsArray())
        if (!result || !result.ok) {
            validationMessage = result && result.mensaje
                    ? String(result.mensaje)
                    : "No se pudo crear el dataset."
            return
        }

        var created = result.dataset || ({})
        root.datasetCreated(created)
        resetForm()
        close()
    }

    parent: Overlay.overlay
    anchors.centerIn: Overlay.overlay
    width: Math.max(1, Math.min(1000, viewportWidth - 32))
    height: Math.max(1, Math.min(850, viewportHeight - 32))
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

    ListModel {
        id: examplesModel
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.contentMargin
        spacing: 13
        Accessible.name: "Crear mi dataset"
        Accessible.description: "Formulario para crear ejemplos de entrada y respuesta"

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Label {
                    Layout.fillWidth: true
                    text: "Crear mi dataset"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: root.width < 720 ? 21 : 26
                    wrapMode: Text.WordWrap
                    Accessible.role: Accessible.Heading
                }

                Label {
                    Layout.fillWidth: true
                    text: "La aplicación guardará tus ejemplos como JSONL compatible y lo añadirá a la biblioteca."
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }

            ToolButton {
                id: closeButton
                objectName: "datasetCreatorCloseButton"
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                text: "×"
                focusPolicy: Qt.StrongFocus
                Accessible.name: "Cerrar creador de dataset"
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
            id: creatorScroll
            objectName: "datasetCreatorScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: creatorScroll.availableWidth
                spacing: 13

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: contractContent.implicitHeight + 22
                    radius: 10
                    color: Style.Theme.info_fondo
                    border.width: 1
                    border.color: Style.Theme.info

                    ColumnLayout {
                        id: contractContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 11
                        spacing: 4

                        Label {
                            Layout.fillWidth: true
                            text: "Qué necesita cada ejemplo"
                            color: Style.Theme.info_texto
                            font.bold: true
                            font.pixelSize: 15
                            wrapMode: Text.WordWrap
                        }

                        Label {
                            Layout.fillWidth: true
                            text: "instruction es la entrada del encoder y response es la respuesta correcta que aprende el decoder. context aporta información adicional y category solo organiza. Los nombres de estos campos son el contrato del cargador de esta aplicación."
                            color: Style.Theme.texto_primario
                            font.pixelSize: 13
                            lineHeight: 1.15
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Label {
                        Layout.fillWidth: true
                        text: "Nombre del dataset  *"
                        color: Style.Theme.texto_primario
                        font.bold: true
                        font.pixelSize: 14
                    }

                    TextField {
                        id: nameField
                        objectName: "datasetCreatorNameField"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 43
                        maximumLength: 80
                        placeholderText: "Ejemplo: preguntas de ciencias"
                        color: Style.Theme.texto_primario
                        placeholderTextColor: Style.Theme.texto_terciario
                        selectByMouse: true
                        Accessible.name: "Nombre del dataset, obligatorio"
                        Accessible.description: "Máximo 80 caracteres"

                        background: Rectangle {
                            radius: 8
                            color: Style.Theme.surface
                            border.width: nameField.activeFocus ? 2 : 1
                            border.color: nameField.activeFocus
                                          ? Style.Theme.acento : Style.Theme.borde_suave
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: nameField.length + "/80 · Se usará para identificarlo en la biblioteca; el nombre del archivo se hará seguro automáticamente."
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: editorContent.implicitHeight + 24
                    radius: 11
                    color: Style.Theme.superficie_alterna
                    border.width: 1
                    border.color: Style.Theme.borde_medio

                    ColumnLayout {
                        id: editorContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true

                            Label {
                                Layout.fillWidth: true
                                text: "Nuevo ejemplo"
                                color: Style.Theme.texto_primario
                                font.bold: true
                                font.pixelSize: 17
                                Accessible.role: Accessible.Heading
                            }

                            Rectangle {
                                Layout.preferredWidth: requiredLegend.implicitWidth + 18
                                Layout.preferredHeight: 27
                                radius: height / 2
                                color: Style.Theme.aviso_fondo

                                Label {
                                    id: requiredLegend
                                    anchors.centerIn: parent
                                    text: "* obligatorio"
                                    color: Style.Theme.aviso_texto
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: "instruction  *  · Entrada para el encoder"
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: 13
                        }

                        TextArea {
                            id: instructionField
                            objectName: "datasetInstructionField"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 72
                            placeholderText: "Pregunta, orden o texto de entrada"
                            color: Style.Theme.texto_primario
                            placeholderTextColor: Style.Theme.texto_terciario
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            Accessible.name: "Instruction, entrada obligatoria"

                            background: Rectangle {
                                radius: 8
                                color: Style.Theme.surface
                                border.width: instructionField.activeFocus ? 2 : 1
                                border.color: instructionField.activeFocus
                                              ? Style.Theme.acento : Style.Theme.borde_suave
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: "context  · Opcional, se añade a la entrada"
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: 13
                        }

                        TextArea {
                            id: contextField
                            objectName: "datasetContextField"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 62
                            placeholderText: "Datos o fragmento que ayudan a responder (opcional)"
                            color: Style.Theme.texto_primario
                            placeholderTextColor: Style.Theme.texto_terciario
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            Accessible.name: "Context, información adicional opcional"

                            background: Rectangle {
                                radius: 8
                                color: Style.Theme.surface
                                border.width: contextField.activeFocus ? 2 : 1
                                border.color: contextField.activeFocus
                                              ? Style.Theme.acento : Style.Theme.borde_suave
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: "response  *  · Salida objetivo del decoder"
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: 13
                        }

                        TextArea {
                            id: responseField
                            objectName: "datasetResponseField"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 72
                            placeholderText: "Respuesta correcta que el modelo debe aprender"
                            color: Style.Theme.texto_primario
                            placeholderTextColor: Style.Theme.texto_terciario
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            Accessible.name: "Response, respuesta esperada obligatoria"

                            background: Rectangle {
                                radius: 8
                                color: Style.Theme.surface
                                border.width: responseField.activeFocus ? 2 : 1
                                border.color: responseField.activeFocus
                                              ? Style.Theme.acento : Style.Theme.borde_suave
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: "category  · Opcional, solo organiza"
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: 13
                        }

                        TextField {
                            id: categoryField
                            objectName: "datasetCategoryField"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42
                            placeholderText: "Ejemplo: traducción, resumen, preguntas"
                            color: Style.Theme.texto_primario
                            placeholderTextColor: Style.Theme.texto_terciario
                            selectByMouse: true
                            Accessible.name: "Category, etiqueta opcional"

                            background: Rectangle {
                                radius: 8
                                color: Style.Theme.surface
                                border.width: categoryField.activeFocus ? 2 : 1
                                border.color: categoryField.activeFocus
                                              ? Style.Theme.acento : Style.Theme.borde_suave
                            }
                        }

                        Button {
                            id: addExampleButton
                            objectName: "datasetAddExampleButton"
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredWidth: 180
                            Layout.preferredHeight: 40
                            text: "+ Agregar ejemplo"
                            focusPolicy: Qt.StrongFocus
                            Accessible.name: "Agregar ejemplo al dataset"
                            onClicked: root.addCurrentExample()

                            background: Rectangle {
                                radius: 9
                                color: addExampleButton.down
                                       ? Style.Theme.boton_presionado
                                       : (addExampleButton.hovered
                                          ? Style.Theme.acento_fondo : Style.Theme.boton)
                                border.width: addExampleButton.activeFocus ? 2 : 1
                                border.color: addExampleButton.activeFocus
                                              ? Style.Theme.acento : Style.Theme.borde_boton
                            }

                            contentItem: Text {
                                text: addExampleButton.text
                                color: Style.Theme.texto_primario
                                font.bold: true
                                font.pixelSize: 13
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Label {
                        id: exampleCountLabel
                        objectName: "datasetExampleCountLabel"
                        Layout.fillWidth: true
                        text: examplesModel.count
                              + (examplesModel.count === 1
                                 ? " ejemplo agregado" : " ejemplos agregados")
                        color: Style.Theme.texto_primario
                        font.bold: true
                        font.pixelSize: 16
                        Accessible.role: Accessible.Heading
                    }

                    Label {
                        visible: examplesModel.count > 0
                        text: "JSONL · 1 línea por ejemplo"
                        color: Style.Theme.acento_texto
                        font.pixelSize: 12
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: examplesModel.count === 0
                    text: "Todavía no agregaste ejemplos. Completa instruction y response; context y category pueden quedar vacíos."
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: examplesModel

                    delegate: Rectangle {
                        id: exampleCard
                        required property int index
                        required property string instruction
                        required property string context
                        required property string response
                        required property string category
                        Layout.fillWidth: true
                        Layout.preferredHeight: exampleContent.implicitHeight + 22
                        radius: 10
                        color: Style.Theme.surface
                        border.width: 1
                        border.color: Style.Theme.borde_medio

                        ColumnLayout {
                            id: exampleContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 11
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true

                                Label {
                                    Layout.fillWidth: true
                                    text: "Ejemplo " + (exampleCard.index + 1)
                                    color: Style.Theme.acento_texto
                                    font.bold: true
                                    font.pixelSize: 13
                                }

                                ToolButton {
                                    id: removeButton
                                    objectName: "datasetDeleteExampleButton_" + exampleCard.index
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 30
                                    text: "Eliminar"
                                    focusPolicy: Qt.StrongFocus
                                    Accessible.name: "Eliminar ejemplo " + (exampleCard.index + 1)
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Eliminar este ejemplo"
                                    onClicked: root.removeExample(exampleCard.index)

                                    background: Rectangle {
                                        radius: 7
                                        color: removeButton.down
                                               ? Style.Theme.error_fondo
                                               : (removeButton.hovered
                                                  ? Style.Theme.error_fondo : "transparent")
                                    }

                                    contentItem: Text {
                                        text: "×"
                                        color: Style.Theme.error_texto
                                        font.bold: true
                                        font.pixelSize: 22
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                text: "instruction: " + exampleCard.instruction
                                color: Style.Theme.texto_primario
                                font.pixelSize: 12
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                wrapMode: Text.WordWrap
                            }

                            Label {
                                Layout.fillWidth: true
                                visible: exampleCard.context !== ""
                                text: "context: " + exampleCard.context
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 12
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                wrapMode: Text.WordWrap
                            }

                            Label {
                                Layout.fillWidth: true
                                text: "response: " + exampleCard.response
                                color: Style.Theme.texto_primario
                                font.pixelSize: 12
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                wrapMode: Text.WordWrap
                            }

                            Label {
                                Layout.fillWidth: true
                                visible: exampleCard.category !== ""
                                text: "category: " + exampleCard.category
                                color: Style.Theme.acento_texto
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 2
                }
            }
        }

        Label {
            id: errorLabel
            objectName: "datasetCreatorErrorLabel"
            Layout.fillWidth: true
            visible: root.validationMessage !== ""
            text: root.validationMessage
            color: Style.Theme.error_texto
            font.bold: true
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Accessible.role: Accessible.AlertMessage
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                id: cancelButton
                objectName: "datasetCreatorCancelButton"
                Layout.preferredWidth: 125
                Layout.preferredHeight: 41
                text: "Cancelar"
                focusPolicy: Qt.StrongFocus
                Accessible.name: "Cancelar creación del dataset"
                onClicked: root.close()

                background: Rectangle {
                    radius: 9
                    color: cancelButton.down
                           ? Style.Theme.boton_presionado
                           : (cancelButton.hovered
                              ? Style.Theme.chip_fondo : Style.Theme.surface)
                    border.width: cancelButton.activeFocus ? 2 : 1
                    border.color: cancelButton.activeFocus
                                  ? Style.Theme.acento : Style.Theme.borde_suave
                }

                contentItem: Text {
                    text: cancelButton.text
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Label {
                Layout.fillWidth: true
                text: "Se requiere un nombre y al menos un par válido."
                color: Style.Theme.texto_secundario
                font.pixelSize: 11
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
            }

            Button {
                id: createButton
                objectName: "datasetCreateConfirmButton"
                Layout.preferredWidth: 185
                Layout.preferredHeight: 41
                text: "Crear dataset"
                enabled: root.datasetController
                         && !root.datasetController.ocupado
                         && root.clean(nameField.text) !== ""
                         && (examplesModel.count > 0 || root.draftHasContent())
                focusPolicy: Qt.StrongFocus
                Accessible.name: "Crear dataset y añadirlo a la biblioteca"
                onClicked: root.createDataset()

                background: Rectangle {
                    radius: 9
                    color: !createButton.enabled
                           ? Style.Theme.chip_fondo
                           : (createButton.down
                              ? Style.Theme.boton_presionado : Style.Theme.acento_fondo)
                    border.width: createButton.activeFocus ? 2 : 1
                    border.color: createButton.activeFocus
                                  ? Style.Theme.acento : Style.Theme.borde_boton
                }

                contentItem: Text {
                    text: createButton.text
                    color: createButton.enabled
                           ? Style.Theme.acento_texto : Style.Theme.texto_terciario
                    font.bold: true
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    onOpened: Qt.callLater(function() { nameField.forceActiveFocus() })
}
