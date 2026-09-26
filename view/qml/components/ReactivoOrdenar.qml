pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../styles" as Style

// Ordenar elementos (T4 y S4) · presentación «lista_arrastrable».
//
// Montón arriba, posiciones numeradas abajo. Se toca una ficha y luego la
// posición, o se arrastra de una a otra.
//
// El montón empieza lleno a propósito, en lugar de mostrar la lista ya ordenada
// de cualquier manera para que el estudiante la reacomode. Con una lista
// precargada, el reactivo ya estaría «contestado» desde el primer momento —el
// modelo considera completa una asignación cuando todos los elementos tienen
// destino— y se podría avanzar sin tocar nada, entregando un orden que nadie
// eligió. Una ranura vacía, en cambio, se ve vacía.
AsignacionBase {
    id: root

    implicitHeight: columna.implicitHeight

    // El orden del montón se fija al cargar el reactivo. Si se recalculara en
    // cada cambio, devolver una ficha la haría aparecer en otro lugar del
    // montón y el estudiante perdería de vista lo que acaba de mover.
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

    // Pendientes en el orden estable del montón.
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

        // ── Montón ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * root.sx

            Text {
                text: "POR COLOCAR"
                color: Style.Theme.texto_secundario
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 11 * root.sx
                font.bold: true
                font.letterSpacing: 0.8
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.pendientes.length === 0
                      ? "Todas colocadas"
                      : root.pendientes.length + " de " + root.elementos.length
                color: root.pendientes.length === 0
                       ? Style.Theme.exito_texto : Style.Theme.texto_secundario_fuerte
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 11 * root.sx
                font.bold: true
            }
        }

        Rectangle {
            id: monton
            objectName: "evaluationAssignmentPool"
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(58 * root.sy,
                                             fichasMonton.implicitHeight + 20 * root.sy)
            radius: 12 * root.sx
            color: root.enMano !== "" || areaMonton.containsDrag
                   ? Style.Theme.acento_fondo : Style.Theme.superficie_alterna
            border.width: 1
            border.color: areaMonton.containsDrag
                          ? Style.Theme.acento : Style.Theme.borde_suave
            Behavior on color { ColorAnimation { duration: 110 } }

            // Soltar aquí devuelve la ficha al montón.
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
                text: "Todas las fichas están colocadas"
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

        // ── Posiciones ───────────────────────────────────────────────
        Text {
            Layout.topMargin: 4 * root.sy
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
                id: ranura
                required property var modelData
                required property int index

                readonly property string destinoId: String(ranura.modelData.id)
                readonly property var ocupante: root.elementoEn(ranura.destinoId)
                readonly property bool libre: ranura.ocupante === null
                readonly property bool esperando: root.enMano !== "" && ranura.libre

                objectName: "evaluationSlot_" + ranura.destinoId
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(54 * root.sy,
                                                 contenidoRanura.implicitHeight + 16 * root.sy)
                radius: 11 * root.sx
                color: areaRanura.containsDrag || ranura.esperando
                       ? Style.Theme.acento_fondo : "transparent"
                border.width: ranura.libre ? 1.5 : 1
                border.color: areaRanura.containsDrag
                              ? Style.Theme.acento
                              : (ranura.libre ? Style.Theme.borde_medio
                                              : Style.Theme.borde_suave)
                Behavior on color { ColorAnimation { duration: 110 } }

                DropArea {
                    id: areaRanura
                    anchors.fill: parent
                    onDropped: function (drop) {
                        if (drop.source && drop.source.elementoId)
                            root.asignar(drop.source.elementoId, ranura.destinoId)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    // Cuando la ranura está ocupada, el clic lo atiende la
                    // ficha de encima; este área solo cubre la ranura vacía.
                    enabled: ranura.libre
                    onClicked: root.soltarEn(ranura.destinoId)
                }

                RowLayout {
                    id: contenidoRanura
                    anchors.fill: parent
                    anchors.margins: 8 * root.sx
                    spacing: 10 * root.sx

                    Rectangle {
                        Layout.preferredWidth: 34 * root.sx
                        Layout.preferredHeight: 34 * root.sx
                        Layout.alignment: Qt.AlignVCenter
                        radius: width / 2
                        color: ranura.libre
                               ? "transparent" : Style.Theme.acento
                        border.width: ranura.libre ? 1.5 : 0
                        border.color: Style.Theme.borde_medio

                        Text {
                            anchors.centerIn: parent
                            text: String(ranura.modelData.texto)
                            color: ranura.libre
                                   ? Style.Theme.texto_secundario
                                   : Style.Theme.texto_sobre_acento
                            font.family: Style.Theme.fuente_interfaz
                            font.pixelSize: 14 * root.sx
                            font.bold: true
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: ranura.libre
                        text: root.enMano !== ""
                              ? "Toca aquí para colocarla"
                              : "Vacía"
                        color: root.enMano !== ""
                               ? Style.Theme.acento_fuerte : Style.Theme.texto_terciario
                        font.family: Style.Theme.fuente_interfaz
                        font.pixelSize: 13 * root.sx
                    }

                    FichaAsignable {
                        id: fichaColocada
                        visible: !ranura.libre
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? implicitHeight : 0
                        elementoId: ranura.ocupante ? String(ranura.ocupante.id) : ""
                        texto: ranura.ocupante ? String(ranura.ocupante.texto) : ""
                        colocada: true
                        seleccionada: root.enMano === fichaColocada.elementoId
                        sx: root.sx
                        sy: root.sy
                        onTocada: root.liberar(fichaColocada.elementoId)
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 2 * root.sy
            text: "Toca una ficha y luego su posición, o arrástrala. "
                  + "Para sacarla, tócala otra vez."
            color: Style.Theme.texto_terciario
            font.family: Style.Theme.fuente_interfaz
            font.pixelSize: 11 * root.sx
            wrapMode: Text.WordWrap
        }
    }
}
