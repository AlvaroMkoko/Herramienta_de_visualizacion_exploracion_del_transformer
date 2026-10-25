"""Reglas del aula conectada, sin red ni Qt."""

from __future__ import annotations

import json

import pytest

from model.aprendizaje.module_question_bank import ModuleQuestionBank
from model.aula import analisis
from model.aula import protocolo as p
from model.aula.apodos import ApodoInvalido, sugerir_apodo, validar_apodo
from model.aula.archivo_clase import ArchivoInvalido, crear_paquete, guardar_paquete, leer_paquete
from model.aula.codigo_clase import formatear_codigo, generar_codigo, huella_codigo, normalizar_codigo
from model.aula.estado_alumno import EstadoAlumnoAula
from model.aula.repositorio_clase import RepositorioClase
from model.aula.sesion_clase import TODOS, SesionClase
from model.evaluacion.results_repository import ResultsRepository


def _clase(tmp_path, **opciones) -> SesionClase:
    repo = RepositorioClase.crear(tmp_path / "clases", "Redes neuronales", "6CV1", **opciones)
    return SesionClase(repo, frozenset({"pendejo"}))


def _enviar(sesion: SesionClase, conexion: str, tipo: str, **campos):
    return sesion.procesar(conexion, p.codificar(p.mensaje(tipo, **campos)))


def _unir(sesion: SesionClase, conexion: str, apodo: str, **extra):
    sesion.conectar(conexion, extra.pop("origen", "10.0.0." + conexion[-1]))
    envios = _enviar(
        sesion, conexion, "hola", codigo=sesion.repo.codigo, apodo=apodo,
        device_id="dev-" + conexion, **extra,
    )
    return envios[-1].mensaje


def _resultado(result_id: str, tipo: str, pct: float, modulo: str = "module_1", answers=None):
    return {
        "result_id": result_id,
        "schema_version": 2,
        "assessment_type": tipo,
        "module_id": modulo,
        # Los resultados de módulo siempre traen la versión del instrumento.
        "instrument_version": ModuleQuestionBank.VERSION_PREGUNTAS,
        "percentage": pct,
        "student_id": "__self__",
        "completed_at": f"2026-10-07T10:00:0{1 if tipo == 'pre' else 2}+00:00",
        "answers": answers or [],
    }


# ---------------------------------------------------------------------------
# Código y apodos
# ---------------------------------------------------------------------------

def test_codigo_tolera_confusiones_al_escribirlo():
    codigo = generar_codigo()
    assert normalizar_codigo(formatear_codigo(codigo).lower()) == codigo
    assert normalizar_codigo("k0p-1qx") == normalizar_codigo("KOP IQX") == "K0P1QX"
    assert normalizar_codigo("ABC") == ""
    assert huella_codigo("k0p-1qx") == huella_codigo("K0P1QX")


def test_apodo_valida_longitud_caracteres_y_palabras():
    assert validar_apodo("  Ana   López ") == "Ana López"
    for malo in ("A", "x" * 21, "Ana<script>", ""):
        with pytest.raises(ApodoInvalido):
            validar_apodo(malo)
    with pytest.raises(ApodoInvalido):
        validar_apodo("El Pendejo", frozenset({"pendejo"}))
    assert sugerir_apodo("Ana", ["ana", "ANA2"]) == "Ana3"


# ---------------------------------------------------------------------------
# Sesión: unión, reconexión y control del docente
# ---------------------------------------------------------------------------

def test_consulta_revela_lo_que_pide_la_clase_solo_con_codigo_correcto(tmp_path):
    sesion = _clase(tmp_path, pedir_matricula=True)
    sesion.conectar("c1", "10.0.0.1")
    malo = _enviar(sesion, "c1", "consulta", codigo="ZZZZZZ")[0].mensaje
    assert malo["motivo"] == p.CODIGO_INVALIDO
    info = _enviar(sesion, "c1", "consulta", codigo=formatear_codigo(sesion.repo.codigo))[0].mensaje
    assert info["tipo"] == "info_clase"
    assert info["clase"]["pedir_matricula"] is True
    assert "secreto" not in json.dumps(info)


def test_apodo_duplicado_se_rechaza_con_sugerencia(tmp_path):
    sesion = _clase(tmp_path)
    assert _unir(sesion, "c1", "Ana")["tipo"] == "bienvenida"
    rechazo = _unir(sesion, "c2", "  ána ")
    assert rechazo["motivo"] == p.APODO_EN_USO
    assert rechazo["sugerencia"] == "ána2"


