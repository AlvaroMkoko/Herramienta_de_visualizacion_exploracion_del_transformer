import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property string componentId: ""
    property string title: ""
    property string subtitle: ""
    property color accentColor: "#6d5bd0"
    property bool selected: false
    property bool emphasized: false
    property real blockWidth: 224
    property real blockHeight: 42
    property real depthX: 16
    property real depthY: 12
    property bool hovered: hitArea.containsMouse

    signal clicked(string componentId)

    width: blockWidth + depthX + 4
    height: blockHeight + depthY + 4

    readonly property color faceColor: selected
        ? Qt.alpha(accentColor, 0.28)
        : (emphasized ? Qt.alpha(accentColor, 0.25)
        : Qt.alpha(accentColor, hovered ? 0.20 : 0.11)
          )
    readonly property color sideColor: selected
        ? Qt.alpha(accentColor, 0.34)
        : Qt.alpha(accentColor, hovered ? 0.25 : 0.15)

    Shape {
        anchors.fill: parent
        antialiasing: true

        // Bottom face. Together with the front, top, and right faces this
        // closes every visible edge of the prism.
        ShapePath {
            strokeColor: root.accentColor
            strokeWidth: root.selected ? 2.2 : (root.emphasized ? 2.0 : (root.hovered ? 1.7 : 1.15))
            fillColor: root.sideColor
            joinStyle: ShapePath.MiterJoin
            startX: 1
            startY: root.blockHeight
            PathLine { x: root.blockWidth; y: root.blockHeight }
            PathLine { x: root.blockWidth + root.depthX; y: root.blockHeight + root.depthY }
            PathLine { x: 1 + root.depthX; y: root.blockHeight + root.depthY }
            PathLine { x: 1; y: root.blockHeight }
        }

        // Top face creates the depth illusion.
        ShapePath {
            strokeColor: root.accentColor
            strokeWidth: root.selected ? 2.2 : (root.emphasized ? 2.0 : (root.hovered ? 1.7 : 1.15))
            fillColor: root.sideColor
            joinStyle: ShapePath.MiterJoin
            startX: 1
            startY: 1
            PathLine { x: root.blockWidth; y: 1 }
            PathLine { x: root.blockWidth + root.depthX; y: root.depthY }
            PathLine { x: 1 + root.depthX; y: root.depthY }
            PathLine { x: 1; y: 1 }
        }

        // Left face closes the rear-left vertical edge.
        ShapePath {
            strokeColor: root.accentColor
            strokeWidth: root.selected ? 2.2 : (root.emphasized ? 2.0 : (root.hovered ? 1.7 : 1.15))
            fillColor: root.sideColor
            joinStyle: ShapePath.MiterJoin
            startX: 1
            startY: 1
            PathLine { x: 1 + root.depthX; y: root.depthY }
            PathLine { x: 1 + root.depthX; y: root.blockHeight + root.depthY }
            PathLine { x: 1; y: root.blockHeight }
            PathLine { x: 1; y: 1 }
        }

        // Right face.
        ShapePath {
            strokeColor: root.accentColor
            strokeWidth: root.selected ? 2.2 : (root.emphasized ? 2.0 : (root.hovered ? 1.7 : 1.15))
            fillColor: root.sideColor
            joinStyle: ShapePath.MiterJoin
            startX: root.blockWidth
            startY: 1
            PathLine { x: root.blockWidth + root.depthX; y: root.depthY }
            PathLine { x: root.blockWidth + root.depthX; y: root.blockHeight + root.depthY }
            PathLine { x: root.blockWidth; y: root.blockHeight }
            PathLine { x: root.blockWidth; y: 1 }
        }

        // Front face is drawn last so all shared edges meet cleanly.
        ShapePath {
            strokeColor: root.accentColor
            strokeWidth: root.selected ? 2.2 : (root.emphasized ? 2.0 : (root.hovered ? 1.7 : 1.15))
            fillColor: root.faceColor
            joinStyle: ShapePath.MiterJoin
            startX: 1
            startY: 1
            PathLine { x: root.blockWidth; y: 1 }
            PathLine { x: root.blockWidth; y: root.blockHeight }
            PathLine { x: 1; y: root.blockHeight }
            PathLine { x: 1; y: 1 }
        }
    }

    Column {
        x: 5
        y: root.subtitle.length > 0 ? 8 : 12
        width: root.blockWidth - 8
        spacing: 2

        Text {
            width: parent.width
            text: root.title
            color: Qt.darker(root.accentColor, 1.45)
            font.bold: root.selected
            font.pixelSize: root.title.length > 25 ? 11 : 12
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        Text {
            visible: root.subtitle.length > 0
            width: parent.width
            text: root.subtitle
            color: Qt.alpha(Qt.darker(root.accentColor, 1.35), 0.72)
            font.pixelSize: 8
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    Rectangle {
        visible: root.selected
        x: -6
        y: root.blockHeight / 2 - 3
        width: 6
        height: 6
        radius: 3
        color: root.accentColor
    }

    Rectangle {
        visible: root.emphasized && !root.selected
        x: root.blockWidth - 7
        y: -7
        width: 14
        height: 14
        radius: 7
        color: root.accentColor
        border.color: "white"
        border.width: 2

        SequentialAnimation on opacity {
            running: root.emphasized
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 650 }
            NumberAnimation { to: 1.0; duration: 650 }
        }
    }

    MouseArea {
        id: hitArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked(root.componentId)
    }

    Behavior on scale {
        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
    }
    scale: hovered ? 1.018 : 1.0
}
