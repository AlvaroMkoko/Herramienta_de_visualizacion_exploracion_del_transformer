# Aula conectada: funcionamiento de la red

Este documento explica cómo se comunican la app del docente y la de los
alumnos. Está pensado para quien mantenga o extienda el código. La guía de
uso para docentes y alumnos está en [uso_aula.md](uso_aula.md).

## 1. Idea general

El docente crea una clase y obtiene un **código de 6 caracteres**
(`K7P-4QX`). Mientras la clase está abierta, **la app del docente funciona
como servidor**, igual que el anfitrión de una partida en red. Los alumnos
escriben el código y un **apodo**, y desde ese momento su avance se envía
solo al docente.

El alumno nunca depende de la red. Todo se guarda primero en su equipo, como
antes, y la red solo **replica** lo que falte cuando hay conexión.

Hay tres formas de llevar los datos, y las tres comparten protocolo y formato:

| Opción | Red | Qué cambia en el código |
|---|---|---|
| **A**. El docente es host en la LAN de la escuela | Wi-Fi o cable de la escuela | Nada: es el caso base |
| **B**. Hotspot o router del docente | Red propia del docente | Nada: es la opción A sobre otra red. El servidor escucha en todas las interfaces y responde por la interfaz de origen |
| **D**. Archivo `.tvclase` | Sin red | Mismo snapshot y resultados, guardados en disco y firmados con HMAC |

La opción C (servidor en la nube) no está implementada. La arquitectura la
deja preparada (ver la sección 12).

## 2. Capas

```
model/aula/                      (sin Qt, probado sin red)
  codigo_clase.py     generar, normalizar y huella del código
  apodos.py           validar apodo, unicidad y sugerencias ("Ana" → "Ana2")
  protocolo.py        mensajes JSON versionados, puertos y límites
  sesion_clase.py     reglas de la clase: unirse, reconectar, aprobar, expulsar,
                      recibir progreso y resultados, importar archivos
  repositorio_clase.py persistencia del docente (una carpeta por clase)
  estado_alumno.py    lo que recuerda el equipo del alumno (mi_clase.json)
  archivo_clase.py    archivos .tvclase y su firma
  analisis.py         estados por módulo, análisis del grupo y CSV

viewmodel/aula/                  (Qt, sin lógica de negocio)
  red.py              interfaces de red y destinos de broadcast
  servidor_lan.py     QWebSocketServer + QUdpSocket → SesionClase
  cliente_lan.py      búsqueda UDP + QWebSocket
  classroom_host_controller.py     API para QML del docente
  classroom_student_controller.py  API para QML del alumno
```

`SesionClase` **no conoce sockets**. El transporte solo hace tres cosas:

1. Avisar `conectar(id, ip)` y `desconectar(id)`.
2. Entregar el texto recibido con `procesar(id, texto)`.
3. Enviar los `Envio(destino, mensaje, cerrar)` que la sesión devuelve.

Por eso la misma sesión puede ejecutarse dentro de la app (hoy) o en un
servidor asyncio (opción C) sin cambios.

Todo el transporte corre en el **event loop de Qt**, sin hilos: los sockets
de QtNetwork y QtWebSockets son asíncronos y avisan con señales, igual que el
resto del ViewModel. No se agregaron dependencias, porque `PySide6` ya
incluye QtNetwork y QtWebSockets.

## 3. Puertos

| Puerto | Protocolo | Uso |
|---|---|---|
| 47800 | UDP | Descubrimiento por broadcast |
| 47801–47810 | TCP (WebSocket) | Datos de la clase. Si 47801 está ocupado, el docente prueba los siguientes y anuncia el elegido |

Las constantes están en `model/aula/protocolo.py`.

## 4. Descubrimiento: cómo el código se convierte en una dirección

```
Alumno                                          Docente
  │  UDP broadcast → :47800                       │
  │  {"v":1,"tipo":"buscar","huella":"3fa2…"}  ─▶ │  ¿huella == sha256("tvaula:"+código)[:16]?
  │                                               │  sí → responde a la IP/puerto de origen
  │ ◀─ {"v":1,"tipo":"aqui","huella":"3fa2…",     │
  │      "puerto":47801,"nombre":"IA 6CV1"}       │
  │  la IP del docente es la de origen del datagrama
```

