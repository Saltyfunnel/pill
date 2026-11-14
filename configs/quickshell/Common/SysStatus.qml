pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// System state for the island panel (swipe over the compact island).
// - Always: event-based connectivity (`nmcli monitor`, no polling) → `online` (red dot).
//   Upon each change, NetworkManager's last known state is read (`nmcli networking
//   connectivity`, without forcing an HTTP check); only on startup and when opening the panel is
//   one forced (`... check`). Previously: `check` every 10s = one process and one HTTP request every 10s.
// - Only with the panel open (acquire/release): resources every 3s and network/devices every 10s,
//   using scripts/sysstatus.py (one short process per query, nothing permanent).
// Does not read other singletons.
Singleton {
    id: root
    property int users: 0
    function acquire() { users++; if (users === 1) { full.go(); conn.go() } }
    function release() { users = Math.max(0, users - 1) }

    // Connectivity: "full" | "limited" | "portal" | "none" | "unknown"
    property string connectivity: "unknown"
    readonly property bool known: connectivity !== "unknown" && connectivity !== ""
    readonly property bool online: connectivity === "full"

    property var res: null      // { cpu, memUsed, memTotal, diskUsed, diskTotal, temp }
    property var net: null      // { type, name, device, signal, connectivity }
    property var dev: null      // { keyboards, mice, audio, bluetooth, usb }
    property var gpu: null      // { name, util, temp } | null

    readonly property string script: Qt.resolvedUrl("../scripts/sysstatus.py").toString().replace("file://", "")

    function gib(b) { return (b / 1073741824).toFixed(1) }

    Process {
        id: conn
        property bool force: true
        function go() { force = true; if (!running) running = true }          // real check (startup, panel)
        function peek() { if (!running) { force = false; running = true } }   // last known state (events)
        command: force ? ["nmcli", "networking", "connectivity", "check"] : ["nmcli", "networking", "connectivity"]
        stdout: StdioCollector { onStreamFinished: root.connectivity = text.trim() || "unknown" }
    }
    Component.onCompleted: conn.go()
    // NetworkManager events: connection, state, and connectivity. One sleeping process, no polling.
    Process {
        id: monitor
        running: true
        command: ["nmcli", "monitor"]
        // Any line is a change (connectivity, state, devices): grouped and read once.
        stdout: SplitParser { onRead: line => settle.restart() }
        // If NetworkManager restarts (or nmcli is missing), retry in 30s, no tight loops.
        onExited: retry.restart()
    }
    Timer { id: settle; interval: 600; onTriggered: conn.peek() }        // one read per event burst
    Timer { id: retry; interval: 30000; onTriggered: { monitor.running = true; conn.peek() } }

    Process {
        id: resP
        function go() { if (!running) running = true }
        command: [root.script, "res"]
        stdout: StdioCollector { onStreamFinished: { try { root.res = JSON.parse(text).res } catch (e) {} } }
    }
    Process {
        id: full
        function go() { if (!running) running = true }
        command: [root.script, "full"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    root.res = j.res; root.net = j.net; root.dev = j.dev; root.gpu = j.gpu
                    if (j.net && j.net.connectivity) root.connectivity = j.net.connectivity
                } catch (e) {}
            }
        }
    }
    Timer { running: root.users > 0; repeat: true; interval: 5000; onTriggered: resP.go() }
    Timer { running: root.users > 0; repeat: true; interval: 10000; onTriggered: full.go() }
}
