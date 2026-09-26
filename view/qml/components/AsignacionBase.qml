pragma ComponentBehavior: Bound

import QtQuick

// Máquina de estados común a los tres subtipos de asignación del instrumento:
//
//   ordenar     (T4, S4)  colocar cada elemento en su posición 1..N
//   clasificar  (E4)      repartir enunciados entre categorías
//   relacionar  (A1, S2)  emparejar elemento con función
//
// Los tres producen la misma respuesta —`{"asignaciones": {elementoId: destinoId}}`—
// y se diferencian solo en cómo se ven y se tocan, así que el estado vive aquí
// una vez y cada disposición hereda de este tipo y pone su propia vista encima.
//
// Modelo de interacción: se toma un elemento (queda «en mano») y se suelta en un
// destino. Tocar es la vía principal y siempre suficiente; el arrastre es una
// comodidad encima de las mismas funciones, nunca la única forma de contestar.
// Un examen que solo se pueda contestar arrastrando deja fuera a quien usa
// teclado, lector de pantalla o una pantalla táctil pequeña, y eso mide destreza
// con el ratón, no comprensión del Transformer.
Item {
    id: base

    property var pregunta: ({})
    property var respuestaInicial: null
    property real sx: 1
    property real sy: 1

    signal respuestaCambiada(var valor)

    // elementoId -> destinoId
    property var asignaciones: ({})

    // Elemento tomado, a la espera de un destino. Cadena vacía = ninguno.
    property string enMano: ""

    // Las listas se leen con listaDe() y NO con una derivada directa: QML
    // dispara onPreguntaChanged en cuanto se asigna `pregunta`, pero reevalúa
    // los enlaces derivados después, así que dentro del handler una derivada
    // todavía vale lo que valía con la pregunta anterior.
    readonly property var elementos: base.listaDe("elementos")
    readonly property var destinos: base.listaDe("destinos")

    readonly property bool destinosUnicos: !!(base.pregunta
                                              && base.pregunta.destinos_unicos)
    readonly property string etiquetaDestino:
        (base.pregunta && base.pregunta.etiqueta_destino)
        ? String(base.pregunta.etiqueta_destino) : "Destino"

    readonly property string subtipo:
        (base.pregunta && base.pregunta.subtipo) ? String(base.pregunta.subtipo) : ""

    readonly property var pendientes: base.sinAsignar()
    readonly property bool completa: base.pendientes.length === 0
                                     && base.elementos.length > 0

    function listaDe(nombre) {
        if (!base.pregunta)
            return []
        var valor = base.pregunta[nombre]
        return (valor && valor.length !== undefined) ? valor : []
    }

    function respuestaActual() {
        var copia = {}
        for (var clave in base.asignaciones)
            copia[clave] = base.asignaciones[clave]
        return { "asignaciones": copia }
    }

    function restaurar() {
        var previas = (base.respuestaInicial && base.respuestaInicial.asignaciones)
                      ? base.respuestaInicial.asignaciones : ({})
        var limpias = {}
        for (var clave in previas) {
            var valor = String(previas[clave])
            if (valor !== "")
                limpias[clave] = valor
        }
        base.asignaciones = limpias
        base.enMano = ""
    }

    function destinoDe(elementoId) {
        var valor = base.asignaciones[String(elementoId)]
        return valor === undefined ? "" : String(valor)
    }

    function elementosEn(destinoId) {
        var dentro = []
        var lista = base.listaDe("elementos")
        for (var i = 0; i < lista.length; ++i) {
            var elementoId = String(lista[i].id)
            if (base.destinoDe(elementoId) === String(destinoId))
                dentro.push(lista[i])
        }
        return dentro
    }

    // Para destinos únicos: el elemento que lo ocupa, o null.
    function elementoEn(destinoId) {
        var dentro = base.elementosEn(destinoId)
        return dentro.length > 0 ? dentro[0] : null
    }

    function sinAsignar() {
        var fuera = []
        var lista = base.listaDe("elementos")
        for (var i = 0; i < lista.length; ++i) {
            if (base.destinoDe(String(lista[i].id)) === "")
                fuera.push(lista[i])
        }
        return fuera
    }

    function textoDe(elementoId) {
        var lista = base.listaDe("elementos")
        for (var i = 0; i < lista.length; ++i) {
            if (String(lista[i].id) === String(elementoId))
                return String(lista[i].texto || "")
        }
        return ""
    }

    function indiceDestino(destinoId) {
        var lista = base.listaDe("destinos")
        for (var i = 0; i < lista.length; ++i) {
            if (String(lista[i].id) === String(destinoId))
                return i
        }
        return -1
    }

    // ── Acciones ────────────────────────────────────────────────────

    function tomar(elementoId) {
        var id = String(elementoId)
        base.enMano = (base.enMano === id) ? "" : id
    }

    // Tocar un destino. Si no hay nada en mano y el destino está ocupado, se
    // toma lo que había: así un emparejamiento equivocado se corrige con dos
    // toques, sin tener que buscar antes un botón de quitar.
    function soltarEn(destinoId) {
        if (base.enMano !== "") {
            base.asignar(base.enMano, destinoId)
            return
        }
        if (!base.destinosUnicos)
            return
        var ocupante = base.elementoEn(destinoId)
        if (ocupante)
            base.enMano = String(ocupante.id)
    }

    function asignar(elementoId, destinoId) {
        var id = String(elementoId)
        var destino = String(destinoId)
        if (id === "" || destino === "")
            return

        var copia = {}
        for (var clave in base.asignaciones)
            copia[clave] = base.asignaciones[clave]

        if (base.destinosUnicos) {
            var ocupante = base.elementoEn(destino)
            if (ocupante && String(ocupante.id) !== id) {
                // Intercambio: si el elemento que llega venía de otro destino,
                // el desalojado ocupa ese hueco en vez de volver al montón.
                // Con una biyección —relacionar, ordenar— es lo que espera
                // quien mueve una ficha: las dos cambian de lugar.
                var origen = base.destinoDe(id)
                if (origen !== "")
                    copia[String(ocupante.id)] = origen
                else
                    delete copia[String(ocupante.id)]
            }
        }

        copia[id] = destino
        base.asignaciones = copia
        base.enMano = ""
        base.respuestaCambiada(base.respuestaActual())
    }

    function liberar(elementoId) {
        var id = String(elementoId)
        if (base.asignaciones[id] === undefined) {
            base.enMano = (base.enMano === id) ? "" : base.enMano
            return
        }
        var copia = {}
        for (var clave in base.asignaciones)
            copia[clave] = base.asignaciones[clave]
        delete copia[id]
        base.asignaciones = copia
        if (base.enMano === id)
            base.enMano = ""
        base.respuestaCambiada(base.respuestaActual())
    }

    // Tocar una ficha ya colocada: la devuelve al montón. Tocar una del montón:
    // la toma. Es la única acción que necesita la vista para ambos casos.
    function alternar(elementoId) {
        if (base.destinoDe(elementoId) !== "")
            base.liberar(elementoId)
        else
            base.tomar(elementoId)
    }

    function limpiar() {
        base.asignaciones = ({})
        base.enMano = ""
        base.respuestaCambiada(base.respuestaActual())
    }

    onPreguntaChanged: base.restaurar()
    Component.onCompleted: base.restaurar()
}
