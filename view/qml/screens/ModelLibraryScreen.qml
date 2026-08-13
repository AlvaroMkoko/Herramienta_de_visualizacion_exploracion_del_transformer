pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root

    property var controller: mainViewModel.modelLibraryController
    property string rutaParaExportar: ""
    property string extensionParaExportar: "tvismodel"
    property string mensajeEstado: ""
    property bool mensajeEsError: false
    property string accionTrasCarga: ""
    property var modelosVisibles: []

    function valor(item, nombres, alternativo) {
        if (item === undefined || item === null)
            return alternativo
        var listaNombres = Array.isArray(nombres) ? nombres : []

        for (var i = 0; i < listaNombres.length; ++i) {
            var candidato = item[listaNombres[i]]
            if (candidato !== undefined && candidato !== null && candidato !== "")
                return candidato
        }

        // Los modelos portables conservan estos datos agrupados en el
        // manifiesto; esta segunda búsqueda permite mostrar tanto ese formato
        // como los checkpoints históricos ya aplanados por el controlador.
        var grupos = [item.architecture, item.arquitectura, item.config,
                      item.training, item.entrenamiento, item.tokenizer]
        for (var g = 0; g < grupos.length; ++g) {
            var grupo = grupos[g]
            if (grupo === undefined || grupo === null)
                continue
            for (var j = 0; j < listaNombres.length; ++j) {
                var anidado = grupo[listaNombres[j]]
                if (anidado !== undefined && anidado !== null && anidado !== "")
                    return anidado
            }
        }
        return alternativo
    }

    function booleano(item, nombres, alternativo) {
        var resultado = valor(item, nombres, alternativo)
        if (typeof resultado === "string") {
            var normalizado = resultado.toLowerCase()
            if (normalizado === "true" || normalizado === "si" || normalizado === "sí"
                    || normalizado === "yes" || normalizado === "1")
                return true
            if (normalizado === "false" || normalizado === "no" || normalizado === "0")
                return false
        }
        return Boolean(resultado)
    }

    function ruta(item) {
        return String(valor(item, ["path", "ruta"], ""))
    }

    function nombre(item) {
        return String(valor(item, ["nombre", "name", "archivo"], "Modelo sin nombre"))
    }

    function esActivo(item) {
        if (root.booleano(item, ["activo", "esActivo", "es_activo"], false))
            return true
        if (!root.controller || !root.controller.modeloActivoRuta)
            return false
        var rutaItem = root.ruta(item).replace(/\\/g, "/").toLowerCase()
        var rutaActiva = String(root.controller.modeloActivoRuta).replace(/\\/g, "/").toLowerCase()
        return rutaItem !== "" && rutaItem === rutaActiva
    }

    function capasEncoder(item) {
        return valor(item, ["encoder_layers", "capasEncoder", "capas_encoder",
                            "num_capas_encoder", "num_capas"], "—")
    }

    function capasDecoder(item) {
        return valor(item, ["decoder_layers", "capasDecoder", "capas_decoder",
                            "num_capas_decoder", "num_capas"], "—")
    }

    function numeroLegible(valorNumerico) {
        if (valorNumerico === undefined || valorNumerico === null || valorNumerico === "")
            return "—"
        var numero = Number(valorNumerico)
        if (isNaN(numero))
            return String(valorNumerico)
        if (numero >= 1000000000)
            return (numero / 1000000000).toFixed(2) + " mil M"
        if (numero >= 1000000)
            return (numero / 1000000).toFixed(2) + " M"
        if (numero >= 1000)
            return (numero / 1000).toFixed(1) + " mil"
        return numero.toLocaleString(Qt.locale())
    }

    function tamanoLegible(item) {
        var preparado = valor(item, ["tamano", "tamano_legible", "size"], "")
        if (preparado !== "")
            return String(preparado)

        var bytes = Number(valor(item, ["tamanoBytes", "tamano_bytes", "size_bytes"], 0))
        if (!bytes || isNaN(bytes))
            return "—"
        if (bytes >= 1073741824)
            return (bytes / 1073741824).toFixed(2) + " GiB"
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(1) + " MiB"
        if (bytes >= 1024)
            return (bytes / 1024).toFixed(1) + " KiB"
        return bytes + " B"
    }

    function perdidaLegible(item) {
        var perdida = valor(item, ["perdida_final", "perdida", "loss", "last_loss"], "—")
        var numero = Number(perdida)
        return perdida !== "—" && !isNaN(numero) ? numero.toFixed(4) : String(perdida)
    }

    function esLegado(item) {
        var formato = String(valor(item, ["formato", "format"], "")).toLowerCase()
        var archivo = ruta(item).toLowerCase()
        return booleano(item, ["legado", "legacy", "is_legacy"], false)
                || formato.indexOf("legacy") !== -1
                || formato === "pt"
                || archivo.endsWith(".pt")
    }

    function insignias(item) {
        var formato = String(valor(item, ["formato", "format"], "")).toLowerCase()
        var compatible = booleano(item, ["compatible"], true)
        var portable = booleano(item, ["portable"], formato.indexOf("tvis") !== -1)
        var inferencia = booleano(item, ["inferencia", "inference_ready"], compatible)
        var reanudable = booleano(item, ["reanudable", "resume_available"], false)
        var entrenable = booleano(item, ["entrenable", "trainable"], compatible)
        var tokenizer = booleano(item, ["tokenizadorIncluido", "tokenizer_included"], false)
        var resultado = []

        if (root.esActivo(item))
            resultado.push({ texto: "● Activo", fondo: "#DCFCE7", tinta: "#166534" })
        resultado.push({ texto: compatible ? "Compatible" : "Incompatible",
                           fondo: compatible ? "#DCFCE7" : "#FEE2E2",
                           tinta: compatible ? "#166534" : "#991B1B" })
        if (inferencia)
            resultado.push({ texto: "Inferencia lista", fondo: "#DBEAFE", tinta: "#1E40AF" })
        if (entrenable)
            resultado.push({ texto: "Entrenable", fondo: "#F3E8FF", tinta: "#6B21A8" })
        if (reanudable)
            resultado.push({ texto: "Reanudable", fondo: "#FEF3C7", tinta: "#92400E" })
        if (tokenizer)
            resultado.push({ texto: "Tokenizador incluido", fondo: "#CCFBF1", tinta: "#115E59" })
        if (portable)
            resultado.push({ texto: "Portable", fondo: "#E0E7FF", tinta: "#3730A3" })
        if (esLegado(item))
            resultado.push({ texto: "Legado .pt", fondo: "#F3F4F6", tinta: "#4B5563" })
        return resultado
    }

    function mostrarEstado(mensaje, esError) {
        mensajeEstado = mensaje === undefined || mensaje === null ? "" : String(mensaje)
        mensajeEsError = esError
        if (mensajeEstado !== "")
            temporizadorEstado.restart()
    }

    function llamar(accion) {
        if (!controller || controller.ocupado)
            return
        accion()
    }

    function reconstruirModelosVisibles() {
        var origen = root.controller ? root.controller.modelos : []
        var consulta = campoBusqueda.text.trim().toLowerCase()
        var decorados = []
        for (var i = 0; i < origen.length; ++i) {
            var item = origen[i]
            var tags = root.valor(item, ["tags", "etiquetas"], [])
            var tagsTexto = Array.isArray(tags) ? tags.join(" ") : String(tags || "")
            var textoBusqueda = [
                root.nombre(item), root.ruta(item),
                root.valor(item, ["formato", "format"], ""),
                root.valor(item, ["grupo", "experimentGroup", "experiment_group"], ""),
                root.valor(item, ["version", "versión"], ""), tagsTexto,
                root.valor(item, ["encoding", "tokenizer_encoding"], "")
            ].join(" ").toLowerCase()
            if (consulta === "" || textoBusqueda.indexOf(consulta) !== -1)
                decorados.push({ "item": item, "indice": i })
        }

        var modo = selectorOrden.currentIndex
        decorados.sort(function(a, b) {
            if (modo === 1 || modo === 2) {
                var nombreA = root.nombre(a.item).toLowerCase()
                var nombreB = root.nombre(b.item).toLowerCase()
                var comparacion = nombreA < nombreB ? -1 : (nombreA > nombreB ? 1 : 0)
                return modo === 2 ? -comparacion : comparacion
            }
            if (modo === 3 || modo === 4) {
                var parametrosA = Number(root.valor(a.item,
                                                     ["parametros_totales", "parametros", "parameter_count"], 0))
                var parametrosB = Number(root.valor(b.item,
                                                     ["parametros_totales", "parametros", "parameter_count"], 0))
                var diferencia = parametrosA - parametrosB
                if (diferencia !== 0)
                    return modo === 3 ? -diferencia : diferencia
            }
            return a.indice - b.indice
        })

        var visibles = []
        for (var j = 0; j < decorados.length; ++j)
            visibles.push(decorados[j].item)
        root.modelosVisibles = visibles
    }

    function verDetalles(item) {
        var rutaModelo = root.ruta(item)
        if (rutaModelo === "") {
            root.mostrarEstado("No se encontró la ruta del modelo.", true)
            return
        }
        root.stackView.push("ModelDetailScreen.qml", {
            "stackView": root.stackView,
            "rutaModelo": rutaModelo,
            "modeloResumen": item
        })
    }

    function exportar(item) {
        rutaParaExportar = ruta(item)
        if (rutaParaExportar === "") {
            mostrarEstado("No se encontró la ruta del modelo.", true)
            return
        }
        extensionParaExportar = esLegado(item) ? "pt" : "tvismodel"
        dialogoExportar.open()
    }

    function cargarPara(item, accion) {
        var rutaModelo = ruta(item)
        if (rutaModelo === "") {
            mostrarEstado("No se encontró la ruta del modelo.", true)
            return
        }
        if (accion === "inferencia" && root.esActivo(item)
                && mainViewModel.modeloListo) {
            root.stackView.push("InferenceScreen.qml", {
                "stackView": root.stackView
            })
            return
        }
        accionTrasCarga = accion
        llamar(function() { controller.cargarModelo(rutaModelo) })
    }

    function eliminarModelo(item){
        var ruatModelo = ruta(item)
        if (ruatModelo === "") {
            mostrarEstado("No se encontró la ruta del modelo.", true)
            return
        }
        llamar (function(){controller.eliminarModelo(ruatModelo,true)})
    }

    function exportarComoCodigo(item) {
        var rutaModelo = ruta(item)
        if (rutaModelo === "") {
            mostrarEstado("No se encontró la ruta del modelo.", true)
            return
        }
        llamar(function() {
            var codigo = controller.exportarCodigo(rutaModelo)
            if (codigo !== undefined && codigo !== null && String(codigo) !== "") {
                campoCodigo.text = String(codigo)
                panelCodigo.expandido = true
                mostrarEstado("Código generado. Puedes copiarlo desde el cuadro inferior.", false)
            }
        })
    }

    Component.onCompleted: {
        if (controller) {
            controller.refrescar()
            root.reconstruirModelosVisibles()
        }
    }

    Connections {
        target: root.controller
        ignoreUnknownSignals: true

        function onModelosCambio() {
            root.reconstruirModelosVisibles()
            listaModelos.forceLayout()
        }

        function onOperacion_exitosa(mensaje) {
            root.mostrarEstado(mensaje, false)
        }

        function onError(mensaje) {
            root.accionTrasCarga = ""
            root.mostrarEstado(mensaje, true)
        }

    }

    Connections {
        target: mainViewModel
        ignoreUnknownSignals: true

        function onModeloListoCambio() {
            if (!mainViewModel.modeloListo || root.accionTrasCarga === "")
                return
            var accion = root.accionTrasCarga
            root.accionTrasCarga = ""
            if (accion === "inferencia") {
                root.stackView.push("InferenceScreen.qml", {
                    "stackView": root.stackView
                })
            } else if (accion === "entrenamiento") {
                root.stackView.push("SetupScreen.qml", {
                    "stackView": root.stackView,
                    "usarModeloActual": true
                })
            }
        }
    }

    Timer {
        id: temporizadorEstado
        interval: 6000
        onTriggered: root.mensajeEstado = ""
    }

    FileDialog {
        id: dialogoImportar
        title: "Importar modelo"
        fileMode: FileDialog.OpenFile
        nameFilters: [
            "Modelos Transformer (*.tvismodel *.pt)",
            "Modelo portable (*.tvismodel)",
            "Checkpoint legado (*.pt)"
        ]

        onAccepted: root.llamar(function() {
            root.controller.importarModelo(selectedFile.toString())
        })
    }

    FileDialog {
        id: dialogoExportar
        title: root.extensionParaExportar === "pt"
               ? "Exportar checkpoint legado"
               : "Exportar modelo portable"
        fileMode: FileDialog.SaveFile
        defaultSuffix: root.extensionParaExportar
        nameFilters: root.extensionParaExportar === "pt"
                     ? ["Checkpoint legado (*.pt)"]
                     : ["Modelo portable (*.tvismodel)"]

        onAccepted: root.llamar(function() {
            root.controller.exportarModelo(root.rutaParaExportar, selectedFile.toString())
        })
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
            Layout.preferredWidth: 210 * root.sx
            Layout.preferredHeight: 44 * root.sy
            text: "↶ Volver al inicio"
            size_text: 0.27
            onClicked: root.stackView.pop()
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2 * root.sy

            Text {
                text: "Biblioteca de modelos"
                color: Style.Theme.texto_primario
                font.bold: true
                font.pixelSize: 27 * Math.min(root.sx, root.sy)
            }

            Text {
                text: root.modelosVisibles.length
                      + (root.modelosVisibles.length === 1 ? " modelo visible" : " modelos visibles")
                      + ((root.controller && root.controller.modelos.length !== root.modelosVisibles.length)
                         ? " de " + root.controller.modelos.length : "")
                color: Style.Theme.texto_secundario
                font.pixelSize: 14 * Math.min(root.sx, root.sy)
            }
        }

        BusyIndicator {
            Layout.preferredWidth: 36 * root.sy
            Layout.preferredHeight: 36 * root.sy
            running: root.controller && root.controller.ocupado
            visible: running
        }

        BotonPrincipal {
            Layout.preferredWidth: 160 * root.sx
            Layout.preferredHeight: 44 * root.sy
            text: "Actualizar"
            size_text: 0.26
            enabled: root.controller && !root.controller.ocupado
            onClicked: root.llamar(function() { root.controller.refrescar() })
        }

        BotonPrincipal {
            Layout.preferredWidth: 180 * root.sx
            Layout.preferredHeight: 44 * root.sy
            text: "Importar archivo"
            size_text: 0.24
            enabled: root.controller && !root.controller.ocupado
            onClicked: dialogoImportar.open()
        }

        BotonPrincipal {
            Layout.preferredWidth: 170 * root.sx
            Layout.preferredHeight: 44 * root.sy
            text: "Pegar modelo"
            size_text: 0.25
            enabled: root.controller && !root.controller.ocupado
            ToolTip.visible: hovered
            ToolTip.text: "Importa un archivo de modelo copiado al portapapeles"
            onClicked: root.llamar(function() { root.controller.pegarModelo() })
        }
    }

    Rectangle {
        id: aviso
        anchors.top: cabecera.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 40 * root.sx, textoAviso.implicitWidth + 34 * root.sx)
        height: root.mensajeEstado === "" ? 0 : 34 * root.sy
        radius: 8 * root.sx
        color: root.mensajeEsError ? "#FEE2E2" : "#DCFCE7"
        border.color: root.mensajeEsError ? "#FCA5A5" : "#86EFAC"
        visible: height > 0
        clip: true
        z: 5

        Behavior on height { NumberAnimation { duration: 120 } }

        Text {
            id: textoAviso
            anchors.centerIn: parent
            width: Math.min(implicitWidth, aviso.width - 20 * root.sx)
            text: root.mensajeEstado
            color: root.mensajeEsError ? "#991B1B" : "#166534"
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 13 * Math.min(root.sx, root.sy)
        }
    }

    RowLayout {
        id: herramientasCatalogo
        anchors.top: aviso.bottom
        anchors.topMargin: 9 * root.sy
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 30 * root.sx
        anchors.rightMargin: 30 * root.sx
        height: 42 * root.sy
        spacing: 10 * root.sx

        TextField {
            id: campoBusqueda
            Layout.fillWidth: true
            Layout.preferredHeight: 40 * root.sy
            placeholderText: "Buscar por nombre, ruta, grupo, versión, etiqueta o tokenizador…"
            selectByMouse: true
            onTextChanged: root.reconstruirModelosVisibles()
        }

        ComboBox {
            id: selectorOrden
            Layout.preferredWidth: 225 * root.sx
            Layout.preferredHeight: 40 * root.sy
            model: ["Más recientes", "Nombre A–Z", "Nombre Z–A",
                    "Más parámetros", "Menos parámetros"]
            onCurrentIndexChanged: root.reconstruirModelosVisibles()
        }

        BotonPrincipal {
            Layout.preferredWidth: 115 * root.sx
            Layout.preferredHeight: 39 * root.sy
            text: "Limpiar"
            size_text: 0.26
            enabled: campoBusqueda.text.length > 0 || selectorOrden.currentIndex !== 0
            opacity: enabled ? 1 : 0.5
            onClicked: {
                campoBusqueda.clear()
                selectorOrden.currentIndex = 0
            }
        }
    }

    ListView {
        id: listaModelos
        anchors.top: herramientasCatalogo.bottom
        anchors.topMargin: 12 * root.sy
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: panelCodigo.top
        anchors.leftMargin: 30 * root.sx
        anchors.rightMargin: 30 * root.sx
        anchors.bottomMargin: 12 * root.sy
        spacing: 14 * root.sy
        clip: true
        model: root.modelosVisibles
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        delegate: RectanglePrincipal {
            id: tarjeta
            required property var modelData
            property var info: modelData
            property bool compatible: root.booleano(info, ["compatible"], true)

            width: listaModelos.width - 14 * root.sx
            height: 352 * root.sy
            sx: root.sx
            sy: root.sy
            opacity: compatible ? 1.0 : 0.82

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18 * root.sx
                spacing: 7 * root.sy

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10 * root.sx

                    Text {
                        Layout.fillWidth: true
                        text: root.nombre(tarjeta.info)
                        color: Style.Theme.texto_primario
                        font.bold: true
                        font.pixelSize: 21 * Math.min(root.sx, root.sy)
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        Layout.preferredWidth: etiquetaFormato.implicitWidth + 18 * root.sx
                        Layout.preferredHeight: 25 * root.sy
                        radius: height / 2
                        color: "#F3F4F6"
                        border.color: "#D1D5DB"

                        Text {
                            id: etiquetaFormato
                            anchors.centerIn: parent
                            text: String(root.valor(tarjeta.info, ["formato", "format"], root.esLegado(tarjeta.info) ? "PT" : "TVISMODEL")).toUpperCase()
                            color: "#4B5563"
                            font.bold: true
                            font.pixelSize: 11 * Math.min(root.sx, root.sy)
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.ruta(tarjeta.info)
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 12 * Math.min(root.sx, root.sy)
                    elide: Text.ElideMiddle
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: "#E5E7EB"
                }

                Text {
                    Layout.fillWidth: true
                    text: "Encoder: " + root.capasEncoder(tarjeta.info) + " capas"
                          + "   ·   Decoder: " + root.capasDecoder(tarjeta.info) + " capas"
                          + "   ·   Cabezas: " + root.valor(tarjeta.info, ["num_cabezas", "cabezas", "heads", "nhead"], "—")
                    color: "#312E81"
                    font.bold: true
                    font.pixelSize: 15 * Math.min(root.sx, root.sy)
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: "d_model " + root.valor(tarjeta.info, ["dimension_modelo", "dimension", "d_model"], "—")
                          + "   ·   d_ff " + root.valor(tarjeta.info, ["dimension_ff", "dimensionFF", "d_ff"], "—")
                          + "   ·   Contexto " + root.valor(tarjeta.info, ["longitud_maxima_secuencia", "contexto", "context_length", "max_seq_len"], "—")
                          + "   ·   Vocabulario " + root.numeroLegible(root.valor(tarjeta.info, ["tamano_vocabulario", "vocabulario", "vocab_size"], "—"))
                    color: Style.Theme.texto_primario
                    font.pixelSize: 14 * Math.min(root.sx, root.sy)
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: "Parámetros " + root.numeroLegible(root.valor(tarjeta.info, ["parametros_totales", "parametros", "parameter_count", "num_parameters"], "—"))
                          + "   ·   Tamaño " + root.tamanoLegible(tarjeta.info)
                          + "   ·   Tokenizador " + root.valor(tarjeta.info, ["encoding", "tokenizer_encoding"], "No especificado")
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 13 * Math.min(root.sx, root.sy)
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: "Entrenamiento: época " + root.valor(tarjeta.info, ["epoca", "epoch"], "—")
                          + "   ·   paso " + root.valor(tarjeta.info, ["paso_global", "pasos", "global_step"], "—")
                          + "   ·   loss " + root.perdidaLegible(tarjeta.info)
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 13 * Math.min(root.sx, root.sy)
                    elide: Text.ElideRight
                }

                Text {
                    visible: !root.booleano(tarjeta.info,
                                             ["usarMascaraCausal", "usar_mascara_causal", "causal_mask"],
                                             true)
                    text: "⚠ Sin máscara causal — modelo experimental"
                    color: "#E8A33D"
                    font.pixelSize: 11 * root.sy
                }

                Flow {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28 * root.sy
                    spacing: 6 * root.sx

                    Repeater {
                        model: root.insignias(tarjeta.info)

                        delegate: Rectangle {
                            id: insigniaModelo
                            required property var modelData
                            width: textoInsignia.implicitWidth + 16 * root.sx
                            height: 24 * root.sy
                            radius: height / 2
                            color: insigniaModelo.modelData.fondo

                            Text {
                                id: textoInsignia
                                anchors.centerIn: parent
                                text: insigniaModelo.modelData.texto
                                color: insigniaModelo.modelData.tinta
                                font.bold: true
                                font.pixelSize: 10 * Math.min(root.sx, root.sy)
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: !tarjeta.compatible
                    text: root.valor(tarjeta.info, ["error", "motivo_incompatibilidad"], "Este formato no es compatible con esta versión.")
                    color: Style.Theme.error
                    font.pixelSize: 11 * Math.min(root.sx, root.sy)
                    elide: Text.ElideRight
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 39 * root.sy
                    spacing: 7 * root.sx

                    BotonPrincipal {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 39 * root.sy
                        text: "Ver detalles"
                        size_text: 0.24
                        enabled: root.ruta(tarjeta.info) !== ""
                        ToolTip.visible: hovered
                        ToolTip.text: "Inspeccionar arquitectura, procedencia, historial e integridad sin cargar los pesos"
                        onClicked: root.verDetalles(tarjeta.info)
                    }

                    BotonPrincipal {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 39 * root.sy
                        text: "Abrir en inferencia"
                        size_text: 0.21
                        enabled: tarjeta.compatible && root.controller && !root.controller.ocupado
                        ToolTip.visible: hovered
                        ToolTip.text: "Cargar los pesos y comenzar una sesión de inferencia"
                        onClicked: root.cargarPara(tarjeta.info, "inferencia")
                    }

                    BotonPrincipal {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 39 * root.sy
                        text: "Continuar entrenamiento"
                        size_text: 0.19
                        enabled: tarjeta.compatible && root.controller && !root.controller.ocupado
                        ToolTip.visible: hovered
                        ToolTip.text: "Cargar pesos y seleccionar datasets para continuar"
                        onClicked: root.cargarPara(tarjeta.info, "entrenamiento")
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36 * root.sy
                    spacing: 7 * root.sx

                    BotonPrincipal {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36 * root.sy
                        text: "Exportar"
                        size_text: 0.24
                        enabled: tarjeta.compatible && root.controller && !root.controller.ocupado
                        onClicked: root.exportar(tarjeta.info)
                    }

                    BotonPrincipal {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36 * root.sy
                        text: "Copiar archivo"
                        size_text: 0.20
                        enabled: root.controller && !root.controller.ocupado
                        onClicked: root.llamar(function() { root.controller.copiarModelo(root.ruta(tarjeta.info)) })
                    }

                    BotonPrincipal {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36 * root.sy
                        text: "Copiar ficha"
                        size_text: 0.21
                        enabled: root.controller && !root.controller.ocupado
                        onClicked: root.llamar(function() { root.controller.copiarFicha(root.ruta(tarjeta.info)) })
                    }

                    BotonPrincipal {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36 * root.sy
                        text: "Código"
                        size_text: 0.24
                        enabled: tarjeta.compatible && root.controller && !root.controller.ocupado
                        ToolTip.visible: hovered
                        ToolTip.text: "Generar texto para compartir modelos pequeños"
                        onClicked: root.exportarComoCodigo(tarjeta.info)
                    }

                    BotonPrincipal {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36 * root.sy
                        text: "Eliminar"
                        size_text: 0.23
                        enabled: tarjeta.compatible && root.controller && !root.controller.ocupado
                        ToolTip.visible: hovered
                        ToolTip.text: "Eliminar el modelo de la biblioteca"
                        onClicked: root.eliminarModelo(tarjeta.info)
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            width: Math.min(parent.width, 680 * root.sx)
            visible: listaModelos.count === 0 && !(root.controller && root.controller.ocupado)
            text: root.controller && root.controller.modelos.length > 0
                  ? "Ningún modelo coincide con la búsqueda.\nPrueba con otro nombre, grupo, etiqueta o tokenizador."
                  : "Todavía no hay modelos en la biblioteca.\nImporta un archivo .tvismodel o .pt para comenzar."
            color: Style.Theme.texto_secundario
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: 18 * Math.min(root.sx, root.sy)
        }
    }

    RectanglePrincipal {
        id: panelCodigo
        property bool expandido: false

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 30 * root.sx
        anchors.rightMargin: 30 * root.sx
        anchors.bottomMargin: 18 * root.sy
        height: expandido ? 220 * root.sy : 50 * root.sy
        sx: root.sx
        sy: root.sy
        clip: true

        Behavior on height { NumberAnimation { duration: 160 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10 * root.sx
            spacing: 8 * root.sy

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 32 * root.sy

                Text {
                    Layout.fillWidth: true
                    text: "Compartir como texto (recomendado solo para modelos pequeños)"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 14 * Math.min(root.sx, root.sy)
                }

                BotonPrincipal {
                    Layout.preferredWidth: 130 * root.sx
                    Layout.preferredHeight: 31 * root.sy
                    text: panelCodigo.expandido ? "Ocultar" : "Mostrar"
                    size_text: 0.27
                    onClicked: panelCodigo.expandido = !panelCodigo.expandido
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: panelCodigo.expandido
                spacing: 10 * root.sx

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    TextArea {
                        id: campoCodigo
                        placeholderText: "Pega aquí un código TVIS1:… o genera uno desde una tarjeta"
                        selectByMouse: true
                        wrapMode: TextEdit.WrapAnywhere
                        font.family: "monospace"
                        font.pixelSize: 11 * Math.min(root.sx, root.sy)
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 230 * root.sx
                    Layout.fillHeight: true
                    spacing: 8 * root.sy

                    TextField {
                        id: nombreCodigo
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38 * root.sy
                        placeholderText: "Nombre del modelo"
                    }

                    BotonPrincipal {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42 * root.sy
                        text: "Importar código"
                        size_text: 0.23
                        enabled: campoCodigo.text.trim().length > 0
                                 && root.controller && !root.controller.ocupado
                        onClicked: root.llamar(function() {
                            root.controller.importarCodigo(
                                campoCodigo.text.trim(),
                                nombreCodigo.text.trim()
                            )
                        })
                    }

                    BotonPrincipal {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36 * root.sy
                        text: "Copiar texto"
                        size_text: 0.25
                        enabled: campoCodigo.text.length > 0
                        onClicked: {
                            campoCodigo.selectAll()
                            campoCodigo.copy()
                            campoCodigo.deselect()
                            root.mostrarEstado("Código TVIS1 copiado al portapapeles.", false)
                        }
                    }

                    BotonPrincipal {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36 * root.sy
                        text: "Limpiar"
                        size_text: 0.25
                        enabled: campoCodigo.text.length > 0
                        onClicked: campoCodigo.clear()
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
