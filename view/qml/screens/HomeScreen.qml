pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root
    objectName: "homeScreen"

    readonly property real pageMargin: Math.max(20, Math.min(40, width * 0.032))
    readonly property real minimumFlowWidth: 1160
    readonly property int totalPlatformStages: 5
    readonly property var platformStageOrder: [1, 2, 3, 4, 5]
    readonly property var platformStageAvailability: [true, true, true, true, true]
    readonly property var learningController: (typeof mainViewModel !== "undefined"
                                               && mainViewModel.learningController)
                                              ? mainViewModel.learningController
                                              : null
    readonly property int completedUnitsCount: learningController
                                               ? Number(learningController.completedUnitsCount)
                                               : 0
    readonly property int totalUnitsCount: learningController
                                           ? Number(learningController.totalUnits)
                                           : 0
    readonly property int learningProgressPercent: learningController
                                                   ? Number(learningController.progressPercent)
                                                   : 0
    readonly property bool learningStarted: learningController
                                             && (completedUnitsCount > 0
                                                 || Number(learningController.lastUnitIndex) > 0
                                                 || Number(learningController.lastConceptIndex) > 0)
    readonly property string guidedActionLabel: learningStarted
                                                   ? "Continuar recorrido"
                                                   : "Comenzar recorrido"

    function isPlatformStageAvailable(stageOrder) {
        return stageOrder >= 1 && stageOrder <= totalPlatformStages
                ? platformStageAvailability[stageOrder - 1]
                : false
    }

    function openGuidedLearning() {
        root.stackView.push("GuidedLearningScreen.qml", {
            "stackView": root.stackView
        })
    }

    function openTestModule(stageOrder, moduleTitle, moduleDescription) {
        root.stackView.push("ModulePlaceholderScreen.qml", {
            "stackView": root.stackView,
            "stageNumber": stageOrder,
            "moduleTitle": moduleTitle,
            "moduleDescription": moduleDescription
        })
    }

    ScrollView {
        id: pageScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            width: pageScroll.availableWidth
            spacing: 16

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: root.pageMargin
                Layout.rightMargin: root.pageMargin
                spacing: 24

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        Layout.fillWidth: true
                        text: "Ruta de aprendizaje Transformer"
                        color: Style.Theme.texto_primario
                        font.pixelSize: Math.max(25, Math.min(34, root.width * 0.027))
                        font.bold: true
                        wrapMode: Text.WordWrap
                        Accessible.name: text
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Avanza en orden: diagnóstico, aprendizaje, práctica, evaluación y seguimiento."
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 15
                        wrapMode: Text.WordWrap
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 190
                    Layout.preferredHeight: 34
                    radius: height / 2
                    color: "#F3E8FF"
                    border.width: 1
                    border.color: "#D8B4FE"

                    Text {
                        anchors.centerIn: parent
                        text: "PLATAFORMA EDUCATIVA"
                        color: "#6B21A8"
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 0.6
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: root.pageMargin
                Layout.rightMargin: root.pageMargin
                Layout.preferredHeight: 58
                radius: Style.Theme.radius
                color: "#F5F3FF"
                border.width: 1
                border.color: "#DDD6FE"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 14
                        color: "#7C3AED"

                        Text {
                            anchors.centerIn: parent
                            text: "i"
                            color: "white"
                            font.pixelSize: 15
                            font.bold: true
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Modo de prueba activo: puedes abrir cualquier etapa sin completar las anteriores. Los módulos futuros muestran una vista placeholder."
                        color: "#4C1D95"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: root.pageMargin
                Layout.rightMargin: root.pageMargin
                text: "FLUJO FORMATIVO"
                color: Style.Theme.texto_secundario
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1.1
            }

            ScrollView {
                id: flowScroll
                Layout.fillWidth: true
                Layout.leftMargin: root.pageMargin
                Layout.rightMargin: root.pageMargin
                Layout.preferredHeight: 346
                clip: true
                contentWidth: Math.max(availableWidth, root.minimumFlowWidth)
                contentHeight: availableHeight
                ScrollBar.horizontal.policy: contentWidth > availableWidth
                                             ? ScrollBar.AsNeeded
                                             : ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                RowLayout {
                    width: flowScroll.contentWidth
                    height: flowScroll.availableHeight - 12
                    spacing: 8

                    Component {
                        id: stageDelegateComponent

                        Item {
                            id: stageContainer
                            readonly property int stageOrder: parent ? parent.stageOrder : 0
                            readonly property string eyebrow: parent ? parent.eyebrow : ""
                            readonly property string title: parent ? parent.title : ""
                            readonly property string description: parent ? parent.description : ""
                            readonly property string stageStatus: parent ? parent.stageStatus : ""
                            readonly property bool stageAvailable: parent ? parent.stageAvailable : false
                            readonly property string stageRoute: parent ? parent.stageRoute : ""
                            readonly property string kind: parent ? parent.kind : ""
                            readonly property string accentColor: parent ? parent.accentColor : "#9CA3AF"
                            readonly property string note: parent ? parent.note : ""
                            readonly property bool stagePlaceholder: parent ? parent.stagePlaceholder : false
                            readonly property string testButtonName: parent ? parent.testButtonName : ""

                            anchors.fill: parent

                            Rectangle {
                                id: stageCard
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: stageContainer.stageOrder < 5
                                               ? connector.left
                                               : parent.right
                                anchors.rightMargin: stageContainer.stageOrder < 5 ? 8 : 0
                                radius: Style.Theme.radius
                                color: stageContainer.stageAvailable ? Style.Theme.surface : "#FAFAFC"
                                border.width: stageContainer.kind === "guided" ? 2 : 1
                                border.color: stageContainer.kind === "guided"
                                              ? stageContainer.accentColor
                                              : (stageContainer.stageAvailable
                                                 ? "#C7C3D1"
                                                 : "#D9DCE3")

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 7

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        spacing: 8

                                        Rectangle {
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: 18
                                            color: stageContainer.stageAvailable
                                                   ? stageContainer.accentColor
                                                   : "#E5E7EB"

                                            Text {
                                                anchors.centerIn: parent
                                                text: stageContainer.stageOrder
                                                color: stageContainer.stageAvailable ? "white" : "#6B7280"
                                                font.pixelSize: 16
                                                font.bold: true
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            Layout.preferredWidth: statusLabel.implicitWidth + 16
                                            Layout.preferredHeight: 24
                                            radius: 12
                                            color: stageContainer.stageAvailable ? "#DCFCE7" : "#F3F4F6"
                                            border.width: 1
                                            border.color: stageContainer.stageAvailable ? "#BBF7D0" : "#E5E7EB"

                                            Text {
                                                id: statusLabel
                                                anchors.centerIn: parent
                                                text: stageContainer.stageStatus.toUpperCase()
                                                color: stageContainer.stageAvailable ? "#166534" : "#6B7280"
                                                font.pixelSize: 9
                                                font.bold: true
                                                font.letterSpacing: 0.35
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        text: stageContainer.eyebrow
                                        color: stageContainer.accentColor
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.letterSpacing: 0.8
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        text: stageContainer.title
                                        color: Style.Theme.texto_primario
                                        font.pixelSize: 19
                                        font.bold: true
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        text: stageContainer.description
                                        color: Style.Theme.texto_secundario
                                        font.pixelSize: 12
                                        lineHeight: 1.14
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 4
                                        elide: Text.ElideRight
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        visible: stageContainer.kind === "guided"
                                        spacing: 4

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0

                                            Text {
                                                text: "Tu progreso"
                                                color: Style.Theme.texto_secundario
                                                font.pixelSize: 10
                                            }

                                            Item { Layout.fillWidth: true }

                                            Text {
                                                text: root.completedUnitsCount + "/"
                                                      + root.totalUnitsCount + " · "
                                                      + root.learningProgressPercent + "%"
                                                color: "#6D28D9"
                                                font.pixelSize: 10
                                                font.bold: true
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 6
                                            radius: 3
                                            color: "#EDE9FE"

                                            Rectangle {
                                                width: parent.width * Math.max(0, Math.min(100,
                                                       root.learningProgressPercent)) / 100
                                                height: parent.height
                                                radius: parent.radius
                                                color: "#7C3AED"

                                                Behavior on width {
                                                    NumberAnimation { duration: 180 }
                                                }
                                            }
                                        }
                                    }

                                    Item { Layout.fillHeight: true }

                                    Button {
                                        id: guidedButton
                                        objectName: stageContainer.kind === "guided"
                                                    ? "guidedStartButton"
                                                    : ""
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        Layout.preferredHeight: 42
                                        implicitWidth: 0
                                        visible: stageContainer.kind === "guided"
                                        text: root.guidedActionLabel
                                        focusPolicy: Qt.StrongFocus
                                        Accessible.name: text
                                        Accessible.description: "Abre el paso 2 de la ruta de aprendizaje"

                                        background: Rectangle {
                                            radius: 8
                                            color: guidedButton.down
                                                   ? "#5B21B6"
                                                   : (guidedButton.hovered ? "#6D28D9" : "#7C3AED")
                                        }
                                        contentItem: Text {
                                            text: guidedButton.text
                                            color: "white"
                                            font.pixelSize: 12
                                            font.bold: true
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        onClicked: root.openGuidedLearning()
                                    }

                                    Button {
                                        id: placeholderButton
                                        objectName: stageContainer.stagePlaceholder
                                                    ? stageContainer.testButtonName
                                                    : ""
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        Layout.preferredHeight: 42
                                        implicitWidth: 0
                                        visible: stageContainer.stagePlaceholder
                                        text: "Abrir vista de prueba"
                                        focusPolicy: Qt.StrongFocus
                                        Accessible.name: "Abrir " + stageContainer.title
                                        Accessible.description: "Abre el placeholder del paso "
                                                                + stageContainer.stageOrder

                                        background: Rectangle {
                                            radius: 8
                                            color: placeholderButton.down
                                                   ? "#B45309"
                                                   : (placeholderButton.hovered ? "#D97706" : "#F59E0B")
                                        }

                                        contentItem: Text {
                                            text: placeholderButton.text
                                            color: "white"
                                            font.pixelSize: 12
                                            font.bold: true
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        onClicked: root.openTestModule(stageContainer.stageOrder,
                                                                       stageContainer.title,
                                                                       stageContainer.description)
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        visible: stageContainer.kind === "labs"
                                        spacing: 5

                                        Button {
                                            id: trainingButton
                                            objectName: stageContainer.kind === "labs"
                                                        ? "trainingLabButton"
                                                        : ""
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            Layout.preferredHeight: 34
                                            implicitWidth: 0
                                            text: "Entrenar / configurar"
                                            focusPolicy: Qt.StrongFocus
                                            Accessible.description: "Abre el laboratorio de configuración y entrenamiento"
                                            onClicked: root.stackView.push("SetupScreen.qml", {
                                                "stackView": root.stackView
                                            })
                                            background: Rectangle {
                                                radius: 7
                                                color: trainingButton.down
                                                       ? Style.Theme.boton_presionado
                                                       : (trainingButton.hovered ? "#EDE9FE" : Style.Theme.boton)
                                                border.width: 1
                                                border.color: Style.Theme.borde_boton
                                            }
                                        }

                                        Button {
                                            id: libraryButton
                                            objectName: stageContainer.kind === "labs"
                                                        ? "modelLibraryLabButton"
                                                        : ""
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            Layout.preferredHeight: 34
                                            implicitWidth: 0
                                            text: "Abrir modelo"
                                            focusPolicy: Qt.StrongFocus
                                            Accessible.description: "Abre la biblioteca de modelos"
                                            onClicked: root.stackView.push("ModelLibraryScreen.qml", {
                                                "stackView": root.stackView
                                            })
                                            background: Rectangle {
                                                radius: 7
                                                color: libraryButton.down
                                                       ? Style.Theme.boton_presionado
                                                       : (libraryButton.hovered ? "#EDE9FE" : Style.Theme.boton)
                                                border.width: 1
                                                border.color: Style.Theme.borde_boton
                                            }
                                        }

                                        Button {
                                            id: comparisonButton
                                            objectName: stageContainer.kind === "labs"
                                                        ? "comparisonLabButton"
                                                        : ""
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            Layout.preferredHeight: 34
                                            implicitWidth: 0
                                            text: "Comparar modelos"
                                            focusPolicy: Qt.StrongFocus
                                            Accessible.description: "Abre el laboratorio de comparación"
                                            onClicked: root.stackView.push("ComparisonScreen.qml", {
                                                "stackView": root.stackView
                                            })
                                            background: Rectangle {
                                                radius: 7
                                                color: comparisonButton.down
                                                       ? Style.Theme.boton_presionado
                                                       : (comparisonButton.hovered ? "#EDE9FE" : Style.Theme.boton)
                                                border.width: 1
                                                border.color: Style.Theme.borde_boton
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        visible: stageContainer.stagePlaceholder
                                        spacing: 6

                                        Rectangle {
                                            Layout.preferredWidth: 7
                                            Layout.preferredHeight: 7
                                            radius: 4
                                            color: "#CBD5E1"
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            text: stageContainer.note
                                            color: Style.Theme.texto_secundario
                                            font.pixelSize: 10
                                            font.italic: true
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }
                                    }

                                }
                            }

                            Item {
                                id: connector
                                visible: stageContainer.stageOrder < 5
                                width: 22
                                height: 28
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                Accessible.ignored: true

                                Rectangle {
                                    width: 13
                                    height: 2
                                    radius: 1
                                    color: "#B8B1C6"
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Item {
                                    width: 9
                                    height: 16
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        width: 8
                                        height: 2
                                        radius: 1
                                        color: "#776F86"
                                        x: 0
                                        y: 4
                                        rotation: 45
                                    }

                                    Rectangle {
                                        width: 8
                                        height: 2
                                        radius: 1
                                        color: "#776F86"
                                        x: 0
                                        y: 10
                                        rotation: -45
                                    }
                                }
                            }
                        }
                    }

                    Loader {
                        objectName: "pretestStageCard"
                        property int stageOrder: 1
                        property string eyebrow: "DIAGNÓSTICO"
                        property string title: "Pre-test"
                        property string description: "Identificará tus conocimientos previos para personalizar la experiencia."
                        property string stageStatus: "Vista de prueba"
                        property bool stageAvailable: true
                        property string stageRoute: "ModulePlaceholderScreen.qml"
                        property string kind: "placeholder"
                        property string accentColor: "#D97706"
                        property string note: "Funcionalidad pendiente; navegación habilitada."
                        property bool stagePlaceholder: true
                        property string testButtonName: "pretestOpenButton"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 214
                        Layout.preferredWidth: 230
                        sourceComponent: stageDelegateComponent
                    }

                    Loader {
                        objectName: "guidedStageCard"
                        property int stageOrder: 2
                        property string eyebrow: "APRENDIZAJE"
                        property string title: "Recorrido guiado"
                        property string description: "Comprende el Transformer paso a paso mediante explicaciones y actividades."
                        property string stageStatus: "Disponible"
                        property bool stageAvailable: true
                        property string stageRoute: "GuidedLearningScreen.qml"
                        property string kind: "guided"
                        property string accentColor: "#7C3AED"
                        property string note: "Punto de inicio disponible ahora."
                        property bool stagePlaceholder: false
                        property string testButtonName: ""
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 214
                        Layout.preferredWidth: 230
                        sourceComponent: stageDelegateComponent
                    }

                    Loader {
                        objectName: "labsStageCard"
                        property int stageOrder: 3
                        property string eyebrow: "PRÁCTICA"
                        property string title: "Laboratorios"
                        property string description: "Aplica lo aprendido con datos, modelos y generaciones reales."
                        property string stageStatus: "Disponible"
                        property bool stageAvailable: true
                        property string stageRoute: ""
                        property string kind: "labs"
                        property string accentColor: "#4F46E5"
                        property string note: "Elige un laboratorio."
                        property bool stagePlaceholder: false
                        property string testButtonName: ""
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 214
                        Layout.preferredWidth: 230
                        sourceComponent: stageDelegateComponent
                    }

                    Loader {
                        objectName: "posttestStageCard"
                        property int stageOrder: 4
                        property string eyebrow: "EVALUACIÓN"
                        property string title: "Post-test"
                        property string description: "Comprobará cuánto aprendiste después del recorrido y la práctica."
                        property string stageStatus: "Vista de prueba"
                        property bool stageAvailable: true
                        property string stageRoute: "ModulePlaceholderScreen.qml"
                        property string kind: "placeholder"
                        property string accentColor: "#D97706"
                        property string note: "Funcionalidad pendiente; navegación habilitada."
                        property bool stagePlaceholder: true
                        property string testButtonName: "posttestOpenButton"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 214
                        Layout.preferredWidth: 230
                        sourceComponent: stageDelegateComponent
                    }

                    Loader {
                        objectName: "resultsStageCard"
                        property int stageOrder: 5
                        property string eyebrow: "SEGUIMIENTO"
                        property string title: "Progreso y resultados"
                        property string description: "Reunirá tus avances, resultados y recomendaciones de estudio."
                        property string stageStatus: "Vista de prueba"
                        property bool stageAvailable: true
                        property string stageRoute: "ModulePlaceholderScreen.qml"
                        property string kind: "placeholder"
                        property string accentColor: "#D97706"
                        property string note: "Funcionalidad pendiente; navegación habilitada."
                        property bool stagePlaceholder: true
                        property string testButtonName: "resultsOpenButton"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 214
                        Layout.preferredWidth: 230
                        sourceComponent: stageDelegateComponent
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: root.pageMargin
                Layout.rightMargin: root.pageMargin
                Layout.preferredHeight: 76
                radius: Style.Theme.radius
                color: Style.Theme.surface
                border.width: 1
                border.color: "#D7D3DE"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: 10
                        color: "#F3E8FF"

                        Text {
                            anchors.centerIn: parent
                            text: "{ }"
                            color: "#7C3AED"
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: "Recursos para los laboratorios"
                            color: Style.Theme.texto_primario
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Carga y administra los conjuntos de datos que usarás durante la práctica."
                            color: Style.Theme.texto_secundario
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }

                    Button {
                        id: datasetButton
                        objectName: "datasetManagerButton"
                        Layout.preferredWidth: 168
                        Layout.preferredHeight: 38
                        text: "Gestionar datasets"
                        focusPolicy: Qt.StrongFocus
                        Accessible.description: "Abre la gestión de conjuntos de datos"
                        onClicked: root.stackView.push("LoadDataSetScreen.qml", {
                            "stackView": root.stackView
                        })

                        background: Rectangle {
                            radius: 8
                            color: datasetButton.down
                                   ? Style.Theme.boton_presionado
                                   : (datasetButton.hovered ? "#EDE9FE" : Style.Theme.boton)
                            border.width: 1
                            border.color: Style.Theme.borde_boton
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: root.pageMargin
                Layout.rightMargin: root.pageMargin
                text: "Acceso libre para pruebas: las vistas placeholder no representan todavía la funcionalidad final."
                color: Style.Theme.texto_secundario
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
            }
        }
    }
}
