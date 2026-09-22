pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Reactivo de opción única: una sola respuesta correcta entre varias.
// Cubre los 10 reactivos de opción múltiple del instrumento, incluida la
// interpretación de matriz (que solo agrega un `recurso` al enunciado) y las
// etapas de los reactivos compuestos.
//
// Contrato común de todos los componentes Reactivo*:
//   in   pregunta            objeto público del banco (sin claves de respuesta)
//   in   respuestaInicial    para restaurar el estado si QML reinstancia
//   out  respuestaCambiada   se emite en cada interacción del estudiante
//   fn   respuestaActual()   forma serializable que espera el modelo
Item {
    id: root

    property var pregunta: ({})
    property var respuestaInicial: null
    property real sx: 1
    property real sy: 1

    signal respuestaCambiada(var valor)

    property string seleccionada: ""

    readonly property var opciones: (root.pregunta && root.pregunta.options)
                                    ? root.pregunta.options : []

    implicitHeight: columna.implicitHeight

    function respuestaActual() {
        return { "opcion_id": root.seleccionada }
    }

    function restaurar() {
        root.seleccionada = (root.respuestaInicial && root.respuestaInicial.opcion_id)
                            ? String(root.respuestaInicial.opcion_id) : ""
    }

    function elegir(opcionId) {
        if (root.seleccionada === opcionId)
            return
        root.seleccionada = opcionId
        root.respuestaCambiada(root.respuestaActual())
    }

    Component.onCompleted: root.restaurar()
    onPreguntaChanged: root.restaurar()

    ColumnLayout {
        id: columna
        width: root.width
        spacing: 9 * root.sy

        Repeater {
            model: root.opciones

            delegate: Button {
                id: opcion
                required property var modelData
                required property int index

                readonly property bool elegida: root.seleccionada === String(opcion.modelData.id)

                Layout.fillWidth: true
                Layout.minimumHeight: 54 * root.sy
                Layout.preferredHeight: Math.max(54 * root.sy,
                                                 textoOpcion.implicitHeight + 26 * root.sy)
                objectName: "evaluationOption_" + opcion.modelData.id
                focusPolicy: Qt.StrongFocus
                Accessible.name: textoOpcion.text
                Accessible.description: "Opción " + (opcion.index + 1) + " de " + root.opciones.length

                onClicked: root.elegir(String(opcion.modelData.id))

                background: Rectangle {
                    radius: 11 * root.sx
                    color: opcion.elegida
                           ? Style.Theme.acento_fondo
                           : (opcion.hovered ? Style.Theme.superficie_alterna : Style.Theme.surface)
                    border.width: opcion.elegida ? 2 : 1
                    border.color: opcion.elegida
                                  ? Style.Theme.acento
                                  : (opcion.hovered ? Style.Theme.acento_alt : Style.Theme.borde_suave)
                    Behavior on color { ColorAnimation { duration: 110 } }
                }

                contentItem: RowLayout {
                    spacing: 12 * root.sx

                    // Viñeta con la letra de la opción. Es el único indicador de
                    // selección además del borde: durante el examen no se revela
                    // si la opción elegida es la correcta.
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
                            text: String(opcion.modelData.id).toUpperCase()
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
