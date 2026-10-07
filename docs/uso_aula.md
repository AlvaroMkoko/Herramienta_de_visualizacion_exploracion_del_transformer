# Aula conectada: guía de uso

Con el aula conectada, el docente comparte un **código de clase** y los
alumnos se unen con un **apodo**, como en Kahoot. Desde ese momento el docente
ve en vivo quién está conectado, en qué módulo va cada alumno y cómo le fue en
sus evaluaciones.

El detalle técnico de la red está en [red_aula.md](red_aula.md).

---

## Antes de la primera clase (una sola vez)

### 1. Elegir la red

Docente y alumnos deben estar **en la misma red**. Hay dos opciones:

- **Red de la escuela** (Wi-Fi o cable). Es lo más cómodo, si la red permite
  que los equipos se vean entre sí.
- **Red propia del docente.** Un router de viaje, o el hotspot de la laptop
  del docente (*Configuración → Red e Internet → Zona con cobertura
  inalámbrica móvil*). El hotspot de Windows acepta **máximo 8 equipos**;
  para un grupo completo conviene un router. No necesita tener internet.

### 2. Permitir la aplicación en el firewall (equipo del docente)

La primera vez que se abre una clase, Windows puede preguntar si permite el
acceso a la red. Marca **redes privadas y públicas** y acepta. Si no tienes
permisos de administrador, pide a quien los tenga que ejecute una vez:

```
powershell -ExecutionPolicy Bypass -File scripts\permitir_firewall_aula.ps1
```

### 3. Probar la red

En el equipo del docente:

```
python diagnostico_aula.py docente
```

Aparecen un código de prueba y la dirección del equipo. En el equipo de un
alumno:

```
python diagnostico_aula.py alumno CODIGO
```

