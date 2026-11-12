// Updates.qml — singleton: pending pacman updates, checked every 30 min via checkupdates.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property var packages: []
  property bool checking: false
  property bool failed: false
  property string lastChecked: "never"
  readonly property int total: packages.length

  function refresh() {
    if (checking) return
    checking = true
    checkProc.running = true
  }

  function upgrade() {
    upgradeProc.running = true
  }

  Process {
    id: checkProc
    command: ["checkupdates"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim() ? text.trim().split("\n") : []
        root.packages = lines.map(l => {
          const p = l.split(" ")
          return { name: p[0], from: p[1], to: p[3] }
        })
      }
    }
    // exit 0 = updates, 2 = none, anything else = real failure
    onExited: (code, status) => {
      root.failed = (code !== 0 && code !== 2)
      root.checking = false
      root.lastChecked = Qt.formatTime(new Date(), "HH:mm")
    }
  }

  // re-check automatically once the update terminal closes
  Process {
    id: upgradeProc
    command: [
      "kitty", "--class", "updates", "-e", "sh", "-c",
      "sudo pacman -Syu; echo; read -r -p 'Done. Press Enter to close '"
    ]
    onExited: root.refresh()
  }

  Timer {
    interval: 30 * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
