from importlib.metadata import metadata
from pathlib import Path
import json

from PySide6.QtCore import QObject, Slot
import hashlib
from collections import Counter
import csv

FORMATOS_SOPORTADOS = {".jsonl", ".json", ".csv", ".txt", ".pdf"}


def _registros_desde_jsonl(ruta):
    """Un objeto JSON por línea (Dolly, etc.)."""
    with open(ruta, "r", encoding="utf8") as archivo:
        for numero_linea, linea in enumerate(archivo, start=1):
            linea = linea.strip()
            if linea == "":
                continue
            try:
                yield json.loads(linea)
            except json.JSONDecodeError as error:
                raise ValueError(
                    f"Línea {numero_linea} de {ruta.name} no es JSON válido: {error}"
                ) from error


def _registros_desde_json(ruta):
    """Una lista de objetos: [{...}, {...}]."""
    with open(ruta, "r", encoding="utf8") as archivo:
        datos = json.load(archivo)
    if not isinstance(datos, list):
        raise ValueError(f"{ruta.name}: el JSON debe ser una lista de objetos, ej. [{{...}}, {{...}}]")
    yield from datos


def _registros_desde_csv(ruta):
    """Una fila por registro, las columnas del encabezado son los campos."""
    with open(ruta, "r", encoding="utf8", newline="") as archivo:
        lector = csv.DictReader(archivo)
        for fila in lector:
            yield dict(fila)


def _registros_desde_texto_plano(ruta):
    """Sin estructura de pares (.txt): cada línea no vacía se trata como
    un "registro" propio, solo para poder calcular estadísticas (tokens,
    vocabulario, longitud) de forma consistente con los demás formatos.
    No es la misma lógica que usa `crear_pares_por_ventana` en
    `dataset_loader.py` para ARMAR pares de entrenamiento — acá solo es
    para la tarjeta del catálogo."""
    with open(ruta, "r", encoding="utf8") as archivo:
        for linea in archivo:
            linea = linea.strip()
            if linea == "":
                continue
            yield {"texto": linea}


def _registros_desde_pdf(ruta):
    """Extrae el texto con `cargar_texto_desde_pdf` (mismo extractor que
    usa `dataset_loader.py` para entrenar) y aplica el mismo criterio
    línea-por-línea que `.txt`."""
    from model.gestor_de_datos.dataset_loader import cargar_texto_desde_pdf

    texto_completo = cargar_texto_desde_pdf(ruta)
    for linea in texto_completo.splitlines():
        linea = linea.strip()
        if linea == "":
            continue
        yield {"texto": linea}

