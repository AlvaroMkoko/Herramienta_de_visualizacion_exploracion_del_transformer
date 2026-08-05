import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: popup

    property var registros: []
    property string datasetNombre: ""

    width: 700
    height: 500
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    function mostrar(nombre, listaRegistros) {
        datasetNombre = nombre
        registros = listaRegistros
        open()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        Text {
            text: "Vista previa: " + popup.datasetNombre
            font.bold: true
            font.pixelSize: 16
        }

        Text {
            text: registros.length + " registros mostrados"
            color: "#777777"
            font.pixelSize: 12
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: listView
                model: popup.registros
                spacing: 8

                delegate: Rectangle {
                    width: listView.width
                    height: contenido.implicitHeight + 20
                    color: index % 2 === 0 ? "#f5f5f5" : "#ffffff"
                    radius: 4

                    Text {
                        id: contenido
                        anchors.fill: parent
                        anchors.margins: 10
                        wrapMode: Text.Wrap
                        text: JSON.stringify(modelData, null, 2)
                        font.family: "monospace"
                        font.pixelSize: 11
                    }
                }
            }
        }

        BotonPrincipal {
            Layout.alignment: Qt.AlignRight
            text: "Cerrar"
            onClicked: popup.close()
        }
    }
}


// import QtQuick
// import QtQuick.Controls
// import QtQuick.Layouts

// Popup {
//     id: popup

//     property var registros: []
//     property var datasetInfo: ({})   // fila completa del datasetModel (tokens, vocabulario, etc.)

//     property color colorAccent: "#6A63E8"
//     property color colorBg: "#f7f7fb"
//     property color colorBorder: "#e3e1f5"
//     property color colorTextMuted: "#8a8a8a"

//     width: 640
//     height: 520
//     modal: true
//     focus: true
//     closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

//     background: Rectangle {
//         color: "white"
//         radius: 14
//         border.width: 1
//         border.color: colorBorder
//     }

//     function mostrar(datasetRow, listaRegistros) {
//         datasetInfo = datasetRow
//         registros = listaRegistros
//         tabBar.currentIndex = 0
//         open()
//     }

//     function calcularFrecuencia() {
//         var conteo = {}

//         for (var i = 0; i < registros.length; ++i) {
//             var reg = registros[i]
//             var texto = (reg.instruction || "") + " " + (reg.context || "") + " " + (reg.response || "")
//             var palabras = texto.toLowerCase().match(/[a-záéíóúñü0-9]+/g) || []

//             for (var j = 0; j < palabras.length; ++j) {
//                 var p = palabras[j]
//                 if (p.length < 4) continue
//                 conteo[p] = (conteo[p] || 0) + 1
//             }
//         }

//         var lista = Object.keys(conteo).map(function(k) {
//             return { palabra: k, veces: conteo[k] }
//         })

//         lista.sort(function(a, b) { return b.veces - a.veces })
//         return lista.slice(0, 15)
//     }

//     ColumnLayout {
//         anchors.fill: parent
//         anchors.margins: 20
//         spacing: 14

//         // ---------- Header ----------
//         RowLayout {
//             Layout.fillWidth: true

//             ColumnLayout {
//                 spacing: 2
//                 Text {
//                     text: popup.datasetInfo.nombre || "Dataset"
//                     font.bold: true
//                     font.pixelSize: 18
//                     color: "#222222"
//                 }
//                 Text {
//                     text: (popup.datasetInfo.registros || 0) + " registros · " +
//                           (popup.datasetInfo.formato || "")
//                     font.pixelSize: 12
//                     color: popup.colorTextMuted
//                 }
//             }

//             Item { Layout.fillWidth: true }

//             ToolButton {
//                 text: "✕"
//                 onClicked: popup.close()
//                 background: Item {}
//                 contentItem: Text {
//                     text: "✕"
//                     color: popup.colorTextMuted
//                     font.pixelSize: 16
//                     horizontalAlignment: Text.AlignHCenter
//                     verticalAlignment: Text.AlignVCenter
//                 }
//             }
//         }

//         // ---------- Tabs ----------
//         TabBar {
//             id: tabBar
//             Layout.fillWidth: true
//             background: Rectangle { color: "transparent" }

//             TabButton {
//                 text: "muestra"
//                 width: implicitWidth + 24
//             }
//             TabButton {
//                 text: "tokens"
//                 width: implicitWidth + 24
//             }
//             TabButton {
//                 text: "frecuencia"
//                 width: implicitWidth + 24
//             }
//             TabButton {
//                 text: "estadísticas"
//                 width: implicitWidth + 24
//             }
//         }

//         Rectangle {
//             Layout.fillWidth: true
//             height: 1
//             color: popup.colorBorder
//         }

//         // ---------- Contenido ----------
//         StackLayout {
//             Layout.fillWidth: true
//             Layout.fillHeight: true
//             currentIndex: tabBar.currentIndex

//             // === Muestra ===
//             ColumnLayout {
//                 spacing: 8

//                 Rectangle {
//                     Layout.fillWidth: true
//                     Layout.fillHeight: true
//                     color: popup.colorBg
//                     radius: 10
//                     border.width: 1
//                     border.color: popup.colorBorder

