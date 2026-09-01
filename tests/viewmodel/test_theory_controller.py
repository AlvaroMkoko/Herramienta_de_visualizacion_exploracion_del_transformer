"""Pruebas del acceso a teoría contextual del diagrama Transformer."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from viewmodel.theory_controller import TheoryController


MAPA_ESPERADO = {
    "encoder_add_norm_ffn": "flujo_add_norm",
    "encoder_feed_forward": "que_es_ffn",
    "encoder_add_norm_attention": "flujo_add_norm",
    "encoder_self_attention": "que_es_self_attention",
    "input_embedding": "embeddings",
    "encoder_positional_encoding": "positional_encoding",
    "softmax": "softmax_final",
    "linear": "capa_linear_salida",
    "decoder_add_norm_ffn": "flujo_add_norm",
    "decoder_feed_forward": "que_es_ffn",
    "decoder_add_norm_cross": "flujo_add_norm",
    "decoder_cross_attention": "que_es_cross_attention",
    "decoder_add_norm_masked": "flujo_add_norm",
    "decoder_masked_attention": "por_que_mascara",
    "output_embedding": "entrada_decoder",
    "decoder_positional_encoding": "positional_encoding",
}


CONCEPTOS_TECNICOS_REQUERIDOS = {
    "temperature": "salida",
    "top_k": "salida",
    "top_p": "salida",
    "greedy_sampling": "salida",
    "dropout": "entrenamiento",
    "training_step": "entrenamiento",
    "loss_delta": "entrenamiento",
    "gradient_norm_rms": "entrenamiento",
    "gradient_norm_l2": "entrenamiento",
    "weight_norm": "entrenamiento",
    "activation_functions": "feed_forward",
    "context_window": "dimensiones",
    "layer_count": "dimensiones",
    "parameter_count": "dimensiones",
    "pca_projection": "entrada",
    "explained_variance": "entrada",
    "validation_loss": "evaluacion_persistencia",
    "perplexity": "evaluacion_persistencia",
    "accuracy": "evaluacion_persistencia",
    "generalization": "evaluacion_persistencia",
    "checkpoint": "evaluacion_persistencia",
    "dataset": "entrada",
}


def _documento_minimo(
    *,
    id_concepto: str = "concepto_principal",
    titulo: str = "Concepto principal",
    relacionados: list[str] | None = None,
) -> dict:
    conceptos = [
        {
            "id": id_concepto,
            "title": titulo,
            "order": 1,
            "short_description": "Descripción breve",
            "explanation": "Explicación extensa",
            "related_concepts": relacionados or [],
        }
    ]
    if relacionados:
        conceptos.extend(
            {
                "id": id_relacionado,
                "title": f"Relacionado {id_relacionado}",
                "order": indice + 2,
                "short_description": "Otro concepto",
                "explanation": "Otra explicación",
                "related_concepts": [],
            }
            for indice, id_relacionado in enumerate(relacionados)
        )
    return {
        "version": 1,
        "componentes_diagrama": {"bloque": id_concepto},
        "secciones": [
            {
                "id": "seccion_prueba",
                "title": "Sección de prueba",
                "order": 1,
                "conceptos": conceptos,
            }
        ],
    }


def _escribir_json(ruta: Path, datos: dict) -> None:
    ruta.write_text(
        json.dumps(datos, ensure_ascii=False, indent=2), encoding="utf8"
    )


def test_ruta_por_defecto_no_depende_del_directorio_actual(
    monkeypatch, tmp_path
):
    monkeypatch.chdir(tmp_path)

    controlador = TheoryController()
    teoria = controlador.obtenerTeoriaDeComponente("input_embedding")

    assert controlador.errorCarga == ""
    assert teoria["existe"] is True
    assert teoria["id"] == "embeddings"


def test_json_mapea_exhaustivamente_los_16_ids_del_diagrama():
    ruta_json = (
        Path(__file__).resolve().parents[2]
        / "data"
        / "teoria"
        / "transformer.json"
    )
    datos = json.loads(ruta_json.read_text(encoding="utf8"))

    assert datos["componentes_diagrama"] == MAPA_ESPERADO

    controlador = TheoryController(ruta_json)
    for id_componente, id_concepto in MAPA_ESPERADO.items():
        teoria = controlador.obtenerTeoriaDeComponente(id_componente)
        assert teoria["existe"] is True
        assert teoria["componente_id"] == id_componente
        assert teoria["id"] == id_concepto
        assert teoria["title"]
        assert teoria["explanation"]


@pytest.mark.parametrize(
    ("id_concepto", "seccion_esperada"),
    CONCEPTOS_TECNICOS_REQUERIDOS.items(),
)
def test_catalogo_incluye_conceptos_tecnicos_con_contenido_pedagogico(
    id_concepto, seccion_esperada
):
    controlador = TheoryController()

    concepto = controlador.obtenerConcepto(id_concepto)

    assert controlador.errorCarga == ""
    assert concepto["existe"] is True
    assert concepto["id"] == id_concepto
    assert concepto["seccion"] == seccion_esperada
    assert len(concepto["title"].strip()) >= 3
    assert len(concepto["short_description"].strip()) >= 20
    assert len(concepto["explanation"].strip()) >= 120
    assert any(
        concepto.get(campo)
        for campo in ("formula", "example", "steps")
    )

    ids_relacionados = concepto.get("related_concepts", [])
    relacionados_resueltos = controlador.obtenerRelacionados(id_concepto)
    assert ids_relacionados
    assert [item["id"] for item in relacionados_resueltos] == ids_relacionados
    assert all(
        item["title"] and item["short_description"]
        for item in relacionados_resueltos
    )


def test_teoria_de_componente_incluye_relacionados_resueltos(tmp_path):
    ruta = tmp_path / "teoria.json"
    _escribir_json(
        ruta,
        _documento_minimo(relacionados=["detalle_uno", "detalle_dos"]),
    )
    controlador = TheoryController(ruta)

    teoria = controlador.obtenerTeoriaDeComponente("bloque")

    assert teoria["id"] == "concepto_principal"
    assert teoria["seccion"] == "seccion_prueba"
    assert teoria["relacionados"] == [
        {
            "id": "detalle_uno",
            "title": "Relacionado detalle_uno",
            "short_description": "Otro concepto",
            "seccion": "seccion_prueba",
        },
        {
            "id": "detalle_dos",
            "title": "Relacionado detalle_dos",
            "short_description": "Otro concepto",
            "seccion": "seccion_prueba",
        },
    ]
    assert controlador.obtenerRelacionados("concepto_principal") == teoria[
        "relacionados"
    ]


def test_componente_desconocido_devuelve_fallback_estable(tmp_path):
    ruta = tmp_path / "teoria.json"
    _escribir_json(ruta, _documento_minimo())
    controlador = TheoryController(ruta)

    teoria = controlador.obtenerTeoriaDeComponente("bloque_desconocido")

    assert teoria == {
        "id": "bloque_desconocido",
        "title": "Sin información todavía",
        "short_description": "",
        "explanation": (
            'Todavía no hay teoría escrita para "bloque_desconocido".'
        ),
        "existe": False,
        "seccion": "",
        "componente_id": "bloque_desconocido",
        "relacionados": [],
    }


def test_json_invalido_no_lanza_y_expone_error_de_carga(tmp_path):
    ruta = tmp_path / "teoria.json"
    ruta.write_text("{esto no es json", encoding="utf8")
    controlador = TheoryController(ruta)

    teoria = controlador.obtenerTeoriaDeComponente("bloque")

    assert teoria["existe"] is False
    assert teoria["relacionados"] == []
    assert controlador.obtenerSecciones() == []
    assert "JSON inválido" in controlador.errorCarga


def test_rechaza_ids_de_concepto_duplicados(tmp_path):
    ruta = tmp_path / "teoria.json"
    datos = _documento_minimo()
    datos["secciones"][0]["conceptos"].append(
        {
            "id": "concepto_principal",
            "title": "Duplicado",
            "explanation": "No debe sobrescribir al original",
        }
    )
    _escribir_json(ruta, datos)
    controlador = TheoryController(ruta)

    assert "duplicado" in controlador.errorCarga
    assert controlador.obtenerConcepto("concepto_principal")["existe"] is False


def test_rechaza_claves_json_duplicadas_en_el_mapa(tmp_path):
    ruta = tmp_path / "teoria.json"
    ruta.write_text(
        """
        {
          "componentes_diagrama": {
            "bloque": "uno",
            "bloque": "dos"
          },
          "secciones": []
        }
        """,
        encoding="utf8",
    )
    controlador = TheoryController(ruta)

    assert "contenido duplicado" in controlador.errorCarga
    assert "'bloque'" in controlador.errorCarga


def test_rechaza_mapeo_hacia_concepto_inexistente(tmp_path):
    ruta = tmp_path / "teoria.json"
    datos = _documento_minimo()
    datos["componentes_diagrama"]["bloque"] = "no_existe"
    _escribir_json(ruta, datos)
    controlador = TheoryController(ruta)

    assert "concepto inexistente 'no_existe'" in controlador.errorCarga
    assert controlador.obtenerTeoriaDeComponente("bloque")["existe"] is False


def test_recargar_reconstruye_indices_y_actualiza_contenido(tmp_path):
    ruta = tmp_path / "teoria.json"
    _escribir_json(ruta, _documento_minimo(titulo="Antes"))
    controlador = TheoryController(ruta)

    assert controlador.obtenerTeoriaDeComponente("bloque")["title"] == "Antes"

    _escribir_json(ruta, _documento_minimo(titulo="Después"))

    assert controlador.recargar() is True
    assert controlador.obtenerTeoriaDeComponente("bloque")["title"] == "Después"
