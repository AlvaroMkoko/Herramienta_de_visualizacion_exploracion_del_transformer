"""Pruebas sin red de la biblioteca visual de modelos."""

from __future__ import annotations

import os
from pathlib import Path
import sys
import threading
import types
from typing import Any

# Debe establecerse antes de crear QApplication para que funcione tambien en
# CI sin servidor grafico.
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

import pytest
import torch
from PySide6.QtWidgets import QApplication


# ``viewmodel.model_library_controller`` importa el wrapper real al cargar el
# modulo. En entornos minimos sin tiktoken proporcionamos solo el contrato que
# ese wrapper necesita; cuando la dependencia existe no la reemplazamos.
try:
    import tiktoken as _tiktoken  # noqa: F401
except ModuleNotFoundError:
    modulo_tiktoken = types.ModuleType("tiktoken")

    class _EncodingStub:
        def __init__(self, name: str) -> None:
            self.name = name
            self.n_vocab = 13

        def encode(self, texto: str) -> list[int]:
            return [ord(caracter) % self.n_vocab for caracter in texto]

        def decode(self, tokens: list[int]) -> str:
            return "".join(chr(token) for token in tokens)

    modulo_tiktoken.get_encoding = lambda nombre: _EncodingStub(nombre)  # type: ignore[attr-defined]
    sys.modules["tiktoken"] = modulo_tiktoken

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer
from model.persistencia.model_storage import guardar_modelo_portable, inspeccionar_modelo
from viewmodel import model_library_controller as modulo_biblioteca
from viewmodel.model_library_controller import ModelLibraryController, _ruta_local


class TokenizerFalso:
    """Tokenizador determinista que nunca consulta archivos ni la red."""

    def __init__(self, tipo_encoding: int = 2) -> None:
        if tipo_encoding not in range(3):
            raise ValueError("tipo_encoding invalido")
        self.tipo_encoding = tipo_encoding
        self.vocab_size = 13
        self.encoding = types.SimpleNamespace(
            name=modulo_biblioteca.ENCODINGS[tipo_encoding]
        )

    def encode(self, texto: str) -> list[int]:
        return [ord(caracter) % self.vocab_size for caracter in texto]

    def decode(self, tokens: list[int]) -> str:
        return "".join(chr(token) for token in tokens)


def _crear_modelo() -> Transformer:
    config = ConfiguracionTransformer(
        tamano_vocabulario=16,
        dimension_modelo=8,
        num_cabezas=2,
        num_capas=1,
        dimension_ff=16,
        longitud_maxima_secuencia=8,
        dropout=0.0,
        id_token_relleno=13,
    )
    torch.manual_seed(912)
    return Transformer(config, compartir_pesos_salida=True)


@pytest.fixture(scope="module")
def aplicacion_qt() -> QApplication:
    app = QApplication.instance()
    if app is None:
        app = QApplication([])
    assert isinstance(app, QApplication)
    return app


@pytest.fixture
def controlador(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    aplicacion_qt: QApplication,
) -> ModelLibraryController:
    del aplicacion_qt
    monkeypatch.setattr(modulo_biblioteca, "DIR_CHECKPOINTS", tmp_path)
    monkeypatch.setattr(modulo_biblioteca, "DISPOSITIVO", torch.device("cpu"))
    monkeypatch.setattr(modulo_biblioteca, "Tokenizer", TokenizerFalso)
    return ModelLibraryController()


