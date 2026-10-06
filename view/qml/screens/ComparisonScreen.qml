pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root
    helpModalObjectName: "comparisonTheoryModal"
    helpPanelObjectName: "comparisonTheoryPanel"

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
    // Snapshots del forward real de cada token, para la vista interna.
    property var pasosA: []
    property var pasosB: []
    property bool mostrarInterior: false
    // Paso que muestran ambos paneles (0 = seguir el último token).
    property int pasoSeleccionado: 0
    readonly property int pasosDisponibles: Math.max(root.pasosA.length, root.pasosB.length)
    readonly property int pasoVisible: root.pasoSeleccionado > 0
                                       ? Math.min(root.pasoSeleccionado, root.pasosDisponibles)
                                       : root.pasosDisponibles

    function pasoDe(lista) {
        var indice = root.pasoVisible - 1
        return indice >= 0 && indice < lista.length ? lista[indice] : null
    }
    property var pasosVisualizacionA: []
    property var pasosVisualizacionB: []
    property var detallesPendientesA: ({})
    property var detallesPendientesB: ({})
    property var detalleForwardComunA: ({})
    property var detalleForwardComunB: ({})
    property int indiceDetalleComun: -1
    property int indiceExploracion: -1
    property bool sesionPasoAPaso: false
    property bool pasoPendienteA: false
    property bool pasoPendienteB: false

    readonly property bool modelosListos: controller && controller.modelosListos
    readonly property bool cargando: controller && controller.cargando
    readonly property var controladorA: controller ? controller.controladorA : null
    readonly property var controladorB: controller ? controller.controladorB : null
    readonly property int maxTokensPermitidos: controller
            ? controller.maxTokensPermitidos : 512
    readonly property bool pasoPendiente: pasoPendienteA || pasoPendienteB
    readonly property bool hayTraza: pasosVisualizacionA.length > 0
                                      || pasosVisualizacionB.length > 0
    readonly property bool modeloAActivo: Boolean(controladorA
                                                   && controladorA.estaGenerando)
    readonly property bool modeloBActivo: Boolean(controladorB
                                                   && controladorB.estaGenerando)
    readonly property string etiquetaAvance: {
        if (modeloAActivo && modeloBActivo)
            return "Siguiente token en ambos"
        if (modeloAActivo)
            return "Continuar solo Modelo A"
        if (modeloBActivo)
            return "Continuar solo Modelo B"
        return "Generación finalizada"
    }

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
        pasosA = []
        pasosB = []
        pasoSeleccionado = 0
        duracionA = 0
        duracionB = 0
        estadoA = "Listo"
        estadoB = "Listo"
        sesionPasoAPaso = false
        pasoPendienteA = false
        pasoPendienteB = false
        pasosVisualizacionA = []
        pasosVisualizacionB = []
        detallesPendientesA = ({})
        detallesPendientesB = ({})
        detalleForwardComunA = ({})
        detalleForwardComunB = ({})
        indiceDetalleComun = -1
        indiceExploracion = -1
        controller.cargarModelos(ruta(seleccionadoA), ruta(seleccionadoB))
    }

    function snapshotLigero(paso) {
        if (!paso || paso.visualizacion === undefined)
            return null
        var snapshot = paso.visualizacion
        var resumen = ({})
        for (var clave in snapshot) {
            if (clave !== "detalle_forward")
                resumen[clave] = snapshot[clave]
        }
        return resumen
    }

    function agregarDetallePendiente(modelo, indice, detalle) {
        if (!detalle || detalle.metadata === undefined)
            return
        var origen = modelo === "A" ? detallesPendientesA : detallesPendientesB
        var actualizado = ({})
        for (var clave in origen)
            actualizado[clave] = origen[clave]
        actualizado[String(indice)] = detalle
        if (modelo === "A")
            detallesPendientesA = actualizado
        else
            detallesPendientesB = actualizado
    }

    function detallesPosteriores(origen, indice) {
        var restantes = ({})
        for (var clave in origen) {
            if (Number(clave) > indice)
                restantes[clave] = origen[clave]
        }
        return restantes
    }

    function sincronizarDetallesComunes() {
        var indice = Math.min(pasosVisualizacionA.length,
                              pasosVisualizacionB.length) - 1
        if (indice < 0)
            return
        var clave = String(indice)
        var detalleA = detallesPendientesA[clave]
        var detalleB = detallesPendientesB[clave]
        if (!detalleA || detalleA.metadata === undefined
                || !detalleB || detalleB.metadata === undefined)
            return
        detalleForwardComunA = detalleA
        detalleForwardComunB = detalleB
        indiceDetalleComun = indice
        // Solo permanece en memoria la captura común más reciente y los
        // pasos adelantados que todavía esperan a su pareja.
        detallesPendientesA = detallesPosteriores(detallesPendientesA, indice)
        detallesPendientesB = detallesPosteriores(detallesPendientesB, indice)
    }

    function detallePara(modelo, indice) {
        if (indice === indiceDetalleComun)
            return modelo === "A" ? detalleForwardComunA : detalleForwardComunB
        var pendientes = modelo === "A" ? detallesPendientesA : detallesPendientesB
        return pendientes[String(indice)] || ({})
    }

    function indiceDetallePara(modelo, indice) {
        var detalle = detallePara(modelo, indice)
        return detalle && detalle.metadata !== undefined ? indice : -1
    }

    function indiceComparacionPreferido() {
        var comunes = Math.min(pasosVisualizacionA.length,
                               pasosVisualizacionB.length)
        if (comunes > 0)
            return comunes - 1
        return Math.max(pasosVisualizacionA.length,
                        pasosVisualizacionB.length) - 1
    }

    function registrarToken(modelo, paso) {
        var resumen = snapshotLigero(paso)
        var detalle = paso && paso.visualizacion
                ? (paso.visualizacion.detalle_forward || ({})) : ({})
        if (modelo === "A") {
            if (resumen)
                pasosVisualizacionA = pasosVisualizacionA.concat([resumen])
            agregarDetallePendiente("A", pasosVisualizacionA.length - 1, detalle)
            pasoPendienteA = sesionPasoAPaso && Boolean(paso && paso.es_ultimo_token)
        } else {
            if (resumen)
                pasosVisualizacionB = pasosVisualizacionB.concat([resumen])
            agregarDetallePendiente("B", pasosVisualizacionB.length - 1, detalle)
            pasoPendienteB = sesionPasoAPaso && Boolean(paso && paso.es_ultimo_token)
        }
        sincronizarDetallesComunes()
        indiceExploracion = indiceComparacionPreferido()
    }

    function abrirExploracion() {
        if (!hayTraza)
            return
        indiceExploracion = indiceComparacionPreferido()
        if (root.secondaryDisplayAvailable) {
            exploradorComparacion.close()
            exploradorComparacionAparte.show()
            if (typeof displayManager !== "undefined" && displayManager)
                displayManager.placeAuxiliaryWindow(
                            exploradorComparacionAparte, true)
        } else {
            exploradorComparacionAparte.hide()
            exploradorComparacion.open()
        }
    }

    function cerrarExploracion() {
        exploradorComparacion.close()
        exploradorComparacionAparte.hide()
    }

    function avanzarUnToken() {
        if (!controller || !sesionPasoAPaso || !controller.estaGenerando
                || pasoPendiente)
            return
        pasoPendienteA = Boolean(controladorA && controladorA.estaGenerando)
        pasoPendienteB = Boolean(controladorB && controladorB.estaGenerando)
        estadoA = pasoPendienteA ? "Procesando siguiente token…" : estadoA
        estadoB = pasoPendienteB ? "Procesando siguiente token…" : estadoB
        mensajeEstado = etiquetaAvance + "…"
        mensajeEsError = false
        controller.generarSiguienteToken()
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
        pasosA = []
        pasosB = []
        pasoSeleccionado = 0
        duracionA = 0
        duracionB = 0
        inicioA = Date.now()
        inicioB = inicioA
        estadoA = "Preparando generación…"
        estadoB = "Preparando generación…"
        pasosVisualizacionA = []
        pasosVisualizacionB = []
        detallesPendientesA = ({})
        detallesPendientesB = ({})
        detalleForwardComunA = ({})
        detalleForwardComunB = ({})
        indiceDetalleComun = -1
        indiceExploracion = -1
        sesionPasoAPaso = modoGeneracion.currentIndex === 0
        pasoPendienteA = sesionPasoAPaso
        pasoPendienteB = sesionPasoAPaso
        mensajeEstado = sesionPasoAPaso
                ? "Generando el primer token en ambos modelos…"
                : "Generando de corrido con los mismos parámetros…"
        mensajeEsError = false
        if (sesionPasoAPaso) {
            controller.iniciarGeneracionPasoAPaso(
                        prompt,
                        maxTokens.value,
                        temperatura.value,
                        usarTopK.checked ? topK.value : 0,
                        usarTopP.checked ? topP.value : 1.0,
                        muestreoCodicioso.checked)
        } else {
            controller.iniciarGeneracion(
                        prompt,
                        maxTokens.value,
                        temperatura.value,
                        usarTopK.checked ? topK.value : 0,
                        usarTopP.checked ? topP.value : 1.0,
                        muestreoCodicioso.checked)
        }
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
            root.pasoPendienteA = false
            root.pasoPendienteB = false
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
            root.registrarToken("A", paso)
            var resumenA = root.snapshotLigero(paso)
            if (resumenA)
                root.pasosA = root.pasosA.concat([resumenA])
            root.tokensA += 1
            root.estadoA = root.sesionPasoAPaso
                    ? "Token " + root.tokensA + " listo"
                    : "Generando token " + root.tokensA + "…"
            if (root.sesionPasoAPaso && !root.pasoPendiente)
                root.mensajeEstado = "Paso listo. Explora las trazas o genera el siguiente token."
        }
        function onGeneracion_completa(texto) {
            if (texto !== undefined && texto !== null)
                root.textoA = String(texto)
            root.duracionA = Math.max(0, Date.now() - root.inicioA)
            root.estadoA = "Completada"
            root.pasoPendienteA = false
            root.mensajeEstado = root.controladorB && root.controladorB.estaGenerando
                    ? "Modelo A terminó; Modelo B continúa generando…"
                    : "Comparación finalizada. Revisa ambas respuestas."
        }
        function onGeneracion_cancelada(texto) {
            if (texto !== undefined && texto !== null)
                root.textoA = String(texto)
            root.duracionA = Math.max(0, Date.now() - root.inicioA)
            root.estadoA = "Detenida"
            root.pasoPendienteA = false
        }
        function onError(mensaje) {
            root.estadoA = "Error: " + String(mensaje)
            root.pasoPendienteA = false
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
            root.registrarToken("B", paso)
            var resumenB = root.snapshotLigero(paso)
            if (resumenB)
                root.pasosB = root.pasosB.concat([resumenB])
            root.tokensB += 1
            root.estadoB = root.sesionPasoAPaso
                    ? "Token " + root.tokensB + " listo"
                    : "Generando token " + root.tokensB + "…"
            if (root.sesionPasoAPaso && !root.pasoPendiente)
                root.mensajeEstado = "Paso listo. Explora las trazas o genera el siguiente token."
        }
        function onGeneracion_completa(texto) {
            if (texto !== undefined && texto !== null)
                root.textoB = String(texto)
            root.duracionB = Math.max(0, Date.now() - root.inicioB)
            root.estadoB = "Completada"
            root.pasoPendienteB = false
            root.mensajeEstado = root.controladorA && root.controladorA.estaGenerando
                    ? "Modelo B terminó; Modelo A continúa generando…"
                    : "Comparación finalizada. Revisa ambas respuestas."
        }
        function onGeneracion_cancelada(texto) {
            if (texto !== undefined && texto !== null)
                root.textoB = String(texto)
            root.duracionB = Math.max(0, Date.now() - root.inicioB)
            root.estadoB = "Detenida"
            root.pasoPendienteB = false
        }
        function onError(mensaje) {
            root.estadoB = "Error: " + String(mensaje)
            root.pasoPendienteB = false
            root.mensajeEstado = "Modelo B: " + String(mensaje)
            root.mensajeEsError = true
        }
    }

    RowLayout {
        id: cabecera
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 24 * root.sy
        anchors.leftMargin: 24 * root.sx
        anchors.rightMargin: Math.max(100, 150 * root.sx)
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
                objectName: "comparisonScreenTitle"
                text: "Comparación de modelos"
                color: Style.Theme.texto_primario
                font.bold: true
                font.pixelSize: 27 * Math.min(root.sx, root.sy)
            }
            Text {
                text: root.modelosListos
                      ? "Mismo prompt; compara encoder, decoder y salida token a token."
                      : "Selecciona modelos ya entrenados desde tu biblioteca local."
                color: Style.Theme.texto_secundario
                font.pixelSize: 14 * Math.min(root.sx, root.sy)
            }
        }

        Rectangle {
            Layout.preferredWidth: Math.min(610 * root.sx, mensajeCabecera.implicitWidth + 36 * root.sx)
            Layout.preferredHeight: 38 * root.sy
            radius: height / 2
            color: root.mensajeEsError ? Style.Theme.error_fondo : Style.Theme.acento_fondo
            border.color: root.mensajeEsError ? "#FCA5A5" : Style.Theme.acento_alt
            Text {
                id: mensajeCabecera
                anchors.centerIn: parent
                text: root.mensajeEstado
                color: root.mensajeEsError ? Style.Theme.error_texto : Style.Theme.acento_fuerte
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
                        color: elegida ? Style.Theme.acento_fondo : Style.Theme.surface
                        border.width: elegida ? 2 : 1
                        border.color: elegida ? Style.Theme.acento : Style.Theme.borde_suave
                        opacity: utilizable ? 1.0 : 0.58

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 15 * root.sx
                            spacing: 18 * root.sx

                            Rectangle {
                                Layout.preferredWidth: 48 * root.sx
                                Layout.preferredHeight: 48 * root.sy
                                radius: 12 * root.sx
                                color: tarjetaModelo.elegida ? Style.Theme.acento : Style.Theme.acento_fondo
                                Text {
                                    anchors.centerIn: parent
                                    text: tarjetaModelo.elegida
                                          ? root.etiquetaSeleccion(tarjetaModelo.modelData).slice(-1)
                                          : "T"
                                    color: tarjetaModelo.elegida ? Style.Theme.texto_sobre_color : Style.Theme.acento_fuerte
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
                                    color: Style.Theme.acento
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
                                       ? (tarjetaModelo.elegida ? Style.Theme.acento_fuerte : Style.Theme.exito_texto)
                                       : Style.Theme.error_texto
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
                        color: modelData.item ? Style.Theme.acento_fondo : Style.Theme.superficie_alterna
                        border.color: modelData.item ? Style.Theme.acento_alt : Style.Theme.borde_suave
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12 * root.sx
                            spacing: 5 * root.sy
                            Text {
                                text: resumenSeleccionado.modelData.etiqueta
                                color: Style.Theme.acento
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
                    text: root.cargando
                          ? ((root.controller.faseCarga || "Cargando modelos") + "…")
                          : "Comparar modelos  →"
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

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: 46 * root.sy
            text: root.controller && root.controller.faseCarga
                  ? root.controller.faseCarga + "…" : ""
            color: Style.Theme.texto_secundario
            font.pixelSize: 13 * Math.min(root.sx, root.sy)
            visible: root.cargando
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
                        color: Style.Theme.acento_fuerte
                        font.bold: true
                        font.pixelSize: 13 * Math.min(root.sx, root.sy)
                    }
                    BotonAcento {
                        objectName: "comparisonOpenExplorerButton"
                        visible: root.hayTraza
                        Layout.preferredWidth: 205 * root.sx
                        Layout.preferredHeight: 34 * root.sy
                        text: "Explorar encoder y decoder"
                        font.pixelSize: 11 * Math.min(root.sx, root.sy)
                        onClicked: root.abrirExploracion()
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
                        AreaTextoPrincipal {
                            id: campoPrompt
                            sx: root.sx
                            sy: root.sy
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
                            ConceptHelpButton {
                                conceptId: "detencion_generacion"
                                controlSize: Math.max(21, 24 * Math.min(root.sx, root.sy))
                                onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                            }
                            NumeroPrincipal {
                                id: maxTokens
                                Layout.preferredWidth: 110 * root.sx
                                from: 1
                                to: root.maxTokensPermitidos
                                value: Math.min(100, root.maxTokensPermitidos)
                                editable: true
                                enabled: !root.controller.estaGenerando
                            }
                            Text { text: "Temperatura"; color: Style.Theme.texto_secundario }
                            ConceptHelpButton {
                                conceptId: "temperature"
                                controlSize: Math.max(21, 24 * Math.min(root.sx, root.sy))
                                onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                            }
                            SliderPrincipal {
                                id: temperatura
                                Layout.fillWidth: true
                                sx: root.sx
                                sy: root.sy
                                from: 0.1
                                to: 2.0
                                stepSize: 0.05
                                value: 1.0
                                enabled: !root.controller.estaGenerando && !muestreoCodicioso.checked
                            }
                            Text {
                                text: temperatura.value.toFixed(2)
                                color: Style.Theme.acento_fuerte
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            CasillaPrincipal {
                                id: usarTopK
                                text: "Top-K"
                                checked: true
                                enabled: !root.controller.estaGenerando && !muestreoCodicioso.checked
                            }
                            ConceptHelpButton {
                                conceptId: "top_k"
                                controlSize: Math.max(21, 24 * Math.min(root.sx, root.sy))
                                onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                            }
                            NumeroPrincipal {
                                id: topK
                                Layout.preferredWidth: 100 * root.sx
                                from: 1
                                to: 100
                                value: 50
                                editable: true
                                enabled: usarTopK.checked && usarTopK.enabled
                            }
                            CasillaPrincipal {
                                id: usarTopP
                                text: "Top-P"
                                checked: true
                                enabled: !root.controller.estaGenerando && !muestreoCodicioso.checked
                            }
                            ConceptHelpButton {
                                conceptId: "top_p"
                                controlSize: Math.max(21, 24 * Math.min(root.sx, root.sy))
                                onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                            }
                            SliderPrincipal {
                                id: topP
                                Layout.fillWidth: true
                                sx: root.sx
                                sy: root.sy
                                from: 0.05
                                to: 0.99
                                stepSize: 0.01
                                value: 0.90
                                enabled: usarTopP.checked && usarTopP.enabled
                            }
                            Text {
                                text: topP.value.toFixed(2)
                                color: Style.Theme.acento_fuerte
                                font.bold: true
                            }
                            CasillaPrincipal {
                                id: muestreoCodicioso
                                text: "Codicioso"
                                checked: false
                                enabled: !root.controller.estaGenerando
                            }
                            ConceptHelpButton {
                                conceptId: "greedy_sampling"
                                controlSize: Math.max(21, 24 * Math.min(root.sx, root.sy))
                                onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 7 * root.sx

                            Text {
                                text: "Modo"
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 11 * Math.min(root.sx, root.sy)
                            }

                            SelectorPrincipal {
                                id: modoGeneracion
                                objectName: "comparisonGenerationMode"
                                Layout.preferredWidth: 152 * root.sx
                                Layout.preferredHeight: 38 * root.sy
                                model: ["Token por token", "De corrido"]
                                currentIndex: 0
                                enabled: !root.controller.estaGenerando
                                sx: root.sx
                                sy: root.sy
                            }

                            Item { Layout.fillWidth: true }

                            BotonPrincipal {
                                objectName: "comparisonGenerateButton"
                                Layout.preferredWidth: 205 * root.sx
                                Layout.preferredHeight: 45 * root.sy
                                text: root.sesionPasoAPaso && root.controller.estaGenerando
                                      ? root.etiquetaAvance
                                      : (modoGeneracion.currentIndex === 0
                                         ? "▶ Primer token" : "▶ Generar ambos")
                                size_text: 0.25
                                enabled: campoPrompt.text.trim().length > 0
                                         && (!root.controller.estaGenerando
                                             || (root.sesionPasoAPaso
                                                 && !root.pasoPendiente))
                                opacity: enabled ? 1.0 : 0.48
                                onClicked: {
                                    if (root.sesionPasoAPaso
                                            && root.controller.estaGenerando)
                                        root.avanzarUnToken()
                                    else
                                        root.iniciarComparacion()
                                }
                            }
                            BotonPrincipal {
                                visible: !root.sesionPasoAPaso
                                         && root.controller.estaGenerando
                                Layout.preferredWidth: visible ? 116 * root.sx : 0
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
                                Layout.preferredWidth: 108 * root.sx
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
            id: barraVistaComparacion
            objectName: "comparisonViewBar"
            anchors.top: panelPrompt.bottom
            anchors.topMargin: 10 * root.sy
            anchors.left: parent.left
            anchors.right: parent.right
            height: 36 * root.sy
            spacing: 10 * root.sx

            BotonSecundario {
                objectName: "comparisonShowOutputButton"
                Layout.preferredWidth: 150 * root.sx
                Layout.preferredHeight: 32 * root.sy
                sx: root.sx
                sy: root.sy
                text: "Respuestas"
                checkable: true
                checked: !root.mostrarInterior
                font.bold: checked
                onClicked: root.mostrarInterior = false
            }
            BotonSecundario {
                objectName: "comparisonShowInternalButton"
                Layout.preferredWidth: 190 * root.sx
                Layout.preferredHeight: 32 * root.sy
                sx: root.sx
                sy: root.sy
                text: "Estados internos"
                checkable: true
                checked: root.mostrarInterior
                font.bold: checked
                onClicked: root.mostrarInterior = true
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: root.mostrarInterior
                text: root.pasosDisponibles > 0
                      ? "Paso " + root.pasoVisible + " de " + root.pasosDisponibles
                        + (root.pasoSeleccionado === 0 ? " (siguiendo el último)" : "")
                      : "Sin pasos generados"
                color: Style.Theme.texto_secundario
                font.pixelSize: 12 * Math.min(root.sx, root.sy)
            }
            Slider {
                objectName: "comparisonStepSlider"
                visible: root.mostrarInterior
                Layout.preferredWidth: 260 * root.sx
                from: 1
                to: Math.max(1, root.pasosDisponibles)
                stepSize: 1
                enabled: root.pasosDisponibles > 1
                value: root.pasoVisible
                onMoved: root.pasoSeleccionado = Math.round(value)
            }
            BotonSecundario {
                visible: root.mostrarInterior
                Layout.preferredWidth: 110 * root.sx
                Layout.preferredHeight: 32 * root.sy
                sx: root.sx
                sy: root.sy
                text: "Último"
                enabled: root.pasoSeleccionado !== 0
                onClicked: root.pasoSeleccionado = 0
            }
        }

        RowLayout {
            anchors.top: barraVistaComparacion.bottom
            anchors.topMargin: 10 * root.sy
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
                        pasoInterno: root.pasoDe(root.pasosA),
                        tokens: root.tokensA,
                        duracion: root.duracionA,
                        estado: root.estadoA,
                        acento: Style.Theme.acento,
                        fondo: Style.Theme.acento_fondo
                    },
                    {
                        etiqueta: "MODELO B",
                        info: root.controller ? root.controller.modeloBInfo : {},
                        texto: root.textoB,
                        pasoInterno: root.pasoDe(root.pasosB),
                        tokens: root.tokensB,
                        duracion: root.duracionB,
                        estado: root.estadoB,
                        acento: "#2563EB",
                        fondo: Style.Theme.chip_fondo
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

                        ComparacionInterna {
                            objectName: "comparisonInternal_" + resultadoModelo.modelData.etiqueta
                            visible: root.mostrarInterior
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            paso: resultadoModelo.modelData.pasoInterno
                            acento: resultadoModelo.modelData.acento
                            sx: root.sx
                            sy: root.sy
                            onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                        }

                        Rectangle {
                            visible: !root.mostrarInterior
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8 * root.sx
                            color: Style.Theme.superficie_alterna
                            border.color: Style.Theme.divisor

                            ScrollView {
                                anchors.fill: parent
                                anchors.margins: 7 * root.sx
                                clip: true
                                AreaTextoPrincipal {
                                    text: resultadoModelo.modelData.texto
                                    placeholderText: "La respuesta aparecerá aquí token a token…"
                                    readOnly: true
                                    selectByMouse: true
                                    wrapMode: TextEdit.Wrap
                                    color: Style.Theme.texto_primario
                                    font.pixelSize: 15 * Math.min(root.sx, root.sy)
                                    sx: root.sx
                                    sy: root.sy
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

    Component {
        id: panelExploradorComparacion

        ComparisonExplorationPanel {
            snapshotsA: root.pasosVisualizacionA
            snapshotsB: root.pasosVisualizacionB
            infoA: root.controller ? root.controller.modeloAInfo : ({})
            infoB: root.controller ? root.controller.modeloBInfo : ({})
            detailA: root.detallePara("A", root.indiceExploracion)
            detailB: root.detallePara("B", root.indiceExploracion)
            detailIndexA: root.indiceDetallePara("A", root.indiceExploracion)
            detailIndexB: root.indiceDetallePara("B", root.indiceExploracion)
            selectedIndex: root.indiceExploracion
            stepMode: root.sesionPasoAPaso
            canGenerateNext: Boolean(root.controller
                                     && root.controller.estaGenerando
                                     && root.sesionPasoAPaso)
            tokenProcessing: root.pasoPendiente
            stateA: root.estadoA
            stateB: root.estadoB
            tokenCountA: root.tokensA
            tokenCountB: root.tokensB
            modelAActive: root.modeloAActivo
            modelBActive: root.modeloBActivo
            nextTokenLabel: root.etiquetaAvance
            sx: Math.min(1, width / Style.Theme.baseWidth)
            sy: Math.min(1, height / Style.Theme.baseHeight)
            onCloseRequested: root.cerrarExploracion()
            onNextTokenRequested: root.avanzarUnToken()
            onStepSelected: function(index) { root.indiceExploracion = index }
        }
    }

    Popup {
        id: exploradorComparacion
        objectName: "comparisonExplorerPopup"
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        width: root.width - 42 * root.sx
        height: root.height - 42 * root.sy
        padding: 0
        modal: true
        dim: true
        focus: true
        closePolicy: Popup.CloseOnEscape

        Overlay.modal: Rectangle { color: "#990F172A" }
        background: Rectangle { color: "transparent" }

        contentItem: Loader {
            sourceComponent: panelExploradorComparacion
        }
    }

    Window {
        id: exploradorComparacionAparte
        objectName: "comparisonExplorerSecondaryWindow"
        visible: false
        minimumWidth: 960
        minimumHeight: 600
        width: Style.Theme.baseWidth
        height: Style.Theme.baseHeight
        title: "Comparaci\u00f3n detallada de modelos"
        color: Style.Theme.fondo

        Loader {
            anchors.fill: parent
            anchors.margins: 12
            sourceComponent: panelExploradorComparacion
        }

        Component.onCompleted: {
            if (typeof displayManager !== "undefined" && displayManager)
                displayManager.registerAuxiliaryWindow(
                            exploradorComparacionAparte, true)
        }
        onVisibleChanged: {
            if (visible
                    && typeof displayManager !== "undefined"
                    && displayManager)
                displayManager.placeAuxiliaryWindow(
                            exploradorComparacionAparte, true)
        }
        onClosing: function(close) {
            root.cerrarExploracion()
            close.accepted = true
        }
    }

    onSecondaryDisplayAvailableChanged: {
        if (secondaryDisplayAvailable && exploradorComparacion.opened) {
            exploradorComparacion.close()
            exploradorComparacionAparte.show()
            if (typeof displayManager !== "undefined" && displayManager)
                displayManager.placeAuxiliaryWindow(
                            exploradorComparacionAparte, true)
        } else if (!secondaryDisplayAvailable
                   && exploradorComparacionAparte.visible) {
            exploradorComparacionAparte.hide()
            exploradorComparacion.open()
        }
    }

    onVisibleChanged: {
        if (!visible)
            root.cerrarExploracion()
    }
}
