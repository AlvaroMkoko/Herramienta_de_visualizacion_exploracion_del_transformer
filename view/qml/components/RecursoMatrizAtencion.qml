pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Matriz de pesos de atención adjunta a un reactivo (A4 en ambas formas).
//
// Es un `recurso`, no un tipo de pregunta: se declara aparte del cuerpo del
// reactivo y compone con cualquier tipo de respuesta. Cuando haga falta adjuntar
// un diagrama o una secuencia de tokens, se agrega otro componente Recurso* sin
// tocar ningún calificador.
//
// La intensidad del color codifica el peso, pero el número siempre está escrito:
// el color es refuerzo, nunca el único portador de la información.
//
// ⚠ Lo que este componente NO debe hacer: resaltar el máximo de cada renglón.
// A4 pregunta justamente cuál es, así que marcarlo convierte un reactivo de
// nivel «Aplicar» en uno de «leer el recuadro de color». El resaltado al pasar
// el cursor sí es legítimo: ayuda a seguir un renglón sin decir nada sobre los
// valores.
Item {
    id: root

    property var recurso: ({})
    property real sx: 1
    property real sy: 1

    readonly property var filas: (root.recurso && root.recurso.filas)
                                 ? root.recurso.filas : []
    readonly property var columnas: (root.recurso && root.recurso.columnas)
                                    ? root.recurso.columnas : []
    readonly property var valores: (root.recurso && root.recurso.valores)
                                   ? root.recurso.valores : []

    readonly property real anchoCelda: 84 * root.sx
    readonly property real altoCelda: 40 * root.sy
    readonly property real anchoEtiqueta: 96 * root.sx

    function valorEn(fila, columna) {
        if (fila < 0 || fila >= root.valores.length)
            return 0
        var renglon = root.valores[fila]
        if (!renglon || columna < 0 || columna >= renglon.length)
            return 0
        return Number(renglon[columna])
    }

    //: Celda bajo el cursor, para resaltar su renglón y su columna.
    property int filaActiva: -1
    property int columnaActiva: -1

    implicitHeight: tarjeta.implicitHeight

    Rectangle {
        id: tarjeta
        width: root.width
        implicitHeight: contenido.implicitHeight + 28 * root.sy
        radius: 12 * root.sx
        color: Style.Theme.superficie_alterna
        border.width: 1
        border.color: Style.Theme.divisor

        ColumnLayout {
            id: contenido
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14 * root.sx
            spacing: 10 * root.sy

            Text {
                Layout.fillWidth: true
                text: (root.recurso && root.recurso.titulo)
                      ? root.recurso.titulo : "Matriz de pesos de atención"
                color: Style.Theme.texto_secundario
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 11 * root.sx
                font.bold: true
                wrapMode: Text.WordWrap
            }

            // Encabezado de columnas
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4 * root.sx

                Item {
                    width: root.anchoEtiqueta
                    height: root.altoCelda
                }

                Repeater {
                    model: root.columnas

                    delegate: Item {
                        id: encabezado
                        required property var modelData
                        width: root.anchoCelda
                        height: root.altoCelda

                        Text {
                            anchors.centerIn: parent
                            text: encabezado.modelData
                            color: Style.Theme.texto_secundario
                            font.family: Style.Theme.fuente_mono
                            font.pixelSize: 12 * root.sx
                            font.bold: true
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // Renglones
            Repeater {
                model: root.filas

                delegate: Row {
                    id: renglon
                    required property var modelData
                    required property int index

                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4 * root.sx
                    bottomPadding: 4 * root.sy

                    Rectangle {
                        width: root.anchoEtiqueta
                        height: root.altoCelda
                        radius: 7 * root.sx
                        color: Style.Theme.chip_fondo
                        border.width: 1
                        border.color: Style.Theme.chip_borde

                        Text {
                            anchors.centerIn: parent
                            text: renglon.modelData
                            color: Style.Theme.texto_primario
                            font.family: Style.Theme.fuente_mono
                            font.pixelSize: 12 * root.sx
                            font.bold: true
                            elide: Text.ElideRight
                        }
                    }

                    Repeater {
                        model: root.columnas.length

                        delegate: Rectangle {
                            id: celda
                            required property int index

                            readonly property real valor: root.valorEn(renglon.index, celda.index)
                            // En cruz: el renglón o la columna bajo el cursor.
                            // Solo indica dónde está el puntero, nunca qué
                            // valor es mayor.
                            readonly property bool enCruz: root.filaActiva === renglon.index
                                                           || root.columnaActiva === celda.index
                            readonly property bool esFoco: root.filaActiva === renglon.index
                                                           && root.columnaActiva === celda.index

                            width: root.anchoCelda
                            height: root.altoCelda
                            radius: 7 * root.sx
                            color: Qt.alpha(Style.Theme.acento,
                                            0.10 + 0.62 * Math.max(0, Math.min(1, celda.valor)))
                            border.width: celda.esFoco ? 2 : 1
                            border.color: celda.esFoco
                                          ? Style.Theme.acento_fuerte
                                          : (celda.enCruz ? Style.Theme.borde_medio
                                                          : Style.Theme.divisor)
                            opacity: (root.filaActiva < 0 || celda.enCruz) ? 1 : 0.55
                            Behavior on opacity { NumberAnimation { duration: 110 } }

                            HoverHandler {
                                onHoveredChanged: {
                                    if (hovered) {
                                        root.filaActiva = renglon.index
                                        root.columnaActiva = celda.index
                                    } else if (root.filaActiva === renglon.index
                                               && root.columnaActiva === celda.index) {
                                        root.filaActiva = -1
                                        root.columnaActiva = -1
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: celda.valor.toFixed(2)
                                color: Style.Theme.texto_primario
                                font.family: Style.Theme.fuente_mono
                                font.pixelSize: 13 * root.sx
                                font.bold: celda.esFoco
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Cada renglón suma 1.00. Pasa el cursor sobre una celda "
                      + "para seguir su renglón y su columna."
                color: Style.Theme.texto_terciario
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 10 * root.sx
                wrapMode: Text.WordWrap
            }
        }
    }
}
