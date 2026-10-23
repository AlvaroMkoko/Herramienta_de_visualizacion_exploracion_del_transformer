"""Genera los datasets predefinidos de traducción a partir de Tatoeba EN-ES.

Procedencia de los datos
------------------------
- Corpus: Tatoeba (https://tatoeba.org), pares inglés–español.
- Volcado: OPUS Tatoeba v2026-07-08 (publicado el 9 de julio de 2026), formato moses:
  https://object.pouta.csc.fi/OPUS-Tatoeba/v2026-07-08/moses/en-es.txt.zip
- Licencia: CC BY 2.0 FR (https://creativecommons.org/licenses/by/2.0/fr/).
- Cita que pide OPUS: J. Tiedemann, 2012, «Parallel Data, Tools and Interfaces in
  OPUS». In Proceedings of the 8th International Conference on Language Resources
  and Evaluation (LREC 2012).

El volcado en bruto no entra al repositorio: se descarga y descomprime aparte.

Salida: ``traduccion_es_en_basica.jsonl`` (ES→EN) y ``traduccion_en_es_basica.jsonl``
(los mismos pares invertidos). ``traduccion_demo.jsonl`` está escrito a mano y este
script no lo genera.

Uso, desde la raíz del repositorio:

    python tools/filtrar_tatoeba.py <Tatoeba.en-es.en> <Tatoeba.en-es.es> <directorio_salida>

La lista negra vive en ``tools/palabras_vetadas_corpus.txt``. Las pruebas de
``tests/model/test_datasets_traduccion.py`` comprueban los invariantes de la salida.

Por qué no se reutiliza ``data/aula/palabras_bloqueadas.json``
--------------------------------------------------------------
Parecen la misma lista y no lo son: aquella bloquea apodos y esta filtra un corpus.
Fusionarlas degradaría las dos:

- Comparan distinto. La del aula busca subcadenas de cuatro letras o más en el apodo
  sin espacios (``model/aula/apodos.py``); aplicada a oraciones descartaría
  «computadora» por contener «puta». Esta busca palabras completas con patrones que
  cubren conjugaciones («coger» tiene una docena de formas), y una lista de palabras
  sueltas no puede expresarlas.
- Vetan cosas distintas. En un apodo, «idiota» o «perra» son un ataque a un compañero;
  en «La perra tuvo cachorros» o «Hasta los idiotas te pueden dar buenos consejos» son
  español cotidiano. Al revés, esta veta temas («matar», «drogas») que en un apodo no
  son el problema.
- Una se edita y la otra no. El docente amplía la del aula desde la interfaz; si este
  script la leyera, el mismo comando daría otro dataset según quién hubiera editado
  qué, y un dataset citado en la tesis tiene que poder regenerarse idéntico.
"""
import json
import random
import re
import statistics
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ))
from model.motor_llm.tokenizer import Tokenizer  # noqa: E402

TAMANO = 4000
SEMILLA = 20261022
# Tatoeba nombra a «Tom» en uno de cada ocho pares; sin cuota, el modelo aprende
# más sobre Tom que sobre el español.
CUOTA_TOM = round(TAMANO * 0.025)
TOM_EN = re.compile(r"\bTom\b")
TOM_ES = re.compile(r"\bTom(ás)?\b")

LISTA_NEGRA = Path(__file__).with_name("palabras_vetadas_corpus.txt")


def cargar_vetadas(ruta: Path) -> re.Pattern:
    """Une los patrones del archivo en una sola expresión de palabra completa."""
    patrones = []
    for linea in ruta.read_text(encoding="utf8").splitlines():
        patron = linea.split("#", 1)[0].strip()
        if patron:
            patrones.append(patron)
    return re.compile(r"\b(" + "|".join(patrones) + r")\b", re.IGNORECASE)


VETADAS = cargar_vetadas(LISTA_NEGRA)

# Revisión manual: lo que la lista negra no atrapa (violencia, temas delicados) y
# traducciones erróneas. Frases en español, tal como vienen en el volcado.
EXCLUIDOS_A_MANO = {
    "María le está pegando a su hija.",
    "Esta es la primera vez que le he pegado a mi perro.",
    "Tuve un aborto hace dos años.",
    "Eres demasiado estúpido para vivir.",
    "Solía maltratar a Tom en la escuela secundaria.",
    "Los terroristas hicieron estallar un bus.",
    "Los genocidios son crímenes de odio.",
    "Las paredes están cubiertas de sangre.",
    "El hombre fue encontrado muerto en su dormitorio en la mañana.",
    "No quiero gritarte, pero lo haré de ser necesario.",
    "Este pobre hombre no tenía ni un amigo.",
    "Nosotros disparamos a un ciervo.",
    "La crueldad es el primer atributo de Dios.",
    "¡Él sí le disparó!",
    "Acabo de disparar a alguien, creo.",
    "Tom recibió un disparo en la cabeza de un francotirador.",
    "Has transgredido mi territorio, ahora debo dispararte.",
    "No estoy ahorcando a tus gatos.",
    "Odia su vida.",
    "Su crimen merecía la pena de muerte.",
    "Él fue condenado a muerte.",
    "El ladrón la atacó en un callejón.",
    "Dios no existe.",
    "Mary se odiaba.",
    "Tomás parece estar muerto.",
    "Estaba completamente borracho.",
    "Está de toma pan y moja.",
    "Ella lo apuñaló con un cuchillo.",
    "¿Es cierto que le pegaste a Taninna?",
    "Tú eres responsable por la muerte del niño.",
    "¿Cómo podría alguien dispararse en la espalda?",
    "Ella oía disparos cada noche.",
    "Estoy sediento de sangre.",
    "¿Tu arma está cargada?",
    "Juro que te dispararé.",
    "Es una pavada.",
    "¿Van ellos a darme una paliza?",
    "Planeó el ataque con cuidado.",
}


