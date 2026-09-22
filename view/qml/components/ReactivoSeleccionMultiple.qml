pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Reactivo de selección múltiple (E2 en ambas formas): varias afirmaciones
// correctas entre las presentadas.
//
// El estudiante ve una advertencia explícita de que marcar de más resta, porque
// el criterio es (aciertos − errores) / total de correctas: marcar todo no es
// una estrategia ganadora y eso debe saberlo antes de responder, no después.
Item {
    id: root

    property var pregunta: ({})
    property var respuestaInicial: null
    property real sx: 1
    property real sy: 1

    signal respuestaCambiada(var valor)

    property var seleccionadas: []

    readonly property var opciones: (root.pregunta && root.pregunta.options)
                                    ? root.pregunta.options : []

    implicitHeight: columna.implicitHeight

    function respuestaActual() {
        return { "opciones_ids": root.seleccionadas.slice() }
    }

    function restaurar() {
        var previas = (root.respuestaInicial && root.respuestaInicial.opciones_ids)
                      ? root.respuestaInicial.opciones_ids : []
        var limpias = []
        for (var i = 0; i < previas.length; ++i)
            limpias.push(String(previas[i]))
        root.seleccionadas = limpias
    }

    function estaMarcada(opcionId) {
        return root.seleccionadas.indexOf(opcionId) !== -1
    }

    function alternar(opcionId) {
        var copia = root.seleccionadas.slice()
        var posicion = copia.indexOf(opcionId)
        if (posicion === -1)
            copia.push(opcionId)
        else
            copia.splice(posicion, 1)
        root.seleccionadas = copia
        root.respuestaCambiada(root.respuestaActual())
    }

    Component.onCompleted: root.restaurar()
    onPreguntaChanged: root.restaurar()

    ColumnLayout {
        id: columna
        width: root.width
        spacing: 9 * root.sy

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: avisoTexto.implicitHeight + 18 * root.sy
            radius: 8 * root.sx
            color: Style.Theme.aviso_fondo
            border.width: 1
            border.color: Style.Theme.warning

            Text {
                id: avisoTexto
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12 * root.sx
                anchors.rightMargin: 12 * root.sx
                text: "Marca todas las que apliquen. Cada opción marcada de más "
                      + "resta puntos, así que marcarlas todas no conviene."
                color: Style.Theme.aviso_texto
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 11 * root.sx
                wrapMode: Text.WordWrap
            }
        }

        Repeater {
            model: root.opciones

            delegate: Rectangle {
                id: fila
                required property var modelData

                readonly property bool marcada: root.estaMarcada(String(fila.modelData.id))

                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(52 * root.sy,
                                                 casilla.implicitHeight + 20 * root.sy)
                radius: 11 * root.sx
                color: fila.marcada ? Style.Theme.acento_fondo : Style.Theme.surface
                border.width: fila.marcada ? 2 : 1
                border.color: fila.marcada ? Style.Theme.acento : Style.Theme.borde_suave
                Behavior on color { ColorAnimation { duration: 110 } }

                CasillaPrincipal {
                    id: casilla
                    objectName: "evaluationCheck_" + fila.modelData.id
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 14 * root.sx
                    anchors.rightMargin: 14 * root.sx
                    sx: root.sx
                    sy: root.sy
                    text: fila.modelData.text
                    checked: fila.marcada
                    Accessible.name: text

                    // El estado lo manda `seleccionadas`, no el CheckBox: si el
                    // binding y el control se pelearan, la vista mostraría una
                    // cosa y el modelo registraría otra.
                    onToggled: root.alternar(String(fila.modelData.id))
                }
            }
        }
    }
}
