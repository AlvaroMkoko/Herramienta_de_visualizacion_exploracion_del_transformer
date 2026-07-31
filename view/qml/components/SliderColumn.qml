import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root

    // Propiedades públicas
    property alias text: titulo.text
    property alias value: slider.value
    property string tipo_dato: "entero"

    property real from: 0
    property real to: 10
    property real stepSize: 1

    property real sx: 1
    property real sy: 1

    spacing: 6 * sy

    Text {
        id: titulo

        Layout.fillWidth: true

        color: "#555555"
        font.pixelSize: 14 * sy
    }

    RowLayout {
        Layout.fillWidth: true

        spacing: 6 * sx

        Slider {
            id: slider

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            from: root.from
            to: root.to
            stepSize: root.stepSize
            snapMode: Slider.SnapAlways

            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2

                width: slider.availableWidth
                height: 6 * root.sy

                radius: height / 2
                color: "#E0E0E0"

                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height

                    radius: parent.radius
                    color: "#5A4FCF"
                }
            }

            handle: Rectangle {
                x: slider.leftPadding +
                   slider.visualPosition * (slider.availableWidth - width)

                y: slider.topPadding +
                   slider.availableHeight / 2 - height / 2

                width: 26 * root.sx
                height: width

                radius: width / 2

                color: "#5A4FCF"

                border.width: 2
                border.color: "white"
            }
        }

        Text {
            id: valor

            Layout.alignment: Qt.AlignVCenter

            text: tipo_dato === "entero"
                    ? Math.round(slider.value)
                    : slider.value.toFixed(3)

            color: "#5A4FCF"
            font.pixelSize: 22 * root.sy
            font.bold: true
        }
    }
}