"""Contratos de las presentaciones del instrumento v3.

El banco declara dos ejes por reactivo: `tipo` (qué forma tiene la respuesta que
espera el modelo) y `presentacion` (cómo se dibuja y se toca). Estas pruebas
cubren el punto donde los dos ejes se encuentran, que es justo donde el proyecto
ya se rompió una vez: un componente puede verse perfecto y producir una
respuesta que el calificador no entiende, sin que nada falle a la vista.

Por eso casi todas las pruebas terminan en `calificar()`: se manipula el
componente como lo haría el estudiante y se comprueba que la estructura que sale
de la vista puntúa en el modelo. No se comprueban colores ni tamaños.
"""

from __future__ import annotations

import os
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

import pytest
from PySide6.QtCore import Q_ARG, QMetaObject, QObject, Qt, QUrl
from PySide6.QtQml import QJSValue, QQmlComponent, QQmlEngine, QQmlExpression

from model.evaluacion.question_bank import QuestionBank
from model.evaluacion.scorers import calificar, es_respuesta_completa

PROJECT_ROOT = Path(__file__).resolve().parents[2]
QML_ROOT = PROJECT_ROOT / "view" / "qml"

# Presentación -> componente que debe dibujarla. Es la misma tabla que
# `componentePara` en EvaluationScreen.qml, escrita aquí a mano a propósito:
# si alguien agrega una presentación al banco y olvida registrarla en la
# pantalla, esta tabla y el banco dejan de coincidir y la prueba lo dice.
COMPONENTE_POR_PRESENTACION = {
    "tarjetas": "ReactivoOpcionUnica",
    "tarjetas_con_escenario": "ReactivoOpcionUnica",
    "heatmap_clic": "ReactivoOpcionUnica",
    "chips_toggle": "ReactivoSeleccionMultiple",
    "caja_en_linea": "ReactivoTexto",
    "lista_arrastrable": "ReactivoOrdenar",
    "cestas": "ReactivoCestas",
    "lineas_o_tocar_para_emparejar": "ReactivoRelacionar",
    "pasos": "ReactivoEtapas",
    "botones_vf_acordeon": "ReactivoEtapas",
    "fragmentos_clicables": "ReactivoFragmentos",
}

# El instrumento tiene un reactivo paralelo por forma; uno puede estar mal
# redactado sin que el otro lo esté, así que se prueban los dos.
AMBAS_FORMAS = pytest.mark.parametrize("assessment_type", ["pre", "post"])

# Mantiene con vida los componentes creados durante el módulo.
_VIVOS: list = []


@pytest.fixture(scope="module")
def engine(qapp):
    # `qapp` es obligatorio: un QQmlEngine sin QGuiApplication viva aborta el
    # proceso entero, no lanza una excepción.
    motor = QQmlEngine()
    motor.addImportPath(str(QML_ROOT))
    yield motor
    motor.deleteLater()


@pytest.fixture(scope="module")
def bank() -> QuestionBank:
    return QuestionBank()


def _crear(engine: QQmlEngine, nombre: str) -> QObject:
    """Instancia un componente Reactivo* suelto, sin la pantalla alrededor."""
    ruta = QML_ROOT / "components" / f"{nombre}.qml"
    componente = QQmlComponent(engine, QUrl.fromLocalFile(str(ruta)))
    errores = "\n".join(error.toString() for error in componente.errors())
    assert componente.status() == QQmlComponent.Status.Ready, errores
    objeto = componente.create()
    assert objeto is not None, errores
    # El motor QML es dueño de lo que crea y lo recoge en cuanto Python suelta
    # la última referencia: sin esto, el objeto muere a mitad de la prueba con
    # «Internal C++ object already deleted».
    QQmlEngine.setObjectOwnership(objeto, QQmlEngine.ObjectOwnership.CppOwnership)
    _VIVOS.append((componente, objeto))
    return objeto


