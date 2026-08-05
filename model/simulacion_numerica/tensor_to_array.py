"""
Manejo de Simulaciones Numéricas.

Transforma los tensores crudos del modelo (matrices de atención,
logits) en arreglos numéricos (`numpy.ndarray`) — el cómputo real
(promediar cabezas, entropía de Shannon, softmax + top-k) vive acá.

Este módulo es parte del MODELO: no importa nada de `view/` ni
`viewmodel/`, no sabe qué es QML ni Qt, y no decodifica texto (eso
necesita el `Tokenizer`, que es una decisión de más arriba en la
pila — ver `viewmodel/visual_adapter.py`, que sí tiene acceso al
tokenizer del modelo actual y arma el resultado final para la Vista).

Devuelve `numpy.ndarray`/`float`/`int` — nunca listas de Python ni
diccionarios pensados para QML; esa conversión final es responsabilidad
de `visual_adapter.py`.
"""

import numpy as np
import torch


def tensor_a_numpy(tensor: torch.Tensor) -> np.ndarray:
    """Desconecta un tensor del grafo de autograd y de la GPU, y lo
    convierte a `numpy.ndarray`. Punto de entrada genérico — para casos
    específicos (matrices de atención, logits) usar las funciones de
    abajo, que ya seleccionan la dimensión correcta."""
    return tensor.detach().cpu().numpy()


def mapa_atencion(
    pesos_atencion: torch.Tensor,
    indice_cabeza: int | None = None,
    indice_batch: int = 0,
) -> np.ndarray:
    """Extrae UNA matriz 2D (T_consulta x T_clave) de un tensor de pesos
    de atención con forma (B, num_cabezas, T_q, T_k).

    Args:
        pesos_atencion: tensor con forma (B, num_cabezas, T_q, T_k),
            como los que expone `AtencionMultiCabeza.ultimos_pesos_atencion`.
        indice_cabeza: qué cabeza extraer. Si es None, se promedian
            TODAS las cabezas (una vista "resumen" en vez de una
            cabeza específica).
        indice_batch: qué elemento del batch (normalmente 0, ya que la
            inferencia interactiva usa batch_size=1).

    Returns:
        `numpy.ndarray` de forma (T_q, T_k), valores en [0, 1] (cada
        fila es una distribución de probabilidad post-softmax).

    Raises:
        IndexError: si `indice_cabeza` o `indice_batch` están fuera de rango.
    """
    matriz = pesos_atencion[indice_batch]  # (num_cabezas, T_q, T_k)

    if indice_cabeza is not None:
        matriz = matriz[indice_cabeza]  # (T_q, T_k)
    else:
        matriz = matriz.mean(dim=0)  # promedio sobre cabezas -> (T_q, T_k)

    return tensor_a_numpy(matriz)


def mapa_atencion_por_capa(
    pesos_por_capa: list[torch.Tensor],
    indice_capa: int,
    indice_cabeza: int | None = None,
    indice_batch: int = 0,
) -> np.ndarray:
    """Igual que `mapa_atencion`, pero eligiendo una capa específica de
    la lista que devuelven `Encoder.pesos_atencion_por_capa()` /
    `Decoder.pesos_autoatencion_por_capa()` / `Decoder.pesos_atencion_cruzada_por_capa()`
    (y las claves equivalentes en los diccionarios `paso` que emiten
    `InferenceController`/`TrainingController`).

    Raises:
        IndexError: si `indice_capa` está fuera de rango.
        ValueError: si la capa pedida no tiene pesos calculados todavía
            (None — pasa si nunca se corrió un forward por esa capa).
    """
    if not 0 <= indice_capa < len(pesos_por_capa):
        raise IndexError(
            f"indice_capa={indice_capa} fuera de rango (hay {len(pesos_por_capa)} capas)"
        )

    pesos_capa = pesos_por_capa[indice_capa]
    if pesos_capa is None:
        raise ValueError(f"La capa {indice_capa} todavía no tiene pesos de atención calculados.")

    return mapa_atencion(pesos_capa, indice_cabeza=indice_cabeza, indice_batch=indice_batch)


def entropia_atencion(
    pesos_atencion: torch.Tensor,
    indice_cabeza: int | None = None,
    indice_batch: int = 0,
) -> float:
    """Entropía de Shannon de la distribución de atención — cuánto se
    "reparte" la atención entre posiciones (alta entropía = atención
    difusa; baja entropía = atención concentrada). Se promedia sobre
    todas las posiciones de consulta para dar un único número resumen.

    Returns:
        Entropía promedio en nats (logaritmo natural), >= 0. 0 = atención
        completamente concentrada en un solo token; el máximo posible es
        log(T_k) (atención perfectamente uniforme entre T_k posiciones).
    """
    matriz = pesos_atencion[indice_batch]
    if indice_cabeza is not None:
        matriz = matriz[indice_cabeza]
    else:
        matriz = matriz.mean(dim=0)

    # Evitar log(0): las posiciones con peso exactamente 0 (ej.
    # enmascaradas por la mascara causal) no deben romper el logaritmo.
    epsilon = 1e-12
    entropia_por_fila = -(matriz * torch.log(matriz + epsilon)).sum(dim=-1)
    return entropia_por_fila.mean().item()


def probabilidades_top_n(
    logits: torch.Tensor,
    n: int = 10,
    indice_batch: int = 0,
) -> tuple[np.ndarray, np.ndarray]:
    """Aplica softmax a los logits y devuelve los `n` ids con mayor
    probabilidad. NO decodifica a texto — eso requiere el `Tokenizer`,
    que este módulo no conoce (ver `visual_adapter.py`).

    Args:
        logits: forma (B, tamano_vocabulario).
        n: cuántos candidatos devolver (si el vocabulario tiene menos
            de `n` tokens, se devuelven todos).
        indice_batch: idem que en las funciones anteriores.

    Returns:
        Tupla `(ids, probabilidades)`, ambos `numpy.ndarray` de forma
        `(min(n, tamano_vocabulario),)`, ordenados de mayor a menor
        probabilidad.
    """
    probabilidades = torch.softmax(logits[indice_batch], dim=-1)
    valores, indices = torch.topk(probabilidades, min(n, probabilidades.size(-1)))
    return indices.cpu().numpy(), valores.cpu().numpy()