"""
Muestreo: convierte los logits crudos del modelo en un token concreto
durante la generación autoregresiva.

Durante el ENTRENAMIENTO no se usa nada de este archivo — se conoce el
token correcto de antemano y se optimiza con `calcular_perdida`
(cross-entropy) en `transformer.py`. Este archivo solo entra en juego en
INFERENCIA, cuando el modelo tiene que elegir un token sin saber la
"respuesta correcta".

Las tres técnicas se aplican en este orden, cada una recibe la salida de
la anterior:

1. Temperatura: escala los logits antes del softmax (afila/aplana la
   distribución de probabilidad).
2. Top-k / Top-p: recortan la distribución a un subconjunto de
   candidatos plausibles (se puede usar una, otra, ambas, o ninguna).
3. Muestreo final: se saca un token al azar de la distribución ya
   filtrada.
"""

import torch
import torch.nn.functional as F


def aplicar_temperatura(logits: torch.Tensor, temperatura: float) -> torch.Tensor:
    """Escala los logits por la temperatura antes del softmax.

    temperatura < 1.0 afila la distribución (más determinista, el token
    más probable domina más). temperatura > 1.0 la aplana (más
    aleatorio/creativo). temperatura == 1.0 no cambia nada.

    Args:
        logits: forma (..., tamano_vocabulario).
        temperatura: valor > 0. Ver `core/constants.py` para los límites
            (`TEMPERATURA_MIN`, `TEMPERATURA_MAX`) que expone la Vista.

    Returns:
        Logits escalados, misma forma que la entrada.
    """
    if temperatura <= 0:
        raise ValueError(f"temperatura debe ser > 0, recibido: {temperatura}")

    return logits / temperatura


def filtrar_top_k(logits: torch.Tensor, k: int) -> torch.Tensor:
    """Deja solo los `k` tokens con mayor logit; el resto se pone en
    -infinito (probabilidad 0 después del softmax).

    Args:
        logits: forma (..., tamano_vocabulario).
        k: cantidad de candidatos a conservar. Si `k` es mayor o igual
            al tamaño del vocabulario, no se filtra nada (se retorna
            una copia sin cambios).

    Returns:
        Logits filtrados, misma forma que la entrada.
    """
    if k <= 0:
        raise ValueError(f"k debe ser > 0, recibido: {k}")

    tamano_vocabulario = logits.size(-1)
    if k >= tamano_vocabulario:
        return logits.clone()

    valores_top_k, _ = torch.topk(logits, k, dim=-1)
    # El k-esimo valor mas alto es el umbral: todo lo que quede POR
    # DEBAJO de el se descarta.
    umbral = valores_top_k[..., -1, None]
    return logits.masked_fill(logits < umbral, float("-inf"))


def filtrar_top_p(logits: torch.Tensor, p: float) -> torch.Tensor:
    """Nucleus sampling: conserva el conjunto MÁS PEQUEÑO de tokens
    (ordenados de mayor a menor probabilidad) cuya probabilidad
    acumulada supera `p`. El resto se pone en -infinito.

    A diferencia de top-k (cantidad fija de candidatos), top-p se adapta:
    si el modelo está muy seguro (una probabilidad domina), el conjunto
    puede ser de 1-2 tokens; si está indeciso (distribución plana), el
    conjunto puede ser mucho más grande.

    Args:
        logits: forma (..., tamano_vocabulario).
        p: valor en (0, 1]. p=1.0 no filtra nada.

    Returns:
        Logits filtrados, misma forma que la entrada.
    """
    if not (0 < p <= 1):
        raise ValueError(f"p debe estar en (0, 1], recibido: {p}")

    if p == 1.0:
        return logits.clone()

    logits_ordenados, indices_ordenados = torch.sort(logits, descending=True, dim=-1)
    probabilidades_ordenadas = F.softmax(logits_ordenados, dim=-1)
    probabilidad_acumulada = torch.cumsum(probabilidades_ordenadas, dim=-1)

    # Se descarta un token si la probabilidad acumulada JUSTO ANTES de el
    # ya superaba p (es decir, el "nucleo" ya estaba completo sin el).
    # Por eso se desplaza la mascara una posicion a la derecha: el primer
    # token que hace superar el umbral SIEMPRE se conserva (garantiza que
    # el conjunto nunca quede vacio).
    mascara_a_eliminar = probabilidad_acumulada - probabilidades_ordenadas > p

    logits_ordenados = logits_ordenados.masked_fill(mascara_a_eliminar, float("-inf"))

    # Deshacer el ordenamiento para volver al orden original del vocabulario.
    logits_filtrados = torch.full_like(logits, float("-inf"))
    logits_filtrados.scatter_(-1, indices_ordenados, logits_ordenados)
    return logits_filtrados


def muestrear(
    logits: torch.Tensor,
    temperatura: float = 1.0,
    top_k: int | None = None,
    top_p: float | None = None,
) -> torch.Tensor:
    """Pipeline completo: temperatura -> top-k -> top-p -> muestreo final.

    Args:
        logits: forma (B, tamano_vocabulario) — logits del ÚLTIMO token
            de la secuencia (el que se está prediciendo ahora).
        temperatura: ver `aplicar_temperatura`.
        top_k: si no es None, ver `filtrar_top_k`.
        top_p: si no es None, ver `filtrar_top_p`.

    Returns:
        Tensor de forma (B, 1) con el id del token muestreado para cada
        elemento del batch.
    """
    logits = aplicar_temperatura(logits, temperatura)

    if top_k is not None:
        logits = filtrar_top_k(logits, top_k)

    if top_p is not None:
        logits = filtrar_top_p(logits, top_p)

    probabilidades = F.softmax(logits, dim=-1)
    return torch.multinomial(probabilidades, num_samples=1)


def muestrear_codicioso(logits: torch.Tensor) -> torch.Tensor:
    """Muestreo "greedy": siempre elige el token de mayor probabilidad,
    sin aleatoriedad. Equivalente a `muestrear` con una temperatura que
    tiende a 0, pero exacto y determinista (útil para pruebas
    reproducibles o cuando el usuario quiere la salida "más probable"
    sin variación entre ejecuciones).

    Args:
        logits: forma (B, tamano_vocabulario).

    Returns:
        Tensor de forma (B, 1) con el id del token de mayor probabilidad.
    """
    return torch.argmax(logits, dim=-1, keepdim=True)