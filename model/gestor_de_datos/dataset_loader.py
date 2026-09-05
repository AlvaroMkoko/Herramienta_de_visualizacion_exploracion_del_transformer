"""
Carga de datasets: convierte pares de texto (origen, destino) en batches
de tensores listos para `Transformer.forward` / `calcular_perdida`.

## El problema de los tokens especiales (resuelto aquí)

`tiktoken` no reserva ningún id de su vocabulario para relleno (padding),
inicio o fin de secuencia — todos los ids corresponden a texto real.
Para poder entrenar el Transformer necesitamos TRES ids especiales que
no choquen con ningún token real, así que este módulo reserva tres ids
EXTRA, más allá del vocabulario real del tokenizador:

    id_token_relleno = tokenizer.vocab_size      (padding)
    id_token_inicio  = tokenizer.vocab_size + 1  (inicio de la secuencia destino, "BOS")
    id_token_fin     = tokenizer.vocab_size + 2  (fin de la secuencia destino, "EOS")
    tamano_vocabulario_total = tokenizer.vocab_size + 3

Por eso, al construir la `ConfiguracionTransformer` para un modelo que
va a entrenar con este loader, hay que usar:

    ConfiguracionTransformer(
        tamano_vocabulario=obtener_tamano_vocabulario_total(tokenizer),
        id_token_relleno=obtener_id_token_relleno(tokenizer),
        ...
    )

y pasarle `obtener_id_token_inicio(tokenizer)` / `obtener_id_token_fin(tokenizer)`
a `DatasetSecuencias` y luego a `Transformer.generar()` — usar SIEMPRE
estas tres funciones (nunca ids arbitrarios elegidos a mano) es lo que
garantiza que ningún id especial se salga del rango del vocabulario del
modelo ni choque con un token real.

## Formato de cada ejemplo (entrenamiento con "teacher forcing")

Para cada par (texto_origen, texto_destino):

    tokens_destino_completos = [id_token_inicio] + encode(texto_destino) + [id_token_fin]
    tokens_destino_entrada   = tokens_destino_completos[:-1]   # lo que RECIBE el decoder
    tokens_destino_objetivo  = tokens_destino_completos[1:]    # lo que DEBE predecir

Esto es exactamente el "Outputs (shifted right)" del diagrama original:
el objetivo es la misma secuencia de destino, desplazada una posición.
"""

import csv
import json
from pathlib import Path
from typing import Any

import torch
from torch.utils.data import DataLoader, Dataset

from model.motor_llm.tokenizer import Tokenizer
from pypdf import PdfReader

# ---------------------------------------------------------------------------
# Resolución de los tokens especiales (ver docstring del módulo)
# ---------------------------------------------------------------------------


def obtener_id_token_relleno(tokenizer: Tokenizer) -> int:
    """Id reservado para relleno (padding)."""
    return tokenizer.vocab_size


def obtener_id_token_inicio(tokenizer: Tokenizer) -> int:
    """Id reservado para marcar el inicio de la secuencia de destino (BOS)."""
    return tokenizer.vocab_size + 1


def obtener_id_token_fin(tokenizer: Tokenizer) -> int:
    """Id reservado para marcar el fin de la secuencia de destino (EOS)."""
    return tokenizer.vocab_size + 2


def obtener_tamano_vocabulario_total(tokenizer: Tokenizer) -> int:
    """Tamaño de vocabulario a usar en `ConfiguracionTransformer`,
    incluyendo los 3 ids extra reservados (relleno, inicio, fin)."""
    return tokenizer.vocab_size + 3


# ---------------------------------------------------------------------------
# Carga de pares (origen, destino) desde distintas fuentes
# ---------------------------------------------------------------------------


def cargar_pares_desde_listas(origenes: list[str], destinos: list[str]) -> list[tuple[str, str]]:
    """Empareja dos listas paralelas de strings.

    Raises:
        ValueError: si las listas no tienen la misma longitud.
    """
    if len(origenes) != len(destinos):
        raise ValueError(
            f"origenes y destinos deben tener la misma longitud "
            f"({len(origenes)} != {len(destinos)})"
        )
    return list(zip(origenes, destinos))


