"""
Orquesta la interacción del usuario con el Motor LLM (Modelo).

Flujo típico (ej. CU de ajuste de Temperatura):
1. La Vista notifica el cambio de parámetro.
2. Este controlador delega el recálculo al Modelo (en background,
   vía concurrency_manager).
3. Al recibir el resultado, adapta los datos (visual_adapter) y
   notifica a la Vista mediante señales (signal_manager).

TODO:
- on_parameter_changed(param_name, value)
- run_inference(prompt)
"""
