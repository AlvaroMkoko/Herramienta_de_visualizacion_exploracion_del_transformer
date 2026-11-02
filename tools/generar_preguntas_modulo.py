"""Genera el documento de preguntas y respuestas correctas de un módulo.

Parte del banco y del catálogo reales, para que el documento no se desfase del
instrumento. Sirve para que el equipo revise un módulo completo sin abrir la
aplicación:

    python tools/generar_preguntas_modulo.py module_4

Sin argumentos genera los módulos 1, 2 y 4–8. El del módulo 3 se escribió a mano,
con su propio formato, y aquí no se toca.
"""

from __future__ import annotations

import random
import re
import sys
import unicodedata
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
if str(RAIZ) not in sys.path:
    sys.path.insert(0, str(RAIZ))

from model.aprendizaje.learning_module import LearningModuleCatalog  # noqa: E402
from model.aprendizaje.module_question_bank import ModuleQuestionBank  # noqa: E402

MODULOS = ("module_1", "module_2", "module_4", "module_5", "module_6", "module_7", "module_8")


def nombre_de_archivo(module_id: str, titulo: str) -> Path:
    plano = unicodedata.normalize("NFKD", titulo).encode("ascii", "ignore").decode()
    slug = re.sub(r"[^a-z0-9]+", "_", plano.lower()).strip("_")
    numero = module_id.split("_")[1]
    return RAIZ / f"preguntas_respuestas_modulo_{numero}_{slug}.md"


def _elegida(reto: dict) -> str:
    return str(reto["options"][int(reto["correct_index"])])


def _reactivo(banco: ModuleQuestionBank, pregunta: dict, forma: str, lineas: list[str]) -> None:
    lineas.append(f"### {forma.upper()}-{pregunta['code']}")
    lineas.append("")
    lineas.append(f"**Pregunta:** {pregunta['prompt']}")
    lineas.append("")
    opciones = pregunta.get("options") or []
    if opciones:
        for opcion in opciones:
            lineas.append(f"- {opcion['text']}")
        lineas.append("")
    lineas.append(f"**Clave:** {banco.answer_key(forma, pregunta['id'])['correct_text']}")
    lineas.append("")


def generar(module_id: str) -> Path:
    catalogo = LearningModuleCatalog()
    modulo = catalogo.get(module_id)
    banco = ModuleQuestionBank(catalogo, module_id=module_id, rng=random.Random(0))
    version = ModuleQuestionBank.version_de_modulo(module_id)
    lineas = [
        f"# Preguntas y respuestas correctas — Módulo {modulo['order']}: {modulo['title']}",
        "",
        f"Generado por `tools/generar_preguntas_modulo.py`. Corresponde a la versión "
        f"{version} del banco modular. El pre-test y el post-test tienen 25 reactivos "
        f"disponibles cada uno; cada intento selecciona "
        f"{ModuleQuestionBank.QUESTIONS_PER_ATTEMPT}.",
        "",
        "## Pregunta ancla",
        "",
        f"**Pregunta:** {modulo['anchor']['question']}",
        "",
        f"**Ejemplo:** {modulo['anchor']['example']}",
        "",
        f"**Cierre:** {modulo['anchor']['closing']['prompt']}",
        "",
        f"**Respuesta correcta:** {_elegida(modulo['anchor']['closing'])}",
        "",
        "## Comprobaciones del recorrido guiado",
        "",
    ]
    for indice, paso in enumerate(modulo["guided_steps"], start=1):
        lineas += [
            f"### R{indice}. {paso['title']}",
            "",
            f"**Pregunta:** {paso['check']['prompt']}",
            "",
            f"**Respuesta correcta:** {_elegida(paso['check'])}",
            "",
        ]
    for forma, titulo in (("pre", "Pre-test"), ("post", "Post-test")):
        lineas += [f"## {titulo}", ""]
        for pregunta in banco.all_questions(forma):
            _reactivo(banco, pregunta, forma, lineas)
    lineas += ["## Retos del laboratorio", ""]
    for reto in modulo["lab_challenges"]:
        lineas += [
            f"### LAB-{reto['id']}",
            "",
            f"**Pregunta:** {reto['prompt']}",
            "",
            f"**Respuesta correcta:** {_elegida(reto)}",
            "",
            f"**Explicación:** {reto.get('explanation', '')}",
            "",
        ]
    destino = nombre_de_archivo(module_id, str(modulo["title"]))
    destino.write_text("\n".join(lineas).rstrip() + "\n", encoding="utf-8", newline="\n")
    return destino


def main() -> None:
    for module_id in sys.argv[1:] or MODULOS:
        print(generar(module_id))


if __name__ == "__main__":
    main()
