from __future__ import annotations

import json

from model.evaluacion.results_repository import ResultsRepository


def resultado(tipo: str = "pre") -> dict:
    return {"assessment_type": tipo, "percentage": 75.0}


def test_guarda_y_relee_resultados_desde_ruta(tmp_path):
    ruta = tmp_path / "resultados.json"
    ResultsRepository(ruta).save_result(resultado())

    contenido = json.loads(ruta.read_text(encoding="utf-8"))
    assert contenido["version"] == 1
    assert ResultsRepository(ruta).latest("pre") == resultado()


def test_archivo_corrupto_no_lanza_excepcion(tmp_path):
    ruta = tmp_path / "resultados.json"
    ruta.write_text("{no es json", encoding="utf-8")

    assert ResultsRepository(ruta).get_history() == []


def test_contenido_no_lista_es_historial_vacio(tmp_path):
    ruta = tmp_path / "resultados.json"
    ruta.write_text(json.dumps({"version": 1, "results": {}}), encoding="utf-8")

    assert ResultsRepository(ruta).get_history() == []


def test_lista_desnuda_se_acepta_por_compatibilidad(tmp_path):
    ruta = tmp_path / "resultados.json"
    ruta.write_text(json.dumps([resultado()]), encoding="utf-8")

    assert ResultsRepository(ruta).get_history() == [resultado()]


def test_descarta_entradas_sin_tipo(tmp_path):
    ruta = tmp_path / "resultados.json"
    ruta.write_text(json.dumps([{}, resultado()]), encoding="utf-8")

    assert ResultsRepository(ruta).get_history() == [resultado()]


def test_clear_vacia_el_historial_y_el_archivo(tmp_path):
    ruta = tmp_path / "resultados.json"
    repositorio = ResultsRepository(ruta)
    repositorio.save_result(resultado())
    repositorio.clear()

    assert repositorio.get_history() == []
    assert not ruta.exists()


def test_latest_filtra_por_tipo(tmp_path):
    repositorio = ResultsRepository(tmp_path / "resultados.json")
    repositorio.save_result(resultado("pre"))
    repositorio.save_result(resultado("post"))

    assert repositorio.latest("post")["assessment_type"] == "post"


def test_sin_ruta_no_crea_archivos(tmp_path):
    repositorio = ResultsRepository()
    repositorio.save_result(resultado())

    assert list(tmp_path.iterdir()) == []
