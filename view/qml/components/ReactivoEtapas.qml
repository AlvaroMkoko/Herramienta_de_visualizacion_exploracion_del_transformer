pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Reactivo compuesto por etapas. Cubre tres formatos del instrumento:
//
//   A2  dos etapas          qué ocurre + por qué          (exigir_todas: true)
//   A3  detectar y corregir veredicto + corrección        (etapa 2 condicionada)
//   F2  verdadero/falso     V/F + justificación escrita   (etapa 2 no puntúa)
//
// Cada etapa se dibuja con el mismo componente que un reactivo suelto, así que
// agregar un tipo de etapa es registrarlo en `componenteParaEtapa`.
Item {
    id: root

    property var pregunta: ({})
    property var respuestaInicial: null
    property real sx: 1
    property real sy: 1

    signal respuestaCambiada(var valor)

    property var respuestasEtapas: ({})

    readonly property var etapas: (root.pregunta && root.pregunta.etapas)
                                  ? root.pregunta.etapas : []

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
    }

    function respuestaDe(etapaId) {
        return root.respuestasEtapas[etapaId] !== undefined
               ? root.respuestasEtapas[etapaId] : null
    }

    // Una etapa condicionada solo se muestra si su etapa padre tiene el valor
    // indicado. En A3, quien contesta «Sí» no ve la corrección; mostrársela
    // sería regalarle que la afirmación era falsa.
    function etapaAplica(etapa) {
        if (!etapa || !etapa.depende_de)
            return true
        var padre = root.respuestaDe(String(etapa.depende_de.etapa_id))
        return !!padre && String(padre.opcion_id || "")
               === String(etapa.depende_de.opcion_id)
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
        spacing: 16 * root.sy

        Repeater {
            model: root.etapas

            delegate: ColumnLayout {
                id: bloqueEtapa
                required property var modelData
                required property int index

                readonly property string etapaId: String(bloqueEtapa.modelData.id)
                readonly property bool aplica: root.etapaAplica(bloqueEtapa.modelData)
                readonly property bool esOpcional:
                    bloqueEtapa.modelData.puntua === false

                Layout.fillWidth: true
                spacing: 8 * root.sy
                visible: bloqueEtapa.aplica

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
                            text: bloqueEtapa.index + 1
                            color: Style.Theme.acento_fuerte
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
                        visible: bloqueEtapa.esOpcional
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
                }

                Text {
                    Layout.fillWidth: true
                    text: bloqueEtapa.modelData.prompt || ""
                    color: Style.Theme.texto_primario
                    font.family: Style.Theme.fuente_interfaz
                    font.pixelSize: 16 * root.sx
                    lineHeight: 1.22
                    wrapMode: Text.WordWrap
                }

                Loader {
                    id: cargadorEtapa
                    Layout.fillWidth: true
                    active: bloqueEtapa.aplica
                    sourceComponent: root.componenteParaEtapa(
                                         String(bloqueEtapa.modelData.tipo))

                    onLoaded: {
                        item.sx = Qt.binding(function () { return root.sx })
                        item.sy = Qt.binding(function () { return root.sy })
                        item.respuestaInicial = root.respuestaDe(bloqueEtapa.etapaId)
                        item.pregunta = bloqueEtapa.modelData
                        item.respuestaCambiada.connect(function (valor) {
                            root.registrarEtapa(bloqueEtapa.etapaId, valor)
                        })
                    }
                }
            }
        }
    }
}
