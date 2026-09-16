pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../styles" as Style

Rectangle {
    id: root
    objectName: "inferenceProcessMap"

    property var chapters: []
    property int currentIndex: 0
    property int currentStep: 1
    property int currentStepCount: 1
    property color accent: Style.Theme.acento
    property real sx: 1
    property real sy: 1
    readonly property bool keyboardNavigationEnabled: true

    signal chapterSelected(int index)

    radius: 12 * Math.min(sx, sy)
    color: Style.Theme.surface
    border.color: Style.Theme.borde_medio

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 12 * root.sx
        anchors.rightMargin: 12 * root.sx
        anchors.topMargin: 8 * root.sy
        anchors.bottomMargin: 8 * root.sy
        spacing: 5 * root.sy

        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * root.sx

            Text {
                text: "MAPA DEL PROCESO"
                color: Style.Theme.texto_secundario
                font.bold: true
                font.letterSpacing: 0.6
                font.pixelSize: Math.max(11, 11 * root.sx)
            }

            Text {
                Layout.fillWidth: true
                text: "Sigue una sola operaci\u00f3n; el mapa mantiene visible el recorrido completo."
                color: Style.Theme.texto_secundario
                elide: Text.ElideRight
                font.pixelSize: Math.max(11, 11 * root.sx)
            }

            Text {
                text: root.chapters.length
                      ? "Etapa " + (root.currentIndex + 1) + " de " + root.chapters.length
                        + "  ·  paso " + root.currentStep + " de " + root.currentStepCount
                      : ""
                color: root.accent
                font.bold: true
                font.pixelSize: Math.max(11, 11 * root.sx)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6 * root.sx

            EndpointChip {
                Layout.preferredWidth: Math.max(62, 82 * root.sx)
                Layout.fillHeight: true
                title: "Prompt"
                caption: "entrada"
                symbol: "T"
                sx: root.sx
            }

            Text {
                text: "\u2192"
                color: Style.Theme.texto_terciario
                font.bold: true
                font.pixelSize: Math.max(13, 15 * root.sx)
            }

            Repeater {
                model: root.chapters

                delegate: RowLayout {
                    id: chapterDelegate
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    // Todos los capitulos parten del mismo ancho base. Sin
                    // esto, RowLayout usa el ancho implicito del texto y la
                    // tarjeta corta de "Salida" puede quedar comprimida.
                    Layout.preferredWidth: 1
                    Layout.minimumWidth: 0
                    spacing: 6 * root.sx

                    readonly property bool current: index === root.currentIndex
                    readonly property bool completed: index < root.currentIndex

                    Rectangle {
                        id: chapterCard
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        activeFocusOnTab: true
                        radius: 9 * Math.min(root.sx, root.sy)
                        color: chapterDelegate.current
                               ? Qt.alpha(root.accent, 0.12)
                               : (chapterDelegate.completed ? Style.Theme.surface : Style.Theme.superficie_alterna)
                        border.color: chapterDelegate.current
                                      ? root.accent
                                      : (chapterDelegate.completed ? "#86EFAC" : Style.Theme.borde_suave)
                        border.width: activeFocus ? 3 : (chapterDelegate.current ? 2 : 1)

                        Accessible.role: Accessible.Button
                        Accessible.name: "Ir a la etapa " + (chapterDelegate.index + 1)
                                         + ": " + chapterDelegate.modelData.label
                        Accessible.description: chapterDelegate.modelData.caption || ""
                        Accessible.onPressAction: root.chapterSelected(chapterDelegate.index)

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Return
                                    || event.key === Qt.Key_Enter
                                    || event.key === Qt.Key_Space) {
                                root.chapterSelected(chapterDelegate.index)
                                event.accepted = true
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 7 * root.sx
                            spacing: 7 * root.sx

                            Rectangle {
                                Layout.preferredWidth: Math.max(24, 25 * root.sx)
                                Layout.preferredHeight: width
                                radius: width / 2
                                color: chapterDelegate.current
                                       ? root.accent
                                       : (chapterDelegate.completed ? Style.Theme.success : Style.Theme.borde_medio)

                                Text {
                                    anchors.centerIn: parent
                                    text: chapterDelegate.completed ? "\u2713" : chapterDelegate.index + 1
                                    color: chapterDelegate.current || chapterDelegate.completed
                                           ? "#FFFFFF" : Style.Theme.texto_secundario
                                    font.bold: true
                                    font.pixelSize: Math.max(11, 11 * root.sx)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: chapterDelegate.modelData.label || ""
                                    color: chapterDelegate.current ? root.accent : Style.Theme.texto_secundario_fuerte
                                    font.bold: true
                                    elide: Text.ElideRight
                                    font.pixelSize: Math.max(11, 11 * root.sx)
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: chapterDelegate.modelData.caption || ""
                                    color: Style.Theme.texto_secundario
                                    elide: Text.ElideRight
                                    font.pixelSize: Math.max(10, 10 * root.sx)
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                chapterCard.forceActiveFocus()
                                root.chapterSelected(chapterDelegate.index)
                            }
                        }
                    }

                    Text {
                        visible: chapterDelegate.index < root.chapters.length - 1
                        Layout.preferredWidth: visible ? Math.max(12, 14 * root.sx) : 0
                        text: "\u2192"
                        color: chapterDelegate.completed ? Style.Theme.success : Style.Theme.texto_terciario
                        font.bold: true
                        font.pixelSize: Math.max(12, 14 * root.sx)
                    }
                }
            }

            Text {
                text: "\u2192"
                color: root.currentIndex === root.chapters.length - 1 ? root.accent : Style.Theme.texto_terciario
                font.bold: true
                font.pixelSize: Math.max(13, 15 * root.sx)
            }

            EndpointChip {
                Layout.preferredWidth: Math.max(68, 92 * root.sx)
                Layout.fillHeight: true
                title: "Token"
                caption: "vuelve al decoder"
                symbol: "\u21ba"
                highlighted: root.currentIndex === root.chapters.length - 1
                accent: root.accent
                sx: root.sx
            }
        }
    }

    component EndpointChip: Rectangle {
        id: endpoint
        property string title: ""
        property string caption: ""
        property string symbol: ""
        property bool highlighted: false
        property color accent: Style.Theme.acento
        property real sx: 1

        radius: 9 * endpoint.sx
        color: highlighted ? Qt.alpha(accent, 0.12) : Style.Theme.superficie_alterna
        border.color: highlighted ? accent : Style.Theme.borde_suave

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 8 * endpoint.sx
            spacing: 0

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: endpoint.symbol + "  " + endpoint.title
                color: endpoint.highlighted ? endpoint.accent : Style.Theme.texto_secundario_fuerte
                font.bold: true
                font.pixelSize: Math.max(11, 11 * endpoint.sx)
            }
            Text {
                Layout.fillWidth: true
                text: endpoint.caption
                color: Style.Theme.texto_secundario
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.pixelSize: Math.max(10, 10 * endpoint.sx)
            }
        }
    }
}