def test_matricula_obligatoria_si_la_clase_la_pide(tmp_path):
    sesion = _clase(tmp_path, pedir_matricula=True)
    assert _unir(sesion, "c1", "Ana")["motivo"] == p.MATRICULA_REQUERIDA
    sesion.conectar("c2", "10.0.0.2")
    ok = _enviar(sesion, "c2", "hola", codigo=sesion.repo.codigo, apodo="Ana", matricula="2021630001")
    assert ok[0].mensaje["tipo"] == "bienvenida"
    assert sesion.repo.alumnos()[0]["matricula"] == "2021630001"


def test_reconexion_con_token_conserva_identidad_y_cierra_la_conexion_vieja(tmp_path):
    sesion = _clase(tmp_path)
    bienvenida = _unir(sesion, "c1", "Ana")
    sesion.conectar("c2", "10.0.0.2")
    envios = _enviar(
        sesion, "c2", "hola", codigo=sesion.repo.codigo, apodo="otro",
        alumno_id=bienvenida["alumno_id"], token=bienvenida["token"],
    )
    assert envios[0].destino == "c1" and envios[0].cerrar
    assert envios[0].mensaje["tipo"] == "sesion_reemplazada"
    assert envios[1].mensaje["tipo"] == "bienvenida"
    assert envios[1].mensaje["apodo"] == "Ana"
    assert len(sesion.repo.alumnos()) == 1


def test_codigo_incorrecto_repetido_cierra_la_conexion(tmp_path):
    sesion = _clase(tmp_path)
    sesion.conectar("c1", "10.0.0.1")
    envios = []
    for _ in range(5):
        envios = _enviar(sesion, "c1", "consulta", codigo="ZZZZZZ")
    assert envios[-1].cerrar
    assert _enviar(sesion, "c1", "consulta", codigo=sesion.repo.codigo)[0].mensaje["motivo"] == p.DEMASIADOS_INTENTOS


def test_sala_de_espera_requiere_aprobacion(tmp_path):
    sesion = _clase(tmp_path, aprobar_ingresos=True)
    espera = _unir(sesion, "c1", "Ana")
    assert espera["tipo"] == "en_espera"
    bloqueado = _enviar(sesion, "c1", "progreso", snapshot={}, generado_en="x")
    assert bloqueado[0].mensaje["motivo"] == p.NO_UNIDO
    aprobado = sesion.aprobar(espera["alumno_id"])
    assert aprobado[0].destino == "c1" and aprobado[0].mensaje["tipo"] == "bienvenida"


def test_rechazar_pendiente_lo_elimina(tmp_path):
    sesion = _clase(tmp_path, aprobar_ingresos=True)
    espera = _unir(sesion, "c1", "Ana")
    envios = sesion.rechazar(espera["alumno_id"])
    assert envios[0].cerrar
    assert sesion.repo.alumnos() == []


def test_resultados_se_reasignan_al_alumno_y_no_se_duplican(tmp_path):
    sesion = _clase(tmp_path)
    bienvenida = _unir(sesion, "c1", "Ana")
    resultado = _resultado("r1", "pre", 40.0)
    primero = _enviar(sesion, "c1", "resultado", resultado=resultado)[0].mensaje
    segundo = _enviar(sesion, "c1", "resultado", resultado=resultado)[0].mensaje
    assert primero["resultados"] == ["r1"] == segundo["resultados"]
    guardados = sesion.repo.resultados_de(bienvenida["alumno_id"])
    assert len(guardados) == 1
    assert guardados[0]["student"]["apodo"] == "Ana"
    assert guardados[0]["student"]["origen"] == "aula"


def test_expulsado_no_puede_volver(tmp_path):
    sesion = _clase(tmp_path)
    bienvenida = _unir(sesion, "c1", "Ana")
    assert sesion.expulsar(bienvenida["alumno_id"])[0].cerrar
    sesion.conectar("c2", "10.0.0.2")
    envios = _enviar(
        sesion, "c2", "hola", codigo=sesion.repo.codigo, apodo="Ana",
        alumno_id=bienvenida["alumno_id"], token=bienvenida["token"],
    )
    assert envios[-1].mensaje["motivo"] == p.EXPULSADO
    # El apodo de un expulsado queda libre.
    assert _unir(sesion, "c3", "Ana")["tipo"] == "bienvenida"


def test_renombrar_avisa_al_alumno_y_valida_unicidad(tmp_path):
    sesion = _clase(tmp_path)
    ana = _unir(sesion, "c1", "Ana")
    _unir(sesion, "c2", "Luis")
    envios = sesion.renombrar(ana["alumno_id"], "Ana G")
    assert envios[0].mensaje == p.mensaje("renombrado", apodo="Ana G")
    with pytest.raises(ApodoInvalido):
        sesion.renombrar(ana["alumno_id"], "luis")


