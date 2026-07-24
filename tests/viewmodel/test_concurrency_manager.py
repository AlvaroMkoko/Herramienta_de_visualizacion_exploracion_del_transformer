"""
Pruebas de `viewmodel/concurrency_manager.py` usando pytest-qt.

pytest-qt provee el fixture `qtbot`, que maneja el event loop de Qt por
nosotros (ya no hace falta armar `QCoreApplication` + `QTimer` a mano
como en las pruebas exploratorias). En particular, `qtbot.waitSignal(...)`
bloquea la prueba hasta que una señal se emite (o hace fallar la prueba
si se cumple un timeout antes) — es la forma idiomática de probar código
asíncrono basado en señales de Qt.

Cubren:
- Que una tarea simple complete y emita `finalizado` con el resultado
  correcto.
- Que `progreso` se emita una vez por cada `yield` del generador.
- Que `detener()` cancele la tarea de forma cooperativa (sin completar
  todos los pasos).
- Que `pausar()` / `reanudar()` bloqueen y reanuden la ejecución.
- Que `detener()` funcione incluso si la tarea está pausada (no debe
  quedarse esperando un `reanudar()` que nunca llega).
- Que `establecer_velocidad()` / `velocidad_inicial` introduzcan el
  retardo esperado entre pasos.
- Que no se pueda lanzar una segunda tarea mientras hay una en curso.
- Que una excepción dentro de la tarea se propague vía la señal `error`,
  sin crashear el proceso.
- Que `esta_en_ejecucion` refleje el estado real en cada momento.
"""

import time

import pytest

from viewmodel.concurrency_manager import GestorConcurrencia


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def gestor(qtbot):
    g = GestorConcurrencia()
    yield g
    # Limpieza: si alguna prueba deja una tarea corriendo (ej. por un
    # assert que falla a mitad de camino), la detenemos para no dejar
    # hilos huerfanos entre pruebas.
    if g.esta_en_ejecucion:
        g.detener()
        qtbot.waitUntil(lambda: not g.esta_en_ejecucion, timeout=2000)


# ---------------------------------------------------------------------------
# Tareas de prueba reutilizables
# ---------------------------------------------------------------------------

def _tarea_simple(trabajador, n_pasos: int, retardo: float = 0.0):
    for i in range(n_pasos):
        if trabajador.debe_detenerse:
            return "detenido"
        if retardo:
            time.sleep(retardo)
        yield i
    return "completado"


def _tarea_con_error(trabajador):
    yield "paso_1"
    raise RuntimeError("fallo simulado dentro de la tarea")


# ---------------------------------------------------------------------------
# Ejecución básica
# ---------------------------------------------------------------------------

class TestEjecucionBasica:
    def test_tarea_completa_emite_finalizado_con_resultado_correcto(self, qtbot, gestor):
        with qtbot.waitSignal(gestor.finalizado, timeout=2000) as blocker:
            gestor.ejecutar_en_segundo_plano(_tarea_simple, 5)

        assert blocker.args == ["completado"]

    def test_progreso_se_emite_una_vez_por_paso(self, qtbot, gestor):
        valores_recibidos = []
        gestor.progreso.connect(valores_recibidos.append)

        with qtbot.waitSignal(gestor.finalizado, timeout=2000):
            gestor.ejecutar_en_segundo_plano(_tarea_simple, 5)

        assert valores_recibidos == [0, 1, 2, 3, 4]

    def test_esta_en_ejecucion_refleja_el_estado(self, qtbot, gestor):
        assert gestor.esta_en_ejecucion is False

        with qtbot.waitSignal(gestor.iniciado, timeout=1000):
            gestor.ejecutar_en_segundo_plano(_tarea_simple, 3, retardo=0.05)

        assert gestor.esta_en_ejecucion is True

        qtbot.waitUntil(lambda: not gestor.esta_en_ejecucion, timeout=2000)
        assert gestor.esta_en_ejecucion is False

    def test_no_permite_doble_ejecucion_concurrente(self, qtbot, gestor):
        contador_segunda_tarea = {"llamadas": 0}

        def tarea_que_no_deberia_correr(trabajador):
            contador_segunda_tarea["llamadas"] += 1
            yield "no_deberia_pasar"

        with qtbot.waitSignal(gestor.finalizado, timeout=2000):
            gestor.ejecutar_en_segundo_plano(_tarea_simple, 5, retardo=0.02)
            # Se intenta lanzar una segunda tarea MIENTRAS la primera corre
            gestor.ejecutar_en_segundo_plano(tarea_que_no_deberia_correr)

        assert contador_segunda_tarea["llamadas"] == 0


# ---------------------------------------------------------------------------
# Detener (cancelación cooperativa)
# ---------------------------------------------------------------------------

class TestDetener:
    def test_detener_cancela_antes_de_completar_todos_los_pasos(self, qtbot, gestor):
        with qtbot.waitSignal(gestor.cancelado, timeout=3000):
            gestor.ejecutar_en_segundo_plano(_tarea_simple, 50, retardo=0.05)
            qtbot.wait(150)  # dejar correr un par de pasos
            gestor.detener()

        assert gestor.esta_en_ejecucion is False

    def test_detener_sin_tarea_en_curso_no_falla(self, qtbot, gestor):
        gestor.detener()
        assert gestor.esta_en_ejecucion is False


# ---------------------------------------------------------------------------
# Pausar / Reanudar
# ---------------------------------------------------------------------------

