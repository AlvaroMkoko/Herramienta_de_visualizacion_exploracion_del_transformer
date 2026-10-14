pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../styles" as Style

// Interruptor global de movimiento reducido. Gemelo de ThemeSwitch: vive en
// main.qml, junto a él, para que la preferencia de accesibilidad se alcance
// desde cualquier pantalla y a cualquier ancho. Los paneles solo la leen de
// Style.Theme.movimientoReducido; ninguno guarda una copia local.
ControlActivableAccesible {
    id: control
    objectName: "motionSwitch"

    implicitWidth: 74
    implicitHeight: 34
    hoverEnabled: true
    checkable: true
    checked: Style.Theme.movimientoReducido

    // Anuncia la acción, no el estado, igual que ThemeSwitch.
    Accessible.role: Accessible.Button
    Accessible.name: checked ? "Restaurar movimiento" : "Reducir movimiento"

    ToolTip.visible: hovered
    ToolTip.delay: 500
    ToolTip.text: Accessible.name

    onToggled: Style.Theme.alternarMovimiento()

    background: Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: control.checked ? Style.Theme.acento : Style.Theme.superficie_alterna
        border.width: control.hovered ? 2 : 1
        border.color: control.checked ? Style.Theme.acento_fuerte : Style.Theme.borde_medio
        Behavior on color { ColorAnimation { duration: Style.Theme.duracionMedia } }
    }

    // Pausa: visible con el movimiento reducido (perilla a la derecha).
    Row {
        objectName: "motionSwitchPauseIcon"
        anchors.verticalCenter: parent.verticalCenter
        x: 12
        spacing: 4
        opacity: control.checked ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Style.Theme.duracionCorta } }
        Repeater {
            model: 2
            delegate: Rectangle {
                width: 4; height: 14; radius: 1
                color: Style.Theme.texto_sobre_acento
            }
        }
    }

    // Onda: visible con el movimiento activo (perilla a la izquierda). Ocupa
    // el extremo contrario a la perilla para que el control comunique su
    // función, como el sol y la luna de ThemeSwitch.
    Text {
        objectName: "motionSwitchWaveIcon"
        anchors.verticalCenter: parent.verticalCenter
        x: control.width - width - 10
        text: "∿"
        color: Style.Theme.texto_secundario
        font.pixelSize: 20
        font.bold: true
        opacity: control.checked ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Style.Theme.duracionCorta } }
    }

    // Perilla deslizante. Es una animación de estado: comunica la
    // interacción, así que se conserva aun con movimiento reducido
    // (Theme.qml, sección Movimiento).
    Rectangle {
        objectName: "motionSwitchKnob"
        width: parent.height - 8
        height: width
        radius: width / 2
        color: Style.Theme.surface
        border.color: Style.Theme.borde_suave
        anchors.verticalCenter: parent.verticalCenter
        x: control.checked ? control.width - width - 4 : 4
        Behavior on x { NumberAnimation { duration: Style.Theme.duracionMedia; easing.type: Easing.OutCubic } }
    }
}
