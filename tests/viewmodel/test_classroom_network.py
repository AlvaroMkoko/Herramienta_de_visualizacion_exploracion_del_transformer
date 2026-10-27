"""Docente y alumno reales hablando por WebSocket y UDP en este equipo.

El descubrimiento usa ``127.0.0.1`` (siempre incluido entre los destinos), así
que la prueba no depende de la red del equipo donde corre.
"""

from __future__ import annotations

import socket

import pytest

from model.aprendizaje import ModuleProgressRepository
from model.evaluacion.results_repository import ResultsRepository
from viewmodel.aula import ClassroomHostController, ClassroomStudentController
from viewmodel.aula import classroom_student_controller as modulo_alumno
from viewmodel.aula.cliente_lan import ClienteAulaLan
from viewmodel.course_controller import CourseController
from viewmodel.module_evaluation_controller import ModuleEvaluationController

TIEMPO = 15000
BLOQUEO_DOCENTE = "El docente todavía no habilita este módulo en la clase."


def _responder(controller: ModuleEvaluationController) -> dict:
    question = controller._manager.current_question
    tipo = question["tipo"]
    if tipo == "opcion_unica":
        return {"opcion_id": question["correct_option_id"]}
    if tipo == "seleccion_multiple":
        return {"opciones_ids": question["correct_option_ids"]}
    if tipo == "texto":
        return {"texto": question["respuestas_aceptadas"][0]}
    if tipo == "asignacion":
        return {"asignaciones": {i["id"]: i["correcto"] for i in question["elementos"]}}
    raise AssertionError(tipo)


def _completar_evaluacion(controller: ModuleEvaluationController, modulo: str, tipo: str) -> None:
    controller.startModuleEvaluation(modulo, tipo)
    while controller.isActive:
        controller.registrarRespuesta(_responder(controller))
        controller.submitCurrentAnswer()


class _Alumno:
    def __init__(self, tmp_path, nombre: str, puerto_udp: int) -> None:
        carpeta = tmp_path / nombre
        self.results = ResultsRepository(carpeta / "results.json")
        self.evaluacion = ModuleEvaluationController(repository=self.results)
        self.course = CourseController(
            self.evaluacion, repository=ModuleProgressRepository(carpeta / "progreso.json")
        )
        self.controller = ClassroomStudentController(
            self.course,
            self.results,
            (self.evaluacion,),
            ruta_estado=carpeta / "mi_clase.json",
            cliente=ClienteAulaLan(puerto_descubrimiento=puerto_udp, espera_busqueda_ms=300),
        )


@pytest.fixture
def puerto_udp() -> int:
    # El sistema operativo evita aquí sus rangos reservados; elegir un número
    # al azar hacía que estas pruebas de red fallaran de forma intermitente.
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as comprobacion:
        comprobacion.bind(("127.0.0.1", 0))
        return comprobacion.getsockname()[1]


@pytest.fixture
def docente(tmp_path, puerto_udp):
    host = ClassroomHostController(
        raiz_clases=tmp_path / "clases", puerto_websocket=0, puerto_descubrimiento=puerto_udp
    )
    yield host
    host.detenerClase()


def _unir(qtbot, alumno: _Alumno, docente, apodo: str) -> None:
    assert alumno.controller.buscarClase(docente.codigo.lower())
    qtbot.waitUntil(lambda: alumno.controller.estado == "eligiendo_apodo", timeout=TIEMPO)
    assert alumno.controller._cliente._socket.requestUrl().scheme() == "wss"
    assert len(alumno.controller._cliente._huella_esperada) == 64
    assert alumno.controller.nombreClase == "Inteligencia Artificial"
    assert alumno.controller.unirse(apodo, "")
    qtbot.waitUntil(lambda: alumno.controller.estado == "conectado", timeout=TIEMPO)


