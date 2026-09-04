import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"
import Vispy 1.0
import QtQuick.Layouts
import QtQuick.Dialogs


PagePrincipal {
    id: root
    helpModalObjectName: "loadDatasetTheoryModal"
    helpPanelObjectName: "loadDatasetTheoryPanel"

    property alias datasetModel: datasetModel
    property alias markModel: markModel
    readonly property var datasetController: mainViewModel.datasetController
    readonly property var estadoTrabajo: datasetController ? datasetController.progreso : ({})
    property string vistaPreviaPendienteId: ""
    property string vistaPreviaPendienteNombre: ""
    property string mensajeErrorDataset: ""

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
        if (datasetController.ocupado)
            return

        datasetController.eliminarDataset(datasetId)

        let markIdx = indexOfMark(datasetId)
        if (markIdx !== -1)
            markModel.remove(markIdx)

        let dsIdx = indexOfDataset(datasetId)
        if (dsIdx !== -1)
            datasetModel.remove(dsIdx)
    }

    function incorporarDataset(dataset) {
        if (!dataset || !dataset.id)
            return
        if (indexOfDataset(dataset.id) === -1)
            datasetModel.append(dataset)
    }

    function solicitarVistaPrevia(datasetId, nombreDataset) {
        if (datasetController.ocupado)
            return
        vistaPreviaPendienteId = datasetId
        vistaPreviaPendienteNombre = nombreDataset
        if (!datasetController.obtenerRegistrosAsync(datasetId, 50)) {
            vistaPreviaPendienteId = ""
            vistaPreviaPendienteNombre = ""
        }
    }

    Component.onCompleted: {
        var datasets = datasetController.obtenerDatasets()

        datasetModel.clear()

        for (var i = 0; i < datasets.length; ++i) {
            datasetModel.append(datasets[i])
        }
    }

    Connections {
        target: root.datasetController

        function onResultado(payload) {
            if (!payload)
                return
            if (payload.operacion === "agregar") {
                root.incorporarDataset(payload.dataset)
            } else if (payload.operacion === "vista_previa"
                       && payload.dataset_id === root.vistaPreviaPendienteId) {
                verDatos.mostrar(root.vistaPreviaPendienteNombre,
                                 payload.registros || [])
                root.vistaPreviaPendienteId = ""
                root.vistaPreviaPendienteNombre = ""
            }
        }

        function onError(mensaje) {
            root.vistaPreviaPendienteId = ""
            root.vistaPreviaPendienteNombre = ""
            root.mensajeErrorDataset = mensaje
            errorDatasetDialog.open()
        }
    }

    FileDialog {
        id: datasetDialog
        title: "Selecciona un dataset"
        nameFilters: [
            "Datasets compatibles (*.jsonl *.json *.csv *.txt *.pdf)",
            "JSONL (*.jsonl)",
            "JSON (*.json)",
            "CSV (*.csv)",
            "Texto (*.txt)",
            "PDF (*.pdf)",
            "Todos los archivos (*)"
        ]

        onAccepted: {
            var ruta = selectedFile.toString()
            root.datasetController.agregarDatasetAsync(ruta)
        }
    }

    Dialog {
        id: errorDatasetDialog
        anchors.centerIn: parent
        width: Math.min(520 * root.sx, root.width - 48 * root.sx)
        modal: true
        title: "No se pudo completar la operación"
        standardButtons: Dialog.Ok

        contentItem: Text {
            text: root.mensajeErrorDataset
            color: Style.Theme.texto_primario
            font.pixelSize: 14 * Math.min(root.sx, root.sy)
            wrapMode: Text.WordWrap
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
            enabled: !root.datasetController.ocupado
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
                        color: Style.Theme.chip_fondo
                        border.color: Style.Theme.borde_suave

                        Text {
                            id: etiquetaFormato
                            anchors.centerIn: parent
                            text: String(formato).toUpperCase()
                            color: Style.Theme.chip_texto
                            font.bold: true
                            font.pixelSize: 11 * Math.min(root.sx, root.sy)
                        }
                    }

                    BotonPrincipal {
                        Layout.preferredWidth: 120 * root.sx
                        Layout.preferredHeight: 36 * root.sy
                        text: "Ver datos"
                        size_text: 0.24
                        enabled: !root.datasetController.ocupado
                        onClicked: root.solicitarVistaPrevia(id, nombre)
                    }

                    BotonPrincipal {
                        Layout.preferredWidth: 145 * root.sx
                        Layout.preferredHeight: 36 * root.sy
                        text: "Eliminar dataset"
                        size_text: 0.21
                        enabled: !root.datasetController.ocupado
                        onClicked: root.eliminarDatasetCompleto(id)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Style.Theme.divisor
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20 * root.sx

                    RowLayout {
                        spacing: 4 * root.sx
                        Text {
                            text: "Registros  " + registros
                            color: Style.Theme.texto_primario
                            font.pixelSize: 13 * Math.min(root.sx, root.sy)
                        }
                        ConceptHelpButton {
                            conceptId: "dataset"
                            controlSize: Math.max(21, 24 * Math.min(root.sx, root.sy))
                            onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                        }
                    }

                    RowLayout {
                        spacing: 4 * root.sx
                        Text {
                            text: "Tokens  " + tokens
                            color: Style.Theme.texto_primario
                            font.pixelSize: 13 * Math.min(root.sx, root.sy)
                        }
                        ConceptHelpButton {
                            conceptId: "tokenizacion"
                            controlSize: Math.max(21, 24 * Math.min(root.sx, root.sy))
                            onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                        }
                    }

                    RowLayout {
                        spacing: 4 * root.sx
                        Text {
                            text: "Vocabulario  " + vocabulario
                            color: Style.Theme.texto_primario
                            font.pixelSize: 13 * Math.min(root.sx, root.sy)
                        }
                        ConceptHelpButton {
                            conceptId: "token_ids"
                            controlSize: Math.max(21, 24 * Math.min(root.sx, root.sy))
                            onHelpRequested: function(conceptId) { root.openTheoryConcept(conceptId) }
                        }
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
                        color: Style.Theme.exito_fondo

                        Text {
                            id: textoEstado
                            anchors.centerIn: parent
                            text: estado
                            color: Style.Theme.exito_texto
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

    Rectangle {
        id: indicadorOperacion
        anchors.fill: parent
        z: 1000
        visible: root.datasetController && root.datasetController.ocupado
        color: "#990F172A"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(470 * root.sx, parent.width - 48 * root.sx)
            height: 190 * root.sy
            radius: 16 * Math.min(root.sx, root.sy)
            color: Style.Theme.surface
            border.color: "#D8D5F5"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24 * root.sx
                spacing: 10 * root.sy

                BusyIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 44 * root.sx
                    Layout.preferredHeight: 44 * root.sy
                    running: indicadorOperacion.visible
                }

                Text {
                    Layout.fillWidth: true
                    text: root.estadoTrabajo.fase || "Procesando dataset"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 17 * Math.min(root.sx, root.sy)
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.estadoTrabajo.detalle || ""
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 12 * Math.min(root.sx, root.sy)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                }

                ProgressBar {
                    Layout.fillWidth: true
                    visible: !root.estadoTrabajo.indeterminado
                             && Number(root.estadoTrabajo.total || 0) > 0
                    from: 0
                    to: Math.max(1, Number(root.estadoTrabajo.total || 1))
                    value: Number(root.estadoTrabajo.valor || 0)
                }

                Text {
                    Layout.fillWidth: true
                    visible: !root.estadoTrabajo.indeterminado
                             && Number(root.estadoTrabajo.total || 0) > 0
                    text: Math.round(Number(root.estadoTrabajo.porcentaje || 0)) + " %"
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 12 * Math.min(root.sx, root.sy)
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
