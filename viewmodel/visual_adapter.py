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
from model.motor_llm.muestreo import (
    aplicar_temperatura,
    filtrar_top_k,
    filtrar_top_p,
)


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


def _texto_token(tokenizer, token_id: int, especial: str = "") -> str:
    """Decodifica un token aislado y hace visibles espacios/saltos en QML."""
    if especial:
        return especial
    try:
        texto = tokenizer.decode([int(token_id)])
    except (KeyError, RuntimeError, TypeError, ValueError):
        texto = ""
    if texto == "":
        return "∅"
    return (
        texto.replace(" ", "␠")
        .replace("\n", "↵")
        .replace("\t", "⇥")
        .replace("\r", "")
    )


def _offsets_tokens(tokenizer, ids: list[int]) -> list[tuple[int, int]] | None:
    encoding = getattr(tokenizer, "encoding", None)
    if encoding is None or not hasattr(encoding, "decode_with_offsets"):
        return None
    try:
        texto, inicios = encoding.decode_with_offsets(ids)
    except (KeyError, RuntimeError, TypeError, ValueError, UnicodeError):
        return None
    finales = list(inicios[1:]) + [len(texto)]
    return [(int(inicio), int(fin)) for inicio, fin in zip(inicios, finales)]


def _tokens_visibles(tokenizer, ids: list[int], limite: int = 32) -> list[dict]:
    """Tokens compactos con posición; conserva el final si la secuencia es larga."""
    inicio = max(0, len(ids) - limite)
    offsets = _offsets_tokens(tokenizer, ids)
    resultado = []
    for indice, token_id in enumerate(ids[inicio:], start=inicio):
        token = {
            "posicion": indice,
            "token_id": int(token_id),
            "texto": _texto_token(tokenizer, int(token_id)),
            "offset_inicio": offsets[indice][0] if offsets else -1,
            "offset_fin": offsets[indice][1] if offsets else -1,
        }
        resultado.append(token)
    return resultado


def _atencion_ultima_consulta(
    pesos_por_capa: list[torch.Tensor | None],
    etiquetas: list[dict],
    limite: int = 32,
) -> list[dict]:
    """Promedia cabezas de la última consulta en la última capa disponible."""
    pesos = next((p for p in reversed(pesos_por_capa) if p is not None), None)
    if pesos is None or pesos.numel() == 0:
        return []
    vector = pesos.detach().float()[0].mean(dim=0)[-1]
    cantidad = min(int(vector.numel()), len(etiquetas))
    inicio = max(0, cantidad - limite)
    return [
        {
            **etiquetas[indice],
            "peso": round(float(vector[indice].item()), 5),
        }
        for indice in range(inicio, cantidad)
    ]


def _resumen_atencion_ultima_consulta(
    pesos_por_capa: list[torch.Tensor | None],
) -> dict:
    """Resume solo la fila que produjo el token actual.

    En inferencia autoregresiva las matrices causales crecen en cada vuelta.
    Limitar el resumen a la última consulta evita copiar matrices cuadradas
    completas a CPU sin perder la lectura relevante para la decisión actual.
    """
    capas = []
    for indice, pesos in enumerate(pesos_por_capa):
        if pesos is None or pesos.numel() == 0:
            continue
        por_cabeza = pesos.detach().float()[0, :, -1, :]
        promedio = por_cabeza.mean(dim=0)
        entropia = float(
            (-(por_cabeza * torch.log(por_cabeza + 1e-12)).sum(dim=-1))
            .mean()
            .item()
        )
        capas.append(
            {
                "capa": indice + 1,
                "entropia": entropia,
                "pico": float(promedio.max().item()),
            }
        )
    return {"capas": capas}


def _forma(tensor: torch.Tensor) -> str:
    return " × ".join(str(int(valor)) for valor in tensor.shape)


def _estadisticas_tensor(tensor: torch.Tensor) -> dict:
    valores = tensor.detach().float().reshape(-1)
    finitos = valores[torch.isfinite(valores)]
    if finitos.numel() == 0:
        return {
            "minimo": "—", "maximo": "—", "media": "—",
            "desviacion": "—", "norma_l2": "—", "finitos": 0,
        }
    return {
        "minimo": _formatear_numero(float(finitos.min().item())),
        "maximo": _formatear_numero(float(finitos.max().item())),
        "media": _formatear_numero(float(finitos.mean().item())),
        "desviacion": _formatear_numero(
            float(finitos.std(unbiased=False).item())
        ),
        "norma_l2": _formatear_numero(float(finitos.norm().item())),
        "finitos": int(finitos.numel()),
    }


def _histograma(tensor: torch.Tensor, bins: int = 16) -> dict:
    valores = tensor.detach().float().reshape(-1)
    valores = valores[torch.isfinite(valores)]
    if valores.numel() == 0:
        return {"conteos": [], "bordes": [], "total": 0}
    minimo = float(valores.min().item())
    maximo = float(valores.max().item())
    if math.isclose(minimo, maximo):
        return {
            "conteos": [int(valores.numel())],
            "bordes": [minimo, maximo],
            "total": int(valores.numel()),
        }
    conteos = torch.histc(valores, bins=bins, min=minimo, max=maximo)
    bordes = torch.linspace(minimo, maximo, bins + 1)
    return {
        "conteos": [int(round(valor)) for valor in conteos.tolist()],
        "bordes": [round(float(valor), 6) for valor in bordes.tolist()],
        "total": int(valores.numel()),
    }


