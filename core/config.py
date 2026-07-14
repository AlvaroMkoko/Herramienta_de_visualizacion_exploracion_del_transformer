"""
Configuración global de la aplicación.

TODO:
- Detección de dispositivo de cómputo (CPU/CUDA) de forma dinámica,
  para soportar transparentemente distintas GPUs de desarrollo
  (ej. RTX 5070 Ti de escritorio, RTX 3050 de laptop):

    import torch
    DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

- Rutas base (datasets, checkpoints, logs).
"""