//                     ScrollView {
//                         anchors.fill: parent
//                         anchors.margins: 14
//                         clip: true

//                         Text {
//                             width: parent.width
//                             wrapMode: Text.Wrap
//                             font.family: "Consolas, monospace"
//                             font.pixelSize: 12
//                             lineHeight: 1.4
//                             color: "#333333"
//                             text: {
//                                 if (registros.length === 0) return "Sin datos disponibles."
//                                 var r = registros[0]
//                                 var texto = (r.instruction || "") + " " + (r.context || "") + " " + (r.response || "")
//                                 return texto.substring(0, 300) + (texto.length > 300 ? "…" : "")
//                             }
//                         }
//                     }
//                 }

//                 Text {
//                     text: "Primeros 300 caracteres del corpus — vista previa del primer registro"
//                     font.pixelSize: 11
//                     color: popup.colorTextMuted
//                 }
//             }

//             // === Tokens ===
//             GridLayout {
//                 columns: 2
//                 columnSpacing: 14
//                 rowSpacing: 14

//                 Repeater {
//                     model: [
//                         { label: "Tokens totales", valor: popup.datasetInfo.tokens },
//                         { label: "Promedio por registro", valor: popup.datasetInfo.tokens_promedio },
//                         { label: "Longitud máxima", valor: popup.datasetInfo.longitud_maxima },
//                         { label: "Longitud mínima", valor: popup.datasetInfo.longitud_minima },
//                         { label: "Vocabulario único", valor: popup.datasetInfo.vocabulario },
//                         { label: "Ejemplos vacíos", valor: popup.datasetInfo.ejemplos_vacios }
//                     ]

//                     delegate: Rectangle {
//                         Layout.fillWidth: true
//                         Layout.preferredHeight: 70
//                         radius: 10
//                         color: popup.colorBg
//                         border.width: 1
//                         border.color: popup.colorBorder

//                         ColumnLayout {
//                             anchors.centerIn: parent
//                             spacing: 2

//                             Text {
//                                 text: modelData.valor !== undefined ? modelData.valor : "—"
//                                 font.bold: true
//                                 font.pixelSize: 20
//                                 color: popup.colorAccent
//                                 Layout.alignment: Qt.AlignHCenter
//                             }
//                             Text {
//                                 text: modelData.label
//                                 font.pixelSize: 11
//                                 color: popup.colorTextMuted
//                                 Layout.alignment: Qt.AlignHCenter
//                             }
//                         }
//                     }
//                 }
//             }

//             // === Frecuencia ===
//             ScrollView {
//                 clip: true

//                 ColumnLayout {
//                     width: parent.width
//                     spacing: 6

//                     Repeater {
//                         model: popup.calcularFrecuencia()

//                         delegate: RowLayout {
//                             Layout.fillWidth: true
//                             spacing: 10

//                             Text {
//                                 text: modelData.palabra
//                                 font.pixelSize: 13
//                                 color: "#333333"
//                                 Layout.preferredWidth: 140
//                                 elide: Text.ElideRight
//                             }

//                             Rectangle {
//                                 Layout.fillWidth: true
//                                 height: 16
//                                 radius: 8
//                                 color: popup.colorBg

//                                 Rectangle {
//                                     height: parent.height
//                                     radius: 8
//                                     color: popup.colorAccent
//                                     width: Math.max(6, parent.width *
//                                         (modelData.veces / (popup.calcularFrecuencia()[0]
//                                             ? popup.calcularFrecuencia()[0].veces : 1)))
//                                 }
//                             }

//                             Text {
//                                 text: modelData.veces
//                                 font.pixelSize: 12
//                                 color: popup.colorTextMuted
//                                 Layout.preferredWidth: 30
//                                 horizontalAlignment: Text.AlignRight
//                             }
//                         }
//                     }
//                 }
//             }

//             // === Estadísticas ===
//             ScrollView {
//                 clip: true

//                 ColumnLayout {
//                     width: parent.width
//                     spacing: 10

//                     Repeater {
//                         model: [
//                             { label: "ID", valor: popup.datasetInfo.id },
//                             { label: "Formato", valor: popup.datasetInfo.formato },
//                             { label: "Tamaño", valor: (popup.datasetInfo.tamano_mb || 0) + " MB" },
//                             { label: "Estado", valor: popup.datasetInfo.estado },
//                             { label: "Categorías", valor: popup.datasetInfo.categorias ? Object.keys(popup.datasetInfo.categorias).length : 0 },
//                             { label: "Campos", valor: popup.datasetInfo.campos_texto }
//                         ]

//                         delegate: RowLayout {
//                             Layout.fillWidth: true

//                             Text {
//                                 text: modelData.label
//                                 font.bold: true
//                                 font.pixelSize: 13
//                                 color: "#555555"
//                                 Layout.preferredWidth: 120
//                             }
//                             Text {
//                                 text: modelData.valor !== undefined ? modelData.valor : "—"
//                                 font.pixelSize: 13
//                                 color: "#333333"
//                                 Layout.fillWidth: true
//                                 wrapMode: Text.Wrap
//                             }
//                         }
//                     }
//                 }
//             }
//         }
//     }
// }