"""Reactivos del banco modular: forma por ejes, banco de opciones y número.

Como en `test_evaluation_presentations.py`, cada prueba manipula el componente
como lo haría el estudiante y termina en `calificar()`: lo que sale de la vista
tiene que puntuar en el modelo.
"""

from __future__ import annotations

import os
from pathlib import Path
import random

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QSG_RHI_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

import pytest
from PySide6.QtCore import Q_ARG, QMetaObject, QObject, Qt, QUrl
from PySide6.QtQml import QJSValue, QQmlComponent, QQmlEngine, QQmlExpression

from model.aprendizaje import LearningModuleCatalog, ModuleQuestionBank
from model.evaluacion.scorers import calificar, es_respuesta_completa

QML_ROOT = Path(__file__).resolve().parents[2] / "view" / "qml"

_VIVOS: list = []


@pytest.fixture(scope="module")
def engine(qapp):
    motor = QQmlEngine()
    motor.addImportPath(str(QML_ROOT))
    yield motor
    motor.deleteLater()


@pytest.fixture(scope="module")
def banco() -> ModuleQuestionBank:
    return ModuleQuestionBank(module_id="module_3", rng=random.Random(3))


def _crear(engine: QQmlEngine, nombre: str) -> QObject:
    ruta = QML_ROOT / "components" / f"{nombre}.qml"
    componente = QQmlComponent(engine, QUrl.fromLocalFile(str(ruta)))
    errores = "\n".join(error.toString() for error in componente.errors())
    assert componente.status() == QQmlComponent.Status.Ready, errores
    objeto = componente.create()
    assert objeto is not None, errores
    QQmlEngine.setObjectOwnership(objeto, QQmlEngine.ObjectOwnership.CppOwnership)
    _VIVOS.append((componente, objeto))
    return objeto


def _valor(objeto: QObject, nombre: str):
    valor = objeto.property(nombre)
    return valor.toVariant() if isinstance(valor, QJSValue) else valor


def _llamar(objeto: QObject, metodo: str, *argumentos) -> None:
    args = [Q_ARG("QVariant", valor) for valor in argumentos]
    assert QMetaObject.invokeMethod(
        objeto, metodo, Qt.ConnectionType.DirectConnection, *args
    ), metodo


def _evaluar(objeto: QObject, expresion_qml: str):
    contexto = QQmlEngine.contextForObject(objeto)
    expresion = QQmlExpression(contexto, objeto, expresion_qml)
    valor, error = expresion.evaluate()
    assert not error, expresion_qml
    return valor.toVariant() if isinstance(valor, QJSValue) else valor


def _reactivo(banco: ModuleQuestionBank, forma: str, codigo: str) -> dict:
    return next(q for q in banco.all_questions(forma) if q["code"] == codigo)


def _montar(engine, banco, forma, codigo, componente):
    pregunta = _reactivo(banco, forma, codigo)
    objeto = _crear(engine, componente)
    objeto.setProperty("pregunta", banco.public_question(pregunta))
    return pregunta, objeto


# ── Presentaciones del banco modular ────────────────────────────────────


def test_todo_el_banco_modular_usa_presentaciones_con_componente():
    """EvaluationScreen dibuja estas presentaciones; una nueva sin registrar
    caería en la vista genérica sin que nadie lo notara."""
    registradas = {
        "tarjetas", "chips_toggle", "caja_en_linea", "forma_tensor",
        "lista_arrastrable", "lineas_o_tocar_para_emparejar",
    }
    pantalla = (QML_ROOT / "screens" / "EvaluationScreen.qml").read_text("utf-8")
    assert 'case "forma_tensor":' in pantalla

    catalogo = LearningModuleCatalog()
    banco = ModuleQuestionBank(catalogo, rng=random.Random(1))
    for modulo in catalogo.modules:
        banco.set_module(modulo["id"])
        for forma in ("pre", "post"):
            for pregunta in banco.all_questions(forma):
                assert pregunta["presentacion"] in registradas, pregunta["id"]


