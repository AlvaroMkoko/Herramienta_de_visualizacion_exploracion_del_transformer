// Ventana principal / navegación raíz.

import QtQuick
import QtQuick.Controls
import "styles" as Style
import "components"

ApplicationWindow {
    id: window
    visible: true
    width: Style.Theme.baseWidth
    height: Style.Theme.baseHeight
    // Las vistas escalan desde 1280 x 820, pero la ventana puede reducirse
    // para portatiles con 720--768 px de alto util.
    minimumWidth: 960
    minimumHeight: 600
    title: "Visualizador de Transformers"

    // Los controles Qt no personalizados heredan también una paleta legible.
    // Esto cubre botones estándar de diálogos y evita que una incorporación
    // futura vuelva a caer en los colores de plataforma de bajo contraste.
    palette.window: Style.Theme.fondo
    palette.windowText: Style.Theme.texto_primario
    palette.base: Style.Theme.surface
    palette.text: Style.Theme.texto_primario
    palette.button: Style.Theme.boton
    palette.buttonText: Style.Theme.texto_primario
    palette.highlight: Style.Theme.acento
    palette.highlightedText: Style.Theme.texto_sobre_acento
    palette.mid: Style.Theme.borde_boton
    palette.dark: Style.Theme.borde

    readonly property bool multiScreenAvailable:
        typeof displayManager !== "undefined"
        && displayManager
        && displayManager.hasSecondaryScreen

    StackView {
        id: stack
        objectName: "mainNavigation"
        anchors.fill: parent

        // Transición única para TODAS las pantallas: la nueva aparece y sube
        // un poco; al volver (pop), la que se va baja y se desvanece. La
        // dirección del movimiento dice "avanzo" o "regreso" sin palabras.
        // Se usan NumberAnimation y no OpacityAnimator/YAnimator: los Animator
        // dependen del hilo de render y, si la ventana aún no pinta (primer
        // push), la página puede quedarse congelada en opacidad 0.
        readonly property int _dur: Style.Theme.movimientoReducido ? 0 : Style.Theme.duracionEntrada
        readonly property int _durSalida: Style.Theme.movimientoReducido ? 0 : Style.Theme.duracionMedia
        readonly property real _dist: Style.Theme.movimientoReducido ? 0 : 18

        pushEnter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: stack._dur; easing.type: Easing.OutCubic }
                NumberAnimation { property: "y"; from: stack._dist; to: 0; duration: stack._dur; easing.type: Easing.OutCubic }
            }
        }
        pushExit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: stack._durSalida; easing.type: Easing.OutCubic }
        }
        popEnter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: stack._dur; easing.type: Easing.OutCubic }
        }
        popExit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: stack._durSalida; easing.type: Easing.InCubic }
                NumberAnimation { property: "y"; from: 0; to: stack._dist; duration: stack._durSalida; easing.type: Easing.InCubic }
            }
        }
        replaceEnter: pushEnter
        replaceExit: pushExit
    }

    ThemeSwitch {
        id: themeSwitch
        z: 100
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
    }

    Rectangle {
        id: indicadorDual
        objectName: "dualScreenIndicator"
        z: 100
        visible: window.multiScreenAvailable
        anchors.right: themeSwitch.left
        anchors.rightMargin: 8
        anchors.verticalCenter: themeSwitch.verticalCenter
        width: 150
        height: 32
        radius: height / 2
        color: Style.Theme.info_fondo
        border.color: Style.Theme.inferencia_estructura

        Text {
            anchors.centerIn: parent
            text: "\u25a3 Vista dual activa"
            color: Style.Theme.info_texto
            font.bold: true
            font.pixelSize: 11
        }
    }

    // ── Aula conectada (alumno) ──────────────────────────────────────
    // Visibles en cualquier pantalla: el alumno no tiene que volver a la
    // bienvenida para saber si su docente lo ve o para leer un aviso.
    readonly property var aulaAlumno: typeof mainViewModel !== "undefined" && mainViewModel
                                      ? mainViewModel.classroomStudentController : null

    Rectangle {
        id: chipAula
        objectName: "classroomStatusChip"
        readonly property bool enLinea: visible && window.aulaAlumno.conectado
        z: 100
        visible: window.aulaAlumno !== null && window.aulaAlumno.enClase
        anchors.right: indicadorDual.visible ? indicadorDual.left : themeSwitch.left
        anchors.rightMargin: 8
        anchors.verticalCenter: themeSwitch.verticalCenter
        width: textoChipAula.implicitWidth + 30
        height: 32
        radius: height / 2
        color: enLinea ? Style.Theme.exito_fondo : Style.Theme.aviso_fondo
        border.color: enLinea ? Style.Theme.success : Style.Theme.warning
        Accessible.role: Accessible.StaticText
        Accessible.name: "Estado de la clase: " + textoChipAula.text

        Text {
            id: textoChipAula
            anchors.centerIn: parent
            text: chipAula.visible
                  ? (chipAula.enLinea ? "● " : "○ ") + window.aulaAlumno.estadoTexto
                  : ""
            color: chipAula.enLinea ? Style.Theme.exito_texto : Style.Theme.aviso_texto
            font.bold: true
            font.pixelSize: 11
        }
    }

    Rectangle {
        id: avisoAula
        objectName: "classroomAnnouncementBanner"
        z: 101
        visible: window.aulaAlumno !== null && window.aulaAlumno.ultimoAviso !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 56
        width: Math.min(640, window.width - 48)
        height: Math.max(textoAviso.implicitHeight, cerrarAviso.height) + 28
        radius: 12
        color: Style.Theme.info_fondo
        border.color: Style.Theme.info

        Text {
            id: textoAviso
            anchors.left: parent.left
            anchors.right: cerrarAviso.left
            anchors.margins: 14
            anchors.verticalCenter: parent.verticalCenter
            text: avisoAula.visible ? "📣 Aviso del docente: " + window.aulaAlumno.ultimoAviso : ""
            color: Style.Theme.info_texto
            font.pixelSize: 14
            wrapMode: Text.WordWrap
        }
        BotonSecundario {
            id: cerrarAviso
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 100
            height: 32
            text: "Entendido"
            onClicked: window.aulaAlumno.descartarAviso()
        }
    }

    Component.onCompleted: {
        if (typeof displayManager !== "undefined" && displayManager)
            displayManager.registerMainWindow(window)
        // La primera pantalla aparece sin transición: no hay de dónde venir.
        stack.push("screens/ProfileSelectionScreen.qml", {
            "stackView": stack
        }, StackView.Immediate)
    }
}
