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

def proyeccion_dimensiones(
    embeddings: torch.Tensor,
    dimensiones: list[int],
    indice_batch: int = 0,
) -> np.ndarray:
    """Proyecta embeddings de dimensión `d` sobre las 1-3 dimensiones
    elegidas — la "sombra" del vector sobre ese subespacio coordenado.

    Matemáticamente es una proyección ortogonal: la matriz de proyección
    tiene como filas los vectores base `e_i` de las dimensiones pedidas,
    que son ortonormales entre sí. Por eso no distorsiona escalas: los
    ejes del gráfico están en las mismas unidades que el embedding
    original.

    Consecuencia importante para interpretar la vista: una proyección es
    CONTRACTIVA (nunca agranda distancias). Dos tokens que se ven
    separados en la sombra están realmente separados en el espacio
    completo; pero dos que se ven juntos pueden estar lejísimos en las
    dimensiones que no se están mostrando. Ver `varianza_por_dimension`
    para cuantificar cuánta información queda fuera.

    Args:
        embeddings: tensor de forma (B, T, d) o (T, d).
        dimensiones: 1 a 3 índices de dimensión, en el orden en que se
            quieren mapear a los ejes X, Y, Z. Se admiten repetidos
            (proyectar la misma dimensión en dos ejes es válido, aunque
            colapsa los puntos sobre una diagonal).
        indice_batch: cuál elemento del batch usar, si el tensor es 3D.

    Returns:
        `numpy.ndarray` de forma (T, len(dimensiones)).

    Raises:
        ValueError: si `dimensiones` está vacío o tiene más de 3 índices.
        IndexError: si algún índice está fuera del rango del embedding.
    """
    if not 1 <= len(dimensiones) <= 3:
        raise ValueError(
            f"Se pueden elegir entre 1 y 3 dimensiones, recibidas: {len(dimensiones)}"
        )

    matriz = embeddings[indice_batch] if embeddings.dim() == 3 else embeddings
    dimension_total = matriz.size(-1)

    for dim in dimensiones:
        if not 0 <= dim < dimension_total:
            raise IndexError(
                f"La dimensión {dim} está fuera de rango "
                f"(el embedding tiene {dimension_total} dimensiones: 0 a {dimension_total - 1})"
            )

    return tensor_a_numpy(matriz[:, dimensiones])


def varianza_por_dimension(
    embeddings: torch.Tensor,
    indice_batch: int = 0,
) -> np.ndarray:
    """Varianza de cada dimensión a lo largo de los tokens.

    Sirve para dos cosas en la Vista: ordenar las dimensiones por cuánta
    información aportan (las de varianza casi nula son ejes "muertos",
    donde todos los tokens caen en el mismo punto), y calcular qué
    fracción del total conserva una selección de 3 — ver
    `fraccion_varianza_conservada`.

    Returns:
        `numpy.ndarray` de forma (d,), no negativo.
    """
    matriz = embeddings[indice_batch] if embeddings.dim() == 3 else embeddings
    return tensor_a_numpy(matriz.var(dim=0, unbiased=False))


def fraccion_varianza_conservada(
    embeddings: torch.Tensor,
    dimensiones: list[int],
    indice_batch: int = 0,
) -> float:
    """Qué fracción de la varianza total conservan las dimensiones
    elegidas — es decir, cuánta de la "forma" real de la nube de puntos
    sobrevive en la sombra 3D.

    Con embeddings poco estructurados, elegir 3 de 32 dimensiones ronda
    3/32 ≈ 9%: la vista es honesta pero parcial. Valores mucho más altos
    indican que esas dimensiones concentran buena parte de la señal.

    Returns:
        Float en [0, 1]. Devuelve 0.0 si la varianza total es cero (todos
        los tokens tienen exactamente el mismo embedding), en vez de
        dividir por cero.
    """
    varianzas = varianza_por_dimension(embeddings, indice_batch=indice_batch)
    total = float(varianzas.sum())
    if total <= 0.0:
        return 0.0
    return float(varianzas[list(dimensiones)].sum() / total)


