import QtQuick
import QtQuick.Controls
import "../styles" as Style

AbstractButton {
    id: control
    objectName: "themeSwitch"

    implicitWidth: 74
    implicitHeight: 34
    hoverEnabled: true
    checkable: true
    checked: Style.Theme.modoOscuro

    Accessible.role: Accessible.Button
    Accessible.name: checked ? "Cambiar a modo claro" : "Cambiar a modo oscuro"

    onToggled: Style.Theme.alternarModo()

    background: Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: control.checked ? "#141418" : "#F97316"
        border.width: control.hovered ? 2 : 0
        border.color: control.checked ? "#4A4A5A" : "#C2560B"
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    // Luna con estrellas: visible en modo oscuro
    Item {
        width: 20; height: 20
        anchors.verticalCenter: parent.verticalCenter
        x: 9
        opacity: control.checked ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d"); ctx.reset()
                ctx.fillStyle = "#FFFFFF"
                // Media luna: un círculo lleno menos otro desplazado
                ctx.beginPath(); ctx.arc(11, 11, 8, 0, Math.PI * 2); ctx.fill()
                ctx.globalCompositeOperation = "destination-out"
                ctx.beginPath(); ctx.arc(6, 8, 7.5, 0, Math.PI * 2); ctx.fill()
            }
        }
        Repeater {
            model: [{x: 1, y: 2, s: 3.2}, {x: 6, y: 0, s: 2.4}, {x: 2, y: 8, s: 2}]
            delegate: Rectangle {
                required property var modelData
                x: modelData.x; y: modelData.y
                width: modelData.s; height: modelData.s
                radius: width / 2; color: "#FFFFFF"
            }
        }
    }

    // Sol: visible en modo claro
    Item {
        id: sol
        width: 22; height: 22
        anchors.verticalCenter: parent.verticalCenter
        // En modo claro la perilla está a la izquierda; el sol ocupa el
        // extremo contrario para que el control comunique su función.
        x: control.width - width - 9
        opacity: control.checked ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Rectangle {
            anchors.centerIn: parent
            width: 10; height: 10; radius: 5
            color: "#FFFFFF"
        }
        Repeater {
            model: 8
            delegate: Rectangle {
                required property int index
                width: 2; height: 4; radius: 1; color: "#FFFFFF"
                x: sol.width / 2 - 1 + Math.cos(index * Math.PI / 4) * 9
                y: sol.height / 2 - 2 + Math.sin(index * Math.PI / 4) * 9
                rotation: index * 45
            }
        }
    }

    // Perilla deslizante
    Rectangle {
        objectName: "themeSwitchKnob"
        width: parent.height - 8
        height: width
        radius: width / 2
        color: "#FFFFFF"
        anchors.verticalCenter: parent.verticalCenter
        x: control.checked ? control.width - width - 4 : 4
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }
}