def test_flujo_completo_de_clase_en_red(qtbot, tmp_path, docente, puerto_udp, monkeypatch):
    monkeypatch.setattr(modulo_alumno, "ESPERAS_REINTENTO_MS", (200, 400))
    assert docente.crearClase("Inteligencia Artificial", "6CV1", False, False)
    assert docente.activa and docente.puerto > 0

    ana = _Alumno(tmp_path, "ana", puerto_udp)
    _unir(qtbot, ana, docente, "Ana")
    assert ana.controller.enClase and ana.controller.apodo == "Ana"
    qtbot.waitUntil(lambda: docente.conectados == 1, timeout=TIEMPO)
    assert docente.alumnos[0]["apodo"] == "Ana"

    # Un resultado local llega al docente con la identidad del aula.
    _completar_evaluacion(ana.evaluacion, "module_1", "pre")
    qtbot.waitUntil(lambda: ana.controller.pendientes == 0, timeout=TIEMPO)
    alumno_id = docente.alumnos[0]["alumno_id"]
    guardados = docente._repo.resultados_de(alumno_id)
    assert len(guardados) == 1 and guardados[0]["student"]["apodo"] == "Ana"

    # El progreso del curso también se sincroniza.
    for paso in ana.course.catalog.get("module_1")["guided_steps"]:
        ana.course.recordGuidedCheck("module_1", paso["id"], 0)
    assert ana.course.completeGuidedTour("module_1")
    qtbot.waitUntil(
        lambda: docente.alumnos and docente.alumnos[0]["modules"][0]["progress_percent"] == 40,
        timeout=TIEMPO,
    )
    # El post-test del final exige el laboratorio: sin él la evaluación se rechaza.
    pasos = ana.course.catalog.get("module_1")["guided_steps"]
    for paso in pasos[: CourseController.REQUIRED_LAB_CYCLES]:
        ana.course.recordDiscoveryCycle("module_1", paso["id"], True, 1)
    ana.course.recordAnchorClosing("module_1", 0)
    assert ana.course.stageAvailable("module_1", "posttest")
    qtbot.waitUntil(
        lambda: docente.alumnos[0]["modules"][0]["progress_percent"] == 60,
        timeout=TIEMPO,
    )

    # El docente restringe módulos y envía avisos.
    docente.habilitarModulo("module_2", False)
    # El módulo 2 ya está cerrado por prerrequisitos; lo que se observa es que
    # el motivo pase a ser la restricción del docente, que tiene prioridad.
    qtbot.waitUntil(
        lambda: ana.course.stageBlockReason("module_2", "guided") == BLOQUEO_DOCENTE,
        timeout=TIEMPO,
    )
    assert docente.enviarAviso("Empiecen el módulo 1")
    qtbot.waitUntil(lambda: ana.controller.ultimoAviso == "Empiecen el módulo 1", timeout=TIEMPO)

    # Si el docente cierra la app y la reabre, el alumno vuelve solo aunque
    # el puerto haya cambiado: la última dirección falla y busca por código.
    class_id = docente.classId
    docente.detenerClase()
    qtbot.waitUntil(lambda: ana.controller.estado == "reconectando", timeout=TIEMPO)
    _completar_evaluacion(ana.evaluacion, "module_1", "post")
    assert ana.controller.pendientes == 1
    assert docente.abrirClase(class_id)
    qtbot.waitUntil(lambda: ana.controller.estado == "conectado", timeout=TIEMPO)
    qtbot.waitUntil(lambda: ana.controller.pendientes == 0, timeout=TIEMPO)
    assert len(docente._repo.resultados_de(alumno_id)) == 2

    # Expulsión: el alumno sale de la clase pero conserva su avance local.
    docente.expulsarAlumno(alumno_id)
    qtbot.waitUntil(lambda: not ana.controller.enClase, timeout=TIEMPO)
    assert ana.controller.estado == "sin_clase"
    assert len(ana.results.get_history()) == 2
    # Fuera de la clase ya no rige la restricción del docente, solo los
    # prerrequisitos del curso.
    assert ana.course.stageBlockReason("module_2", "guided") not in ("", BLOQUEO_DOCENTE)


