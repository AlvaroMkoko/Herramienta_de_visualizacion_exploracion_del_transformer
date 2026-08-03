import sys

from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
import os
os.environ["QSG_RHI_BACKEND"] = "opengl"

import sys
from PySide6.QtWidgets import QApplication

#Se importan las clases que se van a linkear a Qt Quick

# Modulos de View Model para la gestion de Datos
# from viewmodel.main_viewmodel import MainViewModel
from viewmodel.setup_controller import SetupController
# from viewmodel.training_controller import TrainingController
# from viewmodel.inference_controller import InferenceController
# from viewmodel.evaluation_controller import EvaluationController
# from viewmodel.theory_controller import TheoryController
# from viewmodel.signal_manager import SignalManager
# from viewmodel.concurrency_manager import ConcurrencyManager
# from viewmodel.visual_adapter import VisualAdapter


from PySide6.QtQml import qmlRegisterType
from view.canvas.animation_engine import VispyItem

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

#   mainViewModel = MainViewModel()
#   #controladores
  setupController = SetupController()
#   trainingController = TrainingController()
#   inferenceController = InferenceController()
#   evaluationController = EvaluationController()
#   theoryController = TheoryController()
#   signalManager = SignalManager()
#   concurrencyManager = ConcurrencyManager()
#   visualAdapter = VisualAdapter()
#   visualAnimation = SetupControllerr()

  qmlRegisterType(
          VispyItem,
          "Vispy",
          1,
          0,
          "VispyItem"
    )

  engine = QQmlApplicationEngine()
#   engine.rootContext().setContextProperty(
#     "/viewmodel/mainViewModel",
#     mainViewModel
# )

  engine.rootContext().setContextProperty(
      "setupController",
      setupController
  )

#   engine.rootContext().setContextProperty(
#       "/viewmodel/trainingController",
#       trainingController
#   )

#   engine.rootContext().setContextProperty(
#       "/viewmodel/inferenceController",
#       inferenceController
#   )

#   engine.rootContext().setContextProperty(
#       "/viewmodel/evaluationController",
#       evaluationController
#   )

#   engine.rootContext().setContextProperty(
#       "/viewmodel/theoryController",
#       theoryController
#   )

#   engine.rootContext().setContextProperty(
#       "/viewmodel/signalManager",
#       signalManager
#   )

#   engine.rootContext().setContextProperty(
#       "/viewmodel/concurrencyManager",
#       concurrencyManager
#   )

#   engine.rootContext().setContextProperty(
#       "/viewmodel/visualAdapter",
#       visualAdapter
#   )
  # engine.rootContext().setContextProperty(
  #     "SetupControllerr",
  #     visualAnimation
  # )

  
  engine.load("view/qml/main.qml")
  

  if not engine.rootObjects():
      sys.exit(-1)

  sys.exit(app.exec())


if __name__ == "__main__":
    main()
