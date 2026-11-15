pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Opens the default browser / file manager (scripts/open-default.sh).
// Non-blocking: if it fails, `error` carries a short message that the island displays for a few seconds.
Singleton {
    id: root
    property string error: ""
    property string pending: ""
    signal launched()
    readonly property string script: Qt.resolvedUrl("../scripts/open-default.sh").toString().replace("file://", "")

    function open(kind) {
        if (proc.running) return          // one launch at a time
        error = ""; pending = kind
        proc.command = ["sh", root.script, kind]   // via sh: works even without the executable bit
        proc.running = true
    }
    Process {
        id: proc
        stderr: StdioCollector { id: err }
        onExited: code => {
            if (code === 0) root.launched()
            else { root.error = root.pending === "files" ? I18n.tr("Could not open the file manager.") : I18n.tr("Could not open the browser."); clear.restart() }
            root.pending = ""
        }
    }
    Timer { id: clear; interval: 4000; onTriggered: root.error = "" }
}
