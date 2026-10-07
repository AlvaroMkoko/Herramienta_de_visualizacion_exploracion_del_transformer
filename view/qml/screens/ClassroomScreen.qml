pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../styles" as Style
import "../components"

// Sala en vivo del docente. El encabezado muestra lo que se dicta (código y
// direcciones); las pestañas responden "¿quién está?", "¿cómo va cada uno?",
// "¿qué le cuesta al grupo?" y "¿qué controlo?".
PagePrincipal {
    id: root
    objectName: "classroomScreen"

    readonly property var host: mainViewModel.classroomHostController
    property string alumnoSeleccionado: ""
    property var analisis: ({})

    function colorModulo(status) {
        switch (String(status)) {
        case "completed": return Style.Theme.exito_fondo
        case "review_recommended": return Style.Theme.aviso_fondo
        case "in_progress": return Style.Theme.acento_fondo
        default: return Style.Theme.superficie_alterna
        }
    }

    function textoModulo(status) {
        switch (String(status)) {
        case "completed": return Style.Theme.exito_texto
        case "review_recommended": return Style.Theme.aviso_texto
        case "in_progress": return Style.Theme.acento_fuerte
        default: return Style.Theme.texto_terciario
        }
    }

    function porcentaje(valor) {
        return valor === null || valor === undefined ? "—" : Math.round(valor) + "%"
    }

    function cargarAnalisis() {
        if (root.host.modulos.length === 0)
            return
        var modulo = root.host.modulos[Math.max(0, selectorModulo.currentIndex)]
        root.analisis = root.host.analisisModulo(modulo.id)
    }

    function abrirRenombrar(alumnoId, apodo) {
        root.alumnoSeleccionado = alumnoId
        nuevoApodoField.text = apodo
        dialogoRenombrar.open()
    }

    function abrirExpulsar(alumnoId, apodo) {
        root.alumnoSeleccionado = alumnoId
        dialogoExpulsar.texto = "«" + apodo + "» saldrá de la clase y no podrá volver a unirse con esta cuenta. Sus resultados se conservan."
        dialogoExpulsar.open()
    }

    Connections {
        target: root.host
        function onAlumnosCambio() {
            if (pestanas.currentIndex === 2)
                root.cargarAnalisis()
        }
        function onClaseCambio() {
            if (!root.host.activa && root.StackView.status === StackView.Active)
                root.stackView.pop()
        }
    }

    FileDialog {
        id: dialogoCsv
        title: "Exportar resultados de la clase"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "csv"
        nameFilters: ["CSV (*.csv)"]
        onAccepted: root.host.exportarCsv(selectedFile.toString())
    }

    FileDialog {
        id: dialogoImportar
        title: "Importar avances de alumnos"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["Avance de clase (*.tvclase)"]
        onAccepted: {
            var rutas = []
            for (var i = 0; i < selectedFiles.length; ++i)
                rutas.push(selectedFiles[i].toString())
            root.host.importarArchivos(rutas)
        }
    }

    Dialog {
        id: dialogoRenombrar
        anchors.centerIn: parent
        width: Math.min(420, root.width - 48)
        modal: true
        title: "Cambiar apodo"
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: root.host.renombrarAlumno(root.alumnoSeleccionado, nuevoApodoField.text)
        contentItem: CampoTextoPrincipal {
            id: nuevoApodoField
            maximumLength: 20
            placeholderText: "Nuevo apodo"
        }
    }

    Dialog {
        id: dialogoExpulsar
        property string texto: ""
        anchors.centerIn: parent
        width: Math.min(460, root.width - 48)
        modal: true
        title: "¿Retirar de la clase?"
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: root.host.expulsarAlumno(root.alumnoSeleccionado)
        contentItem: Text {
            text: dialogoExpulsar.texto
            color: Style.Theme.texto_primario
            wrapMode: Text.WordWrap
        }
    }

    Dialog {
        id: dialogoFinalizar
        anchors.centerIn: parent
        width: Math.min(480, root.width - 48)
        modal: true
        title: "¿Finalizar la clase?"
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: root.host.finalizarClase()
        contentItem: Text {
            text: "Se avisará a los alumnos y ya no podrán unirse ni enviar avance por red. Los datos quedan guardados y puedes reabrir la clase después."
            color: Style.Theme.texto_primario
            wrapMode: Text.WordWrap
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 26
        spacing: 14

        // ── Encabezado: lo que se dicta en voz alta ─────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            BotonSecundario {
                objectName: "classroomBackButton"
                Layout.preferredWidth: 120
                Layout.preferredHeight: 38
                Layout.alignment: Qt.AlignTop
                text: "← Clases"
                onClicked: root.stackView.pop()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: root.host.nombreClase + (root.host.grupo ? "  ·  " + root.host.grupo : "")
                    color: Style.Theme.texto_primario
                    font.pixelSize: 26
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    text: root.host.conectados + " conectado(s) de " + root.host.totalAlumnos + " alumno(s)"
                          + (root.host.pendientesAprobacion > 0
                             ? "  ·  " + root.host.pendientesAprobacion + " esperando aprobación" : "")
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 13
                }
                Repeater {
                    model: root.host.direcciones
                    delegate: Text {
                        required property var modelData
                        text: "Dirección: " + modelData.direccion + "   (" + modelData.nombre
                              + (modelData.hotspot ? ", hotspot" : "") + ")"
                        color: Style.Theme.texto_secundario_fuerte
                        font.pixelSize: 12
                    }
                }
                Text {
                    visible: !root.host.descubrimientoActivo
                    Layout.fillWidth: true
                    text: "Búsqueda automática no disponible: los alumnos deben usar «Conectar por dirección»."
                    color: Style.Theme.aviso_texto
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                objectName: "classroomCodeBox"
                Layout.preferredWidth: 250
                Layout.preferredHeight: 104
                radius: 14
                color: Style.Theme.acento_fondo
                border.color: Style.Theme.acento
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "CÓDIGO DE LA CLASE"
                        color: Style.Theme.acento_fuerte
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.2
                    }
                    Text {
                        objectName: "classroomCodeText"
                        Layout.alignment: Qt.AlignHCenter
                        text: root.host.codigo
                        color: Style.Theme.texto_primario
                        font.pixelSize: 40
                        font.bold: true
                        font.letterSpacing: 4
                    }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 8
                BotonSecundario {
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 38
                    text: "Detener"
                    onClicked: root.host.detenerClase()
                }
                BotonSecundario {
                    objectName: "classroomFinishButton"
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 38
                    variante: "peligro"
                    text: "Finalizar clase"
                    onClicked: dialogoFinalizar.open()
                }
            }
        }

        Text {
            visible: text !== ""
            Layout.fillWidth: true
            text: root.host.mensaje
            color: Style.Theme.texto_secundario_fuerte
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        TabBar {
            id: pestanas
            objectName: "classroomTabs"
            Layout.fillWidth: true
            spacing: 6
            background: Item {}
            onCurrentIndexChanged: if (currentIndex === 2) root.cargarAnalisis()
            PestanaAccesible { text: "Sala" }
            PestanaAccesible { text: "Avance por módulo" }
            PestanaAccesible { text: "Análisis del grupo" }
            PestanaAccesible { text: "Herramientas" }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: pestanas.currentIndex

            // ── Sala ─────────────────────────────────────────────────
            Rectangle {
                radius: 14
                color: Style.Theme.surface
                border.color: Style.Theme.borde_cuadro

                Text {
                    visible: root.host.alumnos.length === 0
                    anchors.centerIn: parent
                    width: Math.min(460, parent.width - 40)
                    text: "Aún no hay alumnos. Pide que abran «Unirse a una clase» y escriban el código " + root.host.codigo + "."
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 15
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                ListView {
                    id: listaAlumnos
                    objectName: "classroomStudentsList"
                    anchors.fill: parent
                    anchors.margins: 14
                    clip: true
                    spacing: 8
                    model: root.host.alumnos
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        id: filaAlumno
                        required property var modelData
                        readonly property bool pendiente: modelData.estado === "pendiente"
                        readonly property bool retirado: modelData.estado === "expulsado"
                        width: listaAlumnos.width
                        height: 72
                        radius: 10
                        color: pendiente ? Style.Theme.aviso_fondo : Style.Theme.superficie_alterna
                        border.color: Style.Theme.borde_suave
                        opacity: retirado ? 0.6 : 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 14

                            Rectangle {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                radius: 21
                                color: Style.Theme.acento_fondo
                                Text {
                                    anchors.centerIn: parent
                                    text: String(filaAlumno.modelData.apodo || "?").charAt(0).toUpperCase()
                                    color: Style.Theme.acento
                                    font.pixelSize: 18
                                    font.bold: true
                                }
                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 6
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    color: filaAlumno.modelData.conectado ? Style.Theme.success : Style.Theme.borde
                                    border.color: Style.Theme.surface
                                    border.width: 2
                                }
                            }

                            ColumnLayout {
                                Layout.preferredWidth: 220
                                spacing: 2
                                RowLayout {
                                    spacing: 6
                                    Text {
                                        Layout.maximumWidth: 160
                                        text: filaAlumno.modelData.apodo
                                        color: Style.Theme.texto_primario
                                        font.pixelSize: 16
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Rectangle {
                                        visible: !filaAlumno.modelData.verificado
                                        implicitWidth: sinVerificar.implicitWidth + 12
                                        implicitHeight: 18
                                        radius: 9
                                        color: Style.Theme.aviso_fondo
                                        Text {
                                            id: sinVerificar
                                            anchors.centerIn: parent
                                            text: "sin verificar"
                                            color: Style.Theme.aviso_texto
                                            font.pixelSize: 10
                                        }
                                    }
                                }
                                Text {
                                    text: filaAlumno.pendiente ? "Esperando tu aprobación"
                                          : filaAlumno.retirado ? "Retirado de la clase"
                                          : (filaAlumno.modelData.conectado ? "Conectado" : "Desconectado · " + filaAlumno.modelData.ultima_actividad)
                                            + (filaAlumno.modelData.matricula ? "  ·  " + filaAlumno.modelData.matricula : "")
                                    color: Style.Theme.texto_secundario
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text {
                                    Layout.fillWidth: true
                                    text: filaAlumno.modelData.modulo_actual + "  —  " + filaAlumno.modelData.etapa
                                    color: Style.Theme.texto_primario
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    BarraProgreso {
                                        Layout.fillWidth: true
                                        valor: filaAlumno.modelData.global_percent / 100
                                        etiquetaAccesible: "Avance del curso de " + filaAlumno.modelData.apodo
                                    }
                                    Text {
                                        text: filaAlumno.modelData.global_percent + "%"
                                        color: Style.Theme.texto_secundario_fuerte
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }
                            }

                            BotonPrincipal {
                                visible: filaAlumno.pendiente
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 34
                                text: "Aceptar"
                                onClicked: root.host.aprobarAlumno(filaAlumno.modelData.alumno_id)
                            }
                            BotonSecundario {
                                visible: filaAlumno.pendiente
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 34
                                variante: "peligro"
                                text: "Rechazar"
                                onClicked: root.host.rechazarAlumno(filaAlumno.modelData.alumno_id)
                            }
                            BotonSecundario {
                                visible: !filaAlumno.pendiente && !filaAlumno.retirado
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 34
                                text: "Renombrar"
                                onClicked: root.abrirRenombrar(filaAlumno.modelData.alumno_id, filaAlumno.modelData.apodo)
                            }
                            BotonSecundario {
                                visible: !filaAlumno.pendiente && !filaAlumno.retirado
                                Layout.preferredWidth: 90
                                Layout.preferredHeight: 34
                                variante: "peligro"
                                text: "Retirar"
                                onClicked: root.abrirExpulsar(filaAlumno.modelData.alumno_id, filaAlumno.modelData.apodo)
                            }
                            BotonSecundario {
                                visible: filaAlumno.retirado
                                Layout.preferredWidth: 110
                                Layout.preferredHeight: 34
                                text: "Readmitir"
                                onClicked: root.host.readmitirAlumno(filaAlumno.modelData.alumno_id)
                            }
                        }
                    }
                }
            }

            // ── Avance por módulo (matriz) ──────────────────────────
            Rectangle {
                radius: 14
                color: Style.Theme.surface
                border.color: Style.Theme.borde_cuadro

                Flickable {
                    id: matriz
                    anchors.fill: parent
                    anchors.margins: 14
                    clip: true
                    contentWidth: Math.max(width, tablaMatriz.implicitWidth)
                    contentHeight: tablaMatriz.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

                    Column {
                        id: tablaMatriz
                        spacing: 6

                        Row {
                            spacing: 6
                            Text {
                                width: 180
                                height: 30
                                text: "Alumno"
                                color: Style.Theme.texto_terciario
                                font.bold: true
                                verticalAlignment: Text.AlignVCenter
                            }
                            Repeater {
                                model: root.host.modulos
                                delegate: Text {
                                    id: encabezadoModulo
                                    required property var modelData
                                    width: 78
                                    height: 30
                                    text: "M" + encabezadoModulo.modelData.order + (encabezadoModulo.modelData.habilitado ? "" : " 🔒")
                                    color: Style.Theme.texto_terciario
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    ToolTip.visible: celdaEncabezado.containsMouse
                                    ToolTip.text: encabezadoModulo.modelData.title
                                    MouseArea { id: celdaEncabezado; anchors.fill: parent; hoverEnabled: true }
                                }
                            }
                        }

                        Repeater {
                            model: root.host.alumnos
                            delegate: Row {
                                id: filaMatriz
                                required property var modelData
                                visible: modelData.estado === "activo"
                                spacing: 6
                                Text {
                                    width: 180
                                    height: 36
                                    text: (filaMatriz.modelData.conectado ? "● " : "○ ") + filaMatriz.modelData.apodo
                                    color: Style.Theme.texto_primario
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Repeater {
                                    model: filaMatriz.modelData.modules
                                    delegate: Rectangle {
                                        id: celda
                                        required property var modelData
                                        width: 78
                                        height: 36
                                        radius: 8
                                        color: root.colorModulo(modelData.status)
                                        border.color: Style.Theme.borde_suave
                                        Text {
                                            anchors.centerIn: parent
                                            text: celda.modelData.post_percentage !== null
                                                  && celda.modelData.post_percentage !== undefined
                                                  ? Math.round(celda.modelData.post_percentage) + "%"
                                                  : celda.modelData.progress_percent + "%"
                                            color: root.textoModulo(celda.modelData.status)
                                            font.bold: true
                                            font.pixelSize: 12
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            width: 700
                            topPadding: 10
                            text: "Cada celda muestra el post-test si ya existe; si no, cuántas etapas del módulo lleva. Verde: completado · Ámbar: conviene repasar (post-test < 70%) · Morado: en curso."
                            color: Style.Theme.texto_terciario
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // ── Análisis del grupo ──────────────────────────────────
            Rectangle {
                radius: 14
                color: Style.Theme.surface
                border.color: Style.Theme.borde_cuadro

                Flickable {
                    id: panelAnalisis
                    anchors.fill: parent
                    anchors.margins: 18
                    clip: true
                    contentWidth: width
                    contentHeight: columnaAnalisis.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    ColumnLayout {
                        id: columnaAnalisis
                        width: panelAnalisis.width
                        spacing: 12

                        SelectorPrincipal {
                            id: selectorModulo
                            objectName: "classroomModuleSelector"
                            Layout.preferredWidth: 420
                            Layout.preferredHeight: 38
                            model: root.host.modulos.map(function(m) { return "Módulo " + m.order + " · " + m.title })
                            onActivated: root.cargarAnalisis()
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 4
                            columnSpacing: 12
                            Repeater {
                                model: [
                                    { "etiqueta": "PRE-TEST PROMEDIO", "valor": root.porcentaje(root.analisis.avg_pre), "detalle": (root.analisis.with_pre || 0) + " alumno(s)" },
                                    { "etiqueta": "POST-TEST PROMEDIO", "valor": root.porcentaje(root.analisis.avg_post), "detalle": (root.analisis.with_post || 0) + " alumno(s)" },
                                    { "etiqueta": "CAMBIO PROMEDIO", "valor": root.analisis.avg_delta === null || root.analisis.avg_delta === undefined ? "—" : (root.analisis.avg_delta > 0 ? "+" : "") + root.analisis.avg_delta + " pts", "detalle": (root.analisis.with_both || 0) + " con ambos tests" },
                                    { "etiqueta": "ALUMNOS", "valor": String(root.analisis.students || 0), "detalle": "en la clase" }
                                ]
                                delegate: Rectangle {
                                    id: tarjetaDato
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 86
                                    radius: 12
                                    color: Style.Theme.superficie_alterna
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 2
                                        Text { text: tarjetaDato.modelData.etiqueta; color: Style.Theme.texto_terciario; font.pixelSize: 10; font.bold: true }
                                        Text { text: tarjetaDato.modelData.valor; color: Style.Theme.texto_primario; font.pixelSize: 24; font.bold: true }
                                        Text { text: tarjetaDato.modelData.detalle; color: Style.Theme.texto_secundario; font.pixelSize: 11 }
                                    }
                                }
                            }
                        }

                        Text {
                            text: "Conceptos con más errores en el post-test"
                            color: Style.Theme.texto_primario
                            font.pixelSize: 16
                            font.bold: true
                        }
                        Text {
                            visible: !root.analisis.concept_errors || root.analisis.concept_errors.length === 0
                            text: "Todavía no hay post-tests con errores en este módulo."
                            color: Style.Theme.texto_terciario
                        }
                        Repeater {
                            model: root.analisis.concept_errors || []
                            delegate: RowLayout {
                                id: filaConcepto
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                spacing: 10
                                Text {
                                    Layout.preferredWidth: 260
                                    text: filaConcepto.modelData.name
                                    color: Style.Theme.texto_primario
                                    elide: Text.ElideRight
                                }
                                BarraProgreso {
                                    Layout.fillWidth: true
                                    colorRelleno: Style.Theme.error
                                    valor: filaConcepto.modelData.count / Math.max(1, root.analisis.concept_errors[0].count)
                                    etiquetaAccesible: "Errores en " + filaConcepto.modelData.name
                                }
                                Text {
                                    text: filaConcepto.modelData.count + " error(es)"
                                    color: Style.Theme.texto_secundario
                                    font.pixelSize: 12
                                }
                            }
                        }

                        Text {
                            Layout.topMargin: 8
                            text: "Reactivos más fallados"
                            color: Style.Theme.texto_primario
                            font.pixelSize: 16
                            font.bold: true
                        }
                        Repeater {
                            model: root.analisis.question_errors || []
                            delegate: Text {
                                required property var modelData
                                Layout.fillWidth: true
                                text: "• " + modelData.count + "×  " + (modelData.prompt || modelData.question_id)
                                color: Style.Theme.texto_secundario_fuerte
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            // ── Herramientas ────────────────────────────────────────
            Rectangle {
                radius: 14
                color: Style.Theme.surface
                border.color: Style.Theme.borde_cuadro

                Flickable {
                    id: panelHerramientas
                    anchors.fill: parent
                    anchors.margins: 18
                    clip: true
                    contentWidth: width
                    contentHeight: columnaHerramientas.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    GridLayout {
                        id: columnaHerramientas
                        width: panelHerramientas.width
                        columns: width > 900 ? 2 : 1
                        columnSpacing: 24
                        rowSpacing: 14

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: 6
                            Text { text: "Módulos habilitados"; color: Style.Theme.texto_primario; font.pixelSize: 16; font.bold: true }
                            Text {
                                Layout.fillWidth: true
                                text: "Los alumnos sólo pueden abrir los módulos marcados."
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                            Repeater {
                                model: root.host.modulos
                                delegate: CasillaPrincipal {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    text: "Módulo " + modelData.order + " · " + modelData.title
                                    checked: modelData.habilitado
                                    onToggled: root.host.habilitarModulo(modelData.id, checked)
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: 8

                            Text { text: "Aviso a toda la clase"; color: Style.Theme.texto_primario; font.pixelSize: 16; font.bold: true }
                            RowLayout {
                                Layout.fillWidth: true
                                CampoTextoPrincipal {
                                    id: avisoField
                                    objectName: "classroomAnnouncementField"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    maximumLength: 500
                                    placeholderText: "Ej. Terminen el pre-test del módulo 2"
                                    onAccepted: if (root.host.enviarAviso(text)) text = ""
                                }
                                BotonPrincipal {
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 40
                                    text: "Enviar"
                                    onClicked: if (root.host.enviarAviso(avisoField.text)) avisoField.text = ""
                                }
                            }

                            Text { Layout.topMargin: 8; text: "Ingreso"; color: Style.Theme.texto_primario; font.pixelSize: 16; font.bold: true }
                            CasillaPrincipal {
                                Layout.fillWidth: true
                                text: "Sala de espera: aceptar a cada alumno nuevo"
                                checked: root.host.aprobarIngresos
                                onToggled: root.host.setAprobarIngresos(checked)
                            }
                            CasillaPrincipal {
                                Layout.fillWidth: true
                                text: "Pedir matrícula a los alumnos nuevos"
                                checked: root.host.pedirMatricula
                                onToggled: root.host.setPedirMatricula(checked)
                            }

                            Text { Layout.topMargin: 8; text: "Datos"; color: Style.Theme.texto_primario; font.pixelSize: 16; font.bold: true }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                BotonSecundario {
                                    objectName: "classroomExportCsvButton"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    text: "Exportar resultados (CSV)"
                                    onClicked: dialogoCsv.open()
                                }
                                BotonSecundario {
                                    objectName: "classroomImportButton"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    text: "Importar archivos .tvclase"
                                    onClicked: dialogoImportar.open()
                                }
                            }

                            Text { Layout.topMargin: 8; text: "Diagnóstico de red"; color: Style.Theme.texto_primario; font.pixelSize: 16; font.bold: true }
                            Repeater {
                                model: root.host.interfacesRed
                                delegate: Text {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    text: "• " + modelData.nombre + ": " + modelData.ip
                                          + (modelData.hotspot ? "  (hotspot de este equipo)" : "")
                                    color: Style.Theme.texto_secundario_fuerte
                                    font.pixelSize: 12
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Si los alumnos no encuentran la clase: verifiquen que están en la misma red, permitan la aplicación en el firewall (redes privadas y públicas) o usen «Conectar por dirección». Si el Wi-Fi de la escuela aísla a los equipos, activa un hotspot o un router propio y conecta ahí a todos."
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
    }
}
