import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root
    objectName: "modulePlaceholderScreen"

    property int stageNumber: 0
    property string moduleTitle: "Módulo"
    property string moduleDescription: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 18

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Button {
                id: backButton
                objectName: "modulePlaceholderBackButton"
                Layout.preferredWidth: 118
                Layout.preferredHeight: 42
                text: "← Inicio"
                focusPolicy: Qt.StrongFocus
                Accessible.name: "Volver al inicio"
                onClicked: root.stackView.pop()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: "Paso " + root.stageNumber + " de 5"
                    color: Style.Theme.aviso_texto
                    font.pixelSize: 12
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: root.moduleTitle
                    color: Style.Theme.texto_primario
                    font.pixelSize: 28
                    font.bold: true
                    wrapMode: Text.WordWrap
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }
            }

            Rectangle {
                Layout.preferredWidth: 158
                Layout.preferredHeight: 32
                radius: height / 2
                color: "#FEF3C7"
                border.color: "#F59E0B"

                Text {
                    anchors.centerIn: parent
                    text: "MODO DE PRUEBA"
                    color: Style.Theme.aviso_texto
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 0.6
                }
            }
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(680, root.width - 64)
            Layout.preferredHeight: 360
            radius: 18
            color: Style.Theme.surface
            border.width: 1
            border.color: "#F3C56A"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 30
                spacing: 16

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 68
                    Layout.preferredHeight: 68
                    radius: 34
                    color: "#FEF3C7"

                    Text {
                        anchors.centerIn: parent
                        text: root.stageNumber
                        color: Style.Theme.aviso_texto
                        font.pixelSize: 27
                        font.bold: true
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Placeholder navegable"
                    color: Style.Theme.texto_primario
                    font.pixelSize: 22
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: root.moduleDescription
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 15
                    lineHeight: 1.2
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: testMessage.implicitHeight + 24
                    radius: 10
                    color: "#FFF7E6"
                    border.color: "#F6D48A"

                    Text {
                        id: testMessage
                        anchors.fill: parent
                        anchors.margins: 12
                        text: "El acceso está habilitado sin requisitos de progreso para probar el flujo. La lógica y el contenido definitivo de este módulo se implementarán después."
                        color: "#7C4A12"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Item { Layout.fillHeight: true }

                Button {
                    objectName: "modulePlaceholderReturnButton"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 210
                    Layout.preferredHeight: 42
                    text: "Volver al flujo formativo"
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: text
                    onClicked: root.stackView.pop()
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
