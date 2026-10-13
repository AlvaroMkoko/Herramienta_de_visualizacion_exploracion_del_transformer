import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

Rectangle {
    id: root

    property alias checked: control.checked
    property string title: "Opción"
    property string checkedText: "Activa"
    property string uncheckedText: "Inactiva"
    property color accent: Style.Theme.acento
    property real sx: 1
    property real sy: 1

    implicitHeight: 76 * sy
    radius: 10 * sx
    color: Style.Theme.superficie_alterna
    border.color: Qt.alpha(accent, 0.65)

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10 * root.sx
        spacing: 8 * root.sx

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2 * root.sy
            Text {
                Layout.fillWidth: true
                text: root.title
                color: Style.Theme.texto_secundario_fuerte
                font.bold: true
                font.pixelSize: Math.max(10, 11 * root.sy)
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                text: control.checked ? root.checkedText : root.uncheckedText
                color: control.checked ? root.accent : Style.Theme.texto_terciario
                font.bold: true
                font.pixelSize: Math.max(9, 10 * root.sy)
            }
        }

        Switch {
            id: control
            objectName: "laboratoryToggleControl"
            hoverEnabled: true
            focusPolicy: Qt.StrongFocus
            Accessible.name: root.title
            Accessible.description: checked ? root.checkedText : root.uncheckedText

            indicator: Rectangle {
                implicitWidth: 48 * root.sx
                implicitHeight: 27 * root.sy
                x: control.leftPadding
                y: parent.height / 2 - height / 2
                radius: height / 2
                color: control.checked ? root.accent : Style.Theme.divisor
                border.color: control.checked ? root.accent : Style.Theme.borde_medio

                Rectangle {
                    x: control.checked ? parent.width - width - 4 * root.sx : 4 * root.sx
                    anchors.verticalCenter: parent.verticalCenter
                    width: 19 * root.sx
                    height: 19 * root.sy
                    radius: width / 2
                    color: control.checked ? Style.Theme.texto_sobre_acento
                                           : Style.Theme.surface
                    border.color: Style.Theme.borde_suave
                    Behavior on x { NumberAnimation { duration: 130 } }
                }
            }

            contentItem: Item { implicitWidth: 0 }
        }
    }
}