def _valor(objeto: QObject, nombre: str):
    """Lee una propiedad `var` de QML ya convertida a tipos de Python.

    Una propiedad declarada `var` llega a Python envuelta en un QJSValue, que
    no es ni una lista ni un diccionario. Es el mismo desenvuelto que hace
    `_a_python()` en EvaluationController; si se olvida, la prueba falla con
    «'QJSValue' object is not iterable» aunque la vista esté bien.
    """
    valor = objeto.property(nombre)
    return valor.toVariant() if isinstance(valor, QJSValue) else valor


def _llamar(objeto: QObject, metodo: str, *argumentos) -> None:
    args = [Q_ARG("QVariant", valor) for valor in argumentos]
    invocado = QMetaObject.invokeMethod(
        objeto, metodo, Qt.ConnectionType.DirectConnection, *args
    )
    assert invocado, f"No se pudo invocar {metodo} en {objeto}"


def _reactivo(bank: QuestionBank, assessment_type: str, presentacion: str) -> dict:
    for question in bank.get_questions(assessment_type):
        if question.get("presentacion") == presentacion:
            return question
    raise AssertionError(f"El banco no tiene ningún reactivo «{presentacion}»")


def _publico(bank: QuestionBank, question: dict) -> dict:
    return QuestionBank.public_question(question)


# ── El puente entre los dos ejes ────────────────────────────────────────

def test_toda_presentacion_del_banco_tiene_componente_registrado(bank):
    """Una presentación sin componente cae al respaldo por tipo y se ve
    genérica, sin que nada falle: es exactamente el tipo de regresión que
    nadie nota hasta la aplicación piloto."""
    for assessment_type in ("pre", "post"):
        for question in bank.get_questions(assessment_type):
            presentacion = question.get("presentacion")
            assert presentacion in COMPONENTE_POR_PRESENTACION, (
                f"{question['code']} declara la presentación «{presentacion}», "
                "que ninguna vista dibuja"
            )


@pytest.mark.parametrize("presentacion", sorted(COMPONENTE_POR_PRESENTACION))
def test_cada_componente_acepta_su_reactivo_sin_errores(engine, bank, presentacion):
    nombre = COMPONENTE_POR_PRESENTACION[presentacion]
    question = _reactivo(bank, "pre", presentacion)
    objeto = _crear(engine, nombre)
    # Asignar la pregunta es lo que dispara restaurar() y reevalúa los enlaces
    # derivados: si algo revienta ahí, el objeto se queda sin altura.
    objeto.setProperty("pregunta", _publico(bank, question))
    assert objeto.property("implicitHeight") is not None


def test_la_pantalla_despacha_por_presentacion_y_no_por_tipo(engine):
    """A3 y F2 son ambos de tipo «etapas» y deben ir a componentes distintos:
    es la prueba de que el despacho mira la presentación."""
    ruta = QML_ROOT / "screens" / "EvaluationScreen.qml"
    componente = QQmlComponent(engine, QUrl.fromLocalFile(str(ruta)))
    errores = "\n".join(error.toString() for error in componente.errors())
    assert componente.status() == QQmlComponent.Status.Ready, errores
    assert COMPONENTE_POR_PRESENTACION["fragmentos_clicables"] != \
        COMPONENTE_POR_PRESENTACION["botones_vf_acordeon"]


# ── caja_en_linea (T1) ──────────────────────────────────────────────────

def test_la_caja_en_linea_parte_la_oracion_en_el_hueco(engine, bank):
    question = _reactivo(bank, "pre", "caja_en_linea")
    objeto = _crear(engine, "ReactivoTexto")
    objeto.setProperty("pregunta", _publico(bank, question))

    antes = _valor(objeto, "palabrasAntes")
    despues = _valor(objeto, "palabrasDespues")

    assert antes and despues, "La oración debe quedar partida a ambos lados"
    # Las palabras reconstruyen el enunciado sin la marca del hueco.
    reconstruido = " ".join(list(antes) + list(despues))
    assert "_" not in reconstruido
    assert "algoritmo" in reconstruido