Si todas las líneas dicen `[OK]`, la red funciona. Si alguna dice `[FALLA]`,
el mismo mensaje sugiere la causa. Consulta también la sección
[Problemas frecuentes](#problemas-frecuentes).

---

## Docente

### Crear la clase

1. En la selección de perfil, entra a **Soy profesor**.
2. Pulsa **Clase en red**.
3. Escribe el nombre de la clase y, si quieres, el grupo.
4. Elige las opciones:
   - **Pedir matrícula además del apodo.** Útil si necesitas relacionar los
     resultados con tu lista oficial.
   - **Sala de espera.** Cada alumno nuevo espera a que lo aceptes antes de
     entrar.
5. Pulsa **Crear y abrir clase**.

La pantalla muestra en grande el **código de la clase**, y debajo la
**dirección** del equipo (por ejemplo `192.168.1.20:47801`). Dicta el código o
escríbelo en el pizarrón.

> Mantén la aplicación abierta durante la clase: tu equipo es el servidor.
> Puedes moverte a otras pantallas; la clase sigue abierta.

### Pestaña «Sala»

Lista a todos los alumnos:

- **Punto verde**: conectado. **Gris**: desconectado, con su última
  actividad.
- Módulo y etapa en que va cada alumno, y su barra de avance del curso.
- **Aceptar / Rechazar**: solo con sala de espera, para los alumnos nuevos.
- **Renombrar**: cambia un apodo inapropiado o confuso. El alumno ve el
  cambio al instante.
- **Retirar**: saca al alumno de la clase. No podrá volver a unirse con esa
  cuenta, pero sus resultados se conservan. **Readmitir** lo deshace.
- La etiqueta **sin verificar** marca a quien entregó su avance por archivo
  sin haberse conectado nunca (ver [Entregas por archivo](#entregas-por-archivo)).

### Pestaña «Avance por módulo»

Una tabla de alumnos por módulos (M1 … M8). Cada celda muestra el post-test si
ya existe o, si no, cuánto lleva del módulo:

- **Verde**: módulo completado.
- **Ámbar**: conviene repasar (post-test menor a 70 %).
- **Morado**: en curso.
- 🔒 junto a un módulo indica que lo tienes deshabilitado.

### Pestaña «Análisis del grupo»

Elige un módulo y verás:

- Promedio del pre-test, del post-test y el **cambio promedio**. El cambio
  solo cuenta a los alumnos que hicieron ambos tests.
- **Conceptos con más errores** en el post-test.
- **Reactivos más fallados**, con su enunciado.

### Pestaña «Herramientas»

- **Módulos habilitados.** Los alumnos solo pueden abrir los módulos
  marcados. Sirve para avanzar todos al mismo ritmo.
- **Aviso a toda la clase.** Aparece como una franja en la pantalla de cada
  alumno conectado.
- **Ingreso.** Activa o desactiva la sala de espera y la matrícula para los
  alumnos que entren después.
- **Exportar resultados (CSV).** Una fila por evaluación, lista para Excel,
  R o pandas.
- **Importar archivos .tvclase.** Los avances que los alumnos entregaron sin
  red.
- **Diagnóstico de red.** Las redes de tu equipo y qué hacer si los alumnos
  no te encuentran.

### Terminar la clase

- **Detener.** Cierra la clase por hoy. Los alumnos ven "Sin conexión con el
  docente" y siguen trabajando; cuando la vuelvas a abrir, se reconectan
  solos.
- **Finalizar clase.** Avisa a los alumnos y los saca de la clase. Los datos
  se conservan.

Para retomar otro día: **Clase en red → Clases guardadas → Abrir**. El
código es el mismo.

---

## Alumno

### Unirse

1. En la pantalla de bienvenida, pulsa **Unirse a una clase**.
2. Escribe el código que dicta tu docente. Da igual usar mayúsculas o
   minúsculas, y confundir la O con el 0 o la I con el 1.
3. Pulsa **Buscar clase**.
4. Escribe tu **apodo**: así te verá tu docente. Si te lo piden, escribe
   también tu matrícula.
5. Pulsa **Entrar a la clase**.

Si alguien ya usa ese apodo, la app propone otro (por ejemplo «Ana2»). Puedes
aceptarlo con un clic o escribir uno distinto. Si tu docente activó la sala
de espera, verás "Esperando aprobación" hasta que te acepte.

### Durante la clase

- Trabaja normalmente en tu ruta. Tu avance y tus evaluaciones se envían
  solos.
- Arriba a la derecha, un indicador muestra **Conectado** o **Sin conexión
  con el docente**.
- Si se cae la red, **no pierdes nada**: todo se guarda en tu equipo y se
  envía cuando vuelva la conexión.
- Los avisos del docente aparecen como una franja azul. Pulsa **Entendido**
  para cerrarla.
- Si un módulo aparece como **Bloqueado** en el mapa del curso, tu docente
  todavía no lo habilita: espera su indicación.

### Si no encuentra la clase

1. Revisa el código y que estés conectado a la misma red que tu docente.
2. Pulsa **Conectar por dirección** y escribe la dirección que aparece en la
   pantalla del docente (por ejemplo `192.168.1.20:47801`).
3. Si aun así no conecta, entrega tu avance por archivo (siguiente sección).

### Entregas por archivo

Si no hay red, o no logras conectarte:

- **Si nunca te uniste:** en *Unirse a una clase*, pulsa **Sin red: entregar
  por archivo**. Escribe el código de la clase y tu apodo, y pulsa **Exportar
  mi avance**.
- **Si ya estás en la clase:** en *Ver mi clase*, pulsa **Exportar mi avance
  a archivo**.

Guarda el archivo `.tvclase` y entrégalo a tu docente (USB, Classroom o
correo). Puedes exportar varias veces; el docente no duplica evaluaciones.

### Salir de la clase

En *Ver mi clase*, pulsa **Salir de la clase**. Tu avance sigue en tu equipo
y puedes volver a unirte con el código.

---

## Problemas frecuentes

| Qué pasa | Qué hacer |
|---|---|
| "No se encontró la clase en esta red" | Revisar el código y la red. Probar **Conectar por dirección** |
| Por dirección tampoco conecta | En el equipo del docente, permitir la app en el firewall (redes privadas **y públicas**) o ejecutar `scripts\permitir_firewall_aula.ps1` |
| Nada conecta aunque el firewall está abierto | El Wi-Fi de la escuela aísla a los equipos. Usar el hotspot del docente o un router propio |
| Un alumno aparece dos veces | Se unió desde dos equipos con apodos distintos. Retira el que no corresponda |
| "Tu cuenta de la clase se abrió en otra ventana o equipo" | Cierra la otra ventana y pulsa **Reintentar ahora** |
| La búsqueda automática "no está disponible" en el docente | Otra copia de la app ocupa el puerto de búsqueda. Ciérrala, o que los alumnos usen **Conectar por dirección** |
| El archivo `.tvclase` se rechaza por la firma | Alguien lo modificó a mano. Pide al alumno que lo exporte de nuevo |

## Dónde quedan los datos

- **Docente:** `data/aula/clases/<clase>/`, o `datos/aula/clases/` junto al
  ejecutable en la versión empaquetada. Copia esa carpeta para respaldar una
  clase.
- **Alumno:** su avance sigue donde siempre. `data/aula/mi_clase.json` solo
  recuerda a qué clase pertenece.
