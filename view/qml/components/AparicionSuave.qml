import QtQuick
import "../styles" as Style

// Animación de entrada reutilizable: el objetivo aparece (opacidad 0 → 1)
// y sube unos píxeles hasta su lugar. Se "adjunta" a cualquier Item sin
// envolverlo, así que funciona igual dentro de Layouts, Columns o anclas.
//
// Uso:
//   Rectangle {
//       id: tarjeta
//       ...
//       AparicionSuave { objetivo: tarjeta; orden: 1 }
//   }
//
// `orden` escalona varios bloques: 0 aparece primero, 1 un poco después…
// Se desplaza con un Translate (no con `y`), porque `y` lo controla el
// Layout y ambos se pelearían.
//
// Nota: si el objetivo ya usa `transform`, esta animación lo sustituye.
QtObject {
    id: root

    required property Item objetivo
    property int orden: 0
    property int retraso: orden * Style.Theme.escalonEntrada
    property real distancia: 16
    // false = la llamada a reproducir() queda a cargo de la pantalla
    // (por ejemplo, para repetir la entrada al volver con StackView.pop).
    property bool automatica: true

    readonly property bool _sinMovimiento: Style.Theme.movimientoReducido

    property Translate _desplazamiento: Translate { y: 0 }

    property SequentialAnimation _animacion: SequentialAnimation {
        PauseAnimation { duration: root._sinMovimiento ? 0 : root.retraso }
        ParallelAnimation {
            NumberAnimation {
                target: root.objetivo
                property: "opacity"
                from: 0; to: 1
                duration: root._sinMovimiento ? 0 : Style.Theme.duracionEntrada
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root._desplazamiento
                property: "y"
                from: root._sinMovimiento ? 0 : root.distancia; to: 0
                duration: root._sinMovimiento ? 0 : Style.Theme.duracionEntrada
                easing.type: Easing.OutCubic
            }
        }
    }

    function reproducir() {
        if (!root.objetivo)
            return
        root._animacion.stop()
        root.objetivo.opacity = root._sinMovimiento ? 1 : 0
        root._animacion.start()
    }

    Component.onCompleted: {
        if (!root.objetivo)
            return
        root.objetivo.transform = [root._desplazamiento]
        if (root.automatica)
            root.reproducir()
    }
}
