import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"
import Vispy 1.0
import QtQuick.Layouts
import QtQuick.Dialogs


PagePrincipal{
    id: root 

    property alias datasetModel: datasetModel
    property alias markModel: markModel


    VerDatos {
    id: verDatos
}

    ListModel {
        id: datasetModel
    }
    
    ListModel {
        id: markModel
    }

    function indexOfDataset(datasetId) {
        for (let i = 0; i < datasetModel.count; ++i) {
            if (datasetModel.get(i).id === datasetId)
                return i
        }
        return -1
    }

    function indexOfMark(datasetId) {
        for (let i = 0; i < markModel.count; ++i) {
            if (markModel.get(i).datasetId === datasetId)
                return i
        }
        return -1
    }

    function eliminarDatasetCompleto(datasetId) {
        // 1. Elimina en el backend
        mainViewModel.datasetController.eliminarDataset(datasetId)

        // 2. Si estaba seleccionado, lo saca del markModel (chip de arriba)
        let markIdx = indexOfMark(datasetId)
        if (markIdx !== -1)
            markModel.remove(markIdx)

        // 3. Lo saca de la lista principal
        let dsIdx = indexOfDataset(datasetId)
        if (dsIdx !== -1)
            datasetModel.remove(dsIdx)
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
                var ruta = selectedFile.toString()
                ruta = ruta.replace("file:///", "")
                console.log(ruta)
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
                        id:rec_padre
                        // property int rowIndex: index
                        // property int dsIndex: datasetIndex
                        property string dsId: datasetId   // ahora sí existe este rol

                        width: 200
                        height: 50
                        color:"white"


                        RowLayout{
                            Layout.fillWidth: true
                            spacing: 20 * sx

                            Text{
                                text: datasetId    
                                color: "black"
                                font.pixelSize: 8 * sy
                                font.bold: true
                            }

                            BotonPrincipal {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 40 * sx
                                Layout.preferredHeight: 40 * sy
                                text: "X"
                                property var mkModel: root.markModel
                                property var dsModel: root.datasetModel

                                onClicked: {
                                    // datasetModel.append({})
                                        // agregarDataset()
                                    // dsModel.setProperty(rec_padre.dsIndex, "selected", false)
                                    // mkModel.remove(rec_padre.rowIndex)    
                                    let dsIdx = root.indexOfDataset(rec_padre.dsId)
                                    if (dsIdx !== -1)
                                        root.datasetModel.setProperty(dsIdx, "selected", false)
                                }   
                            }
                        }
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


                        property var dsModel: root.datasetModel
                        property var mkModel: root.markModel
                        property int rowIndex: index

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
                                    checked: selected
                                    
                                    onCheckedChanged: {
                                        dsModel.setProperty(rowIndex, "selected", checked)

                                        if (checked) {
                                            mkModel.append({
                                                datasetId: id,   // <- unificado
                                                ruta: ruta
                                            })
                                        } else {
                                            let i = root.indexOfMark(id)
                                            if (i !== -1)
                                                mkModel.remove(i)
                                        }
                                    }


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

                                    onClicked: {
                                        var registros = mainViewModel.datasetController.obtenerRegistros(id, 50)
                                        verDatos.mostrar(nombre, registros)
                                    }
                                }
                                BotonPrincipal {
                                    Layout.preferredWidth: 120 * sx
                                    Layout.preferredHeight: 35 * sy
                                    text: "Eliminar DataSet"

                                    onClicked: {
                                        root.eliminarDatasetCompleto(id)
                                    }
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
                            // datasetModel.append({})
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

