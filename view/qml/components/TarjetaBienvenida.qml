import QtQuick
import QtQuick.Layouts
import "../styles" as Style

// Tarjeta de "camino" para pantallas de entrada (bienvenida, hubs).
//
// Estructura fija — icono + insignia, título, descripción — y un espacio
// libre (propiedad por defecto) donde cada pantalla coloca sus acciones.
// Así todas las tarjetas-hub de la app comparten ritmo vertical, radios y
// estados sin copiar 60 líneas por tarjeta.
//
// Ejemplo:
//   TarjetaBienvenida {
//       glifo: "◆"; titulo: "Ruta"; descripcion: "..."
//       insignia: "Recomendado"; destacada: true
//       BotonAcento { Layout.fillWidth: true; text: "Empezar" }
//   }
Rectangle {
    id: root

    default property alias contenido: zonaContenido.data

    property string glifo: ""
    property string fuenteGlifo: Style.Theme.fuente_simbolos
    property color glifoColor: Style.Theme.acento
    property color glifoFondo: Style.Theme.acento_fondo
    property color acentoTarjeta: glifoColor
    property string titulo: ""
    property string descripcion: ""

    // Insignia opcional arriba a la derecha ("Recomendado", "Bloqueado"...).
    property string insignia: ""
    property color insigniaFondo: Style.Theme.acento_fondo
    property color insigniaTexto: Style.Theme.acento_texto

    // `destacada` da peso visual (borde de acento) a la opción recomendada.
    property bool destacada: false
    // Retraso de la animación de entrada, para escalonar varias tarjetas.
    property int retrasoEntrada: 0

    readonly property bool resaltada: destacada || hover.hovered

    implicitHeight: columna.implicitHeight + 2 * 28
    radius: 20
    color: Style.Theme.surface
    border.width: destacada ? 2 : 1
    border.color: resaltada ? root.acentoTarjeta : Style.Theme.borde_medio
    scale: hover.hovered ? 1.006 : 1
    transformOrigin: Item.Center
    Behavior on border.color { ColorAnimation { duration: Style.Theme.duracionMedia } }
    Behavior on scale { NumberAnimation { duration: Style.Theme.duracionCorta; easing.type: Easing.OutCubic } }

    Accessible.role: Accessible.Grouping
    Accessible.name: titulo
    Accessible.description: descripcion

    HoverHandler { id: hover }

    // Entrada compartida con el resto de la app (ver AparicionSuave.qml).
    AparicionSuave { objetivo: root; retraso: root.retrasoEntrada }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: 28
        width: root.resaltada ? 78 : 42
        height: 4
        radius: 2
        color: root.acentoTarjeta
        opacity: root.destacada ? 1 : 0.72

        Behavior on width { NumberAnimation { duration: Style.Theme.duracionMedia; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        width: 118
        height: 118
        radius: 59
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -46
        anchors.topMargin: -54
        color: root.glifoFondo
        opacity: Style.Theme.modoOscuro ? 0.16 : 0.38
        Accessible.ignored: true
    }

    ColumnLayout {
        id: columna
        anchors.fill: parent
        anchors.margins: 28
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: 13
                color: root.glifoFondo
                Text {
                    anchors.centerIn: parent
                    text: root.glifo
                    color: root.glifoColor
                    font.family: root.fuenteGlifo
                    font.pixelSize: 22
                    font.bold: true
                    Accessible.ignored: true
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                visible: root.insignia.length > 0
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: textoInsignia.implicitWidth + 20
                Layout.preferredHeight: 26
                radius: 13
                color: root.insigniaFondo
                Text {
                    id: textoInsignia
                    anchors.centerIn: parent
                    text: root.insignia
                    color: root.insigniaTexto
                    font.family: Style.Theme.fuente_interfaz
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 18
            text: root.titulo
            color: Style.Theme.texto_primario
            font.family: Style.Theme.fuente_interfaz
            font.pixelSize: Style.Theme.subtitleSize
            font.bold: true
            wrapMode: Text.WordWrap
            Accessible.role: Accessible.Heading
            Accessible.name: text
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 6
            text: root.descripcion
            color: Style.Theme.texto_secundario
            font.family: Style.Theme.fuente_interfaz
            font.pixelSize: 15
            lineHeight: 1.25
            wrapMode: Text.WordWrap
        }

        // Espacio de cada pantalla. Se estira cuando la fila de tarjetas es
        // más alta que su contenido: coloca un `Item { Layout.fillHeight: true }`
        // donde quieras que vaya el hueco (antes del CTA para anclarlo abajo,
        // o al final para mantener las acciones juntas). Sin él, ColumnLayout
        // reparte el sobrante entre todos los hijos.
        ColumnLayout {
            id: zonaContenido
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 20
            spacing: 10
        }
    }
}
