import QtQuick
import QtQuick.Controls
import "../styles" as Style

Item {
    id: nube

    signal helpRequested(string conceptId)

    // Datos que llegan desde TrainingScreen (payload de nube_embeddings)
    property var puntos: []
    property var etiquetas: []
    property real varianzaConservada: 0
    property var varianzaPorComponente: []
    property string modo: "pca"
    property var dimensiones: []

    property real yaw: 0.6
    property real pitch: 0.35
    property real zoom: 1.0
    property bool rotacionAutomatica: false

    // La rotacion es ortogonal: preserva distancias, asi que girar la
    // camara nunca deforma la nube (verificado numericamente).
    function rotar(p, yaw, pitch) {
        var cy = Math.cos(yaw),   sy = Math.sin(yaw)
        var cp = Math.cos(pitch), sp = Math.sin(pitch)
        var x1 =  p[0]*cy + p[2]*sy
        var y1 =  p[1]
        var z1 = -p[0]*sy + p[2]*cy
        return [x1, y1*cp - z1*sp, y1*sp + z1*cp]
    }

    onPuntosChanged: lienzo.requestPaint()
    onYawChanged: lienzo.requestPaint()
    onPitchChanged: lienzo.requestPaint()
    onZoomChanged: lienzo.requestPaint()

    Timer {
        running: nube.rotacionAutomatica && nube.visible
        interval: 33
        repeat: true
        onTriggered: nube.yaw += 0.01
    }

    Canvas {
        id: lienzo
        anchors.fill: parent
        renderStrategy: Canvas.Threaded

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var datos = nube.puntos
            if (!datos || datos.length === 0) {
                ctx.fillStyle = "#8A8A9A"
                ctx.font = "13px sans-serif"
                ctx.textAlign = "center"
                ctx.fillText("Esperando datos del entrenamiento…", width/2, height/2)
                return
            }

            // --- Normalizar a un cubo centrado, con escala UNIFORME ---
            // Usar el mismo divisor en los 3 ejes es deliberado: normalizar
            // cada eje por su propio rango haria que una nube plana se viera
            // como un cubo, mintiendo sobre la forma real de los datos.
            var mn = [1e30,1e30,1e30], mx = [-1e30,-1e30,-1e30]
            for (var i = 0; i < datos.length; ++i) {
                for (var e = 0; e < 3; ++e) {
                    var v = datos[i][e] !== undefined ? datos[i][e] : 0
                    if (v < mn[e]) mn[e] = v
                    if (v > mx[e]) mx[e] = v
                }
            }
            var centro = [(mn[0]+mx[0])/2, (mn[1]+mx[1])/2, (mn[2]+mx[2])/2]
            var rango = Math.max(mx[0]-mn[0], mx[1]-mn[1], mx[2]-mn[2]) || 1

            var escala = Math.min(width, height) * 0.62 * nube.zoom
            var cx = width/2, cy = height/2

            // --- Proyectar y ordenar por profundidad ---
            var proyectados = []
            for (var j = 0; j < datos.length; ++j) {
                var p = [
                    ((datos[j][0] !== undefined ? datos[j][0] : 0) - centro[0]) / rango,
                    ((datos[j][1] !== undefined ? datos[j][1] : 0) - centro[1]) / rango,
                    ((datos[j][2] !== undefined ? datos[j][2] : 0) - centro[2]) / rango
                ]
                var r = nube.rotar(p, nube.yaw, nube.pitch)
                proyectados.push({
                    x: cx + r[0]*escala,
                    y: cy - r[1]*escala,
                    z: r[2],
                    etiqueta: nube.etiquetas[j] !== undefined ? nube.etiquetas[j] : ""
                })
            }
            // Dibujar de atras hacia adelante para que los puntos cercanos
            // tapen a los lejanos.
            proyectados.sort(function(a,b){ return a.z - b.z })

            // --- Ejes de referencia ---
            var ejes = [[[0.5,0,0],"X"], [[0,0.5,0],"Y"], [[0,0,0.5],"Z"]]
            ctx.strokeStyle = "#C9C6DE"
            ctx.lineWidth = 1
            ctx.font = "10px sans-serif"
            ctx.textAlign = "center"
            for (var k = 0; k < 3; ++k) {
                var re = nube.rotar(ejes[k][0], nube.yaw, nube.pitch)
                var ex = cx + re[0]*escala, ey = cy - re[1]*escala
                ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(ex, ey); ctx.stroke()
                ctx.fillStyle = "#9A97B5"
                ctx.fillText(ejes[k][1], ex, ey - 4)
            }

            // --- Puntos ---
            for (var m = 0; m < proyectados.length; ++m) {
                var pt = proyectados[m]
                // La profundidad se codifica en tamano y opacidad: sin esto
                // la nube se ve plana, no hay pista de que punto esta adelante.
                var t = (pt.z + 0.9) / 1.8
                t = Math.max(0, Math.min(1, t))
                var radio = (3 + t*4) * nube.zoom
                ctx.globalAlpha = 0.45 + t*0.55
                ctx.fillStyle = "#6A63E8"
                ctx.beginPath()
                ctx.arc(pt.x, pt.y, radio, 0, Math.PI*2)
                ctx.fill()

                if (pt.etiqueta !== "" && t > 0.35) {
                    ctx.fillStyle = "#3A3752"
                    ctx.font = "11px sans-serif"
                    ctx.fillText(pt.etiqueta, pt.x, pt.y - radio - 3)
                }
            }
            ctx.globalAlpha = 1.0
        }
    }

    MouseArea {
        anchors.fill: parent
        property real ultimoX: 0
        property real ultimoY: 0

        onPressed: function(mouse) { ultimoX = mouse.x; ultimoY = mouse.y }
        onPositionChanged: function(mouse) {
            nube.yaw   += (mouse.x - ultimoX) * 0.01
            nube.pitch += (mouse.y - ultimoY) * 0.01
            // Limitar el pitch evita que la nube quede "de cabeza",
            // desorientando al usuario.
            nube.pitch = Math.max(-1.4, Math.min(1.4, nube.pitch))
            ultimoX = mouse.x; ultimoY = mouse.y
        }
        onWheel: function(wheel) {
            nube.zoom = Math.max(0.4, Math.min(3.0, nube.zoom + wheel.angleDelta.y * 0.0008))
        }
    }

    // --- Overlay informativo ---
    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 2

        Row {
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: nube.modo === "pca"
                      ? "Proyección: PCA (3 componentes)"
                      : "Proyección: dims " + JSON.stringify(nube.dimensiones)
                color: Style.Theme.texto_primario
                font.pixelSize: 11
                font.bold: true
            }
            ConceptHelpButton {
                conceptId: "pca_projection"
                controlSize: 24
                onHelpRequested: function(conceptId) { nube.helpRequested(conceptId) }
            }
        }
        Row {
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Varianza conservada: " + Math.round(nube.varianzaConservada * 1000)/10 + "%"
                color: nube.varianzaConservada < 0.25 ? "#C77B21" : "#4A7C4E"
                font.pixelSize: 11
            }
            ConceptHelpButton {
                conceptId: "explained_variance"
                controlSize: 24
                onHelpRequested: function(conceptId) { nube.helpRequested(conceptId) }
            }
        }
        Text {
            // Advertencia honesta: la proyeccion es contractiva, asi que
            // "cerca en pantalla" NO implica "cerca en el espacio real".
            visible: nube.varianzaConservada < 0.25
            text: "Vista parcial: los puntos cercanos pueden estar lejos en\nlas dimensiones no mostradas."
            color: "#C77B21"
            font.pixelSize: 9
        }
        Text {
            text: nube.puntos.length + " tokens"
            color: "#8A8A9A"
            font.pixelSize: 10
        }
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        text: "Arrastrar: rotar · Rueda: zoom"
        color: "#A5A2BB"
        font.pixelSize: 9
    }
}
