// WallpaperView.qml — minimal wallpaper strip, hosted inside the morphing pill.
//   Left / Right (or the mouse wheel) move along the strip, Enter or a click on the selected one applies it.
//   Just start typing to filter by name. Tab picks a random one. Esc closes.
//   Applying hands the path to setwall.sh, which recolours everything.
import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  signal closeRequested()

  implicitWidth: 720
  implicitHeight: 172

  property string homeDir: Quickshell.env("HOME")
  property string wallpaperDir: homeDir + "/Pictures/Wallpapers"
  property string searchQuery: ""

  // every wallpaper found: [{ path, name }]
  property var all: []
  // the ones matching the search
  property var results: {
    const q = root.searchQuery
    if (q === "") return root.all
    return root.all.filter(w => w.name.toLowerCase().includes(q))
  }
  property var current: strip.currentIndex >= 0 && strip.currentIndex < results.length ? results[strip.currentIndex] : null

  Component.onCompleted: {
    strip.currentIndex = 0
    Qt.callLater(searchField.forceActiveFocus)
  }

  function apply(w) {
    if (!w) return
    Quickshell.execDetached([
      "sh", "-c",
      "export PATH=\"$PATH:" + root.homeDir + "/.cargo/bin\"; " +
      "export HYPRLAND_INSTANCE_SIGNATURE=\"" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "\"; " +
      "\"" + root.homeDir + "/.config/scripts/setwall.sh\" \"" + w.path + "\""
    ])
    root.closeRequested()
  }

  // ---------- scanning the wallpaper folder (runs once each time the view opens) ----------
  Process {
    id: loadWallpapers
    command: ["sh", "-c", "find \"" + root.wallpaperDir + "\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.jpeg' \\) | sort"]
    running: true
    stdout: SplitParser {
      onRead: data => {
        const path = data.trim()
        if (path !== "") root.all = root.all.concat([{ path: path, name: path.split("/").pop() }])
      }
    }
  }

  // Invisible input that just catches typing, so the filter needs no visible field
  TextInput {
    id: searchField
    width: 1
    height: 1
    opacity: 0
    color: Colors.text

    onTextChanged: {
      root.searchQuery = text.trim().toLowerCase()
      strip.currentIndex = 0
    }
    Keys.onEscapePressed: root.closeRequested()
    Keys.onReturnPressed: root.apply(root.current)
    Keys.onEnterPressed: root.apply(root.current)
    // Left / Right move along the strip, unless you are editing a search
    Keys.onLeftPressed: event => { if (text === "") strip.decrementCurrentIndex(); else event.accepted = false }
    Keys.onRightPressed: event => { if (text === "") strip.incrementCurrentIndex(); else event.accepted = false }
    // Tab jumps to a random wallpaper
    Keys.onTabPressed: event => {
      if (root.results.length > 0)
        strip.currentIndex = Math.floor(Math.random() * root.results.length)
      event.accepted = true
    }
  }

  // Mouse wheel / touchpad anywhere across the view
  WheelHandler {
    property real acc: 0
    onWheel: event => {
      const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
      acc += delta
      while (acc >= 120)  { strip.decrementCurrentIndex(); acc -= 120 }
      while (acc <= -120) { strip.incrementCurrentIndex(); acc += 120 }
      event.accepted = true
    }
  }

  // ---------- the strip ----------
  ListView {
    id: strip
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: 14
    height: 114
    orientation: ListView.Horizontal
    model: root.results
    clip: true
    currentIndex: 0
    highlightRangeMode: ListView.StrictlyEnforceRange     // keep the selected one centred
    preferredHighlightBegin: width / 2 - 95
    preferredHighlightEnd: width / 2 + 95
    highlightMoveDuration: 220
    interactive: false          // we drive currentIndex ourselves

    delegate: Item {
      id: del
      required property var modelData
      required property int index
      readonly property bool selected: ListView.isCurrentItem

      width: 190
      height: strip.height

      Rectangle {
        anchors.centerIn: parent
        width: 160
        height: 90
        radius: 12
        color: Colors.card
        scale: del.selected ? 1.1 : 0.88
        opacity: del.selected ? 1 : 0.5

        Behavior on scale   { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 220 } }

        RoundedImage {
          anchors.fill: parent
          radius: 12
          decodeWidth: 320
          source: "file://" + del.modelData.path
        }

        Rectangle {
          anchors.fill: parent
          radius: 12
          color: "transparent"
          border.width: del.selected ? 2 : 0
          border.color: Colors.accent
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (del.selected) root.apply(del.modelData); else strip.currentIndex = del.index
      }
    }
  }

  // ---------- caption: name, position, and the filter while typing ----------
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 12
    color: Colors.subtext
    font.family: "Hack Nerd Font"
    font.pixelSize: 11
    text: root.results.length === 0
      ? (root.all.length === 0 ? "No wallpapers in ~/Pictures/Wallpapers" : "No matches")
      : (searchField.text !== "" ? "󰍉 " + searchField.text + "   ·   " : "")
        + (root.current ? root.current.name + "   ·   " + (strip.currentIndex + 1) + " / " + root.results.length : "")
  }
}
