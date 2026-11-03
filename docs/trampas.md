# Trampas frecuentes de Python, PySide6 y QML

## Propiedades y señales

- Toda propiedad que pueda cambiar desde Python necesita una señal `notify`; emitir otra señal no actualiza el binding de QML.
- Registrar objetos de contexto antes de cargar el QML. Un binding evaluado antes de que exista el objeto puede quedar indefinido o producir avisos silenciosos.
- No crear dos fuentes de verdad entre QML y el ViewModel. QML muestra estado; el controlador valida y decide.

## Vida de objetos e hilos

- Conservar una referencia Python a controladores, hilos, trabajadores y ventanas. El recolector puede destruir objetos que QML todavía usa.
- Crear y modificar objetos visuales solo en el hilo principal. Las tareas largas comunican resultados mediante señales.
- Al cancelar, ignorar resultados obsoletos mediante el identificador de ejecución y destruir hilo y trabajador cuando terminen.

## Tipos y datos

- Convertir tensores a CPU, separar el grafo y resumirlos antes de enviarlos a QML; no cruzar tensores completos ni objetos con gradiente.
- Declarar tipos de señales y slots compatibles con las conversiones de Qt. Distinguir `None`, objeto vacío y lista vacía.
- Las rutas recibidas desde `FileDialog` pueden ser URL; normalizarlas antes de abrir archivos y probar espacios y caracteres no ASCII.

## Persistencia y pruebas

- Usar una organización y aplicación de `QSettings` separadas en pruebas para no modificar el progreso real.
- Mantener `objectName` estable en controles cubiertos por pruebas; el texto visible puede cambiar sin romper su localización.
- Tratar advertencias QML como defectos: propiedades inexistentes, anchors en conflicto y bindings recursivos suelen no detener la aplicación.
- Ejecutar la suite con un `--basetemp` escribible en Windows. Restaurar constantes globales modificadas por una prueba.

## Recursos y empaquetado

- Resolver recursos con la utilidad central del proyecto, no con el directorio de trabajo actual.
- Verificar en el ejecutable las importaciones QML, plugins de plataforma, certificados, datasets, fuentes e imágenes; que funcione desde código fuente no garantiza que PyInstaller los incluya.
