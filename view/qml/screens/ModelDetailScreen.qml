pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root

    required property string rutaModelo
    property var modeloResumen: ({})
    property var controller: mainViewModel.modelLibraryController
    property var detalle: ({})
    property var tokenizacion: ({})
    property var salud: ({})
    property bool cargandoDetalle: false
    property bool cargandoTokenizacion: false
    property bool cargandoSalud: false
    property bool guardandoMetadata: false
    property string errorDetalle: ""
    property string errorTokenizacion: ""
    property string errorSalud: ""
    property string mensajeEstado: ""
    property bool mensajeEsError: false
    property string accionTrasCarga: ""

    readonly property var descriptorActual: root.tiene(root.campo(root.detalle, ["descriptor"], null))
                                                ? root.campo(root.detalle, ["descriptor"], {})
                                                : root.modeloResumen
    readonly property var arquitecturaActual: root.campo(root.detalle, ["arquitectura", "architecture"], {})
    readonly property var procedenciaActual: root.campo(root.detalle, ["procedencia", "provenance"], {})
    readonly property var historialActual: root.campo(root.detalle, ["historial", "history"], {})
    readonly property var integridadActual: root.campo(root.detalle, ["integridad", "integrity"], {})
    readonly property var compatibilidadActual: root.campo(root.detalle, ["compatibilidad", "compatibility"], {})
    readonly property var gestionActual: root.campo(root.detalle, ["gestion", "management"], {})
    readonly property string rutaActual: String(root.campo(root.detalle, ["ruta", "path"], root.rutaModelo))

    function tiene(valor) {
        if (valor === undefined || valor === null || valor === "")
            return false
        if (Array.isArray(valor))
            return valor.length > 0
        if (typeof valor === "object")
            return Object.keys(valor).length > 0
        return true
    }

    function campo(objeto, nombres, alternativo) {
        if (objeto === undefined || objeto === null)
            return alternativo
        var listaNombres = Array.isArray(nombres) ? nombres : []
        for (var i = 0; i < listaNombres.length; ++i) {
            var valor = objeto[listaNombres[i]]
            if (valor !== undefined && valor !== null && valor !== "")
                return valor
        }
        return alternativo
    }

    function campoCombinado(nombres, alternativo) {
        var fuentes = [root.arquitecturaActual, root.descriptorActual,
                       root.detalle, root.modeloResumen]
        for (var i = 0; i < fuentes.length; ++i) {
            var valor = root.campo(fuentes[i], nombres, null)
            if (root.tiene(valor) || valor === false || valor === 0)
                return valor
        }
        return alternativo
    }

    function texto(valor, alternativo) {
        if (!root.tiene(valor) && valor !== false && valor !== 0)
            return alternativo === undefined ? "No registrado" : alternativo
        return String(valor)
    }

    function booleanoTexto(valor) {
        if (valor === undefined || valor === null || valor === "")
            return "No registrado"
        if (typeof valor === "string") {
            var normalizado = valor.toLowerCase()
            if (normalizado === "true" || normalizado === "sí" || normalizado === "si" || normalizado === "1")
                return "Sí"
            if (normalizado === "false" || normalizado === "no" || normalizado === "0")
                return "No"
        }
        return Boolean(valor) ? "Sí" : "No"
    }

    function numeroLegible(valor) {
        if (valor === undefined || valor === null || valor === "")
            return "No registrado"
        var numero = Number(valor)
        if (isNaN(numero))
            return String(valor)
        if (Math.abs(numero) >= 1000000000)
            return (numero / 1000000000).toFixed(2) + " mil M"
        if (Math.abs(numero) >= 1000000)
            return (numero / 1000000).toFixed(2) + " M"
        if (Math.abs(numero) >= 1000)
            return (numero / 1000).toFixed(1) + " mil"
        return numero.toLocaleString(Qt.locale())
    }

    function decimalLegible(valor, decimales) {
        if (valor === undefined || valor === null || valor === "")
            return "No registrado"
        var numero = Number(valor)
        return isNaN(numero) ? String(valor) : numero.toFixed(decimales === undefined ? 4 : decimales)
    }

    function duracionLegible(valor) {
        if (valor === undefined || valor === null || valor === "")
            return "No registrada"
        var segundos = Number(valor)
        if (isNaN(segundos))
            return String(valor)
        if (segundos < 60)
            return segundos.toFixed(segundos < 10 ? 1 : 0) + " s"
        if (segundos < 3600)
            return Math.floor(segundos / 60) + " min " + Math.round(segundos % 60) + " s"
        return Math.floor(segundos / 3600) + " h "
                + Math.floor((segundos % 3600) / 60) + " min"
    }

    function probabilidadLegible(valor) {
        if (valor === undefined || valor === null || valor === "")
            return "No registrada"
        var numero = Number(valor)
        if (isNaN(numero))
            return String(valor)
        var porcentaje = Math.abs(numero) <= 1 ? numero * 100 : numero
        return porcentaje.toFixed(1) + " %"
    }

    function porcentajeLegible(valor) {
        if (valor === undefined || valor === null || valor === "")
            return "No registrado"
        var numero = Number(valor)
        return isNaN(numero) ? String(valor) : numero.toFixed(1) + " %"
    }

    function conteoLegible(valor) {
        if (Array.isArray(valor))
            return String(valor.length)
        return root.texto(valor, "No registrado")
    }

    function comoLista(valor) {
        if (valor === undefined || valor === null)
            return []
        if (Array.isArray(valor))
            return valor
        if (typeof valor !== "object")
            return [valor]
        var resultado = []
        for (var clave in valor) {
            var elemento = valor[clave]
            if (elemento !== null && typeof elemento === "object" && !Array.isArray(elemento)) {
                var copia = {}
                for (var propiedad in elemento)
                    copia[propiedad] = elemento[propiedad]
                if (!root.tiene(root.campo(copia, ["nombre", "name", "bloque", "tensor"], null)))
                    copia.nombre = clave
                resultado.push(copia)
            } else {
                resultado.push({ "nombre": clave, "valor": elemento })
            }
        }
        return resultado
    }

    function listaDe(objeto, nombres) {
        return root.comoLista(root.campo(objeto, nombres, []))
    }

    function mismaRuta(a, b) {
        return String(a || "").replace(/\\/g, "/").toLowerCase()
                === String(b || "").replace(/\\/g, "/").toLowerCase()
    }

    function esModeloActivo() {
        if (!root.controller)
            return false
        var activa = root.controller.modeloActivoRuta
        return root.tiene(activa) && root.mismaRuta(activa, root.rutaActual)
    }

    function nombreModelo() {
        return root.texto(root.campo(root.detalle, ["nombre", "name"],
                                     root.campo(root.descriptorActual, ["nombre", "name", "archivo"],
                                                "Modelo")), "Modelo")
    }

    function compatible() {
        var valor = root.campo(root.compatibilidadActual, ["compatible"],
                               root.campo(root.descriptorActual, ["compatible"], true))
        return valor === undefined || valor === null ? true : Boolean(valor)
    }

    function mostrarEstado(mensaje, esError) {
        root.mensajeEstado = root.texto(mensaje, "")
        root.mensajeEsError = esError
        if (root.mensajeEstado !== "")
            temporizadorEstado.restart()
    }

    function solicitarDetalle() {
        if (!root.controller || typeof root.controller.solicitarDetalleModelo !== "function") {
            root.cargandoDetalle = false
            root.errorDetalle = "Esta versión del controlador no permite inspeccionar modelos."
            return
        }
        root.cargandoDetalle = true
        root.errorDetalle = ""
        root.controller.solicitarDetalleModelo(root.rutaActual)
    }

    function cargarYAvanzar(destino) {
        if (!root.controller || root.controller.ocupado || !root.compatible())
            return
        if (destino === "inferencia" && root.esModeloActivo()
                && mainViewModel.modeloListo) {
            root.stackView.push("InferenceScreen.qml", { "stackView": root.stackView })
            return
        }
        root.accionTrasCarga = destino
        root.mostrarEstado(destino === "inferencia"
                           ? "Cargando el modelo para inferencia…"
                           : "Cargando pesos para continuar el entrenamiento…", false)
        root.controller.cargarModelo(root.rutaActual)
    }

    function analizarTexto() {
        var entrada = campoTextoTokenizador.text
        if (entrada.length === 0) {
            root.errorTokenizacion = "Escribe un texto para analizarlo."
            campoTextoTokenizador.forceActiveFocus()
            return
        }
        if (!root.controller || typeof root.controller.analizarTokenizacion !== "function") {
            root.errorTokenizacion = "El laboratorio de tokenización no está disponible en esta versión."
            return
        }
        root.cargandoTokenizacion = true
        root.errorTokenizacion = ""
        root.tokenizacion = ({})
        root.controller.analizarTokenizacion(root.rutaActual, entrada)
    }

    function ejecutarSalud() {
        if (!root.controller || typeof root.controller.ejecutarPruebaSalud !== "function") {
            root.errorSalud = "La prueba de salud no está disponible en esta versión."
            return
        }
        root.cargandoSalud = true
        root.errorSalud = ""
        root.salud = ({})
        root.controller.ejecutarPruebaSalud(root.rutaActual)
    }

    function puntosPerdida() {
        var crudos = root.listaDe(root.historialActual,
                                  ["perdidas", "losses", "curvaPerdida", "loss_history"])
        var puntos = []
        for (var i = 0; i < crudos.length; ++i) {
            var item = crudos[i]
            var y = typeof item === "number" ? item
                    : Number(root.campo(item, ["perdida", "loss", "valor", "value", "y"], NaN))
            var x = typeof item === "number" ? i + 1
                    : Number(root.campo(item, ["paso", "step", "epoca", "epoch", "x"], i + 1))
            if (!isNaN(x) && isFinite(x) && !isNaN(y) && isFinite(y))
                puntos.push({ "x": x, "y": y })
        }
        return puntos
    }

    function resumenSerie(valor, etiqueta) {
        var lista = root.comoLista(valor)
        if (lista.length === 0)
            return "No registrada"
        var ultimo = lista[lista.length - 1]
        if (typeof ultimo === "object")
            ultimo = root.campo(ultimo, ["valor", "value", "loss", "perdida",
                                          "precision", "accuracy", "perplexity"], null)
        return lista.length + (lista.length === 1 ? " punto" : " puntos")
                + (ultimo === null ? "" : " · último: " + root.decimalLegible(ultimo, 4))
    }

    function tokenVisible(valor) {
        if (valor === undefined || valor === null)
            return "—"
        return "“" + String(valor).replace(/\r/g, "\\r").replace(/\n/g, "\\n")
                .replace(/\t/g, "\\t").replace(/ /g, "·") + "”"
    }

    function caracteresLegibles(valor) {
        if (!root.tiene(valor) && valor !== 0)
            return "No registrado"
        if (Array.isArray(valor))
            return valor.join(" – ")
        if (typeof valor === "object") {
            var inicio = root.campo(valor, ["inicio", "start", "desde"], null)
            var fin = root.campo(valor, ["fin", "end", "hasta"], null)
            if (inicio !== null || fin !== null)
                return root.texto(inicio, "?") + " – " + root.texto(fin, "?")
        }
        return String(valor)
    }

    function especialesComoTexto() {
        var especiales = root.listaDe(root.tokenizacion,
                                      ["especiales", "specialTokens", "tokensEspeciales"])
        var partes = []
        for (var i = 0; i < especiales.length; ++i) {
            var item = especiales[i]
            if (typeof item === "object") {
                var nombre = root.campo(item,
                                        ["nombre", "name", "nombreEspecial", "token"],
                                        "especial")
                var id = root.campo(item, ["id", "tokenId", "valor", "value"], null)
                partes.push(String(nombre) + (id === null ? "" : " = " + id))
            } else {
                partes.push(String(item))
            }
        }
        return partes.join("   ·   ")
    }

    function tagsComoTexto() {
        var tags = root.listaDe(root.gestionActual, ["tags", "etiquetas"])
        var textos = []
        for (var i = 0; i < tags.length; ++i)
            textos.push(String(typeof tags[i] === "object"
                               ? root.campo(tags[i], ["nombre", "name", "valor"], "") : tags[i]))
        return textos.filter(function(valor) { return valor.trim().length > 0 }).join(", ")
    }

    function listaTags(textoCrudo) {
        var partes = String(textoCrudo || "").split(",")
        var resultado = []
        for (var i = 0; i < partes.length; ++i) {
            var etiqueta = partes[i].trim()
            if (etiqueta.length > 0 && resultado.indexOf(etiqueta) === -1)
                resultado.push(etiqueta)
        }
        return resultado
    }

    function cargarCamposMetadata() {
        campoNombre.text = root.nombreModelo()
        campoNotas.text = root.texto(root.campo(root.gestionActual, ["notas", "notes"], ""), "")
        campoTags.text = root.tagsComoTexto()
        campoGrupo.text = root.texto(root.campo(root.gestionActual,
                                                ["grupo", "experimentGroup", "experiment_group"], ""), "")
        campoVersion.text = root.texto(root.campo(root.gestionActual, ["version", "versión"], ""), "")
        campoDuplicado.text = root.nombreModelo() + " copia"
    }

    function guardarMetadata() {
        if (!root.controller || typeof root.controller.actualizarMetadataModelo !== "function") {
            root.mostrarEstado("La edición de metadatos no está disponible.", true)
            return
        }
        if (campoNombre.text.trim().length === 0) {
            root.mostrarEstado("El nombre visible no puede quedar vacío.", true)
            campoNombre.forceActiveFocus()
            return
        }
        root.guardandoMetadata = true
        root.controller.actualizarMetadataModelo(root.rutaActual,
                                                  campoNombre.text.trim(),
                                                  campoNotas.text.trim(),
                                                  root.listaTags(campoTags.text),
                                                  campoGrupo.text.trim(),
                                                  campoVersion.text.trim())
    }

    function renombrar() {
        if (!root.controller || typeof root.controller.renombrarModelo !== "function") {
            root.mostrarEstado("El renombrado no está disponible.", true)
            return
        }
        if (campoNombre.text.trim().length === 0) {
            root.mostrarEstado("Escribe un nombre antes de renombrar.", true)
            return
        }
        root.guardandoMetadata = true
        root.controller.renombrarModelo(root.rutaActual, campoNombre.text.trim())
    }

    function duplicar() {
        if (!root.controller || typeof root.controller.duplicarModelo !== "function") {
            root.mostrarEstado("La duplicación no está disponible.", true)
            return
        }
        if (campoDuplicado.text.trim().length === 0) {
            root.mostrarEstado("Escribe un nombre para la copia.", true)
            return
        }
        root.guardandoMetadata = true
        root.controller.duplicarModelo(root.rutaActual, campoDuplicado.text.trim())
    }

    Component.onCompleted: root.solicitarDetalle()

    Connections {
        target: root.controller
        ignoreUnknownSignals: true

        function onDetalle_modelo_listo(resultado) {
            var rutaResultado = root.campo(resultado, ["ruta", "path"], root.rutaActual)
            if (!root.mismaRuta(rutaResultado, root.rutaActual))
                return
            root.detalle = resultado || ({})
            root.cargandoDetalle = false
            root.errorDetalle = ""
            root.cargarCamposMetadata()
            lossCanvas.requestPaint()
        }

        function onTokenizacion_lista(resultado) {
            var rutaResultado = root.campo(resultado, ["ruta", "path"], root.rutaActual)
            if (!root.mismaRuta(rutaResultado, root.rutaActual))
                return
            root.tokenizacion = resultado || ({})
            root.cargandoTokenizacion = false
            root.errorTokenizacion = ""
        }

        function onPrueba_salud_lista(resultado) {
            var rutaResultado = root.campo(resultado, ["ruta", "path"], root.rutaActual)
            if (!root.mismaRuta(rutaResultado, root.rutaActual))
                return
            root.salud = resultado || ({})
            root.cargandoSalud = false
            root.errorSalud = ""
        }

        function onOperacion_exitosa(mensaje) {
            root.guardandoMetadata = false
            root.mostrarEstado(mensaje, false)
            root.solicitarDetalle()
        }

        function onError(mensaje) {
            if (root.cargandoTokenizacion) {
                root.cargandoTokenizacion = false
                root.errorTokenizacion = String(mensaje)
            } else if (root.cargandoSalud) {
                root.cargandoSalud = false
                root.errorSalud = String(mensaje)
            } else if (root.cargandoDetalle) {
                root.cargandoDetalle = false
                root.errorDetalle = String(mensaje)
            } else {
                root.guardandoMetadata = false
                root.accionTrasCarga = ""
                root.mostrarEstado(mensaje, true)
            }
        }
    }

    Connections {
        target: mainViewModel
        ignoreUnknownSignals: true

        function onModeloListoCambio() {
            if (!mainViewModel.modeloListo || root.accionTrasCarga === "")
                return
            var destino = root.accionTrasCarga
            root.accionTrasCarga = ""
            if (destino === "inferencia") {
                root.stackView.push("InferenceScreen.qml", { "stackView": root.stackView })
            } else {
                root.stackView.push("SetupScreen.qml", {
                    "stackView": root.stackView,
                    "usarModeloActual": true
                })
            }
        }
    }

    Timer {
        id: temporizadorEstado
        interval: 6500
        onTriggered: root.mensajeEstado = ""
    }

    QtObject {
        id: miniBridge
        property string selectedId: ""
        property int numCapas: Math.max(1, Number(root.campoCombinado(
                                                     ["capasEncoder", "encoder_layers", "num_capas"], 1)))
        function selectComponent(componentId) {}
    }

    RowLayout {
        id: cabecera
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 22 * root.sx
        anchors.rightMargin: 22 * root.sx
        height: 78 * root.sy
        spacing: 12 * root.sx

        BotonPrincipal {
            Layout.preferredWidth: 170 * root.sx
            Layout.preferredHeight: 43 * root.sy
            text: "↶ Biblioteca"
            size_text: 0.27
            onClicked: root.stackView.pop()
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1 * root.sy
            Text {
                Layout.fillWidth: true
                text: root.nombreModelo()
                color: Style.Theme.texto_primario
                font.bold: true
                font.pixelSize: 25 * Math.min(root.sx, root.sy)
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: root.rutaActual
                color: Style.Theme.texto_secundario
                font.pixelSize: 11 * Math.min(root.sx, root.sy)
                elide: Text.ElideMiddle
            }
        }

        Rectangle {
            Layout.preferredWidth: activoTexto.implicitWidth + 22 * root.sx
            Layout.preferredHeight: 30 * root.sy
            radius: height / 2
            color: root.esModeloActivo() ? "#DCFCE7" : "#F3F4F6"
            border.color: root.esModeloActivo() ? "#86EFAC" : "#D1D5DB"
            Text {
                id: activoTexto
                anchors.centerIn: parent
                text: root.esModeloActivo() ? "● Modelo activo" : "○ No activo"
                color: root.esModeloActivo() ? "#166534" : "#4B5563"
                font.bold: true
                font.pixelSize: 11 * Math.min(root.sx, root.sy)
            }
        }

        BusyIndicator {
            Layout.preferredWidth: 33 * root.sy
            Layout.preferredHeight: 33 * root.sy
            running: root.controller && root.controller.ocupado
            visible: running
        }

        BotonPrincipal {
            Layout.preferredWidth: 195 * root.sx
            Layout.preferredHeight: 43 * root.sy
            text: "Abrir en inferencia"
            size_text: 0.23
            enabled: root.compatible() && root.controller && !root.controller.ocupado
            opacity: enabled ? 1 : 0.5
            onClicked: root.cargarYAvanzar("inferencia")
        }

        BotonPrincipal {
            Layout.preferredWidth: 205 * root.sx
            Layout.preferredHeight: 43 * root.sy
            text: "Continuar entrenamiento"
            size_text: 0.21
            enabled: root.compatible() && root.controller && !root.controller.ocupado
            opacity: enabled ? 1 : 0.5
            onClicked: root.cargarYAvanzar("entrenamiento")
        }
    }

    Rectangle {
        id: aviso
        anchors.top: cabecera.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 44 * root.sx, textoAviso.implicitWidth + 38 * root.sx)
        height: root.mensajeEstado === "" ? 0 : 34 * root.sy
        visible: height > 0
        radius: 8 * root.sx
        color: root.mensajeEsError ? "#FEE2E2" : "#DCFCE7"
        border.color: root.mensajeEsError ? "#FCA5A5" : "#86EFAC"
        z: 20
        clip: true
        Behavior on height { NumberAnimation { duration: 120 } }
        Text {
            id: textoAviso
            anchors.centerIn: parent
            width: Math.min(implicitWidth, aviso.width - 18 * root.sx)
            text: root.mensajeEstado
            color: root.mensajeEsError ? "#991B1B" : "#166534"
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.pixelSize: 12 * Math.min(root.sx, root.sy)
        }
    }

    TabBar {
        id: pestañas
        anchors.top: aviso.bottom
        anchors.topMargin: 8 * root.sy
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 24 * root.sx
        anchors.rightMargin: 24 * root.sx
        height: 46 * root.sy

        Repeater {
            model: ["Arquitectura", "Procedencia", "Historial", "Tokenizador",
                    "Salud", "Versiones", "Integridad"]
            delegate: TabButton {
                required property var modelData
                text: modelData
                font.bold: checked
                font.pixelSize: 12 * Math.min(root.sx, root.sy)
            }
        }
    }

    Rectangle {
        id: bannerErrorDetalle
        anchors.top: pestañas.bottom
        anchors.topMargin: 7 * root.sy
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 28 * root.sx
        anchors.rightMargin: 28 * root.sx
        height: root.errorDetalle === "" ? 0 : 48 * root.sy
        visible: height > 0
        radius: 8 * root.sx
        color: "#FEF2F2"
        border.color: "#FCA5A5"
        clip: true
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14 * root.sx
            anchors.rightMargin: 8 * root.sx
            Text {
                Layout.fillWidth: true
                text: "No se pudo completar la ficha: " + root.errorDetalle
                      + ". Se muestran los datos disponibles del catálogo."
                color: "#991B1B"
                elide: Text.ElideRight
                font.pixelSize: 11 * Math.min(root.sx, root.sy)
            }
            BotonPrincipal {
                Layout.preferredWidth: 105 * root.sx
                Layout.preferredHeight: 31 * root.sy
                text: "Reintentar"
                size_text: 0.27
                onClicked: root.solicitarDetalle()
            }
        }
    }

    StackLayout {
        id: paginas
        anchors.top: bannerErrorDetalle.bottom
        anchors.topMargin: 8 * root.sy
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 26 * root.sx
        anchors.rightMargin: 26 * root.sx
        anchors.bottomMargin: 20 * root.sy
        currentIndex: pestañas.currentIndex

        // -----------------------------------------------------------------
        // Arquitectura
        // -----------------------------------------------------------------
        ScrollView {
            id: scrollArquitectura
            clip: true
            contentWidth: availableWidth

            ColumnLayout {
                width: scrollArquitectura.availableWidth
                spacing: 14 * root.sy

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 455 * root.sy
                    spacing: 14 * root.sx

                    RectanglePrincipal {
                        Layout.preferredWidth: Math.min(620 * root.sx,
                                                        scrollArquitectura.availableWidth * 0.39)
                        Layout.fillHeight: true
                        sx: root.sx
                        sy: root.sy
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14 * root.sx
                            spacing: 6 * root.sy
                            Text {
                                Layout.fillWidth: true
                                text: "MAPA DE LA ARQUITECTURA"
                                color: "#6D28D9"
                                font.bold: true
                                font.pixelSize: 12 * Math.min(root.sx, root.sy)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.texto(root.campo(root.arquitecturaActual,
                                                           ["tipo", "type"], null),
                                                 "Tipo de arquitectura no registrado")
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 11 * Math.min(root.sx, root.sy)
                                elide: Text.ElideRight
                            }
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                TransformerDiagram {
                                    anchors.fill: parent
                                    bridge: miniBridge
                                    enabled: false
                                    opacity: 0.92
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
                            anchors.margins: 16 * root.sx
                            spacing: 9 * root.sy
                            Text {
                                Layout.fillWidth: true
                                text: "DIMENSIONES Y DECISIONES DE DISEÑO"
                                color: "#6D28D9"
                                font.bold: true
                                font.pixelSize: 12 * Math.min(root.sx, root.sy)
                            }
                            GridLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                columns: 3
                                columnSpacing: 9 * root.sx
                                rowSpacing: 9 * root.sy
                                Repeater {
                                    model: [
                                        { e: "Capas encoder", v: root.campoCombinado(["capasEncoder", "encoder_layers"], null) },
                                        { e: "Capas decoder", v: root.campoCombinado(["capasDecoder", "decoder_layers"], null) },
                                        { e: "Cabezas", v: root.campoCombinado(["cabezas", "num_cabezas", "heads"], null) },
                                        { e: "d_model", v: root.campoCombinado(["dModel", "d_model", "dimension_modelo", "dimension"], null) },
                                        { e: "d_head", v: root.campoCombinado(["dimensionCabeza", "dimension_cabeza", "headDimension", "head_dimension", "d_head"], null) },
                                        { e: "d_ff", v: root.campoCombinado(["dFF", "d_ff", "dimension_ff", "dimensionFF"], null) },
                                        { e: "Contexto", v: root.campoCombinado(["contexto", "context_length", "longitud_maxima_secuencia"], null) },
                                        { e: "Vocabulario", v: root.campoCombinado(["vocabulario", "vocab_size", "tamano_vocabulario"], null) },
                                        { e: "Parámetros", v: root.campoCombinado(["parametrosTotales", "parametros_totales", "parametros"], null), numero: true },
                                        { e: "Activación", v: root.campoCombinado(["activacion", "activation"], null) },
                                        { e: "Dropout", v: root.campoCombinado(["dropout"], null) },
                                        { e: "Máscara causal", v: root.booleanoTexto(root.campoCombinado(["mascaraCausal", "usar_mascara_causal", "causal_mask"], null)) },
                                        { e: "Normalización", v: root.campoCombinado(["normalizacion", "normalization", "normType", "tipo_normalizacion", "normalization_type"], null) },
                                        { e: "Orden de normalización", v: root.campoCombinado(["ordenNormalizacion", "normalizationOrder", "normalization_order", "orden_normalizacion"], null) },
                                        { e: "Weight tying", v: root.booleanoTexto(root.campoCombinado(["weightTying", "weight_tying", "pesosCompartidos", "compartir_pesos_salida"], null)) },
                                        { e: "Formato", v: root.campo(root.descriptorActual, ["formato", "format"], null) }
                                    ]
                                    delegate: Rectangle {
                                        id: arquitecturaMetrica
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 7 * root.sx
                                        color: "#F8FAFC"
                                        border.color: "#E5E7EB"
                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8 * root.sx
                                            spacing: 2 * root.sy
                                            Text {
                                                Layout.fillWidth: true
                                                text: arquitecturaMetrica.modelData.e
                                                color: Style.Theme.texto_secundario
                                                font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: arquitecturaMetrica.modelData.numero
                                                      ? root.numeroLegible(arquitecturaMetrica.modelData.v)
                                                      : root.texto(arquitecturaMetrica.modelData.v, "No registrado")
                                                color: Style.Theme.texto_primario
                                                font.bold: true
                                                font.pixelSize: 13 * Math.min(root.sx, root.sy)
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                RectanglePrincipal {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(155 * root.sy,
                                                      55 * root.sy + root.listaDe(root.arquitecturaActual,
                                                                                 ["bloques", "blocks"]).length * 34 * root.sy)
                    sx: root.sx
                    sy: root.sy
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14 * root.sx
                        spacing: 5 * root.sy
                        Text {
                            text: "PARÁMETROS Y SHAPES POR BLOQUE"
                            color: "#6D28D9"
                            font.bold: true
                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 25 * root.sy
                            spacing: 8 * root.sx
                            Repeater {
                                model: [
                                    { t: "Bloque", w: 1.4 }, { t: "Entrada", w: 1 },
                                    { t: "Salida", w: 1 }, { t: "Repeticiones", w: 0.7 },
                                    { t: "Parámetros", w: 0.9 }
                                ]
                                delegate: Text {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: modelData.w * 100
                                    text: modelData.t
                                    color: Style.Theme.texto_secundario
                                    font.bold: true
                                    font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        Repeater {
                            model: root.listaDe(root.arquitecturaActual, ["bloques", "blocks"])
                            delegate: Rectangle {
                                id: filaBloque
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 31 * root.sy
                                color: index % 2 === 0 ? "#F8FAFC" : "#FFFFFF"
                                radius: 4 * root.sx
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8 * root.sx
                                    anchors.rightMargin: 8 * root.sx
                                    spacing: 8 * root.sx
                                    Repeater {
                                        model: [
                                            { v: root.campo(filaBloque.modelData, ["nombre", "name", "bloque"], "Bloque"), w: 1.4 },
                                            { v: root.campo(filaBloque.modelData, ["shapeEntrada", "entrada", "inputShape", "input"], "No registrado"), w: 1 },
                                            { v: root.campo(filaBloque.modelData, ["shapeSalida", "salida", "outputShape", "output"], "No registrado"), w: 1 },
                                            { v: root.campo(filaBloque.modelData, ["repeticiones", "repeat", "veces"], "—"), w: 0.7 },
                                            { v: root.numeroLegible(root.campo(filaBloque.modelData, ["parametros", "parameters", "parameterCount"], null)), w: 0.9 }
                                        ]
                                        delegate: Text {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: modelData.w * 100
                                            text: root.texto(modelData.v, "No registrado")
                                            color: Style.Theme.texto_primario
                                            font.family: "monospace"
                                            font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: root.listaDe(root.arquitecturaActual, ["bloques", "blocks"]).length === 0
                            text: "El archivo no incluye un desglose de parámetros por bloque."
                            color: Style.Theme.texto_secundario
                            horizontalAlignment: Text.AlignHCenter
                            font.italic: true
                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                        }
                    }
                }

                RectanglePrincipal {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(130 * root.sy,
                                                      52 * root.sy + root.listaDe(root.arquitecturaActual,
                                                                                 ["tensores", "tensors"]).length * 32 * root.sy)
                    sx: root.sx
                    sy: root.sy
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14 * root.sx
                        spacing: 4 * root.sy
                        Text {
                            text: "DIMENSIONES DE TENSORES EN EL FLUJO"
                            color: "#6D28D9"
                            font.bold: true
                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                        }
                        Repeater {
                            model: root.listaDe(root.arquitecturaActual, ["tensores", "tensors"])
                            delegate: Rectangle {
                                id: filaTensor
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 29 * root.sy
                                color: index % 2 === 0 ? "#F8FAFC" : "transparent"
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8 * root.sx
                                    anchors.rightMargin: 8 * root.sx
                                    Text {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 300 * root.sx
                                        text: root.campo(filaTensor.modelData, ["nombre", "name", "tensor"], "Tensor")
                                        color: Style.Theme.texto_primario
                                        font.family: "monospace"
                                        font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                        elide: Text.ElideMiddle
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: "shape " + root.texto(root.campo(filaTensor.modelData,
                                                                               ["shape", "forma", "dimensiones", "valor"], null),
                                                                     "no registrado")
                                        color: Style.Theme.texto_secundario
                                        font.family: "monospace"
                                        font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.preferredWidth: 160 * root.sx
                                        text: root.texto(root.campo(filaTensor.modelData, ["dtype", "tipo"], null), "dtype no registrado")
                                        color: Style.Theme.texto_secundario
                                        font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: root.listaDe(root.arquitecturaActual, ["tensores", "tensors"]).length === 0
                            text: "Este formato no describe las dimensiones de los tensores del flujo."
                            color: Style.Theme.texto_secundario
                            horizontalAlignment: Text.AlignHCenter
                            font.italic: true
                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                        }
                    }
                }
            }
        }

        // -----------------------------------------------------------------
        // Procedencia
        // -----------------------------------------------------------------
        ScrollView {
            id: scrollProcedencia
            clip: true
            contentWidth: availableWidth
            ColumnLayout {
                width: scrollProcedencia.availableWidth
                spacing: 14 * root.sy

                RectanglePrincipal {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.campo(root.procedenciaActual,
                                                       ["telemetria_procedencia_completa", "telemetriaProcedenciaCompleta"],
                                                       true) === false ? 132 * root.sy : 105 * root.sy
                    sx: root.sx
                    sy: root.sy
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16 * root.sx
                        spacing: 16 * root.sx
                        Rectangle {
                            Layout.preferredWidth: 54 * root.sy
                            Layout.preferredHeight: 54 * root.sy
                            radius: width / 2
                            color: "#EDE9FE"
                            Text { anchors.centerIn: parent; text: "↗"; color: "#6D28D9"; font.pixelSize: 25 * root.sy }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Procedencia del entrenamiento"
                                color: Style.Theme.texto_primario
                                font.bold: true
                                font.pixelSize: 18 * Math.min(root.sx, root.sy)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Esta ficha sólo presenta metadatos contenidos en el modelo o su sidecar. Un campo ausente no se interpreta como cero."
                                color: Style.Theme.texto_secundario
                                wrapMode: Text.WordWrap
                                font.pixelSize: 12 * Math.min(root.sx, root.sy)
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: root.campo(root.procedenciaActual,
                                                    ["telemetria_procedencia_completa", "telemetriaProcedenciaCompleta"],
                                                    true) === false
                                text: "⚠ Telemetría parcial"
                                      + (root.tiene(root.campo(root.procedenciaActual,
                                                               ["telemetria_desde_paso", "telemetriaDesdePaso", "paso_inicio_telemetria"], null))
                                         ? ": registrada desde el paso "
                                           + root.campo(root.procedenciaActual,
                                                        ["telemetria_desde_paso", "telemetriaDesdePaso", "paso_inicio_telemetria"], "")
                                         : ": el checkpoint no conserva toda la procedencia de sesiones anteriores.")
                                color: "#B45309"
                                font.bold: true
                                font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: scrollProcedencia.availableWidth > 900 * root.sx ? 4 : 2
                    columnSpacing: 12 * root.sx
                    rowSpacing: 12 * root.sy
                    Repeater {
                        model: [
                            { e: "Tarea", v: root.campo(root.procedenciaActual, ["tarea", "task"], null) },
                            { e: "Ejemplos vistos", v: root.numeroLegible(root.campo(root.procedenciaActual, ["ejemplosVistos", "ejemplos_vistos", "examplesSeen"], null)) },
                            { e: "Tokens de origen vistos", v: root.numeroLegible(root.campo(root.procedenciaActual, ["tokensOrigenVistos", "tokens_origen_vistos", "sourceTokensSeen", "tokensVistos", "tokensSeen"], null)) },
                            { e: "Tokens objetivo vistos", v: root.numeroLegible(root.campo(root.procedenciaActual, ["tokensObjetivoVistos", "tokens_objetivo_vistos", "targetTokensSeen"], null)) },
                            { e: "Learning rate", v: root.texto(root.campo(root.procedenciaActual, ["learningRate", "learning_rate", "lr"], null), "No registrado") },
                            { e: "Batch size", v: root.texto(root.campo(root.procedenciaActual, ["batchSize", "batch_size"], null), "No registrado") },
                            { e: "Semilla", v: root.texto(root.campo(root.procedenciaActual, ["semilla", "seed"], null), "No registrada") },
                            { e: "Primera sesión", v: root.texto(root.campo(root.procedenciaActual, ["primera_sesion_inicio_utc", "primeraSesionInicioUtc"], null), "No registrada") },
                            { e: "Última sesión iniciada", v: root.texto(root.campo(root.procedenciaActual, ["ultima_sesion_inicio_utc", "ultimaSesionInicioUtc"], null), "No registrada") },
                            { e: "Última sesión finalizada", v: root.texto(root.campo(root.procedenciaActual, ["ultima_sesion_fin_utc", "ultimaSesionFinUtc"], null), "No registrada") },
                            { e: "Duración entrenando", v: root.duracionLegible(root.campo(root.procedenciaActual, ["duracion_entrenamiento_segundos", "duracion", "duration"], null)) },
                            { e: "Checkpoint creado/guardado", v: root.texto(root.campo(root.procedenciaActual, ["creado_en", "created_at", "fecha", "date"], null), "No registrada") }
                        ]
                        delegate: RectanglePrincipal {
                            id: procedenciaMetrica
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 92 * root.sy
                            sx: root.sx
                            sy: root.sy
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 13 * root.sx
                                Text {
                                    Layout.fillWidth: true
                                    text: procedenciaMetrica.modelData.e
                                    color: Style.Theme.texto_secundario
                                    font.pixelSize: 11 * Math.min(root.sx, root.sy)
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: procedenciaMetrica.modelData.v
                                    color: Style.Theme.texto_primario
                                    font.bold: true
                                    font.pixelSize: 15 * Math.min(root.sx, root.sy)
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                RectanglePrincipal {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(145 * root.sy,
                                                      70 * root.sy + root.listaDe(root.procedenciaActual,
                                                                                 ["datasets", "dataSets", "fuentes"]).length * 42 * root.sy)
                    sx: root.sx
                    sy: root.sy
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16 * root.sx
                        spacing: 7 * root.sy
                        Text {
                            text: "DATASETS UTILIZADOS"
                            color: "#6D28D9"
                            font.bold: true
                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                        }
                        Repeater {
                            model: root.listaDe(root.procedenciaActual, ["datasets", "dataSets", "fuentes"])
                            delegate: Rectangle {
                                id: datasetItem
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38 * root.sy
                                radius: 6 * root.sx
                                color: "#F8FAFC"
                                border.color: "#E5E7EB"
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10 * root.sx
                                    anchors.rightMargin: 10 * root.sx
                                    Text { text: "▤"; color: "#7C3AED"; font.pixelSize: 15 * root.sy }
                                    Text {
                                        Layout.fillWidth: true
                                        text: typeof datasetItem.modelData === "object"
                                              ? root.texto(root.campo(datasetItem.modelData,
                                                                      ["nombre", "name", "ruta", "path", "id"], null),
                                                            "Dataset sin nombre")
                                              : String(datasetItem.modelData)
                                        color: Style.Theme.texto_primario
                                        font.pixelSize: 12 * Math.min(root.sx, root.sy)
                                        elide: Text.ElideMiddle
                                    }
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: root.listaDe(root.procedenciaActual, ["datasets", "dataSets", "fuentes"]).length === 0
                            text: "No se registraron los datasets utilizados."
                            color: Style.Theme.texto_secundario
                            horizontalAlignment: Text.AlignHCenter
                            font.italic: true
                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                        }
                    }
                }
            }
        }

        // -----------------------------------------------------------------
        // Historial
        // -----------------------------------------------------------------
        ScrollView {
            id: scrollHistorial
            clip: true
            contentWidth: availableWidth
            ColumnLayout {
                width: scrollHistorial.availableWidth
                spacing: 14 * root.sy

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 370 * root.sy
                    spacing: 14 * root.sx

                    RectanglePrincipal {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        sx: root.sx
                        sy: root.sy
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16 * root.sx
                            spacing: 8 * root.sy
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: "CURVA COMPLETA DE PÉRDIDA"
                                    color: "#6D28D9"
                                    font.bold: true
                                    font.pixelSize: 12 * Math.min(root.sx, root.sy)
                                }
                                Text {
                                    text: root.puntosPerdida().length + " puntos"
                                    color: Style.Theme.texto_secundario
                                    font.pixelSize: 11 * Math.min(root.sx, root.sy)
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 7 * root.sx
                                color: "#FAFAFA"
                                border.color: "#E5E7EB"
                                Canvas {
                                    id: lossCanvas
                                    anchors.fill: parent
                                    anchors.margins: 9 * root.sx

                                    onWidthChanged: requestPaint()
                                    onHeightChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.reset()
                                        var puntos = root.puntosPerdida()
                                        var left = 43 * root.sx
                                        var right = width - 12 * root.sx
                                        var top = 13 * root.sy
                                        var bottom = height - 30 * root.sy
                                        ctx.strokeStyle = "#CBD5E1"
                                        ctx.lineWidth = 1
                                        ctx.beginPath()
                                        ctx.moveTo(left, top)
                                        ctx.lineTo(left, bottom)
                                        ctx.lineTo(right, bottom)
                                        ctx.stroke()
                                        if (puntos.length === 0)
                                            return
                                        var minX = puntos[0].x, maxX = puntos[0].x
                                        var minY = puntos[0].y, maxY = puntos[0].y
                                        for (var i = 1; i < puntos.length; ++i) {
                                            minX = Math.min(minX, puntos[i].x)
                                            maxX = Math.max(maxX, puntos[i].x)
                                            minY = Math.min(minY, puntos[i].y)
                                            maxY = Math.max(maxY, puntos[i].y)
                                        }
                                        if (maxX === minX) maxX = minX + 1
                                        if (maxY === minY) maxY = minY + 1
                                        ctx.strokeStyle = "#7C3AED"
                                        ctx.lineWidth = 2.2 * Math.min(root.sx, root.sy)
                                        ctx.beginPath()
                                        for (var j = 0; j < puntos.length; ++j) {
                                            var px = left + (puntos[j].x - minX) / (maxX - minX) * (right - left)
                                            var py = bottom - (puntos[j].y - minY) / (maxY - minY) * (bottom - top)
                                            if (j === 0) ctx.moveTo(px, py)
                                            else ctx.lineTo(px, py)
                                        }
                                        ctx.stroke()
                                        ctx.fillStyle = "#64748B"
                                        ctx.font = Math.max(9, 10 * Math.min(root.sx, root.sy)) + "px sans-serif"
                                        ctx.fillText(maxY.toFixed(4), 2, top + 8)
                                        ctx.fillText(minY.toFixed(4), 2, bottom)
                                        ctx.fillText(String(minX), left, height - 8)
                                        var etiquetaMaxX = String(maxX)
                                        ctx.fillText(etiquetaMaxX, right - ctx.measureText(etiquetaMaxX).width, height - 8)
                                    }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: root.puntosPerdida().length === 0
                                    width: parent.width - 30 * root.sx
                                    text: root.texto(root.campo(root.historialActual, ["mensaje", "message"], null),
                                                     "El checkpoint sólo conserva la pérdida final; no hay una serie para graficar.")
                                    color: Style.Theme.texto_secundario
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    font.italic: true
                                    font.pixelSize: 12 * Math.min(root.sx, root.sy)
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: Math.min(450 * root.sx,
                                                        scrollHistorial.availableWidth * 0.34)
                        Layout.fillHeight: true
                        spacing: 10 * root.sy
                        Repeater {
                            model: [
                                { e: "Época", v: root.campo(root.historialActual, ["epoca", "epoch"], root.campo(root.descriptorActual, ["epoca"], null)) },
                                { e: "Paso global", v: root.campo(root.historialActual, ["pasoGlobal", "paso_global", "globalStep"], root.campo(root.descriptorActual, ["paso_global"], null)) },
                                { e: "Pérdida de entrenamiento", v: root.resumenSerie(root.campo(root.historialActual, ["perdidas", "losses"], [])) },
                                { e: "Validación", v: root.resumenSerie(root.campo(root.historialActual, ["validacion", "validation"], [])) },
                                { e: "Perplexity", v: root.resumenSerie(root.campo(root.historialActual, ["perplexity", "perplejidad"], [])) },
                                { e: "Precisión", v: root.resumenSerie(root.campo(root.historialActual, ["precision", "accuracy"], [])) }
                            ]
                            delegate: RectanglePrincipal {
                                id: historiaMetrica
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                sx: root.sx
                                sy: root.sy
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 13 * root.sx
                                    anchors.rightMargin: 13 * root.sx
                                    Text {
                                        Layout.fillWidth: true
                                        text: historiaMetrica.modelData.e
                                        color: Style.Theme.texto_secundario
                                        font.pixelSize: 11 * Math.min(root.sx, root.sy)
                                    }
                                    Text {
                                        Layout.preferredWidth: 190 * root.sx
                                        text: root.texto(historiaMetrica.modelData.v, "No registrado")
                                        color: Style.Theme.texto_primario
                                        font.bold: true
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideRight
                                        font.pixelSize: 11 * Math.min(root.sx, root.sy)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58 * root.sy
                    radius: 8 * root.sx
                    color: "#FFFBEB"
                    border.color: "#FDE68A"
                    Text {
                        anchors.fill: parent
                        anchors.margins: 12 * root.sx
                        text: "Una pérdida final aislada no mide generalización. Validación, perplexity y precisión sólo aparecen si fueron calculadas y guardadas; no se deducen de la pérdida de entrenamiento."
                        color: "#78350F"
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 11 * Math.min(root.sx, root.sy)
                    }
                }

                RectanglePrincipal {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(140 * root.sy,
                                                      68 * root.sy + root.listaDe(root.historialActual,
                                                                                 ["checkpoints", "puntosGuardados"]).length * 42 * root.sy)
                    sx: root.sx
                    sy: root.sy
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15 * root.sx
                        spacing: 6 * root.sy
                        Text {
                            text: "CHECKPOINTS DEL EXPERIMENTO"
                            color: "#6D28D9"
                            font.bold: true
                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                        }
                        Repeater {
                            model: root.listaDe(root.historialActual, ["checkpoints", "puntosGuardados"])
                            delegate: Rectangle {
                                id: checkpointItem
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38 * root.sy
                                color: "#F8FAFC"
                                radius: 6 * root.sx
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10 * root.sx
                                    anchors.rightMargin: 10 * root.sx
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.texto(root.campo(checkpointItem.modelData,
                                                                   ["nombre", "name", "archivo", "ruta"], null),
                                                         typeof checkpointItem.modelData === "string"
                                                         ? checkpointItem.modelData : "Checkpoint")
                                        color: Style.Theme.texto_primario
                                        elide: Text.ElideMiddle
                                        font.pixelSize: 11 * Math.min(root.sx, root.sy)
                                    }
                                    Text {
                                        text: "época " + root.texto(root.campo(checkpointItem.modelData, ["epoca", "epoch"], null), "—")
                                              + " · loss " + root.decimalLegible(root.campo(checkpointItem.modelData, ["perdida", "loss"], null), 4)
                                        color: Style.Theme.texto_secundario
                                        font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                    }
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: root.listaDe(root.historialActual, ["checkpoints", "puntosGuardados"]).length === 0
                            text: "No se encontraron checkpoints vinculados a este experimento."
                            color: Style.Theme.texto_secundario
                            horizontalAlignment: Text.AlignHCenter
                            font.italic: true
                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                        }
                    }
                }
            }
        }

        // -----------------------------------------------------------------
        // Laboratorio del tokenizador
        // -----------------------------------------------------------------
        ScrollView {
            id: scrollTokenizador
            clip: true
            contentWidth: availableWidth
            ColumnLayout {
                width: scrollTokenizador.availableWidth
                spacing: 14 * root.sy

                RectanglePrincipal {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 215 * root.sy
                    sx: root.sx
                    sy: root.sy
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16 * root.sx
                        spacing: 9 * root.sy
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: "LABORATORIO DEL TOKENIZADOR"
                                color: "#6D28D9"
                                font.bold: true
                                font.pixelSize: 12 * Math.min(root.sx, root.sy)
                            }
                            Text {
                                text: "Encoding: " + root.texto(root.campo(root.tokenizacion, ["encoding"],
                                                                          root.campo(root.descriptorActual, ["encoding"], null)),
                                                                "No registrado")
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 11 * Math.min(root.sx, root.sy)
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Observa cómo el texto se divide realmente antes de entrar al Transformer. Los espacios se representan con ·."
                            color: Style.Theme.texto_secundario
                            wrapMode: Text.WordWrap
                            font.pixelSize: 11 * Math.min(root.sx, root.sy)
                        }
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            TextArea {
                                id: campoTextoTokenizador
                                placeholderText: "Escribe una frase, símbolos, saltos de línea o texto multilingüe…"
                                wrapMode: TextEdit.Wrap
                                selectByMouse: true
                                font.pixelSize: 14 * Math.min(root.sx, root.sy)
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: root.errorTokenizacion
                                visible: text !== ""
                                color: Style.Theme.error
                                elide: Text.ElideRight
                                font.pixelSize: 11 * Math.min(root.sx, root.sy)
                            }
                            BusyIndicator {
                                Layout.preferredWidth: 28 * root.sy
                                Layout.preferredHeight: 28 * root.sy
                                running: root.cargandoTokenizacion
                                visible: running
                            }
                            BotonPrincipal {
                                Layout.preferredWidth: 175 * root.sx
                                Layout.preferredHeight: 38 * root.sy
                                text: root.cargandoTokenizacion ? "Analizando…" : "Analizar tokens"
                                size_text: 0.25
                                enabled: !root.cargandoTokenizacion && !(root.controller && root.controller.ocupado)
                                opacity: enabled ? 1 : 0.5
                                onClicked: root.analizarTexto()
                            }
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    columnSpacing: 10 * root.sx
                    rowSpacing: 10 * root.sy
                    Repeater {
                        model: [
                            { e: "Tokens", v: root.campo(root.tokenizacion, ["conteoTokens", "tokenCount"], null) },
                            { e: "Contexto máximo", v: root.campo(root.tokenizacion, ["contexto", "contextLength"], root.campoCombinado(["contexto"], null)) },
                            { e: "Contexto ocupado", v: root.porcentajeLegible(root.campo(root.tokenizacion, ["porcentajeContexto", "contextPercentage"], null)) },
                            { e: "Excede contexto", v: root.booleanoTexto(root.campo(root.tokenizacion, ["excedeContexto", "exceedsContext"], null)) }
                        ]
                        delegate: RectanglePrincipal {
                            id: tokenMetrica
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 78 * root.sy
                            sx: root.sx
                            sy: root.sy
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 11 * root.sx
                                Text { text: tokenMetrica.modelData.e; color: Style.Theme.texto_secundario; font.pixelSize: 10 * Math.min(root.sx, root.sy) }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.texto(tokenMetrica.modelData.v, "Sin analizar")
                                    color: Style.Theme.texto_primario
                                    font.bold: true
                                    font.pixelSize: 14 * Math.min(root.sx, root.sy)
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 47 * root.sy
                    visible: root.especialesComoTexto() !== ""
                    radius: 7 * root.sx
                    color: "#FFFBEB"
                    border.color: "#FDE68A"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 13 * root.sx
                        anchors.rightMargin: 13 * root.sx
                        Text {
                            text: "Tokens especiales"
                            color: "#92400E"
                            font.bold: true
                            font.pixelSize: 10 * Math.min(root.sx, root.sy)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.especialesComoTexto()
                            color: "#78350F"
                            font.family: "monospace"
                            font.pixelSize: 11 * Math.min(root.sx, root.sy)
                            elide: Text.ElideRight
                        }
                    }
                }

                RectanglePrincipal {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(155 * root.sy,
                                                      70 * root.sy + root.listaDe(root.tokenizacion,
                                                                                 ["tokens"]).length * 38 * root.sy)
                    sx: root.sx
                    sy: root.sy
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14 * root.sx
                        spacing: 5 * root.sy
                        Text {
                            text: "DESGLOSE TOKEN A TOKEN"
                            color: "#6D28D9"
                            font.bold: true
                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24 * root.sy
                            Text { Layout.preferredWidth: 55 * root.sx; text: "#"; color: Style.Theme.texto_secundario; font.bold: true }
                            Text { Layout.preferredWidth: 120 * root.sx; text: "ID"; color: Style.Theme.texto_secundario; font.bold: true }
                            Text { Layout.fillWidth: true; text: "Token visible"; color: Style.Theme.texto_secundario; font.bold: true }
                            Text { Layout.preferredWidth: 190 * root.sx; text: "Caracteres"; color: Style.Theme.texto_secundario; font.bold: true }
                            Text { Layout.preferredWidth: 180 * root.sx; text: "Especial"; color: Style.Theme.texto_secundario; font.bold: true }
                        }
                        Repeater {
                            model: root.listaDe(root.tokenizacion, ["tokens"])
                            delegate: Rectangle {
                                id: tokenItem
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 35 * root.sy
                                radius: 5 * root.sx
                                color: root.campo(tokenItem.modelData, ["esEspecial", "special"], false)
                                       ? "#FEF3C7" : (index % 2 === 0 ? "#F8FAFC" : "transparent")
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 7 * root.sx
                                    anchors.rightMargin: 7 * root.sx
                                    Text {
                                        Layout.preferredWidth: 55 * root.sx
                                        text: root.campo(tokenItem.modelData, ["indice", "index"], tokenItem.index)
                                        color: Style.Theme.texto_secundario
                                        font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                    }
                                    Text {
                                        Layout.preferredWidth: 120 * root.sx
                                        text: root.campo(tokenItem.modelData, ["id", "tokenId"], "—")
                                        color: "#5B21B6"
                                        font.family: "monospace"
                                        font.bold: true
                                        font.pixelSize: 11 * Math.min(root.sx, root.sy)
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.tokenVisible(root.campo(tokenItem.modelData, ["texto", "text", "token"], null))
                                        color: Style.Theme.texto_primario
                                        font.family: "monospace"
                                        elide: Text.ElideRight
                                        font.pixelSize: 11 * Math.min(root.sx, root.sy)
                                    }
                                    Text {
                                        Layout.preferredWidth: 190 * root.sx
                                        text: root.caracteresLegibles(root.campo(tokenItem.modelData, ["caracteres", "characters", "span"], null))
                                        color: Style.Theme.texto_secundario
                                        elide: Text.ElideRight
                                        font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                    }
                                    Text {
                                        Layout.preferredWidth: 180 * root.sx
                                        text: root.campo(tokenItem.modelData, ["esEspecial", "special"], false)
                                              ? root.texto(root.campo(tokenItem.modelData, ["nombreEspecial", "specialName"], null), "Sí")
                                              : "No"
                                        color: root.campo(tokenItem.modelData, ["esEspecial", "special"], false) ? "#92400E" : Style.Theme.texto_secundario
                                        font.bold: root.campo(tokenItem.modelData, ["esEspecial", "special"], false)
                                        elide: Text.ElideRight
                                        font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                    }
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: root.listaDe(root.tokenizacion, ["tokens"]).length === 0
                            text: "Escribe un texto y pulsa «Analizar tokens» para ver IDs, caracteres y tokens especiales."
                            color: Style.Theme.texto_secundario
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            font.italic: true
                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                        }
                    }
                }
            }
        }

        // -----------------------------------------------------------------
        // Salud
        // -----------------------------------------------------------------
        ScrollView {
            id: scrollSalud
            clip: true
            contentWidth: availableWidth
            ColumnLayout {
                width: scrollSalud.availableWidth
                spacing: 14 * root.sy

                RectanglePrincipal {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150 * root.sy
                    sx: root.sx
                    sy: root.sy
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 17 * root.sx
                        spacing: 18 * root.sx
                        Rectangle {
                            Layout.preferredWidth: 70 * root.sy
                            Layout.preferredHeight: 70 * root.sy
                            radius: width / 2
                            color: "#ECFDF5"
                            Text { anchors.centerIn: parent; text: "♥"; color: "#059669"; font.pixelSize: 30 * root.sy }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Prueba rápida de salud"
                                color: Style.Theme.texto_primario
                                font.bold: true
                                font.pixelSize: 19 * Math.min(root.sx, root.sy)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Ejecuta prompts deterministas pequeños para detectar NaN, repetición, ausencia de EOS y problemas de velocidad o confianza. La coherencia semántica no se califica automáticamente."
                                color: Style.Theme.texto_secundario
                                wrapMode: Text.WordWrap
                                font.pixelSize: 12 * Math.min(root.sx, root.sy)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.errorSalud
                                visible: text !== ""
                                color: Style.Theme.error
                                elide: Text.ElideRight
                                font.pixelSize: 11 * Math.min(root.sx, root.sy)
                            }
                        }
                        BusyIndicator {
                            Layout.preferredWidth: 38 * root.sy
                            Layout.preferredHeight: 38 * root.sy
                            running: root.cargandoSalud
                            visible: running
                        }
                        BotonPrincipal {
                            Layout.preferredWidth: 205 * root.sx
                            Layout.preferredHeight: 47 * root.sy
                            text: root.cargandoSalud ? "Ejecutando…" : "Ejecutar diagnóstico"
                            size_text: 0.23
                            enabled: !root.cargandoSalud && !(root.controller && root.controller.ocupado)
                            opacity: enabled ? 1 : 0.5
                            onClicked: root.ejecutarSalud()
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 5
                    columnSpacing: 9 * root.sx
                    rowSpacing: 9 * root.sy
                    Repeater {
                        model: {
                            var resumen = root.campo(root.salud, ["resumen", "summary"], {})
                            return [
                                { e: "Muestras", v: root.campo(resumen, ["muestras", "total", "sampleCount"], root.listaDe(root.salud, ["muestras", "samples"]).length || null) },
                                { e: "NaN detectado", v: root.booleanoTexto(root.campo(resumen, ["hayNaN", "hasNaN", "nan"], null)) },
                                { e: "EOS observado", v: root.probabilidadLegible(root.campo(resumen, ["tasaEOS", "eosRate"], null)) },
                                { e: "Latencia media", v: root.tiene(root.campo(resumen, ["latenciaMediaMs", "averageLatencyMs"], null)) ? root.decimalLegible(root.campo(resumen, ["latenciaMediaMs", "averageLatencyMs"], null), 1) + " ms" : "No registrada" },
                                { e: "Repetición media", v: root.probabilidadLegible(root.campo(resumen, ["tasaRepeticionMedia", "averageRepetitionRate"], null)) }
                            ]
                        }
                        delegate: RectanglePrincipal {
                            id: saludMetrica
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 82 * root.sy
                            sx: root.sx
                            sy: root.sy
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 11 * root.sx
                                Text { text: saludMetrica.modelData.e; color: Style.Theme.texto_secundario; font.pixelSize: 10 * Math.min(root.sx, root.sy) }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.texto(saludMetrica.modelData.v, "Sin ejecutar")
                                    color: Style.Theme.texto_primario
                                    font.bold: true
                                    elide: Text.ElideRight
                                    font.pixelSize: 13 * Math.min(root.sx, root.sy)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 68 * root.sy
                    radius: 8 * root.sx
                    color: "#EFF6FF"
                    border.color: "#BFDBFE"
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12 * root.sx
                        Text { text: "ⓘ"; color: "#1D4ED8"; font.pixelSize: 20 * root.sy }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Text { text: "Coherencia"; color: "#1E40AF"; font.bold: true; font.pixelSize: 11 * Math.min(root.sx, root.sy) }
                            Text {
                                Layout.fillWidth: true
                                text: root.texto(root.campo(root.campo(root.salud, ["coherencia", "coherence"], {}),
                                                                   ["mensaje", "message"], null),
                                                 "No evaluada automáticamente: requiere revisión humana de las salidas.")
                                color: "#1E3A8A"
                                wrapMode: Text.WordWrap
                                font.pixelSize: 11 * Math.min(root.sx, root.sy)
                            }
                        }
                    }
                }

                Repeater {
                    model: root.listaDe(root.salud, ["muestras", "samples"])
                    delegate: RectanglePrincipal {
                        id: muestraSalud
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 235 * root.sy
                        sx: root.sx
                        sy: root.sy
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 15 * root.sx
                            spacing: 7 * root.sy
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: "MUESTRA " + (muestraSalud.index + 1)
                                    color: "#6D28D9"
                                    font.bold: true
                                    font.pixelSize: 11 * Math.min(root.sx, root.sy)
                                }
                                Rectangle {
                                    Layout.preferredWidth: estadoMuestra.implicitWidth + 16 * root.sx
                                    Layout.preferredHeight: 24 * root.sy
                                    radius: height / 2
                                    color: root.tiene(root.campo(muestraSalud.modelData, ["error"], null))
                                           || root.campo(muestraSalud.modelData, ["hayNaN", "hasNaN"], false)
                                           ? "#FEE2E2" : "#DCFCE7"
                                    Text {
                                        id: estadoMuestra
                                        anchors.centerIn: parent
                                        text: root.tiene(root.campo(muestraSalud.modelData, ["error"], null))
                                              ? "Error" : (root.campo(muestraSalud.modelData, ["hayNaN", "hasNaN"], false) ? "NaN" : "Sin NaN")
                                        color: text === "Sin NaN" ? "#166534" : "#991B1B"
                                        font.bold: true
                                        font.pixelSize: 9 * Math.min(root.sx, root.sy)
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Prompt: " + root.texto(root.campo(muestraSalud.modelData, ["prompt", "entrada"], null), "No registrado")
                                color: Style.Theme.texto_primario
                                font.bold: true
                                elide: Text.ElideRight
                                font.pixelSize: 12 * Math.min(root.sx, root.sy)
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: "#F8FAFC"
                                border.color: "#E5E7EB"
                                radius: 6 * root.sx
                                ScrollView {
                                    anchors.fill: parent
                                    anchors.margins: 6 * root.sx
                                    clip: true
                                    TextArea {
                                        text: root.texto(root.campo(muestraSalud.modelData, ["salida", "output"], null), "Sin salida")
                                        readOnly: true
                                        selectByMouse: true
                                        wrapMode: TextEdit.Wrap
                                        color: Style.Theme.texto_primario
                                        font.pixelSize: 12 * Math.min(root.sx, root.sy)
                                        background: Rectangle { color: "transparent" }
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 18 * root.sx
                                Text { text: "Tokens: " + root.conteoLegible(root.campo(muestraSalud.modelData, ["tokens", "tokenCount"], null)); color: Style.Theme.texto_secundario }
                                Text { text: "Latencia: " + (root.tiene(root.campo(muestraSalud.modelData, ["latenciaMs", "latencyMs"], null)) ? root.decimalLegible(root.campo(muestraSalud.modelData, ["latenciaMs", "latencyMs"], null), 1) + " ms" : "—"); color: Style.Theme.texto_secundario }
                                Text { text: "ms/token: " + root.decimalLegible(root.campo(muestraSalud.modelData, ["msPorToken", "msPerToken"], null), 2); color: Style.Theme.texto_secundario }
                                Text { text: "EOS: " + root.booleanoTexto(root.campo(muestraSalud.modelData, ["eos"], null)); color: Style.Theme.texto_secundario }
                                Text { text: "Confianza: " + root.probabilidadLegible(root.campo(muestraSalud.modelData, ["confianzaMedia", "averageConfidence"], null)); color: Style.Theme.texto_secundario }
                                Text { text: "Repetición: " + root.probabilidadLegible(root.campo(muestraSalud.modelData, ["tasaRepeticion", "repetitionRate"], null)); color: Style.Theme.texto_secundario }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 35 * root.sy
                    visible: root.listaDe(root.salud, ["muestras", "samples"]).length === 0 && !root.cargandoSalud
                    text: "Todavía no se ha ejecutado el diagnóstico para este modelo."
                    color: Style.Theme.texto_secundario
                    horizontalAlignment: Text.AlignHCenter
                    font.italic: true
                    font.pixelSize: 13 * Math.min(root.sx, root.sy)
                }

                Repeater {
                    model: root.listaDe(root.salud, ["advertencias", "warnings"])
                    delegate: Rectangle {
                        id: advertenciaSalud
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42 * root.sy
                        radius: 7 * root.sx
                        color: "#FFF7ED"
                        border.color: "#FDBA74"
                        Text {
                            anchors.fill: parent
                            anchors.margins: 10 * root.sx
                            text: "⚠ " + (typeof advertenciaSalud.modelData === "object"
                                          ? root.campo(advertenciaSalud.modelData,
                                                       ["mensaje", "message"], "Advertencia")
                                          : advertenciaSalud.modelData)
                            color: "#9A3412"
                            elide: Text.ElideRight
                            font.pixelSize: 11 * Math.min(root.sx, root.sy)
                        }
                    }
                }
            }
        }

        // -----------------------------------------------------------------
        // Versiones y metadatos
        // -----------------------------------------------------------------
        ScrollView {
            id: scrollVersiones
            clip: true
            contentWidth: availableWidth
            ColumnLayout {
                width: scrollVersiones.availableWidth
                spacing: 14 * root.sy

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 395 * root.sy
                    spacing: 14 * root.sx

                    RectanglePrincipal {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        sx: root.sx
                        sy: root.sy
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16 * root.sx
                            spacing: 9 * root.sy
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: "FICHA EDITABLE"
                                    color: "#6D28D9"
                                    font.bold: true
                                    font.pixelSize: 12 * Math.min(root.sx, root.sy)
                                }
                                Text {
                                    text: root.esModeloActivo() ? "● Activo" : "○ No activo"
                                    color: root.esModeloActivo() ? "#15803D" : Style.Theme.texto_secundario
                                    font.bold: true
                                    font.pixelSize: 11 * Math.min(root.sx, root.sy)
                                }
                            }
                            Text { text: "Nombre visible"; color: Style.Theme.texto_secundario; font.pixelSize: 10 * Math.min(root.sx, root.sy) }
                            TextField {
                                id: campoNombre
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38 * root.sy
                                placeholderText: "Nombre del modelo"
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10 * root.sx
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Grupo / experimento"; color: Style.Theme.texto_secundario; font.pixelSize: 10 * Math.min(root.sx, root.sy) }
                                    TextField { id: campoGrupo; Layout.fillWidth: true; placeholderText: "Ej. ablación_dropout" }
                                }
                                ColumnLayout {
                                    Layout.preferredWidth: 220 * root.sx
                                    Text { text: "Versión"; color: Style.Theme.texto_secundario; font.pixelSize: 10 * Math.min(root.sx, root.sy) }
                                    TextField { id: campoVersion; Layout.fillWidth: true; placeholderText: "Ej. v3 o época 12" }
                                }
                            }
                            Text { text: "Etiquetas (separadas por comas)"; color: Style.Theme.texto_secundario; font.pixelSize: 10 * Math.min(root.sx, root.sy) }
                            TextField {
                                id: campoTags
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38 * root.sy
                                placeholderText: "estable, español, experimento-2"
                            }
                            Text { text: "Notas"; color: Style.Theme.texto_secundario; font.pixelSize: 10 * Math.min(root.sx, root.sy) }
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                TextArea {
                                    id: campoNotas
                                    placeholderText: "Hipótesis, cambios, resultados observados…"
                                    wrapMode: TextEdit.Wrap
                                    selectByMouse: true
                                    font.pixelSize: 12 * Math.min(root.sx, root.sy)
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }
                                BotonPrincipal {
                                    Layout.preferredWidth: 135 * root.sx
                                    Layout.preferredHeight: 36 * root.sy
                                    text: "Renombrar"
                                    size_text: 0.25
                                    enabled: !root.guardandoMetadata && !(root.controller && root.controller.ocupado)
                                    onClicked: root.renombrar()
                                }
                                BotonPrincipal {
                                    Layout.preferredWidth: 175 * root.sx
                                    Layout.preferredHeight: 36 * root.sy
                                    text: root.guardandoMetadata ? "Guardando…" : "Guardar ficha"
                                    size_text: 0.24
                                    enabled: !root.guardandoMetadata && !(root.controller && root.controller.ocupado)
                                    onClicked: root.guardarMetadata()
                                }
                            }
                        }
                    }

                    RectanglePrincipal {
                        Layout.preferredWidth: Math.min(470 * root.sx,
                                                        scrollVersiones.availableWidth * 0.36)
                        Layout.fillHeight: true
                        sx: root.sx
                        sy: root.sy
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16 * root.sx
                            spacing: 9 * root.sy
                            Text {
                                text: "CREAR UNA VERSIÓN DERIVADA"
                                color: "#6D28D9"
                                font.bold: true
                                font.pixelSize: 12 * Math.min(root.sx, root.sy)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Duplica el archivo sin sobrescribir el original. Después podrás editar el grupo, versión y notas de la copia."
                                color: Style.Theme.texto_secundario
                                wrapMode: Text.WordWrap
                                font.pixelSize: 11 * Math.min(root.sx, root.sy)
                            }
                            TextField {
                                id: campoDuplicado
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40 * root.sy
                                placeholderText: "Nombre de la copia"
                            }
                            BotonPrincipal {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 42 * root.sy
                                text: "Duplicar modelo"
                                size_text: 0.24
                                enabled: !root.guardandoMetadata && !(root.controller && root.controller.ocupado)
                                onClicked: root.duplicar()
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: "#E5E7EB"
                            }
                            Text {
                                text: "MODELO ACTIVO"
                                color: "#6D28D9"
                                font.bold: true
                                font.pixelSize: 11 * Math.min(root.sx, root.sy)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.esModeloActivo()
                                      ? "Este modelo está cargado actualmente."
                                      : "Abrirlo en inferencia o continuar su entrenamiento lo convertirá en el modelo activo."
                                color: Style.Theme.texto_secundario
                                wrapMode: Text.WordWrap
                                font.pixelSize: 11 * Math.min(root.sx, root.sy)
                            }
                            BotonPrincipal {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40 * root.sy
                                text: root.esModeloActivo() ? "Abrir inferencia del activo" : "Activar en inferencia"
                                size_text: 0.23
                                enabled: root.compatible() && !(root.controller && root.controller.ocupado)
                                onClicked: root.cargarYAvanzar("inferencia")
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }
                }

                RectanglePrincipal {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(150 * root.sy,
                                                      70 * root.sy + root.listaDe(root.gestionActual,
                                                                                 ["versiones", "versions", "modelosGrupo"]).length * 42 * root.sy)
                    sx: root.sx
                    sy: root.sy
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15 * root.sx
                        spacing: 6 * root.sy
                        Text {
                            text: "VERSIONES DEL MISMO GRUPO"
                            color: "#6D28D9"
                            font.bold: true
                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                        }
                        Repeater {
                            model: root.listaDe(root.gestionActual, ["versiones", "versions", "modelosGrupo"])
                            delegate: Rectangle {
                                id: versionItem
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38 * root.sy
                                radius: 6 * root.sx
                                color: root.mismaRuta(root.campo(versionItem.modelData, ["ruta", "path"], ""), root.rutaActual)
                                       ? "#EDE9FE" : "#F8FAFC"
                                border.color: "#E5E7EB"
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10 * root.sx
                                    anchors.rightMargin: 10 * root.sx
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.texto(root.campo(versionItem.modelData, ["nombre", "name", "archivo"], null), "Versión")
                                        color: Style.Theme.texto_primario
                                        font.bold: root.mismaRuta(root.campo(versionItem.modelData, ["ruta", "path"], ""), root.rutaActual)
                                        elide: Text.ElideRight
                                        font.pixelSize: 11 * Math.min(root.sx, root.sy)
                                    }
                                    Text {
                                        text: root.texto(root.campo(versionItem.modelData, ["version", "versión"], null), "sin versión")
                                              + " · época " + root.texto(root.campo(versionItem.modelData, ["epoca", "epoch"], null), "—")
                                        color: Style.Theme.texto_secundario
                                        font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                    }
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: root.listaDe(root.gestionActual, ["versiones", "versions", "modelosGrupo"]).length === 0
                            text: "Asigna el mismo grupo a varios modelos para agrupar sus versiones."
                            color: Style.Theme.texto_secundario
                            horizontalAlignment: Text.AlignHCenter
                            font.italic: true
                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                        }
                    }
                }
            }
        }

        // -----------------------------------------------------------------
        // Integridad y compatibilidad
        // -----------------------------------------------------------------
        ScrollView {
            id: scrollIntegridad
            clip: true
            contentWidth: availableWidth
            ColumnLayout {
                width: scrollIntegridad.availableWidth
                spacing: 14 * root.sy

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 11 * root.sx
                    rowSpacing: 11 * root.sy
                    Repeater {
                        model: [
                            { e: "Estado de integridad", v: root.booleanoTexto(root.campo(root.integridadActual, ["valida", "verified", "integra"], null)) },
                            { e: "Checksum general", v: root.campo(root.integridadActual, ["checksum", "sha256", "hash"], null), mono: true },
                            { e: "Checksum de pesos", v: root.campo(root.integridadActual, ["checksumPesos", "checksum_pesos", "weightsChecksum"], null), mono: true },
                            { e: "Checksum de entrenamiento", v: root.campo(root.integridadActual, ["checksumEstadoEntrenamiento", "checksum_estado_entrenamiento", "trainingStateChecksum"], null), mono: true },
                            { e: "Checksum de archivo", v: root.campo(root.integridadActual, ["checksumArchivo", "checksum_archivo", "fileChecksum"], null), mono: true },
                            { e: "Algoritmo", v: root.campo(root.integridadActual, ["algoritmo", "algoritmo_checksum", "algorithm"], null) },
                            { e: "Dtype", v: root.campo(root.integridadActual, ["dtype", "dtypes", "tipoDatos"], null) },
                            { e: "Número de tensores", v: root.campo(root.integridadActual, ["numeroTensores", "numero_tensores", "tensorCount", "num_tensors", "num_tensores"], null) },
                            { e: "Versión de formato", v: root.campo(root.integridadActual, ["versionFormato", "version_formato", "formatVersion", "schemaVersion"], root.campo(root.descriptorActual, ["versionFormato", "version_formato"], null)) },
                            { e: "Formato", v: root.campo(root.descriptorActual, ["formato", "format"], null) },
                            { e: "Tamaño", v: root.campo(root.integridadActual, ["tamano", "size"], root.campo(root.descriptorActual, ["tamano", "tamano_legible"], null)) },
                            { e: "Portable", v: root.booleanoTexto(root.campo(root.descriptorActual, ["portable"], null)) }
                        ]
                        delegate: RectanglePrincipal {
                            id: integridadMetrica
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 88 * root.sy
                            sx: root.sx
                            sy: root.sy
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12 * root.sx
                                Text { text: integridadMetrica.modelData.e; color: Style.Theme.texto_secundario; font.pixelSize: 10 * Math.min(root.sx, root.sy) }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.texto(integridadMetrica.modelData.v, "No registrado")
                                    color: Style.Theme.texto_primario
                                    font.bold: true
                                    font.family: integridadMetrica.modelData.mono ? "monospace" : "sans-serif"
                                    elide: integridadMetrica.modelData.mono ? Text.ElideMiddle : Text.ElideRight
                                    font.pixelSize: 12 * Math.min(root.sx, root.sy)
                                    ToolTip.visible: integridadHover.containsMouse && integridadMetrica.modelData.mono
                                    ToolTip.text: text
                                    MouseArea { id: integridadHover; anchors.fill: parent; hoverEnabled: true }
                                }
                            }
                        }
                    }
                }

                RectanglePrincipal {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 300 * root.sy
                    sx: root.sx
                    sy: root.sy
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16 * root.sx
                        spacing: 10 * root.sy
                        Text {
                            text: "FORMAS DE CONTINUAR"
                            color: "#6D28D9"
                            font.bold: true
                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                        }
                        Repeater {
                            model: [
                                {
                                    t: "Reanudar exactamente",
                                    disponible: root.campo(root.compatibilidadActual, ["reanudacionExacta", "exactResume"], root.campo(root.descriptorActual, ["reanudacionExacta"], null)),
                                    d: "Restaura pesos, estado del optimizador, época/paso y los estados reproducibles que incluya el checkpoint. Es la opción para proseguir la misma corrida."
                                },
                                {
                                    t: "Continuar con Adam",
                                    disponible: root.campo(root.compatibilidadActual, ["continuarConAdam", "optimizerResume", "reanudable"], root.campo(root.descriptorActual, ["reanudable"], null)),
                                    d: "Conserva los momentos del optimizador cuando están presentes, pero puede iniciar una sesión con nuevos datos o hiperparámetros; ya no garantiza continuidad idéntica."
                                },
                                {
                                    t: "Entrenar desde los pesos",
                                    disponible: root.campo(root.compatibilidadActual, ["entrenarDesdePesos", "trainFromWeights", "entrenable"], root.campo(root.descriptorActual, ["entrenable"], null)),
                                    d: "Carga únicamente los parámetros aprendidos y crea un optimizador nuevo. Es útil para ajuste fino o cuando el estado de entrenamiento no fue guardado."
                                }
                            ]
                            delegate: Rectangle {
                                id: modoContinuacion
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 8 * root.sx
                                color: "#F8FAFC"
                                border.color: "#E5E7EB"
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12 * root.sx
                                    Rectangle {
                                        Layout.preferredWidth: 82 * root.sx
                                        Layout.preferredHeight: 28 * root.sy
                                        radius: height / 2
                                        color: modoContinuacion.modelData.disponible === true ? "#DCFCE7"
                                               : (modoContinuacion.modelData.disponible === false ? "#FEE2E2" : "#F3F4F6")
                                        Text {
                                            anchors.centerIn: parent
                                            text: modoContinuacion.modelData.disponible === true ? "Disponible"
                                                  : (modoContinuacion.modelData.disponible === false ? "No disponible" : "Sin dato")
                                            color: modoContinuacion.modelData.disponible === true ? "#166534"
                                                   : (modoContinuacion.modelData.disponible === false ? "#991B1B" : "#4B5563")
                                            font.bold: true
                                            font.pixelSize: 9 * Math.min(root.sx, root.sy)
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: modoContinuacion.modelData.t
                                            color: Style.Theme.texto_primario
                                            font.bold: true
                                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modoContinuacion.modelData.d
                                            color: Style.Theme.texto_secundario
                                            wrapMode: Text.WordWrap
                                            font.pixelSize: 10 * Math.min(root.sx, root.sy)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 76 * root.sy
                    radius: 8 * root.sx
                    color: root.compatible() ? "#ECFDF5" : "#FEF2F2"
                    border.color: root.compatible() ? "#A7F3D0" : "#FCA5A5"
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14 * root.sx
                        Text {
                            text: root.compatible() ? "✓" : "!"
                            color: root.compatible() ? "#047857" : "#B91C1C"
                            font.bold: true
                            font.pixelSize: 24 * root.sy
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Text {
                                text: root.compatible() ? "Compatible con esta aplicación" : "Modelo incompatible"
                                color: root.compatible() ? "#065F46" : "#991B1B"
                                font.bold: true
                                font.pixelSize: 13 * Math.min(root.sx, root.sy)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.texto(root.campo(root.compatibilidadActual, ["mensaje", "message", "motivo"],
                                                           root.campo(root.descriptorActual, ["error"], null)),
                                                 root.compatible()
                                                 ? "El formato y el tokenizador declarados pueden cargarse."
                                                 : "Consulta el motivo de incompatibilidad antes de intentar cargarlo.")
                                color: root.compatible() ? "#065F46" : "#991B1B"
                                elide: Text.ElideRight
                                font.pixelSize: 11 * Math.min(root.sx, root.sy)
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: paginas
        visible: root.cargandoDetalle && !root.tiene(root.detalle)
        color: "#CCFFFFFF"
        z: 30
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 10 * root.sy
            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 58 * root.sy
                Layout.preferredHeight: 58 * root.sy
                running: parent.parent.visible
            }
            Text {
                text: "Leyendo arquitectura, historial e integridad…"
                color: Style.Theme.texto_secundario
                font.pixelSize: 13 * Math.min(root.sx, root.sy)
            }
        }
    }
}
