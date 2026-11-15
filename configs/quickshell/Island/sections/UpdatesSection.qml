import QtQuick
import Quickshell.Io
import "../../Common"

// Pending pacman updates. Shown only when something is available.
// Click: closes the island and runs the update in a floating kitty window (class "updates"); the count refreshes
// when that window closes. Needs `checkupdates` (pacman-contrib).
Item {
    id: root
    signal done()

    property int total: 0    // pending updates
    implicitHeight: 44

    function refresh() { if (!check.running) check.running = true }
    function runUpdate() {
        if (upd.running) return
        upd.running = true
        root.done()
    }

    // Counts pending updates without touching the real package database.
    Process {
        id: check
        command: ["sh", "-c", "checkupdates 2>/dev/null | wc -l"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.total = parseInt(text.trim()) || 0
            }
        }
    }

    // The update itself, in a terminal so you can see and answer prompts.
    Process {
        id: upd
        command: ["kitty", "--class", "updates", "-e", "sh", "-c", "sudo pacman -Syu; echo; printf 'Done. Press Enter to close. '; read _"]
        onRunningChanged: if (!running) root.refresh()
    }

    // Re-check every 30 minutes.
    Timer { interval: 1800000; running: true; repeat: true; onTriggered: root.refresh() }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: mouse.containsMouse ? Theme.hover : Theme.field
        Behavior on color { ColorAnimation { duration: Theme.durMicro } }

        Icon { x: 16; anchors.verticalCenter: parent.verticalCenter; name: "update"; size: 18; tone: "accent" }
        Text {
            x: 46; anchors.verticalCenter: parent.verticalCenter
            text: root.total + (root.total === 1 ? " update" : " updates")
            color: Theme.textPrimary
            font.family: Theme.font; font.pixelSize: Theme.fontBody
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: "Update"
            color: Theme.fill
            font.family: Theme.font; font.pixelSize: Theme.fontCaption; font.weight: Font.DemiBold
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.runUpdate()
        }
    }
}
