// Clock.qml — time + date. Later: click it to open a calendar card.
import Quickshell
import QtQuick

Row {
  spacing: 10

  SystemClock { id: clock; precision: SystemClock.Minutes }

  Text {
    text: Qt.formatDateTime(clock.date, "HH:mm")
    color: Colors.text
    font.family: "Hack Nerd Font"
    font.pixelSize: 14
    font.bold: true
  }
  Text {
    text: Qt.formatDateTime(clock.date, "ddd d MMM")
    color: Colors.subtext
    font.family: "Hack Nerd Font"
    font.pixelSize: 13
  }
}
