"""Pruebas del catálogo de datasets y sus operaciones asíncronas."""

from __future__ import annotations

import json
from pathlib import Path
import threading

import pytest
from PySide6.QtCore import QThread, QTimer, QUrl

from viewmodel import dataset_controller as modulo_datasets
from viewmodel.dataset_controller import DatasetController


def _crear_controlador(
    tmp_path: Path,
    monkeypatch,
) -> DatasetController:
    catalogo = tmp_path / "catalogo" / "datasets.json"
    monkeypatch.setattr(DatasetController, "DATASET_FILE", catalogo)
    return DatasetController()


def test_api_sincrona_se_conserva_y_acepta_file_url(
    tmp_path: Path,
    monkeypatch,
) -> None:
    controlador = _crear_controlador(tmp_path, monkeypatch)
    ruta = tmp_path / "ejemplo con espacios.jsonl"
    ruta.write_text(
        '{"pregunta": "hola mundo", "respuesta": "hola", "categoria": "demo"}\n'
        '{"pregunta": "otra pregunta", "respuesta": "otra respuesta"}\n',
        encoding="utf8",
    )

    dataset = controlador.agregarDataset(QUrl.fromLocalFile(str(ruta)).toString())

    assert dataset["id"] == "DS-001"
    assert dataset["registros"] == 2
    assert dataset["tokens"] == 8
    assert dataset["categorias"] == {"demo": 1}
    assert controlador.obtenerRegistros(dataset["id"], 1) == [
        {"pregunta": "hola mundo", "respuesta": "hola", "categoria": "demo"}
    ]
    assert json.loads(controlador.DATASET_FILE.read_text(encoding="utf8"))[0][
        "checksum"
    ] == dataset["checksum"]


def test_agregar_async_reporta_fases_y_hace_commit_en_hilo_del_controlador(
    tmp_path: Path,
    monkeypatch,
    qtbot,
) -> None:
    controlador = _crear_controlador(tmp_path, monkeypatch)
    ruta = tmp_path / "datos.jsonl"
    ruta.write_text(
        "".join(
            json.dumps({"texto": f"registro numero {indice}"}) + "\n"
            for indice in range(20)
        ),
        encoding="utf8",
    )
    progresos: list[dict] = []
    hilos_progreso: list[QThread] = []
    hilos_guardado: list[QThread] = []
    guardar_original = controlador.guardar_datasets

    def guardar_observado() -> None:
        hilos_guardado.append(QThread.currentThread())
        guardar_original()

    monkeypatch.setattr(controlador, "guardar_datasets", guardar_observado)
    def registrar_progreso() -> None:
        progresos.append(dict(controlador.progreso))
        hilos_progreso.append(QThread.currentThread())

    controlador.progresoCambio.connect(registrar_progreso)

    with qtbot.waitSignal(controlador.resultado, timeout=3000) as final:
        assert controlador.agregarDatasetAsync(str(ruta)) is True
        assert controlador.ocupado is True

    payload = final.args[0]
    assert controlador.ocupado is False
    assert payload["operacion"] == "agregar"
    assert payload["dataset"]["id"] == "DS-001"
    assert len(controlador.datasets) == 1
    assert hilos_guardado == [controlador.thread()]
    assert hilos_progreso
    assert all(hilo == controlador.thread() for hilo in hilos_progreso)
    assert any(item.get("fase") == "Analizando registros" for item in progresos)
    hashes = [
        item for item in progresos if item.get("fase") == "Verificando integridad"
    ]
    assert hashes
    assert hashes[-1]["valor"] == ruta.stat().st_size
    assert hashes[-1]["total"] == ruta.stat().st_size
    assert hashes[-1]["porcentaje"] == 100.0


def test_async_no_bloquea_eventos_y_rechaza_doble_inicio(
    tmp_path: Path,
    monkeypatch,
    qtbot,
) -> None:
    controlador = _crear_controlador(tmp_path, monkeypatch)
    ruta = tmp_path / "lento.txt"
    ruta.write_text("uno\ndos\n", encoding="utf8")
    entro_al_worker = threading.Event()
    continuar = threading.Event()
    analizar_original = modulo_datasets._analizar_dataset

    def analizar_lento(ruta_local, dataset_id, reportar=None):
        entro_al_worker.set()
        assert continuar.wait(timeout=2)
        return analizar_original(ruta_local, dataset_id, reportar)

    monkeypatch.setattr(modulo_datasets, "_analizar_dataset", analizar_lento)

    assert controlador.agregarDatasetAsync(str(ruta)) is True
    assert entro_al_worker.wait(timeout=1)
    assert controlador.agregarDatasetAsync(str(ruta)) is False

    temporizador_atendido: list[bool] = []
    QTimer.singleShot(0, lambda: temporizador_atendido.append(True))
    qtbot.waitUntil(lambda: temporizador_atendido == [True], timeout=1000)

    with qtbot.waitSignal(controlador.resultado, timeout=3000):
        continuar.set()


