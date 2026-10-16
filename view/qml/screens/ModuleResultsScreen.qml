pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root
    objectName: "moduleResultsScreen"

    property string moduleId: "module_1"
    readonly property var courseController: mainViewModel.courseController
    property var results: ({})

    Component.onCompleted: {
        root.results = root.courseController.moduleResults(root.moduleId)
        if (root.results.available)
            root.courseController.markResultsViewed(root.moduleId)
    }

    function formatTime(seconds) {
        var total = Math.round(Number(seconds) || 0)
        return Math.floor(total / 60) + " min " + (total % 60) + " s"
    }

    // Ganancia normalizada de Hake: fracción de lo que faltaba que se ganó.
    function formatGain(value) {
        if (value === undefined || value === null)
            return "—"
        return Number(value).toFixed(2)
    }

    function openStep(step) {
        if (!step || step.index === undefined)
            return
        root.stackView.push("ModuleGuidedTourScreen.qml", {
            "stackView": root.stackView,
            "moduleId": root.moduleId,
            "currentIndex": Number(step.index)
        })
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28 * root.sx
        spacing: 14 * root.sy

        RowLayout {
            Layout.fillWidth: true
            BotonPrincipal {
                Layout.preferredWidth: 160 * root.sx
                Layout.preferredHeight: 42 * root.sy
                text: "← Volver"
                onClicked: root.stackView.pop()
            }
            ColumnLayout {
                Layout.fillWidth: true
                Text {
                    text: "RESULTADOS DEL MÓDULO"
                    color: Style.Theme.acento_fuerte
                    font.bold: true
                    font.pixelSize: 12 * root.sx
                }
                Text {
                    text: root.results.module_title || "Resultados"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 28 * root.sx
                }
            }
            Text {
                text: root.formatTime(root.results.duration_seconds)
                color: Style.Theme.texto_secundario_fuerte
                font.pixelSize: 14 * root.sx
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 112 * root.sy
            spacing: 12 * root.sx
            Repeater {
                model: [
                    { label: "PRE-TEST", value: (root.results.pre_percentage || 0) + "%", color: Style.Theme.info_fondo, textColor: Style.Theme.info_texto },
                    { label: "POST-TEST", value: (root.results.post_percentage || 0) + "%", color: Style.Theme.exito_fondo, textColor: Style.Theme.exito_texto },
                    { label: "DIFERENCIA", value: root.results.comparable ? (((root.results.delta_percentage || 0) >= 0 ? "+" : "") + (root.results.delta_percentage || 0) + " pts") : "—", color: Style.Theme.acento_fondo, textColor: Style.Theme.acento_fuerte },
                    { label: "MEJORA RELATIVA", value: root.results.comparable ? ((root.results.relative_improvement || 0) + "%") : "—", color: Style.Theme.formula_fondo, textColor: Style.Theme.formula_texto },
                    { label: "GANANCIA NORMALIZADA (g)", value: root.results.comparable ? root.formatGain(root.results.normalized_gain) : "—", color: Style.Theme.concepto_fondo, textColor: Style.Theme.concepto_texto }
                ]
                delegate: Rectangle {
                    id: metricCard
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12 * root.sx
                    color: metricCard.modelData.color
                    Column {
                        anchors.centerIn: parent
                        spacing: 5
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: metricCard.modelData.value; color: metricCard.modelData.textColor; font.bold: true; font.pixelSize: 28 * root.sx }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: metricCard.modelData.label; color: metricCard.modelData.textColor; font.bold: true; font.pixelSize: 11 * root.sx }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14 * root.sx

            RectanglePrincipal {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sx: root.sx
                sy: root.sy
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16 * root.sx
                    spacing: 8 * root.sy
                    Text { text: "Rendimiento por concepto"; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 17 * root.sx }
                    ScrollView {
                        id: conceptScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: availableWidth
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ColumnLayout {
                            width: conceptScroll.availableWidth
                            spacing: 7 * root.sy
                            Repeater {
                                model: root.results.concepts || []
                                delegate: Rectangle {
                                    id: conceptRow
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 58 * root.sy
                                    radius: 8 * root.sx
                                    color: Style.Theme.superficie_alterna
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 9 * root.sx
                                        Text { Layout.preferredWidth: 190 * root.sx; text: conceptRow.modelData.name; color: Style.Theme.texto_primario; font.pixelSize: 12 * root.sx; wrapMode: Text.WordWrap }
                                        ProgressBar { Layout.fillWidth: true; from: 0; to: 100; value: conceptRow.modelData.post_percentage }
                                        Text { Layout.preferredWidth: 52 * root.sx; text: conceptRow.modelData.assessed_post ? conceptRow.modelData.post_percentage + "%" : "—"; color: Style.Theme.acento_fuerte; font.bold: true; horizontalAlignment: Text.AlignRight; font.pixelSize: 12 * root.sx }
                                        Text { Layout.preferredWidth: 58 * root.sx; text: conceptRow.modelData.comparable ? ((conceptRow.modelData.delta_percentage >= 0 ? "+" : "") + conceptRow.modelData.delta_percentage) : "—"; color: conceptRow.modelData.delta_percentage >= 0 ? Style.Theme.exito_texto : Style.Theme.error_texto; horizontalAlignment: Text.AlignRight; font.pixelSize: 11 * root.sx }
                                        Text { Layout.preferredWidth: 58 * root.sx; text: "g " + root.formatGain(conceptRow.modelData.normalized_gain); color: Style.Theme.concepto_texto; horizontalAlignment: Text.AlignRight; font.pixelSize: 11 * root.sx }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.preferredWidth: 390 * root.sx
                Layout.fillHeight: true
                spacing: 10 * root.sy
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12 * root.sx
                    color: Style.Theme.exito_fondo
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14 * root.sx
                        Text { text: "Conceptos dominados"; color: Style.Theme.exito_texto; font.bold: true; font.pixelSize: 15 * root.sx }
                        Text { Layout.fillWidth: true; Layout.fillHeight: true; text: (root.results.mastered || []).length ? (root.results.mastered || []).join(" · ") : "Aún no hay conceptos evaluados por encima de 80%."; color: Style.Theme.exito_texto; wrapMode: Text.WordWrap; font.pixelSize: 12 * root.sx }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12 * root.sx
                    color: Style.Theme.aviso_fondo
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14 * root.sx
                        Text { text: "Necesitan refuerzo"; color: Style.Theme.aviso_texto; font.bold: true; font.pixelSize: 15 * root.sx }
                        Text { Layout.fillWidth: true; visible: !(root.results.recommendations || []).length; text: "Ningún concepto evaluado quedó por debajo de 70%."; color: Style.Theme.aviso_texto; wrapMode: Text.WordWrap; font.pixelSize: 12 * root.sx }
                        // Cada recomendación lleva al paso exacto del recorrido
                        // y nombra el reto de laboratorio del mismo concepto.
                        ScrollView {
                            id: recommendationScroll
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: availableWidth
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            ColumnLayout {
                                width: recommendationScroll.availableWidth
                                spacing: 6 * root.sy
                                Repeater {
                                    model: root.results.recommendations || []
                                    delegate: ColumnLayout {
                                        id: recommendation
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        spacing: 3 * root.sy
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { Layout.fillWidth: true; text: recommendation.modelData.name; color: Style.Theme.aviso_texto; font.bold: true; wrapMode: Text.WordWrap; font.pixelSize: 12 * root.sx }
                                            BotonSecundario {
                                                objectName: "moduleResultsReviewStep" + recommendation.index
                                                visible: recommendation.modelData.step && recommendation.modelData.step.index !== undefined
                                                sx: root.sx; sy: root.sy
                                                Layout.preferredWidth: 120 * root.sx
                                                text: "Repasar paso " + (Number((recommendation.modelData.step || {}).index || 0) + 1)
                                                onClicked: root.openStep(recommendation.modelData.step)
                                            }
                                        }
                                        Text { Layout.fillWidth: true; visible: String(recommendation.modelData.lab_prompt || "").length > 0; text: "En el laboratorio: " + recommendation.modelData.lab_prompt; color: Style.Theme.aviso_texto; wrapMode: Text.WordWrap; font.pixelSize: 10.5 * root.sx }
                                    }
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 90 * root.sy
                    radius: 12 * root.sx
                    color: Style.Theme.acento_fondo
                    Text {
                        anchors.fill: parent
                        anchors.margins: 13 * root.sx
                        text: root.results.recommendation || ""
                        color: Style.Theme.acento_fuerte
                        font.bold: true
                        font.pixelSize: 12 * root.sx
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12 * root.sx
            BotonPrincipal {
                objectName: "moduleResultsOpenReview"
                visible: (root.results.review || []).length > 0
                Layout.preferredWidth: 260 * root.sx
                Layout.preferredHeight: 46 * root.sy
                text: "Revisar mis respuestas del post-test"
                onClicked: reviewPopup.open()
            }
            BotonPrincipal {
                Layout.preferredWidth: 230 * root.sx
                Layout.preferredHeight: 46 * root.sy
                text: "Ver todos los módulos"
                onClicked: root.stackView.push("ModuleMapScreen.qml", { "stackView": root.stackView })
            }
            BotonPrincipal {
                visible: root.moduleId !== "module_8"
                Layout.preferredWidth: 240 * root.sx
                Layout.preferredHeight: 46 * root.sy
                text: "Continuar al siguiente módulo →"
                onClicked: root.stackView.push("ModuleScreen.qml", {
                    "stackView": root.stackView,
                    "moduleId": root.courseController.currentModuleId
                })
            }
        }
    }

    // Revisión del post-test: respuesta correcta, explicación y el paso del
    // recorrido que la enseña. El pre-test nunca se revisa así (medición).
    Popup {
        id: reviewPopup
        objectName: "moduleResultsReviewPopup"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(root.width - 60 * root.sx, 860 * root.sx)
        height: Math.min(root.height - 60 * root.sy, 640 * root.sy)
        modal: true
        focus: true
        padding: 16 * root.sx
        background: Rectangle {
            radius: 14 * root.sx
            color: Style.Theme.surface
            border.color: Style.Theme.borde_suave
        }

        contentItem: ColumnLayout {
            spacing: 10 * root.sy
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Revisión del post-test"
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 18 * root.sx
                }
                BotonSecundario {
                    sx: root.sx; sy: root.sy
                    Layout.preferredWidth: 90 * root.sx
                    text: "Cerrar"
                    onClicked: reviewPopup.close()
                }
            }
            ListView {
                id: reviewList
                objectName: "moduleResultsReviewList"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8 * root.sy
                model: root.results.review || []
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    id: reviewRow
                    required property var modelData
                    required property int index
                    width: reviewList.width - 12 * root.sx
                    height: reviewColumn.implicitHeight + 16 * root.sy
                    radius: 10 * root.sx
                    color: reviewRow.modelData.correct ? Style.Theme.exito_fondo : Style.Theme.aviso_fondo
                    ColumnLayout {
                        id: reviewColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8 * root.sx
                        spacing: 4 * root.sy
                        Text {
                            Layout.fillWidth: true
                            text: (reviewRow.modelData.correct ? "✓ " : "✗ ") + (reviewRow.index + 1) + ". "
                                  + reviewRow.modelData.prompt
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: 12 * root.sx
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: !reviewRow.modelData.correct && String(reviewRow.modelData.correct_text || "").length > 0
                            text: "Respuesta correcta: " + reviewRow.modelData.correct_text
                            color: Style.Theme.aviso_texto
                            font.pixelSize: 11 * root.sx
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: String(reviewRow.modelData.explanation || "").length > 0
                            text: "Por qué: " + reviewRow.modelData.explanation
                            color: Style.Theme.texto_secundario_fuerte
                            font.pixelSize: 11 * root.sx
                            wrapMode: Text.WordWrap
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: "Concepto: " + reviewRow.modelData.concept_name
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 10 * root.sx
                            }
                            BotonSecundario {
                                visible: !reviewRow.modelData.correct && reviewRow.modelData.step
                                         && reviewRow.modelData.step.index !== undefined
                                sx: root.sx; sy: root.sy
                                Layout.preferredWidth: 150 * root.sx
                                text: "Ir al paso " + (Number((reviewRow.modelData.step || {}).index || 0) + 1)
                                onClicked: {
                                    reviewPopup.close()
                                    root.openStep(reviewRow.modelData.step)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