def test_la_caja_en_linea_sin_hueco_no_pierde_el_enunciado(engine):
    """Si alguien reescribe el reactivo y quita los guiones bajos, la pregunta
    debe seguir leyéndose: el campo se va al final, pero el texto no se borra."""
    objeto = _crear(engine, "ReactivoTexto")
    objeto.setProperty("pregunta", {"prompt": "Nombra el algoritmo de subpalabras"})

    antes = list(_valor(objeto, "palabrasAntes"))
    assert _valor(objeto, "palabrasDespues") == []
    assert "algoritmo" in " ".join(antes)


@AMBAS_FORMAS
def test_lo_escrito_en_la_caja_puntua_en_el_modelo(engine, bank, assessment_type):
    question = _reactivo(bank, assessment_type, "caja_en_linea")
    objeto = _crear(engine, "ReactivoTexto")
    objeto.setProperty("pregunta", _publico(bank, question))

    campo = objeto.findChild(QObject, "evaluationTextAnswer")
    assert campo is not None
    campo.setProperty("text", "BPE")

    resultado = calificar(question, {"texto": campo.property("text")})
    assert resultado["correcto"] is True
    assert resultado["puntaje"] == pytest.approx(1.0)


# ── fragmentos_clicables (A3) ───────────────────────────────────────────

def test_los_fragmentos_se_extraen_del_enunciado(engine, bank):
    question = _reactivo(bank, "pre", "fragmentos_clicables")
    objeto = _crear(engine, "ReactivoFragmentos")
    objeto.setProperty("pregunta", _publico(bank, question))

    assert objeto.property("enunciadoParseado") is True
    palabras = list(_valor(objeto, "palabras"))
    hallados = {p["fragmentoId"] for p in palabras if p["fragmentoId"]}
    declarados = {str(f["id"]) for f in question["fragmentos"]}
    assert hallados == declarados

    # Ninguna palabra conserva la marca «[2]»: el número vive en la insignia.
    assert not any("[" in p["texto"] for p in palabras)
    # Y el primer trozo, el texto conectivo, no pertenece a ningún fragmento.
    assert palabras[0]["fragmentoId"] == ""


@AMBAS_FORMAS
def test_el_texto_de_cada_fragmento_coincide_con_el_declarado(
    engine, bank, assessment_type
):
    """Si la redacción del enunciado y la lista `fragmentos` se separan, el
    respaldo mostraría tramos distintos de los que se pueden tocar."""
    question = _reactivo(bank, assessment_type, "fragmentos_clicables")
    objeto = _crear(engine, "ReactivoFragmentos")
    objeto.setProperty("pregunta", _publico(bank, question))

    reconstruido: dict[str, list[str]] = {}
    for palabra in _valor(objeto, "palabras"):
        if palabra["fragmentoId"]:
            reconstruido.setdefault(palabra["fragmentoId"], []).append(
                palabra["texto"]
            )

    for fragmento in question["fragmentos"]:
        esperado = str(fragmento["texto"])
        obtenido = " ".join(reconstruido[str(fragmento["id"])])
        # El enunciado lleva la puntuación que une los tramos; se compara el
        # texto sin ella.
        assert obtenido.rstrip(",.;»").strip() == esperado.rstrip(",.;»").strip()


@AMBAS_FORMAS
def test_tocar_un_fragmento_produce_la_respuesta_que_espera_el_calificador(
    engine, bank, assessment_type
):
    question = _reactivo(bank, assessment_type, "fragmentos_clicables")
    publico = _publico(bank, question)
    objeto = _crear(engine, "ReactivoFragmentos")
    objeto.setProperty("pregunta", publico)

    deteccion, correccion = question["etapas"]
    _llamar(objeto, "elegirFragmento", deteccion["correct_option_id"])
    _llamar(objeto, "elegirCorreccion", correccion["correct_option_id"])

    respuesta = {"etapas": dict(_valor(objeto, "respuestasEtapas"))}
    resultado = calificar(question, respuesta)
    assert resultado["puntaje"] == pytest.approx(1.0)
    assert resultado["correcto"] is True


