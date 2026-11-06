"""Mide tasa de cuadros, bloqueo de la interfaz y memoria en la app real.

Arranca la aplicación con el mismo conductor de los casos de uso (ventana
visible, OpenGL, datos en un sandbox) y registra el instante de cada cuadro
presentado (``QQuickWindow.frameSwapped``). Qt Quick solo dibuja cuando algo
cambia, así que cada escenario mantiene una animación en curso:

* ``laboratorio_animacion``: animaciones de fórmula del laboratorio (módulo 3).
* ``inferencia``: generación de texto con el modelo distribuido.
* ``calculo_en_hilo`` / ``calculo_en_interfaz``: la misma animación mientras
  se analiza el texto en modo entrenamiento (con gradientes), una vez en el
  hilo del laboratorio y otra en el hilo de la interfaz, como antes.

Con ``--minutos N`` repite los escenarios durante N minutos y muestrea la
memoria del proceso y de la GPU (RNF06).

Uso, desde la raíz del repositorio y con la ventana a la vista (minimizada
no dibuja y la medición sale en cero):

    python -m pruebas.auditoria.medir_rendimiento --modelo RUTA.tvismodel --json salida.json
"""

from __future__ import annotations

import argparse
import json
import platform
import shutil
import statistics
import sys
import time
from pathlib import Path

import pruebas.ejecutar_casos_de_uso as cu  # aísla data/ al importarse

import psutil
import torch
from PySide6.QtCore import QEventLoop, QTimer

TEXTO = "La atención conecta cada token con su contexto y decide qué información conservar."
NOMBRE_MODELO = cu.MODELOS_A_COPIAR[0]
MODULO_LAB = "module_3"


class Cuadros:
    """Instantes de presentación de cuadros de la ventana principal."""

    def __init__(self, ventana) -> None:
        self.instantes: list[float] = []
        self.activo = False
        ventana.frameSwapped.connect(self._al_cuadro)

    def _al_cuadro(self) -> None:
        if self.activo:
            self.instantes.append(time.perf_counter())

    def medir(self, accion, segundos: float) -> dict:
        self.instantes = []
        self.activo = True
        inicio = time.perf_counter()
        accion()
        esperar(segundos)
        self.activo = False
        return resumir(self.instantes, time.perf_counter() - inicio)


def esperar(segundos: float) -> None:
    # Bucle de eventos nativo: un sleep entre processEvents frenaría la
    # animación y mediría al medidor, no a la app.
    bucle = QEventLoop()
    QTimer.singleShot(int(segundos * 1000), bucle.quit)
    bucle.exec()


def resumir(instantes: list[float], duracion: float) -> dict:
    intervalos = [b - a for a, b in zip(instantes, instantes[1:])]
    if not intervalos:
        return {"cuadros": len(instantes), "fps": 0.0, "duracion_s": round(duracion, 2)}
    ms = sorted(i * 1000 for i in intervalos)

    def percentil(p: float) -> float:
        return round(ms[min(len(ms) - 1, int(p * len(ms)))], 2)

    return {
        "cuadros": len(instantes),
        "duracion_s": round(duracion, 2),
        "fps": round(len(intervalos) / (instantes[-1] - instantes[0]), 1),
        "intervalo_p50_ms": percentil(0.50),
        "intervalo_p95_ms": percentil(0.95),
        "intervalo_p99_ms": percentil(0.99),
        "intervalo_max_ms": round(ms[-1], 1),
        "cuadros_lentos_pct": round(100 * sum(1 for v in ms if v > 1000 / 30) / len(ms), 2),
    }


def memoria() -> dict:
    datos = {"rss_mb": round(psutil.Process().memory_info().rss / 2**20, 1)}
    if torch.cuda.is_available():
        datos["gpu_asignada_mb"] = round(torch.cuda.memory_allocated() / 2**20, 1)
        datos["gpu_reservada_mb"] = round(torch.cuda.memory_reserved() / 2**20, 1)
    return datos


