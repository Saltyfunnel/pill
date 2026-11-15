pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording with wf-recorder (focused output, with system audio if
// pactl is available). Stopping sends SIGINT so the .mp4 closes properly.
// From Hyprland: qs -p ~/Proyectos/~/.config/quickshell ipc call recorder toggle
Singleton {
    id: root
    property string bin: "wf-recorder"
    property bool recording: false
    property bool starting: false
    property int elapsed: 0                  // seconds
    property string file: ""
    property string notice: ""               // brief message for the compact island
    readonly property string elapsedText: {
        const m = Math.floor(elapsed / 60), s = elapsed % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    function toggle() { if (recording || starting) stop(); else start() }

    // Starts after `delay` ms (so the island closes before recording).
    function start(delay) {
        if (recording || starting) return
        starting = true
        startDelay.interval = delay || 0
        startDelay.restart()
    }
    function stop() {
        startDelay.stop()
        starting = false
        if (proc.running) proc.signal(2)    // SIGINT → wf-recorder finishes the file
    }
    function say(msg, ms) { notice = msg; noticeTimer.interval = ms || 2200; noticeTimer.restart() }

    Timer { id: startDelay; onTriggered: root.launch() }
    Timer { id: noticeTimer; onTriggered: root.notice = "" }
    Timer { running: root.recording; interval: 1000; repeat: true; onTriggered: root.elapsed++ }

    function launch() {
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")
        root.file = "Recording-" + stamp + ".mp4"
        proc.command = ["sh", "-c",
            'command -v "$1" >/dev/null 2>&1 || exit 127\n' +
            'dir=$(xdg-user-dir VIDEOS 2>/dev/null); [ -n "$dir" ] && [ "$dir" != "$HOME" ] || dir="$HOME/Videos"\n' +
            'dir="$dir/Recordings"; mkdir -p "$dir"; echo "DIR:$dir"\n' +
            'out=$(hyprctl activeworkspace 2>/dev/null | sed -n "1s/.* on monitor \\(.*\\):$/\\1/p")\n' +
            'set -- "$1" -f "$dir/$2"; [ -n "$out" ] && set -- "$@" -o "$out"\n' +
            'if command -v pactl >/dev/null 2>&1; then s=$(pactl get-default-sink 2>/dev/null); [ -n "$s" ] && set -- "$@" "--audio=$s.monitor"; fi\n' +
            'exec "$@"',
            "island-rec", root.bin, root.file]
        root.elapsed = 0
        root.starting = false
        root.recording = true
        proc.running = true
    }

    Process {
        id: proc
        stdout: SplitParser { onRead: l => { if (l.startsWith("DIR:")) root.dir = l.slice(4) } }
        onExited: (code, status) => {
            const was = root.recording
            root.recording = false
            if (code === 127) root.say(I18n.tr("Install wf-recorder"), 3500)
            else if (was && root.elapsed > 0) root.say(I18n.tr("Saved · %1", root.file))
            else if (was) root.say(I18n.tr("Could not record"), 2500)
        }
    }
    property string dir: ""

    IpcHandler {
        target: "recorder"
        function toggle(): void { root.toggle() }
        function start(): void { root.start(0) }
        function stop(): void { root.stop() }
    }
}
