.pragma library
// Definiciones de la «Vista general» de los módulos 1, 2 y 4–8: una por cada
// paso de `_module_steps`, en inferencia y en entrenamiento. El módulo 3 conserva
// las suyas en ModuleOverviewScene.definitionFor. Aquí no hay números del modelo:
// la vista es conceptual y el cálculo vive en «Animación detallada».

var MODULES = {
    module_1: {
        location: "UBICACIÓN DENTRO DE LA ENTRADA AL TRANSFORMER",
        example: ["el", "gato", "duerme"],
        moments: [
            { label: "TEXTO", tone: "structure" },
            { label: "TOKENS", tone: "transform" },
            { label: "IDS", tone: "focus" },
            { label: "BATCH", tone: "result" }
        ]
    },
    module_2: {
        location: "UBICACIÓN DENTRO DE EMBEDDINGS Y POSICIÓN",
        example: ["gato", "ve", "otro", "gato"],
        moments: [
            { label: "EMBEDDING", tone: "structure" },
            { label: "ESCALA", tone: "transform" },
            { label: "POSICIÓN", tone: "focus" },
            { label: "ENTRADA LISTA", tone: "result" }
        ]
    },
    module_4: {
        location: "UBICACIÓN DENTRO DE MULTI-HEAD ATTENTION",
        example: ["ella", "pidió", "el", "libro"],
        moments: [
            { label: "PROYECCIÓN", tone: "structure" },
            { label: "CABEZAS", tone: "transform" },
            { label: "ATENCIÓN POR CABEZA", tone: "focus" },
            { label: "UNIÓN", tone: "result" }
        ]
    },
    module_5: {
        location: "UBICACIÓN DENTRO DEL ENCODER",
        example: ["el", "gato", "duerme"],
        moments: [
            { label: "ENTRADA", tone: "structure" },
            { label: "ATENCIÓN + NORMA", tone: "transform" },
            { label: "FEED FORWARD", tone: "focus" },
            { label: "PILA", tone: "result" }
        ]
    },
    module_6: {
        location: "UBICACIÓN DENTRO DEL DECODER",
        example: ["BOS", "el", "gato"],
        moments: [
            { label: "PREFIJO", tone: "structure" },
            { label: "ATENCIÓN CAUSAL", tone: "transform" },
            { label: "CROSS-ATTENTION", tone: "focus" },
            { label: "SALIDA", tone: "result" }
        ]
    },
    module_7: {
        location: "UBICACIÓN DENTRO DE LA GENERACIÓN DE LA SALIDA",
        example: ["perro", "gato", "pez"],
        moments: [
            { label: "ESTADO", tone: "structure" },
            { label: "LOGITS", tone: "transform" },
            { label: "FILTROS", tone: "focus" },
            { label: "TOKEN", tone: "result" }
        ]
    },
    module_8: {
        location: "UBICACIÓN DENTRO DEL TRANSFORMER COMPLETO",
        example: ["hola", "mundo"],
        moments: [
            { label: "ENTRADA", tone: "structure" },
            { label: "ENCODER", tone: "transform" },
            { label: "DECODER", tone: "focus" },
            { label: "SALIDA", tone: "result" }
        ]
    }
}

function moduleInfo(moduleId) {
    return MODULES[moduleId] || MODULES.module_1
}

function supports(moduleId) {
    return MODULES[moduleId] !== undefined
}

// Forma corta para que cada definición quepa de un vistazo. `e` da chips y tokens.
function stage(kind, phase, title, purpose, question, entra, pasa, sale, takeaway, extra) {
    var result = {
        kind: kind, phase: phase, title: title, purpose: purpose, question: question,
        inputTitle: entra[0], inputDetail: entra[1], inputItems: entra[2],
        actionTitle: pasa[0], actionDetail: pasa[1], visualLabel: pasa[2],
        outputTitle: sale[0], outputDetail: sale[1], outputItems: sale[2],
        takeaway: takeaway
    }
    for (var key in (extra || {}))
        result[key] = extra[key]
    return result
}

function backwardStage(phase, target, roles, reach, takeaway, e) {
    var chips = []
    var gradients = []
    for (var index = 0; index < roles.length; ++index) {
        chips.push(e.chip("g " + roles[index], "error"))
        gradients.push(roles[index])
    }
    return stage("gradient_back", phase, "Propagar la señal de error",
                 "Durante el entrenamiento, el error recorre " + target + " en sentido inverso.",
                 "¿A qué parámetros debe llegar la señal de error?",
                 ["Señal desde la pérdida", "Indica cuánto influyó esta parte en el error.", [e.chip("error", "error")]],
                 ["Volver por el recorrido", reach, "la señal regresa hacia lo que se aprende"],
                 ["Gradientes", "Describen qué ajuste convendría a cada parámetro.", chips],
                 takeaway, { learning: true, roles: gradients })
}

function updateStage(phase, roles, takeaway, e) {
    var before = []
    var after = []
    for (var index = 0; index < roles.length; ++index) {
        before.push(e.chip(roles[index], "input"))
        after.push(e.chip(roles[index] + "′", "result"))
    }
    return stage("update_params", phase, "Visualizar un ajuste de los parámetros",
                 "El laboratorio muestra cómo los gradientes orientarían un pequeño cambio.",
                 "¿Cómo cambiarían estos parámetros después de aprender del error?",
                 ["Parámetros + gradientes", "Cada parámetro recibe su propia señal.", before],
                 ["Aplicar un cambio hipotético", "Se ilustra la dirección del ajuste sin alterar el modelo.", "antes → pequeño ajuste → después"],
                 ["Parámetros simulados", "Representan cómo sería el siguiente estado.", after],
                 takeaway, { learning: true, roles: roles })
}

function definition(moduleId, stepId, e) {
    var table = { module_1: module1, module_2: module2, module_4: module4, module_5: module5,
                  module_6: module6, module_7: module7, module_8: module8 }
    var build = table[moduleId]
    return build ? build(String(stepId), e) : ({})
}

