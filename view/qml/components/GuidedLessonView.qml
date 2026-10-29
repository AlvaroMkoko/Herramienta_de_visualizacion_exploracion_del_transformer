pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// Lección de un paso del recorrido guiado, en una sola columna desplazable.
//
// Antes, el paso se repartía en tres ventanas (imagen, traza con la pregunta y
// teoría) y el estudiante no sabía a qué atender; además soltaba términos como
// d_model sin explicarlos. Aquí el paso se lee de arriba abajo, en el orden en
// que se aprende:
//
//   1. La idea        intuición en lenguaje cotidiano
//   2. Términos       cada palabra nueva, antes de usarla
//   3. Míralo         la visualización del paso
//   4. Paso a paso    el procedimiento, con fórmula donde ayuda
//   5. Con números    el ejemplo ancla resuelto
//   6. Resumen        entrada, operación, por qué, cambio, resultado y forma
//   7. Comprueba      la pregunta del paso, al final
//
// El contenido viene de `step.lesson` (data/aprendizaje/alineacion.json) y el
// resumen usa los mismos campos del paso que alimentan el pre y el post-test.
// `tour` es la pantalla del recorrido: de ella salen el paso actual, su
// comprobación y la acción de comprobar.
ScrollView {
    id: root
    objectName: "moduleGuidedLesson"

    property var tour: null

    readonly property real s: root.tour ? root.tour.uiScale : 1
    readonly property var step: root.tour ? root.tour.currentStep : ({})
    readonly property var lesson: root.step && root.step.lesson ? root.step.lesson : ({})
    readonly property var terminos: root.lesson.terminos || []
    readonly property var pasos: root.lesson.pasos || []
    readonly property var ejemplo: root.lesson.ejemplo || ({})
    readonly property var definicion: root.tour ? root.tour.currentConceptDefinition : ({})
    readonly property real anchoLectura: Math.min(root.availableWidth - 32 * root.s, 1040 * root.s)

    clip: true
    contentWidth: availableWidth
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ScrollBar.vertical.policy: ScrollBar.AsNeeded

    // Cada paso nuevo se empieza a leer desde arriba.
    Connections {
        target: root.tour
        function onCurrentIndexChanged() {
            root.contentItem.contentY = 0
            comprobacion.selectedIndex = -1
        }
    }

    component Seccion: ColumnLayout {
        id: seccion
        property string numero: ""
        property string titulo: ""
        Layout.fillWidth: true
        spacing: 10 * root.s

        RowLayout {
            Layout.fillWidth: true
            spacing: 10 * root.s
            Rectangle {
                visible: seccion.numero !== ""
                Layout.preferredWidth: 28 * root.s
                Layout.preferredHeight: 28 * root.s
                radius: width / 2
                color: Style.Theme.acento
                Text {
                    anchors.centerIn: parent
                    text: seccion.numero
                    color: Style.Theme.texto_sobre_acento
                    font.bold: true
                    font.pixelSize: 13 * root.s
                }
            }
            Text {
                Layout.fillWidth: true
                text: seccion.titulo
                color: Style.Theme.texto_primario
                font.bold: true
                font.pixelSize: 19 * root.s
                wrapMode: Text.WordWrap
            }
        }
    }

    component Parrafo: Text {
        Layout.fillWidth: true
        color: Style.Theme.texto_primario
        font.pixelSize: 16 * root.s
        lineHeight: 1.3
        wrapMode: Text.WordWrap
    }

    component Formula: Rectangle {
        id: formula
        property string texto: ""
        Layout.fillWidth: true
        Layout.preferredHeight: textoFormula.implicitHeight + 18 * root.s
        visible: formula.texto !== ""
        radius: 8 * root.s
        color: Style.Theme.formula_fondo
        Text {
            id: textoFormula
            anchors.fill: parent
            anchors.margins: 9 * root.s
            text: formula.texto
            color: Style.Theme.formula_texto
            font.family: Style.Theme.fuente_mono
            font.bold: true
            font.pixelSize: 15 * root.s
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignVCenter
        }
    }

    Item {
        width: root.availableWidth
        implicitHeight: columna.implicitHeight + 40 * root.s

        ColumnLayout {
            id: columna
            width: root.anchoLectura
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 8 * root.s
            spacing: 26 * root.s

            // ── Encabezado del paso ─────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4 * root.s
                Text {
                    text: "PASO " + ((root.tour ? root.tour.currentIndex : 0) + 1)
                          + " DE " + (root.tour ? root.tour.steps.length : 0)
                    color: Style.Theme.acento_fuerte
                    font.bold: true
                    font.pixelSize: 12 * root.s
                    font.letterSpacing: 0.8
                }
                Text {
                    objectName: "moduleGuidedLessonTitle"
                    Layout.fillWidth: true
                    text: String(root.step.title || "")
                    color: Style.Theme.texto_primario
                    font.bold: true
                    font.pixelSize: 30 * root.s
                    wrapMode: Text.WordWrap
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.tour ? root.tour.currentIsFocus : false
                    text: "★ En el pre-test fallaste reactivos de este concepto: tómate tu tiempo en este paso."
                    color: Style.Theme.aviso_texto
                    font.bold: true
                    font.pixelSize: 13 * root.s
                    wrapMode: Text.WordWrap
                }
            }

            // ── 1. La idea ──────────────────────────────────────────
            Seccion {
                numero: "1"
                titulo: "La idea"
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: textoIdea.implicitHeight + 32 * root.s
                    radius: 12 * root.s
                    color: Style.Theme.concepto_fondo
                    Text {
                        id: textoIdea
                        objectName: "moduleGuidedIntuition"
                        anchors.fill: parent
                        anchors.margins: 16 * root.s
                        text: String(root.lesson.intuicion || "")
                        color: Style.Theme.texto_primario
                        font.pixelSize: 17 * root.s
                        lineHeight: 1.35
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ── 2. Términos nuevos ──────────────────────────────────
            Seccion {
                numero: "2"
                titulo: "Términos que necesitas"
                visible: root.terminos.length > 0

                GridLayout {
                    Layout.fillWidth: true
                    columns: root.anchoLectura >= 720 * root.s ? 2 : 1
                    columnSpacing: 10 * root.s
                    rowSpacing: 10 * root.s

                    Repeater {
                        model: root.terminos
                        delegate: Rectangle {
                            id: tarjetaTermino
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: contenidoTermino.implicitHeight + 24 * root.s
                            Layout.alignment: Qt.AlignTop
                            radius: 10 * root.s
                            color: Style.Theme.surface
                            border.width: 1
                            border.color: Style.Theme.borde_suave
                            ColumnLayout {
                                id: contenidoTermino
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 12 * root.s
                                spacing: 4 * root.s
                                Text {
                                    Layout.fillWidth: true
                                    text: String(tarjetaTermino.modelData.termino)
                                    color: Style.Theme.concepto_texto
                                    font.bold: true
                                    font.pixelSize: 15 * root.s
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: String(tarjetaTermino.modelData.definicion)
                                    color: Style.Theme.texto_primario
                                    font.pixelSize: 14 * root.s
                                    lineHeight: 1.25
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }

            // ── 3. Míralo ───────────────────────────────────────────
            Seccion {
                numero: root.terminos.length > 0 ? "3" : "2"
                titulo: "Míralo"
                GuidedDemoVisualization {
                    objectName: "moduleGuidedVisualization"
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(300 * root.s, root.anchoLectura * 0.36)
                    conceptId: root.tour ? root.tour.currentTheoryConceptId : ""
                    stepId: String(root.step.id || "")
                    scaleFactor: root.s
                }
            }

            // ── 4. Paso a paso ──────────────────────────────────────
            Seccion {
                numero: root.terminos.length > 0 ? "4" : "3"
                titulo: "Paso a paso"
                Repeater {
                    model: root.pasos
                    delegate: RowLayout {
                        id: filaPaso
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 12 * root.s
                        Rectangle {
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 30 * root.s
                            Layout.preferredHeight: 30 * root.s
                            radius: width / 2
                            color: Style.Theme.acento_fondo
                            border.width: 1
                            border.color: Style.Theme.acento
                            Text {
                                anchors.centerIn: parent
                                text: String(filaPaso.index + 1)
                                color: Style.Theme.acento_fuerte
                                font.bold: true
                                font.pixelSize: 14 * root.s
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6 * root.s
                            Parrafo { text: String(filaPaso.modelData.texto || "") }
                            Formula { texto: String(filaPaso.modelData.formula || "") }
                        }
                    }
                }
            }

            // ── 5. Con números ──────────────────────────────────────
            Seccion {
                numero: root.terminos.length > 0 ? "5" : "4"
                titulo: "Con números: " + String(root.ejemplo.titulo || "")
                visible: (root.ejemplo.lineas || []).length > 0
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: lineasEjemplo.implicitHeight + 28 * root.s
                    radius: 12 * root.s
                    color: Style.Theme.ejemplo_fondo
                    ColumnLayout {
                        id: lineasEjemplo
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 14 * root.s
                        spacing: 6 * root.s
                        Repeater {
                            model: root.ejemplo.lineas || []
                            delegate: Text {
                                required property var modelData
                                Layout.fillWidth: true
                                text: String(modelData)
                                color: Style.Theme.texto_primario
                                font.family: Style.Theme.fuente_mono
                                font.pixelSize: 15 * root.s
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            // ── Resumen del paso ────────────────────────────────────
            Seccion {
                titulo: "Resumen del paso"

                Rectangle {
                    objectName: "moduleGuidedDefinition"
                    Layout.fillWidth: true
                    visible: String(root.definicion.description || "").length > 0
                    Layout.preferredHeight: textoDefinicion.implicitHeight + 24 * root.s
                    radius: 10 * root.s
                    color: Style.Theme.concepto_fondo
                    Text {
                        id: textoDefinicion
                        anchors.fill: parent
                        anchors.margins: 12 * root.s
                        text: "<b>" + String(root.definicion.title || "") + ":</b> "
                              + String(root.definicion.description || "")
                        textFormat: Text.StyledText
                        color: Style.Theme.concepto_texto
                        font.pixelSize: 15 * root.s
                        wrapMode: Text.WordWrap
                    }
                }

                Repeater {
                    model: [
                        { "etiqueta": "Recibe", "valor": root.step.input || "" },
                        { "etiqueta": "Operación", "valor": root.step.operation || "" },
                        { "etiqueta": "¿Por qué?", "valor": root.step.why || "" },
                        { "etiqueta": "Qué cambia", "valor": root.step.change || "" },
                        { "etiqueta": "Produce", "valor": root.step.output || "" },
                        { "etiqueta": "Forma", "valor": root.step.dimensions || "" }
                    ]
                    delegate: RowLayout {
                        id: filaResumen
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 14 * root.s
                        Text {
                            Layout.preferredWidth: 130 * root.s
                            Layout.alignment: Qt.AlignTop
                            text: String(filaResumen.modelData.etiqueta).toUpperCase()
                            color: Style.Theme.texto_secundario
                            font.bold: true
                            font.pixelSize: 12 * root.s
                            font.letterSpacing: 0.6
                        }
                        Text {
                            Layout.fillWidth: true
                            text: String(filaResumen.modelData.valor)
                            color: Style.Theme.texto_primario
                            font.family: filaResumen.modelData.etiqueta === "Forma"
                                         ? Style.Theme.fuente_mono : Style.Theme.fuente_interfaz
                            font.pixelSize: 15 * root.s
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: String(root.lesson.clave || "").length > 0
                    Layout.preferredHeight: textoClave.implicitHeight + 24 * root.s
                    radius: 10 * root.s
                    color: Style.Theme.proceso_fondo
                    Text {
                        id: textoClave
                        anchors.fill: parent
                        anchors.margins: 12 * root.s
                        text: "Para recordar: " + String(root.lesson.clave || "")
                        color: Style.Theme.proceso_texto
                        font.bold: true
                        font.pixelSize: 15 * root.s
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ── Comprueba ───────────────────────────────────────────
            Seccion {
                titulo: "Comprueba lo que entendiste"
                visible: root.tour ? root.tour.currentHasCheck : false

                PredictionCheck {
                    id: comprobacion
                    objectName: "moduleGuidedCheck"
                    Layout.fillWidth: true
                    sx: root.s * 1.3
                    eyebrow: "RESPONDE PARA PASAR AL SIGUIENTE PASO"
                    check: root.step.check || ({})
                    result: root.tour
                            ? (root.tour.checkResults[String(root.step.id || "")] || ({}))
                            : ({})
                    onSubmitted: function (optionIndex) { root.tour.submitCheck(optionIndex) }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12 * root.s
                Text {
                    Layout.fillWidth: true
                    text: "Siguiente: " + String(root.step.next || "fin del recorrido")
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 13 * root.s
                    wrapMode: Text.WordWrap
                }
                BotonSecundario {
                    objectName: "moduleGuidedDeepDive"
                    Layout.preferredWidth: 230 * root.s
                    Layout.preferredHeight: 40 * root.s
                    sx: root.s
                    sy: root.s
                    text: "Profundizar en la teoría"
                    onClicked: root.tour.openTheoryConcept(root.tour.currentTheoryConceptId)
                }
            }
        }
    }
}
