import sys

from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle


"""
Punto de entrada de la aplicación.

Responsabilidades:
- Instanciar QGuiApplication.
- Registrar el/los ViewModel(s) en el contexto de QML (setContextProperty
  o qmlRegisterType, según el patrón que se elija).
- Cargar view/qml/main.qml mediante QQmlApplicationEngine.
- Arrancar el loop de eventos de Qt.

TODO (Fase I - Sprint 1):
- Configurar QQmlApplicationEngine.
- Exponer MainViewModel al QML root context.
"""

def main():
  "Archivo principal para correr la pagina principal de QML"

  QQuickStyle.setStyle("Basic")   # o "Basic" o "Material"

  app = QApplication(sys.argv)

  engine = QQmlApplicationEngine()
  engine.load("view/qml/main.qml")

  if not engine.rootObjects():
      sys.exit(-1)

  sys.exit(app.exec())


if __name__ == "__main__":
    main()
