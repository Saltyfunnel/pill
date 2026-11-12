// TrayModule.qml — system tray icons for apps that live in the tray (Steam, Discord, LocalSend, ...).
//   Left click   : activate the app (or open its menu if it only has a menu)
//   Middle click : secondary action
//   Right click  : the app's own menu
// The whole thing is hidden while nothing is in the tray (see `active`).
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick

Row {
  id: root

  readonly property bool active: SystemTray.items.values.length > 0
  spacing: 10

  Repeater {
    model: SystemTray.items

    MouseArea {
      id: slot
      required property var modelData

      width: 18
      height: 18
      anchors.verticalCenter: parent.verticalCenter
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

      onClicked: mouse => {
        if (mouse.button === Qt.LeftButton && !slot.modelData.onlyMenu) {
          slot.modelData.activate()
        } else if (mouse.button === Qt.MiddleButton) {
          slot.modelData.secondaryActivate()
        } else if (slot.modelData.hasMenu) {
          menu.open()
        }
      }

      IconImage {
        anchors.fill: parent
        source: slot.modelData.icon
        opacity: slot.containsMouse ? 1.0 : 0.8
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
      }

      QsMenuAnchor {
        id: menu
        menu: slot.modelData.menu
        anchor.item: slot
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
      }
    }
  }
}