def cargar_pares_desde_csv(
    ruta: str | Path,
    columna_origen: str,
    columna_destino: str,
    delimitador: str = ",",
    columna_contexto: str | None = None,
) -> list[tuple[str, str]]:
    """Carga pares desde un CSV con encabezado.

    Args:
        ruta: archivo .csv.
        columna_origen, columna_destino: nombres de columna del encabezado.
        delimitador: separador de campos (',' por defecto, usar '\\t' para TSV).
        columna_contexto: columna opcional que se concatena a la entrada cuando
            contiene texto. No es obligatorio que exista en el archivo.

    Raises:
        FileNotFoundError: si `ruta` no existe.
        KeyError: si las columnas indicadas no están en el encabezado.
        ValueError: si una fila no contiene texto en origen/destino o si el
            contexto presente no es texto.
    """
    ruta = Path(ruta)
    if not ruta.exists():
        raise FileNotFoundError(f"No se encontró el archivo: {ruta}")

    pares = []
    with ruta.open(encoding="utf-8", newline="") as archivo:
        lector = csv.DictReader(archivo, delimiter=delimitador)
        if lector.fieldnames is None or (
            columna_origen not in lector.fieldnames or columna_destino not in lector.fieldnames
        ):
            raise KeyError(
                f"El CSV debe tener las columnas '{columna_origen}' y '{columna_destino}'. "
                f"Columnas encontradas: {lector.fieldnames}"
            )
        for numero_fila, fila in enumerate(lector, start=2):
            origen = fila[columna_origen]
            destino = fila[columna_destino]
            contexto = fila.get(columna_contexto, "") if columna_contexto else ""
            if not isinstance(origen, str) or not origen.strip():
                raise ValueError(
                    f"Fila {numero_fila} de {ruta.name}: '{columna_origen}' debe contener texto."
                )
            if not isinstance(destino, str) or not destino.strip():
                raise ValueError(
                    f"Fila {numero_fila} de {ruta.name}: '{columna_destino}' debe contener texto."
                )
            if not isinstance(contexto, str):
                raise ValueError(
                    f"Fila {numero_fila} de {ruta.name}: el contexto debe ser texto."
                )
            if contexto.strip():
                origen = f"{origen}\n{contexto}"
            pares.append((origen, destino))

    return pares


def cargar_pares_desde_json(
    ruta: str | Path,
    clave_origen: str,
    clave_destino: str,
    clave_contexto: str | None = None,
) -> list[tuple[str, str]]:
    """Carga pares desde un JSON que contiene una lista de objetos, ej.:

        [{"pregunta": "...", "respuesta": "..."}, ...]

    Args:
        ruta: archivo .json.
        clave_origen, clave_destino: claves de cada objeto de la lista.
        clave_contexto: clave opcional que se concatena al origen cuando no
            está vacía.

    Raises:
        FileNotFoundError: si `ruta` no existe.
        ValueError: si el JSON no es una lista de objetos, o falta alguna clave.
    """
    ruta = Path(ruta)
    if not ruta.exists():
        raise FileNotFoundError(f"No se encontró el archivo: {ruta}")

    with ruta.open(encoding="utf-8") as archivo:
        datos: Any = json.load(archivo)

    if not isinstance(datos, list):
        raise ValueError("El JSON debe ser una lista de objetos, ej. [{...}, {...}]")

    return _pares_desde_objetos(datos, clave_origen, clave_destino, clave_contexto)


def cargar_pares_desde_jsonl(
    ruta: str | Path,
    clave_origen: str,
    clave_destino: str,
    clave_contexto: str | None = None,
) -> list[tuple[str, str]]:
    """Carga pares desde un archivo JSONL (JSON Lines): UN objeto JSON por
    línea, sin corchetes envolventes ni comas entre líneas — el formato
    típico de datasets grandes tipo Dolly, ej.:

        {"instruction": "...", "context": "", "response": "...", "category": "..."}
        {"instruction": "...", "context": "...", "response": "...", "category": "..."}

    Args:
        ruta: archivo .jsonl.
        clave_origen: clave del texto de entrada (ej. "instruction").
        clave_destino: clave del texto esperado (ej. "response").
        clave_contexto: clave opcional con información adicional (ej.
            "context"). Si se indica y el valor NO está vacío para un
            ejemplo dado, se concatena al origen como
            "{origen}\\n{contexto}"; si está vacío (común en datasets
            tipo Dolly, donde muchas filas tienen `context: ""`), se usa
            solo el origen tal cual. Si `clave_contexto` es None, se
            ignora por completo (comportamiento anterior).

    Raises:
        FileNotFoundError: si `ruta` no existe.
        ValueError: si alguna línea no es JSON válido, o falta alguna clave.
    """
    ruta = Path(ruta)
    if not ruta.exists():
        raise FileNotFoundError(f"No se encontró el archivo: {ruta}")

    objetos = []
    with ruta.open(encoding="utf-8") as archivo:
        for numero_linea, linea in enumerate(archivo, start=1):
            linea = linea.strip()
            if not linea:  # tolera líneas en blanco al final del archivo
                continue
            try:
                objetos.append(json.loads(linea))
            except json.JSONDecodeError as error:
                raise ValueError(f"Línea {numero_linea} de {ruta} no es JSON válido: {error}") from error

    return _pares_desde_objetos(objetos, clave_origen, clave_destino, clave_contexto)


