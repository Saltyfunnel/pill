// DashWeather.qml — small weather card: icon, temperature, description, "feels like".
import QtQuick

DashPanel {
  Text {
    visible: !Weather.loaded
    anchors.centerIn: parent
    text: Weather.failed ? "Weather unavailable" : "Loading weather..."
    color: Colors.subtext
    font.family: Theme.font
    font.pixelSize: 13
  }

  Row {
    visible: Weather.loaded
    anchors.centerIn: parent
    spacing: 16

    Text {
      text: Weather.icon
      color: Colors.accent
      font.family: Theme.font
      font.pixelSize: 44
      anchors.verticalCenter: parent.verticalCenter
    }
    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2
      Text {
        text: Weather.tempC + "°C"
        color: Colors.text
        font.family: Theme.font
        font.pixelSize: 26
        font.bold: true
      }
      Text {
        text: Weather.desc
        color: Colors.subtext
        font.family: Theme.font
        font.pixelSize: 12
      }
    }
  }
}
