pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root
    objectName: "evaluationIntroScreen"

    property string assessmentType: "pre"
    property string moduleId: ""
    readonly property var evaluationController: moduleId.length > 0
                                                ? mainViewModel.moduleEvaluationController
                                                : mainViewModel.evaluationController
    readonly property bool isPreTest: assessmentType === "pre"
    readonly property bool isModuleEvaluation: moduleId.length > 0
    property string errorMessage: ""

    function prepareAssessment() {
        if (root.moduleId.length > 0)
            root.evaluationController.prepareModuleEvaluation(root.moduleId, root.assessmentType)
        else
            root.evaluationController.prepareEvaluation(root.assessmentType)
    }

    function startAssessment() {
        if (root.moduleId.length > 0)
            root.evaluationController.startModuleEvaluation(root.moduleId, root.assessmentType)
        else
            root.evaluationController.startEvaluation(root.assessmentType)
    }

    Component.onCompleted: prepareAssessment()

    Connections {
        target: root.evaluationController
        function onError(message) { root.errorMessage = message }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 40 * root.sx
        anchors.rightMargin: 40 * root.sx
        anchors.topMargin: 28 * root.sy
        anchors.bottomMargin: 30 * root.sy
        spacing: 16 * root.sy

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 74 * root.sy
            spacing: 20 * root.sx

            BotonPrincipal {
                objectName: "evaluationIntroBackButton"
                Layout.preferredWidth: 210 * root.sx
                Layout.preferredHeight: 48 * root.sy
                text: "← Volver al inicio"
                onClicked: root.stackView.pop()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3 * root.sy

                Text {
                    Layout.fillWidth: true
                    text: root.evaluationController.eyebrow
                    color: root.isPreTest ? Style.Theme.info_texto : Style.Theme.acento_fuerte
                    font.pixelSize: 14 * root.sx
                    font.bold: true
                    font.letterSpacing: 1
                }
                Text {
                    objectName: "evaluationIntroTitle"
                    Layout.fillWidth: true
                    text: root.evaluationController.title
                    color: Style.Theme.texto_primario
                    font.pixelSize: 34 * root.sx
                    font.bold: true
                }
            }

            Rectangle {
                Layout.preferredWidth: 175 * root.sx
                Layout.preferredHeight: 38 * root.sy
                radius: height / 2
                color: root.isPreTest ? Style.Theme.info_fondo : Style.Theme.acento_fondo
                border.color: root.isPreTest ? Style.Theme.info : Style.Theme.acento

                Text {
                    anchors.centerIn: parent
                    text: root.isModuleEvaluation
                          ? String(root.evaluationController.forma || "EVALUACIÓN").toUpperCase()
                          : (root.isPreTest ? "FORMA A" : "FORMA B")
                    color: root.isPreTest ? Style.Theme.info_texto : Style.Theme.acento_fuerte
                    font.pixelSize: 13 * root.sx
                    font.bold: true
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 24 * root.sx

            RectanglePrincipal {
                objectName: "evaluationIntroContentCard"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 650 * root.sx
                sx: root.sx
                sy: root.sy

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24 * root.sx
                    spacing: 12 * root.sy

                    Text {
                        Layout.fillWidth: true
                        text: root.isPreTest
                              ? "Descubre tu punto de partida"
                              : "Comprueba cuánto aprendiste"
                        color: Style.Theme.texto_primario
                        font.pixelSize: 29 * root.sx
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.evaluationController.description
                        color: Style.Theme.texto_secundario_fuerte
                        font.pixelSize: 18 * root.sx
                        lineHeight: 1.25
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: instructionText.implicitHeight + 28 * root.sy
                        radius: 10 * root.sx
                        color: root.isPreTest ? Style.Theme.info_fondo : Style.Theme.acento_fondo
                        border.color: root.isPreTest ? Style.Theme.info : Style.Theme.acento_alt

                        Text {
                            id: instructionText
                            anchors.fill: parent
                            anchors.margins: 14 * root.sx
                            text: root.evaluationController.instructions
                            color: root.isPreTest ? Style.Theme.info_texto : Style.Theme.acento_fuerte
                            font.pixelSize: 15 * root.sx
                            wrapMode: Text.WordWrap
                        }
                    }

                    Text {
                        text: "¿QUÉ SE EVALÚA?"
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 12 * root.sx
                        font.bold: true
                        font.letterSpacing: 0.8
                    }

                    // Un módulo expone ocho dimensiones. La lista anterior
                    // las apilaba en filas fijas y las últimas quedaban fuera
                    // de la tarjeta. La cuadrícula aprovecha el ancho y deja
                    // desplazamiento vertical como respaldo.
                    ScrollView {
                        id: dimensionsScroll
                        objectName: "evaluationDimensionsScroll"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: availableWidth
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: contentHeight > availableHeight + 2
                                                   ? ScrollBar.AsNeeded
                                                   : ScrollBar.AlwaysOff

                        GridLayout {
                            id: dimensionGrid
                            objectName: "evaluationDimensionGrid"
                            width: dimensionsScroll.availableWidth
                            columns: root.isModuleEvaluation && width >= 560 * root.sx ? 2 : 1
                            rowSpacing: 10 * root.sy
                            columnSpacing: 10 * root.sx

                            Repeater {
                                model: root.evaluationController.dimensions
                                delegate: Rectangle {
                                    id: dimensionCard
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: (dimensionGrid.width
                                                            - dimensionGrid.columnSpacing
                                                              * (dimensionGrid.columns - 1))
                                                           / dimensionGrid.columns
                                    Layout.preferredHeight: 58 * root.sy
                                    radius: 9 * root.sx
                                    color: Style.Theme.superficie_alterna
                                    border.color: Style.Theme.borde_medio

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 13 * root.sx
                                        anchors.rightMargin: 13 * root.sx
                                        spacing: 9 * root.sx

                                        Rectangle {
                                            Layout.preferredWidth: 30 * root.sx
                                            Layout.preferredHeight: 30 * root.sy
                                            radius: width / 2
                                            color: Style.Theme.acento_fondo
                                            Text { anchors.centerIn: parent; text: "✓"; color: Style.Theme.acento_fuerte; font.bold: true }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: dimensionCard.modelData.name
                                            color: Style.Theme.texto_primario
                                            font.pixelSize: 14 * root.sx
                                            font.bold: true
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: dimensionCard.modelData.question_count
                                                  + (dimensionCard.modelData.question_count === 1
                                                     ? " pregunta" : " preguntas")
                                            color: Style.Theme.texto_secundario
                                            font.pixelSize: 11 * root.sx
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RectanglePrincipal {
                Layout.preferredWidth: 400 * root.sx
                Layout.minimumWidth: 360 * root.sx
                Layout.fillHeight: true
                sx: root.sx
                sy: root.sy

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24 * root.sx
                    spacing: 12 * root.sy

                    Text { text: "Antes de comenzar"; color: Style.Theme.texto_primario; font.pixelSize: 25 * root.sx; font.bold: true }

                    Repeater {
                        model: root.isModuleEvaluation ? [
                            "Responde según el formato: elegir, seleccionar, ordenar, relacionar o escribir.",
                            "El intento combina 5 preguntas básicas, 5 intermedias y 5 avanzadas.",
                            "No se mostrará si acertaste hasta terminar.",
                            "Cada intento combina memoria, comprensión, aplicación y razonamiento."
                        ] : [
                            "Responde según el formato: elegir, ordenar, relacionar o escribir.",
                            "Debes responder para poder avanzar.",
                            "No se mostrará si acertaste hasta terminar.",
                            "Tus respuestas no modifican el modelo Transformer."
                        ]
                        delegate: RowLayout {
                            id: ruleRow
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 10 * root.sx
                            Text { text: "•"; color: Style.Theme.acento; font.pixelSize: 20 * root.sx; font.bold: true }
                            Text {
                                Layout.fillWidth: true
                                text: ruleRow.modelData
                                color: Style.Theme.texto_secundario_fuerte
                                font.pixelSize: 15 * root.sx
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 86 * root.sy
                        radius: 10 * root.sx
                        color: Style.Theme.chip_fondo
                        border.color: Style.Theme.chip_borde

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14 * root.sx
                            spacing: 12 * root.sx
                            ColumnLayout {
                                Layout.fillWidth: true
                                Text { text: "PREGUNTAS"; color: Style.Theme.texto_secundario; font.pixelSize: 10 * root.sx; font.bold: true }
                                Text { text: root.evaluationController.totalQuestions; color: Style.Theme.texto_primario; font.pixelSize: 26 * root.sx; font.bold: true }
                            }
                            Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Style.Theme.divisor }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Text { text: "DIMENSIONES"; color: Style.Theme.texto_secundario; font.pixelSize: 10 * root.sx; font.bold: true }
                                Text { text: root.evaluationController.dimensions.length; color: Style.Theme.texto_primario; font.pixelSize: 26 * root.sx; font.bold: true }
                            }
                            Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Style.Theme.divisor }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Text { text: "TIEMPO APROX."; color: Style.Theme.texto_secundario; font.pixelSize: 10 * root.sx; font.bold: true }
                                Text {
                                    text: root.isModuleEvaluation ? "15-25 min" : "30-40 min"
                                    color: Style.Theme.texto_primario
                                    font.pixelSize: 20 * root.sx
                                    font.bold: true
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: root.evaluationController.hasPreviousResult
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? 60 * root.sy : 0
                        radius: 8 * root.sx
                        color: Style.Theme.exito_fondo
                        Text {
                            anchors.centerIn: parent
                            text: "Último resultado: " + root.evaluationController.previousResult.puntaje + "/"
                                  + root.evaluationController.previousResult.maximo + " ("
                                  + root.evaluationController.previousResult.percentage + "%)"
                            color: Style.Theme.exito_texto
                            font.pixelSize: 14 * root.sx
                            font.bold: true
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        visible: root.errorMessage !== ""
                        Layout.fillWidth: true
                        text: root.errorMessage
                        color: Style.Theme.error_texto
                        wrapMode: Text.WordWrap
                    }

                    BotonPrincipal {
                        objectName: "evaluationStartButton"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52 * root.sy
                        minimum_text_size: 13
                        text: root.evaluationController.hasPreviousResult
                              ? "Repetir " + root.evaluationController.title.toLowerCase()
                              : "Comenzar " + root.evaluationController.title.toLowerCase()
                        onClicked: {
                            root.errorMessage = ""
                            root.startAssessment()
                            if (root.evaluationController.isActive) {
                                root.stackView.push("EvaluationScreen.qml", {
                                    "stackView": root.stackView,
                                    "assessmentType": root.assessmentType,
                                    "moduleId": root.moduleId
                                })
                            }
                        }
                    }
                }
            }
        }
    }
}
