// StatBar.qml — a label, a value, and a thin progress bar. Used by Hardware.qml.
//   StatBar { label: "CPU"; valueText: "42%"; fraction: 0.42 }
import QtQuick

Column {
  property string label: ""
  property string valueText: ""
  property real fraction: 0
  property color barColor: Colors.accent

  width: parent ? parent.width : 240
  spacing: 5

  Item {
    width: parent.width
    height: 16

    Text {
      text: label
      color: Colors.subtext
      font.family: "Hack Nerd Font"
      font.pixelSize: 12
    }
    Text {
      anchors.right: parent.right
      text: valueText
      color: Colors.text
      font.family: "Hack Nerd Font"
      font.pixelSize: 12
      font.bold: true
    }
  }

  Rectangle {
    width: parent.width
    height: 6
    radius: 3
    color: Colors.track

    Rectangle {
      width: parent.width * Math.max(0, Math.min(1, fraction))
      height: parent.height
      radius: 3
      color: barColor
      Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    }
  }
}
