.pragma library
// Gráficos de la «Vista general» de los módulos 1, 2 y 4–8. Cada función dibuja
// un tipo de etapa como función pura de `r`, el avance de la operación: así la
// escena se puede repetir y respeta el movimiento reducido.
// `s` es la escena (medidas, tokens y utilidades de dibujo) y `t` el tema.
// Los números son ilustrativos: el cálculo real vive en «Animación detallada».

function txt(ctx, s, value, x, y, color, size, bold, maxWidth) {
    ctx.fillStyle = String(color)
    ctx.font = (bold === false ? "" : "bold ") + Math.max(9, (size || 8) * s.sx) + "px sans-serif"
    ctx.textAlign = "center"
    ctx.textBaseline = "middle"
    if (maxWidth !== undefined)
        ctx.fillText(String(value), x, y, Math.max(4, maxWidth))
    else
        ctx.fillText(String(value), x, y)
}

function cell(ctx, x, y, w, h, fill, stroke, alpha) {
    ctx.save()
    ctx.globalAlpha = alpha === undefined ? 1 : alpha
    ctx.fillStyle = String(fill)
    ctx.fillRect(x, y, w, h)
    if (stroke) {
        ctx.strokeStyle = String(stroke)
        ctx.lineWidth = 1
        ctx.strokeRect(x, y, w, h)
    }
    ctx.restore()
}

// Una fila de celdas cuyo color oscurece con la magnitud: el vector como objeto.
function vector(ctx, x, y, w, h, values, color, fill, r) {
    var gap = 2
    var size = (w - gap * (values.length - 1)) / values.length
    for (var index = 0; index < values.length; ++index) {
        cell(ctx, x + index * (size + gap), y, size, h, fill, color, r)
        cell(ctx, x + index * (size + gap), y, size, h, color, null,
             Math.min(1, Math.abs(values[index])) * 0.75 * r)
    }
}

function curve(ctx, points, color, width, r) {
    ctx.save()
    ctx.globalAlpha = r
    ctx.strokeStyle = String(color)
    ctx.lineWidth = width
    ctx.beginPath()
    for (var index = 0; index < points.length; ++index) {
        if (index === 0)
            ctx.moveTo(points[index][0], points[index][1])
        else
            ctx.lineTo(points[index][0], points[index][1])
    }
    ctx.stroke()
    ctx.restore()
}

function tokens(s, fallback) {
    var result = []
    for (var index = 0; index < s.visibleTokenCount; ++index)
        result.push(s.tokenLabelAt(index, fallback ? fallback + index : "T" + (index + 1)))
    return result
}

// ─── Módulo 1 ───────────────────────────────────────────────────────────────

function textInput(ctx, w, h, s, t, r) {
    var phrase = s.phraseText
    var count = Math.min(phrase.length, 22)
    var size = Math.min(16 * s.sx, (w - 10) / Math.max(1, count))
    var startX = (w - size * count) / 2
    var y = h / 2 - 12 * s.sy
    for (var index = 0; index < count; ++index) {
        var shown = index / count <= r
        cell(ctx, startX + index * size, y, size - 1, 24 * s.sy, t.info_fondo,
             t.inferencia_estructura, shown ? 1 : 0.2)
        if (shown)
            txt(ctx, s, phrase.charAt(index) === " " ? "␣" : phrase.charAt(index),
                startX + index * size + size / 2, y + 12 * s.sy, t.texto_primario, 8)
    }
    txt(ctx, s, "cada casilla es un carácter", w / 2, y + 36 * s.sy, t.texto_secundario, 8, false)
}

function tokenize(ctx, w, h, s, t, r) {
    var labels = tokens(s)
    s.canvasBlock(ctx, w * 0.12, 3, w * 0.76, 22 * s.sy, t.info_fondo,
                  t.inferencia_estructura, s.phraseText, t.texto_primario, 1)
    var slot = w / labels.length
    for (var index = 0; index < labels.length; ++index) {
        var x = slot * index + slot * 0.1
        s.canvasGrowingArrow(ctx, w / 2, 26 * s.sy, x + slot * 0.4, h - 28 * s.sy,
                             t.inferencia_transformacion, 1.2 * s.sx, r)
        s.canvasBlock(ctx, x, h - 26 * s.sy, slot * 0.8, 24 * s.sy, t.exito_fondo,
                      t.inferencia_resultado, labels[index], t.exito_texto, r)
    }
}

function vocabLookup(ctx, w, h, s, t, r) {
    var labels = tokens(s).slice(0, 3)
    var ids = [7, 15, 23]
    var rows = 5
    var rowHeight = (h - 6) / rows
    var tableX = w * 0.40
    var tableW = w * 0.22
    var positions = [1, 2, 4]
    for (var row = 0; row < rows; ++row) {
        var used = positions.indexOf(row)
        cell(ctx, tableX, 3 + row * rowHeight, tableW, rowHeight - 1,
             used >= 0 ? t.acento_fondo : t.superficie_alterna,
             used >= 0 ? t.inferencia_foco : t.borde_suave, used >= 0 ? r : 1)
        txt(ctx, s, used >= 0 ? "fila " + ids[used] : "…", tableX + tableW / 2,
            3 + row * rowHeight + rowHeight / 2, t.texto_secundario, 7, false)
    }
    for (var index = 0; index < labels.length; ++index) {
        var targetY = 3 + positions[index] * rowHeight + rowHeight / 2
        var y = 3 + index * (h - 6) / labels.length
        var chipH = (h - 6) / labels.length - 4
        s.canvasBlock(ctx, 2, y, w * 0.26, chipH, t.info_fondo, t.inferencia_estructura,
                      labels[index], t.texto_primario, 1)
        s.canvasGrowingArrow(ctx, w * 0.27, y + chipH / 2, tableX - 2, targetY,
                             t.inferencia_transformacion, 1.2 * s.sx, r)
        s.canvasGrowingArrow(ctx, tableX + tableW + 2, targetY, w * 0.74, y + chipH / 2,
                             t.inferencia_foco, 1.2 * s.sx, r)
        s.canvasBlock(ctx, w * 0.75, y, w * 0.22, chipH, t.acento_fondo, t.inferencia_foco,
                      String(ids[index]), t.acento_texto, r)
    }
}

function specials(ctx, w, h, s, t, r) {
    var input = ["BOS", "yo", "como"]
    var target = ["yo", "como", "EOS"]
    var slot = (w * 0.76) / 3
    var startX = w * 0.22
    var rowH = Math.min(26 * s.sy, h * 0.34)
    txt(ctx, s, "entrada", w * 0.10, h * 0.28, t.inferencia_estructura, 8)
    txt(ctx, s, "objetivo", w * 0.10, h * 0.76, t.inferencia_foco, 8)
    for (var index = 0; index < 3; ++index) {
        s.canvasBlock(ctx, startX + index * slot, h * 0.28 - rowH / 2, slot - 5, rowH,
                      index === 0 ? t.acento_fondo : t.info_fondo, t.inferencia_estructura,
                      input[index], t.texto_primario, 1)
        s.canvasBlock(ctx, startX + index * slot, h * 0.76 - rowH / 2, slot - 5, rowH,
                      index === 2 ? t.acento_fondo : t.exito_fondo, t.inferencia_foco,
                      target[index], t.texto_primario, r)
        s.canvasGrowingArrow(ctx, startX + index * slot + slot / 2, h * 0.28 + rowH / 2,
                             startX + index * slot + slot / 2, h * 0.76 - rowH / 2,
                             t.inferencia_transformacion, 1.2 * s.sx, r)
    }
}

