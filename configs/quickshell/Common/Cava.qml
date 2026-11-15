pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Audio equalizer data from cava (raw ASCII mode, 8 bars, values 0-100).
// cava only runs while `active` is true (set by the media card while it is
// visible and a player is playing), so there is zero CPU use otherwise.
Singleton {
    id: root
    property bool active: false
    readonly property int count: 8
    property var bars: [0, 0, 0, 0, 0, 0, 0, 0]
    readonly property string conf: Qt.resolvedUrl("../scripts/cava-raw.conf").toString().replace("file://", "")

    Process {
        id: proc
        command: ["cava", "-p", root.conf]
        running: root.active
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";").filter(s => s !== "")
                if (parts.length < root.count) return
                const out = []
                for (let i = 0; i < root.count; i++) out.push(Math.min(100, parseInt(parts[i]) || 0))
                root.bars = out
            }
        }
        onExited: root.bars = [0, 0, 0, 0, 0, 0, 0, 0]
    }
}
