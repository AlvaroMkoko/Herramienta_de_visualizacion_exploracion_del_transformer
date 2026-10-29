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
// Si el reactivo trae `banco_opciones`, el hueco se llena eligiendo una ficha
// del banco en vez de escribir. Con texto libre, el estudiante que sabía la
// respuesta no sabía si escribir «Q» o «Query», ni si un error de ortografía
// le costaba el punto. El banco convierte la evocación en reconocimiento (otro
// nivel cognitivo, por eso subió la versión del instrumento modular), pero
// mide el concepto y no la manera de escribirlo. Sin banco queda el campo, y
// con `formato_respuesta: "numero"` sólo admite un número.
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

    readonly property var banco: (root.pregunta && root.pregunta.banco_opciones)
                                 ? root.pregunta.banco_opciones : []
    readonly property bool conBanco: root.banco.length > 0
    readonly property bool esNumero: !!(root.pregunta
                                        && root.pregunta.formato_respuesta === "numero")
    property string elegida: ""

    implicitHeight: columna.implicitHeight

    RegularExpressionValidator {
        id: validadorNumero
        regularExpression: /-?[0-9]*([.,][0-9]*)?/
    }

    TextMetrics {
        id: metricasPlaceholder
        font: campo.font
        text: campo.placeholderText
    }

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
        return { "texto": root.conBanco ? root.elegida : campo.text }
    }

    function restaurar() {
        root.restaurando = true
        var previa = (root.respuestaInicial && root.respuestaInicial.texto)
                     ? String(root.respuestaInicial.texto) : ""
        campo.text = previa
        root.elegida = previa
        root.restaurando = false
    }

    // Tocar la ficha ya elegida la devuelve al banco.
    function elegir(opcion) {
        root.elegida = (root.elegida === opcion) ? "" : String(opcion)
        root.respuestaCambiada(root.respuestaActual())
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

            // Hueco del banco: muestra la ficha elegida, o invita a elegir.
            Rectangle {
                id: hueco
                objectName: "evaluationBankSlot"
                visible: root.conBanco
                width: Math.max(230 * root.sx, textoHueco.implicitWidth + 36 * root.sx)
                height: campo.height
                radius: 10 * root.sx
                color: root.elegida !== "" ? Style.Theme.acento_fondo : "transparent"
                border.width: root.elegida !== "" ? 2 : 1.5
                border.color: root.elegida !== "" ? Style.Theme.acento : Style.Theme.borde_medio

                Text {
                    id: textoHueco
                    anchors.centerIn: parent
                    text: root.elegida !== "" ? root.elegida : "elige abajo ↓"
                    color: root.elegida !== "" ? Style.Theme.texto_primario
                                               : Style.Theme.texto_terciario
                    font.family: Style.Theme.fuente_interfaz
                    font.pixelSize: 17 * root.sy
                    font.bold: root.elegida !== ""
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.elegida !== ""
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.elegir(root.elegida)
                }
            }

            CampoTextoPrincipal {
                id: campo
                objectName: "evaluationTextAnswer"
                visible: !root.conBanco
                validator: root.esNumero ? validadorNumero : null
                // Crece con lo escrito para que la oración no salte de golpe,
                // pero nunca tanto como para empujar el resto fuera del renglón.
                width: Math.max(230 * root.sx,
                                Math.min(430 * root.sx,
                                         Math.max(contentWidth,
                                                  metricasPlaceholder.advanceWidth)
                                         + 46 * root.sx))
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
                Keys.onEscapePressed: campo.focus = false
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

        Flow {
            objectName: "evaluationAnswerBank"
            Layout.fillWidth: true
            visible: root.conBanco
            spacing: 8 * root.sx

            Repeater {
                model: root.banco

                delegate: BotonAccesible {
                    id: ficha
                    required property var modelData
                    readonly property bool marcada: root.elegida === String(ficha.modelData)
                    height: 42 * root.sy
                    width: etiquetaFicha.implicitWidth + 32 * root.sx
                    Accessible.name: String(ficha.modelData)
                    onClicked: root.elegir(String(ficha.modelData))

                    background: Rectangle {
                        radius: 10 * root.sx
                        color: ficha.marcada ? Style.Theme.acento
                                             : (ficha.hovered ? Style.Theme.acento_fondo
                                                              : Style.Theme.surface)
                        border.width: 1
                        border.color: ficha.marcada ? Style.Theme.acento : Style.Theme.borde_medio
                    }
                    contentItem: Text {
                        id: etiquetaFicha
                        text: String(ficha.modelData)
                        color: ficha.marcada ? Style.Theme.texto_sobre_acento
                                             : Style.Theme.texto_primario
                        font.family: Style.Theme.fuente_interfaz
                        font.pixelSize: 15 * root.sx
                        font.bold: ficha.marcada
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.conBanco
                  ? "Elige la opción que completa la frase. Para cambiarla, toca otra; para quitarla, tócala de nuevo."
                  : (root.esNumero
                     ? "Escribe sólo el número, sin unidades. Usa punto o coma para los decimales (0.5)."
                     : "No importan las mayúsculas ni los acentos.")
            color: Style.Theme.texto_terciario
            font.family: Style.Theme.fuente_interfaz
            font.pixelSize: 11 * root.sx
            wrapMode: Text.WordWrap
        }
    }
}