- El código **no viaja en claro**: viaja su huella SHA-256 truncada.
  Cualquiera en la red escucha el broadcast, pero con la huella solo puede
  confirmar un código que ya conoce.
- El alumno envía la búsqueda a `255.255.255.255`, al broadcast dirigido de
  **cada** interfaz y a `127.0.0.1`. En Windows, `255.255.255.255` sale solo
  por la interfaz principal. El loopback permite probar docente y alumno en
  el mismo equipo.
- El docente responde a la **dirección de origen** del datagrama, y el sistema
  operativo elige la interfaz correcta. Así funciona aunque el docente esté a
  la vez en el Wi-Fi de la escuela y en su hotspot (opción B).
- La búsqueda se repite 3 veces con 0.9 s de espera. Si nadie responde, la
  interfaz ofrece **Conectar por dirección** (la `IP:puerto` que muestra la
  pantalla del docente). Ese camino no usa UDP.

## 5. Protocolo

Cada mensaje es un objeto JSON en una trama de texto WebSocket, con
`v` (versión del protocolo, hoy `1`) y `tipo`. Si la versión no coincide, el
docente responde `rechazo{version_incompatible}` y cierra la conexión.

**Del alumno al docente**

| Tipo | Campos | Cuándo |
|---|---|---|
| `consulta` | `codigo` | Antes de pedir el apodo: confirma el código y pregunta si la clase pide matrícula |
| `hola` | `codigo, apodo, matricula, device_id`; al reconectar también `alumno_id, token` | Unirse o reconectarse |
| `progreso` | `snapshot, generado_en` | Al cambiar el avance (agrupado cada 0.8 s) |
| `resultado` | `resultado` (con `result_id`) | Al terminar una evaluación y al reconectar, por cada pendiente |
| `presencia` | `modulo_id, etapa` | Cada 20 s y al cambiar de módulo |

**Del docente al alumno**

| Tipo | Campos | Significado |
|---|---|---|
| `info_clase` | `clase` | Código válido: nombre de la clase y si pide matrícula |
| `bienvenida` | `alumno_id, token, apodo, clase` | Dentro de la clase |
| `en_espera` | igual que `bienvenida` | Sala de espera: falta que el docente lo acepte |
| `rechazo` | `motivo, mensaje, sugerencia?` | Ver los motivos abajo |
| `ack` | `resultados[], progreso` | Confirma lo que se guardó |
| `config_clase` | `clase` | Cambiaron los módulos habilitados u otra opción |
| `aviso` | `texto` | Mensaje del docente para toda la clase |
| `renombrado` | `apodo` | El docente cambió el apodo |
| `expulsado` / `clase_finalizada` | `mensaje` | El alumno sale de la clase y conserva su avance local |
| `sesion_reemplazada` | `mensaje` | La misma cuenta se abrió en otra ventana o equipo |

Motivos de `rechazo`: `codigo_invalido`, `apodo_invalido`, `apodo_en_uso`
(incluye `sugerencia`), `matricula_requerida`, `expulsado`,
`clase_finalizada`, `demasiados_intentos`, `no_unido`, `mensaje_invalido`,
`version_incompatible`.

### Secuencia para unirse

```
Alumno                              Docente
 consulta{codigo}            ─▶
                             ◀─    info_clase{nombre, pedir_matricula}
 (el alumno escribe su apodo)
 hola{codigo, apodo, ...}    ─▶    valida apodo, unicidad y matrícula
                             ◀─    bienvenida{alumno_id, token, ...}   (o en_espera / rechazo)
 progreso{snapshot}          ─▶
 resultado{...} × pendientes ─▶
                             ◀─    ack{...}
 presencia{...} cada 20 s    ─▶
```

### Secuencia para reconectar

El alumno guarda `alumno_id`, `token` y la última `IP:puerto`. Al reconectar:

1. Intenta primero la última dirección conocida.
2. Si falla (por ejemplo, el docente cambió de IP por DHCP o de puerto), busca
   por código.
3. Si tampoco lo encuentra, reintenta con espera creciente: 3, 6, 12, 20 y
   30 s.

El `hola` con `alumno_id` y `token` válidos **no vuelve a validar el apodo**:
conserva la identidad y el apodo que tiene el docente. Si había otra conexión
abierta con la misma cuenta, el docente la cierra con `sesion_reemplazada`.
Ese alumno **no** se reconecta solo, para que dos ventanas no se quiten la
sesión una a otra en bucle.

