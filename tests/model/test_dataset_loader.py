"""Contratos de lectura para datasets estructurados usados por la interfaz."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from model.gestor_de_datos.dataset_loader import cargar_pares_combinados


REGISTROS_VALIDOS = [
    {
        "instruction": "¿Qué ave nada?",
        "context": "El pingüino es un ave marina.",
        "response": "El pingüino.",
    },
    {
        "instruction": "Saluda en español",
        "context": "   ",
        "response": "¡Hola!",
    },
]


def _contenido_estructurado(extension: str, registros: list[dict]) -> str:
    if extension == ".jsonl":
        return "".join(
            json.dumps(registro, ensure_ascii=False) + "\n" for registro in registros
        )
    if extension == ".json":
        return json.dumps(registros, ensure_ascii=False)
    if extension == ".csv":
        filas = ["instruction,context,response"]
        filas.extend(
            f'{registro["instruction"]},{registro.get("context", "")},{registro["response"]}'
            for registro in registros
        )
        return "\n".join(filas) + "\n"
    raise AssertionError(f"Extensión de prueba no soportada: {extension}")


@pytest.mark.parametrize("extension", [".jsonl", ".json", ".csv"])
def test_formatos_estructurados_producen_los_mismos_pares_con_contexto(
    tmp_path: Path,
    extension: str,
) -> None:
    ruta = tmp_path / f"dataset{extension}"
    ruta.write_text(
        _contenido_estructurado(extension, REGISTROS_VALIDOS), encoding="utf8"
    )

    pares = cargar_pares_combinados([(str(ruta), extension)])

    assert pares == [
        ("¿Qué ave nada?\nEl pingüino es un ave marina.", "El pingüino."),
        ("Saluda en español", "¡Hola!"),
    ]


@pytest.mark.parametrize("extension", [".jsonl", ".json", ".csv"])
@pytest.mark.parametrize("campo_vacio", ["instruction", "response"])
def test_formatos_estructurados_rechazan_campos_obligatorios_vacios(
    tmp_path: Path,
    extension: str,
    campo_vacio: str,
) -> None:
    registro = {
        "instruction": "Entrada válida",
        "context": "Contexto opcional",
        "response": "Respuesta válida",
    }
    registro[campo_vacio] = "   "
    ruta = tmp_path / f"vacio{extension}"
    ruta.write_text(
        _contenido_estructurado(extension, [registro]), encoding="utf8"
    )

    with pytest.raises(ValueError, match=rf"{campo_vacio}.*debe contener texto"):
        cargar_pares_combinados([(str(ruta), extension)])


@pytest.mark.parametrize("extension", [".jsonl", ".json"])
@pytest.mark.parametrize(
    ("campo", "valor"),
    [("instruction", None), ("response", 42)],
)
def test_json_y_jsonl_rechazan_campos_obligatorios_que_no_son_texto(
    tmp_path: Path,
    extension: str,
    campo: str,
    valor: object,
) -> None:
    registro = {
        "instruction": "Entrada válida",
        "context": "",
        "response": "Respuesta válida",
    }
    registro[campo] = valor
    ruta = tmp_path / f"tipo_invalido{extension}"
    ruta.write_text(
        _contenido_estructurado(extension, [registro]), encoding="utf8"
    )

    with pytest.raises(ValueError, match=rf"{campo}.*debe contener texto"):
        cargar_pares_combinados([(str(ruta), extension)])
