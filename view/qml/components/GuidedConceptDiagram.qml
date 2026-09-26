pragma ComponentBehavior: Bound

import QtQuick
import "../styles" as Style

Item {
    id: root
    objectName: "guidedConceptDiagram"

    property string conceptId: ""
    property real scaleFactor: 1.0
    readonly property string sceneKind: conceptId

    function canvasFont(size, bold) {
        return (bold ? "bold " : "") + size + "px \""
                + Style.Theme.fuente_interfaz + "\""
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

    function roundedPath(ctx, x, y, width, height, radius) {
        var r = Math.min(radius, width / 2, height / 2)
        ctx.beginPath()
        ctx.moveTo(x + r, y)
        ctx.lineTo(x + width - r, y)
        ctx.quadraticCurveTo(x + width, y, x + width, y + r)
        ctx.lineTo(x + width, y + height - r)
        ctx.quadraticCurveTo(x + width, y + height, x + width - r, y + height)
        ctx.lineTo(x + r, y + height)
        ctx.quadraticCurveTo(x, y + height, x, y + height - r)
        ctx.lineTo(x, y + r)
        ctx.quadraticCurveTo(x, y, x + r, y)
        ctx.closePath()
    }

    function box(ctx, x, y, width, height, title, detail, fill, accent) {
        ctx.fillStyle = Qt.alpha(Style.Theme.texto_primario, 0.08)
        roundedPath(ctx, x + 2, y + 3, width, height, 8)
        ctx.fill()
        ctx.fillStyle = fill
        roundedPath(ctx, x, y, width, height, 8)
        ctx.fill()
        ctx.strokeStyle = Qt.alpha(accent, 0.72)
        ctx.lineWidth = 1.4
        ctx.stroke()
        ctx.textAlign = "center"
        ctx.textBaseline = "middle"
        ctx.fillStyle = accent
        ctx.font = canvasFont(10, true)
        ctx.fillText(title, x + width / 2, y + height * 0.38)
        if (detail) {
            ctx.fillStyle = Style.Theme.texto_secundario_fuerte
            ctx.font = canvasFont(8, false)
            var lines = String(detail).split("\n")
            for (var i = 0; i < lines.length; ++i)
                ctx.fillText(lines[i], x + width / 2,
                             y + height * 0.68 + i * 10)
        }
    }

    function pill(ctx, x, y, width, text, fill, accent, selected) {
        ctx.fillStyle = fill
        roundedPath(ctx, x, y, width, 23, 7)
        ctx.fill()
        ctx.strokeStyle = accent
        ctx.lineWidth = selected ? 2.2 : 1.1
        ctx.stroke()
        ctx.fillStyle = accent
        ctx.font = canvasFont(9, selected)
        ctx.textAlign = "center"
        ctx.textBaseline = "middle"
        ctx.fillText(text, x + width / 2, y + 12)
    }

    function label(ctx, text, x, y, color, size, bold, align) {
        ctx.fillStyle = color || Style.Theme.texto_secundario_fuerte
        ctx.font = canvasFont(size || 9, bold)
        ctx.textAlign = align || "left"
        ctx.textBaseline = "middle"
        ctx.fillText(text, x, y)
    }

    function captionTag(ctx, text, x, y, color, size) {
        var caption = String(text)
        var fontSize = size || 8
        ctx.font = canvasFont(fontSize, true)
        var tagWidth = ctx.measureText(caption).width + 12
        var tagHeight = fontSize + 8
        ctx.fillStyle = Qt.alpha(Style.Theme.fondo, 0.97)
        roundedPath(ctx, x - tagWidth / 2, y - tagHeight / 2,
                    tagWidth, tagHeight, tagHeight / 2)
        ctx.fill()
        ctx.strokeStyle = Qt.alpha(color || Style.Theme.acento, 0.30)
        ctx.lineWidth = 0.8
        ctx.stroke()
        label(ctx, caption, x, y, color || Style.Theme.acento,
              fontSize, true, "center")
    }

    function arrow(ctx, x1, y1, x2, y2, color, caption) {
        var angle = Math.atan2(y2 - y1, x2 - x1)
        var head = 6
        ctx.strokeStyle = color || Style.Theme.acento
        ctx.fillStyle = color || Style.Theme.acento
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.moveTo(x1, y1)
        ctx.lineTo(x2, y2)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(x2, y2)
        ctx.lineTo(x2 - Math.cos(angle - 0.55) * head,
                   y2 - Math.sin(angle - 0.55) * head)
        ctx.lineTo(x2 - Math.cos(angle + 0.55) * head,
                   y2 - Math.sin(angle + 0.55) * head)
        ctx.closePath()
        ctx.fill()
        if (caption)
            captionTag(ctx, caption, (x1 + x2) / 2,
                       (y1 + y2) / 2 - 9,
                       color || Style.Theme.acento, 8)
    }

    function curveArrow(ctx, x1, y1, cx1, cy1, cx2, cy2, x2, y2, color) {
        ctx.strokeStyle = color || Style.Theme.acento
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.moveTo(x1, y1)
        ctx.bezierCurveTo(cx1, cy1, cx2, cy2, x2, y2)
        ctx.stroke()
        var angle = Math.atan2(y2 - cy2, x2 - cx2)
        ctx.fillStyle = color || Style.Theme.acento
        ctx.beginPath()
        ctx.moveTo(x2, y2)
        ctx.lineTo(x2 - Math.cos(angle - 0.55) * 6,
                   y2 - Math.sin(angle - 0.55) * 6)
        ctx.lineTo(x2 - Math.cos(angle + 0.55) * 6,
                   y2 - Math.sin(angle + 0.55) * 6)
        ctx.closePath()
        ctx.fill()
    }

    function drawQueEsTransformer(ctx) {
        label(ctx, "TOKENS DE ENTRADA", 18, 13, Style.Theme.info_texto, 8, true)
        var tokens = ["El", "gato", "duerme"]
        for (var i = 0; i < tokens.length; ++i)
            pill(ctx, 18, 25 + i * 34, 65, tokens[i], Style.Theme.info_fondo,
                 Style.Theme.info_texto, i === 1)
        box(ctx, 225, 35, 145, 72, "ATENCIÓN", "conecta cualquier\npar de tokens",
            Style.Theme.concepto_fondo, Style.Theme.concepto_texto)
        for (i = 0; i < tokens.length; ++i) {
            curveArrow(ctx, 84, 37 + i * 34, 140, 37 + i * 34,
                       170, 48 + i * 18, 225, 56 + i * 16,
                       i === 1 ? Style.Theme.acento : Qt.alpha(Style.Theme.info, 0.55))
        }
        arrow(ctx, 370, 71, 432, 71, Style.Theme.acento, "en paralelo")
        for (i = 0; i < tokens.length; ++i)
            pill(ctx, 452, 25 + i * 34, 125, tokens[i] + " + contexto",
                 Style.Theme.proceso_fondo, Style.Theme.proceso_texto, i === 1)
        label(ctx, "Cada salida ya incorpora información de los demás tokens",
              300, 134, Style.Theme.proceso_texto, 9, true, "center")
    }

    function drawEncoderDecoder(ctx) {
        pill(ctx, 12, 56, 68, "Entrada", Style.Theme.info_fondo,
             Style.Theme.info_texto, false)
        arrow(ctx, 81, 68, 108, 68, Style.Theme.info)
        box(ctx, 110, 27, 100, 82, "ENCODER", "lee toda\nla entrada",
            Style.Theme.info_fondo, Style.Theme.info_texto)
        arrow(ctx, 211, 68, 243, 68, Style.Theme.acento)
        box(ctx, 245, 38, 105, 60, "MEMORIA", "H_enc queda fija",
            Style.Theme.concepto_fondo, Style.Theme.concepto_texto)
        arrow(ctx, 351, 68, 388, 68, Style.Theme.acento)
        box(ctx, 390, 27, 105, 82, "DECODER", "prefijo +\nmemoria",
            Style.Theme.formula_fondo, Style.Theme.formula_texto)
        arrow(ctx, 496, 68, 523, 68, Style.Theme.proceso_texto)
        pill(ctx, 525, 56, 62, "token", Style.Theme.proceso_fondo,
             Style.Theme.proceso_texto, true)
        curveArrow(ctx, 556, 80, 556, 127, 443, 130, 443, 110,
                   Style.Theme.proceso_texto)
        captionTag(ctx, "el token se agrega al prefijo y vuelve al decoder",
                   470, 134, Style.Theme.proceso_texto, 8)
    }

    function drawPipeline(ctx) {
        var titles = ["Dataset", "Tokens", "Transformer", "Predicción", "Loss"]
        var details = ["entrada +\nrespuesta", "IDs +\nposiciones", "encoder +\ndecoder",
                       "logits del\nvocabulario", "comparar con\nobjetivo"]
        var fills = [Style.Theme.superficie_alterna, Style.Theme.info_fondo,
                     Style.Theme.concepto_fondo, Style.Theme.formula_fondo,
                     Style.Theme.proceso_fondo]
        var accents = [Style.Theme.texto_secundario_fuerte, Style.Theme.info_texto,
                       Style.Theme.concepto_texto, Style.Theme.formula_texto,
                       Style.Theme.proceso_texto]
        for (var i = 0; i < titles.length; ++i) {
            box(ctx, 10 + i * 119, 30, 95, 82, titles[i], details[i], fills[i], accents[i])
            if (i < titles.length - 1)
                arrow(ctx, 106 + i * 119, 71, 125 + i * 119, 71, Style.Theme.acento)
        }
        curveArrow(ctx, 552, 116, 500, 143, 335, 143, 320, 115,
                   Style.Theme.proceso_texto)
        captionTag(ctx, "el error vuelve para ajustar parámetros",
                   425, 134, Style.Theme.proceso_texto, 8)
    }

    function drawTokenization(ctx) {
        box(ctx, 14, 42, 115, 58, "TEXTO", "«Los gatitos»",
            Style.Theme.superficie_alterna, Style.Theme.texto_secundario_fuerte)
        arrow(ctx, 130, 71, 168, 71, Style.Theme.acento, "cortar")
        label(ctx, "TOKENS", 245, 23, Style.Theme.concepto_texto, 8, true, "center")
        pill(ctx, 175, 38, 48, "Los", Style.Theme.concepto_fondo, Style.Theme.concepto_texto, false)
        pill(ctx, 228, 38, 48, "gat", Style.Theme.concepto_fondo, Style.Theme.concepto_texto, true)
        pill(ctx, 281, 38, 53, "itos", Style.Theme.concepto_fondo, Style.Theme.concepto_texto, false)
        pill(ctx, 175, 78, 48, "51", Style.Theme.info_fondo, Style.Theme.info_texto, false)
        pill(ctx, 228, 78, 48, "804", Style.Theme.info_fondo, Style.Theme.info_texto, true)
        pill(ctx, 281, 78, 53, "219", Style.Theme.info_fondo, Style.Theme.info_texto, false)
        arrow(ctx, 340, 71, 388, 71, Style.Theme.acento, "orden")
        box(ctx, 392, 32, 190, 78, "SECUENCIA DE IDs", "[51, 804, 219]\nmisma longitud: 3",
            Style.Theme.proceso_fondo, Style.Theme.proceso_texto)
        label(ctx, "El ID identifica una pieza del vocabulario; todavía no es un significado",
              300, 133, Style.Theme.aviso_texto, 8, true, "center")
    }

    function drawEmbedding(ctx) {
        pill(ctx, 12, 55, 72, "id 804", Style.Theme.info_fondo,
             Style.Theme.info_texto, true)
        arrow(ctx, 85, 67, 125, 67, Style.Theme.info, "índice")
        label(ctx, "TABLA W_embed", 200, 14, Style.Theme.concepto_texto, 8, true, "center")
        for (var r = 0; r < 5; ++r) {
            for (var c = 0; c < 6; ++c) {
                ctx.fillStyle = r === 2 ? Style.Theme.acento_fondo : Style.Theme.superficie_alterna
                ctx.fillRect(132 + c * 23, 25 + r * 19, 20, 16)
                ctx.strokeStyle = r === 2 ? Style.Theme.acento : Style.Theme.borde_suave
                ctx.strokeRect(132 + c * 23, 25 + r * 19, 20, 16)
            }
        }
        arrow(ctx, 275, 67, 326, 67, Style.Theme.acento, "fila 804")
        var values = [0.35, -0.62, 0.81, 0.18, -0.44, 0.56]
        for (var i = 0; i < values.length; ++i) {
            var value = values[i]
            ctx.fillStyle = value >= 0 ? Style.Theme.proceso_texto : Style.Theme.formula_texto
            var height = Math.abs(value) * 45
            ctx.fillRect(337 + i * 25, value >= 0 ? 72 - height : 72, 15, height)
        }
        ctx.strokeStyle = Style.Theme.borde
        ctx.beginPath(); ctx.moveTo(330, 72); ctx.lineTo(495, 72); ctx.stroke()
        label(ctx, "VECTOR APRENDIDO", 413, 18, Style.Theme.proceso_texto, 8, true, "center")
        arrow(ctx, 498, 67, 532, 67, Style.Theme.acento)
        box(ctx, 534, 38, 55, 60, "× √d", "escala",
            Style.Theme.formula_fondo, Style.Theme.formula_texto)
        label(ctx, "El ID solo elige la fila; los valores de la fila son los que se entrenan",
              300, 133, Style.Theme.texto_secundario_fuerte, 8, true, "center")
    }

    function drawPosition(ctx) {
        label(ctx, "MISMO EMBEDDING", 92, 13, Style.Theme.info_texto, 8, true, "center")
        box(ctx, 18, 27, 148, 42, "«banco»", "E = [0.8, 0.2, …]",
            Style.Theme.info_fondo, Style.Theme.info_texto)
        box(ctx, 18, 82, 148, 42, "«banco»", "E = [0.8, 0.2, …]",
            Style.Theme.info_fondo, Style.Theme.info_texto)
        arrow(ctx, 168, 48, 215, 48, Style.Theme.acento, "+ P₁")
        arrow(ctx, 168, 103, 215, 103, Style.Theme.acento, "+ P₄")
        ctx.strokeStyle = Style.Theme.formula_texto
        ctx.lineWidth = 2
        for (var row = 0; row < 2; ++row) {
            ctx.beginPath()
            for (var x = 220; x <= 350; x += 4) {
                var y = (row === 0 ? 48 : 103) + Math.sin((x - 220) / 13 + row * 1.7) * 13
                if (x === 220) ctx.moveTo(x, y); else ctx.lineTo(x, y)
            }
            ctx.stroke()
        }
        arrow(ctx, 356, 48, 405, 48, Style.Theme.acento)
        arrow(ctx, 356, 103, 405, 103, Style.Theme.acento)
        box(ctx, 408, 27, 170, 42, "VECTOR EN POSICIÓN 1", "E + P₁",
            Style.Theme.proceso_fondo, Style.Theme.proceso_texto)
        box(ctx, 408, 82, 170, 42, "VECTOR EN POSICIÓN 4", "E + P₄",
            Style.Theme.proceso_fondo, Style.Theme.proceso_texto)
        label(ctx, "La palabra es igual; el patrón posicional hace que la entrada sea diferente",
              300, 137, Style.Theme.concepto_texto, 8, true, "center")
    }

    function drawQkv(ctx) {
        box(ctx, 15, 47, 92, 52, "TOKEN X", "vector contextual",
            Style.Theme.superficie_alterna, Style.Theme.texto_secundario_fuerte)
        var ys = [18, 61, 104]
        var letters = ["Q", "K", "V"]
        var roles = ["qué busca", "cómo se identifica", "qué entrega"]
        var fills = [Style.Theme.matriz_query_fondo, Style.Theme.matriz_key_fondo,
                     Style.Theme.matriz_value_fondo]
        var colors = [Style.Theme.matriz_query_texto, Style.Theme.matriz_key_texto,
                      Style.Theme.matriz_value_texto]
        for (var i = 0; i < 3; ++i) {
            arrow(ctx, 108, 73, 175, ys[i] + 13, colors[i])
            pill(ctx, 178, ys[i], 52, letters[i], fills[i], colors[i], true)
            box(ctx, 250, ys[i] - 3, 135, 29, roles[i], "", fills[i], colors[i])
        }
        arrow(ctx, 388, 31, 435, 55, Style.Theme.acento)
        arrow(ctx, 388, 74, 435, 65, Style.Theme.acento)
        arrow(ctx, 388, 117, 435, 76, Style.Theme.acento)
        box(ctx, 438, 39, 145, 61, "ATENCIÓN", "Q·K decide el peso\nel peso mezcla V",
            Style.Theme.concepto_fondo, Style.Theme.concepto_texto)
        label(ctx, "Q y K deciden · V transporta", 510, 122,
              Style.Theme.proceso_texto, 9, true, "center")
    }

    function drawAttention(ctx) {
        pill(ctx, 10, 54, 52, "Q", Style.Theme.matriz_query_fondo,
             Style.Theme.matriz_query_texto, true)
        arrow(ctx, 63, 66, 82, 66, Style.Theme.matriz_query)
        box(ctx, 84, 30, 94, 72, "Q · Kᵀ", "scores\n[2.1, 0.7, −0.2]",
            Style.Theme.matriz_key_fondo, Style.Theme.matriz_key_texto)
        arrow(ctx, 179, 66, 207, 66, Style.Theme.acento, "÷ √dₖ")
        box(ctx, 210, 30, 94, 72, "SOFTMAX", "pesos positivos\ny suma = 1",
            Style.Theme.formula_fondo, Style.Theme.formula_texto)
        arrow(ctx, 305, 66, 326, 66, Style.Theme.acento)
        var bars = [0.72, 0.18, 0.10]
        var names = ["gato", "duerme", "."]
        for (var i = 0; i < bars.length; ++i) {
            label(ctx, names[i], 328, 34 + i * 30, Style.Theme.texto_secundario, 8, false)
            ctx.fillStyle = Style.Theme.divisor
            roundedPath(ctx, 370, 28 + i * 30, 74, 12, 6); ctx.fill()
            ctx.fillStyle = root.attentionColor(bars[i])
            roundedPath(ctx, 370, 28 + i * 30, 74 * bars[i], 12, 6); ctx.fill()
            label(ctx, Math.round(bars[i] * 100) + "%", 451, 34 + i * 30,
                  Style.Theme.info_texto, 8, true)
            curveArrow(ctx, 478, 34 + i * 30,
                       494, 34 + i * 30, 504, 58 + i * 8,
                       520, 58 + i * 8, Style.Theme.matriz_value_texto)
        }
        label(ctx, "peso × V", 491, 16, Style.Theme.matriz_value_texto,
              8, true, "center")
        box(ctx, 521, 42, 68, 62, "Σ CONTEXTO", "mezcla de V",
            Style.Theme.proceso_fondo,
            Style.Theme.proceso_texto)
        label(ctx, "Los pesos suman 1 y controlan cuánto aporta cada Value",
              300, 135, Style.Theme.proceso_texto, 8, true, "center")
    }

    function drawMultiHead(ctx) {
        box(ctx, 14, 48, 86, 50, "ENTRADA X", "mismos tokens",
            Style.Theme.superficie_alterna, Style.Theme.texto_secundario_fuerte)
        var ys = [16, 58, 100]
        var labels = ["H1 · sintaxis", "H2 · referencia", "H3 · posición"]
        var colors = [Style.Theme.info_texto, Style.Theme.concepto_texto,
                      Style.Theme.proceso_texto]
        var fills = [Style.Theme.info_fondo, Style.Theme.concepto_fondo,
                     Style.Theme.proceso_fondo]
        for (var i = 0; i < 3; ++i) {
            arrow(ctx, 101, 73, 160, ys[i] + 14, colors[i])
            box(ctx, 163, ys[i], 135, 29, labels[i], "", fills[i], colors[i])
            arrow(ctx, 299, ys[i] + 14, 365, 73, colors[i])
        }
        box(ctx, 368, 43, 100, 60, "CONCAT", "une todas\nlas cabezas",
            Style.Theme.formula_fondo, Style.Theme.formula_texto)
        arrow(ctx, 469, 73, 505, 73, Style.Theme.acento, "Wᴼ")
        box(ctx, 508, 43, 78, 60, "SALIDA", "d_model",
            Style.Theme.proceso_fondo, Style.Theme.proceso_texto)
        label(ctx, "Cada cabeza puede especializarse sin perder las demás perspectivas",
              300, 135, Style.Theme.concepto_texto, 8, true, "center")
    }

    function drawMask(ctx) {
        var n = 5, cell = 22, ox = 42, oy = 20
        label(ctx, "KEY →", ox + 55, 10, Style.Theme.texto_secundario, 8, true, "center")
        label(ctx, "QUERY ↓", 5, oy + 55, Style.Theme.texto_secundario, 8, true)
        for (var r = 0; r < n; ++r) {
            for (var c = 0; c < n; ++c) {
                var allowed = c <= r
                ctx.fillStyle = allowed ? Style.Theme.proceso_fondo : Style.Theme.error_fondo
                roundedPath(ctx, ox + c * (cell + 3), oy + r * (cell + 3), cell, cell, 4)
                ctx.fill()
                ctx.strokeStyle = allowed ? Style.Theme.proceso_texto : Style.Theme.error_texto
                ctx.stroke()
                label(ctx, allowed ? "✓" : "×", ox + c * (cell + 3) + 11,
                      oy + r * (cell + 3) + 11,
                      allowed ? Style.Theme.proceso_texto : Style.Theme.error_texto,
                      9, true, "center")
            }
        }
        arrow(ctx, 188, 71, 243, 71, Style.Theme.acento)
        box(ctx, 247, 23, 145, 42, "PASADO + PRESENTE", "scores conservados",
            Style.Theme.proceso_fondo, Style.Theme.proceso_texto)
        box(ctx, 247, 79, 145, 42, "FUTURO", "score = −∞",
            Style.Theme.error_fondo, Style.Theme.error_texto)
        arrow(ctx, 394, 99, 440, 99, Style.Theme.error_texto, "Softmax")
        box(ctx, 443, 77, 135, 45, "PESO CERO", "no puede copiarse",
            Style.Theme.superficie_alterna, Style.Theme.texto_secundario_fuerte)
        label(ctx, "La diagonal sí se permite: la posición puede verse a sí misma",
              420, 17, Style.Theme.info_texto, 8, true, "center")
    }

    function drawGeneration(ctx) {
        label(ctx, "PREFIJO ACTUAL", 88, 16, Style.Theme.info_texto, 8, true, "center")
        pill(ctx, 14, 30, 54, "BOS", Style.Theme.info_fondo, Style.Theme.info_texto, false)
        pill(ctx, 72, 30, 42, "El", Style.Theme.info_fondo, Style.Theme.info_texto, false)
        pill(ctx, 118, 30, 58, "gato", Style.Theme.info_fondo, Style.Theme.info_texto, true)
        arrow(ctx, 177, 42, 222, 42, Style.Theme.acento)
        box(ctx, 225, 18, 105, 55, "TRANSFORMER", "calcula logits",
            Style.Theme.concepto_fondo, Style.Theme.concepto_texto)
        arrow(ctx, 331, 43, 373, 43, Style.Theme.acento)
        var probs = [0.58, 0.27, 0.15]
        var words = ["duerme", "corre", "come"]
        for (var i = 0; i < probs.length; ++i) {
            label(ctx, words[i], 378, 20 + i * 24, Style.Theme.texto_secundario, 8, false)
            ctx.fillStyle = Style.Theme.divisor
            roundedPath(ctx, 425, 14 + i * 24, 100, 11, 5); ctx.fill()
            ctx.fillStyle = i === 0 ? Style.Theme.proceso_texto : Style.Theme.info
            roundedPath(ctx, 425, 14 + i * 24, 100 * probs[i], 11, 5); ctx.fill()
        }
        pill(ctx, 477, 91, 95, "+ duerme", Style.Theme.proceso_fondo,
             Style.Theme.proceso_texto, true)
        curveArrow(ctx, 477, 102, 385, 139, 113, 139, 112, 55,
                   Style.Theme.proceso_texto)
        captionTag(ctx, "se agrega y la secuencia vuelve a entrar",
                   297, 130, Style.Theme.proceso_texto, 8)
    }

    function drawSelection(ctx) {
        label(ctx, "LOGITS", 72, 13, Style.Theme.formula_texto, 8, true, "center")
        var heights = [30, 65, 42, 20]
        var tokenNames = ["El", "duerme", "gato", "EOS"]
        var colors = [Style.Theme.info, Style.Theme.acento, Style.Theme.proceso_texto,
                      Style.Theme.formula_texto]
        for (var i = 0; i < heights.length; ++i) {
            ctx.fillStyle = colors[i]
            roundedPath(ctx, 25 + i * 26, 103 - heights[i], 17, heights[i], 4); ctx.fill()
            label(ctx, tokenNames[i], 33 + i * 26, 113,
                  Style.Theme.texto_secundario, 6, i === 1, "center")
        }
        arrow(ctx, 137, 67, 178, 67, Style.Theme.acento)
        box(ctx, 181, 38, 94, 67, "TEMPERATURA", "T baja: concentra\nT alta: aplana",
            Style.Theme.formula_fondo, Style.Theme.formula_texto)
        arrow(ctx, 276, 67, 318, 67, Style.Theme.acento)
        ctx.fillStyle = Style.Theme.concepto_fondo
        ctx.strokeStyle = Style.Theme.concepto_texto
        ctx.lineWidth = 1.5
        ctx.beginPath(); ctx.moveTo(322, 35); ctx.lineTo(420, 35); ctx.lineTo(388, 105); ctx.lineTo(354, 105); ctx.closePath(); ctx.fill(); ctx.stroke()
        label(ctx, "TOP‑K / TOP‑P", 371, 58, Style.Theme.concepto_texto, 9, true, "center")
        label(ctx, "descarta candidatos", 371, 78, Style.Theme.texto_secundario, 8, false, "center")
        arrow(ctx, 421, 67, 467, 67, Style.Theme.acento)
        pill(ctx, 477, 60, 104, "«duerme»", Style.Theme.proceso_fondo,
             Style.Theme.proceso_texto, true)
        label(ctx, "argmax = determinista · muestreo = diversidad controlada",
              300, 129, Style.Theme.texto_secundario_fuerte, 8, true, "center")
    }

    function drawTrainVsInfer(ctx) {
        label(ctx, "ENTRENAMIENTO", 18, 18, Style.Theme.formula_texto, 9, true)
        pill(ctx, 18, 29, 92, "entrada", Style.Theme.info_fondo, Style.Theme.info_texto, false)
        pill(ctx, 18, 58, 92, "+ objetivo", Style.Theme.formula_fondo, Style.Theme.formula_texto, true)
        arrow(ctx, 111, 57, 150, 57, Style.Theme.formula_texto)
        box(ctx, 153, 28, 104, 59, "LOSS", "backward()",
            Style.Theme.formula_fondo, Style.Theme.formula_texto)
        arrow(ctx, 258, 57, 297, 57, Style.Theme.proceso_texto)
        pill(ctx, 304, 45, 107, "θ cambia", Style.Theme.proceso_fondo,
             Style.Theme.proceso_texto, true)
        ctx.strokeStyle = Style.Theme.borde_medio
        ctx.beginPath(); ctx.moveTo(10, 99); ctx.lineTo(590, 99); ctx.stroke()
        label(ctx, "INFERENCIA", 18, 114, Style.Theme.info_texto, 9, true)
        pill(ctx, 112, 104, 92, "prompt", Style.Theme.info_fondo, Style.Theme.info_texto, false)
        arrow(ctx, 205, 116, 250, 116, Style.Theme.info)
        box(ctx, 253, 101, 104, 33, "MODELO", "θ fijo",
            Style.Theme.concepto_fondo, Style.Theme.concepto_texto)
        arrow(ctx, 358, 117, 405, 117, Style.Theme.info)
        pill(ctx, 412, 105, 115, "genera token", Style.Theme.proceso_fondo,
             Style.Theme.proceso_texto, true)
        label(ctx, "θ fijo · sin loss · sin gradiente", 536, 137,
              Style.Theme.texto_secundario, 8, false, "center")
    }

    function drawCrossEntropy(ctx) {
        var names = ["perro", "gato ✓", "casa", "corre"]
        var probs = [0.55, 0.10, 0.22, 0.13]
        label(ctx, "PROBABILIDADES DEL VOCABULARIO", 16, 13,
              Style.Theme.texto_secundario, 8, true)
        for (var i = 0; i < names.length; ++i) {
            label(ctx, names[i], 16, 34 + i * 24,
                  i === 1 ? Style.Theme.proceso_texto : Style.Theme.texto_secundario,
                  8, i === 1)
            ctx.fillStyle = Style.Theme.divisor
            roundedPath(ctx, 75, 28 + i * 24, 170, 12, 6); ctx.fill()
            ctx.fillStyle = i === 1 ? Style.Theme.proceso_texto : Style.Theme.info
            roundedPath(ctx, 75, 28 + i * 24, 170 * probs[i], 12, 6); ctx.fill()
            label(ctx, Math.round(probs[i] * 100) + "%", 255, 34 + i * 24,
                  i === 1 ? Style.Theme.proceso_texto : Style.Theme.info_texto,
                  8, true)
        }
        arrow(ctx, 280, 70, 338, 70, Style.Theme.formula_texto, "tomar p correcta")
        box(ctx, 342, 35, 110, 70, "−log(p)", "−log(0.10)",
            Style.Theme.formula_fondo, Style.Theme.formula_texto)
        arrow(ctx, 453, 70, 493, 70, Style.Theme.formula_texto)
        box(ctx, 496, 35, 88, 70, "LOSS", "2.30",
            Style.Theme.error_fondo, Style.Theme.error_texto)
        label(ctx, "Menor probabilidad del objetivo implica mayor penalización",
              420, 125, Style.Theme.formula_texto, 9, true, "center")
    }

    function drawUpdate(ctx) {
        box(ctx, 12, 40, 96, 66, "PESO ANTES", "θ = 0.500",
            Style.Theme.info_fondo, Style.Theme.info_texto)
        arrow(ctx, 110, 73, 140, 73, Style.Theme.concepto_texto)
        box(ctx, 143, 24, 112, 58, "BACKWARD", "calcula g = 0.30\ny lo guarda en .grad",
            Style.Theme.concepto_fondo, Style.Theme.concepto_texto)
        arrow(ctx, 199, 83, 199, 95, Style.Theme.texto_secundario_fuerte)
        pill(ctx, 143, 97, 112, "θ aún no cambia",
             Style.Theme.superficie_alterna, Style.Theme.texto_secundario_fuerte, false)
        arrow(ctx, 256, 54, 289, 54, Style.Theme.formula_texto)
        box(ctx, 292, 24, 120, 82, "ADAM.STEP()", "usa g + estado\nΔθ = −0.002",
            Style.Theme.formula_fondo, Style.Theme.formula_texto)
        arrow(ctx, 413, 65, 459, 65, Style.Theme.proceso_texto)
        box(ctx, 462, 32, 125, 74, "PESO NUEVO", "θ = 0.498\nparámetro actualizado",
            Style.Theme.proceso_fondo, Style.Theme.proceso_texto)
        label(ctx, "backward calcula el gradiente · optimizer.step aplica el cambio",
              300, 136, Style.Theme.proceso_texto, 8, true, "center")
    }

    function drawDataset(ctx) {
        label(ctx, "CAMPOS DEL REGISTRO", 68, 10,
              Style.Theme.texto_secundario, 8, true, "center")
        box(ctx, 12, 18, 112, 29, "instruction", "Resume",
            Style.Theme.info_fondo, Style.Theme.info_texto)
        box(ctx, 12, 53, 112, 29, "context", "Texto fuente",
            Style.Theme.concepto_fondo, Style.Theme.concepto_texto)
        box(ctx, 12, 105, 112, 29, "response", "Un resumen",
            Style.Theme.formula_fondo, Style.Theme.formula_texto)
        arrow(ctx, 125, 33, 174, 43, Style.Theme.info)
        arrow(ctx, 125, 67, 174, 52, Style.Theme.concepto_texto)
        box(ctx, 177, 27, 128, 45, "ENTRADA ENCODER", "instruction + context",
            Style.Theme.info_fondo, Style.Theme.info_texto)
        arrow(ctx, 306, 49, 385, 49, Style.Theme.info_texto)
        box(ctx, 388, 27, 150, 45, "MEMORIA DEL ENCODER", "H_enc queda disponible",
            Style.Theme.concepto_fondo, Style.Theme.concepto_texto)
        arrow(ctx, 125, 119, 174, 105, Style.Theme.formula_texto)
        box(ctx, 177, 88, 145, 41, "ENTRADA DECODER", "BOS + response[:-1]",
            Style.Theme.formula_fondo, Style.Theme.formula_texto)
        curveArrow(ctx, 125, 119, 225, 143, 360, 143, 388, 112,
                   Style.Theme.proceso_texto)
        box(ctx, 388, 88, 150, 41, "OBJETIVO", "response[1:] + EOS",
            Style.Theme.proceso_fondo, Style.Theme.proceso_texto)
        arrow(ctx, 323, 82, 386, 82, Style.Theme.acento,
              "alineados +1")
    }

    function drawTeacher(ctx) {
        var xs = [170, 270, 370]
        var input = ["BOS", "hola", "mundo"]
        var target = ["hola", "mundo", "EOS"]
        label(ctx, "POSICIÓN", 86, 18, Style.Theme.texto_secundario, 8, true)
        label(ctx, "1", xs[0] + 32, 18, Style.Theme.texto_secundario, 8, true, "center")
        label(ctx, "2", xs[1] + 32, 18, Style.Theme.texto_secundario, 8, true, "center")
        label(ctx, "3", xs[2] + 32, 18, Style.Theme.texto_secundario, 8, true, "center")
        label(ctx, "ENTRADA", 18, 47, Style.Theme.info_texto, 9, true)
        label(ctx, "OBJETIVO", 18, 104, Style.Theme.proceso_texto, 9, true)
        for (var i = 0; i < 3; ++i) {
            pill(ctx, xs[i], 34, 65, input[i], Style.Theme.info_fondo,
                 Style.Theme.info_texto, i === 0)
            arrow(ctx, xs[i] + 32, 58, xs[i] + 32, 88,
                  Style.Theme.acento, "predice")
            pill(ctx, xs[i], 91, 65, target[i], Style.Theme.proceso_fondo,
                 Style.Theme.proceso_texto, i === 2)
        }
        box(ctx, 475, 42, 108, 69, "EN PARALELO", "3 pérdidas\nen una pasada",
            Style.Theme.formula_fondo, Style.Theme.formula_texto)
        label(ctx, "La entrada está desplazada exactamente una posición respecto al objetivo",
              300, 135, Style.Theme.concepto_texto, 8, true, "center")
    }

    function drawEpochBatch(ctx) {
        label(ctx, "DATASET · 12 EJEMPLOS", 15, 14, Style.Theme.texto_secundario, 8, true)
        var colors = [Style.Theme.info, Style.Theme.acento, Style.Theme.proceso_texto]
        for (var i = 0; i < 12; ++i) {
            var group = Math.floor(i / 4)
            ctx.fillStyle = colors[group]
            ctx.beginPath(); ctx.arc(25 + (i % 4) * 28, 38 + group * 32, 8, 0, Math.PI * 2); ctx.fill()
            label(ctx, String(i + 1), 25 + (i % 4) * 28, 38 + group * 32,
                  Style.Theme.texto_sobre_color, 7, true, "center")
        }
        var names = ["BATCH 1", "BATCH 2", "BATCH 3"]
        for (var g = 0; g < 3; ++g) {
            box(ctx, 170, 22 + g * 39, 95, 31, names[g], "4 ejemplos",
                g === 0 ? Style.Theme.info_fondo : (g === 1 ? Style.Theme.concepto_fondo : Style.Theme.proceso_fondo),
                colors[g])
            arrow(ctx, 266, 37 + g * 39, 315, 37 + g * 39, colors[g])
            pill(ctx, 320, 26 + g * 39, 102, "optimizer.step",
                 Style.Theme.formula_fondo, Style.Theme.formula_texto, false)
        }
        box(ctx, 465, 38, 115, 66, "1 EPOCH", "12/12 vistos\nmezclar y repetir",
            Style.Theme.proceso_fondo, Style.Theme.proceso_texto)
        for (g = 0; g < 3; ++g)
            arrow(ctx, 424, 38 + g * 39, 464, 69, Style.Theme.proceso_texto)
        curveArrow(ctx, 520, 106, 520, 139, 82, 139, 82, 119, Style.Theme.acento)
    }

    function paintScene(ctx, width, height) {
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        ctx.save()
        var sceneScale = Math.min(width / 600, height / 145)
        ctx.translate((width - 600 * sceneScale) / 2,
                      (height - 145 * sceneScale) / 2)
        ctx.scale(sceneScale, sceneScale)
        var id = root.conceptId
        if (id === "que_es_transformer") drawQueEsTransformer(ctx)
        else if (id === "encoder_decoder_general") drawEncoderDecoder(ctx)
        else if (id === "flujo_general") drawPipeline(ctx)
        else if (id === "tokenizacion") drawTokenization(ctx)
        else if (id === "embeddings") drawEmbedding(ctx)
        else if (id === "positional_encoding") drawPosition(ctx)
        else if (id === "query_key_value") drawQkv(ctx)
        else if (id === "formula_attention_completa") drawAttention(ctx)
        else if (id === "problema_multi_head") drawMultiHead(ctx)
        else if (id === "por_que_mascara") drawMask(ctx)
        else if (id === "generacion_token_por_token") drawGeneration(ctx)
        else if (id === "seleccion_token") drawSelection(ctx)
        else if (id === "entrenamiento_vs_inferencia") drawTrainVsInfer(ctx)
        else if (id === "cross_entropy") drawCrossEntropy(ctx)
        else if (id === "actualizacion_parametros") drawUpdate(ctx)
        else if (id === "dataset") drawDataset(ctx)
        else if (id === "teacher_forcing") drawTeacher(ctx)
        else if (id === "epoch_batch") drawEpochBatch(ctx)
        else drawPipeline(ctx)
        ctx.restore()
    }

    Canvas {
        id: diagram
        anchors.fill: parent
        antialiasing: true
        renderStrategy: Canvas.Cooperative
        onPaint: root.paintScene(getContext("2d"), width, height)
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    onConceptIdChanged: diagram.requestPaint()

    Connections {
        target: Style.Theme
        function onModoOscuroChanged() { diagram.requestPaint() }
    }
}
