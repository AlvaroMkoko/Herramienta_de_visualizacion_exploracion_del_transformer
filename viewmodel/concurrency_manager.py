"""
Gestor de Concurrencia.

Despacha la ejecución de algoritmos pesados (inferencia, entrenamiento)
en hilos secundarios (QThread / QRunnable) para evitar que el GIL de
Python bloquee la interfaz gráfica.

TODO:
- Worker(QRunnable) genérico para tareas del Modelo.
- run_in_background(fn, *args, on_result=..., on_error=...)
"""
