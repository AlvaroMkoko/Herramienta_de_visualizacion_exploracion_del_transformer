pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Reactivo compuesto por etapas. Cubre dos presentaciones del instrumento v3:
//
//   A2  «pasos»                dos etapas: resultado + razón   (exigir_todas)
//   F2  «botones_vf_acordeon»  V/F + justificación escrita     (etapa 2 no puntúa)
//
// A3 ya no llega aquí: su presentación «fragmentos_clicables» tiene componente
// propio, aunque el tipo de respuesta que produce sea el mismo.
//
// Cada etapa se dibuja con el mismo componente que un reactivo suelto, así que
// agregar un tipo de etapa es registrarlo en `componenteParaEtapa`.
//
// Dos comportamientos dependen de la presentación:
//
//   Revelación progresiva («pasos»). La etapa 2 no aparece hasta contestar la
//   1. Sin esto, A2 se puede resolver al revés: leer las razones, reconocer
//   cuál suena a teoría conocida y deducir el resultado desde ahí, que es un
//   proceso cognitivo distinto del que el reactivo pretende medir.
//
//   Bloqueo de etapas anteriores (solo si `exigir_todas`). Una vez visible la
//   etapa 2, la 1 queda en modo lectura. El botón «Cambiar» la reabre y BORRA
//   las etapas posteriores: se puede corregir un clic equivocado, pero no
//   acomodar el resultado después de haber visto las razones.
Item {
    id: root

    property var pregunta: ({})
    property var respuestaInicial: null
    property real sx: 1
    property real sy: 1

    signal respuestaCambiada(var valor)

    property var respuestasEtapas: ({})

    // Etapas que el estudiante reabrió a mano. Se reinicia con cada reactivo.
    property var etapasDesbloqueadas: ({})

    readonly property var etapas: (root.pregunta && root.pregunta.etapas)
                                  ? root.pregunta.etapas : []

    readonly property string presentacion: String(
        (root.pregunta && root.pregunta.presentacion) ? root.pregunta.presentacion : "")

    readonly property bool revelacionProgresiva: root.presentacion === "pasos"
    readonly property bool acordeonOpcional: root.presentacion === "botones_vf_acordeon"
    readonly property bool exigirTodas: !!(root.pregunta && root.pregunta.exigir_todas)

    implicitHeight: columna.implicitHeight

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
        root.etapasDesbloqueadas = ({})
    }

    function respuestaDe(etapaId) {
        return root.respuestasEtapas[etapaId] !== undefined
               ? root.respuestasEtapas[etapaId] : null
    }

    // Una etapa cuenta como contestada si tiene una opción elegida. El texto
    // libre no cuenta: F2 debe poder avanzar con la justificación vacía.
    function etapaContestada(etapaId) {
        var valor = root.respuestaDe(etapaId)
        return !!valor && String(valor.opcion_id || "") !== ""
    }

    // Una etapa condicionada solo se muestra si su etapa padre tiene el valor
    // indicado. El instrumento v3 ya no usa `depende_de`, pero el esquema lo
    // sigue admitiendo y quitarlo rompería bancos anteriores.
    function etapaAplica(etapa) {
        if (!etapa || !etapa.depende_de)
            return true
        var padre = root.respuestaDe(String(etapa.depende_de.etapa_id))
        return !!padre && String(padre.opcion_id || "")
               === String(etapa.depende_de.opcion_id)
    }

    // Con revelación progresiva, una etapa espera a que todas las anteriores
    // que puntúan estén contestadas.
    function etapaVisible(indice) {
        var etapa = root.etapas[indice]
        if (!root.etapaAplica(etapa))
            return false
        if (!root.revelacionProgresiva || indice === 0)
            return true
        for (var i = 0; i < indice; ++i) {
            var previa = root.etapas[i]
            if (previa.puntua === false || !root.etapaAplica(previa))
                continue
            if (!root.etapaContestada(String(previa.id)))
                return false
        }
        return true
    }

    function etapaBloqueada(indice) {
        if (!root.revelacionProgresiva || !root.exigirTodas)
            return false
        var etapaId = String(root.etapas[indice].id)
        if (root.etapasDesbloqueadas[etapaId])
            return false
        // Bloqueada solo si ya hay una etapa posterior visible, es decir, si
        // el estudiante ya pudo leer lo que viene después.
        for (var i = indice + 1; i < root.etapas.length; ++i) {
            if (root.etapaVisible(i))
                return true
        }
        return false
    }

    function desbloquear(indice) {
        var etapaId = String(root.etapas[indice].id)

        var desbloqueadas = {}
        for (var clave in root.etapasDesbloqueadas)
            desbloqueadas[clave] = root.etapasDesbloqueadas[clave]
        desbloqueadas[etapaId] = true
        root.etapasDesbloqueadas = desbloqueadas

        // Reabrir una etapa borra las posteriores: si no, la razón elegida
        // seguiría viajando al modelo después de cambiar el resultado.
        var copia = {}
        for (var clave2 in root.respuestasEtapas)
            copia[clave2] = root.respuestasEtapas[clave2]
        var huboCambio = false
        for (var i = indice + 1; i < root.etapas.length; ++i) {
            var posterior = String(root.etapas[i].id)
            if (copia[posterior] !== undefined) {
                delete copia[posterior]
                huboCambio = true
            }
        }
        if (huboCambio) {
            root.respuestasEtapas = copia
            root.respuestaCambiada(root.respuestaActual())
        }
    }

    function registrarEtapa(etapaId, valor) {
        var copia = {}
        for (var clave in root.respuestasEtapas)
            copia[clave] = root.respuestasEtapas[clave]
        copia[etapaId] = valor

        // Al cambiar una etapa padre, las hijas que dejan de aplicar se limpian:
        // si no, una corrección elegida antes de cambiar el veredicto seguiría
        // viajando al modelo sin estar visible.
        for (var i = 0; i < root.etapas.length; ++i) {
            var etapa = root.etapas[i]
            if (!etapa.depende_de)
                continue
            if (String(etapa.depende_de.etapa_id) !== etapaId)
                continue
            var sigueAplicando = !!copia[etapaId]
                    && String(copia[etapaId].opcion_id || "")
                       === String(etapa.depende_de.opcion_id)
            if (!sigueAplicando)
                delete copia[String(etapa.id)]
        }

        root.respuestasEtapas = copia
        root.respuestaCambiada(root.respuestaActual())
    }

    Component.onCompleted: root.restaurar()
    onPreguntaChanged: root.restaurar()

    Component { id: compOpcionUnicaEtapa; ReactivoOpcionUnica {} }
    Component { id: compTextoLibreEtapa; ReactivoTextoLibre {} }

    function componenteParaEtapa(tipo) {
        if (tipo === "opcion_unica")
            return compOpcionUnicaEtapa
        if (tipo === "texto_libre")
            return compTextoLibreEtapa
        return null
    }

    ColumnLayout {
        id: columna
        width: root.width
        spacing: 14 * root.sy

        Repeater {
            model: root.etapas

            delegate: Rectangle {
                id: bloqueEtapa
                required property var modelData
                required property int index

                readonly property string etapaId: String(bloqueEtapa.modelData.id)
                readonly property bool visibleAhora: root.etapaVisible(bloqueEtapa.index)
                readonly property bool bloqueada: root.etapaBloqueada(bloqueEtapa.index)
                readonly property bool esOpcional: bloqueEtapa.modelData.puntua === false
                readonly property bool enAcordeon: root.acordeonOpcional
                                                   && bloqueEtapa.esOpcional

                // Estado del acordeón. Se fija una sola vez para romper el
                // enlace: después manda el clic del estudiante, no el dato.
                property bool desplegada: false

                Component.onCompleted: {
                    bloqueEtapa.desplegada = !bloqueEtapa.enAcordeon
                            || root.respuestaDe(bloqueEtapa.etapaId) !== null
                }

                Layout.fillWidth: true
                Layout.preferredHeight: bloqueEtapa.visibleAhora
                                        ? contenidoEtapa.implicitHeight + 28 * root.sy
                                        : 0
                visible: bloqueEtapa.visibleAhora
                radius: 12 * root.sx
                color: bloqueEtapa.bloqueada
                       ? Style.Theme.superficie_alterna : "transparent"
                border.width: bloqueEtapa.bloqueada ? 1 : 0
                border.color: Style.Theme.borde_suave

                // La etapa recién revelada entra con una animación corta: es la
                // señal de que apareció contenido nuevo más abajo.
                opacity: bloqueEtapa.visibleAhora ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }

                ColumnLayout {
                    id: contenidoEtapa
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: bloqueEtapa.bloqueada ? 14 * root.sx : 0
                    anchors.topMargin: bloqueEtapa.bloqueada ? 14 * root.sy : 0
                    spacing: 8 * root.sy

                    // ── Cabecera de la etapa ─────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8 * root.sx

                        Rectangle {
                            Layout.preferredWidth: 24 * root.sx
                            Layout.preferredHeight: 24 * root.sx
                            radius: width / 2
                            color: bloqueEtapa.bloqueada
                                   ? Style.Theme.exito_fondo : Style.Theme.acento_fondo
                            border.width: 1
                            border.color: bloqueEtapa.bloqueada
                                          ? Style.Theme.exito_texto : Style.Theme.acento_alt

                            Text {
                                anchors.centerIn: parent
                                text: bloqueEtapa.bloqueada
                                      ? "✓" : String(bloqueEtapa.index + 1)
                                color: bloqueEtapa.bloqueada
                                       ? Style.Theme.exito_texto : Style.Theme.acento_fuerte
                                font.family: Style.Theme.fuente_interfaz
                                font.pixelSize: 11 * root.sx
                                font.bold: true
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: bloqueEtapa.modelData.titulo || ""
                            color: Style.Theme.acento_fuerte
                            font.family: Style.Theme.fuente_interfaz
                            font.pixelSize: 11 * root.sx
                            font.bold: true
                        }

                        Rectangle {
                            visible: bloqueEtapa.esOpcional && !bloqueEtapa.enAcordeon
                            Layout.preferredWidth: etiquetaOpcional.implicitWidth + 16 * root.sx
                            Layout.preferredHeight: 22 * root.sy
                            radius: height / 2
                            color: Style.Theme.chip_fondo
                            border.width: 1
                            border.color: Style.Theme.chip_borde

                            Text {
                                id: etiquetaOpcional
                                anchors.centerIn: parent
                                text: "No puntúa"
                                color: Style.Theme.texto_secundario
                                font.family: Style.Theme.fuente_interfaz
                                font.pixelSize: 10 * root.sx
                                font.bold: true
                            }
                        }

                        // Reapertura de una etapa bloqueada.
                        Button {
                            id: botonCambiar
                            objectName: "evaluationStageUnlock_" + bloqueEtapa.etapaId
                            visible: bloqueEtapa.bloqueada
                            Layout.preferredWidth: 96 * root.sx
                            Layout.preferredHeight: 28 * root.sy
                            Accessible.name: "Cambiar la respuesta de "
                                             + (bloqueEtapa.modelData.titulo || "esta etapa")
                            onClicked: root.desbloquear(bloqueEtapa.index)

                            background: Rectangle {
                                radius: height / 2
                                color: botonCambiar.hovered
                                       ? Style.Theme.acento_fondo : "transparent"
                                border.width: 1
                                border.color: Style.Theme.borde_medio
                            }
                            // Un Button con `background` pero sin `contentItem`
                            // dibuja el texto invisible.
                            contentItem: Text {
                                text: "Cambiar"
                                color: Style.Theme.acento_fuerte
                                font.family: Style.Theme.fuente_interfaz
                                font.pixelSize: 11 * root.sx
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    // ── Enunciado de la etapa ────────────────────────────
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: bloqueEtapa.modelData.prompt || ""
                        color: Style.Theme.texto_primario
                        font.family: Style.Theme.fuente_interfaz
                        font.pixelSize: 16 * root.sx
                        lineHeight: 1.22
                        wrapMode: Text.WordWrap
                    }

                    // ── Disparador del acordeón (solo etapas que no puntúan)
                    Button {
                        id: disparadorAcordeon
                        objectName: "evaluationStageDisclosure_" + bloqueEtapa.etapaId
                        visible: bloqueEtapa.enAcordeon && !bloqueEtapa.desplegada
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? 44 * root.sy : 0
                        Accessible.name: "Agregar una justificación, opcional"
                        onClicked: bloqueEtapa.desplegada = true

                        background: Rectangle {
                            radius: 10 * root.sx
                            color: disparadorAcordeon.hovered
                                   ? Style.Theme.superficie_alterna : "transparent"
                            border.width: 1
                            border.color: Style.Theme.borde_suave
                        }
                        contentItem: Text {
                            text: "＋  Agregar una justificación  ·  opcional, no puntúa"
                            color: Style.Theme.texto_secundario_fuerte
                            font.family: Style.Theme.fuente_interfaz
                            font.pixelSize: 13 * root.sx
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // ── Cuerpo de la etapa ───────────────────────────────
                    Loader {
                        id: cargadorEtapa
                        Layout.fillWidth: true
                        active: bloqueEtapa.visibleAhora && bloqueEtapa.desplegada
                        visible: active
                        enabled: !bloqueEtapa.bloqueada
                        opacity: bloqueEtapa.bloqueada ? 0.72 : 1
                        sourceComponent: root.componenteParaEtapa(
                                             String(bloqueEtapa.modelData.tipo))

                        onLoaded: {
                            if (!item)
                                return
                            item.sx = Qt.binding(function () { return root.sx })
                            item.sy = Qt.binding(function () { return root.sy })
                            // El orden importa: la respuesta previa va antes que
                            // la pregunta, porque asignar `pregunta` restaura.
                            item.respuestaInicial = root.respuestaDe(bloqueEtapa.etapaId)
                            item.pregunta = bloqueEtapa.modelData
                            // La señal se detecta por su método connect, no con
                            // hasOwnProperty: las señales declaradas en QML viven
                            // en el meta-objeto y hasOwnProperty no las ve.
                            if (item.respuestaCambiada
                                    && typeof item.respuestaCambiada.connect === "function") {
                                item.respuestaCambiada.connect(function (valor) {
                                    root.registrarEtapa(bloqueEtapa.etapaId, valor)
                                })
                            }
                        }
                    }
                }
            }
        }
    }
}