function batchPad(ctx, w, h, s, t, r) {
    var rows = [[true, true, true, true, true], [true, true, true, false, false],
                [true, true, true, true, false]]
    var cols = 5
    var size = Math.min((w * 0.86) / cols, (h - 16 * s.sy) / rows.length)
    var startX = (w - size * cols) / 2
    for (var row = 0; row < rows.length; ++row) {
        for (var col = 0; col < cols; ++col) {
            var real = rows[row][col]
            cell(ctx, startX + col * size, 2 + row * size, size - 2, size - 2,
                 real ? t.info_fondo : t.error_fondo,
                 real ? t.inferencia_estructura : t.inferencia_error, real ? 1 : r)
            if (real || r > 0.3)
                txt(ctx, s, real ? "id" : "PAD", startX + col * size + size / 2 - 1,
                    2 + row * size + size / 2 - 1, real ? t.texto_primario : t.error_texto, 7, true, size - 4)
        }
    }
    txt(ctx, s, "B filas × T columnas", w / 2, h - 7 * s.sy, t.texto_secundario, 8, false)
}

function batchTrim(ctx, w, h, s, t, r) {
    var cols = 8
    var limit = 6
    var size = (w * 0.92) / cols
    var startX = w * 0.04
    var y = h / 2 - size / 2
    for (var col = 0; col < cols; ++col) {
        var outside = col >= limit
        cell(ctx, startX + col * size, y, size - 3, size,
             outside ? t.error_fondo : t.info_fondo,
             outside ? t.inferencia_error : t.inferencia_estructura, outside ? 1 - 0.7 * r : 1)
        txt(ctx, s, "id", startX + col * size + size / 2 - 1, y + size / 2, t.texto_primario, 7)
    }
    var lineX = startX + limit * size - 1.5
    curve(ctx, [[lineX, y - 12 * s.sy], [lineX, y + size + 8 * s.sy]], t.inferencia_error, 2 * s.sx, r)
    txt(ctx, s, "T_max", lineX, y - 18 * s.sy, t.error_texto, 8)
}

function padMask(ctx, w, h, s, t, r) {
    var labels = tokens(s).slice(0, 3)
    if (s.paddingIndex < 0)
        labels.push("PAD (ej.)")
    var size = (w * 0.9) / labels.length
    var startX = w * 0.05
    var rowH = Math.min(26 * s.sy, h * 0.36)
    for (var index = 0; index < labels.length; ++index) {
        var pad = labels[index].toUpperCase().indexOf("PAD") >= 0
        s.canvasBlock(ctx, startX + index * size, 3, size - 4, rowH,
                      pad ? t.error_fondo : t.info_fondo,
                      pad ? t.inferencia_error : t.inferencia_estructura,
                      labels[index], t.texto_primario, 1)
        s.canvasGrowingArrow(ctx, startX + index * size + size / 2 - 2, rowH + 4,
                             startX + index * size + size / 2 - 2, h - rowH - 3,
                             t.inferencia_transformacion, 1.2 * s.sx, r)
        s.canvasBlock(ctx, startX + index * size, h - rowH - 1, size - 4, rowH,
                      pad ? t.error_fondo : t.exito_fondo,
                      pad ? t.inferencia_error : t.inferencia_resultado,
                      pad ? "False" : "True", pad ? t.error_texto : t.exito_texto, r)
    }
}

function noGrad(ctx, w, h, s, t, r) {
    var boxes = ["Tokenizar", "PAD", "Máscara", "Embedding"]
    var slot = w / boxes.length
    var cy = h * 0.36
    for (var index = 0; index < boxes.length; ++index) {
        var learns = index === boxes.length - 1
        s.canvasBlock(ctx, index * slot + 3, cy - 15 * s.sy, slot - 10, 30 * s.sy,
                      learns ? t.exito_fondo : t.superficie_alterna,
                      learns ? t.inferencia_resultado : t.borde_medio,
                      boxes[index], t.texto_primario, 1)
        if (index > 0)
            s.canvasArrow(ctx, index * slot - 7, cy, index * slot + 3, cy, t.borde_medio, 1 * s.sx, 1)
    }
    var y = h * 0.78
    s.canvasGrowingArrow(ctx, w * 0.98, y, w * 0.72, y, t.inferencia_error, 1.6 * s.sx, r)
    if (r > 0.6)
        s.canvasCross(ctx, w * 0.68, y, 7 * s.sx, t.inferencia_error, r)
    txt(ctx, s, "el gradiente se detiene aquí", w * 0.34, y, t.error_texto, 8, true, w * 0.56)
}

// ─── Módulo 2 ───────────────────────────────────────────────────────────────

function embedLookup(ctx, w, h, s, t, r) {
    var rows = 5
    var cols = 6
    var active = 2
    var tableX = w * 0.26
    var tableW = w * 0.36
    var rowH = (h - 18 * s.sy) / rows
    var colW = tableW / cols
    for (var row = 0; row < rows; ++row) {
        for (var col = 0; col < cols; ++col) {
            var shade = Math.abs(Math.sin((row + 1) * (col + 2)))
            cell(ctx, tableX + col * colW, row * rowH, colW - 1, rowH - 1,
                 row === active ? t.acento_fondo : t.superficie_alterna,
                 row === active ? t.inferencia_foco : t.borde_suave, 1)
            if (row === active)
                cell(ctx, tableX + col * colW, row * rowH, colW - 1, rowH - 1, t.inferencia_foco, null, shade * 0.7 * r)
        }
    }
    txt(ctx, s, "|V| filas × d_model columnas", tableX + tableW / 2, h - 8 * s.sy, t.texto_secundario, 7, false, tableW)
    s.canvasBlock(ctx, 2, active * rowH - 2, w * 0.18, rowH + 4, t.info_fondo, t.inferencia_estructura, "ID", t.texto_primario, 1)
    s.canvasGrowingArrow(ctx, w * 0.20, active * rowH + rowH / 2, tableX - 2, active * rowH + rowH / 2, t.inferencia_transformacion, 1.4 * s.sx, r)
    s.canvasGrowingArrow(ctx, tableX + tableW + 2, active * rowH + rowH / 2, w * 0.70, active * rowH + rowH / 2, t.inferencia_foco, 1.4 * s.sx, r)
    var values = []
    for (var v = 0; v < cols; ++v)
        values.push(Math.sin((active + 1) * (v + 2)))
    vector(ctx, w * 0.71, active * rowH, w * 0.27, rowH, values, t.inferencia_resultado, t.exito_fondo, r)
}

function barsPair(ctx, x, w, baseY, values, scale, color, r) {
    var slot = w / values.length
    for (var index = 0; index < values.length; ++index) {
        var height = values[index] * scale * r
        cell(ctx, x + index * slot + slot * 0.15, baseY - height, slot * 0.7, height, color, null, 0.25 + 0.75 * r)
    }
}

