import QtQuick
import QtQuick.Controls

Page {

    Label {
        anchors.centerIn: parent
        text: "Pantalla de configuración"
    }

    Button {
        text: "Volver"

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 20

        onClicked: StackView.view.pop()
    }
}