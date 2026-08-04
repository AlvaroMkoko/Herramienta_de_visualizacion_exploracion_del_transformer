import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"
import Vispy 1.0
import QtQuick.Layouts
import QtQuick.Dialogs


PagePrincipal{
    id: root

    property var idsSeleccionados: []
    property string mensajeError: ""
    property string mensajeExito: ""

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

        mainViewModel.errorDataset.connect(function(mensaje) {
            root.mensajeError = mensaje
            root.mensajeExito = ""
        })
        mainViewModel.datasetListoParaEntrenar.connect(function(cantidadPares) {
            root.mensajeError = ""
            root.mensajeExito = cantidadPares + " pares combinados listos para entrenar."
            stackView.pop()
        })
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
            var ruta = selectedFile.toString()
            ruta = ruta.replace("file:///", "")
            var dataset = mainViewModel.datasetController.agregarDataset(ruta)

            var existe = false
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
                text: " ↶ Volver"
                onClicked: {
                    stackView.pop()
                }
                
    }

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
                    datasetDialog.open()
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

            onCheckedChanged: {
                if (checked) {
                    if (root.idsSeleccionados.indexOf(id) === -1) {
                        root.idsSeleccionados = root.idsSeleccionados.concat([id])
                    }
                } else {
                    root.idsSeleccionados = root.idsSeleccionados.filter(function(x) {
                        return x !== id
                    })
                }
            }
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
        color:"blue"
        
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
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
                sx: root.sx
                sy: root.sy
                ColumnLayout{
                    anchors.fill: parent
                    anchors.margins: 10 * sx
                    spacing: 10 * sy

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.idsSeleccionados.length + " dataset(s) seleccionado(s)"
                        color: "white"
                        font.pixelSize: 14 * sx
                    }

                    BotonPrincipal {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 250*sx
                        Layout.preferredHeight: 40 * sy
                        text: "Usar selección ->"
                        enabled: root.idsSeleccionados.length > 0
                        onClicked: {
                            root.mensajeError = ""
                            mainViewModel.cargarDatasetsParaEntrenar(root.idsSeleccionados)
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: root.mensajeError !== ""
                        text: root.mensajeError
                        color: "red"
                        wrapMode: Text.WordWrap
                        Layout.preferredWidth: parent.width
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
                
            }


        RectanglePrincipal {
            id: rectangulo_blanco_2
            width: parent.width
            height:300 * sy
            sx: root.sx
            sy: root.sy
            ColumnLayout{
                anchors.fill: parent
                anchors.margins: 10 * sx
                spacing: 1 * sy 
                }   
            }
        }
    }
            
}