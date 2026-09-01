pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: popup

    property var registros: []
    property string datasetNombre: ""

    readonly property real viewportWidth: Overlay.overlay
                                                   ? Overlay.overlay.width
                                                   : (parent ? parent.width : 960)
    readonly property real viewportHeight: Overlay.overlay
                                                    ? Overlay.overlay.height
                                                    : (parent ? parent.height : 720)
    readonly property real edgeMargin: viewportWidth < 640 || viewportHeight < 600
                                               ? 12 : 24
    readonly property real contentMargin: width < 520 ? 14 : 24

    function mostrar(nombre, listaRegistros) {
        datasetNombre = nombre === undefined || nombre === null
                ? "" : String(nombre)
        registros = listaRegistros || []
        open()

        Qt.callLater(function() {
            listView.positionViewAtBeginning()
        })
    }

    parent: Overlay.overlay
    anchors.centerIn: Overlay.overlay
    width: Math.max(1, Math.min(960, viewportWidth - edgeMargin * 2))
    height: Math.max(1, Math.min(720, viewportHeight - edgeMargin * 2))
    padding: 0
    modal: true
    dim: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    Overlay.modal: Rectangle {
        color: "#990F172A"
    }

    background: Rectangle {
        color: "#FFFFFF"
        radius: 16
        border.width: 1
        border.color: "#D9DEE8"
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: popup.contentMargin
        spacing: popup.width < 520 ? 12 : 16

        Accessible.name: "Vista previa del dataset " + popup.datasetNombre

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Label {
                    Layout.fillWidth: true
                    text: "Vista previa de datos"
                    color: "#111827"
                    font.bold: true
                    font.pixelSize: popup.width < 520 ? 19 : 23
                    wrapMode: Text.Wrap
                }

                Label {
                    Layout.fillWidth: true
                    text: popup.datasetNombre !== ""
                          ? popup.datasetNombre : "Dataset sin nombre"
                    color: "#4B5563"
                    font.pixelSize: popup.width < 520 ? 13 : 15
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }
            }

            ToolButton {
                id: closeButton

                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                focusPolicy: Qt.StrongFocus
                hoverEnabled: true
                text: "×"

                Accessible.name: "Cerrar vista previa de datos"
                Accessible.description: "Cierra este diálogo y vuelve a la pantalla anterior"

                ToolTip.delay: 400
                ToolTip.visible: hovered
                ToolTip.text: "Cerrar (Esc)"

                background: Rectangle {
                    color: closeButton.down
                           ? "#E5E7EB"
                           : (closeButton.hovered || closeButton.activeFocus
                              ? "#F3F4F6" : "transparent")
                    radius: 9
                    border.width: closeButton.activeFocus ? 2 : 0
                    border.color: "#6A63E8"
                }

                contentItem: Text {
                    text: closeButton.text
                    color: "#374151"
                    font.pixelSize: 26
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: popup.close()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#E5E7EB"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: recordCount.implicitWidth + 20
                Layout.preferredHeight: 30
                color: "#F0EEFF"
                radius: 15

                Label {
                    id: recordCount
                    anchors.centerIn: parent
                    text: popup.registros.length + " registros mostrados"
                    color: "#514BC2"
                    font.bold: true
                    font.pixelSize: 12
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Label {
                visible: popup.width >= 560
                text: "Desplázate para explorar los registros"
                color: "#6B7280"
                font.pixelSize: 12
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#F8FAFC"
            radius: 11
            border.width: 1
            border.color: "#E1E6EF"
            clip: true

            ScrollView {
                id: recordsScroll

                anchors.fill: parent
                anchors.margins: 1
                clip: true
                contentWidth: availableWidth

                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ListView {
                    id: listView

                    width: recordsScroll.availableWidth
                    height: recordsScroll.availableHeight
                    model: popup.registros
                    spacing: 8
                    clip: true
                    reuseItems: true
                    boundsBehavior: Flickable.StopAtBounds
                    activeFocusOnTab: true

                    Accessible.name: "Registros de " + popup.datasetNombre

                    header: Item {
                        width: 1
                        height: 8
                    }

                    footer: Item {
                        width: 1
                        height: 8
                    }

                    delegate: Rectangle {
                        id: recordDelegate

                        required property int index
                        required property var modelData

                        width: Math.max(0, listView.width - 16)
                        height: Math.max(54, contenido.implicitHeight + 24)
                        x: 8
                        color: recordDelegate.index % 2 === 0
                               ? "#FFFFFF" : "#F3F5F9"
                        radius: 8
                        border.width: 1
                        border.color: "#E2E7F0"

                        Text {
                            id: contenido

                            anchors.fill: parent
                            anchors.margins: 12
                            text: {
                                try {
                                    var serialized = JSON.stringify(
                                                recordDelegate.modelData, null, 2)
                                    return serialized === undefined
                                            ? String(recordDelegate.modelData)
                                            : serialized
                                } catch (error) {
                                    return String(recordDelegate.modelData)
                                }
                            }
                            textFormat: Text.PlainText
                            color: "#273142"
                            wrapMode: Text.Wrap
                            font.family: Qt.platform.os === "windows"
                                         ? "Consolas" : "monospace"
                            font.pixelSize: 12
                        }
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: listView.count === 0
                text: "No hay registros para mostrar."
                color: "#6B7280"
                font.pixelSize: 14
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Label {
                Layout.fillWidth: true
                visible: popup.width >= 420
                text: "También puedes presionar Esc para cerrar"
                color: "#6B7280"
                font.pixelSize: 12
            }

            BotonPrincipal {
                Layout.alignment: Qt.AlignRight
                Layout.preferredWidth: 124
                Layout.preferredHeight: 40
                text: "Cerrar"
                Accessible.name: "Cerrar vista previa de datos"
                onClicked: popup.close()
            }
        }
    }

    onOpened: closeButton.forceActiveFocus()
}
