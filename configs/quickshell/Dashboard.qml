// Dashboard.qml — the clock in the bar; click it for a tabbed dashboard popup.
//   Dashboard : system info on top; clock, calendar, mixer and media card below
//   Media     : big now-playing view
//   Performance : CPU / memory charts, disk, temperatures, battery
//   Weather   : current conditions and a 3-day forecast (town set in Config.qml)
//   Connectivity : network + Wi-Fi list, Bluetooth devices
//   Capture   : screenshots and screen recording
//
// The tab row also shows a pill with the pending pacman update count (click to update).
//
// Other bar modules can open a specific tab with  dashboard.openTab(n)
//   0 Dashboard, 1 Media, 2 Performance, 3 Weather, 4 Connectivity, 5 Capture
import Quickshell
import QtQuick

Item {
  id: root

  property string popupName: "dashboard"
  property string openPopup: ""
  signal toggle(string name)
  property alias popup: card        // shell.qml's focus grab uses this

  property int tab: 0
  property int requestedTab: 0      // the tab the popup opens on next time
  readonly property var tabNames: ["Dashboard", "Media", "Performance", "Weather", "Connectivity", "Capture"]

  // tell Connectivity.qml when its tab is on screen, so it only scans Wi-Fi then
  readonly property bool connectivityShowing: openPopup === popupName && tab === 4
  onConnectivityShowingChanged: Connectivity.scanning = connectivityShowing

  // Open the dashboard on a given tab. If it's already open, just switch tab.
  function openTab(n) {
    root.requestedTab = n
    if (root.openPopup === root.popupName) root.tab = n
    else root.toggle(root.popupName)
  }

  implicitWidth: barClock.implicitWidth
  implicitHeight: barClock.implicitHeight

  // ---------- bar item: the clock ----------
  Clock { id: barClock }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.requestedTab = 0; root.toggle(root.popupName) }
  }

  // ---------- the popup, centred under the clock ----------
  PopupWindow {
    id: card
    anchor.item: root
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    visible: root.openPopup === root.popupName
    implicitWidth: 780
    implicitHeight: 440
    color: "transparent"

    onVisibleChanged: if (visible) { root.tab = root.requestedTab; calendar.reset() }

    Rectangle {
      anchors.fill: parent
      anchors.topMargin: 8
      radius: Theme.radiusLg
      color: Qt.alpha(Colors.surface, 0.9)

      Column {
        anchors.fill: parent
        anchors.margins: Theme.pad
        spacing: Theme.gap

        // ----- tab bar (tabs on the left, updates pill on the right) -----
        Item {
          id: tabBar
          width: parent.width
          height: 30

          Row {
            spacing: 6

            Repeater {
              model: root.tabNames

              Rectangle {
                required property string modelData
                required property int index
                readonly property bool active: root.tab === index

                width: tabText.implicitWidth + 28
                height: 30
                radius: 15
                color: active ? Colors.accent : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                  id: tabText
                  anchors.centerIn: parent
                  text: modelData
                  color: active ? Colors.surface : Colors.subtext
                  font.family: Theme.font
                  font.pixelSize: 13
                  font.bold: active
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.tab = index
                }
              }
            }
          }

          // updates pill: only shown when something is pending; click to update
          Rectangle {
            visible: Updates.total > 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 26
            width: pillRow.implicitWidth + 20
            radius: 13
            color: "transparent"
            border.width: 1
            border.color: Colors.accent

            Row {
              id: pillRow
              anchors.centerIn: parent
              spacing: 6
              Text {
                text: "󰚰"
                color: Colors.accent
                font.family: Theme.font
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: Updates.total + (Updates.total === 1 ? " update" : " updates")
                color: Colors.text
                font.family: Theme.font
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.toggle(root.popupName); Updates.upgrade() }
            }
          }
        }

        // ----- pages -----
        Item {
          width: parent.width
          height: parent.height - tabBar.height - Theme.gap

          // Dashboard: top row, then clock + calendar + mixer + media
          Column {
            visible: root.tab === 0
            anchors.fill: parent
            spacing: Theme.gap

            Row {
              width: parent.width
              height: 96
              spacing: Theme.gap

              DashWeather { width: 260; height: parent.height }
              DashSysInfo { width: parent.width - 260 - Theme.gap; height: parent.height }
            }

            Row {
              width: parent.width
              height: parent.height - 96 - Theme.gap
              spacing: Theme.gap

              DashClock { width: 64; height: parent.height }
              DashCalendar { id: calendar; width: 280; height: parent.height }
              MixerPanel { width: 84; height: parent.height }
              DashMedia { width: parent.width - 64 - 280 - 84 - 3 * Theme.gap; height: parent.height }
            }
          }

          MediaPanel { visible: root.tab === 1; anchors.fill: parent }

          PerformancePanel { visible: root.tab === 2; anchors.fill: parent }

          WeatherPanel { visible: root.tab === 3; anchors.fill: parent }

          ConnectivityPanel { visible: root.tab === 4; anchors.fill: parent }

          CapturePanel {
            visible: root.tab === 5
            anchors.fill: parent
            onCloseRequested: root.toggle(root.popupName)
          }
        }
      }
    }
  }
}
