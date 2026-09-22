"""Calificación de reactivos del pre-test y post-test (esquema v2).

Funciones puras, sin Qt y sin estado. Cada tipo de reactivo tiene su propia
función de calificación registrada en ``_SCORERS``; agregar un formato nuevo es
escribir la función y registrarla, sin tocar el resto del módulo.

Contrato de las respuestas que llegan desde el ViewModel::

    opcion_unica        {"opcion_id": "c"}
    seleccion_multiple  {"opciones_ids": ["a", "b"]}
    texto               {"texto": "BPE"}
    asignacion          {"asignaciones": {"p1": "3", "p2": "4", ...}}
    etapas              {"etapas": {"e1": {"opcion_id": "no"},
                                    "e2": {"opcion_id": "a"}}}
    texto_libre         {"texto": "..."}   (solo como etapa)

Toda función de calificación devuelve::

    {"puntaje": 0.75, "maximo": 1.0, "correcto": False, "detalle": {...}}
"""

from __future__ import annotations

import re
import unicodedata
from typing import Any, Callable, Mapping


class ScoringError(ValueError):
    """El reactivo declara un tipo que no sabemos calificar."""


# ---------------------------------------------------------------------------
# Normalización de texto libre
# ---------------------------------------------------------------------------

_NO_ALFANUMERICO = re.compile(r"[^0-9a-z]+")


def normalizar_texto(valor: Any) -> str:
    """Minúsculas, sin acentos y sin signos, para comparar respuestas abiertas.

    ``"Byte-Pair Encoding"``, ``"byte pair encoding"`` y ``"BYTE  PAIR ENCODING."``
    colapsan todos a ``"byte pair encoding"``. Se aplica por igual a la respuesta
    del estudiante y a la lista de respuestas aceptadas, de modo que el banco
    puede escribirse con acentos sin que eso afecte la comparación.
    """
    texto = unicodedata.normalize("NFD", str(valor or "")).lower()
    texto = "".join(c for c in texto if unicodedata.category(c) != "Mn")
    return _NO_ALFANUMERICO.sub(" ", texto).strip()


# ---------------------------------------------------------------------------
# Utilidades internas
# ---------------------------------------------------------------------------

def _maximo(question: Mapping[str, Any]) -> float:
    try:
        return float(question.get("puntaje_maximo", 1.0))
    except (TypeError, ValueError):
        return 1.0


def _resultado(
    fraccion: float, maximo: float, detalle: dict[str, Any] | None = None
) -> dict[str, Any]:
    fraccion = max(0.0, min(1.0, float(fraccion)))
    puntaje = round(fraccion * maximo, 4)
    return {
        "puntaje": puntaje,
        "maximo": maximo,
        "correcto": fraccion >= 1.0,
        "detalle": detalle or {},
    }


def _como_dict(respuesta: Any) -> dict[str, Any]:
    return respuesta if isinstance(respuesta, Mapping) else {}


def _lista_de_ids(valor: Any) -> list[str]:
    """QML puede entregar una lista, una cadena suelta o ``None``."""
    if valor is None:
        return []
    if isinstance(valor, str):
        return [valor] if valor else []
    if isinstance(valor, (list, tuple, set)):
        return [str(item) for item in valor if str(item)]
    return []


# ---------------------------------------------------------------------------
# Calificadores por tipo
# ---------------------------------------------------------------------------

def _calificar_opcion_unica(
    question: Mapping[str, Any], respuesta: Any
) -> dict[str, Any]:
    elegida = str(_como_dict(respuesta).get("opcion_id", ""))
    esperada = str(question.get("correct_option_id", ""))
    acierto = bool(elegida) and elegida == esperada
    return _resultado(
        1.0 if acierto else 0.0,
        _maximo(question),
        {"elegida": elegida, "esperada": esperada},
    )


