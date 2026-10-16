"""Catálogo declarativo de módulos educativos.

Esta capa no conoce Qt. Valida una sola definición JSON que luego consumen
los ViewModels y las pantallas genéricas del curso.
"""

from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
from typing import Any

from core.rutas import recurso


DEFAULT_MODULE_CATALOG_PATH = recurso("data", "aprendizaje", "modules.json")
ALIGNMENT_FILE_NAME = "alineacion.json"


class LearningModuleError(ValueError):
    """El catálogo modular no cumple su contrato."""


class LearningModuleCatalog:
    """Carga y valida los ocho módulos sin acoplarlos a una pantalla.

    La alineación pedagógica (``alineacion.json``) vive junto al catálogo y se
    fusiona aquí, de modo que recorrido, laboratorio y evaluación lean la misma
    fuente: ejemplo ancla, comprobación de cada paso, forma post de cada reto,
    reactivos de transferencia y retos propios del laboratorio.
    """

    REQUIRED_MODULES = 8
    REQUIRED_CONCEPTS = 8
    REQUIRED_STEPS = 8
    REQUIRED_CHALLENGES = 8
    REQUIRED_TRANSFER_KINDS = ("verdadero_falso", "respuesta_corta")

    def __init__(
        self,
        path: str | Path | None = None,
        alignment_path: str | Path | None = None,
    ) -> None:
        self.path = Path(path) if path is not None else DEFAULT_MODULE_CATALOG_PATH
        self.alignment_path = (
            Path(alignment_path)
            if alignment_path is not None
            else self.path.with_name(ALIGNMENT_FILE_NAME)
        )
        self._data = self._load()
        self._validate()
        self._modules = sorted(self._data["modules"], key=lambda item: item["order"])
        self._by_id = {item["id"]: item for item in self._modules}
        # Un catálogo de prueba sin archivo hermano conserva el contrato
        # anterior; si el archivo existe, debe estar completo.
        self.has_alignment = self.alignment_path.is_file()
        if self.has_alignment:
            self._merge_alignment(self._load_alignment())

    def _load(self) -> dict[str, Any]:
        try:
            with self.path.open("r", encoding="utf-8") as source:
                data = json.load(source)
        except (OSError, json.JSONDecodeError) as exc:
            raise LearningModuleError(f"No se pudo cargar el catálogo modular: {exc}") from exc
        if not isinstance(data, dict):
            raise LearningModuleError("La raíz del catálogo modular debe ser un objeto.")
        return data

    def _load_alignment(self) -> dict[str, Any]:
        try:
            with self.alignment_path.open("r", encoding="utf-8") as source:
                data = json.load(source)
        except (OSError, json.JSONDecodeError) as exc:
            raise LearningModuleError(
                f"No se pudo cargar la alineación pedagógica: {exc}"
            ) from exc
        if not isinstance(data, dict) or data.get("schema_version") != 1:
            raise LearningModuleError("La alineación pedagógica debe usar schema_version=1.")
        if not isinstance(data.get("modules"), dict):
            raise LearningModuleError("La alineación debe declarar un objeto «modules».")
        return data

    @staticmethod
    def _validate_choice(owner: str, item: Any, *, minimum: int = 3) -> None:
        if not isinstance(item, dict) or not str(item.get("prompt", "")).strip():
            raise LearningModuleError(f"{owner} necesita un enunciado.")
        options = item.get("options")
        correct_index = item.get("correct_index")
        if (
            not isinstance(options, list)
            or len(options) < minimum
            or len({str(option) for option in options}) != len(options)
        ):
            raise LearningModuleError(
                f"{owner} necesita al menos {minimum} opciones distintas."
            )
        if not isinstance(correct_index, int) or not 0 <= correct_index < len(options):
            raise LearningModuleError(f"{owner} tiene una respuesta inválida.")

    def _merge_alignment(self, alignment: dict[str, Any]) -> None:
        by_module = alignment["modules"]
        for module in self._modules:
            module_id = module["id"]
            fragment = by_module.get(module_id)
            if not isinstance(fragment, dict):
                raise LearningModuleError(f"La alineación no cubre {module_id}.")
            concept_ids = {item["id"] for item in module["concepts"]}

            anchor = fragment.get("anchor")
            if (
                not isinstance(anchor, dict)
                or not str(anchor.get("question", "")).strip()
                or not str(anchor.get("example", "")).strip()
            ):
                raise LearningModuleError(f"{module_id} necesita un ejemplo ancla.")
            self._validate_choice(f"{module_id}/cierre", anchor.get("closing"))

            checks = fragment.get("step_checks")
            if not isinstance(checks, dict):
                raise LearningModuleError(f"{module_id} necesita comprobaciones por paso.")
            for step in module["guided_steps"]:
                check = checks.get(step["id"])
                self._validate_choice(f"{module_id}/{step['id']}", check)
                step["check"] = deepcopy(check)

            variants = fragment.get("post_variants")
            if not isinstance(variants, dict):
                raise LearningModuleError(f"{module_id} necesita formas post de sus retos.")
            for challenge in module["challenges"]:
                variant = variants.get(challenge["id"])
                self._validate_choice(f"{module_id}/{challenge['id']}/post", variant)
                challenge["post_variant"] = deepcopy(variant)

            transfer = fragment.get("transfer_items")
            if (
                not isinstance(transfer, list)
                or tuple(item.get("kind") for item in transfer)
                != self.REQUIRED_TRANSFER_KINDS
            ):
                raise LearningModuleError(
                    f"{module_id} necesita un reactivo de transferencia verdadero/falso "
                    "y otro de respuesta corta."
                )
            for item in transfer:
                if item.get("concept_id") not in concept_ids:
                    raise LearningModuleError(
                        f"{module_id}/{item.get('id')} referencia un concepto inexistente."
                    )
                for moment in ("pre", "post"):
                    form = item.get(moment)
                    key = "statement" if item["kind"] == "verdadero_falso" else "prompt"
                    answer_key = "correct" if item["kind"] == "verdadero_falso" else "answer"
                    if (
                        not isinstance(form, dict)
                        or not str(form.get(key, "")).strip()
                        or form.get(answer_key) in (None, "")
                    ):
                        raise LearningModuleError(
                            f"{module_id}/{item.get('id')} necesita su forma {moment}."
                        )
            module["transfer_items"] = deepcopy(transfer)

            # El laboratorio elige retos por índice según el paso que se observa;
            # cada reto propio debe tratar el mismo concepto que el reto de igual
            # índice para que ese mapa siga siendo válido.
            lab_challenges = fragment.get("lab_challenges")
            if (
                not isinstance(lab_challenges, list)
                or len(lab_challenges) != self.REQUIRED_CHALLENGES
            ):
                raise LearningModuleError(
                    f"{module_id} necesita {self.REQUIRED_CHALLENGES} retos de laboratorio."
                )
            for index, item in enumerate(lab_challenges):
                self._validate_choice(f"{module_id}/{item.get('id')}", item)
                if item.get("concept_id") != module["challenges"][index]["concept_id"]:
                    raise LearningModuleError(
                        f"{module_id}/{item.get('id')} no trata el concepto de su reto."
                    )
            module["lab_challenges"] = deepcopy(lab_challenges)
            module["anchor"] = deepcopy(anchor)

    def _validate(self) -> None:
        if self._data.get("schema_version") != 1:
            raise LearningModuleError("El catálogo modular debe usar schema_version=1.")
        modules = self._data.get("modules")
        if not isinstance(modules, list) or len(modules) != self.REQUIRED_MODULES:
            raise LearningModuleError(
                f"El curso debe declarar exactamente {self.REQUIRED_MODULES} módulos."
            )

        ids: set[str] = set()
        orders: set[int] = set()
        for module in modules:
            if not isinstance(module, dict):
                raise LearningModuleError("Cada módulo debe ser un objeto.")
            module_id = str(module.get("id", "")).strip()
            title = str(module.get("title", "")).strip()
            order = module.get("order")
            if not module_id or not title or module_id in ids:
                raise LearningModuleError("Los módulos necesitan id y título únicos.")
            if not isinstance(order, int) or order in orders:
                raise LearningModuleError("Cada módulo necesita un orden entero único.")
            ids.add(module_id)
            orders.add(order)

            concepts = module.get("concepts")
            steps = module.get("guided_steps")
            theory_sequence = module.get("theory_sequence")
            challenges = module.get("challenges")
            laboratory = module.get("laboratory")
            if not isinstance(concepts, list) or len(concepts) != self.REQUIRED_CONCEPTS:
                raise LearningModuleError(
                    f"{module_id} debe declarar {self.REQUIRED_CONCEPTS} conceptos."
                )
            if not isinstance(steps, list) or len(steps) != self.REQUIRED_STEPS:
                raise LearningModuleError(
                    f"{module_id} debe declarar {self.REQUIRED_STEPS} pasos guiados."
                )
            if (
                not isinstance(theory_sequence, list)
                or len(theory_sequence) != self.REQUIRED_STEPS
                or any(
                    not isinstance(concept_id, str) or not concept_id.strip()
                    for concept_id in theory_sequence
                )
            ):
                raise LearningModuleError(
                    f"{module_id} debe vincular cada paso con un concepto teórico."
                )
            if not isinstance(challenges, list) or len(challenges) != self.REQUIRED_CHALLENGES:
                raise LearningModuleError(
                    f"{module_id} debe declarar {self.REQUIRED_CHALLENGES} retos."
                )
            if not isinstance(laboratory, dict):
                raise LearningModuleError(
                    f"{module_id} debe declarar un laboratorio especializado."
                )
            modes = laboratory.get("modes")
            if (
                not isinstance(modes, list)
                or len(modes) != 2
                or set(modes) != {"training", "inference"}
            ):
                raise LearningModuleError(
                    f"{module_id} debe ofrecer entrenamiento e inferencia."
                )
            data_keys = laboratory.get("data_keys")
            if (
                not isinstance(data_keys, list)
                or not data_keys
                or any(not isinstance(key, str) or not key.strip() for key in data_keys)
            ):
                raise LearningModuleError(
                    f"{module_id} debe declarar tensores inspeccionables."
                )

            concept_ids = {str(item.get("id", "")) for item in concepts}
            if "" in concept_ids or len(concept_ids) != len(concepts):
                raise LearningModuleError(f"{module_id} contiene conceptos sin id o repetidos.")
            for collection, name in ((steps, "paso"), (challenges, "reto")):
                for item in collection:
                    if not str(item.get("id", "")).strip():
                        raise LearningModuleError(f"{module_id} contiene un {name} sin id.")
                    concept_id = str(item.get("concept_id", ""))
                    if concept_id not in concept_ids:
                        raise LearningModuleError(
                            f"{module_id}/{item.get('id')} referencia un concepto inexistente."
                        )
            for challenge in challenges:
                options = challenge.get("options")
                correct_index = challenge.get("correct_index")
                if not isinstance(options, list) or len(options) < 3:
                    raise LearningModuleError(
                        f"{module_id}/{challenge['id']} necesita al menos tres opciones."
                    )
                if not isinstance(correct_index, int) or not 0 <= correct_index < len(options):
                    raise LearningModuleError(
                        f"{module_id}/{challenge['id']} tiene una respuesta inválida."
                    )

        if orders != set(range(1, self.REQUIRED_MODULES + 1)):
            raise LearningModuleError("El orden de módulos debe ser continuo de 1 a 8.")

    @property
    def modules(self) -> list[dict[str, Any]]:
        return deepcopy(self._modules)

    @property
    def module_ids(self) -> tuple[str, ...]:
        return tuple(item["id"] for item in self._modules)

    def get(self, module_id: str) -> dict[str, Any]:
        try:
            return deepcopy(self._by_id[str(module_id)])
        except KeyError as exc:
            raise LearningModuleError(f"Módulo desconocido: {module_id!r}.") from exc

    def step_for_concept(self, module_id: str, concept_id: str) -> dict[str, Any]:
        """Primer paso guiado que enseña ``concept_id``; vacío si ninguno lo hace.

        Algunos conceptos (p. ej. las dimensiones de entrada) se evalúan sin un
        paso propio; quien muestre el enlace debe tolerar el resultado vacío.
        """
        module = self.get(module_id)
        for index, step in enumerate(module["guided_steps"]):
            if step.get("concept_id") == concept_id:
                return {"index": index, "id": step["id"], "title": step["title"]}
        return {}

    def next_id(self, module_id: str) -> str:
        module = self.get(module_id)
        index = int(module["order"])
        return self._modules[index]["id"] if index < len(self._modules) else ""
