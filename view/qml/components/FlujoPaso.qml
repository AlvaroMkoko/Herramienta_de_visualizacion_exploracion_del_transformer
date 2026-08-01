

import QtQuick
import QtQuick.Layouts

import "../styles" as Style
import QtQuick.Layouts


import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    // Propiedades públicas
    property string title: ""
    property string state: "pending"

    // Escala recibida del padre
    property real scale: 1.0

    Layout.fillWidth: true
    implicitHeight: 34 * scale

    spacing: 12 * scale

    readonly property color indicatorColor: {
        switch(state) {
        case "done":
            return "#5A56C9"
        case "running":
            return "#C58B2B"
        case "error":
            return "#E53935"
        default:
            return "#F4F3FF"
        }
    }

    readonly property color indicatorBorder: {
        return state === "pending"
                ? "#C9C5F5"
                : "transparent"
    }

    readonly property color indicatorTextColor: {
        return state === "pending"
                ? "#B0A8EE"
                : "white"
    }

    readonly property color titleColor: {
        switch(state) {
        case "running":
            return "#C58B2B"
        case "pending":
            return "#B0B0B0"
        case "error":
            return "#E53935"
        default:
            return "#555555"
        }
    }

    readonly property string icon: {
        switch(state) {
        case "done":
            return "✓"
        case "running":
            return "!"
        case "error":
            return "✕"
        default:
            return "•"
        }
    }

    Rectangle {

        Layout.preferredWidth: 28 * scale
        Layout.preferredHeight: 28 * scale

        radius: width / 2

        color: indicatorColor

        border.width: state === "pending" ? 1 : 0
        border.color: indicatorBorder

        Text {

            anchors.centerIn: parent

            text: icon

            color: indicatorTextColor

            font.bold: true
            font.pixelSize: parent.width * 0.55
        }
    }

    Text {

        Layout.fillWidth: true

        text: title

        color: titleColor

        font.bold: state === "running"

        font.pixelSize: 16 * scale

        verticalAlignment: Text.AlignVCenter

        elide: Text.ElideRight
    }
}