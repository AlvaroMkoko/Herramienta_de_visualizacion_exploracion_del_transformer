import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Control compacto para los parámetros del laboratorio. Agrupa nombre, valor
// y rango en una sola tarjeta para que la barra no parezca un control aislado.
Rectangle {
    id: root

    property alias value: control.value
    property real from: 0
    property real to: 1
    property real stepSize: 0.1
    property int displayOffset: 0
    property int decimals: 0
    property string title: "Parámetro"
    property string suffix: ""
    property color accent: Style.Theme.acento
    property real sx: 1
    property real sy: 1

    function formatted(number) {
        var shifted = Number(number) + root.displayOffset
        return (root.decimals > 0 ? shifted.toFixed(root.decimals)
                                  : String(Math.round(shifted))) + root.suffix
    }

    implicitHeight: 76 * sy
    radius: 10 * sx
    color: Style.Theme.superficie_alterna
    border.color: Qt.alpha(accent, 0.65)

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 10 * root.sx
        anchors.rightMargin: 10 * root.sx
        anchors.topMargin: 7 * root.sy
        anchors.bottomMargin: 6 * root.sy
        spacing: 2 * root.sy

        RowLayout {
            Layout.fillWidth: true
            spacing: 6 * root.sx

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Style.Theme.texto_secundario_fuerte
                font.bold: true
                font.pixelSize: Math.max(10, 11 * root.sy)
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.preferredWidth: Math.max(42 * root.sx,
                                                currentValue.implicitWidth + 14 * root.sx)
                Layout.preferredHeight: 23 * root.sy
                radius: height / 2
                color: Qt.alpha(root.accent, 0.14)
                border.color: root.accent

                Text {
                    id: currentValue
                    anchors.centerIn: parent
                    text: root.formatted(control.value)
                    color: Style.Theme.texto_primario
                    font.family: Style.Theme.fuente_mono
                    font.bold: true
                    font.pixelSize: Math.max(10, 11 * root.sy)
                }
            }
        }

        SliderPrincipal {
            id: control
            objectName: "laboratorySliderControl"
            Layout.fillWidth: true
            Layout.preferredHeight: 26 * root.sy
            from: root.from
            to: root.to
            stepSize: root.stepSize
            colorRelleno: root.accent
            sx: root.sx
            sy: root.sy
            Accessible.name: root.title
            Accessible.description: "Valor " + root.formatted(value)
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: root.formatted(root.from)
                color: Style.Theme.texto_terciario
                font.pixelSize: Math.max(8, 9 * root.sy)
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.formatted(root.to)
                color: Style.Theme.texto_terciario
                font.pixelSize: Math.max(8, 9 * root.sy)
            }
        }
    }
}
