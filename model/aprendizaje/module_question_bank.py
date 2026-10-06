"""Banco pedagógico reutilizable para las evaluaciones de cada módulo.

Cada módulo produce dos formas paralelas de 25 reactivos. Los reactivos no se
limitan a reconocer la mejor opción: combinan siete interacciones calificables
con los componentes QML existentes y recorren memoria, comprensión, aplicación
y razonamiento.
"""

from __future__ import annotations

from copy import deepcopy
import random
from typing import Any, Iterable

from model.evaluacion.question_bank import QuestionBank, QuestionBankError

from .learning_module import LearningModuleCatalog


class ModuleQuestionBank:
    """Adapta el catálogo modular al contrato de :class:`EvaluationManager`.

    Hay 25 reactivos por módulo y momento: 8 básicos, 9 intermedios y
    8 avanzados. Cada intento selecciona cinco de cada nivel, prioriza preguntas
    no vistas y procura cubrir conceptos e interacciones diferentes.
    """

    VALID_ASSESSMENTS = ("pre", "post")
    QUESTIONS_PER_ATTEMPT = 15
    QUESTIONS_PER_LEVEL = 5
    INSTRUMENT_VERSION = 5

    PEDAGOGICAL_TYPES = (
        "opcion_multiple",
        "seleccion_multiple",
        "verdadero_falso",
        "ordenar_pasos",
        "relacionar_conceptos",
        "respuesta_corta",
        "completar_espacios",
    )

    def __init__(
        self,
        catalog: LearningModuleCatalog | None = None,
        module_id: str = "module_1",
        rng: random.Random | None = None,
    ) -> None:
        self.catalog = catalog or LearningModuleCatalog()
        self._rng = rng or random.SystemRandom()
        self._module_id = ""
        self._banks: dict[str, list[dict[str, Any]]] = {}
        self._selection: dict[str, list[dict[str, Any]]] = {}
        self.set_module(module_id)

    def set_module(self, module_id: str) -> None:
        module = self.catalog.get(module_id)
        if module_id == self._module_id:
            return
        self._module_id = module_id
        self._banks = {
            assessment: self._build_questions(module, assessment)
            for assessment in self.VALID_ASSESSMENTS
        }
        self._selection = {}

    @property
    def module_id(self) -> str:
        return self._module_id

    @property
    def instrument_version(self) -> int:
        return self.INSTRUMENT_VERSION

    @property
    def dimensions(self) -> list[dict[str, str]]:
        module = self.catalog.get(self._module_id)
        return [{"id": item["id"], "name": item["title"]} for item in module["concepts"]]

    @property
    def criterios(self) -> dict[str, str]:
        return {
            "opcion_multiple": "1 punto por identificar la alternativa correcta.",
            "seleccion_multiple": (
                "Crédito parcial por afirmaciones correctas; las selecciones "
                "incorrectas descuentan sin producir puntaje negativo."
            ),
            "verdadero_falso": "1 punto por evaluar correctamente la afirmación.",
            "ordenar_pasos": "Crédito parcial por cada etapa ubicada en su posición.",
            "relacionar_conceptos": "Crédito parcial por cada relación correcta.",
            "respuesta_corta": (
                "1 punto por la dimensión, valor o término correcto; se ignoran "
                "mayúsculas, acentos y signos de separación."
            ),
            "completar_espacios": "1 punto por completar correctamente la transformación.",
        }

    def all_questions(self, assessment_type: str) -> list[dict[str, Any]]:
        assessment = self._normalize(assessment_type)
        return deepcopy(self._banks[assessment])

    def start_attempt(
        self, assessment_type: str, used_question_ids: Iterable[str] = ()
    ) -> list[str]:
        assessment = self._normalize(assessment_type)
        used = {str(item) for item in used_question_ids}
        chosen: list[dict[str, Any]] = []
        covered_concepts: set[str] = set()
        covered_formats: set[str] = set()

        for difficulty in ("Básica", "Intermedia", "Avanzada"):
            level = [
                question
                for question in self._banks[assessment]
                if question["difficulty"] == difficulty
            ]
            unseen = [question for question in level if question["id"] not in used]
            repeated = [question for question in level if question["id"] in used]
            self._rng.shuffle(unseen)
            self._rng.shuffle(repeated)
            selected: list[dict[str, Any]] = []

            # En cada grupo se prioriza primero una combinación nueva de
            # concepto + interacción, después un concepto nuevo y por último
            # un formato aún ausente. Así las 15 preguntas no se convierten en
            # quince variantes de la misma acción.
            for pool in (unseen, repeated):
                while pool and len(selected) < self.QUESTIONS_PER_LEVEL:
                    preferred_index = self._preferred_index(
                        pool, covered_concepts, covered_formats
                    )
                    question = pool.pop(preferred_index)
                    selected.append(question)
                    covered_concepts.add(str(question["concept_id"]))
                    covered_formats.add(str(question["pedagogical_type"]))
                if len(selected) == self.QUESTIONS_PER_LEVEL:
                    break
            chosen.extend(selected)

        self._rng.shuffle(chosen)
        self._selection[assessment] = [self._shuffle_question(item) for item in chosen]
        return [item["id"] for item in self._selection[assessment]]

    @staticmethod
    def _preferred_index(
        pool: list[dict[str, Any]],
        covered_concepts: set[str],
        covered_formats: set[str],
    ) -> int:
        preferences = (
            lambda q: q["concept_id"] not in covered_concepts
            and q["pedagogical_type"] not in covered_formats,
            lambda q: q["concept_id"] not in covered_concepts,
            lambda q: q["pedagogical_type"] not in covered_formats,
        )
        for predicate in preferences:
            index = next((i for i, question in enumerate(pool) if predicate(question)), None)
            if index is not None:
                return index
        return 0

    def get_assessment(self, assessment_type: str) -> dict[str, Any]:
        assessment = self._normalize(assessment_type)
        if assessment not in self._selection:
            self.start_attempt(assessment)
        module = self.catalog.get(self._module_id)
        label = "Pre-test" if assessment == "pre" else "Post-test"
        return {
            "title": f"{label} · {module['title']}",
            "eyebrow": f"MÓDULO {module['order']} · EVALUACIÓN",
            "forma": "Diagnóstico" if assessment == "pre" else "Comprobación",
            "description": (
                "Explora qué recuerdas, comprendes y puedes razonar antes del módulo."
                if assessment == "pre"
                else "Comprueba lo aprendido con problemas equivalentes y variados."
            ),
            "instructions": (
                "Responderás 15 preguntas de un banco de 25: 5 básicas, "
                "5 intermedias y 5 avanzadas. Encontrarás opción múltiple, "
                "selección múltiple, verdadero/falso, ordenamientos, relaciones, "
                "respuestas cortas y espacios para completar."
            ),
            "questions": deepcopy(self._selection[assessment]),
        }

    def get_questions(self, assessment_type: str) -> list[dict[str, Any]]:
        return self.get_assessment(assessment_type)["questions"]

    @classmethod
    def public_question(cls, question: dict[str, Any]) -> dict[str, Any]:
        public = QuestionBank.public_question(question)
        public.pop("explanation", None)
        return public

    def dimension_name(self, dimension_id: str) -> str:
        return next(
            (item["name"] for item in self.dimensions if item["id"] == dimension_id),
            dimension_id,
        )

    def _normalize(self, assessment_type: str) -> str:
        normalized = str(assessment_type).strip().lower()
        if normalized not in self.VALID_ASSESSMENTS:
            raise QuestionBankError(f"Tipo de evaluación desconocido: {assessment_type!r}.")
        return normalized

    def _shuffle_question(self, question: dict[str, Any]) -> dict[str, Any]:
        shuffled = deepcopy(question)
        options = shuffled.get("options")
        if isinstance(options, list):
            self._rng.shuffle(options)

        elements = shuffled.get("elementos")
        if isinstance(elements, list):
            self._rng.shuffle(elements)

        # Las posiciones 1..N de un ordenamiento deben seguir visibles en
        # secuencia; en relacionar sí conviene variar ambas columnas.
        destinations = shuffled.get("destinos")
        if (
            isinstance(destinations, list)
            and shuffled.get("subtipo") != "ordenar"
        ):
            self._rng.shuffle(destinations)
        return shuffled

    # ------------------------------------------------------------------
    # Constructores de reactivos
    # ------------------------------------------------------------------

    @staticmethod
    def _base_question(
        prefix: str,
        code: str,
        concept_id: str,
        difficulty: str,
        bloom_level: str,
        cognitive_process: str,
        pedagogical_type: str,
        formato: str,
        presentacion: str,
        tipo: str,
        prompt: str,
        related_concepts: Iterable[str] = (),
        explanation: str = "",
    ) -> dict[str, Any]:
        concepts = [concept_id, *[str(item) for item in related_concepts]]
        concepts = list(dict.fromkeys(item for item in concepts if item))
        return {
            "id": f"{prefix}_{code.lower()}",
            "code": code,
            "dimension_id": concept_id,
            "concept_id": concept_id,
            "concept_ids": concepts,
            "category": concept_id,
            "difficulty": difficulty,
            "bloom_level": bloom_level,
            "cognitive_process": cognitive_process,
            "pedagogical_type": pedagogical_type,
            "formato": formato,
            "presentacion": presentacion,
            "tipo": tipo,
            "puntaje_maximo": 1.0,
            "criterio_id": pedagogical_type,
            "prompt": prompt,
            "explanation": explanation,
        }

    @classmethod
    def _single_choice(
        cls,
        prefix: str,
        code: str,
        concept_id: str,
        difficulty: str,
        bloom_level: str,
        cognitive_process: str,
        prompt: str,
        options: list[str],
        correct_index: int,
        *,
        pedagogical_type: str = "opcion_multiple",
        formato: str = "Opción múltiple",
        related_concepts: Iterable[str] = (),
        explanation: str = "",
        resource: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        question = cls._base_question(
            prefix,
            code,
            concept_id,
            difficulty,
            bloom_level,
            cognitive_process,
            pedagogical_type,
            formato,
            "tarjetas",
            "opcion_unica",
            prompt,
            related_concepts,
            explanation,
        )
        option_ids = list("abcdef")[: len(options)]
        question["options"] = [
            {"id": option_id, "text": text}
            for option_id, text in zip(option_ids, options)
        ]
        question["correct_option_id"] = option_ids[correct_index]
        if resource:
            question["recurso"] = deepcopy(resource)
        return question

    @classmethod
    def _true_false(
        cls,
        prefix: str,
        code: str,
        concept_id: str,
        difficulty: str,
        bloom_level: str,
        cognitive_process: str,
        statement: str,
        correct: bool,
        *,
        explanation: str = "",
    ) -> dict[str, Any]:
        return cls._single_choice(
            prefix,
            code,
            concept_id,
            difficulty,
            bloom_level,
            cognitive_process,
            f"Decide si la afirmación es verdadera o falsa:\n\n«{statement}»",
            ["Verdadero", "Falso"],
            0 if correct else 1,
            pedagogical_type="verdadero_falso",
            formato="Verdadero / Falso",
            explanation=explanation,
        )

    @classmethod
    def _multiple_selection(
        cls,
        prefix: str,
        code: str,
        concept_id: str,
        difficulty: str,
        bloom_level: str,
        cognitive_process: str,
        prompt: str,
        options: list[str],
        correct_indices: Iterable[int],
        *,
        related_concepts: Iterable[str] = (),
        explanation: str = "",
    ) -> dict[str, Any]:
        question = cls._base_question(
            prefix,
            code,
            concept_id,
            difficulty,
            bloom_level,
            cognitive_process,
            "seleccion_multiple",
            "Selección múltiple",
            "chips_toggle",
            "seleccion_multiple",
            prompt,
            related_concepts,
            explanation,
        )
        option_ids = list("abcdef")[: len(options)]
        question["options"] = [
            {"id": option_id, "text": text}
            for option_id, text in zip(option_ids, options)
        ]
        question["correct_option_ids"] = [
            option_ids[index] for index in correct_indices
        ]
        return question

    @classmethod
    def _text_question(
        cls,
        prefix: str,
        code: str,
        concept_id: str,
        difficulty: str,
        bloom_level: str,
        cognitive_process: str,
        prompt: str,
        accepted: Iterable[str],
        *,
        pedagogical_type: str,
        formato: str,
        placeholder: str,
        explanation: str = "",
    ) -> dict[str, Any]:
        question = cls._base_question(
            prefix,
            code,
            concept_id,
            difficulty,
            bloom_level,
            cognitive_process,
            pedagogical_type,
            formato,
            "caja_en_linea",
            "texto",
            prompt,
            explanation=explanation,
        )
        question["respuestas_aceptadas"] = list(
            dict.fromkeys(str(item).strip() for item in accepted if str(item).strip())
        )
        question["placeholder"] = placeholder
        return question

    @classmethod
    def _assignment_question(
        cls,
        prefix: str,
        code: str,
        concept_id: str,
        difficulty: str,
        bloom_level: str,
        cognitive_process: str,
        prompt: str,
        elements: list[dict[str, str]],
        destinations: list[dict[str, str]],
        *,
        subtype: str,
        related_concepts: Iterable[str] = (),
        explanation: str = "",
    ) -> dict[str, Any]:
        ordering = subtype == "ordenar"
        pedagogical_type = "ordenar_pasos" if ordering else "relacionar_conceptos"
        question = cls._base_question(
            prefix,
            code,
            concept_id,
            difficulty,
            bloom_level,
            cognitive_process,
            pedagogical_type,
            "Ordenar pasos" if ordering else "Relacionar conceptos",
            "lista_arrastrable" if ordering else "lineas_o_tocar_para_emparejar",
            "asignacion",
            prompt,
            related_concepts,
            explanation,
        )
        question.update(
            {
                "subtipo": subtype,
                "etiqueta_destino": "Posición" if ordering else "Función",
                "destinos_unicos": True,
                "destinos": destinations,
                "elementos": elements,
            }
        )
        return question

    @staticmethod
    def _challenge_prompt(challenge: dict[str, Any], assessment: str) -> str:
        if assessment == "post":
            return str(challenge.get("post_prompt", challenge["prompt"]))
        return str(challenge["prompt"])

    @staticmethod
    def _correct_answer(challenge: dict[str, Any]) -> str:
        return str(challenge["options"][int(challenge["correct_index"])])

    @staticmethod
    def _wrong_answer(challenge: dict[str, Any]) -> str:
        correct_index = int(challenge["correct_index"])
        for index, option in enumerate(challenge["options"]):
            if index != correct_index:
                return str(option)
        return ""

    @staticmethod
    def _order_payload(steps: list[dict[str, Any]]) -> tuple[list[dict], list[dict]]:
        destinations = [
            {"id": str(index + 1), "texto": str(index + 1)}
            for index in range(len(steps))
        ]
        elements = [
            {
                "id": f"step_{index + 1}",
                "texto": str(step["title"]),
                "correcto": str(index + 1),
            }
            for index, step in enumerate(steps)
        ]
        return elements, destinations

    @staticmethod
    def _relation_payload(
        pairs: list[tuple[str, str]],
    ) -> tuple[list[dict], list[dict]]:
        elements = []
        destinations = []
        for index, (left, right) in enumerate(pairs):
            destination_id = f"d{index + 1}"
            elements.append(
                {"id": f"e{index + 1}", "texto": left, "correcto": destination_id}
            )
            destinations.append({"id": destination_id, "texto": right})
        return elements, destinations

    # ------------------------------------------------------------------
    # Generación pedagógica de los 25 reactivos
    # ------------------------------------------------------------------

    def _build_questions(
        self, module: dict[str, Any], assessment: str
    ) -> list[dict[str, Any]]:
        prefix = f"{module['id']}_{assessment}"
        concepts = module["concepts"]
        steps = module["guided_steps"]
        challenges = module["challenges"]
        questions: list[dict[str, Any]] = []

        def concept_choice(code: str, index: int) -> dict[str, Any]:
            concept = concepts[index]
            offset = 1 if assessment == "pre" else 2
            distractors = [
                concepts[(index + offset + jump) % len(concepts)]["description"]
                for jump in (0, 2, 4)
            ]
            prompt = (
                f"¿Qué descripción corresponde a «{concept['title']}»?"
                if assessment == "pre"
                else f"¿Qué afirmación explica correctamente el papel de "
                f"«{concept['title']}» dentro del módulo?"
            )
            return self._single_choice(
                prefix,
                code,
                concept["id"],
                "Básica",
                "Recordar",
                "Memoria conceptual",
                prompt,
                [concept["description"], *distractors],
                0,
                explanation=concept["description"],
            )

        # ── 8 básicas: recordar sin reducir todo a reconocimiento ─────
        questions.extend([concept_choice("B1", 0), concept_choice("B2", 4)])

        concept = concepts[1]
        if assessment == "pre":
            statement = f"{concept['title']}: {concept['description']}"
            correct = True
        else:
            statement = f"{concept['title']}: {concepts[2]['description']}"
            correct = False
        questions.append(
            self._true_false(
                prefix,
                "B3",
                concept["id"],
                "Básica",
                "Recordar",
                "Memoria conceptual",
                statement,
                correct,
                explanation=concept["description"],
            )
        )

        concept = concepts[3]
        if assessment == "pre":
            statement = f"{concept['title']}: {concepts[6]['description']}"
            correct = False
        else:
            statement = f"{concept['title']}: {concept['description']}"
            correct = True
        questions.append(
            self._true_false(
                prefix,
                "B4",
                concept["id"],
                "Básica",
                "Recordar",
                "Discriminación conceptual",
                statement,
                correct,
                explanation=concept["description"],
            )
        )

        selected_indices = (2, 5) if assessment == "pre" else (3, 6)
        first, second = (concepts[index] for index in selected_indices)
        questions.append(
            self._multiple_selection(
                prefix,
                "B5",
                first["id"],
                "Básica",
                "Comprender",
                "Discriminación conceptual",
                "Selecciona las DOS asociaciones coherentes entre concepto y función.",
                [
                    f"{first['title']}: {first['description']}",
                    f"{second['title']}: {second['description']}",
                    f"{first['title']}: {second['description']}",
                    f"{second['title']}: {first['description']}",
                ],
                (0, 1),
                related_concepts=[second["id"]],
            )
        )

        blank_index = 4 if assessment == "pre" else 5
        blank_step = steps[blank_index]
        previous_step = steps[blank_index - 1]
        next_step = steps[(blank_index + 1) % len(steps)]
        questions.append(
            self._text_question(
                prefix,
                "B6",
                blank_step["concept_id"],
                "Básica",
                "Recordar",
                "Evocación guiada",
                f"Completa el flujo: {previous_step['title']} → ________ → "
                f"{next_step['title']}.",
                [blank_step["title"]],
                pedagogical_type="completar_espacios",
                formato="Completar espacios",
                placeholder="Escribe el nombre de la etapa",
                explanation=f"La etapa intermedia es {blank_step['title']}.",
            )
        )

        relation_indices = [0, 2, 4, 6] if assessment == "pre" else [1, 3, 5, 7]
        relation_concepts = [concepts[index] for index in relation_indices]
        elements, destinations = self._relation_payload(
            [(item["title"], item["description"]) for item in relation_concepts]
        )
        questions.append(
            self._assignment_question(
                prefix,
                "B7",
                relation_concepts[0]["id"],
                "Básica",
                "Comprender",
                "Asociación conceptual",
                "Relaciona cada concepto con la función que cumple en este módulo.",
                elements,
                destinations,
                subtype="relacionar",
                related_concepts=[item["id"] for item in relation_concepts[1:]],
            )
        )

        dimension_step = steps[7 if assessment == "pre" else 0]
        questions.append(
            self._text_question(
                prefix,
                "B8",
                dimension_step["concept_id"],
                "Básica",
                "Aplicar",
                "Lectura de dimensiones",
                f"Escribe la dimensión o forma indicada para la salida de "
                f"«{dimension_step['title']}»: ________.",
                [dimension_step["dimensions"]],
                pedagogical_type="respuesta_corta",
                formato="Respuesta numérica/corta",
                placeholder="Ejemplo: [B,T,d_model]",
                explanation=f"La forma esperada es {dimension_step['dimensions']}.",
            )
        )

        # ── 9 intermedias: comprender relaciones y secuencias ─────────
        order_windows = (
            ([0, 1, 2, 3], [4, 5, 6, 7])
            if assessment == "pre"
            else ([1, 2, 3, 4], [3, 4, 5, 6])
        )
        for number, indices in enumerate(order_windows, start=1):
            ordered_steps = [steps[index] for index in indices]
            elements, destinations = self._order_payload(ordered_steps)
            questions.append(
                self._assignment_question(
                    prefix,
                    f"I{number}",
                    ordered_steps[-1]["concept_id"],
                    "Intermedia",
                    "Comprender",
                    "Secuenciación causal",
                    "Ordena las etapas según el flujo real de información.",
                    elements,
                    destinations,
                    subtype="ordenar",
                    related_concepts=[step["concept_id"] for step in ordered_steps[:-1]],
                )
            )

        step_indices = [0, 2, 4, 6] if assessment == "pre" else [1, 3, 5, 7]
        selected_steps = [steps[index] for index in step_indices]
        elements, destinations = self._relation_payload(
            [(step["title"], step["output"]) for step in selected_steps]
        )
        questions.append(
            self._assignment_question(
                prefix,
                "I3",
                selected_steps[0]["concept_id"],
                "Intermedia",
                "Comprender",
                "Relación proceso–resultado",
                "Relaciona cada transformación con la información que produce.",
                elements,
                destinations,
                subtype="relacionar",
                related_concepts=[step["concept_id"] for step in selected_steps[1:]],
            )
        )

        selected_concepts = [
            concepts[index]
            for index in ([1, 3, 5, 7] if assessment == "pre" else [0, 2, 4, 6])
        ]
        elements, destinations = self._relation_payload(
            [(item["title"], item["description"]) for item in selected_concepts]
        )
        questions.append(
            self._assignment_question(
                prefix,
                "I4",
                selected_concepts[0]["id"],
                "Intermedia",
                "Comprender",
                "Relación entre componentes",
                "Relaciona los componentes sin usar su posición como pista.",
                elements,
                destinations,
                subtype="relacionar",
                related_concepts=[item["id"] for item in selected_concepts[1:]],
            )
        )

        pair_indices = (2, 5) if assessment == "pre" else (1, 6)
        first_step, second_step = (steps[index] for index in pair_indices)
        questions.append(
            self._multiple_selection(
                prefix,
                "I5",
                first_step["concept_id"],
                "Intermedia",
                "Comprender",
                "Explicación funcional",
                "Selecciona las DOS explicaciones que justifican correctamente su etapa.",
                [
                    f"{first_step['title']}: {first_step['why']}",
                    f"{second_step['title']}: {second_step['why']}",
                    f"{first_step['title']}: {second_step['why']}",
                    f"{second_step['title']}: {first_step['why']}",
                ],
                (0, 1),
                related_concepts=[second_step["concept_id"]],
            )
        )

        sequence_start = 1
        claimed_next = 2 if assessment == "pre" else 4
        statement = (
            f"En el flujo del módulo, después de «{steps[sequence_start]['title']}» "
            f"ocurre «{steps[claimed_next]['title']}»."
        )
        questions.append(
            self._true_false(
                prefix,
                "I6",
                steps[sequence_start]["concept_id"],
                "Intermedia",
                "Comprender",
                "Comprensión del flujo",
                statement,
                assessment == "pre",
                explanation=(
                    f"La etapa siguiente es {steps[sequence_start + 1]['title']}."
                ),
            )
        )

        output_step = steps[6 if assessment == "pre" else 5]
        questions.append(
            self._text_question(
                prefix,
                "I7",
                output_step["concept_id"],
                "Intermedia",
                "Comprender",
                "Reconstrucción del flujo",
                f"Completa: «{output_step['title']}» recibe "
                f"{output_step['input']} y produce ________.",
                [output_step["output"]],
                pedagogical_type="completar_espacios",
                formato="Completar espacios",
                placeholder="Escribe la salida de la etapa",
                explanation=f"Produce {output_step['output']}.",
            )
        )

        why_index = 5 if assessment == "pre" else 2
        why_step = steps[why_index]
        distractor_whys = [
            steps[index]["why"]
            for index in range(len(steps))
            if index != why_index
        ][:3]
        questions.append(
            self._single_choice(
                prefix,
                "I8",
                why_step["concept_id"],
                "Intermedia",
                "Comprender",
                "Explicación funcional",
                f"¿Por qué se realiza «{why_step['title']}»?",
                [why_step["why"], *distractor_whys],
                0,
                explanation=why_step["why"],
            )
        )

        edge_indices = (0, 7) if assessment == "pre" else (1, 6)
        first_edge, second_edge = (steps[index] for index in edge_indices)
        questions.append(
            self._multiple_selection(
                prefix,
                "I9",
                first_edge["concept_id"],
                "Intermedia",
                "Comprender",
                "Seguimiento entrada–salida",
                "Selecciona los DOS pares entrada → salida que respetan el flujo.",
                [
                    f"{first_edge['input']} → {first_edge['output']}",
                    f"{second_edge['input']} → {second_edge['output']}",
                    f"{first_edge['input']} → {second_edge['output']}",
                    f"{second_edge['input']} → {first_edge['output']}",
                ],
                (0, 1),
                related_concepts=[second_edge["concept_id"]],
            )
        )

        # ── 8 avanzadas: cálculo, interpretación y razonamiento ───────
        challenge = challenges[0]
        questions.append(
            self._text_question(
                prefix,
                "A1",
                challenge["concept_id"],
                "Avanzada",
                "Aplicar",
                "Cálculo o interpretación",
                "Resuelve sin opciones: " + self._challenge_prompt(challenge, assessment),
                [self._correct_answer(challenge)],
                pedagogical_type="respuesta_corta",
                formato="Respuesta numérica/corta",
                placeholder="Escribe el valor o la dimensión",
                explanation=str(challenge.get("explanation", "")),
            )
        )

        challenge = challenges[1]
        questions.append(
            self._single_choice(
                prefix,
                "A2",
                challenge["concept_id"],
                "Avanzada",
                "Aplicar",
                "Aplicación",
                self._challenge_prompt(challenge, assessment),
                list(challenge["options"]),
                int(challenge["correct_index"]),
                explanation=str(challenge.get("explanation", "")),
                resource=challenge.get("resource"),
            )
        )

        first_challenge, second_challenge = challenges[2], challenges[3]
        questions.append(
            self._multiple_selection(
                prefix,
                "A3",
                first_challenge["concept_id"],
                "Avanzada",
                "Analizar",
                "Razonamiento",
                "Selecciona las DOS conclusiones correctas. Cada opción combina "
                "un caso con su resultado.",
                [
                    f"{self._challenge_prompt(first_challenge, assessment)} "
                    f"→ {self._correct_answer(first_challenge)}",
                    f"{self._challenge_prompt(second_challenge, assessment)} "
                    f"→ {self._correct_answer(second_challenge)}",
                    f"{self._challenge_prompt(first_challenge, assessment)} "
                    f"→ {self._wrong_answer(first_challenge)}",
                    f"{self._challenge_prompt(second_challenge, assessment)} "
                    f"→ {self._wrong_answer(second_challenge)}",
                ],
                (0, 1),
                related_concepts=[second_challenge["concept_id"]],
            )
        )

        advanced_indices = [1, 2, 3, 4] if assessment == "pre" else [2, 3, 4, 5]
        advanced_steps = [steps[index] for index in advanced_indices]
        elements, destinations = self._order_payload(advanced_steps)
        questions.append(
            self._assignment_question(
                prefix,
                "A4",
                advanced_steps[-1]["concept_id"],
                "Avanzada",
                "Analizar",
                "Razonamiento secuencial",
                "Reconstruye el orden necesario para que la transformación sea válida.",
                elements,
                destinations,
                subtype="ordenar",
                related_concepts=[step["concept_id"] for step in advanced_steps[:-1]],
            )
        )

        related_challenges = challenges[4:8]
        elements, destinations = self._relation_payload(
            [
                (
                    self._challenge_prompt(challenge, assessment),
                    self._correct_answer(challenge),
                )
                for challenge in related_challenges
            ]
        )
        questions.append(
            self._assignment_question(
                prefix,
                "A5",
                related_challenges[0]["concept_id"],
                "Avanzada",
                "Analizar",
                "Transferencia",
                "Relaciona cada situación con la conclusión que se deduce de ella.",
                elements,
                destinations,
                subtype="relacionar",
                related_concepts=[
                    challenge["concept_id"] for challenge in related_challenges[1:]
                ],
            )
        )

        challenge = challenges[4]
        conclusion = (
            self._correct_answer(challenge)
            if assessment == "pre"
            else self._wrong_answer(challenge)
        )
        questions.append(
            self._true_false(
                prefix,
                "A6",
                challenge["concept_id"],
                "Avanzada",
                "Analizar",
                "Razonamiento",
                f"Ante el caso «{self._challenge_prompt(challenge, assessment)}», "
                f"la conclusión «{conclusion}» es correcta.",
                assessment == "pre",
                explanation=f"La conclusión correcta es {self._correct_answer(challenge)}.",
            )
        )

        shortest_index = min(
            range(1, len(challenges)),
            key=lambda index: len(self._correct_answer(challenges[index])),
        )
        challenge = challenges[shortest_index]
        questions.append(
            self._text_question(
                prefix,
                "A7",
                challenge["concept_id"],
                "Avanzada",
                "Aplicar",
                "Cálculo sin pistas",
                "Responde sin opciones: " + self._challenge_prompt(challenge, assessment),
                [self._correct_answer(challenge)],
                pedagogical_type="respuesta_corta",
                formato="Respuesta numérica/corta",
                placeholder="Escribe una respuesta breve",
                explanation=str(challenge.get("explanation", "")),
            )
        )

        challenge = challenges[7]
        questions.append(
            self._single_choice(
                prefix,
                "A8",
                challenge["concept_id"],
                "Avanzada",
                "Analizar",
                "Razonamiento",
                self._challenge_prompt(challenge, assessment),
                list(challenge["options"]),
                int(challenge["correct_index"]),
                explanation=str(challenge.get("explanation", "")),
                resource=challenge.get("resource"),
            )
        )

        if len(questions) != 25:
            raise QuestionBankError(
                f"{module['id']}/{assessment} generó {len(questions)} preguntas; "
                "se esperaban 25."
            )
        self._validate_generated_questions(module, questions)
        return questions

    @staticmethod
    def _validate_generated_questions(
        module: dict[str, Any], questions: list[dict[str, Any]]
    ) -> None:
        dimension_ids = {str(item["id"]) for item in module["concepts"]}
        question_ids: set[str] = set()
        for question in questions:
            QuestionBank._validate_question(question, dimension_ids, question_ids)

