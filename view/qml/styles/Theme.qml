pragma Singleton

import QtQuick

QtObject {

    // ========= Tamaño de ancho y largo

    

    //Se supone que debe tener en cuenta el tamaño del monitor en el que se esta poniendo

    readonly property real baseWidth: 1280
    readonly property real baseHeight: 820

    
    // ========= Colores principales =========
    readonly property color fondo: "#fffeff"
    readonly property color fondo_gradiente: "#e7d9f0"
    readonly property color boton: "#f3eff5"
    readonly property color boton_gradiente: "#dcc3ea"
    readonly property color boton_presionado: "#d9cae2"

    // ========= Fondo =========
    readonly property color background: "#F8FAFC"
    readonly property color surface: "#FFFFFF"

    // ========= Texto =========
    readonly property color texto_primario: "#111827"
    readonly property color texto_secundario: "#6B7280"

    // ========= Bordes =========
    readonly property color borde: "#aeb0b3"
    readonly property color borde_boton: "#afb4b9"
    readonly property color borde_cuadro: "#9e979f"
    // ========= Estados =========
    readonly property color success: "#22C55E"
    readonly property color warning: "#F59E0B"
    readonly property color error: "#EF4444"
    readonly property color info: "#3B82F6"

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