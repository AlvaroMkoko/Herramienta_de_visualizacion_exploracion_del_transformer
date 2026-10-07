pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

// Crear una clase en red o reabrir una guardada. Al abrirla, este equipo se
// vuelve el servidor del aula y la pantalla salta a la sala en vivo.
PagePrincipal {
    id: root
    objectName: "classroomSetupScreen"

    readonly property var host: mainViewModel.classroomHostController

    function abrirSala() {
        root.stackView.push("ClassroomScreen.qml", { "stackView": root.stackView })
    }

    function crear() {
        if (root.host.crearClase(nombreField.text, grupoField.text,
                                 matriculaCheck.checked, aprobarCheck.checked))
            root.abrirSala()
    }

    function reabrir(classId) {
        if (root.host.abrirClase(classId))
            root.abrirSala()
    }

    Component.onCompleted: root.host.actualizarClases()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 34
        spacing: 18

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            BotonSecundario {
                objectName: "classroomSetupBackButton"
                Layout.preferredWidth: 150
                Layout.preferredHeight: 38
                text: "← Panel docente"
                onClicked: root.stackView.pop()
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: "Clase en red"
                    color: Style.Theme.texto_primario
                    font.pixelSize: 30
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    text: "Comparte un código y sigue el avance de tus alumnos en vivo"
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }
        }

        // Clase abierta en este momento: volver a ella sin recrearla.
        Rectangle {
            visible: root.host.activa
            Layout.fillWidth: true
            implicitHeight: 64
            radius: 12
            color: Style.Theme.exito_fondo
            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12
                Text {
                    Layout.fillWidth: true
                    text: "Clase abierta: " + root.host.nombreClase + "  ·  código " + root.host.codigo
                    color: Style.Theme.exito_texto
                    font.bold: true
                    elide: Text.ElideRight
                }
                BotonPrincipal {
                    objectName: "classroomSetupResumeButton"
                    Layout.preferredWidth: 170
                    Layout.preferredHeight: 38
                    text: "Volver a la sala"
                    onClicked: root.abrirSala()
                }
                BotonSecundario {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 38
                    text: "Detener"
                    onClicked: root.host.detenerClase()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 18

            // ── Nueva clase ───────────────────────────────────────────
            Rectangle {
                Layout.preferredWidth: Math.max(360, parent.width * 0.42)
                Layout.fillHeight: true
                radius: 14
                color: Style.Theme.surface
                border.color: Style.Theme.borde_cuadro

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 10

                    Text {
                        text: "Nueva clase"
                        color: Style.Theme.texto_primario
                        font.pixelSize: 20
                        font.bold: true
                    }
                    Text { text: "Nombre de la clase *"; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 12 }
                    CampoTextoPrincipal {
                        id: nombreField
                        objectName: "classroomNameField"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        placeholderText: "Ej. Inteligencia Artificial"
                        maximumLength: 60
                    }
                    Text { text: "Grupo (opcional)"; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 12 }
                    CampoTextoPrincipal {
                        id: grupoField
                        objectName: "classroomGroupField"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        placeholderText: "Ej. 6CV1"
                        maximumLength: 30
                    }
                    CasillaPrincipal {
                        id: matriculaCheck
                        objectName: "classroomRequireIdCheck"
                        Layout.fillWidth: true
                        text: "Pedir matrícula además del apodo"
                    }
                    CasillaPrincipal {
                        id: aprobarCheck
                        objectName: "classroomApproveCheck"
                        Layout.fillWidth: true
                        text: "Sala de espera: aceptar a cada alumno antes de que entre"
                    }
                    Text {
                        visible: text !== ""
                        Layout.fillWidth: true
                        text: root.host.mensaje
                        color: Style.Theme.error_texto
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                    Item { Layout.fillHeight: true }
                    BotonPrincipal {
                        objectName: "classroomCreateButton"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        text: "Crear y abrir clase"
                        onClicked: root.crear()
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Este equipo será el servidor del aula: mantén la aplicación abierta durante la clase."
                        color: Style.Theme.texto_terciario
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ── Clases guardadas ──────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: Style.Theme.surface
                border.color: Style.Theme.borde_cuadro

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 10

                    Text {
                        text: "Clases guardadas"
                        color: Style.Theme.texto_primario
                        font.pixelSize: 20
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Reabrir conserva el código: los alumnos se reconectan solos."
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        visible: root.host.clasesGuardadas.length === 0
                        Layout.fillWidth: true
                        Layout.topMargin: 20
                        text: "Aún no has creado clases en este equipo."
                        color: Style.Theme.texto_terciario
                        horizontalAlignment: Text.AlignHCenter
                    }
                    ListView {
                        id: listaClases
                        objectName: "classroomSavedList"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 8
                        model: root.host.clasesGuardadas
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: Rectangle {
                            id: filaClase
                            required property var modelData
                            width: listaClases.width
                            height: 72
                            radius: 10
                            color: Style.Theme.superficie_alterna
                            border.color: Style.Theme.borde_suave
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: filaClase.modelData.nombre
                                              + (filaClase.modelData.grupo ? "  ·  " + filaClase.modelData.grupo : "")
                                        color: Style.Theme.texto_primario
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: "Código " + filaClase.modelData.codigo + "  ·  "
                                              + filaClase.modelData.alumnos + " alumno(s)  ·  creada "
                                              + filaClase.modelData.creada
                                              + (filaClase.modelData.finalizada ? "  ·  finalizada" : "")
                                        color: Style.Theme.texto_secundario
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }
                                BotonSecundario {
                                    Layout.preferredWidth: 110
                                    Layout.preferredHeight: 36
                                    text: "Abrir"
                                    onClicked: root.reabrir(filaClase.modelData.class_id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
