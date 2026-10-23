"""Contratos del catálogo y del banco modular."""

from __future__ import annotations

from difflib import SequenceMatcher
import json
import random
import re
import unicodedata

from core.rutas import recurso
from model.aprendizaje import LearningModuleCatalog, ModuleQuestionBank
from model.evaluacion.scorers import (
    calificar,
    es_respuesta_completa,
    normalizar_texto,
)


def _texto_comparable(texto: str) -> str:
    texto = unicodedata.normalize("NFKD", texto.lower())
    texto = texto.encode("ascii", "ignore").decode("ascii")
    return " ".join(re.findall(r"[a-z0-9]+", texto))


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
    assert all(
        set(module["laboratory"]["modes"]) == {"training", "inference"}
        for module in catalog.modules
    )
    assert all(module["laboratory"]["data_keys"] for module in catalog.modules)


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
        assert {question["difficulty"] for question in bank.all_questions("pre")} == {
            "Básica",
            "Intermedia",
            "Avanzada",
        }
        assert {
            question["pedagogical_type"] for question in bank.all_questions("pre")
        } == set(ModuleQuestionBank.PEDAGOGICAL_TYPES)
        assert {
            question["pedagogical_type"] for question in bank.all_questions("post")
        } == set(ModuleQuestionBank.PEDAGOGICAL_TYPES)
        assert {question["bloom_level"] for question in bank.all_questions("pre")} == {
            "Recordar",
            "Comprender",
            "Aplicar",
            "Analizar",
        }


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
    assert (
        len(
            {
                concept_id
                for question in first_questions
                for concept_id in question["concept_ids"]
            }
        )
        == 8
    )
    assert {question["pedagogical_type"] for question in first_questions} == set(
        ModuleQuestionBank.PEDAGOGICAL_TYPES
    )


def test_cada_intento_pre_y_post_incluye_los_siete_formatos():
    catalog = LearningModuleCatalog()
    expected = set(ModuleQuestionBank.PEDAGOGICAL_TYPES)

    for module in catalog.modules:
        for assessment in ("pre", "post"):
            bank = ModuleQuestionBank(catalog, module["id"], rng=random.Random(17))
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


def test_reactivos_no_repiten_opciones_claves_ni_destinos():
    catalog = LearningModuleCatalog()
    bank = ModuleQuestionBank(catalog, rng=random.Random(23))

    for module in catalog.modules:
        bank.set_module(module["id"])
        for assessment in ("pre", "post"):
            for question in bank.all_questions(assessment):
                options = [
                    normalizar_texto(option["text"])
                    for option in question.get("options", [])
                ]
                accepted = [
                    normalizar_texto(answer)
                    for answer in question.get("respuestas_aceptadas", [])
                ]
                destinations = [
                    normalizar_texto(destination["texto"])
                    for destination in question.get("destinos", [])
                ]
                assert len(options) == len(set(options))
                assert len(accepted) == len(set(accepted))
                assert len(destinations) == len(set(destinations))


def test_preguntas_de_forma_piden_un_solo_tensor_bien_definido():
    catalog = LearningModuleCatalog()
    bank = ModuleQuestionBank(catalog, rng=random.Random(29))

    for module in catalog.modules:
        bank.set_module(module["id"])
        for assessment in ("pre", "post"):
            question = next(
                item
                for item in bank.all_questions(assessment)
                if item["id"].endswith("_b8")
            )
            assert re.fullmatch(r"\[[^\[\]]+\]", question["respuestas_aceptadas"][0])


def test_respuestas_de_dimensiones_aceptan_notaciones_equivalentes():
    bank = ModuleQuestionBank(module_id="module_1", rng=random.Random(31))
    matrix_question = next(
        item for item in bank.all_questions("pre") if item["id"].endswith("_a1")
    )
    assert calificar(matrix_question, {"texto": "3 x 7"})["puntaje"] == 1.0

    bank.set_module("module_8")
    output_question = next(
        item for item in bank.all_questions("pre") if item["id"].endswith("_a1")
    )
    assert calificar(output_question, {"texto": "[B,T,|V|]"})["puntaje"] == 1.0


def test_dimensiones_con_millares_aceptan_escritura_sin_separador():
    bank = ModuleQuestionBank(module_id="module_2", rng=random.Random(33))
    embedding_shape = next(
        item for item in bank.all_questions("pre") if item["id"].endswith("_a1")
    )
    assert calificar(embedding_shape, {"texto": "[10000, 256]"})["puntaje"] == 1.0

    bank.set_module("module_7")
    # El post usa la forma isomorfa (3 ejemplos, |V| = 50 000), no los
    # números del pre.
    logits_shape = next(
        item for item in bank.all_questions("post") if item["id"].endswith("_a1")
    )
    assert calificar(logits_shape, {"texto": "3 x 50000"})["puntaje"] == 1.0


