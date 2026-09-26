"""Pruebas del repositorio persistente de resultados (esquema v2).

Dos comportamientos concentran casi toda la prueba. El primero es que un
archivo dañado nunca puede impedir que la aplicación arranque. El segundo es que
los resultados del instrumento v1 se archivan en vez de mezclarse: comparar un
pre-test de 8 reactivos contra un post-test de 20 produciría un número con
apariencia de dato y sin significado.
"""

from __future__ import annotations

import json

import pytest

from model.evaluacion.results_repository import (
    RESULT_SCHEMA_VERSION,
    ResultsRepository,
)


def resultado(tipo: str = "pre", puntaje: float = 15.0) -> dict:
    """Resultado mínimo con la forma que produce ``compute_metrics``."""
    return {
        "schema_version": RESULT_SCHEMA_VERSION,
        "assessment_type": tipo,
        "puntaje": puntaje,
        "maximo": 20.0,
        "percentage": round(puntaje * 5, 1),
    }


def resultado_v1(tipo: str = "pre") -> dict:
    """Resultado del instrumento anterior: sin versión y con conteo entero."""
    return {"assessment_type": tipo, "correct": 6, "total": 8, "percentage": 75.0}


# ---------------------------------------------------------------------------
# Persistencia
# ---------------------------------------------------------------------------


def test_guarda_y_relee_entre_sesiones(tmp_path):
    ruta = tmp_path / "resultados.json"
    ResultsRepository(ruta).save_result(resultado())

    # Un repositorio nuevo equivale a reabrir la aplicación.
    assert ResultsRepository(ruta).latest("pre") == resultado()


def test_el_archivo_declara_la_version_del_esquema(tmp_path):
    ruta = tmp_path / "resultados.json"
    ResultsRepository(ruta).save_result(resultado())

    contenido = json.loads(ruta.read_text(encoding="utf-8"))
    assert contenido["version"] == RESULT_SCHEMA_VERSION
    assert contenido["results"][0]["schema_version"] == RESULT_SCHEMA_VERSION


def test_se_sella_la_version_aunque_no_venga(tmp_path):
    ruta = tmp_path / "resultados.json"
    crudo = {"assessment_type": "pre", "puntaje": 12.0, "maximo": 20.0}
    ResultsRepository(ruta).save_result(crudo)

    assert ResultsRepository(ruta).latest("pre")["schema_version"] == (
        RESULT_SCHEMA_VERSION
    )


def test_crea_las_carpetas_que_falten(tmp_path):
    ruta = tmp_path / "sin" / "crear" / "resultados.json"
    ResultsRepository(ruta).save_result(resultado())

    assert ruta.is_file()


def test_la_escritura_es_atomica(tmp_path):
    """No debe quedar un .tmp: un cierre abrupto no puede dejar el archivo a
    medias ni basura al lado."""
    ruta = tmp_path / "resultados.json"
    ResultsRepository(ruta).save_result(resultado())

    assert list(tmp_path.glob("*.tmp")) == []


def test_sin_ruta_no_toca_el_disco(tmp_path):
    repositorio = ResultsRepository()
    repositorio.save_result(resultado())

    assert repositorio.latest("pre")["puntaje"] == 15.0
    assert list(tmp_path.iterdir()) == []


# ---------------------------------------------------------------------------
# Resultados de instrumentos anteriores
# ---------------------------------------------------------------------------


def test_los_resultados_v1_se_archivan_fuera_del_historial(tmp_path):
    ruta = tmp_path / "resultados.json"
    ruta.write_text(
        json.dumps(
            {"version": 1, "results": [resultado_v1("pre"), resultado_v1("post")]}
        ),
        encoding="utf-8",
    )

    repositorio = ResultsRepository(ruta)

    assert repositorio.get_history() == []
    assert repositorio.archived_count == 2
    # Lo importante: no contaminan el cálculo de avance pre→post.
    assert repositorio.latest("pre") == {}
    assert repositorio.latest("post") == {}


def test_archivar_no_pierde_los_resultados_v1(tmp_path):
    ruta = tmp_path / "resultados.json"
    ruta.write_text(
        json.dumps({"version": 1, "results": [resultado_v1()]}), encoding="utf-8"
    )

    ResultsRepository(ruta)

    contenido = json.loads(ruta.read_text(encoding="utf-8"))
    assert contenido["version"] == RESULT_SCHEMA_VERSION
    assert len(contenido["archivados"]) == 1
    assert contenido["archivados"][0]["correct"] == 6