function module1(id, e) {
    if (id === "text") return stage("text_input", 0, "Recibir el texto tal como se escribió",
        "El modelo todavía no ve palabras ni números: sólo una cadena de caracteres.",
        "¿Qué tiene el modelo al comenzar?",
        ["Texto escrito", "Letras, espacios y signos, en orden.", [e.chip("«" + e.phrase + "»", "input")]],
        ["Tomar la cadena completa", "Todavía no se separa ni se convierte nada.", "caracteres en orden · aún sin significado para el modelo"],
        ["Texto listo para separar", "Es lo que recibirá el tokenizador.", [e.chip("cadena", "result")]],
        "Las capas neuronales no pueden calcular con letras: primero hay que convertirlas en números.")
    if (id === "tokens") return stage("tokenize", 1, "Separar el texto en tokens",
        "El vocabulario decide en qué piezas se corta la cadena; una palabra rara puede quedar en varias.",
        "¿En qué piezas se divide esta frase?",
        ["Una sola cadena", "Aún no tiene divisiones.", [e.chip("cadena", "input")]],
        ["Cortar según el vocabulario", "Cada pieza debe existir en el vocabulario.", "una cadena → una lista ordenada de tokens"],
        ["Tokens en orden", "El orden original se conserva.", e.tokenChips(true)],
        "Un token es la unidad con la que trabaja el modelo; no siempre coincide con una palabra.")
    if (id === "ids") return stage("vocab_lookup", 2, "Cambiar cada token por su número",
        "El vocabulario es una lista: el ID de un token es la fila donde está guardado.",
        "¿Qué número le toca a cada token?",
        ["Tokens", "Cada uno se busca en el vocabulario.", e.tokenChips(false)],
        ["Buscar en el vocabulario", "La misma pieza da siempre el mismo ID.", "token → fila del vocabulario → ID"],
        ["IDs enteros", "Son direcciones, no medidas.", [e.chip("7", "focus"), e.chip("15", "focus"), e.chip("23", "focus")]],
        "Un ID sólo identifica una fila: que 15 sea mayor que 7 no significa nada.", { focus: true })
    if (id === "specials") return stage("specials", 2, "Marcar el inicio y el fin de la salida",
        "BOS y EOS no vienen del texto. Se agregan a la frase de salida para saber dónde empieza y dónde termina.",
        "¿Por qué la secuencia de destino se divide en dos?",
        ["IDs del destino", "Los tokens de la respuesta esperada.", [e.chip("ids", "input")]],
        ["Agregar BOS y EOS, y desplazar", "El decoder recibe BOS + ids; el objetivo es ids + EOS.", "entrada del decoder ↓ objetivo: un token adelantado"],
        ["Entrada y objetivo", "Cada posición debe predecir el token siguiente.", [e.chip("BOS + ids", "result"), e.chip("ids + EOS", "focus")]],
        "La entrada del encoder se tokeniza sin BOS ni EOS: estos tokens sólo marcan la frase de destino.")
    if (id === "batch") {
        if (e.training) return stage("batch_pad", 3, "Igualar longitudes con PAD",
            "Varias frases se procesan juntas en una tabla, y una tabla necesita filas del mismo largo.",
            "¿Qué se hace con la frase más corta?",
            ["Frases de distinta longitud", "Cada una tiene sus propios IDs.", [e.chip("frase larga", "input"), e.chip("frase corta", "input")]],
            ["Rellenar con PAD al final", "PAD ocupa lugar, pero no aporta significado.", "filas iguales · la frase corta recibe relleno"],
            ["Matriz [B, T]", "B frases de T posiciones.", [e.chip("B × T", "result")]],
            "PAD no cambia lo que dice la frase; sólo permite formar una tabla rectangular.")
        return stage("batch_trim", 3, "Ajustar la frase al contexto máximo",
            "En inferencia suele haber una sola frase, sin PAD. Si supera el contexto admitido, se recorta.",
            "¿Qué pasa si la frase es más larga que el contexto?",
            ["Secuencia de IDs", "Puede tener cualquier longitud.", [e.chip("ids", "input")]],
            ["Recortar hasta T_max", "No se inventa contenido: sólo se quita lo que sobra.", "se conserva hasta T_max · lo demás queda fuera"],
            ["Secuencia admitida", "Lista para entrar al modelo.", [e.chip("T ≤ T_max", "result")]],
            "Si la frase ya cabe, este paso no cambia nada.")
    }
    if (id === "mask") return stage("pad_mask", 3, "Avisar qué posiciones son relleno",
        "La máscara es una lista de verdadero o falso, del mismo largo que la secuencia: dice qué columnas son reales.",
        "¿Qué posiciones debe ignorar la atención?",
        ["IDs del batch", "Algunos pueden ser PAD.", [e.chip("id", "input"), e.chip("PAD (ej.)", "error")]],
        ["Comparar cada ID con PAD", "Real → permitido; PAD → bloqueado.", "ejemplo: la última posición es relleno"],
        ["Máscara booleana", "La usarán las capas de atención.", [e.chip("True", "result"), e.chip("False", "error")]],
        "La máscara no borra datos: indica a la atención qué columnas no debe consultar.")
    return stage("no_grad", 3, "Comprobar qué parte aprende",
        "Tokenizar, rellenar y enmascarar son reglas fijas: no tienen parámetros que el entrenamiento pueda ajustar.",
        "¿Llega el gradiente hasta el tokenizador?",
        ["Batch preparado", "IDs y máscara.", [e.chip("batch", "input")]],
        ["Entregar los datos al modelo", "El aprendizaje empieza en la tabla de embeddings.", "el gradiente se detiene antes de los datos"],
        ["Entrada válida", "Sin parámetros aprendidos en este módulo.", [e.chip("0 parámetros", "result")]],
        "Aquí todo es preparación de datos: nada se aprende en esta etapa.")
}

