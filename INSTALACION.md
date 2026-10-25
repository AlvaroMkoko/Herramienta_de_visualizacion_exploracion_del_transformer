# Instalar Transformer Visualizer en los equipos del laboratorio

No necesita Python, internet ni permisos de administrador (salvo el paso 5, que es
opcional). Por equipo: el archivo `TransformerVisualizer.zip` (407 MB) y 1 GB libre.

## 1. Desbloquear el .zip antes de descomprimir

Clic derecho sobre `TransformerVisualizer.zip` → **Propiedades** → en la pestaña
*General*, marca **Desbloquear** → **Aceptar**. Si la casilla no aparece, no hace falta.

*Por qué:* si no, cada uno de los 5 300 archivos sale marcado como «descargado de
internet» y Windows puede frenarlos o bloquearlos.

## 2. Descomprimir en una ruta corta: `C:\TV\`

Clic derecho sobre el .zip → **Extraer todo…** → cambia la carpeta de destino por
`C:\TV` → **Extraer**. Queda así: `C:\TV\TransformerVisualizer\TransformerVisualizer.exe`.

**El límite:** la ruta de la carpeta que contiene `TransformerVisualizer.exe` debe
tener **168 caracteres o menos** (con `C:\TV\TransformerVisualizer` son 27). Si se
pasa, la aplicación **no abre y no muestra ningún error**: parece que no pasó nada.
Si alguien dice «le doy doble clic y no hace nada», lo primero es revisar la ruta.

No la pongas en `Archivos de programa`: ahí no se puede escribir y los resultados
irían a parar a otro sitio (ver paso 4).

## 3. Primera ejecución

Doble clic en `TransformerVisualizer.exe`. **La primera vez tarda más**, porque el
antivirus revisa los archivos; las siguientes es casi inmediata. Ábrela una vez en
cada equipo **antes** de la sesión, y no le des doble clic varias veces mientras carga.

**Si aparece «Windows protegió su PC»** (SmartScreen): clic en **Más información** →
**Ejecutar de todas formas**. Sale porque el programa no tiene firma digital, y solo
la primera vez. Si no aparece el botón, o el antivirus pone el programa en
cuarentena, el equipo está bloqueado por la escuela: pide a quien administre los
equipos que permita la carpeta `C:\TV\TransformerVisualizer`. Desde aquí no se puede
saltar.

## 4. Comprobar que guarda donde debe

Abre y cierra la aplicación **con la cuenta de Windows que usarán los alumnos**. Junto
a `TransformerVisualizer.exe` debe haber una carpeta `datos` con `datasets` y `logs`
dentro. Si está, todo lo que hagan los alumnos se guardará ahí.

## 5. Solo si se usará el aula conectada: el firewall

Solo en el equipo del profesor y solo una vez. **Requiere administrador.** Inicio →
escribe `PowerShell` → clic derecho → **Ejecutar como administrador**, pega esto y
pulsa Enter:

    powershell -ExecutionPolicy Bypass -File C:\TV\TransformerVisualizer\scripts\permitir_firewall_aula.ps1

Deben salir dos líneas verdes «Regla creada». Para deshacerlo, la misma orden con
` -Quitar` al final.

## 6. Al terminar la sesión: recoger los resultados

Todo queda en la carpeta **`datos`**, junto a `TransformerVisualizer.exe`: pre-test,
post-test, avance de cada alumno y clases del aula.

1. Cierra la aplicación.
2. Copia la carpeta `datos` completa a la USB y renómbrala con el nombre del equipo
   (por ejemplo `datos_EQUIPO07`).
3. **No borres la carpeta `datos` del equipo** hasta que Álvaro confirme que recibió la
   copia. Si reinstalas, no la reemplaces: también lleva el modelo que usan los alumnos.
