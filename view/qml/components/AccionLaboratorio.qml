import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Fila de acción con icono, título, detalle contextual y chevron.
//
// Sustituye a los botones de texto centrado cuando varias acciones del
// mismo nivel necesitan distinguirse entre sí: el icono permite reconocerlas
// de un vistazo y el detalle responde "¿qué pasa si hago clic?" antes del
// clic. Úsala en listas de 2 a 5 acciones; con una sola, usa un botón.
//
// Ejemplo:
//   AccionLaboratorio {
//       glifo: "⚙"
//       titulo: "Entrenar un modelo"
//       detalle: "Elige datos e hiperparámetros"
//       onClicked: ...
//   }
AbstractButton {
    id: control

    property string glifo: ""
    property string titulo: text
    property string detalle: ""
    // Resalta el detalle con color de aviso (p. ej. "Necesitas 2 modelos").
    property bool detalleEsAviso: false

    implicitHeight: Math.max(60, fila.implicitHeight + 20)
    implicitWidth: fila.implicitWidth + 28
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    text: titulo

    Accessible.role: Accessible.Button
    Accessible.name: titulo
    Accessible.description: detalle

    background: Rectangle {
        radius: 10
        color: control.enabled && (control.hovered || control.down)
               ? Style.Theme.acento_fondo : Style.Theme.superficie_alterna
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus || (control.enabled && control.hovered)
                      ? Style.Theme.acento : Style.Theme.borde_medio
        Behavior on color { ColorAnimation { duration: Style.Theme.duracionCorta } }
        Behavior on border.color { ColorAnimation { duration: Style.Theme.duracionCorta } }
    }

    contentItem: Item {
        opacity: control.enabled ? 1.0 : 0.55

        RowLayout {
            id: fila
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 9
                color: control.enabled && control.hovered ? Style.Theme.surface : Style.Theme.acento_fondo
                Behavior on color { ColorAnimation { duration: Style.Theme.duracionCorta } }

                Text {
                    anchors.centerIn: parent
                    text: control.glifo
                    color: Style.Theme.acento_texto
                    font.family: Style.Theme.fuente_simbolos
                    font.pixelSize: 17
                    Accessible.ignored: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: control.titulo
                    color: Style.Theme.texto_primario
                    font.family: Style.Theme.fuente_interfaz
                    font.pixelSize: 15
                    font.bold: true
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: control.detalle
                    color: control.detalleEsAviso ? Style.Theme.aviso_texto
                                                  : Style.Theme.texto_secundario
                    font.family: Style.Theme.fuente_interfaz
                    font.pixelSize: Style.Theme.smallSize
                    // Envuelve (máx. 2 líneas) en vez de truncar: el detalle
                    // es información, no decoración.
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            Text {
                text: "›"
                color: control.enabled && control.hovered ? Style.Theme.acento : Style.Theme.texto_terciario
                font.pixelSize: 24
                Accessible.ignored: true
                transform: Translate {
                    x: control.enabled && control.hovered ? 3 : 0
                    Behavior on x {
                        NumberAnimation { duration: Style.Theme.duracionCorta; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
