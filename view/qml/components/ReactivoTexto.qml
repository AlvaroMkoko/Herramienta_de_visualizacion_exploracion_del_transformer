pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Reactivo de completar (T1 en ambas formas): el estudiante escribe el término
// que falta. La comparación contra las respuestas aceptadas ocurre en el modelo,
// que normaliza mayúsculas, acentos y signos; aquí no se valida nada ni se
// insinúa si lo escrito es correcto.
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
        return { "texto": campo.text }
    }

    function restaurar() {
        root.restaurando = true
        campo.text = (root.respuestaInicial && root.respuestaInicial.texto)
                     ? String(root.respuestaInicial.texto) : ""
        root.restaurando = false
    }

    Component.onCompleted: root.restaurar()
    onPreguntaChanged: root.restaurar()

    ColumnLayout {
        id: columna
        width: root.width
        spacing: 8 * root.sy

        CampoTextoPrincipal {
            id: campo
            objectName: "evaluationTextAnswer"
            Layout.fillWidth: true
            Layout.preferredHeight: 48 * root.sy
            sx: root.sx
            sy: root.sy
            font.pixelSize: 15 * root.sy
            placeholderText: (root.pregunta && root.pregunta.placeholder)
                             ? root.pregunta.placeholder : "Escribe tu respuesta"
            Accessible.name: "Respuesta escrita"

            onTextChanged: {
                if (!root.restaurando)
                    root.respuestaCambiada(root.respuestaActual())
            }
            Keys.onReturnPressed: campo.focus = false
        }

        Text {
            Layout.fillWidth: true
            text: "No importan las mayúsculas ni los acentos."
            color: Style.Theme.texto_terciario
            font.family: Style.Theme.fuente_interfaz
            font.pixelSize: 11 * root.sx
            wrapMode: Text.WordWrap
        }
    }
}
