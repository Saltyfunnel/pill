// ActionTile.qml — a big clickable tile: large icon on top, label underneath.
import QtQuick

Rectangle {
  id: root

  property string icon: ""
  property string label: ""
  property string sublabel: ""
  property color iconColor: Colors.accent
  property int iconSize: 30
  signal clicked()

  radius: Theme.radiusSm
  color: area.containsMouse ? Colors.track : Colors.surface
  Behavior on color { ColorAnimation { duration: Theme.animFast } }

  Column {
    anchors.centerIn: parent
    spacing: 8

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.icon
      color: root.iconColor
      font.family: "Hack Nerd Font"
      font.pixelSize: root.iconSize
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.label
      color: Colors.text
      font.family: Theme.font
      font.pixelSize: 13
    }
    Text {
      visible: root.sublabel !== ""
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.sublabel
      color: Colors.subtext
      font.family: Theme.font
      font.pixelSize: 11
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
