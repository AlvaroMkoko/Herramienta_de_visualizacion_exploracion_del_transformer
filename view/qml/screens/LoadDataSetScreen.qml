import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"
import Vispy 1.0
import QtQuick.Layouts
import QtQuick.Dialogs


PagePrincipal {
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
        mainViewModel.datasetController.eliminarDataset(datasetId)

        let markIdx = indexOfMark(datasetId)
        if (markIdx !== -1)
            markModel.remove(markIdx)

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

    RowLayout {
        id: cabecera
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 24 * root.sx
        height: 72 * root.sy
        spacing: 14 * root.sx

        BotonPrincipal {
            Layout.preferredWidth: 210 * root.sx
            Layout.preferredHeight: 44 * root.sy
            text: "\u21b6 Volver al inicio"
            size_text: 0.27
            onClicked: root.stackView.pop()
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2 * root.sy

            Text {
                text: "Biblioteca de datasets"
                color: Style.Theme.texto_primario
                font.bold: true
                font.pixelSize: 27 * Math.min(root.sx, root.sy)
            }

            Text {
                text: root.datasetModel.count
                      + (root.datasetModel.count === 1 ? " dataset disponible" : " datasets disponibles")
                color: Style.Theme.texto_secundario
                font.pixelSize: 14 * Math.min(root.sx, root.sy)
            }
        }

        BotonPrincipal {
            Layout.preferredWidth: 180 * root.sx
            Layout.preferredHeight: 44 * root.sy
            text: "+ Agregar dataset"
            size_text: 0.24
            onClicked: datasetDialog.open()
        }
    }

    ListView {
        id: listaDatasets
        anchors.top: cabecera.bottom
        anchors.topMargin: 14 * root.sy
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 30 * root.sx
        anchors.rightMargin: 30 * root.sx
        anchors.bottomMargin: 22 * root.sy
        spacing: 14 * root.sy
        clip: true
        model: datasetModel
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        delegate: RectanglePrincipal {
            id: tarjetaDataset
            property var dsModel: root.datasetModel
            property var mkModel: root.markModel
            property int rowIndex: index

            width: listaDatasets.width - 14 * root.sx
            height: 154 * root.sy
            sx: root.sx
            sy: root.sy

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16 * root.sx
                spacing: 7 * root.sy

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12 * root.sx

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2 * root.sy

                        Text {
                            Layout.fillWidth: true
                            text: nombre
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: 19 * Math.min(root.sx, root.sy)
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: id
                            color: Style.Theme.texto_secundario
                            font.pixelSize: 12 * Math.min(root.sx, root.sy)
                            elide: Text.ElideMiddle
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: etiquetaFormato.implicitWidth + 18 * root.sx
                        Layout.preferredHeight: 25 * root.sy
                        radius: height / 2
                        color: "#F3F4F6"
                        border.color: "#D1D5DB"

                        Text {
                            id: etiquetaFormato
                            anchors.centerIn: parent
                            text: String(formato).toUpperCase()
                            color: "#4B5563"
                            font.bold: true
                            font.pixelSize: 11 * Math.min(root.sx, root.sy)
                        }
                    }

                    BotonPrincipal {
                        Layout.preferredWidth: 120 * root.sx
                        Layout.preferredHeight: 36 * root.sy
                        text: "Ver datos"
                        size_text: 0.24
                        onClicked: {
                            var registrosDataset = mainViewModel.datasetController.obtenerRegistros(id, 50)
                            verDatos.mostrar(nombre, registrosDataset)
                        }
                    }

                    BotonPrincipal {
                        Layout.preferredWidth: 145 * root.sx
                        Layout.preferredHeight: 36 * root.sy
                        text: "Eliminar dataset"
                        size_text: 0.21
                        onClicked: root.eliminarDatasetCompleto(id)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: "#E5E7EB"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20 * root.sx

                    Text {
                        text: "Registros  " + registros
                        color: Style.Theme.texto_primario
                        font.pixelSize: 13 * Math.min(root.sx, root.sy)
                    }

                    Text {
                        text: "Tokens  " + tokens
                        color: Style.Theme.texto_primario
                        font.pixelSize: 13 * Math.min(root.sx, root.sy)
                    }

                    Text {
                        text: "Vocabulario  " + vocabulario
                        color: Style.Theme.texto_primario
                        font.pixelSize: 13 * Math.min(root.sx, root.sy)
                    }

                    Text {
                        text: "Tama\u00f1o  " + tamano_mb + " MB"
                        color: Style.Theme.texto_primario
                        font.pixelSize: 13 * Math.min(root.sx, root.sy)
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: textoEstado.implicitWidth + 18 * root.sx
                        Layout.preferredHeight: 24 * root.sy
                        radius: height / 2
                        color: "#DCFCE7"

                        Text {
                            id: textoEstado
                            anchors.centerIn: parent
                            text: estado
                            color: "#166534"
                            font.bold: true
                            font.pixelSize: 10 * Math.min(root.sx, root.sy)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20 * root.sx

                    Text {
                        text: "Categor\u00edas  " + (categorias ? Object.keys(categorias).length : 0)
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 12 * Math.min(root.sx, root.sy)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Campos  " + campos_texto
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 12 * Math.min(root.sx, root.sy)
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: listaDatasets.count === 0
            text: "Todav\u00eda no hay datasets en la biblioteca.\nAgrega un archivo JSON o JSONL para comenzar."
            color: Style.Theme.texto_secundario
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 18 * Math.min(root.sx, root.sy)
        }
    }
}
