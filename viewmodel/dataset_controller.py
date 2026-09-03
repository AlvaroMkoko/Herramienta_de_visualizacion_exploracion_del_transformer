"""Catálogo de datasets y operaciones de lectura para la interfaz QML.

Las operaciones síncronas originales se conservan para scripts y pruebas. La
interfaz usa sus equivalentes asíncronos para que analizar, calcular SHA-256 o
construir una vista previa no bloquee el hilo gráfico de Qt.
"""

from __future__ import annotations

from collections import Counter
from collections.abc import Callable, Iterator
import csv
import hashlib
import json
from pathlib import Path
import time
from typing import Any

from PySide6.QtCore import Property, QObject, QThread, QUrl, Signal, Slot


FORMATOS_SOPORTADOS = {".jsonl", ".json", ".csv", ".txt", ".pdf"}
_TAMANO_BLOQUE_HASH = 1024 * 1024
_INTERVALO_PROGRESO_SEGUNDOS = 0.10


def _ruta_local(valor: str | Path) -> Path:
    """Acepta una ruta nativa o una URL ``file:`` entregada por QML."""
    if isinstance(valor, Path):
        return valor.expanduser()

    texto = str(valor).strip()
    if not texto:
        return Path()

    url = QUrl(texto)
    if url.isLocalFile():
        ruta = url.toLocalFile()
        if ruta:
            return Path(ruta)
    return Path(texto).expanduser()


def _registros_desde_jsonl(ruta: Path) -> Iterator[dict[str, Any]]:
    """Lee un objeto JSON por línea (Dolly y formatos semejantes)."""
    with ruta.open("r", encoding="utf8") as archivo:
        for numero_linea, linea in enumerate(archivo, start=1):
            linea = linea.strip()
            if not linea:
                continue
            try:
                objeto = json.loads(linea)
            except json.JSONDecodeError as error:
                raise ValueError(
                    f"Línea {numero_linea} de {ruta.name} no es JSON válido: {error}"
                ) from error
            if not isinstance(objeto, dict):
                raise ValueError(
                    f"Línea {numero_linea} de {ruta.name}: cada registro debe ser un objeto JSON."
                )
            yield objeto


def _registros_desde_json(ruta: Path) -> Iterator[dict[str, Any]]:
    """Lee una lista JSON de objetos: ``[{...}, {...}]``."""
    with ruta.open("r", encoding="utf8") as archivo:
        datos = json.load(archivo)
    if not isinstance(datos, list):
        raise ValueError(
            f"{ruta.name}: el JSON debe ser una lista de objetos, ej. [{{...}}, {{...}}]"
        )
    for indice, objeto in enumerate(datos, start=1):
        if not isinstance(objeto, dict):
            raise ValueError(
                f"Registro {indice} de {ruta.name}: cada elemento debe ser un objeto JSON."
            )
        yield objeto


def _registros_desde_csv(ruta: Path) -> Iterator[dict[str, Any]]:
    """Lee una fila por registro usando el encabezado como nombres de campo."""
    with ruta.open("r", encoding="utf8", newline="") as archivo:
        lector = csv.DictReader(archivo)
        for fila in lector:
            yield dict(fila)


def _registros_desde_texto_plano(ruta: Path) -> Iterator[dict[str, Any]]:
    """Representa cada línea no vacía de un TXT como un registro."""
    with ruta.open("r", encoding="utf8") as archivo:
        for linea in archivo:
            linea = linea.strip()
            if linea:
                yield {"texto": linea}


def _registros_desde_pdf(ruta: Path) -> Iterator[dict[str, Any]]:
    """Extrae un PDF con la misma función usada por el entrenamiento."""
    from model.gestor_de_datos.dataset_loader import cargar_texto_desde_pdf

    texto_completo = cargar_texto_desde_pdf(ruta)
    for linea in texto_completo.splitlines():
        linea = linea.strip()
        if linea:
            yield {"texto": linea}


_GENERADORES_POR_FORMATO: dict[str, Callable[[Path], Iterator[dict[str, Any]]]] = {
    ".jsonl": _registros_desde_jsonl,
    ".json": _registros_desde_json,
    ".csv": _registros_desde_csv,
    ".txt": _registros_desde_texto_plano,
    ".pdf": _registros_desde_pdf,
}


