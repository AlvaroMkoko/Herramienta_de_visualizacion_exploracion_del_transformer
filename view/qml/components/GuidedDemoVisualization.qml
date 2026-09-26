pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../styles" as Style

Rectangle {
    id: root
    objectName: conceptId !== "" ? "guidedConceptVisualization"
                                  : "guidedDemoVisualization"

    property string visualType: "pipeline"
    property string conceptId: ""
    property real scaleFactor: 1.0
    readonly property bool compactLayout: conceptId === ""
                                          && width > 0
                                          && width < 480 * scaleFactor

    readonly property var conceptVisuals: ({
        "que_es_transformer": {
            "title": "La secuencia completa puede relacionarse de una vez",
            "caption": "La atención crea rutas directas entre tokens; no necesita recorrerlos uno por uno como una red recurrente.",
            "steps": [
                { "label": "Entrada", "detail": "El gato duerme" },
                { "label": "Atención", "detail": "cada token mira a los demás" },
                { "label": "Bloques", "detail": "mezclan y refinan contexto" },
                { "label": "Salida", "detail": "vectores contextualizados" }
            ]
        },
        "encoder_decoder_general": {
            "title": "Comprender una vez; generar paso a paso",
            "caption": "El encoder deja una memoria estable. El decoder la consulta en cada vuelta mientras amplía su propio prefijo.",
            "steps": [
                { "label": "Entrada", "detail": "frase completa" },
                { "label": "Encoder", "detail": "crea memoria H_enc" },
                { "label": "Decoder", "detail": "memoria + tokens previos" },
                { "label": "Bucle", "detail": "un token nuevo por vuelta" }
            ]
        },
        "flujo_general": {
            "title": "Del ejemplo a una señal para aprender",
            "caption": "Los datos se convierten en IDs, el Transformer predice y la pérdida compara esa predicción con el objetivo.",
            "steps": []
        },
        "tokenizacion": {
            "title": "El texto se transforma en piezas reutilizables",
            "caption": "Un token puede ser una palabra, parte de una palabra o un signo. Cada pieza recibe un ID del vocabulario.",
            "steps": [
                { "label": "Texto", "detail": "Los gatitos" },
                { "label": "Piezas", "detail": "Los · gat · itos" },
                { "label": "IDs", "detail": "51 · 804 · 219" },
                { "label": "Secuencia", "detail": "lista para el modelo" }
            ]
        },
        "embeddings": {
            "title": "Un ID selecciona una fila aprendida",
            "caption": "El número del token no contiene significado. Sirve como índice para recuperar un vector que sí puede aprender relaciones.",
            "steps": [
                { "label": "Token", "detail": "gat → id 804" },
                { "label": "Tabla W", "detail": "buscar fila 804" },
                { "label": "Embedding", "detail": "[−0.4, 0.8, …]" },
                { "label": "Escala", "detail": "vector × √d_model" }
            ]
        },
        "positional_encoding": {
            "title": "Identidad del token + ubicación",
            "caption": "El mismo embedding recibe un patrón distinto en cada posición; por eso el modelo puede distinguir cambios de orden.",
            "steps": []
        },
        "query_key_value": {
            "title": "Buscar, ser encontrado y entregar información",
            "caption": "Q y K deciden la relevancia. V transporta el contenido después de que el peso ya fue calculado.",
            "steps": [
                { "label": "X", "detail": "vector del token" },
                { "label": "Q", "detail": "qué información busca" },
                { "label": "K", "detail": "cómo puede ser encontrado" },
                { "label": "V", "detail": "qué contenido entrega" }
            ]
        },
        "formula_attention_completa": {
            "title": "De similitudes a una mezcla contextual",
            "caption": "Cada fila de pesos suma 1. Esos pesos indican cuánto aporta cada Value a la salida de una Query.",
            "steps": []
        },
        "problema_multi_head": {
            "title": "Varias relaciones se observan en paralelo",
            "caption": "Cada cabeza aprende proyecciones distintas; concatenarlas evita comprimir todas las relaciones en un único promedio.",
            "steps": [
                { "label": "Cabeza 1", "detail": "relación sintáctica" },
                { "label": "Cabeza 2", "detail": "referencias lejanas" },
                { "label": "Cabeza 3", "detail": "patrón posicional" },
                { "label": "Concat + Wᴼ", "detail": "reúne las perspectivas" }
            ]
        },
        "por_que_mascara": {
            "title": "Cada posición conserva el pasado y bloquea el futuro",
            "caption": "Las celdas futuras reciben −∞ antes de Softmax, así que terminan con peso cero y no pueden filtrar la respuesta.",
            "steps": []
        },
        "generacion_token_por_token": {
            "title": "La salida vuelve a entrar como nuevo contexto",
            "caption": "La red se repite con un prefijo cada vez mayor hasta elegir EOS o alcanzar el límite configurado.",
            "steps": [
                { "label": "Inicio", "detail": "[BOS]" },
                { "label": "Predicción", "detail": "elige «El»" },
                { "label": "Nuevo prefijo", "detail": "[BOS, El]" },
                { "label": "Repetir", "detail": "hasta EOS" }
            ]
        },
        "seleccion_token": {
            "title": "Los logits se convierten en una decisión",
            "caption": "Temperatura y filtros cambian la forma de elegir, pero no vuelven correctas las probabilidades: solo controlan diversidad.",
            "steps": [
                { "label": "Logits", "detail": "puntajes crudos" },
                { "label": "Temperatura", "detail": "aplana o concentra" },
                { "label": "Top‑k / Top‑p", "detail": "filtra candidatos" },
                { "label": "Elección", "detail": "argmax o muestreo" }
            ]
        },
        "entrenamiento_vs_inferencia": {
            "title": "Entrenar modifica pesos; inferir los mantiene fijos",
            "caption": "Solo la rama de entrenamiento conoce el objetivo y puede construir pérdida, gradientes y una actualización.",
            "steps": [
                { "label": "Entrenamiento", "detail": "entrada + respuesta" },
                { "label": "Loss", "detail": "backward + optimizer" },
                { "label": "Inferencia", "detail": "solo entrada/prefijo" },
                { "label": "Pesos fijos", "detail": "genera sin aprender" }
            ]
        },
        "cross_entropy": {
            "title": "La respuesta correcta recibe una penalización",
            "caption": "Si la probabilidad del objetivo baja, −log(p) crece. La pérdida usa todo el vocabulario, no solamente el Top‑K visible.",
            "steps": [
                { "label": "Logits", "detail": "uno por token" },
                { "label": "Objetivo", "detail": "token correcto = «gato»" },
                { "label": "Probabilidad", "detail": "p(gato) = 0.10" },
                { "label": "Pérdida", "detail": "−log(0.10) = 2.30" }
            ]
        },
        "actualizacion_parametros": {
            "title": "El gradiente se convierte en un cambio de pesos",
            "caption": "Backward calcula sensibilidad; el optimizador es quien aplica la actualización. Son dos momentos distintos.",
            "steps": []
        },
        "dataset": {
            "title": "Un ejemplo separa entrada y respuesta esperada",
            "caption": "Instruction y context alimentan al encoder; response sirve tanto para la entrada desplazada del decoder como para el objetivo.",
            "steps": []
        },
        "teacher_forcing": {
            "title": "La respuesta se desplaza una posición",
            "caption": "Cada posición recibe el contexto correcto anterior y practica el siguiente token; todas pueden calcularse en paralelo.",
            "steps": [
                { "label": "Response", "detail": "hola · mundo · EOS" },
                { "label": "Entrada", "detail": "BOS · hola · mundo" },
                { "label": "Objetivo", "detail": "hola · mundo · EOS" },
                { "label": "Alineación", "detail": "cada columna predice +1" }
            ]
        },
        "epoch_batch": {
            "title": "Los ejemplos se procesan por grupos",
            "caption": "Cada batch produce una actualización. Una epoch termina cuando todos los ejemplos del dataset participaron una vez.",
            "steps": [
                { "label": "Dataset", "detail": "12 ejemplos" },
                { "label": "Batch", "detail": "3 grupos de 4" },
                { "label": "Actualización", "detail": "una por grupo" },
                { "label": "Epoch", "detail": "12/12 y volver a mezclar" }
            ]
        }
    })
    readonly property var conceptVisual: conceptVisuals[conceptId]
                                         || ({ "title": "Cómo fluye la información",
                                               "caption": "Sigue las flechas de izquierda a derecha.",
                                               "steps": [] })

    readonly property string accessibleSummary: {
        if (conceptId !== "")
            return String(conceptVisual.title) + ". " + String(conceptVisual.caption)
        if (visualType === "dataset_pairs")
            return "Un registro aporta instruction y context al encoder; response entra al decoder desplazada entre los tokens BOS y EOS para convertirse en el objetivo."
        if (visualType === "token_position")
            return "Dos tokens iguales se combinan con posiciones distintas y producen vectores distintos."
        if (visualType === "attention")
            return "Una matriz asigna 72 por ciento de atención a gato, 18 a duerme y 10 al punto."
        if (visualType === "causal_mask")
            return "Matriz triangular: cada fila permite el pasado y bloquea el futuro."
        if (visualType === "training")
            return "La pérdida produce gradientes, el optimizador los aplica y los parámetros cambian."
        return "Flujo de entrenamiento: el dataset aporta instruction, context y response; la aplicación tokeniza, el encoder y el decoder predicen, y la pérdida compara la predicción con la response esperada."
    }

    function attentionColor(value) {
        var normalized = Math.max(0, Math.min(1, Number(value)))
        if (normalized < 0.20)
            return Style.Theme.escala_sec_0
        if (normalized < 0.40)
            return Style.Theme.escala_sec_1
        if (normalized < 0.60)
            return Style.Theme.escala_sec_2
        if (normalized < 0.80)
            return Style.Theme.escala_sec_3
        return Style.Theme.escala_sec_4
    }

    function conceptStepFill(index) {
        return [Style.Theme.superficie_alterna,
                Style.Theme.concepto_fondo,
                Style.Theme.formula_fondo,
                Style.Theme.proceso_fondo][index % 4]
    }

    function conceptStepAccent(index) {
        return [Style.Theme.texto_secundario_fuerte,
                Style.Theme.concepto_texto,
                Style.Theme.formula_texto,
                Style.Theme.proceso_texto][index % 4]
    }

    implicitHeight: (conceptId !== "" ? 220
                     : compactLayout && visualType === "pipeline" ? 265
                     : compactLayout && visualType === "dataset_pairs" ? 245
                     : compactLayout && visualType === "training" ? 250
                     : compactLayout ? 185 : 170) * scaleFactor
    radius: 9 * scaleFactor
    color: Style.Theme.fondo
    border.color: Style.Theme.borde_suave
    Accessible.name: "Demostración didáctica con datos precalculados"
    Accessible.description: accessibleSummary

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 9 * root.scaleFactor
        spacing: 7 * root.scaleFactor

        RowLayout {
            Layout.fillWidth: true
            spacing: 6 * root.scaleFactor

            Rectangle {
                Layout.preferredWidth: 7 * root.scaleFactor
                Layout.preferredHeight: 7 * root.scaleFactor
                radius: width / 2
                color: Style.Theme.ejemplo_texto
            }
            Text {
                Layout.fillWidth: true
                text: root.conceptId !== ""
                      ? String(root.conceptVisual.title)
                      : "TRAZA DIDÁCTICA · DATOS PRECALCULADOS"
                color: Style.Theme.texto_secundario
                font.bold: true
                font.pixelSize: (root.conceptId !== "" ? 10 : 8) * root.scaleFactor
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: root.conceptId !== "" ? conceptDiagramDemo
                             : root.visualType === "dataset_pairs" ? datasetPairsDemo
                             : root.visualType === "token_position" ? tokenPositionDemo
                             : root.visualType === "attention" ? attentionDemo
                             : root.visualType === "causal_mask" ? causalMaskDemo
                             : root.visualType === "training" ? trainingDemo
                             : pipelineDemo
        }

        Text {
            visible: root.conceptId !== ""
            Layout.fillWidth: true
            text: String(root.conceptVisual.caption)
            color: Style.Theme.texto_secundario_fuerte
            font.pixelSize: 9 * root.scaleFactor
            lineHeight: 1.12
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Component {
        id: conceptDiagramDemo

        GuidedConceptDiagram {
            conceptId: root.conceptId
            scaleFactor: root.scaleFactor
        }
    }

    component DemoBlock: Rectangle {
        id: demoBlock
        property string label: ""
        property string detail: ""
        property color fillColor: Style.Theme.concepto_fondo
        property color accentColor: Style.Theme.concepto_texto
        radius: 7 * root.scaleFactor
        color: fillColor
        border.color: Qt.alpha(accentColor, 0.52)

        Column {
            anchors.centerIn: parent
            width: parent.width - 6 * root.scaleFactor
            spacing: 3 * root.scaleFactor
            Text {
                width: parent.width
                text: demoBlock.label
                color: Style.Theme.texto_primario
                font.bold: true
                font.pixelSize: 8 * root.scaleFactor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                text: demoBlock.detail
                color: demoBlock.accentColor
                font.pixelSize: 8 * root.scaleFactor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }

    component LegendChip: Rectangle {
        id: legendChip
        property string symbol: ""
        property string description: ""
        property color fillColor: Style.Theme.concepto_fondo
        property color accentColor: Style.Theme.concepto_texto
        radius: 6 * root.scaleFactor
        color: fillColor
        border.color: Qt.alpha(accentColor, 0.55)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 7 * root.scaleFactor
            anchors.rightMargin: 7 * root.scaleFactor
            spacing: 4 * root.scaleFactor

            Text {
                text: legendChip.symbol
                color: legendChip.accentColor
                font.bold: true
                font.pixelSize: 9 * root.scaleFactor
            }
            Text {
                Layout.fillWidth: true
                text: legendChip.description
                color: Style.Theme.texto_secundario_fuerte
                font.pixelSize: 7 * root.scaleFactor
                elide: Text.ElideRight
            }
        }
    }

    Component {
        id: conceptFlowDemo
        Item {
            RowLayout {
                anchors.fill: parent
                spacing: 5 * root.scaleFactor

                Repeater {
                    model: root.conceptVisual.steps || []

                    delegate: Item {
                        id: conceptStep
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        RowLayout {
                            anchors.fill: parent
                            spacing: 4 * root.scaleFactor

                            DemoBlock {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                label: String(conceptStep.modelData.label)
                                detail: String(conceptStep.modelData.detail)
                                fillColor: root.conceptStepFill(conceptStep.index)
                                accentColor: root.conceptStepAccent(conceptStep.index)
                            }

                            Text {
                                visible: conceptStep.index
                                         < (root.conceptVisual.steps || []).length - 1
                                text: "→"
                                color: Style.Theme.acento
                                font.bold: true
                                font.pixelSize: 14 * root.scaleFactor
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: pipelineDemo

        Loader {
            anchors.fill: parent
            sourceComponent: root.compactLayout ? pipelineCompactDemo
                                                : pipelineWideDemo
        }
    }

    Component {
        id: pipelineWideDemo

        Item {
            RowLayout {
                anchors.fill: parent
                spacing: 3 * root.scaleFactor
                DemoBlock {
                    objectName: "guidedPipelineDatasetBlock"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "Dataset"
                    detail: "instruction\n+ context\n+ response"
                    fillColor: Style.Theme.superficie_alterna
                    accentColor: Style.Theme.texto_secundario_fuerte
                }
                Text { text: "→"; color: Style.Theme.acento; font.bold: true }
                DemoBlock {
                    objectName: "guidedPipelineTokenizationBlock"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "Tokenización"
                    detail: "IDs +\nBOS / EOS"
                }
                Text { text: "→"; color: Style.Theme.acento; font.bold: true }
                DemoBlock {
                    objectName: "guidedPipelineTransformerBlock"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "Transformer"
                    detail: "encoder\n+ decoder"
                    fillColor: Style.Theme.formula_fondo
                    accentColor: Style.Theme.formula_texto
                }
                Text { text: "→"; color: Style.Theme.acento; font.bold: true }
                DemoBlock {
                    objectName: "guidedPipelineLearningBlock"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "Aprendizaje"
                    detail: "predicción\nvs. objetivo"
                    fillColor: Style.Theme.proceso_fondo
                    accentColor: Style.Theme.proceso_texto
                }
            }
        }
    }

    Component {
        id: pipelineCompactDemo

        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 3 * root.scaleFactor

                DemoBlock {
                    objectName: "guidedPipelineDatasetBlock"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "1 · Dataset"
                    detail: "instruction + context + response"
                    fillColor: Style.Theme.superficie_alterna
                    accentColor: Style.Theme.texto_secundario_fuerte
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "↓  convertir texto en IDs"
                    color: Style.Theme.acento
                    font.bold: true
                    font.pixelSize: 8 * root.scaleFactor
                }
                DemoBlock {
                    objectName: "guidedPipelineTokenizationBlock"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "2 · Tokenización"
                    detail: "IDs + posiciones + BOS / EOS"
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "↓  procesar contexto"
                    color: Style.Theme.acento
                    font.bold: true
                    font.pixelSize: 8 * root.scaleFactor
                }
                DemoBlock {
                    objectName: "guidedPipelineTransformerBlock"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "3 · Transformer"
                    detail: "encoder una vez · decoder por token"
                    fillColor: Style.Theme.formula_fondo
                    accentColor: Style.Theme.formula_texto
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "↓  comparar predicción y objetivo"
                    color: Style.Theme.acento
                    font.bold: true
                    font.pixelSize: 8 * root.scaleFactor
                }
                DemoBlock {
                    objectName: "guidedPipelineLearningBlock"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "4 · Aprendizaje"
                    detail: "loss → gradientes → parámetros nuevos"
                    fillColor: Style.Theme.proceso_fondo
                    accentColor: Style.Theme.proceso_texto
                }
            }
        }
    }

    Component {
        id: datasetPairsDemo

        Loader {
            anchors.fill: parent
            sourceComponent: root.compactLayout ? datasetPairsCompactDemo
                                                : datasetPairsWideDemo
        }
    }

    Component {
        id: datasetPairsWideDemo

        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 5 * root.scaleFactor

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4 * root.scaleFactor
                    DemoBlock {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: "instruction"
                        detail: "Resume el texto"
                        fillColor: Style.Theme.superficie_alterna
                        accentColor: Style.Theme.texto_secundario_fuerte
                    }
                    Text { text: "+"; color: Style.Theme.acento; font.bold: true }
                    DemoBlock {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: "context (opcional)"
                        detail: "Texto fuente"
                        fillColor: Style.Theme.concepto_fondo
                        accentColor: Style.Theme.concepto_texto
                    }
                    Text { text: "→"; color: Style.Theme.acento; font.bold: true }
                    DemoBlock {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: "Encoder"
                        detail: "entrada"
                        fillColor: Style.Theme.proceso_fondo
                        accentColor: Style.Theme.proceso_texto
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4 * root.scaleFactor
                    DemoBlock {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: "response"
                        detail: "Un resumen"
                        fillColor: Style.Theme.formula_fondo
                        accentColor: Style.Theme.formula_texto
                    }
                    Text { text: "→"; color: Style.Theme.acento; font.bold: true }
                    DemoBlock {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: "Decoder recibe"
                        detail: "BOS · Un resumen"
                        fillColor: Style.Theme.concepto_fondo
                        accentColor: Style.Theme.concepto_texto
                    }
                    Text { text: "→"; color: Style.Theme.acento; font.bold: true }
                    DemoBlock {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: "Objetivo"
                        detail: "Un resumen · EOS"
                        fillColor: Style.Theme.proceso_fondo
                        accentColor: Style.Theme.proceso_texto
                    }
                }
            }
        }
    }

    Component {
        id: datasetPairsCompactDemo

        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 5 * root.scaleFactor

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 74 * root.scaleFactor
                    spacing: 5 * root.scaleFactor
                    DemoBlock {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: "instruction + context"
                        detail: "entrada del encoder"
                        fillColor: Style.Theme.info_fondo
                        accentColor: Style.Theme.info_texto
                    }
                    Text {
                        text: "→"
                        color: Style.Theme.acento
                        font.bold: true
                    }
                    DemoBlock {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: "Memoria H_enc"
                        detail: "contexto comprendido"
                        fillColor: Style.Theme.concepto_fondo
                        accentColor: Style.Theme.concepto_texto
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 18 * root.scaleFactor
                    text: "response se desplaza en dos versiones"
                    color: Style.Theme.formula_texto
                    font.bold: true
                    font.pixelSize: 8 * root.scaleFactor
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 74 * root.scaleFactor
                    spacing: 6 * root.scaleFactor
                    DemoBlock {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: "Decoder recibe"
                        detail: "BOS + response[:-1]"
                        fillColor: Style.Theme.formula_fondo
                        accentColor: Style.Theme.formula_texto
                    }
                    DemoBlock {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: "Objetivo"
                        detail: "response[1:] + EOS"
                        fillColor: Style.Theme.proceso_fondo
                        accentColor: Style.Theme.proceso_texto
                    }
                }
            }
        }
    }

    Component {
        id: tokenPositionDemo
        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 6 * root.scaleFactor
                Text {
                    Layout.fillWidth: true
                    text: "Mismo token, distinta posición"
                    color: Style.Theme.texto_secundario
                    font.pixelSize: 8 * root.scaleFactor
                }
                Repeater {
                    model: [
                        { "position": "P₁", "vector": "v = [0.8, 0.2]" },
                        { "position": "P₄", "vector": "v = [0.3, 0.9]" }
                    ]
                    delegate: RowLayout {
                        id: positionDelegate
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 4 * root.scaleFactor
                        DemoBlock { Layout.preferredWidth: 55 * root.scaleFactor; Layout.fillHeight: true; label: "Token"; detail: "banco"; fillColor: Style.Theme.superficie_alterna; accentColor: Style.Theme.texto_secundario_fuerte }
                        Text { text: "+"; color: Style.Theme.texto_secundario }
                        DemoBlock { Layout.preferredWidth: 42 * root.scaleFactor; Layout.fillHeight: true; label: "Pos."; detail: positionDelegate.modelData.position }
                        Text { text: "→"; color: Style.Theme.acento }
                        DemoBlock { Layout.fillWidth: true; Layout.fillHeight: true; label: "Vector"; detail: positionDelegate.modelData.vector; fillColor: Style.Theme.proceso_fondo; accentColor: Style.Theme.proceso_texto }
                    }
                }
            }
        }
    }

    Component {
        id: attentionDemo
        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 5 * root.scaleFactor

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24 * root.scaleFactor
                    spacing: 4 * root.scaleFactor
                    LegendChip { Layout.fillWidth: true; Layout.fillHeight: true; symbol: "Q"; description: "busca"; fillColor: Style.Theme.matriz_query_fondo; accentColor: Style.Theme.matriz_query_texto }
                    Text { text: "×"; color: Style.Theme.texto_secundario; font.bold: true }
                    LegendChip { Layout.fillWidth: true; Layout.fillHeight: true; symbol: "K"; description: "identifica"; fillColor: Style.Theme.matriz_key_fondo; accentColor: Style.Theme.matriz_key_texto }
                    Text { text: "→"; color: Style.Theme.texto_secundario; font.bold: true }
                    LegendChip { Layout.fillWidth: true; Layout.fillHeight: true; symbol: "V"; description: "transporta"; fillColor: Style.Theme.matriz_value_fondo; accentColor: Style.Theme.matriz_value_texto }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 9 * root.scaleFactor
                    ColumnLayout {
                        Layout.preferredWidth: 101 * root.scaleFactor
                        Layout.fillHeight: true
                        Text { Layout.fillWidth: true; text: "Pesos · 0 a 1"; color: Style.Theme.texto_secundario; font.pixelSize: 8 * root.scaleFactor; horizontalAlignment: Text.AlignHCenter }
                        GridLayout {
                            Layout.alignment: Qt.AlignHCenter
                            columns: 3
                            rowSpacing: 2 * root.scaleFactor
                            columnSpacing: 2 * root.scaleFactor
                            Repeater {
                                model: [0.72, 0.18, 0.10, 0.21, 0.63, 0.16, 0.14, 0.24, 0.62]
                                delegate: Rectangle {
                                    id: attentionCell
                                    required property real modelData
                                    Layout.preferredWidth: 25 * root.scaleFactor
                                    Layout.preferredHeight: 25 * root.scaleFactor
                                    radius: 4 * root.scaleFactor
                                    color: root.attentionColor(attentionCell.modelData)
                                    Text { anchors.centerIn: parent; text: attentionCell.modelData.toFixed(2); color: attentionCell.modelData >= 0.5 ? Style.Theme.texto_sobre_color : "#0F172A"; font.pixelSize: 7 * root.scaleFactor }
                                }
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Text { Layout.fillWidth: true; text: "Atención desde «duerme»"; color: Style.Theme.texto_secundario; font.pixelSize: 8 * root.scaleFactor }
                        Repeater {
                            model: [{ "label": "gato", "value": 0.72 }, { "label": "duerme", "value": 0.18 }, { "label": ".", "value": 0.10 }]
                            delegate: ColumnLayout {
                                id: barDelegate
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 1 * root.scaleFactor
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { Layout.fillWidth: true; text: barDelegate.modelData.label; color: Style.Theme.texto_primario; font.pixelSize: 8 * root.scaleFactor }
                                    Text { text: Math.round(barDelegate.modelData.value * 100) + "%"; color: Style.Theme.ejemplo_texto; font.bold: true; font.pixelSize: 8 * root.scaleFactor }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 7 * root.scaleFactor
                                    radius: height / 2
                                    color: Style.Theme.divisor
                                    Rectangle { width: parent.width * barDelegate.modelData.value; height: parent.height; radius: height / 2; color: root.attentionColor(barDelegate.modelData.value) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: causalMaskDemo
        Item {
            RowLayout {
                anchors.fill: parent
                spacing: 11 * root.scaleFactor
                GridLayout {
                    columns: 4
                    rowSpacing: 3 * root.scaleFactor
                    columnSpacing: 3 * root.scaleFactor
                    Repeater {
                        model: 16
                        delegate: Rectangle {
                            id: maskCell
                            required property int index
                            readonly property int row: Math.floor(index / 4)
                            readonly property int column: index % 4
                            readonly property bool allowed: column <= row
                            Layout.preferredWidth: 27 * root.scaleFactor
                            Layout.preferredHeight: 27 * root.scaleFactor
                            radius: 4 * root.scaleFactor
                            color: allowed ? Style.Theme.proceso_fondo : Style.Theme.error_fondo
                            border.color: allowed ? Style.Theme.proceso_texto : Style.Theme.error
                            Text { anchors.centerIn: parent; text: maskCell.allowed ? "✓" : "×"; color: maskCell.allowed ? Style.Theme.proceso_texto : Style.Theme.error_texto; font.bold: true; font.pixelSize: 10 * root.scaleFactor }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: "Máscara causal"; color: Style.Theme.texto_primario; font.bold: true; font.pixelSize: 10 * root.scaleFactor }
                    Text { Layout.fillWidth: true; text: "✓ pasado visible\n× futuro bloqueado"; color: Style.Theme.texto_secundario; font.pixelSize: 9 * root.scaleFactor; lineHeight: 1.3 }
                    Text { Layout.fillWidth: true; text: "La fila crece un token en cada paso."; color: Style.Theme.concepto_texto; font.pixelSize: 8 * root.scaleFactor; wrapMode: Text.WordWrap }
                }
            }
        }
    }

    Component {
        id: trainingDemo

        Loader {
            anchors.fill: parent
            sourceComponent: root.compactLayout ? trainingCompactDemo
                                                : trainingWideDemo
        }
    }

    Component {
        id: trainingWideDemo

        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 5 * root.scaleFactor
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 3 * root.scaleFactor
                    DemoBlock { Layout.fillWidth: true; Layout.fillHeight: true; label: "Pérdida"; detail: "1.84"; fillColor: Style.Theme.formula_fondo; accentColor: Style.Theme.formula_texto }
                    Text { text: "→"; color: Style.Theme.acento }
                    DemoBlock { Layout.fillWidth: true; Layout.fillHeight: true; label: "Gradiente"; detail: "∂L/∂θ" }
                    Text { text: "→"; color: Style.Theme.acento }
                    DemoBlock { Layout.fillWidth: true; Layout.fillHeight: true; label: "Optimizador"; detail: "−η · g"; fillColor: Style.Theme.ejemplo_fondo; accentColor: Style.Theme.ejemplo_texto }
                    Text { text: "→"; color: Style.Theme.acento }
                    DemoBlock { Layout.fillWidth: true; Layout.fillHeight: true; label: "Parámetros"; detail: "θ nuevo"; fillColor: Style.Theme.proceso_fondo; accentColor: Style.Theme.proceso_texto }
                }
                Text { Layout.fillWidth: true; text: "Ejemplo fijo: η = 0.001 · no ejecuta entrenamiento real"; color: Style.Theme.texto_secundario; font.pixelSize: 7 * root.scaleFactor; horizontalAlignment: Text.AlignHCenter }
            }
        }
    }

    Component {
        id: trainingCompactDemo

        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 3 * root.scaleFactor

                DemoBlock {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "1 · Pérdida"
                    detail: "compara predicción y objetivo · L = 1.84"
                    fillColor: Style.Theme.formula_fondo
                    accentColor: Style.Theme.formula_texto
                }
                Text { Layout.alignment: Qt.AlignHCenter; text: "↓  backward()"; color: Style.Theme.acento; font.bold: true; font.pixelSize: 8 * root.scaleFactor }
                DemoBlock {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "2 · Gradientes"
                    detail: "∂L/∂θ queda en .grad"
                }
                Text { Layout.alignment: Qt.AlignHCenter; text: "↓  optimizer.step()"; color: Style.Theme.acento; font.bold: true; font.pixelSize: 8 * root.scaleFactor }
                DemoBlock {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "3 · Optimizador"
                    detail: "Adam calcula Δθ con el gradiente"
                    fillColor: Style.Theme.ejemplo_fondo
                    accentColor: Style.Theme.ejemplo_texto
                }
                Text { Layout.alignment: Qt.AlignHCenter; text: "↓  aplicar Δθ"; color: Style.Theme.acento; font.bold: true; font.pixelSize: 8 * root.scaleFactor }
                DemoBlock {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "4 · Parámetros"
                    detail: "θ nuevo para el siguiente batch"
                    fillColor: Style.Theme.proceso_fondo
                    accentColor: Style.Theme.proceso_texto
                }
            }
        }
    }
}
