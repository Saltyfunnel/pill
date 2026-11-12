// MenuRow.qml — one clickable row: icon + label, highlights on hover.
// Use inside a Column:   MenuRow { icon: "..."; label: "Lock"; onClicked: ... }
import QtQuick

Rectangle {
  id: row

  property string icon: ""
  property string label: ""
  property color iconColor: Colors.accent
  signal clicked()

  width: parent ? parent.width : 200
  height: 38
  radius: 10
  color: mouse.containsMouse ? Colors.card : "transparent"
  Behavior on color { ColorAnimation { duration: 100 } }

  Row {
    anchors.fill: parent
    anchors.leftMargin: 12
    anchors.rightMargin: 12
    spacing: 14

    Text {
      text: row.icon
      color: row.iconColor
      font.family: "Hack Nerd Font"
      font.pixelSize: 16
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: row.label
      color: Colors.text
      font.family: "Hack Nerd Font"
      font.pixelSize: 13
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: row.clicked()
  }
}
