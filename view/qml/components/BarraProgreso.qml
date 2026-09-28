import QtQuick
import "../styles" as Style

// Barra de progreso fina, animada y accesible (lectores de pantalla la
// anuncian como barra de progreso con su valor).
//
//   BarraProgreso { valor: 0.4; etiquetaAccesible: "Progreso de la ruta" }
Rectangle {
    id: root

    property real valor: 0            // 0.0 – 1.0
    property string etiquetaAccesible: "Progreso"
    property color colorRelleno: Style.Theme.acento

    readonly property real valorAcotado: Math.max(0, Math.min(1, valor))

    implicitHeight: 6
    radius: height / 2
    color: Style.Theme.divisor

    Accessible.role: Accessible.ProgressBar
    Accessible.name: etiquetaAccesible + ": " + Math.round(valorAcotado * 100) + " %"

    Rectangle {
        height: parent.height
        radius: parent.radius
        color: root.colorRelleno
        width: parent.width * root.valorAcotado
        Behavior on width {
            enabled: !Style.Theme.movimientoReducido
            NumberAnimation { duration: Style.Theme.duracionMedia * 3; easing.type: Easing.OutCubic }
        }
    }
}
