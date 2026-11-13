pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../Common"
import ".."

// Pinned menu items (Settings › Personalization › Island menu):
// sliders on top and buttons in rows of 4 (maximum 3 rows).
Column {
    id: root
    signal done()
    signal desktops()
    signal clipboard()
    signal notes()
    signal emoji()
    spacing: 18

    readonly property var sliders: QuickItems.pinnedSliders
    readonly property var buttons: QuickItems.pinnedButtons
    readonly property string screenOffScript: Qt.resolvedUrl("../../scripts/pantalla-off.sh").toString().replace("file://", "")
    readonly property string shotScript: Qt.resolvedUrl("../../scripts/screenshot.sh").toString().replace("file://", "")

    function activate(id) {
        if (id === "terminal") { QuickItems.run("kitty"); root.done() }
        // Record: closes island and starts after 0.4s (so it's not recorded open).
        else if (id === "record") { if (Recorder.recording) Recorder.stop(); else Recorder.start(400); root.done() }
        else if (id === "capture") { Quickshell.execDetached(["sh", "-c", 'sleep 0.3; exec "$0" area', root.shotScript]); root.done() }
        // Turn off monitor: island closes and
        // script turns off via DPMS after 1s. Nothing closes or moves.
        else if (id === "screenoff") { Quickshell.execDetached([root.screenOffScript]); root.done() }
        else if (id === "desktops") root.desktops()
        else if (id === "clipboard") root.clipboard()
        else if (id === "notes") root.notes()
        else if (id === "emoji") root.emoji()
        // Browser / files: island closes only if launched; otherwise, inline notice.
        else if (id === "browser" || id === "files") Launch.open(id)
        else { const c = QuickItems.custom(id); if (c) { QuickItems.run(c.cmd); root.done() } }
    }

    // Volume slider (when pinned)
    VolumeSection { width: parent.width; visible: ready && root.sliders.indexOf("volume") >= 0 }

    Grid {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.buttons.length > 0
        columns: QuickItems.columns
        rowSpacing: 4
        Repeater {
            model: root.buttons
            delegate: MenuButton {
                id: b
                required property string modelData
                readonly property var item: QuickItems.builtins.find(x => x.id === modelData) ?? QuickItems.custom(modelData)
                readonly property bool rec: modelData === "record" && Recorder.recording
                icon: rec ? "stop" : (item && item.icon ? item.icon : "")
                letter: item && !item.icon ? item.label.charAt(0).toUpperCase() : ""
                label: rec ? I18n.tr("Stop") : modelData === "record" ? I18n.tr("Record") : modelData === "screenoff" ? I18n.tr("Monitor off") : (item ? item.label : "")
                active: rec
                onActivated: root.activate(b.modelData)
            }
        }
    }

    Connections {
        target: Launch
        function onLaunched() { root.done() }
    }
    // Error on opening (non-blocking; disappears on its own).
    Text {
        width: parent.width
        visible: Launch.error !== ""
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: Launch.error
        color: Theme.danger; font.family: Theme.font; font.pixelSize: Theme.fontCaption
    }
}