def test_las_formas_se_piden_por_ejes_y_completar_con_banco(banco):
    for forma in ("pre", "post"):
        b8 = _reactivo(banco, forma, "B8")
        assert b8["presentacion"] == "forma_tensor"
        assert {"B", "T", "d_model"} <= set(b8["simbolos"])
        assert "eje por eje" in b8["prompt"]
        for codigo in ("B6", "I7"):
            completar = _reactivo(banco, forma, codigo)
            opciones = completar["banco_opciones"]
            assert len(opciones) == 4
            assert completar["respuestas_aceptadas"][0] in opciones
        # El público conserva el banco: sin él no hay nada que elegir.
        assert banco.public_question(completar)["banco_opciones"]
        assert _reactivo(banco, forma, "A7")["formato_respuesta"] == "numero"


# ── forma_tensor ────────────────────────────────────────────────────────


@pytest.mark.parametrize("forma", ["pre", "post"])
def test_la_forma_armada_por_ejes_puntua(engine, banco, forma):
    pregunta, objeto = _montar(engine, banco, forma, "B8", "ReactivoForma")
    esperada = pregunta["respuestas_aceptadas"][0].strip("[]").split(",")

    assert _valor(objeto, "ejes") == ["", ""]
    while len(_valor(objeto, "ejes")) < len(esperada):
        _llamar(objeto, "agregarEje")
    for indice, eje in enumerate(esperada):
        # Escrito a mano, en minúsculas y sin guion bajo.
        _llamar(objeto, "fijar", indice, eje.replace("_", "").lower())

    respuesta = _evaluar(objeto, "respuestaActual()")
    assert es_respuesta_completa(pregunta, respuesta)
    assert calificar(pregunta, respuesta)["puntaje"] == 1.0


def test_una_casilla_vacia_no_deja_continuar(engine, banco):
    pregunta, objeto = _montar(engine, banco, "pre", "A1", "ReactivoForma")
    _llamar(objeto, "fijar", 0, "5")

    respuesta = _evaluar(objeto, "respuestaActual()")
    assert objeto.property("completa") is False
    assert not es_respuesta_completa(pregunta, respuesta)

    _llamar(objeto, "fijar", 1, "5")
    respuesta = _evaluar(objeto, "respuestaActual()")
    assert calificar(pregunta, respuesta)["puntaje"] == 1.0


def test_el_simbolo_de_la_paleta_va_a_la_casilla_vacia(engine, banco):
    _pregunta, objeto = _montar(engine, banco, "pre", "B8", "ReactivoForma")
    _llamar(objeto, "ponerSimbolo", "B")
    _llamar(objeto, "ponerSimbolo", "T")

    assert _valor(objeto, "ejes") == ["B", "T"]


def test_la_forma_se_restaura_al_volver_al_reactivo(engine, banco):
    pregunta = _reactivo(banco, "pre", "B8")
    objeto = _crear(engine, "ReactivoForma")
    objeto.setProperty("respuestaInicial", {"texto": "[B,T,d_v]"})
    objeto.setProperty("pregunta", banco.public_question(pregunta))

    assert _valor(objeto, "ejes") == ["B", "T", "d_v"]


# ── caja_en_linea con banco y con número ────────────────────────────────


@pytest.mark.parametrize("codigo", ["B6", "I7"])
def test_elegir_del_banco_puntua_y_tocarla_de_nuevo_la_quita(engine, banco, codigo):
    pregunta, objeto = _montar(engine, banco, "post", codigo, "ReactivoTexto")
    correcta = pregunta["respuestas_aceptadas"][0]
    assert objeto.property("conBanco") is True

    _llamar(objeto, "elegir", correcta)
    respuesta = _evaluar(objeto, "respuestaActual()")
    assert calificar(pregunta, respuesta)["puntaje"] == 1.0

    _llamar(objeto, "elegir", correcta)
    assert not es_respuesta_completa(pregunta, _evaluar(objeto, "respuestaActual()"))


def test_la_respuesta_numerica_solo_admite_numeros(engine, banco):
    _pregunta, objeto = _montar(engine, banco, "pre", "A7", "ReactivoTexto")
    campo = objeto.findChild(QObject, "evaluationTextAnswer")

    assert objeto.property("esNumero") is True
    assert campo.property("validator") is not None
    assert objeto.property("conBanco") is False


# ── relacionar en cualquier orden ───────────────────────────────────────


