import QtQuick
import "../styles" as Style

Rectangle {
    id: root

    property int currentStep: 0
    property real sx: 1
    property real sy: 1
    property bool compact: false

    readonly property int totalSteps: 3
    readonly property int normalizedCurrentStep: Math.max(
        0, Math.min(currentStep, totalSteps - 1))
    readonly property var stepTitles: [
        "Configuración",
        "Entrenamiento",
        "Inferencia"
    ]
    readonly property string currentStepTitle: stepTitles[normalizedCurrentStep]

    implicitWidth: 760 * sx
    implicitHeight: Math.max(62, timeline.implicitHeight)
    radius: Style.Theme.radius * Math.min(sx, sy)
    color: Style.Theme.surface
    border.width: Math.max(1, Math.round(Math.min(sx, sy)))
    border.color: Style.Theme.divisor

    Accessible.role: Accessible.ProgressBar
    Accessible.name: "Progreso del laboratorio"
    Accessible.description: "Paso " + (normalizedCurrentStep + 1) + " de "
                            + totalSteps + ": " + currentStepTitle

    TimeLine {
        id: timeline
        objectName: root.objectName + "Timeline"
        anchors.fill: parent
        anchors.leftMargin: 20 * root.sx
        anchors.rightMargin: 20 * root.sx
        sx: root.sx
        sy: root.sy
        baseCircleSize: root.compact ? 30 : 34
        baseCircleSizeActive: root.compact ? 34 : 40
        baseFontSize: root.compact ? 13 : 15
        baseFontSizeActive: root.compact ? 14 : 16
        baseVerticalPadding: root.compact ? 4 : 6
        baseColumnSpacing: root.compact ? 4 : 6
        model: [
            {
                title: root.stepTitles[0],
                state: root.normalizedCurrentStep > 0 ? "done"
                                                     : "running"
            },
            {
                title: root.stepTitles[1],
                state: root.normalizedCurrentStep > 1 ? "done"
                      : (root.normalizedCurrentStep === 1 ? "running" : "pending")
            },
            {
                title: root.stepTitles[2],
                state: root.normalizedCurrentStep === 2 ? "running" : "pending"
            }
        ]
    }
}