def _matriz_muestra(
    tensor: torch.Tensor,
    max_filas: int = 32,
    max_columnas: int = 32,
) -> dict:
    datos = tensor.detach().float()
    while datos.dim() > 2:
        datos = datos[0]
    if datos.dim() == 1:
        datos = datos.unsqueeze(0)
    filas_originales, columnas_originales = datos.shape
    inicio_fila = max(0, filas_originales - max_filas)
    muestra = datos[inicio_fila:, :max_columnas].cpu()
    completa = muestra.shape == datos.shape
    return {
        "valores": [
            [round(float(valor), 6) for valor in fila]
            for fila in muestra.tolist()
        ],
        "original_shape": f"{filas_originales} × {columnas_originales}",
        "displayed_shape": f"{muestra.size(0)} × {muestra.size(1)}",
        "aggregation_method": "ninguna",
        "level_of_detail": (
            "completo exacto"
            if completa
            else f"ventana exacta: últimas {muestra.size(0)} filas × primeras {muestra.size(1)} dimensiones"
        ),
        "rango": _estadisticas_tensor(datos),
    }


def _ventana_tokens(tensor: torch.Tensor, limite: int = 24) -> tuple[torch.Tensor, int]:
    """Devuelve una matriz token × dimensión pequeña y su offset real."""
    datos = tensor.detach().float()
    while datos.dim() > 2:
        datos = datos[0]
    if datos.dim() == 1:
        datos = datos.unsqueeze(0)
    inicio = max(0, int(datos.size(0)) - limite)
    return datos[inicio:].cpu(), inicio


def _pca_compartido(matrices: list[torch.Tensor]) -> tuple[list[list[dict]], float]:
    """Proyecta varias nubes con una única base PCA determinista.

    Ajustar cada nube por separado permitiría rotaciones/reflejos arbitrarios
    y produciría una animación engañosa. Aquí se concatena todo, se centra una
    sola vez y se reutilizan exactamente los mismos dos ejes.
    """
    preparadas = [matriz.detach().float().cpu() for matriz in matrices if matriz.numel()]
    if not preparadas:
        return [[] for _ in matrices], 0.0

    dimension = min(int(matriz.size(-1)) for matriz in preparadas)
    preparadas = [matriz[:, :dimension] for matriz in preparadas]
    conjunta = torch.cat(preparadas, dim=0)
    centrada = conjunta - conjunta.mean(dim=0, keepdim=True)

    try:
        _, valores_singulares, vh = torch.linalg.svd(centrada, full_matrices=False)
        componentes = vh[: min(2, vh.size(0))].T.contiguous()
        # Fija el signo de cada eje usando su carga dominante para evitar que
        # dos capturas equivalentes parpadeen por una reflexión del SVD.
        for eje in range(componentes.size(1)):
            indice = int(componentes[:, eje].abs().argmax().item())
            if float(componentes[indice, eje].item()) < 0:
                componentes[:, eje].mul_(-1)
        coordenadas = centrada @ componentes
        energia = valores_singulares.square()
        varianza = float(
            energia[: componentes.size(1)].sum().item()
            / max(float(energia.sum().item()), 1e-12)
        )
    except RuntimeError:
        # Un fallback exacto y estable para backends sin SVD: primeras dos
        # dimensiones centradas. Sigue siendo una proyección compartida.
        coordenadas = centrada[:, : min(2, dimension)]
        total = float(centrada.square().sum().item())
        varianza = float(coordenadas.square().sum().item() / max(total, 1e-12))

    if coordenadas.size(1) < 2:
        coordenadas = torch.cat(
            [coordenadas, torch.zeros(coordenadas.size(0), 2 - coordenadas.size(1))],
            dim=1,
        )

    resultado: list[list[dict]] = []
    cursor = 0
    for matriz in preparadas:
        cantidad = int(matriz.size(0))
        puntos = coordenadas[cursor : cursor + cantidad]
        resultado.append(
            [
                {"x": round(float(punto[0]), 6), "y": round(float(punto[1]), 6)}
                for punto in puntos.tolist()
            ]
        )
        cursor += cantidad
    return resultado, round(varianza, 6)


def _proyeccion_posicional(
    embedding: torch.Tensor,
    entrada: torch.Tensor,
    limite: int = 24,
) -> dict:
    embedding_ventana, inicio_embedding = _ventana_tokens(embedding, limite)
    entrada_ventana, inicio_entrada = _ventana_tokens(entrada, limite)
    cantidad = min(embedding_ventana.size(0), entrada_ventana.size(0))
    embedding_ventana = embedding_ventana[-cantidad:]
    entrada_ventana = entrada_ventana[-cantidad:]
    puntos, varianza = _pca_compartido([embedding_ventana, entrada_ventana])
    return {
        "embedding": puntos[0] if puntos else [],
        "entrada": puntos[1] if len(puntos) > 1 else [],
        "inicio_posicion": max(inicio_embedding, inicio_entrada),
        "varianza_conservada": varianza,
        "dimension_original": int(embedding_ventana.size(-1)),
        "metodo": "PCA conjunto centrado",
    }


def _trayectoria_pca(
    entrada: torch.Tensor | None,
    bloques,
    limite: int = 24,
) -> dict:
    if entrada is None:
        return {"capas": [], "inicio_posicion": 0, "varianza_conservada": 0.0}

    inicial, inicio = _ventana_tokens(entrada, limite)
    estados = [inicial]
    numeros_capa = [0]
    for indice, bloque in enumerate(bloques, start=1):
        traza = getattr(bloque.conexion_feed_forward, "ultima_traza", None) or {}
        tensor = traza.get("salida_visual")
        if tensor is None:
            continue
        estado, inicio_estado = _ventana_tokens(tensor, limite)
        cantidad = min(inicial.size(0), estado.size(0))
        estados = [existente[-cantidad:] for existente in estados]
        inicial = inicial[-cantidad:]
        estado = estado[-cantidad:]
        estados.append(estado)
        numeros_capa.append(indice)
        inicio = max(inicio, inicio_estado)

    puntos, varianza = _pca_compartido(estados)
    return {
        "capas": [
            {"capa": numero, "puntos": nube}
            for numero, nube in zip(numeros_capa, puntos)
        ],
        "inicio_posicion": inicio,
        "varianza_conservada": varianza,
        "dimension_original": int(estados[0].size(-1)) if estados else 0,
        "metodo": "PCA conjunto centrado",
    }


