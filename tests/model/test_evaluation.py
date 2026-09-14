from __future__ import annotations

import pytest

from model.evaluacion import EvaluationManager, EvaluationStateError, QuestionBank


def test_banco_contiene_formas_equivalentes_y_respuestas_validas():
    bank = QuestionBank()
    pre = bank.get_questions("pre")
    post = bank.get_questions("post")

    assert len(pre) == 8
    assert len(post) == 8
    assert {question["dimension_id"] for question in pre} == {
        "tokenizacion",
        "embeddings_posicion",
    }
    assert {question["dimension_id"] for question in post} == {
        "tokenizacion",
        "embeddings_posicion",
    }
    assert len({question["id"] for question in [*pre, *post]}) == 16
    assert all(
        question["correct_option_id"]
        in {option["id"] for option in question["options"]}
        for question in [*pre, *post]
    )


def test_preguntas_publicas_no_exponen_la_respuesta_correcta():
    public_questions = QuestionBank().get_public_questions("pre")

    assert public_questions
    assert all("correct_option_id" not in question for question in public_questions)


@pytest.mark.parametrize("assessment_type", ["pre", "post"])
def test_gestor_califica_respuestas_correctas_por_dimension(assessment_type):
    bank = QuestionBank()
    manager = EvaluationManager(bank)
    questions = bank.get_questions(assessment_type)
    manager.start_evaluation(assessment_type)

    result = {}
    for question in questions:
        result = manager.submit_answer(
            question["id"], question["correct_option_id"]
        )

    assert manager.finished is True
    assert result["correct"] == 8
    assert result["percentage"] == 100.0
    assert all(dimension["correct"] == 4 for dimension in result["dimensions"])


def test_gestor_rechaza_opcion_que_no_pertenece_a_la_pregunta():
    manager = EvaluationManager(QuestionBank())
    manager.start_evaluation("pre")

    with pytest.raises(EvaluationStateError):
        manager.submit_answer("pre_t1", "opcion_inexistente")
