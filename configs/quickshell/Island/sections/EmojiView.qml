pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../../Common"
import "../../Common/emoji.js" as E

// Emoji selector inside the island ("Emojis" pinnable access). Categories + search
// (Spanish and English, unaccented). Click: copies exact sequence with wl-copy and shows
// "Copied"; writes nothing by itself. Opening the view does not touch the clipboard.
// Data (assets/emoji/emoji.json) is read on first open.
Item {
    id: root
    signal back()
    property bool active: false
    property string raw: ""
    property string cat: "caras"
    property string copied: ""
    implicitHeight: col.implicitHeight

    readonly property var cats: raw ? E.parse(raw, I18n.lang) : []
    readonly property var current: cats.find(c => c.id === cat) ?? (cats.length ? cats[0] : null)
    readonly property bool searching: field.text.trim() !== ""
    readonly property var shown: searching ? E.search(cats, field.text, 64) : (current ? current.items : [])
    readonly property int tone: DisplayState.emojiTone

    function reset() { field.text = ""; field.focus = false; copied = ""; flick.contentY = 0 }
    onActiveChanged: if (active && !raw) data.path = Qt.resolvedUrl("../../assets/emoji/emoji.json").toString().replace("file://", "")

    function pick(item) {
        const s = E.textFor(item, root.tone)
        Clipboard.copyText(s)
        root.copied = s
        copiedTimer.restart()
    }

    FileView {
        id: data
        blockLoading: false
        printErrors: false
        onLoaded: root.raw = text()
    }
    Timer { id: copiedTimer; interval: 1600; onTriggered: root.copied = "" }

    Column {
        id: col
        width: parent.width
        spacing: 12

        // Header: back · title · skin tone (click: next tone).
        Item {
            width: parent.width; height: 32
            Rectangle {
                width: 32; height: 32; radius: 16
                color: bm.containsMouse ? Theme.hover : Theme.surface
                Icon { anchors.centerIn: parent; name: "back"; size: 18 }
                MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
            }
            Text {
                anchors.centerIn: parent
                text: I18n.tr("Emojis")
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: Theme.fontClock; font.weight: Font.DemiBold
            }
            Rectangle {
                anchors.right: parent.right
                width: 32; height: 32; radius: 16
                color: tm.containsMouse ? Theme.hover : Theme.surface
                Text { anchors.centerIn: parent; text: E.withTone("\u270B", root.tone); font.family: Theme.emojiFont; font.pixelSize: 17 }
                MouseArea {
                    id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: DisplayState.setEmojiTone((root.tone + 1) % E.TONES.length)
                }
                Accessible.name: I18n.tr("Skin tone")
            }
        }

        // Search (borderless: gray pill).
        Rectangle {
            width: parent.width; height: 38; radius: 19
            color: Theme.field
            MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onPressed: field.forceActiveFocus() }
            Icon { id: lupa; x: 14; anchors.verticalCenter: parent.verticalCenter; name: "search"; tone: "gray"; size: 16 }
            TextInput {
                id: field
                anchors.left: lupa.right; anchors.leftMargin: 8
                anchors.right: parent.right; anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.textPrimary
                selectionColor: Theme.hover; selectedTextColor: Theme.textPrimary
                cursorDelegate: Rectangle { width: 2; radius: 1; color: Theme.textPrimary; visible: field.activeFocus && field.cursorVisible }
                font.family: Theme.font; font.pixelSize: Theme.fontBody
                clip: true
                onTextChanged: flick.contentY = 0
                Keys.onReturnPressed: if (root.shown.length > 0) root.pick(root.shown[0])
                Keys.onEscapePressed: e => { if (field.text) field.text = ""; else e.accepted = false }
                Text {
                    visible: !field.text
                    text: I18n.tr("Search emoji")
                    color: Theme.textSecondary
                    font: field.font
                }
            }
        }

        // Categories (search-free only).
        Row {
            visible: !root.searching
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0
            Repeater {
                model: root.cats
                delegate: Rectangle {
                    id: tab
                    required property var modelData
                    readonly property bool cur: root.current !== null && root.current.id === modelData.id
                    width: Math.floor(col.width / Math.max(1, root.cats.length)); height: 34; radius: 17
                    color: cur ? Theme.field : (tbm.containsMouse ? Theme.hover : "transparent")
                    Text { anchors.centerIn: parent; text: tab.modelData.icon; font.family: Theme.emojiFont; font.pixelSize: 17; opacity: tab.cur ? 1 : 0.55 }
                    MouseArea { id: tbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.cat = tab.modelData.id; flick.contentY = 0 } }
                    Accessible.name: tab.modelData.label
                }
            }
        }

        Text {
            width: parent.width; leftPadding: 4
            text: root.searching ? (root.shown.length ? I18n.tr("Results") : I18n.tr("No results")) : (root.current ? root.current.label : (root.raw ? "" : I18n.tr("Loading…")))
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: Theme.fontCaption; font.weight: Font.DemiBold
        }

        Flickable {
            id: flick
            width: parent.width
            height: 5 * 44
            contentHeight: grid.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            Grid {
                id: grid
                columns: 8
                Repeater {
                    model: root.shown
                    delegate: Rectangle {
                        id: cell
                        required property var modelData
                        readonly property string txt: E.textFor(modelData, root.tone)
                        width: Math.floor(flick.width / 8); height: 44; radius: 12
                        color: cm.containsMouse ? Theme.hover : "transparent"
                        Text { anchors.centerIn: parent; text: E.glyph(cell.txt); font.family: Theme.emojiFont; font.pixelSize: 24 }
                        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pick(cell.modelData) }
                        Accessible.name: cell.modelData.name
                        Accessible.role: Accessible.Button
                    }
                }
            }
        }

        // Discreet notice after copying (emoji goes in its own text, with emoji font).
        Item {
            width: parent.width; height: 20
            Row {
                anchors.centerIn: parent; spacing: 6
                Text { anchors.verticalCenter: parent.verticalCenter; text: root.copied ? I18n.tr("Copied") : I18n.tr("Click to copy · Ctrl+V to paste"); color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: Theme.fontCaption }
                Text { anchors.verticalCenter: parent.verticalCenter; visible: root.copied !== ""; text: E.glyph(root.copied); font.family: Theme.emojiFont; font.pixelSize: Theme.fontBody }
            }
        }
    }
}