function module2(id, e) {
    if (id === "lookup") return stage("embed_lookup", 0, "Buscar el vector de cada token",
        "El ID indica qué fila de la tabla de embeddings hay que copiar. Esa fila es un vector aprendido.",
        "¿De dónde sale el vector de «" + e.focused + "»?",
        ["Un ID", "La dirección de una fila.", [e.chip("ID de «" + e.focused + "»", "input")]],
        ["Copiar una fila de la tabla", "Filas |V|, columnas d_model.", "ID → fila resaltada → vector de d_model números"],
        ["Vector de embedding", "Sus números se aprenden al entrenar.", [e.chip("d_model números", "result")]],
        "El mismo token da siempre la misma fila: aquí todavía no importa su lugar en la frase.", { focus: true })
    if (id === "scale") return stage("scale_vector", 1, "Equilibrar la magnitud",
        "Todos los números del embedding se multiplican por √d_model para que su tamaño no quede por debajo de la señal de posición.",
        "¿Qué cambia y qué se conserva al escalar?",
        ["Embedding aprendido", "Valores más bien pequeños.", [e.chip("e", "input")]],
        ["Multiplicar por √d_model", "El mismo factor para cada componente.", "más grande · misma dirección · mismo número de componentes"],
        ["Embedding escalado", "Las proporciones se conservan.", [e.chip("e · √d_model", "result")]],
        "Escalar cambia el tamaño de los números, no cuál es mayor ni cuántos hay.")
    if (id === "position") return stage("pos_wave", 2, "Crear una señal para cada lugar",
        "Cada posición recibe un vector hecho con senos y cosenos de distinta frecuencia. No se aprende: se calcula.",
        "¿Cómo se distingue la posición 0 de la posición 3?",
        ["Índice de posición", "0, 1, 2, …", [e.chip("0", "input"), e.chip("1", "input"), e.chip("2", "input")]],
        ["Leer ondas en esa posición", "Cada componente usa otra frecuencia.", "cada línea vertical da el vector de una posición"],
        ["Vector PE", "Mismo ancho que el embedding.", [e.chip("PE", "focus")]],
        "La posición no se aprende en este modelo: la misma posición da siempre el mismo vector.")
    if (id === "sum") return stage("add_vector", 2, "Sumar significado y posición",
        "Como ambos vectores tienen d_model componentes, se suman uno a uno. El resultado guarda las dos señales.",
        "¿Por qué dos apariciones de «gato» ya no son iguales?",
        ["Dos vectores", "Embedding escalado y PE.", [e.chip("ẽ", "input"), e.chip("PE", "focus")]],
        ["Sumar componente a componente", "No se concatenan: el ancho no cambia.", "ẽ + PE = x · el ancho sigue siendo d_model"],
        ["Representación con posición", "Lista para el encoder.", [e.chip("x", "result")]],
        "Misma palabra en otro lugar: mismo embedding, distinta suma.", { firstLabel: "ẽ", secondLabel: "PE", resultLabel: "x" })
    if (id === "dropout") {
        if (e.training) return stage("dropout", 3, "Apagar algunas activaciones al azar",
            "Durante el entrenamiento, algunos números se vuelven cero para que el modelo no dependa de uno solo.",
            "¿Qué se apaga y por qué sólo al entrenar?",
            ["Representación x", "Con todas sus componentes.", [e.chip("x", "input")]],
            ["Anular componentes al azar", "Cambian en cada ejecución.", "ejemplo: las celdas tachadas valen 0"],
            ["x̃ con ruido", "Misma forma que x.", [e.chip("x̃", "result")]],
            "Dropout apaga números, no tokens completos: la frase sigue teniendo las mismas posiciones.", { droppedCells: true })
        return stage("dropout", 3, "Dejar pasar la representación",
            "En inferencia dropout está desactivado: la salida es igual a la entrada y el resultado es reproducible.",
            "¿Qué hace dropout durante inferencia?",
            ["Representación x", "Con todas sus componentes.", [e.chip("x", "input")]],
            ["Pasar sin cambios", "Ninguna componente se apaga.", "ninguna celda se apaga en inferencia"],
            ["Entrada del encoder", "Exactamente igual a x.", [e.chip("x̃ = x", "result")]],
            "Al usar el modelo no se añade ruido: el mismo texto da la misma entrada.", { droppedCells: false })
    }
    if (id === "embedding_gradient")
        return backwardStage(0, "la tabla de embeddings", ["E[id]"],
            "La señal llega sólo a las filas consultadas por el ejemplo.",
            "Una fila que no se usó no recibe señal directa en este ejemplo.", e)
    return updateStage(0, ["E"], "Esta vista no reentrena ni sobrescribe la tabla: sólo muestra el posible ajuste.", e)
}

function module4(id, e) {
    if (id === "project") return stage("project_joint", 0, "Proyectar Q, K y V completos",
        "Primero se calculan Q, K y V con todo su ancho. Una sola operación grande equivale a preparar todas las cabezas.",
        "¿Todavía hay cabezas en este punto?",
        ["Representación X", "Una fila por token.", [e.chip("X", "input")]],
        ["Tres proyecciones aprendidas", "WQ, WK y WV dan el mismo ancho d_model.", "X → Q, K y V de ancho d_model · aún sin separar"],
        ["Q, K y V conjuntos", "Listos para repartirse.", [e.chip("Q", "q"), e.chip("K", "k"), e.chip("V", "v")]],
        "Las cabezas aparecen en el siguiente paso; aquí sólo hay tres matrices anchas.")
    if (id === "split") return stage("split_heads", 1, "Repartir el ancho entre las cabezas",
        "El ancho d_model se divide en h bloques iguales. Cada cabeza trabaja con su bloque de d_head componentes.",
        "¿Qué se reparte: los tokens o las componentes?",
        ["Q, K y V completos", "Ancho d_model.", [e.chip("d_model", "input")]],
        ["Reorganizar el último eje", "No se copia ni se calcula nada nuevo.", "d_model = h × d_head · los tokens no se cortan"],
        ["h bloques", "Uno por cabeza.", [e.chip("cabeza 1", "focus"), e.chip("cabeza 2", "focus")]],
        "Cada cabeza ve los mismos tokens, pero con otra porción de las componentes.")
    if (id === "maps") return stage("head_maps", 2, "Cada cabeza calcula su propio mapa",
        "Cada cabeza repite Self-Attention por su cuenta: compara, escala y aplica softmax en su bloque.",
        "¿Por qué los mapas pueden ser distintos?",
        ["Q y K de cada cabeza", "Bloques distintos.", [e.chip("Q₁ K₁", "q"), e.chip("Q₂ K₂", "k")]],
        ["Atención en paralelo", "Ninguna cabeza consulta a las otras.", "ejemplo: la cabeza " + (e.head + 1) + " está seleccionada"],
        ["Un mapa T×T por cabeza", "Cada fila suma 1.", [e.chip("A₁", "result"), e.chip("A₂", "result")]],
        "Distintos subespacios pueden fijarse en relaciones distintas, aunque no siempre tienen una función humana clara.")
    if (id === "contexts") return stage("head_contexts", 2, "Mezclar los Values de cada cabeza",
        "Cada mapa multiplica los Values de su misma cabeza y produce un contexto por token.",
        "¿Con qué Values se mezcla cada mapa?",
        ["Mapa y Values", "De la misma cabeza.", [e.chip("A_h", "focus"), e.chip("V_h", "v")]],
        ["Calcular A_h · V_h", "Suma ponderada dentro de la cabeza.", "cada cabeza produce su contexto de ancho d_head"],
        ["Contextos C_h", "Todavía separados.", [e.chip("C₁", "result"), e.chip("C₂", "result")]],
        "Cada cabeza produce un contexto más angosto: aún hay que juntarlos.")
    if (id === "concat") return stage("concat_heads", 3, "Colocar los contextos uno junto a otro",
        "Los h contextos se ponen lado a lado por token y se recupera el ancho original.",
        "¿Se calcula algo nuevo al concatenar?",
        ["Contextos por cabeza", "h bloques de d_head.", [e.chip("C₁", "input"), e.chip("C₂", "input")]],
        ["Concatenar", "Se ordenan: todavía no se mezclan.", "h bloques → un vector de ancho d_model"],
        ["Vector concatenado", "Ancho d_model.", [e.chip("C", "result")]],
        "Concatenar sólo acomoda: cada bloque sigue siendo el de su cabeza.")
    if (id === "wo") return stage("wo_mix", 3, "Mezclar lo que encontró cada cabeza",
        "WO es una matriz aprendida. Hace que cada componente de la salida combine información de todas las cabezas.",
        "¿Qué aporta WO que la concatenación no hacía?",
        ["Vector concatenado", "Bloques todavía separados.", [e.chip("C", "input")]],
        ["Multiplicar por WO", "Aprende cómo combinar las cabezas.", "todas las cabezas alimentan cada salida · el ancho no cambia"],
        ["Salida multi-head", "Forma [B, T, d_model].", [e.chip("Y", "result")]],
        "WO no es un promedio fijo: aprende la mezcla, y la salida puede sumarse al residual.")
    if (id === "backward")
        return backwardStage(3, "Multi-Head Attention", ["WQ", "WK", "WV", "WO"],
            "La señal alcanza las proyecciones y la mezcla final.",
            "Backward calcula señales de cambio; todavía no modifica los pesos del modelo.", e)
    return updateStage(3, ["WQ", "WK", "WV", "WO"], "Esta vista no reentrena: sólo explica el posible ajuste.", e)
}

