"""
Controlador de Teoría Contextual (CU17).

A diferencia de los demás controladores, no hace nada asíncrono — es
una simple consulta de contenido estático por id de componente. La
Vista lo llama cuando el usuario hace click en una pieza del diagrama
de flujo (ej. los bloques de `FlujoPaso` en `TrainingScreen.qml`:
"Atención", "FFN", "Softmax", etc.) para mostrar una tarjeta explicativa.

Los ids esperados están pensados para coincidir con los nombres que ya
aparecen en los `flowModel`/`model` de las pantallas existentes,
normalizados a snake_case sin acentos (ver `CONTENIDO_TEORIA` abajo).
Si un id no está en el diccionario, `obtenerTeoria` devuelve un
contenido "no disponible" en vez de lanzar un error — así la Vista
nunca se rompe por un id que todavía no tiene teoría escrita.
"""

from PySide6.QtCore import QObject, Slot

CONTENIDO_TEORIA: dict[str, dict[str, str]] = {
    "tokens": {
        "titulo": "Tokenización",
        "descripcion": (
            "Antes de que el modelo pueda procesar texto, hay que convertirlo en "
            "números. El tokenizador parte el texto en fragmentos (tokens) — no "
            "siempre palabras completas, a veces trozos de palabra — y le asigna "
            "a cada uno un id numérico según su vocabulario."
        ),
    },
    "embeddings": {
        "titulo": "Embeddings",
        "descripcion": (
            "Cada id de token se transforma en un vector de números (el "
            "'embedding'), aprendido durante el entrenamiento. Tokens con "
            "significado parecido terminan con vectores parecidos — es la forma "
            "en que el modelo representa el significado de las palabras "
            "internamente, en vez de solo verlas como ids sueltos."
        ),
    },
    "codificacion_posicional": {
        "titulo": "Codificación Posicional",
        "descripcion": (
            "La atención, por sí sola, no distingue el orden de los tokens — "
            "trataría 'el perro come' igual que 'come el perro'. La codificación "
            "posicional le suma a cada embedding un patrón de senos y cosenos que "
            "depende de la posición, así el modelo sabe dónde está cada token "
            "dentro de la secuencia."
        ),
    },
    "atencion": {
        "titulo": "Multi-Head Attention (Self-Attention)",
        "descripcion": (
            "Cada token 'mira' a los demás tokens de la misma secuencia y decide "
            "cuánto le importa cada uno para entender su propio significado en "
            "contexto. 'Multi-Head' significa que esto se hace varias veces en "
            "paralelo (varias 'cabezas'), cada una libre de aprender a fijarse en "
            "un tipo de relación distinto (gramatical, semántica, etc.)."
        ),
    },
    "atencion_causal": {
        "titulo": "Masked Multi-Head Attention",
        "descripcion": (
            "Es la misma idea que la atención normal, pero con una restricción: "
            "cada token del decoder solo puede mirar a los tokens ANTERIORES a él "
            "(y a sí mismo), nunca a los que vienen después. Esto es necesario "
            "porque, al generar texto, el modelo todavía no sabe cuáles van a ser "
            "los tokens futuros."
        ),
    },
    "atencion_cruzada": {
        "titulo": "Cross-Attention",
        "descripcion": (
            "Acá el decoder 'consulta' al encoder: la consulta (quién pregunta) "
            "sale del decoder, pero las respuestas posibles (qué se puede mirar) "
            "salen de la salida del encoder. Es el mecanismo que conecta la "
            "secuencia de entrada con la de salida — por ejemplo, qué palabras del "
            "texto original influyen en cada palabra que se está generando."
        ),
    },
    "feed_forward": {
        "titulo": "Feed Forward",
        "descripcion": (
            "Después de que la atención mezcló información entre tokens, esta "
            "capa procesa cada posición de forma independiente: expande la "
            "dimensión, aplica una no-linealidad, y vuelve a comprimir. Es donde "
            "el modelo 'piensa' sobre la información que ya juntó, token por token."
        ),
    },
    "normalizacion": {
        "titulo": "Add & Norm",
        "descripcion": (
            "Dos cosas en una: 'Add' es una conexión residual (se suma la entrada "
            "original a la salida de la subcapa, para que el gradiente pueda fluir "
            "sin degradarse en redes profundas), y 'Norm' es una normalización que "
            "mantiene los valores en un rango estable, evitando que el "
            "entrenamiento se vuelva inestable."
        ),
    },
    "encoder": {
        "titulo": "Encoder",
        "descripcion": (
            "Procesa la secuencia de entrada completa, de una sola vez, sin "
            "restricciones de orden temporal — cada posición puede mirar a "
            "cualquier otra, incluidas las que vienen después. Su salida es un "
            "resumen contextualizado de toda la entrada, que después consulta el "
            "decoder mediante cross-attention."
        ),
    },
    "decoder": {
        "titulo": "Decoder",
        "descripcion": (
            "Genera la secuencia de salida un token a la vez, de forma "
            "autoregresiva: cada token nuevo se predice a partir de los tokens ya "
            "generados (vía masked self-attention) y de la salida completa del "
            "encoder (vía cross-attention)."
        ),
    },
    "capa_lineal": {
        "titulo": "Capa Linear (final)",
        "descripcion": (
            "Convierte la salida del decoder (un vector por posición) en un "
            "puntaje ('logit') para cada palabra posible del vocabulario. Cuanto "
            "más alto el logit de una palabra, más probable la considera el "
            "modelo como la siguiente palabra."
        ),
    },
    "softmax": {
        "titulo": "Softmax",
        "descripcion": (
            "Convierte los logits (números sin límite, positivos o negativos) en "
            "una distribución de probabilidad de verdad: todos los valores quedan "
            "entre 0 y 1, y suman exactamente 1. Es el último paso antes de elegir "
            "qué token generar."
        ),
    },
    "temperatura": {
        "titulo": "Temperatura (muestreo)",
        "descripcion": (
            "Escala los logits antes del softmax. Temperatura baja (ej. 0.3) "
            "afila la distribución — el modelo casi siempre elige lo más "
            "probable, texto más conservador. Temperatura alta (ej. 1.5) la "
            "aplana — más variedad, pero también más riesgo de texto sin sentido."
        ),
    },
    "top_k": {
        "titulo": "Top-k (muestreo)",
        "descripcion": (
            "En vez de considerar las probabilidades de TODO el vocabulario, se "
            "descartan todas las opciones excepto las k más probables, y se "
            "elige al azar entre esas. Evita que el modelo, aunque sea con muy "
            "baja probabilidad, termine eligiendo algo completamente absurdo."
        ),
    },
    "top_p": {
        "titulo": "Top-p / Nucleus Sampling (muestreo)",
        "descripcion": (
            "Parecido a top-k, pero en vez de un número fijo de candidatos, se "
            "queda con el grupo más chico de opciones cuya probabilidad acumulada "
            "supera p (ej. 0.9). Se adapta mejor que top-k: si el modelo está muy "
            "seguro, el grupo es chico; si está indeciso, el grupo crece solo."
        ),
    },
}


class TheoryController(QObject):
    """Expone `CONTENIDO_TEORIA` a QML. No depende de que exista un
    modelo creado — está disponible desde el arranque, igual que
    `setupController` y `datasetController`."""

    def __init__(self, parent: QObject | None = None):
        super().__init__(parent)

    @Slot(str, result="QVariantMap")
    def obtenerTeoria(self, id_componente: str) -> dict:
        """Devuelve `{"titulo": ..., "descripcion": ...}` para el
        componente pedido. Si no existe, devuelve un contenido de
        respaldo en vez de fallar — así un id todavía sin escribir no
        rompe la Vista, solo muestra "sin información todavía"."""
        return CONTENIDO_TEORIA.get(
            id_componente,
            {
                "titulo": "Sin información todavía",
                "descripcion": f'Todavía no hay teoría escrita para "{id_componente}".',
            },
        )

    @Slot(result="QVariantList")
    def obtenerIdsDisponibles(self) -> list:
        """Lista de ids con contenido real — útil para depurar qué
        falta, o para armar un índice/menú de teoría."""
        return list(CONTENIDO_TEORIA.keys())