function scaleVector(ctx, w, h, s, t, r) {
    var values = [0.35, 0.18, 0.28, 0.12]
    var baseY = h - 12 * s.sy
    barsPair(ctx, w * 0.03, w * 0.32, baseY, values, h * 0.8, t.inferencia_estructura, 1)
    txt(ctx, s, "e", w * 0.19, h - 5 * s.sy, t.texto_secundario, 8)
    s.canvasGrowingArrow(ctx, w * 0.38, h / 2, w * 0.60, h / 2, t.inferencia_transformacion, 1.5 * s.sx, r)
    txt(ctx, s, "× √d_model", w * 0.49, h / 2 - 11 * s.sy, t.inferencia_transformacion, 8)
    barsPair(ctx, w * 0.64, w * 0.32, baseY, values, h * (0.8 + 1.2 * r), t.inferencia_resultado, r)
    txt(ctx, s, "e · √d_model", w * 0.80, h - 5 * s.sy, t.texto_secundario, 8, true, w * 0.32)
}

function posWave(ctx, w, h, s, t, r) {
    var plotH = h - 14 * s.sy
    var freqs = [
        { f: 0.5, color: t.inferencia_estructura, phase: 0 },
        { f: 1.1, color: t.inferencia_transformacion, phase: 1.57 },
        { f: 2.3, color: t.inferencia_foco, phase: 0 }
    ]
    var band = plotH / freqs.length
    for (var line = 0; line < freqs.length; ++line) {
        var center = band * (line + 0.5)
        var points = []
        var limit = Math.max(2, Math.round(60 * r))
        for (var step = 0; step <= limit; ++step) {
            var x = w * 0.04 + (w * 0.92) * step / 60
            points.push([x, center - Math.sin(step / 60 * 6.283 * freqs[line].f + freqs[line].phase) * band * 0.36])
        }
        curve(ctx, points, freqs[line].color, 1.5 * s.sx, 1)
    }
    var positions = [0, 1, 2, 3]
    for (var index = 0; index < positions.length; ++index) {
        var px = w * 0.04 + (w * 0.92) * (index * 2 + 1) / 8
        curve(ctx, [[px, 0], [px, plotH]], t.borde_medio, 1, 0.8)
        txt(ctx, s, "pos " + positions[index], px, h - 6 * s.sy, t.texto_secundario, 7)
    }
}

function addVector(ctx, w, h, s, t, r) {
    var def = s.stageDefinition
    var first = [0.8, 0.2, 0.5, 0.1]
    var second = [0.1, 0.6, 0.2, 0.9]
    var sum = [0.9, 0.8, 0.7, 1.0]
    var vectorW = w * 0.25
    var rowH = Math.min(30 * s.sy, h * 0.42)
    var y = h / 2 - rowH / 2
    vector(ctx, w * 0.01, y, vectorW, rowH, first, t.inferencia_estructura, t.info_fondo, 1)
    txt(ctx, s, def.firstLabel || "A", w * 0.01 + vectorW / 2, y - 9 * s.sy, t.info_texto, 8)
    txt(ctx, s, "+", w * 0.30, h / 2, t.texto_primario, 15)
    vector(ctx, w * 0.33, y, vectorW, rowH, second, t.inferencia_foco, t.acento_fondo, r)
    txt(ctx, s, def.secondLabel || "B", w * 0.33 + vectorW / 2, y - 9 * s.sy, t.acento_texto, 8)
    txt(ctx, s, "=", w * 0.62, h / 2, t.texto_primario, 15)
    vector(ctx, w * 0.66, y, vectorW + w * 0.06, rowH, sum, t.inferencia_resultado, t.exito_fondo, r)
    txt(ctx, s, def.resultLabel || "C", w * 0.66 + (vectorW + w * 0.06) / 2, y - 9 * s.sy, t.exito_texto, 8)
    txt(ctx, s, "mismo ancho: se suma celda por celda", w / 2, y + rowH + 11 * s.sy, t.texto_secundario, 8, false)
}

function dropout(ctx, w, h, s, t, r) {
    var dropped = s.stageDefinition.droppedCells === true
    var rows = 3
    var cols = 8
    var off = { "0,2": 1, "0,6": 1, "1,1": 1, "1,4": 1, "2,3": 1, "2,7": 1 }
    var size = Math.min((w * 0.9) / cols, (h - 4) / rows)
    var startX = (w - size * cols) / 2
    for (var row = 0; row < rows; ++row) {
        for (var col = 0; col < cols; ++col) {
            var isOff = dropped && off[row + "," + col] === 1
            var x = startX + col * size
            var y = 2 + row * size
            cell(ctx, x, y, size - 2, size - 2, isOff ? t.error_fondo : t.exito_fondo,
                 isOff ? t.inferencia_error : t.inferencia_resultado, 1)
            if (isOff && r > 0.2)
                s.canvasCross(ctx, x + size / 2 - 1, y + size / 2 - 1, size * 0.22, t.inferencia_error, r)
        }
    }
}

// ─── Aprendizaje (compartido) ───────────────────────────────────────────────

function gradientBack(ctx, w, h, s, t, r) {
    var roles = s.stageDefinition.roles || []
    var cy = h / 2
    s.canvasBlock(ctx, w * 0.76, cy - 17 * s.sy, w * 0.21, 34 * s.sy, t.error_fondo,
                  t.inferencia_error, "error", t.error_texto, r)
    var rowH = (h - 4) / Math.max(1, roles.length)
    for (var index = 0; index < roles.length; ++index) {
        var y = 2 + index * rowH
        var blockH = Math.min(24 * s.sy, rowH - 3)
        s.canvasGrowingArrow(ctx, w * 0.75, cy, w * 0.36, y + blockH / 2, t.inferencia_error, 1.5 * s.sx, r)
        s.canvasBlock(ctx, w * 0.03, y, w * 0.31, blockH, t.info_fondo, t.inferencia_estructura,
                      roles[index], t.texto_primario, 0.3 + 0.7 * r)
    }
}

function updateParams(ctx, w, h, s, t, r) {
    var roles = s.stageDefinition.roles || []
    var rowH = (h - 4) / Math.max(1, roles.length)
    for (var index = 0; index < roles.length; ++index) {
        var y = 2 + index * rowH
        var blockH = Math.min(24 * s.sy, rowH - 3)
        s.canvasBlock(ctx, w * 0.02, y, w * 0.26, blockH, t.info_fondo, t.inferencia_estructura, roles[index], t.texto_primario, 1)
        s.canvasGrowingArrow(ctx, w * 0.30, y + blockH / 2, w * 0.66, y + blockH / 2, t.inferencia_transformacion, 1.3 * s.sx, r)
        txt(ctx, s, "− η g", w * 0.48, y + blockH / 2 - 7 * s.sy, t.inferencia_transformacion, 7)
        s.canvasBlock(ctx, w * 0.68, y, w * 0.29, blockH, t.exito_fondo, t.inferencia_resultado, roles[index] + "′", t.exito_texto, r)
    }
}

// ─── Módulo 4 ───────────────────────────────────────────────────────────────

function projectJoint(ctx, w, h, s, t, r) {
    var cy = h / 2
    s.canvasBlock(ctx, 4, cy - 18 * s.sy, w * 0.16, 36 * s.sy, t.info_fondo, t.inferencia_estructura, "X", t.texto_primario, 1)
    var roles = [["Q", t.matriz_query, t.matriz_query_fondo], ["K", t.matriz_key, t.matriz_key_fondo], ["V", t.matriz_value, t.matriz_value_fondo]]
    var rowH = (h - 6) / 3
    for (var index = 0; index < 3; ++index) {
        var y = 3 + index * rowH
        s.canvasGrowingArrow(ctx, w * 0.21, cy, w * 0.40, y + rowH / 2, roles[index][1], 1.4 * s.sx, r)
        s.canvasBlock(ctx, w * 0.42, y, w * 0.54, rowH - 4, roles[index][2], roles[index][1], roles[index][0] + " · ancho d_model", t.texto_primario, r)
    }
}

