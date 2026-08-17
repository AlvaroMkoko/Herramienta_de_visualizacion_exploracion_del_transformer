pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root

    property var controller: mainViewModel.comparisonController
    property var biblioteca: mainViewModel.modelLibraryController
    property var seleccionadoA: null
    property var seleccionadoB: null
    property string mensajeEstado: "Selecciona dos modelos entrenados para comenzar."
    property bool mensajeEsError: false

    property string textoA: ""
    property string textoB: ""
    property int tokensA: 0
    property int tokensB: 0
    property double inicioA: 0
    property double inicioB: 0
    property int duracionA: 0
    property int duracionB: 0
    property string estadoA: "Listo"
    property string estadoB: "Listo"

    readonly property bool modelosListos: controller && controller.modelosListos
    readonly property bool cargando: controller && controller.cargando
    readonly property var controladorA: controller ? controller.controladorA : null
    readonly property var controladorB: controller ? controller.controladorB : null
    readonly property int maxTokensPermitidos: controller
            ? controller.maxTokensPermitidos : 512

    function valor(item, nombres, alternativo) {
        if (item === undefined || item === null)
            return alternativo
        for (var i = 0; i < nombres.length; ++i) {
            var candidato = item[nombres[i]]
            if (candidato !== undefined && candidato !== null && candidato !== "")
                return candidato
        }
        return alternativo
    }

    function ruta(item) {
        return String(valor(item, ["ruta", "path"], ""))
    }

    function nombre(item) {
        return String(valor(item, ["nombre", "name", "archivo"], "Modelo sin nombre"))
    }

    function resumen(item) {
        var preparado = valor(item, ["resumen"], "")
        if (preparado !== "")
            return preparado
        return "L" + valor(item, ["num_capas", "capas"], "—")
                + " · H" + valor(item, ["num_cabezas", "cabezas"], "—")
                + " · d=" + valor(item, ["dimension_modelo", "dimension"], "—")
                + " · FFN=" + valor(item, ["dimension_ff", "dimensionFF"], "—")
    }

    function numeroLegible(valorNumerico) {
        var numero = Number(valorNumerico)
        if (!numero || isNaN(numero))
            return "—"
        if (numero >= 1000000000)
            return (numero / 1000000000).toFixed(2) + " mil M"
        if (numero >= 1000000)
            return (numero / 1000000).toFixed(2) + " M"
        if (numero >= 1000)
            return (numero / 1000).toFixed(1) + " mil"
        return String(numero)
    }

    function estaSeleccionado(item) {
        var rutaItem = ruta(item)
        return (seleccionadoA && ruta(seleccionadoA) === rutaItem)
                || (seleccionadoB && ruta(seleccionadoB) === rutaItem)
    }

    function etiquetaSeleccion(item) {
        var rutaItem = ruta(item)
        if (seleccionadoA && ruta(seleccionadoA) === rutaItem)
            return "Modelo A"
        if (seleccionadoB && ruta(seleccionadoB) === rutaItem)
            return "Modelo B"
        return ""
    }

    function alternarSeleccion(item) {
        var rutaItem = ruta(item)
        if (seleccionadoA && ruta(seleccionadoA) === rutaItem) {
            seleccionadoA = seleccionadoB
            seleccionadoB = null
        } else if (seleccionadoB && ruta(seleccionadoB) === rutaItem) {
            seleccionadoB = null
        } else if (!seleccionadoA) {
            seleccionadoA = item
        } else if (!seleccionadoB) {
            seleccionadoB = item
        } else {
            seleccionadoB = item
        }
        mensajeEstado = seleccionadoA && seleccionadoB
                ? "Los dos modelos están seleccionados."
                : "Selecciona " + (seleccionadoA ? "un modelo más." : "dos modelos.")
        mensajeEsError = false
    }

    function cargarSeleccion() {
        if (!seleccionadoA || !seleccionadoB) {
            mensajeEstado = "Debes seleccionar dos modelos diferentes."
            mensajeEsError = true
            return
        }
        mensajeEstado = "Cargando ambos modelos en memoria…"
        mensajeEsError = false
        textoA = ""
        textoB = ""
        tokensA = 0
        tokensB = 0
        duracionA = 0
        duracionB = 0
        estadoA = "Listo"
        estadoB = "Listo"
        controller.cargarModelos(ruta(seleccionadoA), ruta(seleccionadoB))
    }

    function iniciarComparacion() {
        var prompt = campoPrompt.text.trim()
        if (prompt.length === 0) {
            mensajeEstado = "Escribe un prompt antes de generar."
            mensajeEsError = true
            campoPrompt.forceActiveFocus()
            return
        }
        textoA = ""
        textoB = ""
        tokensA = 0
        tokensB = 0
        duracionA = 0
        duracionB = 0
        inicioA = Date.now()
        inicioB = inicioA
        estadoA = "Preparando generación…"
        estadoB = "Preparando generación…"
        mensajeEstado = "Generando con los mismos parámetros…"
        mensajeEsError = false
        controller.iniciarGeneracion(
                    prompt,
                    maxTokens.value,
                    temperatura.value,
                    usarTopK.checked ? topK.value : 0,
                    usarTopP.checked ? topP.value : 1.0,
                    muestreoCodicioso.checked)
    }

    function volver() {
        if (controller)
            controller.liberarModelos()
        stackView.pop()
    }

    Component.onCompleted: {
        if (controller)
            controller.liberarModelos()
        if (biblioteca)
            biblioteca.refrescar()
        if (maxTokens.value > maxTokensPermitidos)
            maxTokens.value = maxTokensPermitidos
    }

    Component.onDestruction: {
        if (controller)
            controller.liberarModelos()
    }

    onMaxTokensPermitidosChanged: {
        if (maxTokens.value > maxTokensPermitidos)
            maxTokens.value = maxTokensPermitidos
    }

    Connections {
        target: root.controller
        ignoreUnknownSignals: true

        function onCargaCompleta(mensaje) {
            root.mensajeEstado = String(mensaje)
            root.mensajeEsError = false
        }

        function onError(mensaje) {
            root.mensajeEstado = String(mensaje)
            root.mensajeEsError = true
            if (root.estadoA.indexOf("Preparando") === 0)
                root.estadoA = "No iniciada"
            if (root.estadoB.indexOf("Preparando") === 0)
                root.estadoB = "No iniciada"
        }
    }

    Connections {
        target: root.biblioteca
        ignoreUnknownSignals: true
        function onError(mensaje) {
            root.mensajeEstado = String(mensaje)
            root.mensajeEsError = true
        }
    }

    Connections {
        target: root.controladorA
        ignoreUnknownSignals: true

        function onToken_generado(paso) {
            if (paso && paso.texto_parcial !== undefined)
                root.textoA = String(paso.texto_parcial)
            root.tokensA += 1
            root.estadoA = "Generando token " + root.tokensA + "…"
        }
        function onGeneracion_completa(texto) {
            if (texto !== undefined && texto !== null)
                root.textoA = String(texto)
            root.duracionA = Math.max(0, Date.now() - root.inicioA)
            root.estadoA = "Completada"
            root.mensajeEstado = root.controladorB && root.controladorB.estaGenerando
                    ? "Modelo A terminó; Modelo B continúa generando…"
                    : "Comparación finalizada. Revisa ambas respuestas."
        }
        function onGeneracion_cancelada(texto) {
            if (texto !== undefined && texto !== null)
                root.textoA = String(texto)
            root.duracionA = Math.max(0, Date.now() - root.inicioA)
            root.estadoA = "Detenida"
        }
        function onError(mensaje) {
            root.estadoA = "Error: " + String(mensaje)
            root.mensajeEstado = "Modelo A: " + String(mensaje)
            root.mensajeEsError = true
        }
    }

    Connections {
        target: root.controladorB
        ignoreUnknownSignals: true

        function onToken_generado(paso) {
            if (paso && paso.texto_parcial !== undefined)
                root.textoB = String(paso.texto_parcial)
            root.tokensB += 1
            root.estadoB = "Generando token " + root.tokensB + "…"
        }
        function onGeneracion_completa(texto) {
            if (texto !== undefined && texto !== null)
                root.textoB = String(texto)
            root.duracionB = Math.max(0, Date.now() - root.inicioB)
            root.estadoB = "Completada"
            root.mensajeEstado = root.controladorA && root.controladorA.estaGenerando
                    ? "Modelo B terminó; Modelo A continúa generando…"
                    : "Comparación finalizada. Revisa ambas respuestas."
        }
        function onGeneracion_cancelada(texto) {
            if (texto !== undefined && texto !== null)
                root.textoB = String(texto)
            root.duracionB = Math.max(0, Date.now() - root.inicioB)
            root.estadoB = "Detenida"
        }
        function onError(mensaje) {
            root.estadoB = "Error: " + String(mensaje)
            root.mensajeEstado = "Modelo B: " + String(mensaje)
            root.mensajeEsError = true
        }
    }

    RowLayout {
        id: cabecera
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 24 * root.sx
        height: 72 * root.sy
        spacing: 14 * root.sx

        BotonPrincipal {
            Layout.preferredWidth: 205 * root.sx
            Layout.preferredHeight: 44 * root.sy
            text: "↶ Volver al inicio"
            size_text: 0.27
            onClicked: root.volver()
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1 * root.sy
            Text {
                text: root.modelosListos ? "Comparación de generación" : "Elige dos modelos"
                color: Style.Theme.texto_primario
                font.bold: true
                font.pixelSize: 27 * Math.min(root.sx, root.sy)
            }
            Text {
                text: root.modelosListos
                      ? "Mismo prompt y muestreo; dos resultados independientes."
                      : "Selecciona modelos ya entrenados desde tu biblioteca local."
                color: Style.Theme.texto_secundario
                font.pixelSize: 14 * Math.min(root.sx, root.sy)
            }
        }

        Rectangle {
            Layout.preferredWidth: Math.min(610 * root.sx, mensajeCabecera.implicitWidth + 36 * root.sx)
            Layout.preferredHeight: 38 * root.sy
            radius: height / 2
            color: root.mensajeEsError ? "#FEE2E2" : "#EDE9FE"
            border.color: root.mensajeEsError ? "#FCA5A5" : "#C4B5FD"
            Text {
                id: mensajeCabecera
                anchors.centerIn: parent
                text: root.mensajeEstado
                color: root.mensajeEsError ? "#991B1B" : "#5B21B6"
                font.pixelSize: 12 * Math.min(root.sx, root.sy)
                elide: Text.ElideRight
                width: Math.min(570 * root.sx, implicitWidth)
            }
        }
    }

    Item {
        id: vistaSeleccion
        visible: !root.modelosListos
        anchors.top: cabecera.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28 * root.sx

        RectanglePrincipal {
            id: panelLista
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: panelSeleccion.top
            anchors.bottomMargin: 16 * root.sy
            sx: root.sx
            sy: root.sy

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18 * root.sx
                spacing: 12 * root.sy

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40 * root.sy
                    Text {
                        Layout.fillWidth: true
                        text: "Biblioteca de modelos"
                        color: Style.Theme.texto_primario
                        font.bold: true
                        font.pixelSize: 19 * Math.min(root.sx, root.sy)
                    }
                    Text {
                        text: root.biblioteca ? root.biblioteca.modelos.length + " disponibles" : "0 disponibles"
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 13 * Math.min(root.sx, root.sy)
                    }
                    BotonPrincipal {
                        Layout.preferredWidth: 135 * root.sx
                        Layout.preferredHeight: 36 * root.sy
                        text: "Actualizar"
                        size_text: 0.27
                        enabled: !root.cargando && root.biblioteca
                        onClicked: root.biblioteca.refrescar()
                    }
                }

                ListView {
                    id: listaModelos
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 10 * root.sy
                    model: root.biblioteca ? root.biblioteca.modelos : []
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        id: tarjetaModelo
                        required property var modelData
                        required property int index
                        readonly property bool utilizable: Boolean(modelData.compatible)
                                && Boolean(modelData.inferencia)
                        readonly property bool elegida: root.estaSeleccionado(modelData)

                        width: listaModelos.width - 10 * root.sx
                        height: 126 * root.sy
                        radius: 10 * root.sx
                        color: elegida ? "#F5F3FF" : "#FFFFFF"
                        border.width: elegida ? 2 : 1
                        border.color: elegida ? "#7C3AED" : "#D1D5DB"
                        opacity: utilizable ? 1.0 : 0.58

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 15 * root.sx
                            spacing: 18 * root.sx

                            Rectangle {
                                Layout.preferredWidth: 48 * root.sx
                                Layout.preferredHeight: 48 * root.sy
                                radius: 12 * root.sx
                                color: tarjetaModelo.elegida ? "#7C3AED" : "#EDE9FE"
                                Text {
                                    anchors.centerIn: parent
                                    text: tarjetaModelo.elegida
                                          ? root.etiquetaSeleccion(tarjetaModelo.modelData).slice(-1)
                                          : "T"
                                    color: tarjetaModelo.elegida ? "white" : "#6D28D9"
                                    font.bold: true
                                    font.pixelSize: 20 * Math.min(root.sx, root.sy)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5 * root.sy
                                Text {
                                    Layout.fillWidth: true
                                    text: root.nombre(tarjetaModelo.modelData)
                                    color: Style.Theme.texto_primario
                                    font.bold: true
                                    font.pixelSize: 17 * Math.min(root.sx, root.sy)
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.resumen(tarjetaModelo.modelData)
                                    color: Style.Theme.texto_secundario
                                    font.pixelSize: 13 * Math.min(root.sx, root.sy)
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Parámetros: " + root.numeroLegible(root.valor(tarjetaModelo.modelData, ["parametros", "parametros_totales"], 0))
                                          + "   ·   encoding: " + root.valor(tarjetaModelo.modelData, ["encoding"], "desconocido")
                                          + "   ·   época: " + root.valor(tarjetaModelo.modelData, ["epoca"], "—")
                                    color: "#7C3AED"
                                    font.pixelSize: 12 * Math.min(root.sx, root.sy)
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                Layout.preferredWidth: 220 * root.sx
                                text: tarjetaModelo.utilizable
                                      ? (tarjetaModelo.elegida
                                         ? root.etiquetaSeleccion(tarjetaModelo.modelData)
                                         : "Listo para inferencia")
                                      : "No disponible para inferencia"
                                color: tarjetaModelo.utilizable
                                       ? (tarjetaModelo.elegida ? "#6D28D9" : "#166534")
                                       : "#991B1B"
                                font.bold: true
                                horizontalAlignment: Text.AlignRight
                                font.pixelSize: 12 * Math.min(root.sx, root.sy)
                            }

                            BotonPrincipal {
                                Layout.preferredWidth: 150 * root.sx
                                Layout.preferredHeight: 42 * root.sy
                                text: tarjetaModelo.elegida ? "Quitar" : "Seleccionar"
                                size_text: 0.25
                                enabled: tarjetaModelo.utilizable && !root.cargando
                                opacity: enabled ? 1.0 : 0.45
                                onClicked: root.alternarSeleccion(tarjetaModelo.modelData)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: listaModelos.count === 0 && !root.cargando
                        text: "Aún no hay modelos en la biblioteca.\nEntrena o importa dos modelos y vuelve a actualizar."
                        color: Style.Theme.texto_secundario
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 17 * Math.min(root.sx, root.sy)
                    }
                }
            }
        }

        RectanglePrincipal {
            id: panelSeleccion
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 148 * root.sy
            sx: root.sx
            sy: root.sy

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16 * root.sx
                spacing: 14 * root.sx

                Repeater {
                    model: [
                        { etiqueta: "MODELO A", item: root.seleccionadoA },
                        { etiqueta: "MODELO B", item: root.seleccionadoB }
                    ]
                    delegate: Rectangle {
                        id: resumenSeleccionado
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 9 * root.sx
                        color: modelData.item ? "#F5F3FF" : "#F9FAFB"
                        border.color: modelData.item ? "#C4B5FD" : "#D1D5DB"
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12 * root.sx
                            spacing: 5 * root.sy
                            Text {
                                text: resumenSeleccionado.modelData.etiqueta
                                color: "#7C3AED"
                                font.bold: true
                                font.pixelSize: 11 * Math.min(root.sx, root.sy)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: resumenSeleccionado.modelData.item
                                      ? root.nombre(resumenSeleccionado.modelData.item)
                                      : "Sin seleccionar"
                                color: Style.Theme.texto_primario
                                font.bold: true
                                font.pixelSize: 15 * Math.min(root.sx, root.sy)
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: resumenSeleccionado.modelData.item
                                      ? root.resumen(resumenSeleccionado.modelData.item)
                                      : "Elige una tarjeta de la lista"
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 12 * Math.min(root.sx, root.sy)
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                BotonPrincipal {
                    Layout.preferredWidth: 245 * root.sx
                    Layout.preferredHeight: 52 * root.sy
                    text: root.cargando ? "Cargando modelos…" : "Comparar modelos  →"
                    size_text: 0.24
                    enabled: root.seleccionadoA && root.seleccionadoB && !root.cargando
                    opacity: enabled ? 1.0 : 0.48
                    onClicked: root.cargarSeleccion()
                }
            }
        }

        BusyIndicator {
            anchors.centerIn: parent
            width: 72 * root.sx
            height: 72 * root.sy
            running: root.cargando
            visible: running
            z: 20
        }
    }

    Item {
        id: vistaComparacion
        visible: root.modelosListos
        anchors.top: cabecera.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28 * root.sx

        RectanglePrincipal {
            id: panelPrompt
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 222 * root.sy
            sx: root.sx
            sy: root.sy

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16 * root.sx
                spacing: 10 * root.sy

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "PROMPT Y PARÁMETROS COMPARTIDOS"
                        color: "#6D28D9"
                        font.bold: true
                        font.pixelSize: 13 * Math.min(root.sx, root.sy)
                    }
                    BotonPrincipal {
                        Layout.preferredWidth: 170 * root.sx
                        Layout.preferredHeight: 34 * root.sy
                        text: "Cambiar modelos"
                        size_text: 0.25
                        enabled: !root.controller.estaGenerando
                        onClicked: {
                            root.controller.liberarModelos()
                            root.mensajeEstado = "Selecciona dos modelos entrenados para comenzar."
                            root.mensajeEsError = false
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 15 * root.sx

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        TextArea {
                            id: campoPrompt
                            placeholderText: "Escribe el texto inicial que recibirán ambos modelos…"
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            font.pixelSize: 15 * Math.min(root.sx, root.sy)
                            color: Style.Theme.texto_primario
                            enabled: !root.controller.estaGenerando
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 650 * root.sx
                        Layout.fillHeight: true
                        spacing: 4 * root.sy

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Tokens nuevos"; color: Style.Theme.texto_secundario }
                            SpinBox {
                                id: maxTokens
                                Layout.preferredWidth: 110 * root.sx
                                from: 1
                                to: root.maxTokensPermitidos
                                value: Math.min(100, root.maxTokensPermitidos)
                                editable: true
                                enabled: !root.controller.estaGenerando
                            }
                            Text { text: "Temperatura"; color: Style.Theme.texto_secundario }
                            Slider {
                                id: temperatura
                                Layout.fillWidth: true
                                from: 0.1
                                to: 2.0
                                stepSize: 0.05
                                value: 1.0
                                enabled: !root.controller.estaGenerando && !muestreoCodicioso.checked
                            }
                            Text {
                                text: temperatura.value.toFixed(2)
                                color: "#6D28D9"
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            CheckBox {
                                id: usarTopK
                                text: "Top-K"
                                checked: true
                                enabled: !root.controller.estaGenerando && !muestreoCodicioso.checked
                            }
                            SpinBox {
                                id: topK
                                Layout.preferredWidth: 100 * root.sx
                                from: 1
                                to: 100
                                value: 50
                                editable: true
                                enabled: usarTopK.checked && usarTopK.enabled
                            }
                            CheckBox {
                                id: usarTopP
                                text: "Top-P"
                                checked: true
                                enabled: !root.controller.estaGenerando && !muestreoCodicioso.checked
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
                            Text {
                                text: topP.value.toFixed(2)
                                color: "#6D28D9"
                                font.bold: true
                            }
                            CheckBox {
                                id: muestreoCodicioso
                                text: "Codicioso"
                                checked: false
                                enabled: !root.controller.estaGenerando
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Item { Layout.fillWidth: true }
                            BotonPrincipal {
                                Layout.preferredWidth: 225 * root.sx
                                Layout.preferredHeight: 45 * root.sy
                                text: "▶ Generar ambos"
                                size_text: 0.25
                                enabled: !root.controller.estaGenerando
                                         && campoPrompt.text.trim().length > 0
                                opacity: enabled ? 1.0 : 0.48
                                onClicked: root.iniciarComparacion()
                            }
                            BotonPrincipal {
                                Layout.preferredWidth: 130 * root.sx
                                Layout.preferredHeight: 45 * root.sy
                                text: root.controladorA && root.controladorA.estaPausado
                                      ? "▶ Reanudar" : "⏸ Pausar"
                                size_text: 0.24
                                enabled: root.controller.estaGenerando
                                opacity: enabled ? 1.0 : 0.45
                                onClicked: {
                                    if (root.controladorA && root.controladorA.estaPausado)
                                        root.controller.reanudar()
                                    else
                                        root.controller.pausar()
                                }
                            }
                            BotonPrincipal {
                                Layout.preferredWidth: 120 * root.sx
                                Layout.preferredHeight: 45 * root.sy
                                text: "■ Detener"
                                size_text: 0.24
                                enabled: root.controller.estaGenerando
                                opacity: enabled ? 1.0 : 0.45
                                onClicked: root.controller.detener()
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            anchors.top: panelPrompt.bottom
            anchors.topMargin: 16 * root.sy
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 16 * root.sx

            Repeater {
                model: [
                    {
                        etiqueta: "MODELO A",
                        info: root.controller ? root.controller.modeloAInfo : {},
                        texto: root.textoA,
                        tokens: root.tokensA,
                        duracion: root.duracionA,
                        estado: root.estadoA,
                        acento: "#7C3AED",
                        fondo: "#F5F3FF"
                    },
                    {
                        etiqueta: "MODELO B",
                        info: root.controller ? root.controller.modeloBInfo : {},
                        texto: root.textoB,
                        tokens: root.tokensB,
                        duracion: root.duracionB,
                        estado: root.estadoB,
                        acento: "#2563EB",
                        fondo: "#EFF6FF"
                    }
                ]

                delegate: RectanglePrincipal {
                    id: resultadoModelo
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sx: root.sx
                    sy: root.sy

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 17 * root.sx
                        spacing: 9 * root.sy

                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle {
                                Layout.preferredWidth: 92 * root.sx
                                Layout.preferredHeight: 27 * root.sy
                                radius: height / 2
                                color: resultadoModelo.modelData.fondo
                                Text {
                                    anchors.centerIn: parent
                                    text: resultadoModelo.modelData.etiqueta
                                    color: resultadoModelo.modelData.acento
                                    font.bold: true
                                    font.pixelSize: 11 * Math.min(root.sx, root.sy)
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.nombre(resultadoModelo.modelData.info)
                                color: Style.Theme.texto_primario
                                font.bold: true
                                font.pixelSize: 19 * Math.min(root.sx, root.sy)
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.resumen(resultadoModelo.modelData.info)
                                  + " · " + root.numeroLegible(root.valor(resultadoModelo.modelData.info, ["parametros_totales"], 0))
                                  + " parámetros"
                            color: Style.Theme.texto_secundario
                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8 * root.sx
                            color: "#FAFAFA"
                            border.color: "#E5E7EB"

                            ScrollView {
                                anchors.fill: parent
                                anchors.margins: 7 * root.sx
                                clip: true
                                TextArea {
                                    text: resultadoModelo.modelData.texto
                                    placeholderText: "La respuesta aparecerá aquí token a token…"
                                    readOnly: true
                                    selectByMouse: true
                                    wrapMode: TextEdit.Wrap
                                    color: Style.Theme.texto_primario
                                    font.pixelSize: 15 * Math.min(root.sx, root.sy)
                                    background: Rectangle { color: "transparent" }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 43 * root.sy
                            radius: 8 * root.sx
                            color: resultadoModelo.modelData.fondo
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12 * root.sx
                                anchors.rightMargin: 12 * root.sx
                                Text {
                                    Layout.fillWidth: true
                                    text: resultadoModelo.modelData.estado
                                    color: resultadoModelo.modelData.acento
                                    font.bold: true
                                    font.pixelSize: 12 * Math.min(root.sx, root.sy)
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: resultadoModelo.modelData.tokens + " tokens"
                                          + (resultadoModelo.modelData.duracion > 0
                                             ? " · " + resultadoModelo.modelData.duracion + " ms" : "")
                                    color: Style.Theme.texto_secundario
                                    font.pixelSize: 12 * Math.min(root.sx, root.sy)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
