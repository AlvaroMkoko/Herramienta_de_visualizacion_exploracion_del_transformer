# Estándar de red del aula conectada

**Para quién:** cualquier agente o persona que modifique algo que viaje por la red o que el
docente guarde al recibirlo. Es obligatorio leerlo antes de tocar:

- `model/aula/` y `viewmodel/aula/` (protocolo, sesión, transporte, TLS, controladores).
- `model/evaluacion/results_repository.py` (el docente guarda ahí cada resultado que recibe).
- La forma de un resultado o de `CourseController.progress_snapshot()` (viajan completos).
- Los puertos, el empaquetado (PyInstaller) o `scripts/permitir_firewall_aula.ps1`.

Cómo funciona la red, mensaje por mensaje: [red_aula.md](red_aula.md). Este documento no lo
repite: fija **qué no se puede romper** y **cómo se comprueba**.

---

## 1. El objetivo que se garantiza

**Un docente y 40 alumnos en la misma clase, con todos los resultados recibidos, sin pérdidas
ni duplicados, y el panel del docente respondiendo.** Debe cumplirse también al final del
semestre, cuando la clase ya acumula los 8 módulos (unos 680 resultados y un
`resultados.json` de unos 12 MB).

Un cambio que no mantenga esto **no está terminado**, aunque pasen las pruebas unitarias.

## 2. La red real: Wi-Fi IPN

Medido el 27 de octubre de 2026 con `../Analisis_red/analizar_red.py` desde el salón. Los reportes están en `../Analisis_red/reportes/`.

| Hecho medido | Consecuencia obligatoria para el código |
|---|---|
| Red abierta, subred `/19` (unas 8 000 direcciones), DHCP, perfil «Público» en Windows | La IP del docente puede cambiar entre sesiones. El firewall de Windows bloquea lo entrante salvo que haya regla. |
| **No reenvía broadcast ni multicast entre clientes**: dos escuchas pasivas (45 s y 30 s) sin un solo paquete de los 12–15 equipos visibles, con el paquete de control propio recibido y el firewall permitiendo Python | **«Buscar por código» no encuentra al docente.** Los alumnos entran con **«Conectar por dirección»**. |
| **El tráfico TCP directo entre clientes sí pasa**: un celular en 10.100.87.203 abrió una conexión a la laptop del docente en 10.100.93.12:47801 y recibió la respuesta (`analizar_red.py escuchar`, reporte `red_20261027_145938_*`). Es otro /24 dentro del mismo /19 | **La herramienta funciona en esta red con «Conectar por dirección»** (opción A sin descubrimiento). No hace falta un router propio. |

Reglas que se derivan:

1. **El broadcast nunca es el único camino.** Todo lo que se pueda hacer buscando por código
   debe poder hacerse con `IP:puerto`. Esto incluye unirse, reconectarse y reabrir la clase.
2. **La reconexión no puede depender del descubrimiento.** El alumno reintenta la última
   dirección conocida. Si para reconectarse hace falta algo que solo trae el broadcast (por
   ejemplo, una huella TLS nueva), en esta red no se reconecta nunca.
3. **La dirección del docente debe estar a la vista** en su pantalla mientras la clase está abierta.
4. Si en otra red el tráfico directo entre clientes tampoco pasa, se usa la opción B con un **router propio**.
   El hotspot de Windows admite solo 8 equipos, no 40. La opción D (archivos `.tvclase`) es el
   respaldo.

## 3. Invariantes del protocolo y del transporte

