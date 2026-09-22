pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Justificación escrita. Solo aparece como etapa dentro de un reactivo por
// etapas (F2 en ambas formas) y **nunca puntúa**: el criterio la trata como dato
// cualitativo, igual que el campo de explicación del recorrido guiado POE.
//
// Tampoco bloquea el avance. Obligar a escribir para poder continuar produciría
// texto de relleno de quien no quiere justificar, que es peor dato que un campo
// vacío honesto.
Item {
    id: root

    property var pregunta: ({})
    property var respuestaInicial: null
    property real sx: 1
    property real sy: 1

    signal respuestaCambiada(var valor)

    // Asignar el texto dentro de restaurar() también dispara
    // onTextChanged. Sin esta bandera, restaurar un reactivo devolvería
    // al controlador la respuesta que se acaba de leer de él.
    property bool restaurando: false

    implicitHeight: columna.implicitHeight

    function respuestaActual() {
        return { "texto": area.text }
    }

    function restaurar() {
        root.restaurando = true
        area.text = (root.respuestaInicial && root.respuestaInicial.texto)
                    ? String(root.respuestaInicial.texto) : ""
        root.restaurando = false
    }

    Component.onCompleted: root.restaurar()
    onPreguntaChanged: root.restaurar()

    ColumnLayout {
        id: columna
        width: root.width
        spacing: 6 * root.sy

        AreaTextoPrincipal {
            id: area
            objectName: "evaluationJustification"
            Layout.fillWidth: true
            Layout.preferredHeight: 108 * root.sy
            sx: root.sx
            sy: root.sy
            wrapMode: TextArea.Wrap
            placeholderText: (root.pregunta && root.pregunta.placeholder)
                             ? root.pregunta.placeholder
                             : "Escribe tu justificación (opcional)"
            Accessible.name: "Justificación escrita, opcional"

            onTextChanged: {
                if (!root.restaurando)
                    root.respuestaCambiada(root.respuestaActual())
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Opcional. Puedes continuar sin escribir nada."
            color: Style.Theme.texto_terciario
            font.family: Style.Theme.fuente_interfaz
            font.pixelSize: 11 * root.sx
            wrapMode: Text.WordWrap
        }
    }
}
