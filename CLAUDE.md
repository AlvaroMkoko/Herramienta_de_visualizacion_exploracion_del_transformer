# Herramienta de Visualización y Exploración del Transformer

Este archivo contiene solo las reglas de trabajo del agente. Lo que es conocimiento del proyecto
—capas, rutas, convenciones, pruebas, trampas, invariantes de medición— vive en `docs/` y aquí
solo se enlaza. Si un hecho está en los dos lados, uno sobra: el dueño es `docs/`.

---

## Antes de escribir código

Lectura obligatoria, en este orden:

| Documento | Qué contiene |
|---|---|
| `docs/architecture.md` | **La fuente autoritativa.** Panorama, capas y dependencias, rutas y datos, el curso modular, las convenciones de cada capa, idioma de los identificadores, cómo correr las pruebas, archivos vacíos y `.gitignore`. |
| `docs/medicion.md` | Invariantes de medición del pre-test y el post-test. **Obligatorio** si el cambio toca evaluación, reactivos o resultados. |
| `docs/trampas.md` | Trampas de PySide6 y QML que no producen error. Repásalo antes de tocar QML o el puente Python↔QML. |
| `docs/red_aula.md` | Protocolo y transporte del aula conectada. Solo si tocas `aula`. |
| `docs/estandar_red.md` | **Obligatorio** si el cambio toca `aula`, `ResultsRepository`, la forma de un resultado o del avance, los puertos o el empaquetado: invariantes de red, presupuesto de rendimiento del docente y la prueba de carga de 40 alumnos que debe pasar. |
| `docs/mejoras_pedagogicas.md` | Antes de tocar el recorrido guiado, los retos del laboratorio, los reactivos del banco modular o la exportación de resultados: qué se cambió en el módulo 3 tras la prueba piloto, formato de las lecciones y cómo llevarlo a los otros módulos. |
| `docs/uso_aula.md` | Guía de uso del aula. Solo si tocas `aula`. |
| `README.md` | Flujo funcional, perfiles estudiante/profesor y el contrato de datasets. |

Convenciones al trabajar dentro de una capa: `viewmodel/CLAUDE.md`, `view/qml/CLAUDE.md` y
`tests/CLAUDE.md` (patrones de prueba y cobertura) se cargan al trabajar ahí.

---

## Reglas de trabajo

**Sin git.** No hagas `commit`, `push`, `checkout`, `branch`, `merge`, `reset` ni `stash`. Deja los
cambios en el árbol de trabajo; el control de versiones lo hace el equipo a mano.

**Los datos no se tocan.** Nunca borres ni reescribas `data/resultados/` ni `data/progreso/` para
«limpiar estado». Por qué: `docs/architecture.md` → *Panorama* y *Rutas y datos*.

**Línea base de pruebas.** Al empezar la sesión, antes de tocar nada, corre la suite completa y
anota cuántas pasan; al terminar, comprueba que el conteo en verde no bajó. La regla es la
comparación, no una cifra. Si ya al empezar hay fallos, el problema es del entorno, no tuyo:
dilo antes de cambiar nada. Cómo correrla: `docs/architecture.md` → *Pruebas*.

**Verifica, no supongas.**

- Antes de afirmar algo sobre el código, **abre el archivo**. No cites una prueba ni la
  documentación como evidencia de lo que hace el código: en este proyecto ya han estado
  desactualizadas.
- Antes de decir que terminaste, **corre las pruebas**.
- Si tocas QML, pásale `pyside6-qmllint` (comando y motivo en `docs/architecture.md` →
  *Revisar QML sin ejecutar la app*).
- Si un cambio es de interfaz y toca un reactivo, di explícitamente qué invariante de
  `docs/medicion.md` revisaste.

**Cuando algo falle, di qué falla y por qué.** Si la causa es ambiental (sin GPU, sin red, sin
display), dilo en vez de dar la prueba por buena. Si una prueba es intermitente, repórtala como
intermitente en lugar de volver a correrla hasta que pase.

**Cambios quirúrgicos.** Este repositorio tiene archivos de 2 000 a 4 000 líneas
(`FormulaAnimationScene.qml` tiene 3 965). No reescribas un archivo completo para cambiar una
sección; edita lo que toca. No reformatees de paso.

**Imita el código vecino.** Idioma de los identificadores y comentarios del por qué:
`docs/architecture.md` → *Convenciones de código*.

**Archivos que `git status` no muestra.** Si creas un `.json` de datos o un documento en `docs/`,
dilo explícitamente para que se agregue la excepción (`docs/architecture.md` → *Control de
versiones*).

---

## Lo que hay en `.claude/`

Agentes, comandos y el hook `verificar_cambio.py` se ven con `ls .claude`. Lo que no se ve:
las reglas `deny` de `settings.json` son una **barandilla contra el accidente, no una
frontera de seguridad** — no alcanzan a un programa invocado por ruta absoluta ni dentro
de otro intérprete. Lo que de verdad manda es la regla de arriba: **sin git**.
