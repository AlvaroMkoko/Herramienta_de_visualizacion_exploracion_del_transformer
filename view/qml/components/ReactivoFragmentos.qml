pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Reactivo de detectar y corregir (A3 en ambas formas) · presentación
// «fragmentos_clicables».
//
// La afirmación se muestra como una sola oración corrida en la que cuatro
// tramos son seleccionables. El estudiante señala el tramo equivocado tocándolo
// dentro de la frase, no eligiendo de una lista que repite los cuatro tramos
// fuera de contexto: leer «[2] la máscara bloquea el triángulo inferior» suelto
// es una tarea distinta de leerlo dentro de la oración que lo rodea, y el
// reactivo mide la segunda.
//
// Produce el mismo tipo de respuesta que ReactivoEtapas («etapas»), porque el
// modelo no sabe nada de presentaciones: solo cambia cómo se ve y se toca.
//
// Este componente dibuja el enunciado, así que la pantalla NO debe volver a
// dibujarlo (ver `reactivoDibujaEnunciado` en EvaluationScreen.qml).
Item {
    id: root

    property var pregunta: ({})
    property var respuestaInicial: null
    property real sx: 1
    property real sy: 1

    signal respuestaCambiada(var valor)

    property var respuestasEtapas: ({})
    property string fragmentoSobrevolado: ""

    readonly property var etapas: (root.pregunta && root.pregunta.etapas)
                                  ? root.pregunta.etapas : []

    readonly property var etapaDeteccion: root.etapaPorIndice(0)
    readonly property var etapaCorreccion: root.etapaPorIndice(1)

    readonly property string idDeteccion: root.etapaDeteccion
                                          ? String(root.etapaDeteccion.id) : "e1"
    readonly property string idCorreccion: root.etapaCorreccion
                                           ? String(root.etapaCorreccion.id) : "e2"

    readonly property string fragmentoElegido: {
        var valor = root.respuestasEtapas[root.idDeteccion]
        return (valor && valor.opcion_id !== undefined) ? String(valor.opcion_id) : ""
    }

    readonly property string correccionElegida: {
        var valor = root.respuestasEtapas[root.idCorreccion]
        return (valor && valor.opcion_id !== undefined) ? String(valor.opcion_id) : ""
    }

    readonly property var analisis: root.analizarEnunciado()
    readonly property string instruccion: root.analisis.instruccion
    readonly property var palabras: root.analisis.palabras
    readonly property bool enunciadoParseado: root.analisis.fragmentosHallados > 0

    // Los fragmentos declarados en el banco. Solo se usan para el respaldo:
    // la oración se arma del enunciado, que es donde vive el texto conectivo.
    readonly property var fragmentos: (root.pregunta && root.pregunta.fragmentos)
                                      ? root.pregunta.fragmentos : []

    implicitHeight: columna.implicitHeight

    function etapaPorIndice(indice) {
        return (root.etapas.length > indice) ? root.etapas[indice] : null
    }

    // Separa la instrucción de la afirmación y convierte la afirmación en una
    // lista plana de palabras, cada una sabiendo a qué fragmento pertenece.
    //
    // Se trabaja sobre palabras sueltas, no sobre un bloque de texto por
    // fragmento, para que el Flow pueda cortar el renglón en cualquier punto:
    // un fragmento largo dentro de un solo elemento obligaría a partir la
    // oración en bloques y dejaría de leerse como una frase.
    function analizarEnunciado() {
        var vacio = { "instruccion": "", "palabras": [], "fragmentosHallados": 0 }
        if (!root.pregunta || !root.pregunta.prompt)
            return vacio

        var texto = String(root.pregunta.prompt)
        var instruccion = ""
        var afirmacion = texto

        var separador = texto.indexOf("\n\n")
        if (separador !== -1) {
            instruccion = texto.substring(0, separador).trim()
            afirmacion = texto.substring(separador + 2)
        }

        // Las comillas angulares se quitan: el bloque ya se presenta como cita.
        afirmacion = afirmacion.replace(/[«»]/g, "").trim()

        // split con grupo de captura intercala literales e identificadores:
        //   ["texto previo ", "1", " fragmento uno, ", "2", " fragmento dos…"]
        var piezas = afirmacion.split(/\[(\d+)\]/)
        var palabras = []
        var hallados = 0

        for (var i = 0; i < piezas.length; ++i) {
            if (i % 2 === 1)
                continue  // el identificador se toma desde la pieza siguiente
            var fragmentoId = (i === 0) ? "" : String(piezas[i - 1])
            if (fragmentoId !== "")
                hallados += 1

            var sueltas = String(piezas[i]).split(/\s+/)
            var primera = true
            for (var j = 0; j < sueltas.length; ++j) {
                if (sueltas[j] === "")
                    continue
                palabras.push({
                    "texto": sueltas[j],
                    "fragmentoId": fragmentoId,
                    "esInicio": fragmentoId !== "" && primera
                })
                primera = false
            }
        }

        return { "instruccion": instruccion, "palabras": palabras,
                 "fragmentosHallados": hallados }
    }

    function respuestaActual() {
        var copia = {}
        for (var clave in root.respuestasEtapas)
            copia[clave] = root.respuestasEtapas[clave]
        return { "etapas": copia }
    }

    function restaurar() {
        var previas = (root.respuestaInicial && root.respuestaInicial.etapas)
                      ? root.respuestaInicial.etapas : ({})
        var limpias = {}
        for (var clave in previas)
            limpias[clave] = previas[clave]
        root.respuestasEtapas = limpias
        root.fragmentoSobrevolado = ""
    }

    function registrar(etapaId, opcionId) {
        var copia = {}
        for (var clave in root.respuestasEtapas)
            copia[clave] = root.respuestasEtapas[clave]
        copia[etapaId] = { "opcion_id": String(opcionId) }
        root.respuestasEtapas = copia
        root.respuestaCambiada(root.respuestaActual())
    }

    function elegirFragmento(fragmentoId) {
        if (root.fragmentoElegido === String(fragmentoId))
            return
        root.registrar(root.idDeteccion, fragmentoId)
    }

    function elegirCorreccion(opcionId) {
        if (root.correccionElegida === String(opcionId))
            return
        root.registrar(root.idCorreccion, opcionId)
    }

    Component.onCompleted: root.restaurar()
    onPreguntaChanged: root.restaurar()

    ColumnLayout {
        id: columna
        width: root.width
        spacing: 16 * root.sy

        // ── Instrucción ──────────────────────────────────────────────
        Text {
            Layout.fillWidth: true
            visible: root.instruccion !== ""
            text: root.instruccion
            color: Style.Theme.texto_primario
            font.family: Style.Theme.fuente_interfaz
            font.pixelSize: 20 * root.sx
            font.bold: true
            lineHeight: 1.2
            wrapMode: Text.WordWrap
        }

        // ── La afirmación, con los tramos seleccionables ─────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: oracion.implicitHeight + 34 * root.sy
            visible: root.enunciadoParseado
            radius: 12 * root.sx
            color: Style.Theme.superficie_alterna
            border.width: 1
            border.color: Style.Theme.borde_suave

            // Barra de cita.
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 10 * root.sy
                width: 3 * root.sx
                radius: width / 2
                color: Style.Theme.acento_alt
            }

            Flow {
                id: oracion
                objectName: "evaluationFragmentSentence"
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 26 * root.sx
                anchors.rightMargin: 17 * root.sx
                anchors.topMargin: 17 * root.sy
                spacing: 0

                Repeater {
                    model: root.palabras

                    delegate: Item {
                        id: palabra
                        required property var modelData

                        readonly property string fragmentoId: String(palabra.modelData.fragmentoId)
                        readonly property bool esFragmento: palabra.fragmentoId !== ""
                        readonly property bool elegida: palabra.esFragmento
                                && root.fragmentoElegido === palabra.fragmentoId
                        readonly property bool sobrevolada: palabra.esFragmento
                                && root.fragmentoSobrevolado === palabra.fragmentoId

                        implicitWidth: (palabra.modelData.esInicio ? insignia.width + 5 * root.sx : 0)
                                       + letras.implicitWidth
                        implicitHeight: 34 * root.sy

                        Rectangle {
                            anchors.fill: parent
                            visible: palabra.esFragmento
                            color: palabra.elegida
                                   ? Style.Theme.acento_fondo
                                   : (palabra.sobrevolada
                                      ? Style.Theme.chip_fondo : "transparent")
                            Behavior on color { ColorAnimation { duration: 90 } }
                        }

                        // Subrayado: punteado suave mientras el tramo está
                        // disponible, sólido y en acento cuando está elegido.
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 5 * root.sy
                            anchors.rightMargin: 4 * root.sx
                            visible: palabra.esFragmento
                            height: palabra.elegida ? 2.5 * root.sy : 1 * root.sy
                            color: palabra.elegida
                                   ? Style.Theme.acento : Style.Theme.borde_medio
                            opacity: palabra.elegida ? 1 : (palabra.sobrevolada ? 0.9 : 0.55)
                        }

                        Rectangle {
                            id: insignia
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !!palabra.modelData.esInicio
                            width: visible ? 19 * root.sx : 0
                            height: 19 * root.sx
                            radius: width / 2
                            color: palabra.elegida
                                   ? Style.Theme.acento : Style.Theme.chip_fondo
                            border.width: palabra.elegida ? 0 : 1
                            border.color: Style.Theme.chip_borde

                            Text {
                                anchors.centerIn: parent
                                text: palabra.fragmentoId
                                color: palabra.elegida
                                       ? Style.Theme.texto_sobre_acento
                                       : Style.Theme.texto_secundario
                                font.family: Style.Theme.fuente_interfaz
                                font.pixelSize: 10 * root.sx
                                font.bold: true
                            }
                        }

                        Text {
                            id: letras
                            anchors.left: parent.left
                            anchors.leftMargin: palabra.modelData.esInicio
                                                ? insignia.width + 5 * root.sx : 0
                            anchors.verticalCenter: parent.verticalCenter
                            // El espacio va dentro del elemento: con spacing 0
                            // en el Flow, el resaltado de un tramo queda
                            // continuo entre palabra y palabra.
                            text: palabra.modelData.texto + " "
                            color: Style.Theme.texto_primario
                            font.family: Style.Theme.fuente_interfaz
                            font.pixelSize: 19 * root.sx
                            font.bold: palabra.elegida
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: palabra.esFragmento
                            hoverEnabled: true
                            cursorShape: palabra.esFragmento
                                         ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onEntered: root.fragmentoSobrevolado = palabra.fragmentoId
                            onExited: {
                                if (root.fragmentoSobrevolado === palabra.fragmentoId)
                                    root.fragmentoSobrevolado = ""
                            }
                            onClicked: root.elegirFragmento(palabra.fragmentoId)
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.enunciadoParseado
            text: root.fragmentoElegido === ""
                  ? "Toca dentro de la frase el tramo que contiene el error."
                  : "Señalaste el tramo " + root.fragmentoElegido
                    + ". Puedes tocar otro para cambiarlo."
            color: root.fragmentoElegido === ""
                   ? Style.Theme.texto_secundario : Style.Theme.acento_fuerte
            font.family: Style.Theme.fuente_interfaz
            font.pixelSize: 13 * root.sx
            wrapMode: Text.WordWrap
        }

        // ── Respaldo: si el enunciado no se pudo separar en tramos, los
        //    fragmentos se listan uno por renglón. Nunca se queda sin forma
        //    de contestar por un cambio de redacción en el banco.
        ColumnLayout {
            Layout.fillWidth: true
            visible: !root.enunciadoParseado
            spacing: 8 * root.sy

            Text {
                Layout.fillWidth: true
                text: root.pregunta && root.pregunta.prompt ? root.pregunta.prompt : ""
                color: Style.Theme.texto_primario
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 18 * root.sx
                lineHeight: 1.22
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: root.fragmentos

                delegate: Button {
                    id: filaFragmento
                    required property var modelData

                    readonly property string fragmentoId: String(filaFragmento.modelData.id)
                    readonly property bool elegida: root.fragmentoElegido === filaFragmento.fragmentoId

                    objectName: "evaluationFragmentRow_" + filaFragmento.fragmentoId
                    Layout.fillWidth: true
                    Layout.minimumHeight: 48 * root.sy
                    Layout.preferredHeight: Math.max(48 * root.sy,
                                                     textoFila.implicitHeight + 22 * root.sy)
                    onClicked: root.elegirFragmento(filaFragmento.fragmentoId)

                    background: Rectangle {
                        radius: 10 * root.sx
                        color: filaFragmento.elegida
                               ? Style.Theme.acento_fondo
                               : (filaFragmento.hovered
                                  ? Style.Theme.superficie_alterna : Style.Theme.surface)
                        border.width: filaFragmento.elegida ? 2 : 1
                        border.color: filaFragmento.elegida
                                      ? Style.Theme.acento : Style.Theme.borde_suave
                    }
                    contentItem: RowLayout {
                        spacing: 10 * root.sx
                        Text {
                            text: "[" + filaFragmento.fragmentoId + "]"
                            color: Style.Theme.acento_fuerte
                            font.family: Style.Theme.fuente_mono
                            font.pixelSize: 13 * root.sx
                            font.bold: true
                        }
                        Text {
                            id: textoFila
                            Layout.fillWidth: true
                            text: filaFragmento.modelData.texto || ""
                            color: Style.Theme.texto_primario
                            font.family: Style.Theme.fuente_interfaz
                            font.pixelSize: 14 * root.sx
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            visible: root.fragmentoElegido !== ""
            color: Style.Theme.divisor
        }

        // ── Etapa 2: la corrección ───────────────────────────────────
        //
        // Aparece solo después de señalar el tramo. Mostrar antes las cuatro
        // correcciones delataría el error: cada una nombra el tramo que
        // corrige.
        ColumnLayout {
            id: bloqueCorreccion
            Layout.fillWidth: true
            visible: root.fragmentoElegido !== "" && !!root.etapaCorreccion
            spacing: 9 * root.sy
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * root.sx

                Rectangle {
                    Layout.preferredWidth: 24 * root.sx
                    Layout.preferredHeight: 24 * root.sx
                    radius: width / 2
                    color: Style.Theme.acento_fondo
                    border.width: 1
                    border.color: Style.Theme.acento_alt
                    Text {
                        anchors.centerIn: parent
                        text: "2"
                        color: Style.Theme.acento_fuerte
                        font.family: Style.Theme.fuente_interfaz
                        font.pixelSize: 11 * root.sx
                        font.bold: true
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.etapaCorreccion
                          ? (root.etapaCorreccion.titulo || "Corregir") : "Corregir"
                    color: Style.Theme.acento_fuerte
                    font.family: Style.Theme.fuente_interfaz
                    font.pixelSize: 11 * root.sx
                    font.bold: true
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.etapaCorreccion ? (root.etapaCorreccion.prompt || "") : ""
                color: Style.Theme.texto_primario
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 16 * root.sx
                lineHeight: 1.22
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: root.etapaCorreccion && root.etapaCorreccion.options
                       ? root.etapaCorreccion.options : []

                delegate: Button {
                    id: opcion
                    required property var modelData
                    required property int index

                    readonly property string opcionId: String(opcion.modelData.id)
                    readonly property bool elegida: root.correccionElegida === opcion.opcionId

                    objectName: "evaluationOption_" + opcion.opcionId
                    Layout.fillWidth: true
                    Layout.minimumHeight: 54 * root.sy
                    Layout.preferredHeight: Math.max(54 * root.sy,
                                                     textoOpcion.implicitHeight + 26 * root.sy)
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: textoOpcion.text
                    onClicked: root.elegirCorreccion(opcion.opcionId)

                    background: Rectangle {
                        radius: 11 * root.sx
                        color: opcion.elegida
                               ? Style.Theme.acento_fondo
                               : (opcion.hovered
                                  ? Style.Theme.superficie_alterna : Style.Theme.surface)
                        border.width: opcion.elegida ? 2 : 1
                        border.color: opcion.elegida
                                      ? Style.Theme.acento
                                      : (opcion.hovered
                                         ? Style.Theme.acento_alt : Style.Theme.borde_suave)
                        Behavior on color { ColorAnimation { duration: 110 } }
                    }

                    contentItem: RowLayout {
                        spacing: 12 * root.sx

                        Rectangle {
                            Layout.preferredWidth: 28 * root.sx
                            Layout.preferredHeight: 28 * root.sx
                            Layout.alignment: Qt.AlignVCenter
                            radius: width / 2
                            color: opcion.elegida ? Style.Theme.acento : "transparent"
                            border.width: opcion.elegida ? 0 : 1.5
                            border.color: Style.Theme.borde_medio

                            Text {
                                anchors.centerIn: parent
                                text: opcion.opcionId.toUpperCase()
                                color: opcion.elegida
                                       ? Style.Theme.texto_sobre_acento
                                       : Style.Theme.texto_secundario
                                font.family: Style.Theme.fuente_interfaz
                                font.pixelSize: 12 * root.sx
                                font.bold: true
                            }
                        }

                        Text {
                            id: textoOpcion
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: opcion.modelData.text
                            color: Style.Theme.texto_primario
                            font.family: Style.Theme.fuente_interfaz
                            font.pixelSize: 14 * root.sx
                            lineHeight: 1.22
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
