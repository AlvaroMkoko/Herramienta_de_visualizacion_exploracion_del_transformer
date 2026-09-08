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
    readonly property int totalUnits: units.length
    readonly property int totalCoreConcepts: countCoreConcepts()
    readonly property int predictionOptionCount: currentUnit.activity
                                                 && currentUnit.activity.options
                                                 ? currentUnit.activity.options.length : 0
    property int currentUnitIndex: 0
    property int currentConceptIndex: 0
    property int activityStage: 0
    property int selectedPrediction: -1
    property var optionOrder: []
    property var currentConcept: ({})
    property var currentRelatedConcepts: []
    property int progressRevision: 0
    property var fallbackCompletedUnitIds: []

    readonly property bool hasLearningController: typeof mainViewModel !== "undefined"
                                                  && mainViewModel.learningController !== null
    readonly property var currentUnit: units[currentUnitIndex] || ({})
    readonly property int currentUnitConceptCount: currentUnit.conceptIds
                                                    ? currentUnit.conceptIds.length : 0
    readonly property string currentConceptId: currentUnit.conceptIds
                                                && currentUnit.conceptIds.length > currentConceptIndex
                                                ? String(currentUnit.conceptIds[currentConceptIndex]) : ""
    readonly property int completedUnitsCount: hasLearningController
                                                ? mainViewModel.learningController.completedUnitsCount
                                                : fallbackCompletedUnitIds.length
    readonly property real overallProgress: totalUnits > 0
                                            ? completedUnitsCount / totalUnits : 0
    readonly property bool currentUnitCompleted: isUnitCompleted(String(currentUnit.id || ""))
    readonly property int globalConceptNumber: conceptOffset(currentUnitIndex)
                                               + currentConceptIndex + 1

    readonly property var units: [
        {
            "id": "unit_1",
            "number": "01",
            "title": "Mapa mental: del dataset al Transformer",
            "shortTitle": "Flujo completo",
            "objective": "Reconoce cómo un registro del dataset se convierte en tokens, atraviesa el encoder–decoder y produce una señal de aprendizaje.",
            "conceptIds": ["que_es_transformer", "encoder_decoder_general", "flujo_general"],
            "activity": {
                "visualType": "pipeline",
                "question": "Mientras el decoder genera una respuesta de 10 tokens, ¿cuántas veces procesa el encoder la oración de entrada?",
                "options": ["Una sola vez, al principio", "Una vez por cada token generado", "Dos veces: al empezar y al terminar"],
                "correctIndex": 0,
                "trace": ["El encoder lee la entrada completa de una vez", "Produce una representación por cada token de entrada", "El decoder consulta esa representación en cada paso", "Cada token nuevo reutiliza la misma salida del encoder"],
                "observation": "Observa que la salida del encoder no se recalcula: es la misma matriz la que el decoder consulta en el paso 1 y en el paso 10.",
                "correctFeedback": "Coincide. Ahora contrasta tu explicación con esta: la entrada no cambia durante la generación, así que su representación se calcula una vez y se reutiliza. ¿Tu explicación menciona que la entrada permanece fija?",
                "optionFeedback": [
                    "",
                    "Eso describiría una tubería que alterna encoder y decoder en cada paso. Pero la oración de entrada no cambia mientras se genera: recalcular su representación daría exactamente el mismo resultado. Lo que se repite es el decoder, no el encoder.",
                    "No hay una segunda pasada de cierre. El encoder termina su trabajo antes de que el decoder empiece, y su salida queda disponible sin volver a calcularse."
                ],
                "revisionFeedback": "El encoder lee la entrada completa de una vez; lo que se repite en cada token es el decoder.",
                "explanationPrompt": "¿Por qué el encoder puede ejecutarse una sola vez mientras el decoder debe ejecutarse muchas?",
                "modelExplanation": "El encoder lee toda la secuencia de entrada de una vez y produce una representación contextualizada por token. Esa entrada no cambia durante la generación, así que su representación se calcula una sola vez. El decoder, en cambio, produce la salida de a un token por vez: en cada paso consulta la salida completa del encoder y los tokens que él mismo ya generó."
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
                "question": "Dos frases tienen exactamente los mismos tokens en distinto orden. ¿Qué mecanismo permite que el modelo las distinga?",
                "options": ["Cada token recibe un embedding distinto según dónde aparece", "A cada embedding se le suma un patrón fijo distinto por posición", "El orden queda codificado en el token id asignado al tokenizar"],
                "correctIndex": 1,
                "trace": ["La frase se divide en tokens", "Cada token obtiene su embedding de la tabla", "Se suma el positional encoding de su posición", "El vector resultante lleva identidad y orden"],
                "observation": "Fíjate en que el mismo token en dos posiciones parte del mismo embedding: lo que difiere es el patrón que se le suma encima.",
                "correctFeedback": "Coincide. Ahora contrasta tu explicación con esta: el embedding aporta identidad y el positional encoding aporta ubicación, y ambos se suman en el mismo vector. ¿Tu explicación distingue las dos señales?",
                "optionFeedback": [
                    "La tabla de embeddings se consulta por id de token, no por posición: la misma palabra devuelve siempre la misma fila, aparezca donde aparezca. La diferencia de posición se agrega después, sumando el positional encoding.",
                    "",
                    "El token id es el índice de ese token dentro del vocabulario, no su lugar en la frase. La misma palabra tiene el mismo id en cualquier posición; el orden se inyecta aparte."
                ],
                "revisionFeedback": "El embedding depende solo de qué token es; la posición se agrega sumando un patrón aparte.",
                "explanationPrompt": "¿Por qué no alcanza con el embedding y hace falta sumar información de posición?",
                "modelExplanation": "El embedding depende únicamente del token: la misma palabra devuelve la misma fila de la tabla sin importar dónde aparezca, y tampoco depende del contexto. El positional encoding es una matriz con un patrón único por posición, que se suma al embedding. El vector que entra a la primera capa lleva así identidad y ubicación superpuestas."
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
                "question": "Cuando un token decide cuánta atención prestar a otro, ¿qué determina ese peso?",
                "options": ["La distancia entre ambos tokens dentro de la frase", "La comparación entre la Query de uno y la Key del otro", "El contenido del Value del token consultado"],
                "correctIndex": 1,
                "trace": ["Cada token produce su Query, Key y Value", "La Query se compara con todas las Keys", "Softmax convierte esos scores en pesos", "Los Values se promedian con esos pesos"],
                "observation": "Observa que dos tokens vecinos pueden recibir pesos muy distintos, y que un token lejano puede recibir el peso más alto de la fila.",
                "correctFeedback": "Coincide. Ahora contrasta tu explicación con esta: Query y Key deciden la relevancia, y el Value solo transporta lo que se transmite una vez decidida. ¿Tu explicación separa esos dos roles?",
                "optionFeedback": [
                    "La distancia no interviene en el cálculo: el peso sale de comparar Query con Key, y esa comparación no sabe dónde está cada token. Justamente por eso hace falta el positional encoding para que el orden influya de algún modo.",
                    "",
                    "El Value no participa en decidir el peso: entra recién después, cuando ya se calcularon los pesos y hay que promediar. Quien determina la relevancia es la comparación entre Query y Key."
                ],
                "revisionFeedback": "El peso sale de comparar la Query de un token con las Keys de los demás; el Value solo aporta el contenido que se transmite.",
                "explanationPrompt": "¿Por qué hacen falta tres vectores distintos y no alcanza con comparar los tokens directamente?",
                "modelExplanation": "Cada token genera tres vectores. La Query representa lo que busca, la Key lo que ofrece para ser encontrado, y el Value la información que entrega si resulta seleccionado. La atención compara la Query de un token con las Keys de todos los demás para decidir cuánto de cada Value tomar. Separar los roles permite que buscar, ser encontrado y transmitir se optimicen por separado."
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
                "observation": "Fíjate en el triángulo superior de la matriz: está en cero, mientras la diagonal y todo lo que queda debajo conservan peso.",
                "correctFeedback": "Coincide. Ahora contrasta tu explicación con esta: el objetivo en la posición t es el token t+1, que está presente en la entrada durante el entrenamiento; sin máscara el modelo lo copiaría en vez de predecirlo. ¿Tu explicación menciona esa copia?",
                "optionFeedback": [
                    "Ocultar el pasado dejaría a cada token sin contexto alguno para predecir. El pasado es justamente lo único que estará disponible al generar, así que debe permanecer visible.",
                    "",
                    "La atención cruzada no lleva máscara causal: la secuencia de entrada está completa desde el principio y no contiene ningún futuro que ocultar. La restricción aplica solo a la autoatención del decoder."
                ],
                "revisionFeedback": "Cada posición conserva su pasado visible; lo que se bloquea son las posiciones que todavía no deberían conocerse.",
                "explanationPrompt": "¿Por qué ocultar el futuro durante el entrenamiento es lo que hace posible generar después token por token?",
                "modelExplanation": "Durante el entrenamiento se entrega la secuencia objetivo completa por eficiencia, pero el objetivo en la posición t es el token que aparece en t+1 de la entrada. Sin máscara, el modelo copiaría ese token por atención en lugar de aprender a predecirlo: la pérdida bajaría rápido y el fallo aparecería recién al generar, cuando no hay futuro que copiar."
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
                "question": "Un modelo ya entrenado responde diez preguntas seguidas. ¿Sus parámetros cambian durante ese uso?",
                "options": ["Sí, cada respuesta ajusta un poco los parámetros", "Solo cambian cuando la respuesta generada es incorrecta", "No cambian: solo se modifican durante el entrenamiento"],
                "correctIndex": 2,
                "trace": ["En entrenamiento hay una respuesta correcta disponible", "La cross entropy compara predicción y objetivo", "Los gradientes indican cómo ajustar cada parámetro", "En inferencia no hay objetivo, así que no hay gradiente"],
                "observation": "Observa que la cadena pérdida → gradiente → actualización arranca en la comparación con la respuesta correcta. Sin ese objetivo, la cadena no puede iniciarse.",
                "correctFeedback": "Coincide. Ahora contrasta tu explicación con esta: actualizar un parámetro requiere un gradiente, y un gradiente requiere una pérdida, que a su vez requiere conocer la respuesta correcta. ¿Tu explicación recorre esa cadena completa?",
                "optionFeedback": [
                    "Para ajustar un parámetro hace falta un gradiente, y para calcularlo hace falta una pérdida que compare la salida con la respuesta correcta. En inferencia no hay respuesta correcta disponible, así que esa cadena nunca arranca.",
                    "Eso supondría que el modelo sabe que se equivocó, pero durante la inferencia no dispone de la respuesta correcta con la cual compararse. Sin objetivo no hay pérdida, y sin pérdida no hay ni detección del error ni actualización.",
                    ""
                ],
                "revisionFeedback": "Sin respuesta correcta no hay pérdida, sin pérdida no hay gradiente y sin gradiente no hay actualización.",
                "explanationPrompt": "¿Por qué el modelo no puede seguir aprendiendo mientras se lo usa?",
                "modelExplanation": "Entrenamiento e inferencia son modos distintos. En entrenamiento se dispone de la secuencia objetivo, la cross entropy mide el desacuerdo entre la predicción y el token correcto, backpropagation obtiene los gradientes y el optimizador actualiza cada parámetro. En inferencia no hay respuesta disponible: no puede calcularse la pérdida ni, por lo tanto, ningún gradiente."
            }
        },
        {
            "id": "unit_6",
            "number": "06",
            "title": "Del dataset al aprendizaje",
            "shortTitle": "Dataset y ejemplos",
            "objective": "Identifica el formato que convierte ejemplos de texto en una señal de aprendizaje para el encoder y el decoder.",
            "conceptIds": ["dataset", "teacher_forcing", "epoch_batch"],
                        "activity": {
                "visualType": "dataset_pairs",
                "question": "Durante el entrenamiento, el decoder predice mal el tercer token de la response. ¿Qué recibe como entrada para predecir el cuarto?",
                "options": ["Su propia predicción equivocada del tercer token", "El tercer token correcto, tomado de la response", "Nada: el ejemplo se descarta y se pasa al siguiente"],
                "correctIndex": 1,
                "trace": ["instruction y context forman la entrada del encoder", "response aporta la salida esperada", "El decoder recibe la response desplazada una posición", "Cada posición se predice a partir del texto correcto anterior"],
                "observation": "Fíjate en que la entrada del decoder proviene siempre de la response real, no de lo que el modelo produjo en el paso anterior.",
                "correctFeedback": "Coincide. Ahora contrasta tu explicación con esta: alimentar el contexto correcto permite evaluar todas las posiciones en una sola pasada y evita que un error temprano contamine el resto. ¿Tu explicación menciona alguna de esas dos ventajas?",
                "optionFeedback": [
                    "Eso ocurre al generar, no al entrenar. Con teacher forcing el decoder recibe la secuencia objetivo real desplazada una posición, en vez de lo que él mismo predijo; así un error temprano no arrastra a todas las predicciones siguientes.",
                    "",
                    "El ejemplo no se descarta: todas las posiciones se evalúan en la misma pasada y cada una aporta su propia pérdida. Un error en una posición no invalida las demás."
                ],
                "revisionFeedback": "Durante el entrenamiento el decoder recibe la response real desplazada, no sus propias predicciones.",
                "explanationPrompt": "¿Por qué conviene alimentar al decoder con la respuesta correcta durante el entrenamiento, si al generar no la tendrá?",
                "modelExplanation": "Teacher forcing consiste en dar al decoder la secuencia objetivo real desplazada una posición, en lugar de lo que él mismo predijo. Permite paralelizar todas las posiciones y evita que un error temprano arrastre a las predicciones siguientes. La contrapartida es el exposure bias: el modelo se entrena viendo siempre contexto perfecto, pero al generar debe apoyarse en su propia salida."
            }
        }
    ]

    function bounded(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, Number(value)))
    }

    function countCoreConcepts() {
        var total = 0
        for (var i = 0; i < root.units.length; ++i) {
            var conceptIds = root.units[i].conceptIds || []
            total += conceptIds.length
        }
        return total
    }

    function conceptOffset(unitIndex) {
        var total = 0
        var limit = Math.min(Math.max(Number(unitIndex), 0), root.units.length)
        for (var i = 0; i < limit; ++i) {
            var conceptIds = root.units[i].conceptIds || []
            total += conceptIds.length
        }
        return total
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

    function repeatCurrentUnit() {
        var unitId = String(root.currentUnit.id || "")
        if (!unitId)
            return
        if (root.hasLearningController)
            mainViewModel.learningController.unmarkUnitCompleted(unitId)
        else
            root.fallbackCompletedUnitIds = root.fallbackCompletedUnitIds.filter(
                function(id) { return id !== unitId })
        root.currentConceptIndex = 0
        root.restoreActivityState()
        root.savePosition()
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
        root.shuffleOptionOrder()
        root.activityStage = root.currentUnitCompleted ? 3 : 0
    }

        function selectUnit(index) {
        var target = Math.round(Number(index))
        if (!isFinite(target) || target < 0 || target >= root.totalUnits)
            return
        if (!root.isUnitUnlocked(target))
            return
        root.currentUnitIndex = target
        root.currentConceptIndex = 0
        root.restoreActivityState()
        root.savePosition()
    }

    function nextConcept() {
        if (root.currentConceptIndex < root.currentUnitConceptCount - 1) {
            root.currentConceptIndex += 1
            root.savePosition()
        } else if (root.currentUnitIndex < root.totalUnits - 1
                   && root.currentUnitCompleted) {
            root.selectUnit(root.currentUnitIndex + 1)
        }
    }

    function selectConcept(index) {
        var target = Math.round(Number(index))
        if (!isFinite(target) || target < 0 || target >= root.currentUnitConceptCount)
            return
        root.currentConceptIndex = target
        root.savePosition()
    }

    function previousConcept() {
        if (root.currentConceptIndex > 0) {
            root.currentConceptIndex -= 1
            root.savePosition()
        } else if (root.currentUnitIndex > 0) {
            root.currentUnitIndex -= 1
            root.currentConceptIndex = Math.max(root.currentUnitConceptCount - 1, 0)
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
        if (root.selectedPrediction < 0 || root.activityStage !== 0)
            return
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

        function shuffleOptionOrder() {
        var total = root.predictionOptionCount
        var order = []
        for (var i = 0; i < total; ++i)
            order.push(i)
        
        for (var j = order.length - 1; j > 0; --j) {
            var k = Math.floor(Math.random() * (j + 1))
            var t = order[j]; order[j] = order[k]; order[k] = t
        }
        root.optionOrder = order
    }

    function realOptionIndex(visibleIndex) {
        if (root.optionOrder.length > visibleIndex)
            return root.optionOrder[visibleIndex]
        return visibleIndex
    }

        function isUnitUnlocked(index) {
        var dependency = root.progressRevision
        if (index <= 0)
            return true
        // Una unidad se desbloquea cuando TODAS las anteriores están
        // completas. Permite volver a repasar unidades ya hechas.
        for (var i = 0; i < index; ++i) {
            if (!root.isUnitCompleted(String(root.units[i].id || "")))
                return false
        }
        return true
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
                                                    0, Math.max(root.currentUnitConceptCount - 1, 0))
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
            color: Style.Theme.surface
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
                        text: root.totalUnits + " unidades y " + root.totalCoreConcepts
                              + " conceptos sobre el Transformer encoder–decoder y sus datos."
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
                color: Style.Theme.surface
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

                            enabled: root.isUnitUnlocked(unitDelegate.index)
                            opacity: enabled ? 1.0 : 0.45
                            Accessible.description: root.isUnitUnlocked(unitDelegate.index)
                                                    ? (root.isUnitCompleted(String(unitDelegate.modelData.id))
                                                       ? "Unidad completada" : "Unidad pendiente")
                                                    : "Bloqueada: completa la unidad anterior"

                            // objectName: "guidedUnitButton" + index
                            // Layout.fillWidth: true
                            // Layout.preferredHeight: 70 * root.uiScale
                            // activeFocusOnTab: true
                            // Accessible.name: "Unidad " + (index + 1) + ": " + modelData.title
                            // Accessible.description: root.isUnitCompleted(String(modelData.id))
                            //                         ? "Unidad completada" : "Unidad pendiente"

                            background: Rectangle {
                                radius: 10 * root.uiScale
                                color: root.currentUnitIndex === unitDelegate.index
                                       ? "#F0ECFA"
                                       : unitDelegate.hovered ? "#F8F6FC" : Style.Theme.surface
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
                                              ? "En curso · concepto " + (root.currentConceptIndex + 1)
                                                + "/" + (unitDelegate.modelData.conceptIds || []).length
                                              : (unitDelegate.modelData.conceptIds || []).length
                                                + " conceptos · 1 actividad"
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
                    color: Style.Theme.surface
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
                                               ? "#EDE8FA" : conceptDelegate.hovered ? "#F7F5FC" : Style.Theme.chip_fondo
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
                        text: root.currentConceptIndex < root.currentUnitConceptCount - 1
                              ? "Siguiente concepto →" : "Siguiente unidad →"
                        activeFocusOnTab: true
                        Accessible.name: text
                        onClicked: root.nextConcept()

                        // enabled: root.currentConceptIndex < root.currentUnitConceptCount - 1
                        //          || root.currentUnitCompleted
                        // ToolTip.visible: hovered && !enabled
                        // ToolTip.text: "Completa la actividad de esta unidad para continuar"

                    }

                    Button {
                        id: repeatUnitButton
                        objectName: "guidedRepeatUnitButton"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34 * root.uiScale
                        visible: root.currentUnitCompleted
                        text: "Repetir esta unidad"
                        flat: true
                        activeFocusOnTab: true
                        Accessible.name: text
                        Accessible.description: "Vuelve a habilitar la actividad de la unidad actual sin borrar el resto del avance"
                        onClicked: root.repeatCurrentUnit()
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
                optionOrder: root.optionOrder
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
            text: "Se borrará el progreso de las " + root.totalUnits
                  + " unidades y volverás al primer concepto."
            color: Style.Theme.texto_primario
            font.pixelSize: 12 * root.uiScale
            wrapMode: Text.WordWrap
        }

        onAccepted: root.resetProgress()
    }

}
