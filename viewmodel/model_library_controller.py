"""Biblioteca de modelos portables expuesta a la interfaz QML.

El controlador mantiene la UI desacoplada del formato físico de los modelos:
presenta un catálogo de descriptores simples, delega la validación y la carga a
``model_storage`` y reconstruye el tokenizador que corresponde al vocabulario
del modelo.  Las operaciones que pueden copiar o materializar muchos pesos se
ejecutan fuera del hilo de la interfaz.
"""

from __future__ import annotations

from dataclasses import asdict, is_dataclass
import datetime
import json
import math
import os
from pathlib import Path
import shutil
import tempfile
import threading
import time
from typing import Any, Callable, Mapping

import torch
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

from model.motor_llm.config import ACTIVACIONES
from model.persistencia import model_storage as _model_storage


_SCHEMA_METADATA_BIBLIOTECA = "tvis-library-metadata"
_VERSION_METADATA_BIBLIOTECA = 1
_MAX_BYTES_METADATA_BIBLIOTECA = 256 * 1024
_MAX_CARACTERES_TOKENIZACION = 200_000

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

def _booleano(valor: Any, default: bool = False) -> bool:
    """Interpreta booleanos que pueden venir como bool, número o texto.

    Necesario porque `bool("false")` es `True` en Python: si un manifiesto
    trae la bandera como cadena (JSON mal serializado, exportadores
    externos), usar `bool()` directo invertiría silenciosamente el valor.
    """
    if isinstance(valor, bool):
        return valor
    if isinstance(valor, str):
        texto = valor.strip().lower()
        if texto in {"true", "1", "si", "sí", "yes"}:
            return True
        if texto in {"false", "0", "no"}:
            return False
        return default
    if isinstance(valor, (int, float)):
        return bool(valor)
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
    detalle_modelo_listo = Signal(dict)
    tokenizacion_lista = Signal(dict)
    prueba_salud_lista = Signal(dict)
    operacion_exitosa = Signal(str)
    error = Signal(str)
    ocupadoCambio = Signal()
    operacionActualCambio = Signal()
    modeloActivoRutaCambio = Signal()
    _archivo_validado_para_copiar = Signal(str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._modelos: list[dict[str, Any]] = []
        self._ocupado = False
        self._operacion_actual = ""
        self._modelo_activo_ruta = ""
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

    @Property(str, notify=operacionActualCambio)
    def operacionActual(self) -> str:
        """Descripción breve y honesta de la operación de fondo actual."""
        with self._bloqueo:
            return self._operacion_actual

    @Property(str, notify=modeloActivoRutaCambio)
    def modeloActivoRuta(self) -> str:
        """Ruta absoluta del modelo abierto en la sesión de inferencia.

        Una cadena vacía significa que todavía no se ha abierto ningún
        modelo desde la biblioteca. La comparación usa sesiones separadas y
        por ello no cambia esta propiedad.
        """
        return self._modelo_activo_ruta

    @Slot(str)
    def _establecer_modelo_activo(self, ruta: str) -> None:
        nueva_ruta = str(_ruta_local(ruta).resolve()) if ruta else ""
        if os.path.normcase(nueva_ruta) == os.path.normcase(
            self._modelo_activo_ruta
        ):
            return
        self._modelo_activo_ruta = nueva_ruta
        self.modeloActivoRutaCambio.emit()
        # Actualiza la insignia "Activo" de las tarjetas sin volver a leer
        # pesos o manifiestos desde disco.
        for modelo in self._modelos:
            activo = bool(
                nueva_ruta
                and os.path.normcase(str(modelo.get("ruta", "")))
                == os.path.normcase(nueva_ruta)
            )
            modelo["activo"] = activo
            modelo["esActivo"] = activo
            modelo["es_activo"] = activo
        self.modelosCambio.emit()

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

    @Slot(str,bool)
    def eliminarModelo(self, ruta: str,confirmacion:bool) -> None:
        """Elimina un modelo confirmado y su ficha local dentro de la biblioteca."""
        if not confirmacion:
            self.error.emit("Confirma la eliminación del modelo.")
            return
        try:
            archivo = self._validar_modelo_de_biblioteca(ruta)
            era_activo = os.path.normcase(str(archivo.resolve())) == os.path.normcase(
                self._modelo_activo_ruta
            )
            archivo.unlink()
            self._ruta_sidecar(archivo).unlink(missing_ok=True)
            if era_activo:
                self._establecer_modelo_activo("")
            self.refrescar()
            self.operacion_exitosa.emit(f"Modelo eliminado: {archivo.name}")
        except (OSError, ValueError, TypeError) as exc:
            self.error.emit(f"No se pudo eliminar el modelo: {exc}")

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
    # Ficha detallada, diagnósticos y organización local
    # ------------------------------------------------------------------

    @Slot(str)
    def solicitarDetalleModelo(self, ruta: str) -> None:
        """Construye la ficha educativa completa sin bloquear el hilo QML."""
        origen = _ruta_local(ruta)

        def tarea() -> None:
            if not origen.is_file():
                raise FileNotFoundError(f"No se encontró el modelo: {origen}")
            # La ficha de integridad afirma "verificado", por lo que esta
            # ruta recorre y contrasta los hashes sin construir el Transformer.
            manifiesto = _como_dict(verificar_integridad_modelo(origen))
            descriptor = self._crear_descriptor(origen, manifiesto)
            historial = self._inspeccionar_historial(origen, manifiesto)
            detalle = self._crear_detalle(
                origen,
                manifiesto,
                descriptor,
                historial,
                integridad_verificada=True,
            )
            self.detalle_modelo_listo.emit(detalle)

        self._ejecutar_en_segundo_plano("inspeccionar el modelo", tarea)

    @Slot(str, str)
    def analizarTokenizacion(self, ruta: str, texto: str) -> None:
        """Tokeniza texto con el encoding exacto declarado por el modelo."""
        origen = _ruta_local(ruta)
        texto = str(texto)
        if len(texto) > _MAX_CARACTERES_TOKENIZACION:
            self.error.emit(
                "El texto excede el límite de 200 000 caracteres para la prueba."
            )
            return

        def tarea() -> None:
            if not origen.is_file():
                raise FileNotFoundError(f"No se encontró el modelo: {origen}")
            manifiesto = _como_dict(inspeccionar_modelo(origen))
            descriptor = self._crear_descriptor(origen, manifiesto)
            tokenizer = self._crear_tokenizer_ligero(manifiesto, descriptor)
            ids = [int(item) for item in tokenizer.encode(texto)]
            contexto = int(descriptor.get("contexto") or 0)
            especiales = self._tokens_especiales(manifiesto, tokenizer)
            por_id = {
                int(info["id"]): str(info["nombre"])
                for info in especiales
                if info.get("id") is not None
            }
            piezas: list[dict[str, Any]] = []
            for indice, token_id in enumerate(ids):
                es_especial = token_id in por_id
                pieza = f"<{por_id[token_id]}>" if es_especial else self._decodificar_token(
                    tokenizer, token_id
                )
                piezas.append({
                    "indice": indice,
                    "id": token_id,
                    "texto": pieza,
                    "token": pieza,
                    "caracteres": len(pieza),
                    "esEspecial": es_especial,
                    "es_especial": es_especial,
                    "nombreEspecial": por_id.get(token_id, ""),
                })
            porcentaje = (len(ids) / contexto * 100.0) if contexto > 0 else None
            self.tokenizacion_lista.emit({
                "ruta": str(origen.resolve()),
                "texto": texto,
                "encoding": descriptor.get("encoding", "Desconocido"),
                "tokens": piezas,
                "ids": ids,
                "especiales": especiales,
                "conteoTokens": len(ids),
                "conteo_tokens": len(ids),
                "contexto": contexto,
                "porcentajeContexto": porcentaje,
                "porcentaje_contexto": porcentaje,
                "excedeContexto": bool(contexto and len(ids) > contexto),
                "excede_contexto": bool(contexto and len(ids) > contexto),
                "mensaje": (
                    "El texto excede el contexto del modelo."
                    if contexto and len(ids) > contexto
                    else "Tokenización completada con el encoding del modelo."
                ),
            })

        self._ejecutar_en_segundo_plano("analizar la tokenización", tarea)

    @Slot(str)
    def ejecutarPruebaSalud(self, ruta: str) -> None:
        """Ejecuta prompts cortos en modo greedy y reporta evidencia numérica.

        La prueba es deliberadamente determinista y no asigna una puntuación
        semántica: la coherencia de las respuestas requiere revisión humana.
        """
        origen = _ruta_local(ruta)

        def tarea() -> None:
            if not origen.is_file():
                raise FileNotFoundError(f"No se encontró el modelo: {origen}")
            manifiesto = _como_dict(inspeccionar_modelo(origen))
            resultado = (
                cargar_checkpoint(origen, "cpu")
                if origen.suffix.lower() == ".pt"
                else cargar_modelo_portable(origen, "cpu")
            )
            modelo = getattr(resultado, "modelo", resultado)
            tokenizer = self._crear_tokenizer(resultado, manifiesto, modelo)
            payload = self._probar_salud(origen, modelo, tokenizer)
            self.prueba_salud_lista.emit(payload)

        self._ejecutar_en_segundo_plano("ejecutar la prueba de salud", tarea)

    @Slot(str, str, str, "QVariantList", str)
    @Slot(str, str, str, "QVariantList", str, str)
    def actualizarMetadataModelo(
        self,
        ruta: str,
        nombre: str,
        notas: str,
        tags: list,
        grupo: str,
        version: str = "",
    ) -> None:
        """Actualiza nombre visible, notas, etiquetas y agrupación en sidecar.

        Nunca reescribe el manifiesto ni los pesos. El overload de cinco
        argumentos acepta ``grupo/version`` en una sola cadena.
        """
        try:
            origen = self._validar_modelo_de_biblioteca(ruta)
            grupo_limpio, version_limpia = self._separar_grupo_version(grupo, version)
            nombre_limpio = self._limpiar_texto_metadata(nombre, 240)
            if not nombre_limpio:
                raise ValueError("El nombre visible no puede quedar vacio.")
            metadata = self._leer_metadata_sidecar(origen, ignorar_errores=False)
            metadata.update({
                "schema": _SCHEMA_METADATA_BIBLIOTECA,
                "version_schema": _VERSION_METADATA_BIBLIOTECA,
                "nombre": nombre_limpio,
                "notas": self._limpiar_texto_metadata(notas, 20_000),
                "tags": self._limpiar_tags(tags),
                "grupo": grupo_limpio,
                "version": version_limpia,
                "actualizado_en": datetime.datetime.now(
                    tz=datetime.timezone.utc
                ).isoformat(),
            })
            self._escribir_metadata_sidecar(origen, metadata)
            self.refrescar()
            self.operacion_exitosa.emit("Ficha local del modelo actualizada.")
        except (OSError, ValueError, TypeError, RuntimeError) as exc:
            self.error.emit(f"No se pudo actualizar la ficha del modelo: {exc}")

    @Slot(str, str)
    def renombrarModelo(self, ruta: str, nombre: str) -> None:
        """Cambia solamente el nombre visible; el archivo permanece intacto."""
        try:
            origen = self._validar_modelo_de_biblioteca(ruta)
            nombre_limpio = self._limpiar_texto_metadata(nombre, 240)
            if not nombre_limpio:
                raise ValueError("El nombre visible no puede quedar vacio.")
            metadata = self._leer_metadata_sidecar(origen, ignorar_errores=False)
            metadata.update({
                "schema": _SCHEMA_METADATA_BIBLIOTECA,
                "version_schema": _VERSION_METADATA_BIBLIOTECA,
                "nombre": nombre_limpio,
                "actualizado_en": datetime.datetime.now(
                    tz=datetime.timezone.utc
                ).isoformat(),
            })
            self._escribir_metadata_sidecar(origen, metadata)
            self.refrescar()
            self.operacion_exitosa.emit(
                "Nombre visible actualizado; el archivo de pesos no se modificó."
            )
        except (OSError, ValueError, TypeError, RuntimeError) as exc:
            self.error.emit(f"No se pudo renombrar el modelo: {exc}")

    @Slot(str, str)
    def duplicarModelo(self, ruta: str, nombre: str) -> None:
        """Crea una copia verificada sin sobrescribir la versión original."""
        try:
            origen = self._validar_modelo_de_biblioteca(ruta)
        except (OSError, ValueError, TypeError) as exc:
            self.error.emit(f"No se pudo duplicar el modelo: {exc}")
            return

        def tarea() -> None:
            verificar_integridad_modelo(origen)
            extension = origen.suffix.lower()
            nombre_base = self._limpiar_texto_metadata(nombre, 240) or f"{origen.stem} copia"
            destino = self._destino_disponible(f"{nombre_base}{extension}")
            temporal = destino.with_name(f".{destino.name}.duplicando")
            try:
                shutil.copy2(origen, temporal)
                verificar_integridad_modelo(temporal)
                temporal.replace(destino)
            finally:
                temporal.unlink(missing_ok=True)

            metadata = self._leer_metadata_sidecar(origen, ignorar_errores=True)
            metadata.update({
                "schema": _SCHEMA_METADATA_BIBLIOTECA,
                "version_schema": _VERSION_METADATA_BIBLIOTECA,
                "nombre": nombre_base,
                "duplicado_de": str(origen.resolve()),
                "actualizado_en": datetime.datetime.now(
                    tz=datetime.timezone.utc
                ).isoformat(),
            })
            self._escribir_metadata_sidecar(destino, metadata)
            self.refrescar()
            self.operacion_exitosa.emit(f"Modelo duplicado: {destino.name}")

        self._ejecutar_en_segundo_plano("duplicar el modelo", tarea)

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
        metadata_extra = _como_dict(manifiesto.get("metadata_extra"))
        metadata_biblioteca = self._leer_metadata_sidecar(
            ruta, manifiesto, ignorar_errores=True
        )

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

        activacion = str(_primero(
            arquitectura.get("activacion"), arquitectura.get("activation"),
            config.get("activacion"), default="relu",
        )).strip().lower()
        if activacion not in ACTIVACIONES:
            activacion = "relu"

        usar_mascara_causal = _booleano(_primero(
            arquitectura.get("usar_mascara_causal"), arquitectura.get("mascara_causal"),
            arquitectura.get("causal_mask"), config.get("usar_mascara_causal"),
            default=True,
        ), default=True)   

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

        nombre_original = str(
            _primero(manifiesto.get("nombre"), manifiesto.get("name"), ruta.stem)
        )
        nombre = str(_primero(metadata_biblioteca.get("nombre"), nombre_original))
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
        grupo = str(_primero(
            metadata_biblioteca.get("grupo"), metadata_extra.get("grupo"),
            metadata_extra.get("experimento_id"), default="",
        ))
        version = str(_primero(
            metadata_biblioteca.get("version"), metadata_extra.get("version"), default="",
        ))
        tags = list(metadata_biblioteca.get("tags", []))
        notas = str(metadata_biblioteca.get("notas", ""))
        activo = bool(
            self._modelo_activo_ruta
            and os.path.normcase(ruta_resuelta)
            == os.path.normcase(self._modelo_activo_ruta)
        )
        compatible_declarado = bool(manifiesto.get("compatible", True))
        utilizable = inferencia or entrenable
        compatible = compatible_declarado and utilizable
        descriptor = {
            "manifest": manifiesto,
            "ruta": ruta_resuelta,
            "path": ruta_resuelta,
            "nombre": nombre,
            "nombreOriginal": nombre_original,
            "nombre_original": nombre_original,
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
            "activacion": activacion,
            "activation": activacion,
            "usar_mascara_causal": usar_mascara_causal,
            "usarMascaraCausal": usar_mascara_causal,
            "causal_mask": usar_mascara_causal,
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
            "metadataBiblioteca": metadata_biblioteca,
            "metadata_biblioteca": metadata_biblioteca,
            "notas": notas,
            "tags": tags,
            "grupo": grupo,
            "grupoVersion": grupo,
            "version": version,
            "activo": activo,
            "esActivo": activo,
            "es_activo": activo,
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
            "dropout": 0.0, "activacion": "relu", "activation": "relu",
            "usar_mascara_causal": True, "usarMascaraCausal": True, "causal_mask": True,
            "encoding": "Desconocido", "parametros": 0,
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
            "capabilities": {}, "metadataBiblioteca": {}, "metadata_biblioteca": {},
            "nombreOriginal": ruta.stem, "nombre_original": ruta.stem,
            "notas": "", "tags": [], "grupo": "", "grupoVersion": "",
            "version": "", "activo": False, "esActivo": False, "es_activo": False,
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

    @staticmethod
    def _ruta_sidecar(ruta: Path) -> Path:
        return ruta.with_name(f"{ruta.name}.library.json")

    @staticmethod
    def _limpiar_texto_metadata(valor: Any, limite: int) -> str:
        texto = str(valor or "").strip()
        if len(texto) > limite:
            raise ValueError(f"El texto excede el limite de {limite} caracteres.")
        return texto

    def _limpiar_tags(self, tags: Any) -> list[str]:
        if tags is None:
            return []
        if not isinstance(tags, (list, tuple)):
            raise TypeError("Las etiquetas deben enviarse como una lista.")
        resultado: list[str] = []
        for tag in tags:
            limpio = self._limpiar_texto_metadata(tag, 80)
            if limpio and limpio not in resultado:
                resultado.append(limpio)
            if len(resultado) > 100:
                raise ValueError("No se permiten mas de 100 etiquetas.")
        return resultado

    @staticmethod
    def _separar_grupo_version(grupo: Any, version: Any) -> tuple[str, str]:
        grupo_limpio = str(grupo or "").strip()
        version_limpia = str(version or "").strip()
        if len(grupo_limpio) > 240 or len(version_limpia) > 120:
            raise ValueError("Grupo o version exceden la longitud permitida.")
        return grupo_limpio, version_limpia

    def _leer_metadata_sidecar(
        self,
        ruta: Path,
        manifiesto: Mapping[str, Any] | None = None,
        *,
        ignorar_errores: bool,
    ) -> dict[str, Any]:
        sidecar = self._ruta_sidecar(ruta)
        if not sidecar.is_file():
            return {}
        try:
            if sidecar.stat().st_size > _MAX_BYTES_METADATA_BIBLIOTECA:
                raise ValueError("La ficha local excede el tamano permitido.")
            valor = json.loads(sidecar.read_text(encoding="utf-8"))
            if not isinstance(valor, dict):
                raise ValueError("La ficha local debe ser un objeto JSON.")
            if valor.get("schema") != _SCHEMA_METADATA_BIBLIOTECA:
                raise ValueError("La ficha local usa un esquema no compatible.")
            if valor.get("version_schema") != _VERSION_METADATA_BIBLIOTECA:
                raise ValueError("La ficha local usa una version no compatible.")
            tags = valor.get("tags", [])
            if not isinstance(tags, list):
                raise ValueError("Las etiquetas de la ficha no son validas.")
            return dict(valor)
        except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError, TypeError):
            if ignorar_errores:
                return {}
            raise

    def _escribir_metadata_sidecar(self, ruta: Path, metadata: Mapping[str, Any]) -> None:
        sidecar = self._ruta_sidecar(ruta)
        datos = json.dumps(
            dict(metadata), ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False
        ).encode("utf-8")
        if len(datos) > _MAX_BYTES_METADATA_BIBLIOTECA:
            raise ValueError("La ficha local excede el tamano permitido.")
        sidecar.parent.mkdir(parents=True, exist_ok=True)
        descriptor, temporal_nombre = tempfile.mkstemp(
            prefix=f".{sidecar.name}.", suffix=".tmp", dir=str(sidecar.parent)
        )
        temporal = Path(temporal_nombre)
        try:
            with os.fdopen(descriptor, "wb") as archivo:
                archivo.write(datos)
                archivo.flush()
                os.fsync(archivo.fileno())
            os.replace(temporal, sidecar)
        except Exception:
            temporal.unlink(missing_ok=True)
            raise

    @staticmethod
    def _validar_modelo_de_biblioteca(ruta: str | Path) -> Path:
        origen = _ruta_local(ruta).resolve()
        directorio = DIR_CHECKPOINTS.resolve()
        try:
            origen.relative_to(directorio)
        except ValueError as exc:
            raise ValueError("El modelo no pertenece a la biblioteca local.") from exc
        if not origen.is_file() or origen.suffix.lower() not in {
            EXTENSION_MODELO.lower(), ".pt"
        }:
            raise FileNotFoundError(f"No se encontro el modelo: {origen}")
        return origen

    @staticmethod
    def _inspeccionar_historial(
        ruta: Path, manifiesto: Mapping[str, Any]
    ) -> dict[str, Any]:
        inspector = getattr(
            _model_storage, "inspeccionar_historial_entrenamiento", None
        )
        if callable(inspector):
            # Una excepción del inspector significa corrupción real y no debe
            # convertirse silenciosamente en "sin datos".
            return dict(inspector(ruta))

        # Compatibilidad con instalaciones cuyo model_storage todavía no
        # ofrece inspección ligera. Este camino materializa el modelo, pero
        # conserva el mismo contrato y sigue ejecutándose fuera del hilo QML.
        resultado = (
            cargar_checkpoint(ruta, "cpu")
            if ruta.suffix.lower() == ".pt"
            else cargar_modelo_portable(ruta, "cpu")
        )
        historial = [
            float(valor)
            for valor in (getattr(resultado, "historial_perdidas", []) or [])
        ]
        entrenamiento = _como_dict(manifiesto.get("entrenamiento"))
        metadata = _como_dict(
            _primero(
                getattr(resultado, "metadata_extra", None),
                manifiesto.get("metadata_extra"),
                default={},
            )
        )
        hiperparametros = _como_dict(
            _primero(
                getattr(resultado, "hiperparametros_entrenamiento", None),
                manifiesto.get("hiperparametros_entrenamiento"),
                default={},
            )
        )
        estado_optimizador = getattr(resultado, "optimizer_state_dict", None) is not None
        epoca = _primero(getattr(resultado, "epoca", None), entrenamiento.get("epoca"))
        paso_global = _primero(
            getattr(resultado, "paso_global", None), entrenamiento.get("paso_global")
        )
        return {
            "historial_perdidas": historial,
            "epoca": epoca,
            "siguiente_epoca": _primero(
                getattr(resultado, "siguiente_epoca", None),
                entrenamiento.get("siguiente_epoca"),
            ),
            "paso_epoca": _primero(
                getattr(resultado, "paso_epoca", None),
                entrenamiento.get("paso_epoca"),
            ),
            "paso_global": paso_global,
            "perdida_final": historial[-1] if historial else None,
            "num_registros_perdida": len(historial),
            "hiperparametros_entrenamiento": hiperparametros,
            "metadata_extra": metadata,
            "resume_available": bool(
                entrenamiento.get("resume_available", estado_optimizador)
            ),
            "estado_optimizador_disponible": estado_optimizador,
            "formato": "pt_legacy" if ruta.suffix.lower() == ".pt" else "tvismodel",
            "es_legacy": ruta.suffix.lower() == ".pt",
        }

    def _versiones_del_grupo(self, grupo: str, ruta_actual: Path) -> list[dict[str, Any]]:
        if not grupo:
            return []
        versiones: list[dict[str, Any]] = []
        for item in self._modelos:
            if str(item.get("grupo", "")) == grupo:
                versiones.append({
                    "nombre": item.get("nombre"),
                    "ruta": item.get("ruta"),
                    "version": item.get("version", ""),
                    "epoca": item.get("epoca"),
                    "perdida": item.get("perdida_final"),
                    "actual": os.path.normcase(str(item.get("ruta", "")))
                    == os.path.normcase(str(ruta_actual.resolve())),
                })
        return versiones

    def _crear_detalle(
        self,
        ruta: Path,
        manifiesto: Mapping[str, Any],
        descriptor: Mapping[str, Any],
        historial: Mapping[str, Any],
        *,
        integridad_verificada: bool = False,
    ) -> dict[str, Any]:
        arquitectura = _como_dict(manifiesto.get("arquitectura"))
        pesos = _como_dict(manifiesto.get("pesos"))
        tokenizer = _como_dict(manifiesto.get("tokenizer"))
        capacidades = _como_dict(manifiesto.get("capabilities"))
        entrenamiento = _como_dict(manifiesto.get("entrenamiento"))
        metadata = _como_dict(historial.get("metadata_extra"))
        if not metadata:
            metadata = _como_dict(manifiesto.get("metadata_extra"))
        hiperparametros = _como_dict(historial.get("hiperparametros_entrenamiento"))
        if not hiperparametros:
            hiperparametros = _como_dict(
                manifiesto.get("hiperparametros_entrenamiento")
            )
        local = self._leer_metadata_sidecar(ruta, manifiesto, ignorar_errores=True)

        parametros_componentes = _como_dict(
            arquitectura.get("parametros_por_componente")
        )
        parametros_bloque = _como_dict(arquitectura.get("parametros_por_bloque"))
        bloques = [
            {
                "nombre": "Bloque encoder",
                "shapeEntrada": "[B, T_src, d_model]",
                "shapeSalida": "[B, T_src, d_model]",
                "repeticiones": arquitectura.get("encoder_layers"),
                "parametros": parametros_bloque.get("encoder"),
            },
            {
                "nombre": "Bloque decoder",
                "shapeEntrada": "[B, T_tgt, d_model]",
                "shapeSalida": "[B, T_tgt, d_model]",
                "repeticiones": arquitectura.get("decoder_layers"),
                "parametros": parametros_bloque.get("decoder"),
            },
        ]
        for nombre, valor in parametros_componentes.items():
            bloques.append({"nombre": nombre, "parametros": valor})
        tensores = [
            {
                "nombre": nombre,
                "shape": forma,
                "dtype": (
                    "int64" if nombre.startswith("tokens_") else pesos.get("dtype")
                ),
            }
            for nombre, forma in _como_dict(
                arquitectura.get("dimensiones_tensores")
            ).items()
        ]
        arquitectura_ui = dict(arquitectura)
        arquitectura_ui.update({"bloques": bloques, "tensores": tensores})

        datasets = metadata.get("datasets", hiperparametros.get("datasets", []))
        if isinstance(datasets, Mapping):
            datasets = [dict(datasets)]
        elif isinstance(datasets, (tuple, list)):
            datasets = list(datasets)
        elif datasets:
            datasets = [{"nombre": str(datasets)}]
        else:
            datasets = []
        if not datasets and metadata.get("origen_datos"):
            origen_datos = str(metadata["origen_datos"])
            datasets = [{
                "nombre": Path(origen_datos).name or origen_datos,
                "ruta": origen_datos,
            }]

        procedencia = dict(metadata)
        procedencia.update({
            "datasets": datasets,
            "tarea": _primero(metadata.get("tarea"), hiperparametros.get("tarea")),
            "learning_rate": _primero(
                hiperparametros.get("learning_rate"),
                hiperparametros.get("tasa_aprendizaje"),
            ),
            "batch_size": hiperparametros.get("batch_size"),
            "semilla": _primero(hiperparametros.get("semilla"), metadata.get("semilla")),
            "creado_en": _primero(
                manifiesto.get("fecha_creacion"), manifiesto.get("fecha")
            ),
        })

        perdidas = list(historial.get("historial_perdidas", []) or [])
        historial_ui: dict[str, Any] = {
            "perdidas": perdidas,
            "epoca": historial.get("epoca"),
            "paso_global": historial.get("paso_global"),
            "perdida_final": historial.get("perdida_final"),
            "checkpoints": self._versiones_del_grupo(
                str(descriptor.get("grupo", "")), ruta
            ),
            "mensaje": (
                "No hay una serie de perdida persistida en este checkpoint."
                if not perdidas else ""
            ),
        }
        for destino, claves in (
            ("validacion", ("historial_validacion", "validation_history")),
            ("perplexity", ("historial_perplexity", "perplexity_history")),
            ("precision", ("historial_precision", "accuracy_history")),
        ):
            for fuente in (metadata, hiperparametros):
                for clave in claves:
                    if isinstance(fuente.get(clave), list):
                        historial_ui[destino] = list(fuente[clave])
                        break
                if destino in historial_ui:
                    break

        checksum_pesos = _primero(
            manifiesto.get("checksum_pesos"), pesos.get("sha256")
        )
        checksum_estado = manifiesto.get("checksum_estado_entrenamiento")
        checksum_archivo = manifiesto.get("checksum_archivo")
        integridad = {
            "valida": True if integridad_verificada else None,
            "checksum": checksum_archivo or checksum_pesos,
            "checksum_pesos": checksum_pesos,
            "checksum_estado_entrenamiento": checksum_estado,
            "checksum_archivo": checksum_archivo,
            "algoritmo_checksum": "sha256",
            "dtype": manifiesto.get("dtype", pesos.get("dtype")),
            "dtypes": manifiesto.get("dtypes", pesos.get("dtypes", [])),
            "num_tensores": manifiesto.get("num_tensores", pesos.get("num_tensores")),
            "version_formato": manifiesto.get(
                "version_formato", manifiesto.get("schema_version")
            ),
            "tamano": descriptor.get("tamano"),
        }
        compatibilidad = {
            "compatible": descriptor.get("compatible", False),
            "mensaje": descriptor.get("error", ""),
            "reanudacionExacta": bool(
                _primero(
                    capacidades.get("reanudacion_exacta"),
                    capacidades.get("exact_resume"),
                    default=False,
                )
            ),
            "continuarConAdam": bool(
                historial.get("estado_optimizador_disponible", False)
            ),
            "entrenarDesdePesos": bool(descriptor.get("entrenable", False)),
        }
        grupo = str(descriptor.get("grupo", ""))
        gestion = {
            "nombre": descriptor.get("nombre"),
            "notas": local.get("notas", ""),
            "tags": local.get("tags", []),
            "grupo": grupo,
            "version": descriptor.get("version", ""),
            "versiones": self._versiones_del_grupo(grupo, ruta),
        }
        return {
            "ruta": str(ruta.resolve()),
            "nombre": descriptor.get("nombre"),
            "descriptor": dict(descriptor),
            "arquitectura": arquitectura_ui,
            "procedencia": procedencia,
            "historial": historial_ui,
            "tokenizador": tokenizer,
            "integridad": integridad,
            "compatibilidad": compatibilidad,
            "gestion": gestion,
        }

    def _crear_tokenizer_ligero(
        self, manifiesto: Mapping[str, Any], descriptor: Mapping[str, Any]
    ) -> Tokenizer:
        info = _como_dict(manifiesto.get("tokenizer"))
        candidato = _primero(
            info.get("tipo_encoding"), info.get("encoding"), descriptor.get("encoding")
        )
        if isinstance(candidato, str):
            if candidato not in ENCODINGS:
                raise ValueError(f"El encoding '{candidato}' no es compatible.")
            candidato = ENCODINGS.index(candidato)
        tokenizer = Tokenizer(_entero(candidato, -1))
        vocab = _entero(info.get("vocab_size"))
        if vocab and vocab != tokenizer.vocab_size:
            raise ValueError("El vocabulario declarado no coincide con el tokenizador.")
        return tokenizer

    @staticmethod
    def _tokens_especiales(
        manifiesto: Mapping[str, Any], tokenizer: Tokenizer
    ) -> list[dict[str, Any]]:
        info = _como_dict(manifiesto.get("tokenizer"))
        valores = (
            ("PAD", _primero(info.get("pad"), info.get("id_token_relleno"), tokenizer.vocab_size)),
            ("BOS", _primero(info.get("bos"), info.get("id_token_inicio"), tokenizer.vocab_size + 1)),
            ("EOS", _primero(info.get("eos"), info.get("id_token_fin"), tokenizer.vocab_size + 2)),
        )
        return [{"nombre": nombre, "id": int(token_id)} for nombre, token_id in valores]

    @staticmethod
    def _decodificar_token(tokenizer: Tokenizer, token_id: int) -> str:
        try:
            return tokenizer.decode([token_id])
        except (KeyError, ValueError, UnicodeDecodeError):
            try:
                return tokenizer.encoding.decode_single_token_bytes(token_id).decode(
                    "utf-8", errors="replace"
                )
            except (KeyError, ValueError):
                return "�"

    def _probar_salud(
        self, ruta: Path, modelo: Any, tokenizer: Tokenizer
    ) -> dict[str, Any]:
        modelo.eval()
        dispositivo = next(modelo.parameters()).device
        especiales = self._tokens_especiales(
            {"tokenizer": {"vocab_size": tokenizer.vocab_size}}, tokenizer
        )
        ids_especiales = {item["nombre"]: item["id"] for item in especiales}
        contexto = int(getattr(modelo.config, "longitud_maxima_secuencia", 32))
        prompts = ["Hola", "Explica brevemente qué es atención.", "1, 2, 3,"]
        muestras: list[dict[str, Any]] = []
        for prompt in prompts:
            inicio = time.perf_counter()
            salida_ids: list[int] = []
            ids_generados: list[int] = []
            confianzas: list[float] = []
            entropias: list[float] = []
            sumas_probabilidad: list[float] = []
            hay_nan = False
            hay_infinito = False
            eos = False
            error = ""
            salida = ""
            try:
                ids_origen = tokenizer.encode(prompt)[: max(1, contexto - 1)]
                if not ids_origen:
                    ids_origen = [0]
                tokens_origen = torch.tensor(
                    [ids_origen], dtype=torch.long, device=dispositivo
                )
                for paso in modelo.generar(
                    tokens_origen,
                    ids_especiales["BOS"],
                    ids_especiales["EOS"],
                    max_tokens_nuevos=min(16, max(1, contexto - 1)),
                    muestreo_codicioso=True,
                ):
                    token_id = int(paso["token_id"])
                    ids_generados.append(token_id)
                    logits = paso["logits"].detach().float()
                    hay_nan = hay_nan or bool(torch.isnan(logits).any().item())

                    # ``generar`` enmascara PAD y BOS con -Inf a propósito;
                    # se excluyen al buscar infinitos inesperados.
                    logits_diagnostico = logits.clone()
                    for nombre in ("PAD", "BOS"):
                        especial = ids_especiales[nombre]
                        if 0 <= especial < logits_diagnostico.size(-1):
                            logits_diagnostico[..., especial] = 0.0
                    hay_infinito = hay_infinito or bool(
                        torch.isinf(logits_diagnostico).any().item()
                    )

                    probabilidades = torch.softmax(logits, dim=-1)
                    if not bool(torch.isfinite(probabilidades).all().item()):
                        hay_nan = True
                    else:
                        suma = float(probabilidades.sum(dim=-1).mean().item())
                        sumas_probabilidad.append(suma)
                        confianza = float(probabilidades[0, token_id].item())
                        if math.isfinite(confianza):
                            confianzas.append(confianza)
                        entropia = float(
                            -(
                                probabilidades
                                * probabilidades.clamp_min(1e-12).log()
                            ).sum(dim=-1).mean().item()
                        )
                        if math.isfinite(entropia):
                            entropias.append(entropia)
                    if token_id == ids_especiales["EOS"]:
                        eos = True
                        break
                    if token_id < tokenizer.vocab_size:
                        salida_ids.append(token_id)
                salida = tokenizer.decode(salida_ids) if salida_ids else ""
            except (RuntimeError, ValueError, IndexError, TypeError) as exc:
                error = str(exc)
            duracion_ms = (time.perf_counter() - inicio) * 1000.0
            repeticiones = 0.0
            if len(salida_ids) > 1:
                repeticiones = 1.0 - len(set(salida_ids)) / len(salida_ids)
            total_generados = len(ids_generados)
            desviaciones_suma = [abs(valor - 1.0) for valor in sumas_probabilidad]
            muestras.append({
                "prompt": prompt,
                "salida": salida,
                "ids": ids_generados,
                "idsTexto": salida_ids,
                "tokens": total_generados,
                "latenciaMs": duracion_ms,
                "msPorToken": duracion_ms / max(total_generados, 1),
                "tokensPorSegundo": (
                    total_generados / (duracion_ms / 1000.0)
                    if duracion_ms > 0 else None
                ),
                "eos": eos,
                "confianzaMedia": (
                    sum(confianzas) / len(confianzas) if confianzas else None
                ),
                "entropiaMedia": (
                    sum(entropias) / len(entropias) if entropias else None
                ),
                "sumaProbabilidadesMedia": (
                    sum(sumas_probabilidad) / len(sumas_probabilidad)
                    if sumas_probabilidad else None
                ),
                "errorSumaProbabilidadesMax": (
                    max(desviaciones_suma) if desviaciones_suma else None
                ),
                "tasaRepeticion": repeticiones,
                "hayNaN": hay_nan,
                "hayInfinito": hay_infinito,
                "error": error,
            })
        validas = [m for m in muestras if not m.get("error")]
        def promedio(clave: str) -> float | None:
            valores = [float(m[clave]) for m in validas if m.get(clave) is not None]
            return sum(valores) / len(valores) if valores else None

        resumen = {
            "muestras": len(muestras),
            "hayNaN": any(bool(m.get("hayNaN")) for m in muestras),
            "hayInfinito": any(bool(m.get("hayInfinito")) for m in muestras),
            "errores": sum(1 for m in muestras if m.get("error")),
            "tasaEOS": (
                sum(1 for m in validas if m.get("eos")) / len(validas)
                if validas else None
            ),
            "latenciaMediaMs": promedio("latenciaMs"),
            "tokensPorSegundoMedio": promedio("tokensPorSegundo"),
            "confianzaMedia": promedio("confianzaMedia"),
            "entropiaMedia": promedio("entropiaMedia"),
            "sumaProbabilidadesMedia": promedio("sumaProbabilidadesMedia"),
            "errorSumaProbabilidadesMax": max(
                (
                    float(m["errorSumaProbabilidadesMax"])
                    for m in validas
                    if m.get("errorSumaProbabilidadesMax") is not None
                ),
                default=None,
            ),
            "tasaRepeticionMedia": promedio("tasaRepeticion"),
        }
        advertencias: list[str] = []
        if resumen["errores"]:
            advertencias.append("Una o mas muestras no pudieron completarse.")
        if resumen["hayNaN"] or resumen["hayInfinito"]:
            advertencias.append("Se detectaron logits o probabilidades no finitos.")
        if validas and any(not muestra.get("eos") for muestra in validas):
            advertencias.append("EOS no aparecio dentro del limite en alguna muestra.")
        if any(float(m.get("tasaRepeticion", 0.0)) >= 0.5 for m in validas):
            advertencias.append("Se observo repeticion alta en alguna muestra.")
        return {
            "ruta": str(ruta.resolve()),
            "determinista": True,
            "modo": "greedy",
            "muestras": muestras,
            "resumen": resumen,
            "advertencias": advertencias,
            "coherencia": {
                "automatico": False,
                "estado": "requiere_revision_humana",
                "mensaje": "No evaluada automáticamente: requiere revisión humana de las salidas.",
            },
        }

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
                self._operacion_actual = descripcion.strip().capitalize()
        if ya_ocupado:
            self.error.emit("Ya hay otra operación de modelos en curso.")
            return
        self.ocupadoCambio.emit()
        self.operacionActualCambio.emit()

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
                    self._operacion_actual = ""
                    self._hilos.discard(hilo)
                self.ocupadoCambio.emit()
                self.operacionActualCambio.emit()

        hilo = threading.Thread(target=ejecutar, name="model-library", daemon=True)
        with self._bloqueo:
            self._hilos.add(hilo)
        try:
            hilo.start()
        except RuntimeError as exc:
            with self._bloqueo:
                self._hilos.discard(hilo)
                self._ocupado = False
                self._operacion_actual = ""
            self.ocupadoCambio.emit()
            self.operacionActualCambio.emit()
            self.error.emit(f"No se pudo iniciar la operación para {descripcion}: {exc}")


# Alias en español para código Python existente y nombre inglés para QML/tests.
BibliotecaModelosController = ModelLibraryController