function splitHeads(ctx, w, h, s, t, r) {
    var heads = 4
    var fullW = w * 0.92
    var startX = w * 0.04
    var topH = Math.min(24 * s.sy, h * 0.3)
    s.canvasBlock(ctx, startX, 2, fullW, topH, t.info_fondo, t.inferencia_estructura, "d_model", t.texto_primario, 1)
    var slot = fullW / heads
    var colors = [t.inferencia_estructura, t.inferencia_transformacion, t.inferencia_foco, t.inferencia_resultado]
    var targetY = h - topH - 4
    for (var index = 0; index < heads; ++index) {
        var gap = 6 * s.sx * r
        var x = startX + index * slot + (index - 1.5) * gap / 3
        var y = 2 + topH + (targetY - 2 - topH) * r
        s.canvasBlock(ctx, x, y, slot - 3, topH, t.superficie_alterna, colors[index], "cabeza " + (index + 1), t.texto_primario, 0.3 + 0.7 * r)
    }
    txt(ctx, s, "d_model = h × d_head", w / 2, topH + (targetY - topH) / 2 + 2, t.texto_secundario, 8, false)
}

function miniMap(ctx, x, y, size, pattern, color, fill, r, highlighted) {
    var n = pattern.length
    var c = size / n
    for (var row = 0; row < n; ++row) {
        for (var col = 0; col < n; ++col) {
            cell(ctx, x + col * c, y + row * c, c - 1, c - 1, fill, null, 1)
            cell(ctx, x + col * c, y + row * c, c - 1, c - 1, color, null, pattern[row][col] * r)
        }
    }
    if (highlighted) {
        ctx.save()
        ctx.strokeStyle = String(color)
        ctx.lineWidth = 2
        ctx.strokeRect(x - 2, y - 2, size + 3, size + 3)
        ctx.restore()
    }
}

var HEAD_PATTERNS = [
    [[0.9, 0.05, 0.03, 0.02], [0.1, 0.8, 0.05, 0.05], [0.05, 0.1, 0.8, 0.05], [0.05, 0.05, 0.1, 0.8]],
    [[0.1, 0.1, 0.1, 0.7], [0.7, 0.1, 0.1, 0.1], [0.1, 0.7, 0.1, 0.1], [0.1, 0.1, 0.7, 0.1]],
    [[0.4, 0.4, 0.1, 0.1], [0.4, 0.4, 0.1, 0.1], [0.1, 0.1, 0.4, 0.4], [0.1, 0.1, 0.4, 0.4]],
    [[0.25, 0.25, 0.25, 0.25], [0.6, 0.2, 0.1, 0.1], [0.2, 0.6, 0.1, 0.1], [0.1, 0.1, 0.2, 0.6]]
]

function headMaps(ctx, w, h, s, t, r) {
    var colors = [t.inferencia_estructura, t.inferencia_transformacion, t.inferencia_foco, t.inferencia_resultado]
    var slot = w / 4
    var size = Math.min(slot * 0.82, h - 16 * s.sy)
    var selected = Math.max(0, Number(s.selectedHead || 0)) % 4
    for (var index = 0; index < 4; ++index) {
        var x = index * slot + (slot - size) / 2
        miniMap(ctx, x, 3, size, HEAD_PATTERNS[index], colors[index], t.superficie_alterna, r, index === selected)
        txt(ctx, s, "cabeza " + (index + 1), index * slot + slot / 2, size + 10 * s.sy,
            index === selected ? t.texto_primario : t.texto_secundario, 7, index === selected)
    }
}

function headContexts(ctx, w, h, s, t, r) {
    var heads = 2
    var rowH = (h - 4) / heads
    var colors = [t.inferencia_estructura, t.inferencia_transformacion]
    for (var index = 0; index < heads; ++index) {
        var y = 2 + index * rowH
        var size = Math.min(rowH - 6, w * 0.16)
        miniMap(ctx, w * 0.03, y + 2, size, HEAD_PATTERNS[index], colors[index], t.superficie_alterna, 1, false)
        txt(ctx, s, "×", w * 0.03 + size + 9 * s.sx, y + rowH / 2, t.texto_primario, 12)
        s.canvasBlock(ctx, w * 0.03 + size + 17 * s.sx, y + 4, w * 0.17, rowH - 10, t.matriz_value_fondo, t.matriz_value, "V" + (index + 1), t.matriz_value_texto, 1)
        s.canvasGrowingArrow(ctx, w * 0.50, y + rowH / 2, w * 0.68, y + rowH / 2, colors[index], 1.4 * s.sx, r)
        s.canvasBlock(ctx, w * 0.70, y + 4, w * 0.27, rowH - 10, t.exito_fondo, t.inferencia_resultado, "C" + (index + 1), t.exito_texto, r)
    }
}

function concatHeads(ctx, w, h, s, t, r) {
    var heads = 4
    var colors = [t.inferencia_estructura, t.inferencia_transformacion, t.inferencia_foco, t.inferencia_resultado]
    var slot = (w * 0.86) / heads
    var startX = w * 0.07
    var blockH = Math.min(26 * s.sy, h * 0.3)
    var finalY = h - blockH - 12 * s.sy
    for (var index = 0; index < heads; ++index) {
        var x0 = startX + index * (slot * 1.0) + (index - 1.5) * 5 * s.sx * (1 - r)
        var y = 2 + (finalY - 2) * r
        s.canvasBlock(ctx, x0, y, slot - (r > 0.95 ? 0 : 2), blockH, t.superficie_alterna, colors[index], "C" + (index + 1), t.texto_primario, 1)
    }
    if (r > 0.9)
        txt(ctx, s, "ancho d_model · los bloques aún están separados", w / 2, h - 6 * s.sy, t.texto_secundario, 8, false, w * 0.96)
}

function woMix(ctx, w, h, s, t, r) {
    var cols = 4
    var rowH = h - 8
    var inX = w * 0.20
    var outX = w * 0.80
    var colors = [t.inferencia_estructura, t.inferencia_transformacion, t.inferencia_foco, t.inferencia_resultado]
    for (var i = 0; i < cols; ++i) {
        var y = 4 + (i + 0.5) * rowH / cols
        for (var j = 0; j < cols; ++j)
            s.canvasGrowingArrow(ctx, inX + 8 * s.sx, y, outX - 8 * s.sx, 4 + (j + 0.5) * rowH / cols, colors[i], 0.7 * s.sx, r * 0.8)
        s.canvasBlock(ctx, inX - w * 0.14, y - rowH / cols / 2 + 2, w * 0.21, rowH / cols - 4, t.superficie_alterna, colors[i], "C" + (i + 1), t.texto_primario, 1)
        s.canvasBlock(ctx, outX - w * 0.07, y - rowH / cols / 2 + 2, w * 0.21, rowH / cols - 4, t.exito_fondo, t.inferencia_resultado, "Y" + (i + 1), t.exito_texto, r)
    }
    txt(ctx, s, "WO", w / 2, 8 * s.sy, t.inferencia_transformacion, 9)
}

// ─── Módulo 5 y compartidos con el 6 y el 8 ─────────────────────────────────

