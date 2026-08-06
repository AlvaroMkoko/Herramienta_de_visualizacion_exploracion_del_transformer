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

    width: 40
    height: 40

    Rectangle {
        anchors.centerIn: parent
        width: root.selected ? 38 : 34
        height: width
        radius: width / 2
        color: root.selected ? Qt.alpha(root.accentColor, 0.20) : "#f8f8fd"
        border.color: root.accentColor
        border.width: root.selected ? 2.2 : 1.4

        Text {
            anchors.centerIn: parent
            text: "+"
            color: Qt.darker(root.accentColor, 1.2)
            font.pixelSize: 22
            font.bold: true
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