def _pares_desde_objetos(
    objetos: list[dict],
    clave_origen: str,
    clave_destino: str,
    clave_contexto: str | None = None,
) -> list[tuple[str, str]]:
    """Lógica compartida entre `cargar_pares_desde_json` y
    `cargar_pares_desde_jsonl` para extraer pares (origen, destino) de
    una lista de objetos, con concatenación opcional de contexto."""
    pares = []
    for i, objeto in enumerate(objetos):
        if not isinstance(objeto, dict):
            raise ValueError(f"El objeto en la posición {i} debe ser un objeto JSON.")
        if clave_origen not in objeto or clave_destino not in objeto:
            raise ValueError(
                f"El objeto en la posición {i} no tiene las claves "
                f"'{clave_origen}' y '{clave_destino}': {objeto}"
            )

        origen = objeto[clave_origen]
        destino = objeto[clave_destino]
        if not isinstance(origen, str) or not origen.strip():
            raise ValueError(
                f"El campo '{clave_origen}' del objeto en la posición {i} debe contener texto."
            )
        if not isinstance(destino, str) or not destino.strip():
            raise ValueError(
                f"El campo '{clave_destino}' del objeto en la posición {i} debe contener texto."
            )
        if clave_contexto is not None:
            contexto = objeto.get(clave_contexto, "")
            if not isinstance(contexto, str):
                raise ValueError(
                    f"El campo '{clave_contexto}' del objeto en la posición {i} debe ser texto."
                )
            if contexto.strip():
                origen = f"{origen}\n{contexto}"

        pares.append((origen, destino))

    return pares


# ---------------------------------------------------------------------------
# Texto corrido (.txt / .pdf) -> pares, para cuando NO hay datos ya
# emparejados (traducción, preguntas/respuestas), sino un corpus de texto
# continuo (un libro, artículos, documentación).
# ---------------------------------------------------------------------------

def cargar_pares_combinados(
    rutas_y_formatos: list[tuple[str, str]],
    tokenizer: "Tokenizer | None" = None,
    clave_origen: str = "instruction",
    clave_destino: str = "response",
    clave_contexto: str | None = "context",
    longitud_ventana: int = 128,
    solapamiento: int = 0,
) -> list[tuple[str, str]]:
    """Combina los pares de VARIOS archivos en una sola lista — pensado
    para cuando el usuario selecciona más de un dataset del catálogo y
    quiere entrenar con todos juntos.

    Args:
        rutas_y_formatos: lista de (ruta, formato), donde `formato` es
            la extensión TAL CUAL la guarda `DatasetController`
            (con el punto: ".jsonl", ".json", ".csv", ".txt", ".pdf" —
            así es como viene de `Path(...).suffix`).
        tokenizer: OBLIGATORIO si hay algún archivo .txt/.pdf en la
            lista (hace falta para tokenizar el texto corrido en
            ventanas) — debe ser el tokenizer del MODELO que se va a
            entrenar, no uno nuevo desconectado.
        clave_origen, clave_destino, clave_contexto: nombres de campo
            para los formatos .jsonl/.json/.csv.
        longitud_ventana, solapamiento: para .txt/.pdf, ver
            `crear_pares_por_ventana`.

    Raises:
        ValueError: formato no soportado, o falta el tokenizer para
            un archivo .txt/.pdf.
    """
    pares_combinados: list[tuple[str, str]] = []

    for ruta, formato in rutas_y_formatos:
        if formato == ".jsonl":
            pares_combinados.extend(
                cargar_pares_desde_jsonl(ruta, clave_origen, clave_destino, clave_contexto)
            )
        elif formato == ".json":
            pares_combinados.extend(
                cargar_pares_desde_json(ruta, clave_origen, clave_destino, clave_contexto)
            )
        elif formato == ".csv":
            pares_combinados.extend(
                cargar_pares_desde_csv(
                    ruta,
                    clave_origen,
                    clave_destino,
                    columna_contexto=clave_contexto,
                )
            )
        elif formato in (".txt", ".pdf"):
            if tokenizer is None:
                raise ValueError(
                    f"Para combinar {ruta} ({formato}) hace falta pasar el tokenizer "
                    f"del modelo — no se puede tokenizar texto corrido sin saber con "
                    f"qué vocabulario."
                )
            texto = cargar_texto_desde_txt(ruta) if formato == ".txt" else cargar_texto_desde_pdf(ruta)
            pares_combinados.extend(
                crear_pares_por_ventana(texto, tokenizer, longitud_ventana, solapamiento=solapamiento)
            )
        else:
            raise ValueError(f"Formato no soportado para combinar: {formato} (ruta: {ruta})")

    return pares_combinados


