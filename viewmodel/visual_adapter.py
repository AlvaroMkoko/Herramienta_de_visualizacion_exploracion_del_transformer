"""
Adaptador Visual.

Capa DELGADA sobre `model/simulacion_numerica/tensor_to_array.py`: el
cómputo numérico real (promediar cabezas, entropía, softmax + top-k)
vive ahí, en el Modelo. Este módulo hace tres cosas propias del
ViewModel:

1. Convertir los `numpy.ndarray` que devuelve `tensor_to_array.py` a
   listas de Python — un `numpy.ndarray` tampoco es un tipo que QML
   pueda usar directamente, igual que un `torch.Tensor`.
2. Combinar esos números con cosas que el Modelo no conoce (como el
   `Tokenizer`, para decodificar ids a texto legible).
3. Construir snapshots pequeños y explicativos para QML a partir de los
   pesos, gradientes y salidas reales del batch, sin enviar copias de
   todos los tensores a la interfaz.

Son funciones puras, no una clase con estado ni señales.
"""

import math

import torch

from model.simulacion_numerica import tensor_to_array


def extraer_mapa_atencion(
    pesos_atencion: torch.Tensor,
    indice_cabeza: int | None = None,
    indice_batch: int = 0,
) -> list[list[float]]:
    """Ver `tensor_to_array.mapa_atencion` — acá solo se convierte el
    resultado a lista, lista para pasarle directo a `VispyItem.setMatrix(...)`."""
    return tensor_to_array.mapa_atencion(
        pesos_atencion, indice_cabeza=indice_cabeza, indice_batch=indice_batch
    ).tolist()


def extraer_mapa_atencion_por_capa(
    pesos_por_capa: list[torch.Tensor],
    indice_capa: int,
    indice_cabeza: int | None = None,
    indice_batch: int = 0,
) -> list[list[float]]:
    """Ver `tensor_to_array.mapa_atencion_por_capa`."""
    return tensor_to_array.mapa_atencion_por_capa(
        pesos_por_capa, indice_capa, indice_cabeza=indice_cabeza, indice_batch=indice_batch
    ).tolist()


def calcular_entropia_atencion(
    pesos_atencion: torch.Tensor,
    indice_cabeza: int | None = None,
    indice_batch: int = 0,
) -> float:
    """Ver `tensor_to_array.entropia_atencion` — ya devuelve un `float`
    puro, no necesita conversión adicional; se re-expone acá para que
    la Vista tenga un solo módulo (`visual_adapter`) al que llamar,
    sin tener que saber que por dentro hay una capa de Modelo separada."""
    return tensor_to_array.entropia_atencion(
        pesos_atencion, indice_cabeza=indice_cabeza, indice_batch=indice_batch
    )


def extraer_top_predicciones(
    logits: torch.Tensor,
    tokenizer,
    n: int = 10,
    indice_batch: int = 0,
) -> list[dict]:
    """Combina `tensor_to_array.probabilidades_top_n` (números) con el
    `tokenizer` (decodificación a texto) — esto es lo que justifica que
    esta función viva en el ViewModel y no en `tensor_to_array.py`: el
    Modelo no tiene por qué saber qué tokenizer se está usando.

    Returns:
        Lista de hasta `n` diccionarios
        `{"token_id": int, "texto": str, "probabilidad": float}`,
        ordenados de mayor a menor probabilidad.
    """
    ids, probabilidades = tensor_to_array.probabilidades_top_n(logits, n=n, indice_batch=indice_batch)

    resultado = []
    for id_token, probabilidad in zip(ids.tolist(), probabilidades.tolist()):
        resultado.append(
            {
                "token_id": id_token,
                "texto": tokenizer.decode([id_token]),
                "probabilidad": round(probabilidad, 4),
            }
        )
    return resultado


def _formatear_numero(valor: float) -> str:
    """Representacion compacta y estable para tarjetas QML."""
    if not math.isfinite(valor):
        return "—"
    absoluto = abs(valor)
    if absoluto == 0:
        return "0"
    if absoluto >= 1000 or absoluto < 0.001:
        return f"{valor:.2e}"
    if absoluto >= 100:
        return f"{valor:.1f}"
    if absoluto >= 1:
        return f"{valor:.3f}"
    return f"{valor:.4f}"


def _metrica(etiqueta: str, valor, detalle: str = "") -> dict:
    if isinstance(valor, float):
        texto = _formatear_numero(valor)
    else:
        texto = str(valor)
    return {"etiqueta": etiqueta, "valor": texto, "detalle": detalle}