## 6. Identidad: apodo y token

- **Apodo.** Solo sirve para que el docente reconozca a cada alumno. Tiene de
  2 a 20 caracteres: letras (con acentos), números, espacio, `-` y `_`.
  Es único dentro de la clase, comparando sin acentos ni mayúsculas
  (`Ána` = `ana`). Se filtra contra `data/aula/palabras_bloqueadas.json`. El
  docente puede renombrarlo, y el apodo de un alumno retirado queda libre.
- **`alumno_id`.** Lo asigna el docente (`al-xxxxxxxxxx`) y es la identidad
  real. Los resultados del alumno se guardan en el docente con
  `student.id = alumno_id`, `student.apodo` y `origen = "aula"`.
- **`token`.** Es `HMAC-SHA256(secreto_de_la_clase, alumno_id)`. El docente no
  guarda tokens: los recalcula. El secreto vive en `clase.json` y nunca se
  envía.
- **`device_id`.** Lo genera el equipo del alumno la primera vez que usa el
  aula. Identifica al equipo, no a la persona. Sirve para que reimportar el
  mismo archivo sin firma no cree dos alumnos.
- **Matrícula.** Es opcional. El docente decide si la pide.

## 7. Sincronización

En el **alumno**, la fuente de verdad sigue siendo local:

- Progreso: `CourseController.progress_snapshot()`, el mismo JSON de
  `progreso_modular.json`. Se envía completo; repetirlo no causa problemas.
- Resultados: `ResultsRepository.get_history(student_id="__self__")`. Cada
  resultado tiene un `result_id`:
  - Los nuevos reciben un `uuid4` en `save_result`.
  - Los anteriores a esta versión reciben, al cargar el archivo, un id
    **determinista** (hash del contenido). Es una migración de una sola vez
    que reescribe el archivo de resultados.
- `aula/mi_clase.json` guarda la lista de `result_id` **confirmados** por el
  docente (`ack`). Lo pendiente se calcula como "resultados locales menos
  confirmados", así que no hay una cola aparte que pueda desincronizarse.

En el **docente**:

- `ResultsRepository.save_unique()` descarta los `result_id` repetidos. Un
  resultado puede llegar por red y luego otra vez en un archivo, y se guarda
  una sola vez.
- El snapshot de progreso se reemplaza solo si su `generado_en` es igual o
  más reciente que el guardado. Un archivo exportado ayer no pisa lo que
  llegó hoy por red.

## 8. Datos del docente

```
data/aula/clases/<class_id>/          (junto al ejecutable en modo portable)
    clase.json            código, nombre, grupo, secreto, opciones, módulos habilitados
    alumnos.json          fichas: apodo, matrícula, estado, origen, verificado
    progreso/<alumno>.json último snapshot recibido
    resultados.json       ResultsRepository estándar
```

Cada clase es una carpeta autocontenida: se respalda copiándola. Reabrir una
clase conserva el código y los alumnos se reconectan solos.

## 9. Archivos `.tvclase` (opción D)

Un `.tvclase` es JSON con `formato`, `version`, `generado_en`, `clase`,
`alumno`, `progreso`, `resultados` y `firma`.

- Si el alumno ya se había unido por red, el archivo va **firmado**:
  `firma = HMAC-SHA256(token, JSON canónico sin el campo firma)`. Al importar,
  el docente recalcula el token y verifica la firma. Si alguien editó el
  archivo, se rechaza.
- Si el alumno nunca tuvo conexión, el archivo no tiene firma. Se importa como
  alumno **sin verificar** (aparece marcado en la sala), siempre que el
  código de la clase coincida.
- Los archivos de otra clase o de un alumno retirado se rechazan con un
  mensaje claro.

## 10. Control del docente

- **Módulos habilitados.** `clase.modulos_habilitados` es `None` (todos) o una
  lista. El alumno lo aplica con `CourseController.set_class_modules()`, que
  bloquea esos módulos **incluso con `REVIEW_MODE_UNLOCK_ALL`**. Al salir de
  la clase, la restricción desaparece.
- **Sala de espera** (`aprobar_ingresos`). Los alumnos nuevos quedan
  `pendiente` y no pueden enviar datos hasta que el docente los acepta.