class TestPausarReanudar:
    def test_pausar_emite_señal_pausado_y_bloquea_el_avance(self, qtbot, gestor):
        valores_recibidos = []
        gestor.progreso.connect(valores_recibidos.append)

        with qtbot.waitSignal(gestor.pausado, timeout=2000):
            gestor.ejecutar_en_segundo_plano(_tarea_simple, 10, retardo=0.1)
            qtbot.wait(150)  # dejar correr 1 paso
            gestor.pausar()

        cantidad_al_pausar = len(valores_recibidos)
        qtbot.wait(300)
        assert len(valores_recibidos) == cantidad_al_pausar
        assert gestor.esta_pausado is True

        gestor.detener()  # limpieza

    def test_reanudar_permite_continuar_tras_pausar(self, qtbot, gestor):
        with qtbot.waitSignal(gestor.pausado, timeout=2000):
            gestor.ejecutar_en_segundo_plano(_tarea_simple, 5, retardo=0.05)
            qtbot.wait(80)
            gestor.pausar()

        assert gestor.esta_pausado is True

        with qtbot.waitSignal(gestor.finalizado, timeout=3000) as blocker:
            gestor.reanudar()

        assert gestor.esta_pausado is False
        assert blocker.args == ["completado"]

    def test_detener_funciona_estando_pausado(self, qtbot, gestor):
        """No debe quedarse esperando un reanudar() que nunca llega."""
        with qtbot.waitSignal(gestor.pausado, timeout=2000):
            gestor.ejecutar_en_segundo_plano(_tarea_simple, 20, retardo=0.05)
            qtbot.wait(80)
            gestor.pausar()

        with qtbot.waitSignal(gestor.cancelado, timeout=2000):
            gestor.detener()  # sin llamar reanudar() antes

        assert gestor.esta_en_ejecucion is False


# ---------------------------------------------------------------------------
# Control de velocidad
# ---------------------------------------------------------------------------

class TestVelocidad:
    def test_velocidad_inicial_introduce_retardo_entre_pasos(self, qtbot, gestor):
        """Se fija con `velocidad_inicial` en vez de llamar a
        `establecer_velocidad()` justo despues de iniciar, para evitar la
        condicion de carrera entre el arranque del hilo y esa llamada."""
        marcas_de_tiempo = []
        gestor.progreso.connect(lambda v: marcas_de_tiempo.append(time.monotonic()))

        with qtbot.waitSignal(gestor.finalizado, timeout=3000):
            gestor.ejecutar_en_segundo_plano(_tarea_simple, 4, velocidad_inicial=0.15)

        deltas = [marcas_de_tiempo[i + 1] - marcas_de_tiempo[i] for i in range(len(marcas_de_tiempo) - 1)]
        assert all(delta >= 0.12 for delta in deltas)  # margen de tolerancia

    def test_establecer_velocidad_ajusta_una_tarea_ya_en_curso(self, qtbot, gestor):
        """establecer_velocidad() sigue sirviendo para cambiar el ritmo
        DURANTE una tarea ya en marcha (ej. el usuario mueve el slider a
        mitad de la generacion) — aqui SI puede haber 1-2 pasos con el
        retardo anterior antes de que el nuevo tome efecto, y eso es
        aceptable para ese caso de uso."""
        marcas_de_tiempo = []
        gestor.progreso.connect(lambda v: marcas_de_tiempo.append(time.monotonic()))

        with qtbot.waitSignal(gestor.iniciado, timeout=1000):
            gestor.ejecutar_en_segundo_plano(_tarea_simple, 6, velocidad_inicial=0.05)

        with qtbot.waitSignal(gestor.finalizado, timeout=3000):
            gestor.establecer_velocidad(0.15)

        deltas = [marcas_de_tiempo[i + 1] - marcas_de_tiempo[i] for i in range(len(marcas_de_tiempo) - 1)]
        assert deltas[-1] >= 0.12

    def test_velocidad_por_defecto_es_maxima_sin_retardo_artificial(self, qtbot, gestor):
        inicio = time.monotonic()
        with qtbot.waitSignal(gestor.finalizado, timeout=2000):
            gestor.ejecutar_en_segundo_plano(_tarea_simple, 20)
        duracion = time.monotonic() - inicio

        assert duracion < 0.5  # deberia ser practicamente instantaneo

    def test_velocidad_negativa_lanza_error(self, qtbot, gestor):
        with qtbot.waitSignal(gestor.iniciado, timeout=1000):
            gestor.ejecutar_en_segundo_plano(_tarea_simple, 3, retardo=0.05)

        with pytest.raises(ValueError):
            gestor.establecer_velocidad(-1.0)

        gestor.detener()  # limpieza


# ---------------------------------------------------------------------------
# Manejo de errores
# ---------------------------------------------------------------------------

class TestManejoDeErrores:
    def test_excepcion_en_la_tarea_se_propaga_via_señal_error(self, qtbot, gestor):
        with qtbot.waitSignal(gestor.error, timeout=2000) as blocker:
            gestor.ejecutar_en_segundo_plano(_tarea_con_error)

        assert "fallo simulado" in blocker.args[0]
        assert gestor.esta_en_ejecucion is False

    def test_tras_un_error_se_puede_lanzar_una_nueva_tarea(self, qtbot, gestor):
        with qtbot.waitSignal(gestor.error, timeout=2000):
            gestor.ejecutar_en_segundo_plano(_tarea_con_error)

        with qtbot.waitSignal(gestor.finalizado, timeout=2000) as blocker:
            gestor.ejecutar_en_segundo_plano(_tarea_simple, 3)

        assert blocker.args == ["completado"]