def _estadisticas_modulos(modulos) -> dict:
    """Resume pesos y gradientes sin enviar tensores grandes a QML."""
    if not isinstance(modulos, (list, tuple)):
        modulos = [modulos]

    vistos = set()
    parametros = 0
    suma_pesos_2 = 0.0
    suma_gradientes_2 = 0.0
    parametros_con_gradiente = 0
    for modulo in modulos:
        for parametro in modulo.parameters():
            identificador = id(parametro)
            if identificador in vistos:
                continue
            vistos.add(identificador)
            cantidad = parametro.numel()
            parametros += cantidad
            suma_pesos_2 += float(parametro.detach().float().pow(2).sum().item())
            if parametro.grad is not None:
                gradiente = parametro.grad.detach().float()
                suma_gradientes_2 += float(gradiente.pow(2).sum().item())
                parametros_con_gradiente += cantidad

    return {
        "parametros": parametros,
        "norma_pesos": math.sqrt(suma_pesos_2),
        "norma_gradiente": math.sqrt(suma_gradientes_2),
        "gradiente_rms": (
            math.sqrt(suma_gradientes_2 / parametros_con_gradiente)
            if parametros_con_gradiente
            else 0.0
        ),
    }


def _resumen_atencion(pesos_por_capa: list[torch.Tensor | None]) -> dict:
    capas = []
    for indice, pesos in enumerate(pesos_por_capa):
        if pesos is None:
            continue
        mapa = torch.as_tensor(extraer_mapa_atencion(pesos))
        capas.append(
            {
                "capa": indice + 1,
                "entropia": calcular_entropia_atencion(pesos),
                "pico": float(mapa.max().item()),
            }
        )

    if not capas:
        return {"capas": [], "entropia": 0.0, "pico": 0.0}
    return {
        "capas": capas,
        "entropia": sum(capa["entropia"] for capa in capas) / len(capas),
        "pico": max(capa["pico"] for capa in capas),
    }


def _componente(
    titulo: str,
    explicacion: str,
    efecto_siguiente: str,
    modulos=None,
    metricas_extra: list[dict] | None = None,
    capas: list[dict] | None = None,
) -> dict:
    estadisticas = _estadisticas_modulos(modulos) if modulos is not None else None
    metricas = list(metricas_extra or [])
    if estadisticas is not None:
        metricas.extend(
            [
                _metrica(
                    "Intensidad de aprendizaje (RMS)",
                    estadisticas["gradiente_rms"],
                    "Gradiente medio por parámetro en este batch.",
                ),
                _metrica("Norma de pesos", estadisticas["norma_pesos"]),
                _metrica("Parámetros", estadisticas["parametros"]),
            ]
        )
    return {
        "titulo": titulo,
        "explicacion": explicacion,
        "efecto_siguiente": efecto_siguiente,
        "metricas": metricas,
        "capas": list(capas or []),
        "gradiente_rms": estadisticas["gradiente_rms"] if estadisticas else 0.0,
    }