def test_descriptor_muestra_arquitectura_tokenizador_y_capacidades(
    tmp_path: Path,
    controlador: ModelLibraryController,
) -> None:
    modelo = _crear_modelo()
    optimizador = torch.optim.Adam(modelo.parameters(), lr=0.001)
    ruta = tmp_path / "visible.tvismodel"
    guardar_modelo_portable(
        ruta,
        modelo,
        TokenizerFalso(),
        nombre="Modelo visible",
        optimizador=optimizador,
        reanudable=True,
        epoca=2,
        paso_global=9,
        historial_perdidas=[1.5, 0.8],
    )

    modelos = controlador.obtenerModelos()

    assert len(modelos) == 1
    descriptor = modelos[0]
    assert descriptor["compatible"] is True
    assert descriptor["portable"] is True
    assert descriptor["nombre"] == "Modelo visible"
    assert descriptor["capasEncoder"] == 1
    assert descriptor["capasDecoder"] == 1
    assert descriptor["cabezas"] == 2
    assert descriptor["dimension"] == 8
    assert descriptor["dimensionFF"] == 16
    assert descriptor["contexto"] == 8
    assert descriptor["vocabulario"] == 16
    assert descriptor["encoding"] == "p50k_base"
    assert descriptor["reanudable"] is True
    assert descriptor["tokenizadorIncluido"] is True
    assert descriptor["epoca"] == 2
    assert descriptor["paso_global"] == 9
    assert descriptor["perdida_final"] == 0.8
    assert "Encoder 1 + Decoder 1" in descriptor["resumen"]
    assert any("Inferencia" in capacidad for capacidad in descriptor["capacidades"])
    assert any("Reanudaci" in capacidad for capacidad in descriptor["capacidades"])
    assert any("Tokenizador" in capacidad for capacidad in descriptor["capacidades"])


def test_catalogo_conserva_archivos_invalidos_como_descriptor_incompatible(
    tmp_path: Path,
    controlador: ModelLibraryController,
) -> None:
    invalido = tmp_path / "roto.tvismodel"
    invalido.write_bytes(b"esto no es un modelo")

    controlador.refrescar()
    descriptor = next(
        modelo for modelo in controlador.modelos if modelo["archivo"] == invalido.name
    )

    assert descriptor["compatible"] is False
    assert descriptor["resumen"] == "Modelo incompatible"
    assert descriptor["capacidades"] == ["Formato incompatible"]
    assert descriptor["error"]


def test_cargar_modelo_emite_modelo_tokenizer_y_resultado_sin_red(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    controlador: ModelLibraryController,
) -> None:
    modelo_original = _crear_modelo()
    esperado = {
        nombre: tensor.detach().cpu().clone()
        for nombre, tensor in modelo_original.state_dict().items()
    }
    ruta = tmp_path / "cargable.tvismodel"
    guardar_modelo_portable(ruta, modelo_original, TokenizerFalso())

    # La unidad bajo prueba decide correctamente que la operacion es pesada;
    # aqui ejecutamos su tarea de forma inmediata para observar las senales sin
    # temporizadores ni carreras propias de un test de UI.
    monkeypatch.setattr(
        controlador,
        "_ejecutar_en_segundo_plano",
        lambda _descripcion, tarea: tarea(),
    )
    cargados: list[tuple[Any, Any, Any]] = []
    errores: list[str] = []
    controlador.modelo_cargado.connect(
        lambda modelo, tokenizer, resultado: cargados.append(
            (modelo, tokenizer, resultado)
        )
    )
    controlador.error.connect(errores.append)

    controlador.cargarModelo(str(ruta))

    assert errores == []
    assert len(cargados) == 1
    modelo, tokenizer, resultado = cargados[0]
    assert isinstance(modelo, Transformer)
    assert isinstance(tokenizer, TokenizerFalso)
    assert tokenizer.tipo_encoding == 2
    assert resultado.modelo is modelo
    assert resultado.manifest["ruta"] == str(ruta.resolve())
    assert modelo.config.num_capas == 1
    assert modelo.config.num_cabezas == 2
    assert modelo.config.dimension_modelo == 8
    assert modelo.state_dict().keys() == esperado.keys()
    for nombre, tensor_esperado in esperado.items():
        assert torch.equal(modelo.state_dict()[nombre].cpu(), tensor_esperado), nombre


def test_operacion_actual_describe_el_worker_en_curso(
    controlador: ModelLibraryController,
    qtbot,
) -> None:
    iniciado = threading.Event()
    liberar = threading.Event()

    def tarea() -> None:
        iniciado.set()
        liberar.wait(timeout=2)

    controlador._ejecutar_en_segundo_plano("verificar el modelo", tarea)
    qtbot.waitUntil(iniciado.is_set, timeout=1000)

    assert controlador.ocupado is True
    assert controlador.operacionActual == "Verificar el modelo"

    liberar.set()
    qtbot.waitUntil(lambda: not controlador.ocupado, timeout=2000)
    assert controlador.operacionActual == ""


