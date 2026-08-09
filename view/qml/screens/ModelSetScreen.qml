import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"
import QtQuick.Layouts



PagePrincipal{
    id: root 

    property alias datasetModel: setModel

    ListModel {
        id: setModel
    }

    Component.onCompleted: {
        // var datasets = mainViewModel.datasetController.obtenerModelos()

        // datasetModel.clear()

        // for (var i = 0; i < datasets.length; ++i) {
        //     datasetModel.append(datasets[i])
        // }
    }





    /*
    MODELO EN QT -----ABAJO SOLO SE ENCUENTRA MODELOS VISUALES --------
    
    
    */

     BotonPrincipal {
        anchors.left: parent.left
        anchors.leftMargin: 10 * sx
        anchors.top: parent.top
        anchors.topMargin: 10 * sy
        width: 250 * sx
        height: 40 * sy
        text: " ↶ Volver al inicio"
        z: 10
        onClicked: {
            stackView.pop()
        }
    }


     Rectangle {
            id: rec1
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 10

            property real size_width: 1800
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
                    model: setModel
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
                                                ruta: ruta,
                                                nombre:nombre
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
                                        text: "---NOMBRE----"
                                        font.pixelSize: 18 * sy
                                        font.bold: true
                                        color: "#222222"
                                    }

                                    Text {
                                        text: "----ID----"
                                        font.pixelSize: 12 * sy
                                        color: "#777777"
                                    }
                                }

                                // BotonPrincipal {
                                //     Layout.preferredWidth: 120 * sx
                                //     Layout.preferredHeight: 35 * sy
                                //     text: "Ver datos"

                                //     onClicked: {
                                //         var registros = mainViewModel.datasetController.obtenerRegistros(id, 50)
                                //         verDatos.mostrar(nombre, registros)
                                //     }
                                }
                                BotonPrincipal {
                                    Layout.preferredWidth: 120 * sx
                                    Layout.preferredHeight: 35 * sy
                                    text: "Eliminar Modelo"

                                    onClicked: {
                                        // root.eliminarDatasetCompleto(id)
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
                                    text: "Registros: "// + registros
                                    font.pixelSize: 13 * sy
                                }

                                Text {
                                    text: "Tokens: " // + tokens
                                    font.pixelSize: 13 * sy
                                }

                                Text {
                                    text: "Vocabulario: "// + vocabulario
                                    font.pixelSize: 13 * sy
                                }

                                Text {
                                    text: "Tamaño: " // + tamano_mb + " MB"
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
                                    text: "Formato: " //+ formato
                                    font.pixelSize: 13 * sy
                                }

                                Text {
                                    text: "Estado: "// + estado
                                    color: "#4CAF50"
                                    font.bold: true
                                    font.pixelSize: 13 * sy
                                }

                                Text {
                                    text: "Categorías: "// + (categorias ? Object.keys(categorias).length : 0)
                                    font.pixelSize: 13 * sy
                                }

                                Text {
                                    text: "Campos: "// + campos_texto
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




