import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Resumen de los estados internos de un modelo en un paso de generación.
// Se usa dos veces, lado a lado, en la pantalla de comparación: ambos
// paneles muestran el mismo número de paso para que las diferencias entre
// configuraciones se lean bloque por bloque (salida, atención del encoder,
// del decoder y cruzada). Todos los valores vienen del forward real del
// token (`visualizacion` emitida por InferenceController).
Item {
    id: root

    property var paso: null
    property color acento: Style.Theme.acento
    property real sx: 1
    property real sy: 1
    signal helpRequested(string conceptId)

    readonly property bool disponible: root.paso !== null && root.paso !== undefined
    readonly property var candidatos: root.disponible && root.paso.predicciones_top
                                      ? root.paso.predicciones_top.slice(0, 5) : []
    readonly property var capasEncoder: root.bloque("encoder")
    readonly property var capasDecoder: root.bloque("decoder")
    readonly property var capasCruzada: root.bloque("cruzada")
    readonly property int numCapas: Math.max(root.capasEncoder.length,
                                             root.capasDecoder.length,
                                             root.capasCruzada.length)
    readonly property var foco: {
        if (!root.disponible || !root.paso.foco_entrada)
            return []
        var copia = root.paso.foco_entrada.slice(0)
        copia.sort(function(a, b) { return b.peso - a.peso })
        return copia.slice(0, 4)
    }

    function bloque(nombre) {
        if (!root.disponible || !root.paso.atencion_por_bloque)
            return []
        return root.paso.atencion_por_bloque[nombre] || []
    }

    function entropia(lista, indice) {
        return indice < lista.length ? Number(lista[indice].entropia).toFixed(2) : "—"
    }

    function textoToken(texto) {
        var limpio = String(texto === undefined ? "" : texto).replace(/\n/g, "↵")
        return "«" + limpio + "»"
    }

    Text {
        anchors.centerIn: parent
        visible: !root.disponible
        width: parent.width * 0.9
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: "Genera una respuesta para comparar los estados internos de este modelo."
        color: Style.Theme.texto_terciario
        font.pixelSize: 12 * Math.min(root.sx, root.sy)
    }

    Flickable {
        anchors.fill: parent
        visible: root.disponible
        clip: true
        contentWidth: width
        contentHeight: contenido.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: contenido
            width: parent.width
            spacing: 6 * root.sy

            // --- Salida: token elegido y distribución -------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 4 * root.sx
                Text {
                    Layout.fillWidth: true
                    text: root.disponible
                          ? "Token " + root.paso.paso + ": " + root.textoToken(root.paso.token_elegido.texto)
                            + "  p = " + Number(root.paso.token_elegido.probabilidad).toFixed(3)
                            + " · rango " + root.paso.token_elegido.rango
                          : ""
                    color: root.acento
                    font.bold: true
                    font.pixelSize: 12 * Math.min(root.sx, root.sy)
                    elide: Text.ElideRight
                }
                ConceptHelpButton {
                    conceptId: "softmax_final"
                    controlSize: Math.max(18, 20 * Math.min(root.sx, root.sy))
                    onHelpRequested: function(conceptId) { root.helpRequested(conceptId) }
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.disponible
                      ? "Entropía de la salida " + Number(root.paso.entropia_salida).toFixed(3)
                        + " · candidatos " + root.paso.cantidad_candidatos
                        + " · " + root.paso.filtros
                      : ""
                color: Style.Theme.texto_secundario
                font.pixelSize: 11 * Math.min(root.sx, root.sy)
                elide: Text.ElideRight
            }

            Repeater {
                model: root.candidatos
                delegate: RowLayout {
                    id: filaCandidato
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 6 * root.sx
                    Text {
                        Layout.preferredWidth: 96 * root.sx
                        text: root.textoToken(filaCandidato.modelData.texto)
                        color: filaCandidato.modelData.elegido ? root.acento : Style.Theme.texto_primario
                        font.bold: filaCandidato.modelData.elegido
                        font.pixelSize: 11 * Math.min(root.sx, root.sy)
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 9 * root.sy
                        radius: height / 2
                        color: Style.Theme.superficie_alterna
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, Number(filaCandidato.modelData.probabilidad)))
                            height: parent.height
                            radius: parent.radius
                            color: root.acento
                            opacity: filaCandidato.modelData.elegido ? 1 : 0.45
                        }
                    }
                    Text {
                        Layout.preferredWidth: 44 * root.sx
                        horizontalAlignment: Text.AlignRight
                        text: (Number(filaCandidato.modelData.probabilidad) * 100).toFixed(1) + "%"
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 11 * Math.min(root.sx, root.sy)
                    }
                }
            }

            // --- Atención por capa -------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4 * root.sy
                spacing: 4 * root.sx
                Text {
                    Layout.fillWidth: true
                    text: "Entropía de la atención (última consulta, media de cabezas)"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 11 * Math.min(root.sx, root.sy)
                    elide: Text.ElideRight
                }
                ConceptHelpButton {
                    conceptId: "interpretacion_pesos"
                    controlSize: Math.max(18, 20 * Math.min(root.sx, root.sy))
                    onHelpRequested: function(conceptId) { root.helpRequested(conceptId) }
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: 2 * root.sy
                columnSpacing: 8 * root.sx
                Repeater {
                    model: ["Capa", "Encoder", "Decoder", "Cruzada"]
                    Text {
                        required property string modelData
                        text: modelData
                        color: Style.Theme.texto_secundario
                        font.bold: true
                        font.pixelSize: 10 * Math.min(root.sx, root.sy)
                    }
                }
                Repeater {
                    model: root.numCapas * 4
                    Text {
                        required property int index
                        readonly property int capa: Math.floor(index / 4)
                        readonly property int columna: index % 4
                        text: columna === 0 ? String(capa + 1)
                              : (columna === 1 ? root.entropia(root.capasEncoder, capa)
                                 : (columna === 2 ? root.entropia(root.capasDecoder, capa)
                                    : root.entropia(root.capasCruzada, capa)))
                        color: Style.Theme.texto_primario
                        font.pixelSize: 11 * Math.min(root.sx, root.sy)
                    }
                }
            }

            // --- Foco de la atención cruzada ---------------------------
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 4 * root.sy
                text: "Tokens del prompt más atendidos (atención cruzada, última capa)"
                color: Style.Theme.texto_primario
                font.bold: true
                font.pixelSize: 11 * Math.min(root.sx, root.sy)
                elide: Text.ElideRight
            }
            Flow {
                Layout.fillWidth: true
                spacing: 5 * root.sx
                Repeater {
                    model: root.foco
                    delegate: Rectangle {
                        id: fichaFoco
                        required property var modelData
                        width: textoFoco.implicitWidth + 14 * root.sx
                        height: 22 * root.sy
                        radius: height / 2
                        color: Qt.alpha(root.acento, 0.10 + 0.5 * Number(fichaFoco.modelData.peso))
                        border.color: Qt.alpha(root.acento, 0.4)
                        Text {
                            id: textoFoco
                            anchors.centerIn: parent
                            text: root.textoToken(fichaFoco.modelData.texto) + " "
                                  + Number(fichaFoco.modelData.peso).toFixed(2)
                            color: Style.Theme.texto_primario
                            font.pixelSize: 10 * Math.min(root.sx, root.sy)
                        }
                    }
                }
            }
        }
    }
}
