"""Lo que el equipo del alumno recuerda de su clase.

Se guarda en ``aula/mi_clase.json``. El alumno trabaja siempre en local: este
archivo sólo agrega a qué clase pertenece, con qué identidad y qué parte de su
avance ya confirmó el docente. Lo pendiente se calcula comparando esa lista con
los resultados locales, así que no hace falta una cola aparte que se
desincronice.
"""

from __future__ import annotations

from copy import deepcopy
from pathlib import Path
from typing import Any
import uuid

from ._json import escribir_json, leer_json


class EstadoAlumnoAula:
    def __init__(self, ruta: Path | None) -> None:
        self.ruta = Path(ruta) if ruta is not None else None
        datos = leer_json(self.ruta, {}) if self.ruta is not None else {}
        self._datos: dict[str, Any] = datos if isinstance(datos, dict) else {}
        self._datos.setdefault("clase", {})
        self._datos.setdefault("confirmados", [])

    def _guardar(self) -> None:
        if self.ruta is not None:
            escribir_json(self.ruta, self._datos)

    @property
    def device_id(self) -> str:
        # Identifica al equipo, no a la persona. Sobrevive a salir de una
        # clase para que el docente reconozca reimportaciones. Se crea al
        # primer uso: abrir la app sin tocar el aula no escribe nada.
        if not self._datos.get("device_id"):
            self._datos["device_id"] = uuid.uuid4().hex
            self._guardar()
        return str(self._datos["device_id"])

    @property
    def clase(self) -> dict[str, Any]:
        return deepcopy(self._datos.get("clase", {}))

    @property
    def unido(self) -> bool:
        clase = self._datos.get("clase", {})
        return bool(clase.get("alumno_id") and clase.get("token"))

    def registrar_union(self, mensaje: dict[str, Any], direccion: str = "") -> None:
        anterior = self._datos.get("clase", {})
        clase = dict(mensaje.get("clase", {}))
        if anterior.get("class_id") != clase.get("class_id"):
            self._datos["confirmados"] = []
        self._datos["clase"] = {
            **clase,
            "alumno_id": mensaje.get("alumno_id", ""),
            "token": mensaje.get("token", ""),
            "apodo": mensaje.get("apodo", ""),
            "matricula": mensaje.get("matricula", ""),
            "ultima_direccion": direccion or anterior.get("ultima_direccion", ""),
        }
        self._guardar()

    def actualizar_clase(self, **campos: Any) -> None:
        if not self._datos.get("clase"):
            return
        self._datos["clase"].update(deepcopy(campos))
        self._guardar()

    def salir(self) -> None:
        self._datos["clase"] = {}
        self._datos["confirmados"] = []
        self._guardar()

    def confirmar(self, result_ids: list[str]) -> None:
        confirmados = self._datos.setdefault("confirmados", [])
        nuevos = [i for i in result_ids if i and i not in confirmados]
        if nuevos:
            confirmados.extend(nuevos)
            self._guardar()

    def pendientes(self, resultados: list[dict[str, Any]]) -> list[dict[str, Any]]:
        confirmados = set(self._datos.get("confirmados", []))
        return [r for r in resultados if r.get("result_id") and r["result_id"] not in confirmados]
