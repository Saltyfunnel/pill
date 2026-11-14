pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Hyprland workspaces (Hyprland 0.56 Lua dispatch syntax).
Singleton {
    id: root
    readonly property var list: Hyprland.workspaces.values.filter(w => w.id > 0).sort((a, b) => a.id - b.id)
    readonly property int activeId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    property real lastSwitch: 0      // for the dot indicator (monotonic clock)
    property real lastWheel: 0
    property real wheelAcc: 0
    property real wheelT: 0

    // Monotonic clock: Date.now() breaks if NTP/RTC jumps on startup.
    ElapsedTimer { id: monoClock }
    Component.onCompleted: monoClock.restart()
    function monoNow() { return monoClock.elapsedMs() }

    function dispatchWs(target) {
        // Hyprland.dispatch() does not understand Lua syntax: use hyprctl.
        // Quickshell 0.3.2: execDetached didn't launch the process; use a dedicated Process.
        wsProc.running = false
        wsProc.command = ["hyprctl", "dispatch", "hl.dsp.focus({workspace=\"" + target + "\"})"]
        wsProc.running = true
        lastSwitch = monoNow()
    }
    // One wheel notch = one workspace (with cooldown).
    function wheel(deltaY) {
        const now = monoNow()
        if (deltaY === 0) return
        // Touchpads send many small deltas: accumulate them up to a "notch" (120)
        // so an accidental brush doesn't change workspaces. Pause or direction change: reset.
        const sinceT = now - wheelT
        if (sinceT < 0 || sinceT > 300 || (wheelAcc > 0) !== (deltaY > 0)) wheelAcc = 0
        wheelT = now
        wheelAcc += deltaY
        const sinceLast = now - lastWheel
        // Only cool down if the monotonic delta is in [0, 220). Negative/absurd values don't block.
        if (Math.abs(wheelAcc) < 120 || (sinceLast >= 0 && sinceLast < 220)) return
        lastWheel = now
        wheelAcc = 0
        dispatchWs(deltaY > 0 ? "r-1" : "r+1")
    }
    // Reorder: `order` is the new sequence of IDs; the workspace content that
    // ended up at position i goes to the original i-th ID. Ignores if one is already in progress.
    function reorder(order) {
        const ids = list.map(w => w.id)
        if (reorderProc.running || order.length !== ids.length || order.every((id, i) => id === ids[i])) { reordered(); return }
        reorderProc.command = [Qt.resolvedUrl("../scripts/reorder-ws.py").toString().replace("file://", ""),
                               ids.join(","), order.join(","), String(activeId)]
        reorderProc.running = true
        lastSwitch = monoNow()
    }
    // Without stdout/stderr readers the process failed to execute hyprctl (Quickshell 0.3.2).
    Process {
        id: wsProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }
    signal reordered()
    Process { id: reorderProc; onExited: { Hyprland.refreshWorkspaces(); Hyprland.refreshToplevels(); root.reordered() } }
    // Compact: when a workspace becomes empty (window closed or moved, or exiting an
    // empty one), the subsequent ones shift left to leave no gaps. Event-driven only, no polling;
    // one execution per burst.
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            const n = ev.name
            if (n === "closewindow" || n === "movewindowv2" || n === "destroyworkspacev2") compactLater.restart()
        }
    }
    Timer { id: compactLater; interval: 350; onTriggered: { if (reorderProc.running) restart(); else if (!compactProc.running) compactProc.running = true } }
    Process {
        id: compactProc
        command: [Qt.resolvedUrl("../scripts/compact-ws.py").toString().replace("file://", "")]
        onExited: { Hyprland.refreshWorkspaces(); Hyprland.refreshToplevels() }
    }
    function goTo(id) { dispatchWs(String(id)) }
    function goEmpty() { dispatchWs("emptynm") }
}
