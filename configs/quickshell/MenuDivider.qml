// MenuDivider.qml — a faint horizontal line between groups of rows.
import QtQuick

Item {
  width: parent ? parent.width : 200
  height: 6

  Rectangle {
    anchors.centerIn: parent
    width: parent.width
    height: 1
    color: Colors.accent
    opacity: 0.2
  }
}
