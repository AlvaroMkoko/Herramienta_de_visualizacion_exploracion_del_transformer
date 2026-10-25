# Instalar Transformer Visualizer en los equipos del laboratorio

No necesita Python, internet ni permisos de administrador (salvo el paso 5, que es
opcional). Por equipo: el archivo `TransformerVisualizer.zip` (407 MB) y **1 GB libre
por cada alumno** que vaya a usar ese equipo.

> **Regla: una carpeta por alumno.** La aplicación no distingue a un alumno de otro:
> todo lo que hace se guarda en la carpeta donde se descomprimió. Si dos alumnos usan
> la misma carpeta, el segundo encuentra el pre-test del primero como ya hecho y sus
> resultados no sirven. Por eso cada alumno tiene su propia carpeta
> (`C:\TV\alumno01`, `C:\TV\alumno02`…), **siempre la misma** en todas las sesiones.
> Anota en papel qué número corresponde a cada alumno.

## 1. Desbloquear el .zip antes de descomprimir

Clic derecho sobre `TransformerVisualizer.zip` → **Propiedades** → en la pestaña
*General*, marca **Desbloquear** → **Aceptar**. Si la casilla no aparece, no hace falta.

*Por qué:* si no, cada uno de los 5 300 archivos sale marcado como «descargado de
internet» y Windows puede frenarlos o bloquearlos.

## 2. Descomprimir una vez por alumno, en una ruta corta

Clic derecho sobre el .zip → **Extraer todo…** → cambia la carpeta de destino por
`C:\TV\alumno01` → **Extraer**. Queda así:
`C:\TV\alumno01\TransformerVisualizer\TransformerVisualizer.exe`. Repite con
`alumno02`, `alumno03`… y una más, `C:\TV\profesor`, para el profesor.

**Cada carpeta sale del .zip, nunca de copiar otra carpeta ya usada**: la copia se
llevaría el avance y el pre-test de su dueño.

**El límite:** la ruta de la carpeta que contiene `TransformerVisualizer.exe` debe
tener **168 caracteres o menos** (con `C:\TV\alumno01\TransformerVisualizer` son 36).
Si se pasa, la aplicación **no abre y no muestra ningún error**: parece que no pasó
nada. Si alguien dice «le doy doble clic y no hace nada», lo primero es revisar la ruta.

No la pongas en `Archivos de programa`: ahí no se puede escribir y los resultados
irían a parar a otro sitio (ver paso 4).

## 3. Primera ejecución

Doble clic en `TransformerVisualizer.exe`. **La primera vez tarda más**, porque el
antivirus revisa los archivos; las siguientes es casi inmediata. Abre cada carpeta
una vez **antes** de la sesión, y no le des doble clic varias veces mientras carga.

**Si aparece «Windows protegió su PC»** (SmartScreen): clic en **Más información** →
**Ejecutar de todas formas**. Sale porque el programa no tiene firma digital. Si no
aparece el botón, o el antivirus pone el programa en cuarentena, el equipo está
bloqueado por la escuela: pide a quien administre los equipos que permita la carpeta
`C:\TV`. Desde aquí no se puede saltar.

## 4. Comprobar que guarda donde debe

Abre y cierra la aplicación **con la cuenta de Windows que usarán los alumnos**. Junto
a `TransformerVisualizer.exe` debe haber una carpeta `datos` con `datasets` y `logs`
dentro. Si está, todo lo que haga ese alumno se guardará ahí.

## 5. Solo si se usará el aula conectada: el firewall

Solo en el equipo del profesor y solo una vez. **Requiere administrador.** Inicio →
escribe `PowerShell` → clic derecho → **Ejecutar como administrador**, pega esto y
pulsa Enter:

    powershell -ExecutionPolicy Bypass -File C:\TV\profesor\TransformerVisualizer\scripts\permitir_firewall_aula.ps1

Deben salir dos líneas verdes «Regla creada». Para deshacerlo, la misma orden con
` -Quitar` al final.

## 6. Al terminar la sesión: recoger los resultados

Cada alumno deja todo en la carpeta **`datos`** de su carpeta: pre-test, post-test y
avance. La del profesor guarda además las clases del aula.

1. Cierra la aplicación.
2. Copia cada carpeta `datos` completa a la USB y renómbrala con el alumno y el equipo
   (por ejemplo `datos_alumno01_EQUIPO07`).
3. **No borres ninguna carpeta `datos` del equipo** hasta que Álvaro confirme que
   recibió la copia. Si reinstalas, no la reemplaces: también lleva el modelo que usan
   los alumnos.