def test_reactivo_de_logits_mantiene_la_misma_logica_en_pre_y_post():
    bank = ModuleQuestionBank(module_id="module_7", rng=random.Random(37))

    for assessment in ("pre", "post"):
        question = next(
            item
            for item in bank.all_questions(assessment)
            if item["id"].endswith("_a2")
        )
        correct_id = question["correct_option_id"]
        correct_text = next(
            option["text"]
            for option in question["options"]
            if option["id"] == correct_id
        )
        assert "¿Es válido?" in question["prompt"]
        assert correct_text.startswith("Sí;")


# ── Alineación teoría–práctica–evaluación ──────────────────────────────


def test_la_alineacion_se_fusiona_en_todos_los_modulos():
    catalog = LearningModuleCatalog()

    assert catalog.has_alignment
    for module in catalog.modules:
        assert module["anchor"]["question"] and module["anchor"]["example"]
        assert all(step["check"]["options"] for step in module["guided_steps"])
        assert all("post_variant" in item for item in module["challenges"])
        assert len(module["lab_challenges"]) == 8
        assert [item["kind"] for item in module["transfer_items"]] == [
            "verdadero_falso",
            "respuesta_corta",
        ]


def test_catalogo_sin_archivo_de_alineacion_conserva_el_contrato_anterior(tmp_path):
    copia = tmp_path / "modules.json"
    copia.write_text(
        recurso("data", "aprendizaje", "modules.json").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    catalog = LearningModuleCatalog(copia)
    bank = ModuleQuestionBank(catalog, module_id="module_3", rng=random.Random(5))

    assert not catalog.has_alignment
    assert len(bank.all_questions("pre")) == 25


def test_el_post_no_repite_los_casos_del_pre():
    """Un post con los mismos números mide memoria del pre, no aprendizaje."""
    catalog = LearningModuleCatalog()
    bank = ModuleQuestionBank(catalog, rng=random.Random(41))

    for module in catalog.modules:
        bank.set_module(module["id"])
        pre = {q["code"]: q for q in bank.all_questions("pre")}
        post = {q["code"]: q for q in bank.all_questions("post")}
        for code in ("A1", "A2", "A6", "A7", "A8"):
            assert pre[code]["prompt"] != post[code]["prompt"], (module["id"], code)
        for code in ("A1", "A7"):
            assert (
                pre[code]["respuestas_aceptadas"][0]
                != post[code]["respuestas_aceptadas"][0]
                or module["id"] == "module_8"  # A1: misma forma simbólica [B,T,|V|]
                and code == "A1"
            ), (module["id"], code)


def test_pre_y_post_no_reutilizan_reactivos_ni_asociaciones():
    """Las formas paralelas miden lo mismo sin reciclar hechos completos."""

    def respuesta_legible(question: dict) -> str:
        options = {
            option["id"]: option["text"] for option in question.get("options", [])
        }
        if question.get("correct_option_id"):
            return options[question["correct_option_id"]]
        if question.get("correct_option_ids"):
            return " | ".join(
                sorted(
                    options[option_id] for option_id in question["correct_option_ids"]
                )
            )
        if question.get("respuestas_aceptadas"):
            return question["respuestas_aceptadas"][0]
        destinations = {
            item["id"]: item["texto"] for item in question.get("destinos", [])
        }
        return " | ".join(
            sorted(
                f"{item['texto']} -> {destinations.get(item['correcto'], item['correcto'])}"
                for item in question.get("elementos", [])
            )
        )

    def firma(question: dict) -> tuple[str, str]:
        return (
            _texto_comparable(question["prompt"]),
            _texto_comparable(respuesta_legible(question)),
        )

    def asociaciones(question: dict) -> list[tuple[str, str]]:
        if question.get("subtipo") != "relacionar":
            return []
        destinations = {item["id"]: item["texto"] for item in question["destinos"]}
        return [
            (
                _texto_comparable(item["texto"]),
                _texto_comparable(destinations[item["correcto"]]),
            )
            for item in question["elementos"]
        ]

    catalog = LearningModuleCatalog()
    bank = ModuleQuestionBank(catalog, rng=random.Random(53))

    for module in catalog.modules:
        bank.set_module(module["id"])
        pre = bank.all_questions("pre")
        post = bank.all_questions("post")

        assert {firma(question) for question in pre}.isdisjoint(
            {firma(question) for question in post}
        ), module["id"]

        pre_facts = [fact for question in pre for fact in asociaciones(question)]
        post_facts = [fact for question in post for fact in asociaciones(question)]
        assert len(pre_facts) == len(set(pre_facts)), (module["id"], "pre")
        assert len(post_facts) == len(set(post_facts)), (module["id"], "post")
        assert set(pre_facts).isdisjoint(post_facts), module["id"]

        pre_by_code = {question["code"]: question for question in pre}
        post_by_code = {question["code"]: question for question in post}
        for code in ("B1", "B2"):
            assert _texto_comparable(respuesta_legible(pre_by_code[code])) != (
                _texto_comparable(respuesta_legible(post_by_code[code]))
            ), (module["id"], code)


def test_los_nuevos_reactivos_se_responden_con_el_recorrido_del_modulo():
    catalog = LearningModuleCatalog()
    bank = ModuleQuestionBank(catalog, rng=random.Random(59))

    def respuesta_unica(question: dict) -> str:
        return next(
            option["text"]
            for option in question["options"]
            if option["id"] == question["correct_option_id"]
        )

    def relaciones(question: dict) -> dict[str, str]:
        destinations = {item["id"]: item["texto"] for item in question["destinos"]}
        return {
            item["texto"]: destinations[item["correcto"]]
            for item in question["elementos"]
        }

    for module in catalog.modules:
        bank.set_module(module["id"])
        steps = module["guided_steps"]
        post = {question["code"]: question for question in bank.all_questions("post")}

        assert respuesta_unica(post["B1"]) == steps[0]["operation"]
        assert respuesta_unica(post["B2"]) == steps[4]["operation"]

        for assessment, reason_indices, change_indices in (
            ("pre", (0, 2, 4, 6), (1, 3, 5, 7)),
            ("post", (1, 3, 5, 7), (0, 2, 4, 6)),
        ):
            questions = {
                question["code"]: question
                for question in bank.all_questions(assessment)
            }
            assert relaciones(questions["B7"]) == {
                steps[index]["title"]: steps[index]["why"] for index in reason_indices
            }
            assert relaciones(questions["I4"]) == {
                steps[index]["title"]: steps[index]["change"]
                for index in change_indices
            }
            assert questions["B7"]["explanation"].startswith("Relaciones correctas:")
            assert questions["I4"]["explanation"].startswith("Relaciones correctas:")


def test_un_intento_no_usa_el_mismo_caso_en_dos_reactivos_avanzados():
    catalog = LearningModuleCatalog()
    bank = ModuleQuestionBank(catalog, rng=random.Random(43))

    for module in catalog.modules:
        bank.set_module(module["id"])
        for assessment in ("pre", "post"):
            advanced = {
                q["code"]: q
                for q in bank.all_questions(assessment)
                if q["difficulty"] == "Avanzada"
            }
            a5_cases = {item["texto"] for item in advanced["A5"]["elementos"]}
            assert advanced["A8"]["prompt"] not in a5_cases
            assert not any(case in advanced["A6"]["prompt"] for case in a5_cases)
            assert advanced["A7"]["prompt"].removeprefix(
                "Responde sin opciones: "
            ) not in (
                advanced["A2"]["prompt"],
                advanced["A8"]["prompt"],
            )


def test_los_retos_del_laboratorio_no_aparecen_en_la_evaluacion():
    catalog = LearningModuleCatalog()
    bank = ModuleQuestionBank(catalog, rng=random.Random(47))

    for module in catalog.modules:
        bank.set_module(module["id"])
        texts = []
        for assessment in ("pre", "post"):
            for question in bank.all_questions(assessment):
                texts.append(question["prompt"])
                texts.extend(option["text"] for option in question.get("options", []))
                texts.extend(item["texto"] for item in question.get("elementos", []))
        corpus = "\n".join(texts)
        formal_prompts = [
            question["prompt"]
            for assessment in ("pre", "post")
            for question in bank.all_questions(assessment)
        ]
        for index, challenge in enumerate(module["lab_challenges"]):
            assert challenge["prompt"] not in corpus, challenge["id"]
            prompt = challenge["prompt"]
            assert prompt == prompt.strip()
            assert prompt.endswith("?") and "¿" in prompt
            assert "  " not in prompt
            assert challenge["explanation"].endswith((".", "?", "!"))
            assert all(str(option).strip() for option in challenge["options"])

            normalized_lab = _texto_comparable(prompt)
            similarities = [
                SequenceMatcher(
                    None, normalized_lab, _texto_comparable(formal_prompt)
                ).ratio()
                for formal_prompt in formal_prompts
            ]
            assert max(similarities, default=0.0) < 0.58, challenge["id"]

            parallel_forms = (
                module["challenges"][index]["prompt"],
                module["challenges"][index]["post_variant"]["prompt"],
            )
            assert all(
                SequenceMatcher(
                    None, normalized_lab, _texto_comparable(formal_prompt)
                ).ratio()
                < 0.58
                for formal_prompt in parallel_forms
            ), challenge["id"]


def test_la_clave_legible_cubre_todos_los_formatos():
    catalog = LearningModuleCatalog()
    bank = ModuleQuestionBank(catalog, module_id="module_3", rng=random.Random(53))

    for question in bank.all_questions("post"):
        key = bank.answer_key("post", question["id"])
        assert key["correct_text"], question["id"]
        assert key["concept_id"] == question["concept_id"]
    assert bank.answer_key("post", "no_existe") == {}


def test_cada_concepto_con_paso_guiado_tiene_enlace():
    catalog = LearningModuleCatalog()

    assert catalog.step_for_concept("module_3", "escalamiento_dk") == {
        "index": 4,
        "id": "m3_s5",
        "title": "Escalamiento",
    }
    assert catalog.step_for_concept("module_1", "dimensiones_entrada") == {}
