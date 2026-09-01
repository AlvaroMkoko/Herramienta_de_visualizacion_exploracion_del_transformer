import QtQuick
import QtQuick.Controls

// Boton pequeno para solicitar una explicacion contextual. No consulta datos
// ni abre ventanas por su cuenta: el padre decide como atender la senal.
ToolButton {
    id: root
    objectName: "conceptHelp_" + root.conceptId

    property string conceptId: ""
    property string conceptLabel: ""
    property real controlSize: 24

    readonly property string readableLabel: root.conceptLabel.trim() !== ""
                                            ? root.conceptLabel
                                            : root.conceptId.replace(/_/g, " ")
    readonly property real iconDiameter: Math.max(
                                             15,
                                             Math.min(19, root.controlSize * 0.72)
                                         )

    signal helpRequested(string conceptId)

    function requestHelp() {
        if (root.enabled)
            root.helpRequested(root.conceptId)
    }

    implicitWidth: Math.max(22, root.controlSize)
    implicitHeight: Math.max(22, root.controlSize)
    padding: 0
    enabled: root.conceptId.trim().length > 0
    activeFocusOnTab: true
    hoverEnabled: true

    Accessible.role: Accessible.Button
    Accessible.name: "Abrir explicación: " + root.readableLabel
    Accessible.description: "Muestra informacion educativa sobre este concepto tecnico."

    ToolTip.delay: 350
    ToolTip.timeout: 5000
    ToolTip.visible: root.hovered || root.activeFocus
    ToolTip.text: "Ver explicación de " + root.readableLabel

    background: Item {
        Rectangle {
            anchors.centerIn: parent
            width: root.iconDiameter
            height: root.iconDiameter
            radius: width / 2
            color: root.down ? "#DED7F4"
                             : root.hovered || root.activeFocus ? "#F1EDF9" : "transparent"
            border.color: root.activeFocus ? "#6C5FC3"
                                           : root.hovered ? "#AAA0CF" : "#D4CEE5"
            border.width: root.activeFocus ? 1.5 : 1
            opacity: root.hovered || root.activeFocus ? 1.0 : 0.52
        }
    }

    contentItem: Text {
        text: "?"
        color: root.enabled ? "#5B4AA5" : "#9CA3AF"
        font.bold: true
        font.pixelSize: Math.max(10, root.iconDiameter * 0.64)
        opacity: root.hovered || root.activeFocus ? 1.0 : 0.58
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    onClicked: root.requestHelp()
}
