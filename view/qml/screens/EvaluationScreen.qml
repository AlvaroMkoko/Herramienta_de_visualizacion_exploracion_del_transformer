pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles" as Style
import "../components"

// Pantalla de pre-test y post-test (instrumento v3).
//
// El reactivo no se dibuja aquí: un Loader elige el componente Reactivo* y le
// entrega la pregunta pública.
//
// El componente se elige por `presentacion`, no por `tipo`. Son dos ejes
// distintos y hacen falta los dos:
//
//   tipo          qué FORMA tiene la respuesta que espera el modelo
//   presentacion  cómo se DIBUJA y se toca el reactivo
//
// Dos reactivos del mismo tipo pueden verse completamente distintos (A3 y F2
// son ambos «etapas»; uno se contesta tocando dentro de una frase y el otro con
// V/F más un acordeón), y dos presentaciones distintas pueden producir la misma
// forma de respuesta. Si el banco no declara `presentacion`, o declara una que
// esta versión no conoce, se cae al despacho por tipo: un banco viejo sigue
// abriendo.
//
// La retroalimentación es al final: mientras dura el examen ninguna propiedad
// expuesta revela si la respuesta en curso es correcta.
PagePrincipal {
    id: root
    objectName: "evaluationScreen"

    property string assessmentType: "pre"
    readonly property var evaluationController: mainViewModel.evaluationController
    readonly property var currentQuestion: evaluationController.currentQuestion
    readonly property bool showingResult: evaluationController.finished
    property string errorMessage: ""
    property int questionAtTop: 0

    readonly property var resultado: evaluationController.result

    readonly property string presentacion: String(
        root.currentQuestion.presentacion || "")

    // Presentaciones cuyo componente dibuja el enunciado por su cuenta (porque
    // la respuesta vive DENTRO del texto). La pantalla no lo repite arriba.
    readonly property bool reactivoDibujaEnunciado:
        root.presentacion === "caja_en_linea"
        || root.presentacion === "fragmentos_clicables"

    readonly property string enunciadoCompleto: String(root.currentQuestion.prompt || "")
    readonly property int corteEscenario: root.enunciadoCompleto.indexOf("\n\n")

    // Los reactivos de predicción traen el escenario y la pregunta en el mismo
    // enunciado, separados por un renglón en blanco. Mostrarlos como un solo
    // bloque obliga a releer el caso entero para recordar qué se pregunta; el
    // escenario va en un panel fijo y la pregunta queda sola y en grande.
    readonly property bool tieneEscenario:
        root.presentacion === "tarjetas_con_escenario" && root.corteEscenario !== -1

    readonly property string textoEscenario: root.tieneEscenario
        ? root.enunciadoCompleto.substring(0, root.corteEscenario).trim() : ""

    readonly property string textoEnunciado: root.tieneEscenario
        ? root.enunciadoCompleto.substring(root.corteEscenario + 2).trim()
        : root.enunciadoCompleto

    // Contador de selecciones. Solo aparece en los reactivos de selección
    // múltiple, donde el instrumento no dice cuántas opciones son correctas:
    // el contador informa sin delatar (nunca compara contra el total real).
    readonly property string textoContador: {
        if (String(root.evaluationController.currentQuestionType) !== "seleccion_multiple")
            return ""
        var respuesta = root.evaluationController.currentAnswer
        var elegidas = (respuesta && respuesta.opciones_ids)
                       ? respuesta.opciones_ids.length : 0
        if (elegidas === 0)
            return ""
        return elegidas === 1 ? "1 opción seleccionada"
                              : elegidas + " opciones seleccionadas"
    }

    function returnToLearningPath() {
        if (root.stackView.depth >= 3)
            root.stackView.pop(root.stackView.get(root.stackView.depth - 3))
        else
            root.stackView.pop()
    }

    function numero(valor, decimales) {
        var real = Number(valor)
        return isFinite(real) ? real.toFixed(decimales) : "—"
    }

    // Quita los ceros sobrantes: 17 en vez de 17.00, pero 17.25 completo.
    function puntos(valor) {
        var real = Number(valor) || 0
        return (Math.abs(real - Math.round(real)) < 0.001)
                ? String(Math.round(real)) : root.numero(real, 2)
    }

    Component { id: compOpcionUnica; ReactivoOpcionUnica {} }
    Component { id: compSeleccionMultiple; ReactivoSeleccionMultiple {} }
    Component { id: compTexto; ReactivoTexto {} }
    Component { id: compAsignacion; ReactivoAsignacion {} }
    Component { id: compOrdenar; ReactivoOrdenar {} }
    Component { id: compCestas; ReactivoCestas {} }
    Component { id: compRelacionar; ReactivoRelacionar {} }
    Component { id: compEtapas; ReactivoEtapas {} }
    Component { id: compFragmentos; ReactivoFragmentos {} }
    Component { id: compNoSoportado; Text {
            text: "Este formato de reactivo todavía no tiene vista."
            color: Style.Theme.error_texto
            font.family: Style.Theme.fuente_interfaz
            wrapMode: Text.WordWrap
        } }

    // Eje de dibujo. Solo se listan las presentaciones que tienen una vista
    // propia o que conviene dejar escritas para que se vea de un vistazo qué
    // formato usa qué componente.
    function componentePara(presentacion, tipo) {
        switch (presentacion) {
        case "tarjetas":
        case "tarjetas_con_escenario":
        case "heatmap_clic":                  return compOpcionUnica
        case "chips_toggle":                  return compSeleccionMultiple
        case "caja_en_linea":                 return compTexto
        case "lista_arrastrable":             return compOrdenar
        case "cestas":                        return compCestas
        case "lineas_o_tocar_para_emparejar": return compRelacionar
        case "pasos":
        case "botones_vf_acordeon":           return compEtapas
        case "fragmentos_clicables":          return compFragmentos
        }
        return root.componentePorTipo(tipo)
    }

    // Eje de respuesta. Es el respaldo: un banco sin `presentacion`, o con una
    // presentación que esta versión todavía no dibuja, se sigue pudiendo
    // contestar con la vista genérica del tipo.
    function componentePorTipo(tipo) {
        switch (tipo) {
        case "opcion_unica":       return compOpcionUnica
        case "seleccion_multiple": return compSeleccionMultiple
        case "texto":              return compTexto
        case "asignacion":         return compAsignacion
        case "etapas":             return compEtapas
        }
        // Nunca falla en silencio: si el banco trae un tipo desconocido, se ve.
        return compNoSoportado
    }

    Component.onCompleted: {
        if (!evaluationController.isActive && !evaluationController.finished)
            evaluationController.startEvaluation(assessmentType)
        root.questionAtTop = evaluationController.currentQuestionNumber
    }

    // Un bloque Connections admite UN SOLO target; dos en el mismo bloque es
    // error de compilación y tumba la pantalla entera.
    Connections {
        target: root.evaluationController
        function onError(message) { root.errorMessage = message }

        // Se escucha questionChanged, no stateChanged: la segunda se emite en
        // cada tecla y no hay nada que reposicionar por escribir una letra.
        function onQuestionChanged() {
            const questionNumber = root.evaluationController.currentQuestionNumber
            if (questionNumber === root.questionAtTop)
                return

            root.questionAtTop = questionNumber
            root.errorMessage = ""
            if (questionScroll.ScrollBar.vertical)
                questionScroll.ScrollBar.vertical.position = 0
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 50 * root.sx
        anchors.rightMargin: 50 * root.sx
        anchors.topMargin: 30 * root.sy
        anchors.bottomMargin: 34 * root.sy
        spacing: 18 * root.sy

        // ── Encabezado ───────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 76 * root.sy
            spacing: 18 * root.sx

            BotonPrincipal {
                objectName: "evaluationExitButton"
                Layout.preferredWidth: 190 * root.sx
                Layout.preferredHeight: 48 * root.sy
                text: "← Salir"
                onClicked: root.stackView.pop()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2 * root.sy
                Text {
                    text: root.evaluationController.eyebrow
                    color: Style.Theme.acento_fuerte
                    font.family: Style.Theme.fuente_interfaz
                    font.pixelSize: 13 * root.sx
                    font.bold: true
                    font.letterSpacing: 0.8
                }
                RowLayout {
                    spacing: 10 * root.sx
                    Text {
                        text: root.evaluationController.title
                        color: Style.Theme.texto_primario
                        font.family: Style.Theme.fuente_interfaz
                        font.pixelSize: 30 * root.sx
                        font.bold: true
                    }
                    Rectangle {
                        visible: root.evaluationController.forma !== ""
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: etiquetaForma.implicitWidth + 18 * root.sx
                        Layout.preferredHeight: 24 * root.sy
                        radius: height / 2
                        color: Style.Theme.chip_fondo
                        border.width: 1
                        border.color: Style.Theme.chip_borde
                        Text {
                            id: etiquetaForma
                            anchors.centerIn: parent
                            text: "Forma " + root.evaluationController.forma
                            color: Style.Theme.texto_secundario
                            font.family: Style.Theme.fuente_interfaz
                            font.pixelSize: 11 * root.sx
                            font.bold: true
                        }
                    }
                }
            }

            Text {
                visible: !root.showingResult
                text: "Reactivo " + root.evaluationController.currentQuestionNumber
                      + " de " + root.evaluationController.totalQuestions
                color: Style.Theme.texto_secundario_fuerte
                font.family: Style.Theme.fuente_interfaz
                font.pixelSize: 15 * root.sx
                font.bold: true
            }
        }

        // ── Barra de progreso ────────────────────────────────────────
        Rectangle {
            visible: !root.showingResult
            Layout.fillWidth: true
            Layout.preferredHeight: 12 * root.sy
            radius: height / 2
            color: Style.Theme.divisor

            Rectangle {
                width: parent.width * root.evaluationController.progressFraction
                height: parent.height
                radius: parent.radius
                color: Style.Theme.acento
                Behavior on width { NumberAnimation { duration: 180 } }
            }
        }

        // ── Reactivo en curso ────────────────────────────────────────
        RectanglePrincipal {
            objectName: "evaluationQuestionCard"
            visible: !root.showingResult
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumWidth: 1500 * root.sx
            Layout.alignment: Qt.AlignHCenter
            sx: root.sx
            sy: root.sy

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 30 * root.sx
                spacing: 14 * root.sy

                // Metadatos del reactivo
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10 * root.sx

                    Repeater {
                        model: [
                            { texto: root.currentQuestion.dimension_nombre
                                     || root.currentQuestion.formato || "",
                              fondo: Style.Theme.acento_fondo,
                              letra: Style.Theme.acento_fuerte },
                            { texto: root.currentQuestion.bloom_level || "",
                              fondo: Style.Theme.info_fondo,
                              letra: Style.Theme.info_texto }
                        ]

                        delegate: Rectangle {
                            id: chip
                            required property var modelData
                            visible: String(chip.modelData.texto) !== ""
                            Layout.preferredWidth: textoChip.implicitWidth + 22 * root.sx
                            Layout.preferredHeight: 34 * root.sy
                            radius: height / 2
                            color: chip.modelData.fondo

                            Text {
                                id: textoChip
                                anchors.centerIn: parent
                                text: chip.modelData.texto
                                color: chip.modelData.letra
                                font.family: Style.Theme.fuente_interfaz
                                font.pixelSize: 11 * root.sx
                                font.bold: true
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.currentQuestion.code || ""
                        color: Style.Theme.texto_terciario
                        font.family: Style.Theme.fuente_mono
                        font.pixelSize: 14 * root.sx
                        font.bold: true
                    }
                }

                ScrollView {
                    id: questionScroll
                    objectName: "evaluationQuestionScroll"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    ColumnLayout {
                        width: questionScroll.availableWidth
                        spacing: 14 * root.sy

                        // Escenario del caso, cuando el reactivo lo trae.
                        Rectangle {
                            objectName: "evaluationScenarioPanel"
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible
                                ? textoEscenario.implicitHeight + 32 * root.sy : 0
                            visible: root.tieneEscenario
                            radius: 12 * root.sx
                            color: Style.Theme.info_fondo

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 4 * root.sx
                                radius: width / 2
                                color: Style.Theme.info_texto
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 20 * root.sx
                                anchors.rightMargin: 16 * root.sx
                                anchors.topMargin: 14 * root.sy
                                anchors.bottomMargin: 14 * root.sy
                                spacing: 5 * root.sy

                                Text {
                                    text: "ESCENARIO"
                                    color: Style.Theme.info_texto
                                    font.family: Style.Theme.fuente_interfaz
                                    font.pixelSize: 10 * root.sx
                                    font.bold: true
                                    font.letterSpacing: 0.9
                                }
                                Text {
                                    id: textoEscenario
                                    Layout.fillWidth: true
                                    text: root.textoEscenario
                                    color: Style.Theme.texto_primario
                                    font.family: Style.Theme.fuente_interfaz
                                    font.pixelSize: 16 * root.sx
                                    lineHeight: 1.25
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        Text {
                            objectName: "evaluationQuestionPrompt"
                            Layout.fillWidth: true
                            visible: !root.reactivoDibujaEnunciado
                            text: root.textoEnunciado
                            color: Style.Theme.texto_primario
                            font.family: Style.Theme.fuente_interfaz
                            font.pixelSize: 22 * root.sx
                            font.bold: true
                            lineHeight: 1.2
                            wrapMode: Text.WordWrap
                        }

                        // Recurso adjunto (por ahora, solo la matriz de atención).
                        // Se declara aparte del cuerpo del reactivo, así que
                        // compone con cualquier tipo de respuesta.
                        Loader {
                            id: cargadorRecurso
                            Layout.fillWidth: true
                            active: !!root.currentQuestion.recurso
                                    && root.currentQuestion.recurso.tipo === "matriz_atencion"
                            visible: active
                            sourceComponent: RecursoMatrizAtencion {}
                            onLoaded: {
                                item.sx = Qt.binding(function () { return root.sx })
                                item.sy = Qt.binding(function () { return root.sy })
                                item.recurso = Qt.binding(function () {
                                    return root.currentQuestion.recurso || ({})
                                })
                            }
                        }

                        // El reactivo propiamente dicho.
                        //
                        // `pregunta` se ASIGNA, no se enlaza con Qt.binding. Un
                        // binding aquí crea un ciclo: escribir en un campo emite
                        // stateChanged, el enlace reevalúa la pregunta, el
                        // componente se restaura, eso vuelve a escribir en el
                        // campo… El disparador es `preguntaId`, que es una
                        // cadena: QML compara cadenas por valor, así que solo
                        // avisa cuando el reactivo cambia de verdad.
                        Loader {
                            id: cargadorReactivo
                            objectName: "evaluationQuestionLoader"
                            Layout.fillWidth: true

                            readonly property string preguntaId: root.currentQuestion.id || ""

                            sourceComponent: root.componentePara(
                                                 root.presentacion,
                                                 root.evaluationController.currentQuestionType)

                            function montar() {
                                // No se usa hasOwnProperty: en QML las
                                // propiedades y señales declaradas viven en el
                                // meta-objeto, no como propiedades propias de
                                // JavaScript, así que hasOwnProperty miente.
                                // Se comprueba el valor directamente.
                                if (!item || item.pregunta === undefined)
                                    return
                                item.sx = Qt.binding(function () { return root.sx })
                                item.sy = Qt.binding(function () { return root.sy })
                                // El orden importa: la respuesta previa debe
                                // estar puesta antes que la pregunta, porque
                                // asignar `pregunta` dispara la restauración.
                                item.respuestaInicial = root.evaluationController.currentAnswer
                                item.pregunta = root.currentQuestion
                            }

                            onLoaded: {
                                if (!item)
                                    return
                                // La señal se detecta por su método connect, no
                                // con hasOwnProperty. Si esta conexión no se
                                // hace, el reactivo se ve y se puede responder,
                                // pero el controlador nunca se entera y el botón
                                // de continuar queda deshabilitado para siempre.
                                if (item.respuestaCambiada
                                        && typeof item.respuestaCambiada.connect === "function") {
                                    item.respuestaCambiada.connect(function (valor) {
                                        root.evaluationController.registrarRespuesta(valor)
                                    })
                                }
                                cargadorReactivo.montar()
                            }

                            // Al pasar de un reactivo a otro del mismo tipo, el
                            // Loader conserva su item y `onLoaded` no vuelve a
                            // dispararse: sin esto, la pantalla seguiría
                            // mostrando la pregunta anterior.
                            onPreguntaIdChanged: cargadorReactivo.montar()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Style.Theme.divisor
                }

                RowLayout {
                    objectName: "evaluationActions"
                    Layout.fillWidth: true
                    Layout.minimumHeight: 54 * root.sy
                    Layout.preferredHeight: 54 * root.sy
                    spacing: 12 * root.sx

                    // Regreso al reactivo anterior. La respuesta ya registrada
                    // se restaura sola: el controlador la vuelve a poner en
                    // curso al cambiar de reactivo, así que volver atrás no
                    // obliga a contestar de nuevo.
                    BotonSecundario {
                        objectName: "evaluationPreviousButton"
                        Layout.preferredWidth: 150 * root.sx
                        Layout.preferredHeight: 44 * root.sy
                        Layout.alignment: Qt.AlignVCenter
                        sx: root.sx
                        sy: root.sy
                        text: "← Anterior"
                        enabled: root.evaluationController.canGoBack
                        opacity: enabled ? 1 : 0.4
                        Accessible.name: "Volver al reactivo anterior"
                        onClicked: root.evaluationController.goToPreviousQuestion()
                    }

                    Rectangle {
                        objectName: "evaluationSelectionCounter"
                        visible: root.textoContador !== ""
                        Layout.preferredWidth: visible
                            ? etiquetaContador.implicitWidth + 22 * root.sx : 0
                        Layout.preferredHeight: 30 * root.sy
                        Layout.alignment: Qt.AlignVCenter
                        radius: height / 2
                        color: Style.Theme.acento_fondo

                        Text {
                            id: etiquetaContador
                            anchors.centerIn: parent
                            text: root.textoContador
                            color: Style.Theme.acento_fuerte
                            font.family: Style.Theme.fuente_interfaz
                            font.pixelSize: 11 * root.sx
                            font.bold: true
                        }
                    }

                    Text {
                        objectName: "evaluationStatusText"
                        Layout.fillWidth: true
                        text: root.errorMessage !== ""
                              ? root.errorMessage
                              : (root.evaluationController.isRevisiting
                                 ? "Estás revisando una respuesta anterior. "
                                   + "Se actualiza al continuar."
                                 : (root.evaluationController.canContinue
                                    ? "Respuesta registrada"
                                    : "Completa tu respuesta para continuar"))
                        color: root.errorMessage !== ""
                               ? Style.Theme.error_texto
                               : (root.evaluationController.isRevisiting
                                  ? Style.Theme.aviso_texto
                                  : (root.evaluationController.canContinue
                                     ? Style.Theme.exito_texto
                                     : Style.Theme.texto_secundario))
                        font.family: Style.Theme.fuente_interfaz
                        font.pixelSize: 13 * root.sx
                        wrapMode: Text.WordWrap
                    }

                    // Regreso directo al punto donde se dejó la evaluación.
                    // Sin esto, retroceder cinco reactivos para corregir uno
                    // obligaría a volver a pasar por los cinco.
                    BotonSecundario {
                        objectName: "evaluationResumeButton"
                        visible: root.evaluationController.isRevisiting
                        Layout.preferredWidth: visible ? 210 * root.sx : 0
                        Layout.preferredHeight: 44 * root.sy
                        Layout.alignment: Qt.AlignVCenter
                        sx: root.sx
                        sy: root.sy
                        text: "Ir al reactivo "
                              + root.evaluationController.frontierQuestionNumber + " →"
                        Accessible.name: "Volver al reactivo donde te quedaste"
                        onClicked: root.evaluationController.goToFrontierQuestion()
                    }

                    BotonPrincipal {
                        objectName: "evaluationNextButton"
                        Layout.preferredWidth: 250 * root.sx
                        Layout.preferredHeight: 54 * root.sy
                        minimum_text_size: 13
                        enabled: root.evaluationController.canContinue
                        opacity: enabled ? 1 : 0.45
                        // Al revisar, el botón avanza uno; «Finalizar» solo
                        // aparece de verdad en el último reactivo, que es
                        // cuando el modelo califica.
                        text: root.evaluationController.isLastQuestion
                              ? "Finalizar evaluación"
                              : "Guardar y continuar →"
                        onClicked: root.evaluationController.submitCurrentAnswer()
                    }
                }
            }
        }

        // ── Resultado ────────────────────────────────────────────────
        RectanglePrincipal {
            objectName: "evaluationResultCard"
            visible: root.showingResult
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumWidth: 1300 * root.sx
            Layout.alignment: Qt.AlignHCenter
            sx: root.sx
            sy: root.sy

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 28 * root.sx
                spacing: 12 * root.sy

                Text {
                    Layout.fillWidth: true
                    text: "Evaluación completada"
                    color: Style.Theme.texto_primario
                    font.family: Style.Theme.fuente_interfaz
                    font.pixelSize: 28 * root.sx
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    objectName: "evaluationScoreText"
                    Layout.fillWidth: true
                    text: root.puntos(root.resultado.puntaje) + " / "
                          + root.puntos(root.resultado.maximo)
                    color: Style.Theme.acento_fuerte
                    font.family: Style.Theme.fuente_interfaz
                    font.pixelSize: 52 * root.sx
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: (root.resultado.percentage || 0) + "% del puntaje total"
                    color: Style.Theme.texto_secundario_fuerte
                    font.family: Style.Theme.fuente_interfaz
                    font.pixelSize: 16 * root.sx
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: root.evaluationController.resultMessage
                    color: Style.Theme.texto_secundario_fuerte
                    font.family: Style.Theme.fuente_interfaz
                    font.pixelSize: 15 * root.sx
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                ScrollView {
                    id: resultScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    ColumnLayout {
                        width: resultScroll.availableWidth
                        spacing: 10 * root.sy

                        Text {
                            text: "RESULTADO POR DIMENSIÓN"
                            color: Style.Theme.texto_secundario
                            font.family: Style.Theme.fuente_interfaz
                            font.pixelSize: 12 * root.sx
                            font.bold: true
                            font.letterSpacing: 0.8
                        }

                        Repeater {
                            model: root.resultado.dimensions || []
                            delegate: Rectangle {
                                id: filaDimension
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 68 * root.sy
                                radius: 10 * root.sx
                                color: Style.Theme.superficie_alterna
                                border.width: 1
                                border.color: Style.Theme.borde_medio

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14 * root.sx
                                    spacing: 12 * root.sx

                                    Text {
                                        Layout.fillWidth: true
                                        text: filaDimension.modelData.name
                                        color: Style.Theme.texto_primario
                                        font.family: Style.Theme.fuente_interfaz
                                        font.pixelSize: 14 * root.sx
                                        font.bold: true
                                        wrapMode: Text.WordWrap
                                    }
                                    ProgressBar {
                                        Layout.preferredWidth: 260 * root.sx
                                        from: 0
                                        to: 100
                                        value: filaDimension.modelData.percentage
                                    }
                                    Text {
                                        Layout.preferredWidth: 86 * root.sx
                                        horizontalAlignment: Text.AlignRight
                                        text: root.puntos(filaDimension.modelData.puntaje)
                                              + " / " + root.puntos(filaDimension.modelData.maximo)
                                        color: Style.Theme.acento_fuerte
                                        font.family: Style.Theme.fuente_mono
                                        font.pixelSize: 15 * root.sx
                                        font.bold: true
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.topMargin: 8 * root.sy
                            text: "RESULTADO POR NIVEL COGNITIVO"
                            color: Style.Theme.texto_secundario
                            font.family: Style.Theme.fuente_interfaz
                            font.pixelSize: 12 * root.sx
                            font.bold: true
                            font.letterSpacing: 0.8
                        }

                        Repeater {
                            model: root.resultado.bloom || []
                            delegate: Rectangle {
                                id: filaBloom
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52 * root.sy
                                radius: 10 * root.sx
                                color: Style.Theme.superficie_alterna
                                border.width: 1
                                border.color: Style.Theme.divisor

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14 * root.sx
                                    spacing: 12 * root.sx

                                    Text {
                                        Layout.fillWidth: true
                                        text: filaBloom.modelData.name
                                        color: Style.Theme.texto_primario
                                        font.family: Style.Theme.fuente_interfaz
                                        font.pixelSize: 13 * root.sx
                                    }
                                    ProgressBar {
                                        Layout.preferredWidth: 220 * root.sx
                                        from: 0
                                        to: 100
                                        value: filaBloom.modelData.percentage
                                    }
                                    Text {
                                        Layout.preferredWidth: 86 * root.sx
                                        horizontalAlignment: Text.AlignRight
                                        text: root.puntos(filaBloom.modelData.puntaje)
                                              + " / " + root.puntos(filaBloom.modelData.maximo)
                                        color: Style.Theme.texto_secundario_fuerte
                                        font.family: Style.Theme.fuente_mono
                                        font.pixelSize: 14 * root.sx
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 14 * root.sx

                    BotonPrincipal {
                        objectName: "evaluationRepeatButton"
                        Layout.preferredWidth: 240 * root.sx
                        Layout.preferredHeight: 54 * root.sy
                        text: "Repetir evaluación"
                        onClicked: root.evaluationController.startEvaluation(root.assessmentType)
                    }
                    BotonPrincipal {
                        objectName: "evaluationReturnHomeButton"
                        Layout.preferredWidth: 250 * root.sx
                        Layout.preferredHeight: 54 * root.sy
                        text: "Volver al flujo formativo"
                        onClicked: root.returnToLearningPath()
                    }
                }
            }
        }
    }
}
