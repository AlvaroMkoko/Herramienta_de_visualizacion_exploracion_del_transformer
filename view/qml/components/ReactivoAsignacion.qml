pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Reactivo de asignación: a cada elemento se le asigna un destino de una lista
// cerrada. Un mismo componente cubre tres formatos del instrumento, porque la
// interacción del estudiante es idéntica en los tres:
//
//   subtipo "ordenar"     destinos = 1..4          (T4, S4)
//   subtipo "clasificar"  destinos = categorías    (E4)
//   subtipo "relacionar"  destinos = definiciones  (A1, S2)
//
// `destinos_unicos` distingue ordenar/relacionar (cada destino se usa una sola
// vez) de clasificar (dos enunciados pueden caer en la misma categoría). Cuando
// es true, elegir un destino ya ocupado lo libera del otro elemento: es el
// intercambio que la gente espera al numerar una lista.
Item {
    id: root

    property var pregunta: ({})
    property var respuestaInicial: null
    property real sx: 1
    property real sy: 1

    signal respuestaCambiada(var valor)

    property var asignaciones: ({})

    // Estas propiedades derivadas son para los bindings de la vista. Dentro de
    // onPreguntaChanged NO se pueden usar: QML dispara el handler en cuanto se
    // asigna `pregunta`, pero reevalúa los bindings que dependen de ella
    // después, así que ahí todavía valen undefined. Para eso está listaDe().
    readonly property var elementos: root.listaDe("elementos")
    readonly property var destinos: root.listaDe("destinos")

    // Lee una lista directamente del objeto pregunta, sin pasar por ningún
    // binding intermedio. Siempre devuelve un arreglo.
    function listaDe(nombre) {
        if (!root.pregunta)
            return []
        var valor = root.pregunta[nombre]
        return (valor && valor.length !== undefined) ? valor : []
    }
    readonly property bool unicos: root.pregunta ? root.pregunta.destinos_unicos === true : false
    readonly property string etiquetaDestino: (root.pregunta && root.pregunta.etiqueta_destino)
                                              ? root.pregunta.etiqueta_destino : "Respuesta"
    readonly property bool esOrdenar: root.pregunta
                                      ? root.pregunta.subtipo === "ordenar" : false

    implicitHeight: columna.implicitHeight

    function respuestaActual() {
        var copia = {}
        for (var clave in root.asignaciones)
            copia[clave] = root.asignaciones[clave]
        return { "asignaciones": copia }
    }

    function restaurar() {
        var previas = (root.respuestaInicial && root.respuestaInicial.asignaciones)
                      ? root.respuestaInicial.asignaciones : ({})
        // listaDe() en vez de root.elementos: ver la nota de arriba.
        var lista = root.listaDe("elementos")
        var limpias = {}
        for (var i = 0; i < lista.length; ++i) {
            var elementoId = String(lista[i].id)
            if (previas[elementoId] !== undefined)
                limpias[elementoId] = String(previas[elementoId])
        }
        root.asignaciones = limpias
    }

    function destinoDe(elementoId) {
        return root.asignaciones[elementoId] !== undefined
               ? String(root.asignaciones[elementoId]) : ""
    }

    // Índice dentro de `destinos`, o -1. El ComboBox trabaja con índices y el
    // modelo con ids: esta es la única traducción entre ambos.
    function indiceDe(elementoId) {
        var destinoId = root.destinoDe(elementoId)
        if (destinoId === "")
            return -1
        var lista = root.listaDe("destinos")
        for (var i = 0; i < lista.length; ++i)
            if (String(lista[i].id) === destinoId)
                return i
        return -1
    }

    function asignar(elementoId, destinoId) {
        if (root.destinoDe(elementoId) === destinoId)
            return

        var copia = {}
        for (var clave in root.asignaciones)
            copia[clave] = root.asignaciones[clave]

        if (root.unicos) {
            // Liberar el destino de quien lo tuviera: sin esto, al renumerar una
            // lista quedarían dos elementos con el mismo número y el estudiante
            // no vería que perdió puntos hasta el final.
            for (var otro in copia)
                if (otro !== elementoId && copia[otro] === destinoId)
                    delete copia[otro]
        }

        copia[elementoId] = destinoId
        root.asignaciones = copia
        root.respuestaCambiada(root.respuestaActual())
    }

    Component.onCompleted: root.restaurar()
    onPreguntaChanged: root.restaurar()

    ColumnLayout {
        id: columna
        width: root.width
        spacing: 9 * root.sy

        Text {
            Layout.fillWidth: true
            visible: root.unicos
            text: root.esOrdenar
                  ? "Cada número se usa una sola vez: al repetirlo, se libera del otro paso."
                  : "Cada opción se usa una sola vez: al repetirla, se libera del otro elemento."
            color: Style.Theme.texto_terciario
            font.family: Style.Theme.fuente_interfaz
            font.pixelSize: 11 * root.sx
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.elementos

            delegate: Rectangle {
                id: fila
                required property var modelData
                required property int index

                readonly property string elementoId: String(fila.modelData.id)
                readonly property bool asignado: root.destinoDe(fila.elementoId) !== ""

                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(58 * root.sy,
                                                 textoElemento.implicitHeight + 24 * root.sy)
                radius: 11 * root.sx
                color: fila.asignado ? Style.Theme.acento_fondo : Style.Theme.surface
                border.width: fila.asignado ? 2 : 1
                border.color: fila.asignado ? Style.Theme.acento : Style.Theme.borde_suave
                Behavior on color { ColorAnimation { duration: 110 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14 * root.sx
                    anchors.rightMargin: 14 * root.sx
                    spacing: 12 * root.sx

                    Text {
                        id: textoElemento
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: fila.modelData.texto
                        color: Style.Theme.texto_primario
                        font.family: Style.Theme.fuente_interfaz
                        font.pixelSize: 14 * root.sx
                        lineHeight: 1.2
                        wrapMode: Text.WordWrap
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: root.esOrdenar
                                               ? 92 * root.sx : 250 * root.sx
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: root.etiquetaDestino
                            color: Style.Theme.texto_terciario
                            font.family: Style.Theme.fuente_interfaz
                            font.pixelSize: 9 * root.sx
                            font.bold: true
                        }

                        SelectorPrincipal {
                            id: selector
                            objectName: "evaluationAssign_" + fila.elementoId
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36 * root.sy
                            sx: root.sx
                            sy: root.sy
                            model: root.destinos
                            textRole: "texto"
                            displayText: fila.asignado
                                         ? selector.currentText
                                         : "Elegir…"
                            Accessible.name: root.etiquetaDestino + " para " + textoElemento.text

                            // `currentIndex` se sincroniza desde el estado del
                            // padre, nunca al revés: el ComboBox es solo la
                            // superficie de edición.
                            currentIndex: root.indiceDe(fila.elementoId)

                            onActivated: function (indice) {
                                var lista = root.listaDe("destinos")
                                if (indice >= 0 && indice < lista.length)
                                    root.asignar(fila.elementoId,
                                                 String(lista[indice].id))
                            }
                        }
                    }
                }
            }
        }
    }
}
