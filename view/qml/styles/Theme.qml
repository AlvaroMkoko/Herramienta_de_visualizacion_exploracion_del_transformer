pragma Singleton

import QtQuick
import QtCore

QtObject {
    id: theme

    // ========= Modo de apariencia =========
    // Es la ÚNICA propiedad mutable. Todo lo demás se deriva de ella,
    // así que cambiarla actualiza automáticamente cada binding que use
    // Theme.* en cualquier pantalla, sin tocar esas pantallas.
    property bool modoOscuro: false

    // Recuerda la preferencia entre ejecuciones. Requiere que main.py
    // fije setOrganizationName y setApplicationName antes de crear el
    // engine; sin eso, Settings no encuentra dónde guardar.
    property Settings preferencias: Settings {
        category: "apariencia"
        property alias modoOscuro: theme.modoOscuro
    }

    function alternarModo() { modoOscuro = !modoOscuro }

    // ========= Tamaño de ancho y largo =========
    readonly property real baseWidth: 1280
    readonly property real baseHeight: 820

    // ========= Paletas =========
    readonly property var paletaClara: ({
        "fondo":             "#fffeff",
        "fondo_gradiente":   "#e7d9f0",
        "boton":             "#f3eff5",
        "boton_gradiente":   "#dcc3ea",
        "boton_presionado":  "#d9cae2",
        "background":        "#F8FAFC",
        "surface":           "#FFFFFF",
        "texto_primario":    "#111827",
        "texto_secundario":  "#6B7280",
        "texto_secundario_fuerte":"#334155",
        "borde":             "#aeb0b3",
        "borde_boton":       "#afb4b9",
        "borde_cuadro":      "#9e979f",
        "success":           "#22C55E",
        "warning":           "#F59E0B",
        "error":             "#EF4444",
        "info":              "#3B82F6",
        "texto_sobre_color": "#FFFFFF",
        "texto_sobre_acento": "#FFFFFF",
        "acento_suave":      "#EDE9FE",

        // ===== Neutros (los más repetidos: 58, 42, 36, 34, 27, 20 usos) =====
        // Conserva contraste AA incluso sobre el extremo lavanda del fondo.
        "texto_terciario":   "#526072",
        "divisor":           "#E5E7EB",
        "superficie_alterna":"#F8FAFC",
        "borde_suave":       "#CBD5E1",
        "borde_medio":       "#E2E8F0",

        // ===== Pares semánticos: fondo de chip + su texto =====
        "exito_fondo":   "#DCFCE7",  "exito_texto":   "#166534",
        "error_fondo":   "#FEE2E2",  "error_texto":   "#991B1B",
        "aviso_fondo":   "#FFF7ED",  "aviso_texto":   "#92400E",
        "info_fondo":    "#DBEAFE",  "info_texto":    "#1E40AF",
        "acento_fondo":  "#EDE9FE",  "acento_texto":  "#6D28D9",
        "chip_fondo":    "#F3F4F6",  "chip_texto":    "#4B5563",
        "chip_borde":    "#D1D5DB",

        // ===== Acentos de marca =====
        "acento":        "#7C3AED",
        "acento_fuerte": "#6D28D9",
        "acento_alt":    "#4F46E5",

        // ===== Lenguaje pedagógico =====
        // El color comunica función, no importancia: concepto, transformación,
        // ejemplo y resultado conservan el mismo rol en toda la aplicación.
        "concepto_fondo": "#F5F3FF", "concepto_texto": "#6D28D9",
        "formula_fondo":  "#FFF7ED", "formula_texto":  "#92400E",
        "ejemplo_fondo":  "#EFF6FF", "ejemplo_texto":  "#1E40AF",
        "proceso_fondo":  "#ECFDF5", "proceso_texto":  "#166534",

        // ===== Query, Key y Value =====
        // Identidades estables y distinguibles incluso sin depender solo del tono.
        "matriz_query":       "#0072B2",
        "matriz_query_fondo":"#E0F2FE",
        "matriz_query_texto":"#075985",
        "matriz_key":         "#C47F00",
        "matriz_key_fondo":  "#FFF7D6",
        "matriz_key_texto":  "#854D0E",
        "matriz_value":       "#009E73",
        "matriz_value_fondo":"#DCFCE7",
        "matriz_value_texto":"#166534",

        // ===== Escalas de color =====
        "escala_sec_0":  "#F7FBFF",
        "escala_sec_1":  "#C6DBEF",
        "escala_sec_2":  "#6BAED6",
        "escala_sec_3":  "#2171B5",
        "escala_sec_4":  "#08306B",

        // ===== Escalas divergentes =====
        "escala_div_neg2": "#8C510A",
        "escala_div_neg1": "#DFC27D",
        "escala_div_cero": "#F5F5F5",
        "escala_div_pos1": "#80CDC1",
        "escala_div_pos2": "#01665E"
    })

    readonly property var paletaOscura: ({
        "fondo":             "#14141C",
        "fondo_gradiente":   "#241E33",
        "boton":             "#242233",
        "boton_gradiente":   "#3A2F52",
        "boton_presionado":  "#312B45",
        "background":        "#0F0F16",
        "surface":           "#1C1B26",
        "texto_primario":    "#ECEAF4",
        "texto_secundario":  "#A5A2BB",
        "texto_secundario_fuerte":"#C6C3D8",
        "borde":             "#3A3A4A",
        "borde_boton":       "#45445A",
        "borde_cuadro":      "#4A4860",
        "texto_sobre_color": "#FFFFFF",
        "texto_sobre_acento": "#14141C",

        // Los estados se aclaran: los tonos claros no contrastan sobre fondo oscuro
        "success":           "#4ADE80",
        "warning":           "#FBBF24",
        "error":             "#F87171",
        "info":              "#60A5FA",
        "acento_suave":      "#312A4D",

        // ===== Neutros =====
        "texto_terciario":   "#8B889E",
        "divisor":           "#2E2D3D",
        "superficie_alterna":"#282734",
        "borde_suave":       "#3F3E52",
        "borde_medio":       "#33323F",

        // ===== Pares semánticos =====
        // El fondo del chip se oscurece y desatura; el texto se aclara.
        // Verificado: todos dan AA o AAA sobre su propio chip, y el chip
        // queda a 1.17-1.33 del fondo (no deslumbra).
        "exito_fondo":   "#153226",  "exito_texto":   "#4ADE80",
        "error_fondo":   "#3A1A1D",  "error_texto":   "#F87171",
        "aviso_fondo":   "#3A2A18",  "aviso_texto":   "#FBBF24",
        "info_fondo":    "#16283F",  "info_texto":    "#60A5FA",
        "acento_fondo":  "#2A2342",  "acento_texto":  "#A78BFA",
        "chip_fondo":    "#2A2938",  "chip_texto":    "#C3C0D4",
        "chip_borde":    "#3F3E52",

        // ===== Acentos de marca =====
        "acento":        "#A78BFA",
        "acento_fuerte": "#C4B5FD",
        "acento_alt":    "#818CF8",

        // ===== Lenguaje pedagógico =====
        "concepto_fondo": "#2A2342", "concepto_texto": "#C4B5FD",
        "formula_fondo":  "#3A2A18", "formula_texto":  "#FBBF24",
        "ejemplo_fondo":  "#16283F", "ejemplo_texto":  "#93C5FD",
        "proceso_fondo":  "#153226", "proceso_texto":  "#86EFAC",

        // ===== Query, Key y Value =====
        "matriz_query":       "#56B4E9",
        "matriz_query_fondo":"#102F42",
        "matriz_query_texto":"#7DD3FC",
        "matriz_key":         "#F0C84B",
        "matriz_key_fondo":  "#3A2F17",
        "matriz_key_texto":  "#FDE68A",
        "matriz_value":       "#4ADE80",
        "matriz_value_fondo":"#153226",
        "matriz_value_texto":"#86EFAC",

        // ===== Escalas de color =====
        "escala_sec_0":  "#F7FBFF",
        "escala_sec_1":  "#C6DBEF",
        "escala_sec_2":  "#6BAED6",
        "escala_sec_3":  "#2171B5",
        "escala_sec_4":  "#08306B",

        // ===== Escalas divergentes =====
        "escala_div_neg2": "#8C510A",
        "escala_div_neg1": "#DFC27D",
        "escala_div_cero": "#F5F5F5",
        "escala_div_pos1": "#80CDC1",
        "escala_div_pos2": "#01665E"
    })

    readonly property var p: modoOscuro ? paletaOscura : paletaClara

    // ========= Colores expuestos =========
    // Las pantallas siguen escribiendo Style.Theme.fondo igual que antes.
    readonly property color fondo: p.fondo
    readonly property color fondo_gradiente: p.fondo_gradiente
    readonly property color boton: p.boton
    readonly property color boton_gradiente: p.boton_gradiente
    readonly property color boton_presionado: p.boton_presionado
    readonly property color background: p.background
    readonly property color surface: p.surface
    readonly property color texto_primario: p.texto_primario
    readonly property color texto_secundario: p.texto_secundario
    readonly property color texto_secundario_fuerte: p.texto_secundario_fuerte
    readonly property color texto_sobre_color: p.texto_sobre_color
    readonly property color borde: p.borde
    readonly property color borde_boton: p.borde_boton
    readonly property color borde_cuadro: p.borde_cuadro
    readonly property color success: p.success
    readonly property color warning: p.warning
    readonly property color error: p.error
    readonly property color info: p.info
    readonly property color chip_fondo: p.chip_fondo
    readonly property color chip_borde: p.chip_borde
    readonly property color chip_texto: p.chip_texto
    readonly property color acento_suave: p.acento_suave
    readonly property color acento: p.acento
    readonly property color texto_terciario: p.texto_terciario
    readonly property color texto_sobre_acento: p.texto_sobre_acento
    readonly property color divisor: p.divisor
    readonly property color superficie_alterna: p.superficie_alterna
    readonly property color borde_suave: p.borde_suave
    readonly property color borde_medio: p.borde_medio
    readonly property color exito_fondo: p.exito_fondo
    readonly property color exito_texto: p.exito_texto
    readonly property color error_fondo: p.error_fondo
    readonly property color error_texto: p.error_texto
    readonly property color aviso_fondo: p.aviso_fondo
    readonly property color aviso_texto: p.aviso_texto
    readonly property color info_fondo: p.info_fondo
    readonly property color info_texto: p.info_texto
    readonly property color acento_fondo: p.acento_fondo
    readonly property color acento_texto: p.acento_texto
    readonly property color acento_fuerte: p.acento_fuerte
    readonly property color acento_alt: p.acento_alt

    // ========= Jerarquía didáctica =========
    readonly property color concepto_fondo: p.concepto_fondo
    readonly property color concepto_texto: p.concepto_texto
    readonly property color formula_fondo: p.formula_fondo
    readonly property color formula_texto: p.formula_texto
    readonly property color ejemplo_fondo: p.ejemplo_fondo
    readonly property color ejemplo_texto: p.ejemplo_texto
    readonly property color proceso_fondo: p.proceso_fondo
    readonly property color proceso_texto: p.proceso_texto

    // ========= Identidades conceptuales Q / K / V =========
    readonly property color matriz_query: p.matriz_query
    readonly property color matriz_query_fondo: p.matriz_query_fondo
    readonly property color matriz_query_texto: p.matriz_query_texto
    readonly property color matriz_key: p.matriz_key
    readonly property color matriz_key_fondo: p.matriz_key_fondo
    readonly property color matriz_key_texto: p.matriz_key_texto
    readonly property color matriz_value: p.matriz_value
    readonly property color matriz_value_fondo: p.matriz_value_fondo
    readonly property color matriz_value_texto: p.matriz_value_texto

    // ========= Escalas para datos numéricos =========
    readonly property color escala_sec_0: p.escala_sec_0
    readonly property color escala_sec_1: p.escala_sec_1
    readonly property color escala_sec_2: p.escala_sec_2
    readonly property color escala_sec_3: p.escala_sec_3
    readonly property color escala_sec_4: p.escala_sec_4
    readonly property color escala_div_neg2: p.escala_div_neg2
    readonly property color escala_div_neg1: p.escala_div_neg1
    readonly property color escala_div_cero: p.escala_div_cero
    readonly property color escala_div_pos1: p.escala_div_pos1
    readonly property color escala_div_pos2: p.escala_div_pos2

    // ========= Tipografía =========
    readonly property int titleSize: 28
    readonly property int subtitleSize: 22
    readonly property int bodySize: 16
    readonly property int smallSize: 13

    // ========= Espaciados =========
    readonly property int spacingXS: 4
    readonly property int spacingS: 8
    readonly property int spacingM: 16
    readonly property int spacingL: 24
    readonly property int spacingXL: 32

    // ========= Bordes =========
    readonly property int radius: 12
}
