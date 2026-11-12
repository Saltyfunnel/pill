// Sparkline.qml — a small filled line chart of recent readings (newest on the right).
//   Sparkline { values: someArrayOf0to100; lineColor: Colors.accent }
import QtQuick

Item {
  id: root

  property var values: []            // numbers, oldest first
  property color lineColor: Colors.accent
  property real maxValue: 100
  property int points: 60            // how many samples fill the full width

  width: parent ? parent.width : 240
  height: 44

  onValuesChanged: canvas.requestPaint()
  onLineColorChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()

  // faint panel behind the chart
  Rectangle {
    anchors.fill: parent
    radius: 8
    color: Colors.track
    opacity: 0.35
  }

  Canvas {
    id: canvas
    anchors.fill: parent

    onPaint: {
      const ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)

      const n = root.values.length
      if (n < 2) return

      const step = width / (root.points - 1)
      const x0 = width - (n - 1) * step          // newest sample sits at the right edge
      const yOf = v => height - Math.max(0, Math.min(1, v / root.maxValue)) * (height - 4) - 2

      // soft fill under the line
      ctx.beginPath()
      ctx.moveTo(x0, height)
      for (let i = 0; i < n; i++) ctx.lineTo(x0 + i * step, yOf(root.values[i]))
      ctx.lineTo(x0 + (n - 1) * step, height)
      ctx.closePath()
      ctx.fillStyle = Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.2)
      ctx.fill()

      // the line itself
      ctx.beginPath()
      for (let i = 0; i < n; i++) {
        if (i === 0) ctx.moveTo(x0, yOf(root.values[0]))
        else ctx.lineTo(x0 + i * step, yOf(root.values[i]))
      }
      ctx.strokeStyle = root.lineColor
      ctx.lineWidth = 1.5
      ctx.stroke()
    }
  }
}
