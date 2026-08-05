"""
Adaptador Visual.

Capa DELGADA sobre `model/simulacion_numerica/tensor_to_array.py`: el
cómputo numérico real (promediar cabezas, entropía, softmax + top-k)
vive ahí, en el Modelo. Este módulo solo hace dos cosas que sí son del
ViewModel:

1. Convertir los `numpy.ndarray` que devuelve `tensor_to_array.py` a
   listas de Python — un `numpy.ndarray` tampoco es un tipo que QML
   pueda usar directamente, igual que un `torch.Tensor`.
2. Combinar esos números con cosas que el Modelo no conoce (como el
   `Tokenizer`, para decodificar ids a texto legible).

Son funciones puras, no una clase con estado ni señales.
"""

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