def cargar_texto_desde_txt(ruta: str | Path, encoding: str = "utf-8") -> str:
    """Lee un archivo de texto plano completo.

    Raises:
        FileNotFoundError: si `ruta` no existe.
    """
    ruta = Path(ruta)
    if not ruta.exists():
        raise FileNotFoundError(f"No se encontró el archivo: {ruta}")
    return ruta.read_text(encoding=encoding)


def cargar_texto_desde_pdf(ruta: str | Path) -> str:
    """Extrae el texto de un PDF con texto seleccionable (no escaneado).

    Usa `pypdf`, adecuado para PDFs de texto normales (reportes,
    artículos, libros). Para PDFs ESCANEADOS (sin capa de texto, ej. un
    libro fotocopiado) esto va a devolver texto vacío o casi vacío — en
    ese caso hace falta OCR (fuera de alcance de este loader).

    Raises:
        FileNotFoundError: si `ruta` no existe.
        ValueError: si no se pudo extraer ningún texto (probablemente un
            PDF escaneado sin capa de texto).
    """
    ruta = Path(ruta)
    if not ruta.exists():
        raise FileNotFoundError(f"No se encontró el archivo: {ruta}")


    lector = PdfReader(ruta)
    texto = "\n".join(pagina.extract_text() or "" for pagina in lector.pages)

    if not texto.strip():
        raise ValueError(
            f"No se pudo extraer texto de {ruta}. Probablemente sea un PDF "
            f"escaneado (sin capa de texto) — este loader no incluye OCR."
        )

    return texto


def crear_pares_por_ventana(
    texto: str,
    tokenizer: Tokenizer,
    longitud_ventana: int,
    solapamiento: int = 0,
) -> list[tuple[str, str]]:
    """Convierte un texto corrido en pares (origen, destino) artificiales:
    cada fragmento de `longitud_ventana` tokens se empareja con el
    fragmento que le sigue inmediatamente. El modelo aprende a "continuar
    el texto" — la tarea más natural para un encoder-decoder cuando no
    hay traducciones ni respuestas reales, solo un corpus.

    Args:
        texto: texto completo (de `cargar_texto_desde_txt` o `cargar_texto_desde_pdf`).
        tokenizer: para tokenizar el texto y volver a decodificar cada ventana.
        longitud_ventana: cantidad de tokens por fragmento (origen y
            destino tendrán esta longitud aproximada).
        solapamiento: cuántos tokens se repiten entre una ventana y la
            siguiente (0 = ventanas consecutivas sin solapar). Un
            solapamiento > 0 genera MÁS pares de un mismo texto (útil
            con corpus chicos), a costa de repetir contenido entre
            ejemplos de entrenamiento.

    Returns:
        Lista de pares (texto_origen, texto_destino), lista para pasar a
        `DatasetSecuencias` igual que los pares de CSV/JSON.

    Raises:
        ValueError: si `longitud_ventana` <= 0, o si `solapamiento` es
            mayor o igual a `longitud_ventana` (el paso entre ventanas
            quedaría en 0 o negativo, un bucle infinito).
    """
    if longitud_ventana <= 0:
        raise ValueError(f"longitud_ventana debe ser > 0, recibido: {longitud_ventana}")
    if solapamiento >= longitud_ventana:
        raise ValueError(
            f"solapamiento ({solapamiento}) debe ser menor que longitud_ventana ({longitud_ventana})"
        )

    tokens = tokenizer.encode(texto)
    paso = longitud_ventana - solapamiento

    ventanas = [
        tokens[i : i + longitud_ventana]
        for i in range(0, len(tokens) - longitud_ventana + 1, paso)
    ]

    pares = [
        (tokenizer.decode(ventanas[i]), tokenizer.decode(ventanas[i + 1]))
        for i in range(len(ventanas) - 1)
    ]

    return pares


# ---------------------------------------------------------------------------
# Dataset y collate_fn (armado de batches con relleno)
# ---------------------------------------------------------------------------


