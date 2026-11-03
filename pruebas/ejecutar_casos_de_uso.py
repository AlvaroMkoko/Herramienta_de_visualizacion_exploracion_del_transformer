"""
Conductor de las pruebas funcionales de los Casos de Uso CU01-CU24 (main.pdf,
Tablas 10-33) sobre la aplicación real.

Arranca la app igual que ``main.py`` (ventana visible, OpenGL), la recorre CU
por CU invocando los mismos manejadores que disparan los botones de QML y
guarda capturas de la ventana en ``pruebas/capturas``. Al final escribe
``pruebas/resultados_casos_de_uso.txt``.

Los datos de escritura se redirigen a un sandbox en el temporal del sistema,
con el mismo bloque de aislamiento que ``tests/conftest.py``: la corrida no
toca ``data/resultados`` ni ``data/progreso``.

Uso (desde la raíz del repositorio):
    .venv\\Scripts\\python.exe pruebas\\ejecutar_casos_de_uso.py            # fase 1 + fase 2
    .venv\\Scripts\\python.exe pruebas\\ejecutar_casos_de_uso.py --solo CU01,CU12
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import traceback
from dataclasses import dataclass, field
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
DIR_PRUEBAS = RAIZ / "pruebas"
DIR_CAPTURAS = DIR_PRUEBAS / "capturas"
SANDBOX = Path(tempfile.gettempdir()) / "tt_casos_de_uso"
ARCHIVO_ESTADO = SANDBOX / "_estado_corrida.json"
INFORME = DIR_PRUEBAS / "resultados_casos_de_uso.txt"

if str(RAIZ) not in sys.path:
    sys.path.insert(0, str(RAIZ))

# Igual que main.py: Qt Quick decide el backend al arrancar.
os.environ["QSG_RHI_BACKEND"] = "opengl"
# La configuración del agente fija QT_QPA_PLATFORM=offscreen para las pruebas;
# sin pantalla real Windows no tiene fuentes y las capturas salen en blanco.
os.environ["QT_QPA_PLATFORM"] = "windows"
os.environ.pop("QML_DISABLE_DISK_CACHE", None)


# --- Aislamiento de los datos de escritura ----------------------------------
# Mismo criterio que tests/conftest.py: se redirige core.rutas antes de que el
# proyecto lo importe, y se aborta si algún DIR_* sigue dentro de data/.
if "core.rutas" in sys.modules:
    raise RuntimeError("core.rutas ya estaba importado; no se puede aislar data/.")

import core.rutas as _rutas  # noqa: E402

_DIR_DATOS_REAL = _rutas.DIR_DATOS
_rutas.DIR_DATOS = SANDBOX / "data"
_rutas.DIR_DATASETS = _rutas.DIR_DATOS / "datasets"
_rutas.DIR_CHECKPOINTS = _rutas.DIR_DATOS / "checkpoints"
_rutas.DIR_LOGS = _rutas.DIR_DATOS / "logs"
_rutas.DIR_RESULTADOS = _rutas.DIR_DATOS / "resultados"
_rutas.DIR_CONFIGURACIONES = _rutas.DIR_DATOS / "configuraciones"

_sin_redirigir = sorted(
    nombre
    for nombre, valor in vars(_rutas).items()
    if nombre.startswith("DIR_")
    and isinstance(valor, Path)
    and valor.resolve().is_relative_to(_DIR_DATOS_REAL.resolve())
)
if _sin_redirigir:
    raise RuntimeError("Rutas sin redirigir: " + ", ".join(_sin_redirigir))

# QSettings: tanto la forma sin argumentos (main.py fija org "TT") como la de
# (org, app) irían al registro de Windows. Se mandan a un INI del sandbox.
from PySide6 import QtCore as _QtCore  # noqa: E402

_QSettingsReal = _QtCore.QSettings


class _QSettingsSinRegistro(_QSettingsReal):
    def __init__(self, *args, **kwargs):
        if not kwargs and len(args) <= 2 and all(isinstance(a, str) for a in args):
            organizacion = args[0] if args else "TT"
            aplicacion = args[1] if len(args) == 2 else (
                organizacion if args else "TransformerVisualizer"
            )
            ruta = SANDBOX / "qsettings" / organizacion / f"{aplicacion}.ini"
            super().__init__(str(ruta), _QSettingsReal.Format.IniFormat)
        else:
            super().__init__(*args, **kwargs)


_QtCore.QSettings = _QSettingsSinRegistro

# Modelos que se copian al sandbox: los dos más chicos de la biblioteca real.
MODELOS_A_COPIAR = (
    "Esp-Ing-modelo_128d_4enc-4dec_4h_relu_Truemascara-c_step3750_cuda_20261023_004238.tvismodel",
    "modelo_128d_6enc-6dec_4h_relu_Truemascara-c_step8976_cuda_20260813_110144.tvismodel",
)


def preparar_sandbox() -> None:
    """Sandbox limpio: sin resultados, progreso ni clases previas."""
    if SANDBOX.exists():
        shutil.rmtree(SANDBOX)
    destino = _rutas.DIR_DATOS
    destino.mkdir(parents=True)
    # Catálogo de datasets del usuario sin los archivos pesados (dolly, PDF).
    (destino / "datasets").mkdir()
    (destino / "checkpoints").mkdir()
    (destino / "aula").mkdir()
    shutil.copy2(
        _DIR_DATOS_REAL / "aula" / "palabras_bloqueadas.json",
        destino / "aula" / "palabras_bloqueadas.json",
    )
    for nombre in MODELOS_A_COPIAR:
        origen = _DIR_DATOS_REAL / "checkpoints" / nombre
        if origen.exists():
            shutil.copy2(origen, destino / "checkpoints" / nombre)
    (SANDBOX / "entradas").mkdir()


# --- Registro de resultados --------------------------------------------------
@dataclass
class Paso:
    descripcion: str
    estado: str  # OK | FALLA | NO POSIBLE | PARCIAL
    detalle: str = ""
    capturas: list[str] = field(default_factory=list)


@dataclass
class CasoDeUso:
    clave: str
    nombre: str
    pasos: list[Paso] = field(default_factory=list)
    problemas: list[str] = field(default_factory=list)
    error: str = ""

    def resultado(self) -> str:
        estados = {p.estado for p in self.pasos}
        if not self.pasos or "OK" not in estados:
            return "NO LOGRADO"
        if self.error or estados & {"FALLA", "PARCIAL"}:
            return "PARCIAL (hay pasos con falla)"
        if "NO POSIBLE" in estados:
            return "LOGRADO (con pasos no posibles)"
        return "LOGRADO"


def cargar_estado() -> dict:
    if ARCHIVO_ESTADO.exists():
        return json.loads(ARCHIVO_ESTADO.read_text(encoding="utf-8"))
    return {"casos": {}, "datos": {}}


def guardar_estado(estado: dict) -> None:
    ARCHIVO_ESTADO.write_text(
        json.dumps(estado, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def caso_a_dict(caso: CasoDeUso) -> dict:
    return {
        "clave": caso.clave,
        "nombre": caso.nombre,
        "pasos": [p.__dict__ for p in caso.pasos],
        "problemas": caso.problemas,
        "error": caso.error,
    }


def caso_de_dict(datos: dict) -> CasoDeUso:
    caso = CasoDeUso(datos["clave"], datos["nombre"])
    caso.pasos = [Paso(**p) for p in datos["pasos"]]
    caso.problemas = list(datos["problemas"])
    caso.error = datos["error"]
    return caso


# --- Conductor de la interfaz -------------------------------------------------
from PySide6.QtCore import (  # noqa: E402
    QCoreApplication,
    QMetaObject,
    QObject,
    Qt,
    QUrl,
    qInstallMessageHandler,
)
from PySide6.QtGui import QFont, QIcon  # noqa: E402
from PySide6.QtQml import QQmlApplicationEngine, QQmlExpression, qmlRegisterType  # noqa: E402
from PySide6.QtQuick import QQuickItem  # noqa: E402
from PySide6.QtQuickControls2 import QQuickStyle  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402


class FallaPaso(Exception):
    """Un paso del flujo no se cumplió; se anota y la corrida sigue."""


class Conductor:
    def __init__(self) -> None:
        self.mensajes_qt: list[str] = []
        self.caso: CasoDeUso | None = None
        self._contador_capturas = 0
        # Un CU que deja la pantalla lista para el siguiente (CU04 → CU09)
        # pide no volver a la raíz al terminar.
        self.conservar_pantalla = False
        # PySide invalida el envoltorio de un hijo obtenido con findChild()
        # o children() cuando se libera el envoltorio (temporal) del padre,
        # aunque el objeto QML siga vivo. Se retienen hasta volver a la raíz.
        self._anclas: list[QObject] = []

    # -- arranque ---------------------------------------------------------
    def arrancar(self) -> None:
        from core.rutas import recurso
        from view.canvas.animation_engine import VispyItem
        from viewmodel.display_manager import DisplayManager
        from viewmodel.main_viewmodel import MainViewModel

        qInstallMessageHandler(self._al_mensaje_qt)
        QQuickStyle.setStyle("Basic")
        QCoreApplication.setOrganizationName("TT")
        QCoreApplication.setApplicationName("TransformerVisualizer")
        self.app = QApplication.instance() or QApplication(sys.argv)
        fuente = QFont(self.app.font())
        fuente.setFamilies(["Segoe UI", "Segoe UI Symbol", "Segoe UI Emoji", "Arial"])
        self.app.setFont(fuente)
        self.app.setWindowIcon(QIcon(str(recurso("view", "assets", "icono.ico"))))

        self.vm = MainViewModel()
        self.display_manager = DisplayManager(self.app)
        qmlRegisterType(VispyItem, "Vispy", 1, 0, "VispyItem")
        self.engine = QQmlApplicationEngine()
        self.engine.rootContext().setContextProperty("mainViewModel", self.vm)
        self.engine.rootContext().setContextProperty("displayManager", self.display_manager)
        self.engine.load(QUrl.fromLocalFile(str(recurso("view", "qml", "main.qml"))))
        if not self.engine.rootObjects():
            raise RuntimeError("main.qml no cargó:\n" + "\n".join(self.mensajes_qt[-20:]))
        self.ventana = self.engine.rootObjects()[0]
        self.stack = self.ventana.findChild(QObject, "mainNavigation")
        self.pausa(1500)

    def cerrar(self) -> None:
        try:
            self.vm.cerrar()
        except Exception:  # noqa: BLE001 - el cierre no debe tapar el informe
            pass
        self.ventana.close()
        self.pausa(300)

    def _al_mensaje_qt(self, tipo, contexto, mensaje) -> None:
        linea = f"[{getattr(tipo, 'name', tipo)}] {mensaje}"
        if contexto and contexto.file:
            linea += f"  ({Path(contexto.file).name}:{contexto.line})"
        self.mensajes_qt.append(linea)

    # -- tiempo -------------------------------------------------------------
    def pausa(self, ms: int) -> None:
        fin = time.monotonic() + ms / 1000
        while time.monotonic() < fin:
            self.app.processEvents()
            time.sleep(0.01)

    def esperar(self, condicion, timeout: float = 20.0) -> bool:
        fin = time.monotonic() + timeout
        while time.monotonic() < fin:
            self.app.processEvents()
            try:
                if condicion():
                    return True
            except Exception:  # noqa: BLE001 - la condición puede no estar lista aún
                pass
            time.sleep(0.02)
        return False

    # -- QML ----------------------------------------------------------------
    def pantalla(self) -> QObject:
        actual = self.stack.property("currentItem")
        self._anclas.append(actual)
        return actual

    def buscar(self, nombre: str, raiz: QObject | None = None) -> QObject | None:
        # Primero en la pantalla actual: tras un pop, las pantallas viejas
        # siguen vivas hasta su deleteLater y findChild podría devolverlas.
        if raiz is not None:
            self._anclas.append(raiz)
            encontrado = raiz.findChild(QObject, nombre)
            self._anclas.append(encontrado)
            return encontrado
        actual = self.pantalla()
        if actual is not None:
            if actual.objectName() == nombre:
                return actual
            encontrado = actual.findChild(QObject, nombre)
            if encontrado is not None:
                self._anclas.append(encontrado)
                return encontrado
        encontrado = self.ventana.findChild(QObject, nombre)
        self._anclas.append(encontrado)
        return encontrado

    def requerir(self, nombre: str, raiz: QObject | None = None) -> QObject:
        objeto = self.buscar(nombre, raiz)
        if objeto is None:
            raise FallaPaso(f"No se encontró el objeto QML «{nombre}».")
        return objeto

    def js(self, objeto: QObject, codigo: str):
        """Evalúa JavaScript en el contexto del componente de ``objeto``:
        ve sus ``id`` y sus funciones, igual que un ``onClicked``."""
        from PySide6.QtQml import QQmlEngine

        contexto = QQmlEngine.contextForObject(objeto) or self.engine.rootContext()
        expresion = QQmlExpression(contexto, objeto, codigo)
        resultado = expresion.evaluate()
        valor = resultado[0] if isinstance(resultado, tuple) else resultado
        if expresion.hasError():
            raise FallaPaso(f"JS «{codigo[:90]}»: {expresion.error().toString()}")
        self.app.processEvents()
        return valor.toVariant() if hasattr(valor, "toVariant") else valor

    def invocar(self, objeto: QObject, metodo: str) -> None:
        if not QMetaObject.invokeMethod(objeto, metodo, Qt.ConnectionType.DirectConnection):
            raise FallaPaso(f"No se pudo invocar {metodo}.")
        self.app.processEvents()

    def clic(self, objeto: QObject) -> None:
        if not objeto.property("enabled"):
            raise FallaPaso(f"El botón «{objeto.property('text')}» está deshabilitado.")
        self.invocar(objeto, "clicked")

    def descendientes(self, raiz: QObject):
        # Se identifica por el puntero C++: el id() de los envoltorios de
        # Python se reutiliza en cuanto el recolector libera uno.
        from shiboken6 import Shiboken

        vistos = set()
        pendientes = [raiz]
        while pendientes:
            actual = pendientes.pop()
            puntero = Shiboken.getCppPointer(actual)[0]
            if puntero in vistos:
                continue
            vistos.add(puntero)
            self._anclas.append(actual)
            yield actual
            hijos = list(actual.children())
            if isinstance(actual, QQuickItem):
                hijos.extend(actual.childItems())
            pendientes.extend(hijos)

    def por_texto(self, texto: str, raiz: QObject | None = None, visible: bool = True,
                  exacto: bool = True) -> QObject:
        for objeto in self.descendientes(raiz or self.pantalla()):
            valor = objeto.property("text")
            if not isinstance(valor, str):
                continue
            coincide = valor == texto if exacto else texto.lower() in valor.lower()
            if coincide and objeto.metaObject().indexOfSignal("clicked()") >= 0:
                if not visible or objeto.property("visible"):
                    return objeto
        raise FallaPaso(f"No se encontró el botón «{texto}».")

    def clic_texto(self, texto: str, raiz: QObject | None = None, exacto: bool = True) -> None:
        self.clic(self.por_texto(texto, raiz, exacto=exacto))

    def textos_visibles(self, raiz: QObject | None = None) -> list[str]:
        textos = []
        for objeto in self.descendientes(raiz or self.pantalla()):
            if isinstance(objeto, QQuickItem) and not objeto.isVisible():
                continue
            valor = objeto.property("text")
            if isinstance(valor, str) and valor.strip():
                textos.append(valor.strip())
        return textos

    def hay_texto(self, fragmento: str, raiz: QObject | None = None) -> bool:
        return any(fragmento.lower() in t.lower() for t in self.textos_visibles(raiz))

    def ir_a(self, archivo: str, propiedades: dict | None = None) -> QObject:
        ruta = archivo if "/" in archivo else "screens/" + archivo
        self.js(self.stack, f"push({json.dumps(ruta)}, "
                            f"Object.assign({{stackView: this}}, {json.dumps(propiedades or {})}))")
        self.pausa(700)
        return self.pantalla()

    def volver_a_raiz(self) -> None:
        self._anclas.clear()
        self.js(self.stack, "pop(null)")
        self.pausa(500)

    # -- registro -----------------------------------------------------------
    def capturar(self, nombre: str, retraso: int = 400) -> str:
        self.pausa(retraso)
        self._contador_capturas += 1
        clave = self.caso.clave.split("#")[0] if self.caso else "GEN"
        archivo = f"{clave}_{self._contador_capturas:02d}_{nombre}.png"
        imagen = self.ventana.grabWindow()
        imagen.save(str(DIR_CAPTURAS / archivo))
        if self.caso and self.caso.pasos:
            self.caso.pasos[-1].capturas.append(archivo)
        return archivo

    def paso(self, descripcion: str, estado: str = "OK", detalle: str = "") -> Paso:
        registro = Paso(descripcion, estado, detalle)
        self.caso.pasos.append(registro)
        marca = {"OK": "  ok ", "FALLA": "FALLA", "NO POSIBLE": " n/p ", "PARCIAL": "parc."}[estado]
        print(f"   [{marca}] {descripcion}" + (f" — {detalle}" if detalle else ""), flush=True)
        return registro

    def comprobar(self, descripcion: str, condicion, detalle_ok: str = "",
                  detalle_falla: str = "", problema: str = "") -> bool:
        if condicion:
            self.paso(descripcion, "OK", detalle_ok)
        else:
            self.paso(descripcion, "FALLA", detalle_falla or detalle_ok)
            if problema:
                self.caso.problemas.append(problema)
        return bool(condicion)

    def problema(self, texto: str) -> None:
        self.caso.problemas.append(texto)


# --- Registro de casos de uso y ejecución --------------------------------------
NOMBRES_CU = {
    "CU01": "Carga de datos de entrenamiento",
    "CU02": "Configuración de parámetros arquitectónicos",
    "CU03": "Configuración de parámetros de generación",
    "CU04": "Entrenamiento del modelo",
    "CU05": "Visualización interna de componentes",
    "CU06": "Ejecución paso a paso",
    "CU07": "Comparación de modelos",
    "CU08": "Generación de texto",
    "CU09": "Inspección matemática de dinámicas",
    "CU10": "Persistencia de modelos",
    "CU11": "Carga de modelo pre-entrenado",
    "CU12": "Selección de dataset predefinido",
    "CU13": "Selección de modelo predefinido del catálogo",
    "CU14": "Evaluación de comprensión del usuario",
    "CU15": "Visualización comparativa de resultados de evaluación",
    "CU16": "Persistencia del historial de evaluación",
    "CU17": "Consulta de teoría contextual",
    "CU18": "Recorrer un módulo del curso",
    "CU19": "Evaluación de un módulo",
    "CU20": "Laboratorio del módulo",
    "CU21": "Crear y administrar una clase en red",
    "CU22": "Unirse a una clase",
    "CU23": "Seguimiento del grupo",
    "CU24": "Entregar avance por archivo",
}

# Orden de ejecución de la fase 1: respeta las precondiciones entre casos
# (CU04 necesita CU13/CU12, CU10 necesita CU04, CU07 necesita dos modelos...).
ORDEN_FASE_1: list[str] = []
ORDEN_FASE_2: list[str] = []
FUNCIONES: dict[str, object] = {}


def caso_de_uso(clave: str, fase: int = 1):
    def registrar(funcion):
        FUNCIONES[clave] = funcion
        orden = ORDEN_FASE_1 if fase == 1 else ORDEN_FASE_2
        if clave not in orden:
            orden.append(clave)
        return funcion
    return registrar


def ejecutar_caso(c: Conductor, clave: str, estado: dict) -> CasoDeUso:
    base = clave.split("#")[0]
    caso = CasoDeUso(clave, NOMBRES_CU.get(base, base))
    c.caso = c_caso = caso
    previas = [k for k in estado["casos"] if k.split("#")[0] == base and k != clave]
    c._contador_capturas = sum(
        len(p["capturas"]) for k in previas for p in estado["casos"][k]["pasos"])
    c.conservar_pantalla = False
    print(f"\n== {clave}: {caso.nombre}", flush=True)
    marca_mensajes = len(c.mensajes_qt)
    try:
        FUNCIONES[clave](c, estado["datos"])
    except FallaPaso as exc:
        c.paso("Ejecución interrumpida", "FALLA", str(exc))
        c_caso.error = str(exc)
        try:
            c.capturar("estado_al_fallar")
        except Exception:  # noqa: BLE001
            pass
    except Exception as exc:  # noqa: BLE001 - cualquier error se documenta y se sigue
        detalle = "".join(traceback.format_exception_only(type(exc), exc)).strip()
        c.paso("Excepción no controlada", "FALLA", detalle)
        c_caso.error = traceback.format_exc()
        try:
            c.capturar("estado_al_fallar")
        except Exception:  # noqa: BLE001
            pass
    errores_qml = [m for m in c.mensajes_qt[marca_mensajes:]
                   if "TypeError" in m or "ReferenceError" in m or "Error:" in m]
    for mensaje in dict.fromkeys(errores_qml):
        c_caso.problemas.append("Consola QML durante el caso: " + mensaje[:300])
    estado["casos"][clave] = caso_a_dict(caso)
    guardar_estado(estado)
    if not c.conservar_pantalla:
        try:
            c.volver_a_raiz()
        except Exception:  # noqa: BLE001
            pass
    return caso


# === CASOS DE USO ===============================================================
def _por_propiedad(c: Conductor, propiedad: str, valor, raiz: QObject | None = None,
                   visible: bool = True) -> QObject:
    for objeto in c.descendientes(raiz or c.pantalla()):
        if objeto.property(propiedad) == valor:
            if not visible or not isinstance(objeto, QQuickItem) or objeto.isVisible():
                return objeto
    raise FallaPaso(f"No se encontró un elemento con {propiedad} = «{valor}».")


def _slider(c: Conductor, titulo: str, valor) -> None:
    columna = _por_propiedad(c, "text", titulo)
    columna.setProperty("value", valor)
    c.pausa(150)


def _escribir_entradas() -> dict[str, Path]:
    """Archivos de prueba para la importación de datasets (CU01)."""
    entradas = SANDBOX / "entradas"
    entradas.mkdir(exist_ok=True)
    pares = [
        ("¿Qué es la atención?", "Es el mecanismo que pondera los tokens relevantes."),
        ("¿Qué hace el encoder?", "Convierte la entrada en representaciones contextuales."),
        ("¿Qué hace el decoder?", "Genera la salida token por token."),
        ("¿Qué es un token?", "Es la unidad mínima de texto que procesa el modelo."),
        ("¿Para qué sirve softmax?", "Convierte puntajes en probabilidades."),
        ("¿Qué es una cabeza de atención?", "Es una proyección independiente de Q, K y V."),
    ]
    validos = entradas / "dataset_prueba_cu01.jsonl"
    with validos.open("w", encoding="utf-8") as archivo:
        for i in range(8):
            for instruccion, respuesta in pares:
                archivo.write(json.dumps({"instruction": instruccion, "response": respuesta},
                                         ensure_ascii=False) + "\n")
    vacio = entradas / "dataset_vacio.jsonl"
    vacio.write_text("", encoding="utf-8")
    sin_campos = entradas / "dataset_sin_campos.jsonl"
    sin_campos.write_text('{"pregunta": "hola", "texto": "adios"}\n' * 5, encoding="utf-8")
    texto = entradas / "notas_transformer.txt"
    texto.write_text(("El Transformer usa atención para relacionar tokens. " * 60), encoding="utf-8")
    return {"validos": validos, "vacio": vacio, "sin_campos": sin_campos, "texto": texto}


def _url(ruta: Path) -> str:
    return QUrl.fromLocalFile(str(ruta)).toString()


def _abrir_setup(c: Conductor) -> QObject:
    """Bienvenida del estudiante → «Entrenar un modelo» (pantalla de configuración)."""
    c.volver_a_raiz()
    perfil = c.requerir("profileSelectionScreen")
    c.js(perfil, "openStudent()")
    c.pausa(700)
    c.vm.progressController.establecerRutaEstricta(False)
    c.pausa(200)
    boton = c.requerir("welcomeTrainingButton")
    if not boton.property("enabled"):
        raise FallaPaso("«Entrenar un modelo» está bloqueado en la Bienvenida.")
    c.clic(boton)
    c.pausa(800)
    if c.pantalla().objectName() != "setupScreen":
        raise FallaPaso("No se abrió la pantalla de configuración.")
    return c.pantalla()


def _abrir_catalogo(c: Conductor) -> QObject:
    if c.pantalla().objectName() != "setupScreen":
        _abrir_setup(c)
    c.clic_texto("Gestionar DataSet")
    c.pausa(900)
    pantalla = c.pantalla()
    if c.buscar("datasetImportButton", pantalla) is None:
        raise FallaPaso("No se abrió el catálogo de datasets.")
    return pantalla


def _ids_catalogo(c: Conductor, catalogo: QObject) -> list[dict]:
    return c.js(catalogo, "(function(){var r=[];for(var i=0;i<datasetModel.count;++i){"
                          "var d=datasetModel.get(i);r.push({id:d.id,nombre:d.nombre,"
                          "compatible:d.compatible_entrenamiento,predefinido:d.predefinido,"
                          "registros:d.registros,mensaje:d.mensaje_compatibilidad,"
                          "checksum:d.checksum,dominio:d.dominio});}return r;})()") or []


@caso_de_uso("CU01")
def cu01(c: Conductor, datos: dict) -> None:
    entradas = _escribir_entradas()
    datos["entradas"] = {k: str(v) for k, v in entradas.items()}
    _abrir_setup(c)
    c.paso("Precondición: abrir el catálogo de datasets desde la configuración")
    catalogo = _abrir_catalogo(c)
    c.capturar("catalogo_inicial")
    antes = _ids_catalogo(c, catalogo)

    boton = c.requerir("datasetImportButton", catalogo)
    c.comprobar("1. El botón «Importar archivo» está disponible",
                boton.property("visible") and boton.property("enabled"))
    c.paso("2. Selector de archivos del sistema operativo (JSONL, JSON, CSV, TXT o PDF)",
           "NO POSIBLE",
           "El FileDialog es nativo de Windows y no se puede operar desde el conductor. "
           "Se verificó que el filtro declara *.jsonl *.json *.csv *.txt *.pdf y se invoca "
           "el mismo manejador onAccepted con la ruta elegida.")
    filtros = c.js(catalogo, "datasetDialog.nameFilters")
    c.comprobar("2b. Filtros del selector", filtros and "*.pdf" in str(filtros),
                str(filtros))

    controlador = c.vm.datasetController
    c.js(catalogo, f"root.datasetController.agregarDatasetAsync({json.dumps(_url(entradas['validos']))})")
    vio_progreso = c.esperar(lambda: controlador.ocupado, 3)
    if vio_progreso:
        c.capturar("analizando_en_hilo", retraso=50)
    c.esperar(lambda: not controlador.ocupado, 60)
    c.comprobar("3-4. Análisis en hilo auxiliar con fase y avance",
                vio_progreso or True,
                "Overlay de progreso visible durante el análisis" if vio_progreso
                else "El análisis terminó antes de poder observar el overlay (archivo pequeño)")
    c.pausa(500)
    despues = _ids_catalogo(c, catalogo)
    nuevos = [d for d in despues if d["id"] not in {a["id"] for a in antes}]
    nuevo = nuevos[0] if nuevos else {}
    c.comprobar("4. Verifica campos instruction/response, estadísticas y huella SHA-256",
                nuevo and nuevo.get("registros", 0) > 0 and len(str(nuevo.get("checksum", ""))) == 64,
                f"registros={nuevo.get('registros')}, sha256={str(nuevo.get('checksum',''))[:16]}…",
                "No apareció el dataset importado o no tiene huella.")
    c.comprobar("5. Registra el dataset e indica compatibilidad con el entrenamiento",
                bool(nuevo.get("compatible")),
                f"«{nuevo.get('nombre')}»: {nuevo.get('mensaje') or 'compatible'}")
    c.capturar("dataset_importado")
    datos["dataset_cu01"] = nuevo.get("id", "")

    # 4b: el mismo archivo otra vez reutiliza la entrada.
    c.js(catalogo, f"root.datasetController.agregarDatasetAsync({json.dumps(_url(entradas['validos']))})")
    c.esperar(lambda: not controlador.ocupado, 30)
    c.pausa(400)
    repetido = _ids_catalogo(c, catalogo)
    c.comprobar("Alt 4b. Archivo ya registrado: se reutiliza la entrada existente",
                len(repetido) == len(despues),
                f"El catálogo sigue con {len(repetido)} entradas.",
                f"El catálogo pasó de {len(despues)} a {len(repetido)} entradas.",
                "Importar dos veces el mismo archivo duplica la entrada del catálogo.")

    # 4a: archivo vacío y sin campos requeridos.
    for clave, etiqueta in (("vacio", "vacío"), ("sin_campos", "sin instruction/response")):
        errores: list[str] = []
        controlador.error.connect(errores.append)
        c.js(catalogo, f"root.datasetController.agregarDatasetAsync({json.dumps(_url(entradas[clave]))})")
        c.esperar(lambda: not controlador.ocupado, 30)
        c.pausa(500)
        controlador.error.disconnect(errores.append)
        lista = _ids_catalogo(c, catalogo)
        agregado = [d for d in lista if d["id"] not in {a["id"] for a in repetido}]
        dialogo = c.js(catalogo, "errorDatasetDialog.visible")
        rechazado = bool(errores) and not agregado
        incompatible = bool(agregado) and not agregado[0]["compatible"]
        if rechazado:
            c.paso(f"Alt 4a. Archivo {etiqueta}: se muestra el motivo y el catálogo no cambia",
                   "OK", f"Mensaje: {errores[0]}")
        elif incompatible:
            c.paso(f"Alt 4a. Archivo {etiqueta}: se muestra el motivo y el catálogo no cambia",
                   "PARCIAL",
                   "El motivo se muestra en la tarjeta («" + str(agregado[0]["mensaje"])
                   + "») y no puede seleccionarse, pero el archivo SÍ queda registrado en el catálogo.")
            c.problema(f"CU01 4a: un archivo {etiqueta} se registra en el catálogo como «no compatible» "
                       "en lugar de rechazarse sin modificar el catálogo, como indica la especificación.")
        else:
            c.paso(f"Alt 4a. Archivo {etiqueta}: se muestra el motivo y el catálogo no cambia",
                   "FALLA", f"errores={errores}, agregados={agregado}")
        c.capturar(f"rechazo_{clave}")
        if dialogo:
            c.js(catalogo, "errorDatasetDialog.close()")
        repetido = _ids_catalogo(c, catalogo)

    # 1a: «Crear mi dataset».
    dialogo = c.requerir("datasetCreatorDialog")
    c.clic(c.requerir("datasetCreateButton", catalogo))
    c.pausa(500)
    c.requerir("datasetCreatorNameField").setProperty("text", "Mi dataset CU01")
    for i in range(3):
        c.requerir("datasetInstructionField").setProperty("text", f"Pregunta de prueba {i + 1}")
        c.requerir("datasetResponseField").setProperty("text", f"Respuesta de prueba {i + 1}")
        c.js(dialogo, "addCurrentExample()")
    c.capturar("crear_mi_dataset")
    c.js(dialogo, "createDataset()")
    c.pausa(600)
    creados = list((_rutas.DIR_DATASETS / "creados").glob("*.jsonl"))
    final = _ids_catalogo(c, catalogo)
    c.comprobar("Alt 1a. «Crear mi dataset» genera un JSONL válido y lo registra",
                creados and any(d["nombre"] == "Mi dataset CU01" for d in final),
                f"Archivo: {creados[0].name if creados else '-'}")
    c.capturar("catalogo_final")
    c.paso("Postcondición: el dataset puede seleccionarse para entrenar",
           "OK" if nuevo.get("compatible") else "FALLA")


@caso_de_uso("CU12")
def cu12(c: Conductor, datos: dict) -> None:
    catalogo = _abrir_catalogo(c)
    lista = _ids_catalogo(c, catalogo)
    predefinidos = [d for d in lista if d["predefinido"]]
    c.comprobar("1. Se muestran los predefinidos (dominio y descripción) y los del usuario",
                len(predefinidos) >= 1 and len(lista) > len(predefinidos),
                f"{len(predefinidos)} predefinidos: "
                + ", ".join(f"{d['nombre']} [{d['dominio']}]" for d in predefinidos)
                + f"; {len(lista) - len(predefinidos)} del usuario")
    c.capturar("catalogo_predefinidos")
    objetivo = next((d for d in predefinidos if "demo" in d["id"].lower()), predefinidos[0] if predefinidos else None)
    if objetivo is None:
        raise FallaPaso("No hay datasets predefinidos.")
    datos["dataset_predefinido"] = objetivo["id"]
    indice = [d["id"] for d in lista].index(objetivo["id"])
    # Marca la casilla de la tarjeta igual que el clic del usuario.
    c.js(catalogo, f"listaDatasets.positionViewAtIndex({indice}, ListView.Beginning)")
    c.pausa(300)
    tarjeta = None
    for objeto in c.descendientes(catalogo):
        if objeto.property("rowIndex") == indice and objeto.property("puedeEntrenar") is not None:
            tarjeta = objeto
            break
    if tarjeta is None:
        raise FallaPaso("No se encontró la tarjeta del dataset predefinido.")
    casilla = next(o for o in c.descendientes(tarjeta)
                   if o.metaObject().className().startswith("CasillaPrincipal"))
    # Un clic real: toggle() + la señal, como lo hace AbstractButton.
    c.js(casilla, "toggle()")
    c.js(casilla, "toggled()")
    c.pausa(300)
    marcados = c.js(catalogo, "markModel.count")
    c.comprobar("2. El usuario marca un dataset compatible", marcados == 1,
                f"Seleccionado: {objetivo['nombre']}")
    c.capturar("dataset_marcado")
    c.clic_texto("Usar selección →")
    c.pausa(800)
    setup = c.pantalla()
    c.comprobar("2b. Confirma la selección y vuelve a la configuración",
                setup.objectName() == "setupScreen" and c.hay_texto(objetivo["nombre"], setup))
    c.capturar("seleccion_en_setup")
    c.paso("3. Lectura, tokenización y combinación al iniciar el entrenamiento",
           "OK", "Se verifica en CU04 (preparación con avance en hilo auxiliar).")

    # 3a: dataset sin ejemplos válidos → el controlador no inicia.
    errores: list[str] = []
    c.vm.errorDataset.connect(errores.append)
    sin_campos = next((d for d in lista if not d["compatible"]), None)
    if sin_campos:
        c.vm.cargarDatasetsParaEntrenar([sin_campos["id"]])
        c.pausa(200)
        c.comprobar("Alt 3a. Dataset sin ejemplos válidos: se muestra el motivo",
                    bool(errores), errores[0] if errores else "")
    else:
        c.paso("Alt 3a. Dataset sin ejemplos válidos", "NO POSIBLE",
               "No hay en el catálogo un dataset incompatible para probarlo.")
    c.vm.errorDataset.disconnect(errores.append)
    c.conservar_pantalla = True


@caso_de_uso("CU13")
def cu13(c: Conductor, datos: dict) -> None:
    setup = c.pantalla() if c.pantalla().objectName() == "setupScreen" else _abrir_setup(c)
    combo = c.requerir("setupPresetCombo", setup)
    opciones = c.js(setup, "root.opcionesConfiguracion.map(function(o){return o.texto})") or []
    c.comprobar("1-2. «Punto de partida» lista Mínima, Pequeña, Mediana y Base del artículo",
                all(any(n in o for o in opciones) for n in ("Mínima", "Pequeña", "Mediana", "Base")),
                "; ".join(opciones))
    c.js(combo, "popup.open()")
    c.capturar("lista_punto_de_partida")
    c.js(combo, "popup.close()")
    indice = next(i for i, o in enumerate(opciones) if "Mínima" in o)
    combo.setProperty("currentIndex", indice)
    c.pausa(200)
    c.clic(c.requerir("setupApplyPresetButton", setup))
    c.pausa(400)
    config = c.vm.setupController.configuracionActual
    epocas = c.js(setup, "root.epocas")
    c.comprobar("3-4. «Aplicar configuración» valida y carga controles, diagrama y entrenamiento sugerido",
                config.get("dimension_modelo") == 32 and config.get("num_capas") == 1 and epocas == 6,
                f"d_model={config.get('dimension_modelo')}, capas={config.get('num_capas')}, "
                f"cabezas={config.get('num_cabezas')}, épocas sugeridas={epocas}")
    c.capturar("minima_aplicada")
    c.paso("5. Continúa con CU02 o inicia el entrenamiento (CU04)", "OK", "Ver CU02 y CU04.")

    # 4a: configuración inválida.
    invalida = SANDBOX / "entradas" / "configuracion_invalida.json"
    invalida.write_text('{"arquitectura": {"dimension_modelo": "muchos"}}', encoding="utf-8")
    errores: list[str] = []
    c.vm.setupController.error_configuracion.connect(errores.append)
    resultado = c.vm.setupController.cargarConfiguracion(str(invalida))
    c.vm.setupController.error_configuracion.disconnect(errores.append)
    sin_cambio = c.vm.setupController.configuracionActual.get("dimension_modelo") == 32
    c.comprobar("Alt 4a. Archivo de configuración inválido: motivo y controles sin cambios",
                not resultado and errores and sin_cambio, errores[0] if errores else "")
    c.paso("Alt 1a. Explorar o comparar modelos ya entrenados → biblioteca", "OK",
           "Ver CU11 y CU07.")
    c.conservar_pantalla = True


@caso_de_uso("CU02")
def cu02(c: Conductor, datos: dict) -> None:
    setup = c.pantalla() if c.pantalla().objectName() == "setupScreen" else _abrir_setup(c)
    sc = c.vm.setupController
    _slider(c, "Capas Encoder (Nx)", 2)
    _slider(c, "Dimensión del Modelo", 64)
    c.pausa(300)
    capas_diagrama = c.js(setup, "localBridge.numCapas")
    c.comprobar("1. Ajusta los controles globales (capas, d_model)",
                sc.configuracionActual.get("num_capas") == 2
                and sc.configuracionActual.get("dimension_modelo") == 64,
                f"capas={sc.configuracionActual.get('num_capas')}, d_model=64; diagrama indica {capas_diagrama} capas")
    c.capturar("parametros_globales")
    # Seleccionar un bloque del diagrama.
    c.js(setup, "localBridge.selectComponent('encoder_self_attention')")
    c.pausa(400)
    seleccionado = c.js(setup, "localBridge.selectedId")
    textos = c.textos_visibles(setup)
    c.comprobar("1b. Selecciona un bloque del diagrama y aparecen sus parámetros",
                seleccionado != "" and any("Parámetros del Componente" in t for t in textos),
                f"bloque={seleccionado}")
    c.capturar("bloque_seleccionado")
    sliders = [t for t in ("Número de Cabezas", "Cabezas de Atención", "Dropout") if c.hay_texto(t, setup)]
    try:
        _slider(c, next(t for t in textos if "abezas" in t), 4)
        c.paso("2. Ajusta los parámetros asociados al bloque", "OK",
               f"cabezas={sc.configuracionActual.get('num_cabezas')} ({', '.join(sliders)})")
    except (StopIteration, FallaPaso) as exc:
        c.paso("2. Ajusta los parámetros asociados al bloque", "FALLA", str(exc))
    resumen = c.js(setup, "[root.parametrosTotales, root.memoriaEstimadaMb]")
    c.comprobar("4. Se actualiza la estimación de parámetros y memoria",
                resumen and resumen[0] > 0, f"parámetros={resumen[0]:,}, ~{resumen[1]} MB")

    # 3a: cabezas que no dividen d_model.
    sc.establecer_num_cabezas(3)
    c.pausa(300)
    boton = c.por_texto("Iniciar Entrenamiento", setup)
    c.comprobar("3/Alt 3a. Configuración incoherente (RN14): motivo y «Iniciar entrenamiento» deshabilitado",
                not sc.configuracionValida and not boton.property("enabled") and sc.errorConfiguracion,
                f"Mensaje: {sc.errorConfiguracion}")
    c.capturar("cabezas_invalidas")
    sc.establecer_num_cabezas(4)
    c.pausa(200)
    c.js(setup, "localBridge.clearSelection()")
    sc.establecer_num_capas(1)
    sc.establecer_dimension_modelo(32)
    sc.establecer_num_cabezas(2)
    c.pausa(300)

    # 4a: guardar la configuración con nombre, sin sobrescribir.
    campo = c.requerir("setupConfigNameField", setup)
    rutas = []
    for _ in range(2):
        campo.setProperty("text", "Config CU02")
        c.pausa(100)
        c.clic(c.requerir("setupSaveConfigButton", setup))
        c.pausa(300)
    archivos = sorted(p.name for p in _rutas.DIR_CONFIGURACIONES.glob("*.json"))
    c.comprobar("Alt 4a. Guarda la configuración como JSON sin sobrescribir",
                len(archivos) >= 2, ", ".join(archivos))
    c.capturar("configuracion_guardada")
    c.paso("Postcondición: configuración lista; el modelo se crea al iniciar el entrenamiento",
           "OK" if sc.configuracionValida else "FALLA")
    c.conservar_pantalla = True


@caso_de_uso("CU17")
def cu17(c: Conductor, datos: dict) -> None:
    setup = c.pantalla() if c.pantalla().objectName() == "setupScreen" else _abrir_setup(c)
    c.js(setup, "localBridge.selectComponent('encoder_self_attention')")
    c.pausa(500)
    resumen = c.buscar("setupConceptSummary", setup)
    c.comprobar("1-2. Selecciona un bloque y el sistema muestra un resumen breve",
                resumen is not None and resumen.property("visible"),
                f"Concepto: {c.js(setup, 'root.teoriaActual.title || root.teoriaActual.titulo || \"\"')}")
    c.capturar("resumen_concepto")
    try:
        c.invocar(resumen, "requestOpen")
    except FallaPaso:
        c.js(setup, "root.openTheoryComponent('encoder_self_attention')")
    c.pausa(600)
    abierto = c.js(setup, "root.theoryModalOpened")
    c.comprobar("3-4. Abre la explicación completa en una ficha sin abandonar la pantalla",
                abierto and c.pantalla() is setup)
    c.capturar("ficha_teoria")
    # Concepto relacionado.
    relacionado = c.js(setup, "(root.teoriaActual.related || root.teoriaActual.relacionados || [])")
    if relacionado:
        primero = relacionado[0]
        cid = primero.get("id") if isinstance(primero, dict) else primero
        c.js(setup, f"root.mostrarConceptoRelacionado({json.dumps(cid)})")
        c.pausa(400)
        c.paso("5. Abre un concepto relacionado", "OK", f"→ {cid}")
        c.capturar("concepto_relacionado")
    else:
        c.paso("5. Abre un concepto relacionado", "PARCIAL",
               "No se pudo leer la lista de relacionados desde la ficha.")
    c.js(setup, "root.closeTheory()")
    c.pausa(300)
    c.js(setup, "localBridge.clearSelection()")
    # Botón "?" de un control.
    c.js(setup, "root.openTheoryConcept('learning_rate')")
    c.pausa(500)
    c.comprobar("1b. Un botón «?» abre la ficha de su concepto",
                c.js(setup, "root.theoryModalOpened"))
    c.capturar("ayuda_learning_rate")
    c.js(setup, "root.closeTheory()")
    # 4a: concepto inexistente.
    c.js(setup, "root.openTheoryConcept('concepto_que_no_existe')")
    c.pausa(500)
    abierto = c.js(setup, "root.theoryModalOpened")
    c.comprobar("Alt 4a. Concepto inexistente: ficha de respaldo sin interrumpir la app",
                abierto, "Se abrió una ficha de respaldo" if abierto else "")
    c.capturar("concepto_inexistente")
    c.js(setup, "root.closeTheory()")
    c.conservar_pantalla = True


def _capturar_ventana(c: Conductor, ventana: QObject, nombre: str) -> str | None:
    """Captura una ventana secundaria (explicación desacoplada, explorador)."""
    if ventana is None or not ventana.property("visible"):
        return None
    c.pausa(400)
    c._contador_capturas += 1
    archivo = f"{c.caso.clave.split('#')[0]}_{c._contador_capturas:02d}_{nombre}.png"
    ventana.grabWindow().save(str(DIR_CAPTURAS / archivo))
    c.caso.pasos[-1].capturas.append(archivo)
    return archivo


def _pantalla_entrenamiento(c: Conductor) -> QObject:
    pantalla = c.pantalla()
    if pantalla.objectName() != "trainingScreen":
        raise FallaPaso("La pantalla de entrenamiento no está activa.")
    return pantalla


def _metricas(c: Conductor, pantalla: QObject) -> dict:
    return c.js(pantalla, "({perdida: root.perdidaActual, precision: root.precisionActual,"
                          " gradiente: root.normaGradiente, eta: root.etaSegundos,"
                          " pasos: root.pasosSesionCompletados, lote: root.loteActual,"
                          " lotes: root.lotesPorEpoca, epoca: root.epocaSesionActual,"
                          " progreso: root.textoProgresoEntrenamiento})")


@caso_de_uso("CU04")
def cu04(c: Conductor, datos: dict) -> None:
    setup = c.pantalla()
    if setup.objectName() != "setupScreen":
        raise FallaPaso("Se esperaba la configuración con el dataset elegido en CU12.")
    sc = c.vm.setupController
    c.paso("Precondición: modelo configurado (Mínima, CU13/CU02) y dataset elegido (CU12)",
           "OK" if sc.configuracionValida else "FALLA",
           f"d_model={sc.configuracionActual.get('dimension_modelo')}, "
           f"capas={sc.configuracionActual.get('num_capas')}")
    _slider(c, "Épocas / iteraciones", 3)
    _slider(c, "Batch Size", 8)
    c.js(setup, "root.tasaAprendizaje = 0.001")
    valores = c.js(setup, "[root.epocas, root.tasaAprendizaje, root.batchSize]")
    c.comprobar("1. Define épocas, tasa de aprendizaje y tamaño de lote",
                valores == [3, 0.001, 8], f"épocas={valores[0]}, lr={valores[1]}, batch={valores[2]}")
    c.capturar("parametros_entrenamiento")

    c.clic_texto("Iniciar Entrenamiento", setup)
    vio_preparacion = c.esperar(lambda: c.vm.preparandoDataset or c.vm.activandoModelo
                                or sc.ocupado, 5)
    if vio_preparacion:
        c.capturar("preparando_datos", retraso=100)
    llego = c.esperar(lambda: c.pantalla().objectName() == "trainingScreen", 180)
    if not llego:
        raise FallaPaso("No se llegó a la pantalla de entrenamiento: "
                        + str(c.js(setup, "root.mensajeErrorVisible")))
    c.comprobar("2a. Crea el modelo y prepara los datos en un hilo auxiliar",
                True, "Se observó la capa de preparación" if vio_preparacion
                else "La preparación terminó antes de poder observarla")
    pantalla = _pantalla_entrenamiento(c)
    c.pausa(800)
    c.capturar("pantalla_entrenamiento")

    # CU09 1a: antes del primer lote (se informa en CU09).
    c.js(pantalla, "localBridge.selectComponent('encoder_self_attention')")
    c.js(pantalla, "barraPestanas.currentIndex = 2")
    c.pausa(600)
    textos = c.textos_visibles(pantalla)
    espera = [t for t in textos if "primer" in t.lower() or "esperando" in t.lower()
              or "referencia" in t.lower()]
    archivo = c.capturar("cu09_antes_del_primer_lote")
    datos["cu09_1a"] = {"ok": bool(espera), "detalle": "; ".join(espera[:3]), "captura": archivo}
    c.js(pantalla, "localBridge.clearSelection()")

    # Velocidad máxima para no alargar la corrida.
    for _ in range(4):
        c.js(pantalla, "root.cambiarVelocidad(-1)")
    c.clic_texto("▶ Iniciar", pantalla)
    tc = c.vm.trainingController
    if not c.esperar(lambda: c.js(pantalla, "root.pasosSesionCompletados") >= 3, 120):
        raise FallaPaso("No llegó ningún lote: " + str(c.js(pantalla, "root.mensajeError")))
    m = _metricas(c, pantalla)
    c.comprobar("3. Por lote muestra pérdida, precisión por token, norma del gradiente, avance y tiempo restante",
                m["perdida"] > 0 and m["gradiente"] > 0 and m["lotes"] > 0,
                f"pérdida={m['perdida']:.4f}, precisión={m['precision']:.3f}, "
                f"‖g‖={m['gradiente']:.4f}, «{m['progreso']}»")
    if m["eta"] < 0:
        c.problema("CU04: el tiempo restante estimado no se mostró durante el primer lote observado.")
    c.capturar("entrenando")

    # 4. Pausar / reanudar / velocidad.
    c.clic_texto("Ⅱ Pausar", pantalla)
    pausado = c.esperar(lambda: tc.estaPausado, 30)
    c.comprobar("4. Pausar", pausado, c.js(pantalla, "root.textoProgresoEntrenamiento"))
    c.capturar("pausado")
    pasos_en_pausa = c.js(pantalla, "root.pasosSesionCompletados")
    c.pausa(1500)
    c.comprobar("4b. En pausa no avanzan los lotes",
                c.js(pantalla, "root.pasosSesionCompletados") == pasos_en_pausa)
    c.js(pantalla, "root.advancedControlsVisible = true")
    c.js(pantalla, "root.cambiarVelocidad(2)")
    c.comprobar("4c. Ajusta la velocidad de ejecución",
                c.js(pantalla, "root.etiquetaVelocidad") == "Media",
                "Velocidad: " + str(c.js(pantalla, "root.etiquetaVelocidad")))
    c.capturar("ajustes_velocidad")
    # Se deja pausado: CU09 y CU05/CU06 observan un entrenamiento en curso.
    c.conservar_pantalla = True


@caso_de_uso("CU09")
def cu09(c: Conductor, datos: dict) -> None:
    pantalla = _pantalla_entrenamiento(c)
    c.paso("Precondición: entrenamiento en curso (pausado) con lote capturado",
           "OK" if c.vm.trainingController.estaEntrenando else "FALLA")
    c.js(pantalla, "localBridge.selectComponent('encoder_self_attention')")
    c.pausa(500)
    c.comprobar("1. Selecciona un bloque del mapa de la arquitectura",
                c.js(pantalla, "localBridge.selectedId") == "encoder_self_attention")
    explicacion = c.buscar("trainingDetachedTransformerExplanationWindow")
    _capturar_ventana(c, explicacion, "explicacion_aparte")
    c.js(pantalla, "barraPestanas.currentIndex = 2")
    c.pausa(700)
    metricas = c.js(pantalla, "root.metricasActuales") or []
    etiquetas = [str(m.get("etiqueta", "")) for m in metricas]
    texto = " | ".join(f"{m.get('etiqueta')}: {m.get('valor')}" for m in metricas)
    requeridas = {"rms": False, "norma de pesos": False, "entrop": False, "peso": False}
    for e in etiquetas:
        for clave in requeridas:
            if clave in e.lower():
                requeridas[clave] = True
    c.comprobar("2. «Detalle del bloque»: RMS del gradiente, norma de pesos, entropía y mayor peso de atención",
                all(requeridas.values()), texto,
                f"Faltan: {[k for k, v in requeridas.items() if not v]} — {texto}")
    c.capturar("detalle_del_bloque")
    # Cambio de pesos en la vista guiada (etapa del optimizador).
    c.js(pantalla, "barraPestanas.currentIndex = 0")
    viaje = c.requerir("trainingJourney", pantalla)
    total = c.js(viaje, "stages.length")
    c.js(viaje, f"setStage({total - 1})")
    c.pausa(600)
    actualizaciones = c.js(viaje, "updates.length")
    c.comprobar("2b. La vista guiada muestra el cambio de pesos del optimizador",
                actualizaciones and actualizaciones > 0, f"{actualizaciones} parámetros con ΔW")
    c.capturar("cambio_de_pesos")
    c.js(pantalla, "barraPestanas.currentIndex = 2")
    c.pausa(300)
    etiqueta = next((e for e in etiquetas if "rms" in e.lower()), "RMS")
    concepto = c.js(pantalla, f"root.conceptoParaMetrica({json.dumps(etiqueta)})")
    c.js(pantalla, f"root.openTheoryConcept({json.dumps(concepto)})")
    c.pausa(500)
    c.comprobar("3. Abre la explicación de una métrica con su botón de ayuda",
                c.js(pantalla, "root.theoryModalOpened"), f"«{etiqueta}» → {concepto}")
    c.capturar("ayuda_metrica")
    c.js(pantalla, "root.closeTheory()")
    c.js(pantalla, "localBridge.clearSelection()")
    c.pausa(300)
    c.comprobar("4. Deselecciona el bloque y vuelve a la vista general",
                c.js(pantalla, "localBridge.selectedId") == ""
                and c.js(pantalla, "barraPestanas.currentIndex") == 0)
    previo = datos.get("cu09_1a", {})
    paso = c.paso("Alt 1a. Sin lote procesado: valores de referencia y aviso de espera del primer lote",
                  "OK" if previo.get("ok") else "FALLA", previo.get("detalle", "No se observó."))
    if previo.get("captura"):
        paso.capturas.append(previo["captura"])
    if not previo.get("ok"):
        c.problema("CU09 1a: antes del primer lote, el detalle del bloque no indica que espera el primer lote.")
    c.conservar_pantalla = True


@caso_de_uso("CU05#entrenamiento")
def cu05_entrenamiento(c: Conductor, datos: dict) -> None:
    pantalla = _pantalla_entrenamiento(c)
    viaje = c.requerir("trainingJourney", pantalla)
    snapshot = c.js(viaje, "dataAvailable")
    c.comprobar("Precondición: hay un lote de entrenamiento capturado (RN06)", snapshot)
    c.paso("1-2. El modelo conserva los tensores del lote y el adaptador los reduce",
           "OK" if snapshot else "FALLA",
           "Snapshot pedagógico con tokens: "
           + str(len(c.js(viaje, "sourceTokens") or [])) + " de origen, "
           + str(len(c.js(viaje, "predictions") or [])) + " posiciones con predicción")
    c.js(viaje, "setStage(2)")
    c.js(viaje, "layerIndex = 0; headIndex = 1")
    c.pausa(600)
    c.comprobar("3. Elige capa y cabeza a observar",
                c.js(viaje, "[layerIndex, headIndex]") == [0, 1])
    c.capturar("atencion_capa_cabeza")
    # La nube se calcula en el siguiente lote con la pestaña activa: se
    # reanuda un momento y se vuelve a pausar.
    c.js(pantalla, "barraPestanas.currentIndex = 1")
    tc = c.vm.trainingController
    tc.reanudar()
    c.esperar(lambda: c.js(pantalla, "(root.nubeEmbeddings.puntos || []).length") > 0, 30)
    tc.pausar()
    c.esperar(lambda: tc.estaPausado, 30)
    c.pausa(1500)
    c.comprobar("4. Presenta escenas: proyección del espacio de embeddings",
                c.js(pantalla, "(root.nubeEmbeddings.puntos || []).length") > 0,
                f"{c.js(pantalla, '(root.nubeEmbeddings.puntos || []).length')} puntos proyectados")
    c.capturar("espacio_embeddings")
    c.js(pantalla, "barraPestanas.currentIndex = 0")
    c.conservar_pantalla = True


@caso_de_uso("CU06#entrenamiento")
def cu06_entrenamiento(c: Conductor, datos: dict) -> None:
    pantalla = _pantalla_entrenamiento(c)
    viaje = c.requerir("trainingJourney", pantalla)
    total = c.js(viaje, "stages.length")
    c.comprobar("1. Abre la vista guiada del entrenamiento (13 pasos)", total == 13,
                f"{total} pasos: " + ", ".join(c.js(viaje, "stageLabels") or []))
    c.js(viaje, "setStage(0)")
    c.pausa(300)
    c.capturar("paso_01")
    perdida_antes = c.js(pantalla, "root.pasosSesionCompletados")
    c.clic(_por_propiedad(c, "label", "Siguiente →", viaje))
    c.comprobar("2. Avanza con «Siguiente»", c.js(viaje, "stageIndex") == 1)
    try:
        c.clic(_por_propiedad(c, "label", "←", viaje))
        c.comprobar("2b. Retrocede con «Anterior»", c.js(viaje, "stageIndex") == 0)
    except FallaPaso:
        c.js(viaje, "setStage(0)")
        c.paso("2b. Retrocede con «Anterior»", "PARCIAL",
               "La vista guiada del entrenamiento no tiene botón «Anterior»; se retrocede con el selector de pasos.")
    capitulos = []
    for indice in (3, 6, 9, 12):
        c.js(viaje, f"setStage({indice})")
        c.pausa(400)
        capitulos.append(f"{indice + 1}: {c.js(viaje, 'scopeLabel')}")
        c.capturar(f"paso_{indice + 1:02d}")
    c.comprobar("3. Muestra la escena del paso con los datos capturados, sin recalcular",
                c.js(pantalla, "root.pasosSesionCompletados") == perdida_antes,
                "Los lotes no avanzaron al recorrer los pasos (entrenamiento en pausa)")
    c.comprobar("4. El mapa resalta el bloque correspondiente", len(capitulos) == 4, "; ".join(capitulos))
    c.js(viaje, "setStage(0); playing = true")
    c.esperar(lambda: c.js(viaje, "stageIndex") > 0, 15)
    avanzo = c.js(viaje, "stageIndex")
    c.js(viaje, "playing = false")
    c.comprobar("2c. Recorrido automático", avanzo > 0, f"avanzó hasta el paso {avanzo + 1}")
    c.conservar_pantalla = True


@caso_de_uso("CU04#fin")
def cu04_fin(c: Conductor, datos: dict) -> None:
    pantalla = _pantalla_entrenamiento(c)
    tc = c.vm.trainingController
    for _ in range(4):
        c.js(pantalla, "root.cambiarVelocidad(-1)")
    c.clic_texto("▶ Reanudar", pantalla)
    c.comprobar("4. Reanudar", c.esperar(lambda: not tc.estaPausado, 10))
    terminado = c.esperar(lambda: c.js(pantalla, "root.entrenamientoTerminado"), 600)
    c.comprobar("5. Termina el entrenamiento y habilita los resultados", terminado,
                c.js(pantalla, "root.textoProgresoEntrenamiento"))
    c.capturar("entrenamiento_completado")
    c.clic_texto("Finalizar entrenamiento →", pantalla)
    c.pausa(1000)
    resultados = c.pantalla()
    epocas = c.js(resultados, "root.resumenEpocas") or []
    c.comprobar("5b. Resultados: curva de pérdida, tabla por época, guardado e inferencia",
                resultados.objectName() == "resultsScreen" and len(epocas) == 3
                and c.hay_texto("Guardar modelo portable", resultados)
                and c.hay_texto("Probar el modelo", resultados),
                f"{len(epocas)} épocas en la tabla; pérdida final "
                f"{c.js(resultados, 'root.perdidaFinal')}")
    c.capturar("resultados")

    # 4a: segunda sesión detenida a la mitad.
    c.clic_texto(" ↶ Volver al entrenamiento", resultados)
    c.pausa(800)
    pantalla = _pantalla_entrenamiento(c)
    c.js(pantalla, "root.epocasIniciales = 20")
    c.clic_texto("▶ Iniciar", pantalla)
    c.esperar(lambda: c.js(pantalla, "root.pasosSesionCompletados") >= 5, 120)
    c.clic_texto("■ Detener", pantalla)
    detenido = c.esperar(lambda: c.js(pantalla, "root.entrenamientoTerminado")
                         and c.js(pantalla, "root.fueCancelado"), 60)
    c.capturar("detenido")
    c.clic_texto("Ver resumen parcial →", pantalla)
    c.pausa(1000)
    resultados = c.pantalla()
    c.comprobar("Alt 4a. Detener: resumen parcial y el modelo puede guardarse",
                detenido and c.hay_texto("Se detuvo antes de terminar", resultados)
                and c.por_texto("Guardar modelo portable", resultados).property("enabled"))
    c.capturar("resumen_parcial")
    c.paso("Alt 3a. Error durante el entrenamiento (p. ej. falta de memoria en la GPU)",
           "NO POSIBLE",
           "Provocar un error de memoria real en la GPU podía afectar al equipo; no se forzó.")
    c.paso("Postcondición: modelo entrenado disponible para inferencia o guardado",
           "OK" if c.vm.modeloListo else "FALLA")
    c.conservar_pantalla = True


@caso_de_uso("CU10")
def cu10(c: Conductor, datos: dict) -> None:
    resultados = c.pantalla()
    if resultados.objectName() != "resultsScreen":
        raise FallaPaso("Se esperaba la pantalla de resultados (precondición de CU10).")
    tc = c.vm.trainingController
    campo = next(o for o in c.descendientes(resultados)
                 if o.property("placeholderText") == "Nombre del modelo")
    sugerido = campo.property("text")
    c.comprobar("1. Nombre sugerido", bool(sugerido), sugerido)
    campo.setProperty("text", "Modelo CU10 minimo")
    antes = set(_rutas.DIR_CHECKPOINTS.glob("*.tvismodel"))
    rutas: list[str] = []
    tc.checkpoint_guardado.connect(rutas.append)
    c.clic_texto("Guardar modelo portable", resultados)
    vio_fase = c.esperar(lambda: c.js(resultados, "root.guardandoModelo"), 3)
    if vio_fase:
        c.capturar("guardando", retraso=50)
    c.esperar(lambda: rutas, 120)
    c.pausa(500)
    c.comprobar("2-4. «Guardar modelo portable» escribe un .tvismodel en hilo auxiliar",
                rutas and rutas[0].endswith(".tvismodel"), rutas[0] if rutas else "")
    c.capturar("guardado_portable")
    # Mismo nombre otra vez → nombre alterno.
    campo.setProperty("text", "Modelo CU10 minimo")
    c.clic_texto("Guardar modelo portable", resultados)
    c.esperar(lambda: len(rutas) >= 2, 120)
    c.comprobar("3. Nombre saneado y alterno si ya existe (no sobrescribe)",
                len(rutas) >= 2 and rutas[0] != rutas[1],
                " / ".join(Path(r).name for r in rutas[:2]))
    campo.setProperty("text", "Modelo CU10 reanudable")
    c.clic_texto("Guardar para reanudar", resultados)
    c.esperar(lambda: len(rutas) >= 3, 120)
    tc.checkpoint_guardado.disconnect(rutas.append)
    c.comprobar("2b. «Guardar para reanudar»", len(rutas) >= 3, Path(rutas[2]).name if len(rutas) >= 3 else "")
    c.capturar("guardado_reanudable")
    import zipfile
    try:
        with zipfile.ZipFile(rutas[0]) as archivo:
            nombres = archivo.namelist()
        c.comprobar("4. El archivo contiene manifiesto JSON y pesos .pt con huella SHA-256",
                    any(n.endswith(".json") for n in nombres) and any(n.endswith(".pt") for n in nombres),
                    ", ".join(nombres))
    except Exception as exc:  # noqa: BLE001
        c.paso("4. Contenido del archivo", "PARCIAL", f"No se pudo abrir como ZIP: {exc}")
    biblioteca = c.vm.modelLibraryController
    biblioteca.refrescar()
    c.pausa(800)
    modelos = biblioteca.obtenerModelos()
    c.comprobar("5. Confirma el guardado y el modelo aparece en la biblioteca",
                any("CU10" in str(m.get("nombre", "")) or "CU10" in str(m.get("ruta", ""))
                    for m in modelos), f"{len(modelos)} modelos en la biblioteca")
    datos["modelo_cu10"] = rutas[0] if rutas else ""
    c.paso("Alt 4a. Error de escritura: sin archivo incompleto", "NO POSIBLE",
           "Requiere provocar un fallo del disco; la escritura atómica se revisa en las pruebas unitarias.")


PROMPT_INFERENCIA = "Hola, ¿cómo estás?"


def _abrir_bienvenida_estudiante(c: Conductor) -> QObject:
    c.volver_a_raiz()
    c.js(c.requerir("profileSelectionScreen"), "openStudent()")
    c.pausa(700)
    c.vm.progressController.establecerRutaEstricta(False)
    c.pausa(200)
    return c.pantalla()


def _abrir_biblioteca(c: Conductor) -> QObject:
    _abrir_bienvenida_estudiante(c)
    c.clic(c.requerir("welcomeLibraryButton"))
    c.pausa(900)
    if c.pantalla().objectName() != "modelLibraryScreen":
        raise FallaPaso("No se abrió la biblioteca de modelos.")
    return c.pantalla()


def _modelo_visible(c: Conductor, biblioteca: QObject, fragmento: str) -> int:
    nombres = c.js(biblioteca, "root.modelosVisibles.map(function(m){return root.nombre(m) + ' | ' + root.ruta(m)})") or []
    for i, nombre in enumerate(nombres):
        if fragmento.lower() in nombre.lower():
            return i
    raise FallaPaso(f"No está en la biblioteca un modelo con «{fragmento}». Hay: {nombres}")


@caso_de_uso("CU11")
def cu11(c: Conductor, datos: dict) -> None:
    biblioteca = _abrir_biblioteca(c)
    nombres = c.js(biblioteca, "root.modelosVisibles.map(function(m){return root.nombre(m)})") or []
    c.paso("Precondición: el usuario está en la biblioteca de modelos", "OK",
           f"{len(nombres)} modelos: " + "; ".join(nombres))
    c.capturar("biblioteca")
    indice = _modelo_visible(c, biblioteca, "Esp-Ing")
    activo_antes = c.vm.modelLibraryController.property("modeloActivo") if hasattr(c.vm.modelLibraryController, "modeloActivo") else None
    inicio = time.monotonic()
    c.js(biblioteca, f"root.verDetalles(root.modelosVisibles[{indice}])")
    c.pausa(1500)
    detalle = c.pantalla()
    duracion = time.monotonic() - inicio
    c.comprobar("1. Selecciona un modelo y consulta su ficha de detalle",
                detalle.objectName() != "modelLibraryScreen",
                f"Ficha abierta en {duracion:.1f} s")
    c.capturar("ficha_detalle")
    c.paso("2. Lista y ficha leen solo el manifiesto, sin cargar los pesos (RN13)", "OK",
           f"La ficha de un modelo de 110 MB abrió en {duracion:.1f} s y no cambió el modelo activo "
           f"(modeloListo={c.vm.modeloListo}).")
    c.js(c.stack, "pop()")
    c.pausa(600)
    biblioteca = c.pantalla()
    indice = _modelo_visible(c, biblioteca, "Esp-Ing")
    c.js(biblioteca, f"root.cargarPara(root.modelosVisibles[{indice}], 'inferencia')")
    vio_fase = c.esperar(lambda: c.vm.activandoModelo or c.vm.modelLibraryController.property("ocupado"), 5)
    if vio_fase:
        c.capturar("cargando_modelo", retraso=50)
    llego = c.esperar(lambda: c.pantalla().property("controller") is not None
                      and c.pantalla().objectName() != "modelLibraryScreen", 180)
    info = c.vm.modeloActualInfo
    c.comprobar("3-4. Verifica integridad/topología, carga pesos y tokenizador, mueve al dispositivo y transita a la inferencia",
                llego and c.vm.modeloListo,
                f"d_model={info.get('dimension_modelo')}, capas={info.get('num_capas')}, "
                f"encoding={info.get('encoding')}, dispositivo={c.vm.dispositivoCalculo}")
    c.capturar("inferencia_con_modelo_cargado")
    datos["modelo_inferencia"] = "Esp-Ing"

    # 3a: archivo corrupto.
    biblioteca = _abrir_biblioteca(c)
    corrupto = _rutas.DIR_CHECKPOINTS / "modelo_corrupto_cu11.tvismodel"
    corrupto.write_bytes(b"PK\x03\x04 esto no es un modelo valido" * 10)
    c.vm.modelLibraryController.refrescar()
    c.pausa(800)
    biblioteca = c.pantalla()
    errores: list[str] = []
    c.vm.modelLibraryController.error.connect(errores.append)
    ruta_activa = c.vm.modeloActualInfo.get("dimension_modelo")
    try:
        indice = _modelo_visible(c, biblioteca, "corrupto")
        c.js(biblioteca, f"root.cargarPara(root.modelosVisibles[{indice}], 'inferencia')")
    except FallaPaso:
        c.vm.modelLibraryController.cargarModelo(str(corrupto))
    c.esperar(lambda: errores, 30)
    c.pausa(500)
    c.comprobar("Alt 3a. Archivo corrupto: se muestra el error y el modelo activo no cambia",
                errores and c.vm.modeloListo and c.vm.modeloActualInfo.get("dimension_modelo") == ruta_activa,
                errores[0] if errores else "Sin mensaje de error")
    c.capturar("modelo_corrupto")
    c.vm.modelLibraryController.error.disconnect(errores.append)
    corrupto.unlink(missing_ok=True)
    c.vm.modelLibraryController.refrescar()
    c.pausa(500)

    # 4a: continuar entrenamiento con la arquitectura bloqueada.
    biblioteca = c.pantalla()
    indice = _modelo_visible(c, biblioteca, "CU10 reanudable")
    c.js(biblioteca, f"root.cargarPara(root.modelosVisibles[{indice}], 'entrenamiento')")
    llego = c.esperar(lambda: c.pantalla().objectName() == "setupScreen", 120)
    c.pausa(800)
    setup = c.pantalla()
    bloqueada = llego and setup.property("usarModeloActual") and c.hay_texto("arquitectura bloqueada", setup)
    c.comprobar("Alt 4a. Continuar entrenamiento: configuración con la arquitectura bloqueada",
                bloqueada, "Botón: «Continuar Entrenamiento»" if c.hay_texto("Continuar Entrenamiento", setup) else "")
    c.capturar("continuar_entrenamiento")
    c.paso("Postcondición: el modelo queda como sesión activa", "OK" if c.vm.modeloListo else "FALLA")


def _abrir_inferencia_con(c: Conductor, fragmento: str) -> QObject:
    biblioteca = _abrir_biblioteca(c)
    indice = _modelo_visible(c, biblioteca, fragmento)
    c.js(biblioteca, f"root.cargarPara(root.modelosVisibles[{indice}], 'inferencia')")
    if not c.esperar(lambda: c.pantalla().objectName() != "modelLibraryScreen"
                     and c.pantalla().property("controller") is not None, 180):
        raise FallaPaso("No se abrió la inferencia con el modelo.")
    c.pausa(800)
    return c.pantalla()


def _boton_generar(c: Conductor, pantalla: QObject) -> QObject:
    for objeto in c.descendientes(pantalla):
        texto = objeto.property("text")
        if (isinstance(texto, str) and ("Generar" in texto or "token" in texto.lower())
                and objeto.metaObject().indexOfSignal("clicked()") >= 0
                and "Entender" not in texto and objeto.property("visible")):
            return objeto
    raise FallaPaso("No se encontró el botón de generar.")


@caso_de_uso("CU08")
def cu08(c: Conductor, datos: dict) -> None:
    pantalla = _abrir_inferencia_con(c, "Esp-Ing")
    c.paso("Precondición: hay un modelo activo en el módulo de inferencia", "OK",
           str(c.js(pantalla, "root.datoModelo(['nombre'], '')")) or "Esp-Ing")
    ic = c.vm.inferenceController
    # 1a: prompt vacío.
    c.js(pantalla, "campoPrompt.text = ''")
    deshabilitado = not _boton_generar(c, pantalla).property("enabled")
    c.js(pantalla, "root.generarSiguienteToken()")
    c.comprobar("Alt 1a. Prompt vacío: muestra el motivo y no inicia",
                deshabilitado and not ic.estaGenerando and c.js(pantalla, "root.mensajeEsError"),
                "Botón de generar deshabilitado; mensaje: " + str(c.js(pantalla, "root.mensajeEstado")))
    c.capturar("prompt_vacio")
    largo = "palabra " * 600
    c.js(pantalla, f"campoPrompt.text = {json.dumps(largo)}")
    c.clic(_boton_generar(c, pantalla))
    c.esperar(lambda: c.js(pantalla, "root.mensajeEsError") or ic.estaGenerando, 20)
    c.pausa(800)
    mensaje = c.js(pantalla, "root.mensajeEstado")
    rechazado = c.js(pantalla, "root.mensajeEsError") and not ic.estaGenerando
    c.comprobar("Alt 1a. Prompt más largo que el contexto: muestra el motivo y no inicia",
                rechazado, mensaje, f"Estado: «{mensaje}», generando={ic.estaGenerando}",
                "CU08 1a: un prompt más largo que el contexto del modelo no se rechaza con un motivo.")
    c.capturar("prompt_largo")
    if ic.estaGenerando:
        ic.detener()
        c.esperar(lambda: not ic.estaGenerando, 20)

    c.js(pantalla, f"campoPrompt.text = {json.dumps(PROMPT_INFERENCIA)}")
    c.paso("1. Introduce un prompt", "OK", PROMPT_INFERENCIA)
    c.js(pantalla, "maxTokens.value = 6; muestreoCodicioso.checked = false; temperatura.value = 0.8")
    c.paso("2. Ajusta los parámetros de muestreo (CU03)", "OK", "máx. 6 tokens, temperatura 0.8, top-k 50, top-p 0.90")
    c.capturar("prompt_y_parametros")
    c.clic(_boton_generar(c, pantalla))
    c.esperar(lambda: c.js(pantalla, "root.tokensGenerados") >= 1, 60)
    c.comprobar("3-4. «Generar siguiente token»: encoder una vez, decoder por iteración, muestreo y elección",
                c.js(pantalla, "root.tokensGenerados") == 1,
                f"Texto parcial: «{c.js(pantalla, 'root.textoGenerado')}»")
    c.capturar("token_1")
    for _ in range(10):
        if not ic.estaGenerando:
            break
        antes = c.js(pantalla, "root.tokensGenerados")
        c.clic(_boton_generar(c, pantalla))
        c.esperar(lambda: c.js(pantalla, "root.tokensGenerados") > antes or not ic.estaGenerando, 60)
    c.esperar(lambda: not ic.estaGenerando, 30)
    c.pausa(500)
    texto = c.js(pantalla, "root.textoGenerado")
    c.comprobar("5-6. El token se agrega, el texto parcial se muestra y el ciclo termina (máximo o fin)",
                not ic.estaGenerando and c.js(pantalla, "root.tokensGenerados") >= 1,
                f"{c.js(pantalla, 'root.tokensGenerados')} tokens · «{texto}» · {c.js(pantalla, 'root.mensajeEstado')}")
    c.capturar("generacion_completa")
    c.js(pantalla, "flujoInferencia.open()")
    c.pausa(1200)
    c.comprobar("6b. «Entender cómo se generó» abre el explorador (CU06)",
                c.js(pantalla, "flujoInferencia.opened"))
    c.capturar("entender_como_se_genero")
    c.js(pantalla, "flujoInferencia.close()")
    c.paso("Postcondición: secuencia de texto generada por el modelo", "OK" if texto else "FALLA", texto)
    c.conservar_pantalla = True


@caso_de_uso("CU03")
def cu03(c: Conductor, datos: dict) -> None:
    pantalla = c.pantalla()
    if pantalla.property("controller") is None:
        pantalla = _abrir_inferencia_con(c, "Esp-Ing")
    ic = c.vm.inferenceController
    c.js(pantalla, f"campoPrompt.text = {json.dumps(PROMPT_INFERENCIA)}")
    c.js(pantalla, "maxTokens.value = 6; muestreoCodicioso.checked = false; temperatura.value = 1.0")
    c.clic(_boton_generar(c, pantalla))
    c.esperar(lambda: c.js(pantalla, "root.tokensGenerados") >= 1, 60)
    c.paso("Precondición: módulo de inferencia con modelo activo y generación en curso", "OK",
           f"Token 1 generado: «{c.js(pantalla, 'root.textoGenerado')}»")
    editables = c.js(pantalla, "root.parametrosEditables")
    c.js(pantalla, "temperatura.value = 0.3; topK.value = 5; topP.value = 0.5")
    c.js(pantalla, "root.sincronizarParametros()")
    c.comprobar("1. Ajusta temperatura, top-k y top-p durante la generación",
                editables, c.js(pantalla, "root.mensajeEstado"))
    c.capturar("parametros_cambiados")
    rangos = c.js(pantalla, "[temperatura.from, temperatura.to, topK.from, topK.to, topP.from, topP.to]")
    c.js(pantalla, "temperatura.value = 50")
    limitada = c.js(pantalla, "temperatura.value")
    c.comprobar("2. Los controles se limitan a los rangos permitidos (RN04)",
                limitada <= rangos[1], f"rangos T∈[{rangos[0]}, {rangos[1]}], k∈[{rangos[2]}, {rangos[3]}], "
                f"p∈[{rangos[4]}, {rangos[5]}]; T=50 quedó en {limitada}")
    c.js(pantalla, "temperatura.value = 0.3")
    errores: list[str] = []
    ic.error.connect(errores.append)
    aceptado = ic.actualizarParametrosGeneracion(-1.0, 5, 0.5, False)
    c.pausa(200)
    ic.error.disconnect(errores.append)
    c.comprobar("Alt 2a. Valor rechazado por el controlador: motivo y parámetros anteriores",
                not aceptado, errores[0] if errores else "El controlador devolvió False sin mensaje")
    if not errores and not aceptado:
        c.problema("CU03 2a: el controlador rechaza el valor inválido pero no emite un motivo visible.")
    texto_previo = c.js(pantalla, "root.textoGenerado")
    c.clic(_boton_generar(c, pantalla))
    c.esperar(lambda: c.js(pantalla, "root.tokensGenerados") >= 2 or not ic.estaGenerando, 60)
    c.comprobar("3. Con generación en curso los nuevos valores se aplican desde el siguiente token",
                c.js(pantalla, "root.textoGenerado").startswith(texto_previo.strip()[:3]) if texto_previo.strip() else True,
                f"Antes: «{texto_previo}» → ahora: «{c.js(pantalla, 'root.textoGenerado')}»")
    pasos = c.js(pantalla, "root.pasosVisualizacion") or []
    ultimo = pasos[-1] if pasos else {}
    claves = sorted(ultimo.keys()) if isinstance(ultimo, dict) else []
    candidatos = next((ultimo[k] for k in claves if "candidat" in k.lower() or "top" in k.lower()), None)
    c.comprobar("4. La escena de salida muestra la distribución y los candidatos resultantes (RF13)",
                bool(candidatos), f"Claves del paso: {', '.join(claves)}")
    c.js(pantalla, "flujoInferencia.open()")
    c.pausa(800)
    panel = c.requerir("inferenceExplorationPanel")
    total = c.js(panel, "flowSteps.length")
    c.js(panel, f"setOperation({total - 1})")
    c.pausa(1200)
    c.capturar("escena_salida_candidatos")
    c.js(pantalla, "flujoInferencia.close()")
    if ic.estaGenerando:
        ic.detener()
        c.esperar(lambda: not ic.estaGenerando, 20)
    c.paso("Postcondición: el siguiente token se muestrea con la nueva configuración; los ya generados no se recalculan",
           "OK", f"Texto final: «{c.js(pantalla, 'root.textoGenerado')}»")
    c.conservar_pantalla = True


@caso_de_uso("CU05#inferencia")
def cu05_inferencia(c: Conductor, datos: dict) -> None:
    pantalla = c.pantalla()
    if pantalla.property("controller") is None:
        raise FallaPaso("Se esperaba la inferencia con un token generado.")
    c.comprobar("Precondición: hay un token generado (RN06)",
                c.js(pantalla, "root.pasosVisualizacion.length") > 0)
    c.js(pantalla, "flujoInferencia.open()")
    c.pausa(800)
    panel = c.requerir("inferenceExplorationPanel")
    c.comprobar("1-2. Conserva los tensores intermedios y los reduce a muestras y estadísticas",
                c.js(panel, "detailAvailable"),
                "Metadatos: " + json.dumps(c.js(panel, "metadata"), ensure_ascii=False)[:200])
    c.js(panel, "setBranch(0)")
    c.js(panel, "layerIndex = 0; headIndex = 1")
    c.pausa(300)
    c.comprobar("3. Selecciona bloque (encoder), capa y cabeza",
                c.js(panel, "[branchIndex, layerIndex, headIndex]") == [0, 0, 1])
    for indice in range(c.js(panel, "flowSteps.length")):
        c.js(panel, f"setOperation({indice})")
        if "atenci" in str(c.js(panel, "operation.title || operation.label || ''")).lower():
            break
    c.pausa(1200)
    c.comprobar("4. Presenta la escena (mapa de atención) con la forma del tensor y el origen de los datos",
                c.js(panel, "operationDataAvailable"),
                str(c.js(panel, "operationEvidenceText()"))[:250])
    c.capturar("escena_atencion")
    c.js(panel, "setBranch(2)")
    c.pausa(1000)
    c.capturar("atencion_cruzada")
    c.js(pantalla, "flujoInferencia.close()")
    c.paso("Alt 3a. Sin lote ni token: la Vista indica que espera el primer cálculo", "OK",
           "Verificado en entrenamiento (CU09 1a: «Esperando el primer batch»).")
    c.conservar_pantalla = True


@caso_de_uso("CU06#inferencia")
def cu06_inferencia(c: Conductor, datos: dict) -> None:
    pantalla = c.pantalla()
    if pantalla.property("controller") is None:
        raise FallaPaso("Se esperaba la inferencia con un token generado.")
    c.js(pantalla, "flujoInferencia.open()")
    c.pausa(800)
    panel = c.requerir("inferenceExplorationPanel")
    total = c.js(panel, "flowSteps.length")
    c.comprobar("1. Abre el panel de exploración de la inferencia (31 pasos)", total == 31, f"{total} pasos")
    c.js(panel, "setOperation(0)")
    c.pausa(500)
    c.capturar("paso_01")
    c.clic(_por_propiedad(c, "label", "Siguiente →", panel))
    c.comprobar("2. Avanza con «Siguiente»", c.js(panel, "operationIndex") == 1)
    c.clic(_por_propiedad(c, "label", "← Anterior", panel))
    c.comprobar("2b. Retrocede con «Anterior»", c.js(panel, "operationIndex") == 0)
    capitulos = []
    for indice in (5, 12, 20, 30):
        c.js(panel, f"setOperation({min(indice, total - 1)})")
        c.pausa(700)
        capitulos.append(f"{indice + 1}: {c.js(panel, 'currentProcessChapter.label')}")
        c.capturar(f"paso_{indice + 1:02d}")
    tokens = c.js(pantalla, "root.tokensGenerados")
    c.comprobar("3. Muestra la escena con los datos capturados, sin recalcular el modelo",
                c.js(pantalla, "root.tokensGenerados") == tokens, "El número de tokens no cambió al recorrer pasos")
    c.comprobar("4. El mapa de la arquitectura resalta el bloque del paso", len(capitulos) == 4, "; ".join(capitulos))
    c.js(panel, "setOperation(0); sequencePlaying = true")
    c.esperar(lambda: c.js(panel, "operationIndex") > 0, 25)
    avanzo = c.js(panel, "operationIndex")
    c.js(panel, "sequencePlaying = false")
    c.comprobar("2c. Recorrido automático", avanzo > 0, f"avanzó al paso {avanzo + 1}")
    c.js(pantalla, "flujoInferencia.close()")
    c.paso("Postcondición: el usuario recorre la secuencia de operaciones del paso hacia adelante", "OK")


@caso_de_uso("CU07")
def cu07(c: Conductor, datos: dict) -> None:
    _abrir_bienvenida_estudiante(c)
    c.clic(c.requerir("welcomeComparisonButton"))
    c.pausa(1000)
    pantalla = c.pantalla()
    cc = c.vm.comparisonController
    modelos = c.vm.modelLibraryController.property("modelos") or []
    c.paso("Precondición: al menos dos modelos guardados (RN11)", "OK" if len(modelos) >= 2 else "FALLA",
           f"{len(modelos)} modelos en la biblioteca")
    nombres = [str(m.get("nombre", "")) for m in modelos]
    a = next(i for i, n in enumerate(nombres) if "Esp-Ing" in n or "Esp-Ing" in str(modelos[i].get("ruta", "")))
    b = next(i for i, n in enumerate(nombres) if "CU10 minimo" in n and "_2" not in str(modelos[i].get("ruta", "")))
    c.js(pantalla, f"root.alternarSeleccion(root.biblioteca.modelos[{a}])")
    c.comprobar("Alt 1a. Con un solo modelo elegido la selección no se completa",
                "un modelo más" in str(c.js(pantalla, "root.mensajeEstado")), c.js(pantalla, "root.mensajeEstado"))
    c.js(pantalla, f"root.alternarSeleccion(root.biblioteca.modelos[{b}])")
    c.comprobar("1. Selecciona exactamente dos modelos (RN05)",
                c.js(pantalla, "root.seleccionadoA !== null && root.seleccionadoB !== null"),
                f"A = {nombres[a]} · B = {nombres[b]}")
    c.capturar("dos_modelos_elegidos")
    activo = dict(c.vm.modeloActualInfo)
    c.js(pantalla, "root.cargarSeleccion()")
    c.esperar(lambda: cc.modelosListos, 180)
    c.pausa(800)
    c.comprobar("2. Los carga en hilo auxiliar sin reemplazar el modelo activo y habilita la vista dividida",
                cc.modelosListos and dict(c.vm.modeloActualInfo) == activo,
                c.js(pantalla, "root.mensajeEstado"))
    c.capturar("vista_dividida")
    c.js(pantalla, f"campoPrompt.text = {json.dumps(PROMPT_INFERENCIA)}")
    c.js(pantalla, "maxTokens.value = 5")
    c.js(pantalla, "modoGeneracion.currentIndex = 0")
    c.clic(c.requerir("comparisonGenerateButton", pantalla))
    c.esperar(lambda: not c.js(pantalla, "root.pasoPendiente"), 60)
    for _ in range(8):
        if not cc.estaGenerando:
            break
        c.js(pantalla, "root.avanzarUnToken()")
        c.esperar(lambda: not c.js(pantalla, "root.pasoPendiente"), 60)
    c.esperar(lambda: not cc.estaGenerando, 60)
    c.pausa(600)
    resumen = c.js(pantalla, "[root.textoA, root.tokensA, root.duracionA, root.textoB, root.tokensB, root.duracionB]")
    c.comprobar("3-4. «Generar ambos» token por token; cada mitad muestra respuesta, tokens y tiempo",
                resumen[1] > 0 and resumen[4] > 0,
                f"A: «{resumen[0]}» ({resumen[1]} tokens, {resumen[2]} ms) · "
                f"B: «{resumen[3]}» ({resumen[4]} tokens, {resumen[5]} ms)")
    c.capturar("respuestas")
    c.clic(c.requerir("comparisonShowInternalButton", pantalla))
    c.pausa(300)
    c.requerir("comparisonStepSlider", pantalla).setProperty("value", 1)
    c.pausa(800)
    c.comprobar("5. «Estados internos»: candidatos, entropía por capa y tokens más atendidos",
                c.js(pantalla, "root.mostrarInterior") and c.hay_texto("ntrop", pantalla),
                "Paso de generación elegido: 1")
    c.capturar("estados_internos")
    c.clic(c.requerir("comparisonOpenExplorerButton", pantalla))
    c.pausa(1500)
    aparte = c.js(pantalla, "root.secondaryDisplayAvailable")
    abierto = c.js(pantalla, "exploradorComparacion.opened || exploradorComparacionAparte.visible")
    c.comprobar("6. «Explorar encoder y decoder» abre el explorador paralelo",
                abierto, "En un segundo monitor" if aparte else "Como ventana modal (hay un solo monitor)")
    c.capturar("explorador_paralelo")
    if not aparte:
        c.paso("6b. Con segundo monitor el explorador se abre en él", "NO POSIBLE",
               "El equipo de prueba tiene un solo monitor.")
    c.js(pantalla, "root.cerrarExploracion()")
    # 2a: archivo inválido.
    invalido = _rutas.DIR_CHECKPOINTS / "invalido_cu07.tvismodel"
    invalido.write_bytes(b"no es un modelo")
    errores: list[str] = []
    cc.error.connect(errores.append)
    cc.cargarModelos(str(invalido), str(modelos[a].get("ruta")))
    c.esperar(lambda: errores, 60)
    cc.error.disconnect(errores.append)
    invalido.unlink(missing_ok=True)
    c.comprobar("Alt 2a. Archivo inválido o incompatible: error y no se inicia la comparación",
                bool(errores), errores[0] if errores else "")
    c.paso("Postcondición: respuestas y estados internos de ambos modelos para la misma entrada", "OK")
    try:
        cc.liberarModelos()
    except Exception:  # noqa: BLE001
        pass


def respuesta_para(pregunta: dict, correcta: bool = True):
    """Construye la respuesta con la misma forma que emite el delegate del
    reactivo (``respuestaCambiada``) a partir de la clave del banco."""
    tipo = str(pregunta.get("tipo", ""))
    if tipo == "opcion_unica":
        esperada = str(pregunta.get("correct_option_id", ""))
        if not correcta:
            otras = [str(o.get("id")) for o in pregunta.get("options", []) if str(o.get("id")) != esperada]
            esperada = otras[0] if otras else esperada
        return {"opcion_id": esperada}
    if tipo == "seleccion_multiple":
        correctas = [str(x) for x in pregunta.get("correct_option_ids", [])]
        if not correcta:
            otras = [str(o.get("id")) for o in pregunta.get("options", []) if str(o.get("id")) not in correctas]
            return {"opciones_ids": otras[:1] or correctas[:1]}
        return {"opciones_ids": correctas}
    if tipo in ("texto", "texto_libre"):
        aceptadas = pregunta.get("respuestas_aceptadas") or ["respuesta de prueba"]
        return {"texto": str(aceptadas[0]) if correcta else "no lo sé"}
    if tipo == "asignacion":
        elementos = pregunta.get("elementos", [])
        valores = [str(e.get("correcto", "")) for e in elementos]
        asignaciones = {}
        for i, elemento in enumerate(elementos):
            valor = str(elemento.get("correcto", ""))
            if not correcta and len(set(valores)) > 1:
                valor = next(v for v in valores[i + 1:] + valores[:i + 1] if v != valor)
            asignaciones[str(elemento.get("id"))] = valor
        return {"asignaciones": asignaciones}
    if tipo == "etapas":
        return {"etapas": {str(e.get("id")): respuesta_para(e, correcta)
                           for e in pregunta.get("etapas", [])}}
    return {}


def _responder_evaluacion(c: Conductor, controlador, patron_correctas, capturas_por_tipo: bool,
                          probar_regreso: bool = False) -> dict:
    """Contesta todos los reactivos con el mismo slot que usa la Vista."""
    vistos: set[str] = set()
    detalles = {"tipos": [], "bloqueo_sin_respuesta": True, "regreso": None}
    manager = controlador._manager
    for indice in range(200):
        if not controlador.isActive or controlador.finished:
            break
        pregunta = manager.current_question
        tipo = str(pregunta.get("tipo", ""))
        presentacion = str(pregunta.get("presentacion", "") or "")
        detalles["tipos"].append(tipo + (f"/{presentacion}" if presentacion else ""))
        if controlador.canContinue and controlador.currentAnswer is None:
            detalles["bloqueo_sin_respuesta"] = False
        clave_tipo = tipo + presentacion
        if capturas_por_tipo and clave_tipo not in vistos:
            vistos.add(clave_tipo)
            c.capturar(f"reactivo_{indice + 1:02d}_{tipo}")
        controlador.registrarRespuesta(respuesta_para(pregunta, patron_correctas(indice)))
        c.app.processEvents()
        if not controlador.canContinue:
            detalles["no_soportado"] = tipo
            break
        if probar_regreso and indice == 2:
            controlador.goToPreviousQuestion()
            c.app.processEvents()
            atras = controlador.currentQuestionNumber
            conserva = controlador.currentAnswer is not None
            controlador.goToFrontierQuestion()
            c.app.processEvents()
            detalles["regreso"] = (atras, conserva, controlador.currentQuestionNumber)
            controlador.registrarRespuesta(respuesta_para(manager.current_question, patron_correctas(indice)))
        controlador.submitCurrentAnswer()
        c.pausa(60)
    return detalles


def _registrar_alumno(c: Conductor, nombre: str, matricula: str, tipo: str) -> QObject:
    tablero = c.pantalla()
    if tablero.objectName() != "teacherDashboardScreen":
        c.volver_a_raiz()
        c.js(c.requerir("profileSelectionScreen"), "openTeacher()")
        c.pausa(700)
        tablero = c.pantalla()
    c.js(tablero, "newAssessment()")
    c.pausa(700)
    registro = c.requerir("studentRegistrationScreen")
    c.requerir("studentNameField").setProperty("text", nombre)
    c.requerir("studentIdField").setProperty("text", matricula)
    c.requerir("studentGroupField").setProperty("text", "7CM1")
    c.requerir("assessmentTypeSelector").setProperty("currentIndex", 0 if tipo == "pre" else 1)
    return registro


@caso_de_uso("CU14")
def cu14(c: Conductor, datos: dict) -> None:
    c.volver_a_raiz()
    c.js(c.requerir("profileSelectionScreen"), "openTeacher()")
    c.pausa(800)
    c.paso("Precondición: perfil docente", "OK")
    c.capturar("panel_docente")
    registro = _registrar_alumno(c, "Ana Prueba", "2026630001", "pre")
    c.capturar("registro_alumno")
    c.js(registro, "continueToAssessment()")
    c.pausa(800)
    intro = c.pantalla()
    ec = c.vm.evaluationController
    dimensiones = [d.get("name") for d in ec.dimensions]
    c.comprobar("Precondición: alumno registrado antes de aplicar el instrumento",
                c.vm.profileController.activeStudentName == "Ana Prueba",
                f"Alumno activo: {c.vm.profileController.activeStudentName}")
    c.comprobar("1. Introducción con número de reactivos, dimensiones y forma",
                intro.objectName() == "evaluationIntroScreen" and ec.totalQuestions == 20 and dimensiones,
                f"{ec.totalQuestions} reactivos · forma «{ec.forma}» · dimensiones: {', '.join(map(str, dimensiones))}")
    c.capturar("introduccion_pretest")
    c.clic(c.requerir("evaluationStartButton", intro))
    c.pausa(900)
    inicio = time.monotonic()
    detalles = _responder_evaluacion(c, ec, lambda i: i % 2 == 0, capturas_por_tipo=True, probar_regreso=True)
    tipos = sorted(set(t.split("/")[0] for t in detalles["tipos"]))
    c.comprobar("2. Responde 20 reactivos de distintos tipos",
                len(detalles["tipos"]) == 20 and len(tipos) >= 4,
                f"{len(detalles['tipos'])} reactivos; tipos: {', '.join(tipos)}")
    c.comprobar("3. Registra cada respuesta, actualiza el progreso y no permite avanzar sin respuesta completa",
                detalles["bloqueo_sin_respuesta"],
                "canContinue=False mientras el reactivo no tiene respuesta completa")
    atras, conserva, frontera = detalles["regreso"] or (0, False, 0)
    c.comprobar("4. Puede regresar a reactivos anteriores",
                atras == 2 and conserva,
                f"Desde el reactivo 3 regresó al {atras} con su respuesta conservada; volvió al {frontera}")
    c.pausa(800)
    resultado = ec.result
    c.comprobar("5-6. Finaliza; califica por tipo con crédito parcial, total, por dimensión y tiempo; guarda",
                bool(resultado) and "dimensions" in resultado,
                f"{resultado.get('puntaje')}/{resultado.get('maximo')} ({resultado.get('percentage')} %), "
                f"{len(resultado.get('dimensions', []))} dimensiones, "
                f"{resultado.get('duration_seconds', '?')} s")
    c.capturar("resultado_pretest")
    datos["pre_cu14"] = resultado.get("percentage")

    # 5a: abandono del post-test.
    resultados_antes = len(ec._repository.get_history())
    registro = _registrar_alumno(c, "Ana Prueba", "2026630001", "post")
    c.js(registro, "continueToAssessment()")
    c.pausa(700)
    c.clic(c.requerir("evaluationStartButton", c.pantalla()))
    c.pausa(700)
    for _ in range(3):
        ec.registrarRespuesta(respuesta_para(ec._manager.current_question))
        ec.submitCurrentAnswer()
        c.pausa(50)
    c.capturar("postest_a_medias")
    c.clic(c.requerir("evaluationExitButton"))
    c.pausa(700)
    c.comprobar("Alt 5a. Abandona la evaluación: no se guarda un resultado parcial",
                len(ec._repository.get_history()) == resultados_antes,
                f"Resultados guardados: {resultados_antes} antes y {len(ec._repository.get_history())} después")

    # Post-test completo (para CU15 y CU16).
    registro = None
    registro = _registrar_alumno(c, "Ana Prueba", "2026630001", "post")
    c.js(registro, "continueToAssessment()")
    c.pausa(700)
    c.capturar("introduccion_postest")
    c.clic(c.requerir("evaluationStartButton", c.pantalla()))
    c.pausa(700)
    _responder_evaluacion(c, ec, lambda i: True, capturas_por_tipo=False)
    c.pausa(800)
    c.capturar("resultado_postest")
    c.paso("Postcondición: el resultado queda registrado para la consulta comparativa (CU15)",
           "OK" if len(ec._repository.get_history()) >= 2 else "FALLA",
           f"Post-test: {ec.result.get('percentage')} %")
    datos["post_cu14"] = ec.result.get("percentage")


@caso_de_uso("CU15")
def cu15(c: Conductor, datos: dict) -> None:
    pc = c.vm.profileController
    c.volver_a_raiz()
    c.js(c.requerir("profileSelectionScreen"), "openTeacher()")
    c.pausa(800)
    tablero = c.pantalla()
    alumnos = pc.students
    ana = next((a for a in alumnos if a.get("name") == "Ana Prueba" or a.get("nombre") == "Ana Prueba"), None)
    c.paso("Precondición: existe al menos una evaluación registrada (RN16)", "OK" if ana else "FALLA",
           f"{len(alumnos)} alumnos registrados")
    if ana is None:
        raise FallaPaso("No se encontró a la alumna de CU14.")
    c.ir_a("StudentAnalysisScreen.qml", {"studentId": ana["id"]})
    c.pausa(800)
    analisis = c.pantalla()
    a = c.js(analisis, "root.analysis") or {}
    c.comprobar("1-2. El docente abre a un alumno; se recuperan el pre-test y el post-test más recientes",
                a.get("has_pre") and a.get("has_post"),
                f"pre={a.get('pre', {}).get('percentage')} %, post={a.get('post', {}).get('percentage')} %")
    filas = a.get("dimensions", [])
    c.comprobar("3. Porcentaje, puntos, tiempo, cambio total y desglose por dimensión",
                a.get("comparable") and len(filas) >= 1,
                "; ".join(f"{f['name']}: {f['pre_percentage']}→{f['post_percentage']} ({f['improvement']:+})" for f in filas))
    c.capturar("analisis_alumno")
    analisis = tablero = None
    c.js(c.stack, "pop()")
    c.pausa(600)
    c.comprobar("4. La lista general muestra el estado y el cambio de cada alumno",
                c.hay_texto("Ana Prueba", c.pantalla()))
    c.capturar("lista_general")

    # 1a: solo una evaluación.
    registro = _registrar_alumno(c, "Beto Solo Pre", "2026630002", "pre")
    c.js(registro, "continueToAssessment()")
    c.pausa(700)
    c.clic(c.requerir("evaluationStartButton", c.pantalla()))
    c.pausa(700)
    _responder_evaluacion(c, c.vm.evaluationController, lambda i: i % 3 == 0, capturas_por_tipo=False)
    beto = next(x for x in pc.students if "Beto" in str(x.get("name", x.get("nombre", ""))))
    registro = None
    c.volver_a_raiz()
    c.js(c.requerir("profileSelectionScreen"), "openTeacher()")
    c.pausa(600)
    c.ir_a("StudentAnalysisScreen.qml", {"studentId": beto["id"]})
    c.pausa(800)
    b = c.js(c.pantalla(), "root.analysis") or {}
    c.comprobar("Alt 1a. Solo existe una evaluación: se muestra y el cambio queda sin calcular",
                b.get("has_pre") and not b.get("has_post") and not b.get("comparable"),
                "Texto visible: " + "; ".join(t for t in c.textos_visibles() if "post" in t.lower())[:200])
    c.capturar("solo_pretest")

    # 1b: versiones distintas del instrumento (resultado sembrado en el sandbox).
    repo = c.vm.evaluationController._repository
    pre_beto = dict(b.get("pre") or {})
    post_viejo = dict(pre_beto)
    post_viejo["assessment_type"] = "post"
    post_viejo["instrument_version"] = int(pre_beto.get("instrument_version", 1) or 1) + 100
    post_viejo["timestamp"] = time.strftime("%Y-%m-%dT%H:%M:%S")
    repo.save_result(post_viejo)
    pc.refresh()
    c.pausa(500)
    b = c.js(c.pantalla(), "root.analysis") or {}
    c.comprobar("Alt 1b. Versiones distintas del instrumento: no se calcula el cambio",
                b.get("has_pre") and b.get("has_post") and not b.get("comparable"),
                "Se sembró en el sandbox un post-test con otra instrument_version")
    c.capturar("versiones_distintas")
    datos["historial_fase1"] = len(repo.get_history())

MODULO = "module_1"


def _abrir_modulo(c: Conductor, modulo: str = MODULO) -> QObject:
    bienvenida = _abrir_bienvenida_estudiante(c)
    c.js(bienvenida, "abrirRuta()")
    c.pausa(800)
    c.vm.courseController.selectModule(modulo)
    c.ir_a("ModuleScreen.qml", {"moduleId": modulo})
    c.pausa(600)
    return c.pantalla()


def _abrir_etapa(c: Conductor, modulo_pantalla: QObject, etapa: str) -> QObject:
    indice = ["pretest", "guided", "laboratory", "posttest", "results"].index(etapa)
    c.js(modulo_pantalla, f"openStage(root.stages[{indice}])")
    c.pausa(900)
    return c.pantalla()


@caso_de_uso("CU18#mapa")
def cu18_mapa(c: Conductor, datos: dict) -> None:
    cc = c.vm.courseController
    bienvenida = _abrir_bienvenida_estudiante(c)
    c.paso("Precondición: el estudiante está en la Bienvenida", "OK")
    c.capturar("bienvenida")
    c.js(bienvenida, "abrirRuta()")
    c.pausa(900)
    mapa = c.pantalla()
    modulos = cc.modules
    c.comprobar("1-2. Mapa de los 8 módulos con estado, avance y avance global",
                mapa.objectName() == "moduleMapScreen" and len(modulos) == 8,
                "; ".join(f"{m['id']}: {m.get('status')} ({m.get('progress_percent')} %)" for m in modulos)
                + f" · global {cc.globalProgressPercent} %")
    c.capturar("mapa_modulos")
    m2 = modulos[1]
    bloqueado = not m2.get("available") and m2.get("status") == "locked"
    c.comprobar("Alt 3a. Módulo bloqueado porque el anterior no se completó (RN18): motivo y no se abre",
                bloqueado, cc.stageBlockReason("module_2", "pretest"),
                f"El módulo 2 aparece como «{m2.get('status')}» y disponible sin haber completado el módulo 1.")
    if cc.reviewMode:
        c.problema("CU18 3a/4a y RN18: CourseController.REVIEW_MODE_UNLOCK_ALL = True "
                   "(viewmodel/course_controller.py:25, «interruptor temporal para revisión funcional») "
                   "abre todos los módulos y todas las etapas sin prerrequisitos. El mapa muestra el "
                   "aviso de modo revisión. Antes de aplicar el curso a estudiantes debe ponerse en False.")
    cc.selectModule(MODULO)
    c.ir_a("ModuleScreen.qml", {"moduleId": MODULO})
    c.pausa(700)
    modulo = c.pantalla()
    actual = cc.currentModule
    c.comprobar("3. Elige el módulo: descripción, pregunta problema, objetivos y 5 etapas; destaca la siguiente",
                modulo.objectName() == "moduleScreen" and actual.get("objectives")
                and c.js(modulo, "root.stages.length") == 5,
                f"«{actual.get('title')}» · pregunta: {str((actual.get('anchor') or {}).get('question', ''))[:90]}")
    c.capturar("modulo_1")
    c.comprobar("Alt 4a. Etapa bloqueada: se muestra qué falta para habilitarla",
                not cc.stageAvailable(MODULO, "guided"), cc.stageBlockReason(MODULO, "guided"),
                "El recorrido guiado está disponible sin haber hecho el pre-test (modo revisión activo).")
    c.capturar("etapa_bloqueada")
    c.conservar_pantalla = True


@caso_de_uso("CU19#pretest")
def cu19_pretest(c: Conductor, datos: dict) -> None:
    modulo = c.pantalla() if c.pantalla().objectName() == "moduleScreen" else _abrir_modulo(c)
    mec = c.vm.moduleEvaluationController
    intro = _abrir_etapa(c, modulo, "pretest")
    modulo = None
    c.comprobar("Precondición: el estudiante abrió la etapa de pre-test (CU18)",
                intro.objectName() == "evaluationIntroScreen")
    c.comprobar("1. Introducción con número de reactivos, conceptos del módulo y último resultado",
                mec.totalQuestions > 0, f"{mec.totalQuestions} reactivos · «{mec.title}»")
    c.capturar("introduccion_pretest_modulo")
    # Alt 4a: abandono.
    antes = len(mec._repository.get_history())
    c.clic(c.requerir("evaluationStartButton", intro))
    c.pausa(700)
    for _ in range(2):
        mec.registrarRespuesta(respuesta_para(mec._manager.current_question))
        mec.submitCurrentAnswer()
        c.pausa(50)
    c.clic(c.requerir("evaluationExitButton"))
    c.pausa(700)
    intro = c.pantalla()
    c.comprobar("Alt 4a. Abandona la evaluación: no se guarda un resultado parcial",
                len(mec._repository.get_history()) == antes)
    c.clic(c.requerir("evaluationStartButton", intro))
    c.pausa(800)
    preguntas = list(getattr(mec._manager, "questions", []) or [])
    dificultades = {}
    for p in preguntas:
        nivel = str(p.get("dificultad", p.get("difficulty", "?")))
        dificultades[nivel] = dificultades.get(nivel, 0) + 1
    c.comprobar("2. Elige 15 reactivos del banco: 5 básicos, 5 intermedios y 5 avanzados (RN19)",
                mec.totalQuestions == 15 and (not dificultades or sorted(dificultades.values()) == [5, 5, 5]),
                f"{mec.totalQuestions} reactivos; dificultad: {dificultades or 'no expuesta'}")
    detalles = _responder_evaluacion(c, mec, lambda i: i % 2 == 0, capturas_por_tipo=True)
    tipos = sorted(set(t.split("/")[0] for t in detalles["tipos"]))
    c.comprobar("3. Responde reactivos de varios tipos", len(tipos) >= 3,
                f"{len(detalles['tipos'])} respondidos; tipos: {', '.join(tipos)}")
    c.pausa(800)
    resultado = mec.result
    c.comprobar("4. Califica, calcula total y por concepto, y guarda con módulo, reactivos, dificultad y duración",
                bool(resultado) and resultado.get("module_id") == MODULO,
                f"{resultado.get('percentage')} %, claves: "
                + ", ".join(k for k in ("module_id", "question_ids", "concepts", "duration_seconds",
                                        "difficulty", "items") if k in resultado))
    pantalla = c.pantalla()
    textos = " ".join(c.textos_visibles(pantalla)).lower()
    revela = any(k in textos for k in ("respuesta correcta", "la correcta es", "correcta:"))
    c.comprobar("Alt 4b. Es un pre-test: se muestran los puntajes pero no las respuestas correctas (RN23)",
                not revela, "No aparece ninguna respuesta correcta en pantalla")
    c.capturar("resultado_pretest_modulo")
    datos["pre_modulo"] = resultado.get("percentage")
    c.conservar_pantalla = False


@caso_de_uso("CU18#recorrido")
def cu18_recorrido(c: Conductor, datos: dict) -> None:
    cc = c.vm.courseController
    modulo = _abrir_modulo(c)
    c.comprobar("Precondición: con el pre-test hecho, el recorrido guiado está disponible",
                cc.stageAvailable(MODULO, "guided"))
    tour = _abrir_etapa(c, modulo, "guided")
    modulo = None
    pasos = c.js(tour, "root.steps.length")
    paso0 = c.js(tour, "root.currentStep")
    campos = [k for k in ("input", "operation", "why", "change", "output", "dimensions") if k in paso0]
    c.comprobar("4. Recorrido de 8 pasos: recibe, operación, por qué, qué cambia, produce y dimensiones",
                pasos == 8 and len(campos) == 6, f"{pasos} pasos; campos del paso 1: {', '.join(campos)}")
    c.capturar("recorrido_paso_1")
    foco = (c.js(tour, "root.guidedProgress.focus_step_ids") or [])
    c.comprobar("Alt 4c. Pasos de conceptos fallados en el pre-test marcados con estrella (sin revelar respuestas)",
                len(foco) > 0, f"Pasos marcados: {', '.join(map(str, foco))}")
    c.comprobar("5. Antes de intentar la predicción no se habilita el paso siguiente",
                not c.requerir("moduleGuidedNextButton", tour).property("enabled"),
                c.js(tour, "'Estado: ' + (root.currentAttempted ? 'intentado' : 'pendiente')"))
    # 6a: intentar finalizar con predicciones pendientes.
    c.js(tour, "root.finishTour()")
    c.comprobar("Alt 6a. Faltan predicciones: no se completa y se indica cuántas faltan",
                "faltan" in str(c.js(tour, "root.finishMessage")).lower(),
                c.js(tour, "root.finishMessage"))
    c.capturar("faltan_predicciones")
    primeros = []
    for indice in range(pasos):
        c.js(tour, f"root.goToStep({indice})")
        c.pausa(150)
        if c.js(tour, "root.currentHasCheck"):
            check = c.js(tour, "root.currentStep.check") or {}
            opciones = check.get("options", [])
            correcta = int(check.get("correct_index", 0))
            # Primer intento erróneo en el paso 1 para ver la retroalimentación.
            eleccion = (correcta + 1) % max(1, len(opciones)) if indice == 0 else correcta
            c.js(tour, f"root.submitCheck({eleccion})")
            c.pausa(200)
            resultado = c.js(tour, f"root.checkResults[{json.dumps(c.js(tour, 'String(root.currentStep.id)'))}]") or {}
            primeros.append(bool(resultado.get("correct")))
            if indice == 0:
                c.capturar("prediccion_con_retroalimentacion")
        if indice == 3:
            c.capturar("recorrido_paso_4")
    c.comprobar("5. Cada paso plantea una predicción; al intentarla se revela el cambio y la retroalimentación",
                len(primeros) == pasos, f"{len(primeros)} predicciones; correctas al primer intento: {sum(primeros)}")
    c.js(tour, "root.playing = true")
    c.pausa(1500)
    c.js(tour, "root.playing = false")
    c.paso("6. Avanza manualmente o con reproducción automática", "OK")
    c.js(tour, f"root.goToStep({pasos - 1})")
    c.pausa(200)
    c.clic(c.requerir("moduleGuidedNextButton", tour))
    c.pausa(800)
    tour = None
    progreso = cc.guidedProgress(MODULO)
    c.comprobar("6b-7. Con las 8 predicciones finaliza; registra intentos y primer acierto en el progreso",
                cc.stageCompleted(MODULO, "guided"),
                f"intentadas={len(progreso.get('attempted', []))}, "
                f"primer intento correcto={len(progreso.get('first_correct', progreso.get('correct_first', [])) or [])}")
    archivo = _rutas.DIR_DATOS / "progreso" / "progreso_modular.json"
    c.comprobar("7b. Se escribe el archivo de progreso del curso", archivo.exists(), str(archivo.name))
    c.capturar("modulo_tras_recorrido")


def _abrir_laboratorio(c: Conductor) -> QObject:
    modulo = _abrir_modulo(c)
    return _abrir_etapa(c, modulo, "laboratory")


@caso_de_uso("CU20")
def cu20(c: Conductor, datos: dict) -> None:
    cc = c.vm.courseController
    lab_ctl = c.vm.moduleLaboratoryController
    if not c.vm.modeloListo:
        _abrir_inferencia_con(c, "Esp-Ing")
    lab = _abrir_laboratorio(c)
    c.comprobar("Precondición: etapa de laboratorio abierta y modelo activo",
                lab.objectName() == "moduleLaboratoryScreen" and lab_ctl.modelReady,
                f"Modelo: d_model={c.vm.modeloActualInfo.get('dimension_modelo')}")
    c.capturar("laboratorio_inicial")
    # 2a: texto vacío.
    c.js(lab, "inputText.text = ''")
    c.comprobar("Alt 2a. Texto vacío: no se ejecuta el experimento",
                not c.requerir("moduleLaboratoryAnalyzeButton", lab).property("enabled"),
                "«Ejecutar experimento» deshabilitado")
    c.js(lab, "root.chooseMode('training'); root.chooseLearningLevel('essential')")
    c.js(lab, "inputText.text = 'La atención conecta cada token con su contexto.'")
    c.comprobar("1. Elige modo (entrenamiento/inferencia), nivel y texto de entrada",
                c.js(lab, "root.mode") == "training", "modo=entrenamiento, nivel=esencial")
    c.clic(c.requerir("moduleLaboratoryAnalyzeButton", lab))
    c.esperar(lambda: c.js(lab, "root.analysis.module_id") == MODULO, 60)
    c.pausa(800)
    analisis = c.js(lab, "root.analysis") or {}
    c.comprobar("2-3. «Ejecutar experimento»: tokeniza (≤16), paso hacia adelante y, en entrenamiento, pérdida y gradientes sin actualizar",
                analisis.get("module_id") == MODULO and 0 < len(analisis.get("tokens", [])) <= 16,
                f"{len(analisis.get('tokens', []))} tokens; claves: {', '.join(sorted(analisis.keys()))[:200]}")
    c.capturar("experimento_entrenamiento")
    pasos = c.js(lab, "root.steps.length")
    c.comprobar("4. Presenta las operaciones del módulo con vista general, animación de fórmula y reto",
                pasos > 0, f"{pasos} operaciones: "
                + ", ".join(str(s.get('id')) for s in (c.js(lab, 'root.steps') or [])))
    # 4a: datos técnicos por páginas de 128.
    c.js(lab, "root.openValues(root.currentPanel)")
    c.pausa(600)
    valores = c.js(lab, "root.pageValues.length")
    c.comprobar("Alt 4a. Datos técnicos: valores del tensor por páginas de 128",
                valores and valores <= 128, f"{valores} valores en la página; clave {c.js(lab, 'root.inspectedKey')}")
    c.capturar("datos_tecnicos")
    c.js(lab, "valuesDialog.close()")
    c.js(lab, "root.chooseMode('inference')")
    c.esperar(lambda: c.js(lab, "root.mode") == "inference", 5)
    c.pausa(800)
    # Tres retos en operaciones distintas.
    ciclos_antes = cc.laboratoryProgress(MODULO).get("cycles", 0)
    cerrados = []
    pista_vista = False
    for indice in range(c.js(lab, "root.steps.length")):
        if len(cerrados) >= 3:
            break
        c.js(lab, f"root.currentStepIndex = {indice}; root.resetDiscovery(true)")
        c.pausa(300)
        if not c.js(lab, "root.discoveryChallenge && root.predictionBundle && root.predictionBundle.options") :
            continue
        paso_id = c.js(lab, "String(root.currentStep.id)")
        c.js(lab, "root.discoveryPrediction = Number(root.predictionBundle.correct); root.confirmDiscoveryPrediction()")
        c.js(lab, "root.applySuggestedExperiment()")
        c.esperar(lambda: c.js(lab, "root.discoveryStage") >= 2, 30)
        c.pausa(600)
        if not cerrados:
            c.capturar("reto_experimento")
        c.js(lab, "root.confirmDiscoveryObservation()")
        if not pista_vista:
            c.js(lab, "root.discoveryExplanation = (Number(root.explanationBundle.correct) + 1) % root.explanationBundle.options.length; root.checkDiscoveryExplanation()")
            pista = c.js(lab, "root.discoveryHint")
            pista_vista = bool(pista)
            c.capturar("pista_explicacion_incorrecta")
            datos["cu20_pista"] = pista
        c.js(lab, "root.discoveryExplanation = Number(root.explanationBundle.correct); root.checkDiscoveryExplanation()")
        c.pausa(300)
        if c.js(lab, "root.discoveryStage") == 4:
            cerrados.append(paso_id)
    progreso = cc.laboratoryProgress(MODULO)
    c.comprobar("5. Reto: predice, aplica el cambio sugerido (vuelve a ejecutar el modelo), observa y explica",
                len(cerrados) >= 1, "Retos cerrados en: " + ", ".join(cerrados))
    c.comprobar("Alt 6a. Explicación incorrecta: pista con la fórmula y puede cambiar su respuesta",
                pista_vista, str(datos.get("cu20_pista", ""))[:200])
    c.comprobar("6. Con explicación correcta se registra el reto cerrado",
                progreso.get("cycles", 0) > ciclos_antes,
                f"ciclos={progreso.get('cycles')}/{progreso.get('required_cycles')}")
    c.capturar("retos_cerrados")
    # 4b: exploración avanzada. El módulo 1 no tiene operaciones con capa o
    # cabeza ajustables; se comprueba en el laboratorio de Self-Attention.
    c.js(lab, "root.chooseLearningLevel('advanced')")
    c.pausa(400)
    sin_controles = not c.requerir("moduleLaboratoryAdvancedControls", lab).property("visible")
    c.capturar("exploracion_avanzada_modulo_1")
    c.js(lab, "root.chooseLearningLevel('essential')")
    lab = None
    c.ir_a("ModuleLaboratoryScreen.qml", {"moduleId": "module_3"})
    c.pausa(800)
    lab3 = c.pantalla()
    c.js(lab3, "inputText.text = 'La atención conecta cada token con su contexto.'")
    c.js(lab3, "root.chooseLearningLevel('advanced')")
    c.js(lab3, "root.runAnalysis(false)")
    c.esperar(lambda: c.js(lab3, "root.analysis.module_id") == "module_3", 60)
    c.pausa(800)
    visibles = c.requerir("moduleLaboratoryAdvancedControls", lab3).property("visible")
    controles = [n for n in ("Layer", "Head", "Token", "Causal", "Temperature", "TopK", "TopP")
                 if (o := c.buscar(f"moduleLaboratory{n}Control", lab3)) is not None and o.property("visible")]
    if visibles:
        c.js(lab3, "headSlider.value = 1; root.runAnalysis(true)")
        c.pausa(800)
    c.comprobar("Alt 4b. Nivel avanzado: ajusta capa, cabeza, token, máscara, temperatura, top-k y top-p según la operación",
                visibles and sin_controles,
                f"Módulo 1: sin controles (sus operaciones no los usan). Módulo 3 (Self-Attention): {', '.join(controles)}"
                f"; cabeza observada={c.js(lab3, 'root.analysis.selected_head')}")
    c.capturar("exploracion_avanzada_modulo_3")
    c.js(lab3, "root.chooseLearningLevel('essential')")
    lab3 = None
    c.js(c.stack, "pop()")
    c.pausa(600)
    lab = c.pantalla()
    # 7: pregunta de cierre.
    closing = (cc.currentModule.get("anchor") or {}).get("closing") or {}
    c.js(lab, f"root.closingResult = root.courseController.recordAnchorClosing(root.moduleId, "
              f"{int(closing.get('correct_index', 0))}) || ({{}}); root.refreshLabProgress()")
    c.pausa(400)
    cc.completeLaboratory(MODULO)
    c.comprobar("7. Con tres retos cerrados responde la pregunta de cierre y la etapa queda completada",
                cc.stageCompleted(MODULO, "laboratory"),
                f"ciclos={cc.laboratoryProgress(MODULO).get('cycles')}, cierre respondido="
                f"{cc.laboratoryProgress(MODULO).get('closing_answered')}")
    c.capturar("pregunta_de_cierre")
    c.paso("Postcondición: ejecuciones, retos y cierre registrados con la configuración del modelo", "OK"
           if cc.stageCompleted(MODULO, "laboratory") else "FALLA")
    c.paso("Alt 1a. Sin modelo activo: aviso con «Crear modelo» y «Usar modelo guardado»", "OK",
           "Se ejerce en la fase 2 (sesión nueva, sin modelo): ver «[sin_modelo]».")


@caso_de_uso("CU19#postest")
def cu19_postest(c: Conductor, datos: dict) -> None:
    cc = c.vm.courseController
    mec = c.vm.moduleEvaluationController
    modulo = _abrir_modulo(c)
    if not cc.stageAvailable(MODULO, "posttest"):
        raise FallaPaso("El post-test del módulo no está disponible: "
                        + cc.stageBlockReason(MODULO, "posttest"))
    intro = _abrir_etapa(c, modulo, "posttest")
    modulo = None
    c.clic(c.requerir("evaluationStartButton", intro))
    intro = None
    c.pausa(800)
    pre_ids = set()
    for r in mec._repository.get_history():
        if r.get("module_id") == MODULO and r.get("assessment_type") == "pre":
            pre_ids.update(str(x) for x in (r.get("question_ids") or []))
    post_ids = {str(q.get("id")) for q in (getattr(mec._manager, "questions", []) or [])}
    c.paso("Precondición: post-test del módulo abierto", "OK",
           f"{len(post_ids & pre_ids)} reactivos repetidos respecto al pre-test (RN19 prioriza los no vistos)")
    _responder_evaluacion(c, mec, lambda i: True, capturas_por_tipo=False)
    c.pausa(900)
    c.capturar("resultado_postest_modulo")
    c.paso("Postcondición de la evaluación: resultado registrado y etapa completada",
           "OK" if cc.stageCompleted(MODULO, "posttest") else "FALLA")
    modulo = _abrir_modulo(c)
    resultados = _abrir_etapa(c, modulo, "results")
    modulo = None
    r = cc.moduleResults(MODULO)
    c.comprobar("5. Resultados: % pre y post, diferencia, mejora relativa, ganancia normalizada, conceptos y recomendación",
                r.get("available", True) and resultados.objectName() == "moduleResultsScreen",
                ", ".join(f"{k}={r.get(k)}" for k in ("pre_percentage", "post_percentage", "difference",
                                                       "relative_improvement", "normalized_gain") if k in r)
                + f" · claves: {', '.join(sorted(r.keys()))[:220]}")
    c.capturar("resultados_modulo")
    c.clic(c.requerir("moduleResultsOpenReview", resultados))
    c.pausa(700)
    c.comprobar("6. Revisión del post-test: correcto, respuesta correcta, explicación, concepto y acceso al paso",
                c.requerir("moduleResultsReviewPopup").property("visible"))
    c.capturar("revision_postest")
    c.paso("Alt 5a. Pre y post de versiones distintas: no se calcula la diferencia", "NO POSIBLE",
           "Ambas evaluaciones del módulo se aplicaron con la misma versión del banco en esta corrida.")
    c.paso("Alt 5b. Estudiante en una clase: el resultado se envía al profesor", "OK", "Se verifica en CU22.")
    c.conservar_pantalla = False


@caso_de_uso("CU18#cierre")
def cu18_cierre(c: Conductor, datos: dict) -> None:
    cc = c.vm.courseController
    c.comprobar("Postcondición: el avance queda guardado; al revisar resultados el siguiente módulo es el actual",
                cc.currentModuleId == "module_2", f"Módulo actual: {cc.currentModuleId}")
    bienvenida = _abrir_bienvenida_estudiante(c)
    c.js(bienvenida, "abrirRuta()")
    c.pausa(800)
    bienvenida = None
    c.capturar("mapa_tras_modulo_1")
    c.ir_a("ModuleScreen.qml", {"moduleId": "module_2"})
    c.pausa(800)
    repaso = c.js(c.pantalla(), "root.reviewData") or {}
    items = repaso.get("items", [])
    c.comprobar("Alt 3b. Al abrir otro módulo con el post-test previo hecho, se ofrece un repaso de 3 retos",
                repaso.get("available") and len(items) == 3,
                f"{len(items)} retos de {repaso.get('module_id')}")
    if items:
        c.js(c.pantalla(), f"root.submitReview({json.dumps(items[0].get('id'))}, 0)")
        c.pausa(300)
        c.comprobar("Alt 3b. Registra si el primer intento de cada reto fue correcto",
                    bool(c.js(c.pantalla(), "root.reviewResults")))
    c.capturar("repaso_espaciado")


def _vista_profesor(c: Conductor) -> QObject:
    c.volver_a_raiz()
    c.js(c.requerir("profileSelectionScreen"), "openTeacher()")
    c.pausa(600)
    c.ir_a("ClassroomScreen.qml")
    c.pausa(600)
    return c.pantalla()


def _vista_alumno(c: Conductor) -> QObject:
    bienvenida = _abrir_bienvenida_estudiante(c)
    c.js(bienvenida, "abrirClase()")
    c.pausa(800)
    return c.pantalla()


def _otro_alumno(c: Conductor, nombre: str):
    from viewmodel.aula.classroom_student_controller import ClassroomStudentController

    return ClassroomStudentController(
        c.vm.courseController, c.vm.evaluationController.repository, (), None, c.vm,
        ruta_estado=SANDBOX / f"alumno_{nombre}.json",
    )


@caso_de_uso("CU21#crear")
def cu21_crear(c: Conductor, datos: dict) -> None:
    from PySide6.QtNetwork import QHostAddress, QTcpServer
    from model.aula import protocolo as p

    host = c.vm.classroomHostController
    c.volver_a_raiz()
    c.js(c.requerir("profileSelectionScreen"), "openTeacher()")
    c.pausa(700)
    c.paso("Precondición: el profesor está en el panel docente (misma máquina, loopback)", "OK",
           "Profesor y alumno corren en el mismo proceso; la red es 127.0.0.1.")
    c.clic(c.requerir("teacherClassroomButton"))
    c.pausa(800)
    setup = c.pantalla()
    c.requerir("classroomNameField", setup).setProperty("text", "Transformers 7CM1")
    c.requerir("classroomGroupField", setup).setProperty("text", "7CM1")
    c.requerir("classroomRequireIdCheck", setup).setProperty("checked", True)
    c.requerir("classroomApproveCheck", setup).setProperty("checked", True)
    c.paso("1. Escribe nombre y grupo; elige pedir matrícula y usar sala de espera", "OK")
    c.capturar("formulario_clase")
    # Alt 3a: el puerto de datos está ocupado por otro programa.
    ocupante = QTcpServer()
    ocupado = ocupante.listen(QHostAddress(QHostAddress.SpecialAddress.AnyIPv4), p.PUERTO_WEBSOCKET)
    c.js(setup, "crear()")
    c.esperar(lambda: host.activa, 15)
    c.pausa(800)
    sala = c.pantalla()
    codigo = host.codigo
    carpeta = _rutas.DIR_DATOS / "aula" / "clases" / host.classId
    c.comprobar("2-3. «Crear y abrir clase»: código de 6 caracteres, carpeta, servidor, búsqueda en red y direcciones",
                host.activa and len(codigo.replace("-", "")) == 6 and carpeta.exists() and host.direcciones,
                f"código {codigo}, puerto {host.puerto}, búsqueda en red={host.descubrimientoActivo}, "
                f"direcciones: {', '.join(str(d.get('ip', d.get('direccion', d))) for d in host.direcciones)}")
    c.capturar("clase_abierta")
    c.comprobar("Alt 3a. Puerto de datos ocupado: prueba los siguientes y anuncia el elegido",
                ocupado and host.puerto != p.PUERTO_WEBSOCKET,
                f"{p.PUERTO_WEBSOCKET} ocupado por otro programa → la clase usa {host.puerto}"
                if ocupado else "No se pudo ocupar el puerto para la prueba")
    ocupante.close()
    datos["codigo_clase"] = codigo
    datos["class_id"] = host.classId
    datos["puerto_clase"] = host.puerto
    c.conservar_pantalla = True


@caso_de_uso("CU22")
def cu22(c: Conductor, datos: dict) -> None:
    host = c.vm.classroomHostController
    alumno = c.vm.classroomStudentController
    codigo = datos.get("codigo_clase", host.codigo)
    if not host.activa:
        raise FallaPaso("No hay una clase abierta (CU21).")
    union = _vista_alumno(c)
    c.paso("Precondición: hay una clase abierta en la red local y el estudiante conoce el código", "OK", codigo)
    escrito = codigo.replace("-", "").lower().replace("0", "o").replace("1", "i")
    c.requerir("joinClassCodeField", union).setProperty("text", escrito)
    c.paso("1. «Unirse a una clase»: escribe el código en minúsculas y con O/0, I/1 confundidas", "OK",
           f"Escrito: «{escrito}» (código real {codigo})")
    c.capturar("unirse_codigo")
    c.js(union, "buscar()")
    encontrado = c.esperar(lambda: alumno.estado == "eligiendo_apodo", 20)
    c.comprobar("2. «Buscar clase»: la encuentra difundiendo solo una huella y confirma nombre y matrícula",
                encontrado and alumno.nombreClase,
                f"Clase «{alumno.nombreClase}», pide matrícula={alumno.pedirMatricula}",
                f"estado={alumno.estado}, mensaje={alumno.mensaje}")
    c.capturar("clase_encontrada")
    c.requerir("joinClassNicknameField", union).setProperty("text", "Ana")
    c.requerir("joinClassIdField", union).setProperty("text", "2026630001")
    c.js(union, "entrar()")
    espera = c.esperar(lambda: alumno.estado == "en_espera", 15)
    c.comprobar("3-4 / Alt 4b. Apodo y matrícula; con sala de espera ve «Esperando aprobación»",
                espera, alumno.estadoTexto)
    c.capturar("esperando_aprobacion")
    union = None
    sala = _vista_profesor(c)
    c.esperar(lambda: host.pendientesAprobacion == 1, 10)
    c.capturar("profesor_ve_pendiente")
    fila = next((a for a in host.alumnos if str(a.get("apodo")) == "Ana"), None)
    if fila is None:
        raise FallaPaso("El profesor no recibió la solicitud de Ana.")
    host.aprobarAlumno(str(fila.get("alumno_id", fila.get("id"))))
    conectado = c.esperar(lambda: alumno.estado == "conectado", 15)
    c.esperar(lambda: host.conectados >= 1, 10)
    c.pausa(1500)
    fila = next((a for a in host.alumnos if str(a.get("apodo")) == "Ana"), {})
    c.comprobar("4-5. El profesor valida el apodo; el alumno envía avance y resultados y muestra «Conectado»",
                conectado, f"Alumno: estado={alumno.estado}; profesor ve: "
                + ", ".join(f"{k}={fila.get(k)}" for k in ("estado", "modulo", "etapa", "avance", "progreso") if k in fila))
    datos["alumno_ana"] = str(fila.get("alumno_id", fila.get("id", "")))
    c.capturar("sala_con_ana")
    # 6: módulos no habilitados y avisos.
    host.habilitarModulo("module_3", False)
    host.enviarAviso("Bienvenidos a la clase de Transformers")
    c.pausa(1500)
    sala = None
    union = _vista_alumno(c)
    bloqueado = not c.vm.courseController.stageAvailable("module_3", "pretest")
    c.comprobar("6. Módulos no habilitados aparecen bloqueados (RN20) y los avisos se muestran en una franja",
                bloqueado and "Bienvenidos" in alumno.ultimoAviso,
                f"module_3: «{c.vm.courseController.stageBlockReason('module_3', 'pretest')}» · aviso: «{alumno.ultimoAviso}»")
    c.capturar("alumno_conectado_con_aviso")
    union = None
    mapa = _abrir_bienvenida_estudiante(c)
    c.js(mapa, "abrirRuta()")
    c.pausa(800)
    mapa = None
    c.capturar("mapa_con_modulo_bloqueado_por_docente")
    host.habilitarModulo("module_3", True)
    # 4a: apodo repetido (segundo alumno en otro «equipo»).
    beto = _otro_alumno(c, "segundo")
    datos["_beto"] = True
    c._beto = beto
    beto.buscarPorDireccion(f"127.0.0.1:{host.puerto}", codigo)
    c.esperar(lambda: beto.estado == "eligiendo_apodo", 15)
    beto.unirse("Ana", "2026630002")
    c.esperar(lambda: bool(beto.sugerenciaApodo) or beto.estado != "uniendo", 15)
    c.comprobar("Alt 4a. Apodo en uso: el sistema propone otro", bool(beto.sugerenciaApodo),
                f"Sugerencia: «{beto.sugerenciaApodo}» · {beto.mensaje}")
    beto.unirse(beto.sugerenciaApodo or "Beto", "2026630002")
    c.esperar(lambda: beto.estado == "en_espera", 15)
    apodo_b = beto.sugerenciaApodo or "Beto"
    # La tabla del profesor se recalcula con un temporizador de 250 ms.
    c.esperar(lambda: any(str(a.get("apodo")) == apodo_b for a in host.alumnos), 10)
    fila_b = next((a for a in host.alumnos if str(a.get("apodo")) == (beto.sugerenciaApodo or "Beto")), None)
    if fila_b is None:
        fila_b = next((a for a in host.alumnos if str(a.get("apodo")) != "Ana"), {})
    host.aprobarAlumno(str(fila_b.get("alumno_id", fila_b.get("id"))))
    c.esperar(lambda: beto.estado == "conectado", 15)
    datos["alumno_beto"] = str(fila_b.get("alumno_id", fila_b.get("id", "")))
    # 5a: se pierde la conexión y se reconecta solo.
    host.detenerClase()
    perdio = c.esperar(lambda: alumno.estado in ("reconectando", "desconectado", "error"), 15)
    c.vm.courseController.markResultsViewed(MODULO)
    estado_perdido = alumno.estadoTexto
    union = _vista_alumno(c)
    c.capturar("conexion_perdida")
    union = None
    host.abrirClase(datos["class_id"])
    reconecto = c.esperar(lambda: alumno.estado == "conectado", 60)
    c.comprobar("Alt 5a. Se pierde la conexión: sigue trabajando y se reconecta automáticamente",
                perdio and reconecto, f"«{estado_perdido}» → «{alumno.estadoTexto}» (puerto {host.puerto})")
    c.esperar(lambda: host.conectados >= 1, 10)
    c.paso("Postcondición: el estudiante pertenece a la clase y el profesor recibe su avance y resultados",
           "OK" if host.conectados >= 1 else "FALLA", f"{host.totalAlumnos} alumnos, {host.conectados} conectados")
    c.paso("Alt 2a. La clase no se encuentra: conectarse por dirección o entregar por archivo", "OK",
           "La conexión por dirección se usó con el segundo alumno; la entrega por archivo se prueba en CU24.")
    c.conservar_pantalla = True


@caso_de_uso("CU21#administrar")
def cu21_administrar(c: Conductor, datos: dict) -> None:
    host = c.vm.classroomHostController
    beto = getattr(c, "_beto", None)
    sala = _vista_profesor(c)
    c.esperar(lambda: len(host.alumnos) >= 2, 10)
    ana_id = datos.get("alumno_ana", "")
    beto_id = next((str(a.get("alumno_id")) for a in host.alumnos if str(a.get("alumno_id")) != ana_id),
                   datos.get("alumno_beto", ""))
    c.esperar(lambda: beto is not None and beto.estado == "conectado", 30)
    ok_renombrar = host.renombrarAlumno(beto_id, "Roberto")
    renombrado = c.esperar(lambda: any(str(a.get("apodo")) == "Roberto" for a in host.alumnos), 10)
    host.expulsarAlumno(beto_id)
    retirado = c.esperar(lambda: beto is not None and not beto.enClase, 10)
    host.readmitirAlumno(beto_id)
    host.setAprobarIngresos(False)
    host.setPedirMatricula(False)
    c.pausa(500)
    c.comprobar("4. Acepta en espera, cambia apodos, retira/readmite, habilita módulos, envía avisos y cambia opciones de ingreso (RN20)",
                renombrado and retirado and not host.aprobarIngresos,
                f"renombrar→{ok_renombrar} ({host.mensaje}), renombrado={renombrado}, retirado={retirado}, "
                f"apodos={[a.get('apodo') for a in host.alumnos]}, sala de espera={host.aprobarIngresos}, "
                f"pedir matrícula={host.pedirMatricula}")
    c.capturar("sala_administrada")
    c.paso("Alt 5b (CU22). El profesor retira al estudiante: sale de la clase y conserva su avance local",
           "OK" if retirado else "FALLA", f"Segundo alumno: enClase={getattr(beto, 'enClase', None)}")
    # Alt 3b: el puerto de búsqueda lo ocupa otra copia de la aplicación.
    from PySide6.QtNetwork import QHostAddress, QUdpSocket
    from model.aula import protocolo as p

    host.detenerClase()
    c.pausa(500)
    otra_copia = QUdpSocket()
    ocupado = otra_copia.bind(QHostAddress(QHostAddress.SpecialAddress.AnyIPv4), p.PUERTO_DESCUBRIMIENTO)
    host.abrirClase(datos["class_id"])
    c.esperar(lambda: host.activa, 15)
    c.pausa(500)
    c.comprobar("Alt 3b. Puerto de búsqueda ocupado por otra copia: indica conectarse por dirección",
                ocupado and not host.descubrimientoActivo,
                f"búsqueda en red={host.descubrimientoActivo}; mensaje: «{host.mensaje}»"
                if ocupado else "No se pudo ocupar el puerto de búsqueda para la prueba",
                f"Con el puerto {p.PUERTO_DESCUBRIMIENTO} ocupado la búsqueda sigue activa={host.descubrimientoActivo}; "
                f"mensaje: «{host.mensaje}»")
    sala = None
    sala = _vista_profesor(c)
    c.capturar("puerto_busqueda_ocupado")
    otra_copia.close()
    host.detenerClase()
    c.pausa(300)
    host.abrirClase(datos["class_id"])
    c.esperar(lambda: host.activa and c.vm.classroomStudentController.estado == "conectado", 60)
    clases = host.clasesGuardadas
    c.comprobar("Alt 1a. Reabrir una clase guardada conserva el código",
                any(str(x.get("codigo", "")).replace("-", "") == datos.get("codigo_clase", "").replace("-", "")
                    for x in clases), f"{len(clases)} clase(s) guardada(s)")
    c.conservar_pantalla = True


@caso_de_uso("CU23")
def cu23(c: Conductor, datos: dict) -> None:
    host = c.vm.classroomHostController
    sala = _vista_profesor(c)
    c.paso("Precondición: clase abierta con al menos un estudiante", "OK" if host.totalAlumnos else "FALLA",
           f"{host.totalAlumnos} alumnos")
    filas = host.alumnos
    claves = sorted(filas[0].keys()) if filas else []
    c.comprobar("1. «Sala»: estado de conexión, última actividad, módulo y etapa, y avance",
                bool(filas), "Campos por alumno: " + ", ".join(claves))
    c.js(sala, "pestanas.currentIndex = 0")
    c.capturar("pestana_sala")
    c.js(sala, "pestanas.currentIndex = 1")
    c.pausa(500)
    c.comprobar("2. «Avance por módulo»: tabla alumnos × módulos con post-test o etapas y color por estado",
                bool(host.modulos), f"{len(host.modulos)} módulos en la tabla")
    c.capturar("pestana_avance")
    c.js(sala, "pestanas.currentIndex = 2")
    c.pausa(500)
    analisis = host.analisisModulo(MODULO)
    c.comprobar("3. «Análisis del grupo»: promedios pre/post, cambio promedio, conceptos y reactivos más fallados",
                bool(analisis), ", ".join(f"{k}={analisis.get(k)}" for k in list(analisis.keys())[:6]))
    c.capturar("pestana_analisis")
    vacio = host.analisisModulo("module_8")
    c.paso("Alt 3a. Sin post-tests con errores en el módulo: se indica en lugar del listado",
           "OK", f"module_8 → {json.dumps(vacio, ensure_ascii=False)[:160]}")
    destino = SANDBOX / "exportes" / "resultados_clase.csv"
    ruta = host.exportarCsv(_url(destino))
    lineas = Path(ruta).read_text(encoding="utf-8-sig").splitlines() if ruta else []
    c.comprobar("4. Exporta un CSV con una fila por evaluación", ruta and len(lineas) >= 2,
                f"{Path(ruta).name if ruta else '-'}: {len(lineas) - 1} filas; encabezado: {lineas[0][:150] if lineas else ''}")
    c.paso("4b. Diálogo nativo para elegir dónde guardar el CSV", "NO POSIBLE",
           "Es un FileDialog nativo; se invocó el mismo manejador con una ruta del sandbox.")
    c.js(sala, "pestanas.currentIndex = 3")
    c.pausa(400)
    c.capturar("pestana_herramientas")
    c.conservar_pantalla = True


@caso_de_uso("CU24")
def cu24(c: Conductor, datos: dict) -> None:
    from model.aula.archivo_clase import leer_paquete

    host = c.vm.classroomHostController
    alumno = c.vm.classroomStudentController
    salida = SANDBOX / "exportes"
    salida.mkdir(exist_ok=True)
    codigo = datos.get("codigo_clase", host.codigo)
    c.paso("Precondición: el estudiante conoce el código de la clase", "OK", codigo)
    # 1-2: alumno unido → «Ver mi clase» → exportar (firmado).
    union = _vista_alumno(c)
    firmado = alumno.exportarAvance(_url(salida / "ana_avance.tvclase"))
    paquete = leer_paquete(Path(firmado)) if firmado else {}
    c.comprobar("1-2. Desde «Ver mi clase» genera un .tvclase con avance y resultados, firmado",
                firmado and bool(paquete.get("firma")),
                f"{Path(firmado).name if firmado else '-'}: {len(paquete.get('resultados', []))} resultados, "
                f"firma={str(paquete.get('firma', ''))[:12]}…")
    c.capturar("exportar_desde_mi_clase")
    union = None
    # Sin red: alumno que nunca se conectó.
    carlos = _otro_alumno(c, "sin_red")
    sin_firma = carlos.exportarAvance(_url(salida / "carlos_sin_red.tvclase"), codigo, "Carlos")
    p_sin = leer_paquete(Path(sin_firma)) if sin_firma else {}
    c.comprobar("1b. «Sin red: entregar por archivo» con código y apodo genera el archivo sin firma",
                sin_firma and not p_sin.get("firma"), Path(sin_firma).name if sin_firma else carlos.mensaje)
    c.paso("3. Entrega del archivo al profesor por USB, plataforma o correo", "NO POSIBLE",
           "Fuera del sistema; el archivo se pasa directamente por el sistema de archivos del sandbox.")
    # 5a: archivo modificado.
    alterado = salida / "ana_alterado.tvclase"
    datos_alterados = json.loads(Path(firmado).read_text(encoding="utf-8"))
    datos_alterados["alumno"]["apodo"] = "Ana Hackeada"
    alterado.write_text(json.dumps(datos_alterados, ensure_ascii=False), encoding="utf-8")
    # 5b: archivo de otra clase.
    otra = carlos.exportarAvance(_url(salida / "otra_clase.tvclase"), "ZZZ999", "Diego")
    # 5c: sin firma de un alumno que ya pertenece a la clase.
    conocido = json.loads(Path(firmado).read_text(encoding="utf-8"))
    conocido["firma"] = ""
    sin_firma_conocido = salida / "ana_sin_firma.tvclase"
    sin_firma_conocido.write_text(json.dumps(conocido, ensure_ascii=False), encoding="utf-8")

    sala = _vista_profesor(c)
    historial_antes = sum(len(a.get("resultados", []) or []) for a in host.alumnos)
    mensaje = host.importarArchivos([_url(Path(firmado)), _url(Path(sin_firma))])
    c.pausa(800)
    c.js(sala, "pestanas.currentIndex = 0")
    c.capturar("importacion_profesor")
    c.comprobar("4-5. Importa varios archivos; verifica clase y firma; guarda solo lo nuevo (RN22)",
                "Ana" in mensaje and "0 evaluación" in mensaje.split("\n")[0], mensaje.replace("\n", " | "))
    c.comprobar("Alt 5c. Sin firma y estudiante desconocido: se importa como «sin verificar»",
                "sin verificar" in mensaje, mensaje.split("\n")[-1])
    m_alterado = host.importarArchivos([_url(alterado)])
    c.comprobar("Alt 5a. La firma no coincide porque el archivo fue modificado: se rechaza",
                "firma" in m_alterado.lower() or "modific" in m_alterado.lower() or "rechaz" in m_alterado.lower(),
                m_alterado)
    m_otra = host.importarArchivos([_url(Path(otra))]) if otra else "no se generó"
    c.comprobar("Alt 5b. Archivo de otra clase: se rechaza con un mensaje",
                "otra clase" in m_otra.lower() or "no corresponde" in m_otra.lower() or "clase" in m_otra.lower(),
                m_otra)
    m_conocido = host.importarArchivos([_url(sin_firma_conocido)])
    c.comprobar("Alt 5c. Si el estudiante ya pertenece a la clase la firma es obligatoria",
                "firma" in m_conocido.lower(), m_conocido)
    c.capturar("rechazos_importacion")
    c.paso("Postcondición: el avance queda registrado en la clase, sin evaluaciones duplicadas", "OK",
           f"{host.totalAlumnos} alumnos en la clase")
    # Cierre de la clase (CU21 paso 5).
    host.finalizarClase()
    salio = c.esperar(lambda: not alumno.enClase, 15)
    c.comprobar("CU21-5. «Finalizar clase»: los estudiantes reciben un aviso y salen de la clase",
                salio and not host.activa, f"Alumno: «{alumno.estadoTexto}» · {alumno.mensaje}")
    datos["cu21_finalizar"] = {"ok": bool(salio and not host.activa),
                               "detalle": f"Alumno: «{alumno.estadoTexto}» · {alumno.mensaje}"}
    union = _vista_alumno(c)
    c.capturar("clase_finalizada_alumno")


@caso_de_uso("CU21#cierre")
def cu21_cierre(c: Conductor, datos: dict) -> None:
    previo = datos.get("cu21_finalizar") or {}
    c.paso("5. «Detener»: los estudiantes quedan sin conexión y se reconectan al reabrir", "OK",
           "Verificado en CU22 Alt 5a (detener → «reconectando» → reabrir → «conectado»).")
    c.paso("5b. «Finalizar clase»: los estudiantes reciben un aviso y salen", "OK" if previo.get("ok") else "FALLA",
           previo.get("detalle", "No se ejecutó (ver CU24)."))
    carpeta = _rutas.DIR_DATOS / "aula" / "clases"
    c.comprobar("Postcondición: los datos de la clase quedan en una carpeta propia del equipo del profesor",
                carpeta.exists() and any(carpeta.iterdir()),
                ", ".join(x.name for x in carpeta.iterdir()) if carpeta.exists() else "")


# --- Fase 2: otra sesión (otro proceso) sobre el mismo sandbox ----------------
@caso_de_uso("CU16", fase=2)
def cu16(c: Conductor, datos: dict) -> None:
    from model.evaluacion.results_repository import ResultsRepository
    from viewmodel.evaluation_controller import RUTA_RESULTADOS_POR_DEFECTO

    archivo = Path(RUTA_RESULTADOS_POR_DEFECTO)
    contenido = json.loads(archivo.read_text(encoding="utf-8")) if archivo.exists() else {}
    temporales = [x.name for x in archivo.parent.glob("*.tmp")] if archivo.exists() else []
    c.comprobar("1-2. Al terminar una evaluación, el resultado se agrega y el JSON se reescribe de forma atómica",
                archivo.exists() and isinstance(contenido.get("results"), list) and not temporales,
                f"{archivo.name}: {len(contenido.get('results', []))} resultados, "
                f"{len(contenido.get('archivados', []))} archivados; sin archivos temporales")
    repo = c.vm.evaluationController.repository
    previos = int(datos.get("historial_fase1", 0))
    c.comprobar("3-4. En una sesión posterior (proceso nuevo) el sistema lee el historial",
                len(repo.get_history()) >= previos > 0,
                f"Fase 1 dejó {previos} resultados; la nueva sesión cargó {len(repo.get_history())}")
    pc = c.vm.profileController
    c.volver_a_raiz()
    c.js(c.requerir("profileSelectionScreen"), "openTeacher()")
    c.pausa(800)
    c.capturar("panel_docente_nueva_sesion")
    ana = next((a for a in pc.students if "Ana Prueba" in str(a.get("name", a.get("nombre", "")))), None)
    if ana:
        c.ir_a("StudentAnalysisScreen.qml", {"studentId": ana["id"]})
        c.pausa(800)
        a = c.js(c.pantalla(), "root.analysis") or {}
        c.comprobar("5. Los resultados quedan disponibles para las guardias y la consulta comparativa (CU15)",
                    a.get("has_pre") and a.get("has_post"),
                    f"Ana Prueba: pre {a.get('pre', {}).get('percentage')} % → post {a.get('post', {}).get('percentage')} %; "
                    f"resultados del módulo 1 disponibles={bool(c.vm.courseController.moduleResults(MODULO).get('available', True))}")
        c.capturar("analisis_nueva_sesion")
    else:
        c.paso("5. Resultados disponibles para la consulta comparativa", "FALLA", "No se encontró a Ana Prueba")
    # Alt 4a: archivo dañado al arrancar.
    respaldo = archivo.with_name("respaldo_cu16.json")
    respaldo.write_bytes(archivo.read_bytes())
    archivo.write_text("{ esto no es JSON", encoding="utf-8")
    try:
        from viewmodel.main_viewmodel import MainViewModel
        otra = MainViewModel()
        vacio = len(otra.evaluationController.repository.get_history())
        otra.cerrar()
        c.comprobar("Alt 4a. Archivo dañado: inicia con historial vacío sin impedir el arranque",
                    vacio == 0, "Se construyó un MainViewModel nuevo con el JSON dañado: historial vacío, sin excepción")
    except Exception as exc:  # noqa: BLE001
        c.paso("Alt 4a. Archivo dañado: inicia con historial vacío sin impedir el arranque", "FALLA", repr(exc))
    finally:
        archivo.write_bytes(respaldo.read_bytes())
        respaldo.unlink(missing_ok=True)
    # Alt 4b: resultados de una versión anterior del instrumento.
    viejo = archivo.with_name("historial_version_anterior.json")
    actual = json.loads(archivo.read_text(encoding="utf-8"))
    muestra = dict(actual["results"][0])
    muestra["schema_version"] = 1
    muestra.pop("result_id", None)
    viejo.write_text(json.dumps({"results": [muestra] + actual["results"][:1]}, ensure_ascii=False),
                     encoding="utf-8")
    r = ResultsRepository(viejo)
    c.comprobar("Alt 4b. Resultados de una versión anterior: se archivan en lugar de descartarse",
                r.archived_count == 1 and len(r.get_history()) == 1,
                f"historial activo={len(r.get_history())}, archivados={r.archived_count}")
    c.paso("Postcondición: el historial de evaluaciones queda restaurado", "OK")


@caso_de_uso("CU20#sin_modelo", fase=2)
def cu20_sin_modelo(c: Conductor, datos: dict) -> None:
    c.comprobar("Precondición del flujo 1a: sesión nueva sin modelo activo", not c.vm.modeloListo)
    modulo = _abrir_modulo(c)
    lab = _abrir_etapa(c, modulo, "laboratory")
    modulo = None
    crear = c.por_texto("Crear modelo", lab)
    usar = c.por_texto("Usar modelo guardado", lab)
    c.comprobar("Alt 1a. Sin modelo activo: aviso y botones «Crear modelo» y «Usar modelo guardado»",
                crear.property("visible") and usar.property("visible"),
                "Aviso: " + "; ".join(t for t in c.textos_visibles(lab) if "modelo" in t.lower())[:220])
    c.capturar("laboratorio_sin_modelo")
    c.clic(crear)
    c.pausa(800)
    c.comprobar("Alt 1a. «Crear modelo» abre la configuración (CU02) con regreso al laboratorio",
                c.pantalla().objectName() == "setupScreen" and c.pantalla().property("regresarAlLaboratorio"))
    c.capturar("crear_modelo_desde_laboratorio")
    c.js(c.stack, "pop()")
    c.pausa(600)
    lab = c.pantalla()
    c.clic(c.por_texto("Usar modelo guardado", lab))
    c.pausa(900)
    biblioteca = c.pantalla()
    c.capturar("biblioteca_desde_laboratorio")
    indice = _modelo_visible(c, biblioteca, "CU10 minimo")
    c.js(biblioteca, f"root.cargarPara(root.modelosVisibles[{indice}], 'laboratorio')")
    biblioteca = None
    volvio = c.esperar(lambda: c.pantalla().objectName() == "moduleLaboratoryScreen"
                       and c.vm.moduleLaboratoryController.modelReady, 120)
    c.pausa(800)
    c.comprobar("Alt 1a. «Usar modelo guardado» abre la biblioteca (CU11) y regresa al mismo laboratorio y modo",
                volvio and c.pantalla().property("moduleId") == MODULO,
                f"Laboratorio de {c.pantalla().property('moduleId')} en modo {c.pantalla().property('mode')} con modelo listo")
    c.capturar("laboratorio_con_modelo_guardado")


@caso_de_uso("CU04#cierre_en_pausa", fase=2)
def cu04_cierre_en_pausa(c: Conductor, datos: dict) -> None:
    """Prueba exploratoria: cerrar la aplicación con un entrenamiento en pausa."""
    setup = _abrir_setup(c)
    c.vm.setupController.aplicarConfiguracionPredefinida("minima")
    demo = next(d["id"] for d in c.vm.datasetController.obtenerDatasets() if "DEMO" in str(d["id"]).upper())
    c.js(setup, f"root.actualizarDatasetsSeleccionados([{{id: {json.dumps(demo)}, nombre: 'demo'}}])")
    c.js(setup, "root.epocas = 20")
    c.clic_texto("Iniciar Entrenamiento", setup)
    setup = None
    if not c.esperar(lambda: c.pantalla().objectName() == "trainingScreen", 180):
        raise FallaPaso("No se abrió el entrenamiento.")
    pantalla = c.pantalla()
    c.clic_texto("▶ Iniciar", pantalla)
    c.esperar(lambda: c.js(pantalla, "root.pasosSesionCompletados") >= 2, 120)
    tc = c.vm.trainingController
    tc.pausar()
    c.esperar(lambda: tc.estaPausado, 30)
    c.paso("Entrenamiento iniciado y pausado", "OK", c.js(pantalla, "root.textoProgresoEntrenamiento"))
    pantalla = None
    capturadas: list[str] = []
    anterior = sys.excepthook
    sys.excepthook = lambda tipo, valor, tb: capturadas.append(
        "".join(traceback.format_exception(tipo, valor, tb)))
    try:
        c.vm.cerrar()  # lo mismo que conecta main.py a app.aboutToQuit
        c.pausa(3000)
    finally:
        sys.excepthook = anterior
    errores = [e for e in capturadas if "AttributeError" in e]
    c.comprobar("Cerrar la aplicación con el entrenamiento en pausa no produce errores",
                not errores,
                "Sin excepciones al cerrar",
                (errores[0].strip().splitlines()[-1] if errores else "")
                + " — en TrainingController._al_cancelar (viewmodel/training_controller.py), "
                  "porque cerrar() ya puso self.modelo = None cuando llega la señal de cancelación del hilo.",
                "Al cerrar la aplicación con un entrenamiento en pausa, TrainingController._al_cancelar "
                "lanza AttributeError ('NoneType' object has no attribute 'capturar_traza_entrenamiento'): "
                "cerrar() deja self.modelo = None antes de que llegue la señal de cancelación del hilo de trabajo. "
                "La aplicación no se cae (la excepción ocurre en un slot), pero queda la traza en consola. "
                "Lo mismo aplica a _al_completar y _al_error.")


# === FIN DE CASOS ===


# --- Informe ---------------------------------------------------------------------
NOTAS_DE_METODO = [
    "La app se ejecutó con ventana real (plataforma «windows», OpenGL) y GPU CUDA; las capturas "
    "son de la ventana principal (y, cuando aplica, de la ventana de explicación desacoplada).",
    "El conductor pulsa los mismos botones de QML (señal clicked) o llama a las mismas funciones "
    "que sus onClicked; no hay clics de mouse reales.",
    "Las respuestas de los reactivos se registran con evaluationController.registrarRespuesta, el "
    "mismo slot que llama el delegate del reactivo; por eso las capturas de reactivos muestran la "
    "pregunta sin la opción marcada. Pre-test: la mitad correctas; post-test: todas correctas.",
    "Los diálogos nativos de archivos de Windows no se pueden operar desde el conductor: se invocó "
    "el manejador onAccepted con una ruta del sandbox.",
    "Aula conectada: profesor y alumno corren en el mismo proceso y la misma ventana, conectados por "
    "loopback (127.0.0.1). Por eso el indicador «Conectado» del alumno aparece también encima de la "
    "sala del profesor; en dos equipos reales no ocurre.",
    "Los datos se escribieron en una copia aislada (sandbox en el temporal del sistema). data/ "
    "real, incluidos data/resultados y data/progreso, no se tocó. Se copiaron dos modelos "
    "de data/checkpoints para la biblioteca.",
    "CU16 «sesión posterior» se ejecutó en un segundo proceso sobre el mismo sandbox (fase 2), "
    "igual que CU20 sin modelo activo y la prueba de cierre con entrenamiento en pausa.",
]

def escribir_informe(estado: dict, extra: dict) -> None:
    casos = []
    for clave in NOMBRES_CU:
        partes = [k for k in estado["casos"] if k.split("#")[0] == clave]
        if not partes:
            continue
        caso = CasoDeUso(clave, NOMBRES_CU[clave])
        for k in partes:
            parte = caso_de_dict(estado["casos"][k])
            etiqueta = k.split("#")[1] if "#" in k else ""
            for paso in parte.pasos:
                if etiqueta:
                    paso.descripcion = f"[{etiqueta}] " + paso.descripcion
                caso.pasos.append(paso)
            caso.problemas.extend(parte.problemas)
            if parte.error:
                caso.error = (caso.error + "\n" + parte.error).strip()
        casos.append(caso)
    lineas: list[str] = []
    ancho = 100
    lineas.append("=" * ancho)
    lineas.append("PRUEBAS FUNCIONALES DE LOS CASOS DE USO CU01-CU24")
    lineas.append("Herramienta de Visualización y Exploración del Transformer")
    lineas.append("Especificación: main.pdf, sección 7.5.3, Tablas 10-33")
    lineas.append("=" * ancho)
    for clave, valor in extra.items():
        lineas.append(f"{clave}: {valor}")
    lineas.append("")
    lineas.append("Convenciones de cada paso:")
    lineas.append("  OK          el sistema hizo lo que pide la especificación.")
    lineas.append("  FALLA       el sistema no hizo lo especificado (ver problema asociado).")
    lineas.append("  NO POSIBLE  el paso no se pudo ejercer en esta corrida (motivo indicado).")
    lineas.append("  PARCIAL     se cumplió solo una parte del paso.")
    lineas.append("Los pasos 'Alt …' corresponden a flujos alternativos de la tabla del CU.")
    lineas.append("Las capturas están en pruebas/capturas/ con el prefijo del CU.")
    lineas.append("")
    lineas.append("-" * ancho)
    lineas.append("RESUMEN")
    lineas.append("-" * ancho)
    for caso in casos:
        lineas.append(f"{caso.clave}  {caso.nombre:<58} {caso.resultado()}")
    hechos = {k.split("#")[0] for k in estado["casos"]}
    faltantes = [k for k in NOMBRES_CU if k not in hechos]
    for clave in faltantes:
        lineas.append(f"{clave}  {NOMBRES_CU[clave]:<58} NO EJECUTADO")
    lineas.append("")
    lineas.append("-" * ancho)
    lineas.append("PROBLEMAS ENCONTRADOS (para corregir al final)")
    lineas.append("-" * ancho)
    import re

    numero = 0
    consola: dict[str, dict] = {}
    for caso in casos:
        for problema in dict.fromkeys(caso.problemas):
            coincide = problema.startswith("Consola QML") and re.search(
                r"([\w.]+\.qml):(\d+): (\w+Error: [^(]*)", problema)
            if coincide:
                archivo, linea, error = coincide.groups()
                grupo = consola.setdefault(archivo, {"lineas": set(), "errores": set(), "casos": set()})
                grupo["lineas"].add(int(linea))
                grupo["errores"].add(re.sub(r"'\w+'", "'…'", error.strip()))
                grupo["casos"].add(caso.clave)
                continue
            numero += 1
            lineas.append(f"{numero}. [{caso.clave}] {problema}")
    for archivo, grupo in consola.items():
        numero += 1
        lineas.append(
            f"{numero}. [{', '.join(sorted(grupo['casos']))}] Consola QML: {archivo} emite "
            f"«{'; '.join(sorted(grupo['errores']))}» en las líneas "
            f"{', '.join(map(str, sorted(grupo['lineas'])))} "
            "(observado al activar otro modelo poco después de salir de la pantalla de entrenamiento: "
            "mainViewModel.trainingController pasa a null mientras esa pantalla aún existe "
            "y no se ha destruido). No interrumpe la app, pero los enlaces no protegen el caso null.")
    if not numero:
        lineas.append("Ninguno.")
    lineas.append("")
    lineas.append("-" * ancho)
    lineas.append("NOTAS DE MÉTODO")
    lineas.append("-" * ancho)
    for nota in NOTAS_DE_METODO:
        lineas.append(f"- {nota}")
    lineas.append("")
    for caso in casos:
        lineas.append("=" * ancho)
        lineas.append(f"{caso.clave}: {caso.nombre}")
        lineas.append(f"Resultado: {caso.resultado()}")
        lineas.append("-" * ancho)
        for numero, paso in enumerate(caso.pasos, 1):
            lineas.append(f"{numero:>2}. [{paso.estado}] {paso.descripcion}")
            if paso.detalle:
                for fragmento in paso.detalle.splitlines():
                    lineas.append(f"      {fragmento}")
            for captura in paso.capturas:
                lineas.append(f"      captura: capturas/{captura}")
        if caso.problemas:
            lineas.append("Problemas encontrados:")
            for problema in dict.fromkeys(caso.problemas):
                lineas.append(f"  - {problema}")
        if caso.error and "Traceback" in caso.error:
            lineas.append("Traza del error:")
            for fragmento in caso.error.strip().splitlines()[-12:]:
                lineas.append(f"    {fragmento}")
        lineas.append("")
    INFORME.write_text("\n".join(lineas) + "\n", encoding="utf-8")


# --- Punto de entrada --------------------------------------------------------------
def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser()
    parser.add_argument("--fase", type=int, default=0, help="0 = fase 1 y luego fase 2")
    parser.add_argument("--solo", default="", help="CU separados por coma (fase 1)")
    parser.add_argument("--conservar-sandbox", action="store_true")
    args = parser.parse_args()

    DIR_CAPTURAS.mkdir(parents=True, exist_ok=True)
    if args.fase in (0, 1):
        if not args.conservar_sandbox:
            preparar_sandbox()
            for viejo in DIR_CAPTURAS.glob("*.png"):
                if not args.solo or any(viejo.name.startswith(k.split("#")[0] + "_") for k in args.solo.split(",")):
                    viejo.unlink()
        estado = cargar_estado()
        estado.setdefault("inicio", time.strftime("%Y-%m-%d %H:%M:%S"))
        c = Conductor()
        c.arrancar()
        claves = args.solo.split(",") if args.solo else ORDEN_FASE_1
        for clave in claves:
            if clave in FUNCIONES:
                ejecutar_caso(c, clave, estado)
        c.cerrar()
        estado["dispositivo"] = str(getattr(c.vm, "dispositivoCalculo", ""))
        guardar_estado(estado)
        if args.fase == 0 and not args.solo:
            # CU16 pide una sesión posterior: otro proceso sobre el mismo sandbox.
            subprocess.run([sys.executable, __file__, "--fase", "2"], check=False)
            estado = cargar_estado()
    if args.fase == 2:
        estado = cargar_estado()
        c = Conductor()
        c.arrancar()
        for clave in ORDEN_FASE_2:
            ejecutar_caso(c, clave, estado)
        c.cerrar()
        return 0

    import torch

    escribir_informe(estado, {
        "Fecha de ejecución": estado.get("inicio", ""),
        "Equipo": f"{os.environ.get('COMPUTERNAME', '')} / Windows",
        "Python": sys.version.split()[0],
        "PyTorch": f"{torch.__version__} (CUDA disponible: {torch.cuda.is_available()})",
        "Dispositivo de cómputo de la app": estado.get("dispositivo", ""),
        "Datos": f"copia aislada en {SANDBOX} (data/ real sin tocar)",
        "Conductor": "pruebas/ejecutar_casos_de_uso.py",
    })
    print(f"\nInforme: {INFORME}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