function module5(id, e) {
    if (id === "encoder_input") return stage("layer_input", 0, "Entrar a la capa seleccionada",
        "La primera capa recibe los embeddings con posición; las siguientes reciben la salida de la anterior.",
        "¿De dónde viene lo que entra a esta capa?",
        ["Representaciones", "Una fila por token.", e.tokenChips(false)],
        ["Pasar a la capa l", "La forma no cambia al entrar.", "capa anterior → capa seleccionada"],
        ["X_l", "Forma [T, d_model].", [e.chip("X_l", "result")]],
        "Todas las capas reciben y entregan la misma forma: por eso pueden apilarse.")
    if (id === "encoder_attention") return stage("mini_attention", 1, "Consultar toda la frase",
        "Cada token puede atender a todos los tokens de la fuente, también a los posteriores. Sólo se excluye PAD.",
        "¿A qué tokens puede atender «" + e.focused + "»?",
        ["X_l", "Es a la vez Q, K y V.", [e.chip("X_l", "input")]],
        ["Multi-Head Self-Attention", "Sin máscara causal en el encoder.", "flecha más gruesa = mayor peso"],
        ["Actualización contextual", "Mismo ancho que X_l.", [e.chip("MHA(X_l)", "result")]],
        "En el encoder la frase completa ya se conoce: no hay futuro que ocultar.", { focus: true })
    if (id === "residual_1") return stage("residual", 1, "Sumar lo nuevo a lo que ya había",
        "La entrada toma un atajo alrededor de la atención y se suma a la actualización, componente por componente.",
        "¿Qué pasa si la atención aporta muy poco?",
        ["X_l y su actualización", "Mismo ancho.", [e.chip("X_l", "input"), e.chip("MHA", "focus")]],
        ["Suma residual", "Se suma; no se concatena.", "el atajo conserva la entrada"],
        ["R₁", "Original + contexto.", [e.chip("R₁", "result")]],
        "El atajo garantiza que la información original siga presente y facilita que llegue el gradiente.",
        { pathLabel: "MHA", startLabel: "X", endLabel: "R₁" })
    if (id === "norm_1") return stage("layernorm", 1, "Estabilizar los números de cada token",
        "LayerNorm centra y reescala las componentes de cada token por separado, y luego aplica γ y β aprendidos.",
        "¿Sobre qué se calcula la media: filas o columnas?",
        ["R₁", "Valores de tamaños dispares.", [e.chip("R₁", "input")]],
        ["Normalizar por token", "Media cerca de 0 y varianza cerca de 1, antes de γ y β.", "misma forma · magnitudes más parejas"],
        ["N₁", "Lista para la FFN.", [e.chip("N₁", "result")]],
        "Normalizar no cambia cuántos tokens hay ni su orden, sólo mantiene los números en un rango manejable.")
    if (id === "ffn_expand") return stage("ffn_expand", 2, "Abrir más espacio para cada token",
        "Cada token pasa, por separado, de d_model a d_ff componentes con los mismos parámetros.",
        "¿Qué crece: las filas o las columnas?",
        ["N₁", "Ancho d_model.", [e.chip("d_model", "input")]],
        ["Proyección W₁", "Se aplica a cada posición de forma independiente.", "más columnas · el mismo número de filas"],
        ["H", "Ancho d_ff.", [e.chip("d_ff", "result")]],
        "Más columnas significan más espacio para combinar rasgos; los tokens no se mezclan entre sí aquí.")
    if (id === "ffn_activation") return stage("ffn_activation", 2, "Doblar la transformación",
        "La activación se aplica a cada número. Sin ella, encadenar proyecciones equivaldría a una sola proyección lineal.",
        "¿Qué aporta la activación que no da la proyección?",
        ["H", "Valores positivos y negativos.", [e.chip("H", "input")]],
        ["Aplicar φ elemento a elemento", "Con ReLU, lo negativo se vuelve 0.", "ejemplo con ReLU: lo negativo queda en 0"],
        ["A", "Misma forma que H.", [e.chip("A", "result")]],
        "La no linealidad permite aprender relaciones que una sola recta no puede expresar.")
    if (id === "ffn_project") return stage("ffn_project", 2, "Volver al ancho original",
        "W₂ comprime de d_ff a d_model para que el resultado pueda sumarse a la entrada de esta subcapa.",
        "¿Por qué hay que regresar a d_model?",
        ["A", "Ancho d_ff.", [e.chip("d_ff", "input")]],
        ["Proyección W₂", "Otra vez por posición.", "menos columnas · el mismo número de filas"],
        ["F", "Ancho d_model.", [e.chip("d_model", "result")]],
        "Sin este regreso, el segundo residual no podría sumar vectores de distinto ancho.")
    if (id === "norm_2") return stage("residual", 2, "Segundo Add & Norm",
        "Se repite el mismo cierre: sumar el atajo y normalizar. Sale lo que recibirá la siguiente capa.",
        "¿Qué forma tiene lo que sale de la capa?",
        ["N₁ y F", "Mismo ancho.", [e.chip("N₁", "input"), e.chip("F", "focus")]],
        ["Sumar y normalizar", "Atajo alrededor de la FFN, y LayerNorm.", "el atajo rodea a la FFN"],
        ["X_{l+1}", "Forma [T, d_model].", [e.chip("X_{l+1}", "result")]],
        "Una capa completa entrega la misma forma que recibió.",
        { pathLabel: "FFN", startLabel: "N₁", endLabel: "X⁺" })
    if (id === "stack") return stage("layer_stack", 3, "Repetir la capa N veces",
        "La misma estructura se repite con parámetros propios. La salida de la última capa es la memoria.",
        "¿Comparten parámetros las capas?",
        ["Salida de una capa", "Entra a la siguiente.", [e.chip("X_l", "input")]],
        ["Encadenar N capas", "Misma estructura, distintos parámetros.", "cada capa refina lo anterior"],
        ["Memoria del encoder", "La consultará el decoder.", [e.chip("Memoria", "result")]],
        "La memoria conserva un vector por token de la fuente: el número de posiciones no se reduce.", { layerLabel: "Capa", outLabel: "Memoria" })
    if (id === "backward")
        return backwardStage(3, "la capa del encoder", ["MHA", "FFN", "γ, β"],
            "La señal alcanza atención, FFN y LayerNorm.",
            "Backward calcula señales de cambio; todavía no modifica los pesos del modelo.", e)
    return updateStage(3, ["MHA", "FFN", "γ, β"], "El cambio se calcula y se deja sin aplicar al modelo.", e)
}

