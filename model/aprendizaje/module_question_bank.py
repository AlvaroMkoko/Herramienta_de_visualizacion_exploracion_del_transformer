"""Banco pedagógico reutilizable para las evaluaciones de cada módulo.

Cada módulo produce dos formas paralelas de 25 reactivos. Los reactivos no se
limitan a reconocer la mejor opción: combinan siete interacciones calificables
con los componentes QML existentes y recorren memoria, comprensión, aplicación
y razonamiento.
"""

from __future__ import annotations

from copy import deepcopy
import random
import re
from typing import Any, Iterable

from model.evaluacion.question_bank import QuestionBank, QuestionBankError
from model.evaluacion.scorers import normalizar_texto

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
    # 11: el módulo 1 distingue la entrada del encoder de la secuencia destino
    # completa y del desplazamiento del decoder. También acepta equivalentes
    # semánticos en sus respuestas abiertas. Los resultados de la versión 10
    # no son comparables.
    # 12: las formas de tensor se escriben eje por eje, las respuestas
    # numéricas sólo aceptan números y «completar» se contesta eligiendo del
    # banco de opciones (reconocer en vez de evocar). Los de la 11 no son
    # comparables.
    # 13: los reactivos de Self-Attention incluyen el contexto necesario para
    # interpretar Q, K, V, las filas del mapa y la mezcla antes de preguntar.
    # También se retiraron instrucciones que pedían editar pesos o máscaras
    # que el laboratorio no permite manipular. Los de la 12 no son comparables.
    # 14: se reescribieron los contextos de Self-Attention que adelantaban la
    # respuesta, los verdadero/falso con gramática mecánica y los casos dobles
    # demasiado extensos. Los de la 13 no son comparables.
    VERSION_PREGUNTAS = 14

    #: Una respuesta así se pide con una casilla por eje (presentación
    #: «forma_tensor»): sin ese molde, «[5,5]», «5x5» y «5 por 5» parecen
    #: igual de válidas y nadie sabe cómo escribirla.
    _FORMA = re.compile(r"\[[^\[\]]+\]")
    _NUMERO = re.compile(r"-?\d+(?:[.,]\d+)?")

    PEDAGOGICAL_TYPES = (
        "opcion_multiple",
        "seleccion_multiple",
        "verdadero_falso",
        "ordenar_pasos",
        "relacionar_conceptos",
        "respuesta_corta",
        "completar_espacios",
    )

    FALSE_CONCEPT_CLAIMS = {
        "module_1": {
            "B3": "Convierte por sí solo cada ID en su vector contextual completo.",
            "B4": (
                "El orden de los IDs no afecta la secuencia y puede permutarse "
                "sin consecuencias."
            ),
        },
        "module_2": {
            "B3": ("Contiene una sola probabilidad por token y no usa el eje d_model."),
            "B4": "Indica cuántos tokens contiene el vocabulario.",
        },
        "module_3": {
            "B3": "Son máscaras fijas y no parámetros aprendidos.",
            "B4": "Combina directamente los Values y produce el contexto final.",
        },
        "module_4": {
            "B3": (
                "Obliga a todas las cabezas a usar exactamente el mismo subespacio."
            ),
            "B4": "Exige que todas las cabezas aprendan el mismo mapa de atención.",
        },
        "module_5": {
            "B3": (
                "Sólo permite atender posiciones anteriores mediante una máscara causal."
            ),
            "B4": "Cambia la longitud T y agrega tokens nuevos.",
        },
        "module_6": {
            "B3": "Permite atender sin restricción a tokens futuros.",
            "B4": (
                "Obtiene Q, K y V exclusivamente de posiciones futuras del decoder."
            ),
        },
        "module_7": {
            "B3": ("Convierte por sí sola los logits en probabilidades que suman uno."),
            "B4": "Mantiene logits crudos y no realiza ninguna normalización.",
        },
        "module_8": {
            "B3": (
                "Envía los IDs enteros directamente al encoder sin embeddings ni posición."
            ),
            "B4": (
                "Procesa el destino sin usar el prefijo causal ni la memoria del encoder."
            ),
        },
    }

    I8_DISTRACTOR_INDICES = {
        1: {"pre": (0, 1, 2), "post": (0, 4, 7)},
        2: {"pre": (0, 3, 7), "post": (3, 4, 7)},
        3: {"pre": (0, 2, 7), "post": (0, 5, 6)},
        4: {"pre": (0, 1, 2), "post": (0, 5, 6)},
        5: {"pre": (1, 2, 4), "post": (1, 4, 7)},
        6: {"pre": (0, 1, 6), "post": (0, 3, 6)},
        7: {"pre": (0, 1, 3), "post": (0, 4, 6)},
        8: {"pre": (0, 2, 6), "post": (0, 1, 3)},
    }

    # Una evaluación no debe lanzar símbolos aislados y esperar que el alumno
    # adivine la intención. Estos encuadres se muestran antes de cada reactivo
    # del módulo 3; dan la situación y el significado de los datos sin resolver
    # la decisión concreta que se pregunta después.
    MODULE_3_QUESTION_CONTEXTS = {
        "B1": (
            "La frase «el banco del río» ya fue convertida en vectores. X es "
            "la tabla que recibe self-attention antes de calcular Q, K y V."
        ),
        "B2": (
            "QKᵀ produce scores de compatibilidad. Si sus magnitudes son muy "
            "grandes, softmax puede concentrar casi todo el peso en una sola Key."
        ),
        "B3": (
            "En Q=XWQ, K=XWK y V=XWV intervienen dos clases de datos: la entrada "
            "X de la frase y las matrices W del modelo."
        ),
        "B4": (
            "Self-attention primero obtiene una tabla T×T y después produce un "
            "vector de contexto por token. Identifica qué tarea corresponde a QKᵀ."
        ),
        "B5": (
            "En una fila del mapa, la Query pertenece al token que busca "
            "información. Cada columna corresponde a la Key de un token; su Value "
            "contiene la información que podría aportar."
        ),
        "B6": (
            "Los scores de QKᵀ aún no son pesos. Antes de usarlos para mezclar V, "
            "se controla su magnitud y se normaliza cada fila."
        ),
        "B7": (
            "Cada etapa resuelve un problema distinto: conservar los tokens en "
            "orden, comparar pares, controlar los scores o construir contexto."
        ),
        "B8": (
            "En las formas, B es el número de ejemplos, T el número de tokens, "
            "d_model el ancho de X y d_v el ancho del contexto producido por una cabeza."
        ),
        "I1": (
            "El punto de partida es X y el resultado buscado es la tabla de "
            "compatibilidades. Ordena las operaciones usando la salida de una "
            "como entrada de la siguiente."
        ),
        "I2": (
            "El punto de partida son los scores crudos y el resultado buscado es "
            "el contexto. Ordena las operaciones que conectan ambos extremos."
        ),
        "I3": (
            "Aquí debes relacionar cada transformación con el resultado inmediato "
            "que deja, no con una salida de pasos posteriores."
        ),
        "I4": (
            "Sigue qué cambia realmente en cada etapa: pueden cambiar los ejes, "
            "la magnitud de los números o el significado de la representación."
        ),
        "I5": (
            "Una justificación correcta explica para qué es necesaria una operación; "
            "no basta con repetir su nombre."
        ),
        "I6": (
            "Para decidir si dos etapas son consecutivas, comprueba que la salida "
            "de la primera sea la entrada que necesita la segunda."
        ),
        "I7": (
            "La pregunta ya indica la entrada de una operación. Elige su salida "
            "inmediata, no el resultado final de self-attention."
        ),
        "I8": (
            "El propósito explica por qué hace falta la operación; no es una "
            "descripción de sus pasos ni una consecuencia de otra etapa."
        ),
        "I9": (
            "Un par entrada→salida sólo es válido si ambos pertenecen a la misma "
            "etapa; no mezcles el inicio de una operación con el final de otra."
        ),
        "A1": (
            "En QKᵀ, las T filas de Q se comparan con las T columnas de Kᵀ; "
            "d_k es la dimensión interna que se multiplica y se suma."
        ),
        "A2": (
            "El score que entra a softmax se calcula con score escalado = "
            "score crudo/√d_k."
        ),
        "A3": (
            "Los pesos de una fila indican cuánto multiplica cada Value; el "
            "contexto se obtiene sumando esas contribuciones ponderadas."
        ),
        "A4": (
            "Las cuatro tarjetas forman un solo cálculo. Ordénalas de modo que la "
            "salida y las dimensiones de cada una sirvan a la siguiente."
        ),
        "A5": (
            "Resuelve cada situación por separado. Recuerda que la Query busca, la "
            "Key se compara, el Value aporta contenido y W sólo cambia al entrenar."
        ),
        "A6": (
            "El escalamiento afecta la magnitud de los scores antes de softmax. "
            "Evalúa exactamente el efecto que afirma el caso."
        ),
        "A7": (
            "Para Values escalares, aplica directamente contexto = Σ(peso_j·Value_j)."
        ),
        "A8": (
            "Pesos tiene forma [T,T] y V tiene forma [T,d_v]; la T interna se "
            "suma y queda un vector de ancho d_v por cada Query."
        ),
    }

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
        return self.VERSION_PREGUNTAS

    @property
    def dimensions(self) -> list[dict[str, str]]:
        module = self.catalog.get(self._module_id)
        return [
            {"id": item["id"], "name": item["title"]} for item in module["concepts"]
        ]

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
                    covered_concepts.update(
                        str(concept_id)
                        for concept_id in question.get(
                            "concept_ids", [question["concept_id"]]
                        )
                    )
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
        def introduces_new_concept(question: dict[str, Any]) -> bool:
            question_concepts = {
                str(concept_id)
                for concept_id in question.get("concept_ids", [question["concept_id"]])
            }
            return not question_concepts.issubset(covered_concepts)

        preferences = (
            lambda q: (
                introduces_new_concept(q)
                and q["pedagogical_type"] not in covered_formats
            ),
            introduces_new_concept,
            lambda q: q["pedagogical_type"] not in covered_formats,
        )
        for predicate in preferences:
            index = next(
                (i for i, question in enumerate(pool) if predicate(question)), None
            )
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

    def answer_key(self, assessment_type: str, question_id: str) -> dict[str, Any]:
        """Respuesta correcta legible y explicación de un reactivo del banco.

        Es para la revisión posterior al post-test. Nunca debe mostrarse tras el
        pre-test: revelaría la clave de reactivos paralelos antes de la
        intervención y contaminaría la medición de ganancia.
        """
        assessment = self._normalize(assessment_type)
        question = next(
            (item for item in self._banks[assessment] if item["id"] == question_id),
            None,
        )
        if question is None:
            return {}
        return {
            "question_id": question_id,
            "concept_id": question.get("concept_id", ""),
            "correct_text": self._readable_answer(question),
            "explanation": str(question.get("explanation", "")),
        }

    @staticmethod
    def _readable_answer(question: dict[str, Any]) -> str:
        options = {
            str(option["id"]): str(option["text"])
            for option in question.get("options", []) or []
        }
        if question.get("correct_option_id"):
            return options.get(str(question["correct_option_id"]), "")
        if question.get("correct_option_ids"):
            return " · ".join(
                options.get(str(option_id), "")
                for option_id in question["correct_option_ids"]
            )
        if question.get("respuestas_aceptadas"):
            return str(question["respuestas_aceptadas"][0])
        destinations = {
            str(item["id"]): str(item["texto"])
            for item in question.get("destinos", []) or []
        }
        elements = question.get("elementos") or []
        if question.get("subtipo") == "ordenar":
            ordered = sorted(elements, key=lambda item: int(item["correcto"]))
            return " → ".join(str(item["texto"]) for item in ordered)
        return " · ".join(
            f"{item['texto']} → {destinations.get(str(item['correcto']), '')}"
            for item in elements
        )

    def dimension_name(self, dimension_id: str) -> str:
        return next(
            (item["name"] for item in self.dimensions if item["id"] == dimension_id),
            dimension_id,
        )

    def _normalize(self, assessment_type: str) -> str:
        normalized = str(assessment_type).strip().lower()
        if normalized not in self.VALID_ASSESSMENTS:
            raise QuestionBankError(
                f"Tipo de evaluación desconocido: {assessment_type!r}."
            )
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
        if isinstance(destinations, list) and shuffled.get("subtipo") != "ordenar":
            self._rng.shuffle(destinations)

        bank = shuffled.get("banco_opciones")
        if isinstance(bank, list):
            self._rng.shuffle(bank)
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
            f"Lee la afirmación y decide si es verdadera o falsa:\n\n{statement}",
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
        options: Iterable[str] = (),
        symbols: Iterable[str] = (),
    ) -> dict[str, Any]:
        """Reactivo de texto con la casilla que corresponde a su respuesta.

        Con ``options`` se contesta eligiendo del banco (sin ortografía que
        adivinar); una forma ``[..]`` se escribe eje por eje con ``symbols`` a
        la mano; un número sólo admite dígitos. Lo demás queda en texto libre.
        La respuesta sigue siendo ``{"texto": ...}`` en todos los casos, así que
        la calificación no cambia.
        """
        aceptadas = list(
            dict.fromkeys(str(item).strip() for item in accepted if str(item).strip())
        )
        bank = list(dict.fromkeys(str(item) for item in options if str(item).strip()))
        es_forma = (
            not bank and bool(aceptadas) and bool(cls._FORMA.fullmatch(aceptadas[0]))
        )
        question = cls._base_question(
            prefix,
            code,
            concept_id,
            difficulty,
            bloom_level,
            cognitive_process,
            pedagogical_type,
            formato,
            "forma_tensor" if es_forma else "caja_en_linea",
            "texto",
            prompt,
            explanation=explanation,
        )
        question["respuestas_aceptadas"] = aceptadas
        question["placeholder"] = placeholder
        if bank:
            question["banco_opciones"] = bank
        elif es_forma:
            question["simbolos"] = list(symbols)
        elif aceptadas and all(cls._NUMERO.fullmatch(item) for item in aceptadas):
            question["formato_respuesta"] = "numero"
            question["placeholder"] = "Escribe sólo el número"
        return question

    @staticmethod
    def _shape_symbols(steps: list[dict[str, Any]]) -> list[str]:
        """Símbolos de eje que usa el recorrido del módulo (B, T, d_model…)."""
        symbols: list[str] = []
        for step in steps:
            for shape in re.findall(r"\[([^\[\]]+)\]", str(step.get("dimensions", ""))):
                for part in shape.split(","):
                    part = part.strip()
                    if part and not part.isdigit() and part not in symbols:
                        symbols.append(part)
        return symbols

    @staticmethod
    def _bank_options(
        correct: str, candidates: Iterable[str], excluded: Iterable[str] = ()
    ) -> list[str]:
        """La respuesta y tres distractores del propio módulo, sin repetidos."""
        seen = {normalizar_texto(item) for item in excluded}
        seen.discard("")
        options = [correct]
        seen.add(normalizar_texto(correct))
        for candidate in candidates:
            key = normalizar_texto(candidate)
            if key and key not in seen:
                options.append(str(candidate))
                seen.add(key)
            if len(options) == 4:
                break
        return options

    @staticmethod
    def _distractor_indices(index: int, total: int) -> list[int]:
        # Se evita el paso siguiente: su resultado suele refinar el del paso
        # pedido («Contexto por token» y «Attention(X)») y dejaría dos opciones
        # defendibles.
        offsets = (-1, -2, -3, 2, 3, -4, 4)
        return [(index + offset) % total for offset in offsets]

    @staticmethod
    def _accepted_short_answers(answer: Any) -> list[str]:
        """Incluye variantes de escritura sin ampliar el significado correcto."""

        value = str(answer).strip()
        candidates = [value]

        # Las cantidades grandes se muestran con espacio de millares para
        # facilitar su lectura (20 000), pero el estudiante puede escribirlas
        # de forma compacta (20000). Ambas notaciones expresan el mismo valor.
        compact_numbers = re.sub(r"(?<=\d)\s+(?=\d)", "", value)
        if compact_numbers != value:
            candidates.append(compact_numbers)

        if ":" in value:
            suffix = value.rsplit(":", 1)[1].strip()
            if suffix:
                candidates.append(suffix)

        shapes = re.findall(r"\[([^\[\]]+)\]", value)
        if len(shapes) == 1:
            parts = [part.strip() for part in shapes[0].split(",")]
            if len(parts) > 1 and all(parts):
                candidates.extend((" x ".join(parts), " por ".join(parts)))
                compact_parts = [
                    re.sub(r"(?<=\d)\s+(?=\d)", "", part) for part in parts
                ]
                if compact_parts != parts:
                    candidates.extend(
                        (" x ".join(compact_parts), " por ".join(compact_parts))
                    )

        aliases = {
            "keys y values": ("K y V", "claves y valores"),
            "query": ("Q", "consulta"),
        }
        candidates.extend(aliases.get(value.casefold(), ()))
        return list(dict.fromkeys(item for item in candidates if item))

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
    def _challenge_form(challenge: dict[str, Any], assessment: str) -> dict[str, Any]:
        """Reto con el enunciado, opciones y clave de la forma pedida.

        Con alineación, el post usa una variante isomorfa: mismo constructo y
        dificultad, otros números y sin nombrar la operación. Sin ella se
        conserva el comportamiento anterior (``post_prompt`` sobre las mismas
        opciones).
        """
        variant = challenge.get("post_variant") if assessment == "post" else None
        if not isinstance(variant, dict):
            return challenge
        form = {
            "id": challenge["id"],
            "concept_id": challenge["concept_id"],
            "prompt": variant["prompt"],
            "options": list(variant["options"]),
            "correct_index": int(variant["correct_index"]),
            "explanation": variant.get("explanation", ""),
        }
        if variant.get("resource"):
            form["resource"] = deepcopy(variant["resource"])
        return form

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

    @classmethod
    def _contextualize_module_questions(
        cls, module: dict[str, Any], questions: list[dict[str, Any]]
    ) -> None:
        """Antecede cada reactivo del módulo 3 con la información que necesita.

        El contexto se añade al final de la construcción para cubrir por igual
        opciones, verdadero/falso, relaciones, ordenamientos y respuestas
        cortas. Así ningún formato vuelve a presentar Q, K, V o una dimensión
        como símbolos aislados.
        """

        if module.get("id") != "module_3":
            return
        for question in questions:
            code = str(question.get("code", ""))
            context = cls.MODULE_3_QUESTION_CONTEXTS.get(code, "").strip()
            if not context:
                raise QuestionBankError(
                    f"module_3/{code or 'sin código'} no tiene contexto pedagógico."
                )
            prompt = str(question.get("prompt", "")).strip()
            question["prompt"] = f"Contexto — {context}\n\n{prompt}"

    def _build_questions(
        self, module: dict[str, Any], assessment: str
    ) -> list[dict[str, Any]]:
        prefix = f"{module['id']}_{assessment}"
        concepts = module["concepts"]
        steps = module["guided_steps"]
        challenges = [
            self._challenge_form(challenge, assessment)
            for challenge in module["challenges"]
        ]
        transfer_items = module.get("transfer_items") or []
        shape_symbols = self._shape_symbols(steps)
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
            if module["id"] == "module_3":
                prompt = (
                    "¿Qué descripción explica correctamente qué contiene X?"
                    if code == "B1"
                    else "¿Qué hace el escalamiento por √d_k para evitarlo?"
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

        def operation_choice(code: str, index: int) -> dict[str, Any]:
            """Evalúa una operación enseñada sin repetir su definición."""

            step = steps[index]
            correct_operation = str(step["operation"])
            distractors: list[str] = []
            for jump in range(1, len(steps)):
                candidate = str(steps[(index + jump) % len(steps)]["operation"])
                if candidate != correct_operation and candidate not in distractors:
                    distractors.append(candidate)
                if len(distractors) == 3:
                    break
            prompt = f"¿Qué operación se realiza durante «{step['title']}»?"
            if module["id"] == "module_3":
                prompt = (
                    "¿Qué operación construye la matriz X?"
                    if code == "B1"
                    else "¿Qué operación se realiza durante el escalamiento?"
                )
            return self._single_choice(
                prefix,
                code,
                step["concept_id"],
                "Básica",
                "Comprender",
                "Reconocimiento de operaciones",
                prompt,
                [correct_operation, *distractors],
                0,
                explanation=(
                    f"Durante «{step['title']}» se realiza esta operación: "
                    f"{correct_operation}."
                ),
            )

        # ── 8 básicas: recordar sin reducir todo a reconocimiento ─────
        if assessment == "pre":
            questions.extend([concept_choice("B1", 0), concept_choice("B2", 4)])
        else:
            questions.extend([operation_choice("B1", 0), operation_choice("B2", 4)])

        concept = concepts[1]
        if assessment == "pre":
            description = concept["description"]
            correct = True
        else:
            description = self.FALSE_CONCEPT_CLAIMS[module["id"]]["B3"]
            correct = False
        statement = (
            (
                "WQ, WK y WV son parámetros aprendidos que transforman X para "
                "obtener Q, K y V."
                if assessment == "pre"
                else "WQ, WK y WV son máscaras fijas, no parámetros aprendidos."
            )
            if module["id"] == "module_3"
            else f"La función específica de «{concept['title']}» es: {description}"
        )
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
            description = self.FALSE_CONCEPT_CLAIMS[module["id"]]["B4"]
            correct = False
        else:
            description = concept["description"]
            correct = True
        statement = (
            (
                "QKᵀ mezcla directamente los Values y produce el contexto final."
                if assessment == "pre"
                else "QKᵀ compara la Query de cada token con la Key de todos los "
                "tokens y produce una tabla de scores de compatibilidad."
            )
            if module["id"] == "module_3"
            else f"La función específica de «{concept['title']}» es: {description}"
        )
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
        blank_answers = [blank_step["title"]]
        if module["id"] == "module_1":
            blank_answers.extend(
                (
                    ["Agregar BOS y EOS", "BOS y EOS"]
                    if blank_step["id"] == "m1_s5"
                    else ["Formar secuencias"]
                )
            )
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
                blank_answers,
                pedagogical_type="completar_espacios",
                formato="Completar espacios",
                placeholder="Elige la etapa",
                explanation=f"La etapa intermedia es {blank_step['title']}.",
                options=self._bank_options(
                    blank_step["title"],
                    (
                        steps[index]["title"]
                        for index in self._distractor_indices(blank_index, len(steps))
                    ),
                    excluded=(previous_step["title"], next_step["title"]),
                ),
            )
        )

        relation_indices = [0, 2, 4, 6] if assessment == "pre" else [1, 3, 5, 7]
        relation_steps = [steps[index] for index in relation_indices]
        reason_pairs = [(step["title"], step["why"]) for step in relation_steps]
        elements, destinations = self._relation_payload(reason_pairs)
        questions.append(
            self._assignment_question(
                prefix,
                "B7",
                relation_steps[0]["concept_id"],
                "Básica",
                "Comprender",
                "Justificación de etapas",
                "Relaciona cada etapa con el motivo por el que se realiza.",
                elements,
                destinations,
                subtype="relacionar",
                related_concepts=[step["concept_id"] for step in relation_steps[1:]],
                explanation="Relaciones correctas: "
                + "; ".join(f"«{title}» → {reason}" for title, reason in reason_pairs)
                + ".",
            )
        )

        dimension_indices = {
            1: (6, 3),
            2: (7, 0),
            3: (7, 0),
            4: (7, 0),
            5: (7, 0),
            6: (7, 0),
            7: (6, 0),
            8: (5, 1),
        }
        dimension_index = dimension_indices[int(module["order"])][
            0 if assessment == "pre" else 1
        ]
        dimension_step = steps[dimension_index]
        questions.append(
            self._text_question(
                prefix,
                "B8",
                dimension_step["concept_id"],
                "Básica",
                "Aplicar",
                "Lectura de dimensiones",
                f"Al terminar el paso «{dimension_step['title']}», ¿qué forma "
                f"(dimensiones) tiene el tensor que se obtiene? Escríbela eje por "
                f"eje con los símbolos del recorrido.",
                self._accepted_short_answers(dimension_step["dimensions"]),
                pedagogical_type="respuesta_corta",
                formato="Forma del tensor",
                placeholder="Eje",
                explanation=f"La forma esperada es {dimension_step['dimensions']}.",
                symbols=shape_symbols,
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
                    related_concepts=[
                        step["concept_id"] for step in ordered_steps[:-1]
                    ],
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

        change_steps = [
            steps[index]
            for index in ([1, 3, 5, 7] if assessment == "pre" else [0, 2, 4, 6])
        ]
        change_pairs = [(step["title"], step["change"]) for step in change_steps]
        elements, destinations = self._relation_payload(change_pairs)
        questions.append(
            self._assignment_question(
                prefix,
                "I4",
                change_steps[0]["concept_id"],
                "Intermedia",
                "Comprender",
                "Relación etapa–cambio",
                "Relaciona cada etapa con el cambio observable que produce.",
                elements,
                destinations,
                subtype="relacionar",
                related_concepts=[step["concept_id"] for step in change_steps[1:]],
                explanation="Relaciones correctas: "
                + "; ".join(f"«{title}» → {change}" for title, change in change_pairs)
                + ".",
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

        output_step = steps[6 if assessment == "pre" else 4]
        output_answers = self._accepted_short_answers(output_step["output"])
        if module["id"] == "module_1":
            output_answers.extend(
                (
                    ["Batch de IDs", "Matriz rectangular de IDs"]
                    if output_step["id"] == "m1_s7"
                    else [
                        "IDs con BOS y EOS",
                        "Secuencia con BOS y EOS",
                        "Secuencia delimitada",
                    ]
                )
            )
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
                output_answers,
                pedagogical_type="completar_espacios",
                formato="Completar espacios",
                placeholder="Elige la salida",
                explanation=f"Produce {output_step['output']}.",
                options=self._bank_options(
                    output_step["output"],
                    (
                        steps[index]["output"]
                        for index in self._distractor_indices(
                            steps.index(output_step), len(steps)
                        )
                    ),
                    excluded=(output_step["input"],),
                ),
            )
        )

        why_index = 5 if assessment == "pre" else 2
        why_step = steps[why_index]
        distractor_whys = [
            steps[index]["why"]
            for index in self.I8_DISTRACTOR_INDICES[int(module["order"])][assessment]
        ]
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
                "Selecciona los DOS pares que describen la entrada y la salida "
                "de una misma etapa del recorrido.",
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
                "Resuelve sin opciones: "
                + self._challenge_prompt(challenge, assessment),
                self._accepted_short_answers(self._correct_answer(challenge)),
                pedagogical_type="respuesta_corta",
                formato="Respuesta numérica/corta",
                placeholder="Escribe el valor o la dimensión",
                explanation=str(challenge.get("explanation", "")),
                symbols=shape_symbols,
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
        if module["id"] == "module_3":
            paired_prompt = (
                "Selecciona las DOS opciones en las que los pesos y su efecto "
                "están emparejados correctamente."
            )
            if assessment == "pre":
                paired_cases = [
                    "Pesos [0.1, 0.7, 0.2] → el segundo Value aporta más.",
                    "Pesos [0.25, 0.75] y Values [4, 8] → el contexto vale 7.",
                    "Pesos [0.1, 0.7, 0.2] → el primer Value aporta más.",
                    "Pesos [0.25, 0.75] y Values [4, 8] → el contexto vale 6.",
                ]
            else:
                paired_cases = [
                    "Pesos [0.5, 0.1, 0.4] → el primer Value aporta más.",
                    "Pesos [0.6, 0.4] y Values [5, 10] → el contexto vale 7.",
                    "Pesos [0.5, 0.1, 0.4] → el segundo Value aporta más.",
                    "Pesos [0.6, 0.4] y Values [5, 10] → el contexto vale 7.5.",
                ]
        else:
            paired_prompt = (
                "Se presentan dos casos. Selecciona las DOS opciones en las que "
                "el caso y la respuesta están emparejados correctamente."
            )
            paired_cases = [
                f"Caso 1 — {self._challenge_prompt(first_challenge, assessment)} "
                f"Respuesta propuesta: {self._correct_answer(first_challenge)}",
                f"Caso 2 — {self._challenge_prompt(second_challenge, assessment)} "
                f"Respuesta propuesta: {self._correct_answer(second_challenge)}",
                f"Caso 1 — {self._challenge_prompt(first_challenge, assessment)} "
                f"Respuesta propuesta: {self._wrong_answer(first_challenge)}",
                f"Caso 2 — {self._challenge_prompt(second_challenge, assessment)} "
                f"Respuesta propuesta: {self._wrong_answer(second_challenge)}",
            ]
        questions.append(
            self._multiple_selection(
                prefix,
                "A3",
                first_challenge["concept_id"],
                "Avanzada",
                "Analizar",
                "Razonamiento",
                paired_prompt,
                paired_cases,
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

        # Con transferencia propia, A5 usa tres retos y deja el octavo sólo a
        # A8; antes A5, A6 y A8 repetían los mismos casos en un mismo intento.
        related_challenges = challenges[4:7] if transfer_items else challenges[4:8]
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
                "Relaciona cada situación con la conclusión correcta. Cada "
                "conclusión se usa una sola vez.",
                elements,
                destinations,
                subtype="relacionar",
                related_concepts=[
                    challenge["concept_id"] for challenge in related_challenges[1:]
                ],
            )
        )

        if transfer_items:
            # Transferencia: situaciones nuevas con el mismo mecanismo. No
            # comparten caso con ningún otro reactivo del intento ni con los
            # retos del laboratorio.
            true_false, short_answer = transfer_items[0], transfer_items[1]
            form = true_false[assessment]
            questions.append(
                self._true_false(
                    prefix,
                    "A6",
                    true_false["concept_id"],
                    "Avanzada",
                    "Analizar",
                    "Transferencia",
                    str(form["statement"]),
                    bool(form["correct"]),
                    explanation=str(form.get("explanation", "")),
                )
            )
            form = short_answer[assessment]
            questions.append(
                self._text_question(
                    prefix,
                    "A7",
                    short_answer["concept_id"],
                    "Avanzada",
                    "Aplicar",
                    "Cálculo sin pistas",
                    "Responde sin opciones: " + str(form["prompt"]),
                    self._accepted_short_answers(form["answer"]),
                    pedagogical_type="respuesta_corta",
                    formato="Respuesta numérica/corta",
                    placeholder="Escribe una respuesta breve",
                    explanation=str(form.get("explanation", "")),
                )
            )
        else:
            challenge = challenges[4]
            conclusion_is_correct = (
                int(module["order"]) + (0 if assessment == "pre" else 1)
            ) % 2 == 0
            conclusion = (
                self._correct_answer(challenge)
                if conclusion_is_correct
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
                    f"Caso: {self._challenge_prompt(challenge, assessment)}\n"
                    f"Conclusión propuesta: {conclusion}",
                    conclusion_is_correct,
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
                    "Responde sin opciones: "
                    + self._challenge_prompt(challenge, assessment),
                    self._accepted_short_answers(self._correct_answer(challenge)),
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

        self._contextualize_module_questions(module, questions)

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