def _resumen_residual(conexion) -> dict:
    traza = getattr(conexion, "ultima_traza", None)
    if not traza:
        return {}
    entrada = traza["entrada"].detach().float()[0]
    actualizacion = traza["actualizacion"].detach().float()[0]
    antes = traza["antes_norma"].detach().float()[0]
    salida = traza["salida"].detach().float()[0]
    media = antes.mean()
    centrado = antes - media
    desviacion = antes.std(unbiased=False)
    estandarizado = centrado / torch.sqrt(antes.var(unbiased=False) + traza["epsilon"])
    gamma = conexion.norma.weight.detach().float()
    beta = conexion.norma.bias.detach().float()
    norma_entrada = float(entrada.norm().item())
    norma_delta = float(actualizacion.norm().item())
    coseno = float(
        torch.nn.functional.cosine_similarity(
            entrada.unsqueeze(0), actualizacion.unsqueeze(0), dim=-1
        ).item()
    )
    return {
        "shape": " × ".join(str(v) for v in traza["shape"]),
        "epsilon": traza["epsilon"],
        "norma_entrada": round(norma_entrada, 6),
        "norma_actualizacion": round(norma_delta, 6),
        "norma_resultado": round(float(salida.norm().item()), 6),
        "ratio_actualizacion": round(norma_delta / max(norma_entrada, 1e-12), 6),
        "coseno": round(coseno, 6),
        "media_antes": round(float(antes.mean().item()), 6),
        "desviacion_antes": round(float(antes.std(unbiased=False).item()), 6),
        "media_despues": round(float(salida.mean().item()), 6),
        "desviacion_despues": round(float(salida.std(unbiased=False).item()), 6),
        "histograma_antes": _histograma(antes),
        "histograma_despues": _histograma(salida),
        "layernorm": {
            "fases": [
                {
                    "id": "suma",
                    "nombre": "x + Δx",
                    "operacion": "Distribución antes de LayerNorm",
                    "valores": [round(float(v), 5) for v in antes[:48].tolist()],
                    "media": round(float(media.item()), 6),
                    "desviacion": round(float(desviacion.item()), 6),
                },
                {
                    "id": "centrado",
                    "nombre": "Restar μ",
                    "operacion": "x − media(x)",
                    "valores": [round(float(v), 5) for v in centrado[:48].tolist()],
                    "media": round(float(centrado.mean().item()), 6),
                    "desviacion": round(float(centrado.std(unbiased=False).item()), 6),
                },
                {
                    "id": "estandarizado",
                    "nombre": "Dividir por σ",
                    "operacion": "(x − μ) / √(var + ε)",
                    "valores": [round(float(v), 5) for v in estandarizado[:48].tolist()],
                    "media": round(float(estandarizado.mean().item()), 6),
                    "desviacion": round(float(estandarizado.std(unbiased=False).item()), 6),
                },
                {
                    "id": "afin",
                    "nombre": "Aplicar γ y β",
                    "operacion": "γ · x̂ + β",
                    "valores": [round(float(v), 5) for v in salida[:48].tolist()],
                    "media": round(float(salida.mean().item()), 6),
                    "desviacion": round(float(salida.std(unbiased=False).item()), 6),
                },
            ],
            "gamma_media": round(float(gamma.mean().item()), 6),
            "gamma_minimo": round(float(gamma.min().item()), 6),
            "gamma_maximo": round(float(gamma.max().item()), 6),
            "beta_media": round(float(beta.mean().item()), 6),
            "beta_minimo": round(float(beta.min().item()), 6),
            "beta_maximo": round(float(beta.max().item()), 6),
        },
        "vectores": {
            "entrada": [round(float(v), 5) for v in entrada[:32].tolist()],
            "actualizacion": [round(float(v), 5) for v in actualizacion[:32].tolist()],
            "resultado": [round(float(v), 5) for v in salida[:32].tolist()],
        },
        "dimension_mostrada": min(32, int(entrada.numel())),
    }


