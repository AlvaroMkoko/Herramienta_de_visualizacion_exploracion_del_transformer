import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"
import Vispy 1.0
import QtQuick.Layouts
import QtQuick.Dialogs


PagePrincipal{
    id: root 
    ListModel {
        id: datasetModel
    }
    
    ListModel {
        id: markModel
    }

    Component.onCompleted: {
        var datasets = mainViewModel.datasetController.obtenerDatasets()

        datasetModel.clear()

        for (var i = 0; i < datasets.length; ++i) {
            datasetModel.append(datasets[i])
        }
    }

    FileDialog {
        id: datasetDialog

        title: "Selecciona un dataset"

        nameFilters: [
            "JSONL (*.jsonl)",
            "JSON (*.json)",
            "Todos los archivos (*)"
        ]

        onAccepted: {

            // var ruta = selectedFile.toString()

            // // Quita el prefijo file://
            // ruta = ruta.replace("file:///", "")

            // var dataset = datasetController.agregarDataset(ruta)

            // datasetModel.append(dataset)
            console.log(mainViewModel.datasetController)
            console.log(typeof mainViewModel.datasetController.agregarDataset)

            
                console.log("holaaaa")
                var ruta = selectedFile.toString()
                ruta = ruta.replace("file:///", "")
                console.log(ruta)
                var dataset = mainViewModel.datasetController.agregarDataset(ruta)

                var existe = false
                // print("Abriendo:", ruta)
                for (var i = 0; i < datasetModel.count; ++i) {

                    if (datasetModel.get(i).id === dataset.id) {
                        existe = true
                        break
                    }
                }

                if (!existe)
                    datasetModel.append(dataset)
            
        }
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
                    // datasetModel.append({})
                        // agregarDataset()
                    onClicked: {
                        datasetDialog.open()
                    }

                    
                }

                
            }
        }
    }


    Rectangle{
        anchors.bottom: rec1.top
        anchors.left: rec1.left
        anchors.bottomMargin: 10
        color:"blue"
        width: 1200*sx
        height: 60 * sy

        ScrollView {
            anchors.fill: parent

            ScrollBar.horizontal.policy: ScrollBar.AsNeeded
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            Row {
                spacing: 10

                Repeater {
                    model: markModel

                    delegate: RectanglePrincipal {
                        width: 200
                        height: 50
                    }
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
    anchors.margins: 12 * sx
    spacing: 8 * sy

    //===========================
    // Primera fila
    //===========================

    RowLayout {
        Layout.fillWidth: true
        spacing: 15 * sx

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

        ColumnLayout {

            Layout.fillWidth: true

            Text {
                text: nombre
                font.pixelSize: 18 * sy
                font.bold: true
                color: "#222222"
            }

            Text {
                text: id
                font.pixelSize: 12 * sy
                color: "#777777"
            }
        }

        BotonPrincipal {
            Layout.preferredWidth: 120 * sx
            Layout.preferredHeight: 35 * sy
            text: "Ver datos"
        }
    }

    //===========================
    // Segunda fila
    //===========================

    RowLayout {

        Layout.fillWidth: true
        spacing: 20 * sx

        Text {
            text: "Registros: " + registros
            font.pixelSize: 13 * sy
        }

        Text {
            text: "Tokens: " + tokens
            font.pixelSize: 13 * sy
        }

        Text {
            text: "Vocabulario: " + vocabulario
            font.pixelSize: 13 * sy
        }

        Text {
            text: "Tamaño: " + tamano_mb + " MB"
            font.pixelSize: 13 * sy
        }
    }

    //===========================
    // Tercera fila
    //===========================

    RowLayout {

        Layout.fillWidth: true
        spacing: 20 * sx

        Text {
            text: "Formato: " + formato
            font.pixelSize: 13 * sy
        }

        Text {
            text: "Estado: " + estado
            color: "#4CAF50"
            font.bold: true
            font.pixelSize: 13 * sy
        }

        Text {
            text: "Categorías: " + Object.keys(categorias).length
            font.pixelSize: 13 * sy
        }

        Text {
            text: "Campos: " + campos_texto
            elide: Text.ElideRight
            Layout.fillWidth: true
            font.pixelSize: 13 * sy
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
                    BotonPrincipal {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 250*sx
                        Layout.preferredHeight: 40 * sy
                        text: "Usar selección ->"
                        onClicked: {
                            datasetModel.append({})
                                // agregarDataset()
                        }   
                    }
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