def test_apodo_repetido_y_conexion_por_direccion(qtbot, tmp_path, docente, puerto_udp):
    assert docente.crearClase("Inteligencia Artificial", "", True, False)
    ana = _Alumno(tmp_path, "ana", puerto_udp)
    otra = _Alumno(tmp_path, "otra", puerto_udp)

    assert ana.controller.buscarPorDireccion(f"127.0.0.1:{docente.puerto}", docente.codigo)
    qtbot.waitUntil(lambda: ana.controller.estado == "eligiendo_apodo", timeout=TIEMPO)
    assert ana.controller._cliente._socket.requestUrl().scheme() == "wss"
    assert len(ana.controller._cliente._huella_esperada) == 64
    assert ana.controller.pedirMatricula
    assert not ana.controller.unirse("Ana", "")  # falta matrícula
    assert ana.controller.unirse("Ana", "2021630001")
    qtbot.waitUntil(lambda: ana.controller.estado == "conectado", timeout=TIEMPO)

    assert otra.controller.buscarClase(docente.codigo)
    qtbot.waitUntil(lambda: otra.controller.estado == "eligiendo_apodo", timeout=TIEMPO)
    otra.controller.unirse("ana", "2021630002")
    qtbot.waitUntil(lambda: otra.controller.sugerenciaApodo == "ana2", timeout=TIEMPO)
    assert otra.controller.estado == "eligiendo_apodo"
    assert otra.controller.unirse(otra.controller.sugerenciaApodo, "2021630002")
    qtbot.waitUntil(lambda: otra.controller.estado == "conectado", timeout=TIEMPO)
    qtbot.waitUntil(lambda: docente.conectados == 2, timeout=TIEMPO)


def test_sala_de_espera_y_renombrar(qtbot, tmp_path, docente, puerto_udp):
    assert docente.crearClase("Inteligencia Artificial", "", False, True)
    ana = _Alumno(tmp_path, "ana", puerto_udp)
    assert ana.controller.buscarClase(docente.codigo)
    qtbot.waitUntil(lambda: ana.controller.estado == "eligiendo_apodo", timeout=TIEMPO)
    ana.controller.unirse("Ana", "")
    qtbot.waitUntil(lambda: ana.controller.estado == "en_espera", timeout=TIEMPO)
    qtbot.waitUntil(lambda: docente.pendientesAprobacion == 1, timeout=TIEMPO)

    alumno_id = docente.alumnos[0]["alumno_id"]
    docente.aprobarAlumno(alumno_id)
    qtbot.waitUntil(lambda: ana.controller.estado == "conectado", timeout=TIEMPO)
    assert docente.renombrarAlumno(alumno_id, "Ana G")
    qtbot.waitUntil(lambda: ana.controller.apodo == "Ana G", timeout=TIEMPO)


def test_codigo_inexistente_informa_error(qtbot, tmp_path, docente, puerto_udp):
    assert docente.crearClase("Inteligencia Artificial", "", False, False)
    ana = _Alumno(tmp_path, "ana", puerto_udp)
    assert not ana.controller.buscarClase("123")
    assert ana.controller.buscarClase("ZZZZZZ" if docente.codigo != "ZZZ-ZZZ" else "YYYYYY")
    qtbot.waitUntil(lambda: ana.controller.estado == "error", timeout=TIEMPO)
    assert "No se encontró" in ana.controller.mensaje


def test_rechaza_certificado_tls_distinto(qtbot, docente, puerto_udp):
    assert docente.crearClase("Inteligencia Artificial", "", False, False)
    cliente = ClienteAulaLan(puerto_descubrimiento=puerto_udp)
    destino = ("127.0.0.1", docente.puerto)
    cliente._huellas_conocidas[destino] = "0" * 64

    with qtbot.waitSignal(cliente.fallo, timeout=TIEMPO) as bloqueo:
        cliente.conectar(*destino)

    assert "TLS" in bloqueo.args[0]
    assert not cliente.esta_conectado
    cliente.cerrar()


