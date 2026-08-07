"""Carga y orquesta dos modelos para compararlos durante inferencia.

La comparacion mantiene una sesion independiente de ``MainViewModel``: abrir
dos modelos aqui no reemplaza el modelo que el usuario estaba entrenando o
explorando en la pantalla de inferencia.
"""

from __future__ import annotations

from dataclasses import asdict
from pathlib import Path
import threading
from typing import Any

from PySide6.QtCore import Property, QObject, Signal, Slot

from model.persistencia.model_storage import (
    cargar_checkpoint,
    cargar_modelo_portable,
    inspeccionar_modelo,
)

from .inference_controller import InferenceController
from .model_library_controller import ModelLibraryController, _ruta_local


class ComparisonController(QObject):
    """Expone a QML dos controladores de inferencia con parametros comunes."""

    controladoresCambio = Signal()
    modelosInfoCambio = Signal()
    modelosListosCambio = Signal()
    cargandoCambio = Signal()
    estaGenerandoCambio = Signal()
    cargaCompleta = Signal(str)
    error = Signal(str)

    _carga_lista = Signal(int, object, object, object, object, object, object)
    _carga_fallida = Signal(int, str)

    def __init__(
        self,
        biblioteca: ModelLibraryController,
        parent: QObject | None = None,
    ) -> None:
        super().__init__(parent)
        self._biblioteca = biblioteca
        self._controlador_a: InferenceController | None = None
        self._controlador_b: InferenceController | None = None
        self._info_a: dict[str, Any] = {}
        self._info_b: dict[str, Any] = {}
        self._cargando = False
        self._version_carga = 0
        self._hilos: set[threading.Thread] = set()
        self._bloqueo = threading.Lock()

        self._carga_lista.connect(self._instalar_modelos)
        self._carga_fallida.connect(self._al_fallar_carga)

    @Property(QObject, notify=controladoresCambio)
    def controladorA(self) -> InferenceController | None:
        return self._controlador_a

    @Property(QObject, notify=controladoresCambio)
    def controladorB(self) -> InferenceController | None:
        return self._controlador_b

    @Property("QVariantMap", notify=modelosInfoCambio)
    def modeloAInfo(self) -> dict[str, Any]:
        return dict(self._info_a)

    @Property("QVariantMap", notify=modelosInfoCambio)
    def modeloBInfo(self) -> dict[str, Any]:
        return dict(self._info_b)

    @Property(bool, notify=modelosListosCambio)
    def modelosListos(self) -> bool:
        return self._controlador_a is not None and self._controlador_b is not None

    @Property(bool, notify=cargandoCambio)
    def cargando(self) -> bool:
        return self._cargando

    @Property(bool, notify=estaGenerandoCambio)
    def estaGenerando(self) -> bool:
        return any(
            controlador is not None and controlador.esta_generando
            for controlador in (self._controlador_a, self._controlador_b)
        )

    @Property(int, notify=modelosInfoCambio)
    def maxTokensPermitidos(self) -> int:
        contextos = [
            int(info.get("longitud_maxima_secuencia", info.get("contexto", 512)))
            for info in (self._info_a, self._info_b)
            if info
        ]
        return max(1, min(512, *contextos)) if contextos else 512

    @Slot(str, str)
    def cargarModelos(self, ruta_a: str, ruta_b: str) -> None:
        """Carga ambos archivos en CPU sin bloquear el hilo de Qt."""
        origen_a = _ruta_local(ruta_a)
        origen_b = _ruta_local(ruta_b)
        if not str(origen_a) or not str(origen_b):
            self.error.emit("Selecciona dos modelos antes de continuar.")
            return
        try:
            if origen_a.resolve() == origen_b.resolve():
                self.error.emit("Selecciona dos modelos diferentes.")
                return
        except OSError as exc:
            self.error.emit(f"No se pudieron validar las rutas: {exc}")
            return
        if self._cargando:
            self.error.emit("La carga de modelos ya esta en curso.")
            return
        if self.estaGenerando:
            self.error.emit("Deten la generacion antes de cambiar los modelos.")
            return

        self._liberar_controladores()
        self._version_carga += 1
        version = self._version_carga
        self._cargando = True
        self.cargandoCambio.emit()

        def tarea() -> None:
            hilo = threading.current_thread()
            try:
                modelo_a, tokenizer_a, resultado_a, manifiesto_a = self._cargar_archivo(origen_a)
                modelo_b, tokenizer_b, resultado_b, manifiesto_b = self._cargar_archivo(origen_b)
                self._carga_lista.emit(
                    version,
                    modelo_a,
                    tokenizer_a,
                    self._crear_info(origen_a, modelo_a, resultado_a, manifiesto_a),
                    modelo_b,
                    tokenizer_b,
                    self._crear_info(origen_b, modelo_b, resultado_b, manifiesto_b),
                )
            except (OSError, ValueError, TypeError, RuntimeError) as exc:
                self._carga_fallida.emit(version, f"No se pudieron cargar los modelos: {exc}")
            except Exception as exc:  # frontera del hilo de carga
                self._carga_fallida.emit(
                    version,
                    f"No se pudieron cargar los modelos: {type(exc).__name__}: {exc}",
                )
            finally:
                with self._bloqueo:
                    self._hilos.discard(hilo)

        hilo = threading.Thread(target=tarea, name="comparison-loader", daemon=True)
        with self._bloqueo:
            self._hilos.add(hilo)
        try:
            hilo.start()
        except RuntimeError as exc:
            with self._bloqueo:
                self._hilos.discard(hilo)
            self._al_fallar_carga(version, f"No se pudo iniciar la carga: {exc}")

    @Slot(str, int, float, int, float, bool)
    def iniciarGeneracion(
        self,
        prompt: str,
        max_tokens_nuevos: int,
        temperatura: float,
        top_k: int,
        top_p: float,
        muestreo_codicioso: bool,
    ) -> None:
        if not self.modelosListos:
            self.error.emit("Primero carga dos modelos para comparar.")
            return
        if self.estaGenerando:
            return

        texto = prompt.strip()
        if not texto:
            self.error.emit("Escribe un prompt antes de generar.")
            return
        for etiqueta, controlador in (
            ("Modelo A", self._controlador_a),
            ("Modelo B", self._controlador_b),
        ):
            assert controlador is not None
            try:
                tokens_prompt = controlador.tokenizer.encode(texto)
            except (TypeError, ValueError) as exc:
                self.error.emit(f"{etiqueta} no pudo tokenizar el prompt: {exc}")
                return
            contexto = int(controlador.modelo.config.longitud_maxima_secuencia)
            if not tokens_prompt:
                self.error.emit("El prompt debe contener al menos un token.")
                return
            if len(tokens_prompt) > contexto:
                self.error.emit(
                    f"El prompt ocupa {len(tokens_prompt)} tokens en {etiqueta} "
                    f"y ese modelo admite {contexto}."
                )
                return

        top_k_real = top_k if top_k > 0 else None
        top_p_real = top_p if top_p < 1.0 else None
        for controlador in (self._controlador_a, self._controlador_b):
            assert controlador is not None
            controlador.iniciar_generacion(
                texto,
                max_tokens_nuevos=max_tokens_nuevos,
                temperatura=temperatura,
                top_k=top_k_real,
                top_p=top_p_real,
                muestreo_codicioso=muestreo_codicioso,
            )

    @Slot()
    def detener(self) -> None:
        for controlador in (self._controlador_a, self._controlador_b):
            if controlador is not None:
                controlador.detener()

    @Slot()
    def pausar(self) -> None:
        for controlador in (self._controlador_a, self._controlador_b):
            if controlador is not None:
                controlador.pausar()

    @Slot()
    def reanudar(self) -> None:
        for controlador in (self._controlador_a, self._controlador_b):
            if controlador is not None:
                controlador.reanudar()

    @Slot()
    def liberarModelos(self) -> None:
        """Invalida cargas pendientes y libera las dos sesiones de comparacion."""
        self._version_carga += 1
        if self._cargando:
            self._cargando = False
            self.cargandoCambio.emit()
        self._liberar_controladores()

    def _cargar_archivo(self, ruta: Path):
        if not ruta.is_file():
            raise FileNotFoundError(f"No se encontro el modelo: {ruta}")
        manifiesto = inspeccionar_modelo(ruta)
        resultado = (
            cargar_checkpoint(ruta, "cpu")
            if ruta.suffix.lower() == ".pt"
            else cargar_modelo_portable(ruta, "cpu")
        )
        modelo = getattr(resultado, "modelo", resultado)
        tokenizer = self._biblioteca._crear_tokenizer(resultado, manifiesto, modelo)
        modelo.eval()
        return modelo, tokenizer, resultado, manifiesto

    @staticmethod
    def _crear_info(ruta: Path, modelo, resultado, manifiesto: dict[str, Any]) -> dict[str, Any]:
        manifest = getattr(resultado, "manifest", None) or manifiesto or {}
        arquitectura = manifest.get("arquitectura", {})
        entrenamiento = manifest.get("entrenamiento", {})
        tokenizer = manifest.get("tokenizer", {})
        config = asdict(modelo.config)
        return {
            **config,
            "nombre": manifest.get("nombre", ruta.stem),
            "ruta": str(ruta.resolve()),
            "encoder_layers": arquitectura.get("encoder_layers", config["num_capas"]),
            "decoder_layers": arquitectura.get("decoder_layers", config["num_capas"]),
            "parametros_totales": sum(p.numel() for p in modelo.parameters()),
            "encoding": tokenizer.get("encoding", "Desconocido"),
            "epoca": entrenamiento.get("epoca"),
            "paso_global": entrenamiento.get("paso_global"),
        }

    @Slot(int, object, object, object, object, object, object)
    def _instalar_modelos(
        self,
        version: int,
        modelo_a,
        tokenizer_a,
        info_a,
        modelo_b,
        tokenizer_b,
        info_b,
    ) -> None:
        if version != self._version_carga:
            return

        self._controlador_a = self._crear_controlador(modelo_a, tokenizer_a)
        self._controlador_b = self._crear_controlador(modelo_b, tokenizer_b)
        self._info_a = dict(info_a)
        self._info_b = dict(info_b)
        self._cargando = False
        self.controladoresCambio.emit()
        self.modelosInfoCambio.emit()
        self.modelosListosCambio.emit()
        self.cargandoCambio.emit()
        self.cargaCompleta.emit("Dos modelos listos para comparar.")

    def _crear_controlador(self, modelo, tokenizer) -> InferenceController:
        id_relleno = modelo.config.id_token_relleno
        id_inicio = id_relleno + 1 if id_relleno is not None else None
        id_fin = id_relleno + 2 if id_relleno is not None else None
        controlador = InferenceController(modelo, tokenizer, id_inicio, id_fin, self)
        controlador.estaGenerandoCambio.connect(self.estaGenerandoCambio.emit)
        return controlador

    @Slot(int, str)
    def _al_fallar_carga(self, version: int, mensaje: str) -> None:
        if version != self._version_carga:
            return
        self._cargando = False
        self.cargandoCambio.emit()
        self.error.emit(mensaje)

    def _liberar_controladores(self) -> None:
        habia_modelos = self.modelosListos or bool(self._info_a) or bool(self._info_b)
        for controlador in (self._controlador_a, self._controlador_b):
            if controlador is not None:
                controlador.cerrar()
                controlador.setParent(None)
                controlador.deleteLater()
        self._controlador_a = None
        self._controlador_b = None
        self._info_a = {}
        self._info_b = {}
        if habia_modelos:
            self.controladoresCambio.emit()
            self.modelosInfoCambio.emit()
            self.modelosListosCambio.emit()
            self.estaGenerandoCambio.emit()


ComparacionController = ComparisonController
