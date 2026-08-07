"""
Gestor de Concurrencia.

Ejecuta tareas pesadas (generación de texto, entrenamiento) en un hilo
secundario usando QThread, para no bloquear la interfaz gráfica (la UI
de Qt corre en un solo hilo, y el GIL de Python impediría que responda
si la inferencia se ejecutara directamente ahí).

Provee tres controles cooperativos sobre la tarea en curso, todos
basados en que la tarea es un GENERADOR de Python que hace `yield`
después de cada paso (ej. después de generar cada token):

1. DETENER: no es seguro "matar" un hilo de Python a la mitad de una
   operación — se marca una bandera (`debe_detenerse`) y la tarea sale
   voluntariamente en su próxima iteración.
2. PAUSAR / REANUDAR: el hilo se bloquea en un `threading.Event.wait()`
   entre un paso y el siguiente (sin busy-waiting, sin gastar CPU),
   hasta que se llame a `reanudar()`.
3. VELOCIDAD: un retardo (en segundos) que se aplica DESPUÉS de cada
   paso, para poder ver la evolución token a token / tensor a tensor a
   un ritmo controlado en el Lienzo Científico, en vez de a la velocidad
   máxima de inferencia.

El PAYLOAD de cada `yield` (lo que llega a la señal `progreso`) puede
ser cualquier objeto — típicamente un diccionario armado por
`inference_controller.py` / `visual_adapter.py` con el token generado
Y los tensores intermedios de ese paso (ej. pesos de atención, logits),
para que la Vista los pueda graficar en tiempo real.
"""

import threading
import time
from collections.abc import Callable, Generator
from typing import Any

from PySide6.QtCore import QObject, QThread, Signal


class TrabajadorSegundoPlano(QObject):
    """Worker que se mueve a un QThread y ejecuta una tarea cancelable,
    pausable y con velocidad ajustable.

    No se instancia directamente desde la Vista/ViewModel de más alto
    nivel — lo crea y administra `GestorConcurrencia`.
    """

    progreso = Signal(object)    # se emite en cada yield del generador (ej. token + tensores de ese paso)
    finalizado = Signal(object)  # se emite con el resultado final (return del generador)
    error = Signal(str)
    cancelado = Signal()
    pausado = Signal()
    reanudado = Signal()

    def __init__(self, funcion_generadora: Callable[..., Generator], *args, **kwargs):
        super().__init__()
        self._funcion_generadora = funcion_generadora
        self._args = args
        self._kwargs = kwargs

        self._evento_detener = threading.Event()

        # Al reves que "detener": aqui SET significa "puede avanzar" y
        # CLEAR significa "en pausa". Empieza en SET (corriendo normal).
        # Usar Event.wait() en vez de un bucle de sondeo evita gastar CPU
        # mientras esta en pausa.
        self._evento_continuar = threading.Event()
        self._evento_continuar.set()

        self._retardo_segundos = 0.0  # 0 = sin retardo, velocidad maxima

    # --- Controles (se llaman desde el hilo principal / UI) ---

    def solicitar_detener(self) -> None:
        """Marca la bandera de cancelación y libera la pausa si estaba
        pausado (para que la tarea pueda salir en vez de quedar
        bloqueada esperando un `reanudar()` que nunca llega)."""
        self._evento_detener.set()
        self._evento_continuar.set()

    def pausar(self) -> None:
        self._evento_continuar.clear()

    def reanudar(self) -> None:
        self._evento_continuar.set()

    def establecer_velocidad(self, segundos_por_paso: float) -> None:
        """Ajusta el retardo aplicado después de cada paso.

        Args:
            segundos_por_paso: 0.0 para velocidad máxima (sin retardo
                artificial); un valor mayor ralentiza la generación para
                poder observarla paso a paso en el Lienzo Científico.
        """
        if segundos_por_paso < 0:
            raise ValueError("segundos_por_paso no puede ser negativo")
        self._retardo_segundos = segundos_por_paso

    @property
    def debe_detenerse(self) -> bool:
        return self._evento_detener.is_set()

    @property
    def esta_pausado(self) -> bool:
        return not self._evento_continuar.is_set()

    # --- Ejecución (corre DENTRO del hilo secundario) ---

    def ejecutar(self) -> None:
        """Punto de entrada que corre dentro del hilo secundario (se
        conecta a `QThread.started`)."""
        try:
            generador = self._funcion_generadora(self, *self._args, **self._kwargs)
            resultado = None
            try:
                while True:
                    if self.debe_detenerse:
                        self.cancelado.emit()
                        return

                    # Bloquea aqui (sin gastar CPU) si esta en pausa. Si
                    # `solicitar_detener()` se llama mientras esta pausado,
                    # tambien libera este wait (ver solicitar_detener).
                    if not self._evento_continuar.is_set():
                        self.pausado.emit()
                        self._evento_continuar.wait()
                        if self.debe_detenerse:
                            self.cancelado.emit()
                            return
                        self.reanudado.emit()

                    valor = next(generador)
                    self.progreso.emit(valor)

                    if self._retardo_segundos > 0:
                        time.sleep(self._retardo_segundos)

            except StopIteration as fin:
                resultado = fin.value

            self.finalizado.emit(resultado)
        except Exception as e:  # noqa: BLE001 - se reporta a la UI en vez de tragarse silenciosamente
            self.error.emit(str(e))


