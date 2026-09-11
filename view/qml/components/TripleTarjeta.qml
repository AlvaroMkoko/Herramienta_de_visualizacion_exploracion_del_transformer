import QtQuick
import QtQuick.Controls
import "../styles" as Style

    
Rectangle{
    color:"blue"
    Rectangle {
        property real sx: 1.0
        property real sy: 1.0

        // x: 200 * sx
        // y: 550 * sy
        // width: 350 * sx
        // height: 
        implicitWidth: 350 * sx
        implicitHeight: 350 * sy
        radius: 10 * sx
        Style.Theme.surface
        border.color: Style.Theme.borde_cuadro
    }

}



