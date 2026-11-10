pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Lección de un paso del recorrido guiado, en una sola columna desplazable.
//
// Antes, el paso se repartía en tres ventanas (imagen, traza con la pregunta y
// teoría) y el estudiante no sabía a qué atender; además soltaba términos como
// d_model sin explicarlos. Aquí el paso se lee de arriba abajo, en el orden en
// que se aprende:
//
//   1. La idea        intuición en lenguaje cotidiano
//   2. Términos       cada palabra nueva, antes de usarla
//   3. Míralo         la visualización del paso
//   4. Paso a paso    el procedimiento, con fórmula donde ayuda
//   5. Con números    el ejemplo ancla resuelto
//   6. Resumen        entrada, operación, por qué, cambio, resultado y forma
//   7. Comprueba      la pregunta del paso, al final
//
// El contenido viene de `step.lesson` (data/aprendizaje/alineacion.json) y el
// resumen usa los mismos campos del paso que alimentan el pre y el post-test.
// `tour` es la pantalla del recorrido: de ella salen el paso actual, su
// comprobación y la acción de comprobar.
ScrollView {
    id: root
    objectName: "moduleGuidedLesson"

    property var tour: null

    readonly property real s: root.tour ? root.tour.uiScale : 1
    readonly property var step: root.tour ? root.tour.currentStep : ({})
    readonly property var lesson: root.step && root.step.lesson ? root.step.lesson : ({})
    readonly property var terminos: root.lesson.terminos || []
    readonly property var pasos: root.lesson.pasos || []
    readonly property var ejemplo: root.lesson.ejemplo || ({})
    readonly property var definicion: root.tour ? root.tour.currentConceptDefinition : ({})
    // El panel lateral de términos es opcional y sólo cabe en pantallas anchas.
    property bool panelTerminosAbierto: false
    readonly property bool panelTerminosCabe: root.availableWidth >= 1040 * root.s
    readonly property bool panelTerminosVisible: root.panelTerminosAbierto && root.panelTerminosCabe
    readonly property real anchoPanelTerminos: 300 * root.s
    readonly property real anchoLectura: Math.min(
        root.availableWidth - 32 * root.s
        - (root.panelTerminosVisible ? root.anchoPanelTerminos + 16 * root.s : 0),
        1040 * root.s)
    // Lectura por partes: una sección tras otra, para no enfrentar todo el paso de golpe.
    readonly property bool revelarPorPartes: root.tour ? root.tour.firstUseGuidance === true : false
    property int seccionRevelada: 7
    readonly property var glosario: root.construirGlosario()

    function revelarInicio() {
        var yaIntentado = root.tour ? root.tour.currentAttempted === true : false
        root.seccionRevelada = root.revelarPorPartes && !yaIntentado ? 1 : 7
    }

    function revelada(numero) {
        return numero <= root.seccionRevelada
    }

    function seguirLeyendo() {
        var siguiente = root.seccionRevelada + 1
        if (siguiente === 2 && root.terminos.length === 0)
            siguiente = 3
        if (siguiente === 5 && (root.ejemplo.lineas || []).length === 0)
            siguiente = 6
        root.seccionRevelada = Math.min(7, siguiente)
    }

    // Términos ya presentados hasta este paso, como en una consulta de glosario.
    function construirGlosario() {
        var entradas = []
        var pasosModulo = root.tour ? (root.tour.steps || []) : []
        var ultimo = root.tour ? Number(root.tour.currentIndex) : -1
        for (var p = 0; p <= ultimo && p < pasosModulo.length; ++p) {
            var leccion = pasosModulo[p].lesson || ({})
            var lista = leccion.terminos || []
            for (var t = 0; t < lista.length; ++t) {
                var nombre = String(lista[t].termino)
                // «Forma [B, T]» es un ejemplo, no una palabra que vaya a aparecer igual.
                if (nombre.indexOf("[") !== -1)
                    continue
                var claves = nombre.replace(/\s*\(.*?\)/g, "").split(/,\s+|\s+y\s+/)
                for (var c = 0; c < claves.length; ++c) {
                    var clave = claves[c].trim()
                    if (clave.length)
                        entradas.push({ "clave": clave, "termino": nombre,
                                        "definicion": String(lista[t].definicion) })
                }
            }
        }
        // Primero las más largas, para que «Token ID» gane sobre «Token».
        entradas.sort(function (a, b) { return b.clave.length - a.clave.length })
        return entradas
    }

    // Un término puede agrupar dos palabras («Token y T»): en el panel va una sola vez.
    function terminosParaPanel() {
        var vistos = []
        var unicos = []
        for (var e = 0; e < root.glosario.length; ++e) {
            if (vistos.indexOf(root.glosario[e].termino) === -1) {
                vistos.push(root.glosario[e].termino)
                unicos.push(root.glosario[e])
            }
        }
        return unicos
    }

    function esParteDePalabra(caracter) {
        return caracter !== undefined && /[0-9A-Za-z_\u00C0-\u024F]/.test(caracter)
    }

    function escaparHtml(texto) {
        return texto.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    // Convierte en enlace la primera aparición de cada término del glosario.
    function marcarTerminos(texto) {
        var original = String(texto)
        var minusculas = original.toLowerCase()
        var tramos = []
        for (var e = 0; e < root.glosario.length; ++e) {
            var clave = root.glosario[e].clave
            var sensible = clave.length < 4
            var donde = sensible ? original : minusculas
            var buscada = sensible ? clave : clave.toLowerCase()
            var inicio = donde.indexOf(buscada)
            while (inicio !== -1) {
                var fin = inicio + buscada.length
                var libre = true
                for (var r = 0; r < tramos.length; ++r)
                    if (inicio < tramos[r].fin && fin > tramos[r].inicio)
                        libre = false
                if (libre && !root.esParteDePalabra(original[inicio - 1])
                        && !root.esParteDePalabra(original[fin])) {
                    tramos.push({ "inicio": inicio, "fin": fin, "entrada": e })
                    break
                }
                inicio = donde.indexOf(buscada, inicio + 1)
            }
        }
        tramos.sort(function (a, b) { return a.inicio - b.inicio })
        var salida = ""
        var cursor = 0
        for (var i = 0; i < tramos.length; ++i) {
            salida += root.escaparHtml(original.substring(cursor, tramos[i].inicio))
            salida += '<a href="' + tramos[i].entrada + '">'
                    + root.escaparHtml(original.substring(tramos[i].inicio, tramos[i].fin)) + "</a>"
            cursor = tramos[i].fin
        }
        return salida + root.escaparHtml(original.substring(cursor))
    }

    function definicionDe(enlace) {
        var entrada = root.glosario[Number(enlace)]
        return entrada ? entrada.termino + ": " + entrada.definicion : ""
    }

    Component.onCompleted: root.revelarInicio()

    clip: true
    contentWidth: availableWidth
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ScrollBar.vertical.policy: ScrollBar.AsNeeded

    // Cada paso nuevo se empieza a leer desde arriba.
    Connections {
        target: root.tour
        function onCurrentIndexChanged() {
            root.contentItem.contentY = 0
            comprobacion.selectedIndex = -1
            root.revelarInicio()
        }
    }

    component Seccion: ColumnLayout {
        id: seccion
        property string numero: ""
        property string titulo: ""
        Layout.fillWidth: true
        spacing: 10 * root.s

        RowLayout {
            Layout.fillWidth: true
            spacing: 10 * root.s
            Rectangle {
                visible: seccion.numero !== ""
                Layout.preferredWidth: 28 * root.s
                Layout.preferredHeight: 28 * root.s
                radius: width / 2
                color: Style.Theme.acento
                Text {
                    anchors.centerIn: parent
                    text: seccion.numero
                    color: Style.Theme.texto_sobre_acento
                    font.bold: true
                    font.pixelSize: 13 * root.s
                }
            }
            Text {
                Layout.fillWidth: true
                text: seccion.titulo
                color: Style.Theme.texto_primario
                font.bold: true
                font.pixelSize: 19 * root.s
                wrapMode: Text.WordWrap
            }
        }
    }

    // Texto con términos enlazados: al pasar el cursor, o al tocar, da su definición.
    component TextoConTerminos: Text {
        id: textoConTerminos
        property string contenido: ""
        property string enlaceFijado: ""
        readonly property string enlaceActivo: hoveredLink.length ? hoveredLink : enlaceFijado
        text: root.marcarTerminos(contenido)
        textFormat: Text.StyledText
        linkColor: Style.Theme.concepto_texto
        wrapMode: Text.WordWrap
        onLinkActivated: function (enlace) {
            textoConTerminos.enlaceFijado = textoConTerminos.enlaceFijado === enlace ? "" : enlace
        }
        HoverHandler {
            enabled: textoConTerminos.hoveredLink.length > 0
            cursorShape: Qt.PointingHandCursor
        }
        ToolTip {
            parent: textoConTerminos
            visible: textoConTerminos.enlaceActivo.length > 0
            text: root.definicionDe(textoConTerminos.enlaceActivo)
            width: Math.min(420 * root.s, implicitWidth)
        }
    }

    component Parrafo: TextoConTerminos {
        Layout.fillWidth: true
        color: Style.Theme.texto_primario
        font.pixelSize: 16 * root.s
        lineHeight: 1.3
    }

    component Formula: Rectangle {
        id: formula
        property string texto: ""
        Layout.fillWidth: true
        Layout.preferredHeight: textoFormula.implicitHeight + 18 * root.s
        visible: formula.texto !== ""
        radius: 8 * root.s
        color: Style.Theme.formula_fondo
        Text {
            id: textoFormula
            anchors.fill: parent
            anchors.margins: 9 * root.s
            text: formula.texto
            color: Style.Theme.formula_texto
            font.family: Style.Theme.fuente_mono
            font.bold: true
            font.pixelSize: 15 * root.s
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignVCenter
        }
    }

    Item {
        width: root.availableWidth
        implicitHeight: columna.implicitHeight + 40 * root.s

        ColumnLayout {
            id: columna
            width: root.anchoLectura
            x: root.panelTerminosVisible ? 16 * root.s : (parent.width - width) / 2
            anchors.top: parent.top
            anchors.topMargin: 8 * root.s
            spacing: 26 * root.s

            // ── Encabezado del paso ─────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4 * root.s
                Text {
                    text: "PASO " + ((root.tour ? root.tour.currentIndex : 0) + 1)
                          + " DE " + (root.tour ? root.tour.steps.length : 0)
                    color: Style.Theme.acento_fuerte
                    font.bold: true
                    font.pixelSize: 12 * root.s
                    font.letterSpacing: 0.8
                }
                BotonSecundario {
                    objectName: "moduleGuidedTermsPanelToggle"
                    visible: root.panelTerminosCabe
                    sx: root.s
                    sy: root.s
                    text: root.panelTerminosAbierto ? "Ocultar los términos" : "Ver los términos al lado"
                    onClicked: root.panelTerminosAbierto = !root.panelTerminosAbierto
                }
                Text {
                    objectName: "moduleGuidedLessonTitle"
                    Layout.fillWidth: true
                    text: String(root.step.title || "")
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 30 * root.s
                    wrapMode: Text.WordWrap
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.tour ? root.tour.currentIsFocus : false
                    text: "★ En el pre-test fallaste reactivos de este concepto: tómate tu tiempo en este paso."
                    color: Style.Theme.aviso_texto
                    font.bold: true
                    font.pixelSize: 13 * root.s
                    wrapMode: Text.WordWrap
                }
            }

            // ── 1. La idea ──────────────────────────────────────────
            Seccion {
                numero: "1"
                titulo: "La idea"
                objectName: "moduleGuidedSectionIdea"
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: textoIdea.implicitHeight + 32 * root.s
                    radius: 12 * root.s
                    color: Style.Theme.concepto_fondo
                    TextoConTerminos {
                        id: textoIdea
                        objectName: "moduleGuidedIntuition"
                        anchors.fill: parent
                        anchors.margins: 16 * root.s
                        contenido: String(root.lesson.intuicion || "")
                        color: Style.Theme.texto_primario
                        font.pixelSize: 17 * root.s
                        lineHeight: 1.35
                    }
                }
            }

            // ── 2. Términos nuevos ──────────────────────────────────
            Seccion {
                numero: "2"
                titulo: "Términos que necesitas"
                visible: root.terminos.length > 0 && root.revelada(2)

                GridLayout {
                    Layout.fillWidth: true
                    columns: root.anchoLectura >= 720 * root.s ? 2 : 1
                    columnSpacing: 10 * root.s
                    rowSpacing: 10 * root.s

                    Repeater {
                        model: root.terminos
                        delegate: Rectangle {
                            id: tarjetaTermino
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: contenidoTermino.implicitHeight + 24 * root.s
                            Layout.alignment: Qt.AlignTop
                            radius: 10 * root.s
                            color: Style.Theme.surface
                            border.width: 1
                            border.color: Style.Theme.borde_suave
                            ColumnLayout {
                                id: contenidoTermino
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 12 * root.s
                                spacing: 4 * root.s
                                Text {
                                    Layout.fillWidth: true
                                    text: String(tarjetaTermino.modelData.termino)
                                    color: Style.Theme.concepto_texto
                                    font.bold: true
                                    font.pixelSize: 15 * root.s
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: String(tarjetaTermino.modelData.definicion)
                                    color: Style.Theme.texto_primario
                                    font.pixelSize: 14 * root.s
                                    lineHeight: 1.25
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }

            // ── 3. Míralo ───────────────────────────────────────────
            Seccion {
                numero: root.terminos.length > 0 ? "3" : "2"
                titulo: "Míralo"
                visible: root.revelada(3)
                GuidedDemoVisualization {
                    objectName: "moduleGuidedVisualization"
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(300 * root.s, root.anchoLectura * 0.36)
                    conceptId: root.tour ? root.tour.currentTheoryConceptId : ""
                    stepId: String(root.step.id || "")
                    scaleFactor: root.s
                }
            }

            // ── 4. Paso a paso ──────────────────────────────────────
            Seccion {
                numero: root.terminos.length > 0 ? "4" : "3"
                titulo: "Paso a paso"
                visible: root.revelada(4)
                Repeater {
                    model: root.pasos
                    delegate: RowLayout {
                        id: filaPaso
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 12 * root.s
                        Rectangle {
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 30 * root.s
                            Layout.preferredHeight: 30 * root.s
                            radius: width / 2
                            color: Style.Theme.acento_fondo
                            border.width: 1
                            border.color: Style.Theme.acento
                            Text {
                                anchors.centerIn: parent
                                text: String(filaPaso.index + 1)
                                color: Style.Theme.acento_fuerte
                                font.bold: true
                                font.pixelSize: 14 * root.s
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6 * root.s
                            Parrafo { contenido: String(filaPaso.modelData.texto || "") }
                            Formula { texto: String(filaPaso.modelData.formula || "") }
                        }
                    }
                }
            }

            // ── 5. Con números ──────────────────────────────────────
            Seccion {
                numero: root.terminos.length > 0 ? "5" : "4"
                titulo: "Con números: " + String(root.ejemplo.titulo || "")
                visible: (root.ejemplo.lineas || []).length > 0 && root.revelada(5)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: lineasEjemplo.implicitHeight + 28 * root.s
                    radius: 12 * root.s
                    color: Style.Theme.ejemplo_fondo
                    ColumnLayout {
                        id: lineasEjemplo
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 14 * root.s
                        spacing: 6 * root.s
                        Repeater {
                            model: root.ejemplo.lineas || []
                            delegate: Text {
                                required property var modelData
                                Layout.fillWidth: true
                                text: String(modelData)
                                color: Style.Theme.texto_primario
                                font.family: Style.Theme.fuente_mono
                                font.pixelSize: 15 * root.s
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            // ── Resumen del paso ────────────────────────────────────
            Seccion {
                titulo: "Resumen del paso"
                visible: root.revelada(6)

                Rectangle {
                    objectName: "moduleGuidedDefinition"
                    Layout.fillWidth: true
                    visible: String(root.definicion.description || "").length > 0
                    Layout.preferredHeight: textoDefinicion.implicitHeight + 24 * root.s
                    radius: 10 * root.s
                    color: Style.Theme.concepto_fondo
                    Text {
                        id: textoDefinicion
                        anchors.fill: parent
                        anchors.margins: 12 * root.s
                        text: "<b>" + String(root.definicion.title || "") + ":</b> "
                              + String(root.definicion.description || "")
                        textFormat: Text.StyledText
                        color: Style.Theme.concepto_texto
                        font.pixelSize: 15 * root.s
                        wrapMode: Text.WordWrap
                    }
                }

                Repeater {
                    model: [
                        { "etiqueta": "Recibe", "valor": root.step.input || "" },
                        { "etiqueta": "Operación", "valor": root.step.operation || "" },
                        { "etiqueta": "¿Por qué?", "valor": root.step.why || "" },
                        { "etiqueta": "Qué cambia", "valor": root.step.change || "" },
                        { "etiqueta": "Produce", "valor": root.step.output || "" },
                        { "etiqueta": "Forma", "valor": root.step.dimensions || "" }
                    ]
                    delegate: RowLayout {
                        id: filaResumen
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 14 * root.s
                        Text {
                            Layout.preferredWidth: 130 * root.s
                            Layout.alignment: Qt.AlignTop
                            text: String(filaResumen.modelData.etiqueta).toUpperCase()
                            color: Style.Theme.texto_secundario
                            font.bold: true
                            font.pixelSize: 12 * root.s
                            font.letterSpacing: 0.6
                        }
                        Text {
                            Layout.fillWidth: true
                            text: String(filaResumen.modelData.valor)
                            color: Style.Theme.texto_primario
                            font.family: filaResumen.modelData.etiqueta === "Forma"
                                         ? Style.Theme.fuente_mono : Style.Theme.fuente_interfaz
                            font.pixelSize: 15 * root.s
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: String(root.lesson.clave || "").length > 0
                    Layout.preferredHeight: textoClave.implicitHeight + 24 * root.s
                    radius: 10 * root.s
                    color: Style.Theme.proceso_fondo
                    Text {
                        id: textoClave
                        anchors.fill: parent
                        anchors.margins: 12 * root.s
                        text: "Para recordar: " + String(root.lesson.clave || "")
                        color: Style.Theme.proceso_texto
                        font.bold: true
                        font.pixelSize: 15 * root.s
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ── Comprueba ───────────────────────────────────────────
            Seccion {
                titulo: "Pon a prueba la idea"
                visible: (root.tour ? root.tour.currentHasCheck : false) && root.revelada(7)

                PredictionCheck {
                    id: comprobacion
                    objectName: "moduleGuidedCheck"
                    Layout.fillWidth: true
                    sx: root.s * 1.3
                    eyebrow: "RESPONDE PARA PASAR AL SIGUIENTE PASO"
                    check: root.step.check || ({})
                    result: root.tour
                            ? (root.tour.checkResults[String(root.step.id || "")] || ({}))
                            : ({})
                    onSubmitted: function (optionIndex) { root.tour.submitCheck(optionIndex) }
                }
            }

            BotonPrincipal {
                objectName: "moduleGuidedContinue"
                visible: root.seccionRevelada < 7
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 220 * root.s
                Layout.preferredHeight: 42 * root.s
                text: "Seguir leyendo  ↓"
                onClicked: root.seguirLeyendo()
            }

            RowLayout {
                visible: root.seccionRevelada >= 7
                Layout.fillWidth: true
                spacing: 12 * root.s
                Text {
                    Layout.fillWidth: true
                    text: "Siguiente: " + String(root.step.next || "fin del recorrido")
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 13 * root.s
                    wrapMode: Text.WordWrap
                }
                BotonSecundario {
                    objectName: "moduleGuidedDeepDive"
                    Layout.preferredWidth: 230 * root.s
                    Layout.preferredHeight: 40 * root.s
                    sx: root.s
                    sy: root.s
                    text: "Profundizar en la teoría"
                    onClicked: root.tour.openTheoryConcept(root.tour.currentTheoryConceptId)
                }
            }
        }

        // Sigue a la lectura: queda a la vista mientras se desplaza la lección.
        Rectangle {
            objectName: "moduleGuidedTermsPanel"
            visible: root.panelTerminosVisible
            x: parent.width - width - 12 * root.s
            y: root.contentItem.contentY + 8 * root.s
            width: root.anchoPanelTerminos
            height: root.height - 16 * root.s
            radius: 10 * root.s
            color: Style.Theme.surface
            border.color: Style.Theme.borde_suave

            ListView {
                anchors.fill: parent
                anchors.margins: 10 * root.s
                clip: true
                spacing: 8 * root.s
                model: root.terminosParaPanel()
                delegate: Text {
                    required property var modelData
                    width: ListView.view.width
                    text: "<b>" + root.escaparHtml(modelData.termino) + ".</b> "
                          + root.escaparHtml(modelData.definicion)
                    textFormat: Text.StyledText
                    color: Style.Theme.texto_primario
                    font.pixelSize: 13 * root.s
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
