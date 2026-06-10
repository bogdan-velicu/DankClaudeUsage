import QtQuick
import qs.Common

Item {
    id: root

    property int percentage: 0
    property color ringColor: Theme.primary
    property color trackColor: Theme.surfaceVariant
    property bool hollow: false
    property string label: ""
    property real thickness: 3
    property int diameter: 22

    implicitWidth: diameter
    implicitHeight: hollow ? diameter + labelText.implicitHeight + 2 : diameter

    Canvas {
        id: canvas
        width: root.diameter
        height: root.diameter
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const cx = width / 2
            const cy = height / 2
            const r = (Math.min(width, height) - root.thickness) / 2
            const start = -Math.PI / 2
            const frac = Math.max(0, Math.min(1, root.percentage / 100))

            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
            ctx.lineWidth = root.thickness
            ctx.strokeStyle = root.trackColor
            ctx.stroke()

            if (frac > 0) {
                ctx.beginPath()
                ctx.arc(cx, cy, r, start, start + frac * 2 * Math.PI)
                ctx.lineWidth = root.thickness
                ctx.lineCap = "round"
                ctx.strokeStyle = root.ringColor
                ctx.stroke()
            }
        }

        Connections {
            target: root
            function onPercentageChanged() { canvas.requestPaint() }
            function onRingColorChanged() { canvas.requestPaint() }
            function onTrackColorChanged() { canvas.requestPaint() }
        }
    }

    StyledText {
        id: centerText
        visible: !root.hollow
        anchors.centerIn: canvas
        text: root.percentage + "%"
        font.pixelSize: Math.round(root.diameter * 0.34)
        color: Theme.surfaceText
    }

    StyledText {
        id: labelText
        visible: root.hollow
        anchors.top: canvas.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: canvas.horizontalCenter
        text: root.percentage + "%"
        font.pixelSize: Math.round(root.diameter * 0.32)
        color: Theme.surfaceText
    }
}