class GestorConcurrencia(QObject):
    """Orquesta tareas en segundo plano: iniciar, detener, pausar/reanudar
    y controlar la velocidad — pensado para la generación autoregresiva
    token a token, visualizada en tiempo real en el Lienzo Científico.

    Uso típico desde `inference_controller.py`:

        def _tarea_generacion(trabajador, modelo, prompt, parametros):
            for token_id, tensores_del_paso in modelo.generar_con_tensores(prompt, **parametros):
                if trabajador.debe_detenerse:
                    return "detenido_por_usuario"
                # El payload incluye los tensores intermedios de ESTE paso,
                # para que la Vista los pueda graficar en tiempo real.
                yield {"token_id": token_id, "tensores": tensores_del_paso}
            return "completado"

        gestor = GestorConcurrencia()
        gestor.progreso.connect(self._on_nuevo_paso)       # actualiza texto + Lienzo Cientifico
        gestor.finalizado.connect(self._on_generacion_completa)
        gestor.ejecutar_en_segundo_plano(_tarea_generacion, modelo, prompt, parametros)

        # Desde los controles de la UI:
        gestor.detener()
        gestor.pausar()
        gestor.reanudar()
        gestor.establecer_velocidad(0.3)  # 300ms entre tokens, para observar con calma
    """

    iniciado = Signal()
    progreso = Signal(object)
    finalizado = Signal(object)
    error = Signal(str)
    cancelado = Signal()
    pausado = Signal()
    reanudado = Signal()

    def __init__(self, parent: QObject | None = None):
        super().__init__(parent)
        self._hilo: QThread | None = None
        self._trabajador: TrabajadorSegundoPlano | None = None

    @property
    def esta_en_ejecucion(self) -> bool:
        return self._hilo is not None and self._hilo.isRunning()

    @property
    def esta_pausado(self) -> bool:
        return self._trabajador is not None and self._trabajador.esta_pausado

    def ejecutar_en_segundo_plano(
        self,
        funcion_generadora: Callable[..., Generator],
        *args,
        velocidad_inicial: float = 0.0,
        **kwargs,
    ) -> None:
        """Lanza `funcion_generadora` en un QThread nuevo.

        Args:
            funcion_generadora: función que recibe como PRIMER argumento
                al `TrabajadorSegundoPlano` y es un generador: usa
                `yield` para reportar cada paso (token + tensores) y
                `return valor` para el resultado final.
            velocidad_inicial: retardo (segundos) entre pasos, fijado
                ANTES de arrancar el hilo. Usar esto en vez de llamar a
                `establecer_velocidad()` justo después de iniciar evita
                una condición de carrera: el hilo podría arrancar y
                procesar el primer paso antes de que una llamada
                posterior a `establecer_velocidad()` alcance a aplicarse.
                Para ajustar la velocidad DURANTE una tarea ya en curso,
                sí se usa `establecer_velocidad()` normalmente.
            *args, **kwargs: argumentos adicionales para `funcion_generadora`.

        Si ya hay una tarea en curso, la solicitud se ignora — evita
        lanzar dos generaciones simultáneas por un doble clic accidental.
        """
        if self.esta_en_ejecucion:
            return

        self._hilo = QThread()
        self._trabajador = TrabajadorSegundoPlano(funcion_generadora, *args, **kwargs)
        self._trabajador.establecer_velocidad(velocidad_inicial)
        self._trabajador.moveToThread(self._hilo)

        self._hilo.started.connect(self._trabajador.ejecutar)

        self._trabajador.progreso.connect(self.progreso.emit)
        self._trabajador.finalizado.connect(self._al_finalizar)
        self._trabajador.error.connect(self._al_fallar)
        self._trabajador.cancelado.connect(self._al_cancelar)
        self._trabajador.pausado.connect(self.pausado.emit)
        self._trabajador.reanudado.connect(self.reanudado.emit)

        self._hilo.start()
        self.iniciado.emit()

    def detener(self) -> None:
        """Solicita la cancelación cooperativa de la tarea en curso
        (funciona incluso si está pausada — la libera para que pueda
        salir en vez de quedar bloqueada esperando `reanudar()`)."""
        if self._trabajador is not None:
            self._trabajador.solicitar_detener()

    def pausar(self) -> None:
        """Pausa la tarea en curso ANTES de su próximo paso. No consume
        CPU mientras está pausada (usa `threading.Event.wait()`)."""
        if self._trabajador is not None:
            self._trabajador.pausar()

    def reanudar(self) -> None:
        """Reanuda una tarea previamente pausada."""
        if self._trabajador is not None:
            self._trabajador.reanudar()

    def establecer_velocidad(self, segundos_por_paso: float) -> None:
        """Ajusta el retardo entre pasos de la tarea en curso (o de la
        próxima, si se llama antes de iniciar). 0.0 = velocidad máxima.
        """
        if self._trabajador is not None:
            self._trabajador.establecer_velocidad(segundos_por_paso)

    def cerrar(self) -> None:
        """Cancela y espera el worker para poder liberar su modelo con seguridad.

        Cambiar de sesion mientras un QThread aun conserva argumentos de la
        tarea mantendria vivos los pesos anteriores. ``quit`` es seguro desde
        el hilo principal y deja que la operacion PyTorch en curso termine su
        paso antes de aplicar la cancelacion cooperativa.
        """
        trabajador = self._trabajador
        hilo = self._hilo
        if trabajador is not None:
            trabajador.solicitar_detener()
        if hilo is not None:
            hilo.quit()
            if hilo.isRunning():
                hilo.wait()
        self._hilo = None
        self._trabajador = None

    def _limpiar_hilo(self) -> None:
        if self._hilo is not None:
            self._hilo.quit()
            self._hilo.wait()
        self._hilo = None
        self._trabajador = None

    def _al_finalizar(self, resultado: Any) -> None:
        self._limpiar_hilo()
        self.finalizado.emit(resultado)

    def _al_fallar(self, mensaje: str) -> None:
        self._limpiar_hilo()
        self.error.emit(mensaje)

    def _al_cancelar(self) -> None:
        self._limpiar_hilo()
        self.cancelado.emit()
