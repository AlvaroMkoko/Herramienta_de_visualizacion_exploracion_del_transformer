from __future__ import annotations

from model.evaluacion import QuestionBank
from viewmodel.evaluation_controller import EvaluationController


def test_controlador_prepara_pre_y_post_test():
    controller = EvaluationController(question_bank=QuestionBank())

    controller.prepareEvaluation("post")

    assert controller.assessmentType == "post"
    assert controller.title == "Post-test"
    assert controller.totalQuestions == 8
    assert len(controller.dimensions) == 2


def test_controlador_exige_seleccion_y_finaliza(qtbot):
    bank = QuestionBank()
    controller = EvaluationController(question_bank=bank)
    controller.startEvaluation("pre")

    assert controller.currentQuestion["id"] == "pre_t1"
    assert "correct_option_id" not in controller.currentQuestion
    assert controller.canContinue is False

    questions = bank.get_questions("pre")
    with qtbot.waitSignal(controller.evaluationCompleted, timeout=1000):
        for question in questions:
            controller.selectAnswer(question["correct_option_id"])
            assert controller.canContinue is True
            controller.submitCurrentAnswer()

    assert controller.finished is True
    assert controller.result["correct"] == 8
    assert controller.result["percentage"] == 100.0
    assert controller.hasPreviousResult is True
