"""
Gestor de Señales.

Traduce las señales puntuales de los controladores (ej.
`InferenceController`) en PROPIEDADES OBSERVABLES (`@Property`) que QML
puede consumir directo con data binding, sin que cada pantalla tenga que
conectar señales a mano.

Un controlador emite eventos aislados ("token_generado",
"generacion_completa"...). QML no trabaja con eventos sueltos — trabaja
con propiedades que se leen en cualquier momento y notifican cuando
cambian (property binding). Este gestor es el puente: escucha las
señales de bajo nivel y mantiene el ESTADO ACTUAL derivado de ellas,
expuesto como propiedades.

No contiene ninguna lógica de negocio (no sabe qué es un token ni cómo
generar texto, ni de threads) — solo agrega y traduce. Toda la lógica
real vive en `InferenceController` (y este gestor solo lo observa).

Nota sobre `@Slot`: los métodos públicos de un `QObject` definido en
Python quedan automáticamente invocables desde QML en PySide6, sin
necesidad del decorador `@Slot` (a diferencia de PyQt, que sí lo exige).
Se omite aquí a propósito para poder usar argumentos por defecto de
Python normales (`max_tokens_nuevos=100`, etc.) sin pelear con firmas
de tipos fijas de Qt.
"""

from PySide6.QtCore import Property, QObject, Signal


class GestorSenales(QObject):
    """Expone el estado de la generación como propiedades observables
    para QML, a partir de las señales de un `InferenceController`.

    Uso típico desde `main.py`:

        gestor_senales = GestorSenales(inference_controller)
        engine.rootContext().setContextProperty("gestorSenales", gestor_senales)

    Y en QML:

        Text { text: gestorSenales.textoGenerado }
        BusyIndicator { running: gestorSenales.estaGenerando }
        Button { text: "Detener"; onClicked: gestorSenales.detener() }
        Slider {
            onValueChanged: gestorSenales.establecerVelocidad(value)
        }
    """

    textoGeneradoCambio = Signal()
    estaGenerandoCambio = Signal()
    estaPausadoCambio = Signal()
    mensajeErrorCambio = Signal()

    # Señal "cruda" de cada paso, para quien necesite los tensores
    # completos (ej. el Adaptador Visual del Lienzo Científico), no solo
    # el texto. No se modela como propiedad: cambia en cada token y
    # contiene tensores de PyTorch, que no tiene sentido exponer vía
    # binding directo de QML.
    pasoRecibido = Signal(dict)

    def __init__(self, inference_controller, parent: QObject | None = None):
        super().__init__(parent)
        self._controlador = inference_controller

        self._texto_generado = ""
        self._esta_generando = False
        self._esta_pausado = False
        self._mensaje_error = ""

        self._controlador.token_generado.connect(self._al_recibir_token)
        self._controlador.generacion_completa.connect(self._al_completar)
        self._controlador.generacion_cancelada.connect(self._al_cancelar)
        self._controlador.error.connect(self._al_fallar)

    # ------------------------------------------------------------------
    # Propiedades observables
    # ------------------------------------------------------------------

    @Property(str, notify=textoGeneradoCambio)
    def textoGenerado(self) -> str:
        return self._texto_generado

    @Property(bool, notify=estaGenerandoCambio)
    def estaGenerando(self) -> bool:
        return self._esta_generando

    @Property(bool, notify=estaPausadoCambio)
    def estaPausado(self) -> bool:
        return self._esta_pausado

    @Property(str, notify=mensajeErrorCambio)
    def mensajeError(self) -> str:
        return self._mensaje_error

    # ------------------------------------------------------------------
    # Acciones invocables desde QML (delegan al InferenceController)
    # ------------------------------------------------------------------

    def iniciarGeneracion(
        self, prompt: str, max_tokens_nuevos: int = 100, temperatura: float = 1.0,
        top_k: int | None = None, top_p: float | None = None, velocidad_inicial: float = 0.0,
    ) -> None:
        self._establecer_mensaje_error("")
        self._controlador.iniciar_generacion(
            prompt, max_tokens_nuevos=max_tokens_nuevos, temperatura=temperatura,
            top_k=top_k, top_p=top_p, velocidad_inicial=velocidad_inicial,
        )

    def detener(self) -> None:
        self._controlador.detener()

    def pausar(self) -> None:
        self._controlador.pausar()
        self._sincronizar_estado_pausa()

    def reanudar(self) -> None:
        self._controlador.reanudar()
        self._sincronizar_estado_pausa()

    def establecerVelocidad(self, segundos_por_token: float) -> None:
        self._controlador.establecer_velocidad(segundos_por_token)

    # ------------------------------------------------------------------
    # Manejadores internos
    # ------------------------------------------------------------------

    def _al_recibir_token(self, paso: dict) -> None:
        self._establecer_texto_generado(paso["texto_parcial"])
        self._establecer_generando(True)
        self.pasoRecibido.emit(paso)

    def _al_completar(self, texto_final: str) -> None:
        self._establecer_texto_generado(texto_final)
        self._establecer_generando(False)

    def _al_cancelar(self, texto_parcial: str) -> None:
        self._establecer_texto_generado(texto_parcial)
        self._establecer_generando(False)

    def _al_fallar(self, mensaje: str) -> None:
        self._establecer_mensaje_error(mensaje)
        self._establecer_generando(False)

    def _establecer_texto_generado(self, valor: str) -> None:
        if self._texto_generado != valor:
            self._texto_generado = valor
            self.textoGeneradoCambio.emit()

    def _establecer_generando(self, valor: bool) -> None:
        if self._esta_generando != valor:
            self._esta_generando = valor
            self.estaGenerandoCambio.emit()
        self._sincronizar_estado_pausa()

    def _establecer_mensaje_error(self, valor: str) -> None:
        if self._mensaje_error != valor:
            self._mensaje_error = valor
            self.mensajeErrorCambio.emit()

    def _sincronizar_estado_pausa(self) -> None:
        nuevo_valor = self._controlador.esta_pausado
        if self._esta_pausado != nuevo_valor:
            self._esta_pausado = nuevo_valor
            self.estaPausadoCambio.emit()