def test_v1_y_v2_conviven_sin_mezclarse(tmp_path):
    ruta = tmp_path / "resultados.json"
    ruta.write_text(
        json.dumps({"version": 1, "results": [resultado_v1("pre"), resultado("pre")]}),
        encoding="utf-8",
    )

    repositorio = ResultsRepository(ruta)

    assert len(repositorio.get_history()) == 1
    assert repositorio.archived_count == 1
    assert repositorio.latest("pre")["puntaje"] == 15.0


def test_los_archivados_sobreviven_a_una_recarga(tmp_path):
    ruta = tmp_path / "resultados.json"
    ruta.write_text(
        json.dumps({"version": 1, "results": [resultado_v1()]}), encoding="utf-8"
    )

    ResultsRepository(ruta)
    assert ResultsRepository(ruta).archived_count == 1


# ---------------------------------------------------------------------------
# Tolerancia a archivos dañados
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "contenido",
    [
        "{no es json",
        "",
        json.dumps({"version": 2, "results": {}}),
        json.dumps({"version": 2, "results": "no es una lista"}),
        json.dumps({"foo": 1}),
        json.dumps("una cadena suelta"),
        json.dumps(42),
    ],
    ids=[
        "json_invalido",
        "vacio",
        "results_es_dict",
        "results_es_cadena",
        "sin_results",
        "raiz_cadena",
        "raiz_numero",
    ],
)
def test_un_archivo_danado_deja_el_historial_vacio_sin_lanzar(tmp_path, contenido):
    ruta = tmp_path / "resultados.json"
    ruta.write_text(contenido, encoding="utf-8")

    assert ResultsRepository(ruta).get_history() == []


def test_una_lista_desnuda_se_acepta_por_compatibilidad(tmp_path):
    """El formato más antiguo era una lista sin envoltorio de versión."""
    ruta = tmp_path / "resultados.json"
    ruta.write_text(json.dumps([resultado()]), encoding="utf-8")

    assert len(ResultsRepository(ruta).get_history()) == 1


def test_descarta_entradas_sin_tipo_de_evaluacion(tmp_path):
    ruta = tmp_path / "resultados.json"
    ruta.write_text(
        json.dumps({"version": 2, "results": [{}, "x", resultado()]}), encoding="utf-8"
    )

    historial = ResultsRepository(ruta).get_history()
    assert len(historial) == 1
    assert historial[0]["assessment_type"] == "pre"


def test_un_archivo_inexistente_no_es_un_error(tmp_path):
    assert ResultsRepository(tmp_path / "todavia_no.json").get_history() == []


# ---------------------------------------------------------------------------
# Consulta y borrado
# ---------------------------------------------------------------------------


def test_latest_filtra_por_tipo_y_devuelve_el_mas_reciente(tmp_path):
    repositorio = ResultsRepository(tmp_path / "resultados.json")
    repositorio.save_result(resultado("pre", 10.0))
    repositorio.save_result(resultado("post", 18.0))
    repositorio.save_result(resultado("pre", 12.0))

    assert repositorio.latest("pre")["puntaje"] == 12.0
    assert repositorio.latest("post")["puntaje"] == 18.0
    assert repositorio.latest("inexistente") == {}


def test_get_history_puede_filtrar_por_tipo(tmp_path):
    repositorio = ResultsRepository(tmp_path / "resultados.json")
    repositorio.save_result(resultado("pre"))
    repositorio.save_result(resultado("post"))

    assert len(repositorio.get_history()) == 2
    assert len(repositorio.get_history("pre")) == 1


def test_lo_devuelto_es_una_copia(tmp_path):
    """Mutar lo que devuelve el repositorio no puede alterar su estado."""
    repositorio = ResultsRepository(tmp_path / "resultados.json")
    repositorio.save_result(resultado())

    repositorio.latest("pre")["puntaje"] = 999.0
    repositorio.get_history()[0]["puntaje"] = 999.0

    assert repositorio.latest("pre")["puntaje"] == 15.0


def test_clear_borra_historial_archivados_y_archivo(tmp_path):
    ruta = tmp_path / "resultados.json"
    ruta.write_text(
        json.dumps({"version": 1, "results": [resultado_v1()]}), encoding="utf-8"
    )
    repositorio = ResultsRepository(ruta)
    repositorio.save_result(resultado("post"))

    repositorio.clear()

    assert repositorio.get_history() == []
    assert repositorio.archived_count == 0
    assert not ruta.exists()
    assert ResultsRepository(ruta).get_history() == []