def test_avisos_y_configuracion_van_a_todos_los_activos(tmp_path):
    sesion = _clase(tmp_path, aprobar_ingresos=True)
    ana = _unir(sesion, "c1", "Ana")
    _unir(sesion, "c2", "Luis")
    sesion.aprobar(ana["alumno_id"])
    assert sesion.aviso("  Empiecen   el módulo 2 ")[0].destino == TODOS
    assert sesion.destinatarios() == ["c1"]
    envio = sesion.configurar(modulos_habilitados=["module_1"])[0]
    assert envio.mensaje["clase"]["modulos_habilitados"] == ["module_1"]


def test_clase_finalizada_rechaza_nuevos_ingresos(tmp_path):
    sesion = _clase(tmp_path)
    assert sesion.finalizar()[0].cerrar
    assert _unir(sesion, "c1", "Ana")["motivo"] == p.CLASE_FINALIZADA


def test_version_de_protocolo_distinta_se_rechaza(tmp_path):
    sesion = _clase(tmp_path)
    sesion.conectar("c1", "x")
    envio = sesion.procesar("c1", json.dumps({"v": 99, "tipo": "hola"}))[0]
    assert envio.mensaje["motivo"] == p.VERSION_INCOMPATIBLE and envio.cerrar


# ---------------------------------------------------------------------------
# Archivos .tvclase
# ---------------------------------------------------------------------------

def test_archivo_firmado_se_importa_y_detecta_modificaciones(tmp_path):
    sesion = _clase(tmp_path)
    ana = _unir(sesion, "c1", "Ana")
    paquete = crear_paquete(
        {"alumno_id": ana["alumno_id"], "apodo": "Ana", "device_id": "dev-c1"},
        ana["clase"],
        {"modules": {"module_1": {"guided_completed": True}}},
        [_resultado("r9", "post", 90.0)],
        "2026-10-07T12:00:00+00:00",
        token=ana["token"],
    )
    ruta = guardar_paquete(tmp_path / "ana", paquete)
    assert ruta.suffix == ".tvclase"
    resumen = sesion.importar_paquete(leer_paquete(ruta))
    assert resumen["resultados_nuevos"] == 1 and resumen["verificado"]
    assert sesion.importar_paquete(leer_paquete(ruta))["resultados_nuevos"] == 0

    paquete["resultados"][0]["percentage"] = 100.0
    with pytest.raises(ArchivoInvalido):
        sesion.importar_paquete(paquete)


def test_archivo_sin_conexion_previa_se_importa_sin_verificar(tmp_path):
    sesion = _clase(tmp_path)
    paquete = crear_paquete(
        {"apodo": "Mar", "device_id": "dev-x"},
        {"codigo": formatear_codigo(sesion.repo.codigo)},
        {},
        [_resultado("r1", "pre", 30.0)],
        "2026-10-07T12:00:00+00:00",
    )
    primero = sesion.importar_paquete(paquete)
    segundo = sesion.importar_paquete(paquete)
    assert primero["nuevo"] and not primero["verificado"]
    assert segundo["alumno_id"] == primero["alumno_id"]
    assert len(sesion.repo.alumnos()) == 1


def test_archivo_de_otra_clase_se_rechaza(tmp_path):
    sesion = _clase(tmp_path)
    paquete = crear_paquete({"apodo": "Mar"}, {"codigo": "ZZZZZZ"}, {}, [], "x")
    with pytest.raises(ArchivoInvalido):
        sesion.importar_paquete(paquete)


def test_progreso_viejo_no_pisa_al_reciente(tmp_path):
    repo = RepositorioClase.crear(tmp_path, "C")
    assert repo.guardar_progreso("al-1", {"n": 2}, "2026-10-07T12:00:00")
    assert not repo.guardar_progreso("al-1", {"n": 1}, "2026-10-06T12:00:00")
    assert repo.snapshot_de("al-1") == {"n": 2}


# ---------------------------------------------------------------------------
# Estado local del alumno, resultados y análisis
# ---------------------------------------------------------------------------