@AMBAS_FORMAS
def test_la_correccion_no_se_muestra_antes_de_senalar_el_tramo(
    engine, bank, assessment_type
):
    """Cada corrección nombra el tramo que corrige: enseñarlas antes de que el
    estudiante señale delataría cuál es el fragmento erróneo."""
    question = _reactivo(bank, assessment_type, "fragmentos_clicables")
    objeto = _crear(engine, "ReactivoFragmentos")
    objeto.setProperty("pregunta", _publico(bank, question))

    assert objeto.property("fragmentoElegido") == ""
    bloque = objeto.findChild(QObject, "evaluationFragmentSentence")
    assert bloque is not None

    _llamar(objeto, "elegirFragmento", "1")
    assert objeto.property("fragmentoElegido") == "1"


@AMBAS_FORMAS
def test_detectar_sin_corregir_deja_credito_parcial(engine, bank, assessment_type):
    question = _reactivo(bank, assessment_type, "fragmentos_clicables")
    objeto = _crear(engine, "ReactivoFragmentos")
    objeto.setProperty("pregunta", _publico(bank, question))

    _llamar(objeto, "elegirFragmento", question["etapas"][0]["correct_option_id"])
    respuesta = {"etapas": dict(_valor(objeto, "respuestasEtapas"))}

    resultado = calificar(question, respuesta)
    assert resultado["puntaje"] == pytest.approx(0.5)
    assert resultado["correcto"] is False


@AMBAS_FORMAS
def test_el_reactivo_publico_no_lleva_las_claves_a_la_vista(bank, assessment_type):
    """La vista recibe `public_question`. Si una clave se colara, quedaría al
    alcance de cualquiera que inspeccione el objeto QML."""
    question = _reactivo(bank, assessment_type, "fragmentos_clicables")
    publico = _publico(bank, question)
    assert "correct_option_id" not in publico
    for etapa in publico["etapas"]:
        assert "correct_option_id" not in etapa
    # Pero los fragmentos sí viajan: son el enunciado, no la respuesta.
    assert len(publico["fragmentos"]) == 4


# ── pasos (A2) ──────────────────────────────────────────────────────────

def test_los_pasos_ocultan_la_razon_hasta_contestar_el_resultado(engine, bank):
    """A2 se puede resolver al revés: leer las razones, reconocer cuál suena a
    teoría conocida y deducir el resultado. La revelación progresiva cierra
    esa puerta."""
    question = _reactivo(bank, "pre", "pasos")
    objeto = _crear(engine, "ReactivoEtapas")
    objeto.setProperty("pregunta", _publico(bank, question))

    assert objeto.property("revelacionProgresiva") is True
    assert _etapa_visible(objeto, 0) is True
    assert _etapa_visible(objeto, 1) is False

    _llamar(objeto, "registrarEtapa", "e1", {"opcion_id": "c"})
    assert _etapa_visible(objeto, 1) is True


@AMBAS_FORMAS
def test_la_primera_etapa_se_bloquea_al_revelarse_la_segunda(
    engine, bank, assessment_type
):
    question = _reactivo(bank, assessment_type, "pasos")
    objeto = _crear(engine, "ReactivoEtapas")
    objeto.setProperty("pregunta", _publico(bank, question))

    assert _etapa_bloqueada(objeto, 0) is False
    _llamar(objeto, "registrarEtapa", "e1", {"opcion_id": "c"})
    assert _etapa_bloqueada(objeto, 0) is True
    # La etapa en curso nunca se bloquea a sí misma.
    assert _etapa_bloqueada(objeto, 1) is False


