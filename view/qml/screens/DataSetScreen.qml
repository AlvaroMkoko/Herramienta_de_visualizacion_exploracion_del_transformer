import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"
import Vispy 1.0
import QtQuick.Layouts


PagePrincipal{
    id: root 
    ListModel {
        id: datasetModel
    }
    BotonPrincipal {
                anchors.left: parent.left
                anchors.leftMargin: 10 * sx
                anchors.top: parent.top
                anchors.topMargin: 10 * sy
                width: 250 * sx
                height: 40 * sy
                text: " ↶ Volver al inicio"
                onClicked: {
                    stackView.pop()
                }
                
    }

    //TODO El Component.onCompleted se usa cuando quieres hacer algo justo cuando se abrio la ventana 
    //TODO Para cargar los datos que cambian se usa el formato JSCON para que facilmente ponames acceder a los datos
    
    // Component.onCompleted: { 
    //     cargarDatasets()
    // }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right

        width: 700 * sx
        height: 60 * sy
        color: "blue"

        RowLayout{
            anchors.fill: parent
            anchors.margins:15 * sx
            spacing: 10* sy

            Text{
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.RichText
                text: "<font color='#7d7a7a'>Selecciona uno o más: </font><font color='#6A63E8'> Data Sets</font>"
                font.bold: true
                font.pixelSize: 18 * sy
            }

            BotonPrincipal {
                
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 250*sx
                Layout.preferredHeight: 40 * sy
                text: "+ Agregar DataSet"
                onClicked: {
                    datasetModel.append({})
                        // agregarDataset()

                    
                }

                
            }
        }
    }

    Rectangle {
            id: rec1
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 10

            property real size_width: 1200
            property real size_height: 900

            property real size_rec1: 120
            

            width: size_width * sx
            height: size_height * sy

            color: "blue"

           ScrollView {
    anchors.fill: parent
    anchors.margins: 10 * sx
    clip: true

    Column {
        id: listaDatasets

        width: rec1.width - 20 * sx
        spacing: 10 * sy

        Repeater {
            model: datasetModel

            delegate: RectanglePrincipal {
                sx: root.sx
                sy: root.sy

                width: listaDatasets.width
                height: 120 * sy

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10 * sx
                    spacing: 10 * sy

                    // ---------------- Primera fila ----------------

                    RowLayout {
                        width: parent.width
                        spacing: 20 * sx
                        CheckBox {
                            id: check

                            indicator: Rectangle {
                                implicitWidth: 20 * sx
                                implicitHeight: 20 * sy
                                radius: 5

                                color: check.checked ? "#6A63E8" : "white"
                                border.width: 1.5
                                border.color: "#6A63E8"

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    visible: check.checked
                                    color: "white"
                                    font.pixelSize: 13 * sy
                                    font.bold: true
                                }
                            }

                            contentItem: Item { }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20 * sy
                            radius: 4
                            color: "#DDDDDD"
                        }

                        BotonPrincipal {
                            Layout.preferredWidth: 120 * sx
                            Layout.preferredHeight: 35 * sy
                            text: "Ver Datos"
                        }
                    }

                    // ---------------- Segunda fila ----------------

                    RowLayout {
                        width: parent.width
                        spacing: 10 * sx

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20 * sy
                            radius: 4
                            color: "#EEEEEE"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20 * sy
                            radius: 4
                            color: "#EEEEEE"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20 * sy
                            radius: 4
                            color: "#EEEEEE"
                        }
                    }
                }
            }
        }
    }
}
            
            }


            Rectangle{
        
        property real size_width: 300
        property real size_height:700
        width:size_width * sx
        height:size_height * sy
        // color: "transparent"
        color:"blue"
        // clip: true          

        
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter   // opcional, si querés centrado vertical
        anchors.rightMargin: 30

        Column{
            anchors.centerIn: parent
            width: parent.size_width * sx

            spacing: 60 * sy


            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -50 * sy
            RectanglePrincipal {
                
                id: rectangulo_blanco_1
                width: parent.width
                height:400 * sy
                // anchors.verticalCenterOffset: -500 * sy

                sx: root.sx
                sy: root.sy

                ColumnLayout{
                    // spacing: 10
                    // width: parent.width-30
                    // anchors.margins: 15 * sx
                    anchors.fill: parent
                    anchors.margins: 10 * sx

                    spacing: 1 * sy 

                     

                }
                
            }


            RectanglePrincipal {
                
                id: rectangulo_blanco_2
                width: parent.width
                height:300 * sy
                // anchors.verticalCenterOffset: -500 * sy

                sx: root.sx
                sy: root.sy

                ColumnLayout{
                    // spacing: 10
                    // width: parent.width-30
                    // anchors.margins: 15 * sx
                    anchors.fill: parent
                    anchors.margins: 10 * sx

                    spacing: 1 * sy 

                     

                }
                
            }


            }
        }
            
}
