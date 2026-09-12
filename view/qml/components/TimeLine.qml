pragma ComponentBehavior: Bound

import QtQuick
import "../styles" as Style

/*
    TimeLine.qml
    ------------
    Barra de progreso tipo "pipeline" horizontal, estilo circulos solidos
    (done = relleno de acento + check contrastante, running = circulo mas
    grande con el numero de paso, pending = circulo claro con borde y numero).

    Uso:

        StepIndicator {
            width: parent.width
            sx: root.sx
            sy: root.sy
            model: [
                { title: "Tokens",   state: "done" },
                { title: "Embeds",   state: "done" },
                { title: "Atención", state: "running" },
                { title: "FFN",      state: "pending" },
                { title: "Norm",     state: "pending" },
                { title: "Softmax",  state: "pending" }
            ]
        }

    Estados soportados por cada item: "done", "running", "pending".
    Como "model" es solo una lista JS, puedes reasignarla en cualquier
    momento (Timer, backend, etc.) y el componente se redibuja solo.

    Convencion de escala: igual que el resto de tus componentes, "sx" es
    el factor principal (tamaños de circulo, fuente, borde, conector);
    "sy" solo se usa para el spacing vertical interno y el alto del
    contenedor.
*/

Item {
    id: root

    // ---- API pública ----
    property var model: []

    // Colores - "done"
    property color doneColor: Style.Theme.acento
    property color doneCheckColor: Style.Theme.texto_sobre_color
    property color doneLabelColor: Style.Theme.chip_texto

    // Colores - "running" (paso activo: circulo mas grande y oscuro)
    property color runningColor: Style.Theme.acento_fuerte
    property color runningCheckColor: Style.Theme.texto_sobre_color
    property color runningLabelColor: Style.Theme.acento_fuerte

    // Colores - "pending"
    property color pendingBg: Style.Theme.acento_fondo
    property color pendingBorder: Style.Theme.acento_alt
    property color pendingCheckColor: Style.Theme.acento_alt
    property color pendingLabelColor: Style.Theme.texto_secundario

    // Conectores
    property color connectorDoneColor: Style.Theme.acento
    property color connectorPendingColor: Style.Theme.acento_fondo

    // ---- Escala ----
    property real sx: 1
    property real sy: 1

    // Tamaños base (a sx = 1)
    property real baseCircleSize: 34
    property real baseCircleSizeActive: 40   // circulo del paso "running"
    property real baseFontSize: 12
    property real baseFontSizeActive: 13
    property real baseIconSize: 14
    property real baseIconSizeActive: 16
    property real minimumCircleSize: 24
    property real minimumCircleSizeActive: 28
    property real minimumFontSize: 11
    property real minimumFontSizeActive: 12
    property real minimumIconSize: 12
    property real minimumIconSizeActive: 13
    property real baseHorizontalPadding: 10
    property real baseVerticalPadding: 6
    property real baseColumnSpacing: 6

    readonly property real circleSize: Math.max(minimumCircleSize, baseCircleSize * sx)
    readonly property real circleSizeActive: Math.max(minimumCircleSizeActive,
                                                       baseCircleSizeActive * sx)
    readonly property real fontSize: Math.max(minimumFontSize, baseFontSize * sx)
    readonly property real fontSizeActive: Math.max(minimumFontSizeActive,
                                                     baseFontSizeActive * sx)
    readonly property real iconSize: Math.max(minimumIconSize, baseIconSize * sx)
    readonly property real iconSizeActive: Math.max(minimumIconSizeActive,
                                                     baseIconSizeActive * sx)
    readonly property real horizontalPadding: baseHorizontalPadding * sx
    readonly property real verticalPadding: baseVerticalPadding * sy
    readonly property real columnSpacing: baseColumnSpacing * sy

    // Tamaño natural calculado del contenido real (no un numero fijo),
    // asi si cambias baseCircleSizeActive/baseFontSize, este valor se
    // actualiza solo y cualquier contenedor que dimensione en base a el
    // (ej. Math.max(altoFijo, indicador.implicitHeight)) mide correcto.
    implicitWidth: Math.max(1, stepRepeater.count) * 140 * sx
                   + horizontalPadding * 2
    implicitHeight: circleSizeActive + columnSpacing + (fontSizeActive * 1.4)
                    + verticalPadding * 2

    Item {
        id: content
        anchors.fill: parent
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        anchors.topMargin: root.verticalPadding
        anchors.bottomMargin: root.verticalPadding

        readonly property real stepWidth: width / Math.max(1, stepRepeater.count)

        Repeater {
            model: root.model

            delegate: Rectangle {
                required property int index
                required property var modelData

                visible: index < stepRepeater.count - 1
                x: (index + 0.5) * content.stepWidth
                y: root.circleSizeActive / 2 - height / 2
                width: content.stepWidth
                height: Math.max(1, 2 * root.sx)
                color: modelData.state === "done"
                       ? root.connectorDoneColor : root.connectorPendingColor

                Behavior on color { ColorAnimation { duration: 250 } }
            }
        }

        Repeater {
            id: stepRepeater
            model: root.model

            delegate: Item {
                id: stepDelegate

                required property int index
                required property var modelData

                readonly property var stepData: modelData
                readonly property bool isDone: stepData.state === "done"
                readonly property bool isRunning: stepData.state === "running"
                readonly property bool isPending: stepData.state === "pending"
                readonly property real thisCircleSize: isRunning ? root.circleSizeActive : root.circleSize

                x: index * content.stepWidth
                width: content.stepWidth
                height: content.height

                Item {
                    id: circleSlot
                    width: parent.width
                    height: root.circleSizeActive

                    Rectangle {
                        id: circle
                        width: stepDelegate.thisCircleSize
                        height: stepDelegate.thisCircleSize
                        radius: width / 2
                        anchors.centerIn: parent
                        color: stepDelegate.isDone ? root.doneColor
                               : stepDelegate.isRunning ? root.runningColor
                               : root.pendingBg
                        border.width: stepDelegate.isPending ? Math.max(1, 1 * root.sx) : 0
                        border.color: root.pendingBorder

                        Behavior on width { NumberAnimation { duration: 200 } }
                        Behavior on height { NumberAnimation { duration: 200 } }
                        Behavior on color { ColorAnimation { duration: 250 } }

                        Text {
                            anchors.centerIn: parent
                            text: stepDelegate.isDone ? "\u2713" : String(stepDelegate.index + 1)
                            font.bold: !stepDelegate.isPending
                            font.pixelSize: stepDelegate.isRunning ? root.iconSizeActive : root.iconSize
                            color: stepDelegate.isDone ? root.doneCheckColor
                                   : stepDelegate.isRunning ? root.runningCheckColor
                                   : root.pendingCheckColor
                        }
                    }
                }

                Text {
                    anchors.top: circleSlot.bottom
                    anchors.topMargin: root.columnSpacing
                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: stepDelegate.stepData.title
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    font.pixelSize: stepDelegate.isRunning ? root.fontSizeActive : root.fontSize
                    font.bold: stepDelegate.isRunning
                    color: stepDelegate.isDone ? root.doneLabelColor
                           : stepDelegate.isRunning ? root.runningLabelColor
                           : root.pendingLabelColor
                }
            }
        }
    }
}
