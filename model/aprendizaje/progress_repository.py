"""Persistencia atómica del avance por módulo."""

from __future__ import annotations

from copy import deepcopy
import json
import os
from pathlib import Path
from typing import Any


class ModuleProgressRepository:
    """Guarda estado educativo sin depender de QSettings ni de Qt."""

    SCHEMA_VERSION = 1

    def __init__(self, path: str | Path | None = None) -> None:
        self.path = Path(path) if path is not None else None
        self._data = self._empty()
        self._load()

    @classmethod
    def _empty(cls) -> dict[str, Any]:
        return {
            "schema_version": cls.SCHEMA_VERSION,
            "current_module_id": "module_1",
            "modules": {},
            "model_configuration": {},
        }

    def _load(self) -> None:
        if self.path is None or not self.path.is_file():
            return
        try:
            with self.path.open("r", encoding="utf-8") as source:
                data = json.load(source)
        except (OSError, ValueError, TypeError):
            return
        if isinstance(data, dict) and data.get("schema_version") == self.SCHEMA_VERSION:
            self._data = data
            self._data.setdefault("modules", {})
            self._data.setdefault("model_configuration", {})

    def snapshot(self) -> dict[str, Any]:
        return deepcopy(self._data)

    def replace(self, data: dict[str, Any]) -> None:
        updated = deepcopy(data)
        updated["schema_version"] = self.SCHEMA_VERSION
        updated.setdefault("modules", {})
        updated.setdefault("model_configuration", {})
        self._data = updated
        self._persist()

    def clear(self) -> None:
        self._data = self._empty()
        self._persist()

    def _persist(self) -> None:
        if self.path is None:
            return
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.path.with_suffix(self.path.suffix + ".tmp")
        try:
            with temporary.open("w", encoding="utf-8") as target:
                json.dump(self._data, target, ensure_ascii=False, indent=2)
                target.flush()
                os.fsync(target.fileno())
            os.replace(temporary, self.path)
        finally:
            if temporary.exists():
                try:
                    temporary.unlink()
                except OSError:
                    pass
