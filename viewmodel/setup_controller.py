"""
Controlador de Configuración (Setup).

Es el ÚNICO controlador que CREA el modelo: junta los hiperparámetros
que el usuario elige en la pantalla de Setup, valida que sean
consistentes (delegando en `ConfiguracionTransformer.__post_init__`),
instancia el `Tokenizer` y el `Transformer`, y los expone al resto de
la aplicación vía la señal `modelo_creado`.

`InferenceController` y `TrainingController` NO crean su propio modelo
— reciben la instancia ya armada aquí (típicamente conectado desde
`main_viewmodel.py`, que escucha `modelo_creado` y ahí sí instancia a
los otros dos controladores con el modelo recién creado).
"""

import json
import re
import threading
from pathlib import Path

from PySide6.QtCore import Property, QObject, Signal, Slot

from core.rutas import DIR_CONFIGURACIONES

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.tokenizer import ENCODINGS, Tokenizer
from model.motor_llm.transformer import Transformer

# Tamaños de vocabulario conocidos de cada encoding de tiktoken (mismo
# orden que ENCODINGS). Se hardcodean a propósito para que el preview en
# vivo (`_recalcular_resumen`) NO tenga que instanciar `Tokenizer` —y por
# lo tanto no dispare una descarga de red— cada vez que el usuario mueve
# un slider que no tiene nada que ver con el tokenizador. El `Tokenizer`
# real solo se instancia una vez, al confirmar en `crear_modelo()`.
#
# Si tiktoken llegara a cambiar estos valores en una versión futura,
# `crear_modelo()` seguiría siendo 100% correcto (usa el `Tokenizer` real);
# solo el preview en vivo podría quedar desactualizado momentáneamente.
TAMANOS_VOCABULARIO_CONOCIDOS = {
    0: 200_019,  # o200k_base
    1: 100_277,  # cl100k_base
    2: 50_281,   # p50k_base
}

ACTIVACIONES = ["relu", "gelu", "swish"]

# Catálogo de configuraciones arquitectónicas listas para usar (RF21). Son
# puntos de partida: al aplicarlas solo se cargan los valores en los
# controles; el usuario puede seguir ajustándolos antes de entrenar.
CONFIGURACIONES_PREDEFINIDAS = [
    {
        "id": "minima",
        "nombre": "Mínima",
        "descripcion": "1 capa, 2 cabezas y d_model = 32. Entrena rápido y "
                       "permite seguir cada tensor con pocas dimensiones.",
        "arquitectura": {
            "dimension_modelo": 32, "num_cabezas": 2, "num_capas": 1,
            "dimension_ff": 128, "longitud_maxima_secuencia": 32,
            "dropout": 0.1, "activacion": "relu", "usar_mascara_causal": True,
        },
        "entrenamiento": {"epocas": 6, "tasa_aprendizaje": 0.001, "batch_size": 6},
    },
    {
        "id": "pequena",
        "nombre": "Pequeña",
        "descripcion": "2 capas, 4 cabezas y d_model = 64. Es la arquitectura "
                       "usada en las pruebas funcionales del proyecto.",
        "arquitectura": {
            "dimension_modelo": 64, "num_cabezas": 4, "num_capas": 2,
            "dimension_ff": 256, "longitud_maxima_secuencia": 64,
            "dropout": 0.1, "activacion": "relu", "usar_mascara_causal": True,
        },
        "entrenamiento": {"epocas": 8, "tasa_aprendizaje": 0.001, "batch_size": 6},
    },
    {
        "id": "mediana",
        "nombre": "Mediana",
        "descripcion": "4 capas, 8 cabezas y d_model = 128 con GELU. Requiere más "
                       "memoria y tiempo; conviene usarla con GPU.",
        "arquitectura": {
            "dimension_modelo": 128, "num_cabezas": 8, "num_capas": 4,
            "dimension_ff": 512, "longitud_maxima_secuencia": 128,
            "dropout": 0.1, "activacion": "gelu", "usar_mascara_causal": True,
        },
        "entrenamiento": {"epocas": 6, "tasa_aprendizaje": 0.0003, "batch_size": 4},
    },
    {
        "id": "base_2017",
        "nombre": "Base del artículo original",
        "descripcion": "6 capas, 8 cabezas, d_model = 512 y d_ff = 2048, como el "
                       "modelo base de Vaswani et al. (2017). Sirve como referencia "
                       "de escala; entrenarlo requiere una GPU con mucha memoria.",
        "arquitectura": {
            "dimension_modelo": 512, "num_cabezas": 8, "num_capas": 6,
            "dimension_ff": 2048, "longitud_maxima_secuencia": 128,
            "dropout": 0.1, "activacion": "relu", "usar_mascara_causal": True,
        },
        "entrenamiento": {"epocas": 1, "tasa_aprendizaje": 0.0001, "batch_size": 2},
    },
]

