"""Biblioteca de modelos portables expuesta a la interfaz QML.

El controlador mantiene la UI desacoplada del formato físico de los modelos:
presenta un catálogo de descriptores simples, delega la validación y la carga a
``model_storage`` y reconstruye el tokenizador que corresponde al vocabulario
del modelo.  Las operaciones que pueden copiar o materializar muchos pesos se
ejecutan fuera del hilo de la interfaz.
"""

from __future__ import annotations

from dataclasses import asdict, is_dataclass
import json
from pathlib import Path
import shutil
import threading
from typing import Any, Callable, Mapping

from PySide6.QtCore import Property, QMimeData, QObject, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication

from core.config import DIR_CHECKPOINTS, DISPOSITIVO
from model.motor_llm.tokenizer import ENCODINGS, Tokenizer
from model.persistencia.model_storage import (
    EXTENSION_MODELO,
    MAX_CARACTERES_CODIGO_MODELO,
    cargar_checkpoint,
    cargar_modelo_portable,
    exportar_codigo_modelo,
    importar_codigo_modelo,
    inspeccionar_modelo,
    sanitizar_nombre_modelo,
    verificar_integridad_modelo,
)


def _como_dict(valor: Any) -> dict[str, Any]:
    """Convierte manifiestos/dataclasses a ``dict`` sin imponer su clase."""
    if valor is None:
        return {}
    if isinstance(valor, dict):
        return valor
    if is_dataclass(valor) and not isinstance(valor, type):
        return asdict(valor)
    if isinstance(valor, Mapping):
        return dict(valor)
    try:
        return vars(valor)
    except TypeError:
        return {}


def _primero(*valores: Any, default: Any = None) -> Any:
    """Retorna el primer valor presente (``None`` y cadena vacía no cuentan)."""
    for valor in valores:
        if valor is not None and valor != "":
            return valor
    return default


def _entero(valor: Any, default: int = 0) -> int:
    try:
        return int(valor)
    except (TypeError, ValueError):
        return default


def _decimal(valor: Any, default: float = 0.0) -> float:
    try:
        return float(valor)
    except (TypeError, ValueError):
        return default


def _ruta_local(valor: str | Path) -> Path:
    """Acepta rutas nativas y URLs ``file:`` provenientes de QFileDialog."""
    if isinstance(valor, Path):
        return valor.expanduser()

    texto = str(valor).strip()
    if not texto:
        return Path()

    url = QUrl(texto)
    if url.isLocalFile():
        local = url.toLocalFile()
        if local:
            return Path(local)
    return Path(texto).expanduser()


def _tamano_legible(numero_bytes: int) -> str:
    valor = float(max(numero_bytes, 0))
    for unidad in ("B", "KiB", "MiB", "GiB", "TiB"):
        if valor < 1024.0 or unidad == "TiB":
            decimales = 0 if unidad == "B" else 1
            return f"{valor:.{decimales}f} {unidad}"
        valor /= 1024.0
    return f"{numero_bytes} B"


