import QtQuick
import QtQuick.Controls
import "../styles" as Style
import "../components"

Page {

    id: root

    required property StackView stackView

    // Los nombres se exponen para que las pruebas y las pantallas puedan
    // localizar el lector compartido sin depender de ids internos de QML.
    property string helpModalObjectName: "theoryHelpModal"
    property string helpPanelObjectName: "theoryHelpPanel"
    readonly property bool theoryModalOpened: theoryHelpModal.opened

    // Resolución base real de la ventana. Mantener estos valores alineados
    // con Theme evita que una fuente de 12 px termine renderizándose a 7–8 px
    // al abrir la aplicación con su tamaño predeterminado.
    readonly property real baseWidth: Style.Theme.baseWidth
    readonly property real baseHeight: Style.Theme.baseHeight

    // Factores de escala
    readonly property real sx: width / baseWidth
    readonly property real sy: height / baseHeight

    function openTheoryComponent(componentId) {
        return theoryHelpModal.openComponent(componentId)
    }

    function previewTheoryComponent(componentId) {
        return theoryHelpModal.previewComponent(componentId)
    }

    function openTheoryConcept(conceptId) {
        return theoryHelpModal.openConcept(conceptId)
    }

    function closeTheory() {
        theoryHelpModal.close()
    }

    background: Rectangle {
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Style.Theme.fondo
            }

            GradientStop {
                position: 1
                color: Style.Theme.fondo_gradiente
            }
        }
    }

    // Una unica instancia por pagina. Como todas las pantallas navegables
    // heredan de PagePrincipal, sus botones y diagramas comparten esta API.
    Modal {
        id: theoryHelpModal

        objectName: root.helpModalObjectName
        panelObjectName: root.helpPanelObjectName
        hostWidth: root.width
        hostHeight: root.height
        theoryController: typeof mainViewModel !== "undefined"
                          && mainViewModel
                          ? mainViewModel.theoryController : null
    }

    onVisibleChanged: {
        if (!visible)
            root.closeTheory()
    }

}
