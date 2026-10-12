.pragma library

// Espejo de VALUE_KINDS (viewmodel/module_laboratory_controller.py): qué
// representan los valores de un panel. Un tipo discreto no admite escala de
// color (sugeriría un orden o una magnitud que no existen) y se escribe como
// entero; uno continuo conserva sus decimales aunque caiga en un entero
// exacto, porque los decimales comunican que es una medida.
// Las posiciones son el siguiente candidato: añadir aquí "positions" a
// `discrete` y declararlo en el controlador.
var CONTINUOUS = "continuous"
var TOKEN_IDS = "token_ids"
var discrete = [TOKEN_IDS]

function of(panel) {
    return panel && panel.value_kind ? String(panel.value_kind) : CONTINUOUS
}

function isDiscrete(kind) {
    return discrete.indexOf(String(kind || CONTINUOUS)) >= 0
}

function isTokenIds(kind) {
    return String(kind || "") === TOKEN_IDS
}
