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
    raise NotImplementedError("Pendiente: bootstrap de la aplicación (Fase I, Sprint 1)")


if __name__ == "__main__":
    main()
