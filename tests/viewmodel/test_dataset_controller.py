"""Pruebas del catálogo de datasets y sus operaciones asíncronas."""

from __future__ import annotations

import json
from pathlib import Path
import threading

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