def _calificar_seleccion_multiple(
    question: Mapping[str, Any], respuesta: Any
) -> dict[str, Any]:
    """Puntaje = (aciertos − errores) / total de correctas, con piso en 0."""
    correctas = set(_lista_de_ids(question.get("correct_option_ids")))
    validas = {str(option.get("id")) for option in question.get("options", [])}
    elegidas = set(_lista_de_ids(_como_dict(respuesta).get("opciones_ids"))) & validas

    if not correctas:
        return _resultado(0.0, _maximo(question), {"error": "sin respuestas correctas"})

    aciertos = len(elegidas & correctas)
    errores = len(elegidas - correctas)
    fraccion = (aciertos - errores) / len(correctas)
    return _resultado(
        fraccion,
        _maximo(question),
        {
            "elegidas": sorted(elegidas),
            "esperadas": sorted(correctas),
            "aciertos": aciertos,
            "errores": errores,
        },
    )


def _calificar_texto(question: Mapping[str, Any], respuesta: Any) -> dict[str, Any]:
    escrito = _como_dict(respuesta).get("texto", "")
    normalizado = normalizar_texto(escrito)
    aceptadas = {
        normalizar_texto(item) for item in question.get("respuestas_aceptadas", [])
    }
    aceptadas.discard("")
    acierto = bool(normalizado) and normalizado in aceptadas
    return _resultado(
        1.0 if acierto else 0.0,
        _maximo(question),
        {"escrito": str(escrito), "normalizado": normalizado},
    )


def _calificar_asignacion(
    question: Mapping[str, Any], respuesta: Any
) -> dict[str, Any]:
    """Ordenar, clasificar y relacionar: fracción de elementos bien asignados."""
    elementos = question.get("elementos", [])
    if not elementos:
        return _resultado(0.0, _maximo(question), {"error": "sin elementos"})

    asignaciones = _como_dict(_como_dict(respuesta).get("asignaciones"))
    aciertos = 0
    por_elemento: dict[str, dict[str, str]] = {}
    for elemento in elementos:
        elemento_id = str(elemento.get("id"))
        elegido = str(asignaciones.get(elemento_id, ""))
        esperado = str(elemento.get("correcto", ""))
        if elegido and elegido == esperado:
            aciertos += 1
        por_elemento[elemento_id] = {"elegido": elegido, "esperado": esperado}

    return _resultado(
        aciertos / len(elementos),
        _maximo(question),
        {"aciertos": aciertos, "total": len(elementos), "por_elemento": por_elemento},
    )


def _etapa_aplica(
    etapa: Mapping[str, Any], respuestas_etapas: Mapping[str, Any]
) -> bool:
    """Una etapa condicionada solo cuenta si su etapa padre tiene el valor pedido.

    En A3 («detectar y corregir»), la corrección solo se muestra a quien marcó
    «No». Si marcó «Sí», la etapa 2 ni se presenta ni puntúa.
    """
    dependencia = etapa.get("depende_de")
    if not isinstance(dependencia, Mapping):
        return True
    padre = _como_dict(respuestas_etapas.get(str(dependencia.get("etapa_id"))))
    return str(padre.get("opcion_id", "")) == str(dependencia.get("opcion_id"))