def test_vista_previa_async_entrega_registros_y_reporta_error(
    tmp_path: Path,
    monkeypatch,
    qtbot,
) -> None:
    controlador = _crear_controlador(tmp_path, monkeypatch)
    ruta = tmp_path / "tabla.csv"
    ruta.write_text("entrada,salida\nhola,mundo\nuno,dos\ntres,cuatro\n", encoding="utf8")
    dataset = controlador.agregarDataset(str(ruta))

    with qtbot.waitSignal(controlador.resultado, timeout=3000) as final:
        assert controlador.obtenerRegistrosAsync(dataset["id"], 2) is True

    payload = final.args[0]
    assert payload == {
        "operacion": "vista_previa",
        "dataset_id": dataset["id"],
        "registros": [
            {"entrada": "hola", "salida": "mundo"},
            {"entrada": "uno", "salida": "dos"},
        ],
    }
    assert controlador.ocupado is False

    errores: list[str] = []
    controlador.error.connect(errores.append)
    ruta.unlink()
    with qtbot.waitSignal(controlador.error, timeout=3000):
        assert controlador.obtenerRegistrosAsync(dataset["id"], 2) is True
    assert "No se encontró el dataset" in errores[-1]
    assert controlador.ocupado is False


def test_crear_dataset_manual_escribe_jsonl_utf8_y_actualiza_catalogo_y_preview(
    tmp_path: Path,
    monkeypatch,
) -> None:
    controlador = _crear_controlador(tmp_path, monkeypatch)
    registros = [
        {
            "instruction": "  ¿Cómo estás?  ",
            "context": "  Conversación en español. ",
            "response": "  Muy bien, gracias. ",
            "category": "  saludo ",
        },
        {
            "instruction": "Resume el texto",
            "context": "El pingüino nada.",
            "response": "Un pingüino está nadando.",
            "category": "",
        },
    ]
    agregados: list[dict] = []
    controlador.datasetAgregado.connect(agregados.append)

    resultado = controlador.crearDatasetManual("Dataset español útil", registros)

    assert resultado["ok"] is True
    dataset = resultado["dataset"]
    ruta = Path(dataset["ruta"])
    assert ruta.parent == controlador.DATASET_FILE.parent / "creados"
    assert ruta.suffix == ".jsonl"
    assert dataset["nombre"] == "Dataset español útil"
    assert dataset["creado_por_app"] is True
    assert dataset["compatible_entrenamiento"] is True
    assert dataset["pares_validos"] == 2
    assert dataset["estado"] == "Listo para entrenar"

    contenido = ruta.read_bytes().decode("utf8")
    assert "¿Cómo estás?" in contenido
    assert "pingüino" in contenido
    registros_guardados = [
        json.loads(linea) for linea in contenido.splitlines() if linea.strip()
    ]
    assert registros_guardados == [
        {
            "instruction": "¿Cómo estás?",
            "context": "Conversación en español.",
            "response": "Muy bien, gracias.",
            "category": "saludo",
        },
        {
            "instruction": "Resume el texto",
            "context": "El pingüino nada.",
            "response": "Un pingüino está nadando.",
        },
    ]
    assert controlador.obtenerRegistros(dataset["id"], 10) == registros_guardados
    assert controlador.obtenerDatasets() == [dataset]
    assert agregados == [dataset]
    assert json.loads(controlador.DATASET_FILE.read_text(encoding="utf8")) == [
        dataset
    ]