@AMBAS_FORMAS
def test_reabrir_la_primera_etapa_borra_la_segunda(engine, bank, assessment_type):
    """Se puede corregir un clic equivocado, pero no acomodar el resultado
    después de haber leído las razones: al reabrir, la razón se descarta."""
    question = _reactivo(bank, assessment_type, "pasos")
    objeto = _crear(engine, "ReactivoEtapas")
    objeto.setProperty("pregunta", _publico(bank, question))

    _llamar(objeto, "registrarEtapa", "e1", {"opcion_id": "c"})
    _llamar(objeto, "registrarEtapa", "e2", {"opcion_id": "a"})
    assert set(_valor(objeto, "respuestasEtapas")) == {"e1", "e2"}

    _llamar(objeto, "desbloquear", 0)
    assert set(_valor(objeto, "respuestasEtapas")) == {"e1"}
    assert _etapa_bloqueada(objeto, 0) is False


@AMBAS_FORMAS
def test_las_dos_etapas_de_pasos_puntuan_juntas(engine, bank, assessment_type):
    question = _reactivo(bank, assessment_type, "pasos")
    objeto = _crear(engine, "ReactivoEtapas")
    objeto.setProperty("pregunta", _publico(bank, question))

    for etapa in question["etapas"]:
        _llamar(objeto, "registrarEtapa", str(etapa["id"]),
                {"opcion_id": etapa["correct_option_id"]})

    respuesta = {"etapas": dict(_valor(objeto, "respuestasEtapas"))}
    assert calificar(question, respuesta)["puntaje"] == pytest.approx(1.0)


# ── botones_vf_acordeon (F2) ────────────────────────────────────────────

def test_el_acordeon_no_revela_ni_bloquea_nada(engine, bank):
    """F2 no exige todas las etapas: la justificación es opcional y el
    veredicto debe poder cambiarse mientras se escribe."""
    question = _reactivo(bank, "pre", "botones_vf_acordeon")
    objeto = _crear(engine, "ReactivoEtapas")
    objeto.setProperty("pregunta", _publico(bank, question))

    assert objeto.property("acordeonOpcional") is True
    assert objeto.property("revelacionProgresiva") is False
    assert objeto.property("exigirTodas") is False
    # Ambas etapas están disponibles desde el principio y ninguna se bloquea.
    assert _etapa_visible(objeto, 1) is True
    _llamar(objeto, "registrarEtapa", "e1", {"opcion_id": "verdadero"})
    assert _etapa_bloqueada(objeto, 0) is False


@AMBAS_FORMAS
def test_el_veredicto_puntua_sin_justificacion(engine, bank, assessment_type):
    question = _reactivo(bank, assessment_type, "botones_vf_acordeon")
    objeto = _crear(engine, "ReactivoEtapas")
    objeto.setProperty("pregunta", _publico(bank, question))

    _llamar(objeto, "registrarEtapa", "e1",
            {"opcion_id": question["etapas"][0]["correct_option_id"]})

    respuesta = {"etapas": dict(_valor(objeto, "respuestasEtapas"))}
    resultado = calificar(question, respuesta)
    assert resultado["puntaje"] == pytest.approx(1.0)


@AMBAS_FORMAS
def test_la_justificacion_escrita_no_cambia_el_puntaje(engine, bank, assessment_type):
    question = _reactivo(bank, assessment_type, "botones_vf_acordeon")
    objeto = _crear(engine, "ReactivoEtapas")
    objeto.setProperty("pregunta", _publico(bank, question))

    _llamar(objeto, "registrarEtapa", "e1",
            {"opcion_id": question["etapas"][0]["correct_option_id"]})
    sin_texto = calificar(
        question, {"etapas": dict(_valor(objeto, "respuestasEtapas"))}
    )["puntaje"]

    _llamar(objeto, "registrarEtapa", "e2", {"texto": "porque normaliza por token"})
    con_texto = calificar(
        question, {"etapas": dict(_valor(objeto, "respuestasEtapas"))}
    )["puntaje"]

    assert sin_texto == pytest.approx(con_texto)


# ── Utilidades ──────────────────────────────────────────────────────────

def _etapa_visible(objeto: QObject, indice: int) -> bool:
    return bool(_evaluar(objeto, f"etapaVisible({indice})"))


