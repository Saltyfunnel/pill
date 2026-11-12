// PowerView.qml — Session card content, hosted inside the morphing pill.
// Logout, reboot and shutdown need a second click to confirm.
import Quickshell
import QtQuick

Item {
  id: root

  signal closeRequested()

  // matches the old card: 260 x 330
  implicitWidth: 260
  implicitHeight: 330

  readonly property color danger: "#FF5555"

  // which destructive action is waiting for its confirming click ("" = none)
  property string pending: ""

  Timer {
    id: confirmTimer
    interval: 3000
    onTriggered: root.pending = ""
  }

  // run a shell command, then close the pill
  function run(cmd) {
    Quickshell.execDetached(["sh", "-c", cmd])
    root.closeRequested()
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
