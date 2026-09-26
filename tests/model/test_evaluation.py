"""Pruebas del dominio de evaluación con el instrumento v2.

El instrumento v2 cambió tres supuestos del v1 y estas pruebas los fijan:
un reactivo ya no es siempre de opción única, el puntaje es flotante porque hay
crédito parcial, y hay una etapa que se registra pero no suma.
"""

from __future__ import annotations

import pytest

from model.evaluacion import (
    EvaluationManager,
    EvaluationStateError,
    QuestionBank,
    QuestionBankError,
    calificar,
    es_respuesta_completa,
    normalizar_texto,
)

#: Claves que revelan la respuesta. Ninguna puede llegar a la vista, a ninguna
#: profundidad: el esquema v2 las esconde en cinco lugares distintos.
CLAVES_SECRETAS = frozenset(
    {
        "correct_option_id",
        "correct_option_ids",
        "respuestas_aceptadas",
        "correcto",
    }
)


@pytest.fixture(scope="module")
def bank() -> QuestionBank:
    return QuestionBank()


def por_codigo(bank: QuestionBank, assessment_type: str, code: str) -> dict:
    return next(
        question
        for question in bank.get_questions(assessment_type)
        if question["code"] == code
    )


def respuesta_perfecta(question: dict) -> dict:
    """Respuesta que obtiene el puntaje máximo, sea cual sea el tipo."""
    tipo = question["tipo"]
    if tipo == "opcion_unica":
        return {"opcion_id": question["correct_option_id"]}
    if tipo == "seleccion_multiple":
        return {"opciones_ids": list(question["correct_option_ids"])}
    if tipo == "texto":
        return {"texto": question["respuestas_aceptadas"][0]}
    if tipo == "asignacion":
        return {
            "asignaciones": {
                elemento["id"]: elemento["correcto"]
                for elemento in question["elementos"]
            }
        }
    if tipo == "etapas":
        return {
            "etapas": {
                etapa["id"]: (
                    {"texto": "justificación del estudiante"}
                    if etapa["tipo"] == "texto_libre"
                    else {"opcion_id": etapa["correct_option_id"]}
                )
                for etapa in question["etapas"]
            }
        }
    raise AssertionError(f"tipo no contemplado en la prueba: {tipo!r}")


def buscar_claves_secretas(objeto, ruta: str = "") -> list[str]:
    """Recorre la estructura completa buscando claves de respuesta."""
    encontradas: list[str] = []
    if isinstance(objeto, dict):
        for clave, valor in objeto.items():
            if clave in CLAVES_SECRETAS:
                encontradas.append(f"{ruta}.{clave}")
            encontradas += buscar_claves_secretas(valor, f"{ruta}.{clave}")
    elif isinstance(objeto, list):
        for indice, valor in enumerate(objeto):
            encontradas += buscar_claves_secretas(valor, f"{ruta}[{indice}]")
    return encontradas


# ---------------------------------------------------------------------------
# Blueprint del instrumento
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("assessment_type", ["pre", "post"])
def test_cada_forma_respeta_el_blueprint(bank, assessment_type):
    questions = bank.get_questions(assessment_type)

    assert len(questions) == 20
    assert sum(q["puntaje_maximo"] for q in questions) == 20.0

    por_dimension: dict[str, int] = {}
    por_bloom: dict[str, int] = {}
    for question in questions:
        por_dimension[question["dimension_id"]] = (
            por_dimension.get(question["dimension_id"], 0) + 1
        )
        por_bloom[question["bloom_level"]] = por_bloom.get(question["bloom_level"], 0) + 1

    assert len(por_dimension) == 5
    assert set(por_dimension.values()) == {4}
    assert por_bloom == {"Recordar": 5, "Comprender": 10, "Aplicar": 5}


def test_las_formas_son_equivalentes(bank):
    """Mismo código, misma dimensión, mismo nivel y mismo tipo en A y B.

    Es lo que permite comparar el pre-test contra el post-test: si una forma
    midiera algo distinto, el avance calculado no significaría nada.
    """
    pre = {q["code"]: q for q in bank.get_questions("pre")}
    post = {q["code"]: q for q in bank.get_questions("post")}

    assert set(pre) == set(post)
    for code in sorted(pre):
        for campo in ("dimension_id", "bloom_level", "tipo", "puntaje_maximo"):
            assert pre[code][campo] == post[code][campo], f"{code}/{campo}"
        assert pre[code]["prompt"] != post[code]["prompt"] or pre[code][
            "tipo"
        ] in ("asignacion", "seleccion_multiple")