def _mapa_progreso(
    operacion: str,
    fase: str,
    *,
    indeterminado: bool,
    valor: int = 0,
    total: int = 0,
    detalle: str = "",
) -> dict[str, Any]:
    porcentaje = (
        round(min(max(valor / total, 0.0), 1.0) * 100.0, 1)
        if total > 0
        else 0.0
    )
    return {
        "operacion": operacion,
        "fase": fase,
        "detalle": detalle,
        "indeterminado": indeterminado,
        "valor": int(valor),
        "total": int(total),
        "porcentaje": porcentaje,
    }


def _calcular_hash(
    ruta: Path,
    reportar: Callable[[dict[str, Any]], None] | None = None,
) -> str:
    """Calcula SHA-256 y, si se solicita, informa bytes procesados."""
    sha = hashlib.sha256()
    total = ruta.stat().st_size
    procesados = 0
    ultimo_reporte = 0.0

    if reportar is not None:
        reportar(
            _mapa_progreso(
                "agregar",
                "Verificando integridad",
                indeterminado=False,
                valor=0,
                total=total,
                detalle=f"0 de {total} bytes",
            )
        )

    with ruta.open("rb") as archivo:
        while True:
            bloque = archivo.read(_TAMANO_BLOQUE_HASH)
            if not bloque:
                break
            sha.update(bloque)
            procesados += len(bloque)

            ahora = time.monotonic()
            if reportar is not None and (
                procesados >= total
                or ahora - ultimo_reporte >= _INTERVALO_PROGRESO_SEGUNDOS
            ):
                ultimo_reporte = ahora
                reportar(
                    _mapa_progreso(
                        "agregar",
                        "Verificando integridad",
                        indeterminado=False,
                        valor=procesados,
                        total=total,
                        detalle=f"{procesados} de {total} bytes",
                    )
                )

    if reportar is not None and total == 0:
        reportar(
            _mapa_progreso(
                "agregar",
                "Verificando integridad",
                indeterminado=False,
                valor=0,
                total=0,
                detalle="Archivo vacío",
            )
        )
    return sha.hexdigest()


