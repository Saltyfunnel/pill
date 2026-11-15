pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Global cursor position (Hyprland). A single lightweight process queries
// `hyprctl cursorpos` ~25 times/sec, and only runs while some consumer
// (visible item) needs it. Without consumers, there is no polling.
Singleton {
    id: root
    property int users: 0
    property real x: -1
    property real y: -1
    property bool ok: false
    property real lastMove: 0

    function acquire() { if (users === 0) lastMove = Date.now(); users++ }
    function release() { users = Math.max(0, users - 1) }

    Process {
        id: proc
        running: root.users > 0
        // If the process crashes (e.g. Hyprland reloaded), it relaunches in 2s while there are users.
        onExited: if (root.users > 0) relaunch.restart()
        // A single process that reads Hyprland's IPC socket with adaptive frequency
        // (previously: one hyprctl every 40 ms ≈ 40% of a core).
        command: [Qt.resolvedUrl("../scripts/cursorpos.py").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/^(-?\d+),\s*(-?\d+)/)
                if (!m) return
                const nx = +m[1], ny = +m[2]
                if (nx !== root.x || ny !== root.y) { root.lastMove = Date.now(); root.x = nx; root.y = ny }
                root.ok = true
            }
        }
    }
    Timer { id: relaunch; interval: 2000; onTriggered: if (root.users > 0) { proc.running = false; proc.running = true } }
}
