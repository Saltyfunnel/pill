// WindowTitle.qml — title of the focused window.
import Quickshell.Hyprland
import QtQuick

Text {
  text: Hyprland.activeToplevel?.title ?? ""
  color: Colors.subtext
  font.family: "Hack Nerd Font"
  font.pixelSize: 13
  elide: Text.ElideRight
  width: Math.min(implicitWidth, 320)
}
