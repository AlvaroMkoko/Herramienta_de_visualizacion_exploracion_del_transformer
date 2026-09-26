pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../styles" as Style

// Clasificar en categorías (E4) · presentación «cestas».
//
// Montón de enunciados arriba, cestas abajo, una por categoría. A diferencia de
// ordenar y relacionar, aquí `destinos_unicos` es falso: una cesta admite varios
// enunciados y el número que le toca a cada una es parte de lo que se evalúa.
//
// Por eso las cestas NO muestran cuántos enunciados esperan. E4 tiene seis
// enunciados repartidos 2-2-2, y enseñar un «0 de 2» convertiría el reactivo en
// un rompecabezas de conteo: bastaría con repartir hasta que cuadre. El contador
// que sí se muestra es el del montón, que no dice nada sobre la respuesta.
AsignacionBase {
    id: root

    implicitHeight: columna.implicitHeight

    property var ordenMonton: []

    onPreguntaChanged: root.rehacerMonton()
    Component.onCompleted: root.rehacerMonton()

    function rehacerMonton() {
        var ids = []
        var lista = root.listaDe("elementos")
        for (var i = 0; i < lista.length; ++i)
            ids.push(String(lista[i].id))
        root.ordenMonton = ids
    }

    function montonOrdenado() {
        var fuera = []
        for (var i = 0; i < root.ordenMonton.length; ++i) {
            var id = root.ordenMonton[i]
            if (root.destinoDe(id) === "")
                fuera.push({ "id": id, "texto": root.textoDe(id) })
        }
        return fuera
    }

    ColumnLayout {
        id: columna
        width: root.width
        spacing: 14 * root.sy

        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * root.sx

            Text {
                text: "POR CLASIFICAR"
                color: Style.Theme.texto_secundario
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 11 * root.sx
                font.bold: true
                font.letterSpacing: 0.8
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.pendientes.length === 0
                      ? "Todos clasificados"
                      : "Quedan " + root.pendientes.length
                color: root.pendientes.length === 0
                       ? Style.Theme.exito_texto : Style.Theme.texto_secundario_fuerte
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 11 * root.sx
                font.bold: true
            }
        }

        // ── Montón ───────────────────────────────────────────────────
        Rectangle {
            objectName: "evaluationAssignmentPool"
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(58 * root.sy,
                                             fichasMonton.implicitHeight + 20 * root.sy)
            radius: 12 * root.sx
            color: areaMonton.containsDrag
                   ? Style.Theme.acento_fondo : Style.Theme.superficie_alterna
            border.width: 1
            border.color: areaMonton.containsDrag
                          ? Style.Theme.acento : Style.Theme.borde_suave
            Behavior on color { ColorAnimation { duration: 110 } }

            DropArea {
                id: areaMonton
                anchors.fill: parent
                onDropped: function (drop) {
                    if (drop.source && drop.source.elementoId)
                        root.liberar(drop.source.elementoId)
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.enMano !== ""
                onClicked: root.liberar(root.enMano)
            }

            Text {
                anchors.centerIn: parent
                visible: root.pendientes.length === 0
                text: "Todos los enunciados están en una cesta"
                color: Style.Theme.texto_terciario
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 13 * root.sx
            }

            ColumnLayout {
                id: fichasMonton
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10 * root.sx
                spacing: 7 * root.sy

                Repeater {
                    model: root.montonOrdenado()

                    delegate: FichaAsignable {
                        id: fichaSuelta
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        elementoId: String(fichaSuelta.modelData.id)
                        texto: String(fichaSuelta.modelData.texto)
                        seleccionada: root.enMano === fichaSuelta.elementoId
                        sx: root.sx
                        sy: root.sy
                        onTocada: root.tomar(fichaSuelta.elementoId)
                    }
                }
            }
        }

        // ── Cestas ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4 * root.sy
            spacing: 12 * root.sx

            Repeater {
                model: root.destinos

                delegate: Rectangle {
                    id: cesta
                    required property var modelData

                    readonly property string destinoId: String(cesta.modelData.id)
                    readonly property var dentro: root.elementosEn(cesta.destinoId)

                    objectName: "evaluationBasket_" + cesta.destinoId
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1   // reparte el ancho en partes iguales
                    Layout.fillHeight: true
                    Layout.minimumHeight: 150 * root.sy
                    Layout.preferredHeight: Math.max(
                        150 * root.sy, contenidoCesta.implicitHeight + 22 * root.sy)
                    Layout.alignment: Qt.AlignTop
                    radius: 12 * root.sx
                    color: areaCesta.containsDrag || root.enMano !== ""
                           ? Style.Theme.acento_fondo : Style.Theme.surface
                    border.width: areaCesta.containsDrag ? 2 : 1
                    border.color: areaCesta.containsDrag
                                  ? Style.Theme.acento : Style.Theme.borde_medio
                    Behavior on color { ColorAnimation { duration: 110 } }

                    DropArea {
                        id: areaCesta
                        anchors.fill: parent
                        onDropped: function (drop) {
                            if (drop.source && drop.source.elementoId)
                                root.asignar(drop.source.elementoId, cesta.destinoId)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.enMano !== ""
                        onClicked: root.soltarEn(cesta.destinoId)
                    }

                    ColumnLayout {
                        id: contenidoCesta
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 11 * root.sx
                        spacing: 8 * root.sy

                        Text {
                            Layout.fillWidth: true
                            text: String(cesta.modelData.texto)
                            color: Style.Theme.acento_fuerte
                            font.family: Style.Theme.fuente_interfaz
                            font.pixelSize: 14 * root.sx
                            font.bold: true
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Style.Theme.divisor
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: cesta.dentro.length === 0
                            text: root.enMano !== "" ? "Toca para soltar aquí" : "Vacía"
                            color: root.enMano !== ""
                                   ? Style.Theme.acento_fuerte : Style.Theme.texto_terciario
                            font.family: Style.Theme.fuente_interfaz
                            font.pixelSize: 12 * root.sx
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Repeater {
                            model: cesta.dentro

                            delegate: FichaAsignable {
                                id: fichaEnCesta
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: implicitHeight
                                elementoId: String(fichaEnCesta.modelData.id)
                                texto: String(fichaEnCesta.modelData.texto)
                                colocada: true
                                sx: root.sx
                                sy: root.sy
                                onTocada: root.liberar(fichaEnCesta.elementoId)
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 2 * root.sy
            text: "Toca un enunciado y luego su cesta, o arrástralo. "
                  + "Para sacarlo, tócalo otra vez."
            color: Style.Theme.texto_terciario
            font.family: Style.Theme.fuente_interfaz
            font.pixelSize: 11 * root.sx
            wrapMode: Text.WordWrap
        }
    }
}