def resumir_paso_entrenamiento(
    modelo,
    logits: torch.Tensor,
    tokens_origen: torch.Tensor,
    tokens_destino: torch.Tensor,
    objetivo: torch.Tensor,
    perdida: float,
    perdida_anterior: float | None,
    norma_gradiente_global: float,
    tokenizer=None,
) -> dict:
    """Construye el snapshot pequeno, real y QML-safe de un batch.

    La funcion se ejecuta despues de ``backward``: por eso las normas de
    gradiente describen la senal que Adam acaba de usar para modificar cada
    componente. No se envian parametros, activaciones ni logits completos.
    """
    config = modelo.config
    encoder = list(modelo.encoder.bloques)
    decoder = list(modelo.decoder.bloques)

    atencion_encoder = _resumen_atencion(
        modelo.encoder.pesos_atencion_por_capa()
    )
    atencion_masked = _resumen_atencion(
        modelo.decoder.pesos_autoatencion_por_capa()
    )
    atencion_cruzada = _resumen_atencion(
        modelo.decoder.pesos_atencion_cruzada_por_capa()
    )

    probabilidades = torch.softmax(logits.detach().float(), dim=-1)
    confianza, prediccion = probabilidades.max(dim=-1)
    mascara_valida = torch.ones_like(objetivo, dtype=torch.bool)
    if config.id_token_relleno is not None:
        mascara_valida = objetivo.ne(config.id_token_relleno)
    cantidad_valida = int(mascara_valida.sum().item())
    if cantidad_valida == 0:
        # Un batch formado solo por padding es anomalo, pero la capa visual
        # debe seguir produciendo numeros finitos en vez de propagar NaN.
        mascara_valida = torch.ones_like(objetivo, dtype=torch.bool)
        cantidad_valida = objetivo.numel()
    precision = float(
        ((prediccion == objetivo) & mascara_valida).sum().item() / cantidad_valida
    )
    confianza_media = float(confianza[mascara_valida].mean().item())
    prob_objetivo = probabilidades.gather(-1, objetivo.unsqueeze(-1)).squeeze(-1)
    prob_objetivo_media = float(prob_objetivo[mascara_valida].mean().item())
    entropia_salida = float(
        (-(probabilidades * torch.log(probabilidades + 1e-12)).sum(dim=-1))[
            mascara_valida
        ].mean().item()
    )

    predicciones_top = []
    if tokenizer is not None:
        try:
            predicciones_top = extraer_top_predicciones(
                logits[:, -1, :], tokenizer, n=3
            )
        except (IndexError, RuntimeError, TypeError, ValueError):
            predicciones_top = []

    tokens_origen_unicos = int(torch.unique(tokens_origen).numel())
    tokens_destino_unicos = int(torch.unique(tokens_destino).numel())
    posicion = modelo.codificacion_posicional.pe[
        :, : max(tokens_origen.size(1), tokens_destino.size(1))
    ]
    amplitud_posicional = float(posicion.float().pow(2).mean().sqrt().item())

    componentes = {
        "input_embedding": _componente(
            "Input Embedding",
            "Convierte cada token de entrada en un vector continuo que el modelo puede ajustar.",
            "Sus vectores, sumados a la posición, son la entrada de la autoatención del encoder.",
            modelo.embedding_entrada,
            [
                _metrica("Forma del batch", f"{tokens_origen.size(0)} × {tokens_origen.size(1)} tokens"),
                _metrica("Tokens únicos", tokens_origen_unicos),
                _metrica("Dimensión del vector", config.dimension_modelo),
            ],
        ),
        "output_embedding": _componente(
            "Output Embedding",
            "Representa los tokens de salida desplazados a la derecha para que el decoder aprenda a predecir el siguiente token.",
            "Al añadir posición, forma las consultas iniciales de la atención causal.",
            modelo.embedding_salida,
            [
                _metrica("Forma del batch", f"{tokens_destino.size(0)} × {tokens_destino.size(1)} tokens"),
                _metrica("Tokens únicos", tokens_destino_unicos),
                _metrica("Pesos compartidos", "Sí" if modelo.compartir_pesos_salida else "No"),
            ],
        ),
        "encoder_positional_encoding": _componente(
            "Positional Encoding · Encoder",
            "Añade senos y cosenos para indicar el orden; no tiene parámetros entrenables.",
            "Permite que la autoatención distinga qué token aparece antes o después.",
            metricas_extra=[
                _metrica("Longitud usada", tokens_origen.size(1)),
                _metrica("Amplitud RMS", amplitud_posicional),
                _metrica("Parámetros entrenables", 0),
            ],
        ),
        "decoder_positional_encoding": _componente(
            "Positional Encoding · Decoder",
            "Añade una señal fija de posición a los embeddings del decoder.",
            "Da orden temporal a las consultas que pasan a la atención causal.",
            metricas_extra=[
                _metrica("Longitud usada", tokens_destino.size(1)),
                _metrica("Amplitud RMS", amplitud_posicional),
                _metrica("Parámetros entrenables", 0),
            ],
        ),
        "encoder_self_attention": _componente(
            "Autoatención del Encoder",
            "Cada token combina información de todos los tokens de entrada mediante varias cabezas.",
            "La mezcla contextual se suma por la conexión residual y luego se normaliza.",
            [bloque.atencion for bloque in encoder],
            [
                _metrica("Entropía media", atencion_encoder["entropia"], "Alta = atención más repartida."),
                _metrica("Mayor peso de atención", atencion_encoder["pico"]),
                _metrica("Cabezas × capas", f"{config.num_cabezas} × {config.num_capas}"),
            ],
            atencion_encoder["capas"],
        ),
        "decoder_masked_attention": _componente(
            "Atención causal del Decoder",
            "Cada posición mira solo su propio token y los anteriores; la máscara evita copiar el futuro.",
            "Produce el contexto de salida que consultará al encoder.",
            [bloque.autoatencion for bloque in decoder],
            [
                _metrica("Entropía media", atencion_masked["entropia"], "Baja = atención más concentrada."),
                _metrica("Mayor peso de atención", atencion_masked["pico"]),
                _metrica("Máscara causal", "Activa" if config.usar_mascara_causal else "Desactivada"),
            ],
            atencion_masked["capas"],
        ),
        "decoder_cross_attention": _componente(
            "Atención cruzada",
            "El decoder usa consultas propias para elegir qué partes de la salida del encoder son relevantes.",
            "Es el puente directo: lo seleccionado aquí alimenta la predicción del decoder.",
            [bloque.atencion_cruzada for bloque in decoder],
            [
                _metrica("Entropía media", atencion_cruzada["entropia"], "Mide cuánto reparte la consulta su atención."),
                _metrica("Mayor peso de atención", atencion_cruzada["pico"]),
                _metrica("Mapa Q × K", f"{tokens_destino.size(1)} × {tokens_origen.size(1)}"),
            ],
            atencion_cruzada["capas"],
        ),
        "encoder_feed_forward": _componente(
            "Feed Forward · Encoder",
            "Procesa por separado el vector contextual de cada posición con expansión, activación y proyección.",
            "Refina las características que el encoder entregará al decoder.",
            [bloque.feed_forward for bloque in encoder],
            [
                _metrica("Expansión", f"{config.dimension_modelo} → {config.dimension_ff} → {config.dimension_modelo}"),
                _metrica("Activación", config.activacion.upper()),
            ],
        ),
        "decoder_feed_forward": _componente(
            "Feed Forward · Decoder",
            "Transforma cada posición después de integrar el contexto causal y el del encoder.",
            "Su salida normalizada pasa a la capa lineal que puntúa el vocabulario.",
            [bloque.feed_forward for bloque in decoder],
            [
                _metrica("Expansión", f"{config.dimension_modelo} → {config.dimension_ff} → {config.dimension_modelo}"),
                _metrica("Activación", config.activacion.upper()),
            ],
        ),
        "linear": _componente(
            "Proyección lineal",
            "Convierte cada vector del decoder en un puntaje (logit) por token del vocabulario.",
            "Softmax transforma esos puntajes en probabilidades comparables.",
            modelo.capa_salida,
            [
                _metrica("Forma de logits", " × ".join(str(v) for v in logits.shape)),
                _metrica("Desviación de logits", float(logits.detach().float().std().item())),
                _metrica("Vocabulario", config.tamano_vocabulario),
            ],
        ),
        "softmax": _componente(
            "Softmax y pérdida",
            "Convierte logits en probabilidades; la pérdida compara esa distribución con el token correcto.",
            "El error resultante viaja hacia atrás y modifica todos los bloques entrenables.",
            metricas_extra=[
                _metrica("Confianza top-1 media", confianza_media),
                _metrica("Probabilidad del objetivo", prob_objetivo_media),
                _metrica("Acierto top-1", f"{precision * 100:.1f}%"),
                _metrica("Entropía de salida", entropia_salida),
            ],
        ),
    }

    # Las conexiones Add & Norm comparten la misma explicacion, pero sus
    # gradientes y parametros proceden de los LayerNorm reales de cada rama.
    conexiones = {
        "encoder_add_norm_attention": [b.conexion_atencion for b in encoder],
        "encoder_add_norm_ffn": [b.conexion_feed_forward for b in encoder],
        "decoder_add_norm_masked": [b.conexion_autoatencion for b in decoder],
        "decoder_add_norm_cross": [b.conexion_atencion_cruzada for b in decoder],
        "decoder_add_norm_ffn": [b.conexion_feed_forward for b in decoder],
    }
    for identificador, modulos in conexiones.items():
        componentes[identificador] = _componente(
            "Conexión residual · Add & Norm",
            "Suma la entrada original con la salida de la subcapa y normaliza el resultado para estabilizar el entrenamiento.",
            "Conserva información previa mientras entrega una escala estable al siguiente bloque.",
            modulos,
            [
                _metrica("Capas observadas", config.num_capas),
                _metrica("Dimensión normalizada", config.dimension_modelo),
                _metrica("Dropout", config.dropout),
            ],
        )

    candidatos = [
        (identificador, datos["gradiente_rms"])
        for identificador, datos in componentes.items()
        if datos["gradiente_rms"] > 0
    ]
    id_relevante, intensidad = max(candidatos, key=lambda item: item[1], default=("", 0.0))
    titulo_relevante = componentes.get(id_relevante, {}).get("titulo", "Sin señal")
    delta = perdida - perdida_anterior if perdida_anterior is not None else 0.0
    if perdida_anterior is None:
        lectura_perdida = "Este es el primer batch de la sesión."
    elif delta < 0:
        lectura_perdida = f"La pérdida bajó {abs(delta):.4f} respecto al batch anterior."
    elif delta > 0:
        lectura_perdida = f"La pérdida subió {delta:.4f}; un batch aislado puede fluctuar."
    else:
        lectura_perdida = "La pérdida se mantuvo respecto al batch anterior."

    return {
        "resumen": {
            "perdida": perdida,
            "delta_perdida": delta,
            "lectura_perdida": lectura_perdida,
            "norma_gradiente_global": norma_gradiente_global,
            "componente_relevante_id": id_relevante,
            "componente_relevante": titulo_relevante,
            "intensidad_relevante": intensidad,
            "predicciones_top": predicciones_top,
        },
        "componentes": componentes,
    }
