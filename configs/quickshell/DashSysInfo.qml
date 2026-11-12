// DashSysInfo.qml — avatar (~/.face) plus distro, window manager and uptime,
// on top of the current wallpaper.
import Quickshell
import Quickshell.Io
import QtQuick

DashPanel {
  id: root

  property string distro: "Linux"
  property real uptimeSec: 0
  property string wallpaper: ""
  readonly property string wm: Quickshell.env("XDG_CURRENT_DESKTOP") || "Hyprland"

  function fmtUptime(s) {
    const m = Math.floor(s / 60)
    const h = Math.floor(m / 60)
    const d = Math.floor(h / 24)
    if (d > 0) return d + "d " + (h % 24) + "h"
    if (h > 0) return h + "h " + (m % 60) + "m"
    return m + " min"
  }

  FileView {
    id: osFile
    path: "/etc/os-release"
    onLoaded: {
      const m = text().match(/^PRETTY_NAME="?([^"\n]*)"?/m)
      root.distro = m ? m[1] : "Linux"
    }
  }
  FileView {
    id: upFile
    path: "/proc/uptime"
    onLoaded: root.uptimeSec = Number(text().split(" ")[0])
  }
  // current wallpaper path, written by setwall.sh
  FileView {
    id: wallFile
    path: Quickshell.env("HOME") + "/.cache/current_wallpaper"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.wallpaper = text().trim()
  }
  Timer {
    running: true
    interval: 30000
    repeat: true
    triggeredOnStart: true
    onTriggered: { upFile.reload(); osFile.reload() }
  }

  // one icon + text line
  component InfoLine: Row {
    property string icon: ""
    property string label: ""
    spacing: 10
    Text {
      text: icon
      color: Colors.accent
      font.family: Theme.font
      font.pixelSize: 15
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: label
      color: Colors.text
      font.family: Theme.font
      font.pixelSize: 13
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
      width: 120
    }
  }

  // ---------- background: the current wallpaper, darkened ----------
  RoundedImage {
    anchors.fill: parent
    radius: 16               // match your DashPanel's corner radius
    decodeWidth: 600
    source: root.wallpaper !== "" ? "file://" + root.wallpaper : ""
  }
  Rectangle {
    anchors.fill: parent
    radius: 16
    color: Colors.card
    opacity: 0.55            // lower = more wallpaper, higher = crisper text
  }

  Row {
    anchors.fill: parent
    anchors.margins: 14
    spacing: 14

    // avatar: your ~/.face picture, or a placeholder if there isn't one
    Item {
      width: 56
      height: 56
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.fill: parent
        radius: 28
        color: Colors.track
        Text {
          anchors.centerIn: parent
          text: "󰣇"
          color: Colors.subtext
          font.family: Theme.font
          font.pixelSize: 24
        }
      }
      RoundedImage {
        anchors.fill: parent
        radius: 28
        source: "file://" + Quickshell.env("HOME") + "/.face"
      }
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 10

      InfoLine { icon: "󰣇"; label: root.distro }
      InfoLine { icon: "󱂬"; label: root.wm }
      InfoLine { icon: "󰔟"; label: "up " + root.fmtUptime(root.uptimeSec) }
    }
  }
}
