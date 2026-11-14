pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../Common"

// Wallpaper picker page: a big preview of the selected wallpaper and a coverflow
// strip of thumbnails underneath.
//   Left / Right or mouse wheel  move along the strip
//   Enter or click on the selected one  apply it (setwall.sh: wallpaper + matugen colours)
//   Type  filter by file name (Backspace edits, Esc clears, then goes back)
//   Tab  jump to a random wallpaper
// Keys arrive through the pill's Keys.forwardTo (see Island.qml), so this item
// does not need active focus itself.
Item {
    id: root
    signal back()
    signal applied()
    implicitHeight: col.implicitHeight

    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: home + "/Pictures/Wallpapers"
    readonly property string setwall: home + "/.config/scripts/setwall.sh"
    readonly property int thumbW: 132
    readonly property int thumbH: 80

    property var all: []                 // [{ path, name }]
    property string query: ""
    property string current: ""          // wallpaper currently applied
    readonly property var shown: {
        const q = query.toLowerCase()
        return q === "" ? all : all.filter(w => w.name.toLowerCase().indexOf(q) >= 0)
    }
    readonly property var selected: strip.currentIndex >= 0 && strip.currentIndex < shown.length ? shown[strip.currentIndex] : null

    function reset() { query = "" }
    function refresh() {
        query = ""
        cur.reload()
        if (!lister.running) lister.running = true
    }
    // Put the strip on the wallpaper that is applied right now.
    function syncCurrent() {
        const i = shown.findIndex(w => w.path === current)
        strip.currentIndex = i >= 0 ? i : 0
        strip.positionViewAtIndex(strip.currentIndex, ListView.Center)
    }
    function step(d) {
        if (shown.length === 0) return
        strip.currentIndex = Math.max(0, Math.min(shown.length - 1, strip.currentIndex + d))
    }
    function random() {
        if (shown.length > 1) strip.currentIndex = Math.floor(Math.random() * shown.length)
    }
    function apply() {
        if (!selected) return
        Quickshell.execDetached([setwall, selected.path])
        current = selected.path
        applied()
    }
    onQueryChanged: Qt.callLater(() => { strip.currentIndex = 0; strip.positionViewAtIndex(0, ListView.Center) })

    FileView {
        id: cur
        path: root.home + "/.cache/current_wallpaper"
        printErrors: false
        onLoaded: { root.current = text().trim(); root.syncCurrent() }
    }
    Process {
        id: lister
        command: ["find", root.dir, "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l !== "").sort()
                root.all = lines.map(p => ({ path: p, name: p.substring(p.lastIndexOf("/") + 1) }))
                root.syncCurrent()
            }
        }
    }

    Keys.onPressed: e => {
        if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
        if (e.key === Qt.Key_Left) { root.step(-1); e.accepted = true }
        else if (e.key === Qt.Key_Right) { root.step(1); e.accepted = true }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.apply(); e.accepted = true }
        else if (e.key === Qt.Key_Tab) { root.random(); e.accepted = true }
        else if (e.key === Qt.Key_Backspace) { if (root.query.length > 0) root.query = root.query.slice(0, -1); e.accepted = true }
        // Esc clears the search first; with an empty search it falls through and the pill goes back to the menu.
        else if (e.key === Qt.Key_Escape && root.query !== "") { root.query = ""; e.accepted = true }
        else if (e.text.length === 1 && e.text >= " " && e.text !== "\x7f") { root.query += e.text; e.accepted = true }
    }

    // Image with rounded corners (mask effect).
    component RoundImage: Item {
        id: ri
        property alias source: img.source
        property alias sourceSize: img.sourceSize
        property int radius: 16
        Rectangle { anchors.fill: parent; radius: ri.radius; color: Theme.field }
        Image { id: img; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; visible: false }
        Item {
            id: mask
            anchors.fill: parent; visible: false; layer.enabled: true
            Rectangle { anchors.fill: parent; radius: ri.radius }
        }
        MultiEffect { anchors.fill: parent; source: img; maskEnabled: true; maskSource: mask; opacity: img.status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } } }
    }

    component RoundButton: Rectangle {
        id: rb
        property string icon
        signal clicked()
        width: 32; height: 32; radius: 16
        color: rbm.containsMouse ? Theme.hover : Theme.surface
        Icon { anchors.centerIn: parent; name: rb.icon; size: 18 }
        MouseArea { id: rbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.clicked() }
    }

    Column {
        id: col
        width: parent.width
        spacing: 12

        // Header: back, title, search box (shows what you type).
        Item {
            width: parent.width; height: 32
            RoundButton { icon: "back"; onClicked: root.back() }
            Text {
                anchors.centerIn: parent
                text: I18n.tr("Wallpaper")
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: Theme.fontClock; font.weight: Font.DemiBold
            }
            Rectangle {
                anchors.right: parent.right
                width: 220; height: 32; radius: 16
                color: Theme.field
                Icon { x: 10; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 16; tone: "gray" }
                Text {
                    x: 34; width: parent.width - 44; anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideLeft; textFormat: Text.PlainText
                    text: root.query !== "" ? root.query : "Type to search"
                    color: root.query !== "" ? Theme.textPrimary : Theme.textSecondary
                    font.family: Theme.font; font.pixelSize: Theme.fontCaption
                }
            }
        }

        // Big preview.
        Item {
            width: parent.width; height: 250
            RoundImage {
                anchors.fill: parent
                radius: 20
                source: root.selected ? "file://" + root.selected.path : ""
                sourceSize: Qt.size(1280, 720)
            }
            Text {
                visible: root.selected === null
                anchors.centerIn: parent
                text: root.all.length === 0 ? "No wallpapers in ~/Pictures/Wallpapers" : "No matches"
                color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: Theme.fontLabel
            }
            Rectangle {
                visible: root.selected !== null
                x: 12; y: parent.height - height - 12
                width: label.implicitWidth + 24; height: 28; radius: 14
                color: Theme.scrim
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: root.selected ? (root.selected.name + (root.selected.path === root.current ? "  ·  current" : "")) : ""
                    color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: Theme.fontCaption
                }
            }
            Rectangle {
                visible: root.selected !== null
                x: parent.width - width - 12; y: parent.height - height - 12
                width: count.implicitWidth + 24; height: 28; radius: 14
                color: Theme.scrim
                Text {
                    id: count
                    anchors.centerIn: parent
                    text: (strip.currentIndex + 1) + " / " + root.shown.length
                    color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: Theme.fontCaption
                    font.features: { "tnum": 1 }
                }
            }
        }

        // Coverflow strip.
        ListView {
            id: strip
            width: parent.width; height: root.thumbH + 24
            orientation: ListView.Horizontal
            model: root.shown
            spacing: 12
            clip: true
            interactive: false
            boundsBehavior: Flickable.StopAtBounds
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: width / 2 - root.thumbW / 2
            preferredHighlightEnd: width / 2 + root.thumbW / 2
            highlightMoveDuration: Theme.durNormal
            cacheBuffer: 600

            delegate: Item {
                id: d
                required property var modelData
                required property int index
                // Distance to the centre of the strip, in item slots (0 = selected).
                readonly property real dist: (x + width / 2 - (strip.contentX + strip.width / 2)) / (width + strip.spacing)
                width: root.thumbW; height: strip.height
                z: 10 - Math.min(Math.abs(dist), 9)
                opacity: 1 - Math.min(Math.abs(dist), 3) * 0.18
                scale: 1 - Math.min(Math.abs(dist), 2) * 0.09
                transform: Rotation {
                    origin.x: d.width / 2; origin.y: d.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: Math.max(-40, Math.min(40, -d.dist * 22))
                }

                RoundImage {
                    anchors.centerIn: parent
                    width: root.thumbW; height: root.thumbH
                    radius: 14
                    source: "file://" + d.modelData.path
                    sourceSize: Qt.size(264, 160)
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: root.thumbW + 6; height: root.thumbH + 6; radius: 17
                    color: "transparent"; border.width: 2; border.color: Theme.fill
                    opacity: d.index === strip.currentIndex ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (d.index === strip.currentIndex) root.apply(); else strip.currentIndex = d.index }
                }
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "← → browse   ·   Enter apply   ·   Tab random   ·   type to search"
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: Theme.fontTiny
        }
    }

    // Mouse wheel / touchpad over the page moves along the strip (clicks pass through).
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        property real last: 0
        onWheel: w => {
            const now = Date.now()
            if (now - last < 70) return
            last = now
            const d = Math.abs(w.angleDelta.x) > Math.abs(w.angleDelta.y) ? w.angleDelta.x : w.angleDelta.y
            if (d !== 0) root.step(d > 0 ? -1 : 1)
        }
    }
}
