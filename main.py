"""
Punto de entrada de la aplicación.

Responsabilidades:
- Instanciar QApplication.
- Instanciar `MainViewModel` (el orquestador raíz) y registrarlo en el
  contexto de QML — es el ÚNICO objeto que se expone directamente; todo
  lo demás (setupController, trainingController, inferenceController)
  se accede en QML como propiedades de `mainViewModel`
  (`mainViewModel.setupController`, etc.), no como context properties
  sueltas. Esto evita tener que registrar/actualizar una lista de
  objetos a mano cada vez que se agrega un controlador nuevo — alcanza
  con que `MainViewModel` lo exponga como `@Property`.
- Registrar `VispyItem` como tipo QML (`import Vispy 1.0`).
- Cargar view/qml/main.qml mediante QQmlApplicationEngine.
- Arrancar el loop de eventos de Qt.
"""

import os
import sys

# Debe fijarse ANTES de crear la QApplication/QQmlApplicationEngine,
# porque Qt Quick decide el backend de renderizado al arrancar.
os.environ["QSG_RHI_BACKEND"] = "opengl"

from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterType
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtWidgets import QApplication

from view.canvas.animation_engine import VispyItem
from viewmodel.main_viewmodel import MainViewModel


def main() -> None:
    QQuickStyle.setStyle("Basic")

    app = QApplication(sys.argv)

    # `main_view_model` se queda vivo mientras dure `app.exec()` porque
    # el contexto de QML mantiene una referencia a él (setContextProperty).
    main_view_model = MainViewModel()
    app.aboutToQuit.connect(main_view_model.cerrar)

    qmlRegisterType(VispyItem, "Vispy", 1, 0, "VispyItem")

    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("mainViewModel", main_view_model)

    engine.load("view/qml/main.qml")

    if not engine.rootObjects():
        sys.exit(-1)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
