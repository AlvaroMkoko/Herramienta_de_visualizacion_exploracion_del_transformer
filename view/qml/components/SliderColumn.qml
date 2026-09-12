import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

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
    property string helpConceptId: ""

    signal helpRequested(string conceptId)

    Layout.fillWidth: true

    spacing: 8 * sy

    RowLayout {
        Layout.fillWidth: true
        spacing: 6 * root.sx

        Text {
            id: titulo
            Layout.fillWidth: true
            color: Style.Theme.chip_texto
            font.pixelSize: 14 * root.sy
            wrapMode: Text.WordWrap
        }

        ConceptHelpButton {
            visible: root.helpConceptId !== ""
            conceptId: root.helpConceptId
            controlSize: Math.max(24, 27 * Math.min(root.sx, root.sy))
            onHelpRequested: function(conceptId) {
                root.helpRequested(conceptId)
            }
        }
    }

    RowLayout {

        Layout.fillWidth: true

        spacing: 12 * sx

        SliderPrincipal {
            id: slider

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            sx: root.sx
            sy: root.sy

            from: root.from
            to: root.to
            stepSize: root.stepSize
        }

        Text {
            id: valor

            Layout.preferredWidth: 55 * sx
            Layout.minimumWidth: 55 * sx
            Layout.maximumWidth: 55 * sx

            Layout.alignment: Qt.AlignVCenter

            horizontalAlignment: Text.AlignRight

            text: tipo_dato === "entero"
                    ? Math.round(slider.value)
                    : Number(slider.value).toFixed(3)

            color: Style.Theme.acento

            font.bold: true
            font.pixelSize: 18 * sy
        }
    }
}
