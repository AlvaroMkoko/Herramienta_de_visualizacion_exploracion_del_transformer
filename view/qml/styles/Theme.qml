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
        "borde":             "#aeb0b3",
        "borde_boton":       "#afb4b9",
        "borde_cuadro":      "#9e979f",
        "success":           "#22C55E",
        "warning":           "#F59E0B",
        "error":             "#EF4444",
        "info":              "#3B82F6",
        // Superficies auxiliares para reemplazar los hex fijos de las pantallas
        "chip_fondo":        "#F3F4F6",
        "chip_borde":        "#D1D5DB",
        "chip_texto":        "#4B5563",
        "acento_suave":      "#EDE9FE",
        "acento":            "#6D28D9",

        // ===== Neutros (los más repetidos: 58, 42, 36, 34, 27, 20 usos) =====
        "texto_terciario":   "#94A3B8",
        "divisor":           "#E5E7EB",
        "superficie_alterna":"#F8FAFC",
        "borde_suave":       "#CBD5E1",
        "borde_medio":       "#E2E8F0",
        "texto_sobre_color": "#FFFFFF",

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
        "acento_alt":    "#4F46E5"
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
        "borde":             "#3A3A4A",
        "borde_boton":       "#45445A",
        "borde_cuadro":      "#4A4860",
        // Los estados se aclaran: los tonos claros no contrastan sobre fondo oscuro
        "success":           "#4ADE80",
        "warning":           "#FBBF24",
        "error":             "#F87171",
        "info":              "#60A5FA",
        "chip_fondo":        "#2A2938",
        "chip_borde":        "#3F3E52",
        "chip_texto":        "#C3C0D4",
        "acento_suave":      "#312A4D",
        "acento":            "#A78BFA",

        // ===== Neutros =====
        "texto_terciario":   "#8B889E",
        "divisor":           "#2E2D3D",
        "superficie_alterna":"#1C1B26",
        "borde_suave":       "#3F3E52",
        "borde_medio":       "#33323F",
        "texto_sobre_color": "#14141C",

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
        "acento_alt":    "#818CF8"
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
    readonly property color divisor: p.divisor
    readonly property color superficie_alterna: p.superficie_alterna
    readonly property color borde_suave: p.borde_suave
    readonly property color borde_medio: p.borde_medio
    readonly property color texto_sobre_color: p.texto_sobre_color
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