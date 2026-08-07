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

from PySide6.QtCore import QObject, Signal, Slot

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

    def __init__(self, parent: QObject | None = None):
        super().__init__(parent)
        self.modelo: Transformer | None = None
        self.tokenizer: Tokenizer | None = None

        self._tipo_encoding = 1  # cl100k_base
        self._dimension_modelo = 384
        self._num_cabezas = 6
        self._num_capas = 6
        self._dimension_ff = 4 * 384
        self._longitud_maxima_secuencia = 256
        self._dropout = 0.1
        self._compartir_pesos_salida = True
        self._activacion = "relu"
        self._usar_mascara_causal = True

    @Slot(int)
    def establecer_tipo_encoding(self, tipo_encoding: int) -> None:
        if not 0 <= tipo_encoding < len(ENCODINGS):
            self.error_configuracion.emit(
                f"tipo_encoding debe estar entre 0 y {len(ENCODINGS) - 1}"
            )
            return
        self._tipo_encoding = tipo_encoding
        self._recalcular_resumen()

    @Slot(int)
    def establecer_dimension_modelo(self, valor: int) -> None:
        self._dimension_modelo = valor
        self._recalcular_resumen()

    @Slot(int)
    def establecer_num_cabezas(self, valor: int) -> None:
        self._num_cabezas = valor
        self._recalcular_resumen()

    @Slot(int)
    def establecer_num_capas(self, valor: int) -> None:
        self._num_capas = valor
        self._recalcular_resumen()

    @Slot(int)
    def establecer_dimension_ff(self, valor: int) -> None:
        self._dimension_ff = valor
        self._recalcular_resumen()

    @Slot(int)
    def establecer_longitud_maxima_secuencia(self, valor: int) -> None:
        self._longitud_maxima_secuencia = valor
        self._recalcular_resumen()

    @Slot(float)
    def establecer_dropout(self, valor: float) -> None:
        self._dropout = valor

    @Slot(bool)
    def establecer_compartir_pesos_salida(self, valor: bool) -> None:
        self._compartir_pesos_salida = valor
        self._recalcular_resumen()

    @Slot(str)
    def establecer_activacion(self, valor: str) -> None:
        """"relu" | "gelu" | "swish". Un valor inválido no se aplica de
        una — se valida al reconstruir la configuración en
        `_recalcular_resumen()` (misma lógica que ya usan los demás
        setters), y se avisa por `error_configuracion` si no es válido."""
        self._activacion = valor
        self._recalcular_resumen()

    @Slot(bool)
    def establecer_usar_mascara_causal(self, valor: bool) -> None:
        """Ver `Transformer.crear_mascaras` para qué implica desactivarla
        — pensado como herramienta educativa, no para uso normal."""
        self._usar_mascara_causal = valor

    def _recalcular_resumen(self) -> None:
        """Estima la cantidad de parámetros sin instanciar el modelo
        (ni el tokenizador real) completo, para que la Vista pueda
        mostrar un preview en vivo mientras el usuario mueve los
        sliders, sin disparar una descarga de red en cada cambio."""
        try:
            tamano_vocabulario = TAMANOS_VOCABULARIO_CONOCIDOS[self._tipo_encoding]
            self._construir_configuracion(tamano_vocabulario)  # solo para validar
        except ValueError as e:
            self.error_configuracion.emit(str(e))
            return

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

    @Slot()
    def crear_modelo(self) -> None:
        """Instancia el `Tokenizer` y el `Transformer` definitivos, y los
        expone vía `modelo_creado`. NOTA: para poder usarse con
        `gestor_de_datos` (padding en batches), `id_token_relleno` debe
        quedar seteado — se resuelve igual que en `entrenar.py`:
        vocab_size, vocab_size+1, vocab_size+2 para relleno/inicio/fin."""
        try:
            tokenizer_nuevo = Tokenizer(self._tipo_encoding)
            id_relleno = tokenizer_nuevo.vocab_size
            config = ConfiguracionTransformer(
                tamano_vocabulario=tokenizer_nuevo.vocab_size + 3,
                dimension_modelo=self._dimension_modelo,
                num_cabezas=self._num_cabezas,
                num_capas=self._num_capas,
                dimension_ff=self._dimension_ff,
                longitud_maxima_secuencia=self._longitud_maxima_secuencia,
                dropout=self._dropout,
                id_token_relleno=id_relleno,
                activacion=self._activacion,
                usar_mascara_causal=self._usar_mascara_causal,
            )
            modelo_nuevo = Transformer(config, compartir_pesos_salida=self._compartir_pesos_salida)
        except ValueError as e:
            self.error_configuracion.emit(str(e))
            return

        self.tokenizer = tokenizer_nuevo
        self.modelo = modelo_nuevo
        self.modelo_creado.emit(self.modelo, self.tokenizer)