function module6(id, e) {
    if (id === "decoder_prefix") {
        if (e.training) return stage("shift_target", 0, "Dar la respuesta desplazada",
            "Al entrenar se conoce la respuesta: el decoder la recibe corrida un lugar y debe predecir el token siguiente.",
            "¿Qué token debe predecir cada posición?",
            ["Objetivo conocido", "La frase correcta.", [e.chip("objetivo", "input")]],
            ["Teacher forcing", "BOS va primero; EOS queda como última etiqueta.", "cada entrada debe predecir el token de abajo"],
            ["Entrada del decoder", "Con BOS al inicio.", [e.chip("BOS + …", "result")]],
            "Sin el desplazamiento, cada posición recibiría justo el token que debe predecir.")
        return stage("grow_prefix", 0, "Usar lo que ya se generó",
            "Al generar no hay respuesta conocida: el decoder sólo dispone de BOS y de los tokens ya elegidos.",
            "¿Qué recibe el decoder en cada paso?",
            ["Salida parcial", "Empieza con BOS.", [e.chip("BOS", "input")]],
            ["Formar el prefijo", "Crece un token por paso.", "el prefijo crece paso a paso"],
            ["Entrada del decoder", "Sólo tokens ya conocidos.", [e.chip("prefijo", "result")]],
            "Cada paso repite el decoder con un prefijo un token más largo.")
    }
    if (id === "decoder_embedding") return stage("add_vector", 0, "Convertir el prefijo en vectores",
        "Igual que la fuente: cada ID obtiene su embedding y se le suma la posición, aunque la tabla es del destino.",
        "¿Por qué el prefijo también necesita posición?",
        ["IDs del prefijo", "Enteros.", [e.chip("IDs", "input")]],
        ["Embedding + posición", "Misma suma que en la entrada del encoder.", "E_out + PE = Z₀"],
        ["Z₀", "Forma [T_tgt, d_model].", [e.chip("Z₀", "result")]],
        "Sin posición, el decoder no sabría en qué lugar del prefijo va.", { firstLabel: "E", secondLabel: "PE", resultLabel: "Z₀" })
    if (id === "causal_mask") return stage("causal_triangle", 1, e.causal ? "Bloquear el futuro" : "Comparar sin la máscara",
        e.causal ? "Cada posición sólo puede ver su lugar y los anteriores: por eso queda un triángulo."
                 : "Sin máscara se vería el futuro. Sirve como contraste; un modelo real no puede generar así.",
        "¿Qué celdas puede usar la fila seleccionada?",
        ["Longitud del prefijo", "T_tgt posiciones.", [e.chip("T × T", "input")]],
        ["Permitir sólo j ≤ i", "La diagonal y lo que está a su izquierda.", e.causal ? "cada fila ve hasta su propia posición" : "contraste: todas las celdas quedan disponibles"],
        ["Máscara triangular", "La usará la atención.", [e.chip("visible", "result"), e.chip("futuro", "error")]],
        "Al generar, el futuro todavía no existe: la máscara hace que entrenar se parezca a generar.", { focus: true })
    if (id === "masked_attention") return stage("mini_attention", 1, "Atender sólo a lo anterior",
        "Es Self-Attention sobre el prefijo, pero las posiciones futuras reciben peso cero.",
        "¿A qué tokens puede atender «" + e.focused + "»?",
        ["Z y la máscara", "Q, K y V vienen del prefijo.", [e.chip("Z", "input"), e.chip("M", "error")]],
        ["Masked self-attention", "Lo futuro queda fuera.", e.causal ? "sólo hay flechas hacia atrás" : "contraste sin máscara: también aparecen flechas al futuro"],
        ["Contexto causal", "Una fila por posición.", [e.chip("A_self", "result")]],
        "Una posición nunca usa tokens que aún no se han generado.", { focus: true, causalArcs: true })
    if (id === "decoder_residual_1") return stage("residual", 1, "Primer Add & Norm",
        "El estado previo toma un atajo y se suma al contexto causal; después se normaliza.",
        "¿Qué conserva el atajo?",
        ["Z y contexto", "Mismo ancho.", [e.chip("Z", "input"), e.chip("A_self", "focus")]],
        ["Sumar y normalizar", "Igual que en el encoder.", "el atajo rodea la atención causal"],
        ["N₁", "Pasa a cross-attention.", [e.chip("N₁", "result")]],
        "Los residuales repiten la misma idea en las tres subcapas del decoder.",
        { pathLabel: "A_self", startLabel: "Z", endLabel: "N₁" })
    if (id === "cross_attention") return stage("cross_attention", 2, "Consultar la frase de origen",
        "Aquí se conectan las dos partes: las Queries salen del decoder; las Keys y los Values, de la memoria del encoder.",
        "¿De dónde sale cada uno: Q, K y V?",
        ["N₁ y memoria", "Dos secuencias de largos distintos.", [e.chip("Q: N₁", "q"), e.chip("K, V: memoria", "k")]],
        ["Cross-attention", "Sin máscara causal: la fuente ya se conoce.", "filas del decoder · columnas de la fuente"],
        ["Contexto de la fuente", "Una fila por posición del decoder.", [e.chip("A_cross", "result")]],
        "El mapa es T_tgt × T_src, y puede no ser cuadrado: comparar dos frases distintas es la novedad del decoder.", { focus: true })
    if (id === "decoder_residual_2") return stage("residual", 2, "Segundo Add & Norm",
        "El contexto recuperado de la fuente se suma al estado del decoder.",
        "¿Qué entra al atajo y qué se suma?",
        ["N₁ y contexto de la fuente", "Mismo ancho.", [e.chip("N₁", "input"), e.chip("A_cross", "focus")]],
        ["Sumar y normalizar", "Integra lo recuperado.", "el atajo rodea a cross-attention"],
        ["N₂", "Pasa a la FFN.", [e.chip("N₂", "result")]],
        "Ahora el estado reúne prefijo y fuente.",
        { pathLabel: "A_cross", startLabel: "N₁", endLabel: "N₂" })
    if (id === "decoder_ffn") return stage("ffn_block", 3, "Procesar cada posición",
        "La misma FFN del encoder: expande, activa y comprime cada posición por separado.",
        "¿Se mezclan posiciones en la FFN?",
        ["N₂", "Ancho d_model.", [e.chip("N₂", "input")]],
        ["Expandir, activar y comprimir", "Por posición, con parámetros compartidos.", "d_model → d_ff → d_model"],
        ["F", "Ancho d_model.", [e.chip("F", "result")]],
        "La mezcla entre posiciones ocurrió en la atención; aquí cada una se transforma sola.")
    if (id === "decoder_output") return stage("residual", 3, "Tercer Add & Norm",
        "El último atajo cierra la capa, y lo que sale avanza a la siguiente capa del decoder.",
        "¿Cuántas sumas residuales tiene una capa del decoder?",
        ["N₂ y F", "Mismo ancho.", [e.chip("N₂", "input"), e.chip("F", "focus")]],
        ["Sumar y normalizar", "Tercera y última subcapa.", "el atajo rodea a la FFN"],
        ["Salida de la capa", "Forma [T_tgt, d_model].", [e.chip("Z_{l+1}", "result")]],
        "Tres subcapas, tres residuales: una más que el encoder.",
        { pathLabel: "FFN", startLabel: "N₂", endLabel: "Z⁺" })
    if (id === "decoder_layers") return stage("layer_stack", 3, "Repetir la capa del decoder",
        "Cada capa refina el estado consultando de nuevo el prefijo y la misma memoria del encoder.",
        "¿Cambia la memoria de una capa a otra?",
        ["Salida de una capa", "Entra a la siguiente.", [e.chip("Z_l", "input")]],
        ["Encadenar N capas", "Todas usan la misma memoria.", "cada capa consulta la misma memoria"],
        ["Estado final", "Pasa a la capa de salida.", [e.chip("Z_N", "result")]],
        "Todavía no son palabras: falta proyectar al vocabulario.", { layerLabel: "Capa", outLabel: "Estado", sideLabel: "Memoria" })
    if (id === "backward")
        return backwardStage(3, "el decoder", ["FFN", "Cross", "Self"],
            "La señal alcanza las tres subcapas.",
            "Backward calcula señales de cambio; todavía no modifica los pesos del modelo.", e)
    return updateStage(3, ["θ decoder"], "El laboratorio no altera el modelo activo: sólo muestra el posible ajuste.", e)
}

