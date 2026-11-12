// Capture.qml — screenshot / screen-record helpers, shared by the dashboard and the bar.
// Uses your scripts in ~/.config/scripts (screenshot.sh, screenrecord.sh).
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  readonly property string scriptDir: Quickshell.env("HOME") + "/.config/scripts"
  property bool isRecording: false

  // is wf-recorder running?
  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: checkStatus.running = true
  }
  Process {
    id: checkStatus
    command: ["pgrep", "-x", "wf-recorder"]
    onExited: (exitCode, exitStatus) => root.isRecording = (exitCode === 0)
  }

  // Run a command a moment later, so the dashboard has time to close
  // and is not in the screenshot.
  property var pending: []
  Timer {
    id: delay
    interval: 250
    onTriggered: Quickshell.execDetached(root.pending)
  }
  function run(args) {
    root.pending = args
    delay.restart()
  }

  function screenshot(mode) { run([scriptDir + "/screenshot.sh", mode]) }
  function toggleRecording() { Quickshell.execDetached([scriptDir + "/screenrecord.sh", "toggle"]) }
}
