# Arquitectura del Sistema (MVVM)

Este documento resume el mapeo entre el diseño arquitectónico (TT1,
sección 4.9) y la estructura de carpetas del código.

## Model (`model/`)
- `motor_llm/`: Motor LLM (Transformer, atención, tokenización, sampling).
- `gestor_de_datos/`: carga y preparación de datasets/tensores.
- `simulacion_numerica/`: adaptación de tensores a arreglos/grafos numéricos.
- `evaluacion/`: banco de preguntas, evaluaciones, resultados históricos, métricas.
- `persistencia/`: guardado/carga de checkpoints de modelos entrenados.

## ViewModel (`viewmodel/`)
- `main_viewmodel.py`: orquestador raíz expuesto a QML.
- `manager_de_siniales.py`: señales/propiedades observables.
- `manager_de_concurrencia.py`: hilos secundarios (QThread/QRunnable).
- `adaptador_visual.py`: adaptación final de datos para VisPy.
- `controlador_de_inferencia.py`, `controlador_de_evaluacion.py`, `controlador_de_teoria.py`:
  controladores de flujo por área funcional.

## View (`view/`)
- `qml/`: interfaz declarativa (pantallas, componentes, tema).
- `canvas/`: Lienzo Científico VisPy/OpenGL embebido en QML.

## Core (`core/`)
Utilidades transversales: configuración (incluye detección CPU/CUDA),
logging, constantes.

## Flujo de datos (resumen)
Vista -> ViewModel -> Modelo -> ViewModel (adapta) -> Vista (re-render)
