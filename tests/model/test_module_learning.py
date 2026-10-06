"""Contratos del catálogo y del banco modular."""

from __future__ import annotations

import json
import random

from core.rutas import recurso
from model.aprendizaje import LearningModuleCatalog, ModuleQuestionBank
from model.evaluacion.scorers import calificar, es_respuesta_completa


def _correct_answer(question: dict) -> dict:
    if question["tipo"] == "opcion_unica":
        return {"opcion_id": question["correct_option_id"]}
    if question["tipo"] == "seleccion_multiple":
        return {"opciones_ids": question["correct_option_ids"]}
    if question["tipo"] == "texto":
        return {"texto": question["respuestas_aceptadas"][0]}
    if question["tipo"] == "asignacion":
        return {
            "asignaciones": {
                item["id"]: item["correcto"] for item in question["elementos"]
            }
        }
    raise AssertionError(f"Tipo inesperado: {question['tipo']}")


def test_catalogo_declara_ocho_modulos_completos():
    catalog = LearningModuleCatalog()

    assert len(catalog.modules) == 8
    assert [module["order"] for module in catalog.modules] == list(range(1, 9))
    assert all(len(module["concepts"]) == 8 for module in catalog.modules)
    assert all(len(module["guided_steps"]) == 8 for module in catalog.modules)
    assert all(len(module["theory_sequence"]) == 8 for module in catalog.modules)
    assert all(len(module["challenges"]) == 8 for module in catalog.modules)


def test_cada_paso_guiado_apunta_a_teoria_existente():
    catalog = LearningModuleCatalog()
    with recurso("data", "teoria", "transformer.json").open(encoding="utf-8") as source:
        theory = json.load(source)
    theory_ids = {
        concept["id"]
        for section in theory["secciones"]
        for concept in section["conceptos"]
    }

    for module in catalog.modules:
        assert set(module["theory_sequence"]) <= theory_ids


def test_cada_modulo_tiene_25_preguntas_pre_y_post():
    catalog = LearningModuleCatalog()
    bank = ModuleQuestionBank(catalog, rng=random.Random(7))

    for module in catalog.modules:
        bank.set_module(module["id"])
        assert len(bank.all_questions("pre")) == 25
        assert len(bank.all_questions("post")) == 25
        assert {
            question["difficulty"] for question in bank.all_questions("pre")
        } == {"Básica", "Intermedia", "Avanzada"}
        assert {
            question["pedagogical_type"] for question in bank.all_questions("pre")
        } == set(ModuleQuestionBank.PEDAGOGICAL_TYPES)
        assert {
            question["pedagogical_type"] for question in bank.all_questions("post")
        } == set(ModuleQuestionBank.PEDAGOGICAL_TYPES)
        assert {
            question["bloom_level"] for question in bank.all_questions("pre")
        } == {"Recordar", "Comprender", "Aplicar", "Analizar"}


def test_intento_selecciona_15_equilibradas_y_minimiza_repeticiones():
    bank = ModuleQuestionBank(module_id="module_3", rng=random.Random(11))
    first = set(bank.start_attempt("pre"))
    first_questions = bank.get_questions("pre")
    second = set(bank.start_attempt("pre", first))

    assert len(first) == len(second) == 15
    assert len(first & second) == 5  # 25 disponibles: diez nuevas en el segundo intento
    assert {
        level: sum(question["difficulty"] == level for question in first_questions)
        for level in ("Básica", "Intermedia", "Avanzada")
    } == {"Básica": 5, "Intermedia": 5, "Avanzada": 5}
    assert len({question["concept_id"] for question in first_questions}) == 8
    assert {
        question["pedagogical_type"] for question in first_questions
    } == set(ModuleQuestionBank.PEDAGOGICAL_TYPES)


def test_cada_intento_pre_y_post_incluye_los_siete_formatos():
    catalog = LearningModuleCatalog()
    expected = set(ModuleQuestionBank.PEDAGOGICAL_TYPES)

    for module in catalog.modules:
        for assessment in ("pre", "post"):
            bank = ModuleQuestionBank(
                catalog, module["id"], rng=random.Random(17)
            )
            bank.start_attempt(assessment)
            assert {
                question["pedagogical_type"]
                for question in bank.get_questions(assessment)
            } == expected


def test_pregunta_publica_oculta_solucion_y_explicacion():
    bank = ModuleQuestionBank(module_id="module_7", rng=random.Random(3))
    private = bank.all_questions("post")[-1]
    public = bank.public_question(private)

    assert "correct_option_id" not in public
    assert "explanation" not in public
    assert private["correct_option_id"]


def test_preguntas_publicas_ocultan_claves_de_todos_los_formatos():
    bank = ModuleQuestionBank(module_id="module_3", rng=random.Random(9))

    for private in bank.all_questions("pre"):
        public = bank.public_question(private)
        assert "correct_option_id" not in public
        assert "correct_option_ids" not in public
        assert "respuestas_aceptadas" not in public
        assert all("correcto" not in item for item in public.get("elementos", []))


def test_los_400_reactivos_modulares_son_completables_y_calificables():
    catalog = LearningModuleCatalog()
    bank = ModuleQuestionBank(catalog, rng=random.Random(13))

    for module in catalog.modules:
        bank.set_module(module["id"])
        for assessment in ("pre", "post"):
            for question in bank.all_questions(assessment):
                answer = _correct_answer(question)
                assert es_respuesta_completa(question, answer)
                assert calificar(question, answer)["puntaje"] == 1.0