def _resumen_ffn(feed_forward) -> dict:
    traza = getattr(feed_forward, "ultima_traza", None)
    if not traza:
        return {}
    activacion = traza["activacion"].detach().float()[0]
    entrada_visual = traza.get("entrada_visual", traza["entrada"].unsqueeze(1))
    preactivacion_visual = traza.get(
        "preactivacion_visual", traza["preactivacion"].unsqueeze(1)
    )
    activacion_visual = traza.get(
        "activacion_visual", traza["activacion"].unsqueeze(1)
    )
    salida_visual = traza.get("salida_visual", traza["salida"].unsqueeze(1))
    entrada_visual = entrada_visual.detach().float()[0]
    preactivacion_visual = preactivacion_visual.detach().float()[0]
    activacion_visual = activacion_visual.detach().float()[0]
    salida_visual = salida_visual.detach().float()[0]
    cantidad_tokens = min(
        entrada_visual.size(0),
        preactivacion_visual.size(0),
        activacion_visual.size(0),
        salida_visual.size(0),
    )
    inicio_posicion = int(
        traza.get(
            "inicio_posicion_visual",
            max(0, int(traza["shape_entrada"][1]) - cantidad_tokens),
        )
    )

    tokens = []
    for indice in range(cantidad_tokens):
        entrada_token = entrada_visual[indice]
        pre_token = preactivacion_visual[indice]
        activacion_token = activacion_visual[indice]
        salida_token = salida_visual[indice]
        tokens.append(
            {
                "posicion": inicio_posicion + indice,
                "entrada": [round(float(v), 5) for v in entrada_token[:64].tolist()],
                "preactivacion": [round(float(v), 5) for v in pre_token[:64].tolist()],
                "activacion": [round(float(v), 5) for v in activacion_token[:64].tolist()],
                "salida": [round(float(v), 5) for v in salida_token[:64].tolist()],
                "norma_entrada": round(float(entrada_token.norm().item()), 6),
                "norma_preactivacion": round(float(pre_token.norm().item()), 6),
                "norma_activacion": round(float(activacion_token.norm().item()), 6),
                "norma_salida": round(float(salida_token.norm().item()), 6),
                "fraccion_negativa": round(float((pre_token < 0).float().mean().item()), 6),
                "fraccion_casi_cero": round(
                    float((activacion_token.abs() < 1e-6).float().mean().item()), 6
                ),
                "dimension_entrada": int(entrada_token.numel()),
                "dimension_oculta": int(activacion_token.numel()),
                "dimension_salida": int(salida_token.numel()),
            }
        )
    cantidad_top = min(8, int(activacion.numel()))
    valores_top, indices_top = torch.topk(activacion.abs(), cantidad_top)
    return {
        "shape_entrada": " × ".join(str(v) for v in traza["shape_entrada"]),
        "shape_oculta": " × ".join(str(v) for v in traza["shape_oculta"]),
        "shape_salida": " × ".join(str(v) for v in traza["shape_salida"]),
        "activacion": traza["activacion_nombre"],
        "tokens": tokens,
        "inicio_posicion": inicio_posicion,
        "histograma_preactivacion": _histograma(traza["preactivacion"]),
        "histograma_activacion": _histograma(activacion),
        "estadisticas": _estadisticas_tensor(activacion),
        "unidades_top": [
            {
                "unidad": int(indice),
                "magnitud": round(float(magnitud), 6),
                "valor": round(float(activacion[int(indice)].item()), 6),
            }
            for magnitud, indice in zip(valores_top.tolist(), indices_top.tolist())
        ],
    }


def _resumen_traza_atencion(atencion) -> dict:
    traza = getattr(atencion, "ultima_traza", None)
    pesos_completos = getattr(atencion, "ultimos_pesos_atencion", None)
    if not traza or pesos_completos is None:
        return {}

    def matriz_3d(tensor: torch.Tensor) -> list[list[float]]:
        return [
            [round(float(valor), 6) for valor in fila]
            for fila in tensor.detach().float()[0].cpu().tolist()
        ]

    pesos = traza["pesos_ultima"].detach().float()[0]
    scores = traza["scores_crudos_ultima"].detach().float()[0]
    scores_mask = traza["scores_enmascarados_ultima"].detach().float()[0]
    contribuciones = traza["contribuciones_ultima"].detach().float()[0]
    mascara = traza["mascara_ultima"]
    if mascara is None:
        mascara_lista = [[1 for _ in range(pesos.size(1))] for _ in range(pesos.size(0))]
    else:
        mascara_lista = [
            [1 if valor else 0 for valor in fila]
            for fila in mascara[0].cpu().tolist()
        ]

    cabezas = []
    sumas = pesos_completos.detach().float().sum(dim=-1)
    for indice in range(pesos.size(0)):
        fila = pesos_completos.detach().float()[0, indice, -1, :]
        entropia = float((-(fila * torch.log(fila + 1e-12))).sum().item())
        cabezas.append(
            {
                "id": f"H{indice + 1:02d}",
                "indice": indice,
                "entropia": round(entropia, 6),
                "maximo": round(float(fila.max().item()), 6),
                "masa_top3": round(
                    float(torch.topk(fila, min(3, fila.numel())).values.sum().item()), 6
                ),
                "soporte_efectivo": round(math.exp(entropia), 4),
                "suma_fila": round(float(sumas[0, indice, -1].item()), 6),
            }
        )

    original = traza["shape_scores"]
    displayed = (pesos.size(0), pesos.size(1))
    pesos_flujo = pesos_completos.detach().float()[0]
    # Doce tokens mantienen legibles las curvas y acotan el payload aun en
    # modelos de 12 capas × 12 cabezas. La ventana es exacta, no agregada.
    limite_flujo = 12
    inicio_queries = max(0, int(pesos_flujo.size(-2)) - limite_flujo)
    inicio_keys_flujo = max(0, int(pesos_flujo.size(-1)) - limite_flujo)
    pesos_flujo = pesos_flujo[
        :, inicio_queries:, inicio_keys_flujo:
    ].cpu()
    return {
        "q": matriz_3d(traza["q_ultima"]),
        "k": matriz_3d(traza["k_destacada"]),
        "v": matriz_3d(traza["v_destacada"]),
        "scores": matriz_3d(scores.unsqueeze(0)),
        "scores_enmascarados": matriz_3d(scores_mask.unsqueeze(0)),
        "mascara": mascara_lista,
        "atencion": matriz_3d(pesos.unsqueeze(0)),
        "contribuciones": matriz_3d(contribuciones.unsqueeze(0)),
        "salida_cabezas": matriz_3d(traza["salida_cabezas_ultima"]),
        "salida_concatenada": [
            round(float(v), 6)
            for v in traza["salida_concatenada_ultima"][0].cpu().tolist()
        ],
        "salida_proyectada": [
            round(float(v), 6)
            for v in traza["salida_proyectada_ultima"][0].cpu().tolist()
        ],
        "key_destacada": traza["key_destacada"],
        "cabezas": cabezas,
        "flujo": {
            "matrices": [
                [
                    [round(float(valor), 6) for valor in fila]
                    for fila in cabeza
                ]
                for cabeza in pesos_flujo.tolist()
            ],
            "inicio_queries": inicio_queries,
            "inicio_keys": inicio_keys_flujo,
            "queries_mostradas": int(pesos_flujo.size(-2)),
            "keys_mostradas": int(pesos_flujo.size(-1)),
            "ventana_exacta": True,
        },
        "shape_q": " × ".join(str(v) for v in traza["shape_q"]),
        "shape_k": " × ".join(str(v) for v in traza["shape_k"]),
        "shape_v": " × ".join(str(v) for v in traza["shape_v"]),
        "original_shape": " × ".join(str(v) for v in original),
        "displayed_shape": f"{displayed[0]} × 1 × {displayed[1]}",
        "aggregation_method": "ninguna; query actual y ventana exacta de keys",
        "level_of_detail": (
            "completo para la query actual"
            if traza["inicio_keys"] == 0
            else f"últimas {displayed[1]} keys; original conserva {original[-1]}"
        ),
        "inicio_keys": traza["inicio_keys"],
        "dimension_mostrada": traza["dimension_mostrada"],
        "validacion": {
            "filas_suman_uno": bool(torch.allclose(
                sumas, torch.ones_like(sumas), atol=1e-5, rtol=1e-5
            )),
            "error_max_suma": round(float((sumas - 1).abs().max().item()), 8),
            "sin_nan": not bool(torch.isnan(pesos_completos).any().item()),
            "enmascarados_cero": traza["maximo_peso_enmascarado"] <= 1e-6,
            "maximo_peso_enmascarado": round(
                float(traza["maximo_peso_enmascarado"]), 8
            ),
            "porcentaje_bloqueado": round(
                float(traza["porcentaje_bloqueado"]), 3
            ),
        },
    }


