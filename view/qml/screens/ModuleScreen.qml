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
    readonly property int moduleProgress: Number(moduleData.progress_percent || 0)
    readonly property int completedStages: Number(moduleData.completed_stages || 0)
    readonly property real pageMargin: Math.max(22, Math.min(34, width * 0.027))
    readonly property real pageGap: Math.max(10, 12 * root.sy)
    readonly property real minimumJourneyWidth: 1110
    readonly property var stages: [
        { id: "pretest", number: "01", eyebrow: "DIAGNÓSTICO", title: "Pre-test", subtitle: "15 de 25 preguntas aleatorias", route: "EvaluationIntroScreen.qml" },
        { id: "guided", number: "02", eyebrow: "APRENDE", title: "Recorrido guiado", subtitle: "8 pasos breves y reproducibles", route: "ModuleGuidedTourScreen.qml" },
        { id: "laboratory", number: "03", eyebrow: "PRÁCTICA", title: "Laboratorio especializado", subtitle: "Entrenamiento e inferencia del componente", route: "ModuleLaboratoryScreen.qml" },
        { id: "posttest", number: "04", eyebrow: "COMPRUEBA", title: "Post-test", subtitle: "15 reactivos equivalentes y distintos", route: "EvaluationIntroScreen.qml" },
        { id: "results", number: "05", eyebrow: "REFLEXIONA", title: "Resultados", subtitle: "Mejora, dominio y recomendaciones", route: "ModuleResultsScreen.qml" }
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

    function stageAccent(stageId) {
        switch (String(stageId)) {
        case "pretest": return Style.Theme.inferencia_estructura
        case "guided": return Style.Theme.inferencia_transformacion
        case "laboratory": return Style.Theme.inferencia_contexto
        case "posttest": return Style.Theme.inferencia_foco
        default: return Style.Theme.inferencia_resultado
        }
    }

    function stageOnAccent(stageId) {
        switch (String(stageId)) {
        case "pretest": return Style.Theme.inferencia_sobre_estructura
        case "guided": return Style.Theme.inferencia_sobre_transformacion
        case "laboratory": return Style.Theme.inferencia_sobre_contexto
        case "posttest": return Style.Theme.inferencia_sobre_foco
        default: return Style.Theme.inferencia_sobre_resultado
        }
    }

    function stageTint(stageId) {
        switch (String(stageId)) {
        case "pretest": return Style.Theme.info_fondo
        case "guided": return Style.Theme.concepto_fondo
        case "laboratory": return Style.Theme.proceso_fondo
        case "posttest": return Style.Theme.formula_fondo
        default: return Style.Theme.exito_fondo
        }
    }

    function stageInk(stageId) {
        switch (String(stageId)) {
        case "pretest": return Style.Theme.info_texto
        case "guided": return Style.Theme.concepto_texto
        case "laboratory": return Style.Theme.proceso_texto
        case "posttest": return Style.Theme.formula_texto
        default: return Style.Theme.exito_texto
        }
    }

    ScrollView {
        id: pageScroll
        objectName: "modulePageScroll"
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            id: pageContent
            objectName: "modulePageContent"
            width: pageScroll.availableWidth
            spacing: root.pageGap

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.pageGap
            }

            RowLayout {
                id: navigationRow
                Layout.fillWidth: true
                Layout.leftMargin: root.pageMargin
                Layout.rightMargin: root.pageMargin
                spacing: 12 * root.sx

                BotonSecundario {
                    objectName: "moduleBackButton"
                    Layout.preferredWidth: 176 * root.sx
                    Layout.preferredHeight: 40 * root.sy
                    sx: root.sx
                    sy: root.sy
                    text: "←  Todos los módulos"
                    Accessible.description: "Regresa al mapa completo del curso"
                    onClicked: root.stackView.pop()
                }

                Rectangle {
                    Layout.preferredWidth: 180 * root.sx
                    Layout.preferredHeight: 34 * root.sy
                    radius: height / 2
                    color: Style.Theme.acento_fondo
                    border.width: 1
                    border.color: Style.Theme.acento_alt

                    Text {
                        anchors.centerIn: parent
                        text: "RUTA · " + root.stages.length + " ETAPAS"
                        color: Style.Theme.acento_fuerte
                        font.pixelSize: Math.max(10, 11 * root.sx)
                        font.bold: true
                        font.letterSpacing: 0.8
                    }
                }

                // El extremo derecho queda libre para los controles globales
                // de tema, vista dual y estado del aula de main.qml.
                Item { Layout.fillWidth: true }

                AparicionSuave { objetivo: navigationRow; orden: 0 }
            }

            Rectangle {
                id: heroCard
                Layout.fillWidth: true
                Layout.leftMargin: root.pageMargin
                Layout.rightMargin: root.pageMargin
                Layout.preferredHeight: 206 * root.sy
                radius: 20 * root.sx
                clip: true
                border.width: 1
                border.color: Style.Theme.acento_alt

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Style.Theme.acento_fondo }
                    GradientStop { position: 0.72; color: Style.Theme.surface }
                    GradientStop { position: 1; color: Style.Theme.concepto_fondo }
                }

                // Motivo sutil inspirado en una red: aporta profundidad sin
                // competir con el título ni convertirse en información.
                Item {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: 390 * root.sx
                    height: parent.height
                    opacity: Style.Theme.modoOscuro ? 0.18 : 0.28
                    Accessible.ignored: true

                    Rectangle {
                        x: 62 * root.sx; y: 28 * root.sy
                        width: 150 * root.sx; height: 2
                        rotation: 18
                        color: Style.Theme.acento
                    }
                    Rectangle {
                        x: 120 * root.sx; y: 112 * root.sy
                        width: 170 * root.sx; height: 2
                        rotation: -20
                        color: Style.Theme.acento_alt
                    }
                    Repeater {
                        model: [
                            { x: 48, y: 25, size: 14 },
                            { x: 190, y: 70, size: 22 },
                            { x: 112, y: 150, size: 16 },
                            { x: 286, y: 105, size: 13 }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            x: modelData.x * root.sx
                            y: modelData.y * root.sy
                            width: modelData.size * root.sx
                            height: modelData.size * root.sx
                            radius: width / 2
                            color: Style.Theme.surface
                            border.width: 2
                            border.color: Style.Theme.acento
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 24 * root.sx
                    spacing: 24 * root.sx

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: 66 * root.sx
                        Layout.preferredHeight: 66 * root.sx
                        radius: 18 * root.sx
                        color: Style.Theme.acento

                        Column {
                            anchors.centerIn: parent
                            spacing: -2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "MÓDULO"
                                color: Style.Theme.texto_sobre_acento
                                font.pixelSize: Math.max(8, 9 * root.sx)
                                font.bold: true
                                font.letterSpacing: 0.5
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.moduleData.order || ""
                                color: Style.Theme.texto_sobre_acento
                                font.pixelSize: 29 * root.sx
                                font.bold: true
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 7 * root.sy

                        Text {
                            Layout.fillWidth: true
                            text: root.moduleProgress === 100
                                  ? "MÓDULO COMPLETADO"
                                  : "TU PRÓXIMO BLOQUE DE APRENDIZAJE"
                            color: Style.Theme.acento_fuerte
                            font.bold: true
                            font.pixelSize: Math.max(10, 11 * root.sx)
                            font.letterSpacing: 1.05
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.moduleData.title || ""
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: Math.max(26, 34 * root.sx)
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.moduleData.description || ""
                            color: Style.Theme.texto_secundario_fuerte
                            font.pixelSize: Math.max(13, 15 * root.sx)
                            lineHeight: 1.2
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 216 * root.sx
                        Layout.preferredHeight: 154 * root.sy
                        Layout.alignment: Qt.AlignVCenter
                        radius: 16 * root.sx
                        color: Style.Theme.surface
                        border.width: 1
                        border.color: Style.Theme.borde_suave

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16 * root.sx
                            spacing: 7 * root.sy

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "TU PROGRESO"
                                    color: Style.Theme.texto_secundario
                                    font.pixelSize: Math.max(9, 10 * root.sx)
                                    font.bold: true
                                    font.letterSpacing: 0.8
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    Layout.preferredWidth: 30 * root.sx
                                    Layout.preferredHeight: 30 * root.sx
                                    radius: width / 2
                                    color: root.moduleProgress === 100
                                           ? Style.Theme.exito_fondo : Style.Theme.acento_fondo
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.moduleProgress === 100 ? "✓" : "↗"
                                        color: root.moduleProgress === 100
                                               ? Style.Theme.exito_texto : Style.Theme.acento_fuerte
                                        font.family: Style.Theme.fuente_simbolos
                                        font.pixelSize: 15 * root.sx
                                        font.bold: true
                                    }
                                }
                            }
                            Text {
                                text: root.moduleProgress + "%"
                                color: Style.Theme.texto_primario
                                font.pixelSize: 35 * root.sx
                                font.bold: true
                            }
                            Text {
                                text: root.completedStages + " de " + root.stages.length
                                      + " etapas completadas"
                                color: Style.Theme.texto_secundario_fuerte
                                font.pixelSize: Math.max(10, 11 * root.sx)
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 7 * root.sy
                                radius: height / 2
                                color: Style.Theme.borde_medio

                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(100, root.moduleProgress)) / 100
                                    height: parent.height
                                    radius: height / 2
                                    color: root.moduleProgress === 100
                                           ? Style.Theme.success : Style.Theme.acento
                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Style.Theme.movimientoReducido
                                                      ? 0 : Style.Theme.duracionMedia
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                AparicionSuave { objetivo: heroCard; orden: 1 }
            }

            Rectangle {
                id: objectivesCard
                Layout.fillWidth: true
                Layout.leftMargin: root.pageMargin
                Layout.rightMargin: root.pageMargin
                Layout.preferredHeight: 106 * root.sy
                radius: 16 * root.sx
                color: Style.Theme.surface
                border.width: 1
                border.color: Style.Theme.borde_suave

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14 * root.sx
                    spacing: 10 * root.sx

                    ColumnLayout {
                        Layout.preferredWidth: 156 * root.sx
                        spacing: 3

                        Text {
                            text: "EN ESTE MÓDULO"
                            color: Style.Theme.acento_fuerte
                            font.pixelSize: Math.max(9, 10 * root.sx)
                            font.bold: true
                            font.letterSpacing: 0.7
                        }
                        Text {
                            text: "Vas a lograr"
                            color: Style.Theme.texto_primario
                            font.pixelSize: Math.max(16, 18 * root.sx)
                            font.bold: true
                        }
                        Text {
                            text: (root.moduleData.objectives || []).length
                                  + " objetivos clave"
                            color: Style.Theme.texto_secundario
                            font.pixelSize: Math.max(10, 11 * root.sx)
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        Layout.topMargin: 5 * root.sy
                        Layout.bottomMargin: 5 * root.sy
                        color: Style.Theme.divisor
                    }

                    Repeater {
                        model: root.moduleData.objectives || []
                        delegate: Rectangle {
                            id: objectiveChip
                            required property int index
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 12 * root.sx
                            color: Style.Theme.concepto_fondo
                            border.width: 1
                            border.color: Style.Theme.acento_suave

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 11 * root.sx
                                spacing: 9 * root.sx

                                Rectangle {
                                    Layout.preferredWidth: 28 * root.sx
                                    Layout.preferredHeight: 28 * root.sx
                                    radius: width / 2
                                    color: Style.Theme.acento
                                    Text {
                                        anchors.centerIn: parent
                                        text: objectiveChip.index + 1
                                        color: Style.Theme.texto_sobre_acento
                                        font.pixelSize: 11 * root.sx
                                        font.bold: true
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: objectiveChip.modelData
                                    color: Style.Theme.concepto_texto
                                    font.pixelSize: Math.max(10, 11.5 * root.sx)
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }

                AparicionSuave { objetivo: objectivesCard; orden: 2 }
            }

            RowLayout {
                id: journeyHeader
                Layout.fillWidth: true
                Layout.leftMargin: root.pageMargin
                Layout.rightMargin: root.pageMargin
                spacing: 10 * root.sx

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Tu ruta dentro del módulo"
                        color: Style.Theme.texto_primario
                        font.pixelSize: Math.max(19, 22 * root.sx)
                        font.bold: true
                    }
                    Text {
                        text: "Avanza a tu ritmo; cada etapa prepara la siguiente."
                        color: Style.Theme.texto_secundario
                        font.pixelSize: Math.max(11, 12 * root.sx)
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 130 * root.sx
                    Layout.preferredHeight: 28 * root.sy
                    radius: height / 2
                    color: Style.Theme.chip_fondo
                    border.width: 1
                    border.color: Style.Theme.chip_borde
                    Text {
                        anchors.centerIn: parent
                        text: root.completedStages + " / " + root.stages.length + " LISTAS"
                        color: Style.Theme.chip_texto
                        font.pixelSize: Math.max(9, 10 * root.sx)
                        font.bold: true
                        font.letterSpacing: 0.5
                    }
                }

                AparicionSuave { objetivo: journeyHeader; orden: 3 }
            }

            ScrollView {
                id: stageScroll
                objectName: "moduleStageScroll"
                Layout.fillWidth: true
                Layout.leftMargin: root.pageMargin
                Layout.rightMargin: root.pageMargin
                // En pantallas panoramicas (y, en especial, con escalado de
                // Windows), la tipografia crece con sx mas que la tarjeta con
                // sy. El laboratorio usa dos lineas de titulo y subtitulo;
                // este minimo evita que su boton salga por debajo del borde.
                Layout.preferredHeight: Math.max(220, 272 * root.sy,
                                                 250 * root.sx)
                clip: true
                contentWidth: Math.max(availableWidth, root.minimumJourneyWidth * root.sx)
                contentHeight: availableHeight
                ScrollBar.horizontal.policy: contentWidth > availableWidth
                                             ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                RowLayout {
                    width: stageScroll.contentWidth
                    height: stageScroll.availableHeight
                    spacing: 12 * root.sx

                    Repeater {
                        model: root.stages
                        delegate: Rectangle {
                            id: stageCard
                            objectName: "moduleStageCard_" + stageCard.index
                            required property int index
                            required property var modelData
                            readonly property bool available: root.courseController.stageAvailable(root.moduleId, modelData.id)
                            readonly property bool completed: root.courseController.stageCompleted(root.moduleId, modelData.id)
                            readonly property bool current: String(root.moduleData.current_stage || "") === modelData.id
                            readonly property color accent: root.stageAccent(modelData.id)
                            readonly property color onAccent: root.stageOnAccent(modelData.id)
                            readonly property color tint: root.stageTint(modelData.id)
                            readonly property color ink: root.stageInk(modelData.id)

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumWidth: 210 * root.sx
                            radius: 15 * root.sx
                            color: !available ? Style.Theme.superficie_alterna
                                              : (completed ? Style.Theme.exito_fondo
                                                           : (cardHover.hovered ? tint : Style.Theme.surface))
                            border.width: current || cardHover.hovered ? 2 : 1
                            border.color: completed ? Style.Theme.success
                                                    : (current || cardHover.hovered
                                                       ? accent : Style.Theme.borde_suave)
                            opacity: available ? 1 : 0.64

                            Behavior on color {
                                ColorAnimation { duration: Style.Theme.duracionCorta }
                            }
                            Behavior on border.color {
                                ColorAnimation { duration: Style.Theme.duracionCorta }
                            }

                            HoverHandler { id: cardHover }

                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 5 * root.sy
                                radius: stageCard.radius
                                color: stageCard.completed ? Style.Theme.success : stageCard.accent
                                opacity: stageCard.available ? 1 : 0.35
                            }

                            // Une visualmente los cinco hitos de la ruta.
                            Rectangle {
                                visible: stageCard.index < root.stages.length - 1
                                x: parent.width - 1
                                y: 38 * root.sy
                                width: 14 * root.sx
                                height: 2
                                color: stageCard.completed ? Style.Theme.success : Style.Theme.borde_suave
                                z: 4
                                Accessible.ignored: true
                            }

                            ColumnLayout {
                                id: stageContent
                                objectName: "moduleStageContent_" + stageCard.index
                                anchors.fill: parent
                                anchors.margins: 14 * root.sx
                                anchors.topMargin: 17 * root.sy
                                spacing: 8 * root.sy

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8 * root.sx

                                    Rectangle {
                                        Layout.preferredWidth: 42 * root.sx
                                        Layout.preferredHeight: 42 * root.sx
                                        radius: 12 * root.sx
                                        color: stageCard.completed
                                               ? Style.Theme.inferencia_resultado : stageCard.accent
                                        Text {
                                            anchors.centerIn: parent
                                            text: stageCard.completed ? "✓" : stageCard.modelData.number
                                            color: stageCard.completed
                                                   ? Style.Theme.inferencia_sobre_resultado
                                                   : stageCard.onAccent
                                            font.family: Style.Theme.fuente_simbolos
                                            font.pixelSize: stageCard.completed
                                                            ? 19 * root.sx : 14 * root.sx
                                            font.bold: true
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            Layout.fillWidth: true
                                            text: stageCard.modelData.eyebrow
                                            color: stageCard.completed
                                                   ? Style.Theme.exito_texto : stageCard.ink
                                            font.pixelSize: Math.max(8, 9 * root.sx)
                                            font.bold: true
                                            font.letterSpacing: 0.6
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: stageCard.completed ? "COMPLETADO"
                                                  : (stageCard.current ? "SIGUIENTE PASO"
                                                     : (stageCard.available ? "DISPONIBLE" : "BLOQUEADO"))
                                            color: stageCard.completed ? Style.Theme.exito_texto
                                                                      : Style.Theme.texto_secundario
                                            font.pixelSize: Math.max(8, 9 * root.sx)
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: stageCard.modelData.title
                                    color: Style.Theme.texto_primario
                                    font.bold: true
                                    font.pixelSize: Math.max(16, 18 * root.sx)
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: stageCard.modelData.subtitle
                                    color: Style.Theme.texto_secundario_fuerte
                                    font.pixelSize: Math.max(10, 11 * root.sx)
                                    lineHeight: 1.15
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32 * root.sy
                                    radius: 8 * root.sx
                                    color: stageCard.completed ? Style.Theme.exito_fondo
                                                               : (stageCard.available
                                                                  ? stageCard.tint : Style.Theme.chip_fondo)

                                    Text {
                                        anchors.fill: parent
                                        anchors.margins: 7 * root.sx
                                        text: stageCard.completed ? "Etapa terminada"
                                              : (stageCard.available ? "Lista para comenzar"
                                                 : root.courseController.stageBlockReason(root.moduleId,
                                                                                          stageCard.modelData.id))
                                        color: stageCard.completed ? Style.Theme.exito_texto
                                                                  : (stageCard.available
                                                                     ? stageCard.ink : Style.Theme.texto_terciario)
                                        font.pixelSize: Math.max(9, 10 * root.sx)
                                        font.bold: true
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }
                                }

                                Item { Layout.fillHeight: true }

                                BotonPrincipal {
                                    objectName: "moduleStageButton_" + stageCard.index
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 38 * root.sy
                                    enabled: stageCard.available
                                    opacity: enabled ? 1 : 0.45
                                    text: stageCard.completed ? "Revisar etapa"
                                          : (stageCard.current ? "Comenzar" : "Abrir etapa")
                                    Accessible.description: "Abre " + stageCard.modelData.title
                                    onClicked: root.openStage(stageCard.modelData)
                                }
                            }

                            AparicionSuave { objetivo: stageCard; orden: stageCard.index + 4 }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 18 * root.sy
            }
        }
    }
}
