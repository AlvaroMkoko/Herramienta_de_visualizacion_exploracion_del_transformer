import QtQuick
import QtQuick.Layouts

/*
    StepIndicator.qml
    ------------------
    Barra de progreso tipo "pipeline" horizontal, estilo circulos solidos
    (done = relleno morado + check blanco, running = circulo mas grande y
    oscuro + texto en negrita, pending = circulo claro con borde y check
    desvanecido).

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
    property color doneColor: "#6c4cf5"
    property color doneCheckColor: "white"
    property color doneLabelColor: "#555555"

    // Colores - "running" (paso activo: circulo mas grande y oscuro)
    property color runningColor: "#4b2fc9"
    property color runningCheckColor: "white"
    property color runningLabelColor: "#4b2fc9"

    // Colores - "pending"
    property color pendingBg: "#e6e1fb"
    property color pendingBorder: "#c3b9f7"
    property color pendingCheckColor: "#b6a8ef"
    property color pendingLabelColor: "#999999"

    // Conectores
    property color connectorDoneColor: "#6c4cf5"
    property color connectorPendingColor: "#d8d3f5"

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
    property real baseConnectorMinWidth: 20
    property real baseHorizontalPadding: 10
    property real baseColumnSpacing: 6

    readonly property real circleSize: baseCircleSize * sx
    readonly property real circleSizeActive: baseCircleSizeActive * sx
    readonly property real fontSize: baseFontSize * sx
    readonly property real fontSizeActive: baseFontSizeActive * sx
    readonly property real iconSize: baseIconSize * sx
    readonly property real iconSizeActive: baseIconSizeActive * sx
    readonly property real connectorMinWidth: baseConnectorMinWidth * sx
    readonly property real horizontalPadding: baseHorizontalPadding * sx
    readonly property real columnSpacing: baseColumnSpacing * sy

    // Tamaño natural calculado del contenido real (no un numero fijo),
    // asi si cambias baseCircleSizeActive/baseFontSize, este valor se
    // actualiza solo y cualquier contenedor que dimensione en base a el
    // (ej. Math.max(altoFijo, indicador.implicitHeight)) mide correcto.
    implicitWidth: rowLayout.implicitWidth + horizontalPadding * 2
    implicitHeight: circleSizeActive + columnSpacing + (fontSizeActive * 1.4) + (12 * sy)

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.margins: root.horizontalPadding
        spacing: 0

        Repeater {
            id: repeater
            model: root.model

            delegate: RowLayout {
                id: stepDelegate
                spacing: 0
                Layout.fillWidth: index < repeater.count - 1

                readonly property var stepData: modelData
                readonly property bool isDone: stepData.state === "done"
                readonly property bool isRunning: stepData.state === "running"
                readonly property bool isPending: stepData.state === "pending"
                readonly property real thisCircleSize: isRunning ? root.circleSizeActive : root.circleSize

                // --- circulo + etiqueta ---
                Column {
                    spacing: root.columnSpacing
                    Layout.alignment: Qt.AlignTop

                    Rectangle {
                        id: circle
                        width: stepDelegate.thisCircleSize
                        height: stepDelegate.thisCircleSize
                        radius: width / 2
                        anchors.horizontalCenter: parent.horizontalCenter
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
                            text: "\u2713"
                            font.bold: !stepDelegate.isPending
                            font.pixelSize: stepDelegate.isRunning ? root.iconSizeActive : root.iconSize
                            color: stepDelegate.isDone ? root.doneCheckColor
                                   : stepDelegate.isRunning ? root.runningCheckColor
                                   : root.pendingCheckColor
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: stepDelegate.stepData.title
                        font.pixelSize: stepDelegate.isRunning ? root.fontSizeActive : root.fontSize
                        font.bold: stepDelegate.isRunning
                        color: stepDelegate.isDone ? root.doneLabelColor
                               : stepDelegate.isRunning ? root.runningLabelColor
                               : root.pendingLabelColor
                    }
                }

                // --- conector entre circulos (no despues del ultimo) ---
                Item {
                    visible: index < repeater.count - 1
                    Layout.fillWidth: true
                    Layout.minimumWidth: root.connectorMinWidth
                    Layout.preferredHeight: Math.max(1, 2 * root.sx)
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: root.circleSize / 2 - (1 * root.sx)

                    Rectangle {
                        anchors.fill: parent
                        color: stepDelegate.isDone ? root.connectorDoneColor : root.connectorPendingColor
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }
                }
            }
        }
    }
}
