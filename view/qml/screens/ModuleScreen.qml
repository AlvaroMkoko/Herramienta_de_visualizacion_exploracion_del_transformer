pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root
    objectName: "moduleScreen"

    property string moduleId: "module_1"
    readonly property var courseController: mainViewModel.courseController
    readonly property var moduleData: courseController.currentModule
    readonly property var stages: [
        { id: "pretest", number: "01", title: "Pre-test", subtitle: "15 de 25 preguntas aleatorias", route: "EvaluationIntroScreen.qml" },
        { id: "guided", number: "02", title: "Recorrido guiado", subtitle: "8 pasos breves y reproducibles", route: "ModuleGuidedTourScreen.qml" },
        { id: "laboratory", number: "03", title: "Laboratorio", subtitle: "Datos reales del modelo activo", route: "ModuleLaboratoryScreen.qml" },
        { id: "posttest", number: "04", title: "Post-test", subtitle: "15 reactivos equivalentes y distintos", route: "EvaluationIntroScreen.qml" },
        { id: "results", number: "05", title: "Resultados", subtitle: "Mejora, dominio y recomendaciones", route: "ModuleResultsScreen.qml" }
    ]

    Component.onCompleted: root.courseController.selectModule(root.moduleId)

    function openStage(stage) {
        if (!root.courseController.stageAvailable(root.moduleId, stage.id))
            return
        var properties = { "stackView": root.stackView, "moduleId": root.moduleId }
        if (stage.id === "pretest")
            properties.assessmentType = "pre"
        else if (stage.id === "posttest")
            properties.assessmentType = "post"
        root.stackView.push(stage.route, properties)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32 * root.sx
        spacing: 18 * root.sy

        RowLayout {
            Layout.fillWidth: true
            spacing: 18 * root.sx
            BotonPrincipal {
                Layout.preferredWidth: 190 * root.sx
                Layout.preferredHeight: 44 * root.sy
                text: "← Todos los módulos"
                onClicked: root.stackView.pop()
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text {
                    text: "MÓDULO " + (root.moduleData.order || "")
                    color: Style.Theme.acento_fuerte
                    font.bold: true
                    font.pixelSize: 12 * root.sx
                    font.letterSpacing: 1
                }
                Text {
                    text: root.moduleData.title || ""
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 31 * root.sx
                }
                Text {
                    text: root.moduleData.description || ""
                    color: Style.Theme.texto_secundario_fuerte
                    font.pixelSize: 14 * root.sx
                }
            }
            Text {
                text: (root.moduleData.progress_percent || 0) + "%"
                color: Style.Theme.acento_fuerte
                font.bold: true
                font.pixelSize: 28 * root.sx
            }
        }

        RectanglePrincipal {
            Layout.fillWidth: true
            Layout.preferredHeight: 116 * root.sy
            sx: root.sx
            sy: root.sy
            RowLayout {
                anchors.fill: parent
                anchors.margins: 16 * root.sx
                spacing: 12 * root.sx
                Text {
                    text: "Objetivos"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 15 * root.sx
                }
                Repeater {
                    model: root.moduleData.objectives || []
                    delegate: Rectangle {
                        id: objectiveChip
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 10 * root.sx
                        color: Style.Theme.concepto_fondo
                        Text {
                            anchors.fill: parent
                            anchors.margins: 10 * root.sx
                            text: objectiveChip.modelData
                            color: Style.Theme.concepto_texto
                            font.pixelSize: 12 * root.sx
                            wrapMode: Text.WordWrap
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10 * root.sx

            Repeater {
                model: root.stages
                delegate: Rectangle {
                    id: stageCard
                    required property var modelData
                    readonly property bool available: root.courseController.stageAvailable(root.moduleId, modelData.id)
                    readonly property bool completed: root.courseController.stageCompleted(root.moduleId, modelData.id)
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14 * root.sx
                    color: completed ? Style.Theme.exito_fondo
                                     : (available ? Style.Theme.surface : Style.Theme.superficie_alterna)
                    border.width: available && !completed ? 2 : 1
                    border.color: completed ? Style.Theme.success
                                            : (available ? Style.Theme.acento : Style.Theme.borde_suave)
                    opacity: available ? 1 : 0.58

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14 * root.sx
                        spacing: 10 * root.sy
                        Text {
                            text: stageCard.modelData.number
                            color: stageCard.completed ? Style.Theme.exito_texto : Style.Theme.acento_fuerte
                            font.bold: true
                            font.pixelSize: 28 * root.sx
                        }
                        Text {
                            Layout.fillWidth: true
                            text: stageCard.modelData.title
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: 19 * root.sx
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            Layout.fillWidth: true
                            text: stageCard.modelData.subtitle
                            color: Style.Theme.texto_secundario_fuerte
                            font.pixelSize: 12 * root.sx
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: stageCard.completed ? "✓ Completado"
                                  : (stageCard.available ? "Disponible"
                                     : root.courseController.stageBlockReason(root.moduleId, stageCard.modelData.id))
                            color: stageCard.completed ? Style.Theme.exito_texto : Style.Theme.texto_secundario
                            font.bold: stageCard.completed
                            font.pixelSize: 11 * root.sx
                            wrapMode: Text.WordWrap
                        }
                        BotonPrincipal {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40 * root.sy
                            enabled: stageCard.available
                            opacity: enabled ? 1 : 0.4
                            text: stageCard.completed ? "Revisar" : "Abrir"
                            onClicked: root.openStage(stageCard.modelData)
                        }
                    }
                }
            }
        }
    }
}