def _detalle_forward(modelo, paso: dict) -> dict:
    traza_global = paso.get("traza_global") or {}
    config = modelo.config

    encoder = []
    for indice, bloque in enumerate(modelo.encoder.bloques):
        encoder.append(
            {
                "capa": indice + 1,
                "atencion": _resumen_traza_atencion(bloque.atencion),
                "residual_atencion": _resumen_residual(bloque.conexion_atencion),
                "ffn": _resumen_ffn(bloque.feed_forward),
                "residual_ffn": _resumen_residual(bloque.conexion_feed_forward),
            }
        )

    decoder = []
    for indice, bloque in enumerate(modelo.decoder.bloques):
        decoder.append(
            {
                "capa": indice + 1,
                "autoatencion": _resumen_traza_atencion(bloque.autoatencion),
                "residual_autoatencion": _resumen_residual(
                    bloque.conexion_autoatencion
                ),
                "atencion_cruzada": _resumen_traza_atencion(
                    bloque.atencion_cruzada
                ),
                "residual_cruzada": _resumen_residual(
                    bloque.conexion_atencion_cruzada
                ),
                "ffn": _resumen_ffn(bloque.feed_forward),
                "residual_ffn": _resumen_residual(bloque.conexion_feed_forward),
            }
        )

    globales = {}
    for nombre in (
        "embedding_encoder",
        "embedding_encoder_escalado",
        "posicion_encoder",
        "entrada_encoder",
        "salida_encoder",
        "embedding_decoder",
        "embedding_decoder_escalado",
        "posicion_decoder",
        "entrada_decoder",
        "salida_decoder",
    ):
        tensor = traza_global.get(nombre)
        if tensor is None:
            continue
        globales[nombre] = {
            "shape": _forma(tensor),
            "dtype": str(tensor.dtype).replace("torch.", ""),
            "device": str(tensor.device),
            "matriz": _matriz_muestra(tensor),
            "histograma": _histograma(tensor),
            "estadisticas": _estadisticas_tensor(tensor),
            "normas_tokens": [
                round(float(valor), 6)
                for valor in tensor.detach().float()[0].norm(dim=-1).cpu().tolist()[-32:]
            ],
        }

    if (
        traza_global.get("embedding_encoder_escalado") is not None
        and traza_global.get("entrada_encoder") is not None
    ):
        globales["proyeccion_posicional_encoder"] = _proyeccion_posicional(
            traza_global["embedding_encoder_escalado"],
            traza_global["entrada_encoder"],
        )
    if (
        traza_global.get("embedding_decoder_escalado") is not None
        and traza_global.get("entrada_decoder") is not None
    ):
        globales["proyeccion_posicional_decoder"] = _proyeccion_posicional(
            traza_global["embedding_decoder_escalado"],
            traza_global["entrada_decoder"],
        )

    trayectorias = {
        "encoder": _trayectoria_pca(
            traza_global.get("entrada_encoder"), modelo.encoder.bloques
        ),
        "decoder": _trayectoria_pca(
            traza_global.get("entrada_decoder"), modelo.decoder.bloques
        ),
    }

    mascara_causal = traza_global.get("mascara_causal")
    if mascara_causal is not None:
        mascara = mascara_causal.detach().bool()
        while mascara.dim() > 2:
            mascara = mascara[0]
        inicio = max(0, mascara.size(0) - 64)
        muestra = mascara[inicio:, inicio:]
        globales["mascara_causal"] = {
            "valores": [[1 if v else 0 for v in fila] for fila in muestra.cpu().tolist()],
            "original_shape": f"{mascara.size(0)} × {mascara.size(1)}",
            "displayed_shape": f"{muestra.size(0)} × {muestra.size(1)}",
            "aggregation_method": "ninguna",
            "level_of_detail": "completo exacto" if inicio == 0 else "ventana causal final exacta",
            "porcentaje_bloqueado": round(
                float((~mascara).float().mean().item() * 100), 3
            ),
        }

    logits = paso["logits"].detach().float()
    return {
        "metadata": {
            "architecture": "encoder_decoder",
            "num_layers": config.num_capas,
            "num_heads": config.num_cabezas,
            "d_model": config.dimension_modelo,
            "d_head": config.dimension_cabeza,
            "d_ff": config.dimension_ff,
            "norm_order": "post-norm",
            "norm_epsilon": float(
                modelo.encoder.bloques[0].conexion_atencion.norma.eps
            ),
            "position_encoding_type": "sinusoidal aditivo",
            "mask_type": "causal decoder + padding cuando aplica",
            "dtype": str(next(modelo.parameters()).dtype).replace("torch.", ""),
            "device": str(next(modelo.parameters()).device),
            "framework": f"PyTorch {torch.__version__}",
            "capture_precision": "float32 para métricas visuales",
        },
        "global": globales,
        "encoder": encoder,
        "decoder": decoder,
        "trayectorias": trayectorias,
        "logits": {
            "shape": _forma(logits),
            "dtype": str(paso["logits"].dtype).replace("torch.", ""),
            "histograma": _histograma(logits),
            "estadisticas": _estadisticas_tensor(logits),
            "sin_nan": not bool(torch.isnan(logits).any().item()),
        },
    }