function layerInput(ctx, w, h, s, t, r) {
    var layers = 3
    var boxH = Math.min(26 * s.sy, (h - 10) / layers - 3)
    for (var index = 0; index < layers; ++index) {
        var y = h - (index + 1) * (boxH + 4)
        s.canvasBlock(ctx, w * 0.40, y, w * 0.44, boxH, index === 1 ? t.acento_fondo : t.superficie_alterna,
                      index === 1 ? t.inferencia_foco : t.borde_medio, "Capa " + (index + 1), t.texto_primario, 1)
    }
    var targetY = h - 2 * (boxH + 4) + boxH / 2
    s.canvasBlock(ctx, w * 0.02, targetY - 15 * s.sy, w * 0.20, 30 * s.sy, t.info_fondo, t.inferencia_estructura, "X_l", t.texto_primario, 1)
    s.canvasGrowingArrow(ctx, w * 0.23, targetY, w * 0.39, targetY, t.inferencia_transformacion, 1.6 * s.sx, r)
    txt(ctx, s, "[T, d_model]", w * 0.92, targetY, t.texto_secundario, 7, false, w * 0.15)
}

function miniAttention(ctx, w, h, s, t, r) {
    var labels = tokens(s)
    var n = Math.max(1, labels.length)
    var slot = w / n
    var boxH = 22 * s.sy
    var y = h - boxH - 2
    var focused = Number(s.focusedIndex || 0)
    var causalArcs = s.stageDefinition.causalArcs === true && s.causal
    var maximum = s.maximumWeight()
    for (var index = 0; index < n; ++index) {
        var blocked = causalArcs && index > focused
        var cx = slot * (index + 0.5)
        s.canvasBlock(ctx, cx - slot * 0.42, y, slot * 0.84, boxH,
                      index === focused ? t.acento_fondo : (blocked ? t.error_fondo : t.info_fondo),
                      index === focused ? t.inferencia_foco : (blocked ? t.inferencia_error : t.inferencia_estructura),
                      labels[index], t.texto_primario, blocked ? 0.5 : 1)
        if (blocked) {
            s.canvasCross(ctx, cx, y + boxH / 2, 6 * s.sx, t.inferencia_error, r)
            continue
        }
        var strength = maximum > 0 ? s.weightFor(index) / maximum : 0.3
        var fromX = slot * (focused + 0.5)
        var points = []
        var limit = Math.max(2, Math.round(20 * r))
        for (var step = 0; step <= limit; ++step) {
            var u = step / 20
            var px = fromX + (cx - fromX) * u
            var py = y - 2 - Math.sin(u * 3.1416) * (y - 8) * (Math.abs(index - focused) === 0 ? 0.35 : 0.9)
            points.push([px, py])
        }
        curve(ctx, points, t.inferencia_foco, (0.6 + strength * 3) * s.sx, 0.35 + 0.65 * strength)
    }
}

function residual(ctx, w, h, s, t, r) {
    var def = s.stageDefinition
    var cy = h * 0.68
    var boxH = Math.min(28 * s.sy, h * 0.36)
    s.canvasBlock(ctx, 2, cy - boxH / 2, w * 0.14, boxH, t.info_fondo, t.inferencia_estructura, def.startLabel || "X", t.texto_primario, 1)
    s.canvasGrowingArrow(ctx, w * 0.17, cy, w * 0.33, cy, t.borde_medio, 1.4 * s.sx, r)
    s.canvasBlock(ctx, w * 0.33, cy - boxH / 2, w * 0.20, boxH, t.acento_fondo, t.inferencia_foco, def.pathLabel || "F", t.acento_texto, 1)
    s.canvasGrowingArrow(ctx, w * 0.54, cy, w * 0.66, cy, t.borde_medio, 1.4 * s.sx, r)
    var nodeX = w * 0.69
    ctx.save()
    ctx.fillStyle = String(t.exito_fondo)
    ctx.strokeStyle = String(t.inferencia_resultado)
    ctx.lineWidth = 2
    ctx.beginPath()
    ctx.arc(nodeX, cy, 11 * s.sx, 0, 6.283)
    ctx.fill()
    ctx.stroke()
    ctx.restore()
    txt(ctx, s, "+", nodeX, cy, t.exito_texto, 12)
    var topY = 8 * s.sy
    curve(ctx, [[w * 0.09, cy - boxH / 2], [w * 0.09, topY], [nodeX, topY], [nodeX, cy - 11 * s.sx]], t.inferencia_estructura, 2 * s.sx, 0.25 + 0.75 * r)
    txt(ctx, s, "atajo: la entrada sigue presente", w * 0.40, topY + 9 * s.sy, t.info_texto, 8, false, w * 0.6)
    s.canvasGrowingArrow(ctx, nodeX + 12 * s.sx, cy, w * 0.82, cy, t.inferencia_resultado, 1.4 * s.sx, r)
    s.canvasBlock(ctx, w * 0.83, cy - boxH / 2, w * 0.15, boxH, t.exito_fondo, t.inferencia_resultado, def.endLabel || "R", t.exito_texto, r)
}

function layernorm(ctx, w, h, s, t, r) {
    var raw = [0.9, -0.2, 0.55, 0.1, 0.75, -0.05]
    var mean = 0.3
    var center = h / 2
    var slot = w * 0.92 / raw.length
    curve(ctx, [[w * 0.04, center], [w * 0.96, center]], t.borde_medio, 1, 1)
    txt(ctx, s, "0", w * 0.02, center, t.texto_secundario, 7)
    for (var index = 0; index < raw.length; ++index) {
        var target = (raw[index] - mean) * 1.05
        var value = raw[index] + (target - raw[index]) * r
        var height = value * h * 0.42
        cell(ctx, w * 0.05 + index * slot, height >= 0 ? center - height : center, slot * 0.66, Math.abs(height) + 1,
             r > 0.9 ? t.inferencia_resultado : t.inferencia_estructura, null, 0.9)
    }
    txt(ctx, s, "un token: sus componentes se centran en 0", w / 2, h - 5 * s.sy, t.texto_secundario, 8, false, w * 0.96)
}

function trapezoid(ctx, x1, h1, x2, h2, cy, color, alpha) {
    ctx.save()
    ctx.globalAlpha = alpha
    ctx.fillStyle = String(color)
    ctx.beginPath()
    ctx.moveTo(x1, cy - h1 / 2)
    ctx.lineTo(x2, cy - h2 / 2)
    ctx.lineTo(x2, cy + h2 / 2)
    ctx.lineTo(x1, cy + h1 / 2)
    ctx.closePath()
    ctx.fill()
    ctx.restore()
}

function ffnExpand(ctx, w, h, s, t, r) {
    var cy = h / 2
    var narrow = h * 0.28
    var wide = h * (0.28 + 0.62 * r)
    cell(ctx, w * 0.06, cy - narrow / 2, w * 0.12, narrow, t.info_fondo, t.inferencia_estructura, 1)
    trapezoid(ctx, w * 0.18, narrow, w * 0.72, wide, cy, t.acento_fondo, 0.9)
    cell(ctx, w * 0.72, cy - wide / 2, w * 0.14, wide, t.exito_fondo, t.inferencia_resultado, r)
    txt(ctx, s, "d_model", w * 0.12, cy, t.texto_primario, 7, true, w * 0.12)
    txt(ctx, s, "W₁", w * 0.45, cy, t.acento_texto, 9)
    txt(ctx, s, "d_ff", w * 0.79, cy, t.exito_texto, 8)
}