class DatasetSecuencias(Dataset):
    """`torch.utils.data.Dataset` de pares (origen, destino) ya tokenizados.

    La tokenización se hace de forma EAGER (en `__init__`, no en cada
    `__getitem__`), porque tokenizar es relativamente barato comparado
    con el costo de hacerlo repetidamente en cada época — el trade-off
    es usar algo más de memoria para guardar los ids ya calculados. Para
    datasets extremadamente grandes que no entran en memoria, este
    diseño habría que cambiarlo a tokenización perezosa; fuera de
    alcance por ahora.
    """

    def __init__(
        self,
        pares: list[tuple[str, str]],
        tokenizer: Tokenizer,
        id_token_inicio: int,
        id_token_fin: int,
        longitud_maxima: int | None = None,
    ):
        """
        Args:
            pares: lista de (texto_origen, texto_destino).
            tokenizer: instancia de `Tokenizer` ya creada.
            id_token_inicio, id_token_fin: ids reservados para marcar
                inicio/fin de la secuencia de destino (deben ser
                consistentes con los que use `Transformer.generar` en
                inferencia). NO pueden coincidir con
                `obtener_id_token_relleno(tokenizer)`.
            longitud_maxima: trunca origen y destino a esta longitud si
                es necesario (protege contra ejemplos absurdamente
                largos que dispararían el uso de memoria). None = sin límite.
        """
        id_relleno = obtener_id_token_relleno(tokenizer)
        if id_token_inicio == id_relleno or id_token_fin == id_relleno:
            raise ValueError(
                f"id_token_inicio ({id_token_inicio}) e id_token_fin ({id_token_fin}) "
                f"no pueden coincidir con el id de relleno reservado ({id_relleno})."
            )

        self._ejemplos: list[tuple[list[int], list[int], list[int]]] = []

        for texto_origen, texto_destino in pares:
            tokens_origen = tokenizer.encode(texto_origen)
            tokens_destino_completos = (
                [id_token_inicio] + tokenizer.encode(texto_destino) + [id_token_fin]
            )

            if longitud_maxima is not None:
                tokens_origen = tokens_origen[:longitud_maxima]
                tokens_destino_completos = tokens_destino_completos[: longitud_maxima + 1]

            tokens_destino_entrada = tokens_destino_completos[:-1]
            tokens_destino_objetivo = tokens_destino_completos[1:]

            self._ejemplos.append((tokens_origen, tokens_destino_entrada, tokens_destino_objetivo))

    def __len__(self) -> int:
        return len(self._ejemplos)

    def __getitem__(self, indice: int) -> tuple[list[int], list[int], list[int]]:
        return self._ejemplos[indice]


def crear_funcion_colacion(id_token_relleno: int):
    """Crea la `collate_fn` que arma un batch a partir de una lista de
    ejemplos de longitud variable, rellenando con `id_token_relleno`
    hasta la longitud del ejemplo más largo del batch.

    Se retorna como una función (en vez de recibir `id_token_relleno`
    junto con el batch) porque `DataLoader` llama a `collate_fn(batch)`
    con un solo argumento — este patrón de "función que crea la función"
    es la forma estándar de parametrizarla en PyTorch.
    """

    def _rellenar(secuencias: list[list[int]]) -> torch.Tensor:
        longitud_maxima = max(len(s) for s in secuencias)
        return torch.tensor(
            [s + [id_token_relleno] * (longitud_maxima - len(s)) for s in secuencias],
            dtype=torch.long,
        )

    def funcion_colacion(
        batch: list[tuple[list[int], list[int], list[int]]],
    ) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
        origenes, destinos_entrada, destinos_objetivo = zip(*batch)
        return (
            _rellenar(list(origenes)),
            _rellenar(list(destinos_entrada)),
            _rellenar(list(destinos_objetivo)),
        )

    return funcion_colacion


def crear_dataloader(
    dataset: DatasetSecuencias,
    id_token_relleno: int,
    batch_size: int = 32,
    shuffle: bool = True,
) -> DataLoader:
    """Arma el `DataLoader` con la función de relleno correcta ya conectada.

    El resultado se puede pasar DIRECTAMENTE como `proveedor_batches` a
    `TrainingController.iniciar_entrenamiento` — un `DataLoader` de
    PyTorch ya es iterable, y volver a iterarlo (`for batch in dataloader`)
    da una nueva pasada (con nuevo shuffle si `shuffle=True`), que es
    exactamente el contrato que espera `training_controller.py`:

        controlador.iniciar_entrenamiento(lambda: dataloader, num_epocas=5)
    """
    return DataLoader(
        dataset,
        batch_size=batch_size,
        shuffle=shuffle,
        collate_fn=crear_funcion_colacion(id_token_relleno),
    )