function module7(id, e) {
    if (id === "hidden") return stage("hidden_row", 0, "Tomar el estado de la posición",
        e.training ? "Al entrenar, cada posición predice su token. Aquí se sigue una de ellas."
                   : "Para generar sólo importa la última fila: es la que predice el siguiente token.",
        "¿Qué fila del decoder se usa?",
        ["Salida del decoder", "Una fila por posición.", [e.chip("[T, d_model]", "input")]],
        ["Elegir una fila", "Las demás no se usan en esta predicción.", "la fila resaltada resume lo disponible"],
        ["h_t", "Un vector de d_model números.", [e.chip("h_t", "result")]],
        "h_t todavía no habla de palabras: es un vector interno del modelo.")
    if (id === "linear") return stage("linear_bars", 1, "Dar un puntaje a cada palabra",
        "Una capa lineal convierte h_t en un número para cada token del vocabulario. Esos números son los logits.",
        "¿Cuántos logits se producen?",
        ["h_t", "d_model números.", [e.chip("h_t", "input")]],
        ["Multiplicar por W_vocab", "Una columna por token del vocabulario.", "un puntaje por token · pueden ser negativos"],
        ["Logits", "Uno por token de |V|.", [e.chip("z", "focus")]],
        "Un logit no es una probabilidad: puede ser negativo y los logits no suman 1.", { candidates: true })
    if (id === "temperature") return stage("temperature", 2, "Ajustar qué tan decidido es el modelo",
        "Todos los logits se dividen entre T. Una T baja separa más al favorito; una T alta acerca a todos.",
        "¿Cambia el orden de los candidatos?",
        ["Logits", "Sin ajustar.", [e.chip("z", "input")]],
        ["Dividir entre T", "T es un control, no un parámetro aprendido.", "T baja concentra · T alta reparte"],
        ["Logits ajustados", "Mismo orden.", [e.chip("z / T", "result")]],
        "La temperatura no cambia quién va primero: cambia la distancia entre candidatos.", { candidates: true })
    if (id === "top_k") return stage("top_k", 2, "Quedarse con los K mejores",
        "Se conservan los K logits mayores; los demás quedan fuera antes de normalizar.",
        "¿Cuántos candidatos sobreviven?",
        ["Logits ajustados", "Todo el vocabulario.", [e.chip("todos", "input")]],
        ["Filtrar por ranking", "El número de supervivientes es fijo.", "las barras tachadas quedan fuera"],
        ["K candidatos", "El resto no se puede elegir.", [e.chip("Top-K", "result")]],
        "Top-K fija cuántos quedan, sin mirar cuánta probabilidad reúnen.", { candidates: true })
    if (id === "top_p") return stage("top_p", 2, "Quedarse con los que suman P",
        "Los candidatos se ordenan y se acumula su probabilidad hasta alcanzar P. Los necesarios para llegar forman el núcleo.",
        "¿Por qué cambia cuántos sobreviven?",
        ["Candidatos Top-K", "Ordenados de mayor a menor.", [e.chip("candidatos", "input")]],
        ["Acumular hasta P", "El tamaño depende de la distribución.", "la línea acumula hasta cruzar P"],
        ["Núcleo Top-P", "Tamaño dinámico.", [e.chip("núcleo", "result")]],
        "Si el favorito ya reúne casi toda la masa, el núcleo puede quedar de un solo token.", { candidates: true })
    if (id === "softmax") return stage("softmax_bars", 3, "Convertir puntajes en probabilidades",
        "Softmax hace positivos a los logits supervivientes y los normaliza para que sumen 1.",
        "¿Cuánto suman las barras al final?",
        ["Logits filtrados", "Sólo los supervivientes.", [e.chip("z filtrado", "input")]],
        ["Aplicar softmax", "Lo filtrado queda con probabilidad 0.", "ahora las barras suman 100 %"],
        ["Distribución p", "Una probabilidad por candidato.", [e.chip("p", "result")]],
        "Sólo ahora los números se pueden leer como probabilidades.", { candidates: true })
    if (id === "select") return stage("select_pick", 3, "Elegir el siguiente token",
        "El laboratorio elige el candidato más probable, para que el resultado se pueda repetir.",
        "¿Qué token se escribe?",
        ["Distribución p", "Una probabilidad por candidato.", [e.chip("p", "input")]],
        ["Tomar el mayor (argmax)", "Otras reglas sortean según p.", "se escribe el candidato más alto"],
        ["Siguiente token", "Uno solo.", [e.chip("ŷ_t", "result")]],
        "El modelo da una distribución; la regla de selección decide qué se escribe.", { candidates: true })
    if (id === "feedback") return stage("feedback_loop", 3, "Volver a empezar con un token más",
        "El token elegido se agrega al prefijo y regresa al decoder, hasta que aparece EOS o se llega al límite.",
        "¿Qué vuelve a entrar al decoder?",
        ["Token elegido", "Recién generado.", [e.chip("ŷ_t", "input")]],
        ["Agregar al prefijo", "La memoria del encoder se reutiliza.", "el prefijo crece y el ciclo se repite"],
        ["Prefijo ampliado", "Un token más largo.", [e.chip("prefijo + ŷ_t", "result")]],
        "Generar una frase es repetir este ciclo: un token por vuelta.")
    if (id === "target") return stage("target_label", 2, "Mirar la respuesta correcta",
        "Al entrenar se conoce qué token iba en esta posición: es el objetivo, y viene de la frase desplazada.",
        "¿Cuál es la respuesta esperada?",
        ["Objetivo del batch", "La frase correcta.", [e.chip("objetivo", "input")]],
        ["Tomar el token de esta posición", "Es un ID, no una distribución.", "el objetivo señala una sola barra"],
        ["ID correcto", "Se comparará con los logits.", [e.chip("y_t", "focus")]],
        "Al entrenar no se elige ni se filtra: se compara con la respuesta conocida.", { candidates: true })
    if (id === "loss") return stage("loss_curve", 3, "Medir qué tan mal salió",
        "La pérdida mira sólo la probabilidad del token correcto: cuanto más cerca de 1, menor error.",
        "¿Qué pasa con la pérdida si la probabilidad correcta baja?",
        ["Logits y objetivo", "Sin Top-K, Top-P ni muestreo.", [e.chip("z", "input"), e.chip("y_t", "focus")]],
        ["Calcular −log p(y_t)", "Se aplica softmax a los logits crudos.", "más probabilidad correcta → menos pérdida"],
        ["Pérdida L_t", "Un solo número.", [e.chip("L_t", "error")]],
        "La pérdida resume el error en un número; de ahí parte el aprendizaje.")
    if (id === "backward")
        return backwardStage(3, "la capa de salida", ["W_vocab"],
            "La señal llega a la proyección al vocabulario.",
            "El gradiente indica cómo subir la probabilidad correcta; todavía no cambia nada.", e)
    return updateStage(3, ["W_vocab"], "Se enseña el cambio de SGD sin aplicarlo al modelo.", e)
}