def _calificar_etapas(question: Mapping[str, Any], respuesta: Any) -> dict[str, Any]:
    etapas = question.get("etapas", [])
    respuestas_etapas = _como_dict(_como_dict(respuesta).get("etapas"))

    acumulado = 0.0
    peso_total = 0.0
    todas_correctas = True
    detalle_etapas: dict[str, Any] = {}

    for etapa in etapas:
        etapa_id = str(etapa.get("id"))
        respuesta_etapa = respuestas_etapas.get(etapa_id)

        if not etapa.get("puntua", True):
            # La justificación escrita se conserva como dato cualitativo,
            # nunca suma al puntaje (criterio de F2).
            detalle_etapas[etapa_id] = {
                "puntua": False,
                "texto": str(_como_dict(respuesta_etapa).get("texto", "")),
            }
            continue

        peso = float(etapa.get("peso", 0.0))
        peso_total += peso

        if not _etapa_aplica(etapa, respuestas_etapas):
            detalle_etapas[etapa_id] = {"puntua": True, "aplica": False, "puntaje": 0.0}
            todas_correctas = False
            continue

        calificador = _SCORERS.get(str(etapa.get("tipo")))
        if calificador is None:
            raise ScoringError(
                f"La etapa {etapa_id!r} declara un tipo no soportado: {etapa.get('tipo')!r}"
            )
        # La etapa se califica sobre 1.0 y el peso la escala dentro del reactivo.
        parcial = calificador({**etapa, "puntaje_maximo": 1.0}, respuesta_etapa)
        acumulado += peso * parcial["puntaje"]
        if not parcial["correcto"]:
            todas_correctas = False
        detalle_etapas[etapa_id] = {
            "puntua": True,
            "aplica": True,
            "peso": peso,
            **parcial,
        }

    if peso_total <= 0:
        return _resultado(0.0, _maximo(question), {"etapas": detalle_etapas})

    # A2 exige ambas etapas: acertar la 2 sin la 1 no otorga crédito parcial.
    if question.get("exigir_todas") and not todas_correctas:
        acumulado = 0.0

    return _resultado(
        acumulado / peso_total,
        _maximo(question),
        {"etapas": detalle_etapas, "exigir_todas": bool(question.get("exigir_todas"))},
    )


def _calificar_texto_libre(
    question: Mapping[str, Any], respuesta: Any
) -> dict[str, Any]:
    """Nunca puntúa; existe para que ``etapas`` pueda hospedarlo uniformemente."""
    return _resultado(
        0.0, 0.0, {"texto": str(_como_dict(respuesta).get("texto", ""))}
    )


_SCORERS: dict[str, Callable[[Mapping[str, Any], Any], dict[str, Any]]] = {
    "opcion_unica": _calificar_opcion_unica,
    "seleccion_multiple": _calificar_seleccion_multiple,
    "texto": _calificar_texto,
    "asignacion": _calificar_asignacion,
    "etapas": _calificar_etapas,
    "texto_libre": _calificar_texto_libre,
}

TIPOS_SOPORTADOS = frozenset(_SCORERS)


# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------

def calificar(question: Mapping[str, Any], respuesta: Any) -> dict[str, Any]:
    """Califica un reactivo. Nunca lanza por una respuesta mal formada: una
    respuesta vacía o con basura simplemente vale 0."""
    tipo = str(question.get("tipo", ""))
    calificador = _SCORERS.get(tipo)
    if calificador is None:
        raise ScoringError(f"Tipo de reactivo no soportado: {tipo!r}")
    return calificador(question, respuesta)


def es_respuesta_completa(question: Mapping[str, Any], respuesta: Any) -> bool:
    """¿Puede el estudiante avanzar al siguiente reactivo?

    La justificación escrita de F2 (``puntua: false``) es **opcional**: obligar a
    escribir bloquearía el avance y el criterio la trata como dato cualitativo.
    """
    tipo = str(question.get("tipo", ""))
    datos = _como_dict(respuesta)

    if tipo == "opcion_unica":
        return bool(str(datos.get("opcion_id", "")))
    if tipo == "seleccion_multiple":
        return len(_lista_de_ids(datos.get("opciones_ids"))) > 0
    if tipo in ("texto", "texto_libre"):
        return bool(str(datos.get("texto", "")).strip())
    if tipo == "asignacion":
        asignaciones = _como_dict(datos.get("asignaciones"))
        return all(
            str(asignaciones.get(str(elemento.get("id")), ""))
            for elemento in question.get("elementos", [])
        )
    if tipo == "etapas":
        respuestas_etapas = _como_dict(datos.get("etapas"))
        for etapa in question.get("etapas", []):
            if not etapa.get("puntua", True):
                continue
            if not _etapa_aplica(etapa, respuestas_etapas):
                continue
            if not es_respuesta_completa(etapa, respuestas_etapas.get(str(etapa.get("id")))):
                return False
        return True
    return False
