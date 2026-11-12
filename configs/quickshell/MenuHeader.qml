// MenuHeader.qml — icon + bold title at the top of a card.
import QtQuick

Row {
  property string icon: ""
  property string title: ""

  width: parent ? parent.width : 200
  height: 30
  spacing: 10

  Text {
    text: parent.icon
    color: Colors.accent
    font.family: "Hack Nerd Font"
    font.pixelSize: 18
    anchors.verticalCenter: parent.verticalCenter
  }
  Text {
    text: parent.title
    color: Colors.text
    font.family: "Hack Nerd Font"
    font.pixelSize: 16
    font.bold: true
    anchors.verticalCenter: parent.verticalCenter
  }
}
