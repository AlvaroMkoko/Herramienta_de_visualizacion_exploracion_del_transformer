pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Cromo global de main.qml: un solo botón en la esquina superior derecha que
// abre las preferencias de toda la aplicación. ThemeSwitch y MotionSwitch se
// montan dentro tal cual; este componente solo decide dónde se dibujan.
ControlActivableAccesible {
    id: control
    objectName: "preferencesButton"

    implicitWidth: 34
    implicitHeight: 34
    radioResaltado: height / 2

    // Anuncia la acción, no el estado, como ThemeSwitch.
    Accessible.role: Accessible.Button
    Accessible.name: panelOpen ? "Cerrar preferencias" : "Abrir preferencias"

    ToolTip.visible: hovered && !panelOpen
    ToolTip.delay: 500
    ToolTip.text: "Preferencias"

    // `visible` y no `opened`: `opened` solo se vuelve cierto al terminar la
    // animación de entrada, y durante ella el botón anunciaría «Abrir» con el
    // panel ya en pantalla.
    readonly property bool panelOpen: panel.visible
    // Abrir el panel es una animación de entrada, no de estado: el
    // movimiento reducido la apaga (Theme.qml, sección Movimiento). Lo
    // obedece el propio panel que contiene el interruptor.
    readonly property int openDuration: Style.Theme.movimientoReducido
                                        ? 0 : Style.Theme.duracionEntrada

    onClicked: panelOpen ? panel.close() : panel.open()

    background: Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: control.panelOpen ? Style.Theme.acento_fondo : Style.Theme.surface
        border.width: control.hovered ? 2 : 1
        border.color: control.panelOpen ? Style.Theme.acento : Style.Theme.borde_medio
        Behavior on color { ColorAnimation { duration: Style.Theme.duracionCorta } }
    }

    Text {
        anchors.centerIn: parent
        text: "⚙"
        color: control.panelOpen ? Style.Theme.acento : Style.Theme.texto_secundario
        font.pixelSize: 19
    }

    Popup {
        id: panel
        objectName: "preferencesPanel"
        // Debajo del botón y alineado a su borde derecho: la esquina es del
        // cromo y el panel no debe salirse de la ventana.
        x: control.width - width
        y: control.height + 8
        padding: 14
        modal: false
        focus: true
        // OutsideParent y no Outside: pulsar el propio botón con el panel
        // abierto debe cerrarlo una vez, no cerrarlo y reabrirlo.
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        // NumberAnimation y no OpacityAnimator: los Animator dependen del hilo
        // de render y pueden dejar el panel congelado en opacidad 0.
        enter: Transition {
            NumberAnimation {
                property: "opacity"; from: 0; to: 1
                duration: control.openDuration; easing.type: Easing.OutCubic
            }
        }
        exit: Transition {
            NumberAnimation {
                property: "opacity"; from: 1; to: 0
                duration: control.openDuration; easing.type: Easing.InCubic
            }
        }

        // El foco entra al panel al abrirlo y vuelve al botón al cerrarlo.
        // Solo vuelve si estaba dentro: si el panel se cierra porque el
        // usuario pulsó otro control, el foco es de ese control.
        onOpened: interruptorTema.forceActiveFocus(Qt.TabFocusReason)
        onAboutToHide: {
            if (panel.activeFocus)
                control.forceActiveFocus(Qt.OtherFocusReason)
        }

        background: Rectangle {
            radius: 12
            color: Style.Theme.surface
            border.color: Style.Theme.borde_medio
        }

        // Sin ListView: un ListView con header/footer dentro de un Popup falla
        // al crear el componente (docs/trampas.md).
        contentItem: ColumnLayout {
            spacing: 12

            Text {
                text: "Preferencias"
                color: Style.Theme.texto_primario
                font.bold: true
                font.pixelSize: 13
            }

            RowLayout {
                spacing: 16
                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 140
                    text: "Modo oscuro"
                    color: Style.Theme.texto_primario
                    font.pixelSize: 12
                }
                ThemeSwitch { id: interruptorTema }
            }

            RowLayout {
                spacing: 16
                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 140
                    text: "Reducir movimiento"
                    color: Style.Theme.texto_primario
                    font.pixelSize: 12
                }
                MotionSwitch {}
            }
        }
    }
}