function ffnProject(ctx, w, h, s, t, r) {
    var cy = h / 2
    var wide = h * 0.9
    var narrow = h * (0.9 - 0.62 * r)
    cell(ctx, w * 0.06, cy - wide / 2, w * 0.14, wide, t.info_fondo, t.inferencia_estructura, 1)
    trapezoid(ctx, w * 0.20, wide, w * 0.74, narrow, cy, t.acento_fondo, 0.9)
    cell(ctx, w * 0.74, cy - narrow / 2, w * 0.14, narrow, t.exito_fondo, t.inferencia_resultado, r)
    txt(ctx, s, "d_ff", w * 0.13, cy, t.texto_primario, 8)
    txt(ctx, s, "W₂", w * 0.47, cy, t.acento_texto, 9)
    txt(ctx, s, "d_model", w * 0.81, cy, t.exito_texto, 7, true, w * 0.14)
}

function ffnBlock(ctx, w, h, s, t, r) {
    var cy = h / 2
    var narrow = h * 0.28
    var wide = h * 0.86
    cell(ctx, w * 0.02, cy - narrow / 2, w * 0.10, narrow, t.info_fondo, t.inferencia_estructura, 1)
    trapezoid(ctx, w * 0.12, narrow, w * 0.40, wide, cy, t.acento_fondo, 0.9)
    cell(ctx, w * 0.40, cy - wide / 2, w * 0.20, wide, t.acento_fondo, t.inferencia_foco, 1)
    trapezoid(ctx, w * 0.60, wide, w * 0.88, narrow, cy, t.acento_fondo, 0.4 + 0.5 * r)
    cell(ctx, w * 0.88, cy - narrow / 2, w * 0.10, narrow, t.exito_fondo, t.inferencia_resultado, r)
    txt(ctx, s, "d_ff + φ", w * 0.50, cy, t.acento_texto, 8, true, w * 0.2)
}

function ffnActivation(ctx, w, h, s, t, r) {
    var originX = w * 0.5
    var originY = h * 0.80
    curve(ctx, [[w * 0.08, originY], [w * 0.92, originY]], t.borde_medio, 1, 1)
    curve(ctx, [[originX, 3], [originX, h - 3]], t.borde_medio, 1, 1)
    var reach = w * 0.38 * r
    curve(ctx, [[originX - reach, originY], [originX, originY]], t.inferencia_foco, 2.4 * s.sx, 1)
    curve(ctx, [[originX, originY], [originX + reach, originY - reach * (h * 0.66) / (w * 0.38)]], t.inferencia_resultado, 2.4 * s.sx, 1)
    txt(ctx, s, "negativo → 0", w * 0.27, originY - 10 * s.sy, t.acento_texto, 8)
    txt(ctx, s, "positivo pasa", w * 0.74, originY + 9 * s.sy, t.exito_texto, 8)
}

function layerStack(ctx, w, h, s, t, r) {
    var def = s.stageDefinition
    var layers = 3
    var totalW = w * (def.sideLabel ? 0.56 : 0.66)
    var slot = totalW / layers
    var startX = 2
    var boxH = h * 0.56
    var cy = h / 2
    var name = def.layerLabel || "Capa"
    for (var index = 0; index < layers; ++index) {
        var shown = (index + 1) / layers <= r + 0.34
        s.canvasBlock(ctx, startX + index * slot, cy - boxH / 2, slot - 12 * s.sx, boxH,
                      index === layers - 1 ? t.acento_fondo : t.superficie_alterna,
                      t.inferencia_estructura, index === layers - 1 ? name + " N" : name + " " + (index + 1),
                      t.texto_primario, shown ? 1 : 0.25)
        s.canvasArrow(ctx, startX + index * slot + slot - 12 * s.sx, cy, startX + (index + 1) * slot - 1, cy,
                      t.inferencia_transformacion, 1.2 * s.sx, shown ? 1 : 0.25)
    }
    s.canvasBlock(ctx, w * 0.74, cy - boxH / 2, w * 0.24, boxH, t.exito_fondo, t.inferencia_resultado,
                  def.outLabel || "Salida", t.exito_texto, r)
    if (def.sideLabel) {
        txt(ctx, s, def.sideLabel + " → a cada capa", totalW / 2, 7 * s.sy, t.matriz_key_texto, 8, true, totalW)
    }
    txt(ctx, s, "misma forma de principio a fin", w / 2, h - 5 * s.sy, t.texto_secundario, 8, false, w)
}

// ─── Módulo 6 ───────────────────────────────────────────────────────────────

function shiftTarget(ctx, w, h, s, t, r) {
    var input = ["BOS", "el", "gato"]
    var target = ["el", "gato", "EOS"]
    var slot = (w * 0.76) / 3
    var startX = w * 0.22
    var rowH = Math.min(26 * s.sy, h * 0.34)
    txt(ctx, s, "entrada", w * 0.10, h * 0.25, t.inferencia_estructura, 8)
    txt(ctx, s, "predice", w * 0.10, h * 0.77, t.inferencia_foco, 8)
    for (var index = 0; index < 3; ++index) {
        s.canvasBlock(ctx, startX + index * slot, h * 0.25 - rowH / 2, slot - 5, rowH, t.info_fondo, t.inferencia_estructura, input[index], t.texto_primario, 1)
        s.canvasGrowingArrow(ctx, startX + index * slot + slot / 2, h * 0.25 + rowH / 2, startX + index * slot + slot / 2, h * 0.77 - rowH / 2, t.inferencia_transformacion, 1.2 * s.sx, r)
        s.canvasBlock(ctx, startX + index * slot, h * 0.77 - rowH / 2, slot - 5, rowH, t.exito_fondo, t.inferencia_foco, target[index], t.exito_texto, r)
    }
}

function growPrefix(ctx, w, h, s, t, r) {
    var rows = [["BOS"], ["BOS", "el"], ["BOS", "el", "gato"]]
    var rowH = (h - 4) / rows.length
    var slot = w * 0.76 / 3
    for (var row = 0; row < rows.length; ++row) {
        txt(ctx, s, "paso " + (row + 1), w * 0.09, 2 + row * rowH + rowH / 2, t.texto_secundario, 8, false)
        for (var col = 0; col < rows[row].length; ++col) {
            var fresh = col === row
            s.canvasBlock(ctx, w * 0.20 + col * slot, 2 + row * rowH + 2, slot - 5, rowH - 5,
                          fresh ? t.exito_fondo : t.info_fondo, fresh ? t.inferencia_resultado : t.inferencia_estructura,
                          rows[row][col], t.texto_primario, fresh ? (row === 0 ? 1 : r) : 1)
        }
    }
}

