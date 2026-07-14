"""
Gestor de Señales — Orquestación y Señales (Signals & Slots).

Expone atributos observables hacia QML mediante @Property de PySide6.
Cuando el Modelo actualiza su estado/progreso, este componente emite
las señales correspondientes para que la Vista reaccione vía data binding.

TODO:
- Definir señales base reutilizables (ej. progressChanged, stateChanged).
"""