function module8(id, e) {
    var flow = function(active) { return { flowActive: active } }
    if (id === "full_tokens") return stage("vocab_lookup", 0, "Del texto a los IDs",
        "Es el recorrido del módulo 1: el texto se separa en tokens y cada uno se cambia por su fila del vocabulario.",
        "¿Qué recibe el modelo como entrada?",
        ["Texto", "Lo que escribe el usuario.", [e.chip("texto", "input")]],
        ["Tokenizar y consultar", "Se obtienen enteros.", "token → fila del vocabulario → ID"],
        ["IDs", "Forma [1, T_src].", [e.chip("IDs", "result")]],
        "Aquí empieza todo: a partir de este punto el modelo sólo ve números.", flow(0))
    if (id === "full_batch") return stage("batch_pad", 0, "Preparar el batch de entrenamiento",
        "Se arman fuente, entrada desplazada, objetivo y máscaras. PAD iguala longitudes dentro del batch.",
        "¿Qué tensores se necesitan para entrenar?",
        ["Pares de frases", "Fuente y destino.", [e.chip("fuente", "input"), e.chip("destino", "input")]],
        ["Tokenizar, rellenar y desplazar", "También se calculan las máscaras.", "filas iguales · la frase corta recibe relleno"],
        ["Tensores discretos", "Listos para el modelo.", [e.chip("src", "result"), e.chip("tgt", "result"), e.chip("M", "error")]],
        "El objetivo es la misma frase de destino, corrida un lugar.", flow(0))
    if (id === "full_embedding") return stage("add_vector", 0, "De IDs a vectores con orden",
        "Es el recorrido del módulo 2: embedding escalado más la señal de posición.",
        "¿Qué dos señales lleva cada vector?",
        ["IDs", "Enteros.", [e.chip("IDs", "input")]],
        ["Embedding + posición", "Misma forma para sumarlas.", "E·√d + PE = X"],
        ["X", "Forma [B, T, d_model].", [e.chip("X", "result")]],
        "Desde aquí, el tercer eje es d_model en casi todo el recorrido.",
        { firstLabel: "E·√d", secondLabel: "PE", resultLabel: "X", flowActive: 0 })
    if (id === "full_encoder") return stage("layer_stack", 1, "Contextualizar la fuente",
        "Los módulos 3, 4 y 5 ocurren aquí: atención, FFN y residuales, repetidos N veces.",
        "¿Cuántas veces se ejecuta el encoder al generar?",
        ["X", "Un vector por token.", [e.chip("X", "input")]],
        ["N capas de encoder", "Cada una con su atención y FFN.", "la forma no cambia a lo largo de la pila"],
        ["Memoria", "Forma [B, T_src, d_model].", [e.chip("Memoria", "result")]],
        "Al generar, el encoder corre una sola vez y su memoria se reutiliza.", { layerLabel: "Encoder", outLabel: "Memoria", flowActive: 1 })
    if (id === "full_decoder") return stage("cross_attention", 2, "Consultar el prefijo y la memoria",
        "Es el módulo 6: el decoder atiende a su prefijo sin ver el futuro, y consulta la memoria de la fuente.",
        "¿Qué dos cosas consulta el decoder?",
        ["Prefijo y memoria", "Dos secuencias.", [e.chip("prefijo", "input"), e.chip("Memoria", "k")]],
        ["N capas de decoder", "Máscara causal y cross-attention.", "filas del decoder · columnas de la fuente"],
        ["Estado", "Una fila por posición del decoder.", [e.chip("H", "result")]],
        "Sigue sin haber palabras: el estado aún es un vector de ancho d_model.", { focus: true, flowActive: 2 })
    if (id === "full_logits") return stage("linear_bars", 3, "Puntuar todo el vocabulario",
        "Es el inicio del módulo 7: la capa lineal da un logit a cada token posible.",
        "¿Cómo cambia el último eje?",
        ["Estado", "Ancho d_model.", [e.chip("d_model", "input")]],
        ["Proyección W_vocab", "El último eje pasa a |V|.", "un puntaje por token · pueden ser negativos"],
        ["Logits", "Último eje |V|.", [e.chip("|V|", "focus")]],
        "B y T siguen iguales: sólo cambia el significado del último eje.", { candidates: true, flowActive: 3 })
    if (id === "full_filters") return stage("top_k", 3, "Aplicar temperatura y filtros",
        "Se dividen los logits entre T, y Top-K y Top-P reducen los candidatos. Sólo se aplica al generar.",
        "¿Qué candidatos siguen en juego?",
        ["Logits", "Todo el vocabulario.", [e.chip("z", "input")]],
        ["z/T → Top-K → Top-P", "Reglas de generación, no capas aprendidas.", "las barras tachadas quedan fuera"],
        ["Logits filtrados", "Pocos candidatos.", [e.chip("filtrados", "result")]],
        "Estas reglas no se aprenden y no participan en la pérdida.", { candidates: true, flowActive: 3 })
    if (id === "full_select") return stage("select_pick", 3, "Elegir el token",
        "Softmax convierte los supervivientes en probabilidades y se toma el mayor.",
        "¿Qué token se escribe?",
        ["Distribución", "Suma 1.", [e.chip("p", "input")]],
        ["Tomar el mayor", "Selección reproducible.", "se escribe el candidato más alto"],
        ["Siguiente token", "Uno solo.", [e.chip("ŷ_t", "result")]],
        "Una vuelta completa produce un solo token.", { candidates: true, flowActive: 3 })
    if (id === "full_feedback") return stage("feedback_loop", 3, "Cerrar el ciclo",
        "El token vuelve al decoder como parte del prefijo; la memoria del encoder no se recalcula.",
        "¿Qué se reutiliza y qué cambia?",
        ["Token elegido", "Recién generado.", [e.chip("ŷ_t", "input")]],
        ["Agregar al prefijo", "El ciclo sigue hasta EOS o el límite.", "el prefijo crece · la memoria se reutiliza"],
        ["Nuevo prefijo", "Un token más largo.", [e.chip("prefijo", "result")]],
        "Se repite el decoder y la salida; la fuente no vuelve a procesarse.", { flowActive: 3 })
    if (id === "full_loss") return stage("loss_curve", 3, "Medir el error de todo el batch",
        "Cross-entropy compara los logits de cada posición válida con su objetivo. PAD no cuenta.",
        "¿Qué posiciones cuentan en la pérdida?",
        ["Logits y objetivo", "Sin filtros.", [e.chip("Z", "input"), e.chip("tgt_out", "focus")]],
        ["Calcular cross-entropy", "Promedia las posiciones válidas.", "más probabilidad correcta → menos pérdida"],
        ["Pérdida L", "Un solo número.", [e.chip("L", "error")]],
        "Un solo número resume el error y de él parte el aprendizaje.", { flowActive: 3 })
    if (id === "full_backward")
        return backwardStage(3, "todo el Transformer", ["Salida", "Decoder", "Encoder", "Emb."],
            "La señal cruza salida, decoder, encoder y embeddings.",
            "La señal llega hasta los embeddings, cruzando la memoria que conecta ambas partes.", e)
    return updateStage(3, ["θ"], "Se calcula un cambio representativo sin ejecutar un optimizador.", e)
}