function causalTriangle(ctx, w, h, s, t, r) {
    var labels = tokens(s)
    var n = Math.max(2, labels.length)
    var labelSpace = 34 * s.sx
    var size = Math.min((w - labelSpace) / n, (h - 16 * s.sy) / n)
    var startX = (w - size * n) / 2 + labelSpace / 3
    var startY = 15 * s.sy
    var focused = Math.min(n - 1, Number(s.focusedIndex || 0))
    for (var col = 0; col < n; ++col)
        txt(ctx, s, labels[col] || "", startX + col * size + size / 2, 7 * s.sy, t.texto_secundario, 7, false, size)
    for (var row = 0; row < n; ++row) {
        txt(ctx, s, labels[row] || "", startX - labelSpace / 2, startY + row * size + size / 2,
            row === focused ? t.texto_primario : t.texto_secundario, 7, row === focused, labelSpace)
        for (var c = 0; c < n; ++c) {
            var visible = !s.causal || c <= row
            var x = startX + c * size
            var y = startY + row * size
            var appear = Math.min(1, r * 1.4)
            cell(ctx, x, y, size - 2, size - 2, visible ? t.exito_fondo : t.error_fondo,
                 visible ? t.inferencia_resultado : t.inferencia_error,
                 visible ? 1 : 0.25 + 0.75 * appear)
            if (!visible && appear > 0.3)
                s.canvasCross(ctx, x + size / 2 - 1, y + size / 2 - 1, size * 0.2, t.inferencia_error, appear)
        }
    }
    ctx.save()
    ctx.strokeStyle = String(t.inferencia_foco)
    ctx.lineWidth = 2
    ctx.strokeRect(startX - 1, startY + focused * size - 1, size * n, size)
    ctx.restore()
}

function crossAttention(ctx, w, h, s, t, r) {
    var rows = ["BOS", "el"]
    var columns = tokens(s)
    if (s.moduleId === "module_6")
        columns = ["the", "cat"]
    var boxH = Math.min(22 * s.sy, h * 0.26)
    var slotTop = w / rows.length
    var slotBottom = w / Math.max(1, columns.length)
    var topY = 15 * s.sy
    var bottomY = h - boxH - 13 * s.sy
    txt(ctx, s, "decoder · Q", w / 2, 6 * s.sy, t.matriz_query_texto, 8)
    txt(ctx, s, "memoria del encoder · K y V", w / 2, h - 5 * s.sy, t.matriz_key_texto, 8, true, w)
    var selected = rows.length - 1
    var strengths = [0.2, 0.8, 0.4, 0.6]
    for (var bottom = 0; bottom < columns.length; ++bottom) {
        var bx = slotBottom * (bottom + 0.5)
        s.canvasGrowingArrow(ctx, slotTop * (selected + 0.5), topY + boxH + 1, bx, bottomY - 1, t.inferencia_foco,
                             (0.7 + strengths[bottom % 4] * 3) * s.sx, r)
        s.canvasBlock(ctx, bx - slotBottom * 0.42, bottomY, slotBottom * 0.84, boxH, t.matriz_key_fondo, t.matriz_key,
                      columns[bottom], t.matriz_key_texto, 1)
    }
    for (var top = 0; top < rows.length; ++top)
        s.canvasBlock(ctx, slotTop * (top + 0.5) - slotTop * 0.36, topY, slotTop * 0.72, boxH,
                      t.matriz_query_fondo, t.matriz_query, rows[top], t.matriz_query_texto,
                      top === selected ? 1 : 0.55)
}

// ─── Módulo 7 ───────────────────────────────────────────────────────────────

function verticalBars(ctx, w, h, s, t, r, list, options) {
    var slot = w / list.length
    var baseY = h - 14 * s.sy
    var top = options.top !== undefined ? options.top : 12 * s.sy
    var maximum = 1e-6
    for (var index = 0; index < list.length; ++index)
        maximum = Math.max(maximum, Math.abs(list[index].value))
    for (var i = 0; i < list.length; ++i) {
        var ratio = list[i].value / maximum
        var height = Math.max(3, Math.abs(ratio) * (baseY - top) * r)
        var x = i * slot + slot * 0.18
        var off = options.off && options.off(i)
        var color = off ? t.borde_medio : (options.color ? options.color(i) : t.inferencia_foco)
        cell(ctx, x, baseY - height, slot * 0.64, height, color, null, off ? 0.5 : 0.9)
        if (off && r > 0.4)
            s.canvasCross(ctx, x + slot * 0.32, baseY - height / 2, Math.min(7 * s.sx, slot * 0.2), t.inferencia_error, r)
        if (options.value && !off)
            txt(ctx, s, options.value(i), x + slot * 0.32, Math.max(6 * s.sy, baseY - height - 7 * s.sy), t.texto_primario, 7, true, slot)
        txt(ctx, s, list[i].label, i * slot + slot / 2, h - 6 * s.sy, t.texto_secundario, 7, false, slot * 0.96)
    }
    curve(ctx, [[0, baseY], [w, baseY]], t.borde_medio, 1, 1)
}

function hiddenRow(ctx, w, h, s, t, r) {
    var rows = 4
    var cols = 7
    var tableW = w * 0.46
    var rowH = (h - 6) / rows
    var active = rows - 1
    for (var row = 0; row < rows; ++row) {
        for (var col = 0; col < cols; ++col) {
            var x = 3 + col * tableW / cols
            cell(ctx, x, 3 + row * rowH, tableW / cols - 1, rowH - 2,
                 row === active ? t.acento_fondo : t.superficie_alterna,
                 row === active ? t.inferencia_foco : t.borde_suave, row === active ? 1 : 0.65)
        }
    }
    var y = 3 + active * rowH
    s.canvasGrowingArrow(ctx, tableW + 6, y + rowH / 2, w * 0.60, y + rowH / 2, t.inferencia_foco, 1.5 * s.sx, r)
    s.canvasBlock(ctx, w * 0.61, y, w * 0.36, rowH - 2, t.exito_fondo, t.inferencia_resultado, "h_t", t.exito_texto, r)
    txt(ctx, s, "cada fila es una posición", w * 0.79, y - 12 * s.sy, t.texto_secundario, 7, false, w * 0.36)
}

function linearBars(ctx, w, h, s, t, r) {
    var list = s.candidateRows()
    s.canvasBlock(ctx, 2, h / 2 - 16 * s.sy, w * 0.14, 32 * s.sy, t.info_fondo, t.inferencia_estructura, "h_t", t.texto_primario, 1)
    s.canvasGrowingArrow(ctx, w * 0.17, h / 2, w * 0.28, h / 2, t.inferencia_transformacion, 1.5 * s.sx, r)
    ctx.save()
    ctx.translate(w * 0.30, 0)
    verticalBars(ctx, w * 0.70, h, s, t, r, list, {})
    ctx.restore()
}

function temperature(ctx, w, h, s, t, r) {
    var list = s.candidateRows()
    var cooled = []
    for (var index = 0; index < list.length; ++index)
        cooled.push({ label: list[index].label, value: Math.pow(Math.max(0.02, list[index].probability), 2.2) })
    var flat = []
    for (var i = 0; i < list.length; ++i)
        flat.push({ label: list[i].label, value: Math.pow(Math.max(0.02, list[i].probability), 0.4) })
    txt(ctx, s, "T baja", w * 0.25, 6 * s.sy, t.inferencia_foco, 8)
    txt(ctx, s, "T alta", w * 0.75, 6 * s.sy, t.inferencia_estructura, 8)
    verticalBars(ctx, w * 0.47, h, s, t, r, cooled, {})
    ctx.save()
    ctx.translate(w * 0.53, 0)
    verticalBars(ctx, w * 0.47, h, s, t, r, flat, { color: function() { return t.inferencia_estructura } })
    ctx.restore()
}

function topK(ctx, w, h, s, t, r) {
    var list = s.candidateRows()
    var keep = Math.max(1, Math.min(list.length, Math.ceil(list.length / 2)))
    verticalBars(ctx, w, h, s, t, r, list, { off: function(i) { return i >= keep } })
}

