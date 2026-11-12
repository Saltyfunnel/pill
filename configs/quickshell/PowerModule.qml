// PowerModule.qml — bar icon + a Session card (lock / logout / suspend / reboot / shutdown).
// Built from the shared pieces: OverlayCard, MenuHeader, MenuDivider, MenuRow.
// Logout, reboot and shutdown need a second click to confirm.
import Quickshell
import QtQuick

Item {
  id: root

  property string popupName: "power"
  property string openPopup: ""
  signal toggle(string name)
  property alias popup: card        // shell.qml's focus grab uses this

  implicitWidth: 15
  implicitHeight: 24

  readonly property color danger: "#FF5555"

  // which destructive action is waiting for its confirming click ("" = none)
  property string pending: ""
  onOpenPopupChanged: pending = ""   // start fresh every time the card opens or closes

  Timer {
    id: confirmTimer
    interval: 3000
    onTriggered: root.pending = ""
  }

  // run a shell command, then close the menu
  function run(cmd) {
    Quickshell.execDetached(["sh", "-c", cmd])
    root.toggle(root.popupName)
  }

  // first click arms the action, second click (within 3s) runs it
  function confirmThenRun(key, cmd) {
    if (root.pending === key) {
      root.pending = ""
      root.run(cmd)
    } else {
      root.pending = key
      confirmTimer.restart()
    }
  }

  // ---------- bar icon ----------
  Text {
    anchors.centerIn: parent
    color: barMouse.containsMouse || card.shown ? Colors.text : Colors.accent
    font.family: "Hack Nerd Font"
    font.pixelSize: 15
    text: "󰐥"
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
  }

  // covers the whole 32x24 slot, so it's easier to hit than just the glyph
  MouseArea {
    id: barMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggle(root.popupName)
  }

  // ---------- the card ----------
  OverlayCard {
    id: card
    shown: root.openPopup === root.popupName
    cardWidth: 260
    cardHeight: 330
    onDismissed: root.toggle(root.popupName)

    Column {
      anchors.fill: parent
      anchors.margins: 20
      spacing: 10

      MenuHeader { icon: "󰐥"; title: "Session" }
      MenuDivider {}

      MenuRow { icon: "󰌾"; label: "Lock";    onClicked: root.run("pidof hyprlock || hyprlock") }
      MenuRow { icon: "󰤄"; label: "Suspend"; onClicked: root.run("systemctl suspend") }

      MenuDivider {}

      // Hyprland 0.55+ Lua syntax. If this ever fails, the blunt alternative is:
      //   root.run("loginctl terminate-user $USER")
      MenuRow {
        icon: "󰍃"
        label: root.pending === "logout" ? "Confirm logout" : "Logout"
        iconColor: root.pending === "logout" ? root.danger : Colors.accent
        onClicked: root.confirmThenRun("logout", "hyprctl dispatch 'hl.dsp.exit()'")
      }
      MenuRow {
        icon: "󰜉"
        label: root.pending === "reboot" ? "Confirm reboot" : "Reboot"
        iconColor: root.pending === "reboot" ? root.danger : Colors.accent
        onClicked: root.confirmThenRun("reboot", "systemctl reboot")
      }
      MenuRow {
        icon: "󰐥"
        label: root.pending === "poweroff" ? "Confirm shutdown" : "Shutdown"
        iconColor: root.pending === "poweroff" ? root.danger : Colors.accent
        onClicked: root.confirmThenRun("poweroff", "systemctl poweroff")
      }
    }
  }
}