def _etapa_bloqueada(objeto: QObject, indice: int) -> bool:
    return bool(_evaluar(objeto, f"etapaBloqueada({indice})"))


def _evaluar(objeto: QObject, expresion_qml: str):
    """Evalúa una expresión en el contexto QML del objeto.

    QMetaObject.invokeMethod no recupera el valor de retorno de una función
    declarada en QML, así que la función se llama desde una expresión QML
    evaluada en el contexto del propio componente.
    """
    contexto = QQmlEngine.contextForObject(objeto)
    assert contexto is not None, "El objeto no tiene contexto QML"
    expresion = QQmlExpression(contexto, objeto, expresion_qml)
    valor, error = expresion.evaluate()
    assert not error, f"Error evaluando «{expresion_qml}»"
    return valor


# ── Asignación: ordenar, cestas y relacionar ────────────────────────────
#
# Las tres disposiciones heredan de AsignacionBase y comparten la máquina de
# estados, así que las reglas se prueban una vez por regla y se parametrizan
# por presentación cuando aplican a todas.

ASIGNACION = pytest.mark.parametrize(
    "presentacion",
    ["lista_arrastrable", "cestas", "lineas_o_tocar_para_emparejar"],
)

# Solo estas dos son biyectivas (`destinos_unicos: true`).
UNICOS = pytest.mark.parametrize(
    "presentacion", ["lista_arrastrable", "lineas_o_tocar_para_emparejar"]
)


def _montar(engine, bank, assessment_type, presentacion):
    question = _reactivo(bank, assessment_type, presentacion)
    objeto = _crear(engine, COMPONENTE_POR_PRESENTACION[presentacion])
    objeto.setProperty("pregunta", _publico(bank, question))
    return question, objeto


def _asignaciones(objeto: QObject) -> dict:
    return dict(_valor(objeto, "asignaciones"))


@ASIGNACION
def test_el_monton_empieza_lleno_y_la_respuesta_incompleta(engine, bank, presentacion):
    """Si el reactivo arrancara con todo repartido, el modelo lo daría por
    contestado y se podría avanzar sin tocar nada, entregando un reparto que
    nadie eligió."""
    question, objeto = _montar(engine, bank, "pre", presentacion)

    assert _asignaciones(objeto) == {}
    assert len(_valor(objeto, "pendientes")) == len(question["elementos"])
    assert objeto.property("completa") is False
    assert not es_respuesta_completa(question, {"asignaciones": {}})


@ASIGNACION
def test_tomar_y_soltar_coloca_el_elemento(engine, bank, presentacion):
    question, objeto = _montar(engine, bank, "pre", presentacion)
    elemento = str(question["elementos"][0]["id"])
    destino = str(question["destinos"][0]["id"])

    _llamar(objeto, "tomar", elemento)
    assert objeto.property("enMano") == elemento

    _llamar(objeto, "soltarEn", destino)
    assert _asignaciones(objeto) == {elemento: destino}
    # Soltar vacía la mano: si no, el siguiente toque movería el mismo elemento.
    assert objeto.property("enMano") == ""


@ASIGNACION
def test_tocar_una_ficha_colocada_la_devuelve_al_monton(engine, bank, presentacion):
    question, objeto = _montar(engine, bank, "pre", presentacion)
    elemento = str(question["elementos"][0]["id"])

    _llamar(objeto, "asignar", elemento, str(question["destinos"][0]["id"]))
    _llamar(objeto, "alternar", elemento)

    assert _asignaciones(objeto) == {}
    assert elemento in [str(e["id"]) for e in _valor(objeto, "pendientes")]


@ASIGNACION
@AMBAS_FORMAS
def test_colocar_todo_bien_puntua_completo(engine, bank, presentacion, assessment_type):
    question, objeto = _montar(engine, bank, assessment_type, presentacion)

    for elemento in question["elementos"]:
        _llamar(objeto, "asignar", str(elemento["id"]), str(elemento["correcto"]))

    assert objeto.property("completa") is True
    respuesta = {"asignaciones": _asignaciones(objeto)}
    assert es_respuesta_completa(question, respuesta)
    assert calificar(question, respuesta)["puntaje"] == pytest.approx(1.0)


