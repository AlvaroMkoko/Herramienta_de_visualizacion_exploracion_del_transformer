import QtQuick
import QtQuick.Layouts
import "../styles" as Style

// Indicador horizontal de etapas (stepper) de solo lectura.
//
// Hace visible el "mapa" completo de un recorrido: cuántas etapas hay,
// cuáles están hechas y dónde está la persona. Ver el final reduce la
// incertidumbre y el progreso parcial motiva a continuar (efecto de
// progreso dotado).
//
// `etapas`: lista de objetos { nombre: string, completada: bool }.
// La etapa actual es la primera no completada; se calcula sola.
Item {
    id: root

    property var etapas: []
    readonly property int actual: {
        for (var i = 0; i < etapas.length; ++i)
            if (!etapas[i].completada)
                return i
        return -1  // todas completadas
    }

    implicitHeight: 58
    implicitWidth: 360

    Accessible.role: Accessible.List
    Accessible.name: "Etapas de la ruta"

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: root.etapas

            Item {
                id: paso
                required property var modelData
                required property int index

                readonly property bool completada: modelData.completada
                readonly property bool esActual: index === root.actual
                readonly property bool ultima: index === root.etapas.length - 1

                Layout.fillWidth: true
                Layout.fillHeight: true

                Accessible.role: Accessible.ListItem
                Accessible.name: "Etapa " + (index + 1) + ", " + modelData.nombre + ": "
                                 + (completada ? "completada" : (esActual ? "actual" : "pendiente"))

                // Conector hacia la siguiente etapa: va del centro de este
                // círculo al centro del siguiente (los pasos miden lo mismo).
                Rectangle {
                    visible: !paso.ultima
                    x: paso.width / 2
                    width: paso.width
                    y: circulo.y + circulo.height / 2 - 1
                    height: 2
                    color: Style.Theme.divisor

                    // Relleno que "fluye" hacia la derecha al completarse.
                    Rectangle {
                        height: parent.height
                        width: paso.completada ? parent.width : 0
                        color: Style.Theme.acento
                        Behavior on width {
                            enabled: !Style.Theme.movimientoReducido
                            NumberAnimation { duration: Style.Theme.duracionMedia * 2; easing.type: Easing.OutCubic }
                        }
                    }
                }

                Rectangle {
                    id: circulo
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 2
                    width: 26
                    height: 26
                    radius: 13
                    color: paso.completada ? Style.Theme.acento
                                           : (paso.esActual ? Style.Theme.surface : Style.Theme.superficie_alterna)
                    border.width: paso.completada ? 0 : 2
                    border.color: paso.esActual ? Style.Theme.acento : Style.Theme.borde_suave
                    Behavior on color { ColorAnimation { duration: Style.Theme.duracionMedia } }

                    // Halo pulsante discreto en la etapa actual: guía la
                    // mirada sin gritar. Se detiene con movimiento reducido.
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 10
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: Style.Theme.acento
                        visible: paso.esActual
                        opacity: 0
                        SequentialAnimation on opacity {
                            running: paso.esActual && !Style.Theme.movimientoReducido
                            loops: Animation.Infinite
                            NumberAnimation { from: 0; to: 0.45; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.45; to: 0; duration: 900; easing.type: Easing.InOutSine }
                            PauseAnimation { duration: 600 }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: paso.completada ? "✓" : String(paso.index + 1)
                        color: paso.completada ? Style.Theme.texto_sobre_acento
                                               : (paso.esActual ? Style.Theme.acento_texto
                                                                : Style.Theme.texto_terciario)
                        font.family: paso.completada ? Style.Theme.fuente_simbolos : Style.Theme.fuente_interfaz
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                Text {
                    anchors.top: circulo.bottom
                    anchors.topMargin: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: paso.width - 4
                    horizontalAlignment: Text.AlignHCenter
                    text: paso.modelData.nombre
                    color: paso.esActual ? Style.Theme.texto_primario
                                         : (paso.completada ? Style.Theme.texto_secundario_fuerte
                                                            : Style.Theme.texto_terciario)
                    font.family: Style.Theme.fuente_interfaz
                    font.pixelSize: 12
                    font.bold: paso.esActual
                    elide: Text.ElideRight
                }
            }
        }
    }
}
