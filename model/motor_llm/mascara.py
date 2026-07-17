"""
Máscaras de atención.

Un LLM autoregresivo (decoder-only, estilo GPT) necesita impedir que cada
posición "vea" tokens futuros durante el entrenamiento y la inferencia.
Esto se logra con una máscara causal que se suma a los scores de atención
antes del softmax, poniendo en -infinito las posiciones prohibidas.

Si además entrenas con batches de longitud variable (secuencias más
cortas rellenadas con un token de relleno), necesitas una máscara de
relleno adicional para que el modelo tampoco atienda a esas posiciones
"falsas".
"""

import torch


def crear_mascara_causal(longitud_secuencia: int, dispositivo: torch.device | None = None) -> torch.Tensor:
    """Crea una máscara causal (triangular) para atención autoregresiva.

    Args:
        longitud_secuencia: longitud de la secuencia (T).
        dispositivo: dispositivo donde crear el tensor (cpu/cuda).

    Returns:
        Tensor booleano de forma (T, T) donde `True` indica una posición
        PERMITIDA (el token i puede atender al token j si j <= i) y
        `False` indica una posición que debe bloquearse (j > i, futuro).
    """
    return torch.tril(
        torch.ones(longitud_secuencia, longitud_secuencia, dtype=torch.bool, device=dispositivo)
    )


def crear_mascara_relleno(tokens: torch.Tensor, id_token_relleno: int) -> torch.Tensor:
    """Crea una máscara de relleno (padding) a partir de los ids de tokens.

    Args:
        tokens: tensor de ids de forma (B, T).
        id_token_relleno: id reservado para el token de relleno.

    Returns:
        Tensor booleano de forma (B, 1, 1, T) donde `True` indica una
        posición real (atendible) y `False` una posición de relleno.
        La forma con dimensiones extra (1, 1) permite hacer broadcast
        directo contra los scores de atención (B, num_cabezas, T, T).
    """
    mascara = tokens != id_token_relleno
    return mascara[:, None, None, :]


def combinar_mascaras(
    mascara_causal: torch.Tensor,
    mascara_relleno: torch.Tensor | None = None,
) -> torch.Tensor:
    """Combina la máscara causal con la de relleno (si existe) vía AND lógico.

    Args:
        mascara_causal: forma (T, T).
        mascara_relleno: forma (B, 1, 1, T) o None si no hay padding.

    Returns:
        Tensor booleano combinado, listo para pasar a `atencion_escalada`.
        Si no hay máscara de relleno, retorna la causal sin modificar
        (se le hace broadcast automáticamente contra el batch).
    """
    if mascara_relleno is None:
        return mascara_causal
    return mascara_causal & mascara_relleno