def test_el_instrumento_usa_los_cinco_tipos(bank):
    tipos = {q["tipo"] for q in bank.get_questions("pre")}
    assert tipos == {
        "opcion_unica",
        "seleccion_multiple",
        "texto",
        "asignacion",
        "etapas",
    }


# ---------------------------------------------------------------------------
# La respuesta no viaja a la vista
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("assessment_type", ["pre", "post"])
def test_las_preguntas_publicas_no_exponen_la_respuesta(bank, assessment_type):
    fugas: list[str] = []
    for question in bank.get_public_questions(assessment_type):
        fugas += buscar_claves_secretas(question, question["id"])
    assert fugas == []


def test_la_version_privada_si_conserva_la_respuesta(bank):
    """Contraprueba: si esto pasara, la prueba anterior sería vacua."""
    privadas = bank.get_questions("pre")
    assert buscar_claves_secretas(privadas[0]) != []


def test_las_etapas_anidadas_tambien_se_limpian(bank):
    a3 = bank.public_question(por_codigo(bank, "pre", "A3"))
    for etapa in a3["etapas"]:
        assert "correct_option_id" not in etapa


# ---------------------------------------------------------------------------
# Validación del banco
# ---------------------------------------------------------------------------


def test_un_banco_v1_se_rechaza_con_un_mensaje_claro(tmp_path):
    import json

    ruta = tmp_path / "banco.json"
    ruta.write_text(
        json.dumps({"dimensions": [], "assessments": {}}), encoding="utf-8"
    )

    with pytest.raises(QuestionBankError, match="schema_version"):
        QuestionBank(ruta)


def test_un_banco_inexistente_se_rechaza(tmp_path):
    with pytest.raises(QuestionBankError):
        QuestionBank(tmp_path / "no_existe.json")


# ---------------------------------------------------------------------------
# Calificación por tipo
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("assessment_type", ["pre", "post"])
def test_examen_perfecto_obtiene_el_puntaje_maximo(bank, assessment_type):
    manager = EvaluationManager(bank)
    manager.start_evaluation(assessment_type)

    resultado: dict = {}
    while manager.active:
        question = manager.current_question
        resultado = manager.submit_answer(
            question["id"], respuesta_perfecta(question)
        )

    assert manager.finished is True
    assert resultado["puntaje"] == 20.0
    assert resultado["maximo"] == 20.0
    assert resultado["percentage"] == 100.0
    assert "correct" not in resultado, "clave del esquema v1"


def test_examen_sin_responder_vale_cero(bank):
    from model.evaluacion import compute_metrics

    resultado = compute_metrics(
        "pre", bank.get_questions("pre"), {}, bank.dimensions
    )

    assert resultado["puntaje"] == 0.0
    assert resultado["respondidas"] == 0
    assert resultado["percentage"] == 0.0