def entorno(c: cu.Conductor) -> dict:
    pantalla = c.app.primaryScreen()
    datos = {
        "sistema": platform.platform(),
        "procesador": platform.processor(),
        "ram_gb": round(psutil.virtual_memory().total / 2**30, 1),
        "python": platform.python_version(),
        "torch": torch.__version__,
        "pantalla_hz": round(pantalla.refreshRate(), 1),
        "pantalla_px": f"{pantalla.size().width()}x{pantalla.size().height()}",
        "ventana_px": f"{c.ventana.width()}x{c.ventana.height()}",
        "dispositivo_modelo": str(getattr(c.vm, "dispositivoCalculo", "")),
    }
    if torch.cuda.is_available():
        propiedades = torch.cuda.get_device_properties(0)
        datos["gpu"] = propiedades.name
        datos["gpu_memoria_gb"] = round(propiedades.total_memory / 2**30, 1)
    return datos


def preparar(c: cu.Conductor, modelo: Path):
    if not c.vm.modeloListo:
        cu._abrir_inferencia_con(c, "Esp-Ing")
        c.volver_a_raiz()
    # Se abre la pantalla directamente: el sandbox empieza sin pre-test y las
    # guardias del curso no dejarían llegar al laboratorio. Aquí se mide
    # rendimiento, no la progresión (esa la cubren los casos de uso).
    c.vm.courseController.selectModule(MODULO_LAB)
    lab = c.ir_a("ModuleLaboratoryScreen.qml", {"moduleId": MODULO_LAB})
    if lab.objectName() != "moduleLaboratoryScreen":
        raise RuntimeError(f"No se abrió el laboratorio: {lab.objectName()}")
    c.ventana.showMaximized()
    esperar(1.0)
    c.js(lab, f"inputText.text = {json.dumps(TEXTO)}")
    c.js(lab, "root.chooseLearningLevel('advanced')")
    return lab


def animar_pasos(c: cu.Conductor, lab) -> None:
    # Recorre las operaciones y relanza su animación para que nunca quede
    # una escena estática durante la medición.
    pasos = int(c.js(lab, "root.steps.length") or 1)
    estado = {"i": 0}

    def siguiente() -> None:
        c.js(lab, f"root.currentStepIndex = {estado['i'] % pasos}; root.showFormulaPane()")
        estado["i"] += 1

    temporizador = QTimer()
    temporizador.timeout.connect(siguiente)
    temporizador.start(2500)
    siguiente()
    animar_pasos.temporizador = temporizador  # vivo mientras dure el escenario


def detener_animacion() -> None:
    temporizador = getattr(animar_pasos, "temporizador", None)
    if temporizador is not None:
        temporizador.stop()


def escenario_laboratorio(c, cuadros, lab, segundos) -> dict:
    c.js(lab, "root.chooseMode('inference'); root.runAnalysis(false)")
    c.esperar(lambda: not c.vm.moduleLaboratoryController.busy
              and c.js(lab, "root.analysis.module_id") == MODULO_LAB, 120)
    resultado = cuadros.medir(lambda: animar_pasos(c, lab), segundos)
    detener_animacion()
    return resultado


def escenario_calculo(c, cuadros, lab, en_hilo: bool, repeticiones: int = 5) -> dict:
    """Animación en curso mientras se repite el análisis en entrenamiento."""
    controlador = c.vm.moduleLaboratoryController
    controlador.run_inline = not en_hilo
    c.js(lab, "root.chooseMode('training')")
    c.esperar(lambda: not controlador.busy, 120)
    duraciones: list[float] = []

    def repetir() -> None:
        animar_pasos(c, lab)
        for _ in range(repeticiones):
            inicio = time.perf_counter()
            c.js(lab, "root.runAnalysis(true, true)")
            while controlador.busy:
                esperar(0.005)
            duraciones.append(time.perf_counter() - inicio)
            esperar(0.5)

    resultado = cuadros.medir(repetir, 0.5)
    detener_animacion()
    controlador.run_inline = False
    resultado["analisis_ms"] = round(1000 * statistics.median(duraciones), 1)
    resultado["repeticiones"] = repeticiones
    return resultado


