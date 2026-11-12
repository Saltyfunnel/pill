// DashPanel.qml — a rounded panel to sit inside a popup. Put anything inside it.
import QtQuick

Rectangle {
  default property alias content: holder.data

  radius: Theme.radiusMd
  color: Qt.tint(Colors.card, Qt.alpha(Colors.accent, 0.04))

  Item { id: holder; anchors.fill: parent }
}