def resumir_paso_inferencia(
    modelo,
    tokenizer,
    tokens_origen: torch.Tensor,
    paso: dict,
    ids_generados: list[int],
    id_token_inicio: int,
    temperatura: float,
    top_k: int | None,
    top_p: float | None,
    muestreo_codicioso: bool,
) -> dict:
    """Construye una explicación QML-safe del cálculo real de un token.

    El snapshot usa los logits y pesos de atención capturados por el motor en
    ese mismo paso. Solo se mandan resúmenes y vectores pequeños a la vista;
    los tensores completos permanecen en la capa Python.
    """
    config = modelo.config
    ids_entrada = [int(valor) for valor in tokens_origen[0].detach().cpu().tolist()]
    tokens_entrada = _tokens_visibles(tokenizer, ids_entrada)
    tokens_salida = _tokens_visibles(tokenizer, ids_generados)

    logits = paso["logits"].detach().float()
    if muestreo_codicioso:
        logits_finales = logits
    else:
        logits_finales = aplicar_temperatura(logits, float(temperatura))
        if top_k is not None:
            logits_finales = filtrar_top_k(logits_finales, int(top_k))
        if top_p is not None:
            logits_finales = filtrar_top_p(logits_finales, float(top_p))

    probabilidades = torch.softmax(logits_finales, dim=-1)[0]
    cantidad_candidatos = (
        1
        if muestreo_codicioso
        else int(torch.isfinite(logits_finales[0]).sum().item())
    )
    cantidad_top = (
        min(8, int(probabilidades.numel()))
        if muestreo_codicioso
        else min(8, max(1, cantidad_candidatos), int(probabilidades.numel()))
    )
    probs_top, ids_top = torch.topk(probabilidades, cantidad_top)
    token_elegido_id = int(paso["token_id"])
    orden = torch.argsort(probabilidades, descending=True)
    posicion_elegida = (orden == token_elegido_id).nonzero(as_tuple=False)
    rango_elegido = (
        int(posicion_elegida[0].item()) + 1 if posicion_elegida.numel() else 0
    )
    predicciones_top = []
    acumulada = 0.0
    for rango, (probabilidad, token_id) in enumerate(
        zip(probs_top.tolist(), ids_top.tolist()), start=1
    ):
        acumulada += float(probabilidad)
        predicciones_top.append(
            {
                "token_id": int(token_id),
                "texto": _texto_token(tokenizer, int(token_id)),
                "logit": round(float(logits[0, int(token_id)].item()), 6),
                "rango": rango,
                "probabilidad": round(float(probabilidad), 6),
                "probabilidad_acumulada": round(acumulada, 6),
                "elegido": int(token_id) == token_elegido_id,
            }
        )
    if not any(prediccion["elegido"] for prediccion in predicciones_top):
        predicciones_top.append(
            {
                "token_id": token_elegido_id,
                "texto": _texto_token(tokenizer, token_elegido_id),
                "logit": round(float(logits[0, token_elegido_id].item()), 6),
                "rango": rango_elegido,
                "probabilidad": round(
                    float(probabilidades[token_elegido_id].item()), 6
                ),
                "probabilidad_acumulada": 0.0,
                "elegido": True,
            }
        )
        predicciones_top[-1]["probabilidad_acumulada"] = round(
            float(probabilidades[orden[:rango_elegido]].sum().item()), 6
        )

    entropia_salida = float(
        -(probabilidades * torch.log(probabilidades + 1e-12)).sum().item()
    )
    atencion_encoder = _resumen_atencion_ultima_consulta(
        paso["pesos_atencion_encoder_por_capa"]
    )
    atencion_masked = _resumen_atencion_ultima_consulta(
        paso["pesos_autoatencion_por_capa"]
    )
    atencion_cruzada = _resumen_atencion_ultima_consulta(
        paso["pesos_atencion_cruzada_por_capa"]
    )

    etiquetas_entrada = [
        {
            "posicion": indice,
            "token_id": token_id,
            "texto": _texto_token(tokenizer, token_id),
        }
        for indice, token_id in enumerate(ids_entrada)
    ]
    ids_contexto_decoder = [int(id_token_inicio), *ids_generados[:-1]]
    etiquetas_decoder = [
        {
            "posicion": indice,
            "token_id": token_id,
            "texto": (
                "<inicio>"
                if indice == 0
                else _texto_token(tokenizer, token_id)
            ),
        }
        for indice, token_id in enumerate(ids_contexto_decoder)
    ]
    foco_entrada = _atencion_ultima_consulta(
        paso["pesos_atencion_cruzada_por_capa"], etiquetas_entrada
    )
    foco_decoder = _atencion_ultima_consulta(
        paso["pesos_autoatencion_por_capa"], etiquetas_decoder
    )

    modo_muestreo = "Codicioso" if muestreo_codicioso else "Muestreo"
    filtros = []
    if not muestreo_codicioso:
        filtros.append(f"T={float(temperatura):.2f}")
        if top_k is not None:
            filtros.append(f"Top-K {int(top_k)}")
        if top_p is not None:
            filtros.append(f"Top-P {float(top_p):.2f}")

    etapas = [
        {
            "numero": "01",
            "titulo": "Tokenización",
            "dato": f"{len(ids_entrada)} tokens",
            "explicacion": "El texto se separa en ids discretos que entiende el vocabulario.",
            "color": "#7C3AED",
        },
        {
            "numero": "02",
            "titulo": "Vectores + posición",
            "dato": f"{len(ids_entrada)} × {config.dimension_modelo}",
            "explicacion": "Cada id se vuelve un vector y recibe información de su orden.",
            "color": "#DB2777",
        },
        {
            "numero": "03",
            "titulo": "Encoder",
            "dato": f"{config.num_capas} capas × {config.num_cabezas} cabezas",
            "explicacion": "La autoatención construye una representación contextual del prompt.",
            "color": "#D97706",
        },
        {
            "numero": "04",
            "titulo": "Decoder",
            "dato": f"{len(ids_contexto_decoder)} posiciones",
            "explicacion": "Mira solo lo ya generado y consulta la representación del encoder.",
            "color": "#2563EB",
        },
        {
            "numero": "05",
            "titulo": "Linear + Softmax",
            "dato": f"{config.tamano_vocabulario} → {cantidad_candidatos}",
            "explicacion": "Asigna un puntaje a todo el vocabulario y lo convierte en probabilidades.",
            "color": "#059669",
        },
        {
            "numero": "06",
            "titulo": "Selección",
            "dato": _texto_token(tokenizer, token_elegido_id),
            "explicacion": "El token elegido se añade a la salida y vuelve a entrar al decoder.",
            "color": "#DC2626",
        },
    ]

    return {
        "paso": int(paso.get("paso", 0)) + 1,
        "token_elegido": {
            "token_id": token_elegido_id,
            "texto": _texto_token(tokenizer, token_elegido_id),
            "probabilidad": round(float(probabilidades[token_elegido_id].item()), 6),
            "rango": rango_elegido,
        },
        "tokens_entrada": tokens_entrada,
        "tokens_entrada_total": len(ids_entrada),
        "tokens_decoder": etiquetas_decoder,
        "tokens_salida": tokens_salida,
        "tokens_salida_total": len(ids_generados),
        "foco_entrada": foco_entrada,
        "foco_decoder": foco_decoder,
        "predicciones_top": predicciones_top,
        "cantidad_candidatos": cantidad_candidatos,
        "entropia_salida": round(entropia_salida, 5),
        "margen_top1_top2": round(
            float(probs_top[0].item() - probs_top[1].item())
            if probs_top.numel() > 1 else float(probs_top[0].item()),
            6,
        ),
        "modo_muestreo": modo_muestreo,
        "filtros": " · ".join(filtros) if filtros else "Sin filtros aleatorios",
        "atencion_por_bloque": {
            "encoder": atencion_encoder["capas"],
            "decoder": atencion_masked["capas"],
            "cruzada": atencion_cruzada["capas"],
        },
        "etapas": etapas,
        "validacion": {
            "probabilidades_suman_uno": math.isclose(
                float(probabilidades.sum().item()), 1.0, abs_tol=1e-5
            ),
            "suma_probabilidades": round(float(probabilidades.sum().item()), 8),
            "logits_sin_nan": not bool(torch.isnan(logits).any().item()),
        },
        "detalle_forward": _detalle_forward(modelo, paso),
    }


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