class DatasetController(QObject):

    DATASET_FILE = Path("data/datasets/dataSets.json")

    def __init__(self):
        super().__init__()
        self.datasets = []
        self.cargar_datasets()


    def cargar_datasets(self):
        self.DATASET_FILE.parent.mkdir(
            parents=True,
            exist_ok=True
        )
        if not self.DATASET_FILE.exists():
            with open(
                self.DATASET_FILE,
                "w",
                encoding="utf8"
            ) as archivo:
                json.dump(
                    [],
                    archivo,
                    indent=4,
                    ensure_ascii=False
                )
        with open(
            self.DATASET_FILE,
            "r",
            encoding="utf8"
        ) as archivo:

            self.datasets = json.load(archivo)


    def guardar_datasets(self):

        with open(
            self.DATASET_FILE,
            "w",
            encoding="utf8"
        ) as archivo:

            json.dump(
                self.datasets,
                archivo,
                indent=4,
                ensure_ascii=False
            )


    @Slot(result="QVariantList")
    def obtenerDatasets(self):
        return self.datasets


    def buscar_dataset(self, ruta):
        ruta = str(Path(ruta).resolve())
        for dataset in self.datasets:
            if dataset["ruta"] == ruta:
                return dataset
        return None



    def generar_id(self):
        if len(self.datasets) == 0:
            return "DS-001"
        numeros = []
        for ds in self.datasets:
            numero = int(ds["id"].split("-")[1])
            numeros.append(numero)
        return f"DS-{max(numeros)+1:03d}"



    @Slot(str)
    def eliminarDataset(self, id_dataset):
        self.datasets = [
            ds
            for ds in self.datasets
            if ds["id"] != id_dataset
        ]
        self.guardar_datasets()


    def contar_tokens(self, texto: str) -> int:
        return len(texto.split())


    def calcular_hash(self, ruta):
        sha = hashlib.sha256()
        with open(ruta, "rb") as archivo:
            while True:
                bloque = archivo.read(8192)
                if not bloque:
                    break
                sha.update(bloque)
        return sha.hexdigest()



    def analizar_dataset(self, ruta):
        ruta = Path(ruta)

        if ruta.suffix not in FORMATOS_SOPORTADOS:
            raise ValueError(
                f"Formato no soportado: {ruta.suffix} "
                f"(soportados: {', '.join(sorted(FORMATOS_SOPORTADOS))})"
            )

        generadores_por_formato = {
            ".jsonl": _registros_desde_jsonl,
            ".json": _registros_desde_json,
            ".csv": _registros_desde_csv,
            ".txt": _registros_desde_texto_plano,
            ".pdf": _registros_desde_pdf,
        }
        registros = generadores_por_formato[ruta.suffix](ruta)

        total_registros = 0
        total_tokens = 0
        vocabulario = set()
        categorias = Counter()
        campos = set()
        longitud_maxima = 0
        longitud_minima = None
        ejemplos_vacios = 0

        for objeto in registros:
            total_registros += 1
            campos.update(objeto.keys())

            # Antes buscaba solo "category"; ahora tambien "categoria",
            # por si el dataset viene en espanol.
            categoria = objeto.get("category") or objeto.get("categoria")
            if categoria:
                categorias[categoria] += 1

            # Antes concatenaba SOLO instruction/context/response (hardcodeado,
            # asumia formato Dolly). Ahora junta CUALQUIER campo de texto del
            # registro, asi funciona con esquemas de columnas distintos
            # (pregunta/respuesta, etc.) y con los pseudo-registros de .txt/.pdf.
            texto = " ".join(
                str(valor) for valor in objeto.values() if isinstance(valor, str)
            ).strip()

            if texto == "":
                ejemplos_vacios += 1
                continue

            palabras = texto.split()
            longitud = len(palabras)

            total_tokens += longitud
            vocabulario.update(palabras)

            longitud_maxima = max(longitud_maxima, longitud)
            longitud_minima = longitud if longitud_minima is None else min(longitud_minima, longitud)

        tamano_mb = round(ruta.stat().st_size / (1024 * 1024), 2)
        promedio = round(total_tokens / total_registros, 2) if total_registros > 0 else 0

        metadata = {
            "id": self.generar_id(),
            "nombre": ruta.stem,
            "ruta": str(ruta.resolve()),
            "formato": ruta.suffix,
            "tamano_mb": tamano_mb,
            "registros": total_registros,
            "tokens": total_tokens,
            "tokens_promedio": promedio,
            "selected": False,
            "vocabulario": len(vocabulario),
            "campos": sorted(list(campos)),
            "campos_texto": ", ".join(sorted(list(campos))),
            "categorias": dict(categorias),
            "longitud_maxima": longitud_maxima,
            "longitud_minima": longitud_minima,
            "ejemplos_vacios": ejemplos_vacios,
            "checksum": self.calcular_hash(ruta),
            "estado": "Validado",
            }
        return metadata


    @Slot(str, result="QVariantMap")
    def agregarDataset(self, ruta):
        existente = self.buscar_dataset(ruta)
        if existente is not None:
            return existente
        metadata = self.analizar_dataset(ruta)
        self.datasets.append(metadata)
        self.guardar_datasets()
        return metadata



    @Slot(str, result="QVariantMap")
    def obtenerDataset(self, id_dataset):
        for ds in self.datasets:
            if ds["id"] == id_dataset:
                return ds
        return {}


    @Slot(str, int, result="QVariantList")
    def obtenerRegistros(self, id_dataset, limite=50):
        dataset = None
        for ds in self.datasets:
            if ds["id"] == id_dataset:
                dataset = ds
                break

        if dataset is None:
            return []

        ruta = Path(dataset["ruta"])

        generadores_por_formato = {
            ".jsonl": _registros_desde_jsonl,
            ".json": _registros_desde_json,
            ".csv": _registros_desde_csv,
            ".txt": _registros_desde_texto_plano,
            ".pdf": _registros_desde_pdf,
        }
        generador = generadores_por_formato.get(ruta.suffix)
        if generador is None:
            return []

        registros = []
        try:
            for objeto in generador(ruta):
                if len(registros) >= limite:
                    break
                registros.append(objeto)
        except (ValueError, FileNotFoundError):
            return []

        return registros