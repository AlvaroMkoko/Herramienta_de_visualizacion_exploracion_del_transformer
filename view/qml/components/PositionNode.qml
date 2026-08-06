import QtQuick
import QtQuick.Controls
import "../styles" as Style

Item {
    id: root

    property string componentId: ""
    property bool selected: false
    property bool hovered: hitArea.containsMouse
    property color accentColor: "#6d5bd0"
    signal clicked(string componentId)

    width: 48
    height: 48

    Rectangle {
        anchors.centerIn: parent
        width: root.selected ? 45 : 41
        height: width
        radius: width / 2
        color: root.selected
            ? Qt.alpha(root.accentColor, 0.22)
            : Qt.alpha(root.accentColor, root.hovered ? 0.15 : 0.08)
        border.color: root.accentColor
        border.width: root.selected ? 2 : 1.2

        Text {
            anchors.centerIn: parent
            text: "PE"
            color: Qt.darker(root.accentColor, 1.2)
            font.pixelSize: 12
            font.bold: root.selected
        }
    }

    MouseArea {
        id: hitArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked(root.componentId)
    }
}