@ASIGNACION
def test_el_credito_es_proporcional_a_los_aciertos(engine, bank, presentacion):
    """Se deja un elemento sin colocar en vez de mandarlo a un destino ajeno:
    con destinos únicos, ocupar un destino ya lleno desaloja al que estaba y
    fallarían dos elementos, no uno."""
    question, objeto = _montar(engine, bank, "pre", presentacion)
    elementos = question["elementos"]

    for elemento in elementos[1:]:
        _llamar(objeto, "asignar", str(elemento["id"]), str(elemento["correcto"]))

    respuesta = {"asignaciones": _asignaciones(objeto)}
    esperado = (len(elementos) - 1) / len(elementos)
    # `calificar` redondea a cuatro decimales, así que 5/6 llega como 0.8333.
    assert calificar(question, respuesta)["puntaje"] == pytest.approx(
        esperado, abs=1e-4
    )
    # Un elemento suelto deja la respuesta incompleta: no se puede avanzar.
    assert not es_respuesta_completa(question, respuesta)


@UNICOS
def test_mover_una_ficha_a_un_destino_ocupado_las_intercambia(
    engine, bank, presentacion
):
    """Con una biyección, arrastrar una ficha sobre otra debe cambiarlas de
    lugar. Si la desalojada se fuera al montón, corregir dos posiciones
    invertidas costaría cuatro movimientos en vez de uno."""
    question, objeto = _montar(engine, bank, "pre", presentacion)
    a, b = (str(e["id"]) for e in question["elementos"][:2])
    d1, d2 = (str(d["id"]) for d in question["destinos"][:2])

    _llamar(objeto, "asignar", a, d1)
    _llamar(objeto, "asignar", b, d2)
    _llamar(objeto, "asignar", a, d2)

    assert _asignaciones(objeto) == {a: d2, b: d1}


@UNICOS
def test_una_ficha_del_monton_desaloja_al_ocupante_hacia_el_monton(
    engine, bank, presentacion
):
    """La que llega del montón no tiene hueco que ofrecer a cambio, así que el
    ocupante vuelve al montón en vez de quedarse en un destino inventado."""
    question, objeto = _montar(engine, bank, "pre", presentacion)
    a, b = (str(e["id"]) for e in question["elementos"][:2])
    destino = str(question["destinos"][0]["id"])

    _llamar(objeto, "asignar", a, destino)
    _llamar(objeto, "asignar", b, destino)

    assert _asignaciones(objeto) == {b: destino}
    assert a in [str(e["id"]) for e in _valor(objeto, "pendientes")]


@UNICOS
def test_tocar_un_destino_ocupado_sin_nada_en_mano_recupera_su_ficha(
    engine, bank, presentacion
):
    question, objeto = _montar(engine, bank, "pre", presentacion)
    elemento = str(question["elementos"][0]["id"])
    destino = str(question["destinos"][0]["id"])

    _llamar(objeto, "asignar", elemento, destino)
    assert objeto.property("enMano") == ""

    _llamar(objeto, "soltarEn", destino)
    assert objeto.property("enMano") == elemento


def test_una_cesta_admite_varios_enunciados(engine, bank):
    """`destinos_unicos: false` es lo único que distingue a las cestas: si la
    base tratara E4 como biyectivo, cada enunciado expulsaría al anterior y el
    reactivo sería imposible de contestar."""
    question, objeto = _montar(engine, bank, "pre", "cestas")
    assert objeto.property("destinosUnicos") is False

    cesta = str(question["destinos"][0]["id"])
    tres = [str(e["id"]) for e in question["elementos"][:3]]
    for elemento in tres:
        _llamar(objeto, "asignar", elemento, cesta)

    assert sorted(_asignaciones(objeto)) == sorted(tres)
    assert all(_asignaciones(objeto)[e] == cesta for e in tres)