def escenario_inferencia(c, cuadros, segundos) -> dict:
    pantalla = cu._abrir_inferencia_con(c, "Esp-Ing")
    c.ventana.showMaximized()
    c.js(pantalla, f"campoPrompt.text = {json.dumps(cu.PROMPT_INFERENCIA)}")
    c.js(pantalla, "maxTokens.value = 40; muestreoCodicioso.checked = false")
    # La generación es paso a paso: cada clic produce un token y su escena.
    pasos = {"n": 0}

    def generar() -> None:
        boton = cu._boton_generar(c, pantalla)
        if boton.property("enabled"):
            c.clic(boton)
            pasos["n"] += 1

    temporizador = QTimer()
    temporizador.timeout.connect(generar)
    resultado = cuadros.medir(lambda: (generar(), temporizador.start(1500)), segundos)
    temporizador.stop()
    resultado["tokens_solicitados"] = pasos["n"]
    if c.vm.inferenceController.estaGenerando:
        c.vm.inferenceController.detener()
        c.esperar(lambda: not c.vm.inferenceController.estaGenerando, 20)
    c.volver_a_raiz()
    return resultado


def main(argv: list[str] | None = None) -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--modelo", type=Path, required=True, help="el .tvismodel distribuido")
    parser.add_argument("--segundos", type=float, default=20.0)
    parser.add_argument("--minutos", type=float, default=0.0, help="sesión prolongada")
    parser.add_argument("--json", type=Path)
    args = parser.parse_args(argv)

    cu.preparar_sandbox()
    shutil.copy2(args.modelo, cu._rutas.DIR_CHECKPOINTS / NOMBRE_MODELO)
    c = cu.Conductor()
    c.arrancar()
    cuadros = Cuadros(c.ventana)
    informe: dict = {"entorno": entorno(c), "memoria_inicial": memoria(), "escenarios": {}}

    lab = preparar(c, args.modelo)
    e = informe["escenarios"]
    e["laboratorio_animacion"] = escenario_laboratorio(c, cuadros, lab, args.segundos)
    e["calculo_en_hilo"] = escenario_calculo(c, cuadros, lab, en_hilo=True)
    e["calculo_en_interfaz"] = escenario_calculo(c, cuadros, lab, en_hilo=False)
    c.volver_a_raiz()
    e["inferencia"] = escenario_inferencia(c, cuadros, args.segundos)
    informe["memoria_tras_escenarios"] = memoria()

    if args.minutos > 0:
        muestras = []
        fin = time.monotonic() + args.minutos * 60
        ciclo = 0
        while time.monotonic() < fin:
            ciclo += 1
            lab = preparar(c, args.modelo)
            fps_lab = escenario_laboratorio(c, cuadros, lab, 30)["fps"]
            c.volver_a_raiz()
            fps_inf = escenario_inferencia(c, cuadros, 30)["fps"]
            muestra = {"minuto": round(args.minutos - (fin - time.monotonic()) / 60, 1),
                       "ciclo": ciclo, "fps_laboratorio": fps_lab, "fps_inferencia": fps_inf,
                       **memoria()}
            muestras.append(muestra)
            print(json.dumps(muestra, ensure_ascii=False), flush=True)
        informe["sesion_prolongada"] = {
            "minutos": args.minutos,
            "ciclos": ciclo,
            "muestras": muestras,
            "advertencias_qt": sum(1 for m in c.mensajes_qt if m.startswith("[QtWarningMsg]")),
            "errores_qt": sum(1 for m in c.mensajes_qt
                              if m.startswith(("[QtCriticalMsg]", "[QtFatalMsg]"))),
        }

    c.cerrar()
    texto = json.dumps(informe, indent=2, ensure_ascii=False)
    print(texto)
    if args.json:
        args.json.write_text(texto, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
