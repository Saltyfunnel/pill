// InfoRow.qml — a label on the left, a value on the right. Used by Network.qml.
import QtQuick

Item {
  property string label: ""
  property string value: ""

  width: parent ? parent.width : 240
  height: 18

  Text {
    text: label
    color: Colors.subtext
    font.family: "Hack Nerd Font"
    font.pixelSize: 12
  }
  Text {
    anchors.right: parent.right
    width: Math.min(implicitWidth, parent.width - 90)
    horizontalAlignment: Text.AlignRight
    elide: Text.ElideRight
    text: value
    color: Colors.text
    font.family: "Hack Nerd Font"
    font.pixelSize: 12
    font.bold: true
  }
}
