from pathlib import Path
import json

from PySide6.QtCore import QObject, Slot
import hashlib
from collections import Counter

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
        total_registros = 0
        total_tokens = 0
        vocabulario = set()
        categorias = Counter()
        campos = set()
        longitud_maxima = 0
        longitud_minima = None
        ejemplos_vacios = 0
        with open(
            ruta,
            "r",
            encoding="utf8"
        ) as archivo:
            for linea in archivo:
                linea = linea.strip()
                if linea == "":
                    continue
                objeto = json.loads(linea)
                total_registros += 1
                campos.update(objeto.keys())
                categoria = objeto.get("category")
                if categoria:
                    categorias[categoria] += 1
                texto = ""
                for campo in [
                    "instruction",
                    "context",
                    "response"
                ]:
                    if campo in objeto:
                        texto += objeto[campo] + " "
                texto = texto.strip()

                if texto == "":
                    ejemplos_vacios += 1
                    continue

                palabras = texto.split()

                longitud = len(palabras)

                total_tokens += longitud

                vocabulario.update(palabras)

                longitud_maxima = max(
                    longitud_maxima,
                    longitud
                )

                if longitud_minima is None:

                    longitud_minima = longitud

                else:

                    longitud_minima = min(
                        longitud_minima,
                        longitud
                    )

        tamano_mb = round(
            ruta.stat().st_size / (1024 * 1024),
            2
        )
        promedio = 0
        if total_registros > 0:
            promedio = round(
                total_tokens / total_registros,
                2
            )

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
            "estado": "Validado"
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
        registros = []

        try:
            with open(ruta, "r", encoding="utf8") as archivo:
                for i, linea in enumerate(archivo):
                    if i >= limite:
                        break

                    linea = linea.strip()
                    if linea == "":
                        continue

                    try:
                        registros.append(json.loads(linea))
                    except json.JSONDecodeError:
                        continue

        except Exception:
            import traceback
            traceback.print_exc()
            return []

        return registros