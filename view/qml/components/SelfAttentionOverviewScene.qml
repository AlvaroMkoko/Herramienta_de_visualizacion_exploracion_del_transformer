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
    readonly property int stageColumns: compact ? 1 : 3
    readonly property real stageCardHeight: compact ? 128 * sy : 238 * sy
    readonly property var displayTokens: buildDisplayTokens()
    readonly property int visibleTokenCount: displayTokens.length
    readonly property int focusedIndex: resolveFocusedIndex()
    readonly property int maximumConnectionCount: visibleTokenCount
    readonly property int visibleConnectionCount: countVisibleConnections()
    readonly property var stageDefinition: definitionFor(stepId)
    readonly property string stageKind: String(stageDefinition.kind || "input")
    readonly property string stageIdentity: String(stepId) + ":" + stageKind
    readonly property string stageTitle: String(stageDefinition.title || "Self-Attention")
    readonly property string stagePurpose: String(stageDefinition.purpose || "")
    readonly property string stageInput: String(stageDefinition.inputTitle || "Entrada")
    readonly property string stageAction: String(stageDefinition.actionTitle || "Transformación")
    readonly property string stageOutput: String(stageDefinition.outputTitle || "Salida")
    readonly property string stageTakeaway: String(stageDefinition.takeaway || "")
    readonly property int globalPhase: Number(stageDefinition.phase || 0)
    readonly property bool learningStage: Boolean(stageDefinition.learning)
    readonly property real inputReveal: revealBetween(0.02, 0.24)
    readonly property real operationReveal: revealBetween(0.24, 0.70)
    readonly property real outputReveal: revealBetween(0.70, 0.94)
    readonly property var globalMoments: [
        { label: "ENTRADA", color: Style.Theme.inferencia_estructura },
        { label: "Q / K / V", color: Style.Theme.inferencia_transformacion },
        { label: "ATENCIÓN", color: Style.Theme.inferencia_foco },
        { label: "CONTEXTO", color: Style.Theme.inferencia_resultado }
    ]

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

    function resolveFocusedIndex() {
        var candidate = selectedToken
        if (attentionData && attentionData.query_seleccionada !== undefined)
            candidate = Number(attentionData.query_seleccionada)
        return Math.max(0, Math.min(Math.max(0, visibleTokenCount - 1),
                                    Number(candidate || 0)))
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
                kind: "learned_weights", phase: 1, title: "Pesos que preparan Q, K y V",
                purpose: "Self-Attention aprende tres formas distintas de leer la misma representación de entrada.",
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
                kind: "qkv", phase: 1, title: "Crear Query, Key y Value",
                purpose: "Cada token adopta tres papeles complementarios antes de relacionarse con los demás.",
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
                kind: "compatibility", phase: 2, title: "Comparar una Query con las Keys",
                purpose: "La Query del token seleccionado revisa qué Keys pueden aportarle contexto útil.",
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
                kind: "scale", phase: 2, title: "Equilibrar los scores",
                purpose: "Los scores se moderan para que unas diferencias muy grandes no dominen el paso siguiente.",
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
                         ? "La máscara causal impide consultar posiciones que todavía no existen en el prefijo."
                         : "La máscara evita que el relleno PAD reciba atención; si no hay PAD, nada cambia.",
                inputTitle: "Scores + posiciones permitidas", inputDetail: causal
                            ? "El prefijo define qué Keys ya son visibles."
                            : "Se distingue un token real de una posición PAD.",
                inputItems: causal ? [chip("pasado", "k"), chip("futuro", "error")]
                                   : [chip("token real", "k"), chip("PAD", "error")],
                actionTitle: "Bloquear lo no permitido", actionDetail: "Sólo se atenúan las celdas que no deben participar.",
                visualLabel: causal ? "el futuro queda oculto" : "PAD queda fuera de la atención",
                outputTitle: "Scores válidos", outputDetail: "Softmax sólo considerará las posiciones permitidas.",
                outputItems: [chip("permitidos", "result")],
                takeaway: causal
                          ? "La máscara cambia qué posiciones puede ver el token, no el contenido de sus Values."
                          : "Si la secuencia no contiene PAD, aplicar la máscara deja los scores exactamente iguales."
            }
        if (id === "softmax")
            return {
                kind: "softmax", phase: 2, title: "Convertir scores en pesos de atención",
                purpose: "Las afinidades se convierten en importancias relativas fáciles de comparar.",
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
                kind: "weighted", phase: 2, title: "Combinar la información de los Values",
                purpose: "Cada Value aporta más o menos información según el peso de atención que recibió.",
                inputTitle: "Pesos + Values", inputDetail: "El peso controla la contribución; V aporta el contenido.",
                inputItems: [chip("pesos", "focus"), chip("V", "v")],
                actionTitle: "Mezclar contribuciones", actionDetail: "Las aportaciones fuertes se ven más marcadas.",
                visualLabel: "varios Values se reúnen en un contexto",
                outputTitle: "Contexto de la Query", outputDetail: "Resume la información relevante para ese token.",
                outputItems: [chip("contexto", "result")],
                takeaway: "Aquí ocurre la mezcla: cambiar un peso cambia cuánto aporta su Value al resultado."
            }
        if (id === "output")
            return {
                kind: "output", phase: 3, title: "Entregar representaciones contextualizadas",
                purpose: "El resultado conserva un vector por token, ahora enriquecido con información de la secuencia.",
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
            purpose: "Cada token llega como un vector que combina su contenido con información de posición.",
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
                objectName: "selfAttentionOverviewFlow"
                Layout.fillWidth: true
                Layout.preferredHeight: root.veryCompact ? 86 * root.sy : 58 * root.sy
                radius: 10 * root.sx
                color: Style.Theme.superficie_alterna
                border.color: Style.Theme.borde_suave

                GridLayout {
                    anchors.fill: parent
                    anchors.margins: 7 * root.sx
                    columns: root.veryCompact ? 2 : 4
                    columnSpacing: 5 * root.sx
                    rowSpacing: 5 * root.sy
                    Repeater {
                        model: root.globalMoments
                        delegate: Rectangle {
                            id: flowMoment
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 7 * root.sx
                            color: flowMoment.index === root.globalPhase
                                   ? Qt.alpha(flowMoment.modelData.color, 0.18)
                                   : Style.Theme.surface
                            border.width: flowMoment.index === root.globalPhase ? 2 : 1
                            border.color: flowMoment.index === root.globalPhase
                                          ? flowMoment.modelData.color
                                          : Style.Theme.borde_suave
                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 6 * root.sx
                                text: flowMoment.modelData.label
                                color: flowMoment.index === root.globalPhase
                                       ? flowMoment.modelData.color
                                       : Style.Theme.texto_terciario
                                font.bold: true
                                font.pixelSize: Math.max(8, 9 * root.sx)
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                        }
                    }
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
                        eyebrow: "RECIBE"
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
                                text: "QUÉ OCURRE"
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
                        eyebrow: "PRODUCE"
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
                    text: "IDEA CLAVE · " + root.stageTakeaway
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
            ctx.fillText(String(label), x + w / 2, y + h / 2)
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

        if (kind === "input") {
            var tw = Math.min(30 * sx, width * 0.10)
            for (var ti = 0; ti < 4; ++ti)
                canvasBlock(ctx, 4 + ti * (tw + 3 * sx), cy - 13 * sy,
                            tw, 26 * sy, Style.Theme.info_fondo, structure,
                            "T" + (ti + 1), ink, reveal)
            canvasArrow(ctx, width * 0.48, cy, width * 0.61, cy,
                        transform, 1.5 * sx, reveal)
            for (var ri = 0; ri < 4; ++ri)
                canvasBlock(ctx, width * 0.66, 4 + ri * Math.max(11, (height - 8) / 4),
                            width * 0.29, Math.max(8, (height - 14) / 4),
                            Style.Theme.exito_fondo, result, ri === 1 ? "X" : "", ink, reveal)
            return
        }
        if (kind === "learned_weights" || kind === "qkv") {
            canvasBlock(ctx, 5 * sx, cy - 15 * sy, width * 0.23, 30 * sy,
                        Style.Theme.info_fondo, structure,
                        kind === "qkv" ? "token" : "X", ink, reveal)
            var roles = [
                { label: kind === "qkv" ? "Q" : "WQ", color: q, fill: qf },
                { label: kind === "qkv" ? "K" : "WK", color: k, fill: kf },
                { label: kind === "qkv" ? "V" : "WV", color: v, fill: vf }
            ]
            for (var role = 0; role < roles.length; ++role) {
                var ry = 3 + role * Math.max(20 * sy, (height - 8) / 3)
                canvasArrow(ctx, width * 0.29, cy, width * 0.57, ry + 11 * sy,
                            roles[role].color, 1.4 * sx, reveal)
                canvasBlock(ctx, width * 0.61, ry, width * 0.32, 22 * sy,
                            roles[role].fill, roles[role].color,
                            roles[role].label, ink, reveal)
            }
            return
        }
        if (kind === "compatibility") {
            canvasBlock(ctx, width * 0.39, 2, width * 0.22, 25 * sy,
                        qf, q, "Q", Style.Theme.matriz_query_texto, reveal)
            var strengths = [0.22, 0.50, 0.30, 0.88]
            for (var ci = 0; ci < 4; ++ci) {
                var cx = width * (0.04 + ci * 0.245)
                canvasArrow(ctx, width * 0.5, 28 * sy, cx + width * 0.09, height - 24 * sy,
                            focus, (0.7 + strengths[ci] * 4) * sx, reveal)
                canvasBlock(ctx, cx, height - 23 * sy, width * 0.18, 21 * sy,
                            kf, k, "K" + (ci + 1), Style.Theme.matriz_key_texto,
                            connectionAllowed(ci) ? reveal : 0.22 * reveal)
            }
            return
        }
        if (kind === "scale") {
            var raw = [0.88, 0.50, 0.72, 0.34]
            for (var bi = 0; bi < 4; ++bi) {
                var bh = Math.max(6, height * raw[bi] * 0.75)
                ctx.globalAlpha = reveal
                ctx.fillStyle = colorText(focus)
                ctx.fillRect(5 + bi * width * 0.075, height - bh, width * 0.045, bh)
            }
            canvasArrow(ctx, width * 0.37, cy, width * 0.58, cy,
                        transform, 1.5 * sx, reveal)
            for (var sj = 0; sj < 4; ++sj) {
                var sh = Math.max(6, height * raw[sj] * 0.43)
                ctx.globalAlpha = reveal
                ctx.fillStyle = colorText(result)
                ctx.fillRect(width * 0.63 + sj * width * 0.075,
                             height - sh, width * 0.045, sh)
            }
            ctx.globalAlpha = 1
            return
        }
        if (kind === "mask") {
            for (var mi = 0; mi < 4; ++mi) {
                var blocked = causal ? mi > focusedIndex : mi === 3
                var mx = width * (0.03 + mi * 0.245)
                canvasBlock(ctx, mx, cy - 18 * sy, width * 0.19, 36 * sy,
                            blocked ? Style.Theme.error_fondo : kf,
                            blocked ? error : k,
                            (!causal && mi === 3) ? "PAD" : "K" + (mi + 1),
                            blocked ? Style.Theme.error_texto : Style.Theme.matriz_key_texto,
                            blocked ? 0.52 * reveal : reveal)
                if (blocked)
                    canvasCross(ctx, mx + width * 0.095, cy,
                                Math.min(10 * sx, width * 0.035), error, reveal)
            }
            return
        }
        if (kind === "softmax") {
            var weights = [0.18, 0.44, 0.28, 0.76]
            for (var wi = 0; wi < 4; ++wi) {
                var barHeight = Math.max(7, height * weights[wi] * 0.72)
                var bx = width * (0.06 + wi * 0.235)
                ctx.globalAlpha = reveal
                ctx.fillStyle = colorText(result)
                ctx.fillRect(bx, height - barHeight - 14 * sy,
                             width * 0.12, barHeight)
                ctx.fillStyle = colorText(Style.Theme.texto_secundario)
                ctx.font = "bold " + Math.max(7, 8 * sx) + "px sans-serif"
                ctx.textAlign = "center"
                ctx.fillText("K" + (wi + 1), bx + width * 0.06, height - 3 * sy)
            }
            ctx.globalAlpha = 1
            return
        }
        if (kind === "weighted") {
            var contribution = [0.22, 0.46, 0.30, 0.82]
            for (var vi = 0; vi < 4; ++vi) {
                var vx = width * (0.02 + vi * 0.17)
                var size = (16 + contribution[vi] * 14) * Math.min(sx, sy)
                canvasBlock(ctx, vx, cy - size / 2, size, size,
                            vf, v, "V" + (vi + 1), Style.Theme.matriz_value_texto,
                            (0.35 + contribution[vi] * 0.65) * reveal)
                canvasArrow(ctx, vx + size, cy, width * 0.78, cy,
                            v, (0.7 + contribution[vi] * 2.6) * sx, reveal)
            }
            canvasBlock(ctx, width * 0.80, cy - 20 * sy, width * 0.17, 40 * sy,
                        Style.Theme.exito_fondo, result, "C", Style.Theme.exito_texto, reveal)
            return
        }
        if (kind === "output") {
            canvasBlock(ctx, width * 0.03, cy - 22 * sy, width * 0.25, 44 * sy,
                        vf, v, "contexto", Style.Theme.matriz_value_texto, reveal)
            canvasArrow(ctx, width * 0.30, cy, width * 0.55, cy,
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
                canvasArrow(ctx, width * 0.74, cy, width * 0.31, by + 10 * sy,
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
            canvasArrow(ctx, width * 0.28, uy + 10 * sy, width * 0.63, uy + 10 * sy,
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