def test_estado_del_alumno_calcula_pendientes_y_conserva_device_id(tmp_path):
    estado = EstadoAlumnoAula(tmp_path / "mi_clase.json")
    device = estado.device_id
    estado.registrar_union(
        {"alumno_id": "al-1", "token": "t", "apodo": "Ana", "clase": {"class_id": "c"}}
    )
    resultados = [{"result_id": "a"}, {"result_id": "b"}]
    estado.confirmar(["a"])
    recargado = EstadoAlumnoAula(tmp_path / "mi_clase.json")
    assert recargado.unido and recargado.device_id == device
    assert recargado.pendientes(resultados) == [{"result_id": "b"}]
    recargado.salir()
    assert not recargado.unido and recargado.device_id == device


def test_repositorio_asigna_ids_a_resultados_antiguos_de_forma_estable(tmp_path):
    ruta = tmp_path / "resultados.json"
    ruta.write_text(
        json.dumps({"version": 2, "results": [{"schema_version": 2, "assessment_type": "pre"}]}),
        encoding="utf-8",
    )
    primero = ResultsRepository(ruta).get_history()[0]["result_id"]
    assert primero and ResultsRepository(ruta).get_history()[0]["result_id"] == primero
    nuevo = {"assessment_type": "post", "schema_version": 2}
    ResultsRepository(ruta).save_result(nuevo)
    assert nuevo["result_id"]


def test_analisis_de_modulo_promedia_solo_pares_completos():
    modulo = {"id": "module_1", "title": "Tokens", "concepts": [{"id": "tok", "title": "Tokenización"}]}
    fallo = [{"question_id": "q1", "concept_id": "tok", "correcto": False, "prompt": "¿?"}]
    alumnos = [
        ({"alumno_id": "a", "apodo": "Ana"}, [_resultado("1", "pre", 40), _resultado("2", "post", 80, answers=fallo)]),
        ({"alumno_id": "b", "apodo": "Luis"}, [_resultado("3", "pre", 60)]),
    ]
    datos = analisis.analisis_modulo(modulo, alumnos)
    assert datos["avg_pre"] == 50.0 and datos["avg_post"] == 80.0
    assert datos["avg_delta"] == 40.0 and datos["with_both"] == 1
    assert datos["concept_errors"][0] == {"concept_id": "tok", "name": "Tokenización", "count": 1}
    csv = analisis.exportar_csv(alumnos)
    assert csv.splitlines()[0].startswith("alumno_id,apodo")
    assert len(csv.splitlines()) == 4


def test_resumen_de_alumno_reproduce_estados_del_curso():
    snapshot = {"modules": {"module_1": {"guided_completed": True, "laboratory_completed": True, "results_viewed": True}}}
    resultados = [_resultado("1", "pre", 40), _resultado("2", "post", 60)]
    resumen = analisis.resumen_alumno(["module_1", "module_2"], snapshot, resultados)
    assert resumen["modules"][0]["status"] == "review_recommended"
    assert resumen["modules"][1]["status"] == "not_started"
    assert resumen["global_percent"] == 50


# ---------------------------------------------------------------------------
# Análisis de reactivos y práctica
# ---------------------------------------------------------------------------

def _respuesta(code: str, puntaje: float) -> dict:
    return {"code": code, "concept_id": "tok", "prompt": f"Reactivo {code}",
            "puntaje": puntaje, "maximo": 1.0, "correcto": puntaje == 1.0}


def test_analisis_de_reactivos_marca_techo_falta_de_ganancia_y_discriminacion():
    modulo = {"id": "module_1", "title": "Entrada", "concepts": [{"id": "tok", "title": "Tokenización"}]}
    alumnos = []
    # A1: todos aciertan desde el pre (techo). A2: mejora y discrimina.
    for indice, total in enumerate((20, 40, 60, 80)):
        acierta_post = indice >= 2
        alumnos.append((
            {"alumno_id": f"a{indice}", "apodo": f"A{indice}"},
            [
                _resultado(f"p{indice}", "pre", total, answers=[_respuesta("A1", 1.0), _respuesta("A2", 0.0)]),
                _resultado(f"q{indice}", "post", total + 10,
                           answers=[_respuesta("A1", 1.0), _respuesta("A2", 1.0 if acierta_post else 0.0)]),
            ],
        ))

    filas = {fila["code"]: fila for fila in analisis.analisis_reactivos("module_1", alumnos)}

    assert filas["A1"]["p_pre"] == 1.0 and "Casi todos aciertan en el pre-test" in filas["A1"]["flags"]
    assert "No mejora entre pre y post" in filas["A1"]["flags"]
    assert filas["A2"]["gain"] == 0.5 and filas["A2"]["d_post"] == 1.0
    assert filas["A2"]["flags"] == []

    datos = analisis.analisis_modulo(modulo, alumnos)
    assert datos["item_analysis"] and datos["avg_normalized_gain"] is not None