| # | Invariante | Dónde vive | Si lo cambias |
|---|---|---|---|
| P1 | Puertos: UDP **47800** y TCP **47801–47810** | `model/aula/protocolo.py` | Actualiza también `scripts/permitir_firewall_aula.ps1`, `../Analisis_red/analizar_red.py`, `../Analisis_red/prueba_carga_aula.py`, `red_aula.md` y la guía de uso |
| P2 | Cada mensaje es un objeto JSON con `v` y `tipo`; los tipos válidos están en `MENSAJES_ALUMNO` y `MENSAJES_DOCENTE` | `protocolo.py` | Un tipo nuevo se agrega a esos conjuntos y a la tabla de `red_aula.md` |
| P3 | `VERSION_PROTOCOLO` solo cambia si un mensaje deja de ser compatible. Un campo **opcional** nuevo no lo cambia | `protocolo.py` | Subirla deja fuera a todos los alumnos con la versión anterior (el docente los rechaza) |
| P4 | Mensaje ≤ **2 MB** (`TAMANO_MAXIMO`), datagrama ≤ 4 KB, **solo tramas de texto** (el docente cierra la conexión ante una binaria) | `protocolo.py`, `servidor_lan.py` | Nunca mandes «todos los resultados» en un solo mensaje: uno por resultado |
| P5 | Transporte `wss://` con TLS ≥ 1.2. El alumno fija la huella SHA-256 del certificado: la que llega en el descubrimiento, o la primera que ve si entró por dirección | `tls.py`, `cliente_lan.py` | No hay retroceso a `ws://` ni `VerifyNone` sin fijar la huella |
| P6 | **El certificado del docente es uno por clase y persiste** en `clase.json`. Reabrir la clase no cambia la huella | `tls.py`, `servidor_lan.py`, `repositorio_clase.py` | Si se generara uno nuevo en cada apertura, los alumnos ya unidos quedarían en «reconectando» para siempre en una red sin broadcast (§2, regla 2). Lo cubre una prueba |
| P7 | Idempotencia: cada resultado lleva `result_id`; el docente lo guarda una sola vez (`save_unique`) y **confirma también los repetidos**. El avance solo reemplaza al guardado si su `generado_en` es igual o más reciente | `sesion_clase.py`, `results_repository.py` | Sin esto, los reenvíos tras un corte duplican datos o dejan colas que nunca se vacían |
| P8 | **El `ack` sale después de que el resultado está en disco.** El alumno borra de su cola solo lo confirmado | `servidor_lan.py` (lote) | Confirmar antes de guardar pierde resultados si el equipo del docente se apaga |
| P9 | El alumno trabaja primero en local: la red solo replica. Pendiente = resultados locales − confirmados (`mi_clase.json`), sin una cola aparte | `classroom_student_controller.py`, `estado_alumno.py` | Una cola aparte se desincroniza |
| P10 | `model/aula/` no importa Qt. `SesionClase` no conoce sockets | — | Rompe la opción C (servidor en la nube) y las pruebas sin red |
| P11 | Todo el transporte corre en el event loop de Qt, sin hilos | `viewmodel/aula/` | Un `QWebSocket` usado desde otro hilo falla sin avisar |
| P12 | El docente escucha en `AnyIPv4` y responde al **origen** del datagrama. El alumno manda la búsqueda a `255.255.255.255`, al broadcast de cada interfaz y a `127.0.0.1` | `servidor_lan.py`, `red.py` | Con varias interfaces (Wi-Fi + hotspot) el docente deja de ser encontrado |
| P13 | Reintentos del alumno: 3, 6, 12, 20 y 30 s (`ESPERAS_REINTENTO_MS`); conexión con 5 s de espera | `classroom_student_controller.py`, `cliente_lan.py` | Bajarlos hace que 40 alumnos reconectando a la vez saturen al docente |
| P14 | Límites contra fuerza bruta: 5 fallos por conexión y 15 por IP cada 60 s. Solo cuentan los **fallos** | `sesion_clase.py` | Si se cuentan intentos exitosos, una red con NAT (todos con una misma IP) deja fuera a la clase |
| P15 | Datos personales por la red: solo apodo y, si el docente la pide, matrícula. Nunca nombre, correo ni edad | `sesion_clase.py` | Requiere aviso de privacidad (LFPDPPP) |

## 4. Presupuesto de rendimiento del docente

El docente atiende a todos los alumnos y además dibuja su interfaz **en un solo hilo**. Mientras
un manejador trabaja, nadie más es atendido. Si se congela más de 5 s, los handshakes TLS de
los alumnos vencen y ven «El equipo del docente no respondió».

| Regla | Por qué |
|---|---|
| **R1.** Un manejador de mensaje no debe tardar más de unos 100 ms con una clase llena | 40 mensajes que llegan juntos se atienden uno detrás de otro |
| **R2.** Nada que cueste en proporción a lo ya guardado puede ocurrir **por mensaje**. Las escrituras de resultados se agrupan por lote (`ResultsRepository.lote()` en `ServidorAulaLan._procesar_cola`) | Reescribir `resultados.json` completo por cada resultado congelaba al docente 34 s al final del semestre (ver §6) |
| **R3.** Para serializar JSON grande, `json.dumps(...)` y una sola escritura, nunca `json.dump(..., archivo)` | `json.dump` no usa el codificador en C: es unas 3 veces más lento con los mismos bytes |
| **R4.** El refresco del panel sigue agrupado (`_refresco`, 250 ms) y nunca se recalcula por cada mensaje | Con 40 alumnos llegan decenas de mensajes por segundo |
| **R5.** Nada de `time.sleep`, `waitForConnected`, `waitForReadyRead` ni bucles de espera en el hilo de Qt | Congela a todos |

