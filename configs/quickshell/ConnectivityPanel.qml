// ConnectivityPanel.qml — the dashboard's Connectivity tab: a network card and a Bluetooth card.
import QtQuick

DashPanel {
  Row {
    anchors.fill: parent
    anchors.margins: 20
    spacing: 16

    // =================== network card ===================
    Rectangle {
      width: (parent.width - parent.spacing) / 2
      height: parent.height
      radius: Theme.radiusSm
      color: Colors.surface

      Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        // header: icon, connection name, type + IP
        Row {
          spacing: 14

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: !Connectivity.connected ? "\udb81\uddaa" : (Connectivity.isWifi ? "\udb81\udda9" : "\udb80\ude00")
            color: Connectivity.connected ? Colors.accent : Colors.subtext
            font.family: "Hack Nerd Font"
            font.pixelSize: 34
          }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
              text: Connectivity.connected ? Connectivity.connName : "Not connected"
              color: Colors.text
              font.family: Theme.font
              font.pixelSize: 15
              font.bold: true
            }
            Text {
              visible: Connectivity.connected
              text: (Connectivity.isWifi ? "Wi-Fi" : "Wired") + (Connectivity.ip !== "" ? "  \u00b7  " + Connectivity.ip : "")
              color: Colors.subtext
              font.family: Theme.font
              font.pixelSize: 12
            }
          }
        }

        MenuDivider { visible: Connectivity.hasWifi }

        Text {
          visible: Connectivity.hasWifi
          text: "Wi-Fi networks"
          color: Colors.subtext
          font.family: Theme.font
          font.pixelSize: 12
        }
        Text {
          visible: Connectivity.hasWifi && Connectivity.accessPoints.length === 0
          text: "Scanning..."
          color: Colors.subtext
          font.family: Theme.font
          font.pixelSize: 13
        }

        // scrollable list: fills the space left under the header
        ListView {
          id: wifiList
          visible: Connectivity.hasWifi
          width: parent.width
          height: Math.max(0, parent.height - y)
          clip: true
          spacing: 4
          boundsBehavior: Flickable.StopAtBounds
          model: Connectivity.hasWifi ? Connectivity.accessPoints : []

          delegate: MenuRow {
            required property var modelData
            width: wifiList.width
            icon: "\udb81\udda9"
            iconColor: modelData.active ? Colors.accent : Colors.subtext
            label: modelData.ssid + (modelData.secure ? "  \udb80\udf3e" : "") + "   " + modelData.signal + "%"
            onClicked: Connectivity.connectTo(modelData)
          }
        }
      }
    }

    // =================== bluetooth card ===================
    Rectangle {
      id: btCard
      width: (parent.width - parent.spacing) / 2
      height: parent.height
      radius: Theme.radiusSm
      color: Colors.surface

      readonly property int connectedCount: Connectivity.devices.filter(d => d.connected).length

      Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        // header: icon, title, status, on/off switch
        Item {
          width: parent.width
          height: 44

          Row {
            spacing: 14
            anchors.verticalCenter: parent.verticalCenter

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: !Connectivity.powered ? "\udb80\udcb2" : (btCard.connectedCount > 0 ? "\udb80\udcb1" : "\udb80\udcaf")
              color: Connectivity.powered ? Colors.accent : Colors.subtext
              font.family: "Hack Nerd Font"
              font.pixelSize: 34
            }
            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2
              Text {
                text: "Bluetooth"
                color: Colors.text
                font.family: Theme.font
                font.pixelSize: 15
                font.bold: true
              }
              Text {
                text: !Connectivity.hasAdapter ? "No adapter found"
                      : !Connectivity.powered ? "Off"
                      : (btCard.connectedCount > 0
                         ? btCard.connectedCount + " connected" : "On")
                color: Colors.subtext
                font.family: Theme.font
                font.pixelSize: 12
              }
            }
          }

          // on/off switch
          Rectangle {
            visible: Connectivity.hasAdapter
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 46; height: 26; radius: 13
            color: Connectivity.powered ? Colors.accent : Colors.track
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Rectangle {
              width: 20; height: 20; radius: 10
              y: 3
              x: Connectivity.powered ? parent.width - width - 3 : 3
              color: Connectivity.powered ? Colors.surface : Colors.subtext
              Behavior on x { NumberAnimation { duration: Theme.animFast } }
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: Connectivity.runBt(["bluetoothctl", "power", Connectivity.powered ? "off" : "on"])
            }
          }
        }

        MenuDivider { visible: Connectivity.hasAdapter && Connectivity.powered }

        Text {
          visible: Connectivity.hasAdapter && Connectivity.powered && Connectivity.devices.length === 0
          text: "No paired devices"
          color: Colors.subtext
          font.family: Theme.font
          font.pixelSize: 13
        }

        // scrollable list of paired devices
        ListView {
          id: btList
          visible: Connectivity.hasAdapter && Connectivity.powered
          width: parent.width
          height: Math.max(0, parent.height - y)
          clip: true
          spacing: 4
          boundsBehavior: Flickable.StopAtBounds
          model: (Connectivity.hasAdapter && Connectivity.powered) ? Connectivity.devices : []

          delegate: MenuRow {
            required property var modelData
            width: btList.width
            icon: modelData.connected ? "\udb80\udcb1" : "\udb80\udcaf"
            iconColor: modelData.connected ? Colors.accent : Colors.subtext
            label: modelData.name + (modelData.connected ? "   connected" : "")
            onClicked: Connectivity.runBt(["bluetoothctl", modelData.connected ? "disconnect" : "connect", modelData.mac])
          }
        }
      }
    }
  }
}