def test_relacionar_empezando_por_la_funcion(engine, banco):
    pregunta, objeto = _montar(
        engine, banco, "pre", "I3", "ReactivoRelacionar"
    )
    for elemento in pregunta["elementos"]:
        _llamar(objeto, "tomarDestino", str(elemento["correcto"]))
        assert objeto.property("destinoEnMano") == str(elemento["correcto"])
        _llamar(objeto, "tomar", str(elemento["id"]))
        assert objeto.property("destinoEnMano") == ""

    respuesta = {"asignaciones": dict(_valor(objeto, "asignaciones"))}
    assert calificar(pregunta, respuesta)["puntaje"] == pytest.approx(1.0)


# ── Arrastrar con el ratón de verdad ────────────────────────────────────

ARRASTRE_HOST = b"""import QtQuick
import QtQuick.Controls
import "components"
ApplicationWindow {
    width: 1100; height: 900; visible: true
    // Igual que en el examen: dentro de un ScrollView que recorta.
    ScrollView {
        anchors.fill: parent; clip: true; contentWidth: availableWidth
        ReactivoOrdenar { objectName: "reactivo"; width: 1000 }
    }
}
"""


def _items(item):
    for hijo in item.childItems():
        yield hijo
        yield from _items(hijo)


def _centro(item):
    from PySide6.QtCore import QPoint, QPointF

    punto = item.mapToScene(QPointF(item.width() / 2, item.height() / 2))
    return QPoint(int(punto.x()), int(punto.y()))


def _arrastrar(ventana, desde, hasta):
    from PySide6.QtCore import QPoint
    from PySide6.QtTest import QTest

    QTest.mousePress(ventana, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, desde)
    for paso in range(1, 21):
        QTest.mouseMove(
            ventana,
            QPoint(desde.x() + (hasta.x() - desde.x()) * paso // 20,
                   desde.y() + (hasta.y() - desde.y()) * paso // 20),
        )
        QTest.qWait(5)
    QTest.mouseRelease(ventana, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, hasta)
    QTest.qWait(50)


def test_arrastrar_una_ficha_a_su_posicion_la_coloca(engine, banco):
    """El arrastre se veía, pero al soltar la ficha volvía al montón: ningún
    destino la recibía. Se arrastra con eventos de ratón reales."""
    from PySide6.QtQuick import QQuickItem

    componente = QQmlComponent(engine)
    componente.setData(ARRASTRE_HOST, QUrl.fromLocalFile(str(QML_ROOT / "ArrastreHost.qml")))
    ventana = componente.create()
    assert ventana is not None, [e.toString() for e in componente.errors()]
    _VIVOS.append((componente, ventana))
    reactivo = ventana.findChild(QQuickItem, "reactivo")
    pregunta = _reactivo(banco, "pre", "I1")
    reactivo.setProperty("pregunta", banco.public_question(pregunta))
    from PySide6.QtTest import QTest

    QTest.qWait(50)

    elementos = list(_items(reactivo))
    ficha = next(
        item for item in elementos
        if item.metaObject().indexOfProperty("elementoId") >= 0
        and item.property("elementoId") and not item.property("colocada")
    )
    ranura = next(item for item in elementos if item.objectName() == "evaluationSlot_3")
    elemento = ficha.property("elementoId")

    _arrastrar(ventana, _centro(ficha), _centro(ranura))
    assert dict(_valor(reactivo, "asignaciones")) == {elemento: "3"}
    # Un arrastre terminado no cuenta como toque: nada queda en mano.
    assert reactivo.property("enMano") == ""

    colocada = next(
        item for item in _items(reactivo)
        if item.metaObject().indexOfProperty("elementoId") >= 0
        and item.property("colocada") and item.property("visible")
    )
    monton = next(i for i in _items(reactivo) if i.objectName() == "evaluationAssignmentPool")
    from PySide6.QtCore import QPoint, QPointF

    esquina = monton.mapToScene(QPointF(monton.width() - 30, 20))
    _arrastrar(ventana, _centro(colocada), QPoint(int(esquina.x()), int(esquina.y())))
    assert dict(_valor(reactivo, "asignaciones")) == {}
    ventana.close()
