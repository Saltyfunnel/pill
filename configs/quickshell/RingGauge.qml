// RingGauge.qml — a circular gauge: ring that fills with `fraction`, value in the middle,
// a bold title and a dimmer detail line under it. Turns red above 85%.
import QtQuick

Item {
  id: root

  property real fraction: 0          // 0..1
  property string valueText: ""
  property string title: ""          // e.g. "Memory"
  property string detail: ""         // e.g. "2.2 / 15.3 GB" (may be empty)
  property color ringColor: Colors.accent
  property int size: 104

  width: size
  height: size + 52                  // fixed, so every ring lines up even with no detail

  // animated copy of fraction, so the ring glides instead of jumping
  property real shown: Math.max(0, Math.min(1, fraction))
  Behavior on shown { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
  onShownChanged: canvas.requestPaint()
  onRingColorChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    width: root.size
    height: root.size
    anchors.horizontalCenter: parent.horizontalCenter

    onPaint: {
      const ctx = getContext("2d")
      ctx.reset()
      const cx = width / 2, cy = height / 2
      const r = width / 2 - 8
      ctx.lineWidth = 9
      ctx.lineCap = "round"

      ctx.strokeStyle = Colors.track
      ctx.beginPath()
      ctx.arc(cx, cy, r, 0, 2 * Math.PI)
      ctx.stroke()

      if (root.shown > 0.01) {
        ctx.strokeStyle = root.shown > 0.85 ? "#FF5555" : root.ringColor
        ctx.beginPath()
        ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + root.shown * 2 * Math.PI)
        ctx.stroke()
      }
    }
    Component.onCompleted: requestPaint()
  }

  Text {
    anchors.centerIn: canvas
    text: root.valueText
    color: Colors.text
    font.family: Theme.font
    font.pixelSize: 20
    font.bold: true
  }

  Column {
    anchors.top: canvas.bottom
    anchors.topMargin: 12
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 3

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      horizontalAlignment: Text.AlignHCenter
      text: root.title
      color: Colors.text
      font.family: Theme.font
      font.pixelSize: 14
      font.bold: true
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      horizontalAlignment: Text.AlignHCenter
      visible: root.detail !== ""
      text: root.detail
      color: Colors.subtext
      font.family: Theme.font
      font.pixelSize: 12
    }
  }
}