def _analizar_dataset(
    ruta: Path,
    dataset_id: str,
    reportar: Callable[[dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    ruta = ruta.resolve()
    extension = ruta.suffix.lower()
    if extension not in FORMATOS_SOPORTADOS:
        raise ValueError(
            f"Formato no soportado: {extension or '(sin extensión)'} "
            f"(soportados: {', '.join(sorted(FORMATOS_SOPORTADOS))})"
        )
    if not ruta.is_file():
        raise FileNotFoundError(f"No se encontró el dataset: {ruta}")

    if reportar is not None:
        reportar(
            _mapa_progreso(
                "agregar",
                "Analizando registros",
                indeterminado=True,
                detalle=ruta.name,
            )
        )

    total_registros = 0
    total_tokens = 0
    vocabulario: set[str] = set()
    categorias: Counter[str] = Counter()
    campos: set[str] = set()
    longitud_maxima = 0
    longitud_minima: int | None = None
    ejemplos_vacios = 0
    ultimo_reporte = time.monotonic()

    for objeto in _GENERADORES_POR_FORMATO[extension](ruta):
        total_registros += 1
        campos.update(str(campo) for campo in objeto.keys())

        categoria = objeto.get("category") or objeto.get("categoria")
        if categoria:
            categorias[str(categoria)] += 1

        texto = " ".join(
            str(valor) for valor in objeto.values() if isinstance(valor, str)
        ).strip()
        if not texto:
            ejemplos_vacios += 1
        else:
            palabras = texto.split()
            longitud = len(palabras)
            total_tokens += longitud
            vocabulario.update(palabras)
            longitud_maxima = max(longitud_maxima, longitud)
            longitud_minima = (
                longitud
                if longitud_minima is None
                else min(longitud_minima, longitud)
            )

        ahora = time.monotonic()
        if reportar is not None and (
            ahora - ultimo_reporte >= _INTERVALO_PROGRESO_SEGUNDOS
        ):
            ultimo_reporte = ahora
            reportar(
                _mapa_progreso(
                    "agregar",
                    "Analizando registros",
                    indeterminado=True,
                    valor=total_registros,
                    detalle=f"{total_registros} registros revisados",
                )
            )

    promedio = round(total_tokens / total_registros, 2) if total_registros else 0
    tamano_mb = round(ruta.stat().st_size / (1024 * 1024), 2)
    checksum = _calcular_hash(ruta, reportar)

    return {
        "id": dataset_id,
        "nombre": ruta.stem,
        "ruta": str(ruta),
        "formato": extension,
        "tamano_mb": tamano_mb,
        "registros": total_registros,
        "tokens": total_tokens,
        "tokens_promedio": promedio,
        "selected": False,
        "vocabulario": len(vocabulario),
        "campos": sorted(campos),
        "campos_texto": ", ".join(sorted(campos)),
        "categorias": dict(categorias),
        "longitud_maxima": longitud_maxima,
        "longitud_minima": longitud_minima,
        "ejemplos_vacios": ejemplos_vacios,
        "checksum": checksum,
        "estado": "Validado",
    }


def _obtener_registros(
    ruta: Path,
    limite: int,
    reportar: Callable[[dict[str, Any]], None] | None = None,
) -> list[dict[str, Any]]:
    ruta = ruta.resolve()
    extension = ruta.suffix.lower()
    generador = _GENERADORES_POR_FORMATO.get(extension)
    if generador is None:
        raise ValueError(f"Formato no soportado para vista previa: {extension}")
    if not ruta.is_file():
        raise FileNotFoundError(f"No se encontró el dataset: {ruta}")

    if reportar is not None:
        reportar(
            _mapa_progreso(
                "vista_previa",
                "Preparando vista previa",
                indeterminado=True,
                detalle=ruta.name,
            )
        )

    registros: list[dict[str, Any]] = []
    for objeto in generador(ruta):
        if len(registros) >= limite:
            break
        registros.append(objeto)
    return registros


class _DatasetWorker(QObject):
    """Ejecuta una función pura dentro de un ``QThread``."""

    progreso = Signal(dict)
    terminado = Signal(object)
    error = Signal(str)

    def __init__(
        self,
        tarea: Callable[[Callable[[dict[str, Any]], None]], Any],
    ) -> None:
        super().__init__()
        self._tarea = tarea

    @Slot()
    def ejecutar(self) -> None:
        try:
            resultado = self._tarea(self.progreso.emit)
        except Exception as exc:  # noqa: BLE001 - el mensaje debe volver a QML
            self.error.emit(str(exc))
            return
        self.terminado.emit(resultado)


class DatasetController(QObject):
    """Administra el catálogo persistente y expone operaciones para QML."""

    DATASET_FILE = Path("data/datasets/dataSets.json")

    ocupadoCambio = Signal()
    progresoCambio = Signal()
    resultado = Signal(dict)
    datasetAgregado = Signal(dict)
    registrosListos = Signal(str, list)
    error = Signal(str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.datasets: list[dict[str, Any]] = []
        self._ocupado = False
        self._progreso: dict[str, Any] = {}
        self._hilo: QThread | None = None
        self._trabajador: _DatasetWorker | None = None
        self._operacion_actual = ""
        self._cerrado = False
        self.cargar_datasets()

    @Property(bool, notify=ocupadoCambio)
    def ocupado(self) -> bool:
        return self._ocupado

    @Property("QVariantMap", notify=progresoCambio)
    def progreso(self) -> dict[str, Any]:
        return dict(self._progreso)

    @Property("QVariantMap", notify=progresoCambio)
    def fase(self) -> dict[str, Any]:
        return dict(self._progreso)

    def _establecer_ocupado(self, valor: bool) -> None:
        if self._ocupado == valor:
            return
        self._ocupado = valor
        self.ocupadoCambio.emit()

    @Slot(dict)
    def _establecer_progreso(self, progreso: dict[str, Any]) -> None:
        self._progreso = dict(progreso)
        self.progresoCambio.emit()

    def cargar_datasets(self) -> None:
        self.DATASET_FILE.parent.mkdir(parents=True, exist_ok=True)
        if not self.DATASET_FILE.exists():
            with self.DATASET_FILE.open("w", encoding="utf8") as archivo:
                json.dump([], archivo, indent=4, ensure_ascii=False)
        with self.DATASET_FILE.open("r", encoding="utf8") as archivo:
            self.datasets = json.load(archivo)

    def guardar_datasets(self) -> None:
        with self.DATASET_FILE.open("w", encoding="utf8") as archivo:
            json.dump(self.datasets, archivo, indent=4, ensure_ascii=False)

    @Slot(result="QVariantList")
    def obtenerDatasets(self) -> list[dict[str, Any]]:
        return list(self.datasets)

    def buscar_dataset(self, ruta: str | Path) -> dict[str, Any] | None:
        ruta_resuelta = str(_ruta_local(ruta).resolve())
        for dataset in self.datasets:
            if dataset["ruta"] == ruta_resuelta:
                return dataset
        return None

    def generar_id(self) -> str:
        if not self.datasets:
            return "DS-001"
        numeros = []
        for dataset in self.datasets:
            try:
                numeros.append(int(str(dataset["id"]).split("-")[1]))
            except (IndexError, KeyError, TypeError, ValueError):
                continue
        return f"DS-{max(numeros, default=0) + 1:03d}"

    @Slot(str)
    def eliminarDataset(self, id_dataset: str) -> None:
        self.datasets = [
            dataset for dataset in self.datasets if dataset["id"] != id_dataset
        ]
        self.guardar_datasets()

    def contar_tokens(self, texto: str) -> int:
        return len(texto.split())

    def calcular_hash(self, ruta: str | Path) -> str:
        return _calcular_hash(_ruta_local(ruta))

    def analizar_dataset(self, ruta: str | Path) -> dict[str, Any]:
        return _analizar_dataset(_ruta_local(ruta), self.generar_id())

    @Slot(str, result="QVariantMap")
    def agregarDataset(self, ruta: str) -> dict[str, Any]:
        """Versión síncrona conservada para compatibilidad."""
        existente = self.buscar_dataset(ruta)
        if existente is not None:
            return existente
        metadata = self.analizar_dataset(ruta)
        self.datasets.append(metadata)
        self.guardar_datasets()
        return metadata

    @Slot(str, result=bool)
    def agregarDatasetAsync(self, ruta: str) -> bool:
        """Analiza y calcula el hash sin bloquear la interfaz."""
        if self._operacion_en_curso():
            return False

        ruta_local = _ruta_local(ruta)
        existente = self.buscar_dataset(ruta_local)
        if existente is not None:
            payload = {"operacion": "agregar", "dataset": dict(existente)}
            self._establecer_progreso(
                _mapa_progreso(
                    "agregar",
                    "Dataset ya disponible",
                    indeterminado=False,
                    valor=1,
                    total=1,
                    detalle=existente.get("nombre", ""),
                )
            )
            self.datasetAgregado.emit(dict(existente))
            self.resultado.emit(payload)
            return True

        def tarea(reportar: Callable[[dict[str, Any]], None]) -> dict[str, Any]:
            return {
                "operacion": "agregar",
                "dataset": _analizar_dataset(ruta_local, "", reportar),
            }

        return self._iniciar_operacion(
            "agregar",
            _mapa_progreso(
                "agregar",
                "Preparando análisis",
                indeterminado=True,
                detalle=ruta_local.name,
            ),
            tarea,
        )

    @Slot(str, result="QVariantMap")
    def obtenerDataset(self, id_dataset: str) -> dict[str, Any]:
        for dataset in self.datasets:
            if dataset["id"] == id_dataset:
                return dataset
        return {}

    def _buscar_por_id(self, id_dataset: str) -> dict[str, Any] | None:
        for dataset in self.datasets:
            if dataset["id"] == id_dataset:
                return dataset
        return None

    @Slot(str, int, result="QVariantList")
    def obtenerRegistros(self, id_dataset: str, limite: int = 50) -> list[dict[str, Any]]:
        """Versión síncrona conservada para compatibilidad."""
        dataset = self._buscar_por_id(id_dataset)
        if dataset is None:
            return []
        try:
            return _obtener_registros(Path(dataset["ruta"]), max(int(limite), 0))
        except (OSError, TypeError, ValueError):
            return []

    @Slot(str, int, result=bool)
    def obtenerRegistrosAsync(self, id_dataset: str, limite: int = 50) -> bool:
        """Construye una vista previa en el worker y la entrega por señal."""
        if self._operacion_en_curso():
            return False

        dataset = self._buscar_por_id(id_dataset)
        if dataset is None:
            self.error.emit(f"No se encontró el dataset {id_dataset}.")
            return False

        ruta = Path(dataset["ruta"])
        limite_seguro = max(int(limite), 0)

        def tarea(reportar: Callable[[dict[str, Any]], None]) -> dict[str, Any]:
            return {
                "operacion": "vista_previa",
                "dataset_id": id_dataset,
                "registros": _obtener_registros(ruta, limite_seguro, reportar),
            }

        return self._iniciar_operacion(
            "vista_previa",
            _mapa_progreso(
                "vista_previa",
                "Preparando vista previa",
                indeterminado=True,
                detalle=dataset.get("nombre", ruta.name),
            ),
            tarea,
        )

    def _operacion_en_curso(self) -> bool:
        return self._ocupado or (
            self._hilo is not None and self._hilo.isRunning()
        )

    def _iniciar_operacion(
        self,
        operacion: str,
        progreso_inicial: dict[str, Any],
        tarea: Callable[[Callable[[dict[str, Any]], None]], Any],
    ) -> bool:
        if self._cerrado:
            return False
        if self._operacion_en_curso():
            return False

        hilo = QThread(self)
        trabajador = _DatasetWorker(tarea)
        trabajador.moveToThread(hilo)

        hilo.started.connect(trabajador.ejecutar)
        trabajador.progreso.connect(self._establecer_progreso)
        trabajador.terminado.connect(self._al_terminar_operacion)
        trabajador.error.connect(self._al_fallar_operacion)
        # El worker pertenece al hilo secundario: programa su destruccion
        # alli, antes de que se detenga el event loop del QThread.
        trabajador.terminado.connect(trabajador.deleteLater)
        trabajador.error.connect(trabajador.deleteLater)

        self._hilo = hilo
        self._trabajador = trabajador
        self._operacion_actual = operacion
        self._establecer_progreso(progreso_inicial)
        self._establecer_ocupado(True)
        try:
            hilo.start()
        except RuntimeError as exc:
            self._trabajador = None
            self._hilo = None
            hilo.deleteLater()
            self._emitir_error(f"No se pudo iniciar el hilo: {exc}")
            return False
        return True

    @Slot(object)
    def _al_terminar_operacion(self, payload: object) -> None:
        self._detener_y_liberar_hilo()
        if self._cerrado:
            self._establecer_ocupado(False)
            self._operacion_actual = ""
            return
        try:
            if not isinstance(payload, dict):
                raise TypeError("El worker devolvió un resultado inválido.")

            resultado = dict(payload)
            operacion = str(resultado.get("operacion", self._operacion_actual))
            if operacion == "agregar":
                metadata = dict(resultado.get("dataset") or {})
                existente = self.buscar_dataset(metadata.get("ruta", ""))
                if existente is None:
                    metadata["id"] = self.generar_id()
                    self.datasets.append(metadata)
                    try:
                        self.guardar_datasets()
                    except Exception:
                        self.datasets.pop()
                        raise
                    existente = metadata
                resultado["dataset"] = dict(existente)
                self.datasetAgregado.emit(dict(existente))
            elif operacion == "vista_previa":
                dataset_id = str(resultado.get("dataset_id", ""))
                registros = list(resultado.get("registros") or [])
                resultado["registros"] = registros
                self.registrosListos.emit(dataset_id, registros)

            self._establecer_progreso(
                _mapa_progreso(
                    operacion,
                    "Completado",
                    indeterminado=False,
                    valor=1,
                    total=1,
                )
            )
            self._establecer_ocupado(False)
            self._operacion_actual = ""
            self.resultado.emit(resultado)
        except Exception as exc:  # noqa: BLE001 - fallo de commit/persistencia
            self._emitir_error(str(exc))

    @Slot(str)
    def _al_fallar_operacion(self, mensaje: str) -> None:
        self._detener_y_liberar_hilo()
        if self._cerrado:
            self._establecer_ocupado(False)
            self._operacion_actual = ""
            return
        self._emitir_error(mensaje)

    def _emitir_error(self, mensaje: str) -> None:
        operacion = self._operacion_actual
        descripcion = (
            "agregar el dataset"
            if operacion == "agregar"
            else "preparar la vista previa"
        )
        self._establecer_progreso(
            _mapa_progreso(
                operacion,
                "Error",
                indeterminado=False,
                detalle=mensaje,
            )
        )
        self._establecer_ocupado(False)
        self._operacion_actual = ""
        self.error.emit(f"No se pudo {descripcion}: {mensaje}")

    def _detener_y_liberar_hilo(self) -> None:
        hilo = self._hilo
        if hilo is not None:
            hilo.quit()
            if hilo.isRunning():
                hilo.wait()
            hilo.deleteLater()
        self._trabajador = None
        self._hilo = None

    @Slot()
    def cerrar(self) -> None:
        """Espera una operacion activa antes de destruir su ``QThread``.

        ``quit`` no aborta parsing/PDF a mitad de una llamada; ``wait`` evita
        el cierre inseguro ``QThread: Destroyed while thread is still running``.
        """
        self._cerrado = True
        self._detener_y_liberar_hilo()
        if self._ocupado:
            self._establecer_ocupado(False)
            self._operacion_actual = ""