def _puerto_tcp_libre() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as comprobacion:
        comprobacion.bind(("127.0.0.1", 0))
        return comprobacion.getsockname()[1]


def test_reabrir_la_clase_sin_broadcast_reconecta_a_los_alumnos(qtbot, tmp_path, monkeypatch):
    """En redes que no dejan pasar el broadcast (Wi-Fi IPN) el alumno solo
    puede volver por la última dirección. Si el docente estrenara certificado al
    reabrir la clase, la huella fijada ya no coincidiría y el alumno se quedaría
    en «reconectando» para siempre (docs/estandar_red.md, P6)."""
    monkeypatch.setattr(modulo_alumno, "ESPERAS_REINTENTO_MS", (200, 400))
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp_docente, socket.socket(
        socket.AF_INET, socket.SOCK_DGRAM
    ) as udp_sin_nadie:
        udp_docente.bind(("127.0.0.1", 0))
        udp_sin_nadie.bind(("127.0.0.1", 0))
        puertos_udp = udp_docente.getsockname()[1], udp_sin_nadie.getsockname()[1]
    puerto = _puerto_tcp_libre()
    docente = ClassroomHostController(
        raiz_clases=tmp_path / "clases", puerto_websocket=puerto, puerto_descubrimiento=puertos_udp[0]
    )
    try:
        assert docente.crearClase("Inteligencia Artificial", "", False, False)
        # El alumno busca en un puerto donde nadie responde: como sin broadcast.
        ana = _Alumno(tmp_path, "ana", puertos_udp[1])
        assert ana.controller.buscarPorDireccion(f"127.0.0.1:{docente.puerto}", docente.codigo)
        qtbot.waitUntil(lambda: ana.controller.estado == "eligiendo_apodo", timeout=TIEMPO)
        assert ana.controller.unirse("Ana", "")
        qtbot.waitUntil(lambda: ana.controller.estado == "conectado", timeout=TIEMPO)
        huella = ana.controller._cliente._huella_esperada

        class_id = docente.classId
        docente.detenerClase()
        qtbot.waitUntil(lambda: ana.controller.estado == "reconectando", timeout=TIEMPO)
        assert docente.abrirClase(class_id) and docente.puerto == puerto

        qtbot.waitUntil(lambda: ana.controller.estado == "conectado", timeout=TIEMPO)
        assert ana.controller._cliente._huella_esperada == huella
        qtbot.waitUntil(lambda: docente.conectados == 1, timeout=TIEMPO)
    finally:
        docente.detenerClase()


def test_archivo_tvclase_sin_red(qtbot, tmp_path, docente, puerto_udp):
    assert docente.crearClase("Inteligencia Artificial", "", False, False)
    sin_red = _Alumno(tmp_path, "mar", puerto_udp)
    _completar_evaluacion(sin_red.evaluacion, "module_1", "pre")
    ruta = sin_red.controller.exportarAvance(str(tmp_path / "mar"), docente.codigo, "Mar")
    assert ruta.endswith(".tvclase")

    con_red = _Alumno(tmp_path, "ana", puerto_udp)
    _unir(qtbot, con_red, docente, "Ana")
    _completar_evaluacion(con_red.evaluacion, "module_1", "pre")
    qtbot.waitUntil(lambda: con_red.controller.pendientes == 0, timeout=TIEMPO)
    firmado = con_red.controller.exportarAvance(str(tmp_path / "ana.tvclase"), "", "")

    resumen = docente.importarArchivos([ruta, firmado])
    assert "Mar (sin verificar), 1 evaluación(es) nueva(s)" in resumen
    assert "Ana, 0 evaluación(es) nueva(s)" in resumen
    qtbot.waitUntil(lambda: docente.totalAlumnos == 2, timeout=TIEMPO)
    csv = docente.exportarCsv(str(tmp_path / "clase"))
    assert csv.endswith(".csv")
    analisis = docente.analisisModulo("module_1")
    assert analisis["with_pre"] == 2
