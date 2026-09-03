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

import threading

from PySide6.QtCore import Property, QObject, Signal, Slot

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

    # Estas senales privadas son el puente seguro entre el hilo Python que
    # materializa los pesos y el hilo de Qt, donde se actualiza el estado QML.
    _fase_creacion_recibida = Signal(int, str)
    _creacion_terminada = Signal(int, object, object)
    _creacion_fallida = Signal(int, str)

    def __init__(self, parent: QObject | None = None):
        super().__init__(parent)
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
        }

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
        )
        self.resumen_cambio.emit({
            "parametros_totales": parametros,
            "memoria_estimada_mb": round(parametros * 4 / 1024**2, 1),
            "tamano_vocabulario": tamano_vocabulario,
        })

    @staticmethod
    def _estimar_parametros(v: int, d: int, n: int, ff: int, compartir_pesos_salida: bool) -> int:
        """Fórmula cerrada del total de parámetros entrenables, sin
        instanciar el modelo. Verificada contra `Transformer` real para
        varias configuraciones (ver `test_setup_controller.py`)."""
        embeddings = 2 * v * d

        atencion = 4 * (d * d + d)
        ff_bloque = 2 * d * ff + ff + d
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
