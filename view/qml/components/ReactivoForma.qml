pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Forma de un tensor · presentación «forma_tensor».
//
// Con un campo libre, «[5,5]», «5x5» o «cinco por cinco» parecían igual de
// válidos y el estudiante no sabía cómo escribir la respuesta. Aquí la forma
// se arma eje por eje: una casilla por eje entre corchetes, que sólo admite
// un número o un símbolo, y los símbolos del recorrido (B, T, d_model…) a un
// toque para no tener que adivinar cómo se escribe «d_model».
//
// Empieza con dos ejes y el estudiante agrega o quita los que hagan falta:
// mostrar ya el número correcto de casillas regalaría la mitad de la respuesta.
//
// La respuesta sigue siendo `{"texto": "[a,b]"}`, la misma que calificaba el
// campo libre; sólo se entrega cuando no queda ninguna casilla vacía.
Item {
    id: root

    property var pregunta: ({})
    property var respuestaInicial: null
    property real sx: 1
    property real sy: 1

    signal respuestaCambiada(var valor)

    readonly property int ejesMinimos: 1
    readonly property int ejesMaximos: 4
    property var ejes: ["", ""]
    // Casilla que recibe el símbolo tocado en la paleta.
    property int activo: 0

    readonly property var simbolos: (root.pregunta && root.pregunta.simbolos)
                                    ? root.pregunta.simbolos : []
    readonly property bool completa: root.ejes.length > 0
                                     && root.ejes.every(function (eje) { return eje !== "" })
    readonly property string textoForma: "[" + root.ejes.map(function (eje) {
        return eje === "" ? "?" : eje
    }).join(", ") + "]"

    implicitHeight: columna.implicitHeight

    function respuestaActual() {
        return { "texto": root.completa ? "[" + root.ejes.join(",") + "]" : "" }
    }

    function restaurar() {
        var texto = (root.respuestaInicial && root.respuestaInicial.texto)
                    ? String(root.respuestaInicial.texto) : ""
        var dentro = texto.replace(/^\s*\[/, "").replace(/\]\s*$/, "")
        var partes = dentro === "" ? [] : dentro.split(",").map(function (parte) {
            return parte.trim()
        })
        while (partes.length < 2)
            partes.push("")
        root.ejes = partes.slice(0, root.ejesMaximos)
        root.activo = 0
    }

    // Lo escrito a mano se lleva al símbolo oficial («DMODEL» → «d_model»),
    // porque el calificador separa por signos y «dmodel» no es «d model».
    function canonico(texto) {
        var limpio = String(texto).trim()
        var clave = limpio.toLowerCase().replace(/[^0-9a-z|]/g, "")
        for (var i = 0; i < root.simbolos.length; ++i) {
            var simbolo = String(root.simbolos[i])
            if (simbolo.toLowerCase().replace(/[^0-9a-z|]/g, "") === clave)
                return simbolo
        }
        return limpio
    }

    function fijar(indice, valor) {
        var copia = root.ejes.slice()
        copia[indice] = root.canonico(valor)
        root.ejes = copia
        root.respuestaCambiada(root.respuestaActual())
    }

    function ponerSimbolo(simbolo) {
        var destino = root.activo
        if (root.ejes[destino] !== "") {
            var vacio = root.ejes.indexOf("")
            if (vacio !== -1)
                destino = vacio
        }
        root.fijar(destino, simbolo)
        root.activo = Math.min(destino + 1, root.ejes.length - 1)
    }

    function agregarEje() {
        if (root.ejes.length >= root.ejesMaximos)
            return
        root.ejes = root.ejes.concat([""])
        root.activo = root.ejes.length - 1
        root.respuestaCambiada(root.respuestaActual())
    }

    function quitarEje() {
        if (root.ejes.length <= root.ejesMinimos)
            return
        root.ejes = root.ejes.slice(0, root.ejes.length - 1)
        root.activo = Math.min(root.activo, root.ejes.length - 1)
        root.respuestaCambiada(root.respuestaActual())
    }

    Component.onCompleted: root.restaurar()
    onPreguntaChanged: root.restaurar()

    ColumnLayout {
        id: columna
        width: root.width
        spacing: 14 * root.sy

        Text {
            Layout.fillWidth: true
            text: "Escribe un número o un símbolo en cada casilla. Agrega o quita ejes "
                  + "hasta que la forma tenga los que necesita."
            color: Style.Theme.texto_secundario_fuerte
            font.family: Style.Theme.fuente_interfaz
            font.pixelSize: 13 * root.sx
            wrapMode: Text.WordWrap
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8 * root.sx

            Text {
                text: "["
                height: 50 * root.sy
                verticalAlignment: Text.AlignVCenter
                color: Style.Theme.texto_primario
                font.family: Style.Theme.fuente_mono
                font.pixelSize: 30 * root.sx
                font.bold: true
            }

            Repeater {
                model: root.ejes.length

                delegate: Row {
                    id: celda
                    required property int index
                    spacing: 8 * root.sx

                    CampoTextoPrincipal {
                        id: campoEje
                        objectName: "evaluationShapeAxis_" + celda.index
                        width: 104 * root.sx
                        height: 50 * root.sy
                        sx: root.sx
                        sy: root.sy
                        font.family: Style.Theme.fuente_mono
                        font.pixelSize: 18 * root.sy
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        placeholderText: "eje " + (celda.index + 1)
                        text: root.ejes[celda.index] || ""
                        validator: RegularExpressionValidator {
                            regularExpression: /[A-Za-z0-9_|]{0,12}/
                        }
                        Accessible.name: "Eje " + (celda.index + 1) + " de la forma"

                        onActiveFocusChanged: if (activeFocus) root.activo = celda.index
                        onTextEdited: root.fijar(celda.index, campoEje.text)
                        onEditingFinished: {
                            var oficial = root.canonico(campoEje.text)
                            if (oficial !== campoEje.text)
                                root.fijar(celda.index, oficial)
                        }
                        Keys.onReturnPressed: campoEje.focus = false
                        Keys.onEscapePressed: campoEje.focus = false
                    }

                    Text {
                        visible: celda.index < root.ejes.length - 1
                        text: ","
                        height: 50 * root.sy
                        verticalAlignment: Text.AlignBottom
                        color: Style.Theme.texto_primario
                        font.family: Style.Theme.fuente_mono
                        font.pixelSize: 26 * root.sx
                        font.bold: true
                    }
                }
            }

            Text {
                text: "]"
                height: 50 * root.sy
                verticalAlignment: Text.AlignVCenter
                color: Style.Theme.texto_primario
                font.family: Style.Theme.fuente_mono
                font.pixelSize: 30 * root.sx
                font.bold: true
            }

            BotonSecundario {
                objectName: "evaluationShapeAddAxis"
                width: 112 * root.sx
                height: 42 * root.sy
                sx: root.sx
                sy: root.sy
                text: "+ eje"
                enabled: root.ejes.length < root.ejesMaximos
                opacity: enabled ? 1 : 0.4
                Accessible.name: "Agregar un eje a la forma"
                onClicked: root.agregarEje()
            }

            BotonSecundario {
                objectName: "evaluationShapeRemoveAxis"
                width: 112 * root.sx
                height: 42 * root.sy
                sx: root.sx
                sy: root.sy
                text: "− eje"
                enabled: root.ejes.length > root.ejesMinimos
                opacity: enabled ? 1 : 0.4
                Accessible.name: "Quitar el último eje de la forma"
                onClicked: root.quitarEje()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.simbolos.length > 0
            spacing: 6 * root.sy

            Text {
                text: "SÍMBOLOS DEL RECORRIDO · tócalo para ponerlo en la casilla activa"
                color: Style.Theme.texto_secundario
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 11 * root.sx
                font.bold: true
                font.letterSpacing: 0.6
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8 * root.sx

                Repeater {
                    model: root.simbolos

                    delegate: BotonAccesible {
                        id: chipSimbolo
                        required property var modelData
                        objectName: "evaluationShapeSymbol_" + String(chipSimbolo.modelData)
                        height: 36 * root.sy
                        width: Math.max(64 * root.sx, etiquetaSimbolo.implicitWidth + 26 * root.sx)
                        // Un clic en la paleta no debe quitarle el foco a la
                        // casilla: así se sabe a cuál va el símbolo.
                        focusPolicy: Qt.NoFocus
                        Accessible.name: "Símbolo " + String(chipSimbolo.modelData)
                        onClicked: root.ponerSimbolo(String(chipSimbolo.modelData))

                        background: Rectangle {
                            radius: height / 2
                            color: chipSimbolo.hovered ? Style.Theme.acento_fondo : Style.Theme.chip_fondo
                            border.width: 1
                            border.color: Style.Theme.borde_medio
                        }
                        contentItem: Text {
                            id: etiquetaSimbolo
                            text: String(chipSimbolo.modelData)
                            color: Style.Theme.texto_primario
                            font.family: Style.Theme.fuente_mono
                            font.pixelSize: 14 * root.sx
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }

        Text {
            objectName: "evaluationShapePreview"
            Layout.fillWidth: true
            text: "Tu respuesta: " + root.textoForma
                  + (root.completa ? "" : "  ·  llena todas las casillas para continuar")
            color: root.completa ? Style.Theme.texto_primario : Style.Theme.texto_terciario
            font.family: Style.Theme.fuente_mono
            font.pixelSize: 13 * root.sx
            wrapMode: Text.WordWrap
        }
    }
}
