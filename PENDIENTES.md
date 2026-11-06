# Trabajo pendiente verificado

Este archivo registra tareas vigentes; las listas históricas ya resueltas se retiraron para no contradecir el estado actual del repositorio.

## Evaluación e instrumentos

- Someter la tabla de especificaciones y los bancos de los ocho módulos a juicio de expertos.
- Estimar confiabilidad, dificultad, discriminación y equivalencia empírica de las formas pre/post con una muestra independiente.
- Definir el tamaño de una réplica mediante potencia estadística, efecto mínimo de interés y pérdida esperada; preregistrar el resultado principal y el plan de análisis.
- Mantener una sola versión del instrumento por aplicación, registrar datos faltantes y, si es viable, incorporar un grupo de comparación con asignación aleatoria.
- Usar una versión española de SUS con evidencia de traducción apropiada y volver a medir después de los cambios de interfaz.

## Privacidad y uso en aula

- Formalizar el aviso de privacidad institucional: responsable, finalidad, datos, transferencias, conservación, acceso, disociación y eliminación.
- Probar el aula conectada entre equipos reales en las redes donde se desplegará, además de la prueba local y de carga automatizada.
- Documentar que el almacenamiento local y TLS reducen exposición, pero no vuelven anónimos la matrícula, el apodo ni los resultados.

## Validación técnica

- Contrastar las transformaciones visuales de los paneles (escalas, recortes, redondeos) contra los valores del forward. Los cálculos ya se contrastan con la referencia NumPy de `pruebas/auditoria/` (`tests/model/test_referencia_numpy.py`).
- Añadir un modo de comparación controlada: mismo punto de control, semilla o generación codiciosa, una variable por vez y repeticiones.
- Repetir `pruebas/auditoria/medir_rendimiento.py` en un equipo de laboratorio escolar (hardware mínimo declarado) y medir también la pantalla de entrenamiento. La auditoría del 5 de noviembre de 2026 solo midió una portátil con RTX 3050 Ti de 4 GB.
- Separar datos de validación de los datos de entrenamiento para las métricas por época.
- Probar teclado, foco, contraste, lectores de pantalla y movimiento reducido con herramientas y usuarios.
- Firmar el ejecutable y, si se requiere autenticidad de modelos, usar firmas digitales; SHA-256 por sí solo detecta discrepancias, no acredita al autor.

## Documentación y distribución

- Construir el ejecutable desde un commit que incluya las correcciones del laboratorio del 5 de noviembre de 2026 (ventana de trazas y cálculo en hilo), correr la suite sobre ese commit y guardar el manifiesto de `python -m pruebas.auditoria.huella_ejecutable`.

- Mantener sincronizados README, manual, capturas, arquitectura, medición y versión del ejecutable.
- Retirar dependencias y rutas heredadas de VisPy que ya no usa la interfaz final.
- Preparar y verificar distribuciones para sistemas distintos de Windows.
