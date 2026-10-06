pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

// Pantalla de bienvenida (hub del estudiante).
//
// Responde a tres preguntas en este orden de lectura:
//   1. ¿Dónde estoy?          → saludo + estado de la ruta
//   2. ¿Qué me conviene hacer? → UNA acción primaria según el progreso
//   3. ¿Qué más puedo hacer?   → laboratorio como alternativa, sin competir
//
// La pantalla tiene tres estados (nuevo, enCurso, completado). Cada uno
// cambia qué tarjeta se destaca, el texto del CTA y el mensaje del
// encabezado; el layout no se mueve, para no desorientar al volver.
PagePrincipal {
    id: root
    objectName: "welcomeScreen"

    // ─────────────────────────────────────────────────────────────
    // CONFIGURACIÓN: si es true, el laboratorio queda bloqueado según la
    // misma regla que la ruta (progressController.etapaDisponible(3)).
    // En false, el laboratorio está siempre disponible desde aquí. Como
    // esta pantalla es la única entrada del perfil de estudiante, este
    // valor decide si el estudiante puede experimentar antes de la ruta.
    readonly property bool requireGuidedBeforeLabs: false
    // ─────────────────────────────────────────────────────────────

    // ── Fuentes de datos ─────────────────────────────────────────────
    readonly property var vm: typeof mainViewModel !== "undefined" && mainViewModel
                              ? mainViewModel : null
    readonly property var learningController: vm ? vm.learningController : null
    readonly property var progressController: vm ? vm.progressController : null
    readonly property var profileController: vm ? vm.profileController : null
    readonly property var libraryController: vm ? vm.modelLibraryController : null

    property int revision: 0
    Connections {
        target: root.learningController
        ignoreUnknownSignals: true
        function onProgressChanged() { root.revision += 1 }
    }
    Connections {
        target: root.progressController
        ignoreUnknownSignals: true
        function onProgresoCambio() { root.revision += 1 }
        function onBanderasCambio() { root.revision += 1 }
    }

    // ── Progreso de la ruta (5 etapas) ───────────────────────────────
    readonly property var etapas: {
        var r = root.revision
        var pc = root.progressController
        return [
            { nombre: "Diagnóstico", completada: pc ? pc.preTestCompletado : false },
            { nombre: "Aprendizaje", completada: pc ? pc.recorridoCompletado : false },
            { nombre: "Práctica",    completada: pc ? pc.laboratoriosCompletados : false },
            { nombre: "Evaluación",  completada: pc ? pc.postTestCompletado : false },
            { nombre: "Seguimiento", completada: pc ? pc.seguimientoVisitado : false }
        ]
    }
    readonly property int etapasCompletadas: {
        var n = 0
        for (var i = 0; i < etapas.length; ++i)
            if (etapas[i].completada) n += 1
        return n
    }
    readonly property int etapaActual: {
        for (var i = 0; i < etapas.length; ++i)
            if (!etapas[i].completada) return i
        return -1
    }

    // Unidades del recorrido guiado (detalle de la etapa "Aprendizaje").
    readonly property int completedUnitsCount: {
        var r = root.revision
        return learningController ? Number(learningController.completedUnitsCount) : 0
    }
    readonly property int totalUnitsCount: learningController ? Number(learningController.totalUnits) : 0
    readonly property bool learningStarted: {
        var r = root.revision
        return etapasCompletadas > 0 || completedUnitsCount > 0
               || (learningController && (Number(learningController.lastUnitIndex) > 0
                                           || Number(learningController.lastConceptIndex) > 0))
    }

    // ── Laboratorio ──────────────────────────────────────────────────
    readonly property bool labsUnlocked: {
        var r = root.revision
        if (!root.requireGuidedBeforeLabs) return true
        return root.progressController ? root.progressController.etapaDisponible(3) : true
    }
    readonly property string motivoBloqueoLabs: {
        var r = root.revision
        return root.progressController ? root.progressController.motivoBloqueo(3) : ""
    }
    readonly property int modelosGuardados: libraryController && libraryController.modelos
                                            ? libraryController.modelos.length : 0

    // ── Perfil ───────────────────────────────────────────────────────
    readonly property string primerNombre: {
        var nombre = profileController ? String(profileController.activeStudentName || "") : ""
        return nombre.trim().split(/\s+/)[0] || ""
    }

    // ── Estado de la pantalla ────────────────────────────────────────
    state: etapaActual === -1 ? "completado" : (learningStarted ? "enCurso" : "nuevo")

    states: [
        State {
            name: "nuevo"
            PropertyChanges {
                tarjetaRuta.destacada: true
                tarjetaRuta.insignia: "Recomendado para empezar"
                botonRuta.text: "Comenzar recorrido"
                subtitulo.text: root.labsUnlocked
                                ? "Te sugerimos empezar por la ruta guiada. El laboratorio queda disponible cuando quieras experimentar."
                                : "Empieza por la ruta guiada: al completarla se abre el laboratorio."
            }
        },
        State {
            name: "enCurso"
            PropertyChanges {
                tarjetaRuta.destacada: true
                tarjetaRuta.insignia: "En curso · " + root.etapasCompletadas + " de " + root.etapas.length
                botonRuta.text: "Continuar: " + root.etapas[root.etapaActual].nombre
                subtitulo.text: "Vas en la etapa " + (root.etapaActual + 1) + " de " + root.etapas.length
                                + ". Retoma donde lo dejaste."
            }
        },
        State {
            name: "completado"
            PropertyChanges {
                tarjetaRuta.destacada: false
                tarjetaRuta.insignia: "Completada"
                tarjetaRuta.insigniaFondo: Style.Theme.exito_fondo
                tarjetaRuta.insigniaTexto: Style.Theme.exito_texto
                botonRuta.text: "Repasar la ruta"
                botonRuta.enfasis: "medio"
                tarjetaLab.destacada: true
                subtitulo.text: "Completaste la ruta. El laboratorio es tuyo para experimentar."
            }
        }
    ]

    function descripcionEtapa(indice) {
        switch (indice) {
        case 0: return "un pre-test breve para saber de dónde partes."
        case 1: return (root.totalUnitsCount > 0 ? root.totalUnitsCount : "Varias")
                       + " unidades guiadas por cada bloque del Transformer."
        case 2: return "entrena, abre y compara modelos en el laboratorio."
        case 3: return "un post-test para medir cuánto avanzaste."
        case 4: return "revisa tus resultados y tu progreso."
        }
        return ""
    }

    // ── Navegación ───────────────────────────────────────────────────
    function abrirRuta() {
        root.stackView.push("ModuleMapScreen.qml", { "stackView": root.stackView })
    }

    function abrirLaboratorio(pantalla, laboratorioId) {
        if (!root.labsUnlocked)
            return
        // Abrir un laboratorio desde aquí también cuenta para la etapa
        // "Práctica", igual que desde la ruta: el progreso es uno solo.
        if (root.progressController && laboratorioId)
            root.progressController.registrarLaboratorioAbierto(laboratorioId)
        root.stackView.push(pantalla, { "stackView": root.stackView })
    }

    Component.onCompleted: botonRuta.forceActiveFocus()

    // ── Layout ───────────────────────────────────────────────────────
    // Flickable + barra superpuesta (no ScrollView): así el ancho útil no
    // depende de si aparece la barra, y el texto no re-envuelve en bucle.
    Flickable {
        id: pageScroll
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: lienzo.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Item {
            id: lienzo
            readonly property real margen: Math.max(24, Math.min(48, pageScroll.width * 0.035))
            readonly property real reservaSuperior: 76   // botón "Cambiar perfil"
            width: pageScroll.width
            implicitHeight: Math.max(pageScroll.height,
                                     contenido.implicitHeight + reservaSuperior + margen)

            BotonSecundario {
                objectName: "welcomeBackToProfilesButton"
                x: lienzo.margen
                y: 20
                width: 160
                height: 36
                text: "← Cambiar perfil"
                Accessible.description: "Vuelve a la selección de perfil"
                onClicked: root.stackView.pop()
            }

            ColumnLayout {
                id: contenido
                // Ancho de lectura cómodo: en monitores grandes las tarjetas
                // no se estiran hasta volverse franjas difíciles de escanear.
                width: Math.min(1080, lienzo.width - 2 * lienzo.margen)
                anchors.horizontalCenter: parent.horizontalCenter
                // Centrado vertical óptico (un poco por encima del centro).
                y: Math.max(lienzo.reservaSuperior,
                            (lienzo.height - implicitHeight) * 0.42)
                spacing: 0

                // ── Encabezado ──────────────────────────────────────
                ColumnLayout {
                    id: encabezado
                    Layout.fillWidth: true
                    spacing: 6
                    opacity: 0
                    NumberAnimation on opacity {
                        to: 1
                        duration: Style.Theme.movimientoReducido ? 0 : Style.Theme.duracionEntrada
                        easing.type: Easing.OutCubic
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "VISUALIZADOR DE TRANSFORMERS"
                        color: Style.Theme.acento_texto
                        font.family: Style.Theme.fuente_interfaz
                        font.pixelSize: 12
                        font.bold: true
                        font.letterSpacing: 1.6
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.primerNombre.length > 0
                              ? "Hola, " + root.primerNombre
                              : "Te damos la bienvenida"
                        color: Style.Theme.texto_primario
                        font.family: Style.Theme.fuente_interfaz
                        font.pixelSize: Math.max(28, Math.min(36, root.width * 0.026))
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        Accessible.role: Accessible.Heading
                        Accessible.name: text
                    }

                    Text {
                        id: subtitulo
                        Layout.fillWidth: true
                        Layout.maximumWidth: 640
                        Layout.alignment: Qt.AlignHCenter
                        color: Style.Theme.texto_secundario
                        font.family: Style.Theme.fuente_interfaz
                        font.pixelSize: Style.Theme.bodySize
                        lineHeight: 1.25
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }

                // ── Tarjetas ────────────────────────────────────────
                GridLayout {
                    id: rejilla
                    Layout.fillWidth: true
                    Layout.topMargin: 32
                    columns: contenido.width < 820 ? 1 : 2
                    columnSpacing: 24
                    rowSpacing: 24

                    // Proporción 56/44: la ruta pesa más (es la recomendada)
                    // sin dejar al laboratorio tan angosto que trunque texto.
                    readonly property real anchoUtil: width - (columns > 1 ? columnSpacing : 0)

                    // ── Ruta de aprendizaje (primaria) ──────────────
                    TarjetaBienvenida {
                        id: tarjetaRuta
                        objectName: "welcomeLearningCard"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: rejilla.columns > 1 ? rejilla.anchoUtil * 0.56 : rejilla.width
                        retrasoEntrada: Style.Theme.escalonEntrada

                        glifo: "◆"
                        titulo: "Ruta de aprendizaje"
                        descripcion: "Recorre la arquitectura paso a paso, desde tu diagnóstico inicial hasta ver cuánto avanzaste."

                        RutaEtapas {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            etapas: root.etapas
                        }

                        // "Siguiente paso": nombra la etapa y dice para qué
                        // sirve. Reduce la pregunta "¿y ahora qué hago?" a cero.
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: 8
                            implicitHeight: siguiente.implicitHeight + 28
                            radius: 10
                            color: Style.Theme.concepto_fondo

                            ColumnLayout {
                                id: siguiente
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 4

                                Text {
                                    Layout.fillWidth: true
                                    text: root.etapaActual === -1 ? "RUTA COMPLETADA" : "SIGUIENTE PASO"
                                    color: Style.Theme.concepto_texto
                                    font.family: Style.Theme.fuente_interfaz
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.letterSpacing: 1.2
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.etapaActual === -1
                                          ? "Puedes volver a cualquier etapa para repasar."
                                          : root.etapas[root.etapaActual].nombre + ": "
                                            + root.descripcionEtapa(root.etapaActual)
                                    color: Style.Theme.texto_primario
                                    font.family: Style.Theme.fuente_interfaz
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                }

                                // Grano fino solo donde importa: unidades de la
                                // etapa "Aprendizaje".
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 6
                                    visible: root.etapaActual === 1 && root.totalUnitsCount > 0
                                    spacing: 10

                                    BarraProgreso {
                                        Layout.fillWidth: true
                                        valor: root.totalUnitsCount > 0
                                               ? root.completedUnitsCount / root.totalUnitsCount : 0
                                        etiquetaAccesible: "Unidades de aprendizaje completadas"
                                    }
                                    Text {
                                        text: root.completedUnitsCount + " de " + root.totalUnitsCount + " unidades"
                                        color: Style.Theme.texto_secundario_fuerte
                                        font.family: Style.Theme.fuente_interfaz
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true; Layout.minimumHeight: 8 }

                        BotonAcento {
                            id: botonRuta
                            objectName: "welcomeLearningButton"
                            Layout.fillWidth: true
                            Accessible.description: "Abre la ruta de aprendizaje"
                            onClicked: root.abrirRuta()
                        }
                    }

                    // ── Laboratorio (secundaria) ────────────────────
                    TarjetaBienvenida {
                        id: tarjetaLab
                        objectName: "welcomeLabCard"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: rejilla.columns > 1 ? rejilla.anchoUtil * 0.44 : rejilla.width
                        retrasoEntrada: Style.Theme.escalonEntrada * 2

                        glifo: root.labsUnlocked ? "⚗" : "🔒"
                        fuenteGlifo: root.labsUnlocked ? Style.Theme.fuente_simbolos : Style.Theme.fuente_emoji
                        glifoColor: Style.Theme.info_texto
                        glifoFondo: Style.Theme.info_fondo
                        titulo: "Laboratorio"
                        descripcion: root.labsUnlocked
                                     ? "Experimenta por tu cuenta con modelos reales."
                                     : root.motivoBloqueoLabs
                        insignia: root.labsUnlocked ? "" : "Bloqueado"
                        insigniaFondo: Style.Theme.aviso_fondo
                        insigniaTexto: Style.Theme.aviso_texto

                        AccionLaboratorio {
                            objectName: "welcomeTrainingButton"
                            Layout.fillWidth: true
                            enabled: root.labsUnlocked
                            glifo: "⚙"
                            titulo: "Entrenar un modelo"
                            detalle: "Elige datos e hiperparámetros"
                            onClicked: root.abrirLaboratorio("SetupScreen.qml", "entrenamiento")
                        }

                        AccionLaboratorio {
                            objectName: "welcomeLibraryButton"
                            Layout.fillWidth: true
                            enabled: root.labsUnlocked
                            glifo: "▤"
                            titulo: "Abrir un modelo guardado"
                            detalle: root.modelosGuardados === 0
                                     ? "Tu biblioteca aún está vacía"
                                     : root.modelosGuardados + (root.modelosGuardados === 1
                                                                ? " modelo en tu biblioteca"
                                                                : " modelos en tu biblioteca")
                            onClicked: root.abrirLaboratorio("ModelLibraryScreen.qml", "biblioteca")
                        }

                        AccionLaboratorio {
                            objectName: "welcomeComparisonButton"
                            Layout.fillWidth: true
                            enabled: root.labsUnlocked
                            glifo: "⇄"
                            titulo: "Comparar modelos"
                            detalle: root.modelosGuardados >= 2
                                     ? "Misma entrada, dos modelos, lado a lado"
                                     : "Necesitas al menos 2 modelos guardados"
                            detalleEsAviso: root.modelosGuardados < 2
                            onClicked: root.abrirLaboratorio("ComparisonScreen.qml", "comparacion")
                        }

                        // Relleno final: mantiene las acciones pegadas a la
                        // descripción (proximidad) en vez de repartir el hueco.
                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }
}