class ModelLibraryController(QObject):
    """Gestiona importación, exportación, inspección y carga de modelos.

    ``modelo_cargado`` entrega ``(modelo, tokenizer, resultado_carga)`` para
    que el ViewModel raíz active una sesión nueva sin que QML tenga que
    manipular objetos de PyTorch.
    """

    modelosCambio = Signal()
    modelo_cargado = Signal(object, object, object)
    operacion_exitosa = Signal(str)
    error = Signal(str)
    ocupadoCambio = Signal()
    _archivo_validado_para_copiar = Signal(str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._modelos: list[dict[str, Any]] = []
        self._ocupado = False
        self._bloqueo = threading.Lock()
        self._hilos: set[threading.Thread] = set()
        self._archivo_validado_para_copiar.connect(
            self._copiar_archivo_validado_al_portapapeles
        )
        self.refrescar()

    @Property("QVariantList", notify=modelosCambio)
    def modelos(self) -> list[dict[str, Any]]:
        """Descriptores amigables de todos los modelos de la biblioteca."""
        return list(self._modelos)

    @Property(bool, notify=ocupadoCambio)
    def ocupado(self) -> bool:
        """Indica que una importación, exportación o carga está en curso."""
        with self._bloqueo:
            return self._ocupado

    @Slot()
    def refrescar(self) -> None:
        """Relee los manifiestos de ``DIR_CHECKPOINTS`` y actualiza QML."""
        try:
            nuevos = self._construir_catalogo()
        except (OSError, ValueError, TypeError) as exc:
            self.error.emit(f"No se pudo actualizar la biblioteca de modelos: {exc}")
            return

        self._modelos = nuevos
        self.modelosCambio.emit()

    @Slot(result="QVariantList")
    def obtenerModelos(self) -> list[dict[str, Any]]:
        """Actualiza y devuelve el catálogo; útil al abrir la pantalla."""
        self.refrescar()
        return list(self._modelos)

    @Slot(str)
    def cargarModelo(self, ruta: str) -> None:
        """Carga y valida un modelo en segundo plano."""
        origen = _ruta_local(ruta)

        def tarea() -> None:
            if not origen.is_file():
                raise FileNotFoundError(f"No se encontró el modelo: {origen}")
            manifiesto = inspeccionar_modelo(origen)
            if origen.suffix.lower() == ".pt":
                resultado = cargar_checkpoint(origen, "cpu")
            else:
                resultado = cargar_modelo_portable(origen, "cpu")
            modelo = getattr(resultado, "modelo", resultado)
            tokenizer = self._crear_tokenizer(resultado, manifiesto, modelo)
            self.modelo_cargado.emit(modelo, tokenizer, resultado)

        self._ejecutar_en_segundo_plano("cargar el modelo", tarea)

    @Slot(str)
    def importarModelo(self, ruta: str) -> None:
        """Copia un ``.tvismodel`` o checkpoint legado a la biblioteca."""
        origen = _ruta_local(ruta)

        def tarea() -> None:
            if not origen.is_file():
                raise FileNotFoundError(f"No se encontró el archivo: {origen}")
            if origen.suffix.lower() not in {EXTENSION_MODELO.lower(), ".pt"}:
                raise ValueError(
                    f"Formato no compatible ({origen.suffix or 'sin extensión'}). "
                    f"Usa {EXTENSION_MODELO} o .pt."
                )

            # Inspeccionar antes de copiar evita almacenar basura en la biblioteca.
            verificar_integridad_modelo(origen)
            en_biblioteca = origen.resolve().parent == DIR_CHECKPOINTS.resolve()
            destino = origen if en_biblioteca else self._destino_disponible(origen.name)
            if origen.resolve() != destino.resolve():
                temporal = destino.with_name(f".{destino.name}.importando")
                try:
                    shutil.copy2(origen, temporal)
                    temporal.replace(destino)
                finally:
                    temporal.unlink(missing_ok=True)
            else:
                destino = origen

            # Verifica también la copia final, no solo el archivo de origen.
            verificar_integridad_modelo(destino)
            self.refrescar()
            self.operacion_exitosa.emit(f"Modelo importado: {destino.name}")

        self._ejecutar_en_segundo_plano("importar el modelo", tarea)

    @Slot(str, str)
    def exportarModelo(self, origen: str, destino: str) -> None:
        """Copia un modelo de la biblioteca a una ubicación elegida."""
        ruta_origen = _ruta_local(origen)
        ruta_destino = _ruta_local(destino)

        def tarea() -> None:
            if not ruta_origen.is_file():
                raise FileNotFoundError(f"No se encontró el modelo: {ruta_origen}")
            verificar_integridad_modelo(ruta_origen)

            final = ruta_destino / ruta_origen.name if ruta_destino.is_dir() else ruta_destino
            if not final.name:
                raise ValueError("Selecciona una ruta de destino válida.")
            if not final.suffix:
                final = final.with_suffix(ruta_origen.suffix or EXTENSION_MODELO)
            final.parent.mkdir(parents=True, exist_ok=True)

            if ruta_origen.resolve() != final.resolve():
                temporal = final.with_name(f".{final.name}.exportando")
                try:
                    shutil.copy2(ruta_origen, temporal)
                    temporal.replace(final)
                finally:
                    temporal.unlink(missing_ok=True)
            self.operacion_exitosa.emit(f"Modelo exportado en: {final}")

        self._ejecutar_en_segundo_plano("exportar el modelo", tarea)

    @Slot(str)
    def eliminarModelo(self, ruta: str) -> None:
        """La eliminación deliberadamente no está habilitada por seguridad."""
        del ruta
        self.error.emit("La eliminación de modelos no está habilitada.")

    @Slot(str)
    def copiarFicha(self, ruta: str) -> None:
        """Copia al portapapeles una ficha JSON, nunca los pesos."""
        try:
            origen = _ruta_local(ruta)
            manifiesto = _como_dict(inspeccionar_modelo(origen))
            descriptor = self._crear_descriptor(origen, manifiesto)
            ficha = {
                "nombre": descriptor["nombre"],
                "formato": descriptor["formato"],
                "capas_encoder": descriptor["capasEncoder"],
                "capas_decoder": descriptor["capasDecoder"],
                "cabezas": descriptor["cabezas"],
                "dimension_modelo": descriptor["dimension"],
                "dimension_ff": descriptor["dimensionFF"],
                "contexto": descriptor["contexto"],
                "vocabulario": descriptor["vocabulario"],
                "encoding": descriptor["encoding"],
                "parametros": descriptor["parametros"],
                "capacidades": descriptor["capacidades"],
            }
            self._portapapeles().setText(
                json.dumps(ficha, ensure_ascii=False, indent=2, sort_keys=True)
            )
            self.operacion_exitosa.emit("Ficha del modelo copiada al portapapeles.")
        except (OSError, ValueError, TypeError, RuntimeError) as exc:
            self.error.emit(f"No se pudo copiar la ficha: {exc}")

    @Slot(str)
    def copiarModelo(self, ruta: str) -> None:
        """Copia una URL de archivo, pegable en exploradores y aplicaciones."""
        origen = _ruta_local(ruta).resolve()

        def tarea() -> None:
            if not origen.is_file():
                raise FileNotFoundError(f"No se encontró el modelo: {origen}")
            verificar_integridad_modelo(origen)
            self._archivo_validado_para_copiar.emit(str(origen))

        self._ejecutar_en_segundo_plano("copiar el modelo", tarea)

    @Slot(str)
    def _copiar_archivo_validado_al_portapapeles(self, ruta: str) -> None:
        try:
            origen = Path(ruta)
            mime = QMimeData()
            mime.setUrls([QUrl.fromLocalFile(str(origen))])
            mime.setText(str(origen))
            self._portapapeles().setMimeData(mime)
            self.operacion_exitosa.emit("Modelo copiado; ya puedes pegar el archivo.")
        except (OSError, ValueError, TypeError, RuntimeError) as exc:
            self.error.emit(f"No se pudo copiar el modelo: {exc}")

    @Slot()
    def pegarModelo(self) -> None:
        """Importa el primer archivo o código TVIS disponible en el portapapeles."""
        try:
            mime = self._portapapeles().mimeData()
            if mime.hasUrls():
                for url in mime.urls():
                    if url.isLocalFile():
                        candidato = Path(url.toLocalFile())
                        if candidato.suffix.lower() in {EXTENSION_MODELO.lower(), ".pt"}:
                            self.importarModelo(str(candidato))
                            return

            texto_crudo = mime.text() if mime.hasText() else ""
            if len(texto_crudo) > MAX_CARACTERES_CODIGO_MODELO:
                raise ValueError("El codigo del portapapeles excede el limite de 5 MiB.")
            texto = texto_crudo.strip()
            if texto.upper().startswith("TVIS"):
                self.importarCodigo(texto, "modelo_compartido")
                return
            if texto:
                candidato = _ruta_local(texto)
                if candidato.is_file():
                    self.importarModelo(str(candidato))
                    return
            raise ValueError("El portapapeles no contiene un modelo o código TVIS válido.")
        except (OSError, ValueError, TypeError, RuntimeError) as exc:
            self.error.emit(f"No se pudo pegar el modelo: {exc}")

    @Slot(str, result=str)
    def exportarCodigo(self, ruta: str) -> str:
        """Devuelve el código textual portable de un modelo pequeño."""
        try:
            origen = _ruta_local(ruta)
            codigo = exportar_codigo_modelo(origen)
            self.operacion_exitosa.emit("Código del modelo generado.")
            return codigo
        except (OSError, ValueError, TypeError, RuntimeError) as exc:
            self.error.emit(f"No se pudo exportar el código: {exc}")
            return ""

    @Slot(str, str)
    def importarCodigo(self, codigo: str, nombre: str) -> None:
        """Decodifica un código TVIS directamente dentro de la biblioteca."""
        if not isinstance(codigo, str):
            self.error.emit("El codigo compartido debe ser texto.")
            return
        if len(codigo) > MAX_CARACTERES_CODIGO_MODELO:
            self.error.emit("El codigo excede el limite de 5 MiB para compartir texto.")
            return
        texto = codigo.strip()

        def tarea() -> None:
            if not texto:
                raise ValueError("El código del modelo está vacío.")
            nombre_seguro = sanitizar_nombre_modelo(nombre or "modelo_compartido")
            destino = self._destino_disponible(nombre_seguro)
            importar_codigo_modelo(texto, destino)
            inspeccionar_modelo(destino)
            self.refrescar()
            self.operacion_exitosa.emit(f"Modelo importado desde código: {destino.name}")

        self._ejecutar_en_segundo_plano("importar el código", tarea)

    # ------------------------------------------------------------------
    # Implementación interna
    # ------------------------------------------------------------------

    def _construir_catalogo(self) -> list[dict[str, Any]]:
        DIR_CHECKPOINTS.mkdir(parents=True, exist_ok=True)
        rutas = [
            ruta
            for ruta in DIR_CHECKPOINTS.iterdir()
            if ruta.is_file() and ruta.suffix.lower() in {EXTENSION_MODELO.lower(), ".pt"}
        ]
        rutas.sort(key=lambda p: p.stat().st_mtime, reverse=True)

        catalogo: list[dict[str, Any]] = []
        for ruta in rutas:
            try:
                manifiesto = _como_dict(inspeccionar_modelo(ruta))
                catalogo.append(self._crear_descriptor(ruta, manifiesto))
            except (OSError, ValueError, TypeError, RuntimeError) as exc:
                catalogo.append(self._descriptor_invalido(ruta, str(exc)))
        return catalogo

    def _crear_descriptor(self, ruta: Path, manifiesto: dict[str, Any]) -> dict[str, Any]:
        config = _como_dict(manifiesto.get("config"))
        arquitectura = _como_dict(manifiesto.get("arquitectura"))
        tokenizer = _como_dict(manifiesto.get("tokenizer"))
        pesos = _como_dict(manifiesto.get("pesos"))
        entrenamiento = _como_dict(manifiesto.get("entrenamiento"))
        capabilities = _como_dict(manifiesto.get("capabilities"))

        capas = _entero(_primero(
            arquitectura.get("num_capas"), arquitectura.get("capas"),
            arquitectura.get("encoder_layers"), config.get("num_capas"),
        ))
        capas_encoder = _entero(_primero(
            arquitectura.get("capas_encoder"), arquitectura.get("encoder_layers"), capas,
        ))
        capas_decoder = _entero(_primero(
            arquitectura.get("capas_decoder"), arquitectura.get("decoder_layers"), capas,
        ))
        cabezas = _entero(_primero(
            arquitectura.get("num_cabezas"), arquitectura.get("cabezas"),
            arquitectura.get("heads"), config.get("num_cabezas"),
        ))
        dimension = _entero(_primero(
            arquitectura.get("dimension_modelo"), arquitectura.get("d_model"),
            arquitectura.get("dimension"), config.get("dimension_modelo"),
        ))
        dimension_ff = _entero(_primero(
            arquitectura.get("dimension_ff"), arquitectura.get("d_ff"),
            config.get("dimension_ff"),
        ))
        contexto = _entero(_primero(
            arquitectura.get("longitud_maxima_secuencia"), arquitectura.get("context_length"),
            arquitectura.get("contexto"), config.get("longitud_maxima_secuencia"),
        ))
        vocabulario = _entero(_primero(
            arquitectura.get("tamano_vocabulario"), arquitectura.get("vocab_size"),
            config.get("tamano_vocabulario"), tokenizer.get("vocabulario_modelo"),
        ))
        dropout = _decimal(_primero(arquitectura.get("dropout"), config.get("dropout")))
        encoding = str(_primero(
            tokenizer.get("encoding"), tokenizer.get("nombre_encoding"),
            tokenizer.get("encoding_name"), default="Desconocido",
        ))
        parametros = _entero(_primero(
            pesos.get("num_parametros"), pesos.get("parametros"),
            pesos.get("parameter_count"),
            pesos.get("parametros_totales"), arquitectura.get("parametros_totales"),
            manifiesto.get("parametros_totales"), manifiesto.get("parametros"),
        ))
        tamano_bytes = ruta.stat().st_size

        reanudable = bool(_primero(
            capabilities.get("reanudable"), capabilities.get("reanudacion"),
            capabilities.get("resume_training"),
            entrenamiento.get("resume_available"),
            entrenamiento.get("optimizer_state_included"),
            entrenamiento.get("estado_optimizador_incluido"), default=False,
        ))
        reanudacion_exacta = bool(_primero(
            capabilities.get("reanudacion_exacta"),
            capabilities.get("exact_resume"), default=False,
        ))
        inferencia = bool(_primero(
            capabilities.get("inferencia"), capabilities.get("inference"), default=True,
        ))
        entrenable = bool(_primero(
            capabilities.get("entrenable"), capabilities.get("entrenamiento_desde_pesos"),
            capabilities.get("train_from_weights"), capabilities.get("trainable"), default=True,
        ))
        tokenizador_incluido = bool(_primero(
            capabilities.get("tokenizador_incluido"),
            bool(tokenizer) and encoding != "Desconocido",
        ))
        epoca = _entero(_primero(entrenamiento.get("epoca"), manifiesto.get("epoca")))
        paso_global = _entero(_primero(
            entrenamiento.get("paso_global"), entrenamiento.get("global_step"),
            manifiesto.get("paso_global"),
        ))
        perdida_final_valor = _primero(
            entrenamiento.get("perdida_final"), entrenamiento.get("last_loss"),
            manifiesto.get("perdida_final"),
        )
        perdida_final = (
            _decimal(perdida_final_valor) if perdida_final_valor is not None else None
        )

        capacidades: list[str] = []
        if inferencia:
            capacidades.append("Inferencia lista")
        if entrenable:
            capacidades.append("Entrenable desde pesos")
        if reanudable:
            capacidades.append(
                "Reanudación exacta" if reanudacion_exacta else "Reanudación disponible"
            )
        if tokenizador_incluido:
            capacidades.append("Tokenizador incluido")

        nombre = str(_primero(manifiesto.get("nombre"), manifiesto.get("name"), ruta.stem))
        formato_predeterminado = (
            "TVIS" if ruta.suffix.lower() == EXTENSION_MODELO.lower() else "Legacy PT"
        )
        formato = str(_primero(manifiesto.get("formato"), formato_predeterminado))
        legado = bool(manifiesto.get("es_legacy", ruta.suffix.lower() == ".pt"))
        fecha_creacion = str(_primero(
            manifiesto.get("fecha_creacion"), manifiesto.get("created_at"), default="",
        ))
        resumen = (
            f"Encoder {capas_encoder} + Decoder {capas_decoder} · "
            f"{cabezas} cabezas · d={dimension} · contexto {contexto}"
        )

        ruta_resuelta = str(ruta.resolve())
        compatible_declarado = bool(manifiesto.get("compatible", True))
        utilizable = inferencia or entrenable
        compatible = compatible_declarado and utilizable
        descriptor = {
            "manifest": manifiesto,
            "ruta": ruta_resuelta,
            "path": ruta_resuelta,
            "nombre": nombre,
            "archivo": ruta.name,
            "formato": formato,
            "legado": legado,
            "es_legacy": legado,
            "portable": not legado and formato in {"tvismodel", "TVIS"},
            "compatible": compatible,
            "error": "" if compatible else "No se pudo identificar un tokenizador compatible.",
            "versionFormato": _entero(_primero(
                manifiesto.get("schema_version"), manifiesto.get("format_version"),
                manifiesto.get("version_formato"),
            )),
            "capas": capas,
            "num_capas": capas,
            "encoder_layers": capas_encoder,
            "decoder_layers": capas_decoder,
            "capasEncoder": capas_encoder,
            "capasDecoder": capas_decoder,
            "cabezas": cabezas,
            "num_cabezas": cabezas,
            "dimension": dimension,
            "dimension_modelo": dimension,
            "d_model": dimension,
            "dimensionFF": dimension_ff,
            "dimension_ff": dimension_ff,
            "d_ff": dimension_ff,
            "contexto": contexto,
            "longitud_maxima_secuencia": contexto,
            "vocabulario": vocabulario,
            "tamano_vocabulario": vocabulario,
            "dropout": dropout,
            "encoding": encoding,
            "parametros": parametros,
            "parametros_totales": parametros,
            "tamanoBytes": tamano_bytes,
            "tamano_bytes": tamano_bytes,
            "tamano_archivo": tamano_bytes,
            "tamano": _tamano_legible(tamano_bytes),
            "tamano_legible": _tamano_legible(tamano_bytes),
            "fechaCreacion": fecha_creacion,
            "fecha_creacion": fecha_creacion,
            "reanudable": reanudable,
            "resume_available": reanudable,
            "reanudacionExacta": reanudacion_exacta,
            "reanudacion_exacta": reanudacion_exacta,
            "epoca": epoca,
            "paso_global": paso_global,
            "perdida_final": perdida_final,
            "inferencia": inferencia,
            "entrenable": entrenable,
            "tokenizadorIncluido": tokenizador_incluido,
            "tokenizador_incluido": tokenizador_incluido,
            "resumen": resumen,
            "capacidades": capacidades,
            "capabilities": capabilities,
        }
        return descriptor

    @staticmethod
    def _descriptor_invalido(ruta: Path, mensaje: str) -> dict[str, Any]:
        return {
            "manifest": {}, "ruta": str(ruta.resolve()), "path": str(ruta.resolve()),
            "nombre": ruta.stem, "archivo": ruta.name,
            "formato": "Desconocido", "portable": ruta.suffix.lower() == EXTENSION_MODELO.lower(),
            "legado": ruta.suffix.lower() == ".pt", "compatible": False,
            "es_legacy": ruta.suffix.lower() == ".pt",
            "error": mensaje, "versionFormato": 0,
            "capas": 0, "capasEncoder": 0, "capasDecoder": 0, "cabezas": 0,
            "num_capas": 0, "encoder_layers": 0, "decoder_layers": 0,
            "num_cabezas": 0, "dimension": 0, "dimension_modelo": 0, "d_model": 0,
            "dimensionFF": 0, "dimension_ff": 0, "d_ff": 0, "contexto": 0,
            "longitud_maxima_secuencia": 0, "vocabulario": 0, "tamano_vocabulario": 0,
            "dropout": 0.0, "encoding": "Desconocido", "parametros": 0,
            "parametros_totales": 0,
            "tamanoBytes": ruta.stat().st_size if ruta.exists() else 0,
            "tamano": _tamano_legible(ruta.stat().st_size if ruta.exists() else 0),
            "tamano_bytes": ruta.stat().st_size if ruta.exists() else 0,
            "tamano_archivo": ruta.stat().st_size if ruta.exists() else 0,
            "tamano_legible": _tamano_legible(ruta.stat().st_size if ruta.exists() else 0),
            "fechaCreacion": "", "fecha_creacion": "", "reanudable": False,
            "resume_available": False, "reanudacionExacta": False,
            "reanudacion_exacta": False, "inferencia": False,
            "epoca": 0, "paso_global": 0, "perdida_final": None,
            "entrenable": False, "tokenizadorIncluido": False,
            "tokenizador_incluido": False,
            "resumen": "Modelo incompatible", "capacidades": ["Formato incompatible"],
            "capabilities": {},
        }

    def _crear_tokenizer(self, resultado: Any, manifiesto_original: Any, modelo: Any) -> Tokenizer:
        manifiesto = _como_dict(
            _primero(getattr(resultado, "manifest", None),
                     getattr(resultado, "manifiesto", None), manifiesto_original)
        )
        info = _como_dict(manifiesto.get("tokenizer"))
        metadata = _como_dict(getattr(resultado, "metadata_extra", None))
        info_legacy = _como_dict(metadata.get("tokenizer"))

        candidato = _primero(
            getattr(resultado, "tipo_encoding", None),
            info.get("tipo_encoding"), info.get("encoding"), info.get("nombre_encoding"),
            info.get("encoding_name"), info_legacy.get("tipo_encoding"),
            info_legacy.get("encoding"), metadata.get("tipo_encoding"), metadata.get("encoding"),
        )
        vocab_modelo = _entero(getattr(getattr(modelo, "config", None), "tamano_vocabulario", 0))

        if isinstance(candidato, str):
            texto = candidato.strip()
            if texto.isdigit():
                candidato = int(texto)
            elif texto in ENCODINGS:
                candidato = ENCODINGS.index(texto)
            else:
                raise ValueError(f"El encoding '{texto}' no es compatible con esta aplicación.")

        if candidato is None:
            # Compatibilidad con .pt antiguos: deduce el encoding solo si el
            # vocabulario lo identifica sin ambigüedad (0 o 3 tokens especiales).
            coincidencias: list[int] = []
            import tiktoken

            for indice, nombre in enumerate(ENCODINGS):
                vocab_base = tiktoken.get_encoding(nombre).n_vocab
                if vocab_modelo == vocab_base + 3:
                    coincidencias.append(indice)
            if len(coincidencias) != 1:
                raise ValueError(
                    "El modelo no identifica su tokenizador y no puede deducirse "
                    f"de su vocabulario ({vocab_modelo})."
                )
            candidato = coincidencias[0]

        tokenizer = Tokenizer(_entero(candidato, -1))
        vocab_declarado = _entero(_primero(
            info.get("vocab_size"), info.get("tamano_vocabulario"),
            info_legacy.get("vocab_size"), info_legacy.get("tamano_vocabulario"),
        ))
        if vocab_declarado and vocab_declarado != tokenizer.vocab_size:
            raise ValueError(
                f"El manifiesto declara un vocabulario de {vocab_declarado}, pero "
                f"{ENCODINGS[tokenizer.tipo_encoding]} contiene {tokenizer.vocab_size}."
            )
        config_modelo = getattr(modelo, "config", None)
        id_relleno = getattr(config_modelo, "id_token_relleno", None)
        if vocab_modelo != tokenizer.vocab_size + 3 or id_relleno != tokenizer.vocab_size:
            raise ValueError(
                f"El vocabulario del modelo ({vocab_modelo}) no corresponde al "
                f"tokenizador {ENCODINGS[tokenizer.tipo_encoding]} "
                f"({tokenizer.vocab_size} + 3 especiales en posiciones canonicas)."
            )

        esperados = {
            "pad": tokenizer.vocab_size,
            "bos": tokenizer.vocab_size + 1,
            "eos": tokenizer.vocab_size + 2,
            "pad_id": tokenizer.vocab_size,
            "bos_id": tokenizer.vocab_size + 1,
            "eos_id": tokenizer.vocab_size + 2,
            "id_token_relleno": tokenizer.vocab_size,
            "id_token_inicio": tokenizer.vocab_size + 1,
            "id_token_fin": tokenizer.vocab_size + 2,
        }
        for nombre, esperado in esperados.items():
            token_id = info.get(nombre)
            if token_id is not None and _entero(token_id, -1) != esperado:
                raise ValueError(
                    f"El token especial {nombre}={token_id} no coincide con {esperado}."
                )

        return tokenizer

    def _destino_disponible(self, nombre: str) -> Path:
        """Genera un nombre seguro sin sobrescribir modelos existentes."""
        if Path(nombre).suffix.lower() == ".pt":
            # ``sanitizar_nombre_modelo`` normaliza al formato portable; se
            # reutiliza para limpiar el tallo, conservando aquí la extensión
            # del importador de compatibilidad legado.
            tallo_limpio = Path(sanitizar_nombre_modelo(Path(nombre).stem)).stem
            seguro = f"{tallo_limpio}.pt"
        else:
            seguro = sanitizar_nombre_modelo(nombre)
        destino = DIR_CHECKPOINTS / seguro
        if not destino.exists():
            return destino
        for indice in range(2, 10_000):
            candidato = destino.with_name(f"{destino.stem}_{indice}{destino.suffix}")
            if not candidato.exists():
                return candidato
        raise OSError("No se pudo encontrar un nombre libre para importar el modelo.")

    @staticmethod
    def _portapapeles():
        app = QGuiApplication.instance()
        if app is None or not hasattr(app, "clipboard"):
            raise RuntimeError("El portapapeles requiere que la aplicación gráfica esté iniciada.")
        return app.clipboard()

    def _ejecutar_en_segundo_plano(self, descripcion: str, tarea: Callable[[], None]) -> None:
        """Ejecuta una tarea pesada y traduce sus excepciones a una señal QML."""
        with self._bloqueo:
            ya_ocupado = self._ocupado
            if not ya_ocupado:
                self._ocupado = True
        if ya_ocupado:
            self.error.emit("Ya hay otra operación de modelos en curso.")
            return
        self.ocupadoCambio.emit()

        def ejecutar() -> None:
            hilo = threading.current_thread()
            try:
                tarea()
            except (OSError, ValueError, TypeError, RuntimeError) as exc:
                self.error.emit(f"No se pudo {descripcion}: {exc}")
            except Exception as exc:  # frontera de seguridad del hilo de trabajo
                self.error.emit(f"No se pudo {descripcion}: {type(exc).__name__}: {exc}")
            finally:
                with self._bloqueo:
                    self._ocupado = False
                    self._hilos.discard(hilo)
                self.ocupadoCambio.emit()

        hilo = threading.Thread(target=ejecutar, name="model-library", daemon=True)
        with self._bloqueo:
            self._hilos.add(hilo)
        try:
            hilo.start()
        except RuntimeError as exc:
            with self._bloqueo:
                self._hilos.discard(hilo)
                self._ocupado = False
            self.ocupadoCambio.emit()
            self.error.emit(f"No se pudo iniciar la operación para {descripcion}: {exc}")


# Alias en español para código Python existente y nombre inglés para QML/tests.
BibliotecaModelosController = ModelLibraryController
