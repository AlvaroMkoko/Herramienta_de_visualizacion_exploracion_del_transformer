pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Relacionar columnas (A1 y S2) · presentación «lineas_o_tocar_para_emparejar».
//
// Dos columnas: a la izquierda los elementos, a la derecha las funciones. Se
// toca uno de cada lado y quedan emparejados; el par se marca con un color y un
// número que aparecen en los dos lados.
//
// No se dibujan líneas entre columnas. Una línea tendría que recalcularse con
// cada cambio de alto, de desplazamiento o de escala, y en cuanto la columna
// derecha se desplaza por su cuenta, la línea apunta a otro renglón: sería un
// indicador que miente. El color compartido dice lo mismo, sobrevive al
// desplazamiento y además se lee en una captura impresa del examen.
//
// Las dos columnas tienen alturas independientes a propósito. Si los renglones
// se alinearan, la posición vertical sería una pista sobre el emparejamiento
// correcto y el reactivo se podría resolver sin leer las funciones.
AsignacionBase {
    id: root

    implicitHeight: columnas.implicitHeight

    // Un color por par. Se indexa por la posición del elemento, no por el orden
    // en que se empareja, así que un par conserva su color aunque se deshaga y
    // se vuelva a hacer.
    readonly property var paleta: [
        Style.Theme.escala_sec_0,
        Style.Theme.escala_sec_1,
        Style.Theme.escala_sec_2,
        Style.Theme.escala_sec_3,
        Style.Theme.escala_sec_4
    ]

    function indiceElemento(elementoId) {
        var lista = root.listaDe("elementos")
        for (var i = 0; i < lista.length; ++i) {
            if (String(lista[i].id) === String(elementoId))
                return i
        }
        return -1
    }

    function colorDe(elementoId) {
        var indice = root.indiceElemento(elementoId)
        if (indice < 0)
            return Style.Theme.borde_medio
        return root.paleta[indice % root.paleta.length]
    }

    function marcaDe(elementoId) {
        var indice = root.indiceElemento(elementoId)
        return indice < 0 ? "" : String(indice + 1)
    }

    ColumnLayout {
        id: columnas
        width: root.width
        spacing: 12 * root.sy

        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * root.sx

            Text {
                Layout.fillWidth: true
                text: root.pendientes.length === 0
                      ? "Todos los elementos están relacionados"
                      : "Toca un elemento y luego su "
                        + root.etiquetaDestino.toLowerCase()
                color: root.pendientes.length === 0
                       ? Style.Theme.exito_texto : Style.Theme.texto_secundario_fuerte
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 13 * root.sx
                wrapMode: Text.WordWrap
            }

            Button {
                id: botonLimpiar
                visible: Object.keys(root.asignaciones).length > 0
                objectName: "evaluationClearPairs"
                Layout.preferredWidth: 118 * root.sx
                Layout.preferredHeight: 30 * root.sy
                Accessible.name: "Deshacer todas las relaciones"
                onClicked: root.limpiar()

                background: Rectangle {
                    radius: height / 2
                    color: botonLimpiar.hovered
                           ? Style.Theme.superficie_alterna : "transparent"
                    border.width: 1
                    border.color: Style.Theme.borde_medio
                }
                contentItem: Text {
                    text: "Deshacer todo"
                    color: Style.Theme.texto_secundario_fuerte
                    font.family: Style.Theme.fuente_interfaz
                    font.pixelSize: 11 * root.sx
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 16 * root.sx

            // ── Columna izquierda: elementos ─────────────────────────
            ColumnLayout {
                Layout.preferredWidth: 1
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 8 * root.sy

                Text {
                    text: "ELEMENTO"
                    color: Style.Theme.texto_secundario
                    font.family: Style.Theme.fuente_interfaz
                    font.pixelSize: 11 * root.sx
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                Repeater {
                    model: root.elementos

                    delegate: Rectangle {
                        id: filaElemento
                        required property var modelData

                        readonly property string elementoId: String(filaElemento.modelData.id)
                        readonly property string destino: root.destinoDe(filaElemento.elementoId)
                        readonly property bool emparejado: filaElemento.destino !== ""
                        readonly property bool enMano: root.enMano === filaElemento.elementoId

                        objectName: "evaluationPairItem_" + filaElemento.elementoId
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(
                            54 * root.sy, textoElemento.implicitHeight + 24 * root.sy)
                        radius: 11 * root.sx
                        color: filaElemento.enMano
                               ? Style.Theme.acento_fondo
                               : (areaElemento.containsMouse
                                  ? Style.Theme.superficie_alterna : Style.Theme.surface)
                        border.width: filaElemento.enMano ? 2 : 1
                        border.color: filaElemento.enMano
                                      ? Style.Theme.acento
                                      : (filaElemento.emparejado
                                         ? root.colorDe(filaElemento.elementoId)
                                         : Style.Theme.borde_suave)
                        Behavior on color { ColorAnimation { duration: 110 } }

                        MouseArea {
                            id: areaElemento
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // Tocar un elemento ya emparejado deshace el par:
                            // es la misma regla que en las otras disposiciones.
                            onClicked: root.alternar(filaElemento.elementoId)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 11 * root.sx
                            spacing: 10 * root.sx

                            Rectangle {
                                Layout.preferredWidth: 26 * root.sx
                                Layout.preferredHeight: 26 * root.sx
                                Layout.alignment: Qt.AlignVCenter
                                radius: width / 2
                                visible: filaElemento.emparejado
                                color: root.colorDe(filaElemento.elementoId)

                                Text {
                                    anchors.centerIn: parent
                                    text: root.marcaDe(filaElemento.elementoId)
                                    color: Style.Theme.texto_sobre_acento
                                    font.family: Style.Theme.fuente_interfaz
                                    font.pixelSize: 12 * root.sx
                                    font.bold: true
                                }
                            }

                            Text {
                                id: textoElemento
                                Layout.fillWidth: true
                                text: String(filaElemento.modelData.texto)
                                color: Style.Theme.texto_primario
                                font.family: Style.Theme.fuente_interfaz
                                font.pixelSize: 15 * root.sx
                                font.bold: true
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            // ── Columna derecha: destinos ────────────────────────────
            ColumnLayout {
                Layout.preferredWidth: 2   // las funciones son textos largos
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 8 * root.sy

                Text {
                    text: root.etiquetaDestino.toUpperCase()
                    color: Style.Theme.texto_secundario
                    font.family: Style.Theme.fuente_interfaz
                    font.pixelSize: 11 * root.sx
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                Repeater {
                    model: root.destinos

                    delegate: Rectangle {
                        id: filaDestino
                        required property var modelData

                        readonly property string destinoId: String(filaDestino.modelData.id)
                        readonly property var ocupante: root.elementoEn(filaDestino.destinoId)
                        readonly property bool ocupado: filaDestino.ocupante !== null
                        readonly property bool esperando: root.enMano !== ""

                        objectName: "evaluationPairTarget_" + filaDestino.destinoId
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(
                            54 * root.sy, contenidoDestino.implicitHeight + 22 * root.sy)
                        radius: 11 * root.sx
                        color: filaDestino.esperando
                               ? Style.Theme.acento_fondo
                               : (areaDestino.containsMouse
                                  ? Style.Theme.superficie_alterna : Style.Theme.surface)
                        border.width: filaDestino.ocupado ? 2 : 1
                        border.color: filaDestino.ocupado
                                      ? root.colorDe(String(filaDestino.ocupante.id))
                                      : (filaDestino.esperando
                                         ? Style.Theme.acento : Style.Theme.borde_suave)
                        Behavior on color { ColorAnimation { duration: 110 } }

                        MouseArea {
                            id: areaDestino
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // Sin nada en mano, tocar un destino ocupado toma
                            // de vuelta su elemento (lo hereda de soltarEn).
                            onClicked: root.soltarEn(filaDestino.destinoId)
                        }

                        ColumnLayout {
                            id: contenidoDestino
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 11 * root.sx
                            anchors.rightMargin: 11 * root.sx
                            spacing: 6 * root.sy

                            Text {
                                Layout.fillWidth: true
                                text: String(filaDestino.modelData.texto)
                                color: Style.Theme.texto_primario
                                font.family: Style.Theme.fuente_interfaz
                                font.pixelSize: 14 * root.sx
                                lineHeight: 1.2
                                wrapMode: Text.WordWrap
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: filaDestino.ocupado
                                spacing: 7 * root.sx

                                Rectangle {
                                    Layout.preferredWidth: 22 * root.sx
                                    Layout.preferredHeight: 22 * root.sx
                                    radius: width / 2
                                    color: filaDestino.ocupado
                                           ? root.colorDe(String(filaDestino.ocupante.id))
                                           : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: filaDestino.ocupado
                                              ? root.marcaDe(String(filaDestino.ocupante.id))
                                              : ""
                                        color: Style.Theme.texto_sobre_acento
                                        font.family: Style.Theme.fuente_interfaz
                                        font.pixelSize: 11 * root.sx
                                        font.bold: true
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: filaDestino.ocupado
                                          ? String(filaDestino.ocupante.texto) : ""
                                    color: Style.Theme.texto_secundario_fuerte
                                    font.family: Style.Theme.fuente_interfaz
                                    font.pixelSize: 12 * root.sx
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Para deshacer un par, toca cualquiera de sus dos lados."
            color: Style.Theme.texto_terciario
            font.family: Style.Theme.fuente_interfaz
            font.pixelSize: 11 * root.sx
            wrapMode: Text.WordWrap
        }
    }
}