_CONCEPTO_POR_METRICA = {
    "Intensidad de aprendizaje (RMS)": "gradient_norm_rms",
    "Norma de pesos": "weight_norm",
    "Parámetros": "parameter_count",
    "Parámetros entrenables": "parameter_count",
    "Forma del batch": "epoch_batch",
    "Tokens únicos": "token_ids",
    "Dimensión del vector": "d_model",
    "Pesos compartidos": "capa_linear_salida",
    "Longitud usada": "context_window",
    "Amplitud RMS": "positional_encoding",
    "Entropía media": "interpretacion_pesos",
    "Mayor peso de atención": "interpretacion_pesos",
    "Cabezas × capas": "cabeza_atencion",
    "Máscara causal": "por_que_mascara",
    "Mapa Q × K": "producto_qk",
    "Expansión": "dimension_d_ff",
    "Activación": "activation_functions",
    "Forma de logits": "logits",
    "Desviación de logits": "logits",
    "Vocabulario": "tokenizacion",
    "Confianza top-1 media": "distribucion_probabilidades",
    "Probabilidad del objetivo": "cross_entropy",
    "Acierto top-1": "accuracy",
    "Entropía de salida": "distribucion_probabilidades",
    "Capas observadas": "layer_count",
    "Dimensión normalizada": "layer_normalization",
    "Dropout": "dropout",
}


def _metrica(
    etiqueta: str,
    valor,
    detalle: str = "",
    concepto_id: str | None = None,
) -> dict:
    if isinstance(valor, float):
        texto = _formatear_numero(valor)
    else:
        texto = str(valor)
    return {
        "etiqueta": etiqueta,
        "valor": texto,
        "detalle": detalle,
        "concepto_id": concepto_id or _CONCEPTO_POR_METRICA.get(etiqueta, ""),
    }


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