@pytest.mark.parametrize(
    ("nombre", "registros", "mensaje_esperado"),
    [
        ("", [{"instruction": "Pregunta", "response": "Respuesta"}], "nombre"),
        ("demo", [], "al menos un ejemplo"),
        ("demo", [{"response": "Respuesta"}], "'instruction'"),
        (
            "demo",
            [{"instruction": "Pregunta", "response": "   "}],
            "'response'",
        ),
        (
            "demo",
            [{"instruction": "Pregunta", "context": 42, "response": "Respuesta"}],
            "debe ser texto",
        ),
    ],
)
def test_crear_dataset_manual_rechaza_datos_incompletos_sin_mutar_catalogo(
    tmp_path: Path,
    monkeypatch,
    nombre: str,
    registros: list,
    mensaje_esperado: str,
) -> None:
    controlador = _crear_controlador(tmp_path, monkeypatch)

    resultado = controlador.crearDatasetManual(nombre, registros)

    assert resultado["ok"] is False
    assert mensaje_esperado in resultado["mensaje"]
    assert controlador.obtenerDatasets() == []
    assert json.loads(controlador.DATASET_FILE.read_text(encoding="utf8")) == []
    creados = controlador.DATASET_FILE.parent / "creados"
    assert not creados.exists() or list(creados.iterdir()) == []


def test_crear_dataset_manual_resuelve_colision_sin_sobrescribir(
    tmp_path: Path,
    monkeypatch,
) -> None:
    controlador = _crear_controlador(tmp_path, monkeypatch)
    directorio = controlador.DATASET_FILE.parent / "creados"
    directorio.mkdir(parents=True)
    ruta_preexistente = directorio / "mi_dataset.jsonl"
    contenido_preexistente = b'{"dato": "no reemplazar"}\n'
    ruta_preexistente.write_bytes(contenido_preexistente)

    resultado = controlador.crearDatasetManual(
        "Mi dataset",
        [{"instruction": "Entrada", "context": "", "response": "Salida"}],
    )

    assert resultado["ok"] is True
    ruta_creada = Path(resultado["dataset"]["ruta"])
    assert ruta_creada.name == "mi_dataset_2.jsonl"
    assert ruta_creada != ruta_preexistente
    assert ruta_preexistente.read_bytes() == contenido_preexistente
    assert json.loads(ruta_creada.read_text(encoding="utf8")) == {
        "instruction": "Entrada",
        "context": "",
        "response": "Salida",
    }


@pytest.mark.parametrize(
    ("nombre_archivo", "contenido"),
    [
        (
            "compatible.jsonl",
            '{"instruction": "Entrada", "context": "", "response": "Salida"}\n',
        ),
        (
            "compatible.json",
            '[{"instruction": "Entrada", "context": "", "response": "Salida"}]',
        ),
        (
            "compatible.csv",
            "instruction,context,response\nEntrada,,Salida\n",
        ),
    ],
)
def test_importacion_estructurada_publica_metadatos_de_compatibilidad(
    tmp_path: Path,
    monkeypatch,
    nombre_archivo: str,
    contenido: str,
) -> None:
    controlador = _crear_controlador(tmp_path, monkeypatch)
    ruta = tmp_path / nombre_archivo
    ruta.write_text(contenido, encoding="utf8")

    dataset = controlador.agregarDataset(str(ruta))

    assert dataset["compatible_entrenamiento"] is True
    assert dataset["pares_validos"] == 1
    assert dataset["estado"] == "Listo para entrenar"
    assert "instruction" in dataset["campos"]
    assert "response" in dataset["campos"]
    assert "pares instruction" in dataset["mensaje_compatibilidad"]


@pytest.mark.parametrize(
    ("nombre_archivo", "contenido", "mensaje_esperado"),
    [
        (
            "sin_respuesta.jsonl",
            '{"instruction": "Entrada", "context": ""}\n',
            "Faltan los campos obligatorios: response",
        ),
        (
            "respuesta_vacia.json",
            '[{"instruction": "Entrada", "response": "   "}]',
            "1 registro(s)",
        ),
        (
            "entrada_vacia.csv",
            "instruction,context,response\n,,Salida\n",
            "1 registro(s)",
        ),
    ],
)
def test_importacion_estructurada_explica_por_que_no_es_compatible(
    tmp_path: Path,
    monkeypatch,
    nombre_archivo: str,
    contenido: str,
    mensaje_esperado: str,
) -> None:
    controlador = _crear_controlador(tmp_path, monkeypatch)
    ruta = tmp_path / nombre_archivo
    ruta.write_text(contenido, encoding="utf8")

    dataset = controlador.agregarDataset(str(ruta))

    assert dataset["compatible_entrenamiento"] is False
    assert dataset["pares_validos"] == 0
    assert dataset["estado"] == "Revisar formato"
    assert mensaje_esperado in dataset["mensaje_compatibilidad"]
