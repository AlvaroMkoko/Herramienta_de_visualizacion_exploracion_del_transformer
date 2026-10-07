"""Reglas del aula conectada, sin red ni Qt."""

from __future__ import annotations

import json

import pytest

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
