pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../styles" as Style
import "../components"

// Unirse a la clase del docente, al estilo Kahoot:
//   1. código de la clase  →  2. apodo (y matrícula si el docente la pide)
// Si el alumno ya pertenece a una clase, la pantalla muestra su estado,
// permite exportar el avance a un archivo .tvclase y salir de la clase.
PagePrincipal {
    id: root
    objectName: "joinClassScreen"

    readonly property var cc: mainViewModel.classroomStudentController
    readonly property bool enPasoApodo: cc.estado === "eligiendo_apodo" || cc.estado === "uniendo"
    property bool mostrarDireccion: false
    property bool mostrarArchivo: false

    function buscar() {
        if (root.mostrarDireccion)
            root.cc.buscarPorDireccion(direccionField.text, codigoField.text)
        else
            root.cc.buscarClase(codigoField.text)
    }

    function entrar() {
        root.cc.unirse(apodoField.text, matriculaField.text)
    }

    function exportar() {
        dialogoExportar.open()
    }

    function colorEstado(estado) {
        switch (String(estado)) {
        case "conectado": return Style.Theme.exito_texto
        case "en_espera": return Style.Theme.aviso_texto
        case "reconectando":
        case "error": return Style.Theme.error_texto
        default: return Style.Theme.texto_secundario
        }
    }

    function fondoEstado(estado) {
        switch (String(estado)) {
        case "conectado": return Style.Theme.exito_fondo
        case "en_espera": return Style.Theme.aviso_fondo
        case "reconectando":
        case "error": return Style.Theme.error_fondo
        default: return Style.Theme.chip_fondo
        }
    }

    Connections {
        target: root.cc
        function onEstadoCambio() {
            if (root.cc.estado === "eligiendo_apodo" && root.cc.sugerenciaApodo === "")
                apodoField.forceActiveFocus()
        }
    }

    FileDialog {
        id: dialogoExportar
        title: "Guardar mi avance para entregarlo al docente"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "tvclase"
        nameFilters: ["Avance de clase (*.tvclase)"]
        onAccepted: root.cc.exportarAvance(selectedFile.toString(),
                                           codigoField.text, apodoArchivoField.text)
    }

    Dialog {
        id: confirmarSalida
        anchors.centerIn: parent
        width: Math.min(460, root.width - 48)
        modal: true
        title: "¿Salir de la clase?"
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: root.cc.salirDeClase()
        contentItem: Text {
            text: "Dejarás de enviar tu avance al docente. Tu progreso sigue guardado en este equipo y podrás unirte de nuevo con el código."
            color: Style.Theme.texto_primario
            wrapMode: Text.WordWrap
        }
    }

    Flickable {
        id: desplazamiento
        anchors.fill: parent
        contentWidth: width
        contentHeight: columna.implicitHeight + 60
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: columna
            width: Math.min(640, desplazamiento.width - 48)
            x: (desplazamiento.width - width) / 2
            y: 24
            spacing: 18

            BotonSecundario {
                objectName: "joinClassBackButton"
                Layout.preferredWidth: 130
                Layout.preferredHeight: 38
                text: "← Volver"
                onClicked: root.stackView.pop()
            }

            Text {
                Layout.fillWidth: true
                text: root.cc.enClase ? "Tu clase" : "Unirse a una clase"
                color: Style.Theme.texto_primario
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 30
                font.bold: true
                Accessible.role: Accessible.Heading
            }

            // ── Ya pertenece a una clase ─────────────────────────────
            Rectangle {
                visible: root.cc.enClase
                Layout.fillWidth: true
                implicitHeight: panelClase.implicitHeight + 48
                radius: 16
                color: Style.Theme.surface
                border.color: Style.Theme.borde_cuadro

                ColumnLayout {
                    id: panelClase
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 24
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: root.cc.nombreClase
                                color: Style.Theme.texto_primario
                                font.pixelSize: 22
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: "Código " + root.cc.codigo + "  ·  Te ven como «" + root.cc.apodo + "»"
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 13
                            }
                        }
                        Rectangle {
                            objectName: "joinClassStatusChip"
                            implicitWidth: textoEstado.implicitWidth + 24
                            implicitHeight: 30
                            radius: 15
                            color: root.fondoEstado(root.cc.estado)
                            Text {
                                id: textoEstado
                                anchors.centerIn: parent
                                text: root.cc.estadoTexto
                                color: root.colorEstado(root.cc.estado)
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.cc.pendientes === 0
                              ? "Todo tu avance está entregado al docente."
                              : root.cc.pendientes + " evaluación(es) se enviarán en cuanto haya conexión."
                        color: Style.Theme.texto_secundario_fuerte
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        visible: root.cc.estado === "reconectando"
                        Layout.fillWidth: true
                        text: "Puedes seguir trabajando: todo se guarda en este equipo y se enviará solo cuando el docente vuelva a estar disponible."
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        spacing: 10
                        BotonPrincipal {
                            objectName: "joinClassContinueButton"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            text: "Ir a mi ruta"
                            onClicked: root.stackView.pop()
                        }
                        BotonSecundario {
                            visible: root.cc.estado !== "conectado" && root.cc.estado !== "en_espera"
                            Layout.preferredHeight: 44
                            Layout.preferredWidth: 150
                            text: "Reintentar ahora"
                            onClicked: root.cc.reintentar()
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        BotonSecundario {
                            objectName: "joinClassExportButton"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            text: "Exportar mi avance a archivo"
                            onClicked: root.exportar()
                        }
                        BotonSecundario {
                            objectName: "joinClassLeaveButton"
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 40
                            variante: "peligro"
                            text: "Salir de la clase"
                            onClicked: confirmarSalida.open()
                        }
                    }
                }
            }

            // ── Paso 1: código ────────────────────────────────────────
            Rectangle {
                visible: !root.cc.enClase && !root.enPasoApodo
                Layout.fillWidth: true
                implicitHeight: pasoCodigo.implicitHeight + 48
                radius: 16
                color: Style.Theme.surface
                border.color: Style.Theme.borde_cuadro

                ColumnLayout {
                    id: pasoCodigo
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 24
                    spacing: 12

                    Text {
                        Layout.fillWidth: true
                        text: "Escribe el código que muestra tu docente. Deben estar conectados a la misma red."
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                    }

                    CampoTextoPrincipal {
                        id: codigoField
                        objectName: "joinClassCodeField"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        font.pixelSize: 30
                        font.bold: true
                        font.letterSpacing: 4
                        horizontalAlignment: TextInput.AlignHCenter
                        placeholderText: "K7P-4QX"
                        maximumLength: 9
                        enabled: !root.cc.ocupado
                        Accessible.name: "Código de la clase"
                        onAccepted: root.buscar()
                    }

                    ColumnLayout {
                        visible: root.mostrarDireccion
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Dirección que aparece en la pantalla del docente"
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: 12
                        }
                        CampoTextoPrincipal {
                            id: direccionField
                            objectName: "joinClassAddressField"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42
                            placeholderText: "192.168.1.20:47801"
                            enabled: !root.cc.ocupado
                            onAccepted: root.buscar()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        BotonPrincipal {
                            objectName: "joinClassSearchButton"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            enabled: !root.cc.ocupado
                            text: root.cc.ocupado ? root.cc.estadoTexto
                                                  : (root.mostrarDireccion ? "Conectar" : "Buscar clase")
                            onClicked: root.buscar()
                        }
                        BotonSecundario {
                            visible: root.cc.ocupado
                            Layout.preferredHeight: 48
                            Layout.preferredWidth: 120
                            text: "Cancelar"
                            onClicked: root.cc.cancelar()
                        }
                    }

                    BusyIndicator {
                        visible: root.cc.ocupado
                        running: visible
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: 36
                    }

                    Text {
                        objectName: "joinClassMessage"
                        visible: text !== ""
                        Layout.fillWidth: true
                        text: root.cc.mensaje
                        color: root.cc.estado === "error" ? Style.Theme.error_texto : Style.Theme.texto_secundario
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        BotonSecundario {
                            objectName: "joinClassToggleAddressButton"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            text: root.mostrarDireccion ? "Buscar automáticamente" : "Conectar por dirección"
                            onClicked: root.mostrarDireccion = !root.mostrarDireccion
                        }
                        BotonSecundario {
                            objectName: "joinClassToggleFileButton"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            text: root.mostrarArchivo ? "Ocultar entrega por archivo" : "Sin red: entregar por archivo"
                            onClicked: root.mostrarArchivo = !root.mostrarArchivo
                        }
                    }

                    // Opción D: sin red, el avance viaja en un archivo.
                    Rectangle {
                        visible: root.mostrarArchivo
                        Layout.fillWidth: true
                        implicitHeight: archivoColumna.implicitHeight + 28
                        radius: 10
                        color: Style.Theme.superficie_alterna
                        ColumnLayout {
                            id: archivoColumna
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8
                            Text {
                                Layout.fillWidth: true
                                text: "Escribe arriba el código de la clase y aquí tu apodo. Guarda el archivo y entrégalo a tu docente (USB, Classroom o correo). Como nunca te conectaste, el docente lo verá como «sin verificar»."
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                            CampoTextoPrincipal {
                                id: apodoArchivoField
                                objectName: "joinClassFileNicknameField"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                maximumLength: 20
                                placeholderText: "Tu apodo"
                            }
                            BotonSecundario {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
                                text: "Exportar mi avance (.tvclase)"
                                onClicked: root.exportar()
                            }
                        }
                    }
                }
            }

            // ── Paso 2: apodo ─────────────────────────────────────────
            Rectangle {
                visible: !root.cc.enClase && root.enPasoApodo
                Layout.fillWidth: true
                implicitHeight: pasoApodo.implicitHeight + 48
                radius: 16
                color: Style.Theme.surface
                border.color: Style.Theme.borde_cuadro

                ColumnLayout {
                    id: pasoApodo
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 24
                    spacing: 12

                    Text {
                        Layout.fillWidth: true
                        text: "Clase encontrada: " + root.cc.nombreClase
                        color: Style.Theme.exito_texto
                        font.pixelSize: 14
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "¿Cómo quieres que te vea tu docente?"
                        color: Style.Theme.texto_primario
                        font.pixelSize: 20
                        font.bold: true
                    }
                    CampoTextoPrincipal {
                        id: apodoField
                        objectName: "joinClassNicknameField"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 54
                        font.pixelSize: 22
                        horizontalAlignment: TextInput.AlignHCenter
                        maximumLength: 20
                        placeholderText: "Tu apodo"
                        enabled: root.cc.estado === "eligiendo_apodo"
                        Accessible.name: "Apodo"
                        onAccepted: root.entrar()
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Entre 2 y 20 caracteres. Sólo lo usa tu docente para reconocerte."
                        color: Style.Theme.texto_terciario
                        font.pixelSize: 11
                    }

                    ColumnLayout {
                        visible: root.cc.pedirMatricula
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Matrícula *"
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: 12
                        }
                        CampoTextoPrincipal {
                            id: matriculaField
                            objectName: "joinClassIdField"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42
                            placeholderText: "Ej. 2021630001"
                            enabled: root.cc.estado === "eligiendo_apodo"
                            onAccepted: root.entrar()
                        }
                    }

                    Text {
                        visible: text !== ""
                        Layout.fillWidth: true
                        text: root.cc.mensaje
                        color: Style.Theme.error_texto
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }

                    BotonSecundario {
                        objectName: "joinClassSuggestionButton"
                        visible: root.cc.sugerenciaApodo !== ""
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        text: "Usar «" + root.cc.sugerenciaApodo + "»"
                        onClicked: {
                            apodoField.text = root.cc.sugerenciaApodo
                            root.entrar()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        BotonPrincipal {
                            objectName: "joinClassEnterButton"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            enabled: root.cc.estado === "eligiendo_apodo"
                            text: root.cc.estado === "uniendo" ? "Entrando…" : "Entrar a la clase"
                            onClicked: root.entrar()
                        }
                        BotonSecundario {
                            Layout.preferredHeight: 48
                            Layout.preferredWidth: 120
                            text: "Cancelar"
                            onClicked: root.cc.cancelar()
                        }
                    }
                }
            }

            Text {
                visible: root.cc.enClase && root.cc.mensaje !== ""
                Layout.fillWidth: true
                text: root.cc.mensaje
                color: Style.Theme.texto_secundario
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
        }
    }
}
