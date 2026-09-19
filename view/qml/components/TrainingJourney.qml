pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
            technical: "Q, K y V proceden de la misma secuencia. Puedes cambiar capa, cabeza y token consultante.",
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
            technical: "La comparación usa los estados reales antes de la pila y después de la última capa del encoder.",
            mathematical: "H_enc = Encoder(X₀)",
            formula: "Representación inicial → contextual"
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
            technical: "Q procede del decoder; K y V proceden de la salida del encoder.",
            mathematical: "Q=H_decWQ · K=H_encWK · V=H_encWV",
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
            mathematical: "Lₜ = −log p(yₜ) · L_batch = mean(Lₜ)",
            formula: "Cross Entropy Loss"
        },
        {
            id: "backprop", short: "Backward", color: "#9333EA",
            title: "El error vuelve por el grafo de cálculo",
            action: "Autograd recorre el cálculo en sentido inverso y deriva la pérdida respecto de cada parámetro entrenable.",
            input: "Pérdida del batch y grafo conservado durante forward.",
            output: "Un gradiente almacenado en .grad para cada parámetro.",
            purpose: "Indica en qué dirección y con qué sensibilidad debería cambiar cada peso; todavía no lo modifica.",
            intuitive: "La señal de error viaja hacia atrás y mide cuánto contribuyó cada parámetro.",
            technical: "autograd aplica la regla de la cadena desde la loss hasta embeddings, atención, FFN y normalizaciones.",
            mathematical: "∂L/∂W = ∂L/∂h · ∂h/∂W",
            formula: "loss.backward()"
        },
        {
            id: "gradients", short: "Gradientes", color: "#C026D3",
            title: "La vista resume los gradientes calculados",
            action: "Agrupa los gradientes reales por función y calcula medidas comparables como norma L2 y RMS.",
            input: "Gradientes producidos por backward.",
            output: "Barras y estadísticas por familia de parámetros.",
            purpose: "Ayuda a interpretar dónde llegó una señal fuerte o débil; esta medición no cambia el modelo.",
            intuitive: "Las barras muestran qué familias recibieron una corrección más intensa en este batch.",
            technical: "Se muestran norma L2, RMS, media, mínimo y máximo de gradientes reales agrupados por función.",
            mathematical: "‖g‖₂ = √Σgᵢ² · RMS(g)=√(Σgᵢ²/n)",
            formula: "∇θL"
        },
        {
            id: "optimizer", short: "Adam", color: "#047857",
            title: "El optimizador aplica una actualización real",
            action: "Adam combina cada gradiente con su historial interno y la tasa de aprendizaje para modificar el parámetro.",
            input: "Pesos actuales, gradientes, estado de Adam y learning rate.",
            output: "Nuevos valores de los parámetros del modelo.",
            purpose: "Este es el momento en que el modelo realmente aprende del batch.",
            intuitive: "Una modificación pequeña de muchos valores, repetida batch tras batch, constituye el aprendizaje.",
            technical: "Antes, gradiente, delta y después pertenecen al mismo elemento real; el delta incluye la regla interna de Adam.",
            mathematical: "θₜ = θₜ₋₁ − η·m̂ₜ/(√v̂ₜ+ε)",
            formula: "optimizer.step()"
        },
        {
            id: "evolution", short: "Evolución", color: "#1D4ED8",
            title: "La mejora se evalúa a lo largo de muchos batches",
            action: "Guarda la pérdida del paso, actualiza los contadores y continúa con el siguiente batch o la siguiente época.",
            input: "Pérdida recién observada e historial anterior.",
            output: "Curva de pérdida actualizada y avance del entrenamiento.",
            purpose: "Permite evaluar la tendencia; un solo batch no basta para decidir si el modelo mejora.",
            intuitive: "La pérdida puede subir en un batch difícil; importa la tendencia, no exigir que cada punto baje.",
            technical: "La curva conserva los últimos pasos observados. Cada punto puede corresponder a ejemplos distintos por el shuffle.",
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

    onSnapshotChanged: {
        tokenIndex = Math.max(0, Math.min(predictions.length - 1, tokenIndex))
        layerIndex = Math.max(0, Math.min(Math.max(1, numLayers) - 1, layerIndex))
        headIndex = Math.max(0, Math.min(Math.max(1, numHeads) - 1, headIndex))
        parameterIndex = Math.max(0, Math.min(updates.length - 1, parameterIndex))
    }

    Timer {
        interval: 3300
        repeat: true
        running: root.playing
        onTriggered: {
            if (root.stageIndex >= root.stages.length - 1)
                root.playing = false
            else
                root.setStage(root.stageIndex + 1)
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
            Text {
                text: "Nivel"
                color: Style.Theme.texto_secundario
                font.pixelSize: root.fontSize(9, root.sx)
            }
            SelectorPrincipal {
                Layout.preferredWidth: 125 * root.sx
                sx: root.sx
                sy: root.sy
                model: ["Intuitiva", "Técnica", "Matemática"]
                currentIndex: root.explanationLevel
                onActivated: function(index) { root.explanationLevel = index }
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

            Rectangle {
                Layout.preferredWidth: 310 * root.sx
                Layout.fillHeight: true
                radius: 11 * root.sx
                color: Qt.alpha(root.stage.color, 0.07)
                border.color: Qt.alpha(root.stage.color, 0.35)

                ScrollView {
                    id: explanationScroll
                    anchors.fill: parent
                    anchors.margins: 13 * root.sx
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                    ColumnLayout {
                    id: explanationPanel
                    width: explanationScroll.availableWidth
                    spacing: 8 * root.sy
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
                        font.pixelSize: 15 * root.sx
                        wrapMode: Text.WordWrap
                    }

                    StageFact {
                        objectName: "trainingStageAction"
                        Layout.fillWidth: true
                        label: "QUÉ HACE"
                        value: root.stage.action
                        accent: root.stage.color
                        sx: root.sx
                        sy: root.sy
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6 * root.sx

                        StageFact {
                            objectName: "trainingStageInput"
                            Layout.fillWidth: true
                            label: "RECIBE"
                            value: root.stage.input
                            accent: root.stage.color
                            sx: root.sx
                            sy: root.sy
                        }

                        StageFact {
                            objectName: "trainingStageOutput"
                            Layout.fillWidth: true
                            label: "PRODUCE"
                            value: root.stage.output
                            accent: root.stage.color
                            sx: root.sx
                            sy: root.sy
                        }
                    }

                    StageFact {
                        objectName: "trainingStagePurpose"
                        Layout.fillWidth: true
                        label: "POR QUÉ IMPORTA"
                        value: root.stage.purpose
                        accent: root.stage.color
                        sx: root.sx
                        sy: root.sy
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "DETALLE · " + (root.explanationLevel === 0 ? "INTUITIVO"
                                               : (root.explanationLevel === 1 ? "TÉCNICO"
                                                                              : "MATEMÁTICO"))
                        color: root.stage.color
                        font.bold: true
                        font.pixelSize: root.fontSize(8, root.sx)
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.explanationLevel === 0 ? root.stage.intuitive
                              : (root.explanationLevel === 1 ? root.stage.technical
                                                             : root.stage.mathematical)
                        color: Style.Theme.texto_secundario_fuerte
                        font.pixelSize: root.fontSize(11, root.sx)
                        wrapMode: Text.WordWrap
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: formulaText.implicitHeight + 18 * root.sy
                        radius: 8 * root.sx
                        color: Style.Theme.surface
                        border.color: Style.Theme.borde_medio
                        Text {
                            id: formulaText
                            anchors.fill: parent
                            anchors.margins: 9 * root.sx
                            text: root.explanationLevel === 2
                                  ? root.stage.mathematical : root.stage.formula
                            color: root.stage.color
                            font.family: "monospace"
                            font.pixelSize: root.fontSize(10, root.sx)
                            wrapMode: Text.WordWrap
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.fillWidth: true
                        text: "Datos del paso global " + root.globalStep
                              + " · no son valores simulados"
                        color: Style.Theme.texto_terciario
                        font.pixelSize: root.fontSize(9, root.sx)
                        wrapMode: Text.WordWrap
                    }
                    }
                }

                Rectangle {
                    id: explanationScrollIndicator
                    readonly property real trackHeight: parent.height - 20 * root.sy
                    readonly property real scrollRange: Math.max(
                        1, explanationScroll.contentHeight - explanationScroll.availableHeight)
                    width: Math.max(4, 5 * root.sx)
                    height: Math.max(30 * root.sy,
                                     trackHeight * Math.min(
                                         1, explanationScroll.availableHeight
                                            / Math.max(1, explanationScroll.contentHeight)))
                    x: parent.width - width - 5 * root.sx
                    y: 10 * root.sy
                       + (trackHeight - height)
                         * Math.max(0, Math.min(scrollRange,
                             explanationScroll.contentItem.contentY)) / scrollRange
                    radius: width / 2
                    color: Qt.alpha(root.scopeColor, 0.62)
                    visible: explanationScroll.contentHeight
                             > explanationScroll.availableHeight + 1
                    z: 2
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
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset(); ctx.clearRect(0, 0, width, height)
                    var b = pcaScene.bounds(); var pad = 32
                    function px(v) { return pad + (v - b.minX) / Math.max(1e-9, b.maxX - b.minX) * (width - 2 * pad) }
                    function py(v) { return height - pad - (v - b.minY) / Math.max(1e-9, b.maxY - b.minY) * (height - 2 * pad) }
                    for (var i = 0; i < pcaScene.count; ++i) {
                        var a = pcaScene.beforePoints[i], z = pcaScene.afterPoints[i]
                        var ax = px(pcaScene.xOf(a)), ay = py(pcaScene.yOf(a)), zx = px(pcaScene.xOf(z)), zy = py(pcaScene.yOf(z))
                        ctx.strokeStyle = Qt.alpha(pcaScene.accent, 0.55); ctx.lineWidth = 1.5
                        ctx.beginPath(); ctx.moveTo(ax, ay); ctx.lineTo(zx, zy); ctx.stroke()
                        ctx.fillStyle = Style.Theme.texto_terciario; ctx.beginPath(); ctx.arc(ax, ay, 4, 0, Math.PI * 2); ctx.fill()
                        ctx.fillStyle = pcaScene.accent; ctx.beginPath(); ctx.arc(zx, zy, 6, 0, Math.PI * 2); ctx.fill()
                        if (i < pcaScene.tokens.length) {
                            ctx.fillStyle = Style.Theme.texto_primario; ctx.font = Math.max(8, 9 * pcaScene.sx) + "px sans-serif"
                            ctx.fillText(String(pcaScene.tokens[i].texto), zx + 7, zy - 7)
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: "PCA solo proyecta para dibujar. La operación real ocurrió en " + Number(pcaScene.projection.dimension_original || 0) + " dimensiones."
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
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset(); ctx.clearRect(0, 0, width, height)
                    var n = maskScene.values.length
                    if (!n) return
                    var side = Math.min(width - 80, height - 55); var cell = side / n; var ox = (width - side) / 2; var oy = 30
                    ctx.font = Math.max(8, 9 * maskScene.sx) + "px sans-serif"; ctx.textAlign = "center"; ctx.textBaseline = "middle"
                    for (var c = 0; c < n; ++c) {
                        ctx.fillStyle = Style.Theme.texto_secundario
                        ctx.fillText(c < maskScene.tokens.length ? String(maskScene.tokens[c].texto) : String(c), ox + (c + 0.5) * cell, oy - 14)
                    }
                    for (var r = 0; r < n; ++r) {
                        ctx.fillStyle = Style.Theme.texto_secundario; ctx.textAlign = "right"
                        ctx.fillText(r < maskScene.tokens.length ? String(maskScene.tokens[r].texto) : String(r), ox - 8, oy + (r + 0.5) * cell)
                        ctx.textAlign = "center"
                        for (c = 0; c < n; ++c) {
                            var allowed = Boolean(maskScene.values[r][c])
                            ctx.fillStyle = allowed ? Style.Theme.exito_fondo : Style.Theme.error_fondo
                            ctx.fillRect(ox + c * cell, oy + r * cell, cell - 1, cell - 1)
                            ctx.fillStyle = allowed ? Style.Theme.exito_texto : Style.Theme.error_texto
                            ctx.fillText(allowed ? "✓" : "×", ox + (c + 0.5) * cell, oy + (r + 0.5) * cell)
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
        RowLayout {
            anchors.fill: parent; spacing: 12 * lossScene.sx
            MetricCard { title: "TOKEN CORRECTO"; value: lossScene.prediction ? lossScene.prediction.objetivo.texto : "—"; detail: lossScene.prediction ? "rango " + lossScene.prediction.objetivo.rango : ""; accent: "#059669"; sx: lossScene.sx; sy: lossScene.sy }
            Text { text: "→"; color: Style.Theme.texto_terciario; font.pixelSize: 22 * lossScene.sx }
            MetricCard { title: "PROBABILIDAD"; value: lossScene.prediction ? (Number(lossScene.prediction.objetivo.probabilidad) * 100).toFixed(3) + "%" : "—"; detail: "asignada al objetivo"; accent: "#2563EB"; sx: lossScene.sx; sy: lossScene.sy }
            Text { text: "→"; color: Style.Theme.texto_terciario; font.pixelSize: 22 * lossScene.sx }
            MetricCard { title: "LOSS DEL TOKEN"; value: lossScene.prediction ? Number(lossScene.prediction.perdida_token).toFixed(4) : "—"; detail: "−log p(objetivo)"; accent: "#B45309"; sx: lossScene.sx; sy: lossScene.sy }
            Text { text: "≠"; color: Style.Theme.texto_terciario; font.pixelSize: 22 * lossScene.sx }
            MetricCard { title: "LOSS DEL BATCH"; value: Number(lossScene.batchLoss).toFixed(4); detail: "media sin PAD"; accent: "#9333EA"; sx: lossScene.sx; sy: lossScene.sy }
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
        NumberAnimation on pulse { from: 0; to: 1; duration: 1800; loops: Animation.Infinite; running: backpropScene.active }
        ColumnLayout {
            anchors.fill: parent; spacing: 14 * backpropScene.sy
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true; spacing: 4 * backpropScene.sx
                Repeater {
                    model: ["Embeddings", "Encoder", "Cross-Attn", "Decoder", "Linear", "LOSS"]
                    delegate: RowLayout {
                        id: backpropBlock
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true; spacing: 3 * backpropScene.sx
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 67 * backpropScene.sy; radius: 9 * backpropScene.sx
                            color: Qt.alpha(backpropBlock.index === 5 ? "#DC2626" : "#9333EA", 0.08 + 0.10 * Math.abs(Math.sin((backpropScene.pulse + backpropBlock.index / 6) * Math.PI)))
                            border.color: backpropBlock.index === 5 ? "#DC2626" : "#9333EA"
                            Text { anchors.centerIn: parent; width: parent.width - 8; text: backpropBlock.modelData; color: backpropBlock.index === 5 ? "#DC2626" : "#9333EA"; font.bold: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.pixelSize: root.fontSize(9, root.sx) }
                        }
                        Text { visible: backpropBlock.index < 5; text: "←"; color: "#9333EA"; font.bold: true; font.pixelSize: 17 * root.sx }
                    }
                }
            }
            Text { Layout.fillWidth: true; text: "Norma global medida después de backward: " + root.number(backpropScene.gradientNorm, 3); color: Style.Theme.texto_primario; font.bold: true; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 12 * backpropScene.sx }
            Item { Layout.fillHeight: true }
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
            Text { Layout.fillWidth: true; text: "Una subida local no implica que Adam haya aprendido al revés: el siguiente batch puede contener tokens más difíciles."; color: Style.Theme.texto_secundario; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.pixelSize: root.fontSize(9, evolution.sx) }
        }
    }
}
