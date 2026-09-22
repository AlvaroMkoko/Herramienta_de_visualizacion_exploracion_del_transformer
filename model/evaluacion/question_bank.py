"""Carga y valida el banco JSON de pre-test y post-test (esquema v2)."""

from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
from typing import Any

from .scorers import TIPOS_SOPORTADOS

DEFAULT_QUESTION_BANK_PATH = (
    Path(__file__).resolve().parents[2] / "data" / "evaluacion" / "question_bank.json"
)

#: Claves que jamás deben cruzar a QML durante el examen.
CLAVES_SECRETAS = (
    "correct_option_id",
    "correct_option_ids",
    "respuestas_aceptadas",
)


class QuestionBankError(ValueError):
    """El banco no cumple el contrato esperado por la evaluación."""


class QuestionBank:
    """Fuente única de preguntas y respuestas correctas.

    El modelo conserva las claves de respuesta; la vista solo recibe copias
    públicas sin ellas, para que la solución no viaje a QML durante el examen.
    """

    VALID_ASSESSMENTS = ("pre", "post")
    SCHEMA_VERSION = 2

    def __init__(self, path: str | Path | None = None) -> None:
        self.path = Path(path) if path is not None else DEFAULT_QUESTION_BANK_PATH
        self._data = self._load()
        self._validate()
        self._dimensions = {
            item["id"]: item["name"] for item in self._data["dimensions"]
        }

    # ------------------------------------------------------------------
    # Carga
    # ------------------------------------------------------------------

    def _load(self) -> dict[str, Any]:
        try:
            with self.path.open("r", encoding="utf-8") as source:
                data = json.load(source)
        except (OSError, json.JSONDecodeError) as exc:
            raise QuestionBankError(
                f"No se pudo cargar el banco de preguntas: {exc}"
            ) from exc
        if not isinstance(data, dict):
            raise QuestionBankError("La raíz del banco debe ser un objeto JSON.")
        return data

    # ------------------------------------------------------------------
    # Validación
    # ------------------------------------------------------------------

    def _validate(self) -> None:
        version = self._data.get("schema_version")
        if version != self.SCHEMA_VERSION:
            raise QuestionBankError(
                f"El banco declara schema_version={version!r}; se esperaba "
                f"{self.SCHEMA_VERSION}. Un banco v1 (una sola opción correcta por "
                "reactivo) ya no es compatible con el instrumento vigente."
            )

        dimensions = self._data.get("dimensions")
        assessments = self._data.get("assessments")
        if not isinstance(dimensions, list) or not dimensions:
            raise QuestionBankError("El banco debe declarar sus dimensiones.")
        if not isinstance(assessments, dict):
            raise QuestionBankError("El banco debe declarar sus evaluaciones.")

        dimension_ids: set[str] = set()
        for dimension in dimensions:
            if not isinstance(dimension, dict):
                raise QuestionBankError("Cada dimensión debe ser un objeto.")
            dimension_id = str(dimension.get("id", "")).strip()
            name = str(dimension.get("name", "")).strip()
            if not dimension_id or not name or dimension_id in dimension_ids:
                raise QuestionBankError("Las dimensiones deben tener id y nombre únicos.")
            dimension_ids.add(dimension_id)

        question_ids: set[str] = set()
        for assessment_type in self.VALID_ASSESSMENTS:
            assessment = assessments.get(assessment_type)
            if not isinstance(assessment, dict):
                raise QuestionBankError(
                    f"Falta la evaluación obligatoria {assessment_type!r}."
                )
            questions = assessment.get("questions")
            if not isinstance(questions, list) or not questions:
                raise QuestionBankError(
                    f"La evaluación {assessment_type!r} no tiene preguntas."
                )
            for question in questions:
                self._validate_question(question, dimension_ids, question_ids)

    @classmethod
    def _validate_question(
        cls, question: Any, dimension_ids: set[str], question_ids: set[str]
    ) -> None:
        if not isinstance(question, dict):
            raise QuestionBankError("Cada pregunta debe ser un objeto.")

        question_id = str(question.get("id", "")).strip()
        if not question_id or question_id in question_ids:
            raise QuestionBankError("Cada pregunta debe tener un id global único.")
        question_ids.add(question_id)

        if question.get("dimension_id") not in dimension_ids:
            raise QuestionBankError(
                f"La pregunta {question_id!r} referencia una dimensión inexistente."
            )
        if not str(question.get("prompt", "")).strip():
            raise QuestionBankError(f"La pregunta {question_id!r} no tiene enunciado.")

        try:
            maximo = float(question.get("puntaje_maximo"))
        except (TypeError, ValueError):
            raise QuestionBankError(
                f"La pregunta {question_id!r} no declara un puntaje_maximo numérico."
            ) from None
        if maximo <= 0:
            raise QuestionBankError(
                f"El puntaje_maximo de {question_id!r} debe ser mayor que cero."
            )

        cls._validate_body(question, question_id, maximo)

    @classmethod
    def _validate_body(
        cls, question: dict[str, Any], question_id: str, maximo: float
    ) -> None:
        tipo = str(question.get("tipo", ""))
        if tipo not in TIPOS_SOPORTADOS:
            raise QuestionBankError(
                f"La pregunta {question_id!r} declara un tipo no soportado: {tipo!r}."
            )

        if tipo in ("opcion_unica", "seleccion_multiple"):
            option_ids = cls._validate_options(question, question_id)
            if tipo == "opcion_unica":
                if question.get("correct_option_id") not in option_ids:
                    raise QuestionBankError(
                        f"La respuesta correcta de {question_id!r} no existe entre sus opciones."
                    )
            else:
                correctas = question.get("correct_option_ids")
                if not isinstance(correctas, list) or not correctas:
                    raise QuestionBankError(
                        f"{question_id!r} debe declarar correct_option_ids."
                    )
                if not set(map(str, correctas)) <= set(option_ids):
                    raise QuestionBankError(
                        f"{question_id!r} marca como correcta una opción inexistente."
                    )
                if len(set(map(str, correctas))) == len(option_ids):
                    raise QuestionBankError(
                        f"En {question_id!r} todas las opciones son correctas; el "
                        "reactivo no discrimina."
                    )

        elif tipo == "texto":
            aceptadas = question.get("respuestas_aceptadas")
            if not isinstance(aceptadas, list) or not aceptadas:
                raise QuestionBankError(
                    f"{question_id!r} debe declarar respuestas_aceptadas."
                )
            if any(not str(item).strip() for item in aceptadas):
                raise QuestionBankError(
                    f"{question_id!r} tiene una respuesta aceptada vacía."
                )

        elif tipo == "asignacion":
            destinos = question.get("destinos")
            elementos = question.get("elementos")
            if not isinstance(destinos, list) or len(destinos) < 2:
                raise QuestionBankError(
                    f"{question_id!r} necesita al menos dos destinos."
                )
            if not isinstance(elementos, list) or not elementos:
                raise QuestionBankError(f"{question_id!r} no tiene elementos.")

            destino_ids = [str(destino.get("id", "")) for destino in destinos]
            if any(not d for d in destino_ids) or len(destino_ids) != len(set(destino_ids)):
                raise QuestionBankError(
                    f"{question_id!r} tiene destinos sin id o repetidos."
                )

            usados = [str(elemento.get("correcto", "")) for elemento in elementos]
            for usado in usados:
                if usado not in destino_ids:
                    raise QuestionBankError(
                        f"{question_id!r} asigna un elemento a un destino inexistente."
                    )
            if question.get("destinos_unicos"):
                if len(set(usados)) != len(usados):
                    raise QuestionBankError(
                        f"{question_id!r} declara destinos_unicos pero repite respuestas."
                    )
                if len(elementos) != len(destinos):
                    raise QuestionBankError(
                        f"{question_id!r} declara destinos_unicos: debe haber tantos "
                        "elementos como destinos."
                    )

        elif tipo == "etapas":
            cls._validate_etapas(question, question_id, maximo)

    @classmethod
    def _validate_etapas(
        cls, question: dict[str, Any], question_id: str, maximo: float
    ) -> None:
        etapas = question.get("etapas")
        if not isinstance(etapas, list) or len(etapas) < 2:
            raise QuestionBankError(f"{question_id!r} necesita al menos dos etapas.")

        vistas: set[str] = set()
        peso_total = 0.0
        for etapa in etapas:
            if not isinstance(etapa, dict):
                raise QuestionBankError(f"Cada etapa de {question_id!r} debe ser un objeto.")
            etapa_id = str(etapa.get("id", "")).strip()
            if not etapa_id or etapa_id in vistas:
                raise QuestionBankError(
                    f"Las etapas de {question_id!r} necesitan un id único."
                )

            tipo_etapa = str(etapa.get("tipo", ""))
            if tipo_etapa not in ("opcion_unica", "texto_libre"):
                raise QuestionBankError(
                    f"La etapa {etapa_id!r} de {question_id!r} usa un tipo no soportado: "
                    f"{tipo_etapa!r}."
                )

            puntua = bool(etapa.get("puntua", True))
            peso = float(etapa.get("peso", 0.0))
            if puntua:
                if tipo_etapa == "texto_libre":
                    raise QuestionBankError(
                        f"La etapa {etapa_id!r} de {question_id!r} es texto libre y no "
                        "puede puntuar."
                    )
                peso_total += peso
                cls._validate_options(etapa, f"{question_id}/{etapa_id}")
                if etapa.get("correct_option_id") not in [
                    str(option.get("id")) for option in etapa.get("options", [])
                ]:
                    raise QuestionBankError(
                        f"La etapa {etapa_id!r} de {question_id!r} no marca una respuesta válida."
                    )
            elif peso:
                raise QuestionBankError(
                    f"La etapa {etapa_id!r} de {question_id!r} no puntúa, su peso debe ser 0."
                )

            dependencia = etapa.get("depende_de")
            if dependencia is not None:
                if not isinstance(dependencia, dict):
                    raise QuestionBankError(
                        f"depende_de de {etapa_id!r} en {question_id!r} debe ser un objeto."
                    )
                padre_id = str(dependencia.get("etapa_id", ""))
                if padre_id not in vistas:
                    raise QuestionBankError(
                        f"La etapa {etapa_id!r} de {question_id!r} depende de una etapa "
                        "posterior o inexistente."
                    )
                padre = next(e for e in etapas if str(e.get("id")) == padre_id)
                padre_option_ids = {str(o.get("id")) for o in padre.get("options", [])}
                if str(dependencia.get("opcion_id")) not in padre_option_ids:
                    raise QuestionBankError(
                        f"La dependencia de {etapa_id!r} en {question_id!r} apunta a una "
                        "opción inexistente."
                    )

            vistas.add(etapa_id)

        if abs(peso_total - maximo) > 1e-9:
            raise QuestionBankError(
                f"Los pesos que puntúan en {question_id!r} suman {peso_total}; deben "
                f"sumar su puntaje_maximo ({maximo})."
            )

    @staticmethod
    def _validate_options(contenedor: dict[str, Any], etiqueta: str) -> list[str]:
        options = contenedor.get("options")
        if not isinstance(options, list) or len(options) < 2:
            raise QuestionBankError(f"{etiqueta!r} necesita al menos dos opciones.")
        option_ids = [str(option.get("id", "")) for option in options]
        if any(not option_id for option_id in option_ids) or len(option_ids) != len(
            set(option_ids)
        ):
            raise QuestionBankError(f"{etiqueta!r} tiene opciones sin id o repetidas.")
        if any(not str(option.get("text", "")).strip() for option in options):
            raise QuestionBankError(f"{etiqueta!r} tiene una opción sin texto.")
        return option_ids

    # ------------------------------------------------------------------
    # Consulta
    # ------------------------------------------------------------------

    def get_assessment(self, assessment_type: str) -> dict[str, Any]:
        normalized = str(assessment_type).lower().strip()
        if normalized not in self.VALID_ASSESSMENTS:
            raise QuestionBankError(
                f"Tipo de evaluación desconocido: {assessment_type!r}."
            )
        return deepcopy(self._data["assessments"][normalized])

    def get_questions(self, assessment_type: str) -> list[dict[str, Any]]:
        return self.get_assessment(assessment_type)["questions"]

    @classmethod
    def public_question(cls, question: dict[str, Any]) -> dict[str, Any]:
        """Copia sin ninguna clave de respuesta, incluidas las anidadas.

        El esquema v2 esconde la solución en cuatro lugares distintos: la opción
        única, la lista de correctas, las respuestas de texto aceptadas y el
        campo ``correcto`` de cada elemento de una asignación. Además, las
        etapas repiten la estructura un nivel más abajo. Olvidar cualquiera de
        ellos deja la respuesta visible desde QML.
        """
        public = deepcopy(question)
        for clave in CLAVES_SECRETAS:
            public.pop(clave, None)

        for elemento in public.get("elementos", []):
            if isinstance(elemento, dict):
                elemento.pop("correcto", None)

        etapas = public.get("etapas")
        if isinstance(etapas, list):
            public["etapas"] = [
                cls.public_question(etapa) if isinstance(etapa, dict) else etapa
                for etapa in etapas
            ]
        return public

    def get_public_questions(self, assessment_type: str) -> list[dict[str, Any]]:
        return [
            self.public_question(question)
            for question in self.get_questions(assessment_type)
        ]

    def dimension_name(self, dimension_id: str) -> str:
        return self._dimensions.get(dimension_id, dimension_id)

    @property
    def dimensions(self) -> list[dict[str, str]]:
        return deepcopy(self._data["dimensions"])

    @property
    def criterios(self) -> dict[str, str]:
        return deepcopy(self._data.get("criterios", {}))
