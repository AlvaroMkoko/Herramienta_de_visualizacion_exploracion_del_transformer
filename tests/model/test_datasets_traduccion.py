"""Invariantes de los datasets de traducción generados desde Tatoeba.

Los archivos los produce ``tools/filtrar_tatoeba.py`` y viven en el repositorio:
el modelo se entrena con ellos. Estas pruebas atrapan una regeneración con el
script mal invocado o editado, que daría un corpus plausible y malo sin que
ningún otro recuento lo notara.
"""

from __future__ import annotations

import json
import re

import pytest

from core.rutas import recurso
from model.motor_llm.tokenizer import Tokenizer

DIRECTORIO = recurso("data", "datasets_predefinidos")
# El mapa de atención es longitud × longitud: fuera de este rango la matriz es
# ilegible o casi vacía.
TOKENS_MINIMO, TOKENS_MAXIMO = 3, 16
TOM_EN = re.compile(r"\bTom\b")
TOM_ES = re.compile(r"\bTom(ás)?\b")


def _pares(id_dataset: str) -> list[tuple[str, str]]:
    catalogo = json.loads((DIRECTORIO / "catalogo.json").read_text(encoding="utf8"))
    entrada = next(e for e in catalogo if e["id"] == id_dataset)
    pares = []
    for linea in (DIRECTORIO / entrada["archivo"]).read_text(encoding="utf8").splitlines():
        if linea.strip():
            registro = json.loads(linea)
            pares.append((registro["instruction"], registro["response"]))
    return pares


@pytest.fixture(scope="module")
def es_en() -> list[tuple[str, str]]:
    return _pares("PRE-TRADUCCION")


@pytest.fixture(scope="module")
def en_es() -> list[tuple[str, str]]:
    return _pares("PRE-TRADUCCION-EN")


def test_longitud_en_tokens_dentro_del_rango_en_los_dos_lados(es_en):
    # Con el tokenizador y la codificación que usa la herramienta, no split():
    # el español se parte en más piezas de las que uno espera.
    tokenizer = Tokenizer(tipo_encoding=1)
    assert tokenizer.encoding.name == "cl100k_base"
    fuera = [
        (texto, len(tokenizer.encode(texto)))
        for par in es_en
        for texto in par
        if not TOKENS_MINIMO <= len(tokenizer.encode(texto)) <= TOKENS_MAXIMO
    ]
    assert fuera == []


def test_cada_frase_aparece_una_sola_vez_en_cada_lado(es_en):
    espanol = [origen for origen, _ in es_en]
    ingles = [destino for _, destino in es_en]
    assert len(set(espanol)) == len(espanol)
    assert len(set(ingles)) == len(ingles)
    assert all(origen.casefold() != destino.casefold() for origen, destino in es_en)


def test_en_es_es_la_inversion_exacta_de_es_en(es_en, en_es):
    assert en_es == [(destino, origen) for origen, destino in es_en]


def test_tom_no_pasa_de_la_cuota(es_en):
    # Tatoeba nombra a Tom en uno de cada ocho pares; sin cuota, el modelo
    # aprende más de Tom que del español.
    con_tom = sum(1 for origen, destino in es_en if TOM_ES.search(origen) or TOM_EN.search(destino))
    assert 0.02 <= con_tom / len(es_en) <= 0.03, con_tom