# Campos que se guardan/cargan en un archivo de configuración, con su tipo.
_CAMPOS_ARQUITECTURA = {
    "tipo_encoding": int,
    "dimension_modelo": int,
    "num_cabezas": int,
    "num_capas": int,
    "dimension_ff": int,
    "longitud_maxima_secuencia": int,
    "dropout": float,
    "compartir_pesos_salida": bool,
    "activacion": str,
    "usar_mascara_causal": bool,
    "usar_sesgo": bool,
}
_CAMPOS_ENTRENAMIENTO = {
    "epocas": int,
    "tasa_aprendizaje": float,
    "batch_size": int,
}
FORMATO_CONFIGURACION = "tvis-configuracion"
VERSION_CONFIGURACION = 1

class SetupController(QObject):
    """Controlador de configuración inicial del modelo.

    Flujo típico:
        1. La Vista llama a los `establecer_*` mientras el usuario mueve
           sliders/selecciona opciones. Cada llamada recalcula un
           resumen (parámetros totales, memoria estimada) SIN crear el
           modelo completo, y lo emite por `resumen_cambio`.
        2. Cuando el usuario confirma, la Vista llama a `crear_modelo()`,
           que instancia el `Tokenizer` y el `Transformer` reales.
        3. Si todo salió bien, se emite `modelo_creado(modelo, tokenizer)`
           — quien esté escuchando (normalmente `main_viewmodel.py`)
           arma ahí `InferenceController` / `TrainingController` con
           esa instancia.
        4. Si algo falla (ej. `dimension_modelo` no divisible entre
           `num_cabezas`), se emite `error_configuracion` en su lugar.
    """

    modelo_creado = Signal(object, object)  # (Transformer, Tokenizer)
    error_configuracion = Signal(str)
    resumen_cambio = Signal(dict)
    configuracionValidaCambio = Signal()
    errorConfiguracionCambio = Signal()
    configuracionActualCambio = Signal()
    ocupadoCambio = Signal()
    faseCambio = Signal()
    configuracionesGuardadasCambio = Signal()

    # Estas senales privadas son el puente seguro entre el hilo Python que
    # materializa los pesos y el hilo de Qt, donde se actualiza el estado QML.
    _fase_creacion_recibida = Signal(int, str)
    _creacion_terminada = Signal(int, object, object)
    _creacion_fallida = Signal(int, str)

    def __init__(
        self,
        parent: QObject | None = None,
        directorio_configuraciones: str | Path | None = None,
    ):
        super().__init__(parent)
        self._directorio_configuraciones = Path(
            directorio_configuraciones or DIR_CONFIGURACIONES
        )
        self.modelo: Transformer | None = None
        self.tokenizer: Tokenizer | None = None

        self._tipo_encoding = 1  # cl100k_base
        # Valores iniciales de la experiencia interactiva. Mantenerlos aquí
        # evita que QML y el controlador construyan transitoriamente 64/6.
        self._dimension_modelo = 64
        self._num_cabezas = 4
        self._num_capas = 6
        self._dimension_ff = 4 * 64
        self._longitud_maxima_secuencia = 64
        self._dropout = 0.1
        self._compartir_pesos_salida = True
        self._activacion = "relu"
        self._usar_mascara_causal = True
        self._usar_sesgo = True
        self._configuracion_valida = True
        self._error_configuracion_actual = ""
        self._ocupado = False
        self._fase = ""
        self._version_creacion = 0
        self._cancelacion_creacion_pendiente = False

        self._fase_creacion_recibida.connect(self._actualizar_fase_async)
        self._creacion_terminada.connect(self._finalizar_creacion_async)
        self._creacion_fallida.connect(self._fallar_creacion_async)

    # ------------------------------------------------------------------
    # Estado observable por QML
    # ------------------------------------------------------------------

    @Property(bool, notify=configuracionValidaCambio)
    def configuracionValida(self) -> bool:
        """Indica si los valores actuales pueden formar una configuración."""
        return self._configuracion_valida

    @Property(str, notify=errorConfiguracionCambio)
    def errorConfiguracion(self) -> str:
        """Último error de validación; se vacía al corregir los valores."""
        return self._error_configuracion_actual

    @Property("QVariantMap", notify=configuracionActualCambio)
    def configuracionActual(self) -> dict:
        """Instantánea de los controles de arquitectura y tokenización."""
        return self._obtener_configuracion_actual()

    @Property(bool, notify=ocupadoCambio)
    def ocupado(self) -> bool:
        """Indica que el tokenizador o los pesos se construyen en segundo plano."""
        return self._ocupado

    @Property(str, notify=faseCambio)
    def fase(self) -> str:
        """Descripcion breve de la fase de creacion que ve la interfaz."""
        return self._fase

    def _establecer_estado_creacion(
        self, *, ocupado: bool | None = None, fase: str | None = None
    ) -> None:
        if ocupado is not None and ocupado != self._ocupado:
            self._ocupado = ocupado
            self.ocupadoCambio.emit()
        if fase is not None and fase != self._fase:
            self._fase = fase
            self.faseCambio.emit()

    def _obtener_configuracion_actual(self) -> dict:
        return {
            "tipo_encoding": self._tipo_encoding,
            "dimension_modelo": self._dimension_modelo,
            "num_cabezas": self._num_cabezas,
            "num_capas": self._num_capas,
            "dimension_ff": self._dimension_ff,
            "longitud_maxima_secuencia": self._longitud_maxima_secuencia,
            "dropout": self._dropout,
            "compartir_pesos_salida": self._compartir_pesos_salida,
            "activacion": self._activacion,
            "usar_mascara_causal": self._usar_mascara_causal,
            "usar_sesgo": self._usar_sesgo,
        }

    # ------------------------------------------------------------------
    # Configuraciones predefinidas y guardadas (RF21 / objetivo 1)
    # ------------------------------------------------------------------

    @Property("QVariantList", constant=True)
    def configuracionesPredefinidas(self) -> list:
        return [
            {
                "id": item["id"],
                "nombre": item["nombre"],
                "descripcion": item["descripcion"],
                "arquitectura": dict(item["arquitectura"]),
                "entrenamiento": dict(item["entrenamiento"]),
            }
            for item in CONFIGURACIONES_PREDEFINIDAS
        ]

    @Property("QVariantList", notify=configuracionesGuardadasCambio)
    def configuracionesGuardadas(self) -> list:
        """Archivos ``.json`` de configuración guardados por el usuario."""
        if not self._directorio_configuraciones.is_dir():
            return []
        resultado = []
        for ruta in sorted(self._directorio_configuraciones.glob("*.json")):
            try:
                datos = self._leer_archivo_configuracion(ruta)
            except ValueError:
                continue
            resultado.append(
                {"nombre": str(datos.get("nombre") or ruta.stem), "ruta": str(ruta)}
            )
        return resultado

    def _aplicar_arquitectura(self, arquitectura: dict) -> None:
        """Carga valores en los controles y valida una sola vez al final."""
        cambio = False
        for campo, tipo in _CAMPOS_ARQUITECTURA.items():
            if campo not in arquitectura:
                continue
            valor = tipo(arquitectura[campo])
            atributo = "_" + campo
            if getattr(self, atributo) != valor:
                setattr(self, atributo, valor)
                cambio = True
        if cambio:
            self.configuracionActualCambio.emit()
        self._recalcular_resumen()

    @Slot(str, result="QVariantMap")
    def aplicarConfiguracionPredefinida(self, identificador: str) -> dict:
        """Aplica una configuración del catálogo y devuelve los parámetros de
        entrenamiento sugeridos para que la Vista actualice sus controles."""
        for item in CONFIGURACIONES_PREDEFINIDAS:
            if item["id"] == identificador:
                self._aplicar_arquitectura(item["arquitectura"])
                return dict(item["entrenamiento"])
        self.error_configuracion.emit(
            f"No existe la configuración predefinida '{identificador}'."
        )
        return {}

    @staticmethod
    def _nombre_archivo_configuracion(nombre: str) -> str:
        limpio = re.sub(r"[^\w\-]+", "_", nombre.strip()).strip("_")[:80]
        return limpio or "configuracion"

    @Slot(str, "QVariantMap", result=str)
    def guardarConfiguracion(self, nombre: str, entrenamiento: dict) -> str:
        """Guarda la arquitectura actual y los parámetros de entrenamiento en
        un archivo JSON independiente de cualquier modelo. Devuelve la ruta
        escrita, o cadena vacía si falló (el motivo se emite por
        ``error_configuracion``). Nunca sobrescribe un archivo existente."""
        if not self._configuracion_valida:
            self.error_configuracion.emit(
                "La configuración actual no es válida; corrígela antes de guardarla."
            )
            return ""
        nombre = str(nombre or "").strip()
        if not nombre:
            self.error_configuracion.emit("Escribe un nombre para la configuración.")
            return ""
        datos_entrenamiento = {}
        for campo, tipo in _CAMPOS_ENTRENAMIENTO.items():
            if entrenamiento and campo in entrenamiento:
                datos_entrenamiento[campo] = tipo(entrenamiento[campo])
        contenido = {
            "formato": FORMATO_CONFIGURACION,
            "version": VERSION_CONFIGURACION,
            "nombre": nombre,
            "arquitectura": self._obtener_configuracion_actual(),
            "entrenamiento": datos_entrenamiento,
        }
        try:
            self._directorio_configuraciones.mkdir(parents=True, exist_ok=True)
            base = self._nombre_archivo_configuracion(nombre)
            ruta = self._directorio_configuraciones / f"{base}.json"
            contador = 2
            while ruta.exists():
                ruta = self._directorio_configuraciones / f"{base}_{contador}.json"
                contador += 1
            temporal = ruta.with_name(ruta.name + ".tmp")
            temporal.write_text(
                json.dumps(contenido, ensure_ascii=False, indent=2), encoding="utf-8"
            )
            temporal.replace(ruta)
        except OSError as exc:
            self.error_configuracion.emit(f"No se pudo guardar la configuración: {exc}")
            return ""
        self.configuracionesGuardadasCambio.emit()
        return str(ruta)

    @staticmethod
    def _leer_archivo_configuracion(ruta: Path) -> dict:
        try:
            datos = json.loads(Path(ruta).read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise ValueError(f"No se pudo leer la configuración: {exc}") from exc
        if not isinstance(datos, dict) or datos.get("formato") != FORMATO_CONFIGURACION:
            raise ValueError("El archivo no es una configuración de la herramienta.")
        if not isinstance(datos.get("arquitectura"), dict):
            raise ValueError("La configuración no contiene la arquitectura.")
        return datos

    @Slot(str, result="QVariantMap")
    def cargarConfiguracion(self, ruta: str) -> dict:
        """Carga una configuración guardada. La arquitectura solo se aplica
        si es válida; si no, los controles conservan sus valores."""
        try:
            datos = self._leer_archivo_configuracion(Path(ruta))
            arquitectura = {}
            for campo, tipo in _CAMPOS_ARQUITECTURA.items():
                if campo not in datos["arquitectura"]:
                    continue
                valor = datos["arquitectura"][campo]
                if isinstance(valor, bool) != (tipo is bool):
                    raise ValueError(f"El campo {campo} no es válido.")
                arquitectura[campo] = tipo(valor)
            if arquitectura.get("activacion", self._activacion) not in ACTIVACIONES:
                raise ValueError("La función de activación no es válida.")
            if (
                arquitectura.get("tipo_encoding", self._tipo_encoding)
                not in TAMANOS_VOCABULARIO_CONOCIDOS
            ):
                raise ValueError("El tokenizador indicado no es válido.")
            # Se valida con los valores nuevos y se restaura el estado previo
            # antes de aplicarlos, para no dejar los controles a medias.
            respaldo = self._obtener_configuracion_actual()
            for campo, valor in arquitectura.items():
                setattr(self, "_" + campo, valor)
            try:
                self._construir_configuracion(
                    TAMANOS_VOCABULARIO_CONOCIDOS[self._tipo_encoding] + 3
                )
            finally:
                for campo, valor in respaldo.items():
                    setattr(self, "_" + campo, valor)
        except (ValueError, TypeError) as exc:
            self.error_configuracion.emit(str(exc))
            return {}
        self._aplicar_arquitectura(arquitectura)
        entrenamiento = {}
        for campo, tipo in _CAMPOS_ENTRENAMIENTO.items():
            valor = (datos.get("entrenamiento") or {}).get(campo)
            if isinstance(valor, (int, float)) and not isinstance(valor, bool):
                entrenamiento[campo] = tipo(valor)
        return entrenamiento

    def _establecer_estado_validacion(self, error: str = "") -> None:
        """Actualiza las propiedades persistentes usadas por los bindings QML.

        ``error_configuracion`` se sigue emitiendo en cada fallo para conservar
        el contrato existente. Las señales ``*Cambio`` solo notifican cuando
        cambia el valor de su propiedad.
        """
        error = str(error or "")
        es_valida = not error

        if error != self._error_configuracion_actual:
            self._error_configuracion_actual = error
            self.errorConfiguracionCambio.emit()
        if es_valida != self._configuracion_valida:
            self._configuracion_valida = es_valida
            self.configuracionValidaCambio.emit()

    def _actualizar_parametro(self, atributo: str, valor) -> None:
        if getattr(self, atributo) != valor:
            setattr(self, atributo, valor)
            self.configuracionActualCambio.emit()
        self._recalcular_resumen()

    @Slot(int)
    def establecer_tipo_encoding(self, tipo_encoding: int) -> None:
        if not 0 <= tipo_encoding < len(ENCODINGS):
            mensaje = f"tipo_encoding debe estar entre 0 y {len(ENCODINGS) - 1}"
            self._establecer_estado_validacion(mensaje)
            self.error_configuracion.emit(mensaje)
            return
        self._actualizar_parametro("_tipo_encoding", tipo_encoding)

    @Slot(int)
    def establecer_dimension_modelo(self, valor: int) -> None:
        self._actualizar_parametro("_dimension_modelo", valor)

    @Slot(int)
    def establecer_num_cabezas(self, valor: int) -> None:
        self._actualizar_parametro("_num_cabezas", valor)

    @Slot(int)
    def establecer_num_capas(self, valor: int) -> None:
        self._actualizar_parametro("_num_capas", valor)

    @Slot(int)
    def establecer_dimension_ff(self, valor: int) -> None:
        self._actualizar_parametro("_dimension_ff", valor)

    @Slot(int)
    def establecer_longitud_maxima_secuencia(self, valor: int) -> None:
        self._actualizar_parametro("_longitud_maxima_secuencia", valor)

    @Slot(float)
    def establecer_dropout(self, valor: float) -> None:
        self._actualizar_parametro("_dropout", valor)

    @Slot(bool)
    def establecer_compartir_pesos_salida(self, valor: bool) -> None:
        self._actualizar_parametro("_compartir_pesos_salida", valor)

    @Slot(str)
    def establecer_activacion(self, valor: str) -> None:
        """"relu" | "gelu" | "swish". Un valor inválido no se aplica de
        una — se valida al reconstruir la configuración en
        `_recalcular_resumen()` (misma lógica que ya usan los demás
        setters), y se avisa por `error_configuracion` si no es válido."""
        self._actualizar_parametro("_activacion", valor)

    @Slot(bool)
    def establecer_usar_mascara_causal(self, valor: bool) -> None:
        """Ver `Transformer.crear_mascaras` para qué implica desactivarla
        — pensado como herramienta educativa, no para uso normal."""
        self._actualizar_parametro("_usar_mascara_causal", valor)

    @Slot(bool)
    def establecer_usar_sesgo(self, valor: bool) -> None:
        """Activa o quita el sesgo (bias) de las capas lineales de la
        atención y de la feed-forward (micro-parametrización, RF02)."""
        self._actualizar_parametro("_usar_sesgo", bool(valor))

    def _recalcular_resumen(self) -> None:
        """Estima la cantidad de parámetros sin instanciar el modelo
        (ni el tokenizador real) completo, para que la Vista pueda
        mostrar un preview en vivo mientras el usuario mueve los
        sliders, sin disparar una descarga de red en cada cambio."""
        try:
            if self._tipo_encoding not in TAMANOS_VOCABULARIO_CONOCIDOS:
                raise ValueError(
                    f"tipo_encoding debe estar entre 0 y {len(ENCODINGS) - 1}"
                )
            tamano_vocabulario_base = TAMANOS_VOCABULARIO_CONOCIDOS[self._tipo_encoding]
            tamano_vocabulario = tamano_vocabulario_base + 3
            self._construir_configuracion(tamano_vocabulario)  # solo para validar
        except ValueError as e:
            mensaje = str(e)
            self._establecer_estado_validacion(mensaje)
            self.error_configuracion.emit(mensaje)
            return

        self._establecer_estado_validacion()

        parametros = self._estimar_parametros(
            v=tamano_vocabulario, d=self._dimension_modelo, n=self._num_capas,
            ff=self._dimension_ff, compartir_pesos_salida=self._compartir_pesos_salida,
            usar_sesgo=self._usar_sesgo,
        )
        self.resumen_cambio.emit({
            "parametros_totales": parametros,
            "memoria_estimada_mb": round(parametros * 4 / 1024**2, 1),
            "tamano_vocabulario": tamano_vocabulario,
        })

    @staticmethod
    def _estimar_parametros(
        v: int, d: int, n: int, ff: int, compartir_pesos_salida: bool,
        usar_sesgo: bool = True,
    ) -> int:
        """Fórmula cerrada del total de parámetros entrenables, sin
        instanciar el modelo. Verificada contra `Transformer` real para
        varias configuraciones (ver `test_setup_controller.py`)."""
        embeddings = 2 * v * d

        sesgo = 1 if usar_sesgo else 0
        atencion = 4 * (d * d + d * sesgo)
        ff_bloque = 2 * d * ff + (ff + d) * sesgo
        ln = 2 * d

        bloque_encoder = atencion + ff_bloque + 2 * ln
        bloque_decoder = 2 * atencion + ff_bloque + 3 * ln

        total_encoder = n * bloque_encoder
        total_decoder = n * bloque_decoder

        if compartir_pesos_salida:
            capa_salida = v
        else:
            capa_salida = d * v + v

        return embeddings + total_encoder + total_decoder + capa_salida

    def _construir_configuracion(self, tamano_vocabulario: int) -> ConfiguracionTransformer:
        return ConfiguracionTransformer(
            tamano_vocabulario=tamano_vocabulario,
            dimension_modelo=self._dimension_modelo,
            num_cabezas=self._num_cabezas,
            num_capas=self._num_capas,
            dimension_ff=self._dimension_ff,
            longitud_maxima_secuencia=self._longitud_maxima_secuencia,
            dropout=self._dropout,
            id_token_relleno=None,
            activacion=self._activacion,
            usar_mascara_causal=self._usar_mascara_causal,
            usar_sesgo=self._usar_sesgo,
        )

    def adoptar_modelo(
        self,
        modelo: Transformer,
        tokenizer: Tokenizer,
        *,
        emitir: bool = True,
    ) -> None:
        """Adopta un modelo ya construido, normalmente cargado de disco.

        ``MainViewModel`` y la preparacion de datasets consultan el modelo y
        el tokenizador activos a traves de este controlador.  Mantenerlos
        sincronizados evita que, despues de abrir un modelo guardado, se
        tokenice con la configuracion de una sesion anterior.

        Args:
            modelo: Transformer reconstruido con sus pesos.
            tokenizer: tokenizador descrito por el archivo del modelo.
            emitir: si es ``True`` reutiliza el flujo normal
                ``modelo_creado``; el orquestador puede usar ``False`` cuando
                necesita adjuntar ademas estado de entrenamiento restaurado.
        """
        self._cancelar_creacion_activa()
        config = modelo.config
        configuracion_previa = self._obtener_configuracion_actual()
        self.modelo = modelo
        self.tokenizer = tokenizer

        self._tipo_encoding = int(getattr(tokenizer, "tipo_encoding", self._tipo_encoding))
        self._dimension_modelo = config.dimension_modelo
        self._num_cabezas = config.num_cabezas
        self._num_capas = config.num_capas
        self._dimension_ff = config.dimension_ff
        self._longitud_maxima_secuencia = config.longitud_maxima_secuencia
        self._dropout = config.dropout
        self._compartir_pesos_salida = modelo.compartir_pesos_salida
        self._activacion = config.activacion
        self._usar_mascara_causal = config.usar_mascara_causal
        self._usar_sesgo = getattr(config, "usar_sesgo", True)

        if self._obtener_configuracion_actual() != configuracion_previa:
            self.configuracionActualCambio.emit()
        self._recalcular_resumen()
        if emitir:
            self.modelo_creado.emit(modelo, tokenizer)

    def liberar_modelo(self) -> None:
        """Suelta las referencias pesadas mientras se reemplaza una sesion."""
        self._cancelar_creacion_activa()
        self.modelo = None
        self.tokenizer = None

    def _cancelar_creacion_activa(self) -> None:
        """Invalida el resultado, pero conserva el bloqueo hasta que termine.

        PyTorch no ofrece una interrupcion segura a mitad de la construccion.
        Mantener ``ocupado`` evita que una segunda solicitud duplique en RAM
        los pesos que el primer hilo todavia esta materializando.
        """
        if not self._ocupado:
            return
        self._version_creacion += 1
        self._cancelacion_creacion_pendiente = True
        self._establecer_estado_creacion(
            fase="Cancelando; esperando que termine la etapa actual..."
        )

    def _finalizar_cancelacion_creacion(self) -> None:
        if not self._cancelacion_creacion_pendiente:
            return
        self._cancelacion_creacion_pendiente = False
        self._establecer_estado_creacion(ocupado=False, fase="")

    @Slot()
    def cancelar_creacion_modelo(self) -> None:
        """Cancela cooperativamente la publicacion de la creacion en curso.

        La construccion que ya entro a PyTorch termina en su hilo, pero su
        resultado queda obsoleto y nunca reemplaza el modelo de la sesion.
        """
        self._cancelar_creacion_activa()

    @staticmethod
    def _materializar_modelo(parametros: dict, notificar_fase=None):
        if notificar_fase is not None:
            notificar_fase("Cargando tokenizador...")
        tokenizer_nuevo = Tokenizer(parametros["tipo_encoding"])
        id_relleno = tokenizer_nuevo.vocab_size
        config = ConfiguracionTransformer(
            tamano_vocabulario=tokenizer_nuevo.vocab_size + 3,
            dimension_modelo=parametros["dimension_modelo"],
            num_cabezas=parametros["num_cabezas"],
            num_capas=parametros["num_capas"],
            dimension_ff=parametros["dimension_ff"],
            longitud_maxima_secuencia=parametros["longitud_maxima_secuencia"],
            dropout=parametros["dropout"],
            id_token_relleno=id_relleno,
            activacion=parametros["activacion"],
            usar_mascara_causal=parametros["usar_mascara_causal"],
            usar_sesgo=parametros.get("usar_sesgo", True),
        )
        if notificar_fase is not None:
            notificar_fase("Inicializando pesos del Transformer...")
        modelo_nuevo = Transformer(
            config,
            compartir_pesos_salida=parametros["compartir_pesos_salida"],
        )
        return modelo_nuevo, tokenizer_nuevo

    @Slot()
    def crear_modelo(self) -> None:
        """Instancia el `Tokenizer` y el `Transformer` definitivos, y los
        expone vía `modelo_creado`. NOTA: para poder usarse con
        `gestor_de_datos` (padding en batches), `id_token_relleno` debe
        quedar seteado — se resuelve igual que en `entrenar.py`:
        vocab_size, vocab_size+1, vocab_size+2 para relleno/inicio/fin."""
        if self._ocupado:
            self.error_configuracion.emit(
                "Ya hay una creacion de modelo en curso; espera a que termine."
            )
            return
        try:
            modelo_nuevo, tokenizer_nuevo = self._materializar_modelo(
                self._obtener_configuracion_actual()
            )
        except ValueError as e:
            mensaje = str(e)
            self._establecer_estado_validacion(mensaje)
            self.error_configuracion.emit(mensaje)
            return

        self._establecer_estado_validacion()
        self.tokenizer = tokenizer_nuevo
        self.modelo = modelo_nuevo
        self.modelo_creado.emit(self.modelo, self.tokenizer)

    @Slot()
    def crear_modelo_async(self) -> None:
        """Construye tokenizador y Transformer sin bloquear el hilo QML.

        Cada solicitud lleva una version. Una cancelacion o una solicitud mas
        reciente hace que los resultados anteriores se descarten al volver al
        hilo principal, evitando que un trabajo tardio active el modelo equivocado.
        """
        if self._ocupado:
            return
        if not self._configuracion_valida:
            mensaje = self._error_configuracion_actual or "La configuracion no es valida."
            self.error_configuracion.emit(mensaje)
            return

        parametros = dict(self._obtener_configuracion_actual())
        self._version_creacion += 1
        version = self._version_creacion
        self._cancelacion_creacion_pendiente = False
        self._establecer_estado_creacion(
            ocupado=True, fase="Preparando la creacion del modelo..."
        )

        def tarea() -> None:
            try:
                modelo, tokenizer = self._materializar_modelo(
                    parametros,
                    lambda fase: self._fase_creacion_recibida.emit(version, fase),
                )
            except Exception as exc:  # noqa: BLE001 - se comunica a la interfaz
                self._creacion_fallida.emit(version, str(exc))
                return
            self._creacion_terminada.emit(version, modelo, tokenizer)

        hilo = threading.Thread(
            target=tarea,
            name=f"crear-transformer-{version}",
            daemon=True,
        )
        try:
            hilo.start()
        except RuntimeError as exc:
            self._fallar_creacion_async(
                version, f"No se pudo iniciar el hilo de creacion: {exc}"
            )

    @Slot(int, str)
    def _actualizar_fase_async(self, version: int, fase: str) -> None:
        if version == self._version_creacion and self._ocupado:
            self._establecer_estado_creacion(fase=fase)

    @Slot(int, object, object)
    def _finalizar_creacion_async(self, version: int, modelo, tokenizer) -> None:
        if version != self._version_creacion:
            self._finalizar_cancelacion_creacion()
            return
        if not self._ocupado:
            return
        self._cancelacion_creacion_pendiente = False
        self._establecer_estado_validacion()
        self.tokenizer = tokenizer
        self.modelo = modelo
        self._establecer_estado_creacion(ocupado=False, fase="Modelo construido")
        self.modelo_creado.emit(modelo, tokenizer)

    @Slot(int, str)
    def _fallar_creacion_async(self, version: int, detalle: str) -> None:
        if version != self._version_creacion:
            self._finalizar_cancelacion_creacion()
            return
        if not self._ocupado:
            return
        self._cancelacion_creacion_pendiente = False
        mensaje = detalle or "No se pudo crear el modelo."
        self._establecer_estado_validacion(mensaje)
        self._establecer_estado_creacion(ocupado=False, fase="")
        self.error_configuracion.emit(mensaje)