def extraer_nube_embeddings(
    embeddings: torch.Tensor,
    dimensiones: list[int],
    tokens_ids: list[int] | None = None,
    tokenizer=None,
    indice_batch: int = 0,
) -> dict:
    """Arma la nube de puntos 3D lista para el Lienzo Científico: la
    "sombra" de los embeddings sobre las 1-3 dimensiones elegidas, más
    el texto de cada token y cuánta información conserva esa vista.

    Args:
        embeddings: (B, T, d) o (T, d).
        dimensiones: 1 a 3 índices, mapeados a los ejes X, Y, Z.
        tokens_ids: ids de los tokens, para etiquetar cada punto. Si es
            None, los puntos van sin etiqueta.
        tokenizer: necesario solo si se pasan `tokens_ids`.
        indice_batch: cuál elemento del batch usar.

    Returns:
        Diccionario con:
        - "puntos": lista de [x, y, z] (o menos ejes si se eligieron
          menos dimensiones).
        - "etiquetas": texto de cada token, alineado con "puntos".
        - "dimensiones": los índices elegidos, para rotular los ejes.
        - "varianza_conservada": fracción en [0, 1] — la Vista debería
          mostrarla para que el usuario sepa qué tan parcial es la vista.
        - "limites": {"min": [...], "max": [...]} por eje, para encuadrar
          la cámara sin recalcularlo en QML.
    """
    puntos = tensor_to_array.proyeccion_dimensiones(
        embeddings, dimensiones, indice_batch=indice_batch
    )

    etiquetas: list[str] = []
    if tokens_ids is not None and tokenizer is not None:
        etiquetas = [tokenizer.decode([id_token]) for id_token in tokens_ids]

    return {
        "puntos": puntos.tolist(),
        "etiquetas": etiquetas,
        "dimensiones": list(dimensiones),
        "varianza_conservada": round(
            tensor_to_array.fraccion_varianza_conservada(
                embeddings, dimensiones, indice_batch=indice_batch
            ),
            4,
        ),
        "limites": {
            "min": puntos.min(axis=0).tolist(),
            "max": puntos.max(axis=0).tolist(),
        },
    }


def extraer_nube_pca(
    embeddings: torch.Tensor,
    tokens_ids: list[int] | None = None,
    tokenizer=None,
    ejes_previos=None,
    indice_batch: int = 0,
) -> dict:
    """Igual que `extraer_nube_embeddings` pero proyectando con PCA en
    vez de sobre dimensiones elegidas a mano.

    Para una vista EN VIVO durante el entrenamiento hay que reenviar
    `ejes` (que viene en el resultado) como `ejes_previos` en la llamada
    siguiente; si no, la nube parpadea reflejándose (ver
    `tensor_to_array.proyeccion_pca`).

    Returns:
        Los mismos campos que `extraer_nube_embeddings`, más:
        - "varianza_por_componente": fracción de cada eje.
        - "ejes": matriz de ejes, para encadenar el frame siguiente. NO
          es QML-safe (es un ndarray): se usa solo del lado de Python.
    """
    puntos, ejes, varianza = tensor_to_array.proyeccion_pca(
        embeddings, num_componentes=3, ejes_previos=ejes_previos, indice_batch=indice_batch
    )

    etiquetas: list[str] = []
    if tokens_ids is not None and tokenizer is not None:
        etiquetas = [tokenizer.decode([id_token]) for id_token in tokens_ids]

    return {
        "puntos": puntos.tolist(),
        "etiquetas": etiquetas,
        "modo": "pca",
        "varianza_conservada": round(float(varianza.sum()), 4),
        "varianza_por_componente": [round(float(v), 4) for v in varianza],
        "limites": {"min": puntos.min(axis=0).tolist(), "max": puntos.max(axis=0).tolist()},
        "ejes": ejes,
    }


def extraer_grupos_por_cabeza(dimension_modelo: int, num_cabezas: int) -> list[dict]:
    """Lista de cabezas con sus dimensiones, para que el selector de la
    Vista pueda ofrecer "Cabeza 0 (dims 0-7)" en vez de 32 números
    sueltos sin agrupar.

    Returns:
        Lista de `{"cabeza": int, "dimensiones": [...], "etiqueta": str}`.
    """
    grupos = []
    for indice in range(num_cabezas):
        dims = tensor_to_array.dimensiones_por_cabeza(dimension_modelo, num_cabezas, indice)
        grupos.append({
            "cabeza": indice,
            "dimensiones": dims,
            "etiqueta": f"Cabeza {indice} (dims {dims[0]}-{dims[-1]})",
        })
    return grupos


def extraer_ranking_dimensiones(
    embeddings: torch.Tensor,
    n: int = 10,
    indice_batch: int = 0,
) -> list[dict]:
    """Dimensiones ordenadas por varianza, de mayor a menor — para que
    el selector de la Vista pueda sugerir cuáles vale la pena mirar en
    vez de dejar al usuario probando a ciegas entre, por ejemplo, las
    4960 combinaciones posibles de 3 dimensiones sobre 32.

    Returns:
        Lista de `{"dimension": int, "varianza": float}`, de mayor a menor.
    """
    varianzas = tensor_to_array.varianza_por_dimension(embeddings, indice_batch=indice_batch)
    indices_ordenados = varianzas.argsort()[::-1][:n]
    return [
        {"dimension": int(indice), "varianza": round(float(varianzas[indice]), 6)}
        for indice in indices_ordenados
    ]

def extraer_nube_segun_modo(
    embeddings: torch.Tensor,
    config: dict,
    tokens_ids: list[int] | None = None,
    tokenizer=None,
    ejes_previos=None,
) -> dict:
    """Despacha al modo de proyección pedido por la Vista.

    `config` es el snapshot que el hilo trabajador tomó bajo lock:
    `{"modo": "pca"|"ejes", "dimensiones": [...]}`. El modo "cabeza" no
    necesita rama propia: la Vista ya resuelve qué dimensiones ocupa la
    cabeza (`extraer_grupos_por_cabeza`) y las manda como "ejes".
    """
    if config.get("modo") == "pca":
        return extraer_nube_pca(
            embeddings, tokens_ids=tokens_ids, tokenizer=tokenizer, ejes_previos=ejes_previos
        )

    dimensiones = config.get("dimensiones") or [0, 1, 2]
    resultado = extraer_nube_embeddings(
        embeddings, dimensiones, tokens_ids=tokens_ids, tokenizer=tokenizer
    )
    resultado["modo"] = "ejes"
    return resultado
