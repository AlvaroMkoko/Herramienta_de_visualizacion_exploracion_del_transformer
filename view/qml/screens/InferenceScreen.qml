pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root

    property var controller: mainViewModel.inferenceController
    property var modelInfo: mainViewModel.modeloActualInfo
    property string textoGenerado: ""
    property string mensajeEstado: "Listo para generar"
    property bool mensajeEsError: false
    property int tokensGenerados: 0
    readonly property int maxTokensPermitidos: Math.max(
        1,
        Math.min(
            512,
            Number(mainViewModel.modeloActualInfo.longitud_maxima_secuencia || 512)
        )
    )

    function ajustarMaxTokens() {
        if (maxTokens.value > root.maxTokensPermitidos)
            maxTokens.value = root.maxTokensPermitidos
        else if (maxTokens.value < 1)
            maxTokens.value = 1
    }

    onMaxTokensPermitidosChanged: ajustarMaxTokens()
    Component.onCompleted: ajustarMaxTokens()

    function datoModelo(nombres, alternativo) {
        if (!root.modelInfo)
            return alternativo
        for (var i = 0; i < nombres.length; ++i) {
            var valor = root.modelInfo[nombres[i]]
            if (valor !== undefined && valor !== null && valor !== "")
                return valor
        }
        return alternativo
    }

    function iniciarGeneracion() {
        var prompt = campoPrompt.text.trim()
        if (!root.controller) {
            root.mensajeEstado = "No hay un modelo activo para generar texto."
            root.mensajeEsError = true
            return
        }
        if (prompt.length === 0) {
            root.mensajeEstado = "Escribe un prompt antes de iniciar."
            root.mensajeEsError = true
            campoPrompt.forceActiveFocus()
            return
        }

        root.textoGenerado = ""
        root.tokensGenerados = 0
        root.mensajeEstado = "Generando…"
        root.mensajeEsError = false
        root.controller.iniciar_generacion_ui(
                    prompt,
                    maxTokens.value,
                    temperatura.value,
                    usarTopK.checked ? topK.value : 0,
                    usarTopP.checked ? topP.value : 1.0,
                    muestreoCodicioso.checked)
    }

    Connections {
        target: root.controller
        ignoreUnknownSignals: true

        function onToken_generado(paso) {
            if (paso && paso.texto_parcial !== undefined)
                root.textoGenerado = String(paso.texto_parcial)
            root.tokensGenerados += 1
            root.mensajeEstado = "Generando token " + root.tokensGenerados + "…"
            root.mensajeEsError = false
        }

        function onGeneracion_completa(texto) {
            root.textoGenerado = texto === undefined || texto === null
                    ? root.textoGenerado : String(texto)
            root.mensajeEstado = "Generación completa · "
                    + root.tokensGenerados + " tokens"
            root.mensajeEsError = false
        }

        function onGeneracion_cancelada(texto) {
            root.textoGenerado = texto === undefined || texto === null
                    ? root.textoGenerado : String(texto)
            root.mensajeEstado = "Generación detenida · se conservó el resultado parcial"
            root.mensajeEsError = false
        }

        function onError(mensaje) {
            root.mensajeEstado = "No se pudo generar: " + String(mensaje)
            root.mensajeEsError = true
        }
    }

    RowLayout {
        id: cabecera
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 24 * root.sx
        height: 68 * root.sy
        spacing: 16 * root.sx

        BotonPrincipal {
            Layout.preferredWidth: 210 * root.sx
            Layout.preferredHeight: 44 * root.sy
            text: "↶ Volver"
            size_text: 0.28
            onClicked: {
                if (root.controller && root.controller.estaGenerando)
                    root.controller.detener()
                root.stackView.pop()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1 * root.sy

            Text {
                text: "Inferencia con el modelo activo"
                color: Style.Theme.texto_primario
                font.bold: true
                font.pixelSize: 27 * Math.min(root.sx, root.sy)
            }

            Text {
                text: "Prueba el Transformer y observa su respuesta token a token"
                color: Style.Theme.texto_secundario
                font.pixelSize: 14 * Math.min(root.sx, root.sy)
            }
        }

        Rectangle {
            Layout.preferredWidth: Math.max(220 * root.sx, textoEstado.implicitWidth + 28 * root.sx)
            Layout.preferredHeight: 36 * root.sy
            radius: 18 * root.sy
            color: root.mensajeEsError ? "#FEE2E2"
                                         : (root.controller && root.controller.estaGenerando
                                            ? "#DBEAFE" : "#DCFCE7")
            border.color: root.mensajeEsError ? "#FCA5A5"
                                              : (root.controller && root.controller.estaGenerando
                                                 ? "#93C5FD" : "#86EFAC")

            Text {
                id: textoEstado
                anchors.centerIn: parent
                width: parent.width - 20 * root.sx
                text: root.mensajeEstado
                color: root.mensajeEsError ? "#991B1B"
                                            : (root.controller && root.controller.estaGenerando
                                               ? "#1E40AF" : "#166534")
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 13 * Math.min(root.sx, root.sy)
            }
        }
    }

    RowLayout {
        anchors.top: cabecera.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 16 * root.sy
        anchors.bottomMargin: 26 * root.sy
        anchors.leftMargin: 30 * root.sx
        anchors.rightMargin: 30 * root.sx
        spacing: 20 * root.sx

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 900 * root.sx
            spacing: 16 * root.sy

            RectanglePrincipal {
                Layout.fillWidth: true
                Layout.preferredHeight: 250 * root.sy
                sx: root.sx
                sy: root.sy

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18 * root.sx
                    spacing: 9 * root.sy

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: "Prompt"
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: 18 * Math.min(root.sx, root.sy)
                        }

                        Text {
                            text: campoPrompt.length + " caracteres"
                            color: Style.Theme.texto_secundario
                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                        }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        TextArea {
                            id: campoPrompt
                            placeholderText: "Escribe el inicio del texto que quieres completar…"
                            text: ""
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            enabled: !root.controller || !root.controller.estaGenerando
                            color: Style.Theme.texto_primario
                            placeholderTextColor: "#9CA3AF"
                            font.pixelSize: 15 * Math.min(root.sx, root.sy)
                            leftPadding: 13 * root.sx
                            rightPadding: 13 * root.sx
                            topPadding: 11 * root.sy
                            bottomPadding: 11 * root.sy
                            background: Rectangle {
                                color: "#FAFAFC"
                                radius: 8 * root.sx
                                border.color: campoPrompt.activeFocus ? "#8B5CF6" : "#D1D5DB"
                                border.width: campoPrompt.activeFocus ? 2 : 1
                            }
                        }
                    }
                }
            }

            RectanglePrincipal {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sx: root.sx
                sy: root.sy

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18 * root.sx
                    spacing: 9 * root.sy

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: "Texto generado"
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: 18 * Math.min(root.sx, root.sy)
                        }

                        Text {
                            text: root.tokensGenerados + (root.tokensGenerados === 1 ? " token" : " tokens")
                            color: "#6D28D9"
                            font.bold: true
                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                        }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        TextArea {
                            id: resultado
                            text: root.textoGenerado
                            placeholderText: "La respuesta aparecerá aquí mientras se genera."
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            color: Style.Theme.texto_primario
                            placeholderTextColor: "#9CA3AF"
                            font.pixelSize: 16 * Math.min(root.sx, root.sy)
                            leftPadding: 14 * root.sx
                            rightPadding: 14 * root.sx
                            topPadding: 13 * root.sy
                            bottomPadding: 13 * root.sy
                            background: Rectangle {
                                color: "#FAFAFC"
                                radius: 8 * root.sx
                                border.color: "#D1D5DB"
                            }
                            onTextChanged: cursorPosition = length
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.preferredWidth: 460 * root.sx
            Layout.fillHeight: true
            spacing: 16 * root.sy

            RectanglePrincipal {
                Layout.fillWidth: true
                Layout.preferredHeight: 160 * root.sy
                sx: root.sx
                sy: root.sy

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16 * root.sx
                    spacing: 9 * root.sy

                    Text {
                        Layout.fillWidth: true
                        text: "Modelo activo"
                        color: Style.Theme.texto_primario
                        font.bold: true
                        font.pixelSize: 17 * Math.min(root.sx, root.sy)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8 * root.sx

                        Repeater {
                            model: [
                                { etiqueta: "CAPAS", valor: root.datoModelo(["num_capas", "encoder_layers"], "—") },
                                { etiqueta: "CABEZAS", valor: root.datoModelo(["num_cabezas"], "—") },
                                { etiqueta: "DIMENSIÓN", valor: root.datoModelo(["dimension_modelo"], "—") }
                            ]

                            delegate: Rectangle {
                                id: metrica
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 8 * root.sx
                                color: "#F5F3FF"
                                border.color: "#DDD6FE"

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 3 * root.sy

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: metrica.modelData.valor
                                        color: "#5B21B6"
                                        font.bold: true
                                        font.pixelSize: 22 * Math.min(root.sx, root.sy)
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: metrica.modelData.etiqueta
                                        color: Style.Theme.texto_secundario
                                        font.bold: true
                                        font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RectanglePrincipal {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sx: root.sx
                sy: root.sy

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18 * root.sx
                    spacing: 10 * root.sy

                    Text {
                        Layout.fillWidth: true
                        text: "Parámetros de generación"
                        color: Style.Theme.texto_primario
                        font.bold: true
                        font.pixelSize: 18 * Math.min(root.sx, root.sy)
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: "#E5E7EB"
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2 * root.sy

                            Text {
                                text: "Máximo de tokens nuevos"
                                color: Style.Theme.texto_primario
                                font.pixelSize: 14 * Math.min(root.sx, root.sy)
                            }
                            Text {
                                text: "Límite de longitud de la respuesta"
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 11 * Math.min(root.sx, root.sy)
                            }
                        }

                        SpinBox {
                            id: maxTokens
                            Layout.preferredWidth: 116 * root.sx
                            from: 1
                            to: root.maxTokensPermitidos
                            value: 100
                            editable: true
                            enabled: !root.controller || !root.controller.estaGenerando
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: "Temperatura"
                            color: Style.Theme.texto_primario
                            font.pixelSize: 14 * Math.min(root.sx, root.sy)
                        }
                        Text {
                            text: temperatura.value.toFixed(2)
                            color: "#6D28D9"
                            font.bold: true
                            font.pixelSize: 13 * Math.min(root.sx, root.sy)
                        }
                    }

                    Slider {
                        id: temperatura
                        Layout.fillWidth: true
                        from: 0.1
                        to: 2.0
                        stepSize: 0.05
                        value: 1.0
                        enabled: (!root.controller || !root.controller.estaGenerando)
                                 && !muestreoCodicioso.checked
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        CheckBox {
                            id: usarTopK
                            Layout.fillWidth: true
                            text: "Usar Top-K"
                            checked: true
                            enabled: (!root.controller || !root.controller.estaGenerando)
                                     && !muestreoCodicioso.checked
                        }
                        SpinBox {
                            id: topK
                            Layout.preferredWidth: 116 * root.sx
                            from: 1
                            to: 500
                            value: 50
                            editable: true
                            enabled: usarTopK.checked && usarTopK.enabled
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        CheckBox {
                            id: usarTopP
                            Layout.fillWidth: true
                            text: "Usar Top-P"
                            checked: true
                            enabled: (!root.controller || !root.controller.estaGenerando)
                                     && !muestreoCodicioso.checked
                        }
                        Text {
                            text: topP.value.toFixed(2)
                            color: "#6D28D9"
                            font.bold: true
                            font.pixelSize: 13 * Math.min(root.sx, root.sy)
                        }
                    }

                    Slider {
                        id: topP
                        Layout.fillWidth: true
                        from: 0.05
                        to: 0.99
                        stepSize: 0.01
                        value: 0.90
                        enabled: usarTopP.checked && usarTopP.enabled
                    }

                    CheckBox {
                        id: muestreoCodicioso
                        Layout.fillWidth: true
                        text: "Muestreo codicioso (elegir siempre el token más probable)"
                        checked: false
                        enabled: !root.controller || !root.controller.estaGenerando
                    }

                    Item { Layout.fillHeight: true }

                    BotonPrincipal {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52 * root.sy
                        text: "▶ Generar texto"
                        size_text: 0.25
                        enabled: root.controller && !root.controller.estaGenerando
                                 && campoPrompt.text.trim().length > 0
                        opacity: enabled ? 1.0 : 0.48
                        onClicked: root.iniciarGeneracion()
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 9 * root.sx

                        BotonPrincipal {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 46 * root.sy
                            text: root.controller && root.controller.estaPausado
                                  ? "▶ Reanudar" : "⏸ Pausar"
                            size_text: 0.24
                            enabled: root.controller && root.controller.estaGenerando
                            opacity: enabled ? 1.0 : 0.45
                            onClicked: {
                                if (root.controller.estaPausado)
                                    root.controller.reanudar()
                                else
                                    root.controller.pausar()
                            }
                        }

                        BotonPrincipal {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 46 * root.sy
                            text: "■ Detener"
                            size_text: 0.24
                            enabled: root.controller && root.controller.estaGenerando
                            opacity: enabled ? 1.0 : 0.45
                            onClicked: root.controller.detener()
                        }
                    }
                }
            }
        }
    }
}
