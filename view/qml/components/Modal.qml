pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// Lector modal reutilizable para la teoría contextual del proyecto.
//
// Las pantallas solo indican si desean abrir un componente del diagrama o un
// concepto del glosario. La consulta y la navegación relacionada permanecen
// encapsuladas aquí.
Popup {
    id: root

    property var theoryController: null
    property var concepto: ({})
    property var relacionados: []
    property string panelObjectName: "theoryHelpPanel"
    property real hostWidth: 1040
    property real hostHeight: 780

    // Permiten recargar exactamente la consulta abierta cuando cambia el JSON.
    property string currentSource: ""
    property string currentId: ""
    property string requestError: ""

    readonly property string errorCarga: root.requestError !== ""
                                                ? root.requestError
                                                : (root.theoryController
                                                   && root.theoryController.errorCarga
                                                   ? String(root.theoryController.errorCarga)
                                                   : "")
    readonly property real viewportWidth: Overlay.overlay
                                                  && Overlay.overlay.width > 0
                                                  ? Overlay.overlay.width
                                                  : root.hostWidth
    readonly property real viewportHeight: Overlay.overlay
                                                   && Overlay.overlay.height > 0
                                                   ? Overlay.overlay.height
                                                   : root.hostHeight
    readonly property real contentScale: Math.max(
                                                   0.92,
                                                   Math.min(1.10, root.width / 900)
                                               )

    function fallback(referenceId, explanation) {
        return {
            "id": referenceId,
            "title": "Información no disponible",
            "short_description": "No fue posible cargar este concepto.",
            "explanation": explanation,
            "existe": false,
            "relacionados": []
        }
    }

    function controllerReady(methodName) {
        return root.theoryController
                && typeof root.theoryController[methodName] === "function"
    }

    // Consulta el contenido sin abrir el lector. Las pantallas usan esta
    // previsualizacion al seleccionar un bloque y dejan la apertura completa
    // para una accion explicita del usuario.
    function previewComponent(componentId) {
        var normalizedId = componentId === undefined || componentId === null
                ? "" : String(componentId).trim()
        if (normalizedId === "")
            return ({})
        if (!root.controllerReady("obtenerTeoriaDeComponente"))
            return root.fallback(
                        normalizedId,
                        "No se pudo acceder al controlador de teoría.")
        return root.theoryController.obtenerTeoriaDeComponente(normalizedId)
    }

    function showResult(result, relatedItems) {
        root.concepto = result || root.fallback(
                    root.currentId,
                    "Todavía no hay una explicación para este concepto."
                )
        root.relacionados = relatedItems || []
        root.open()
        theoryPanel.prepareForOpen()
        return root.concepto
    }

    function openComponent(componentId) {
        var normalizedId = componentId === undefined || componentId === null
                ? "" : String(componentId).trim()
        if (normalizedId === "")
            return root.concepto

        root.currentSource = "component"
        root.currentId = normalizedId
        root.requestError = ""

        if (!root.controllerReady("obtenerTeoriaDeComponente")) {
            root.requestError = "No se pudo acceder al controlador de teoría."
            return root.showResult(
                        root.fallback(normalizedId, root.requestError), [])
        }

        var result = root.previewComponent(normalizedId)
        var relatedItems = result && result.relacionados
                ? result.relacionados : []
        return root.showResult(result, relatedItems)
    }

    function openConcept(conceptId) {
        var normalizedId = conceptId === undefined || conceptId === null
                ? "" : String(conceptId).trim()
        if (normalizedId === "")
            return root.concepto

        root.currentSource = "concept"
        root.currentId = normalizedId
        root.requestError = ""

        if (!root.controllerReady("obtenerConcepto")) {
            root.requestError = "No se pudo acceder al controlador de teoría."
            return root.showResult(
                        root.fallback(normalizedId, root.requestError), [])
        }

        var result = root.theoryController.obtenerConcepto(normalizedId)
        var relatedItems = root.controllerReady("obtenerRelacionados")
                ? root.theoryController.obtenerRelacionados(normalizedId) : []
        return root.showResult(result, relatedItems)
    }

    function refresh() {
        if (root.currentSource === "component")
            return root.openComponent(root.currentId)
        if (root.currentSource === "concept")
            return root.openConcept(root.currentId)
        return root.concepto
    }

    anchors.centerIn: Overlay.overlay
    width: Math.max(1, Math.min(1000, root.viewportWidth - 40))
    height: Math.max(1, Math.min(740, root.viewportHeight - 40))
    padding: 0
    modal: true
    dim: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    Overlay.modal: Rectangle {
        color: "#990F172A"
    }

    background: Rectangle {
        color: "transparent"
    }

    contentItem: ContextPanel {
        id: theoryPanel

        objectName: root.panelObjectName
        visible: root.visible
        concepto: root.concepto
        relatedConcepts: root.relacionados
        errorCarga: root.errorCarga
        closable: true
        expanded: true
        sx: root.contentScale
        sy: root.contentScale

        onCloseRequested: root.close()
        onConceptRequested: function(conceptId) {
            root.openConcept(conceptId)
        }
    }

    onOpened: theoryPanel.prepareForOpen()

    Connections {
        target: root.theoryController
        ignoreUnknownSignals: true

        function onTeoriaRecargada() {
            if (root.visible)
                root.refresh()
        }
    }
}
