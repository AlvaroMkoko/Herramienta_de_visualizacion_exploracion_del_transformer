pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style

// "Fórmula en acción": anima la fórmula del paso con los números reales que
// el controlador calculó en `formula_demos`. Todo el dibujo es una función
// del progreso `t` (0 → 1), así que la animación se puede pausar y recorrer
// con el deslizador sin perder coherencia entre valores y gráficos.
Item {
    id: root
    objectName: "formulaAnimationScene"

    property var demo: ({})
    property var step: ({})
    // La pantalla enlaza estas dos explicaciones especializadas con la misma
    // guía pedagógica que acompaña a la animación principal. Así la fórmula
    // deja de ser una leyenda aislada: el estudiante puede leer qué operación
    // se ejecuta y cómo reconocerla en pantalla sin abrir otra ventana.
    property string formulaExplanation: ""
    property string animationDescription: ""
    property int explanationSection: 0
    property bool reducedMotion: false
    property real sx: 1
    property real sy: 1
    property real t: 1
    property real speed: 1

    readonly property bool running: driver.running
    readonly property real u: Math.max(0.8, Math.min(1.15, Math.min(sx, sy)))
    readonly property string kind: String(demo && demo.kind || "")
    readonly property bool hasDemo: kind.length > 0
    readonly property int cycleDuration: Math.round(durationFor(kind) / Math.max(0.25, speed))
    readonly property var phases: phasesFor(kind)
    readonly property int phaseIndex: {
        var current = 0
        for (var index = 0; index < phases.length; ++index)
            if (t >= phases[index][1])
                current = index
        return current
    }

    // ------------------------------------------------------------ control
    function replay() {
        driver.stop()
        if (root.reducedMotion || !root.hasDemo) {
            root.t = 1
            return
        }
        root.t = 0
        driver.from = 0
        driver.duration = root.cycleDuration
        driver.start()
    }

    function togglePlay() {
        if (driver.running) {
            driver.stop()
            return
        }
        if (root.t >= 0.999)
            root.t = 0
        driver.from = root.t
        driver.duration = Math.max(200, Math.round(root.cycleDuration * (1 - root.t)))
        driver.start()
    }

    function cycleSpeed() {
        root.speed = root.speed >= 2 ? 0.5 : (root.speed >= 1 ? 2 : 1)
        if (driver.running) {
            driver.stop()
            root.togglePlay()
        }
    }

    onDemoChanged: Qt.callLater(root.replay)
    onReducedMotionChanged: if (reducedMotion) { driver.stop(); t = 1 }

    NumberAnimation {
        id: driver
        target: root
        property: "t"
        to: 1
        easing.type: Easing.Linear
    }

    // ---------------------------------------------------------- utilidades
    function clamp01(value) { return Math.max(0, Math.min(1, value)) }
    function seg(a, b) { return clamp01((root.t - a) / Math.max(0.0001, b - a)) }
    function segOf(value, a, b) { return clamp01((value - a) / Math.max(0.0001, b - a)) }
    function ease(x) { return x * x * (3 - 2 * x) }
    function lerp(a, b, f) { return a + (b - a) * f }
    function list(value) { return value && value.length !== undefined ? value : [] }
    function isNum(value) {
        return value !== null && value !== undefined && isFinite(Number(value))
    }
    function num(value) { return isNum(value) ? Number(value) : 0 }

    function readableFormula() {
        var source = String(root.step && root.step.formula
                            || root.demo.formula || "")
        // Las expresiones con varios cálculos se separan por cláusulas. Esto
        // evita reducir la fuente o cortar las fórmulas largas.
        return source.replace(/;\s*/g, ";\n")
    }

    function formulaFontSize() {
        var length = String(root.step && root.step.formula
                            || root.demo.formula || "").length
        if (length > 62)
            return Math.max(18, 19 * root.u)
        if (length > 40)
            return Math.max(19, 21 * root.u)
        return Math.max(21, 24 * root.u)
    }

    function fmt(value, digits) {
        if (!isNum(value))
            return "−∞"
        var number = Number(value)
        var absolute = Math.abs(number)
        var places = digits === undefined ? 3 : digits
        if (absolute !== 0 && (absolute >= 10000 || absolute < Math.pow(10, -places)))
            return number.toExponential(2).replace("-", "−")
        return number.toFixed(places).replace("-", "−")
    }

    function signed(value, digits) {
        var number = num(value)
        return (number < 0 ? "− " : "+ ") + fmt(Math.abs(number), digits)
    }

    function sub(index) {
        var digits = "₀₁₂₃₄₅₆₇₈₉"
        var text = String(Math.max(0, Math.floor(Number(index) || 0)))
        var result = ""
        for (var i = 0; i < text.length; ++i)
            result += digits[Number(text[i])]
        return result
    }

    function maxAbsOf(values) {
        var result = 0
        var items = list(values)
        for (var index = 0; index < items.length; ++index) {
            var entry = items[index]
            if (entry && entry.length !== undefined) {
                result = Math.max(result, maxAbsOf(entry))
            } else if (isNum(entry)) {
                result = Math.max(result, Math.abs(Number(entry)))
            }
        }
        return result
    }

    function mixColor(a, b, f) {
        return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f,
                       a.b + (b.b - a.b) * f, a.a + (b.a - a.a) * f)
    }

    function divColor(value, maximum) {
        if (!isNum(value))
            return Style.Theme.error_fondo
        var f = clamp01(Math.abs(Number(value)) / Math.max(1e-9, maximum))
        var negative = Number(value) < 0
        var middle = negative ? Style.Theme.escala_div_neg1 : Style.Theme.escala_div_pos1
        var extreme = negative ? Style.Theme.escala_div_neg2 : Style.Theme.escala_div_pos2
        return f < 0.5 ? mixColor(Style.Theme.escala_div_cero, middle, f * 2)
                       : mixColor(middle, extreme, (f - 0.5) * 2)
    }

    function inkOn(fill) {
        var light = 0.299 * fill.r + 0.587 * fill.g + 0.114 * fill.b
        return light > 0.56 ? "#111827" : "#FFFFFF"
    }

    function headColor(index) {
        var colors = [Style.Theme.matriz_query, Style.Theme.matriz_key,
                      Style.Theme.matriz_value, Style.Theme.inferencia_transformacion,
                      Style.Theme.inferencia_foco, Style.Theme.inferencia_estructura,
                      Style.Theme.inferencia_contexto, Style.Theme.inferencia_error]
        return colors[Math.abs(Number(index) || 0) % colors.length]
    }

    function cellWidth(count, available, preferred) {
        var ideal = (preferred === undefined ? 60 : preferred) * root.u
        var fit = (available - 4 * root.u * count) / Math.max(1, count)
        return Math.max(26 * root.u, Math.min(ideal, fit))
    }

    // ------------------------------------------------- duración y fases
    function durationFor(kind) {
        switch (kind) {
        case "projection":
            return 6500 * Math.max(1, list(demo.outputs).length) + (list(demo.outputs).length > 1 ? -2500 : 0)
        case "sampling": return 5200 * Math.max(1, list(demo.stages).length)
        case "weighted_sum": return 9000
        case "softmax": return 8500
        case "layernorm": return 9000
        case "positional": return 9000
        case "activation": return 7500
        case "multi_softmax": return 7500
        case "mask_compare": return 7000
        case "causal_mask": return 7000
        default: return 6500
        }
    }

    function phasesFor(kind) {
        switch (kind) {
        case "split_text": return [["Leer texto", 0], ["Cortar en piezas", 0.3], ["Fijar posiciones", 0.82]]
        case "lookup_ids": return [["Buscar en vocabulario", 0], ["Sustituir por ID", 0.1], ["Tensor de IDs", 0.88]]
        case "specials": return [["Contenido", 0], ["Anteponer BOS", 0.1], ["Añadir EOS", 0.4], ["Entrada del decoder", 0.7]]
        case "padding": return demo.training
                             ? [["Filas reales", 0], ["Rellenar con PAD", 0.45], ["Matriz B×T", 0.88]]
                             : [["Secuencia completa", 0], ["Corte en Tmax", 0.35], ["Contexto final", 0.85]]
        case "mask_compare": return [["IDs", 0], ["Comparar con PAD", 0.1], ["Máscara", 0.88]]
        case "no_grad": return [["Forward", 0], ["Backward", 0.45], ["Bloqueo ∅", 0.82]]
        case "lookup_row": return [["Buscar fila", 0], ["Seleccionar", 0.4], ["Copiar vector", 0.55]]
        case "map": return [["Entrada", 0], ["Aplicar operación", 0.1], ["Salida", 0.92]]
        case "positional": return [["Frecuencia", 0], ["Ángulo", 0.05], ["sin / cos", 0.5], ["Vector PE", 0.95]]
        case "sum": return [["Primer vector", 0], ["Sumar el segundo", 0.35], ["Resultado", 0.68]]
        case "matrix_rows": return [["Tokens", 0], ["Filas de X", 0.05], ["Fila elegida", 0.8]]
        case "heatmaps": return [["W_Q", 0], ["W_K", 0.33], ["W_V", 0.63]]
        case "projection": return [["Multiplicar", 0], ["Sumar", 0.55], ["Resultado", 0.85]]
        case "mask_row": return [["Scores", 0], ["Revisar máscara", 0.1], ["Scores permitidos", 0.88]]
        case "softmax": return [["Scores", 0], ["Exponenciar", 0.25], ["Sumar", 0.5], ["Normalizar", 0.7]]
        case "weighted_sum": return [["Pesos", 0], ["Escalar Values", 0.05], ["Acumular", 0.3], ["Contexto", 0.88]]
        case "heads": return demo.mode === "split"
                          ? [["Vector d_model", 0], ["Cortar", 0.25], ["Una fila por cabeza", 0.55]]
                          : (demo.mode === "concat"
                             ? [["Cabezas", 0], ["Alinear", 0.3], ["Concatenar", 0.65]]
                             : [["Cabezas", 0], ["Concatenar", 0.25], ["Mezclar con Wᴼ", 0.62]])
        case "multi_softmax": return [["Scores por cabeza", 0], ["Softmax", 0.15], ["Foco de cada cabeza", 0.85]]
        case "layernorm": return [["Suma", 0], ["Media μ", 0.2], ["Centrar", 0.36], ["÷ σ", 0.56], ["γ y β", 0.76]]
        case "activation": return [["Preactivación", 0], ["Aplicar φ", 0.15], ["Salida", 0.88]]
        case "ffn": return [["Entrada", 0], ["W₁ expande", 0.18], ["φ recorta", 0.48], ["W₂ comprime", 0.7]]
        case "stack": return [["Capa 0", 0], ["Subir por capas", 0.12], ["Salida final", 0.88]]
        case "shift": return demo.training
                           ? [["Objetivo", 0], ["Desplazar + BOS", 0.25], ["Emparejar", 0.6]]
                           : [["Prefijo", 0], ["Siguiente posición", 0.6]]
        case "cross_entropy": return [["Logits", 0], ["Softmax", 0.28], ["Prob. objetivo", 0.55], ["−log p", 0.75]]
        case "sampling": {
            var stages = list(demo.stages)
            var names = { "temperature": "Temperatura", "top_k": "Top-K", "top_p": "Top-P" }
            var result = []
            for (var index = 0; index < stages.length; ++index)
                result.push([names[stages[index]] || stages[index], index / stages.length])
            return result.length ? result : [["Filtro", 0]]
        }
        case "argmax": return [["Recorrer p", 0], ["Comparar", 0.2], ["Ganador", 0.75]]
        case "append": return [["Prefijo", 0], ["Anexar ŷ", 0.2], ["Nueva iteración", 0.65]]
        case "backward": return [["Pérdida", 0], ["Propagar gradiente", 0.08], ["Normas", 0.55]]
        case "update": return [["θ", 0], ["−η·g", 0.1], ["θ′", 0.5]]
        case "vector": return [["Coordenadas", 0], ["Norma", 0.72]]
        case "causal_mask": return [["Fila i", 0], ["j ≤ i ?", 0.05], ["Triángulo", 0.86]]
        default: return [["Resultado", 0]]
        }
    }

    function componentFor(kind) {
        switch (kind) {
        case "split_text": return splitTextComponent
        case "lookup_ids": return lookupIdsComponent
        case "specials": return specialsComponent
        case "padding": return paddingComponent
        case "mask_compare": return maskCompareComponent
        case "no_grad": return noGradComponent
        case "lookup_row": return lookupRowComponent
        case "map": return mapComponent
        case "positional": return positionalComponent
        case "sum": return sumComponent
        case "matrix_rows": return matrixRowsComponent
        case "heatmaps": return heatmapsComponent
        case "projection": return projectionComponent
        case "mask_row": return maskRowComponent
        case "softmax": return softmaxComponent
        case "weighted_sum": return weightedSumComponent
        case "heads": return headsComponent
        case "multi_softmax": return multiSoftmaxComponent
        case "layernorm": return layerNormComponent
        case "activation": return activationComponent
        case "ffn": return ffnComponent
        case "stack": return stackComponent
        case "shift": return shiftComponent
        case "cross_entropy": return crossEntropyComponent
        case "sampling": return samplingComponent
        case "argmax": return argmaxComponent
        case "append": return appendComponent
        case "backward": return backwardComponent
        case "update": return updateComponent
        case "vector": return vectorComponent
        case "causal_mask": return causalMaskComponent
        default: return unavailableComponent
        }
    }

    // ---------------------------------------------------------- estructura
    ColumnLayout {
        anchors.fill: parent
        spacing: 6 * root.u

        RowLayout {
            Layout.fillWidth: true
            spacing: 10 * root.u

            Rectangle {
                Layout.preferredWidth: eyebrow.implicitWidth + 16 * root.u
                Layout.preferredHeight: 24 * root.u
                radius: height / 2
                color: Style.Theme.acento_fondo
                border.color: Style.Theme.acento
                Text {
                    id: eyebrow
                    anchors.centerIn: parent
                    text: "ƒ  FÓRMULA EN ACCIÓN"
                    color: Style.Theme.acento_texto
                    font.bold: true
                    font.letterSpacing: 0.5
                    font.pixelSize: Math.max(9, 10 * root.u)
                }
            }
            Item { Layout.fillWidth: true }
            BotonSecundario {
                objectName: "formulaAnimationReplay"
                Layout.preferredWidth: 38 * root.u
                Layout.preferredHeight: 30 * root.u
                sx: root.u; sy: root.u
                text: "↺"
                Accessible.name: "Repetir animación de la fórmula"
                onClicked: root.replay()
            }
            BotonSecundario {
                objectName: "formulaAnimationPlay"
                Layout.preferredWidth: 38 * root.u
                Layout.preferredHeight: 30 * root.u
                sx: root.u; sy: root.u
                text: root.running ? "Ⅱ" : "▶"
                Accessible.name: root.running ? "Pausar animación" : "Reproducir animación"
                onClicked: root.togglePlay()
            }
            BotonSecundario {
                objectName: "formulaAnimationSpeed"
                Layout.preferredWidth: 48 * root.u
                Layout.preferredHeight: 30 * root.u
                sx: root.u; sy: root.u
                text: (root.speed === 0.5 ? "½" : String(root.speed)) + "×"
                Accessible.name: "Velocidad de la animación"
                onClicked: root.cycleSpeed()
            }
        }

        Rectangle {
            objectName: "formulaAnimationFormulaCard"
            Layout.fillWidth: true
            implicitHeight: formulaText.implicitHeight + 24 * root.u
            radius: 11 * root.u
            color: Style.Theme.formula_fondo
            border.color: Style.Theme.formula_texto
            border.width: 2

            Text {
                id: formulaText
                objectName: "formulaAnimationFormula"
                anchors.fill: parent
                anchors.margins: 12 * root.u
                text: root.readableFormula()
                color: Style.Theme.formula_texto
                font.family: "Cambria Math"
                font.weight: Font.DemiBold
                font.pixelSize: root.formulaFontSize()
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
                lineHeight: 1.12
                Accessible.name: "Fórmula del paso"
                Accessible.description: String(root.formulaExplanation)
            }
        }

        Text {
            objectName: "formulaAnimationTitle"
            Layout.fillWidth: true
            visible: text.length > 0
            text: String(root.demo && root.demo.title || "")
            color: Style.Theme.texto_primario
            font.bold: true
            font.pixelSize: Math.max(13, 15 * root.u)
            wrapMode: Text.WordWrap
            maximumLineCount: 2
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10 * root.u
            color: Style.Theme.superficie_alterna
            border.color: Style.Theme.borde_suave
            clip: true

            Loader {
                id: kindLoader
                objectName: "formulaAnimationLoader"
                anchors.fill: parent
                anchors.margins: 10 * root.u
                sourceComponent: root.hasDemo ? root.componentFor(root.kind) : emptyComponent
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6 * root.u

            Repeater {
                model: root.phases
                delegate: Rectangle {
                    id: phaseChip
                    required property int index
                    required property var modelData
                    readonly property bool active: index === root.phaseIndex
                    readonly property bool done: index < root.phaseIndex
                    Layout.preferredHeight: 22 * root.u
                    Layout.preferredWidth: phaseText.implicitWidth + 18 * root.u
                    radius: height / 2
                    color: active ? Style.Theme.acento : (done ? Style.Theme.acento_fondo : Style.Theme.chip_fondo)
                    border.color: active || done ? Style.Theme.acento : Style.Theme.chip_borde
                    Text {
                        id: phaseText
                        anchors.centerIn: parent
                        text: (phaseChip.index + 1) + " · " + phaseChip.modelData[0]
                        color: phaseChip.active ? Style.Theme.texto_sobre_acento
                                                : (phaseChip.done ? Style.Theme.acento_texto : Style.Theme.chip_texto)
                        font.bold: phaseChip.active
                        font.pixelSize: Math.max(10, 11 * root.u)
                    }
                }
            }
            Slider {
                id: scrubber
                objectName: "formulaAnimationScrubber"
                Layout.fillWidth: true
                Layout.minimumWidth: 80 * root.u
                from: 0
                to: 1
                value: root.t
                onMoved: {
                    driver.stop()
                    root.t = value
                }
            }
        }

        Rectangle {
            objectName: "formulaAnimationExplanationPanel"
            Layout.fillWidth: true
            implicitHeight: explanationColumn.implicitHeight + 18 * root.u
            radius: 9 * root.u
            color: Style.Theme.surface
            border.color: root.explanationSection === 0
                          ? Style.Theme.formula_texto
                          : Style.Theme.inferencia_contexto

            ColumnLayout {
                id: explanationColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 9 * root.u
                spacing: 7 * root.u

                TabBar {
                    id: formulaExplanationTabs
                    objectName: "formulaAnimationExplanationTabs"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38 * root.u
                    currentIndex: root.explanationSection
                    spacing: 4 * root.u
                    onCurrentIndexChanged: root.explanationSection = currentIndex

                    background: Rectangle {
                        radius: 8 * root.u
                        color: Style.Theme.superficie_alterna
                        border.color: Style.Theme.borde_suave
                    }

                    PestanaAccesible {
                        text: "Qué se calcula"
                        font.pixelSize: Math.max(11, 12 * root.u)
                    }
                    PestanaAccesible {
                        text: "Cómo leer la animación"
                        font.pixelSize: Math.max(11, 12 * root.u)
                    }
                }

                Text {
                    objectName: "formulaAnimationExplanation"
                    visible: root.explanationSection === 0
                    Layout.fillWidth: true
                    text: root.formulaExplanation.length
                          ? root.formulaExplanation
                          : String(root.step && root.step.explanation || "La fórmula transforma la entrada del paso en su salida.")
                    color: Style.Theme.texto_primario
                    wrapMode: Text.WordWrap
                    lineHeight: 1.22
                    font.pixelSize: Math.max(13, 15 * root.u)
                }

                Text {
                    objectName: "formulaAnimationCaption"
                    visible: root.explanationSection === 1
                    Layout.fillWidth: true
                    text: {
                        var visual = root.animationDescription
                        var numeric = String(root.demo && root.demo.caption || "")
                        if (visual.length && numeric.length)
                            return visual + " " + numeric
                        return visual.length ? visual : numeric
                    }
                    color: Style.Theme.texto_primario
                    wrapMode: Text.WordWrap
                    lineHeight: 1.22
                    font.pixelSize: Math.max(13, 15 * root.u)
                }

                Rectangle {
                    objectName: "formulaAnimationResultCard"
                    Layout.fillWidth: true
                    implicitHeight: formulaResultText.implicitHeight + 16 * root.u
                    radius: 7 * root.u
                    color: Style.Theme.proceso_fondo
                    border.color: Style.Theme.inferencia_resultado

                    Text {
                        id: formulaResultText
                        objectName: "formulaAnimationResult"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8 * root.u
                        text: "RESULTADO CLAVE  ·  "
                              + String(root.step && root.step.output || "salida del paso")
                        color: Style.Theme.proceso_texto
                        font.bold: true
                        wrapMode: Text.WordWrap
                        lineHeight: 1.16
                        font.pixelSize: Math.max(11, 13 * root.u)
                    }
                }
            }
        }
    }

    // ---------------------------------------------------- piezas comunes
    component Cell: Rectangle {
        id: cell
        property var value: 0
        property real maxAbs: 1
        property string label: ""
        property bool emphasized: false
        property bool useFill: false
        property color fill: Style.Theme.chip_fondo
        property real reveal: 1
        property int digits: 3

        implicitWidth: 60 * root.u
        implicitHeight: 28 * root.u
        radius: 5 * root.u
        opacity: reveal
        color: useFill ? fill : root.divColor(value, maxAbs)
        border.color: emphasized ? Style.Theme.acento : Qt.alpha(Style.Theme.borde_medio, 0.7)
        border.width: emphasized ? 2 : 1
        Text {
            anchors.centerIn: parent
            width: parent.width - 4
            horizontalAlignment: Text.AlignHCenter
            text: cell.label.length ? cell.label : root.fmt(cell.value, cell.digits)
            color: root.inkOn(cell.color)
            font.family: Style.Theme.fuente_mono
            font.bold: cell.emphasized
            font.pixelSize: Math.max(10, Math.min(12 * root.u, cell.height * 0.48))
            elide: Text.ElideRight
        }
    }

    component Chip: Rectangle {
        id: chip
        property string label: ""
        property string caption: ""
        property color fill: Style.Theme.chip_fondo
        property color ink: Style.Theme.chip_texto
        property color edge: Style.Theme.chip_borde
        property real fontScale: 1

        implicitWidth: Math.max(40 * root.u, chipLabel.implicitWidth + 16 * root.u)
        implicitHeight: (caption.length ? 46 : 32) * root.u
        radius: 7 * root.u
        color: fill
        border.color: edge
        Column {
            anchors.centerIn: parent
            spacing: 0
            Text {
                id: chipLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: chip.label
                color: chip.ink
                font.family: Style.Theme.fuente_mono
                font.bold: true
                font.pixelSize: Math.max(11, 13 * root.u * chip.fontScale)
            }
            Text {
                visible: chip.caption.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: chip.caption
                color: chip.ink
                opacity: 0.8
                font.pixelSize: Math.max(9, 10.5 * root.u)
            }
        }
    }

    component FfnStrip: Item {
        id: strip
        property var values: []
        property real maxAbs: 1
        property real reveal: 1
        property string title: ""
        property color accent: Style.Theme.acento
        
        Text {
            anchors.right: parent.left
            anchors.rightMargin: 6 * root.u
            anchors.verticalCenter: parent.verticalCenter
            text: strip.title
            color: strip.accent
            font.bold: true
            font.pixelSize: Math.max(10, 12 * root.u)
        }
        Row {
            anchors.fill: parent
            spacing: 1
            Repeater {
                model: strip.values.length
                delegate: Rectangle {
                    required property int index
                    width: (strip.width - strip.values.length) / Math.max(1, strip.values.length)
                    height: strip.height
                    color: root.divColor(strip.values[index], strip.maxAbs)
                    opacity: root.clamp01(strip.reveal * strip.values.length - index)
                }
            }
        }
    }

    component Tag: Text {
        color: Style.Theme.texto_secundario_fuerte
        font.bold: true
        font.pixelSize: Math.max(10, 12 * root.u)
    }

    component Equation: Rectangle {
        id: equation
        property string text: ""
        property color accent: Style.Theme.acento
        property real reveal: 1
        implicitWidth: equationText.implicitWidth + 18 * root.u
        implicitHeight: 34 * root.u
        radius: 7 * root.u
        opacity: reveal
        color: Qt.alpha(accent, 0.12)
        border.color: accent
        Text {
            id: equationText
            anchors.centerIn: parent
            text: equation.text
            color: Style.Theme.texto_primario
            font.family: Style.Theme.fuente_mono
            font.bold: true
            font.pixelSize: Math.max(12, 13.5 * root.u)
        }
    }

    Component {
        id: emptyComponent
        Item {
            Text {
                anchors.centerIn: parent
                text: "Ejecuta el experimento para ver la fórmula con los números del modelo."
                color: Style.Theme.texto_secundario
                font.pixelSize: Math.max(11, 12 * root.u)
            }
        }
    }

    Component {
        id: unavailableComponent
        Item {
            Text {
                anchors.centerIn: parent
                width: parent.width - 20
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: String(root.demo && root.demo.caption || "Esta operación no tiene animación numérica.")
                color: Style.Theme.texto_secundario
                font.pixelSize: Math.max(11, 12 * root.u)
            }
        }
    }

    // ===================================================== MÓDULO 1
    Component {
        id: splitTextComponent
        Item {
            id: splitView
            readonly property var pieces: root.list(root.demo.pieces)
            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: 18 * root.u

                Rectangle {
                    id: textBox
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width, sourceText.implicitWidth + 40 * root.u)
                    height: 40 * root.u
                    radius: 8 * root.u
                    color: Style.Theme.surface
                    border.color: Style.Theme.inferencia_estructura
                    Text {
                        id: sourceText
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - 20 * root.u)
                        text: "«" + String(root.demo.text || "") + "»"
                        elide: Text.ElideRight
                        color: Style.Theme.texto_primario
                        font.pixelSize: Math.max(12, 15 * root.u)
                    }
                    Rectangle {
                        visible: root.seg(0, 0.35) > 0 && root.seg(0, 0.35) < 1
                        x: sourceText.x + sourceText.width * root.seg(0, 0.35)
                        y: 6 * root.u
                        width: 3 * root.u
                        height: parent.height - 12 * root.u
                        radius: 1
                        color: Style.Theme.inferencia_foco
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "↓  tokenizador"
                    color: Style.Theme.texto_terciario
                    opacity: root.seg(0.2, 0.32)
                    font.pixelSize: Math.max(10, 11 * root.u)
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    scale: Math.min(1, parent.width / Math.max(1, implicitWidth))
                    spacing: 8 * root.u
                    Repeater {
                        model: splitView.pieces
                        delegate: Item {
                            id: pieceItem
                            required property int index
                            required property var modelData
                            readonly property real start: 0.3 + 0.5 * index / Math.max(1, splitView.pieces.length)
                            readonly property real p: root.ease(root.seg(start, start + 0.12))
                            width: pieceChip.width
                            height: pieceChip.height + 18 * root.u
                            opacity: p
                            Chip {
                                id: pieceChip
                                y: (1 - pieceItem.p) * -28 * root.u
                                label: String(pieceItem.modelData.text)
                                fill: Qt.alpha(Style.Theme.inferencia_estructura, 0.15)
                                edge: Style.Theme.inferencia_estructura
                                ink: Style.Theme.texto_primario
                            }
                            Text {
                                anchors.horizontalCenter: pieceChip.horizontalCenter
                                y: pieceChip.height + 2 * root.u
                                visible: Boolean(root.demo.show_positions)
                                opacity: root.seg(0.82 + 0.1 * pieceItem.index / Math.max(1, splitView.pieces.length), 0.95)
                                text: "t" + root.sub(pieceItem.index)
                                color: Style.Theme.inferencia_foco
                                font.bold: true
                                font.pixelSize: Math.max(10, 12 * root.u)
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: root.seg(0.85, 1)
                    text: splitView.pieces.length + " tokens en orden"
                    color: Style.Theme.inferencia_resultado
                    font.bold: true
                    font.pixelSize: Math.max(10, 12 * root.u)
                }
            }
        }
    }

    Component {
        id: lookupIdsComponent
        Item {
            id: idsView
            readonly property var pieces: root.list(root.demo.pieces)
            function flip(index) {
                var start = 0.1 + 0.75 * index / Math.max(1, pieces.length)
                return root.seg(start, start + 0.75 / Math.max(1, pieces.length))
            }
            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: 14 * root.u

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: vocabText.implicitWidth + 24 * root.u
                    height: 28 * root.u
                    radius: height / 2
                    color: Style.Theme.info_fondo
                    border.color: Style.Theme.inferencia_estructura
                    border.width: root.t > 0.1 && root.t < 0.86 ? 2 + Math.round(Math.abs(Math.sin(root.t * 40))) : 1
                    Text {
                        id: vocabText
                        anchors.centerIn: parent
                        text: "Vocabulario · " + root.num(root.demo.vocabulary) + " filas"
                        color: Style.Theme.info_texto
                        font.bold: true
                        font.pixelSize: Math.max(10, 11 * root.u)
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    scale: Math.min(1, parent.width / Math.max(1, implicitWidth))
                    spacing: 8 * root.u
                    Repeater {
                        model: idsView.pieces
                        delegate: Chip {
                            id: idChip
                            required property int index
                            required property var modelData
                            readonly property real p: idsView.flip(index)
                            label: p < 0.5 ? String(modelData.text) : String(modelData.id)
                            caption: p < 0.5 ? "token" : "ID"
                            fill: p < 0.5 ? Style.Theme.chip_fondo : Style.Theme.inferencia_estructura
                            ink: p < 0.5 ? Style.Theme.chip_texto : Style.Theme.inferencia_sobre_estructura
                            edge: p > 0 && p < 1 ? Style.Theme.inferencia_foco : Style.Theme.chip_borde
                            implicitWidth: Math.max(56 * root.u, labelProbe.implicitWidth + 18 * root.u)
                            transform: Scale {
                                origin.x: idChip.width / 2
                                origin.y: idChip.height / 2
                                yScale: Math.max(0.05, Math.abs(Math.cos(Math.PI * idChip.p)))
                            }
                            Text { id: labelProbe; visible: false; text: String(idChip.modelData.text); font.pixelSize: Math.max(9, 11 * root.u); font.family: Style.Theme.fuente_mono; font.bold: true }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        var parts = []
                        for (var i = 0; i < idsView.pieces.length; ++i)
                            parts.push(idsView.flip(i) >= 0.5 ? String(idsView.pieces[i].id) : "·")
                        return "ids = [" + parts.join(", ") + "]"
                    }
                    color: Style.Theme.inferencia_resultado
                    font.family: Style.Theme.fuente_mono
                    font.bold: true
                    font.pixelSize: Math.max(11, 13 * root.u)
                }
            }
        }
    }

    Component {
        id: specialsComponent
        Item {
            id: specialsView
            readonly property var content: root.list(root.demo.content)
            readonly property var decoder: root.list(root.demo.decoder)
            Column {
                anchors.centerIn: parent
                spacing: 14 * root.u
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6 * root.u
                    Chip {
                        label: "BOS"
                        caption: String(root.demo.bos ? root.demo.bos.id : "")
                        fill: Style.Theme.inferencia_resultado
                        ink: Style.Theme.inferencia_sobre_resultado
                        edge: Style.Theme.inferencia_resultado
                        opacity: root.seg(0.1, 0.3)
                        transform: Translate { x: (1 - root.ease(root.seg(0.1, 0.38))) * -70 * root.u }
                    }
                    Repeater {
                        model: specialsView.content
                        delegate: Chip {
                            required property var modelData
                            label: String(modelData.text)
                            caption: String(modelData.id)
                        }
                    }
                    Chip {
                        visible: Boolean(root.demo.eos)
                        label: "EOS"
                        caption: String(root.demo.eos ? root.demo.eos.id : "")
                        fill: Style.Theme.inferencia_error
                        ink: Style.Theme.inferencia_sobre_error
                        edge: Style.Theme.inferencia_error
                        opacity: root.seg(0.4, 0.6)
                        transform: Translate { x: (1 - root.ease(root.seg(0.4, 0.68))) * 70 * root.u }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: root.seg(0.7, 0.8)
                    text: "↓ el decoder recibe la secuencia desplazada a la derecha (el último token se predice, no se lee)"
                    color: Style.Theme.texto_terciario
                    font.pixelSize: Math.max(9, 10 * root.u)
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6 * root.u
                    Tag { anchors.verticalCenter: parent.verticalCenter; text: "decoder:"; opacity: root.seg(0.72, 0.8) }
                    Repeater {
                        model: specialsView.decoder
                        delegate: Chip {
                            required property int index
                            required property var modelData
                            label: String(modelData.text)
                            caption: String(modelData.id)
                            fill: Style.Theme.acento_fondo
                            ink: Style.Theme.acento_texto
                            edge: Style.Theme.acento
                            opacity: root.seg(0.74 + 0.2 * index / Math.max(1, specialsView.decoder.length), 0.98)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: paddingComponent
        Item {
            id: paddingView
            readonly property var rows: root.list(root.demo.rows)
            readonly property bool training: Boolean(root.demo.training)
            readonly property int columns: rows.length ? root.list(rows[0]).length : 0
            readonly property int limit: Number(root.demo.limit || columns)
            readonly property real cw: root.cellWidth(Math.max(1, columns), width - 120 * root.u, 58)
            readonly property real stride: cw + 4 * root.u
            Column {
                anchors.centerIn: parent
                spacing: 10 * root.u
                Repeater {
                    model: paddingView.rows
                    delegate: Row {
                        id: padRow
                        required property int index
                        required property var modelData
                        readonly property int length: paddingView.training ? Number(root.list(root.demo.lengths)[index] || 0) : root.list(modelData).length
                        spacing: 8 * root.u
                        Tag {
                            width: 96 * root.u
                            anchors.verticalCenter: parent.verticalCenter
                            text: paddingView.training ? "fila " + (padRow.index + 1) + " · long. " + padRow.length
                                                       : "ids (" + padRow.length + ")"
                        }
                        Item {
                            width: paddingView.columns * paddingView.stride
                            height: 34 * root.u
                            Repeater {
                                model: root.list(padRow.modelData)
                                delegate: Rectangle {
                                    id: padCell
                                    required property int index
                                    required property var modelData
                                    readonly property bool isPad: paddingView.training && index >= padRow.length
                                    readonly property bool cut: !paddingView.training && index >= paddingView.limit
                                    readonly property real appear: isPad
                                        ? root.seg(0.45 + 0.35 * (index - padRow.length) / Math.max(1, paddingView.columns - padRow.length), 0.86)
                                        : root.seg(0.05 + 0.3 * index / Math.max(1, paddingView.columns), 0.4)
                                    x: index * paddingView.stride
                                    width: paddingView.cw
                                    height: parent.height
                                    radius: 5 * root.u
                                    opacity: appear * (cut ? 1 - 0.7 * root.seg(0.55, 0.85) : 1)
                                    color: isPad ? Style.Theme.aviso_fondo : (cut ? Style.Theme.error_fondo : Style.Theme.info_fondo)
                                    border.color: isPad ? Style.Theme.warning : (cut ? Style.Theme.inferencia_error : Style.Theme.inferencia_estructura)
                                    Column {
                                        anchors.centerIn: parent
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: padCell.isPad ? "PAD" : String(padCell.modelData.text)
                                            width: paddingView.cw - 4
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                            color: Style.Theme.texto_primario
                                            font.bold: padCell.isPad
                                            font.pixelSize: Math.max(8, 9.5 * root.u)
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: String(padCell.modelData.id)
                                            color: Style.Theme.texto_terciario
                                            font.family: Style.Theme.fuente_mono
                                            font.pixelSize: Math.max(8, 8.5 * root.u)
                                        }
                                    }
                                    Rectangle {
                                        visible: padCell.cut
                                        anchors.centerIn: parent
                                        width: parent.width * root.seg(0.55, 0.8)
                                        height: 2
                                        color: Style.Theme.inferencia_error
                                    }
                                }
                            }
                            Rectangle {
                                visible: !paddingView.training && paddingView.limit < paddingView.columns
                                x: paddingView.limit * paddingView.stride - 3 * root.u
                                y: -6 * root.u
                                width: 3 * root.u
                                height: parent.height + 12 * root.u
                                color: Style.Theme.inferencia_error
                                opacity: root.seg(0.35, 0.5)
                            }
                        }
                    }
                }
                Equation {
                    anchors.horizontalCenter: parent.horizontalCenter
                    reveal: root.seg(0.86, 1)
                    accent: Style.Theme.inferencia_resultado
                    text: paddingView.training
                          ? "B × T = " + paddingView.rows.length + " × " + paddingView.columns + "   (PAD id = " + root.demo.pad_id + ")"
                          : (paddingView.limit < paddingView.columns
                             ? "se conservan " + paddingView.limit + " de " + paddingView.columns + " tokens (Tmax = " + paddingView.limit + ")"
                             : paddingView.columns + " ≤ Tmax = " + paddingView.limit + ": no se recorta nada")
                }
            }
        }
    }

    Component {
        id: maskCompareComponent
        Item {
            id: maskView
            readonly property var rows: root.list(root.demo.rows)
            readonly property var mask: root.list(root.demo.mask)
            readonly property int columns: rows.length ? root.list(rows[0]).length : 0
            readonly property int total: rows.length * columns
            readonly property real scan: root.seg(0.1, 0.88) * total
            readonly property int current: Math.min(total - 1, Math.floor(scan))
            readonly property real cw: root.cellWidth(Math.max(1, columns), width * 0.62, 54)
            RowLayout {
                anchors.fill: parent
                spacing: 16 * root.u
                Column {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 6 * root.u
                    Repeater {
                        model: maskView.rows
                        delegate: Column {
                            id: maskRow
                            required property int index
                            required property var modelData
                            spacing: 3 * root.u
                            Row {
                                spacing: 4 * root.u
                                Tag { width: 52 * root.u; text: "ids"; anchors.verticalCenter: parent.verticalCenter }
                                Repeater {
                                    model: root.list(maskRow.modelData)
                                    delegate: Cell {
                                        required property int index
                                        required property var modelData
                                        width: maskView.cw
                                        useFill: true
                                        fill: Style.Theme.chip_fondo
                                        label: String(modelData.id)
                                        emphasized: maskRow.index * maskView.columns + index === maskView.current && root.t < 0.9
                                    }
                                }
                            }
                            Row {
                                spacing: 4 * root.u
                                Tag { width: 52 * root.u; text: "M"; anchors.verticalCenter: parent.verticalCenter; color: Style.Theme.inferencia_resultado }
                                Repeater {
                                    model: root.list(maskRow.modelData)
                                    delegate: Cell {
                                        id: maskCell
                                        required property int index
                                        readonly property bool keep: Boolean(root.list(maskView.mask[maskRow.index])[index])
                                        width: maskView.cw
                                        useFill: true
                                        fill: keep ? Style.Theme.exito_fondo : Style.Theme.error_fondo
                                        label: keep ? "1" : "0"
                                        reveal: root.clamp01(maskView.scan - (maskRow.index * maskView.columns + index))
                                    }
                                }
                            }
                        }
                    }
                }
                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 8 * root.u
                    Equation {
                        readonly property int r: Math.floor(Math.max(0, maskView.current) / Math.max(1, maskView.columns))
                        readonly property int c: Math.max(0, maskView.current) % Math.max(1, maskView.columns)
                        readonly property var entry: maskView.rows.length ? root.list(maskView.rows[r])[c] : null
                        readonly property bool keep: maskView.mask.length ? Boolean(root.list(maskView.mask[r])[c]) : true
                        accent: keep ? Style.Theme.inferencia_resultado : Style.Theme.inferencia_error
                        text: entry ? (entry.id + (keep ? " ≠ " : " = ") + "PAD(" + root.demo.pad_id + ")  →  " + (keep ? "1 visible" : "0 bloqueado")) : ""
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        opacity: root.seg(0.88, 1)
                        text: "Los ceros se convierten en −∞ antes de Softmax: ninguna query podrá atender al relleno."
                        color: Style.Theme.texto_secundario_fuerte
                        font.pixelSize: Math.max(10, 11 * root.u)
                    }
                }
            }
        }
    }

    Component {
        id: noGradComponent
        Item {
            id: gradView
            readonly property var names: ["Texto", "Tokenizador", "IDs", "Embedding", "Transformer", "Pérdida L"]
            readonly property real nodeW: Math.min(130 * root.u, (width - 5 * 18 * root.u) / 6)
            readonly property real gap: (width - 6 * nodeW) / 5
            function center(index) { return index * (nodeW + gap) + nodeW / 2 }
            readonly property real forward: root.seg(0.02, 0.42)
            readonly property real backward: root.seg(0.46, 0.8)
            Item {
                anchors.centerIn: parent
                width: parent.width
                height: 150 * root.u
                Repeater {
                    model: gradView.names
                    delegate: Rectangle {
                        id: gradNode
                        required property int index
                        required property var modelData
                        readonly property bool reachedForward: gradView.forward * 5 >= index
                        readonly property bool reachedBackward: index >= 3 && gradView.backward * 2 >= 5 - index
                        x: index * (gradView.nodeW + gradView.gap)
                        y: 30 * root.u
                        width: gradView.nodeW
                        height: 50 * root.u
                        radius: 9 * root.u
                        color: reachedBackward ? Style.Theme.error_fondo : (reachedForward ? Style.Theme.info_fondo : Style.Theme.surface)
                        border.color: reachedBackward ? Style.Theme.inferencia_error : (index < 3 ? Style.Theme.borde_medio : Style.Theme.inferencia_estructura)
                        border.width: reachedBackward ? 2 : 1
                        Column {
                            anchors.centerIn: parent
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: String(gradNode.modelData)
                                color: Style.Theme.texto_primario
                                font.bold: true
                                font.pixelSize: Math.max(9, 11 * root.u)
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: gradNode.index === 5 && root.isNum(root.demo.loss) ? "L = " + root.fmt(root.demo.loss, 4)
                                      : (gradNode.index < 3 ? "sin parámetros" : (gradNode.reachedBackward ? "recibe ∂L ✓" : "entrenable"))
                                color: gradNode.reachedBackward ? Style.Theme.error_texto : Style.Theme.texto_terciario
                                font.pixelSize: Math.max(8, 9 * root.u)
                            }
                        }
                    }
                }
                Rectangle {
                    visible: gradView.forward > 0 && gradView.forward < 1
                    x: gradView.center(0) + (gradView.center(5) - gradView.center(0)) * gradView.forward - width / 2
                    y: 14 * root.u
                    width: 14 * root.u
                    height: width
                    radius: width / 2
                    color: Style.Theme.inferencia_estructura
                }
                Text {
                    x: gradView.center(0)
                    y: 0
                    opacity: root.seg(0.02, 0.1) * (1 - root.seg(0.42, 0.46))
                    text: "forward →"
                    color: Style.Theme.inferencia_estructura
                    font.bold: true
                    font.pixelSize: Math.max(9, 10 * root.u)
                }
                Rectangle {
                    visible: gradView.backward > 0 && gradView.backward < 1
                    x: gradView.center(5) - (gradView.center(5) - gradView.center(2) - gradView.nodeW * 0.6) * gradView.backward - width / 2
                    y: 92 * root.u
                    width: 14 * root.u
                    height: width
                    radius: width / 2
                    color: Style.Theme.inferencia_error
                }
                Text {
                    x: gradView.center(4)
                    y: 112 * root.u
                    opacity: root.seg(0.46, 0.52)
                    text: "← ∂L"
                    color: Style.Theme.inferencia_error
                    font.bold: true
                    font.pixelSize: Math.max(9, 10 * root.u)
                }
                Rectangle {
                    x: gradView.center(2) + gradView.nodeW / 2 + gradView.gap / 2 - width / 2
                    y: 20 * root.u
                    width: 6 * root.u
                    height: 100 * root.u
                    radius: 3 * root.u
                    color: Style.Theme.inferencia_error
                    opacity: root.seg(0.8, 0.88)
                    Rectangle {
                        anchors.top: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 4 * root.u
                        width: blockText.implicitWidth + 14 * root.u
                        height: 22 * root.u
                        radius: 6 * root.u
                        color: Style.Theme.error_fondo
                        border.color: Style.Theme.inferencia_error
                        Text {
                            id: blockText
                            anchors.centerIn: parent
                            text: "∅  los IDs son enteros: no hay derivada"
                            color: Style.Theme.error_texto
                            font.bold: true
                            font.pixelSize: Math.max(9, 10 * root.u)
                        }
                    }
                }
            }
        }
    }

    // ===================================================== MÓDULO 2
    Component {
        id: lookupRowComponent
        Item {
            id: rowView
            readonly property var rows: root.list(root.demo.rows)
            readonly property int selected: {
                for (var i = 0; i < rows.length; ++i)
                    if (rows[i].selected)
                        return i
                return 0
            }
            readonly property real rowH: 26 * root.u
            readonly property real maxAbs: Math.max(root.maxAbsOf(root.demo.vector), 1e-6)
            RowLayout {
                anchors.fill: parent
                spacing: 18 * root.u
                Item {
                    Layout.preferredWidth: 6 * 52 * root.u + 120 * root.u
                    Layout.fillHeight: true
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 22 * root.u
                        spacing: 4 * root.u
                        Tag { text: "Tabla E  (" + root.num(root.demo.vocabulary) + " × " + root.num(root.demo.size) + ")" }
                        Repeater {
                            model: rowView.rows
                            delegate: Row {
                                id: tableRow
                                required property int index
                                required property var modelData
                                readonly property bool chosen: Boolean(modelData.selected) && root.t >= 0.4
                                spacing: 3 * root.u
                                opacity: chosen || root.t < 0.4 ? 1 : 0.45
                                Rectangle {
                                    width: 48 * root.u
                                    height: rowView.rowH
                                    radius: 5 * root.u
                                    color: tableRow.chosen ? Style.Theme.inferencia_foco : Style.Theme.chip_fondo
                                    Text {
                                        anchors.centerIn: parent
                                        text: "id " + tableRow.modelData.id
                                        color: tableRow.chosen ? Style.Theme.inferencia_sobre_foco : Style.Theme.chip_texto
                                        font.family: Style.Theme.fuente_mono
                                        font.bold: tableRow.chosen
                                        font.pixelSize: Math.max(8, 9.5 * root.u)
                                    }
                                }
                                Repeater {
                                    model: root.list(tableRow.modelData.values)
                                    delegate: Cell {
                                        required property var modelData
                                        width: 50 * root.u
                                        height: rowView.rowH
                                        value: modelData
                                        maxAbs: rowView.maxAbs
                                        emphasized: tableRow.chosen
                                    }
                                }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: "…"; color: Style.Theme.texto_terciario }
                            }
                        }
                    }
                    Text {
                        x: 4 * root.u
                        y: parent.height / 2 - (rowView.rows.length * (rowView.rowH + 4 * root.u)) / 2 + 18 * root.u
                           + rowView.selected * (rowView.rowH + 4 * root.u) * root.ease(root.seg(0.05, 0.38))
                        text: "▶"
                        color: Style.Theme.inferencia_foco
                        font.pixelSize: Math.max(12, 14 * root.u)
                    }
                }
                Text {
                    text: "→"
                    opacity: root.seg(0.45, 0.55)
                    color: Style.Theme.inferencia_foco
                    font.pixelSize: Math.max(18, 26 * root.u)
                    font.bold: true
                }
                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 6 * root.u
                    Tag {
                        text: "e = E[" + root.demo.token_id + "]  («" + root.demo.token + "») · primeras " + root.list(root.demo.vector).length + " de " + root.num(root.demo.size)
                        opacity: root.seg(0.5, 0.6)
                    }
                    Row {
                        spacing: 4 * root.u
                        Repeater {
                            model: root.list(root.demo.vector)
                            delegate: Cell {
                                id: vectorEntry
                                required property int index
                                required property var modelData
                                width: 62 * root.u
                                height: 30 * root.u
                                value: modelData
                                maxAbs: rowView.maxAbs
                                reveal: root.seg(0.55 + 0.35 * index / Math.max(1, root.list(root.demo.vector).length), 0.95)
                                transform: Translate { x: (1 - vectorEntry.reveal) * -40 * root.u }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: mapComponent
        Item {
            id: mapView
            readonly property var inputs: root.list(root.demo.inputs)
            readonly property var outputs: root.list(root.demo.outputs)
            readonly property var labels: root.list(root.demo.labels)
            readonly property var dropped: root.list(root.demo.dropped)
            readonly property int count: inputs.length
            readonly property real cw: root.cellWidth(count, width - 140 * root.u, 70)
            readonly property real maxAbs: Math.max(root.maxAbsOf(inputs), root.maxAbsOf(outputs), 1e-6)
            readonly property real topY: labels.length ? 18 * root.u : 0
            readonly property real bottomY: Math.max(110 * root.u, height - 70 * root.u)
            function local(index) {
                var start = 0.1 + 0.8 * index / Math.max(1, count)
                return root.seg(start, start + 0.8 / Math.max(1, count))
            }
            readonly property int active: Math.min(count - 1, Math.floor(root.seg(0.1, 0.9) * count))
            function opText() {
                var op = String(root.demo.operator || "×")
                return op + " " + root.fmt(root.demo.operand, 4)
            }

            Column {
                x: 0
                y: mapView.topY
                spacing: mapView.bottomY - 24 * root.u - 30 * root.u
                Tag { text: String(root.demo.input_label || "entrada"); height: 24 * root.u; verticalAlignment: Text.AlignVCenter; color: Style.Theme.inferencia_estructura }
                Tag { text: String(root.demo.output_label || "salida"); height: 24 * root.u; verticalAlignment: Text.AlignVCenter; color: Style.Theme.inferencia_resultado }
            }
            Rectangle {
                x: 120 * root.u
                y: mapView.topY + (mapView.bottomY - mapView.topY) / 2
                width: mapView.count * (mapView.cw + 4 * root.u)
                height: 26 * root.u
                radius: 13 * root.u
                color: Qt.alpha(Style.Theme.inferencia_transformacion, 0.12)
                border.color: Style.Theme.inferencia_transformacion
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10 * root.u
                    anchors.verticalCenter: parent.verticalCenter
                    text: mapView.opText()
                    color: Style.Theme.inferencia_transformacion
                    font.family: Style.Theme.fuente_mono
                    font.bold: true
                    font.pixelSize: Math.max(10, 12 * root.u)
                }
            }
            Repeater {
                model: mapView.inputs
                delegate: Item {
                    id: column
                    required property int index
                    required property var modelData
                    readonly property real p: mapView.local(index)
                    readonly property bool isDropped: Boolean(mapView.dropped[index])
                    x: 120 * root.u + index * (mapView.cw + 4 * root.u)
                    width: mapView.cw
                    height: mapView.bottomY + 30 * root.u
                    Text {
                        visible: mapView.labels.length > 0
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: String(mapView.labels[column.index] || "")
                        elide: Text.ElideRight
                        color: Style.Theme.texto_terciario
                        font.pixelSize: Math.max(8, 9 * root.u)
                    }
                    Cell {
                        y: mapView.topY
                        width: parent.width
                        value: column.modelData
                        maxAbs: mapView.maxAbs
                        emphasized: column.index === mapView.active && root.t < 0.92
                    }
                    Rectangle {
                        visible: column.p > 0 && column.p < 0.75
                        width: 12 * root.u
                        height: 12 * root.u
                        radius: 6 * root.u
                        x: parent.width / 2 - width / 2
                        y: mapView.topY + 24 * root.u + (mapView.bottomY - mapView.topY - 36 * root.u) * root.ease(column.p / 0.75)
                        color: Style.Theme.inferencia_transformacion
                    }
                    Cell {
                        y: mapView.bottomY
                        width: parent.width
                        value: mapView.outputs[column.index]
                        maxAbs: mapView.maxAbs
                        reveal: root.segOf(column.p, 0.6, 1)
                        useFill: column.isDropped
                        fill: Style.Theme.error_fondo
                        label: column.isDropped ? "0 ✕" : ""
                    }
                }
            }
            Equation {
                x: 120 * root.u
                y: mapView.bottomY + 34 * root.u
                visible: mapView.count > 0
                accent: Style.Theme.inferencia_transformacion
                text: {
                    var index = Math.max(0, mapView.active)
                    var label = mapView.labels.length ? "«" + mapView.labels[index] + "»  " : "[" + index + "]  "
                    if (mapView.dropped[index])
                        return label + root.fmt(mapView.inputs[index], 4) + "  →  apagado por dropout  →  0"
                    return label + root.fmt(mapView.inputs[index], 4) + "  " + mapView.opText()
                            + "  =  " + root.fmt(mapView.outputs[index], 4)
                }
            }
            Text {
                anchors.right: parent.right
                y: mapView.bottomY + 40 * root.u
                visible: Number(root.demo.size || 0) > mapView.count
                text: "se muestran " + mapView.count + " de " + root.demo.size + " coordenadas"
                color: Style.Theme.texto_terciario
                font.pixelSize: Math.max(9, 10 * root.u)
            }
        }
    }

    Component {
        id: positionalComponent
        Item {
            id: peView
            readonly property var dims: root.list(root.demo.dims)
            readonly property int active: Math.min(dims.length - 1, Math.floor(root.seg(0.05, 0.95) * dims.length))
            readonly property var current: dims.length ? dims[Math.max(0, active)] : ({})
            readonly property real within: root.seg(0.05, 0.95) * dims.length - active
            onActiveChanged: wave.requestPaint()
            onWithinChanged: wave.requestPaint()
            RowLayout {
                anchors.fill: parent
                spacing: 14 * root.u
                Canvas {
                    id: wave
                    Layout.preferredWidth: parent.width * 0.38
                    Layout.fillHeight: true
                    property color lineColor: Style.Theme.inferencia_estructura
                    property color axisColor: Style.Theme.borde_medio
                    property color pointColor: Style.Theme.inferencia_foco
                    property color inkColor: Style.Theme.texto_secundario_fuerte
                    onLineColorChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var w = width, h = height
                        var item = peView.current
                        if (!item || item.angle === undefined) return
                        var angle = root.num(item.angle)
                        var span = Math.max(2 * Math.PI, angle * 1.25 + 0.5)
                        var mid = h / 2
                        var amp = h * 0.36
                        ctx.strokeStyle = axisColor
                        ctx.lineWidth = 1
                        ctx.beginPath(); ctx.moveTo(0, mid); ctx.lineTo(w, mid); ctx.stroke()
                        ctx.strokeStyle = lineColor
                        ctx.lineWidth = 2
                        ctx.beginPath()
                        var isSin = item["function"] === "sin"
                        for (var px = 0; px <= w; px += 2) {
                            var a = px / w * span
                            var v = isSin ? Math.sin(a) : Math.cos(a)
                            if (px === 0) ctx.moveTo(px, mid - v * amp)
                            else ctx.lineTo(px, mid - v * amp)
                        }
                        ctx.stroke()
                        var f = root.ease(root.clamp01(peView.within / 0.6))
                        var shown = angle * f
                        var x = shown / span * w
                        var value = isSin ? Math.sin(shown) : Math.cos(shown)
                        ctx.setLineDash([4, 3])
                        ctx.strokeStyle = pointColor
                        ctx.lineWidth = 1
                        ctx.beginPath(); ctx.moveTo(x, mid); ctx.lineTo(x, mid - value * amp); ctx.stroke()
                        ctx.setLineDash([])
                        ctx.fillStyle = pointColor
                        ctx.beginPath(); ctx.arc(x, mid - value * amp, 6, 0, 2 * Math.PI); ctx.fill()
                        ctx.fillStyle = inkColor
                        ctx.font = "bold " + Math.round(11 * root.u) + "px sans-serif"
                        ctx.fillText(item["function"] + "(θ)  ·  dim " + item.column, 6, 14)
                        ctx.fillText("θ = " + root.fmt(shown, 4), 6, h - 6)
                    }
                }
                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3 * root.u
                    Tag { text: "pos = " + root.demo.position + "  («" + root.demo.token + "»)   ·   d = " + root.demo.size }
                    Repeater {
                        model: peView.dims
                        delegate: Rectangle {
                            id: peRow
                            required property int index
                            required property var modelData
                            readonly property bool isActive: index === peView.active && root.t < 0.95
                            readonly property real reveal: index < peView.active ? 1 : (index === peView.active ? root.clamp01(peView.within / 0.6) : 0)
                            width: parent.width
                            height: 21 * root.u
                            radius: 4 * root.u
                            color: isActive ? Qt.alpha(Style.Theme.inferencia_foco, 0.16) : "transparent"
                            opacity: 0.35 + 0.65 * (index <= peView.active ? 1 : 0)
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 6 * root.u
                                text: "PE[" + peRow.modelData.column + "] = " + peRow.modelData["function"]
                                      + "(" + root.demo.position + " / 10000^" + root.fmt(peRow.modelData.exponent, 3)
                                      + ") = " + peRow.modelData["function"] + "(" + root.fmt(peRow.modelData.angle, 4) + ")"
                                      + (peRow.reveal >= 0.99 ? "  =  " + root.fmt(peRow.modelData.value, 4) : "")
                                color: Style.Theme.texto_primario
                                font.family: Style.Theme.fuente_mono
                                font.bold: peRow.isActive
                                font.pixelSize: Math.max(9, 10.5 * root.u)
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: sumComponent
        Item {
            id: sumView
            readonly property var a: root.list(root.demo.a)
            readonly property var b: root.list(root.demo.b)
            readonly property var c: root.list(root.demo.c)
            readonly property int count: c.length
            readonly property real growA: root.ease(root.seg(0.05, 0.33))
            readonly property real growB: root.ease(root.seg(0.36, 0.66))
            readonly property real result: root.seg(0.68, 0.9)
            readonly property real valueScale: {
                var m = 1e-6
                for (var i = 0; i < count; ++i)
                    m = Math.max(m, Math.abs(root.num(a[i])), Math.abs(root.num(c[i])),
                                 Math.abs(root.num(a[i])) + Math.abs(root.num(b[i])))
                return m
            }
            readonly property real chartH: Math.max(70 * root.u, height - 96 * root.u)
            readonly property real cw: root.cellWidth(count, width - 140 * root.u, 74)
            readonly property real k: chartH / 2 / valueScale
            Column {
                x: 0
                y: 4 * root.u
                spacing: 6 * root.u
                Repeater {
                    model: [[root.demo.a_label, Style.Theme.inferencia_estructura],
                            [root.demo.b_label, Style.Theme.inferencia_foco],
                            [root.demo.c_label, Style.Theme.inferencia_resultado]]
                    delegate: Row {
                        id: legendRow
                        required property var modelData
                        spacing: 5 * root.u
                        Rectangle { width: 12 * root.u; height: 12 * root.u; radius: 3; color: legendRow.modelData[1]; anchors.verticalCenter: parent.verticalCenter }
                        Tag { text: String(legendRow.modelData[0]) }
                    }
                }
            }
            Rectangle {
                x: 120 * root.u
                y: sumView.chartH / 2
                width: sumView.count * (sumView.cw + 4 * root.u)
                height: 1
                color: Style.Theme.borde_medio
            }
            Repeater {
                model: sumView.count
                delegate: Item {
                    id: sumColumn
                    required property int index
                    readonly property real va: root.num(sumView.a[index])
                    readonly property real vb: root.num(sumView.b[index])
                    readonly property real vc: root.num(sumView.c[index])
                    readonly property real base: sumView.chartH / 2
                    x: 120 * root.u + index * (sumView.cw + 4 * root.u)
                    width: sumView.cw
                    height: parent.height
                    Rectangle {
                        readonly property real v: sumColumn.va * sumView.growA
                        x: parent.width * 0.18
                        width: parent.width * 0.64
                        y: sumColumn.base - Math.max(0, v) * sumView.k
                        height: Math.abs(v) * sumView.k
                        color: Style.Theme.inferencia_estructura
                        opacity: 1 - 0.55 * sumView.result
                        radius: 2
                    }
                    Rectangle {
                        readonly property real start: sumColumn.va
                        readonly property real v: sumColumn.vb * sumView.growB
                        x: parent.width * 0.18
                        width: parent.width * 0.64
                        y: sumColumn.base - Math.max(start, start + v) * sumView.k
                        height: Math.abs(v) * sumView.k
                        color: Style.Theme.inferencia_foco
                        opacity: (sumView.growB > 0 ? 0.9 : 0) * (1 - 0.55 * sumView.result)
                        radius: 2
                    }
                    Rectangle {
                        x: 0
                        width: parent.width
                        y: sumColumn.base - sumColumn.vc * sumView.k - 2
                        height: 4 * root.u
                        radius: 2
                        color: Style.Theme.inferencia_resultado
                        opacity: sumView.result
                    }
                    Column {
                        y: sumView.chartH + 6 * root.u
                        width: parent.width
                        spacing: 1
                        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.fmt(sumColumn.va, 3); color: Style.Theme.inferencia_estructura; font.family: Style.Theme.fuente_mono; font.pixelSize: Math.max(8, 9.5 * root.u); opacity: sumView.growA }
                        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.signed(sumColumn.vb, 3); color: Style.Theme.inferencia_foco; font.family: Style.Theme.fuente_mono; font.pixelSize: Math.max(8, 9.5 * root.u); opacity: sumView.growB }
                        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "= " + root.fmt(sumColumn.vc, 3); color: Style.Theme.inferencia_resultado; font.family: Style.Theme.fuente_mono; font.bold: true; font.pixelSize: Math.max(8, 10 * root.u); opacity: sumView.result }
                    }
                }
            }
            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: Number(root.demo.size || 0) > sumView.count
                text: "coordenadas 0–" + (sumView.count - 1) + " de " + root.demo.size
                color: Style.Theme.texto_terciario
                font.pixelSize: Math.max(9, 10 * root.u)
            }
        }
    }

    // ===================================================== MÓDULO 3
    Component {
        id: matrixRowsComponent
        Item {
            id: matrixView
            readonly property var rows: root.list(root.demo.matrix)
            readonly property var labels: root.list(root.demo.row_labels)
            readonly property int selected: Number(root.demo.selected || 0)
            readonly property var shape: root.list(root.demo.shape)
            readonly property real maxAbs: Math.max(root.maxAbsOf(rows), 1e-6)
            readonly property real rowH: Math.max(14 * root.u, Math.min(26 * root.u, (height - 40 * root.u) / Math.max(1, rows.length) - 3 * root.u))
            RowLayout {
                anchors.fill: parent
                spacing: 20 * root.u
                Column {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3 * root.u
                    Row {
                        spacing: 3 * root.u
                        Item { width: 92 * root.u; height: 16 * root.u }
                        Repeater {
                            model: matrixView.rows.length ? root.list(matrixView.rows[0]).length : 0
                            delegate: Text {
                                required property int index
                                width: 56 * root.u
                                horizontalAlignment: Text.AlignHCenter
                                text: "d" + root.sub(index)
                                color: Style.Theme.texto_terciario
                                font.pixelSize: Math.max(8, 9 * root.u)
                            }
                        }
                    }
                    Repeater {
                        model: matrixView.rows
                        delegate: Row {
                            id: matrixRow
                            required property int index
                            required property var modelData
                            readonly property real p: root.ease(root.seg(0.05 + 0.65 * index / Math.max(1, matrixView.rows.length),
                                                                         0.05 + 0.65 * (index + 1) / Math.max(1, matrixView.rows.length)))
                            readonly property bool chosen: index === matrixView.selected && root.t >= 0.8
                            spacing: 3 * root.u
                            opacity: p * (root.t >= 0.8 && !chosen ? 0.55 : 1)
                            transform: Translate { x: (1 - matrixRow.p) * -50 * root.u }
                            Rectangle {
                                width: 92 * root.u
                                height: matrixView.rowH
                                radius: 5 * root.u
                                color: matrixRow.chosen ? Style.Theme.inferencia_foco : Style.Theme.chip_fondo
                                Text {
                                    anchors.centerIn: parent
                                    width: parent.width - 6
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: (matrixRow.index) + " · " + String(matrixView.labels[matrixRow.index] || "")
                                    color: matrixRow.chosen ? Style.Theme.inferencia_sobre_foco : Style.Theme.chip_texto
                                    font.pixelSize: Math.max(8, 9.5 * root.u)
                                    font.bold: matrixRow.chosen
                                }
                            }
                            Repeater {
                                model: root.list(matrixRow.modelData)
                                delegate: Cell {
                                    required property var modelData
                                    width: 56 * root.u
                                    height: matrixView.rowH
                                    value: modelData
                                    maxAbs: matrixView.maxAbs
                                    emphasized: matrixRow.chosen
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: Number(matrixView.shape[1] || 0) > root.list(matrixRow.modelData).length
                                text: " …"
                                color: Style.Theme.texto_terciario
                            }
                        }
                    }
                }
                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 10 * root.u
                    Equation {
                        reveal: root.seg(0.7, 0.85)
                        accent: Style.Theme.inferencia_estructura
                        text: String(root.demo.symbol || "X") + " ∈ ℝ^(" + matrixView.shape[0] + " × " + matrixView.shape[1] + ")"
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        opacity: root.seg(0.8, 0.95)
                        text: "Fila " + matrixView.selected + " = «" + String(matrixView.labels[matrixView.selected] || "") + "»: el token que sigue el laboratorio."
                        color: Style.Theme.texto_secundario_fuerte
                        font.pixelSize: Math.max(10, 11 * root.u)
                    }
                }
            }
        }
    }

    Component {
        id: heatmapsComponent
        Item {
            id: heatView
            readonly property var items: root.list(root.demo.items)
            readonly property real maxAbs: Math.max(root.maxAbsOf(items.map(function(item) { return item.matrix })), 1e-6)
            Row {
                anchors.centerIn: parent
                spacing: 26 * root.u
                Repeater {
                    model: heatView.items
                    delegate: Column {
                        id: heatItem
                        required property int index
                        required property var modelData
                        readonly property var matrix: root.list(modelData.matrix)
                        readonly property real start: 0.03 + 0.31 * index
                        readonly property real cs: Math.max(16 * root.u, Math.min(34 * root.u, (heatView.height - 50 * root.u) / Math.max(1, matrix.length)))
                        spacing: 4 * root.u
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: String(heatItem.modelData.label) + "  [" + root.list(heatItem.modelData.shape).join(" × ") + "]"
                            color: [Style.Theme.matriz_query, Style.Theme.matriz_key, Style.Theme.matriz_value][heatItem.index % 3]
                            font.bold: true
                            font.pixelSize: Math.max(10, 12 * root.u)
                        }
                        Grid {
                            columns: heatItem.matrix.length ? root.list(heatItem.matrix[0]).length : 1
                            spacing: 2
                            Repeater {
                                model: heatItem.matrix.length * (heatItem.matrix.length ? root.list(heatItem.matrix[0]).length : 0)
                                delegate: Cell {
                                    required property int index
                                    readonly property int columns: root.list(heatItem.matrix[0]).length
                                    readonly property int r: Math.floor(index / columns)
                                    readonly property int c: index % columns
                                    width: heatItem.cs * 1.45
                                    height: heatItem.cs
                                    value: heatItem.matrix[r][c]
                                    maxAbs: heatView.maxAbs
                                    digits: 2
                                    reveal: root.seg(heatItem.start + 0.22 * (r + c) / Math.max(1, heatItem.matrix.length + columns - 2),
                                                     heatItem.start + 0.06 + 0.22 * (r + c) / Math.max(1, heatItem.matrix.length + columns - 2))
                                }
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "ventana 6 × 6 de la cabeza"
                            color: Style.Theme.texto_terciario
                            font.pixelSize: Math.max(8, 9 * root.u)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: projectionComponent
        Item {
            id: projView
            readonly property var outputs: root.list(root.demo.outputs)
            readonly property int outputCount: Math.max(1, outputs.length)
            readonly property int activeIndex: Math.min(outputCount - 1, Math.floor(root.t * outputCount * 0.9999))
            readonly property real lt: outputCount === 1 ? root.t : root.clamp01(root.t * outputCount - activeIndex)
            readonly property var out: outputs.length ? (outputs[Math.min(activeIndex, outputs.length - 1)] || ({})) : ({})
            readonly property var input: root.list(root.demo.input)
            readonly property var weights: root.list(out.w)
            readonly property var products: root.list(out.products)
            readonly property int count: products.length
            readonly property real cw: root.cellWidth(count + 1, width * 0.66 - 110 * root.u, 70)
            readonly property real maxIn: Math.max(root.maxAbsOf(input), 1e-6)
            readonly property real maxW: Math.max(root.maxAbsOf(weights), 1e-6)
            readonly property real maxP: Math.max(root.maxAbsOf(products), 1e-6)
            function lseg(a, b) { return root.segOf(lt, a, b) }
            function termReveal(index) {
                var start = 0.05 + 0.5 * index / Math.max(1, count)
                return lseg(start, start + 0.5 / Math.max(1, count))
            }
            readonly property int revealed: {
                var n = 0
                for (var i = 0; i < count; ++i)
                    if (termReveal(i) >= 0.5)
                        n = i + 1
                return n
            }
            readonly property real running: {
                var total = 0
                for (var i = 0; i < revealed; ++i)
                    total += root.num(products[i])
                if (lt >= 0.62) total += root.num(out.hidden_sum)
                if (lt >= 0.72 && root.isNum(out.bias)) total += root.num(out.bias)
                if (lt >= 0.8 && root.isNum(out.divisor)) total /= root.num(out.divisor)
                return total
            }
            function colorFor(label) {
                var l = String(label).toUpperCase()
                if (l === "Q") return Style.Theme.matriz_query
                if (l === "K") return Style.Theme.matriz_key
                if (l === "V") return Style.Theme.matriz_value
                return Style.Theme.inferencia_transformacion
            }

            RowLayout {
                anchors.fill: parent
                spacing: 14 * root.u

                Column {
                    Layout.preferredWidth: parent.width * 0.66
                    Layout.alignment: Qt.AlignTop
                    spacing: 5 * root.u

                    Row {
                        spacing: 6 * root.u
                        visible: projView.outputs.length > 1
                        Repeater {
                            model: projView.outputs
                            delegate: Rectangle {
                                id: outTab
                                required property int index
                                required property var modelData
                                readonly property bool isActive: index === projView.activeIndex
                                readonly property bool done: index < projView.activeIndex || root.t >= 0.999
                                width: outTabText.implicitWidth + 16 * root.u
                                height: 22 * root.u
                                radius: 11 * root.u
                                color: isActive ? projView.colorFor(modelData.label) : Qt.alpha(projView.colorFor(modelData.label), 0.14)
                                border.color: projView.colorFor(modelData.label)
                                Text {
                                    id: outTabText
                                    anchors.centerIn: parent
                                    text: outTab.done || outTab.isActive && projView.lt >= 0.85
                                          ? outTab.modelData.result_label + " = " + root.fmt(outTab.modelData.result, 4)
                                          : outTab.modelData.result_label
                                    color: outTab.isActive ? root.inkOn(projView.colorFor(outTab.modelData.label)) : Style.Theme.texto_primario
                                    font.family: Style.Theme.fuente_mono
                                    font.bold: true
                                    font.pixelSize: Math.max(9, 10 * root.u)
                                }
                            }
                        }
                    }

                    Row {
                        spacing: 4 * root.u
                        Tag { width: 106 * root.u; text: String(root.demo.input_label || "x"); elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter; color: Style.Theme.inferencia_estructura }
                        Repeater {
                            model: projView.input
                            delegate: Cell {
                                required property int index
                                required property var modelData
                                width: projView.cw
                                value: modelData
                                maxAbs: projView.maxIn
                                emphasized: index === projView.revealed - 1 && projView.lt < 0.6
                            }
                        }
                        Text { visible: Number(root.demo.input_size) > projView.input.length; anchors.verticalCenter: parent.verticalCenter; text: "… (" + root.demo.input_size + ")"; color: Style.Theme.texto_terciario; font.pixelSize: Math.max(8, 9 * root.u) }
                    }
                    Row {
                        spacing: 4 * root.u
                        Tag { width: 106 * root.u; text: "× " + String(projView.out.w_label || "w"); elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter; color: projView.colorFor(projView.out.label) }
                        Repeater {
                            model: projView.weights
                            delegate: Cell {
                                required property int index
                                required property var modelData
                                width: projView.cw
                                value: modelData
                                maxAbs: projView.maxW
                                emphasized: index === projView.revealed - 1 && projView.lt < 0.6
                                reveal: projView.lseg(0, 0.05)
                            }
                        }
                    }
                    Row {
                        spacing: 4 * root.u
                        Tag { width: 106 * root.u; text: "= productos"; anchors.verticalCenter: parent.verticalCenter; color: Style.Theme.inferencia_transformacion }
                        Repeater {
                            model: projView.products
                            delegate: Cell {
                                id: productCell
                                required property int index
                                required property var modelData
                                width: projView.cw
                                value: modelData
                                maxAbs: projView.maxP
                                reveal: projView.termReveal(index)
                                transform: Translate { y: (1 - productCell.reveal) * -26 * root.u }
                            }
                        }
                        Cell {
                            visible: Number(projView.out.hidden_terms || 0) > 0
                            width: projView.cw * 1.4
                            useFill: true
                            fill: Style.Theme.chip_fondo
                            label: "+" + projView.out.hidden_terms + " · " + root.fmt(projView.out.hidden_sum, 3)
                            reveal: projView.lseg(0.58, 0.64)
                        }
                    }
                    Item { width: 1; height: 4 * root.u }
                    Row {
                        spacing: 4 * root.u
                        visible: root.list(projView.out.vector).length > 0
                        opacity: projView.lseg(0.86, 0.95)
                        Tag { width: 106 * root.u; text: "→ " + (root.list(projView.out.vector_labels).length ? "candidatos" : "vector"); anchors.verticalCenter: parent.verticalCenter; color: Style.Theme.inferencia_resultado }
                        Repeater {
                            model: root.list(projView.out.vector)
                            delegate: Rectangle {
                                id: vectorCell
                                required property int index
                                required property var modelData
                                readonly property bool hit: index === Number(projView.out.highlight || 0)
                                readonly property int segments: Number(projView.out.segments || 0)
                                readonly property int perHead: segments > 0 ? Math.max(1, Math.round(Number(projView.out.vector_size || 1) / segments)) : 0
                                readonly property real vw: root.list(projView.out.vector_labels).length ? projView.cw : Math.max(20 * root.u, projView.cw * 0.62)
                                width: vw
                                height: (root.list(projView.out.vector_labels).length ? 36 : 24) * root.u
                                radius: 4 * root.u
                                color: root.divColor(modelData, Math.max(root.maxAbsOf(projView.out.vector), 1e-6))
                                border.width: hit ? 3 : (segments > 0 ? 2 : 1)
                                border.color: hit ? Style.Theme.acento : (segments > 0 ? root.headColor(Math.floor(index / perHead)) : Style.Theme.borde_suave)
                                scale: hit ? 1 + 0.15 * Math.sin(Math.PI * projView.lseg(0.86, 1)) : 1
                                Column {
                                    anchors.centerIn: parent
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: root.list(projView.out.vector_labels).length > 0
                                        text: String(root.list(projView.out.vector_labels)[vectorCell.index] || "")
                                        width: vectorCell.width - 4
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        color: root.inkOn(vectorCell.color)
                                        font.pixelSize: Math.max(7, 8.5 * root.u)
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.fmt(vectorCell.modelData, vectorCell.vw > 40 * root.u ? 2 : 1)
                                        color: root.inkOn(vectorCell.color)
                                        font.family: Style.Theme.fuente_mono
                                        font.bold: vectorCell.hit
                                        font.pixelSize: Math.max(7, 8.5 * root.u)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10 * root.u
                    color: Style.Theme.surface
                    border.color: projView.colorFor(projView.out.label)
                    Column {
                        anchors.fill: parent
                        anchors.margins: 10 * root.u
                        spacing: 4 * root.u
                        Tag { text: "SUMA ACUMULADA  Σ" }
                        Text {
                            text: root.fmt(projView.running, 4)
                            color: Style.Theme.texto_primario
                            font.family: Style.Theme.fuente_mono
                            font.bold: true
                            font.pixelSize: Math.max(18, 26 * root.u)
                        }
                        Text {
                            text: projView.revealed + " de " + projView.count + " productos visibles"
                            color: Style.Theme.texto_terciario
                            font.pixelSize: Math.max(9, 10 * root.u)
                        }
                        Text {
                            visible: Number(projView.out.hidden_terms || 0) > 0
                            opacity: projView.lseg(0.58, 0.64)
                            text: "+ resto (" + projView.out.hidden_terms + " términos) = " + root.signed(projView.out.hidden_sum, 4)
                            color: Style.Theme.texto_secundario_fuerte
                            font.family: Style.Theme.fuente_mono
                            font.pixelSize: Math.max(9, 10 * root.u)
                        }
                        Text {
                            visible: root.isNum(projView.out.bias)
                            opacity: projView.lseg(0.68, 0.74)
                            text: "+ sesgo b = " + root.signed(projView.out.bias, 4)
                            color: Style.Theme.texto_secundario_fuerte
                            font.family: Style.Theme.fuente_mono
                            font.pixelSize: Math.max(9, 10 * root.u)
                        }
                        Text {
                            visible: root.isNum(projView.out.divisor)
                            opacity: projView.lseg(0.76, 0.82)
                            text: "÷ " + root.fmt(projView.out.divisor, 4)
                            color: Style.Theme.texto_secundario_fuerte
                            font.family: Style.Theme.fuente_mono
                            font.pixelSize: Math.max(9, 10 * root.u)
                        }
                        Equation {
                            reveal: projView.lseg(0.82, 0.9)
                            accent: Style.Theme.inferencia_resultado
                            text: String(projView.out.result_label || "") + " = " + root.fmt(projView.out.result, 4)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: maskRowComponent
        Item {
            id: maskRowView
            readonly property var labels: root.list(root.demo.labels)
            readonly property var scores: root.list(root.demo.scores)
            readonly property var allowed: root.list(root.demo.allowed)
            readonly property int count: labels.length
            readonly property real cw: root.cellWidth(count, width - 120 * root.u, 70)
            readonly property real maxAbs: Math.max(root.maxAbsOf(scores), 1e-6)
            readonly property real scan: root.seg(0.1, 0.88) * count
            readonly property int blocked: {
                var n = 0
                for (var i = 0; i < allowed.length; ++i) if (!allowed[i]) ++n
                return n
            }
            Column {
                anchors.centerIn: parent
                spacing: 6 * root.u
                Row {
                    spacing: 4 * root.u
                    Tag { width: 110 * root.u; text: "key" }
                    Repeater {
                        model: maskRowView.labels
                        delegate: Text {
                            required property var modelData
                            width: maskRowView.cw
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: String(modelData)
                            color: Style.Theme.texto_terciario
                            font.pixelSize: Math.max(8, 9 * root.u)
                        }
                    }
                }
                Row {
                    spacing: 4 * root.u
                    Tag { width: 110 * root.u; text: "S[«" + root.demo.query_label + "»,:]"; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                    Repeater {
                        model: maskRowView.scores
                        delegate: Cell {
                            required property int index
                            required property var modelData
                            width: maskRowView.cw
                            value: modelData
                            maxAbs: maskRowView.maxAbs
                            emphasized: Math.floor(maskRowView.scan) === index && root.t < 0.88
                        }
                    }
                }
                Row {
                    spacing: 4 * root.u
                    Tag { width: 110 * root.u; text: "máscara"; anchors.verticalCenter: parent.verticalCenter }
                    Repeater {
                        model: maskRowView.allowed
                        delegate: Cell {
                            required property int index
                            required property var modelData
                            width: maskRowView.cw
                            useFill: true
                            fill: modelData ? Style.Theme.exito_fondo : Style.Theme.error_fondo
                            label: modelData ? "✓ permitida" : "✕ PAD"
                            reveal: root.clamp01(maskRowView.scan - index + 0.5)
                        }
                    }
                }
                Row {
                    spacing: 4 * root.u
                    Tag { width: 110 * root.u; text: "S′ resultado"; anchors.verticalCenter: parent.verticalCenter; color: Style.Theme.inferencia_resultado }
                    Repeater {
                        model: maskRowView.scores
                        delegate: Cell {
                            required property int index
                            required property var modelData
                            width: maskRowView.cw
                            value: maskRowView.allowed[index] ? modelData : null
                            maxAbs: maskRowView.maxAbs
                            reveal: root.clamp01(maskRowView.scan - index)
                        }
                    }
                }
                Equation {
                    reveal: root.seg(0.88, 1)
                    accent: maskRowView.blocked ? Style.Theme.inferencia_error : Style.Theme.inferencia_resultado
                    text: (maskRowView.count - maskRowView.blocked) + " keys permitidas · " + maskRowView.blocked + " bloqueadas (−∞)"
                }
            }
        }
    }

    Component {
        id: softmaxComponent
        Item {
            id: softView
            readonly property var labels: root.list(root.demo.labels)
            readonly property var scores: root.list(root.demo.scores)
            readonly property var exps: root.list(root.demo.exps)
            readonly property var probs: root.list(root.demo.probs)
            readonly property var allowed: root.list(root.demo.allowed)
            readonly property bool hasRest: Number(root.demo.rest_count || 0) > 0
            readonly property int count: labels.length + (hasRest ? 1 : 0)
            readonly property real chartH: Math.max(70 * root.u, height - 74 * root.u)
            readonly property real plotW: width * 0.7
            readonly property real cw: Math.max(18 * root.u, Math.min(64 * root.u, plotW / Math.max(1, count) - 6 * root.u))
            readonly property real maxScore: Math.max(root.maxAbsOf(scores), 1e-6)
            readonly property real maxExp: Math.max(root.maxAbsOf(exps), root.num(root.demo.rest_exp), 1e-9)
            readonly property real maxProb: Math.max(root.maxAbsOf(probs), root.num(root.demo.rest_prob), 1e-9)
            readonly property real scoreFade: 1 - root.seg(0.25, 0.33)
            readonly property real expGrow: root.ease(root.seg(0.27, 0.45))
            readonly property real toProb: root.ease(root.seg(0.7, 0.88))
            function value(list, index, restKey) {
                return index < labels.length ? root.num(list[index]) : root.num(root.demo[restKey])
            }

            Item {
                id: plot
                width: softView.plotW
                height: softView.chartH + 34 * root.u
                Rectangle { y: softView.chartH / 2; width: parent.width; height: 1; color: Style.Theme.borde_medio; opacity: softView.scoreFade }
                Rectangle { y: softView.chartH; width: parent.width; height: 1; color: Style.Theme.borde_medio; opacity: 1 - softView.scoreFade }
                Repeater {
                    model: softView.count
                    delegate: Item {
                        id: softColumn
                        required property int index
                        readonly property bool isRest: index >= softView.labels.length
                        readonly property bool ok: isRest || Boolean(softView.allowed[index])
                        readonly property real score: isRest ? 0 : root.num(softView.scores[index])
                        readonly property real ex: softView.value(softView.exps, index, "rest_exp")
                        readonly property real pr: softView.value(softView.probs, index, "rest_prob")
                        x: index * (softView.cw + 6 * root.u)
                        width: softView.cw
                        height: plot.height
                        // Scores con signo alrededor de la línea media.
                        Rectangle {
                            visible: !softColumn.isRest && softColumn.ok
                            x: parent.width * 0.15
                            width: parent.width * 0.7
                            readonly property real h: Math.abs(softColumn.score) / softView.maxScore * softView.chartH * 0.46
                            y: softView.chartH / 2 - (softColumn.score > 0 ? h : 0)
                            height: h
                            radius: 2
                            color: root.divColor(softColumn.score, softView.maxScore)
                            border.color: Style.Theme.borde_medio
                            opacity: softView.scoreFade
                        }
                        // e^s y después probabilidad, desde la base.
                        Rectangle {
                            x: parent.width * 0.15
                            width: parent.width * 0.7
                            readonly property real expH: softColumn.ex / softView.maxExp * softView.chartH * 0.92
                            readonly property real probH: softColumn.pr / softView.maxProb * softView.chartH * 0.92
                            readonly property real h: root.lerp(expH * softView.expGrow, probH, softView.toProb)
                            y: softView.chartH - h
                            height: h
                            radius: 2
                            color: softView.toProb > 0.5 ? Style.Theme.inferencia_resultado
                                                          : (softColumn.isRest ? Style.Theme.borde_medio : Style.Theme.inferencia_foco)
                            opacity: 1 - softView.scoreFade
                        }
                        Text {
                            width: parent.width + 6 * root.u
                            x: -3 * root.u
                            horizontalAlignment: Text.AlignHCenter
                            y: 0
                            text: !softColumn.ok ? (softView.scoreFade > 0.5 ? "−∞" : "0")
                                  : (softView.scoreFade > 0.5 ? root.fmt(softColumn.score, 2)
                                     : (softView.toProb < 0.5 ? root.fmt(softColumn.ex, 2)
                                        : (softColumn.pr * 100).toFixed(1) + "%"))
                            color: softColumn.ok ? Style.Theme.texto_primario : Style.Theme.error_texto
                            font.family: Style.Theme.fuente_mono
                            font.pixelSize: Math.max(7, 8.5 * root.u)
                        }
                        Text {
                            y: softView.chartH + 4 * root.u
                            width: parent.width + 6 * root.u
                            x: -3 * root.u
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: softColumn.isRest ? "+" + root.demo.rest_count + " resto" : String(softView.labels[softColumn.index])
                            color: softColumn.ok ? Style.Theme.texto_secundario_fuerte : Style.Theme.error_texto
                            font.pixelSize: Math.max(7, 9 * root.u)
                        }
                    }
                }
            }

            Column {
                x: softView.plotW + 16 * root.u
                width: parent.width - x
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7 * root.u
                Tag { text: "query «" + root.demo.query_label + "»" }
                Equation {
                    reveal: root.seg(0.27, 0.35)
                    accent: Style.Theme.inferencia_foco
                    text: (Number(root.demo.shift || 0) !== 0 ? "e^(s − " + root.fmt(root.demo.shift, 2) + ")" : "eˢ")
                          + (softView.allowed.indexOf(false) >= 0 ? "   (e^−∞ = 0)" : "")
                }
                Equation {
                    reveal: root.seg(0.5, 0.6)
                    accent: Style.Theme.inferencia_transformacion
                    text: "Σ eˢ = " + root.fmt(root.demo.total, 4)
                }
                Equation {
                    reveal: root.seg(0.7, 0.8)
                    accent: Style.Theme.inferencia_resultado
                    text: "pⱼ = eˢʲ / " + root.fmt(root.demo.total, 3)
                }
                Text {
                    opacity: root.seg(0.88, 1)
                    text: "Σ p = " + (function() {
                        var total = root.num(root.demo.rest_prob)
                        for (var i = 0; i < softView.probs.length; ++i) total += root.num(softView.probs[i])
                        return total.toFixed(4)
                    })()
                    color: Style.Theme.inferencia_resultado
                    font.family: Style.Theme.fuente_mono
                    font.bold: true
                    font.pixelSize: Math.max(11, 13 * root.u)
                }
            }
            // Barra apilada: cada exponencial ocupa su parte de la suma.
            Row {
                x: 0
                y: softView.chartH + 30 * root.u
                height: 10 * root.u
                opacity: root.seg(0.5, 0.58) * (1 - root.seg(0.9, 1) * 0.5)
                Repeater {
                    model: softView.count
                    delegate: Rectangle {
                        required property int index
                        readonly property real ex: softView.value(softView.exps, index, "rest_exp")
                        width: softView.plotW * ex / Math.max(1e-9, root.num(root.demo.total)) * root.ease(root.seg(0.5, 0.68))
                        height: parent.height
                        color: root.headColor(index)
                        border.color: Style.Theme.surface
                    }
                }
            }
        }
    }

    Component {
        id: weightedSumComponent
        Item {
            id: wsView
            readonly property var labels: root.list(root.demo.labels)
            readonly property var weights: root.list(root.demo.weights)
            readonly property var vectors: root.list(root.demo.vectors)
            readonly property var result: root.list(root.demo.result)
            readonly property int dims: result.length
            // Se muestran las keys con más peso; el resto se agrupa en una
            // fila cuya contribución es exactamente C − Σ(filas visibles).
            readonly property var order: {
                var indices = []
                for (var i = 0; i < weights.length; ++i) indices.push(i)
                indices.sort(function(x, y) { return root.num(weights[y]) - root.num(weights[x]) })
                return indices.slice(0, Math.min(indices.length, Math.max(2, Math.floor((height - 70 * root.u) / (25 * root.u)) - 1)))
            }
            readonly property bool hasRest: order.length < weights.length
            readonly property var rest: {
                var values = []
                for (var d = 0; d < dims; ++d) {
                    var shown = 0
                    for (var r = 0; r < order.length; ++r)
                        shown += root.num(weights[order[r]]) * root.num(vectors[order[r]][d])
                    values.push(root.num(result[d]) - shown)
                }
                return values
            }
            readonly property real restWeight: {
                var total = 0
                for (var i = 0; i < weights.length; ++i)
                    if (order.indexOf(i) < 0) total += root.num(weights[i])
                return total
            }
            readonly property int rowCount: order.length + (hasRest ? 1 : 0)
            function rowProgress(r) {
                var start = 0.05 + 0.75 * r / Math.max(1, rowCount)
                return root.seg(start, start + 0.75 / Math.max(1, rowCount))
            }
            function contribution(r, d) {
                if (r >= order.length) return rest[d]
                return root.num(weights[order[r]]) * root.num(vectors[order[r]][d])
            }
            readonly property var accumulated: {
                var values = []
                for (var d = 0; d < dims; ++d) {
                    var total = 0
                    for (var r = 0; r < rowCount; ++r)
                        if (rowProgress(r) >= 0.7) total += contribution(r, d)
                    values.push(total)
                }
                return values
            }
            readonly property real maxV: Math.max(root.maxAbsOf(vectors), 1e-6)
            readonly property real maxWeight: Math.max(root.maxAbsOf(weights), restWeight, 1e-9)
            readonly property real maxC: Math.max(root.maxAbsOf(result), root.maxAbsOf(rest), 1e-6)
            readonly property real cw: root.cellWidth(dims * 2 + 3, width - 230 * root.u, 54)
            readonly property real rowH: 22 * root.u

            Column {
                spacing: 3 * root.u
                Row {
                    spacing: 4 * root.u
                    Tag { width: 86 * root.u; text: "key j" }
                    Tag { width: 96 * root.u; text: "A[«" + root.demo.query_label + "», j]"; elide: Text.ElideRight }
                    Tag { width: wsView.dims * (wsView.cw + 4 * root.u) + 14 * root.u; text: "vⱼ (Value)"; color: Style.Theme.matriz_value }
                    Tag { text: "A·vⱼ (contribución)"; color: Style.Theme.inferencia_transformacion }
                }
                Repeater {
                    model: wsView.rowCount
                    delegate: Row {
                        id: wsRow
                        required property int index
                        readonly property bool isRest: index >= wsView.order.length
                        readonly property int key: isRest ? -1 : wsView.order[index]
                        readonly property real w: isRest ? wsView.restWeight : root.num(wsView.weights[key])
                        readonly property real p: wsView.rowProgress(index)
                        spacing: 4 * root.u
                        opacity: 0.35 + 0.65 * Math.min(1, p * 3)
                        Rectangle {
                            width: 86 * root.u
                            height: wsView.rowH
                            radius: 5 * root.u
                            color: wsRow.p > 0 && wsRow.p < 1 ? Style.Theme.acento_fondo : Style.Theme.chip_fondo
                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 6
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: wsRow.isRest ? "resto (" + (wsView.weights.length - wsView.order.length) + ")" : wsRow.key + " · " + String(wsView.labels[wsRow.key])
                                color: Style.Theme.chip_texto
                                font.pixelSize: Math.max(8, 9 * root.u)
                            }
                        }
                        Item {
                            width: 96 * root.u
                            height: wsView.rowH
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: (parent.width - 44 * root.u) * root.clamp01(wsRow.w / Math.max(1e-9, wsView.maxWeight))
                                height: 10 * root.u
                                radius: 3
                                color: Style.Theme.inferencia_foco
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.fmt(wsRow.w, 3)
                                color: Style.Theme.texto_primario
                                font.family: Style.Theme.fuente_mono
                                font.pixelSize: Math.max(8, 9 * root.u)
                            }
                        }
                        Repeater {
                            model: wsView.dims
                            delegate: Cell {
                                required property int index
                                width: wsView.cw
                                height: wsView.rowH
                                value: wsRow.isRest ? 0 : wsView.vectors[wsRow.key][index]
                                label: wsRow.isRest ? "·" : ""
                                maxAbs: wsView.maxV
                                opacity: 1 - 0.5 * root.segOf(wsRow.p, 0.2, 0.5)
                            }
                        }
                        Text { text: "→"; anchors.verticalCenter: parent.verticalCenter; color: Style.Theme.texto_terciario; width: 10 * root.u }
                        Repeater {
                            model: wsView.dims
                            delegate: Cell {
                                id: contributionCell
                                required property int index
                                width: wsView.cw
                                height: wsView.rowH
                                value: wsView.contribution(wsRow.index, index)
                                maxAbs: wsView.maxC
                                reveal: root.segOf(wsRow.p, 0.2, 0.5)
                                transform: Translate { y: root.segOf(wsRow.p, 0.7, 1) * 6 * root.u }
                            }
                        }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Style.Theme.borde_medio }
                Row {
                    spacing: 4 * root.u
                    Tag { width: 186 * root.u; text: "C«" + root.demo.query_label + "» = Σ  (acumulado)"; elide: Text.ElideRight; color: Style.Theme.inferencia_resultado; anchors.verticalCenter: parent.verticalCenter }
                    Item { width: wsView.dims * (wsView.cw + 4 * root.u) + 14 * root.u; height: 1 }
                    Repeater {
                        model: wsView.dims
                        delegate: Cell {
                            required property int index
                            width: wsView.cw
                            height: wsView.rowH + 4 * root.u
                            value: wsView.accumulated[index]
                            maxAbs: wsView.maxC
                            emphasized: root.t >= 0.88
                        }
                    }
                }
                Row {
                    visible: Boolean(root.demo.extra && root.demo.extra.label)
                    opacity: root.seg(0.9, 1)
                    spacing: 4 * root.u
                    Tag { width: 186 * root.u; text: String(root.demo.extra ? root.demo.extra.label : ""); elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter; color: Style.Theme.inferencia_transformacion }
                    Item { width: wsView.dims * (wsView.cw + 4 * root.u) + 14 * root.u; height: 1 }
                    Repeater {
                        model: root.list(root.demo.extra ? root.demo.extra.values : [])
                        delegate: Cell {
                            required property var modelData
                            width: wsView.cw
                            height: wsView.rowH
                            value: modelData
                            maxAbs: Math.max(root.maxAbsOf(root.demo.extra.values), 1e-6)
                        }
                    }
                }
            }
        }
    }

    // ===================================================== MÓDULO 4
    Component {
        id: headsComponent
        Item {
            id: headsView
            readonly property var heads: root.list(root.demo.heads)
            readonly property int headCount: heads.length
            readonly property int perHead: heads.length ? root.list(heads[0]).length : 1
            readonly property bool truncated: Number(root.demo.d_head || 0) > perHead
            readonly property string mode: String(root.demo.mode || "split")
            readonly property real cw: root.cellWidth(headCount * (perHead + (truncated ? 1 : 0)), width - 160 * root.u, 50)
            readonly property real groupW: (perHead + (truncated ? 1 : 0)) * (cw + 3 * root.u)
            readonly property real rowH: Math.max(18 * root.u, Math.min(26 * root.u, (height - 90 * root.u) / Math.max(1, headCount)))
            readonly property real maxAbs: Math.max(root.maxAbsOf(heads), 1e-6)
            // 0 = una sola fila; 1 = una fila por cabeza. El movimiento se hace
            // en dos tiempos (vertical y horizontal) para que los bloques nunca
            // se encimen mientras viajan.
            readonly property real stackedY: mode === "split"
                                             ? root.ease(root.seg(0.55, 0.7))
                                             : 1 - root.ease(root.seg(mode === "concat" ? 0.5 : 0.4, mode === "concat" ? 0.68 : 0.55))
            readonly property real stackedX: mode === "split"
                                             ? root.ease(root.seg(0.7, 0.85))
                                             : 1 - root.ease(root.seg(mode === "concat" ? 0.3 : 0.25, mode === "concat" ? 0.48 : 0.38))
            readonly property real stacked: Math.min(stackedX, stackedY)
            readonly property real gapOpen: mode === "split"
                                            ? root.ease(root.seg(0.25, 0.5))
                                            : 1 - root.ease(root.seg(mode === "concat" ? 0.5 : 0.4, mode === "concat" ? 0.68 : 0.55))
            Item {
                anchors.fill: parent
                Repeater {
                    model: headsView.heads
                    delegate: Item {
                        id: headGroup
                        required property int index
                        required property var modelData
                        readonly property real lineX: 110 * root.u + index * (headsView.groupW + 18 * root.u * headsView.gapOpen)
                        readonly property real lineY: 10 * root.u
                        readonly property real stackX: 110 * root.u
                        readonly property real stackY: 10 * root.u + index * (headsView.rowH + 6 * root.u)
                        x: root.lerp(lineX, stackX, headsView.stackedX)
                        y: root.lerp(lineY, stackY, headsView.stackedY)
                        width: headsView.groupW
                        height: headsView.rowH
                        Text {
                            x: -96 * root.u
                            width: 90 * root.u
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: "cabeza " + (headGroup.index + 1)
                            opacity: headsView.stackedX
                            color: root.headColor(headGroup.index)
                            font.bold: headGroup.index === Number(root.demo.selected_head)
                            font.pixelSize: Math.max(9, 10 * root.u)
                        }
                        Row {
                            spacing: 3 * root.u
                            Repeater {
                                model: root.list(headGroup.modelData)
                                delegate: Rectangle {
                                    id: headCell
                                    required property var modelData
                                    width: headsView.cw
                                    height: headsView.rowH
                                    radius: 4 * root.u
                                    color: root.divColor(modelData, headsView.maxAbs)
                                    border.color: root.headColor(headGroup.index)
                                    border.width: 2
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.fmt(headCell.modelData, headsView.cw > 44 * root.u ? 3 : 2)
                                        color: root.inkOn(headCell.color)
                                        font.family: Style.Theme.fuente_mono
                                        font.pixelSize: Math.max(7, 9 * root.u)
                                    }
                                }
                            }
                            Rectangle {
                                visible: headsView.truncated
                                width: headsView.cw
                                height: headsView.rowH
                                radius: 4 * root.u
                                color: Style.Theme.chip_fondo
                                border.color: root.headColor(headGroup.index)
                                Text { anchors.centerIn: parent; text: "…"; color: Style.Theme.chip_texto }
                            }
                        }
                    }
                }
                Text {
                    x: 0
                    y: 10 * root.u + (headsView.rowH - height) / 2
                    width: 100 * root.u
                    opacity: 1 - headsView.stackedY
                    text: headsView.mode === "split" ? "q (d_model)" : "Concat (d_model)"
                    color: Style.Theme.texto_secundario_fuerte
                    font.bold: true
                    font.pixelSize: Math.max(9, 10 * root.u)
                }
                Equation {
                    x: 110 * root.u
                    y: parent.height - height - (headsView.mode === "concat_project" ? 40 * root.u : 4 * root.u)
                    reveal: headsView.mode === "split" ? root.seg(0.85, 1) : root.seg(0.55, 0.7)
                    accent: Style.Theme.inferencia_transformacion
                    text: headsView.mode === "split"
                          ? root.demo.size + " = " + headsView.headCount + " cabezas × " + root.demo.d_head + " (d_head)"
                          : headsView.headCount + " × " + root.demo.d_head + " = " + root.demo.size + " coordenadas, en orden de cabeza"
                }
                Row {
                    visible: headsView.mode === "concat_project"
                    x: 0
                    y: parent.height - 30 * root.u
                    spacing: 4 * root.u
                    opacity: root.seg(0.62, 0.72)
                    Rectangle {
                        width: 100 * root.u
                        height: 26 * root.u
                        radius: 6 * root.u
                        color: Style.Theme.inferencia_transformacion
                        Text { anchors.centerIn: parent; text: "· Wᴼ  →  y"; color: Style.Theme.inferencia_sobre_transformacion; font.bold: true; font.pixelSize: Math.max(9, 11 * root.u) }
                    }
                    Repeater {
                        model: root.list(root.demo.projected)
                        delegate: Cell {
                            required property int index
                            required property var modelData
                            width: Math.max(26 * root.u, Math.min(56 * root.u, (headsView.width - 120 * root.u) / Math.max(1, root.list(root.demo.projected).length) - 4 * root.u))
                            height: 26 * root.u
                            value: modelData
                            digits: 2
                            maxAbs: Math.max(root.maxAbsOf(root.demo.projected), 1e-6)
                            reveal: root.seg(0.68 + 0.27 * index / Math.max(1, root.list(root.demo.projected).length), 0.98)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: multiSoftmaxComponent
        Item {
            id: multiView
            readonly property var heads: root.list(root.demo.heads)
            readonly property var labels: root.list(root.demo.labels)
            readonly property int columns: Math.min(4, Math.max(1, heads.length))
            readonly property int rows: Math.ceil(heads.length / columns)
            Grid {
                anchors.fill: parent
                columns: multiView.columns
                spacing: 8 * root.u
                Repeater {
                    model: multiView.heads
                    delegate: Rectangle {
                        id: headPanel
                        required property int index
                        required property var modelData
                        readonly property var scores: root.list(modelData.scores)
                        readonly property var probs: root.list(modelData.probs)
                        readonly property real p: root.ease(root.seg(0.15 + 0.5 * index / Math.max(1, multiView.heads.length),
                                                                      0.35 + 0.5 * index / Math.max(1, multiView.heads.length)))
                        readonly property real maxScore: Math.max(root.maxAbsOf(scores), 1e-6)
                        readonly property int best: {
                            var b = 0
                            for (var i = 1; i < probs.length; ++i) if (root.num(probs[i]) > root.num(probs[b])) b = i
                            return b
                        }
                        width: (multiView.width - (multiView.columns - 1) * 8 * root.u) / multiView.columns
                        height: (multiView.height - (multiView.rows - 1) * 8 * root.u) / multiView.rows
                        radius: 8 * root.u
                        color: Style.Theme.surface
                        border.color: root.headColor(index)
                        border.width: index === Number(root.demo.selected_head) ? 3 : 1
                        Text {
                            x: 8 * root.u; y: 4 * root.u
                            text: "Cabeza " + (headPanel.index + 1)
                            color: root.headColor(headPanel.index)
                            font.bold: true
                            font.pixelSize: Math.max(9, 10 * root.u)
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 8 * root.u; y: 4 * root.u
                            opacity: root.seg(0.85, 0.95)
                            text: "→ «" + String(multiView.labels[headPanel.best] || "") + "» " + (root.num(headPanel.probs[headPanel.best]) * 100).toFixed(0) + "%"
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.pixelSize: Math.max(9, 10 * root.u)
                        }
                        Row {
                            x: 8 * root.u
                            y: 22 * root.u
                            spacing: 2
                            readonly property real barW: (headPanel.width - 16 * root.u) / Math.max(1, headPanel.probs.length) - 2
                            readonly property real barH: headPanel.height - 42 * root.u
                            Repeater {
                                model: headPanel.probs.length
                                delegate: Item {
                                    id: miniBar
                                    required property int index
                                    width: parent.barW
                                    height: parent.barH
                                    readonly property real scoreH: (root.num(headPanel.scores[index]) / headPanel.maxScore * 0.5 + 0.5) * height
                                    readonly property real probH: root.num(headPanel.probs[index]) * height
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: Math.max(1, root.lerp(miniBar.scoreH, miniBar.probH, headPanel.p))
                                        radius: 2
                                        color: headPanel.p > 0.5 ? (miniBar.index === headPanel.best ? root.headColor(headPanel.index) : Qt.alpha(root.headColor(headPanel.index), 0.45))
                                                                  : Style.Theme.borde_medio
                                    }
                                    Text {
                                        anchors.top: parent.bottom
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        text: String(multiView.labels[miniBar.index] || "")
                                        color: Style.Theme.texto_terciario
                                        font.pixelSize: Math.max(7, 8 * root.u)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ===================================================== MÓDULO 5
    Component {
        id: layerNormComponent
        Item {
            id: lnView
            readonly property var a: root.list(root.demo.a)
            readonly property var b: root.list(root.demo.b)
            readonly property var xs: root.list(root.demo.x)
            readonly property var normalized: root.list(root.demo.normalized)
            readonly property var gamma: root.list(root.demo.gamma)
            readonly property var beta: root.list(root.demo.beta)
            readonly property var output: root.list(root.demo.output)
            readonly property bool hasAddends: a.length > 0
            readonly property real mean: root.num(root.demo.mean)
            readonly property real std: root.num(root.demo.std)
            readonly property real grow: root.ease(root.seg(0.02, 0.18))
            readonly property real center: root.ease(root.seg(0.36, 0.52))
            readonly property real divide: root.ease(root.seg(0.56, 0.72))
            readonly property real affine: root.ease(root.seg(0.76, 0.92))
            function current(i) {
                var v = root.num(xs[i]) * grow
                v = v - mean * center
                v = v / root.lerp(1, std, divide)
                if (affine > 0) v = root.lerp(v, root.num(normalized[i]) * root.num(gamma[i]) + root.num(beta[i]), affine)
                return v
            }
            readonly property real valueScale: Math.max(root.maxAbsOf(xs), root.maxAbsOf(normalized), root.maxAbsOf(output), Math.abs(mean) + 1e-6)
            readonly property real chartH: Math.max(70 * root.u, height - 60 * root.u)
            readonly property real k: chartH / 2 / valueScale
            readonly property real plotW: width * 0.58
            readonly property real cw: Math.max(20 * root.u, Math.min(70 * root.u, plotW / Math.max(1, xs.length) - 6 * root.u))

            Item {
                width: lnView.plotW
                height: lnView.chartH + 40 * root.u
                Rectangle { y: lnView.chartH / 2; width: parent.width; height: 1; color: Style.Theme.borde_medio }
                Rectangle {
                    y: lnView.chartH / 2 - lnView.mean * (1 - lnView.center) * lnView.k
                    width: parent.width
                    height: 2
                    color: Style.Theme.inferencia_foco
                    opacity: root.seg(0.2, 0.3) * (1 - root.seg(0.52, 0.58))
                    Text {
                        anchors.right: parent.right
                        anchors.bottom: parent.top
                        text: "μ = " + root.fmt(lnView.mean, 4)
                        color: Style.Theme.inferencia_foco
                        font.family: Style.Theme.fuente_mono
                        font.bold: true
                        font.pixelSize: Math.max(9, 10 * root.u)
                    }
                }
                Repeater {
                    model: lnView.xs.length
                    delegate: Item {
                        id: lnColumn
                        required property int index
                        readonly property real v: lnView.current(index)
                        x: index * (lnView.cw + 6 * root.u)
                        width: lnView.cw
                        height: parent.height
                        Rectangle {
                            x: parent.width * 0.15
                            width: parent.width * 0.7
                            y: lnView.chartH / 2 - Math.max(0, lnColumn.v) * lnView.k
                            height: Math.max(1, Math.abs(lnColumn.v) * lnView.k)
                            radius: 2
                            color: lnView.affine > 0.5 ? Style.Theme.inferencia_resultado
                                   : (lnView.divide > 0.5 ? Style.Theme.inferencia_transformacion
                                      : (lnView.center > 0.5 ? Style.Theme.inferencia_foco : Style.Theme.inferencia_estructura))
                        }
                        Text {
                            y: lnView.chartH + 4 * root.u
                            width: parent.width + 8 * root.u
                            x: -4 * root.u
                            horizontalAlignment: Text.AlignHCenter
                            text: root.fmt(lnColumn.v, 2)
                            color: Style.Theme.texto_primario
                            font.family: Style.Theme.fuente_mono
                            font.pixelSize: Math.max(7, 9 * root.u)
                        }
                        Text {
                            y: lnView.chartH + 18 * root.u
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "d" + root.sub(lnColumn.index)
                            color: Style.Theme.texto_terciario
                            font.pixelSize: Math.max(7, 8 * root.u)
                        }
                    }
                }
            }
            Column {
                x: lnView.plotW + 18 * root.u
                width: parent.width - x
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5 * root.u
                Equation {
                    visible: lnView.hasAddends
                    reveal: root.seg(0.02, 0.12)
                    accent: Style.Theme.inferencia_estructura
                    text: "x = " + root.demo.a_label + " + " + root.demo.b_label + "  →  x[0] = " + root.fmt(lnView.a[0], 3) + " " + root.signed(lnView.b[0], 3) + " = " + root.fmt(lnView.xs[0], 3)
                }
                Equation {
                    reveal: root.seg(0.2, 0.3)
                    accent: Style.Theme.inferencia_foco
                    text: "μ = (1/" + root.demo.size + ") Σ x = " + root.fmt(lnView.mean, 4)
                }
                Equation {
                    reveal: root.seg(0.5, 0.6)
                    accent: Style.Theme.inferencia_transformacion
                    text: "σ = √(" + root.fmt(root.demo.variance, 4) + " + ε) = " + root.fmt(lnView.std, 4)
                }
                Equation {
                    reveal: root.seg(0.74, 0.82)
                    accent: Style.Theme.inferencia_resultado
                    text: "x̂[0] = (" + root.fmt(lnView.xs[0], 3) + " − " + root.fmt(lnView.mean, 3) + ") / " + root.fmt(lnView.std, 3) + " = " + root.fmt(lnView.normalized[0], 3)
                }
                Equation {
                    reveal: root.seg(0.84, 0.94)
                    accent: Style.Theme.inferencia_resultado
                    text: "y[0] = " + root.fmt(lnView.gamma[0], 3) + "·" + root.fmt(lnView.normalized[0], 3) + " " + root.signed(lnView.beta[0], 3) + " = " + root.fmt(lnView.output[0], 3)
                }
            }
        }
    }

    Component {
        id: activationComponent
        Item {
            id: actView
            readonly property var inputs: root.list(root.demo.inputs)
            readonly property var outputs: root.list(root.demo.outputs)
            readonly property string name: String(root.demo.name || "ReLU")
            function phi(v) {
                var n = name.toLowerCase()
                if (n.indexOf("gelu") >= 0)
                    return 0.5 * v * (1 + Math.tanh(Math.sqrt(2 / Math.PI) * (v + 0.044715 * v * v * v)))
                if (n.indexOf("silu") >= 0 || n.indexOf("swish") >= 0)
                    return v / (1 + Math.exp(-v))
                return Math.max(0, v)
            }
            function local(i) {
                var start = 0.15 + 0.7 * i / Math.max(1, inputs.length)
                return root.seg(start, start + 0.7 / Math.max(1, inputs.length))
            }
            readonly property int active: Math.min(inputs.length - 1, Math.floor(root.seg(0.15, 0.85) * inputs.length))
            Connections {
                target: root
                function onTChanged() { curve.requestPaint() }
            }
            RowLayout {
                anchors.fill: parent
                spacing: 16 * root.u
                Canvas {
                    id: curve
                    Layout.preferredWidth: parent.width * 0.5
                    Layout.fillHeight: true
                    property color lineColor: Style.Theme.inferencia_transformacion
                    property color axisColor: Style.Theme.borde_medio
                    property color pointColor: Style.Theme.inferencia_foco
                    property color doneColor: Style.Theme.inferencia_resultado
                    property color inkColor: Style.Theme.texto_secundario_fuerte
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var w = width, h = height
                        var inputs = actView.inputs
                        var lo = -1, hi = 1
                        for (var i = 0; i < inputs.length; ++i) { lo = Math.min(lo, root.num(inputs[i])); hi = Math.max(hi, root.num(inputs[i])) }
                        var pad = (hi - lo) * 0.1
                        lo -= pad; hi += pad
                        var ylo = Math.min(-0.3, actView.phi(lo)), yhi = Math.max(actView.phi(hi), 0.5)
                        function px(v) { return (v - lo) / (hi - lo) * w }
                        function py(v) { return h - 12 - (v - ylo) / (yhi - ylo) * (h - 24) }
                        ctx.strokeStyle = axisColor; ctx.lineWidth = 1
                        ctx.beginPath(); ctx.moveTo(0, py(0)); ctx.lineTo(w, py(0)); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(px(0), 0); ctx.lineTo(px(0), h); ctx.stroke()
                        ctx.strokeStyle = lineColor; ctx.lineWidth = 2.5
                        ctx.beginPath()
                        for (var s = 0; s <= 80; ++s) {
                            var v = lo + (hi - lo) * s / 80
                            if (s === 0) ctx.moveTo(px(v), py(actView.phi(v))); else ctx.lineTo(px(v), py(actView.phi(v)))
                        }
                        ctx.stroke()
                        for (var k = 0; k < inputs.length; ++k) {
                            var p = actView.local(k)
                            if (p <= 0) continue
                            var xin = root.num(inputs[k])
                            var yout = root.num(actView.outputs[k])
                            var yy = root.lerp(0, yout, root.ease(p))
                            ctx.fillStyle = p >= 1 ? doneColor : pointColor
                            ctx.beginPath(); ctx.arc(px(xin), py(yy), p >= 1 ? 4 : 6, 0, 2 * Math.PI); ctx.fill()
                            if (p < 1) {
                                ctx.setLineDash([3, 3]); ctx.strokeStyle = pointColor; ctx.lineWidth = 1
                                ctx.beginPath(); ctx.moveTo(px(xin), py(0)); ctx.lineTo(px(xin), py(yy)); ctx.stroke()
                                ctx.setLineDash([])
                            }
                        }
                        ctx.fillStyle = inkColor
                        ctx.font = "bold " + Math.round(12 * root.u) + "px sans-serif"
                        ctx.fillText("φ = " + actView.name, 8, 16)
                    }
                }
                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2 * root.u
                    Tag { text: "H → φ(H)   (" + actView.inputs.length + " de " + root.demo.size + " neuronas)" }
                    Grid {
                        columns: 2
                        columnSpacing: 12 * root.u
                        rowSpacing: 2 * root.u
                        Repeater {
                            model: actView.inputs
                            delegate: Text {
                                id: actRow
                                required property int index
                                required property var modelData
                                readonly property real p: actView.local(index)
                                text: root.fmt(modelData, 3) + "  →  " + (p >= 0.6 ? root.fmt(actView.outputs[index], 3) : "?")
                                color: p >= 1 && Math.abs(root.num(actView.outputs[index])) < 1e-6 ? Style.Theme.error_texto
                                       : (index === actView.active && root.t < 0.88 ? Style.Theme.inferencia_foco : Style.Theme.texto_primario)
                                font.family: Style.Theme.fuente_mono
                                font.bold: index === actView.active && root.t < 0.88
                                font.pixelSize: Math.max(9, 10.5 * root.u)
                                opacity: 0.4 + 0.6 * Math.min(1, p * 2)
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: ffnComponent
        Item {
            id: ffnView
            readonly property var input: root.list(root.demo.input)
            readonly property var pre: root.list(root.demo.pre)
            readonly property var act: root.list(root.demo.act)
            readonly property var output: root.list(root.demo.output)
            readonly property real stripH: Math.max(22 * root.u, (height - 3 * 30 * root.u) / 3)
            readonly property real narrowW: width * 0.42
            readonly property real wideW: width * 0.9
            readonly property real expand: root.ease(root.seg(0.18, 0.34))
            readonly property real hidden: root.ease(root.seg(0.3, 0.46))
            readonly property real activate: root.ease(root.seg(0.5, 0.68))
            readonly property real compress: root.ease(root.seg(0.7, 0.84))
            readonly property real out: root.ease(root.seg(0.82, 0.96))
            readonly property real maxIn: Math.max(root.maxAbsOf(input), 1e-6)
            readonly property real maxHidden: Math.max(root.maxAbsOf(pre), 1e-6)
            readonly property real maxOut: Math.max(root.maxAbsOf(output), 1e-6)

            Column {
                anchors.centerIn: parent
                spacing: 0
                FfnStrip {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: ffnView.narrowW
                    height: ffnView.stripH
                    values: ffnView.input
                    maxAbs: ffnView.maxIn
                    reveal: root.seg(0, 0.15)
                    title: "N₂ (" + root.demo.d_model + ")"
                    accent: Style.Theme.inferencia_estructura
                }
                Canvas {
                    width: ffnView.wideW
                    height: 30 * root.u
                    property real fill: ffnView.expand
                    property color tint: Style.Theme.inferencia_transformacion
                    onFillChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset()
                        var w = width, h = height
                        var a = (w - ffnView.narrowW) / 2
                        ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.12 + 0.3 * fill)
                        ctx.beginPath(); ctx.moveTo(a, 0); ctx.lineTo(w - a, 0); ctx.lineTo(w, h); ctx.lineTo(0, h); ctx.closePath(); ctx.fill()
                        ctx.fillStyle = tint
                        ctx.font = "bold " + Math.round(11 * root.u) + "px sans-serif"
                        ctx.fillText("· W₁ + b₁  (" + root.demo.d_model + " → " + root.demo.d_ff + ")", w / 2 - 70, h / 2 + 4)
                    }
                }
                Item {
                    width: ffnView.wideW
                    height: ffnView.stripH
                    FfnStrip {
                        anchors.fill: parent
                        values: ffnView.pre
                        maxAbs: ffnView.maxHidden
                        reveal: ffnView.hidden
                        opacity: 1 - ffnView.activate
                        title: "H"
                        accent: Style.Theme.inferencia_transformacion
                    }
                    FfnStrip {
                        anchors.fill: parent
                        values: ffnView.act
                        maxAbs: ffnView.maxHidden
                        reveal: 1
                        opacity: ffnView.activate
                        title: ffnView.activate > 0.5 ? String(root.demo.name) + "(H)" : ""
                        accent: Style.Theme.inferencia_foco
                    }
                }
                Canvas {
                    width: ffnView.wideW
                    height: 30 * root.u
                    property real fill: ffnView.compress
                    property color tint: Style.Theme.inferencia_resultado
                    onFillChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset()
                        var w = width, h = height
                        var a = (w - ffnView.narrowW) / 2
                        ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.12 + 0.3 * fill)
                        ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(w, 0); ctx.lineTo(w - a, h); ctx.lineTo(a, h); ctx.closePath(); ctx.fill()
                        ctx.fillStyle = tint
                        ctx.font = "bold " + Math.round(11 * root.u) + "px sans-serif"
                        ctx.fillText("· W₂ + b₂  (" + root.demo.d_ff + " → " + root.demo.d_model + ")", w / 2 - 70, h / 2 + 4)
                    }
                }
                FfnStrip {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: ffnView.narrowW
                    height: ffnView.stripH
                    values: ffnView.output
                    maxAbs: ffnView.maxOut
                    reveal: ffnView.out
                    title: "F (" + root.demo.d_model + ")"
                    accent: Style.Theme.inferencia_resultado
                }
            }
            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                width: parent.width * 0.22
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignRight
                opacity: root.seg(0.55, 0.65)
                text: {
                    var zeroed = 0
                    for (var i = 0; i < ffnView.act.length; ++i) if (Math.abs(root.num(ffnView.act[i])) < 1e-6) ++zeroed
                    return zeroed + " de " + ffnView.act.length + " neuronas visibles quedan en 0 tras " + root.demo.name
                }
                color: Style.Theme.inferencia_foco
                font.bold: true
                font.pixelSize: Math.max(9, 10 * root.u)
            }
        }
    }

    Component {
        id: stackComponent
        Item {
            id: stackView
            readonly property var layers: root.list(root.demo.layers)
            readonly property int floors: layers.length
            readonly property real floorH: Math.max(20 * root.u, Math.min(34 * root.u, (height - 10 * root.u) / Math.max(1, floors) - 5 * root.u))
            readonly property real climb: root.ease(root.seg(0.08, 0.88)) * Math.max(0, floors - 1)
            readonly property real maxAbs: Math.max(root.maxAbsOf(layers.map(function(layer) { return layer.values })), 1e-6)
            readonly property real cw: root.cellWidth(root.list(layers.length ? layers[0].values : []).length, width - 330 * root.u, 62)
            Repeater {
                model: stackView.layers
                delegate: Item {
                    id: floorItem
                    required property int index
                    required property var modelData
                    readonly property bool reached: stackView.climb >= index - 0.02
                    readonly property bool here: Math.round(stackView.climb) === index
                    y: stackView.height - (index + 1) * (stackView.floorH + 5 * root.u)
                    width: stackView.width
                    height: stackView.floorH
                    Rectangle {
                        anchors.fill: parent
                        radius: 6 * root.u
                        color: floorItem.here ? Qt.alpha(Style.Theme.acento, 0.12) : "transparent"
                        border.color: floorItem.reached ? Style.Theme.acento : Style.Theme.borde_suave
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8 * root.u
                        spacing: 4 * root.u
                        Text {
                            width: 54 * root.u
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(floorItem.modelData.label)
                            color: Style.Theme.texto_primario
                            font.bold: true
                            font.family: "Cambria Math"
                            font.pixelSize: Math.max(11, 13 * root.u)
                        }
                        Repeater {
                            model: root.list(floorItem.modelData.values)
                            delegate: Cell {
                                required property var modelData
                                width: stackView.cw
                                height: stackView.floorH - 6 * root.u
                                value: modelData
                                maxAbs: stackView.maxAbs
                                reveal: floorItem.reached ? 1 : 0.15
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: floorItem.reached ? 1 : 0.2
                            text: "  ‖·‖ = " + root.fmt(floorItem.modelData.norm, 3)
                                  + (floorItem.index > 0 ? "   Δ " + root.signed(root.num(floorItem.modelData.norm) - root.num(stackView.layers[floorItem.index - 1].norm), 3) : "")
                            color: Style.Theme.texto_secundario_fuerte
                            font.family: Style.Theme.fuente_mono
                            font.pixelSize: Math.max(9, 10 * root.u)
                        }
                    }
                }
            }
            Rectangle {
                x: stackView.width - width - 8 * root.u
                y: stackView.height - (stackView.climb + 1) * (stackView.floorH + 5 * root.u) + (stackView.floorH - height) / 2
                width: elevatorText.implicitWidth + 16 * root.u
                height: 24 * root.u
                radius: 12 * root.u
                color: Style.Theme.inferencia_foco
                Text {
                    id: elevatorText
                    anchors.centerIn: parent
                    text: "▲ «" + String(root.demo.token_label || "") + "»"
                    color: Style.Theme.inferencia_sobre_foco
                    font.bold: true
                    font.pixelSize: Math.max(9, 10 * root.u)
                }
            }
        }
    }

    // ===================================================== MÓDULOS 6-8
    Component {
        id: shiftComponent
        Item {
            id: shiftView
            readonly property var inputs: root.list(root.demo.inputs)
            readonly property var targets: root.list(root.demo.targets)
            readonly property var source: root.list(root.demo.source)
            readonly property bool training: targets.length > 0
            readonly property int count: Math.max(inputs.length, targets.length) + (training ? 0 : 1)
            readonly property real cw: root.cellWidth(Math.max(1, count), width - 140 * root.u, 74)
            readonly property real stride: cw + 6 * root.u
            readonly property int highlight: Number(root.demo.highlight || 0)
            Column {
                anchors.centerIn: parent
                spacing: 10 * root.u
                Row {
                    visible: shiftView.source.length > 0
                    spacing: 6 * root.u
                    opacity: root.seg(0, 0.15)
                    Tag { width: 110 * root.u; text: "src → encoder"; anchors.verticalCenter: parent.verticalCenter; color: Style.Theme.inferencia_contexto }
                    Repeater {
                        model: shiftView.source
                        delegate: Chip {
                            required property var modelData
                            width: shiftView.cw
                            label: String(modelData.text)
                            caption: String(modelData.id)
                            fill: Qt.alpha(Style.Theme.inferencia_contexto, 0.14)
                            edge: Style.Theme.inferencia_contexto
                            ink: Style.Theme.texto_primario
                        }
                    }
                }
                Row {
                    spacing: 6 * root.u
                    Tag { width: 110 * root.u; text: shiftView.training ? "tgt_in → decoder" : "prefijo"; anchors.verticalCenter: parent.verticalCenter; color: Style.Theme.acento }
                    Item {
                        width: shiftView.count * shiftView.stride
                        height: 40 * root.u
                        Repeater {
                            model: shiftView.inputs
                            delegate: Chip {
                                id: inputChip
                                required property int index
                                required property var modelData
                                readonly property real slide: shiftView.training ? root.ease(root.seg(0.25, 0.5)) : 1
                                x: shiftView.training ? (index === 0 ? (1 - root.ease(root.seg(0.42, 0.58))) * -60 * root.u : (index - 1 + slide) * shiftView.stride)
                                                      : index * shiftView.stride
                                width: shiftView.cw
                                label: String(modelData.text)
                                caption: String(modelData.id)
                                opacity: shiftView.training ? (index === 0 ? root.seg(0.42, 0.55) : root.seg(0.25, 0.32))
                                                            : root.seg(0.05 + 0.4 * index / Math.max(1, shiftView.inputs.length), 0.5)
                                fill: index === shiftView.highlight && root.t >= 0.6 ? Style.Theme.acento : Style.Theme.acento_fondo
                                ink: index === shiftView.highlight && root.t >= 0.6 ? Style.Theme.texto_sobre_acento : Style.Theme.acento_texto
                                edge: Style.Theme.acento
                            }
                        }
                        Rectangle {
                            visible: !shiftView.training
                            x: shiftView.inputs.length * shiftView.stride
                            width: shiftView.cw
                            height: 40 * root.u
                            radius: 7 * root.u
                            color: "transparent"
                            border.color: Style.Theme.inferencia_foco
                            border.width: 2
                            opacity: root.seg(0.6, 0.7) * (0.55 + 0.45 * Math.abs(Math.sin(root.t * 12)))
                            Text { anchors.centerIn: parent; text: "ŷ ?"; color: Style.Theme.inferencia_foco; font.bold: true; font.pixelSize: Math.max(11, 13 * root.u) }
                        }
                    }
                }
                Row {
                    visible: shiftView.training
                    spacing: 6 * root.u
                    Tag { width: 110 * root.u; text: "tgt_out (objetivo)"; anchors.verticalCenter: parent.verticalCenter; color: Style.Theme.inferencia_resultado }
                    Repeater {
                        model: shiftView.targets
                        delegate: Chip {
                            required property int index
                            required property var modelData
                            width: shiftView.cw
                            label: String(modelData.text)
                            caption: "predecir " + String(modelData.id)
                            opacity: root.seg(0, 0.2)
                            fill: index === shiftView.highlight && root.t >= 0.6 ? Style.Theme.inferencia_resultado : Style.Theme.exito_fondo
                            ink: index === shiftView.highlight && root.t >= 0.6 ? Style.Theme.inferencia_sobre_resultado : Style.Theme.exito_texto
                            edge: Style.Theme.inferencia_resultado
                            border.width: root.clamp01((root.t - 0.6) / 0.35 * shiftView.targets.length - index) > 0 ? 2 : 1
                        }
                    }
                }
                Text {
                    opacity: shiftView.training ? root.seg(0.62, 0.8) : root.seg(0.65, 0.8)
                    text: shiftView.training
                          ? "En la posición " + shiftView.highlight + " el decoder lee «" + String(shiftView.inputs[shiftView.highlight] ? shiftView.inputs[shiftView.highlight].text : "")
                            + "» y debe predecir «" + String(shiftView.targets[shiftView.highlight] ? shiftView.targets[shiftView.highlight].text : "") + "»."
                          : "Solo existen " + shiftView.inputs.length + " tokens; la posición " + shiftView.inputs.length + " es la que el modelo va a generar."
                    color: Style.Theme.texto_secundario_fuerte
                    font.pixelSize: Math.max(10, 11 * root.u)
                }
            }
        }
    }

    Component {
        id: causalMaskComponent
        Item {
            id: causalView
            readonly property var labels: root.list(root.demo.labels)
            readonly property var mask: root.list(root.demo.mask)
            readonly property int n: labels.length
            readonly property real cs: Math.max(14 * root.u, Math.min(34 * root.u, (height - 34 * root.u) / Math.max(1, n)))
            readonly property real scan: root.seg(0.05, 0.86) * n * n
            readonly property int highlight: Number(root.demo.highlight || 0)
            RowLayout {
                anchors.fill: parent
                spacing: 20 * root.u
                Column {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2
                    Row {
                        spacing: 2
                        Item { width: 70 * root.u; height: 16 * root.u }
                        Repeater {
                            model: causalView.labels
                            delegate: Text {
                                required property int index
                                required property var modelData
                                width: causalView.cs
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: "j" + root.sub(index)
                                color: Style.Theme.texto_terciario
                                font.pixelSize: Math.max(7, 8.5 * root.u)
                            }
                        }
                    }
                    Repeater {
                        model: causalView.n
                        delegate: Row {
                            id: causalRow
                            required property int index
                            spacing: 2
                            Text {
                                width: 70 * root.u
                                height: causalView.cs
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                text: "i" + root.sub(causalRow.index) + " " + String(causalView.labels[causalRow.index])
                                color: causalRow.index === causalView.highlight && root.t >= 0.86 ? Style.Theme.acento_fuerte : Style.Theme.texto_secundario_fuerte
                                font.bold: causalRow.index === causalView.highlight && root.t >= 0.86
                                font.pixelSize: Math.max(8, 9 * root.u)
                            }
                            Repeater {
                                model: causalView.n
                                delegate: Rectangle {
                                    id: causalCell
                                    required property int index
                                    readonly property bool allowed: Boolean(root.list(causalView.mask[causalRow.index])[index])
                                    readonly property real reveal: root.clamp01(causalView.scan - (causalRow.index * causalView.n + index))
                                    width: causalView.cs
                                    height: causalView.cs
                                    radius: 3
                                    color: reveal <= 0 ? Style.Theme.chip_fondo : (allowed ? Style.Theme.exito_fondo : Style.Theme.error_fondo)
                                    border.color: causalRow.index === causalView.highlight && root.t >= 0.86 ? Style.Theme.acento
                                                  : (allowed ? Style.Theme.inferencia_resultado : Style.Theme.inferencia_error)
                                    border.width: causalRow.index === causalView.highlight && root.t >= 0.86 ? 2 : (reveal > 0 ? 1 : 0)
                                    Text {
                                        anchors.centerIn: parent
                                        opacity: causalCell.reveal
                                        text: causalCell.allowed ? "1" : "0"
                                        color: causalCell.allowed ? Style.Theme.exito_texto : Style.Theme.error_texto
                                        font.bold: true
                                        font.pixelSize: Math.max(8, causalView.cs * 0.42)
                                    }
                                }
                            }
                        }
                    }
                }
                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 8 * root.u
                    Equation {
                        readonly property int k: root.t >= 0.86
                                                 ? causalView.highlight * causalView.n + causalView.highlight
                                                 : Math.min(causalView.n * causalView.n - 1, Math.max(0, Math.floor(causalView.scan)))
                        readonly property int i: Math.floor(k / Math.max(1, causalView.n))
                        readonly property int j: k % Math.max(1, causalView.n)
                        readonly property bool ok: causalView.mask.length ? Boolean(root.list(causalView.mask[i])[j]) : true
                        visible: causalView.n > 0
                        accent: ok ? Style.Theme.inferencia_resultado : Style.Theme.inferencia_error
                        text: root.demo.causal ? "M[" + i + "," + j + "] = (" + j + " ≤ " + i + ") = " + (ok ? "1 · puede mirar" : "0 · futuro bloqueado")
                                               : "M[" + i + "," + j + "] = 1 · sin máscara causal"
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        opacity: root.seg(0.86, 1)
                        text: "La fila " + causalView.highlight + " («" + String(causalView.labels[causalView.highlight] || "") + "») ve "
                              + root.list(causalView.mask[causalView.highlight]).filter(function(v) { return v }).length
                              + " de " + causalView.n + " posiciones."
                        color: Style.Theme.texto_secundario_fuerte
                        font.pixelSize: Math.max(10, 11 * root.u)
                    }
                }
            }
        }
    }

    Component {
        id: crossEntropyComponent
        Item {
            id: ceView
            readonly property var items: root.list(root.demo.items)
            readonly property real maxLogit: Math.max(root.maxAbsOf(items.map(function(item) { return item.logit })), 1e-6)
            readonly property real maxProb: Math.max(root.maxAbsOf(items.map(function(item) { return item.prob })), 1e-6)
            readonly property real toProb: root.ease(root.seg(0.28, 0.48))
            readonly property real pick: root.seg(0.55, 0.68)
            readonly property real logPhase: root.ease(root.seg(0.75, 0.92))
            onLogPhaseChanged: logCurve.requestPaint()
            RowLayout {
                anchors.fill: parent
                spacing: 16 * root.u
                Column {
                    Layout.preferredWidth: parent.width * 0.55
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4 * root.u
                    Tag { text: ceView.toProb < 0.5 ? "logits z (" + root.demo.vocabulary + " en total)" : "p = softmax(z)" }
                    Repeater {
                        model: ceView.items
                        delegate: Row {
                            id: ceRow
                            required property int index
                            required property var modelData
                            readonly property bool isTarget: Boolean(modelData.target)
                            spacing: 6 * root.u
                            opacity: isTarget ? 1 : 1 - 0.6 * ceView.pick
                            Text {
                                width: 80 * root.u
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                text: (ceRow.isTarget ? "★ " : "") + "«" + ceRow.modelData.text + "»"
                                color: ceRow.isTarget ? Style.Theme.inferencia_resultado : Style.Theme.texto_secundario_fuerte
                                font.bold: ceRow.isTarget
                                font.pixelSize: Math.max(9, 10 * root.u)
                            }
                            Rectangle {
                                readonly property real full: ceView.width * 0.55 - 170 * root.u
                                width: Math.max(2, root.lerp(Math.abs(root.num(ceRow.modelData.logit)) / ceView.maxLogit,
                                                             root.num(ceRow.modelData.prob) / ceView.maxProb, ceView.toProb) * full)
                                height: 16 * root.u
                                radius: 3
                                anchors.verticalCenter: parent.verticalCenter
                                color: ceRow.isTarget && ceView.pick > 0 ? Style.Theme.inferencia_resultado
                                       : (ceView.toProb > 0.5 ? Style.Theme.inferencia_estructura : root.divColor(ceRow.modelData.logit, ceView.maxLogit))
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: ceView.toProb < 0.5 ? "z = " + root.fmt(ceRow.modelData.logit, 3) : "p = " + root.fmt(ceRow.modelData.prob, 4)
                                color: Style.Theme.texto_primario
                                font.family: Style.Theme.fuente_mono
                                font.pixelSize: Math.max(8, 9.5 * root.u)
                            }
                        }
                    }
                }
                Column {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4 * root.u
                    Canvas {
                        id: logCurve
                        width: parent.width
                        height: parent.height - 34 * root.u
                        property color lineColor: Style.Theme.inferencia_error
                        property color axisColor: Style.Theme.borde_medio
                        property color pointColor: Style.Theme.inferencia_resultado
                        property color inkColor: Style.Theme.texto_secundario_fuerte
                        onPaint: {
                            var ctx = getContext("2d"); ctx.reset()
                            var w = width, h = height
                            var ymax = Math.max(4, root.num(root.demo.loss) * 1.2)
                            function px(p) { return 10 + p * (w - 20) }
                            function py(v) { return h - 14 - v / ymax * (h - 28) }
                            ctx.strokeStyle = axisColor; ctx.lineWidth = 1
                            ctx.beginPath(); ctx.moveTo(10, py(0)); ctx.lineTo(w - 10, py(0)); ctx.stroke()
                            ctx.strokeStyle = lineColor; ctx.lineWidth = 2
                            ctx.globalAlpha = 0.25 + 0.75 * ceView.logPhase
                            ctx.beginPath()
                            for (var s = 1; s <= 100; ++s) {
                                var p = s / 100
                                var v = Math.min(ymax, -Math.log(p))
                                if (s === 1) ctx.moveTo(px(p), py(v)); else ctx.lineTo(px(p), py(v))
                            }
                            ctx.stroke()
                            ctx.globalAlpha = 1
                            ctx.fillStyle = inkColor
                            ctx.font = "bold " + Math.round(11 * root.u) + "px sans-serif"
                            ctx.fillText("−log p", 14, 14)
                            ctx.fillText("p → 1", w - 50, h - 2)
                            if (ceView.logPhase > 0) {
                                var target = root.num(root.demo.target ? root.demo.target.prob : 0)
                                var loss = root.num(root.demo.loss)
                                var x = px(target)
                                var y = py(Math.min(ymax, loss * ceView.logPhase))
                                ctx.setLineDash([4, 3]); ctx.strokeStyle = pointColor
                                ctx.beginPath(); ctx.moveTo(x, py(0)); ctx.lineTo(x, y); ctx.stroke(); ctx.setLineDash([])
                                ctx.fillStyle = pointColor
                                ctx.beginPath(); ctx.arc(x, y, 6, 0, 2 * Math.PI); ctx.fill()
                            }
                        }
                    }
                    Equation {
                        reveal: root.seg(0.85, 0.95)
                        accent: Style.Theme.inferencia_error
                        text: "L = −log(" + root.fmt(root.demo.target ? root.demo.target.prob : 0, 4) + ") = " + root.fmt(root.demo.loss, 4)
                    }
                }
            }
        }
    }

    Component {
        id: samplingComponent
        Item {
            id: sampleView
            readonly property var items: root.list(root.demo.items)
            readonly property var stages: root.list(root.demo.stages)
            readonly property int stageCount: Math.max(1, stages.length)
            readonly property int stageIndex: Math.min(stageCount - 1, Math.floor(root.t * stageCount * 0.9999))
            readonly property string stage: String(stages[stageIndex] || "temperature")
            readonly property real lt: root.clamp01(root.t * stageCount - stageIndex)
            readonly property real rowH: Math.max(14 * root.u, Math.min(22 * root.u, (height - 30 * root.u) / Math.max(1, items.length) - 3 * root.u))
            readonly property real barW: width * 0.42
            readonly property int topK: Number(root.demo.top_k || 1)
            readonly property real topP: Number(root.demo.top_p || 1)
            function stageDone(name) {
                var index = stages.indexOf(name)
                return index >= 0 && (index < stageIndex || (index === stageIndex && lt >= 0.85))
            }
            function stageStarted(name) {
                var index = stages.indexOf(name)
                return index >= 0 && index <= stageIndex
            }
            readonly property real morph: stage === "temperature" ? root.ease(root.segOf(lt, 0.15, 0.75)) : 1
            readonly property real cut: stage === "top_k" ? root.ease(root.segOf(lt, 0.2, 0.7)) : (stageDone("top_k") ? 1 : 0)
            readonly property real fill: stage === "top_p" ? root.segOf(lt, 0.1, 0.8) * items.length : (stageDone("top_p") ? items.length : 0)
            readonly property real maxProb: {
                var m = 1e-9
                for (var i = 0; i < items.length; ++i)
                    m = Math.max(m, root.num(items[i].prob_raw), root.num(items[i].prob_t), root.num(items[i].prob_k))
                return m
            }
            function barValue(item, index) {
                if (stage === "top_p" || stageDone("top_p"))
                    return item.kept_k ? root.num(item.cumulative) : 0
                if (stage === "top_k" || stageDone("top_k"))
                    return item.kept_k ? root.num(item.prob_k) : root.num(item.prob_t) * (1 - cut)
                if (stages.indexOf("temperature") < 0)
                    return root.num(item.prob_t)
                return root.lerp(root.num(item.prob_raw), root.num(item.prob_t), morph)
            }
            function barScale() {
                return stage === "top_p" || stageDone("top_p") ? 1 : maxProb
            }
            Column {
                spacing: 3 * root.u
                Row {
                    spacing: 6 * root.u
                    Tag { width: 90 * root.u; text: "candidato" }
                    Tag { width: 120 * root.u; text: sampleView.stageStarted("temperature") ? "z → z/T" : "z/T" }
                    Tag {
                        width: sampleView.barW
                        text: sampleView.stage === "top_p" || sampleView.stageDone("top_p") ? "probabilidad acumulada (P = " + root.fmt(sampleView.topP, 2) + ")"
                              : (sampleView.stage === "top_k" ? "probabilidad tras Top-K (K = " + sampleView.topK + ")" : "probabilidad (T = " + root.fmt(root.demo.temperature, 2) + ")")
                    }
                }
                Repeater {
                    model: sampleView.items
                    delegate: Row {
                        id: sampleRow
                        required property int index
                        required property var modelData
                        readonly property bool outByK: !modelData.kept_k
                                                       && (sampleView.stages.indexOf("top_k") < 0
                                                           ? sampleView.stage === "top_p"
                                                           : sampleView.cut > 0.5)
                        readonly property bool outByP: sampleView.fill > index + 0.5 && !modelData.kept_p && !outByK
                        readonly property bool out: outByK || outByP
                        spacing: 6 * root.u
                        opacity: out ? 0.38 : 1
                        Text {
                            width: 90 * root.u
                            height: sampleView.rowH
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                            text: (sampleRow.index + 1) + ". «" + sampleRow.modelData.text + "»"
                            color: Style.Theme.texto_primario
                            font.strikeout: sampleRow.out
                            font.pixelSize: Math.max(8, 9.5 * root.u)
                        }
                        Text {
                            width: 120 * root.u
                            height: sampleView.rowH
                            verticalAlignment: Text.AlignVCenter
                            text: sampleRow.out ? "−∞"
                                  : (sampleView.stageStarted("temperature") && sampleView.stage === "temperature"
                                     ? root.fmt(sampleRow.modelData.logit, 2) + " → " + (sampleView.morph > 0.5 ? root.fmt(sampleRow.modelData.scaled, 2) : "…")
                                     : root.fmt(sampleRow.modelData.scaled, 3))
                            color: sampleRow.out ? Style.Theme.error_texto : Style.Theme.texto_secundario_fuerte
                            font.family: Style.Theme.fuente_mono
                            font.pixelSize: Math.max(8, 9.5 * root.u)
                        }
                        Item {
                            width: sampleView.barW
                            height: sampleView.rowH
                            Rectangle {
                                width: parent.width
                                height: parent.height
                                radius: 3
                                color: Style.Theme.chip_fondo
                            }
                            Rectangle {
                                readonly property real v: sampleView.barValue(sampleRow.modelData, sampleRow.index)
                                readonly property real grow: sampleView.stage === "top_p" ? root.clamp01(sampleView.fill - sampleRow.index) : 1
                                width: Math.max(1, parent.width * root.clamp01(v / sampleView.barScale()) * grow)
                                height: parent.height
                                radius: 3
                                color: sampleRow.out ? Style.Theme.inferencia_error
                                       : (sampleView.stage === "top_p" ? Style.Theme.inferencia_contexto
                                          : (sampleView.stage === "top_k" ? Style.Theme.inferencia_foco : Style.Theme.inferencia_estructura))
                            }
                            Rectangle {
                                visible: sampleView.stage === "top_p" || sampleView.stageDone("top_p")
                                x: parent.width * sampleView.topP - 1
                                width: 2
                                height: parent.height + 3 * root.u
                                color: Style.Theme.inferencia_error
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 4 * root.u
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.fmt(sampleView.barValue(sampleRow.modelData, sampleRow.index), 3)
                                color: Style.Theme.texto_primario
                                font.family: Style.Theme.fuente_mono
                                font.pixelSize: Math.max(8, 9 * root.u)
                            }
                        }
                    }
                }
            }
            Rectangle {
                visible: sampleView.stage === "top_k" && sampleView.topK < sampleView.items.length
                x: 0
                y: 3 * root.u + (sampleView.rowH + 3 * root.u) * (sampleView.topK + 1) - 3 * root.u
                width: (90 + 120) * root.u + sampleView.barW + 12 * root.u
                height: 3 * root.u
                color: Style.Theme.inferencia_error
                opacity: sampleView.cut
                Text {
                    anchors.left: parent.right
                    anchors.leftMargin: 6 * root.u
                    anchors.verticalCenter: parent.verticalCenter
                    text: "corte K = " + sampleView.topK
                    color: Style.Theme.inferencia_error
                    font.bold: true
                    font.pixelSize: Math.max(9, 10 * root.u)
                }
            }
            Column {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - ((90 + 120) * root.u + sampleView.barW + 40 * root.u)
                spacing: 6 * root.u
                Equation {
                    visible: sampleView.stage === "temperature"
                    accent: Style.Theme.inferencia_estructura
                    reveal: root.segOf(sampleView.lt, 0.05, 0.2)
                    text: "zᵢ / " + root.fmt(root.demo.temperature, 2)
                }
                Equation {
                    visible: sampleView.stage === "top_k"
                    accent: Style.Theme.inferencia_foco
                    reveal: root.segOf(sampleView.lt, 0.7, 0.85)
                    text: root.demo.survivors_k + " de " + root.demo.vocabulary + " sobreviven"
                }
                Equation {
                    visible: sampleView.stage === "top_p"
                    accent: Style.Theme.inferencia_contexto
                    reveal: root.segOf(sampleView.lt, 0.8, 0.92)
                    text: "núcleo: " + root.demo.survivors_p + " tokens"
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    visible: sampleView.stage === "temperature"
                    opacity: root.segOf(sampleView.lt, 0.75, 0.9)
                    text: root.num(root.demo.temperature) < 1 ? "T < 1: el favorito gana más probabilidad."
                          : (root.num(root.demo.temperature) > 1 ? "T > 1: la probabilidad se reparte." : "T = 1: no cambia nada.")
                    color: Style.Theme.texto_secundario_fuerte
                    font.pixelSize: Math.max(9, 10 * root.u)
                }
            }
        }
    }

    Component {
        id: argmaxComponent
        Item {
            id: argView
            readonly property var items: root.list(root.demo.items)
            readonly property int chosen: Number(root.demo.chosen || 0)
            readonly property real scan: root.seg(0.05, 0.7) * items.length
            readonly property int scanned: Math.min(items.length - 1, Math.floor(scan))
            readonly property int best: {
                var b = 0
                for (var i = 1; i <= scanned; ++i)
                    if (root.num(items[i].prob) > root.num(items[b].prob)) b = i
                return b
            }
            readonly property real maxProb: Math.max(root.maxAbsOf(items.map(function(item) { return item.prob })), 1e-9)
            readonly property real chartH: Math.max(60 * root.u, height - 50 * root.u)
            readonly property real plotW: width * 0.66
            readonly property real cw: Math.max(20 * root.u, Math.min(80 * root.u, plotW / Math.max(1, items.length) - 8 * root.u))
            readonly property real win: root.ease(root.seg(0.75, 0.9))
            Repeater {
                model: argView.items
                delegate: Item {
                    id: argColumn
                    required property int index
                    required property var modelData
                    readonly property bool isBest: index === argView.best
                    readonly property bool isWinner: index === argView.chosen && argView.win > 0
                    x: index * (argView.cw + 8 * root.u)
                    width: argView.cw
                    height: argView.height
                    Rectangle {
                        x: 0
                        width: parent.width
                        readonly property real h: root.num(argColumn.modelData.prob) / argView.maxProb * argView.chartH * 0.85
                        y: argView.chartH - h - (argColumn.isWinner ? 10 * root.u * argView.win : 0)
                        height: h
                        radius: 3
                        color: argColumn.isWinner ? Style.Theme.inferencia_resultado
                               : (argColumn.isBest && root.t < 0.75 ? Style.Theme.inferencia_foco : Style.Theme.inferencia_estructura)
                        opacity: argColumn.index <= argView.scanned || root.t >= 0.7 ? 1 : 0.35
                        border.color: argColumn.index === argView.scanned && root.t < 0.7 ? Style.Theme.acento : "transparent"
                        border.width: 3
                        Text {
                            anchors.bottom: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (root.num(argColumn.modelData.prob) * 100).toFixed(1) + "%"
                            color: Style.Theme.texto_primario
                            font.family: Style.Theme.fuente_mono
                            font.pixelSize: Math.max(8, 9 * root.u)
                        }
                    }
                    Text {
                        y: argView.chartH + 4 * root.u
                        width: parent.width + 8 * root.u
                        x: -4 * root.u
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: "«" + argColumn.modelData.text + "»"
                        color: argColumn.isWinner ? Style.Theme.inferencia_resultado : Style.Theme.texto_secundario_fuerte
                        font.bold: argColumn.isWinner
                        font.pixelSize: Math.max(8, 9.5 * root.u)
                    }
                }
            }
            Column {
                x: argView.plotW + 16 * root.u
                width: parent.width - x
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.u
                Equation {
                    visible: root.t < 0.75
                    accent: Style.Theme.inferencia_foco
                    text: argView.items.length ? "mejor hasta ahora: «" + argView.items[argView.best].text + "»" : ""
                }
                Chip {
                    opacity: argView.win
                    scale: 0.6 + 0.4 * argView.win
                    label: argView.items.length ? "ŷ = «" + argView.items[argView.chosen].text + "»" : ""
                    caption: argView.items.length ? "id " + argView.items[argView.chosen].id + " · p = " + root.fmt(argView.items[argView.chosen].prob, 4) : ""
                    fill: Style.Theme.inferencia_resultado
                    ink: Style.Theme.inferencia_sobre_resultado
                    edge: Style.Theme.inferencia_resultado
                    fontScale: 1.2
                }
            }
        }
    }

    Component {
        id: appendComponent
        Item {
            id: appendView
            readonly property var prefix: root.list(root.demo.prefix)
            readonly property real cw: root.cellWidth(prefix.length + 1, width - 60 * root.u, 82)
            readonly property real stride: cw + 6 * root.u
            readonly property real fly: root.ease(root.seg(0.2, 0.6))
            Column {
                anchors.centerIn: parent
                spacing: 18 * root.u
                Item {
                    width: (appendView.prefix.length + 1) * appendView.stride
                    height: 90 * root.u
                    Repeater {
                        model: appendView.prefix
                        delegate: Chip {
                            required property int index
                            required property var modelData
                            x: index * appendView.stride
                            y: 46 * root.u
                            width: appendView.cw
                            label: String(modelData.text)
                            caption: String(modelData.id)
                            fill: Style.Theme.acento_fondo
                            ink: Style.Theme.acento_texto
                            edge: Style.Theme.acento
                        }
                    }
                    Rectangle {
                        x: appendView.prefix.length * appendView.stride
                        y: 46 * root.u
                        width: appendView.cw
                        height: 40 * root.u
                        radius: 7 * root.u
                        color: "transparent"
                        border.color: Style.Theme.inferencia_resultado
                        opacity: 1 - appendView.fly
                    }
                    Chip {
                        x: root.lerp(appendView.prefix.length * appendView.stride + 40 * root.u, appendView.prefix.length * appendView.stride, appendView.fly)
                        y: root.lerp(0, 46 * root.u, appendView.fly)
                        width: appendView.cw
                        label: String(root.demo.token ? root.demo.token.text : "")
                        caption: "ŷ · " + String(root.demo.token ? root.demo.token.id : "")
                        fill: Style.Theme.inferencia_resultado
                        ink: Style.Theme.inferencia_sobre_resultado
                        edge: Style.Theme.inferencia_resultado
                        opacity: root.seg(0.05, 0.2)
                    }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10 * root.u
                    opacity: root.seg(0.65, 0.8)
                    Equation {
                        accent: Style.Theme.acento
                        text: "prefijo: " + appendView.prefix.length + " → " + (appendView.prefix.length + 1) + " tokens"
                    }
                    Equation {
                        accent: Style.Theme.inferencia_contexto
                        reveal: root.seg(0.78, 0.92)
                        text: "↻ el decoder se ejecuta otra vez"
                    }
                }
            }
        }
    }

    // ====================================================== aprendizaje
    Component {
        id: backwardComponent
        Item {
            id: backView
            readonly property var gradient: root.list(root.demo.gradient)
            readonly property var parameters: root.list(root.demo.parameters)
            readonly property real maxG: Math.max(root.maxAbsOf(gradient), 1e-12)
            readonly property real cw: root.cellWidth(gradient.length, width * 0.7 - 120 * root.u, 74)
            readonly property real pulse: root.ease(root.seg(0.08, 0.5))
            readonly property real maxNorm: Math.max(root.maxAbsOf(parameters.map(function(item) { return item.norm })), 1e-12)
            Column {
                anchors.fill: parent
                spacing: 12 * root.u
                Item {
                    width: parent.width
                    height: 64 * root.u
                    Row {
                        id: gradRow
                        y: 18 * root.u
                        spacing: 4 * root.u
                        Tag { width: 116 * root.u; text: "∂L/∂" + root.demo.parameter; elide: Text.ElideMiddle; anchors.verticalCenter: parent.verticalCenter; color: Style.Theme.inferencia_error }
                        Repeater {
                            model: backView.gradient
                            delegate: Cell {
                                required property int index
                                required property var modelData
                                readonly property real arrival: 1 - (index + 1) / (backView.gradient.length + 1)
                                width: backView.cw
                                height: 28 * root.u
                                value: modelData
                                maxAbs: backView.maxG
                                digits: 4
                                reveal: backView.pulse >= arrival ? 1 : 0.15
                            }
                        }
                    }
                    Rectangle {
                        anchors.right: parent.right
                        y: 10 * root.u
                        width: lossText.implicitWidth + 24 * root.u
                        height: 44 * root.u
                        radius: 10 * root.u
                        color: Style.Theme.error_fondo
                        border.color: Style.Theme.inferencia_error
                        Text {
                            id: lossText
                            anchors.centerIn: parent
                            text: "L = " + root.fmt(root.demo.loss, 4)
                            color: Style.Theme.error_texto
                            font.family: Style.Theme.fuente_mono
                            font.bold: true
                            font.pixelSize: Math.max(12, 14 * root.u)
                        }
                    }
                    Rectangle {
                        visible: backView.pulse > 0 && backView.pulse < 1
                        readonly property real startX: parent.width - 60 * root.u
                        readonly property real endX: 120 * root.u
                        x: root.lerp(startX, endX, backView.pulse)
                        y: 0
                        width: 30 * root.u
                        height: 14 * root.u
                        radius: 7 * root.u
                        color: Style.Theme.inferencia_error
                        Text { anchors.centerIn: parent; text: "◀ ∂"; color: Style.Theme.inferencia_sobre_error; font.bold: true; font.pixelSize: Math.max(8, 9 * root.u) }
                    }
                }
                Column {
                    spacing: 4 * root.u
                    opacity: root.seg(0.55, 0.65)
                    Tag { text: "Norma del gradiente por parámetro  ‖g‖₂   (total " + root.fmt(root.demo.gradient_norm, 5) + ")" }
                    Repeater {
                        model: backView.parameters
                        delegate: Row {
                            id: normRow
                            required property int index
                            required property var modelData
                            spacing: 8 * root.u
                            Text {
                                width: 220 * root.u
                                elide: Text.ElideMiddle
                                text: String(normRow.modelData.label)
                                color: Style.Theme.texto_secundario_fuerte
                                font.family: Style.Theme.fuente_mono
                                font.pixelSize: Math.max(8, 9.5 * root.u)
                            }
                            Rectangle {
                                width: Math.max(2, (backView.width - 360 * root.u) * root.num(normRow.modelData.norm) / backView.maxNorm
                                                   * root.ease(root.seg(0.6 + 0.08 * normRow.index, 0.8 + 0.05 * normRow.index)))
                                height: 14 * root.u
                                radius: 3
                                color: Style.Theme.inferencia_transformacion
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: root.fmt(normRow.modelData.norm, 5)
                                color: Style.Theme.texto_primario
                                font.family: Style.Theme.fuente_mono
                                font.pixelSize: Math.max(8, 9.5 * root.u)
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: updateComponent
        Item {
            id: updView
            readonly property var theta: root.list(root.demo.theta)
            readonly property var gradient: root.list(root.demo.gradient)
            readonly property var updated: root.list(root.demo.updated)
            readonly property real lr: Number(root.demo.learning_rate || 0.001)
            readonly property int count: theta.length
            readonly property real cw: root.cellWidth(count, width - 150 * root.u, 84)
            readonly property real maxT: Math.max(root.maxAbsOf(theta), root.maxAbsOf(updated), 1e-9)
            readonly property real maxD: Math.max(root.maxAbsOf(gradient) * lr, 1e-12)
            function local(i) {
                var start = 0.1 + 0.75 * i / Math.max(1, count)
                return root.seg(start, start + 0.75 / Math.max(1, count))
            }
            readonly property int active: Math.min(count - 1, Math.floor(root.seg(0.1, 0.85) * count))
            Column {
                anchors.centerIn: parent
                spacing: 6 * root.u
                Row {
                    spacing: 4 * root.u
                    Tag { width: 130 * root.u; text: String(root.demo.parameter); elide: Text.ElideMiddle; anchors.verticalCenter: parent.verticalCenter; color: Style.Theme.inferencia_estructura }
                    Repeater {
                        model: updView.theta
                        delegate: Cell {
                            required property int index
                            required property var modelData
                            width: updView.cw
                            value: modelData
                            maxAbs: updView.maxT
                            digits: 4
                            emphasized: index === updView.active && root.t < 0.9
                        }
                    }
                }
                Row {
                    spacing: 4 * root.u
                    Tag { width: 130 * root.u; text: "− η·g  (η = " + updView.lr + ")"; anchors.verticalCenter: parent.verticalCenter; color: Style.Theme.inferencia_error }
                    Repeater {
                        model: updView.gradient
                        delegate: Cell {
                            required property int index
                            required property var modelData
                            width: updView.cw
                            value: -root.num(modelData) * updView.lr
                            maxAbs: updView.maxD
                            digits: 6
                            reveal: root.segOf(updView.local(index), 0, 0.4)
                        }
                    }
                }
                Rectangle { width: 130 * root.u + updView.count * (updView.cw + 4 * root.u); height: 1; color: Style.Theme.borde_medio }
                Row {
                    spacing: 4 * root.u
                    Tag { width: 130 * root.u; text: String(root.demo.parameter) + "′  (no se guarda)"; elide: Text.ElideMiddle; anchors.verticalCenter: parent.verticalCenter; color: Style.Theme.inferencia_resultado }
                    Repeater {
                        model: updView.updated
                        delegate: Cell {
                            id: updatedCell
                            required property int index
                            required property var modelData
                            width: updView.cw
                            value: modelData
                            maxAbs: updView.maxT
                            digits: 4
                            reveal: root.segOf(updView.local(index), 0.5, 1)
                            transform: Translate { y: (1 - updatedCell.reveal) * -14 * root.u }
                        }
                    }
                }
                Equation {
                    visible: updView.count > 0
                    accent: Style.Theme.inferencia_resultado
                    text: {
                        var i = Math.max(0, updView.active)
                        return "[" + i + "]  " + root.fmt(updView.theta[i], 6) + "  " + root.signed(-root.num(updView.gradient[i]) * updView.lr, 6) + "  =  " + root.fmt(updView.updated[i], 6)
                    }
                }
            }
        }
    }

    Component {
        id: vectorComponent
        Item {
            id: vecView
            readonly property var values: root.list(root.demo.values)
            readonly property real maxAbs: Math.max(root.maxAbsOf(values), 1e-6)
            readonly property real chartH: Math.max(60 * root.u, height - 60 * root.u)
            readonly property real bw: Math.max(6 * root.u, Math.min(36 * root.u, width / Math.max(1, values.length) - 3 * root.u))
            readonly property real squares: {
                var total = 0
                var n = Math.floor(root.seg(0.72, 0.92) * values.length)
                for (var i = 0; i < n; ++i) total += root.num(values[i]) * root.num(values[i])
                return total
            }
            Rectangle { y: vecView.chartH / 2; width: parent.width; height: 1; color: Style.Theme.borde_medio }
            Repeater {
                model: vecView.values
                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    readonly property real reveal: root.seg(0.05 + 0.6 * index / Math.max(1, vecView.values.length), 0.12 + 0.6 * index / Math.max(1, vecView.values.length))
                    readonly property real h: Math.abs(root.num(modelData)) / vecView.maxAbs * vecView.chartH * 0.48 * reveal
                    x: index * (vecView.bw + 3 * root.u)
                    y: vecView.chartH / 2 - (root.num(modelData) > 0 ? h : 0)
                    width: vecView.bw
                    height: Math.max(1, h)
                    radius: 2
                    color: root.divColor(modelData, vecView.maxAbs)
                    border.color: Style.Theme.borde_medio
                }
            }
            Equation {
                y: vecView.chartH + 8 * root.u
                reveal: root.seg(0.72, 0.8)
                accent: Style.Theme.inferencia_foco
                text: Number(root.demo.size) > vecView.values.length
                      ? "‖" + root.demo.label + "‖ = √(Σ de los " + root.demo.size + " cuadrados) = " + root.fmt(root.demo.norm, 4)
                        + "   (barras: " + vecView.values.length + " de " + root.demo.size + ")"
                      : "‖" + root.demo.label + "‖ = √(Σ h²) = √" + root.fmt(vecView.squares, 3)
                        + (root.t >= 0.92 ? " = " + root.fmt(root.demo.norm, 4) : "")
            }
        }
    }
}
