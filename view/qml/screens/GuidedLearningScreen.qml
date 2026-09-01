pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

PagePrincipal {
    id: root
    objectName: "guidedLearningScreen"
    helpModalObjectName: "guidedTheoryModal"
    helpPanelObjectName: "guidedTheoryPanel"

    readonly property real uiScale: Math.max(0.82, Math.min(width / 1280, height / 820))
    readonly property int totalUnits: 5
    readonly property int totalCoreConcepts: 15
    readonly property int predictionOptionCount: currentUnit.activity
                                                 && currentUnit.activity.options
                                                 ? currentUnit.activity.options.length : 0
    property int currentUnitIndex: 0
    property int currentConceptIndex: 0
    property int activityStage: 0
    property int selectedPrediction: -1
    property var currentConcept: ({})
    property var currentRelatedConcepts: []
    property int progressRevision: 0
    property var fallbackCompletedUnitIds: []

    readonly property bool hasLearningController: typeof mainViewModel !== "undefined"
                                                  && mainViewModel.learningController !== null
    readonly property var currentUnit: units[currentUnitIndex] || ({})
    readonly property string currentConceptId: currentUnit.conceptIds
                                                && currentUnit.conceptIds.length > currentConceptIndex
                                                ? String(currentUnit.conceptIds[currentConceptIndex]) : ""
    readonly property int completedUnitsCount: hasLearningController
                                                ? mainViewModel.learningController.completedUnitsCount
                                                : fallbackCompletedUnitIds.length
    readonly property real overallProgress: totalUnits > 0
                                            ? completedUnitsCount / totalUnits : 0
    readonly property bool currentUnitCompleted: isUnitCompleted(String(currentUnit.id || ""))
    readonly property int globalConceptNumber: currentUnitIndex * 3 + currentConceptIndex + 1

    readonly property var units: [
        {
            "id": "unit_1",
            "number": "01",
            "title": "Mapa mental del Transformer",
            "shortTitle": "Mapa mental",
            "objective": "Reconoce las piezas principales y sigue el viaje de la información.",
            "conceptIds": ["que_es_transformer", "encoder_decoder_general", "flujo_general"],
            "activity": {
                "visualType": "pipeline",
                "question": "En una traducción, ¿qué bloque crea primero una representación contextual de toda la oración de entrada?",
                "options": ["El encoder", "El decoder", "La capa softmax"],
                "correctIndex": 0,
                "trace": ["Texto de entrada", "El encoder contextualiza", "El decoder usa ese contexto", "Aparece el siguiente token"],
                "observation": "La traza separa comprender la entrada de producir la salida: primero el encoder representa; después el decoder genera.",
                "correctFeedback": "Correcto: el encoder construye la representación contextual que consultará el decoder.",
                "revisionFeedback": "La salida no se genera todavía: primero el encoder construye el contexto de la entrada.",
                "explanationPrompt": "Explica por qué encoder y decoder cumplen papeles distintos dentro del mismo flujo.",
                "modelExplanation": "El encoder procesa la entrada y produce representaciones contextualizadas. El decoder consulta esas representaciones y su salida previa para generar un token a la vez."
            }
        },
        {
            "id": "unit_2",
            "number": "02",
            "title": "Del texto a los vectores",
            "shortTitle": "Texto a vectores",
            "objective": "Distingue tokens, embeddings y posición antes de entrar a la atención.",
            "conceptIds": ["tokenizacion", "embeddings", "positional_encoding"],
            "activity": {
                "visualType": "token_position",
                "question": "Dos frases contienen exactamente los mismos tokens, pero en distinto orden. ¿Qué señal permite distinguir sus posiciones?",
                "options": ["La tasa de aprendizaje", "El positional encoding", "El número de épocas"],
                "correctIndex": 1,
                "trace": ["La frase se divide en tokens", "Cada token obtiene un embedding", "Se agrega información de posición", "El modelo recibe vectores con identidad y orden"],
                "observation": "Un embedding identifica contenido, pero no basta para conservar el orden. La codificación posicional aporta esa señal antes de la atención.",
                "correctFeedback": "Correcto: la posición se combina con el embedding para que el orden sea observable.",
                "revisionFeedback": "Los hiperparámetros de entrenamiento no indican dónde aparece cada token; esa tarea corresponde al positional encoding.",
                "explanationPrompt": "Explica qué información aporta el embedding y qué información adicional aporta la posición.",
                "modelExplanation": "El embedding representa la identidad y propiedades aprendidas del token. El positional encoding añade dónde aparece, permitiendo distinguir secuencias con los mismos tokens en órdenes diferentes."
            }
        },
        {
            "id": "unit_3",
            "number": "03",
            "title": "Cómo decide qué mirar",
            "shortTitle": "Atención",
            "objective": "Relaciona Query, Key y Value con los pesos de atención y sus múltiples cabezas.",
            "conceptIds": ["query_key_value", "formula_attention_completa", "problema_multi_head"],
            "activity": {
                "visualType": "attention",
                "question": "Cuando un token busca contexto relevante, ¿qué descripción de Query, Key y Value es la más adecuada?",
                "options": ["Query busca, Key indica compatibilidad y Value aporta información", "Value busca, Query almacena y Key genera", "Los tres vectores siempre son idénticos"],
                "correctIndex": 0,
                "trace": ["La Query del token formula una búsqueda", "Se compara con las Keys", "Softmax convierte scores en pesos", "La suma ponderada reúne Values"],
                "observation": "La atención no copia un único token: distribuye pesos y combina información. Varias cabezas pueden aprender relaciones distintas.",
                "correctFeedback": "Correcto: Query y Key determinan relevancia; Value transporta la información que se combinará.",
                "revisionFeedback": "Recuerda la analogía de búsqueda: Query pregunta, Key permite comparar y Value entrega contenido.",
                "explanationPrompt": "Explica cómo una Query termina produciendo una combinación contextual de Values.",
                "modelExplanation": "La Query se compara con todas las Keys para producir scores; tras escalar y aplicar softmax, esos pesos ponderan los Values. Multi-head repite el proceso en distintos subespacios."
            }
        },
        {
            "id": "unit_4",
            "number": "04",
            "title": "Por qué no puede mirar el futuro",
            "shortTitle": "Máscara y generación",
            "objective": "Comprende la máscara causal y la generación autoregresiva token por token.",
            "conceptIds": ["por_que_mascara", "generacion_token_por_token", "seleccion_token"],
            "activity": {
                "visualType": "causal_mask",
                "question": "Al entrenar la predicción de la posición t, ¿qué información debe ocultar la máscara causal?",
                "options": ["Todos los tokens anteriores", "Los tokens posteriores a t", "La representación del encoder completa"],
                "correctIndex": 1,
                "trace": ["El decoder recibe el prefijo disponible", "La máscara bloquea posiciones futuras", "Se obtiene una distribución de probabilidad", "Se elige y agrega un nuevo token"],
                "observation": "La misma restricción causal evita hacer trampa al entrenar y hace posible repetir el ciclo durante la inferencia.",
                "correctFeedback": "Correcto: cada posición solo puede usar su pasado y la información permitida, nunca los tokens futuros de la salida.",
                "revisionFeedback": "La máscara conserva el pasado visible y bloquea las posiciones que todavía no deberían conocerse.",
                "explanationPrompt": "Explica por qué ocultar el futuro durante entrenamiento es necesario para generar después token por token.",
                "modelExplanation": "Si el decoder viera tokens futuros durante entrenamiento, aprendería con información ausente en inferencia. La máscara causal iguala esa restricción y permite la generación autoregresiva."
            }
        },
        {
            "id": "unit_5",
            "number": "05",
            "title": "Cómo aprende",
            "shortTitle": "Aprendizaje",
            "objective": "Conecta predicción, pérdida, gradientes y actualización de parámetros.",
            "conceptIds": ["entrenamiento_vs_inferencia", "cross_entropy", "actualizacion_parametros"],
            "activity": {
                "visualType": "training",
                "question": "¿Qué proceso ocurre después de calcular la cross entropy durante un paso de entrenamiento?",
                "options": ["Se borran los embeddings", "Se calculan gradientes y se actualizan parámetros", "El modelo entra automáticamente en inferencia"],
                "correctIndex": 1,
                "trace": ["El modelo predice probabilidades", "Cross entropy mide el error", "Backpropagation calcula gradientes", "El optimizador ajusta parámetros"],
                "observation": "La pérdida es una señal numérica; el aprendizaje sucede cuando sus gradientes guían una actualización de los parámetros.",
                "correctFeedback": "Correcto: backpropagation obtiene gradientes y el optimizador aplica la actualización.",
                "revisionFeedback": "Calcular la pérdida solo mide el error; todavía hacen falta gradientes y una actualización para aprender.",
                "explanationPrompt": "Explica la diferencia entre medir el error y modificar el modelo para reducirlo.",
                "modelExplanation": "Cross entropy cuantifica el desacuerdo entre predicción y objetivo. Backpropagation deriva cómo influye cada parámetro y el optimizador usa esos gradientes para actualizarlo."
            }
        }
    ]

    function bounded(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, Number(value)))
    }

    function isUnitCompleted(unitId) {
        var dependency = root.progressRevision
        if (!unitId)
            return false
        if (root.hasLearningController)
            return mainViewModel.learningController.isUnitCompleted(unitId)
        return root.fallbackCompletedUnitIds.indexOf(unitId) >= 0
    }

    function savePosition() {
        if (root.hasLearningController)
            mainViewModel.learningController.savePosition(root.currentUnitIndex,
                                                          root.currentConceptIndex)
    }

    function refreshConcept() {
        if (!root.currentConceptId) {
            root.currentConcept = ({})
            root.currentRelatedConcepts = []
            return
        }
        if (typeof mainViewModel === "undefined" || !mainViewModel.theoryController) {
            root.currentConcept = ({
                "id": root.currentConceptId,
                "title": "Contenido no disponible",
                "explanation": "No se pudo acceder al controlador de teoría."
            })
            root.currentRelatedConcepts = []
            return
        }
        root.currentConcept = mainViewModel.theoryController.obtenerConcepto(root.currentConceptId)
        root.currentRelatedConcepts = mainViewModel.theoryController.obtenerRelacionados(root.currentConceptId)
    }

    function restoreActivityState() {
        root.selectedPrediction = -1
        root.activityStage = root.currentUnitCompleted ? 3 : 0
    }

    function selectUnit(index) {
        var target = Math.round(Number(index))
        if (!isFinite(target) || target < 0 || target >= root.totalUnits)
            return
        root.currentUnitIndex = target
        root.currentConceptIndex = 0
        root.restoreActivityState()
        root.savePosition()
    }

    function selectConcept(index) {
        var target = Math.round(Number(index))
        if (!isFinite(target) || target < 0 || target >= 3)
            return
        root.currentConceptIndex = target
        root.savePosition()
    }

    function nextConcept() {
        if (root.currentConceptIndex < 2) {
            root.currentConceptIndex += 1
            root.savePosition()
        } else if (root.currentUnitIndex < root.totalUnits - 1) {
            root.selectUnit(root.currentUnitIndex + 1)
        }
    }

    function previousConcept() {
        if (root.currentConceptIndex > 0) {
            root.currentConceptIndex -= 1
            root.savePosition()
        } else if (root.currentUnitIndex > 0) {
            root.currentUnitIndex -= 1
            root.currentConceptIndex = 2
            root.restoreActivityState()
            root.savePosition()
        }
    }

    function selectPrediction(optionIndex) {
        var target = Math.round(Number(optionIndex))
        var options = root.currentUnit.activity ? root.currentUnit.activity.options : []
        if (root.activityStage !== 0 || target < 0 || target >= options.length)
            return
        root.selectedPrediction = target
    }

    function showObservation() {
        if (root.activityStage === 0 && root.selectedPrediction >= 0)
            root.activityStage = 1
    }

    function startExplanation() {
        if (root.activityStage === 1)
            root.activityStage = 2
    }

    function completeActivity(explanationText) {
        if (root.activityStage !== 2 || String(explanationText).trim().length < 12)
            return
        var unitId = String(root.currentUnit.id || "")
        if (root.hasLearningController) {
            mainViewModel.learningController.markUnitCompleted(unitId)
        } else if (root.fallbackCompletedUnitIds.indexOf(unitId) < 0) {
            var updated = root.fallbackCompletedUnitIds.slice(0)
            updated.push(unitId)
            root.fallbackCompletedUnitIds = updated
        }
        root.progressRevision += 1
        root.activityStage = 3
    }

    function resetProgress() {
        if (root.hasLearningController)
            mainViewModel.learningController.resetProgress()
        root.fallbackCompletedUnitIds = []
        root.progressRevision += 1
        root.currentUnitIndex = 0
        root.currentConceptIndex = 0
        root.selectedPrediction = -1
        root.activityStage = 0
        root.savePosition()
    }

    function openDeepDive(conceptId) {
        if (!conceptId || typeof mainViewModel === "undefined"
                || !mainViewModel.theoryController)
            return
        root.openTheoryConcept(conceptId)
    }

    function leaveScreen() {
        root.savePosition()
        root.stackView.pop()
    }

    onCurrentConceptIdChanged: refreshConcept()

    Connections {
        target: root.hasLearningController ? mainViewModel.learningController : null
        ignoreUnknownSignals: true

        function onProgressChanged() {
            root.progressRevision += 1
        }
    }

    Connections {
        target: typeof mainViewModel !== "undefined" ? mainViewModel.theoryController : null
        ignoreUnknownSignals: true

        function onTeoriaRecargada() {
            root.refreshConcept()
        }
    }

    Component.onCompleted: {
        if (root.hasLearningController) {
            root.currentUnitIndex = root.bounded(mainViewModel.learningController.lastUnitIndex,
                                                 0, root.totalUnits - 1)
            root.currentConceptIndex = root.bounded(mainViewModel.learningController.lastConceptIndex,
                                                    0, 2)
        }
        root.restoreActivityState()
        root.refreshConcept()
    }

    Shortcut {
        sequence: "Esc"
        onActivated: {
            if (root.theoryModalOpened)
                root.closeTheory()
            else
                root.leaveScreen()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 18 * root.uiScale
        anchors.rightMargin: 18 * root.uiScale
        anchors.topMargin: 14 * root.uiScale
        anchors.bottomMargin: 16 * root.uiScale
        spacing: 12 * root.uiScale

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 88 * root.uiScale
            radius: 14 * root.uiScale
            color: "#FFFFFF"
            border.color: "#D8D2EC"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14 * root.uiScale
                spacing: 14 * root.uiScale

                Button {
                    id: backButton
                    objectName: "guidedBackButton"
                    Layout.preferredWidth: 118 * root.uiScale
                    Layout.preferredHeight: 42 * root.uiScale
                    text: "← Inicio"
                    activeFocusOnTab: true
                    Accessible.name: "Volver al inicio"
                    Accessible.description: "Guarda el avance y regresa a la pantalla principal"

                    background: Rectangle {
                        radius: 9 * root.uiScale
                        color: backButton.down ? "#E4DDF5"
                                               : backButton.hovered ? "#F2EEFA" : "#F8F6FC"
                        border.color: "#CFC7E9"
                    }

                    contentItem: Text {
                        text: backButton.text
                        color: "#54449B"
                        font.bold: true
                        font.pixelSize: 12 * root.uiScale
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: root.leaveScreen()
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2 * root.uiScale

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8 * root.uiScale

                        Text {
                            text: "Recorrido guiado"
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: 23 * root.uiScale
                            Accessible.role: Accessible.Heading
                            Accessible.name: text
                        }

                        Rectangle {
                            Layout.preferredWidth: learningModeLabel.implicitWidth + 16 * root.uiScale
                            Layout.preferredHeight: 24 * root.uiScale
                            radius: height / 2
                            color: "#EAF7F2"

                            Text {
                                id: learningModeLabel
                                anchors.centerIn: parent
                                text: "SIN DATASET NI MODELO"
                                color: "#28745E"
                                font.bold: true
                                font.pixelSize: 9 * root.uiScale
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Cinco unidades sobre la arquitectura Transformer encoder–decoder original."
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 11 * root.uiScale
                        elide: Text.ElideRight
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 265 * root.uiScale
                    spacing: 5 * root.uiScale

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: "Progreso del recorrido"
                            color: Style.Theme.texto_secundario
                            font.pixelSize: 10 * root.uiScale
                        }

                        Text {
                            text: root.completedUnitsCount + " / " + root.totalUnits + " unidades"
                            color: "#5946A3"
                            font.bold: true
                            font.pixelSize: 10 * root.uiScale
                        }
                    }

                    ProgressBar {
                        id: overallProgressBar
                        objectName: "guidedOverallProgress"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 10 * root.uiScale
                        from: 0
                        to: 1
                        value: root.overallProgress
                        Accessible.name: "Progreso del recorrido"
                        Accessible.description: Math.round(root.overallProgress * 100) + " por ciento completado"

                        background: Rectangle {
                            radius: height / 2
                            color: "#ECEAF2"
                        }

                        contentItem: Item {
                            Rectangle {
                                width: overallProgressBar.visualPosition * parent.width
                                height: parent.height
                                radius: height / 2
                                color: root.completedUnitsCount === root.totalUnits
                                       ? "#2C9A73" : "#7563C7"
                                Behavior on width { NumberAnimation { duration: 180 } }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12 * root.uiScale

            Rectangle {
                Layout.preferredWidth: 242 * root.uiScale
                Layout.fillHeight: true
                radius: 14 * root.uiScale
                color: "#FFFFFF"
                border.color: "#D8D2EC"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12 * root.uiScale
                    spacing: 9 * root.uiScale

                    Text {
                        Layout.fillWidth: true
                        text: "Ruta de aprendizaje"
                        color: Style.Theme.texto_primario
                        font.bold: true
                        font.pixelSize: 15 * root.uiScale
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Sigue el orden recomendado o vuelve a una unidad para repasar."
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 10 * root.uiScale
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: "#E8E4F1"
                    }

                    Repeater {
                        model: root.units

                        delegate: Button {
                            id: unitDelegate
                            required property var modelData
                            required property int index
                            objectName: "guidedUnitButton" + index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 76 * root.uiScale
                            activeFocusOnTab: true
                            Accessible.name: "Unidad " + (index + 1) + ": " + modelData.title
                            Accessible.description: root.isUnitCompleted(String(modelData.id))
                                                    ? "Unidad completada" : "Unidad pendiente"

                            background: Rectangle {
                                radius: 10 * root.uiScale
                                color: root.currentUnitIndex === unitDelegate.index
                                       ? "#F0ECFA"
                                       : unitDelegate.hovered ? "#F8F6FC" : "#FFFFFF"
                                border.width: root.currentUnitIndex === unitDelegate.index ? 2 : 1
                                border.color: root.currentUnitIndex === unitDelegate.index
                                              ? "#7968CA" : "#E0DCEB"
                            }

                            contentItem: RowLayout {
                                spacing: 9 * root.uiScale

                                Rectangle {
                                    Layout.preferredWidth: 34 * root.uiScale
                                    Layout.preferredHeight: 34 * root.uiScale
                                    radius: 9 * root.uiScale
                                    color: root.isUnitCompleted(String(unitDelegate.modelData.id))
                                           ? "#DFF4EA" : root.currentUnitIndex === unitDelegate.index
                                             ? "#DED6F4" : "#F0F1F4"

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isUnitCompleted(String(unitDelegate.modelData.id))
                                              ? "✓" : unitDelegate.modelData.number
                                        color: root.isUnitCompleted(String(unitDelegate.modelData.id))
                                               ? "#187455" : "#5D50A5"
                                        font.bold: true
                                        font.pixelSize: 10 * root.uiScale
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3 * root.uiScale

                                    Text {
                                        Layout.fillWidth: true
                                        text: unitDelegate.modelData.shortTitle
                                        color: Style.Theme.texto_primario
                                        font.bold: true
                                        font.pixelSize: 11 * root.uiScale
                                        wrapMode: Text.WordWrap
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.isUnitCompleted(String(unitDelegate.modelData.id))
                                              ? "Completada" : unitDelegate.index === root.currentUnitIndex
                                                ? "En curso · concepto " + (root.currentConceptIndex + 1) + "/3"
                                                : "3 conceptos · 1 actividad"
                                        color: root.isUnitCompleted(String(unitDelegate.modelData.id))
                                               ? "#187455" : Style.Theme.texto_secundario
                                        font.pixelSize: 9 * root.uiScale
                                    }
                                }

                                Text {
                                    text: "›"
                                    color: "#7968CA"
                                    font.pixelSize: 19 * root.uiScale
                                }
                            }

                            onClicked: root.selectUnit(index)
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Button {
                        id: resetButton
                        objectName: "guidedResetProgressButton"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34 * root.uiScale
                        visible: root.completedUnitsCount > 0
                        text: "Reiniciar recorrido"
                        flat: true
                        activeFocusOnTab: true
                        Accessible.name: text
                        onClicked: resetDialog.open()
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 9 * root.uiScale

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82 * root.uiScale
                    radius: 12 * root.uiScale
                    color: "#FFFFFF"
                    border.color: "#D8D2EC"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 11 * root.uiScale
                        spacing: 5 * root.uiScale

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: "UNIDAD " + (root.currentUnitIndex + 1) + " · " + root.currentUnit.title
                                color: "#5F4BAA"
                                font.bold: true
                                font.pixelSize: 11 * root.uiScale
                                elide: Text.ElideRight
                            }

                            Text {
                                text: "Concepto " + root.globalConceptNumber + " de " + root.totalCoreConcepts
                                color: Style.Theme.texto_secundario
                                font.pixelSize: 10 * root.uiScale
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6 * root.uiScale

                            Repeater {
                                model: root.currentUnit.conceptIds || []

                                delegate: Button {
                                    id: conceptDelegate
                                    required property var modelData
                                    required property int index
                                    objectName: "guidedConceptButton" + index
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34 * root.uiScale
                                    text: (index + 1) + ". " + (index === root.currentConceptIndex
                                          ? String(root.currentConcept.title || modelData)
                                          : String(modelData).replace(/_/g, " "))
                                    activeFocusOnTab: true
                                    Accessible.name: "Concepto " + (index + 1) + " de la unidad"

                                    background: Rectangle {
                                        radius: 8 * root.uiScale
                                        color: root.currentConceptIndex === conceptDelegate.index
                                               ? "#EDE8FA" : conceptDelegate.hovered ? "#F7F5FC" : "#F3F4F6"
                                        border.color: root.currentConceptIndex === conceptDelegate.index
                                                      ? "#7968CA" : "transparent"
                                    }

                                    contentItem: Text {
                                        text: conceptDelegate.text
                                        color: root.currentConceptIndex === conceptDelegate.index
                                               ? "#5946A3" : "#626A76"
                                        font.bold: root.currentConceptIndex === conceptDelegate.index
                                        font.pixelSize: 9 * root.uiScale
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }

                                    onClicked: root.selectConcept(index)
                                }
                            }
                        }
                    }
                }

                GuidedConceptReader {
                    id: conceptReader
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    concept: root.currentConcept
                    relatedConcepts: root.currentRelatedConcepts
                    loadError: typeof mainViewModel !== "undefined"
                               ? mainViewModel.theoryController.errorCarga : ""
                    scaleFactor: root.uiScale
                    onDeepDiveRequested: function(conceptId) {
                        root.openDeepDive(conceptId)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42 * root.uiScale
                    Layout.minimumHeight: 42 * root.uiScale
                    Layout.maximumHeight: 42 * root.uiScale
                    spacing: 8 * root.uiScale

                    Button {
                        id: previousButton
                        objectName: "guidedPreviousConceptButton"
                        Layout.preferredWidth: 125 * root.uiScale
                        Layout.fillHeight: true
                        enabled: root.currentUnitIndex > 0 || root.currentConceptIndex > 0
                        text: "← Anterior"
                        activeFocusOnTab: true
                        Accessible.name: "Concepto anterior"
                        onClicked: root.previousConcept()
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.currentUnit.objective
                        color: Style.Theme.texto_secundario
                        font.pixelSize: 9 * root.uiScale
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    Button {
                        id: nextButton
                        objectName: "guidedNextConceptButton"
                        Layout.preferredWidth: 170 * root.uiScale
                        Layout.fillHeight: true
                        enabled: root.globalConceptNumber < root.totalCoreConcepts
                        text: root.currentConceptIndex < 2 ? "Siguiente concepto →" : "Siguiente unidad →"
                        activeFocusOnTab: true
                        Accessible.name: text
                        onClicked: root.nextConcept()
                    }
                }
            }

            GuidedLearningActivity {
                id: activityCard
                Layout.preferredWidth: 330 * root.uiScale
                Layout.fillHeight: true
                activity: root.currentUnit.activity || ({})
                stage: root.activityStage
                selectedPrediction: root.selectedPrediction
                unitCompleted: root.currentUnitCompleted
                scaleFactor: root.uiScale
                onPredictionSelected: function(optionIndex) {
                    root.selectPrediction(optionIndex)
                }
                onObservationRequested: root.showObservation()
                onExplanationRequested: root.startExplanation()
                onCompletionRequested: function(explanation) {
                    root.completeActivity(explanation)
                }
            }
        }
    }

    Dialog {
        id: resetDialog
        objectName: "guidedResetDialog"
        anchors.centerIn: parent
        width: 420 * root.uiScale
        modal: true
        title: "Reiniciar recorrido"
        standardButtons: Dialog.Yes | Dialog.No

        Text {
            text: "Se borrará el progreso de las cinco unidades y volverás al primer concepto."
            color: Style.Theme.texto_primario
            font.pixelSize: 12 * root.uiScale
            wrapMode: Text.WordWrap
        }

        onAccepted: root.resetProgress()
    }

}