@pytest.mark.parametrize(
    "code, respuesta, esperado",
    [
        # Completar: la normalización ignora acentos, guiones y mayúsculas.
        ("T1", {"texto": "Byte-Pair Encoding"}, 1.0),
        ("T1", {"texto": "  BYTE PAIR ENCODING  "}, 1.0),
        ("T1", {"texto": "Codificación por Pares de Bytes"}, 1.0),
        ("T1", {"texto": "word2vec"}, 0.0),
        # Ordenar: 0.25 por posición correcta.
        ("T4", {"asignaciones": {"p1": "3", "p2": "4", "p3": "2", "p4": "1"}}, 1.0),
        ("T4", {"asignaciones": {"p1": "3", "p2": "4", "p3": "1", "p4": "2"}}, 0.5),
        ("T4", {"asignaciones": {"p1": "1", "p2": "2", "p3": "3", "p4": "4"}}, 0.0),
        # Selección múltiple: (aciertos − errores) / correctas, con piso en 0.
        ("E2", {"opciones_ids": ["a", "b", "c"]}, 1.0),
        ("E2", {"opciones_ids": ["a", "b"]}, round(2 / 3, 4)),
        ("E2", {"opciones_ids": ["a", "b", "c", "d"]}, round(2 / 3, 4)),
        ("E2", {"opciones_ids": ["a", "d"]}, 0.0),
        ("E2", {"opciones_ids": ["d"]}, 0.0),
        # Clasificar: 0.25 por elemento; un destino puede repetirse.
        ("E4", {"asignaciones": {"c1": "pos", "c2": "emb", "c3": "emb", "c4": "pos"}}, 1.0),
        ("E4", {"asignaciones": {"c1": "pos", "c2": "emb", "c3": "emb", "c4": "emb"}}, 0.75),
        # Relacionar: 1/3 por par.
        ("A1", {"asignaciones": {"q": "a", "k": "b", "v": "c"}}, 1.0),
        ("A1", {"asignaciones": {"q": "a", "k": "c", "v": "b"}}, round(1 / 3, 4)),
    ],
)
def test_credito_parcial_por_tipo(bank, code, respuesta, esperado):
    question = por_codigo(bank, "pre", code)
    assert calificar(question, respuesta)["puntaje"] == pytest.approx(esperado)


def test_seleccion_multiple_nunca_baja_de_cero(bank):
    """Marcar solo opciones incorrectas no puede producir puntaje negativo."""
    e2 = por_codigo(bank, "pre", "E2")
    assert calificar(e2, {"opciones_ids": ["d"]})["puntaje"] == 0.0


# ---------------------------------------------------------------------------
# Reactivos por etapas
# ---------------------------------------------------------------------------


def test_a2_exige_ambas_etapas(bank):
    """Acertar el «por qué» sin acertar el «qué» no otorga crédito parcial.

    Es el caso que el criterio del instrumento quería evitar: adivinar la
    explicación de un fenómeno que no se identificó.
    """
    a2 = por_codigo(bank, "pre", "A2")

    ambas = {"etapas": {"e1": {"opcion_id": "d"}, "e2": {"opcion_id": "c"}}}
    solo_segunda = {"etapas": {"e1": {"opcion_id": "a"}, "e2": {"opcion_id": "c"}}}
    solo_primera = {"etapas": {"e1": {"opcion_id": "d"}, "e2": {"opcion_id": "a"}}}

    assert calificar(a2, ambas)["puntaje"] == 1.0
    assert calificar(a2, solo_segunda)["puntaje"] == 0.0
    assert calificar(a2, solo_primera)["puntaje"] == 0.0


def test_a3_no_puntua_la_correccion_si_el_veredicto_fue_si(bank):
    """La etapa condicionada solo cuenta cuando su condición se cumple."""
    a3 = por_codigo(bank, "pre", "A3")

    completo = {"etapas": {"e1": {"opcion_id": "no"}, "e2": {"opcion_id": "a"}}}
    detecta_mal_corrige = {
        "etapas": {"e1": {"opcion_id": "no"}, "e2": {"opcion_id": "c"}}
    }
    dice_si = {"etapas": {"e1": {"opcion_id": "si"}, "e2": {"opcion_id": "a"}}}

    assert calificar(a3, completo)["puntaje"] == 1.0
    assert calificar(a3, detecta_mal_corrige)["puntaje"] == 0.5
    assert calificar(a3, dice_si)["puntaje"] == 0.0


def test_f2_la_justificacion_no_suma_al_puntaje(bank):
    """El criterio la trata como dato cualitativo: se registra, no se califica."""
    f2 = por_codigo(bank, "pre", "F2")

    con_texto = {
        "etapas": {"e1": {"opcion_id": "falso"}, "e2": {"texto": "hacen falta ambas"}}
    }
    sin_texto = {"etapas": {"e1": {"opcion_id": "falso"}}}
    vf_incorrecto = {
        "etapas": {"e1": {"opcion_id": "verdadero"}, "e2": {"texto": "hacen falta ambas"}}
    }

    assert calificar(f2, con_texto)["puntaje"] == 1.0
    assert calificar(f2, sin_texto)["puntaje"] == 1.0
    assert calificar(f2, vf_incorrecto)["puntaje"] == 0.0


