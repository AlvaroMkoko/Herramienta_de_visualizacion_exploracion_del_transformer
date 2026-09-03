"""Pruebas del orquestador de comparacion de dos modelos."""

from __future__ import annotations

import torch

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from viewmodel.comparison_controller import ComparisonController


class TokenizerDePrueba:
    def encode(self, texto: str) -> list[int]:
        return [(ord(caracter) % 40) + 1 for caracter in texto]

    def decode(self, tokens: list[int]) -> str:
        return ",".join(str(token) for token in tokens)


class BibliotecaFalsa:
    pass


def _modelo(semilla: int) -> Transformer:
    torch.manual_seed(semilla)
    return Transformer(
        ConfiguracionTransformer(
            tamano_vocabulario=50,
            dimension_modelo=16,
            num_cabezas=4,
            num_capas=1,
            dimension_ff=32,
            longitud_maxima_secuencia=32,
            dropout=0.0,
            id_token_relleno=0,
        )
    )


def _instalar_dos(controlador: ComparisonController) -> None:
    controlador._instalar_modelos(
        0,
        _modelo(10),
        TokenizerDePrueba(),
        {"nombre": "Modelo A", "longitud_maxima_secuencia": 32},
        _modelo(20),
        TokenizerDePrueba(),
        {"nombre": "Modelo B", "longitud_maxima_secuencia": 24},
    )


def test_instala_dos_modelos_y_limita_por_el_contexto_menor(qtbot) -> None:
    controlador = ComparisonController(BibliotecaFalsa())
    _instalar_dos(controlador)

    assert controlador.modelosListos is True
    assert controlador.controladorA is not None
    assert controlador.controladorB is not None
    assert controlador.modeloAInfo["nombre"] == "Modelo A"
    assert controlador.modeloBInfo["nombre"] == "Modelo B"
    assert controlador.maxTokensPermitidos == 24

    controlador.liberarModelos()
    assert controlador.modelosListos is False


def test_genera_en_ambos_modelos_con_los_mismos_parametros(qtbot) -> None:
    controlador = ComparisonController(BibliotecaFalsa())
    _instalar_dos(controlador)
    resultados: dict[str, str] = {}
    controlador.controladorA.generacion_completa.connect(
        lambda texto: resultados.__setitem__("a", texto)
    )
    controlador.controladorB.generacion_completa.connect(
        lambda texto: resultados.__setitem__("b", texto)
    )

    controlador.iniciarGeneracion("hola", 3, 1.0, 0, 1.0, True)
    qtbot.waitUntil(lambda: len(resultados) == 2, timeout=5000)

    assert len(resultados["a"].split(",")) == 3
    assert len(resultados["b"].split(",")) == 3
    assert controlador.estaGenerando is False
    controlador.liberarModelos()


def test_rechaza_seleccionar_el_mismo_archivo(qtbot, tmp_path) -> None:
    controlador = ComparisonController(BibliotecaFalsa())
    ruta = tmp_path / "modelo.pt"
    errores: list[str] = []
    controlador.error.connect(errores.append)

    controlador.cargarModelos(str(ruta), str(ruta))

    assert errores == ["Selecciona dos modelos diferentes."]
    assert controlador.cargando is False


def test_carga_publica_la_fase_de_cada_archivo(qtbot, tmp_path, monkeypatch) -> None:
    controlador = ComparisonController(BibliotecaFalsa())
    llamadas = 0
    fases: list[str] = []

    def cargar_falso(_ruta):
        nonlocal llamadas
        llamadas += 1
        if llamadas == 1:
            return object(), object(), object(), {}
        raise ValueError("fallo simulado en el segundo modelo")

    monkeypatch.setattr(controlador, "_cargar_archivo", cargar_falso)
    controlador.faseCargaCambio.connect(lambda: fases.append(controlador.faseCarga))

    with qtbot.waitSignal(controlador.error, timeout=3000):
        controlador.cargarModelos(
            str(tmp_path / "modelo-a.tvismodel"),
            str(tmp_path / "modelo-b.tvismodel"),
        )

    assert fases == ["Cargando modelo 1 de 2", "Cargando modelo 2 de 2", ""]
    assert controlador.cargando is False
