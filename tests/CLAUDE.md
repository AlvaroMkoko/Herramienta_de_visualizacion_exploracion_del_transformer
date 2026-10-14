# Pruebas — patrones y cobertura

Complementa *Pruebas* de `docs/architecture.md` (variables de entorno, `python -m pytest`) y la
regla de línea base del `CLAUDE.md` raíz (medirla al empezar y comprobar que no baje). Se carga solo al trabajar en `tests/`.

## Patrones de prueba a imitar

`tests/conftest.py` no define fixtures: las del proyecto son locales a su archivo y **no hay
nada compartido** salvo `qapp` y `qtbot` de pytest-qt. Para reutilizar un patrón, cópialo del
archivo vecino. Lo que sí hace el conftest, antes de que se importe código del proyecto:

- Fija las tres variables de Qt (con `setdefault`) para cualquier invocación.
- **Redirige las escrituras a un temporal**: `DIR_DATOS` y los `DIR_*` de `core.rutas`. Ninguna
  prueba escribe en `data/` real, y no hace falta pedirlo.
- Manda los `QSettings("org", "app")` de nombre fijo a un INI dentro de ese temporal, para que
  ninguna prueba lea el registro de quien corre la suite.
- Detiene la corrida si `core.rutas` ya estaba importado o si algún `DIR_*` sigue apuntando a
  `data/`. Las guardas tienen prueba en `tests/test_aislamiento_de_pruebas.py`.

Lo que **no** hace: aislar una prueba de otra. El temporal es uno solo por corrida, y lo que una
prueba escribe lo ve la siguiente (el porqué está comentado en el conftest). Una prueba que
necesite empezar sin datos sigue inyectando su propia ruta en `tmp_path`.

- **Montar QML en una prueba**: se define un host mínimo como `bytes` con una `ApplicationWindow`
  que embebe la pantalla, y se carga con `QQmlComponent.setData` usando una URL **ficticia pero
  dentro de `view/qml/`**, para que resuelvan los imports relativos. Referencia canónica:
  la fixture `setup_qml` en `tests/view/test_smoke.py:104`. Obligatorio: el helper `_errores(component)`
  en el mensaje de aserción (sin él los errores de QML son invisibles),
  `setContextProperty("mainViewModel", ...)`, y el cierre con `deleteLater()` + `processEvents()`.
- **Inspeccionar el árbol QML**: `objectName` + `findChild`, 282 usos. Es el único mecanismo.
  Para invocar métodos QML, `QMetaObject.invokeMethod(..., Q_ARG("QVariant", arg))`, y normaliza
  el retorno con `.toVariant()` porque llega como `QJSValue`.
- **Señales**: solo API de pytest-qt, nunca `QSignalSpy`. `qtbot.waitSignal` (92 usos) para
  esperar una señal, `qtbot.waitUntil` (73) para esperar una condición sobre una propiedad.
  Preferir `waitUntil` sobre un valor observable antes que `waitSignal`: una señal en cola puede
  llegar antes de que el valor esté visible en el hilo principal. `qtbot.wait` ciego es el último
  recurso.
- **Aislar `QSettings`**: nunca el constructor sin argumentos. Siempre un INI en `tmp_path`
  inyectado por parámetro `settings=`, y se **parchean las clases dentro de
  `viewmodel.main_viewmodel`** por fábricas, porque `MainViewModel` las instancia internamente.
  Referencia: fixture `home` en `tests/view/test_home_navigation_guards.py:93`. Hay que aislar
  **los tres** controladores que leen settings (`Learning`, `Evaluation`, `Progress`): aislar uno
  solo deja que los otros lean los datos reales de quien corre la prueba.
- **Aislar el sistema de archivos**: `monkeypatch.setattr` de la constante de ruta a `tmp_path`
  (`DatasetController.DATASET_FILE`, `DIR_CHECKPOINTS`, …).
- **Dobles locales, no `unittest.mock`**, para evitar red y descargas: `TokenizerFalso`,
  `TokenizerDePrueba`. Los modelos de prueba son diminutos a propósito
  (`dimension_modelo=32, num_capas=1`).

**Ruido que no es fallo**: la salida se llena de `TypeError: Cannot read property 'X' of null` de
pantallas QML montadas sin su contexto completo. Las aserciones pasan. No lo confundas con un error.

## Cobertura

No está configurada (`pytest-cov` no está declarado). El `.coverage` de la raíz es un artefacto
obsoleto de una corrida puntual en Windows con solo 3 archivos: **no sirve y debería ignorarse**.

```powershell
pip install pytest-cov
python -m pytest -q --cov=core --cov=model --cov=viewmodel --cov-report=term
```

Línea base: **79 %** en total — `core/` 65 %, `model/` 84 %, `viewmodel/` 77 %. Se excluye `view/`
porque la cobertura de línea no mide QML. Los huecos mayores son
`viewmodel/visual_adapter.py` (57 % de 543 sentencias) y `viewmodel/model_library_controller.py`
(61 % de 839).