def test_la_justificacion_llega_al_resultado_como_dato_cualitativo(bank):
    manager = EvaluationManager(bank)
    manager.start_evaluation("pre")

    resultado: dict = {}
    while manager.active:
        question = manager.current_question
        respuesta = respuesta_perfecta(question)
        if question["code"] == "F2":
            respuesta["etapas"]["e2"] = {"texto": "sin residuales no basta"}
        resultado = manager.submit_answer(question["id"], respuesta)

    assert len(resultado["cualitativos"]) == 1
    assert resultado["cualitativos"][0]["code"] == "F2"
    assert resultado["cualitativos"][0]["texto"] == "sin residuales no basta"


# ---------------------------------------------------------------------------
# Completitud: qué habilita el botón de continuar
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "code, respuesta, esperado",
    [
        ("T2", {"opcion_id": "a"}, True),
        ("T2", {"opcion_id": ""}, False),
        ("T2", None, False),
        ("T1", {"texto": "BPE"}, True),
        ("T1", {"texto": "   "}, False),
        ("E2", {"opciones_ids": ["a"]}, True),
        ("E2", {"opciones_ids": []}, False),
        ("T4", {"asignaciones": {"p1": "1", "p2": "2", "p3": "3", "p4": "4"}}, True),
        ("T4", {"asignaciones": {"p1": "1"}}, False),
        # F2: la justificación es opcional y no debe bloquear el avance.
        ("F2", {"etapas": {"e1": {"opcion_id": "falso"}}}, True),
        ("F2", {"etapas": {"e2": {"texto": "algo"}}}, False),
        # A3: si el veredicto es «Sí», la corrección ni se muestra ni se exige.
        ("A3", {"etapas": {"e1": {"opcion_id": "si"}}}, True),
        ("A3", {"etapas": {"e1": {"opcion_id": "no"}}}, False),
    ],
)
def test_completitud_de_la_respuesta(bank, code, respuesta, esperado):
    question = por_codigo(bank, "pre", code)
    assert es_respuesta_completa(question, respuesta) is esperado


# ---------------------------------------------------------------------------
# Robustez ante lo que llegue de la vista
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("code", ["T1", "T2", "T4", "E2", "A2"])
@pytest.mark.parametrize(
    "basura",
    [None, {}, "texto suelto", [], 42, {"opcion_id": None}, {"asignaciones": "x"}],
)
def test_una_respuesta_mal_formada_vale_cero_sin_lanzar(bank, code, basura):
    question = por_codigo(bank, "pre", code)
    assert calificar(question, basura)["puntaje"] == 0.0


def test_normalizar_texto_colapsa_acentos_signos_y_espacios():
    assert normalizar_texto("Byte-Pair Encoding") == "byte pair encoding"
    assert normalizar_texto("  BYTE   PAIR  ENCODING.  ") == "byte pair encoding"
    assert normalizar_texto("Codificación") == "codificacion"
    assert normalizar_texto(None) == ""


# ---------------------------------------------------------------------------
# Máquina de estados
# ---------------------------------------------------------------------------


def test_no_se_puede_responder_sin_iniciar(bank):
    manager = EvaluationManager(bank)

    with pytest.raises(EvaluationStateError):
        manager.submit_answer("pre_t1", {"opcion_id": "a"})


def test_una_respuesta_de_otra_pregunta_se_rechaza(bank):
    manager = EvaluationManager(bank)
    manager.start_evaluation("pre")

    with pytest.raises(EvaluationStateError):
        manager.submit_answer("pre_s4", {"opcion_id": "a"})


def test_una_respuesta_incompleta_se_rechaza(bank):
    manager = EvaluationManager(bank)
    manager.start_evaluation("pre")

    with pytest.raises(EvaluationStateError):
        manager.submit_answer("pre_t1", {"texto": ""})


def test_avanza_de_uno_en_uno_y_marca_el_ultimo(bank):
    manager = EvaluationManager(bank)
    manager.start_evaluation("pre")

    for indice in range(20):
        assert manager.current_index == indice
        assert manager.is_last_question is (indice == 19)
        question = manager.current_question
        manager.submit_answer(question["id"], respuesta_perfecta(question))

    assert manager.finished is True
    assert manager.active is False