function topP(ctx, w, h, s, t, r) {
    var list = s.candidateRows()
    var total = 0
    var running = []
    for (var index = 0; index < list.length; ++index) {
        total += list[index].probability
        running.push(total)
    }
    var threshold = 0.8 * total
    var cut = 0
    while (cut < running.length - 1 && running[cut] < threshold)
        cut += 1
    verticalBars(ctx, w, h, s, t, r, list, { off: function(i) { return i > cut } })
    var baseY = h - 14 * s.sy
    var top = 8 * s.sy
    var slot = w / list.length
    var points = []
    for (var p = 0; p < running.length; ++p)
        if ((p + 1) / running.length <= r + 0.15)
            points.push([slot * (p + 0.5), baseY - (running[p] / total) * (baseY - top)])
    if (points.length > 1)
        curve(ctx, points, t.inferencia_transformacion, 2 * s.sx, 1)
    var lineY = baseY - 0.8 * (baseY - top)
    curve(ctx, [[0, lineY], [w, lineY]], t.inferencia_error, 1, 0.7)
    txt(ctx, s, "P", w - 7 * s.sx, lineY - 7 * s.sy, t.error_texto, 8)
}

function softmaxBars(ctx, w, h, s, t, r) {
    var list = s.candidateRows()
    var total = 0
    for (var index = 0; index < list.length; ++index)
        total += list[index].probability
    var bars = []
    for (var i = 0; i < list.length; ++i)
        bars.push({ label: list[i].label, value: list[i].probability / total })
    verticalBars(ctx, w, h, s, t, r, bars, {
        color: function() { return t.inferencia_resultado },
        value: function(position) { return Math.round(bars[position].value * 100) + "%" }
    })
}

function selectPick(ctx, w, h, s, t, r) {
    var list = s.candidateRows()
    var best = 0
    for (var index = 1; index < list.length; ++index)
        if (list[index].probability > list[best].probability)
            best = index
    verticalBars(ctx, w, h, s, t, r, list, {
        color: function(i) { return i === best ? t.inferencia_resultado : t.borde_medio }
    })
    if (r > 0.6) {
        var slot = w / list.length
        txt(ctx, s, "✓ " + list[best].label, slot * (best + 0.5), 7 * s.sy, t.exito_texto, 9, true, slot * 1.4)
    }
}

function targetLabel(ctx, w, h, s, t, r) {
    var list = s.candidateRows()
    var correct = Math.min(1, list.length - 1)
    verticalBars(ctx, w, h, s, t, r, list, {
        color: function(i) { return i === correct ? t.inferencia_foco : t.borde_medio }
    })
    var slot = w / list.length
    s.canvasGrowingArrow(ctx, slot * (correct + 0.5), 2, slot * (correct + 0.5), 18 * s.sy, t.inferencia_foco, 2 * s.sx, r)
    txt(ctx, s, "objetivo y_t", Math.min(w - 40 * s.sx, slot * (correct + 0.5) + 36 * s.sx), 8 * s.sy, t.acento_texto, 8)
}

function lossCurve(ctx, w, h, s, t, r) {
    var left = w * 0.10
    var right = w * 0.94
    var bottom = h - 15 * s.sy
    curve(ctx, [[left, 4], [left, bottom], [right, bottom]], t.borde_medio, 1, 1)
    var points = []
    var maxLoss = 3
    for (var step = 1; step <= 40; ++step) {
        var p = step / 40
        var loss = Math.min(maxLoss, -Math.log(p))
        points.push([left + (right - left) * p, bottom - (loss / maxLoss) * (bottom - 6)])
    }
    curve(ctx, points, t.inferencia_error, 2 * s.sx, 1)
    var example = 0.15 + 0.7 * r
    var loss2 = -Math.log(example)
    var px = left + (right - left) * example
    var py = bottom - (loss2 / maxLoss) * (bottom - 6)
    ctx.save()
    ctx.fillStyle = String(t.inferencia_foco)
    ctx.beginPath()
    ctx.arc(px, py, 5 * s.sx, 0, 6.283)
    ctx.fill()
    ctx.restore()
    txt(ctx, s, "probabilidad del token correcto", w * 0.52, h - 6 * s.sy, t.texto_secundario, 8, false, w * 0.84)
    txt(ctx, s, "L", left - 9 * s.sx, 9 * s.sy, t.error_texto, 9)
}

function feedbackLoop(ctx, w, h, s, t, r) {
    var boxH = Math.min(30 * s.sy, h * 0.38)
    var y = h - boxH - 3
    var boxes = ["Decoder", "Salida", "ŷ_t"]
    var slot = w * 0.92 / boxes.length
    for (var index = 0; index < boxes.length; ++index) {
        s.canvasBlock(ctx, w * 0.04 + index * slot, y, slot - 16 * s.sx, boxH,
                      index === 2 ? t.exito_fondo : t.info_fondo,
                      index === 2 ? t.inferencia_resultado : t.inferencia_estructura,
                      boxes[index], t.texto_primario, 1)
        if (index < boxes.length - 1)
            s.canvasArrow(ctx, w * 0.04 + index * slot + slot - 16 * s.sx, y + boxH / 2, w * 0.04 + (index + 1) * slot, y + boxH / 2, t.borde_medio, 1.2 * s.sx, 1)
    }
    var startX = w * 0.04 + 2 * slot + (slot - 16 * s.sx) / 2
    var endX = w * 0.04 + (slot - 16 * s.sx) / 2
    var topY = 10 * s.sy
    var currentX = startX + (endX - startX) * r
    curve(ctx, [[startX, y], [startX, topY], [currentX, topY]], t.inferencia_foco, 2 * s.sx, 1)
    if (r > 0.9)
        s.canvasArrow(ctx, endX, topY, endX, y - 1, t.inferencia_foco, 2 * s.sx, 1)
    txt(ctx, s, "el token entra al prefijo", w / 2, topY + 10 * s.sy, t.acento_texto, 8, true, w * 0.7)
}

var PAINTERS = {
    text_input: textInput, tokenize: tokenize, vocab_lookup: vocabLookup, specials: specials,
    batch_pad: batchPad, batch_trim: batchTrim, pad_mask: padMask, no_grad: noGrad,
    embed_lookup: embedLookup, scale_vector: scaleVector, pos_wave: posWave, add_vector: addVector,
    dropout: dropout, gradient_back: gradientBack, update_params: updateParams,
    project_joint: projectJoint, split_heads: splitHeads, head_maps: headMaps,
    head_contexts: headContexts, concat_heads: concatHeads, wo_mix: woMix,
    layer_input: layerInput, mini_attention: miniAttention, residual: residual,
    layernorm: layernorm, ffn_expand: ffnExpand, ffn_project: ffnProject, ffn_block: ffnBlock,
    ffn_activation: ffnActivation, layer_stack: layerStack,
    shift_target: shiftTarget, grow_prefix: growPrefix, causal_triangle: causalTriangle,
    cross_attention: crossAttention,
    hidden_row: hiddenRow, linear_bars: linearBars, temperature: temperature, top_k: topK,
    top_p: topP, softmax_bars: softmaxBars, select_pick: selectPick, target_label: targetLabel,
    loss_curve: lossCurve, feedback_loop: feedbackLoop
}

function has(kind) {
    return PAINTERS[kind] !== undefined
}

function paint(ctx, width, height, scene, theme, reveal) {
    var painter = PAINTERS[scene.stageKind]
    if (painter)
        painter(ctx, width, height, scene, theme, reveal)
}