def test_ganancia_normalizada_e_interaccion_por_alumno():
    assert analisis.ganancia_normalizada(20, 60) == 0.5
    assert analisis.ganancia_normalizada(100, 100) is None

    modulo = {"id": "module_1", "title": "Entrada", "concepts": []}
    alumnos = [({"alumno_id": "a", "apodo": "Ana"},
                [_resultado("1", "pre", 50), _resultado("2", "post", 75)])]
    snapshots = {"a": {"modules": {"module_1": {
        "guided_checks": {"m1_s1": {"attempts": 2, "first_correct": False},
                          "m1_s2": {"attempts": 1, "first_correct": True}},
        "lab_cycles": [{"step_id": "tokens", "prediction_correct": True},
                       {"step_id": "tokens", "prediction_correct": False},
                       {"step_id": "ids", "prediction_correct": True}],
        "retention": {"m1_l2": {"correct": True}},
    }}}}

    fila = analisis.analisis_modulo(modulo, alumnos, snapshots)["rows"][0]

    assert fila["normalized_gain"] == 0.5
    assert fila["interaction"] == {
        "guided_checks": 2, "guided_first_correct": 1,
        "lab_cycles": 2, "lab_predictions_correct": 2,
        "retention_correct": 1, "retention_total": 1,
    }


def test_el_docente_ve_el_primer_intento_y_cuantas_veces_lo_tomo():
    """Misma regla que CourseController: el primer intento es la medición; las
    repeticiones se cuentan pero no la reemplazan."""
    modulo = {"id": "module_1", "title": "Tokens", "concepts": []}
    # El más antiguo por fecha no es ni el primero ni el último de la lista:
    # así la prueba distingue «primer intento» de «primero/último guardado».
    repetido = dict(_resultado("3", "pre", 95), completed_at="2026-10-07T10:00:09+00:00")
    tardio = dict(_resultado("4", "pre", 70), completed_at="2026-10-07T10:00:05+00:00")
    resultados = [repetido, _resultado("1", "pre", 40), tardio, _resultado("2", "post", 80)]

    estado = analisis.estado_modulo("module_1", {}, resultados)
    assert estado["pre_percentage"] == 40.0
    assert estado["pre_attempts"] == 3 and estado["post_attempts"] == 1

    fila = analisis.analisis_modulo(modulo, [({"alumno_id": "a"}, resultados)])["rows"][0]
    assert fila["pre_percentage"] == 40.0 and fila["delta"] == 40.0
    assert fila["pre_attempts"] == 3


def test_el_aula_no_resta_pre_y_post_de_versiones_distintas():
    """Caso real: el banco modular pasó de v8 a v9. Un pre v8 más antiguo no
    puede ser el «primer intento» de un par con un post v9."""
    vigente = ModuleQuestionBank.VERSION_PREGUNTAS
    modulo = {"id": "module_1", "title": "Tokens", "concepts": []}
    viejo = dict(_resultado("1", "pre", 20), instrument_version=vigente - 1,
                 completed_at="2026-10-07T09:00:00+00:00")
    con_par = [viejo, _resultado("2", "pre", 50), _resultado("3", "post", 80)]
    sin_par = [viejo, _resultado("4", "post", 80)]

    datos = analisis.analisis_modulo(
        modulo, [({"alumno_id": "a"}, con_par), ({"alumno_id": "b"}, sin_par)]
    )

    fila_a, fila_b = datos["rows"]
    assert fila_a["pre_percentage"] == 50.0 and fila_a["delta"] == 30.0
    assert fila_b["delta"] is None and fila_b["comparable"] is False
    assert fila_b["normalized_gain"] is None
    assert datos["avg_delta"] == 30.0 and datos["with_both"] == 1
    # Los promedios no mezclan el pre v8 del alumno b con los v9.
    assert datos["avg_pre"] == 50.0 and datos["with_pre"] == 1


def test_errores_frecuentes_solo_del_post_vigente():
    vigente = ModuleQuestionBank.VERSION_PREGUNTAS
    modulo = {"id": "module_1", "title": "Tokens", "concepts": [{"id": "tok", "title": "Tok"}]}
    fallo = [{"question_id": "viejo", "concept_id": "tok", "correcto": False, "prompt": "¿?"}]
    post_viejo = dict(_resultado("1", "post", 40, answers=fallo), instrument_version=vigente - 1)

    datos = analisis.analisis_modulo(modulo, [({"alumno_id": "a"}, [post_viejo])])

    assert datos["question_errors"] == [] and datos["concept_errors"] == []
    assert datos["outside_current_version"] == 1 and datos["avg_post"] is None
