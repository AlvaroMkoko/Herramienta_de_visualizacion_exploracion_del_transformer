import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"
import Vispy 1.0
import QtQuick.Layouts
import QtQuick.Dialogs



PagePrincipal{
    id:root 
    
    
    
    
    
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



    Rectangle{
        property real size_width: 1460
        property real size_height:1000
        id:rec_padre
        color: "blue"
        width: size_width * sx
        height: size_height * sy
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        // Acomodar el ractangulo 

        ColumnLayout{
            anchors.fill: parent
            anchors.margins:15 * sx
            spacing: 10* sy
            RectanglePrincipal{
                 sx: root.sx
                sy: root.sy
                Layout.preferredWidth: (rec_padre.size_width - 20 ) * sx
                Layout.preferredHeight: 250 * sy
                anchors.margins: 10 * sx
                Layout.alignment: Qt.AlignHCenter

            }
            RectanglePrincipal{
                 sx: root.sx
                sy: root.sy
                Layout.preferredWidth: (rec_padre.size_width - 20 ) * sx
                Layout.preferredHeight: 250 * sy
                anchors.margins: 10 * sx
                Layout.alignment: Qt.AlignHCenter

            }
            BotonPrincipal {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: (rec_padre.size_width - 20 ) * sx
                Layout.preferredHeight: 60 * sy
                text: " Confirmar y Guardar"
                
                onClicked: {
                    // datasetModel.append({})
                        // agregarDataset()
                    // dsModel.setProperty(rec_padre.dsIndex, "selected", false)
                    // mkModel.remove(rec_padre.rowIndex)    
                    // let dsIdx = root.indexOfDataset(rec_padre.dsId)
                    // if (dsIdx !== -1)
                    //     root.datasetModel.setProperty(dsIdx, "selected", false)
                }   
            }
            RectanglePrincipal{
                 sx: root.sx
                sy: root.sy
                Layout.preferredWidth: (rec_padre.size_width - 20 ) * sx
                Layout.preferredHeight: 250 * sy
                anchors.margins: 10 * sx
                Layout.alignment: Qt.AlignHCenter

            }
        }
    }


    Rectangle{

        id:rec_padre_2
        property real size_width: 400
        property real size_height:1000
        color: "blue"
        width: size_width * sx
        height: size_height * sy
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        // Acomodar el ractangulo 

        ColumnLayout{
            anchors.fill: parent
            anchors.margins:15 * sx
            spacing: 10* sy

            RectanglePrincipal{
                 sx: root.sx
                sy: root.sy
                Layout.preferredWidth: (rec_padre_2.size_width - 20 ) * sx
                Layout.preferredHeight: 400 * sy
                anchors.margins: 10 * sx
                Layout.alignment: Qt.AlignHCenter

            }

             RectanglePrincipal{
                 sx: root.sx
                sy: root.sy
                Layout.preferredWidth: (rec_padre_2.size_width - 20 ) * sx
                Layout.preferredHeight: 400 * sy
                anchors.margins: 10 * sx
                Layout.alignment: Qt.AlignHCenter

            }


        }

    }
}