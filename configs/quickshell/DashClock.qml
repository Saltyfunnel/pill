// DashClock.qml — tall stacked clock: hours, three dots, minutes.
import Quickshell
import QtQuick

DashPanel {
  SystemClock { id: clk; precision: SystemClock.Minutes }

  Column {
    anchors.centerIn: parent
    spacing: 6

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDateTime(clk.date, "HH")
      color: Colors.text
      font.family: Theme.font
      font.pixelSize: 28
      font.bold: true
    }

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 4
      Repeater {
        model: 3
        Rectangle { width: 5; height: 5; radius: 2.5; color: Colors.accent }
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDateTime(clk.date, "mm")
      color: Colors.text
      font.family: Theme.font
      font.pixelSize: 28
      font.bold: true
    }
  }
}
