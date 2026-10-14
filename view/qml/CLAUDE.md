# view/qml/ — al trabajar aquí

Se carga solo al trabajar en `view/qml/`. Las reglas generales están en el `CLAUDE.md` raíz.

- Convenciones de QML (`ComponentBehavior: Bound`, escalado `sx`/`sy`, tema, `objectName`,
  movimiento reducido, animación como función del progreso, guarda para pruebas):
  `docs/architecture.md` → *Convenciones obligatorias de la Vista*.
- Trampas que no producen error: `docs/trampas.md`.
- Si tocas un reactivo o una pantalla de evaluación: `docs/medicion.md`.
- Antes de dar por terminado un cambio en QML, pásale `pyside6-qmllint` a cada archivo tocado, y
  si pruebas la app a mano, desactiva la caché de QML. Comandos en `docs/architecture.md` →
  *Revisar QML sin ejecutar la app*.
