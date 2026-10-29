pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

Item {
    id: root
    objectName: "selfAttentionOverviewScene"

    property string stepId: "attention_input"
    property bool trainingMode: false
    property var tokens: []
    property var attentionData: ({})
    property int selectedHead: 0
    property int selectedToken: 0
    property bool causal: false
    property bool active: false
    property bool reducedMotion: false
    property real sx: 1
    property real sy: 1
    property real progress: 1

    readonly property bool conceptualOnly: true
    readonly property bool personalized: true
    readonly property bool compact: width < 820
    readonly property bool veryCompact: width < 540
    readonly property int stageColumns: compact ? 1 : 4
    readonly property real stageCardHeight: compact ? 132 * sy : 242 * sy
    readonly property var displayTokens: buildDisplayTokens()
    readonly property string phraseText: buildPhraseText()
    readonly property int visibleTokenCount: displayTokens.length
    readonly property int focusedIndex: resolveFocusedIndex()
    readonly property bool focusRelevant: ["qkv", "dot", "scale", "mask",
                                           "softmax", "weighted", "output"]
                                          .indexOf(String(stepId)) >= 0
    readonly property int paddingIndex: findPaddingIndex()
    readonly property int maximumConnectionCount: visibleTokenCount
    readonly property int visibleConnectionCount: countVisibleConnections()
    readonly property bool usingCapturedAttention: hasCapturedWeights()
    readonly property bool maskUsesHypotheticalPad: stepId === "mask"
                                                       && !causal
                                                       && paddingIndex < 0
    readonly property var stageDefinition: definitionFor(stepId)
    readonly property string stageKind: String(stageDefinition.kind || "input")
    readonly property string stageIdentity: String(stepId) + ":" + stageKind
    readonly property string stageTitle: String(stageDefinition.title || "Self-Attention")
    readonly property string stagePurpose: String(stageDefinition.purpose || "")
    readonly property string stageInput: String(stageDefinition.inputTitle || "Entrada")
    readonly property string stageAction: String(stageDefinition.actionTitle || "Transformación")
    readonly property string stageOutput: String(stageDefinition.outputTitle || "Salida")
    readonly property string stageTakeaway: String(stageDefinition.takeaway || "")
    readonly property string stageQuestion: String(stageDefinition.question || "¿Qué cambia en esta etapa?")
    readonly property int globalPhase: Number(stageDefinition.phase || 0)
    readonly property bool learningStage: Boolean(stageDefinition.learning)
    readonly property bool phaseIndicatorInteractive: false
    readonly property real inputReveal: revealBetween(0.02, 0.24)
    readonly property real operationReveal: revealBetween(0.24, 0.70)
    readonly property real outputReveal: revealBetween(0.70, 0.94)
    readonly property string stageNarration: progress < 0.24
            ? "Primero observa qué entra: " + stageInput + "."
            : (progress < 0.70
               ? "Ahora observa el cambio: " + stageAction + "."
               : "Resultado de esta etapa: " + stageOutput + ".")
    readonly property var globalMoments: [
        { label: "ENTRADA", color: Style.Theme.inferencia_estructura },
        { label: "Q / K / V", color: Style.Theme.inferencia_transformacion },
        { label: "ATENCIÓN", color: Style.Theme.inferencia_foco },
        { label: "CONTEXTO", color: Style.Theme.inferencia_resultado }
    ]
    readonly property string currentPhaseLabel: globalMoments[Math.max(
            0, Math.min(globalMoments.length - 1, globalPhase))].label

    function clamp01(value) {
        return Math.max(0, Math.min(1, Number(value || 0)))
    }

    function revealBetween(start, end) {
        return clamp01((progress - start) / Math.max(0.001, end - start))
    }

    function safeTokenLabel(token, fallback) {
        var item = token && typeof token === "object" ? token : ({})
        var label = item.text !== undefined ? item.text
                    : (item.texto !== undefined ? item.texto
                       : (item.token !== undefined ? item.token : fallback))
        label = String(label === undefined || label === null ? fallback : label)
        return label.trim().length ? label : fallback
    }

    function buildDisplayTokens() {
        var source = tokens && tokens.length !== undefined ? tokens : []
        var result = []
        if (source.length >= 3) {
            for (var index = 0; index < Math.min(4, source.length); ++index)
                result.push({ label: safeTokenLabel(source[index], "T" + (index + 1)) })
            return result
        }
        return [{ label: "el" }, { label: "banco" },
                { label: "del" }, { label: "río" }]
    }

    function buildPhraseText() {
        var labels = []
        for (var index = 0; index < displayTokens.length; ++index)
            labels.push(String(displayTokens[index].label))
        return labels.join(" ")
    }

    function tokenLabelAt(index, fallback) {
        var token = displayTokens[index]
        return token ? String(token.label) : String(fallback || ("T" + (index + 1)))
    }

    function findPaddingIndex() {
        for (var index = 0; index < displayTokens.length; ++index) {
            var label = String(displayTokens[index].label).toUpperCase()
            if (label.indexOf("PAD") >= 0)
                return index
        }
        return -1
    }

    function resolveFocusedIndex() {
        var candidate = selectedToken
        if (attentionData && attentionData.query_seleccionada !== undefined)
            candidate = Number(attentionData.query_seleccionada)
        return Math.max(0, Math.min(Math.max(0, visibleTokenCount - 1),
                                    Number(candidate || 0)))
    }

    function focusedTokenLabel() {
        var token = displayTokens[focusedIndex]
        return token ? String(token.label) : "token seleccionado"
    }

    function connectionAllowed(index) {
        return !causal || index <= focusedIndex
    }

    function countVisibleConnections() {
        var count = 0
        for (var index = 0; index < visibleTokenCount; ++index)
            if (connectionAllowed(index))
                count += 1
        return count
    }

    function attentionRow() {
        var source = attentionData && attentionData.atencion
                     && attentionData.atencion.length !== undefined
                     ? attentionData.atencion : []
        if (!source.length)
            return []
        var candidate = source
        if (candidate[0] && candidate[0].length !== undefined
                && candidate[0][0] && candidate[0][0].length !== undefined)
            candidate = candidate[Math.max(0, Math.min(candidate.length - 1,
                                                        Number(selectedHead || 0)))]
        if (candidate[0] && candidate[0].length !== undefined)
            candidate = candidate[Math.max(0, Math.min(candidate.length - 1,
                                                        focusedIndex))]
        return candidate && candidate.length !== undefined ? candidate : []
    }

    function fallbackWeight(index) {
        var example = [0.12, 0.25, 0.10, 0.53]
        return index < example.length ? example[index]
                                      : 1 / Math.max(1, visibleTokenCount)
    }

    function weightFor(index) {
        if (!connectionAllowed(index))
            return 0
        var row = attentionRow()
        var value = index < row.length ? Number(row[index]) : NaN
        return Number.isFinite(value) && value >= 0 ? value : fallbackWeight(index)
    }

    function maximumWeight() {
        var maximum = 1e-9
        for (var index = 0; index < visibleTokenCount; ++index)
            maximum = Math.max(maximum, weightFor(index))
        return maximum
    }

    function hasCapturedWeights() {
        return attentionRow().length >= visibleTokenCount
    }

    function chip(label, role) {
        var color = Style.Theme.inferencia_estructura
        var fill = Style.Theme.info_fondo
        var ink = Style.Theme.texto_primario
        if (role === "q") {
            color = Style.Theme.matriz_query
            fill = Style.Theme.matriz_query_fondo
            ink = Style.Theme.matriz_query_texto
        } else if (role === "k") {
            color = Style.Theme.matriz_key
            fill = Style.Theme.matriz_key_fondo
            ink = Style.Theme.matriz_key_texto
        } else if (role === "v") {
            color = Style.Theme.matriz_value
            fill = Style.Theme.matriz_value_fondo
            ink = Style.Theme.matriz_value_texto
        } else if (role === "result") {
            color = Style.Theme.inferencia_resultado
            fill = Style.Theme.exito_fondo
            ink = Style.Theme.exito_texto
        } else if (role === "focus") {
            color = Style.Theme.inferencia_foco
            fill = Style.Theme.acento_fondo
            ink = Style.Theme.acento_texto
        } else if (role === "error") {
            color = Style.Theme.inferencia_error
            fill = Style.Theme.error_fondo
            ink = Style.Theme.error_texto
        }
        return { label: String(label), color: color, fill: fill, ink: ink }
    }

    function tokenChips(resultStyle) {
        var result = []
        for (var index = 0; index < displayTokens.length; ++index)
            result.push(chip(displayTokens[index].label,
                             resultStyle ? "result" : "input"))
        return result
    }

    function definitionFor(identifier) {
        var id = String(identifier || "attention_input")
        if (id === "weights")
            return {
                kind: "learned_weights", phase: 1, title: "Preparar tres formas de leer la entrada",
                purpose: "La misma información X pasa por tres transformaciones aprendidas: una para Q, otra para K y otra para V.",
                question: "¿Para qué existen WQ, WK y WV?",
                inputTitle: "Representación X", inputDetail: "Los mismos vectores alimentan las tres rutas.",
                inputItems: [chip("X", "input")],
                actionTitle: "Tres transformaciones aprendidas", actionDetail: "WQ, WK y WV cumplen funciones diferentes.",
                visualLabel: "una entrada · tres maneras de leerla",
                outputTitle: "Rutas Q, K y V", outputDetail: "Quedan listas para preguntar, comparar y aportar contenido.",
                outputItems: [chip("Q", "q"), chip("K", "k"), chip("V", "v")],
                takeaway: "Estos pesos se aprenden durante el entrenamiento; no son pesos de atención entre tokens."
            }
        if (id === "qkv")
            return {
                kind: "qkv", phase: 1, title: "Dar tres funciones a cada token",
                purpose: "Cada token crea Q para buscar, K para poder compararse y V para compartir su información.",
                question: "¿Qué significan Q, K y V para un token?",
                inputTitle: "Vector de cada token", inputDetail: "Incluye contenido y posición.",
                inputItems: tokenChips(false),
                actionTitle: "Asignar tres papeles", actionDetail: "Q busca; K permite comparar; V lleva la información.",
                visualLabel: "Q busca · K se compara · V aporta",
                outputTitle: "Q, K y V por token", outputDetail: "Todavía no se ha mezclado información entre tokens.",
                outputItems: [chip("Q", "q"), chip("K", "k"), chip("V", "v")],
                takeaway: "Q, K y V son versiones distintas de los vectores de entrada, no tokens nuevos."
            }
        if (id === "dot")
            return {
                kind: "compatibility", phase: 2, title: "Buscar qué tokens se relacionan",
                purpose: "La Query de «" + focusedTokenLabel() + "» se compara con las Keys de los tokens visibles.",
                question: "¿Qué tokens parecen útiles para entender «" + focusedTokenLabel() + "»?",
                inputTitle: "Una Q y varias K", inputDetail: "La fila activa corresponde a una sola Query.",
                inputItems: [chip("Q activa", "q"), chip("Keys", "k")],
                actionTitle: "Medir compatibilidad", actionDetail: "Una conexión más marcada representa mayor afinidad.",
                visualLabel: "una Query consulta pocas Keys visibles",
                outputTitle: "Scores de relación", outputDetail: "Aún expresan afinidad, no probabilidades.",
                outputItems: [chip("afinidad", "focus")],
                takeaway: "Cada fila responde: ¿qué tan relacionada está esta Query con cada Key?"
            }
        if (id === "scale")
            return {
                kind: "scale", phase: 2, title: "Hacer comparables los scores",
                purpose: "Los scores se hacen más pequeños sin cambiar cuál era mayor o menor.",
                question: "¿Por qué se reducen los scores antes de repartir la atención?",
                inputTitle: "Scores crudos", inputDetail: "Pueden quedar demasiado separados.",
                inputItems: [chip("scores altos", "focus")],
                actionTitle: "Reducir su escala", actionDetail: "Todos se ajustan con el mismo criterio.",
                visualLabel: "la forma se conserva · la magnitud se modera",
                outputTitle: "Scores equilibrados", outputDetail: "Mantienen su orden relativo y son más estables.",
                outputItems: [chip("scores estables", "focus")],
                takeaway: "Escalar no decide a qué token atender; prepara comparaciones más estables."
            }
        if (id === "mask")
            return {
                kind: "mask", phase: 2, title: causal ? "Ocultar tokens futuros" : "Excluir posiciones PAD",
                purpose: causal
                         ? "La máscara oculta los tokens futuros para que el modelo use únicamente el prefijo disponible."
                         : "PAD sólo rellena espacio y no contiene significado. La máscara lo excluye; si no hay PAD, nada cambia.",
                question: causal
                          ? "¿Qué tokens todavía no puede consultar esta posición?"
                          : "¿Qué celdas deben ignorarse porque corresponden a relleno PAD?",
                inputTitle: "Scores + posiciones permitidas", inputDetail: causal
                            ? "El prefijo define qué Keys ya son visibles."
                            : "Se distingue un token real de una posición PAD.",
                inputItems: causal ? [chip("pasado", "k"), chip("futuro", "error")]
                                   : [chip("token real", "k"),
                                      chip(paddingIndex >= 0 ? "PAD detectado" : "PAD (ejemplo)", "error")],
                actionTitle: "Quitar lo que no debe participar", actionDetail: "Las celdas permitidas se conservan y las bloqueadas quedan fuera.",
                visualLabel: causal ? "el futuro queda oculto"
                                    : (paddingIndex >= 0
                                       ? "el PAD detectado queda fuera"
                                       : "ejemplo hipotético: si hubiera PAD, quedaría fuera"),
                outputTitle: "Scores válidos", outputDetail: "Softmax sólo considerará las posiciones permitidas.",
                outputItems: [chip("permitidos", "result")],
                takeaway: causal
                          ? "La máscara cambia qué posiciones puede ver el token, no el contenido de sus Values."
                          : "Si la secuencia no contiene PAD, aplicar la máscara deja los scores exactamente iguales."
            }
        if (id === "softmax")
            return {
                kind: "softmax", phase: 2, title: "Repartir la atención entre los tokens",
                purpose: "Los scores se convierten en un reparto: una barra más alta significa que ese token influirá más.",
                question: "¿Cuánta importancia recibirá cada token permitido?",
                inputTitle: "Scores permitidos", inputDetail: "Pueden ser positivos, negativos o muy distintos.",
                inputItems: [chip("scores", "focus")],
                actionTitle: "Repartir la atención", actionDetail: "Más afinidad produce más peso; lo bloqueado recibe cero.",
                visualLabel: "cada barra indica importancia relativa",
                outputTitle: "Pesos de atención", outputDetail: "Forman un reparto para la Query seleccionada.",
                outputItems: [chip("pesos", "result")],
                takeaway: "Estos pesos indican cuánto participará cada Value en el nuevo contexto."
            }
        if (id === "weighted")
            return {
                kind: "weighted", phase: 2, title: "Mezclar la información útil",
                purpose: "Cada Value aporta información al contexto. Un peso mayor hace que su aporte sea más fuerte.",
                question: "¿Cómo se forma el nuevo contexto del token seleccionado?",
                inputTitle: "Pesos aplicados a los Values", inputDetail: "Cada peso multiplica el aporte de su Value.",
                inputItems: [chip("pesos", "focus"), chip("V", "v")],
                actionTitle: "Ponderar y sumar los aportes", actionDetail: "Los pesos vienen de Softmax; aquí se aplican a los Values y las contribuciones se suman.",
                visualLabel: "varios Values se reúnen en un contexto",
                outputTitle: "Contexto de la Query", outputDetail: "Resume la información relevante para ese token.",
                outputItems: [chip("contexto", "result")],
                takeaway: "Aquí ocurre la mezcla: cambiar un peso cambia cuánto aporta su Value al resultado."
            }
        if (id === "output")
            return {
                kind: "output", phase: 3, title: "Obtener tokens con información del contexto",
                purpose: "Sale un vector por token, en el mismo orden, pero ahora cada uno incorpora información relevante de otros tokens.",
                question: "¿Qué produce Self-Attention al terminar?",
                inputTitle: "Contextos de atención", inputDetail: "Cada posición ya reunió información relevante.",
                inputItems: [chip("contextos", "v")],
                actionTitle: "Preparar la salida", actionDetail: "Los contextos se organizan para volver a d_model.",
                visualLabel: "mismo orden · información enriquecida",
                outputTitle: "Vectores con contexto", outputDetail: "Pasan a la siguiente parte del Transformer.",
                outputItems: tokenChips(true),
                takeaway: "Self-Attention produce el mismo número de posiciones, pero cada vector ya conoce su contexto."
            }
        if (id === "backward")
            return {
                kind: "backward", phase: 3, learning: true, title: "Propagar la señal de error",
                purpose: "Durante el entrenamiento, el error recorre Self-Attention en sentido inverso.",
                question: "¿A qué pesos debe llegar la señal de error?",
                inputTitle: "Señal desde la pérdida", inputDetail: "Indica cuánto influyó esta parte en el error.",
                inputItems: [chip("error", "error")],
                actionTitle: "Volver por el recorrido", actionDetail: "La señal alcanza las rutas Q, K y V.",
                visualLabel: "la señal regresa hacia los pesos aprendidos",
                outputTitle: "Gradientes", outputDetail: "Describen qué ajuste convendría para WQ, WK y WV.",
                outputItems: [chip("gWQ", "q"), chip("gWK", "k"), chip("gWV", "v")],
                takeaway: "Backward calcula señales de cambio; todavía no modifica los pesos del modelo."
            }
        if (id === "update")
            return {
                kind: "update", phase: 1, learning: true, title: "Visualizar un ajuste de los pesos",
                purpose: "El laboratorio muestra cómo los gradientes orientarían un pequeño cambio en los parámetros.",
                question: "¿Cómo cambiarían WQ, WK y WV después de aprender del error?",
                inputTitle: "Pesos + gradientes", inputDetail: "Cada ruta recibe su propia señal.",
                inputItems: [chip("WQ", "q"), chip("WK", "k"), chip("WV", "v")],
                actionTitle: "Aplicar un cambio hipotético", actionDetail: "Se ilustra la dirección del ajuste sin alterar el modelo.",
                visualLabel: "antes → pequeño ajuste → después",
                outputTitle: "Pesos simulados", outputDetail: "Representan cómo sería el siguiente estado.",
                outputItems: [chip("WQ′", "q"), chip("WK′", "k"), chip("WV′", "v")],
                takeaway: "Esta vista no reentrena ni sobrescribe el modelo: sólo explica el posible ajuste."
            }
        return {
            kind: "input", phase: 0, title: "Formar la entrada de Self-Attention",
            purpose: "Cada token llega como un vector numérico que ya incluye su contenido y su posición en la frase.",
            question: "¿Qué información recibe Self-Attention antes de comenzar?",
            inputTitle: "Tokens en orden", inputDetail: "Se conserva una posición por token.",
            inputItems: tokenChips(false),
            actionTitle: "Reunir sus vectores", actionDetail: "Cada fila corresponde a un token de la secuencia.",
            visualLabel: "tokens → representaciones de entrada",
            outputTitle: "Matriz X", outputDetail: "Es la información que Self-Attention recibirá.",
            outputItems: [chip("X", "result")],
            takeaway: "Self-Attention recibe vectores de tokens ya posicionados, no texto sin procesar."
        }
    }

    function replay() {
        overviewAnimation.stop()
        progress = reducedMotion ? 1 : 0
        if (!reducedMotion)
            overviewAnimation.start()
    }

    onActiveChanged: if (active) replay()
    onStepIdChanged: if (active) replay()
    onTokensChanged: if (active) replay()
    onCausalChanged: if (active) replay()
    onReducedMotionChanged: if (active) replay()

    NumberAnimation {
        id: overviewAnimation
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 3000
        easing.type: Easing.InOutCubic
    }

    Flickable {
        id: overviewViewport
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, overviewContent.implicitHeight + 20 * root.sy)
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }
        ScrollBar.vertical: ScrollBar {
            policy: overviewViewport.contentHeight > overviewViewport.height
                    ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        ColumnLayout {
            id: overviewContent
            x: 11 * root.sx
            y: 9 * root.sy
            width: Math.max(1, overviewViewport.width - 22 * root.sx)
            spacing: 9 * root.sy

            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * root.sx
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 1
                    Text {
                        objectName: "selfAttentionOverviewTitle"
                        Layout.fillWidth: true
                        text: root.stageTitle
                        color: Style.Theme.texto_primario
                        font.bold: true
                        font.pixelSize: Math.max(15, 18 * Math.min(root.sx, root.sy))
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        objectName: "selfAttentionOverviewScope"
                        Layout.fillWidth: true
                        text: root.stagePurpose
                        color: Style.Theme.texto_secundario_fuerte
                        font.pixelSize: Math.max(10, 11 * root.sx)
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        objectName: "selfAttentionExampleContext"
                        Layout.fillWidth: true
                        text: "EJEMPLO VISIBLE · «" + root.phraseText + "»"
                              + (root.focusRelevant
                                 ? "   ·   TOKEN EN FOCO · «" + root.focusedTokenLabel() + "»"
                                 : "")
                        color: Style.Theme.acento_fuerte
                        font.bold: true
                        font.pixelSize: Math.max(8, 9 * root.sx)
                        wrapMode: Text.WordWrap
                    }
                }
                BotonAccesible {
                    objectName: "selfAttentionOverviewReplay"
                    Layout.preferredWidth: root.compact ? 38 * root.sx : 104 * root.sx
                    Layout.preferredHeight: 32 * root.sy
                    text: root.compact ? "↻" : "↻ Repetir"
                    Accessible.name: "Repetir animación conceptual de esta etapa"
                    onClicked: root.replay()
                }
            }

            Rectangle {
                id: processLocation
                objectName: "selfAttentionOverviewFlow"
                property bool interactive: false
                Layout.fillWidth: true
                Layout.preferredHeight: 88 * root.sy
                radius: 10 * root.sx
                color: Style.Theme.superficie_alterna
                border.color: Style.Theme.borde_suave

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8 * root.sx
                    spacing: 3 * root.sy

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8 * root.sx
                        Text {
                            Layout.fillWidth: true
                            text: "UBICACIÓN DENTRO DE SELF-ATTENTION"
                            color: Style.Theme.texto_secundario_fuerte
                            font.bold: true
                            font.pixelSize: Math.max(8, 9 * root.sx)
                            font.letterSpacing: 0.35
                            elide: Text.ElideRight
                        }
                        Text {
                            objectName: "selfAttentionLocationHint"
                            text: "Indicador informativo · no es un botón"
                            color: Style.Theme.texto_terciario
                            font.italic: true
                            font.pixelSize: Math.max(8, 9 * root.sx)
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: parent.width / 8
                            anchors.rightMargin: parent.width / 8
                            y: 16 * root.sy
                            height: Math.max(2, 2 * root.sy)
                            radius: height / 2
                            color: Style.Theme.borde_medio
                        }

                        RowLayout {
                            anchors.fill: parent
                            spacing: 0
                            Repeater {
                                model: root.globalMoments
                                delegate: Item {
                                    id: flowMoment
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    readonly property bool current: index === root.globalPhase

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: flowMoment.current ? 7 * root.sy : 11 * root.sy
                                        width: flowMoment.current ? 20 * root.sx : 11 * root.sx
                                        height: flowMoment.current ? 20 * root.sy : 11 * root.sy
                                        radius: width / 2
                                        color: flowMoment.current
                                               ? flowMoment.modelData.color
                                               : Style.Theme.surface
                                        border.width: 2
                                        border.color: flowMoment.modelData.color
                                    }
                                    Text {
                                        visible: flowMoment.current
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: -4 * root.sy
                                        text: "ESTÁS AQUÍ"
                                        color: flowMoment.modelData.color
                                        font.bold: true
                                        font.pixelSize: Math.max(7, 8 * root.sx)
                                    }
                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        text: flowMoment.modelData.label
                                        color: flowMoment.current
                                               ? flowMoment.modelData.color
                                               : Style.Theme.texto_terciario
                                        font.bold: flowMoment.current
                                        font.pixelSize: Math.max(8, 9 * root.sx)
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                objectName: "selfAttentionStageQuestion"
                Layout.fillWidth: true
                implicitHeight: stageQuestionText.implicitHeight + 12 * root.sy
                radius: 8 * root.sx
                color: Style.Theme.info_fondo
                border.color: Style.Theme.inferencia_estructura
                Text {
                    id: stageQuestionText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 8 * root.sx
                    text: "PREGUNTA GUÍA · " + root.stageQuestion
                    color: Style.Theme.info_texto
                    font.bold: true
                    font.pixelSize: Math.max(9, 10 * root.sx)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }

            Text {
                visible: root.learningStage
                Layout.fillWidth: true
                text: "ENTRENAMIENTO · la señal vuelve por este recorrido para aprender"
                color: Style.Theme.inferencia_transformacion
                font.bold: true
                font.pixelSize: Math.max(9, 10 * root.sx)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Text {
                objectName: "selfAttentionReadingHint"
                Layout.fillWidth: true
                text: root.compact
                      ? "LEE DE ARRIBA HACIA ABAJO · 1 qué entra → 2 qué pasa → 3 qué sale"
                      : "LEE DE IZQUIERDA A DERECHA · 1 qué entra → 2 qué pasa → 3 qué sale"
                color: Style.Theme.texto_terciario
                font.bold: true
                font.pixelSize: Math.max(8, 9 * root.sx)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Text {
                objectName: "selfAttentionStageNarration"
                Layout.fillWidth: true
                text: root.stageNarration
                color: root.progress < 0.24
                       ? Style.Theme.inferencia_estructura
                       : (root.progress < 0.70
                          ? Style.Theme.inferencia_transformacion
                          : Style.Theme.inferencia_resultado)
                font.bold: true
                font.pixelSize: Math.max(9, 10 * root.sx)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            GridLayout {
                id: stageGrid
                objectName: "selfAttentionStageCards"
                Layout.fillWidth: true
                columns: root.stageColumns
                columnSpacing: 9 * root.sx
                rowSpacing: 8 * root.sy

                Rectangle {
                    objectName: "selfAttentionStageInput"
                    Layout.fillWidth: true
                    Layout.columnSpan: 1
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: root.compact
                                           ? stageGrid.width
                                           : stageGrid.width * 0.23
                    Layout.preferredHeight: root.stageCardHeight
                    radius: 13 * root.sx
                    color: Style.Theme.surface
                    border.width: root.progress < 0.34 ? 2 : 1
                    border.color: Style.Theme.inferencia_estructura
                    opacity: 0.28 + 0.72 * root.inputReveal
                    StageCardContent {
                        anchors.fill: parent
                        anchors.margins: 10 * root.sx
                        number: "1"
                        eyebrow: "QUÉ ENTRA"
                        title: root.stageInput
                        detail: String(root.stageDefinition.inputDetail || "")
                        items: root.stageDefinition.inputItems || []
                        accent: Style.Theme.inferencia_estructura
                        sx: root.sx; sy: root.sy
                    }
                }

                Rectangle {
                    objectName: "selfAttentionStageAction"
                    Layout.fillWidth: true
                    Layout.columnSpan: root.compact ? 1 : 2
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: root.compact
                                           ? stageGrid.width
                                           : stageGrid.width * 0.50
                    Layout.preferredHeight: root.stageCardHeight
                    radius: 13 * root.sx
                    color: Style.Theme.surface
                    border.width: root.progress >= 0.24 && root.progress < 0.78 ? 2 : 1
                    border.color: Style.Theme.inferencia_transformacion
                    opacity: 0.28 + 0.72 * root.operationReveal

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10 * root.sx
                        spacing: 5 * root.sy
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6 * root.sx
                            Rectangle {
                                Layout.preferredWidth: 25 * root.sx
                                Layout.preferredHeight: 25 * root.sy
                                radius: height / 2
                                color: Style.Theme.inferencia_transformacion
                                Text { anchors.centerIn: parent; text: "2"; color: Style.Theme.texto_sobre_color; font.bold: true; font.pixelSize: Math.max(9, 10 * root.sx) }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "QUÉ PASA"
                                color: Style.Theme.inferencia_transformacion
                                font.bold: true
                                font.pixelSize: Math.max(8, 9 * root.sx)
                                font.letterSpacing: 0.4
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.stageAction
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: Math.max(11, 13 * root.sx)
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Canvas {
                            id: stageGraphic
                            objectName: "selfAttentionStageGraphic"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 54 * root.sy
                            property string kind: root.stageKind
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onKindChanged: requestPaint()
                            Component.onCompleted: requestPaint()
                            Connections {
                                target: root
                                function onProgressChanged() { stageGraphic.requestPaint() }
                                function onFocusedIndexChanged() { stageGraphic.requestPaint() }
                                function onCausalChanged() { stageGraphic.requestPaint() }
                            }
                            onPaint: root.paintStage(getContext("2d"), width, height)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: String(root.stageDefinition.visualLabel || "")
                            color: Style.Theme.inferencia_transformacion
                            font.bold: true
                            font.pixelSize: Math.max(8, 9 * root.sx)
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            Layout.fillWidth: true
                            text: String(root.stageDefinition.actionDetail || "")
                            color: Style.Theme.texto_secundario_fuerte
                            font.pixelSize: Math.max(8, 9 * root.sx)
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Rectangle {
                    objectName: "selfAttentionStageOutput"
                    Layout.fillWidth: true
                    Layout.columnSpan: 1
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: root.compact
                                           ? stageGrid.width
                                           : stageGrid.width * 0.23
                    Layout.preferredHeight: root.stageCardHeight
                    radius: 13 * root.sx
                    color: Style.Theme.surface
                    border.width: root.progress >= 0.76 ? 2 : 1
                    border.color: Style.Theme.inferencia_resultado
                    opacity: 0.28 + 0.72 * root.outputReveal
                    StageCardContent {
                        anchors.fill: parent
                        anchors.margins: 10 * root.sx
                        number: "3"
                        eyebrow: "QUÉ SALE"
                        title: root.stageOutput
                        detail: String(root.stageDefinition.outputDetail || "")
                        items: root.stageDefinition.outputItems || []
                        accent: Style.Theme.inferencia_resultado
                        sx: root.sx; sy: root.sy
                    }
                }
            }

            Rectangle {
                objectName: "selfAttentionOverviewTakeaway"
                Layout.fillWidth: true
                implicitHeight: takeawayText.implicitHeight + 16 * root.sy
                radius: 10 * root.sx
                color: root.learningStage ? Style.Theme.acento_fondo : Style.Theme.exito_fondo
                border.color: root.learningStage
                              ? Style.Theme.inferencia_transformacion
                              : Style.Theme.inferencia_resultado
                opacity: 0.28 + 0.72 * root.outputReveal
                Text {
                    id: takeawayText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 10 * root.sx
                    text: "EN PALABRAS SIMPLES · " + root.stageTakeaway
                    color: root.learningStage ? Style.Theme.acento_texto : Style.Theme.exito_texto
                    font.bold: true
                    font.pixelSize: Math.max(9, 10 * root.sx)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    function colorText(color) {
        return String(color)
    }

    function canvasBlock(ctx, x, y, w, h, fill, stroke, label, ink, alpha) {
        ctx.save()
        ctx.globalAlpha = alpha === undefined ? 1 : alpha
        ctx.fillStyle = colorText(fill)
        ctx.strokeStyle = colorText(stroke)
        ctx.lineWidth = Math.max(1, 1.2 * sx)
        ctx.fillRect(x, y, w, h)
        ctx.strokeRect(x, y, w, h)
        if (label) {
            ctx.fillStyle = colorText(ink || Style.Theme.texto_primario)
            ctx.font = "bold " + Math.max(8, 9 * sx) + "px sans-serif"
            ctx.textAlign = "center"
            ctx.textBaseline = "middle"
            ctx.fillText(String(label), x + w / 2, y + h / 2,
                         Math.max(4, w - 5 * sx))
        }
        ctx.restore()
    }

    function canvasArrow(ctx, x1, y1, x2, y2, color, width, alpha) {
        var angle = Math.atan2(y2 - y1, x2 - x1)
        var head = Math.max(5, 6 * sx)
        ctx.save()
        ctx.globalAlpha = alpha === undefined ? 1 : alpha
        ctx.strokeStyle = colorText(color)
        ctx.fillStyle = colorText(color)
        ctx.lineWidth = Math.max(1, width || 1.5 * sx)
        ctx.beginPath()
        ctx.moveTo(x1, y1)
        ctx.lineTo(x2, y2)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(x2, y2)
        ctx.lineTo(x2 - head * Math.cos(angle - Math.PI / 6),
                   y2 - head * Math.sin(angle - Math.PI / 6))
        ctx.lineTo(x2 - head * Math.cos(angle + Math.PI / 6),
                   y2 - head * Math.sin(angle + Math.PI / 6))
        ctx.closePath()
        ctx.fill()
        ctx.restore()
    }

    function canvasGrowingArrow(ctx, x1, y1, x2, y2, color, width, amount) {
        var progressValue = clamp01(amount)
        var currentX = x1 + (x2 - x1) * progressValue
        var currentY = y1 + (y2 - y1) * progressValue
        canvasArrow(ctx, x1, y1, currentX, currentY, color, width,
                    0.18 + 0.82 * progressValue)
    }

    function canvasCross(ctx, x, y, size, color, alpha) {
        ctx.save()
        ctx.globalAlpha = alpha
        ctx.strokeStyle = colorText(color)
        ctx.lineWidth = Math.max(2, 2.2 * sx)
        ctx.beginPath()
        ctx.moveTo(x - size, y - size)
        ctx.lineTo(x + size, y + size)
        ctx.moveTo(x + size, y - size)
        ctx.lineTo(x - size, y + size)
        ctx.stroke()
        ctx.restore()
    }

    function paintStage(ctx, width, height) {
        ctx.reset()
        var reveal = Math.max(0.08, operationReveal)
        var q = Style.Theme.matriz_query
        var qf = Style.Theme.matriz_query_fondo
        var k = Style.Theme.matriz_key
        var kf = Style.Theme.matriz_key_fondo
        var v = Style.Theme.matriz_value
        var vf = Style.Theme.matriz_value_fondo
        var focus = Style.Theme.inferencia_foco
        var result = Style.Theme.inferencia_resultado
        var structure = Style.Theme.inferencia_estructura
        var transform = Style.Theme.inferencia_transformacion
        var error = Style.Theme.inferencia_error
        var ink = Style.Theme.texto_primario
        var cy = height / 2
        var kind = stageKind
        var tokenCount = Math.max(1, visibleTokenCount)

        if (kind === "input") {
            var tokenGap = 3 * sx
            var tokenArea = width * 0.43
            var tw = Math.min(48 * sx,
                              (tokenArea - tokenGap * (tokenCount - 1)) / tokenCount)
            for (var ti = 0; ti < tokenCount; ++ti)
                canvasBlock(ctx, 4 + ti * (tw + tokenGap), cy - 13 * sy,
                            tw, 26 * sy, Style.Theme.info_fondo, structure,
                            tokenLabelAt(ti, "T" + (ti + 1)), ink, reveal)
            canvasGrowingArrow(ctx, width * 0.48, cy, width * 0.61, cy,
                               transform, 1.5 * sx, reveal)
            for (var ri = 0; ri < tokenCount; ++ri)
                canvasBlock(ctx, width * 0.66,
                            4 + ri * Math.max(11, (height - 8) / tokenCount),
                            width * 0.29, Math.max(8, (height - 14) / tokenCount),
                            Style.Theme.exito_fondo, result, ri === 1 ? "X" : "", ink, reveal)
            return
        }
        if (kind === "learned_weights" || kind === "qkv") {
            canvasBlock(ctx, 5 * sx, cy - 15 * sy, width * 0.23, 30 * sy,
                        Style.Theme.info_fondo, structure,
                        kind === "qkv" ? focusedTokenLabel() : "X", ink, reveal)
            var roles = [
                { label: kind === "qkv" ? "Q" : "WQ", color: q, fill: qf },
                { label: kind === "qkv" ? "K" : "WK", color: k, fill: kf },
                { label: kind === "qkv" ? "V" : "WV", color: v, fill: vf }
            ]
            for (var role = 0; role < roles.length; ++role) {
                var ry = 3 + role * Math.max(20 * sy, (height - 8) / 3)
                canvasGrowingArrow(ctx, width * 0.29, cy,
                                   width * 0.57, ry + 11 * sy,
                                   roles[role].color, 1.4 * sx, reveal)
                canvasBlock(ctx, width * 0.61, ry, width * 0.32, 22 * sy,
                            roles[role].fill, roles[role].color,
                            roles[role].label, ink, reveal)
            }
            return
        }
        if (kind === "compatibility") {
            canvasBlock(ctx, width * 0.39, 2, width * 0.22, 25 * sy,
                        qf, q, "Q · " + focusedTokenLabel(),
                        Style.Theme.matriz_query_texto, reveal)
            var maximum = maximumWeight()
            for (var ci = 0; ci < tokenCount; ++ci) {
                var compatibilitySlot = width / tokenCount
                var compatibilityWidth = Math.min(width * 0.18,
                                                  compatibilitySlot * 0.74)
                var cx = (ci + 0.5) * compatibilitySlot
                         - compatibilityWidth / 2
                var strength = maximum > 0 ? weightFor(ci) / maximum : 0.25
                canvasGrowingArrow(ctx, width * 0.5, 28 * sy,
                                   cx + compatibilityWidth / 2, height - 24 * sy,
                                   focus, (0.7 + strength * 4) * sx, reveal)
                canvasBlock(ctx, cx, height - 23 * sy,
                            compatibilityWidth, 21 * sy,
                            kf, k, tokenLabelAt(ci, "K" + (ci + 1)),
                            Style.Theme.matriz_key_texto,
                            connectionAllowed(ci) ? reveal : 0.22 * reveal)
            }
            return
        }
        if (kind === "scale") {
            var raw = [0.88, 0.50, 0.72, 0.34]
            for (var bi = 0; bi < tokenCount; ++bi) {
                var bh = Math.max(6, height * raw[bi] * 0.75)
                ctx.globalAlpha = reveal
                ctx.fillStyle = colorText(focus)
                ctx.fillRect(5 + bi * width * 0.30 / tokenCount,
                             height - bh, width * 0.18 / tokenCount, bh)
            }
            canvasGrowingArrow(ctx, width * 0.37, cy, width * 0.58, cy,
                               transform, 1.5 * sx, reveal)
            for (var sj = 0; sj < tokenCount; ++sj) {
                var sh = Math.max(6, height * raw[sj] * 0.43 * reveal)
                ctx.globalAlpha = reveal
                ctx.fillStyle = colorText(result)
                ctx.fillRect(width * 0.63 + sj * width * 0.30 / tokenCount,
                             height - sh, width * 0.18 / tokenCount, sh)
            }
            ctx.globalAlpha = 1
            return
        }
        if (kind === "mask") {
            for (var mi = 0; mi < tokenCount; ++mi) {
                var hypotheticalPad = !causal && paddingIndex < 0
                                       && mi === tokenCount - 1
                var blocked = causal ? mi > focusedIndex
                                     : (paddingIndex >= 0
                                        ? mi === paddingIndex : hypotheticalPad)
                var maskSlot = width / tokenCount
                var maskWidth = Math.min(width * 0.19, maskSlot * 0.74)
                var mx = (mi + 0.5) * maskSlot - maskWidth / 2
                canvasBlock(ctx, mx, cy - 18 * sy, maskWidth, 36 * sy,
                            blocked ? Style.Theme.error_fondo : kf,
                            blocked ? error : k,
                            hypotheticalPad ? "PAD (ej.)"
                                            : tokenLabelAt(mi, "K" + (mi + 1)),
                            blocked ? Style.Theme.error_texto : Style.Theme.matriz_key_texto,
                            blocked ? 0.52 * reveal : reveal)
                if (blocked)
                    canvasCross(ctx, mx + maskWidth / 2, cy,
                                Math.min(10 * sx, width * 0.035), error, reveal)
            }
            return
        }
        if (kind === "softmax") {
            var maximumSoftmax = maximumWeight()
            for (var wi = 0; wi < tokenCount; ++wi) {
                var currentWeight = weightFor(wi)
                var relativeWeight = maximumSoftmax > 0
                                     ? currentWeight / maximumSoftmax : 0.25
                var barHeight = Math.max(7, height * relativeWeight * 0.72 * reveal)
                var softmaxSlot = width / tokenCount
                var softmaxWidth = Math.min(width * 0.12, softmaxSlot * 0.52)
                var bx = (wi + 0.5) * softmaxSlot - softmaxWidth / 2
                ctx.globalAlpha = reveal
                ctx.fillStyle = colorText(result)
                ctx.fillRect(bx, height - barHeight - 14 * sy,
                             softmaxWidth, barHeight)
                ctx.fillStyle = colorText(Style.Theme.texto_secundario)
                ctx.font = "bold " + Math.max(7, 8 * sx) + "px sans-serif"
                ctx.textAlign = "center"
                ctx.fillText(tokenLabelAt(wi, "K" + (wi + 1)),
                             bx + softmaxWidth / 2, height - 3 * sy,
                             softmaxSlot * 0.88)
                if (hasCapturedWeights()) {
                    ctx.fillStyle = colorText(result)
                    ctx.fillText(Math.round(currentWeight * 100) + "%",
                                 bx + softmaxWidth / 2,
                                 Math.max(7 * sy, height - barHeight - 18 * sy))
                }
            }
            ctx.globalAlpha = 1
            return
        }
        if (kind === "weighted") {
            var maximumContribution = maximumWeight()
            for (var vi = 0; vi < tokenCount; ++vi) {
                var contribution = maximumContribution > 0
                                   ? weightFor(vi) / maximumContribution : 0.25
                var vx = width * 0.02 + vi * width * 0.68 / tokenCount
                var size = (16 + contribution * 14) * Math.min(sx, sy)
                canvasBlock(ctx, vx, cy - size / 2, size, size,
                            vf, v, tokenLabelAt(vi, "V" + (vi + 1)),
                            Style.Theme.matriz_value_texto,
                            (0.35 + contribution * 0.65) * reveal)
                canvasGrowingArrow(ctx, vx + size, cy, width * 0.78, cy,
                                   v, (0.7 + contribution * 2.6) * sx, reveal)
            }
            canvasBlock(ctx, width * 0.80, cy - 20 * sy, width * 0.17, 40 * sy,
                        Style.Theme.exito_fondo, result, "C", Style.Theme.exito_texto, reveal)
            return
        }
        if (kind === "output") {
            canvasBlock(ctx, width * 0.03, cy - 22 * sy, width * 0.25, 44 * sy,
                        vf, v, "contexto", Style.Theme.matriz_value_texto, reveal)
            canvasGrowingArrow(ctx, width * 0.30, cy, width * 0.55, cy,
                               transform, 1.6 * sx, reveal)
            for (var oi = 0; oi < 3; ++oi)
                canvasBlock(ctx, width * 0.61, 3 + oi * Math.max(18, (height - 7) / 3),
                            width * 0.32, Math.max(15, (height - 12) / 3),
                            Style.Theme.exito_fondo, result,
                            oi === 1 ? "+ contexto" : "", Style.Theme.exito_texto, reveal)
            return
        }
        if (kind === "backward") {
            var backRoles = [
                { label: "WQ", color: q, fill: qf },
                { label: "WK", color: k, fill: kf },
                { label: "WV", color: v, fill: vf }
            ]
            canvasBlock(ctx, width * 0.75, cy - 18 * sy, width * 0.21, 36 * sy,
                        Style.Theme.error_fondo, error, "error", Style.Theme.error_texto, reveal)
            for (var br = 0; br < backRoles.length; ++br) {
                var by = 2 + br * Math.max(20, (height - 6) / 3)
                canvasGrowingArrow(ctx, width * 0.74, cy,
                                   width * 0.31, by + 10 * sy,
                                   error, 1.5 * sx, reveal)
                canvasBlock(ctx, width * 0.04, by, width * 0.25, 21 * sy,
                            backRoles[br].fill, backRoles[br].color,
                            backRoles[br].label, ink, reveal)
            }
            return
        }

        var updateRoles = [
            { label: "WQ", color: q, fill: qf },
            { label: "WK", color: k, fill: kf },
            { label: "WV", color: v, fill: vf }
        ]
        for (var ur = 0; ur < updateRoles.length; ++ur) {
            var uy = 2 + ur * Math.max(20, (height - 6) / 3)
            canvasBlock(ctx, width * 0.02, uy, width * 0.23, 21 * sy,
                        updateRoles[ur].fill, updateRoles[ur].color,
                        updateRoles[ur].label, ink, reveal)
            canvasGrowingArrow(ctx, width * 0.28, uy + 10 * sy,
                               width * 0.63, uy + 10 * sy,
                               transform, 1.3 * sx, reveal)
            canvasBlock(ctx, width * 0.68, uy, width * 0.28, 21 * sy,
                        updateRoles[ur].fill, updateRoles[ur].color,
                        updateRoles[ur].label + "′", ink, reveal)
        }
    }

    component StageCardContent: ColumnLayout {
        id: cardContent
        property string number: "1"
        property string eyebrow: "RECIBE"
        property string title: "Entrada"
        property string detail: ""
        property var items: []
        property color accent: Style.Theme.acento
        property real sx: 1
        property real sy: 1
        spacing: 6 * sy

        RowLayout {
            Layout.fillWidth: true
            spacing: 6 * cardContent.sx
            Rectangle {
                Layout.preferredWidth: 25 * cardContent.sx
                Layout.preferredHeight: 25 * cardContent.sy
                radius: height / 2
                color: cardContent.accent
                Text {
                    anchors.centerIn: parent
                    text: cardContent.number
                    color: Style.Theme.texto_sobre_color
                    font.bold: true
                    font.pixelSize: Math.max(9, 10 * cardContent.sx)
                }
            }
            Text {
                Layout.fillWidth: true
                text: cardContent.eyebrow
                color: cardContent.accent
                font.bold: true
                font.pixelSize: Math.max(8, 9 * cardContent.sx)
                font.letterSpacing: 0.4
            }
        }
        Text {
            Layout.fillWidth: true
            text: cardContent.title
            color: Style.Theme.texto_primario
            font.bold: true
            font.pixelSize: Math.max(11, 13 * cardContent.sx)
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
        Item { Layout.fillHeight: true; Layout.minimumHeight: 2 * cardContent.sy }
        RowLayout {
            Layout.fillWidth: true
            spacing: 4 * cardContent.sx
            Repeater {
                model: cardContent.items
                delegate: Rectangle {
                    id: itemChip
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: 42 * cardContent.sy
                    radius: 8 * cardContent.sx
                    color: itemChip.modelData.fill
                    border.color: itemChip.modelData.color
                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 6 * cardContent.sx
                        text: itemChip.modelData.label
                        color: itemChip.modelData.ink
                        font.bold: true
                        font.pixelSize: Math.max(8, 9 * cardContent.sx)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }
            }
        }
        Item { Layout.fillHeight: true; Layout.minimumHeight: 2 * cardContent.sy }
        Text {
            Layout.fillWidth: true
            text: cardContent.detail
            color: Style.Theme.texto_secundario_fuerte
            font.pixelSize: Math.max(8, 9 * cardContent.sx)
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