## 5. Empaquetado

- Dependencias: `PySide6` (incluye QtNetwork y QtWebSockets) y `cryptography` (genera el
  certificado). `cryptography` ya está en `requirements.txt`. Tras cada actualización, todos
  los equipos deben correr `pip install -r requirements.txt`; si falta, la app no arranca
  (`ModuleNotFoundError: cryptography`).
- PyInstaller debe incluir `PySide6.QtWebSockets`, `PySide6.QtNetwork`, **el plugin TLS de Qt**
  (`plugins/tls/`, `qschannelbackend` en Windows) y `cryptography`. Sin el plugin TLS no hay
  `wss://` y nadie puede unirse.
- `data/aula/palabras_bloqueadas.json` es un recurso de solo lectura que viaja en el paquete.

## 6. Cómo se comprueba (obligatorio antes de dar un cambio por terminado)

Corre desde la raíz del proyecto:

```bash
# 1. Pruebas del aula (sin red real)
python -m pytest -q tests/model/test_aula.py tests/viewmodel/test_classroom_network.py tests/view/test_classroom_screens.py

# 2. Carga: 1 docente + 40 alumnos con el código real (TLS, sesión, guardado y panel)
python ../Analisis_red/prueba_carga_aula.py local --alumnos 40

# 3. Si tocaste persistencia, resultados, avance o el panel del docente: fin de semestre
python ../Analisis_red/prueba_carga_aula.py local --alumnos 40 --modulos 8 --espera 240
```

La prueba de carga deja su veredicto en `../Analisis_red/reportes/carga_*.md`. **Ninguna línea
puede quedar en FALLA**, y los números no deben empeorar de forma notable respecto a esta
referencia:

| Escenario (40 alumnos, misma laptop) | Unión p95 | `ack` p95 / máx | Tras corte de red | Congelamiento máx del docente | Reporte |
|---|---|---|---|---|---|
| 1 módulo (120 resultados) | 1,3 s | 0,23 / 0,24 s | 4,2 s | 0,21 s | `carga_20261027_144834_*` |
| 8 módulos (680 resultados, 11,6 MB) | 1,2 s | 0,64 / 0,66 s | 5,2 s | 0,64 s | `carga_20261027_144904_*` |
| *Antes de agrupar las escrituras:* 8 módulos | 1,2 s | 20,8 / 34,4 s | 39,3 s | todo el escenario saturado | `carga_20261027_144106_*` |

Criterios de la prueba: unión del 100 %, el 100 % de los resultados confirmados y guardados una
sola vez, `ack` con p95 ≤ 2 s y máximo ≤ 5 s, recuperación tras un corte en ≤ 35 s y docente
sin congelarse más de 1 s (AVISO) o de 5 s (FALLA).

Si cambiaste el transporte, los puertos, el TLS o el descubrimiento, además se prueba **en la
red real con dos equipos** (el tráfico entre procesos de un mismo equipo no cruza el punto de
acceso):

```bash
python ../Analisis_red/analizar_red.py                       # en el salón: ¿broadcast?, ¿firewall?
python ../Analisis_red/analizar_red.py escuchar              # equipo del docente
python ../Analisis_red/analizar_red.py probar --direccion IP # equipo de un alumno
python ../Analisis_red/prueba_carga_aula.py docente          # equipo del docente
python ../Analisis_red/prueba_carga_aula.py alumnos CODIGO --direccion IP:PUERTO   # otro equipo
```

Al terminar:

- Si cambiaste un mensaje, un puerto o un límite, actualiza [red_aula.md](red_aula.md) y la tabla del §3.
- Si cambió el rendimiento, actualiza la referencia del §6 con el nuevo reporte.
- Di qué invariantes revisaste (P1–P15, R1–R5) en el resumen del cambio.

## 7. Errores que ya ocurrieron (no repetir)

| Error | Síntoma | Regla |
|---|---|---|
| `resultados.json` se reescribía completo por cada resultado recibido | Con 680 resultados, cada ráfaga de 40 congelaba al docente unos 30 s; los `ack` tardaban hasta 34 s | R2, R3 |
| Certificado TLS nuevo en cada apertura de la clase | En una red sin broadcast, tras reabrir la clase ningún alumno se reconectaba («No se pudo verificar la identidad TLS») | P6 |
| `cryptography` agregado al código sin instalarlo en los equipos | La app no arrancaba después del pull | §5 |
