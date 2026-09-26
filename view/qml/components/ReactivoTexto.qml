pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Reactivo de completar (T1 en ambas formas) · presentación «caja_en_linea».
//
// El enunciado trae un hueco marcado con guiones bajos. En lugar de mostrar la
// oración arriba y el campo suelto abajo, la oración se reconstruye palabra por
// palabra dentro de un Flow y el campo ocupa el lugar exacto del hueco. El
// estudiante lee la frase de corrido, que es como está redactada en el papel.
//
// Este componente dibuja el enunciado, así que la pantalla NO debe volver a
// dibujarlo (ver `reactivoDibujaEnunciado` en EvaluationScreen.qml).
//
// Deliberadamente NO hay banco de palabras: T1 está clasificado como «Recordar»
// con evocación libre. Ofrecer opciones lo convertiría en reconocimiento, que es
// otro nivel cognitivo, y dejaría de ser comparable con el instrumento en papel.
//
// La comparación contra las respuestas aceptadas ocurre en el modelo, que
// normaliza mayúsculas, acentos y signos; aquí no se valida nada ni se insinúa
// si lo escrito es correcto.
Item {
    id: root

    property var pregunta: ({})
    property var respuestaInicial: null
    property real sx: 1
    property real sy: 1

    signal respuestaCambiada(var valor)

    // Asignar el texto dentro de restaurar() también dispara onTextChanged. Sin
    // esta bandera, restaurar un reactivo devolvería al controlador la respuesta
    // que se acaba de leer de él.
    property bool restaurando: false

    readonly property string enunciado: String(
        (root.pregunta && root.pregunta.prompt) ? root.pregunta.prompt : "")

    // Tres guiones bajos o más cuentan como hueco: el banco usa ocho, pero no
    // conviene que la vista dependa de cuántos escribió quien redactó el
    // reactivo.
    readonly property var corte: root.partirEnunciado()

    readonly property var palabrasAntes: root.corte.antes
    readonly property var palabrasDespues: root.corte.despues

    implicitHeight: columna.implicitHeight

    // Devuelve las palabras a cada lado del hueco. Si el enunciado no trae
    // hueco, todo queda del lado izquierdo y el campo aparece al final: así
    // nunca se pierde el texto de la pregunta, pase lo que pase con el banco.
    function partirEnunciado() {
        var texto = root.enunciado
        var marca = /_{3,}/
        var encontrado = texto.match(marca)
        if (!encontrado)
            return { "antes": root.enPalabras(texto), "despues": [] }
        var corteInicio = texto.indexOf(encontrado[0])
        return {
            "antes": root.enPalabras(texto.substring(0, corteInicio)),
            "despues": root.enPalabras(texto.substring(corteInicio + encontrado[0].length))
        }
    }

    function enPalabras(texto) {
        return String(texto).split(/\s+/).filter(function (palabra) {
            return palabra !== ""
        })
    }

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
        spacing: 14 * root.sy

        Flow {
            id: oracion
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            spacing: 7 * root.sx

            Repeater {
                model: root.palabrasAntes
                delegate: Text {
                    id: palabraAntes
                    required property var modelData
                    text: palabraAntes.modelData
                    color: Style.Theme.texto_primario
                    font.family: Style.Theme.fuente_interfaz
                    font.pixelSize: 19 * root.sx
                    height: campo.height
                    verticalAlignment: Text.AlignVCenter
                }
            }

            CampoTextoPrincipal {
                id: campo
                objectName: "evaluationTextAnswer"
                // Crece con lo escrito para que la oración no salte de golpe,
                // pero nunca tanto como para empujar el resto fuera del renglón.
                width: Math.max(230 * root.sx,
                                Math.min(430 * root.sx, contentWidth + 46 * root.sx))
                height: 46 * root.sy
                sx: root.sx
                sy: root.sy
                font.pixelSize: 17 * root.sy
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                placeholderText: (root.pregunta && root.pregunta.placeholder)
                                 ? root.pregunta.placeholder : "Escribe tu respuesta"
                Accessible.name: "Palabra que falta en la oración"

                Behavior on width { NumberAnimation { duration: 90 } }

                onTextChanged: {
                    if (!root.restaurando)
                        root.respuestaCambiada(root.respuestaActual())
                }
                Keys.onReturnPressed: campo.focus = false
            }

            Repeater {
                model: root.palabrasDespues
                delegate: Text {
                    id: palabraDespues
                    required property var modelData
                    text: palabraDespues.modelData
                    color: Style.Theme.texto_primario
                    font.family: Style.Theme.fuente_interfaz
                    font.pixelSize: 19 * root.sx
                    height: campo.height
                    verticalAlignment: Text.AlignVCenter
                }
            }
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
