// Stat.qml — one icon + value pair. Used by Hardware.qml.
import QtQuick

Row {
  property string icon: ""
  property string value: ""
  property color tint: Colors.accent

  spacing: 5

  Text {
    text: icon
    color: tint
    font.family: "Hack Nerd Font"
    font.pixelSize: 14
    anchors.verticalCenter: parent.verticalCenter
  }
  Text {
    text: value
    color: Colors.text
    font.family: "Hack Nerd Font"
    font.pixelSize: 13
    anchors.verticalCenter: parent.verticalCenter
  }
}