def principal(ruta_en: Path, ruta_es: Path, salida: Path) -> dict:
    tok = Tokenizer(tipo_encoding=1)
    assert tok.encoding.name == "cl100k_base"

    en = ruta_en.read_text(encoding="utf8").splitlines()
    es = ruta_es.read_text(encoding="utf8").splitlines()
    assert len(en) == len(es)
    pares = [(a.strip(), b.strip()) for a, b in zip(es, en)]
    recuento = {"total_bruto": len(pares)}

    def aplicar(nombre, conservar):
        nonlocal pares
        antes = len(pares)
        pares = [p for p in pares if conservar(p)]
        recuento[nombre] = antes - len(pares)

    aplicar("vacios", lambda p: p[0] and p[1])
    aplicar("origen_igual_destino", lambda p: p[0].casefold() != p[1].casefold())
    aplicar("contenido_inapropiado", lambda p: not (VETADAS.search(p[0]) or VETADAS.search(p[1])))

    longitud = {}
    for a, b in pares:
        for t in (a, b):
            if t not in longitud:
                longitud[t] = len(tok.encode(t))

    aplicar("longitud_fuera_3_16", lambda p: 3 <= longitud[p[0]] <= 16 and 3 <= longitud[p[1]] <= 16)
    aplicar("razon_fuera_0.5_2.0", lambda p: 0.5 <= longitud[p[0]] / longitud[p[1]] <= 2.0)

    vistos: set = set()

    def primera_vez(clave):
        if clave in vistos:
            return False
        vistos.add(clave)
        return True

    aplicar("duplicados_exactos", lambda p: primera_vez(("par", p)))
    # Una traducción por frase, en los dos sentidos: los dos archivos son los mismos
    # pares invertidos, así que el origen de uno es el destino del otro. Se conserva
    # la primera aparición en el orden del volcado.
    aplicar("traduccion_repetida_es", lambda p: primera_vez(("es", p[0])))
    aplicar("traduccion_repetida_en", lambda p: primera_vez(("en", p[1])))
    recuento["pasan_filtros"] = len(pares)

    # Cuota de Tom, antes del muestreo: de los pares que lo nombran solo quedan
    # elegibles CUOTA_TOM, y la muestra los toma todos.
    azar = random.Random(SEMILLA)
    con_tom = [p for p in pares if TOM_ES.search(p[0]) or TOM_EN.search(p[1])]
    sin_tom = [p for p in pares if not (TOM_ES.search(p[0]) or TOM_EN.search(p[1]))]
    recuento["pares_con_tom"] = len(con_tom)
    azar.shuffle(con_tom)
    azar.shuffle(sin_tom)
    # La revisión manual se aplica después de barajar: excluir una frase solo
    # cambia la que entra en su lugar, no el resto de la muestra ya revisada.
    antes = len(con_tom) + len(sin_tom)
    con_tom = [p for p in con_tom if p[0] not in EXCLUIDOS_A_MANO]
    sin_tom = [p for p in sin_tom if p[0] not in EXCLUIDOS_A_MANO]
    recuento["revision_manual"] = antes - len(con_tom) - len(sin_tom)
    recuento["tom_fuera_de_cuota"] = len(con_tom) - CUOTA_TOM
    pares = con_tom[:CUOTA_TOM] + sin_tom[: TAMANO - CUOTA_TOM]
    azar.shuffle(pares)
    recuento["muestra_final"] = len(pares)
    recuento["muestra_con_tom"] = sum(
        1 for a, b in pares if TOM_ES.search(a) or TOM_EN.search(b)
    )

    salida.mkdir(parents=True, exist_ok=True)
    for nombre, invertir in (
        ("traduccion_es_en_basica.jsonl", False),
        ("traduccion_en_es_basica.jsonl", True),
    ):
        with (salida / nombre).open("w", encoding="utf8", newline="\n") as archivo:
            for a, b in pares:
                origen, destino = (b, a) if invertir else (a, b)
                registro = {"instruction": origen, "response": destino, "category": "traduccion"}
                archivo.write(json.dumps(registro, ensure_ascii=False) + "\n")

    def resumen(valores):
        return {"min": min(valores), "mediana": statistics.median(valores), "max": max(valores)}

    recuento["tokens_es"] = resumen([longitud[a] for a, _ in pares])
    recuento["tokens_en"] = resumen([longitud[b] for _, b in pares])
    return recuento


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    print(json.dumps(principal(*(Path(a) for a in sys.argv[1:4])), ensure_ascii=False, indent=2))
