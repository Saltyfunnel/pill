// MixerPanel.qml — vertical sliders: speaker volume, microphone, and screen brightness (laptops).
// Click an icon to mute / unmute.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

DashPanel {
  id: root

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  PwObjectTracker { objects: [root.sink, root.source].filter(o => o) }

  // ---------- screen brightness (only if this machine has a backlight) ----------
  property bool hasBacklight: false
  property real bright: 0

  Process {
    id: brightProc
    command: ["brightnessctl", "-m", "-c", "backlight"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const p = text.trim().split(",")
        if (p.length >= 5) {
          root.bright = parseInt(p[3]) / 100
          root.hasBacklight = true
        }
      }
    }
  }
  // send brightness changes at most every 60 ms while dragging
  Timer {
    id: brightTimer
    interval: 60
    onTriggered: Quickshell.execDetached(["brightnessctl", "-c", "backlight", "set", Math.round(root.bright * 100) + "%"])
  }

  // one vertical slider with an icon underneath
  component VSlider: Item {
    id: s
    property real value: 0
    property string icon: ""
    property bool dim: false
    signal moved(real v)
    signal iconClicked()

    Rectangle {
      id: track
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      width: 14
      height: parent.height - 36
      radius: 7
      color: Colors.track

      Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height * Math.max(0, Math.min(1, s.value))
        radius: 7
        color: s.dim ? Colors.subtext : Colors.accent
        Behavior on height { NumberAnimation { duration: 80 } }
      }
      MouseArea {
        anchors.fill: parent
        onPressed: mouse => s.moved(1 - mouse.y / height)
        onPositionChanged: mouse => s.moved(1 - mouse.y / height)
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      text: s.icon
      color: s.dim ? Colors.subtext : Colors.text
      font.family: Theme.font
      font.pixelSize: 17
      MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: s.iconClicked() }
    }
  }

  Row {
    id: sliders
    anchors.fill: parent
    anchors.margins: 10
    spacing: 4
    readonly property int count: root.hasBacklight ? 3 : 2
    readonly property real slotW: (width - (count - 1) * spacing) / count

    VSlider {
      width: sliders.slotW
      height: parent.height
      icon: "󰕾"
      value: root.sink?.audio?.volume ?? 0
      dim: root.sink?.audio?.muted ?? false
      onMoved: v => { if (root.sink?.audio) root.sink.audio.volume = Math.max(0, Math.min(1, v)) }
      onIconClicked: { if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted }
    }

    VSlider {
      width: sliders.slotW
      height: parent.height
      icon: "󰍬"
      value: root.source?.audio?.volume ?? 0
      dim: root.source?.audio?.muted ?? false
      onMoved: v => { if (root.source?.audio) root.source.audio.volume = Math.max(0, Math.min(1, v)) }
      onIconClicked: { if (root.source?.audio) root.source.audio.muted = !root.source.audio.muted }
    }

    VSlider {
      visible: root.hasBacklight
      width: sliders.slotW
      height: parent.height
      icon: "󰃠"
      value: root.bright
      onMoved: v => {
        root.bright = Math.max(0.01, Math.min(1, v))
        if (!brightTimer.running) brightTimer.start()
      }
    }
  }
}
