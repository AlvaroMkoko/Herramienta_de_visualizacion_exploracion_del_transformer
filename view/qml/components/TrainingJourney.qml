pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "../styles" as Style

Item {
    id: root
    objectName: "trainingJourney"

    property var snapshot: ({})
    property var lossHistory: []
    property int epoch: 0
    property int batch: 0
    property int globalStep: 0
    property int numLayers: 1
    property int numHeads: 1
    property real gradientNorm: 0
    property real sx: 1
    property real sy: 1

    property int stageIndex: 0
    property int explanationLevel: 0
    property int layerIndex: Math.max(0, numLayers - 1)
    property int headIndex: 0
    property int tokenIndex: 0
    property int parameterIndex: 0
    property bool playing: false
    // La animación es la vista principal. La explicación se abre bajo
    // demanda y puede vivir en una ventana separada para no quitarle espacio.
    property bool explanationVisible: false
    property bool explanationDetached: false
    property bool explanationDetailsExpanded: false
    readonly property bool compactJourney: width < 900
    readonly property bool explanationDockVisible: explanationVisible
                                                           && !explanationDetached
                                                           && !compactJourney

    readonly property var example: snapshot && snapshot.ejemplo ? snapshot.ejemplo : ({})
    readonly property var sourceTokens: example.tokens_origen || []
    readonly property var decoderTokens: example.tokens_decoder || []
    readonly property var targetTokens: example.tokens_objetivo || []
    readonly property var predictions: snapshot && snapshot.predicciones_por_posicion
                                              ? snapshot.predicciones_por_posicion : []
    readonly property var currentPrediction: predictions.length
                                                   ? predictions[Math.max(0, Math.min(predictions.length - 1,
                                                                                    tokenIndex))]
                                                   : null
    readonly property var updates: snapshot && snapshot.actualizaciones_parametros
                                          ? snapshot.actualizaciones_parametros : []
    readonly property var currentUpdate: updates.length
                                              ? updates[Math.max(0, Math.min(updates.length - 1,
                                                                           parameterIndex))]
                                              : null
    readonly property var optimizer: snapshot && snapshot.optimizador
                                            ? snapshot.optimizador : ({})
    readonly property bool dataAvailable: Boolean(snapshot && snapshot.disponible)

    // Las escenas contienen mucha información técnica. La geometría puede
    // comprimirse, pero el texto nunca debe bajar del umbral legible.
    function fontSize(baseSize, scale) {
        var minimum = baseSize >= 11 ? 12 : 11
        return Math.max(minimum, Math.round(baseSize * scale))
    }

    readonly property var chapters: [
        { id: "preparation", label: "Preparación", short: "DATOS", first: 0, last: 0, color: "#7C3AED" },
        { id: "encoder", label: "Encoder", short: "ENCODER", first: 1, last: 3, color: "#2563EB" },
        { id: "decoder", label: "Decoder", short: "DECODER", first: 4, last: 7, color: "#D97706" },
        { id: "learning", label: "Aprendizaje", short: "APRENDIZAJE", first: 8, last: 12, color: "#9333EA" }
    ]
    readonly property int chapterIndex: stageIndex <= 0 ? 0 : (stageIndex <= 3 ? 1 : (stageIndex <= 7 ? 2 : 3))
    readonly property var chapter: chapters[chapterIndex]
    readonly property string scopeLabel: stageIndex === 6
                                                ? "PUENTE · ENCODER → DECODER"
                                                : chapter.short
    readonly property color scopeColor: stageIndex === 6 ? "#059669" : chapter.color

    readonly property var stages: [
        {
            id: "dataset", short: "Datos", color: "#7C3AED",
            title: "Prepara el batch y limpia gradientes anteriores",
            action: "Pone los gradientes en cero, toma un lote del dataset y separa la entrada, lo que verá el decoder y la respuesta que debe aprender.",
            input: "Ejemplos tokenizados del dataset.",
            output: "Tokens de origen, entrada desplazada del decoder y tokens objetivo.",
            purpose: "Evita acumular correcciones anteriores y define la pregunta y la respuesta con las que se medirá el error.",
            intuitive: "Durante el entrenamiento conocemos ambos lados del ejemplo. El modelo no memoriza una animación: procesa estos IDs reales del dataset.",
            technical: "El encoder recibe la secuencia fuente; el decoder recibe la salida correcta desplazada y la loss usa la secuencia objetivo.",
            mathematical: "x = tokens_origen · y_in = [BOS, y₀…yₙ₋₁] · y = [y₀…yₙ₋₁, EOS]",
            formula: "dataset → tokenización → IDs"
        },
        {
            id: "embedding", short: "Vectores", color: "#DB2777",
            title: "Embedding y posición forman la representación inicial",
            action: "Busca el vector aprendido de cada token de entrada, lo escala y le suma una señal que representa su posición.",
            input: "IDs de los tokens de origen.",
            output: "Una matriz de vectores con contenido y orden: [batch, tokens, d_model].",
            purpose: "Convierte símbolos discretos en números continuos que el encoder puede procesar.",
            intuitive: "Cada token se convierte en un vector aprendido y recibe una señal que indica dónde está.",
            technical: "Los embeddings se escalan por √d_model y se suman a la codificación posicional sinusoidal.",
            mathematical: "X₀ = Embedding(x) · √d_model + PE(x)",
            formula: "Embedding + Positional Encoding"
        },
        {
            id: "encoder_attention", short: "Self-Attn", color: "#0284C7",
            title: "El encoder mezcla información de la entrada",
            action: "Cada token consulta a los demás tokens válidos de la entrada mediante varias cabezas de autoatención.",
            input: "Vectores de origen y máscara de relleno.",
            output: "Vectores que combinan información relevante de toda la entrada.",
            purpose: "Permite descubrir relaciones entre palabras aunque estén alejadas en la secuencia.",
            intuitive: "Una conexión más intensa significa que esa cabeza usa más información del token conectado.",
            technical: "Q, K y V proceden de la misma secuencia. La vista resumida conserva los pesos más altos de la query elegida para evitar cruces visuales; el tensor y el cálculo usan todos los pesos.",
            mathematical: "Attention(Q,K,V) = softmax(QKᵀ/√dₖ)V",
            formula: "Self-Attention del Encoder"
        },
        {
            id: "encoder_output", short: "Contexto", color: "#2563EB",
            title: "La salida del encoder ya depende del contexto",
            action: "Completa cada bloque con conexión residual, normalización y red feed-forward, y repite el proceso por todas las capas.",
            input: "Resultado de la autoatención en cada capa del encoder.",
            output: "Memoria contextual final del encoder (H_enc).",
            purpose: "Entrega al decoder una representación rica de toda la entrada.",
            intuitive: "Los tokens se desplazan en el espacio de representación porque ahora incorporan información de sus vecinos.",
            technical: "Cada bloque combina Multi-Head Attention y FFN con atajos residuales y LayerNorm. La comparación usa estados reales antes de la pila y después de la última capa.",
            mathematical: "Z = LN(X + MHA(X)); H_enc = LN(Z + FFN(Z))",
            formula: "residual + normalización + FFN"
        },
        {
            id: "shifted_target", short: "Shift", color: "#D97706",
            title: "Teacher forcing: la respuesta se desplaza una posición",
            action: "Antepone BOS y desplaza la respuesta correcta para que cada posición reciba solamente los tokens correctos anteriores.",
            input: "Secuencia objetivo completa del ejemplo.",
            output: "Entrada del decoder y objetivo siguiente alineados posición por posición.",
            purpose: "Permite practicar todas las predicciones del ejemplo en paralelo sin revelar el token actual.",
            intuitive: "El decoder recibe los tokens correctos anteriores y practica predecir el siguiente.",
            technical: "Cada posición alinea una entrada conocida con un objetivo. BOS inicia la primera predicción y EOS enseña cuándo terminar.",
            mathematical: "y_in[t] → predecir y[t]",
            formula: "[BOS, y₀, …] → [y₀, …, EOS]"
        },
        {
            id: "causal_mask", short: "Máscara", color: "#DC2626",
            title: "La máscara causal bloquea el futuro",
            action: "Convierte la entrada desplazada en vectores con posición y aplica una máscara triangular antes de la autoatención del decoder.",
            input: "Tokens desplazados del decoder y sus posiciones.",
            output: "Estados del decoder que solo incorporan el presente y el pasado.",
            purpose: "Evita que el modelo haga trampa mirando tokens futuros de la respuesta.",
            intuitive: "Aunque la respuesta completa está en el batch, cada posición solo puede mirar lo que ya debería conocer.",
            technical: "Las celdas futuras reciben −∞ antes de Softmax, por lo que su peso final es cero.",
            mathematical: "Mᵢⱼ = 0 si j≤i; −∞ si j>i",
            formula: "Masked Self-Attention"
        },
        {
            id: "cross_attention", short: "Cross-Attn", color: "#059669",
            title: "El decoder consulta la memoria del encoder",
            action: "Usa los estados del decoder como consultas y la memoria del encoder como claves y valores; después completa residual, normalización y feed-forward en todas las capas.",
            input: "Estados causales del decoder y memoria H_enc del encoder.",
            output: "Estados finales del decoder enriquecidos con información de la entrada.",
            purpose: "Relaciona cada predicción con las partes pertinentes de la secuencia de origen.",
            intuitive: "El token del decoder busca qué parte de la entrada resulta útil para su siguiente predicción.",
            technical: "Q procede del decoder; K y V proceden de la salida del encoder. La vista resumida enseña como máximo los pesos dominantes de la query seleccionada, pero el forward conserva la distribución completa.",
            mathematical: "Q=H_decWQ; K=H_encWK; V=H_encWV; A=softmax(QKᵀ/√dₖ); salida=AV",
            formula: "Cross-Attention Encoder–Decoder"
        },
        {
            id: "prediction", short: "Top-K", color: "#0F766E",
            title: "Linear produce logits para todo el vocabulario",
            action: "Proyecta cada estado del decoder a un puntaje por token. La vista aplica Softmax para hacer esos puntajes interpretables como probabilidades.",
            input: "Estados finales del decoder.",
            output: "Logits para todo el vocabulario y probabilidades mostradas en Top-5.",
            purpose: "Expresa qué tan compatible considera el modelo cada posible token siguiente.",
            intuitive: "El modelo no entrega directamente una palabra: reparte probabilidad entre todo el vocabulario.",
            technical: "El entrenamiento entrega logits crudos a CrossEntropyLoss. Solo esta vista aplica Softmax sobre todos los logits y limita la lista visible a Top‑5.",
            mathematical: "p(yₜ|x,y<t) = softmax(Wₒhₜ+b)",
            formula: "Decoder → Linear → logits · Softmax solo para visualizar"
        },
        {
            id: "loss", short: "Loss", color: "#B45309",
            title: "La probabilidad del token correcto determina el error",
            action: "Compara los logits con el token objetivo en cada posición, ignora PAD y promedia las penalizaciones válidas del batch.",
            input: "Logits del modelo y tokens objetivo.",
            output: "Una pérdida por token y un único escalar de pérdida para el batch.",
            purpose: "Resume en un número cuánto debe corregirse el modelo.",
            intuitive: "Cuanta menos probabilidad recibe la respuesta correcta, mayor es la penalización.",
            technical: "La loss del token mostrado es exacta; la loss del batch promedia todas las posiciones válidas y omite PAD.",
            mathematical: "Lₜ = −z[yₜ] + log Σⱼ exp(z[j]); L_batch = Σₜ mₜLₜ / Σₜ mₜ",
            formula: "CrossEntropy(logits, objetivo; ignore_index=PAD)"
        },
        {
            id: "backprop", short: "Backward", color: "#9333EA",
            title: "Backward calcula gradientes; todavía no actualiza pesos",
            action: "loss.backward() hace que autograd recorra el grafo en sentido inverso, aplique la regla de la cadena y acumule en .grad la derivada de la pérdida respecto de cada parámetro.",
            input: "Pérdida del batch y grafo conservado durante forward.",
            output: "Un tensor de gradiente en parámetro.grad para cada peso entrenable.",
            purpose: "Mide la sensibilidad del error a cada peso. No decide por sí solo el cambio ni modifica el modelo; esa tarea corresponde a optimizer.step().",
            intuitive: "La señal de error empieza en la loss y vuelve por cada operación. En cada peso pregunta: si este valor cambiara un poco, ¿cuánto cambiaría el error?",
            technical: "autograd conserva durante forward las operaciones necesarias. En backward combina sus derivadas locales desde logits y decoder hasta encoder, embeddings, atención, FFN y normalizaciones. Como PyTorch acumula .grad, zero_grad() se ejecutó al inicio del batch.",
            mathematical: "g_h = ∂L/∂h; ∂L/∂W = g_h·∂h/∂W; en una bifurcación, los gradientes se suman",
            formula: "zero_grad() → forward → loss → loss.backward()"
        },
        {
            id: "gradients", short: "Gradientes", color: "#C026D3",
            title: "La vista resume los gradientes calculados",
            action: "Agrupa los gradientes reales por función y calcula medidas comparables como norma L2 y RMS.",
            input: "Gradientes producidos por backward.",
            output: "Barras y estadísticas por familia de parámetros.",
            purpose: "Ayuda a detectar dónde llegó una señal fuerte, débil o inestable. Medirla no cambia el modelo.",
            intuitive: "La barra compara la magnitud de cada familia con la mayor de este batch; no es una probabilidad ni una puntuación de calidad.",
            technical: "La longitud visual usa la norma L2 relativa al máximo del batch. RMS divide el efecto del número de elementos y permite una comparación complementaria entre tensores de distinto tamaño.",
            mathematical: "‖g‖₂ = √Σgᵢ² · RMS(g)=√(Σgᵢ²/n)",
            formula: "∇θL"
        },
        {
            id: "optimizer", short: "Adam", color: "#047857",
            title: "El optimizador aplica una actualización real",
            action: "optimizer.step() hace que Adam combine cada gradiente con sus promedios móviles y la tasa de aprendizaje para modificar el parámetro.",
            input: "Pesos actuales, gradientes, estado de Adam y learning rate.",
            output: "Nuevos valores de los parámetros del modelo.",
            purpose: "Este es el momento en que el modelo realmente aprende del batch.",
            intuitive: "Una modificación pequeña de muchos valores, repetida batch tras batch, constituye el aprendizaje.",
            technical: "Antes, gradiente, delta y después pertenecen al mismo elemento real. delta = después − antes e incluye el estado interno de Adam; por eso no suele ser exactamente −learning_rate · gradiente.",
            mathematical: "θₜ = θₜ₋₁ − η·m̂ₜ/(√v̂ₜ+ε)",
            formula: "optimizer.step()"
        },
        {
            id: "evolution", short: "Evolución", color: "#1D4ED8",
            title: "La mejora se evalúa a lo largo de muchos batches",
            action: "Guarda la pérdida del paso, actualiza los contadores y continúa con el siguiente batch o la siguiente época.",
            input: "Pérdida recién observada e historial anterior.",
            output: "Curva de pérdida de entrenamiento y avance del proceso.",
            purpose: "Permite vigilar la tendencia de optimización. No sustituye una pérdida de validación sobre datos reservados.",
            intuitive: "La pérdida puede subir en un batch difícil; importa la tendencia. Una curva de entrenamiento baja tampoco demuestra por sí sola que el modelo generalice.",
            technical: "La curva conserva los últimos batches usados para actualizar el modelo. Cada punto puede contener ejemplos distintos por el shuffle; aquí no se está graficando un conjunto de validación.",
            mathematical: "L̄ = (1/N)Σ L_batch",
            formula: "siguiente batch → siguiente época"
        }
    ]
    readonly property var stageLabels: stages.map(function(item, index) {
        return (index + 1) + " · " + item.short
    })
    readonly property var stage: stages[Math.max(0, Math.min(stages.length - 1, stageIndex))]

    function layerModels() {
        var result = []
        for (var i = 0; i < Math.max(1, numLayers); ++i)
            result.push("Capa " + (i + 1))
        return result
    }

    function headModels() {
        var result = []
        for (var i = 0; i < Math.max(1, numHeads); ++i)
            result.push("Cabeza " + (i + 1))
        return result
    }

    function tokenModels() {
        var result = []
        var tokens = stageIndex === 2 ? sourceTokens : decoderTokens
        for (var i = 0; i < tokens.length; ++i)
            result.push((i + 1) + " · " + tokens[i].texto)
        return result.length ? result : ["Sin tokens"]
    }

    function attentionLayers(kind) {
        var all = snapshot && snapshot.atenciones ? snapshot.atenciones : ({})
        var branch = all[kind] || ({})
        return branch.capas || []
    }

    function attentionFor(kind) {
        var layers = attentionLayers(kind)
        if (!layers.length)
            return ({})
        return layers[Math.max(0, Math.min(layers.length - 1, layerIndex))].atencion || ({})
    }

    function maxGradient() {
        var maximum = 1e-12
        for (var i = 0; i < updates.length; ++i)
            maximum = Math.max(maximum, Number(updates[i].gradiente_norma_l2 || 0))
        return maximum
    }

    function number(value, digits) {
        var numeric = Number(value)
        return isFinite(numeric) ? numeric.toExponential(digits) : "—"
    }

    function setStage(index) {
        stageIndex = Math.max(0, Math.min(stages.length - 1, index))
        tokenIndex = Math.max(0, Math.min(tokenModels().length - 1, tokenIndex))
    }

    function scopeForStage(index) {
        if (index === 0)
            return "DATOS"
        if (index <= 3)
            return "ENC"
        if (index <= 7)
            return index === 6 ? "ENC→DEC" : "DEC"
        return "APRENDE"
    }

    function resetJourney() {
        playing = false
        setStage(0)
    }

    function detachExplanation() {
        explanationVisible = true
        explanationDetached = true
        playing = false
        Qt.callLater(function() {
            detachedExplanationWindow.raise()
            detachedExplanationWindow.requestActivate()
        })
    }

    function dockExplanation() {
        explanationDetached = false
        explanationVisible = true
    }

    function closeExplanation() {
        explanationDetached = false
        explanationVisible = false
        explanationDetailsExpanded = false
    }

    function toggleExplanation() {
        if (explanationDetached) {
            detachedExplanationWindow.raise()
            detachedExplanationWindow.requestActivate()
        } else if (explanationDockVisible) {
            closeExplanation()
        } else if (compactJourney) {
            detachExplanation()
        } else {
            explanationVisible = true
        }
    }

    onSnapshotChanged: {
        tokenIndex = Math.max(0, Math.min(predictions.length - 1, tokenIndex))
        layerIndex = Math.max(0, Math.min(Math.max(1, numLayers) - 1, layerIndex))
        headIndex = Math.max(0, Math.min(Math.max(1, numHeads) - 1, headIndex))
        parameterIndex = Math.max(0, Math.min(updates.length - 1, parameterIndex))
    }
    onStageIndexChanged: explanationDetailsExpanded = false
    onVisibleChanged: {
        if (!visible && explanationDetached)
            closeExplanation()
    }

    Timer {
        // El recorrido automático deja tiempo para identificar la transformación
        // antes de cambiar de escena. La navegación manual sigue disponible.
        interval: 6000
        repeat: true
        running: root.playing
        onTriggered: {
            if (root.stageIndex >= root.stages.length - 1)
                root.playing = false
            else
                root.setStage(root.stageIndex + 1)
        }
    }

    Window {
        id: detachedExplanationWindow
        objectName: "trainingDetachedExplanationWindow"
        visible: root.explanationDetached
        transientParent: root.Window.window
        modality: Qt.NonModal
        minimumWidth: 440
        minimumHeight: 540
        width: Math.max(minimumWidth, Math.min(650, root.width * 0.46))
        height: Math.max(minimumHeight, Math.min(850, root.height * 0.92))
        title: "Explicación del entrenamiento · " + root.stage.short
        color: Style.Theme.superficie_alterna

        onClosing: function(close) {
            if (root.explanationDetached)
                root.closeExplanation()
            close.accepted = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 5 * root.sy

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38 * root.sy
            Layout.minimumHeight: 38 * root.sy
            Layout.maximumHeight: 38 * root.sy
            radius: 10 * root.sx
            color: Style.Theme.chip_fondo
            border.color: Qt.alpha(root.stage.color, 0.55)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12 * root.sx
                anchors.rightMargin: 12 * root.sx
                spacing: 8 * root.sx
                Text {
                    text: "Época " + root.epoch + " · Batch " + root.batch
                          + " · Paso: " + root.stage.short
                    color: root.stage.color
                    font.bold: true
                    font.pixelSize: 12 * root.sx
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6 * root.sy
                    radius: height / 2
                    color: Style.Theme.borde_medio
                    Rectangle {
                        width: parent.width * ((root.stageIndex + 1) / root.stages.length)
                        height: parent.height
                        radius: parent.radius
                        color: root.stage.color
                        Behavior on width { NumberAnimation { duration: 260 } }
                    }
                }
                Text {
                    text: (root.stageIndex + 1) + " / " + root.stages.length
                    color: Style.Theme.texto_secundario
                    font.pixelSize: root.fontSize(10, root.sx)
                }
                Rectangle {
                    Layout.preferredWidth: scopeText.implicitWidth + 18 * root.sx
                    Layout.preferredHeight: 27 * root.sy
                    radius: height / 2
                    color: Qt.alpha(root.scopeColor, 0.14)
                    border.color: root.scopeColor
                    Text {
                        id: scopeText
                        anchors.centerIn: parent
                        text: root.scopeLabel
                        color: root.scopeColor
                        font.bold: true
                        font.pixelSize: root.fontSize(9, root.sx)
                    }
                }
            }
        }

        RowLayout {
            objectName: "trainingJourneyChapters"
            Layout.fillWidth: true
            Layout.preferredHeight: 28 * root.sy
            Layout.minimumHeight: 28 * root.sy
            Layout.maximumHeight: 28 * root.sy
            spacing: 6 * root.sx
            Repeater {
                model: root.chapters
                delegate: Rectangle {
                    id: chapterCard
                    required property int index
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 8 * root.sx
                    color: chapterCard.index === root.chapterIndex
                           ? Qt.alpha(chapterCard.modelData.color, 0.15)
                           : Style.Theme.superficie_alterna
                    border.width: chapterCard.index === root.chapterIndex ? 2 : 1
                    border.color: chapterCard.index === root.chapterIndex
                                  ? chapterCard.modelData.color : Style.Theme.borde_medio
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 9 * root.sx
                        anchors.rightMargin: 9 * root.sx
                        Text {
                            text: (chapterCard.index + 1) + " · " + chapterCard.modelData.label
                            color: chapterCard.index === root.chapterIndex
                                   ? chapterCard.modelData.color : Style.Theme.texto_secundario
                            font.bold: chapterCard.index === root.chapterIndex
                            font.pixelSize: root.fontSize(9, root.sx)
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: (chapterCard.modelData.last - chapterCard.modelData.first + 1) + " pasos"
                            color: Style.Theme.texto_terciario
                            font.pixelSize: root.fontSize(8, root.sx)
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.playing = false
                            root.setStage(chapterCard.modelData.first)
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38 * root.sy
            Layout.minimumHeight: 38 * root.sy
            Layout.maximumHeight: 38 * root.sy
            spacing: 7 * root.sx
            SmallButton {
                Layout.preferredWidth: 32 * root.sx
                label: "↺"
                onClicked: root.resetJourney()
            }
            SmallButton {
                Layout.preferredWidth: 32 * root.sx
                label: "←"
                enabled: root.stageIndex > 0
                onClicked: root.setStage(root.stageIndex - 1)
            }
            SelectorPrincipal {
                Layout.fillWidth: true
                Layout.maximumWidth: 205 * root.sx
                sx: root.sx
                sy: root.sy
                model: root.stageLabels
                currentIndex: root.stageIndex
                onActivated: function(index) {
                    root.playing = false
                    root.setStage(index)
                }
            }
            SmallButton {
                Layout.preferredWidth: 72 * root.sx
                label: "Siguiente →"
                enabled: root.stageIndex < root.stages.length - 1
                onClicked: root.setStage(root.stageIndex + 1)
            }
            SmallButton {
                Layout.preferredWidth: 105 * root.sx
                label: root.playing ? "Ⅱ Pausar" : "▶ Recorrido"
                primary: true
                onClicked: {
                    if (!root.playing && root.stageIndex >= root.stages.length - 1)
                        root.setStage(0)
                    root.playing = !root.playing
                }
            }
            Item { Layout.fillWidth: true }
            SmallButton {
                objectName: "trainingExplanationToggleButton"
                Layout.preferredWidth: 132 * root.sx
                label: root.explanationDetached
                       ? "Explicación abierta ↗"
                       : (root.explanationDockVisible
                          ? "Ocultar explicación"
                          : "Ver explicación")
                primary: root.explanationDetached || root.explanationDockVisible
                onClicked: root.toggleExplanation()
            }
        }

        RowLayout {
            readonly property bool hasContextSelectors:
                root.stageIndex === 2 || root.stageIndex === 5
                || root.stageIndex === 6 || root.stageIndex === 7
                || root.stageIndex === 8
            visible: hasContextSelectors
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 34 * root.sy : 0
            Layout.minimumHeight: visible ? 34 * root.sy : 0
            Layout.maximumHeight: visible ? 34 * root.sy : 0
            spacing: 7 * root.sx
            Text {
                text: "Enfoca la visualización"
                color: Style.Theme.texto_secundario
                font.pixelSize: root.fontSize(9, root.sx)
            }
            Item { Layout.fillWidth: true }
            SelectorPrincipal {
                visible: root.stageIndex === 2 || root.stageIndex === 5 || root.stageIndex === 6
                Layout.preferredWidth: 105 * root.sx
                sx: root.sx
                sy: root.sy
                model: root.layerModels()
                currentIndex: root.layerIndex
                onActivated: function(index) { root.layerIndex = index }
            }
            SelectorPrincipal {
                visible: root.stageIndex === 2 || root.stageIndex === 5 || root.stageIndex === 6
                Layout.preferredWidth: 112 * root.sx
                sx: root.sx
                sy: root.sy
                model: root.headModels()
                currentIndex: root.headIndex
                onActivated: function(index) { root.headIndex = index }
            }
            SelectorPrincipal {
                visible: root.stageIndex === 2 || root.stageIndex === 5 || root.stageIndex === 6
                         || root.stageIndex === 7 || root.stageIndex === 8
                Layout.preferredWidth: 125 * root.sx
                sx: root.sx
                sy: root.sy
                model: root.tokenModels()
                currentIndex: root.tokenIndex
                onActivated: function(index) { root.tokenIndex = index }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10 * root.sx

            Item {
                id: explanationDock
                objectName: "trainingExplanationDock"
                visible: root.explanationDockVisible
                Layout.preferredWidth: visible
                                       ? Math.max(300, Math.min(360, root.width * 0.28))
                                       : 0
                Layout.minimumWidth: visible ? 300 : 0
                Layout.maximumWidth: visible ? 360 : 0
                Layout.fillHeight: true

                Rectangle {
                    id: explanationCard
                    objectName: "trainingExplanationPanel"
                    parent: root.explanationDetached
                            ? detachedExplanationWindow.contentItem
                            : explanationDock
                    anchors.fill: parent
                    visible: root.explanationVisible
                    radius: 11 * root.sx
                    color: Qt.alpha(root.stage.color, 0.07)
                    border.color: Qt.alpha(root.stage.color, 0.42)

                    ScrollView {
                        id: explanationScroll
                        anchors.fill: parent
                        anchors.margins: 13 * root.sx
                        clip: true
                        contentWidth: availableWidth
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        ColumnLayout {
                            id: explanationPanel
                            width: explanationScroll.availableWidth
                            spacing: 8 * root.sy

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 5 * root.sx
                                Text {
                                    Layout.fillWidth: true
                                    text: "EXPLICACIÓN DEL PASO"
                                    color: root.stage.color
                                    font.bold: true
                                    elide: Text.ElideRight
                                    font.pixelSize: root.fontSize(9, root.sx)
                                }
                                Button {
                                    objectName: "trainingDetachExplanationButton"
                                    flat: true
                                    text: root.explanationDetached
                                          ? (root.compactJourney ? "Cerrar ventana" : "Acoplar")
                                          : "Abrir aparte"
                                    font.bold: true
                                    font.pixelSize: root.fontSize(9, root.sx)
                                    onClicked: root.explanationDetached
                                               ? (root.compactJourney
                                                  ? root.closeExplanation()
                                                  : root.dockExplanation())
                                               : root.detachExplanation()
                                    ToolTip.visible: hovered
                                    ToolTip.text: root.explanationDetached
                                                  ? (root.compactJourney
                                                     ? "Cierra la explicación separada"
                                                     : "Devuelve la explicación junto a la animación")
                                                  : "Mueve la explicación a una segunda ventana"
                                }
                                Button {
                                    flat: true
                                    text: "×"
                                    font.bold: true
                                    font.pixelSize: root.fontSize(13, root.sx)
                                    onClicked: root.closeExplanation()
                                    Accessible.name: "Cerrar explicación"
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 25 * root.sy
                                radius: height / 2
                                color: Qt.alpha(root.scopeColor, 0.14)
                                border.color: root.scopeColor
                                Text {
                                    id: scopePanelText
                                    anchors.fill: parent
                                    anchors.leftMargin: 9 * root.sx
                                    anchors.rightMargin: 9 * root.sx
                                    text: "BLOQUE " + (root.chapterIndex + 1) + " · " + root.scopeLabel
                                    color: root.scopeColor
                                    font.bold: true
                                    font.pixelSize: root.fontSize(9, root.sx)
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.stage.title
                                color: Style.Theme.texto_primario
                                font.bold: true
                                font.pixelSize: root.fontSize(15, root.sx)
                                wrapMode: Text.WordWrap
                            }

                            StageFact {
                                objectName: "trainingStageInput"
                                Layout.fillWidth: true
                                label: "1 · RECIBE"
                                value: root.stage.input
                                accent: root.stage.color
                                sx: root.sx
                                sy: root.sy
                            }

                            StageFact {
                                objectName: "trainingStageAction"
                                Layout.fillWidth: true
                                label: "2 · QUÉ OCURRE"
                                value: root.stage.action
                                accent: root.stage.color
                                sx: root.sx
                                sy: root.sy
                            }

                            StageFact {
                                objectName: "trainingStageOutput"
                                Layout.fillWidth: true
                                label: "3 · PRODUCE"
                                value: root.stage.output
                                accent: root.stage.color
                                sx: root.sx
                                sy: root.sy
                            }

                            SmallButton {
                                objectName: "trainingExplanationDetailsButton"
                                Layout.fillWidth: true
                                label: root.explanationDetailsExpanded
                                       ? "Ocultar detalle"
                                       : "Ver explicación técnica y matemática"
                                onClicked: root.explanationDetailsExpanded
                                           = !root.explanationDetailsExpanded
                            }

                            StageFact {
                                objectName: "trainingStagePurpose"
                                visible: root.explanationDetailsExpanded
                                Layout.fillWidth: true
                                label: "POR QUÉ IMPORTA"
                                value: root.stage.purpose
                                accent: root.stage.color
                                sx: root.sx
                                sy: root.sy
                            }

                            RowLayout {
                                visible: root.explanationDetailsExpanded
                                Layout.fillWidth: true
                                Text {
                                    text: "Nivel del detalle"
                                    color: Style.Theme.texto_secundario
                                    font.pixelSize: root.fontSize(9, root.sx)
                                }
                                SelectorPrincipal {
                                    Layout.fillWidth: true
                                    sx: root.sx
                                    sy: root.sy
                                    model: ["Intuitiva", "Técnica", "Matemática"]
                                    currentIndex: root.explanationLevel
                                    onActivated: function(index) { root.explanationLevel = index }
                                }
                            }

                            Text {
                                objectName: "trainingStageDetailLabel"
                                visible: root.explanationDetailsExpanded
                                Layout.fillWidth: true
                                text: "DETALLE · " + (root.explanationLevel === 0 ? "INTUITIVO"
                                                       : (root.explanationLevel === 1 ? "TÉCNICO"
                                                                                      : "MATEMÁTICO"))
                                color: root.stage.color
                                font.bold: true
                                font.pixelSize: root.fontSize(8, root.sx)
                            }
                            Text {
                                visible: root.explanationDetailsExpanded
                                objectName: "trainingStageDetail"
                                Layout.fillWidth: true
                                text: root.explanationLevel === 0 ? root.stage.intuitive
                                      : (root.explanationLevel === 1 ? root.stage.technical
                                                                     : root.stage.mathematical)
                                color: Style.Theme.texto_secundario_fuerte
                                font.pixelSize: root.fontSize(11, root.sx)
                                wrapMode: Text.WordWrap
                            }
                            Rectangle {
                                objectName: "trainingStageFormula"
                                visible: root.explanationDetailsExpanded
                                Layout.fillWidth: true
                                Layout.preferredHeight: visible
                                                        ? formulaText.implicitHeight + 18 * root.sy
                                                        : 0
                                radius: 8 * root.sx
                                color: Style.Theme.surface
                                border.color: Style.Theme.borde_medio
                                Text {
                                    id: formulaText
                                    objectName: "trainingStageFormulaText"
                                    anchors.fill: parent
                                    anchors.margins: 9 * root.sx
                                    text: root.explanationLevel === 2
                                          ? root.stage.mathematical : root.stage.formula
                                    color: root.stage.color
                                    font.family: Style.Theme.fuente_mono
                                    font.pixelSize: root.fontSize(10, root.sx)
                                    wrapMode: Text.WordWrap
                                }
                            }
                            Item { Layout.fillHeight: true }
                            Text {
                                visible: root.explanationDetailsExpanded
                                Layout.fillWidth: true
                                text: "Datos del paso global " + root.globalStep
                                      + " · no son valores simulados"
                                color: Style.Theme.texto_terciario
                                font.pixelSize: root.fontSize(9, root.sx)
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: journeyViewport
                objectName: "trainingJourneyViewport"
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 11 * root.sx
                color: Style.Theme.surface
                border.color: Style.Theme.borde_medio
                clip: true

                Item {
                    id: journeyScenes
                    objectName: "trainingJourneyScenes"
                    anchors.fill: parent
                    anchors.margins: 12 * root.sx
                    property int currentIndex: root.stageIndex

                    TokenOverview {
                        objectName: "trainingScene0"
                        anchors.fill: parent
                        visible: root.stageIndex === 0
                        sourceTokens: root.sourceTokens
                        decoderTokens: root.decoderTokens
                        targetTokens: root.targetTokens
                        sx: root.sx; sy: root.sy
                    }

                    PcaPairScene {
                        objectName: "trainingScene1"
                        anchors.fill: parent
                        visible: root.stageIndex === 1
                        projection: root.snapshot && root.snapshot.proyecciones_pca
                                    ? (root.snapshot.proyecciones_pca.embedding_posicion_encoder || ({})) : ({})
                        tokens: root.sourceTokens
                        beforeLabel: "Embedding escalado"
                        afterLabel: "+ posición"
                        accent: root.stage.color
                        sx: root.sx; sy: root.sy
                    }

                    AttentionFlowScene {
                        objectName: "trainingScene2"
                        anchors.fill: parent
                        visible: root.stageIndex === 2
                        attentionData: root.attentionFor("encoder")
                        queryTokens: root.sourceTokens
                        keyTokens: root.sourceTokens
                        crossAttention: false
                        headIndex: root.headIndex
                        focusedQuery: root.tokenIndex
                        active: root.stageIndex === 2
                        sx: root.sx; sy: root.sy
                        onHeadSelected: function(index) { root.headIndex = index }
                    }

                    PcaPairScene {
                        objectName: "trainingScene3"
                        anchors.fill: parent
                        visible: root.stageIndex === 3
                        projection: root.snapshot && root.snapshot.proyecciones_pca
                                    ? (root.snapshot.proyecciones_pca.contexto_encoder || ({})) : ({})
                        tokens: root.sourceTokens
                        beforeLabel: "Entrada a la pila"
                        afterLabel: "Salida contextual"
                        accent: root.stage.color
                        sx: root.sx; sy: root.sy
                    }

                    TeacherForcingScene {
                        objectName: "trainingScene4"
                        anchors.fill: parent
                        visible: root.stageIndex === 4
                        pairs: root.example.pares_teacher_forcing || []
                        decoderTokens: root.decoderTokens
                        targetTokens: root.targetTokens
                        sx: root.sx; sy: root.sy
                    }

                    MaskedAttentionScene {
                        objectName: "trainingScene5"
                        anchors.fill: parent
                        visible: root.stageIndex === 5
                        maskData: root.snapshot.mascara_causal || ({})
                        tokens: root.decoderTokens
                        attentionData: root.attentionFor("decoder_masked")
                        headIndex: root.headIndex
                        focusedQuery: root.tokenIndex
                        active: root.stageIndex === 5
                        sx: root.sx; sy: root.sy
                        onHeadSelected: function(index) { root.headIndex = index }
                    }

                    AttentionFlowScene {
                        objectName: "trainingScene6"
                        anchors.fill: parent
                        visible: root.stageIndex === 6
                        attentionData: root.attentionFor("cross")
                        queryTokens: root.decoderTokens
                        keyTokens: root.sourceTokens
                        crossAttention: true
                        headIndex: root.headIndex
                        focusedQuery: root.tokenIndex
                        active: root.stageIndex === 6
                        sx: root.sx; sy: root.sy
                        onHeadSelected: function(index) { root.headIndex = index }
                    }

                    PredictionScene {
                        objectName: "trainingScene7"
                        anchors.fill: parent
                        visible: root.stageIndex === 7
                        prediction: root.currentPrediction
                        sx: root.sx; sy: root.sy
                    }

                    LossScene {
                        objectName: "trainingScene8"
                        anchors.fill: parent
                        visible: root.stageIndex === 8
                        prediction: root.currentPrediction
                        batchLoss: Number(root.snapshot.perdida_batch || 0)
                        sx: root.sx; sy: root.sy
                    }

                    BackpropScene {
                        objectName: "trainingScene9"
                        anchors.fill: parent
                        visible: root.stageIndex === 9
                        gradientNorm: root.gradientNorm
                        active: root.stageIndex === 9
                        sx: root.sx; sy: root.sy
                    }

                    GradientScene {
                        objectName: "trainingScene10"
                        anchors.fill: parent
                        visible: root.stageIndex === 10
                        updates: root.updates
                        maximum: root.maxGradient()
                        sx: root.sx; sy: root.sy
                    }

                    OptimizerScene {
                        objectName: "trainingScene11"
                        anchors.fill: parent
                        visible: root.stageIndex === 11
                        updates: root.updates
                        selectedIndex: root.parameterIndex
                        optimizer: root.optimizer
                        sx: root.sx; sy: root.sy
                        onSelected: function(index) { root.parameterIndex = index }
                    }

                    EvolutionScene {
                        objectName: "trainingScene12"
                        anchors.fill: parent
                        visible: root.stageIndex === 12
                        history: root.lossHistory
                        batchLoss: Number(root.snapshot.perdida_batch || 0)
                        sx: root.sx; sy: root.sy
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !root.dataAvailable
                    color: Style.Theme.surface
                    Column {
                        anchors.centerIn: parent
                        spacing: 10 * root.sy
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Esperando el primer batch real…"
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: 17 * root.sx
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "El recorrido se habilita después de forward, backward y optimizer.step()."
                            color: Style.Theme.texto_secundario
                            font.pixelSize: root.fontSize(11, root.sx)
                        }
                    }
                }
            }
        }
    }

    component SmallButton: Button {
        id: smallButton
        property string label: ""
        property bool primary: false
        text: label
        implicitHeight: 31 * root.sy
        background: Rectangle {
            radius: 7 * root.sx
            color: smallButton.primary ? Style.Theme.acento : Style.Theme.chip_fondo
            border.color: smallButton.primary ? Style.Theme.acento_fuerte : Style.Theme.borde_medio
            opacity: smallButton.enabled ? 1 : 0.45
        }
        contentItem: Text {
            text: smallButton.text
            color: smallButton.primary ? Style.Theme.texto_sobre_color : Style.Theme.texto_primario
            font.bold: true
            font.pixelSize: root.fontSize(9, root.sx)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    component StageFact: Rectangle {
        id: stageFact
        property string label: ""
        property string value: ""
        property color accent: Style.Theme.acento
        property real sx: 1
        property real sy: 1

        implicitHeight: factContent.implicitHeight + 13 * sy
        radius: 7 * sx
        color: Qt.alpha(accent, 0.055)
        border.color: Qt.alpha(accent, 0.24)

        ColumnLayout {
            id: factContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 8 * stageFact.sx
            anchors.rightMargin: 8 * stageFact.sx
            spacing: 2 * stageFact.sy

            Text {
                Layout.fillWidth: true
                text: stageFact.label
                color: stageFact.accent
                font.bold: true
                font.pixelSize: root.fontSize(8, stageFact.sx)
            }
            Text {
                Layout.fillWidth: true
                text: stageFact.value
                color: Style.Theme.texto_secundario_fuerte
                wrapMode: Text.WordWrap
                font.pixelSize: root.fontSize(9, stageFact.sx)
            }
        }
    }

    component TokenPill: Rectangle {
        id: tokenPill
        property string label: ""
        property string caption: ""
        property color accent: Style.Theme.acento
        width: Math.max(64 * root.sx, pillText.implicitWidth + 18 * root.sx)
        height: 47 * root.sy
        radius: 8 * root.sx
        color: Qt.alpha(accent, 0.11)
        border.color: Qt.alpha(accent, 0.55)
        Column {
            anchors.centerIn: parent
            spacing: 1
            Text { id: pillText; anchors.horizontalCenter: parent.horizontalCenter; text: tokenPill.label; color: tokenPill.accent; font.bold: true; font.pixelSize: root.fontSize(10, root.sx) }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: tokenPill.caption; color: Style.Theme.texto_terciario; font.pixelSize: root.fontSize(8, root.sx) }
        }
    }

    component CompactToken: Rectangle {
        id: compactToken
        property string label: ""
        property color accent: Style.Theme.acento
        property real scaleX: 1
        property real scaleY: 1
        property real fixedWidth: 0
        width: fixedWidth > 0
               ? fixedWidth
               : Math.min(96 * scaleX,
                          Math.max(46 * scaleX, compactTokenText.implicitWidth + 16 * scaleX))
        height: 29 * scaleY
        radius: 7 * scaleX
        color: Qt.alpha(accent, 0.11)
        border.color: Qt.alpha(accent, 0.55)
        Text {
            id: compactTokenText
            anchors.fill: parent
            anchors.leftMargin: 7 * compactToken.scaleX
            anchors.rightMargin: 7 * compactToken.scaleX
            text: compactToken.label
            color: compactToken.accent
            font.bold: true
            font.pixelSize: root.fontSize(9, compactToken.scaleX)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    component ShiftSequenceBand: Item {
        id: shiftBand
        property string title: ""
        property var tokens: []
        property color accent: Style.Theme.acento
        property real sx: 1
        property real sy: 1
        Layout.fillWidth: true
        Layout.preferredHeight: 31 * sy
        RowLayout {
            anchors.fill: parent
            spacing: 8 * shiftBand.sx
            Text {
                Layout.preferredWidth: 116 * shiftBand.sx
                text: shiftBand.title
                color: shiftBand.accent
                font.bold: true
                font.pixelSize: root.fontSize(8, shiftBand.sx)
                elide: Text.ElideRight
            }
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: shiftTokens.implicitWidth
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Row {
                    id: shiftTokens
                    height: parent.height
                    spacing: 5 * shiftBand.sx
                    Repeater {
                        model: shiftBand.tokens
                        delegate: CompactToken {
                            required property var modelData
                            label: modelData.texto
                            accent: shiftBand.accent
                            scaleX: shiftBand.sx
                            scaleY: shiftBand.sy
                            fixedWidth: 72 * shiftBand.sx
                        }
                    }
                }
            }
        }
    }

    component TokenOverview: Item {
        id: tokenOverview
        property var sourceTokens: []
        property var decoderTokens: []
        property var targetTokens: []
        property real sx: 1
        property real sy: 1
        ColumnLayout {
            anchors.fill: parent
            spacing: 12 * tokenOverview.sy
            SequenceRow { title: "ENTRADA DEL ENCODER"; tokens: tokenOverview.sourceTokens; accent: "#2563EB"; sx: tokenOverview.sx; sy: tokenOverview.sy }
            SequenceRow { title: "ENTRADA DEL DECODER · DESPLAZADA"; tokens: tokenOverview.decoderTokens; accent: "#D97706"; sx: tokenOverview.sx; sy: tokenOverview.sy }
            SequenceRow { title: "OBJETIVOS CORRECTOS"; tokens: tokenOverview.targetTokens; accent: "#059669"; sx: tokenOverview.sx; sy: tokenOverview.sy }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 54 * tokenOverview.sy
                radius: 9 * tokenOverview.sx
                color: Style.Theme.info_fondo
                Text {
                    anchors.fill: parent
                    anchors.margins: 10 * tokenOverview.sx
                    text: "Estas tres secuencias provienen del mismo ejemplo. PAD se excluye de las longitudes, la loss y la visualización."
                    color: Style.Theme.info_texto
                    wrapMode: Text.WordWrap
                    font.pixelSize: root.fontSize(10, tokenOverview.sx)
                }
            }
            Item { Layout.fillHeight: true }
        }
    }

    component SequenceRow: Item {
        id: sequenceRow
        property string title: ""
        property var tokens: []
        property color accent: Style.Theme.acento
        property real sx: 1
        property real sy: 1
        Layout.fillWidth: true
        Layout.preferredHeight: 82 * sy
        Column {
            anchors.fill: parent
            spacing: 6 * sequenceRow.sy
            Text { text: sequenceRow.title; color: sequenceRow.accent; font.bold: true; font.pixelSize: root.fontSize(9, sequenceRow.sx) }
            Flickable {
                width: parent.width
                height: 51 * sequenceRow.sy
                contentWidth: sequenceTokens.implicitWidth
                clip: true
                Row {
                    id: sequenceTokens
                    spacing: 6 * sequenceRow.sy
                    Repeater {
                        model: sequenceRow.tokens
                        delegate: TokenPill {
                            required property var modelData
                            label: modelData.texto
                            caption: "id " + modelData.token_id
                            accent: sequenceRow.accent
                        }
                    }
                }
            }
        }
    }

    component PcaPairScene: Item {
        id: pcaScene
        property var projection: ({})
        property var tokens: []
        property string beforeLabel: "Antes"
        property string afterLabel: "Después"
        property color accent: Style.Theme.acento
        property real sx: 1
        property real sy: 1
        readonly property var beforePoints: projection.embedding || []
        readonly property var afterPoints: projection.entrada || []
        readonly property int count: Math.min(beforePoints.length, afterPoints.length)

        function xOf(point) { return Number(point && point.x !== undefined ? point.x : 0) }
        function yOf(point) { return Number(point && point.y !== undefined ? point.y : 0) }
        function bounds() {
            var b = { minX: 1e20, maxX: -1e20, minY: 1e20, maxY: -1e20 }
            for (var i = 0; i < count; ++i) {
                var pair = [beforePoints[i], afterPoints[i]]
                for (var j = 0; j < pair.length; ++j) {
                    b.minX = Math.min(b.minX, xOf(pair[j])); b.maxX = Math.max(b.maxX, xOf(pair[j]))
                    b.minY = Math.min(b.minY, yOf(pair[j])); b.maxY = Math.max(b.maxY, yOf(pair[j]))
                }
            }
            if (b.minX > b.maxX) return { minX: -1, maxX: 1, minY: -1, maxY: 1 }
            var mx = Math.max(0.1, (b.maxX - b.minX) * 0.15)
            var my = Math.max(0.1, (b.maxY - b.minY) * 0.15)
            b.minX -= mx; b.maxX += mx; b.minY -= my; b.maxY += my
            return b
        }
        onProjectionChanged: chart.requestPaint()
        ColumnLayout {
            anchors.fill: parent
            spacing: 8 * pcaScene.sy
            RowLayout {
                Layout.fillWidth: true
                Text { text: pcaScene.beforeLabel + "  →  " + pcaScene.afterLabel; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 14 * pcaScene.sx }
                Item { Layout.fillWidth: true }
                Text { text: "PCA conjunto · varianza " + Math.round(Number(pcaScene.projection.varianza_conservada || 0) * 100) + "%"; color: Style.Theme.texto_secundario; font.pixelSize: root.fontSize(9, pcaScene.sx) }
            }
            Canvas {
                id: chart
                Layout.fillWidth: true
                Layout.fillHeight: true
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset(); ctx.clearRect(0, 0, width, height)
                    var b = pcaScene.bounds(); var pad = 32
                    function px(v) { return pad + (v - b.minX) / Math.max(1e-9, b.maxX - b.minX) * (width - 2 * pad) }
                    function py(v) { return height - pad - (v - b.minY) / Math.max(1e-9, b.maxY - b.minY) * (height - 2 * pad) }
                    var points = []
                    for (var i = 0; i < pcaScene.count; ++i) {
                        var a = pcaScene.beforePoints[i], z = pcaScene.afterPoints[i]
                        var ax = px(pcaScene.xOf(a)), ay = py(pcaScene.yOf(a)), zx = px(pcaScene.xOf(z)), zy = py(pcaScene.yOf(z))
                        ctx.strokeStyle = Qt.alpha(pcaScene.accent, 0.55); ctx.lineWidth = 1.5
                        ctx.beginPath(); ctx.moveTo(ax, ay); ctx.lineTo(zx, zy); ctx.stroke()
                        ctx.fillStyle = Style.Theme.texto_terciario; ctx.beginPath(); ctx.arc(ax, ay, 4, 0, Math.PI * 2); ctx.fill()
                        ctx.fillStyle = pcaScene.accent; ctx.beginPath(); ctx.arc(zx, zy, 6, 0, Math.PI * 2); ctx.fill()
                        points.push({ x: zx, y: zy, index: i })
                    }

                    // Las etiquetas se colocan después de las trayectorias y
                    // prueban cuatro posiciones. Si ninguna queda libre se
                    // omite solo la etiqueta, nunca el punto ni el movimiento.
                    var occupied = []
                    var fontSize = Math.max(9, 9 * pcaScene.sx)
                    ctx.font = fontSize + "px sans-serif"
                    function intersects(box) {
                        for (var j = 0; j < occupied.length; ++j) {
                            var other = occupied[j]
                            if (box.x < other.x + other.w && box.x + box.w > other.x
                                    && box.y < other.y + other.h && box.y + box.h > other.y)
                                return true
                        }
                        return false
                    }
                    for (var labelIndex = 0; labelIndex < points.length; ++labelIndex) {
                        var point = points[labelIndex]
                        if (point.index >= pcaScene.tokens.length)
                            continue
                        var label = String(pcaScene.tokens[point.index].texto)
                        var labelWidth = ctx.measureText(label).width
                        var candidates = [
                            { x: point.x + 8, y: point.y - 8 },
                            { x: point.x + 8, y: point.y + fontSize + 8 },
                            { x: point.x - labelWidth - 8, y: point.y - 8 },
                            { x: point.x - labelWidth - 8, y: point.y + fontSize + 8 }
                        ]
                        for (var candidateIndex = 0; candidateIndex < candidates.length; ++candidateIndex) {
                            var candidate = candidates[candidateIndex]
                            var box = { x: candidate.x - 3,
                                        y: candidate.y - fontSize - 2,
                                        w: labelWidth + 6,
                                        h: fontSize + 5 }
                            if (box.x < 2 || box.y < 2 || box.x + box.w > width - 2
                                    || box.y + box.h > height - 2 || intersects(box))
                                continue
                            ctx.fillStyle = Qt.alpha(Style.Theme.surface, 0.88)
                            ctx.fillRect(box.x, box.y, box.w, box.h)
                            ctx.fillStyle = Style.Theme.texto_primario
                            ctx.fillText(label, candidate.x, candidate.y)
                            occupied.push(box)
                            break
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: "PCA solo proyecta para dibujar; las etiquetas se reubican u ocultan antes de solaparse. La operación real ocurrió en " + Number(pcaScene.projection.dimension_original || 0) + " dimensiones."
                color: Style.Theme.aviso_texto
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: root.fontSize(9, pcaScene.sx)
            }
        }
    }

    component TeacherForcingScene: Item {
        id: teacherScene
        objectName: "teacherForcingScene"
        property var pairs: []
        property var decoderTokens: []
        property var targetTokens: []
        property real sx: 1
        property real sy: 1
        ColumnLayout {
            anchors.fill: parent
            spacing: 7 * teacherScene.sy
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "SHIFT · DESPLAZAMIENTO DE UNA POSICIÓN"
                    color: Style.Theme.aviso_texto
                    font.bold: true
                    font.pixelSize: root.fontSize(10, teacherScene.sx)
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "mismo ancho = misma posición"
                    color: Style.Theme.texto_terciario
                    font.pixelSize: root.fontSize(8, teacherScene.sx)
                }
            }
            Rectangle {
                objectName: "teacherForcingAlignment"
                Layout.fillWidth: true
                Layout.preferredHeight: 82 * teacherScene.sy
                radius: 9 * teacherScene.sx
                color: Style.Theme.superficie_alterna
                border.color: Style.Theme.borde_medio
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 7 * teacherScene.sx
                    spacing: 4 * teacherScene.sy
                    ShiftSequenceBand {
                        title: "ENTRADA DECODER"
                        tokens: teacherScene.decoderTokens
                        accent: "#D97706"
                        sx: teacherScene.sx
                        sy: teacherScene.sy
                    }
                    ShiftSequenceBand {
                        title: "OBJETIVO (+1)"
                        tokens: teacherScene.targetTokens
                        accent: "#059669"
                        sx: teacherScene.sx
                        sy: teacherScene.sy
                    }
                }
            }
            Text {
                text: "PREFIJO QUE PUEDE VER  →  TOKEN QUE DEBE PREDECIR"
                color: Style.Theme.texto_secundario
                font.bold: true
                font.pixelSize: root.fontSize(9, teacherScene.sx)
            }
            ListView {
                objectName: "teacherForcingRows"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 5 * teacherScene.sy
                model: teacherScene.pairs
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    id: forcingRow
                    required property int index
                    required property var modelData
                    width: ListView.view.width
                    height: 43 * teacherScene.sy
                    radius: 8 * teacherScene.sx
                    color: Style.Theme.superficie_alterna
                    border.color: Style.Theme.borde_medio
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 7 * teacherScene.sx
                        spacing: 7 * teacherScene.sx
                        Text {
                            Layout.preferredWidth: 27 * teacherScene.sx
                            text: "t=" + (forcingRow.index + 1)
                            color: Style.Theme.texto_terciario
                            font.pixelSize: root.fontSize(8, teacherScene.sx)
                        }
                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: prefixTokens.implicitWidth
                            contentHeight: height
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            Row {
                                id: prefixTokens
                                height: parent.height
                                spacing: 4 * teacherScene.sx
                                Repeater {
                                    model: forcingRow.modelData.prefijo
                                           || [forcingRow.modelData.entrada]
                                    delegate: CompactToken {
                                        required property var modelData
                                        label: modelData.texto
                                        accent: "#D97706"
                                        scaleX: teacherScene.sx
                                        scaleY: teacherScene.sy
                                    }
                                }
                            }
                        }
                        Text {
                            text: "→"
                            color: Style.Theme.aviso_texto
                            font.bold: true
                            font.pixelSize: 13 * teacherScene.sx
                        }
                        CompactToken {
                            label: forcingRow.modelData.objetivo.texto
                            accent: "#059669"
                            scaleX: teacherScene.sx
                            scaleY: teacherScene.sy
                            fixedWidth: 72 * teacherScene.sx
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: "BOS inicia el decoder; EOS cierra el objetivo. La máscara causal impide consultar posiciones futuras."
                color: Style.Theme.texto_secundario
                font.pixelSize: root.fontSize(8, teacherScene.sx)
                wrapMode: Text.WordWrap
            }
        }
    }

    component MaskScene: Item {
        id: maskScene
        property var maskData: ({})
        property var tokens: []
        property real sx: 1
        property real sy: 1
        readonly property var values: maskData.valores || []
        onValuesChanged: maskCanvas.requestPaint()
        ColumnLayout {
            anchors.fill: parent
            spacing: 8 * maskScene.sy
            RowLayout {
                Layout.fillWidth: true
                Text { text: maskScene.maskData.activa ? "Máscara causal real" : "Máscara causal desactivada (experimento)"; color: maskScene.maskData.activa ? Style.Theme.error_texto : Style.Theme.aviso_texto; font.bold: true; font.pixelSize: 14 * maskScene.sx }
                Item { Layout.fillWidth: true }
                Text { text: Number(maskScene.maskData.porcentaje_bloqueado || 0).toFixed(1) + "% bloqueado"; color: Style.Theme.texto_secundario; font.pixelSize: root.fontSize(10, maskScene.sx) }
            }
            Canvas {
                id: maskCanvas
                Layout.fillWidth: true; Layout.fillHeight: true
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset(); ctx.clearRect(0, 0, width, height)
                    var n = maskScene.values.length
                    if (!n) return
                    var labelMargin = Math.min(96 * maskScene.sx,
                                               Math.max(48 * maskScene.sx, width * 0.16))
                    var side = Math.max(28, Math.min(width - labelMargin - 12,
                                                     height - 48 * maskScene.sy))
                    var cell = side / n
                    var ox = labelMargin + Math.max(0, (width - labelMargin - side) / 2)
                    var oy = 30 * maskScene.sy
                    var fontSize = Math.max(8, Math.min(10 * maskScene.sx, cell * 0.34))
                    var labelStride = Math.max(1, Math.ceil(18 / Math.max(1, cell)))
                    function tokenLabel(index) {
                        var raw = index < maskScene.tokens.length
                                  ? String(maskScene.tokens[index].texto) : String(index)
                        if (cell < 24)
                            return String(index + 1)
                        var limit = Math.max(2, Math.floor(cell / Math.max(5, fontSize * 0.58)))
                        return raw.length > limit ? raw.slice(0, Math.max(1, limit - 1)) + "…" : raw
                    }
                    ctx.font = fontSize + "px sans-serif"; ctx.textAlign = "center"; ctx.textBaseline = "middle"
                    for (var c = 0; c < n; ++c) {
                        if (c % labelStride !== 0)
                            continue
                        ctx.fillStyle = Style.Theme.texto_secundario
                        ctx.fillText(tokenLabel(c), ox + (c + 0.5) * cell, oy - 14 * maskScene.sy)
                    }
                    for (var r = 0; r < n; ++r) {
                        if (r % labelStride === 0) {
                            ctx.fillStyle = Style.Theme.texto_secundario; ctx.textAlign = "right"
                            ctx.fillText(tokenLabel(r), ox - 8 * maskScene.sx, oy + (r + 0.5) * cell)
                        }
                        ctx.textAlign = "center"
                        for (c = 0; c < n; ++c) {
                            var allowed = Boolean(maskScene.values[r][c])
                            ctx.fillStyle = allowed ? Style.Theme.exito_fondo : Style.Theme.error_fondo
                            ctx.fillRect(ox + c * cell, oy + r * cell, cell - 1, cell - 1)
                            if (cell >= 12) {
                                ctx.fillStyle = allowed ? Style.Theme.exito_texto : Style.Theme.error_texto
                                ctx.fillText(allowed ? "✓" : "×", ox + (c + 0.5) * cell, oy + (r + 0.5) * cell)
                            }
                        }
                    }
                }
            }
        }
    }

    component MaskedAttentionScene: Item {
        id: maskedScene
        property var maskData: ({})
        property var tokens: []
        property var attentionData: ({})
        property int headIndex: 0
        property int focusedQuery: -1
        property bool active: false
        property real sx: 1
        property real sy: 1
        property int viewIndex: 0
        signal headSelected(int index)

        ColumnLayout {
            anchors.fill: parent
            spacing: 6 * maskedScene.sy
            TabBar {
                Layout.fillWidth: true
                currentIndex: maskedScene.viewIndex
                onCurrentIndexChanged: maskedScene.viewIndex = currentIndex
                TabButton { text: "1 · Regla de la máscara" }
                TabButton { text: "2 · Pesos permitidos" }
            }
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: maskedScene.viewIndex
                MaskScene {
                    maskData: maskedScene.maskData
                    tokens: maskedScene.tokens
                    sx: maskedScene.sx
                    sy: maskedScene.sy
                }
                AttentionFlowScene {
                    attentionData: maskedScene.attentionData
                    queryTokens: maskedScene.tokens
                    keyTokens: maskedScene.tokens
                    crossAttention: false
                    headIndex: maskedScene.headIndex
                    focusedQuery: maskedScene.focusedQuery
                    active: maskedScene.active && maskedScene.viewIndex === 1
                    sx: maskedScene.sx
                    sy: maskedScene.sy
                    onHeadSelected: function(index) { maskedScene.headSelected(index) }
                }
            }
        }
    }

    component PredictionScene: Item {
        id: predictionScene
        property var prediction: null
        property real sx: 1
        property real sy: 1
        readonly property var candidates: prediction ? prediction.top || [] : []
        readonly property real maximum: candidates.length ? Math.max(1e-9, Number(candidates[0].probabilidad || 0)) : 1
        ColumnLayout {
            anchors.fill: parent; spacing: 8 * predictionScene.sy
            Text { text: predictionScene.prediction ? "Objetivo: “" + predictionScene.prediction.objetivo.texto + "”" : "Sin predicción"; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 15 * predictionScene.sx }
            Repeater {
                model: predictionScene.candidates
                delegate: RowLayout {
                    id: predictionRow
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 39 * predictionScene.sy; spacing: 8 * predictionScene.sx
                    Text { Layout.preferredWidth: 28 * predictionScene.sx; text: "#" + predictionRow.modelData.rango; color: Style.Theme.texto_terciario; font.pixelSize: root.fontSize(9, predictionScene.sx) }
                    Text { Layout.preferredWidth: 115 * predictionScene.sx; text: "“" + predictionRow.modelData.texto + "”"; color: predictionRow.modelData.esperado ? Style.Theme.exito_texto : Style.Theme.texto_primario; font.bold: true; elide: Text.ElideRight; font.pixelSize: root.fontSize(11, predictionScene.sx) }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 16 * predictionScene.sy; radius: height / 2; color: Style.Theme.borde_medio
                        Rectangle { width: parent.width * Number(predictionRow.modelData.probabilidad || 0) / predictionScene.maximum; height: parent.height; radius: parent.radius; color: predictionRow.modelData.esperado ? Style.Theme.success : "#0F766E"; Behavior on width { NumberAnimation { duration: 420 } } }
                    }
                    Text { Layout.preferredWidth: 62 * predictionScene.sx; text: (Number(predictionRow.modelData.probabilidad || 0) * 100).toFixed(2) + "%"; color: Style.Theme.texto_secundario; horizontalAlignment: Text.AlignRight; font.pixelSize: root.fontSize(10, predictionScene.sx) }
                }
            }
            Item { Layout.fillHeight: true }
            Text { Layout.fillWidth: true; text: "El objetivo se marca en verde solo si aparece en Top‑5; su probabilidad exacta siempre se usa para calcular la loss."; color: Style.Theme.texto_secundario; wrapMode: Text.WordWrap; font.pixelSize: root.fontSize(9, predictionScene.sx) }
        }
    }

    component LossScene: Item {
        id: lossScene
        property var prediction: null
        property real batchLoss: 0
        property real sx: 1
        property real sy: 1
        ColumnLayout {
            anchors.fill: parent
            spacing: 10 * lossScene.sy
            Text {
                Layout.fillWidth: true
                text: "La cross entropy usa la probabilidad del objetivo. Después promedia todas las posiciones válidas; PAD no participa."
                color: Style.Theme.texto_secundario
                wrapMode: Text.WordWrap
                font.pixelSize: root.fontSize(10, lossScene.sx)
            }
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: lossScene.width < 720 ? 2 : 4
                columnSpacing: 8 * lossScene.sx
                rowSpacing: 8 * lossScene.sy
                MetricCard { title: "1 · OBJETIVO"; value: lossScene.prediction ? lossScene.prediction.objetivo.texto : "—"; detail: lossScene.prediction ? "token correcto · rango " + lossScene.prediction.objetivo.rango : ""; accent: "#059669"; sx: lossScene.sx; sy: lossScene.sy }
                MetricCard { title: "2 · PROBABILIDAD"; value: lossScene.prediction ? (Number(lossScene.prediction.objetivo.probabilidad) * 100).toFixed(3) + "%" : "—"; detail: "p(objetivo) entre todo el vocabulario"; accent: "#2563EB"; sx: lossScene.sx; sy: lossScene.sy }
                MetricCard { title: "3 · LOSS DEL TOKEN"; value: lossScene.prediction ? Number(lossScene.prediction.perdida_token).toFixed(4) : "—"; detail: "−log p(objetivo)"; accent: "#B45309"; sx: lossScene.sx; sy: lossScene.sy }
                MetricCard { title: "4 · LOSS DEL BATCH"; value: Number(lossScene.batchLoss).toFixed(4); detail: "media de tokens válidos, sin PAD"; accent: "#9333EA"; sx: lossScene.sx; sy: lossScene.sy }
            }
        }
    }

    component MetricCard: Rectangle {
        id: metricCard
        property string title: ""
        property string value: ""
        property string detail: ""
        property color accent: Style.Theme.acento
        property real sx: 1
        property real sy: 1
        Layout.fillWidth: true; Layout.preferredHeight: 130 * sy; radius: 11 * sx
        color: Qt.alpha(accent, 0.09); border.color: Qt.alpha(accent, 0.4)
        Column { anchors.centerIn: parent; width: parent.width - 16 * metricCard.sx; spacing: 7 * metricCard.sy
            Text { width: parent.width; text: metricCard.title; color: metricCard.accent; font.bold: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: root.fontSize(9, metricCard.sx); wrapMode: Text.WordWrap }
            Text { width: parent.width; text: metricCard.value; color: Style.Theme.texto_primario; font.bold: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 18 * metricCard.sx; elide: Text.ElideRight }
            Text { width: parent.width; text: metricCard.detail; color: Style.Theme.texto_secundario; horizontalAlignment: Text.AlignHCenter; font.pixelSize: root.fontSize(9, metricCard.sx); wrapMode: Text.WordWrap }
        }
    }

    component BackpropScene: Item {
        id: backpropScene
        property real gradientNorm: 0
        property bool active: false
        property real sx: 1
        property real sy: 1
        property real pulse: 0
        readonly property bool compact: width < 720
        readonly property var reverseBlocks: compact
            ? [
                  { label: "LOSS", derivative: "punto de partida", color: "#DC2626" },
                  { label: "Salida + decoder", derivative: "∂L/∂h_dec", color: "#9333EA" },
                  { label: "Encoder", derivative: "∂L/∂h_enc", color: "#7C3AED" },
                  { label: "Embeddings", derivative: "∂L/∂W_emb", color: "#2563EB" }
              ]
            : [
                  { label: "LOSS", derivative: "∂L/∂L = 1", color: "#DC2626" },
                  { label: "Linear", derivative: "∂L/∂logits", color: "#B45309" },
                  { label: "Decoder", derivative: "∂L/∂h_dec", color: "#9333EA" },
                  { label: "Cross-Attn", derivative: "dos rutas", color: "#059669" },
                  { label: "Encoder", derivative: "∂L/∂h_enc", color: "#7C3AED" },
                  { label: "Embeddings", derivative: "∂L/∂W_emb", color: "#2563EB" }
              ]
        NumberAnimation on pulse { from: 0; to: 1; duration: 1800; loops: Animation.Infinite; running: backpropScene.active }
        ColumnLayout {
            anchors.fill: parent
            spacing: 10 * backpropScene.sy

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "BACKWARD · EL ERROR RECORRE EL GRAFO AL REVÉS"
                    color: "#9333EA"
                    font.bold: true
                    font.pixelSize: root.fontSize(10, backpropScene.sx)
                    elide: Text.ElideRight
                }
                Rectangle {
                    Layout.preferredWidth: backwardBadge.implicitWidth + 20 * backpropScene.sx
                    Layout.preferredHeight: 27 * backpropScene.sy
                    radius: height / 2
                    color: Qt.alpha("#9333EA", 0.11)
                    border.color: Qt.alpha("#9333EA", 0.55)
                    Text {
                        id: backwardBadge
                        anchors.centerIn: parent
                        text: "loss.backward()"
                        color: "#9333EA"
                        font.bold: true
                        font.family: Style.Theme.fuente_mono
                        font.pixelSize: root.fontSize(9, backpropScene.sx)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "La loss es un escalar. Autograd aplica derivadas locales y la regla de la cadena hasta obtener la sensibilidad de cada parámetro."
                color: Style.Theme.texto_secundario
                wrapMode: Text.WordWrap
                font.pixelSize: root.fontSize(10, backpropScene.sx)
            }

            Rectangle {
                objectName: "trainingBackpropChain"
                Layout.fillWidth: true
                Layout.preferredHeight: backpropScene.compact
                                        ? 145 * backpropScene.sy
                                        : 175 * backpropScene.sy
                Layout.minimumHeight: 125 * backpropScene.sy
                Layout.maximumHeight: 210 * backpropScene.sy
                radius: 11 * backpropScene.sx
                color: Style.Theme.superficie_alterna
                border.color: Qt.alpha("#9333EA", 0.34)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10 * backpropScene.sx
                    spacing: 6 * backpropScene.sy
                    Text {
                        Layout.fillWidth: true
                        text: "LOSS  →  capas finales  →  capas iniciales"
                        color: Style.Theme.texto_secundario
                        horizontalAlignment: Text.AlignHCenter
                        font.bold: true
                        font.pixelSize: root.fontSize(9, backpropScene.sx)
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Row {
                            id: reverseRoute
                            anchors.fill: parent
                            spacing: 0
                            Repeater {
                                model: backpropScene.reverseBlocks
                                delegate: Item {
                                    id: backpropBlock
                                    required property int index
                                    required property var modelData
                                    width: reverseRoute.width
                                           / backpropScene.reverseBlocks.length
                                    height: reverseRoute.height
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        anchors.right: parent.right
                                        anchors.rightMargin: backpropBlock.index
                                                             < backpropScene.reverseBlocks.length - 1
                                                             ? 22 * backpropScene.sx : 0
                                        radius: 8 * backpropScene.sx
                                        color: Qt.alpha(backpropBlock.modelData.color,
                                                        0.07 + 0.10 * Math.abs(Math.sin(
                                                            (backpropScene.pulse
                                                             + backpropBlock.index
                                                               / backpropScene.reverseBlocks.length)
                                                            * Math.PI)))
                                        border.width: backpropBlock.index === 0 ? 2 : 1
                                        border.color: backpropBlock.modelData.color
                                        Column {
                                            anchors.centerIn: parent
                                            width: parent.width - 8 * backpropScene.sx
                                            spacing: 2 * backpropScene.sy
                                            Text {
                                                width: parent.width
                                                text: backpropBlock.modelData.label
                                                color: backpropBlock.modelData.color
                                                font.bold: true
                                                horizontalAlignment: Text.AlignHCenter
                                                wrapMode: Text.WordWrap
                                                font.pixelSize: root.fontSize(9, backpropScene.sx)
                                            }
                                            Text {
                                                width: parent.width
                                                text: backpropBlock.modelData.derivative
                                                color: Style.Theme.texto_secundario
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                                font.pixelSize: root.fontSize(8, backpropScene.sx)
                                            }
                                        }
                                    }
                                    Text {
                                        visible: backpropBlock.index
                                                 < backpropScene.reverseBlocks.length - 1
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 22 * backpropScene.sx
                                        text: "→"
                                        color: "#9333EA"
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        font.pixelSize: 16 * backpropScene.sx
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6 * backpropScene.sx
                Repeater {
                    model: [
                        { number: "1", title: "Derivadas locales", detail: "Cada operación aporta cómo cambia su salida." },
                        { number: "2", title: "Regla de la cadena", detail: "Las sensibilidades se combinan hacia atrás." },
                        { number: "3", title: "Gradientes en .grad", detail: "Se guarda un tensor por parámetro entrenable." }
                    ]
                    delegate: Rectangle {
                        id: chainFact
                        required property int index
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56 * backpropScene.sy
                        radius: 8 * backpropScene.sx
                        color: Qt.alpha("#9333EA", 0.055)
                        border.color: Qt.alpha("#9333EA", 0.24)
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 7 * backpropScene.sx
                            spacing: 7 * backpropScene.sx
                            Rectangle {
                                Layout.preferredWidth: 24 * backpropScene.sx
                                Layout.preferredHeight: 24 * backpropScene.sy
                                radius: width / 2
                                color: "#9333EA"
                                Text { anchors.centerIn: parent; text: chainFact.modelData.number; color: "white"; font.bold: true }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text { Layout.fillWidth: true; text: chainFact.modelData.title; color: Style.Theme.texto_primario; font.bold: true; elide: Text.ElideRight; font.pixelSize: root.fontSize(8, backpropScene.sx) }
                                Text { Layout.fillWidth: true; text: chainFact.modelData.detail; color: Style.Theme.texto_secundario; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; font.pixelSize: root.fontSize(8, backpropScene.sx) }
                            }
                        }
                    }
                }
            }

            Rectangle {
                objectName: "trainingBackpropNoUpdate"
                Layout.fillWidth: true
                Layout.preferredHeight: noUpdateText.implicitHeight + 14 * backpropScene.sy
                radius: 8 * backpropScene.sx
                color: Style.Theme.aviso_fondo
                border.color: Style.Theme.warning
                Text {
                    id: noUpdateText
                    anchors.fill: parent
                    anchors.margins: 7 * backpropScene.sx
                    text: "Aún no cambian los pesos. backward() solo calcula y acumula gradientes. optimizer.step() los usará en el paso siguiente.  Norma L2 global: "
                          + root.number(backpropScene.gradientNorm, 3)
                    color: Style.Theme.aviso_texto
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                    font.pixelSize: root.fontSize(9, backpropScene.sx)
                }
            }
        }
    }

    component GradientScene: Item {
        id: gradientScene
        property var updates: []
        property real maximum: 1
        property real sx: 1
        property real sy: 1
        ColumnLayout {
            anchors.fill: parent; spacing: 7 * gradientScene.sy
            Text {
                Layout.fillWidth: true
                text: "LECTURA: barra = norma L2 relativa a la familia más alta de este batch · RMS = magnitud típica por elemento"
                color: "#C026D3"
                font.bold: true
                wrapMode: Text.WordWrap
                font.pixelSize: root.fontSize(9, gradientScene.sx)
            }
            RowLayout { Layout.fillWidth: true
                Text { text: "FAMILIA DE PARÁMETROS"; Layout.preferredWidth: 190 * gradientScene.sx; color: Style.Theme.texto_secundario; font.bold: true; font.pixelSize: root.fontSize(8, gradientScene.sx) }
                Text { text: "NORMA L2 DEL GRADIENTE"; Layout.fillWidth: true; color: Style.Theme.texto_secundario; font.bold: true; font.pixelSize: root.fontSize(8, gradientScene.sx) }
                Text { text: "RMS"; Layout.preferredWidth: 74 * gradientScene.sx; color: Style.Theme.texto_secundario; font.bold: true; font.pixelSize: root.fontSize(8, gradientScene.sx) }
            }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 5 * gradientScene.sy; model: gradientScene.updates
                delegate: RowLayout {
                    id: gradientRow
                    required property var modelData
                    width: ListView.view.width; height: 31 * gradientScene.sy; spacing: 8 * gradientScene.sx
                    Text { Layout.preferredWidth: 190 * gradientScene.sx; text: gradientRow.modelData.etiqueta; color: Style.Theme.texto_primario; elide: Text.ElideRight; font.pixelSize: root.fontSize(9, gradientScene.sx) }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 12 * gradientScene.sy; radius: height / 2; color: Style.Theme.borde_medio
                        Rectangle { width: parent.width * Math.min(1, Number(gradientRow.modelData.gradiente_norma_l2 || 0) / Math.max(1e-12, gradientScene.maximum)); height: parent.height; radius: parent.radius; color: "#C026D3" }
                    }
                    Text { Layout.preferredWidth: 74 * gradientScene.sx; text: root.number(gradientRow.modelData.gradiente_rms, 2); color: Style.Theme.texto_secundario; horizontalAlignment: Text.AlignRight; font.pixelSize: root.fontSize(8, gradientScene.sx) }
                }
            }
            Text {
                Layout.fillWidth: true
                text: "Estas barras describen la señal calculada; no son probabilidades, calidad ni cambios de peso."
                color: Style.Theme.texto_secundario
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: root.fontSize(9, gradientScene.sx)
            }
        }
    }

    component OptimizerScene: Item {
        id: optimizerScene
        property var updates: []
        property int selectedIndex: 0
        property var optimizer: ({})
        property real sx: 1
        property real sy: 1
        readonly property var update: updates.length ? updates[Math.max(0, Math.min(updates.length - 1, selectedIndex))] : null
        signal selected(int index)
        ColumnLayout {
            anchors.fill: parent; spacing: 12 * optimizerScene.sy
            Rectangle {
                objectName: "trainingOptimizerUpdateNotice"
                Layout.fillWidth: true
                Layout.preferredHeight: optimizerNotice.implicitHeight + 14 * optimizerScene.sy
                radius: 8 * optimizerScene.sx
                color: Style.Theme.exito_fondo
                border.color: Style.Theme.success
                Text {
                    id: optimizerNotice
                    anchors.fill: parent
                    anchors.margins: 7 * optimizerScene.sx
                    text: "AQUÍ SÍ CAMBIAN LOS PESOS · optimizer.step() transforma los gradientes en actualizaciones de Adam."
                    color: Style.Theme.exito_texto
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                    font.pixelSize: root.fontSize(9, optimizerScene.sx)
                }
            }
            RowLayout { Layout.fillWidth: true
                Text { text: "Parámetro inspeccionado"; color: Style.Theme.texto_secundario; font.pixelSize: root.fontSize(10, optimizerScene.sx) }
                SelectorPrincipal { Layout.fillWidth: true; sx: root.sx; sy: root.sy; model: optimizerScene.updates.map(function(item) { return item.etiqueta }); currentIndex: optimizerScene.selectedIndex; onActivated: function(index) { optimizerScene.selected(index) } }
                Text { text: String(optimizerScene.optimizer.nombre || "—") + " · LR " + root.number(optimizerScene.optimizer.tasa_aprendizaje, 2); color: "#047857"; font.bold: true; font.pixelSize: root.fontSize(10, optimizerScene.sx) }
            }
            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8 * optimizerScene.sx
                MetricCard { title: "ANTES"; value: optimizerScene.update ? root.number(optimizerScene.update.antes, 5) : "—"; detail: optimizerScene.update ? optimizerScene.update.parametro + " [" + optimizerScene.update.indice.join(",") + "]" : ""; accent: "#2563EB"; sx: optimizerScene.sx; sy: optimizerScene.sy }
                Text { text: "+"; color: Style.Theme.texto_terciario; font.pixelSize: 20 * optimizerScene.sx }
                MetricCard { title: "DELTA REAL"; value: optimizerScene.update ? root.number(optimizerScene.update.actualizacion, 5) : "—"; detail: "incluye estado de " + String(optimizerScene.optimizer.nombre || "optimizador"); accent: "#D97706"; sx: optimizerScene.sx; sy: optimizerScene.sy }
                Text { text: "="; color: Style.Theme.texto_terciario; font.pixelSize: 20 * optimizerScene.sx }
                MetricCard { title: "DESPUÉS"; value: optimizerScene.update ? root.number(optimizerScene.update.despues, 5) : "—"; detail: optimizerScene.update ? "gradiente " + root.number(optimizerScene.update.gradiente, 3) : ""; accent: "#047857"; sx: optimizerScene.sx; sy: optimizerScene.sy }
            }
            Text {
                Layout.fillWidth: true
                text: optimizerScene.update
                      ? "Gradientes del grupo · L2 " + root.number(optimizerScene.update.gradiente_norma_l2, 3)
                        + " · RMS " + root.number(optimizerScene.update.gradiente_rms, 3)
                        + " · media " + root.number(optimizerScene.update.gradiente_media, 3)
                        + " · min " + root.number(optimizerScene.update.gradiente_minimo, 3)
                        + " · max " + root.number(optimizerScene.update.gradiente_maximo, 3)
                      : ""
                color: Style.Theme.texto_secundario
                wrapMode: Text.WordWrap
                font.pixelSize: root.fontSize(9, optimizerScene.sx)
            }
            Text { Layout.fillWidth: true; text: optimizerScene.optimizer.advertencia || ""; color: Style.Theme.aviso_texto; wrapMode: Text.WordWrap; font.pixelSize: root.fontSize(9, optimizerScene.sx) }
        }
    }

    component EvolutionScene: Item {
        id: evolution
        property var history: []
        property real batchLoss: 0
        property real sx: 1
        property real sy: 1
        onHistoryChanged: lossCanvas.requestPaint()
        ColumnLayout {
            anchors.fill: parent; spacing: 8 * evolution.sy
            RowLayout { Layout.fillWidth: true
                Text { text: "Pérdida observada durante el entrenamiento"; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 14 * evolution.sx }
                Item { Layout.fillWidth: true }
                Text { text: evolution.history.length + " batches · actual " + Number(evolution.batchLoss).toFixed(4); color: "#1D4ED8"; font.bold: true; font.pixelSize: root.fontSize(10, evolution.sx) }
            }
            Canvas {
                id: lossCanvas
                Layout.fillWidth: true; Layout.fillHeight: true
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset(); ctx.clearRect(0, 0, width, height)
                    if (!evolution.history.length) return
                    var data = evolution.history.slice(Math.max(0, evolution.history.length - 80)); var min = 1e30, max = -1e30
                    for (var i = 0; i < data.length; ++i) { min = Math.min(min, Number(data[i])); max = Math.max(max, Number(data[i])) }
                    if (Math.abs(max - min) < 1e-9) { min -= 0.5; max += 0.5 }
                    var pad = 30; ctx.strokeStyle = Style.Theme.borde_medio; ctx.lineWidth = 1
                    ctx.strokeRect(pad, 10, width - pad - 10, height - pad - 10)
                    ctx.strokeStyle = "#1D4ED8"; ctx.lineWidth = 2.5; ctx.beginPath()
                    for (i = 0; i < data.length; ++i) {
                        var x = pad + (data.length === 1 ? 0 : i / (data.length - 1)) * (width - pad - 10)
                        var y = 10 + (max - Number(data[i])) / (max - min) * (height - pad - 10)
                        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                    }
                    ctx.stroke(); ctx.fillStyle = Style.Theme.texto_secundario; ctx.font = Math.max(8, 9 * evolution.sx) + "px sans-serif"
                    ctx.fillText(max.toFixed(3), 2, 18); ctx.fillText(min.toFixed(3), 2, height - pad)
                }
            }
            Text { Layout.fillWidth: true; text: "Cada punto es loss de entrenamiento de un batch usado para actualizar pesos. No es validación ni demuestra generalización; una subida local puede deberse a un batch más difícil."; color: Style.Theme.texto_secundario; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.pixelSize: root.fontSize(9, evolution.sx) }
        }
    }
}
