pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Guía de primer uso: sombrea la pantalla y deja al descubierto una parte a la vez.
// Se muestra sola una vez por `tourId`; se puede omitir y volver a abrir.
//
// Cada paso es { target, title, text, preferences }. Sin `target` visible, la tarjeta
// aparece centrada. `preferences` añade la elección de tema y de tamaño de letra.
Item {
    id: root
    objectName: "guidedTour"

    property string tourId: ""
    property var steps: []
    // Flickable que se desplaza para dejar el objetivo a la vista.
    property var scroller: null
    property real s: 1
    property int index: 0
    property bool running: false
    property rect spotlight: Qt.rect(0, 0, 0, 0)

    readonly property var currentStep: root.steps[root.index] || ({})
    readonly property bool hasSpotlight: root.spotlight.width > 0 && root.spotlight.height > 0

    parent: Overlay.overlay
    anchors.fill: parent
    visible: root.running
    z: 1000

    Settings {
        id: memoria
        category: "guias"
        property string vistas: ""
    }

    function alreadySeen() {
        return memoria.vistas.split(",").indexOf(root.tourId) !== -1
    }

    function startIfNew() {
        if (!root.alreadySeen())
            root.start()
    }

    function start() {
        root.index = 0
        root.running = true
        Qt.callLater(root.refresh)
    }

    function finish() {
        root.running = false
        // La guía desplazó la pantalla para mostrar sus objetivos: se devuelve al inicio.
        if (root.scroller)
            root.scroller.contentY = 0
        if (!root.alreadySeen())
            memoria.vistas = memoria.vistas.length
                    ? memoria.vistas + "," + root.tourId : root.tourId
    }

    function advance(delta) {
        var next = root.index + delta
        if (next >= root.steps.length) {
            root.finish()
            return
        }
        root.index = Math.max(0, next)
        Qt.callLater(root.refresh)
    }

    function refresh() {
        var target = root.currentStep.target
        if (!target || !target.visible || target.width <= 0 || target.height <= 0) {
            root.spotlight = Qt.rect(0, 0, 0, 0)
            return
        }
        if (root.scroller && root.scroller.contentItem) {
            var y = target.mapToItem(root.scroller.contentItem, 0, 0).y
            var limit = Math.max(0, root.scroller.contentHeight - root.scroller.height)
            root.scroller.contentY = Math.max(0, Math.min(limit, y - 24 * root.s))
        }
        var box = target.mapToItem(root, 0, 0, target.width, target.height)
        var margin = 6 * root.s
        root.spotlight = Qt.rect(box.x - margin, box.y - margin,
                                 box.width + 2 * margin, box.height + 2 * margin)
    }

    onWidthChanged: if (root.running) Qt.callLater(root.refresh)
    onHeightChanged: if (root.running) Qt.callLater(root.refresh)

    // Bloquea la pantalla de abajo: durante la guía sólo se avanza con sus botones.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onWheel: function (wheel) { wheel.accepted = true }
    }

    Rectangle {
        x: 0; y: 0; width: parent.width
        height: root.hasSpotlight ? Math.max(0, root.spotlight.y) : parent.height
        color: Style.Theme.velo
    }
    Rectangle {
        visible: root.hasSpotlight
        x: 0; y: root.spotlight.y; height: root.spotlight.height
        width: Math.max(0, root.spotlight.x)
        color: Style.Theme.velo
    }
    Rectangle {
        visible: root.hasSpotlight
        x: root.spotlight.x + root.spotlight.width; y: root.spotlight.y
        height: root.spotlight.height
        width: Math.max(0, parent.width - x)
        color: Style.Theme.velo
    }
    Rectangle {
        visible: root.hasSpotlight
        x: 0; y: root.spotlight.y + root.spotlight.height
        width: parent.width
        height: Math.max(0, parent.height - y)
        color: Style.Theme.velo
    }
    Rectangle {
        visible: root.hasSpotlight
        x: root.spotlight.x; y: root.spotlight.y
        width: root.spotlight.width; height: root.spotlight.height
        color: "transparent"
        radius: 8 * root.s
        border.width: 3
        border.color: Style.Theme.acento
    }

    Rectangle {
        id: card
        objectName: "guidedTourCard"
        width: Math.min(parent.width - 32 * root.s, 480 * root.s)
        height: cardColumn.implicitHeight + 32 * root.s
        radius: 12 * root.s
        color: Style.Theme.surface
        border.color: Style.Theme.acento
        x: root.hasSpotlight
           ? Math.max(16 * root.s, Math.min(parent.width - width - 16 * root.s,
                                            root.spotlight.x))
           : (parent.width - width) / 2
        // Debajo del objetivo si cabe; si no, encima, y si tampoco, al fondo.
        y: {
            if (!root.hasSpotlight)
                return (parent.height - height) / 2
            var below = root.spotlight.y + root.spotlight.height + 12 * root.s
            if (below + height <= parent.height - 8 * root.s)
                return below
            var above = root.spotlight.y - height - 12 * root.s
            return above >= 8 * root.s ? above : parent.height - height - 8 * root.s
        }

        ColumnLayout {
            id: cardColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16 * root.s
            spacing: 10 * root.s

            Text {
                text: "GUÍA · " + (root.index + 1) + " DE " + root.steps.length
                color: Style.Theme.acento_fuerte
                font.bold: true
                font.pixelSize: Math.max(11, 11 * root.s)
                font.letterSpacing: 0.6
            }
            Text {
                objectName: "guidedTourTitle"
                Layout.fillWidth: true
                text: String(root.currentStep.title || "")
                color: Style.Theme.texto_primario
                font.bold: true
                font.pixelSize: Math.max(15, 18 * root.s)
                wrapMode: Text.WordWrap
            }
            Text {
                objectName: "guidedTourText"
                Layout.fillWidth: true
                text: String(root.currentStep.text || "")
                color: Style.Theme.texto_primario
                font.pixelSize: Math.max(13, 14 * root.s)
                lineHeight: 1.25
                wrapMode: Text.WordWrap
            }

            RowLayout {
                visible: root.currentStep.preferences === true
                Layout.fillWidth: true
                spacing: 8 * root.s
                BotonSecundario {
                    objectName: "guidedTourLightTheme"
                    Layout.fillWidth: true
                    sx: root.s; sy: root.s
                    text: (Style.Theme.modoOscuro ? "" : "✓ ") + "Modo claro"
                    onClicked: Style.Theme.modoOscuro = false
                }
                BotonSecundario {
                    objectName: "guidedTourDarkTheme"
                    Layout.fillWidth: true
                    sx: root.s; sy: root.s
                    text: (Style.Theme.modoOscuro ? "✓ " : "") + "Modo oscuro"
                    onClicked: Style.Theme.modoOscuro = true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * root.s
                BotonSecundario {
                    objectName: "guidedTourSkip"
                    visible: root.index < root.steps.length - 1
                    sx: root.s; sy: root.s
                    text: "Omitir guía"
                    onClicked: root.finish()
                }
                Item { Layout.fillWidth: true }
                BotonSecundario {
                    visible: root.index > 0
                    sx: root.s; sy: root.s
                    text: "Anterior"
                    onClicked: root.advance(-1)
                }
                BotonPrincipal {
                    objectName: "guidedTourNext"
                    Layout.preferredWidth: 120 * root.s
                    Layout.preferredHeight: 34 * root.s
                    text: root.index >= root.steps.length - 1 ? "Empezar" : "Siguiente"
                    onClicked: root.advance(1)
                }
            }
        }
    }
}