- **Retirar** marca al alumno como `expulsado`: no puede volver con esa
  cuenta, pero sus resultados se conservan. **Readmitir** lo revierte.
- **Detener** cierra el servidor sin cambiar la clase: los alumnos quedan
  "Sin conexión" y vuelven solos al reabrirla. **Finalizar** avisa a los
  alumnos, los saca de la clase y rechaza nuevos ingresos hasta que el
  docente la reabra.

## 11. Seguridad y límites

La clase vive en la red del aula y el diseño lo asume:

- **No hay TLS** en la LAN. Por eso viajan pocos datos personales: apodo y,
  si el docente la pide, matrícula. Nunca nombre completo, correo ni edad.
- El código no es un secreto fuerte (30 bits). Se compensa con límites:
  5 intentos fallidos por conexión y 15 por IP cada 60 s. Después la conexión
  se cierra con `demasiados_intentos`.
- Mensajes de máximo 2 MB. Los datagramas ajenos o mal formados se ignoran.
- Los mensajes de un alumno que todavía no está activo (o está en espera) se
  rechazan con `no_unido`.

Si en el futuro se usa la nube (opción C), el TLS es obligatorio, junto con un
aviso de privacidad (LFPDPPP).

## 12. Problemas de red en escuelas

| Síntoma | Causa típica | Solución |
|---|---|---|
| La búsqueda no encuentra la clase, pero por dirección sí | Broadcast bloqueado o subredes distintas | "Conectar por dirección" |
| Ni por dirección conecta | Firewall del docente | `scripts/permitir_firewall_aula.ps1` como administrador, o aceptar el aviso de Windows en redes **privadas y públicas** |
| Nada conecta aunque el firewall está abierto | El Wi-Fi escolar aísla a los clientes entre sí | Opción B: hotspot del docente (máximo 8 equipos en Windows) o un router propio |
| Funcionaba y dejó de funcionar | El docente cambió de IP | Nada: el alumno vuelve a buscar por código |

**Diagnóstico (fase 0).** `diagnostico_aula.py` usa los mismos sockets que la
app, pero con una clase temporal que no toca los datos reales:

```
python diagnostico_aula.py interfaces
python diagnostico_aula.py docente                 # en el equipo del docente
python diagnostico_aula.py alumno K7P-4QX           # en otro equipo
python diagnostico_aula.py alumno K7P-4QX --direccion 192.168.1.20:47801
```

Cada paso imprime `[OK]` o `[FALLA]` con la causa probable. Conviene correrlo
en la red real de la escuela, por Wi-Fi y por cable, antes de la primera
clase.

## 13. Empaquetado

- PyInstaller debe incluir `PySide6.QtWebSockets` y `PySide6.QtNetwork`. Si el
  análisis automático no los detecta, agrégalos con `--hidden-import`.
- `data/aula/palabras_bloqueadas.json` es un recurso de **solo lectura**: debe
  viajar dentro del paquete, como `data/aprendizaje/modules.json`.
- El instalador del equipo docente puede ejecutar
  `scripts/permitir_firewall_aula.ps1` para evitar el aviso del firewall.

## 14. Pruebas

- `tests/model/test_aula.py`: reglas de la clase sin red (código, apodos,
  unión, reconexión, sala de espera, expulsión, resultados, archivos firmados
  y sin firma, análisis).
- `tests/viewmodel/test_classroom_network.py`: docente y alumno **reales** por
  UDP y WebSocket en `localhost`. Cubre la unión, la sincronización, la
  restricción de módulos, los avisos, el reinicio del docente con cambio de
  puerto, la expulsión, el apodo repetido, la conexión por dirección y la
  importación de `.tvclase`.
- `tests/view/test_classroom_screens.py`: las pantallas QML sobre la ventana
  real.

## 15. Extender a la nube (opción C)

1. Escribir un servidor asyncio, por ejemplo con `websockets`, que cree un
   `RepositorioClase` y una `SesionClase` por clase, y traduzca
   `procesar()` / `Envio` igual que `ServidorAulaLan`.
2. El código de clase se busca en una tabla del servidor en lugar de por
   broadcast. El alumno usa `ClienteAulaLan.conectar(host, puerto)` con
   `wss://` (habría que permitir esquema seguro en `cliente_lan.py`).
3. El docente se conectaría como un cliente con rol de administrador. Esto
   requiere mensajes nuevos para las acciones que hoy llama directamente.
