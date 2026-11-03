# Medición y evaluación

Esta guía separa las reglas que el software puede verificar de la validez que debe establecer un estudio con participantes.

## Invariantes implementados

- Cada resultado conserva tipo de instrumento, módulo, versión, momento, reactivos, respuestas, puntaje y tiempo.
- Solo se forma un par pre/post cuando pertenece al mismo estudiante, módulo y versión.
- El pre-test no revela claves ni explicaciones antes del post-test.
- Cada intento modular selecciona 15 de 25 reactivos, cinco por nivel declarado, y registra la selección.
- El aula transmite únicamente resultados modulares del perfil estudiante; el instrumento global se recopila por separado.
- El análisis debe reportar cuántos registros fueron excluidos, cuántos pares quedaron completos y por qué faltan datos cuando esa información exista.

## Qué verifican las pruebas

Las pruebas comprueban estructura, cobertura declarada, selección, calificación, persistencia, control de versiones y ausencia de respuestas en el payload público. No establecen validez de contenido, confiabilidad, dificultad, discriminación ni equivalencia psicométrica de formas.

Los cortes de 70 % para recomendar refuerzo y 80 % para señalar dominio son heurísticas de retroalimentación. No deben describirse como umbrales validados.

## Protocolo recomendado

1. Congelar y documentar una sola versión antes de reclutar.
2. Obtener revisión experta de la tabla de especificaciones y de los ocho módulos.
3. Definir resultado principal, efecto mínimo, alfa, potencia, pérdida esperada y tamaño de muestra; preregistrar el análisis.
4. Aplicar instrucciones y tiempos estandarizados. Si es viable, usar grupo de comparación y asignación aleatoria.
5. Registrar ayuda, exposición previa, motivación, tiempo efectivo y motivos de abandono.
6. Analizar pares completos e informar el posible sesgo por faltantes. Tratar correlaciones, subgrupos y conceptos como exploratorios si no se preregistraron.
7. Estimar confiabilidad, dificultad, discriminación y equivalencia de formas con una muestra independiente.

## Privacidad

Matrícula, apodo, identificador de dispositivo y resultados pueden ser datos personales o vinculables. El almacenamiento local y TLS reducen exposición, pero no producen anonimato. Antes de una nueva aplicación se debe formalizar el aviso institucional, finalidad, responsable, acceso, conservación, disociación, eliminación y atención de derechos.
