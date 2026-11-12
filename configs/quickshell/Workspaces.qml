// Workspaces.qml — five dots; the active one stretches into a pill.
import Quickshell.Hyprland
import QtQuick

Row {
  spacing: 6

  Repeater {
    model: 5

    Rectangle {
      required property int index
      property int wsId: index + 1
      property bool active: Hyprland.focusedWorkspace?.id === wsId

      width: active ? 28 : 10
      height: 10
      radius: 5
      anchors.verticalCenter: parent.verticalCenter
      color: active ? Colors.accent : Colors.track

      Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: 200 } }

      MouseArea {
        anchors.fill: parent
        // Hyprland 0.55+ Lua dispatch syntax. On an older (non-Lua) Hyprland use:
        //   Hyprland.dispatch("workspace " + wsId)
        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsId + " })")
      }
    }
  }
}