@ASIGNACION
def test_deshacer_todo_vacia_las_asignaciones(engine, bank, presentacion):
    question, objeto = _montar(engine, bank, "pre", presentacion)
    for elemento in question["elementos"]:
        _llamar(objeto, "asignar", str(elemento["id"]), str(elemento["correcto"]))

    _llamar(objeto, "limpiar")
    assert _asignaciones(objeto) == {}
    assert objeto.property("completa") is False


@UNICOS
@AMBAS_FORMAS
def test_la_posicion_no_alcanza_para_aprobar(bank, presentacion, assessment_type):
    """Validez del banco, no de la vista: si el destino correcto de cada
    elemento fuera el que ocupa su misma posición en la lista, el reactivo se
    contestaría sin leer nada. Se admite algún coincidente suelto, pero no que
    emparejar por posición baste para la mitad del puntaje."""
    question = _reactivo(bank, assessment_type, presentacion)
    ids_destino = [str(d["id"]) for d in question["destinos"]]

    fijos = sum(
        1
        for indice, elemento in enumerate(question["elementos"])
        if indice < len(ids_destino)
        and str(elemento["correcto"]) == ids_destino[indice]
    )
    total = len(question["elementos"])
    assert fijos <= total // 2, (
        f"{question['code']}: emparejar por posición acierta {fijos} de {total}"
    )


@ASIGNACION
def test_reutilizar_el_componente_entre_reactivos_no_filtra_fichas(
    engine, bank, presentacion
):
    """El Loader de la pantalla conserva su item cuando dos reactivos seguidos
    usan el mismo componente —T4 y S4 son ambos «lista_arrastrable»—, así que
    cambiar de reactivo es asignar `pregunta` encima del estado anterior.

    Además comprueba que el handler `onPreguntaChanged` del tipo derivado no
    tapa al de AsignacionBase: si lo tapara, el montón se reharía pero las
    asignaciones viejas seguirían ahí, y el reactivo nuevo aparecería medio
    contestado con fichas del anterior.
    """
    primera, objeto = _montar(engine, bank, "pre", presentacion)
    for elemento in primera["elementos"]:
        _llamar(objeto, "asignar", str(elemento["id"]), str(elemento["correcto"]))
    _llamar(objeto, "tomar", str(primera["elementos"][0]["id"]))
    assert _asignaciones(objeto) != {}

    segunda = _reactivo(bank, "post", presentacion)
    objeto.setProperty("respuestaInicial", None)
    objeto.setProperty("pregunta", _publico(bank, segunda))

    assert _asignaciones(objeto) == {}, "quedaron asignaciones del reactivo anterior"
    assert objeto.property("enMano") == "", "quedó un elemento en mano"

    # Y el montón corresponde al reactivo nuevo, no al viejo.
    pendientes = [str(e["id"]) for e in _valor(objeto, "pendientes")]
    assert sorted(pendientes) == sorted(str(e["id"]) for e in segunda["elementos"])


@ASIGNACION
def test_la_respuesta_previa_se_restaura_al_volver_a_un_reactivo(
    engine, bank, presentacion
):
    """La pantalla asigna `respuestaInicial` antes que `pregunta`, porque
    asignar la pregunta es lo que dispara restaurar(). Si el orden se invirtiera
    —o si restaurar() ignorara la respuesta previa— volver atrás con el botón de
    navegación mostraría el reactivo en blanco."""
    question = _reactivo(bank, "pre", presentacion)
    objeto = _crear(engine, COMPONENTE_POR_PRESENTACION[presentacion])

    previas = {
        str(e["id"]): str(e["correcto"]) for e in question["elementos"][:2]
    }
    objeto.setProperty("respuestaInicial", {"asignaciones": previas})
    objeto.setProperty("pregunta", _publico(bank, question))

    assert _asignaciones(objeto) == previas
