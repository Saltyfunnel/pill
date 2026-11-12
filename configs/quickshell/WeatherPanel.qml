// WeatherPanel.qml — the dashboard's Weather tab: current conditions, details, 3-day forecast.
// Left: a "now" card over a details card. Right: forecast cards that stretch to fill the height.
import QtQuick

DashPanel {
  Text {
    visible: !Weather.loaded
    anchors.centerIn: parent
    text: Weather.failed ? "Weather unavailable (check your network)" : "Loading weather..."
    color: Colors.subtext
    font.family: Theme.font
    font.pixelSize: 15
  }

  Row {
    visible: Weather.loaded
    anchors.fill: parent
    anchors.margins: 20
    spacing: 16

    // =================== left: now + details ===================
    Column {
      width: (parent.width - parent.spacing) / 2
      height: parent.height
      spacing: 16

      // ----- now card -----
      Rectangle {
        id: nowCard
        width: parent.width
        height: 140
        radius: Theme.radiusSm
        color: Colors.surface

        Row {
  anchors.left: parent.left
  anchors.right: parent.right
  anchors.margins: 20
  anchors.verticalCenter: parent.verticalCenter
  spacing: 16

  Text {
    id: nowIcon
    text: Weather.icon
    color: Colors.accent
    font.family: Theme.font
    font.pixelSize: 60
    anchors.verticalCenter: parent.verticalCenter
  }
  Column {
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width - nowIcon.width - parent.spacing
    spacing: 3

    Text {
      text: Weather.tempC + "°C"
      color: Colors.text
      font.family: Theme.font
      font.pixelSize: 40
      font.bold: true
    }
    Text {
      width: parent.width
      text: Weather.desc
      elide: Text.ElideRight
      color: Colors.subtext
      font.family: Theme.font
      font.pixelSize: 13
    }
    Text {
      width: parent.width
      text: "feels like " + Weather.feelsC + "°  ·  " + Config.weatherTown
      elide: Text.ElideRight
      color: Colors.subtext
      font.family: Theme.font
      font.pixelSize: 12
      opacity: 0.7
    }
  }
}
      }

      // ----- details card (fills the rest of the column) -----
      Rectangle {
        width: parent.width
        height: parent.height - nowCard.height - parent.spacing
        radius: Theme.radiusSm
        color: Colors.surface

        Column {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 20
          anchors.verticalCenter: parent.verticalCenter
          spacing: 12

          InfoRow { label: "Humidity";      value: Weather.humidity + "%" }
          InfoRow { label: "Wind";          value: Weather.windMph + " mph " + Weather.windDir }
          InfoRow { label: "Pressure";      value: Weather.pressure + " mb" }
          InfoRow { label: "UV index";      value: Weather.uv }
          InfoRow { label: "Precipitation"; value: Weather.precipMm + " mm" }
        }
      }
    }

    // =================== right: forecast ===================
    Column {
      width: (parent.width - parent.spacing) / 2
      height: parent.height
      spacing: 16

      Repeater {
        id: forecastRepeater
        model: Weather.forecast

        Rectangle {
          required property var modelData
          width: parent.width
          // split the column height evenly between the days
          height: (parent.height - parent.spacing * (forecastRepeater.count - 1)) / Math.max(1, forecastRepeater.count)
          radius: Theme.radiusSm
          color: Colors.surface

          Row {
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18

            Text {
              width: 96
              text: modelData.label
              color: Colors.text
              font.family: Theme.font
              font.pixelSize: 15
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: Weather.iconFor(modelData.code, false)
              color: Colors.accent
              font.family: Theme.font
              font.pixelSize: 36
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Text {
            anchors.right: parent.right
            anchors.rightMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.maxC + "°  /  " + modelData.minC + "°"
            color: Colors.subtext
            font.family: Theme.font
            font.pixelSize: 15
          }
        }
      }
    }
  }
}