def test_helpers_aceptan_file_url_y_generan_destino_sin_sobrescribir(
    tmp_path: Path,
    controlador: ModelLibraryController,
) -> None:
    ruta = tmp_path / "un modelo.tvismodel"
    ruta.touch()
    url = ruta.resolve().as_uri()

    assert _ruta_local(url).resolve() == ruta.resolve()
    primero = controlador._destino_disponible("nombre inseguro?.tvismodel")
    assert primero.name == "nombre inseguro_.tvismodel"
    primero.touch()
    segundo = controlador._destino_disponible("nombre inseguro?.tvismodel")
    assert segundo.name == "nombre inseguro__2.tvismodel"


def test_detalle_historial_y_ficha_local_no_inventan_metricas(
    controlador: ModelLibraryController,
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    ruta = tmp_path / "detalle.tvismodel"
    guardar_modelo_portable(
        ruta,
        _crear_modelo(),
        TokenizerFalso(),
        epoca=2,
        paso_global=7,
        historial_perdidas=[2.2, 1.4],
        hiperparametros_entrenamiento={
            "tasa_aprendizaje": 0.001,
            "batch_size": 4,
        },
        metadata_extra={
            "datasets": [{"nombre": "demo"}],
            "tarea": "pregunta -> respuesta",
        },
    )

    manifiesto = inspeccionar_modelo(ruta)
    descriptor = controlador._crear_descriptor(ruta, manifiesto)
    historial = controlador._inspeccionar_historial(ruta, manifiesto)
    detalle = controlador._crear_detalle(ruta, manifiesto, descriptor, historial)

    assert detalle["historial"]["perdidas"] == [2.2, 1.4]
    assert "validacion" not in detalle["historial"]
    assert "perplexity" not in detalle["historial"]
    assert "precision" not in detalle["historial"]
    assert detalle["procedencia"]["datasets"] == [{"nombre": "demo"}]
    assert detalle["integridad"]["checksum_pesos"]

    controlador.actualizarMetadataModelo(
        str(ruta), "Nombre visible", "nota", ["estable"], "experimento", "v2"
    )
    metadata = controlador._leer_metadata_sidecar(ruta, ignorar_errores=False)
    assert metadata["nombre"] == "Nombre visible"
    assert metadata["tags"] == ["estable"]
    assert metadata["grupo"] == "experimento"
    assert metadata["version"] == "v2"

    monkeypatch.setattr(
        controlador,
        "_ejecutar_en_segundo_plano",
        lambda _descripcion, tarea: tarea(),
    )
    controlador.duplicarModelo(str(ruta), "detalle copia")
    copia = tmp_path / "detalle copia.tvismodel"
    assert copia.is_file()
    inspeccionar_modelo(copia)
    metadata_copia = controlador._leer_metadata_sidecar(
        copia, ignorar_errores=False
    )
    assert metadata_copia["nombre"] == "detalle copia"
    assert metadata_copia["duplicado_de"] == str(ruta.resolve())


def test_tokenizacion_y_salud_exponen_evidencia_revisable(
    controlador: ModelLibraryController,
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    ruta = tmp_path / "salud.tvismodel"
    modelo = _crear_modelo()
    guardar_modelo_portable(ruta, modelo, TokenizerFalso())
    manifiesto = inspeccionar_modelo(ruta)
    descriptor = controlador._crear_descriptor(ruta, manifiesto)

    tokenizer = controlador._crear_tokenizer_ligero(manifiesto, descriptor)
    ids = tokenizer.encode("abc")
    assert ids == [6, 7, 8]
    assert controlador._tokens_especiales(manifiesto, tokenizer) == [
        {"nombre": "PAD", "id": 13},
        {"nombre": "BOS", "id": 14},
        {"nombre": "EOS", "id": 15},
    ]

    resultado = controlador._probar_salud(ruta, modelo, tokenizer)
    assert resultado["resumen"]["muestras"] == 3
    assert resultado["coherencia"]["estado"] == "requiere_revision_humana"
    assert all("hayNaN" in muestra for muestra in resultado["muestras"])
