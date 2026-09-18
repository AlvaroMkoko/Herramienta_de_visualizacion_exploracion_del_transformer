import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root

    BotonPrincipal {
        anchors.left: parent.left
        anchors.leftMargin: 10 * root.sx
        anchors.top: parent.top
        anchors.topMargin: 10 * root.sy
        width: 250 * root.sx
        height: 40 * root.sy
        text: "↶ Volver al inicio"
        onClicked: root.stackView.pop()
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 105 * root.sy
        width: Math.min(760 * root.sx, parent.width - 80 * root.sx)
        spacing: 18 * root.sy

        Text {
            Layout.fillWidth: true
            text: "Guardar modelo"
            color: Style.Theme.texto_primario
            font.pixelSize: 32 * Math.min(root.sx, root.sy)
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.fillWidth: true
            text: "El guardado ahora forma parte del resumen de entrenamiento. Allí puedes elegir el formato adecuado sin perder el contexto de tus resultados."
            color: Style.Theme.texto_secundario
            font.pixelSize: 15 * Math.min(root.sx, root.sy)
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        RectanglePrincipal {
            Layout.fillWidth: true
            Layout.preferredHeight: 300 * root.sy
            sx: root.sx
            sy: root.sy

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 28 * root.sx
                spacing: 16 * root.sy

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 64 * root.sx
                    Layout.preferredHeight: 64 * root.sy
                    radius: 18 * root.sx
                    color: Style.Theme.acento_fondo

                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        color: Style.Theme.acento_fuerte
                        font.pixelSize: 30 * Math.min(root.sx, root.sy)
                        font.bold: true
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Todo listo para guardar"
                    color: Style.Theme.texto_primario
                    font.pixelSize: 21 * Math.min(root.sx, root.sy)
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: "Modelo portable para inferencia o checkpoint para continuar entrenando. Ambas opciones están disponibles en la pantalla de resultados."
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 14 * Math.min(root.sx, root.sy)
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Item { Layout.fillHeight: true }

                BotonPrincipal {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48 * root.sy
                    text: "Volver al resumen de entrenamiento"
                    onClicked: root.stackView.pop()
                }
            }
        }
    }
}