def dimensiones_por_cabeza(dimension_modelo: int, num_cabezas: int, indice_cabeza: int) -> list[int]:
    """Índices de dimensión que ocupa una cabeza de atención concreta.

    `AtencionMultiCabeza` reparte el vector con
    `x.view(b, t, num_cabezas, dimension_cabeza)`, así que cada cabeza
    usa un bloque CONTIGUO: con dimension_modelo=32 y num_cabezas=4, la
    cabeza 0 son las dims 0-7, la 1 las 8-15, etc.

    Proyectar sobre dimensiones de una misma cabeza no es una elección
    arbitraria: es mirar el subespacio donde esa cabeza opera realmente.

    Raises:
        IndexError: si `indice_cabeza` está fuera de rango.
    """
    if not 0 <= indice_cabeza < num_cabezas:
        raise IndexError(
            f"indice_cabeza={indice_cabeza} fuera de rango (hay {num_cabezas} cabezas)"
        )
    dimension_cabeza = dimension_modelo // num_cabezas
    inicio = indice_cabeza * dimension_cabeza
    return list(range(inicio, inicio + dimension_cabeza))


def proyeccion_pca(
    embeddings: torch.Tensor,
    num_componentes: int = 3,
    ejes_previos: np.ndarray | None = None,
    indice_batch: int = 0,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Proyecta sobre las direcciones de máxima varianza (PCA).

    A diferencia de `proyeccion_dimensiones`, los ejes NO son
    dimensiones originales sino combinaciones de todas — se pierde el
    "esta es la dimensión 4" a cambio de conservar mucha más varianza
    (en datos con estructura real, la diferencia puede ser de 4-7x).

    ## Estabilización de signo (importante para vistas en vivo)

    El signo de cada eje que devuelve SVD es arbitrario: recalcular PCA
    en cada paso de entrenamiento produce inversiones constantes (medido:
    ~216 inversiones en 200 pasos), y la nube "salta" reflejada en
    pantalla aunque los embeddings apenas cambien. Pasando `ejes_previos`
    (los del frame anterior) se alinea el signo de cada eje nuevo con el
    anterior, y la animación queda continua.

    Args:
        embeddings: (B, T, d) o (T, d).
        num_componentes: cuántas componentes principales (típicamente 3).
        ejes_previos: matriz `(num_componentes, d)` devuelta por la
            llamada anterior. None en el primer frame.
        indice_batch: cuál elemento del batch usar.

    Returns:
        Tupla `(puntos, ejes, varianza_explicada)`:
        - puntos: `(T, num_componentes)`, las coordenadas a graficar.
        - ejes: `(num_componentes, d)`, para pasar como `ejes_previos`
          en la siguiente llamada.
        - varianza_explicada: `(num_componentes,)`, fracción por componente.

    Raises:
        ValueError: si se piden más componentes que dimensiones disponibles.
    """
    matriz = embeddings[indice_batch] if embeddings.dim() == 3 else embeddings
    datos = tensor_a_numpy(matriz).astype(np.float64)

    num_tokens, dimension = datos.shape
    maximo_componentes = min(num_tokens, dimension)
    if num_componentes > maximo_componentes:
        raise ValueError(
            f"No se pueden extraer {num_componentes} componentes de una matriz "
            f"{num_tokens}x{dimension} (máximo: {maximo_componentes})"
        )

    centrado = datos - datos.mean(axis=0)
    _, valores_singulares, vt = np.linalg.svd(centrado, full_matrices=False)

    ejes = vt[:num_componentes]

    if ejes_previos is not None:
        # Alinear el signo con el frame anterior: si el eje nuevo apunta
        # en sentido contrario al viejo, se invierte. No cambia la
        # geometria (un eje y su opuesto generan la misma recta), solo
        # evita el salto visual.
        for i in range(min(len(ejes), len(ejes_previos))):
            if float(ejes[i] @ ejes_previos[i]) < 0:
                ejes[i] = -ejes[i]

    puntos = centrado @ ejes.T

    varianzas = valores_singulares**2
    total = varianzas.sum()
    varianza_explicada = (
        varianzas[:num_componentes] / total if total > 0 else np.zeros(num_componentes)
    )

    return puntos, ejes, varianza_explicada