pragma ComponentBehavior: Bound
import QtQuick
import "../../Common"

// App launcher page (Super+D): search box and a list of applications.
//   Type    filter apps (Backspace edits)
//   Up / Down (or Tab / Shift+Tab)  move the selection
//   Enter or left click  launch
//   Right click or Delete  hide / unhide the app
//   Esc     clears the search, then leaves "hidden" view, then closes the island
// With an empty search the most used apps are listed first.
// Keys arrive through the pill's Keys.forwardTo (see Island.qml).
Item {
    id: root
    signal done()
    readonly property int maxRows: 8
    readonly property int rowH: 46
    implicitHeight: col.implicitHeight

    property string query: ""
    property int selected: 0
    // When true, hidden apps are listed too (dimmed) so they can be unhidden.
    property bool showHidden: false

    // Flat list of { e: DesktopEntry, header: string }. `header` is a section title shown
    // above the row when it is the first of its group (empty otherwise).
    readonly property var results: {
        const q = root.query.trim()
        if (q !== "")
            return Apps.search(q, 60, root.showHidden).map(e => ({ e: e, header: "" }))
        const top = root.showHidden ? [] : Apps.top(4)
        const topIds = top.map(e => e.id)
        const rest = Apps.list(1000, root.showHidden).filter(e => topIds.indexOf(e.id) < 0)
        const out = []
        top.forEach((e, i) => out.push({ e: e, header: i === 0 ? "Most used" : "" }))
        rest.forEach((e, i) => out.push({ e: e, header: (i === 0 && top.length > 0) ? "All apps" : "" }))
        return out
    }

    function reset() { query = ""; selected = 0; showHidden = false }
    function move(d) { if (results.length > 0) selected = Math.max(0, Math.min(results.length - 1, selected + d)) }
    function launch(entry) { if (!entry) return; Apps.recordLaunch(entry); entry.execute(); done() }
    // Hide / unhide while keeping the scroll position.
    function toggleHide(entry) { if (!entry) return; list.keep = list.contentY; Apps.toggleHidden(entry) }
    onQueryChanged: selected = 0
    onShowHiddenChanged: selected = 0

    Keys.onPressed: e => {
        if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
        if (e.key === Qt.Key_Down) { root.move(1); e.accepted = true }
        else if (e.key === Qt.Key_Up) { root.move(-1); e.accepted = true }
        else if (e.key === Qt.Key_Tab) { root.move(1); e.accepted = true }
        else if (e.key === Qt.Key_Backtab) { root.move(-1); e.accepted = true }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.launch(root.results[root.selected]?.e); e.accepted = true }
        else if (e.key === Qt.Key_Delete) { root.toggleHide(root.results[root.selected]?.e); e.accepted = true }
        else if (e.key === Qt.Key_Backspace) { if (root.query.length > 0) root.query = root.query.slice(0, -1); e.accepted = true }
        else if (e.key === Qt.Key_Escape) {
            if (root.query !== "") root.query = ""
            else if (root.showHidden) root.showHidden = false
            else root.done()
            e.accepted = true
        }
        else if (e.text.length === 1 && e.text >= " " && e.text !== "\x7f") { root.query += e.text; e.accepted = true }
    }

    Column {
        id: col
        width: parent.width
        spacing: 10

        // Search box (shows what you type).
        Rectangle {
            width: parent.width; height: 44; radius: 22
            color: Theme.field
            Icon { x: 16; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 18; tone: "gray" }
            Text {
                x: 46; width: parent.width - 62; anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideLeft; textFormat: Text.PlainText
                text: root.query !== "" ? root.query : "Search apps"
                color: root.query !== "" ? Theme.textPrimary : Theme.textSecondary
                font.family: Theme.font; font.pixelSize: Theme.fontBody
            }
        }

        // Results: scrollable list (wheel, or arrow keys that follow the selection).
        // No visible scrollbar.
        Item {
            width: parent.width
            height: root.maxRows * root.rowH
            ListView {
                id: list
                anchors.fill: parent
                clip: true
                model: root.results
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                // Scroll position to restore after hiding an app (-1 = none).
                property real keep: -1

                // Keep the keyboard selection in view.
                Connections {
                    target: root
                    function onSelectedChanged() { list.positionViewAtIndex(root.selected, ListView.Contain) }
                    function onResultsChanged() {
                        if (root.selected >= root.results.length) root.selected = Math.max(0, root.results.length - 1)
                        if (list.keep >= 0) {
                            const k = list.keep
                            list.keep = -1
                            Qt.callLater(() => { list.contentY = k })
                        } else {
                            list.positionViewAtBeginning()
                        }
                    }
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property int headH: row.modelData.header !== "" ? 26 : 0
                    readonly property bool isHiddenApp: Apps.isHidden(row.modelData.e)
                    width: list.width
                    height: row.headH + root.rowH

                    // Section title ("Most used" / "All apps").
                    Text {
                        visible: row.headH > 0
                        x: 12; y: 6
                        text: row.modelData.header
                        color: Theme.textSecondary
                        font.family: Theme.font; font.pixelSize: Theme.fontCaption; font.weight: Font.DemiBold
                    }

                    Rectangle {
                        id: body
                        y: row.headH
                        width: parent.width; height: root.rowH; radius: 16
                        color: row.index === root.selected ? Theme.hover : "transparent"
                        opacity: row.isHiddenApp ? 0.45 : 1
                        Behavior on color { ColorAnimation { duration: Theme.durMicro } }
                        Image {
                            x: 12; anchors.verticalCenter: parent.verticalCenter
                            width: 28; height: 28; sourceSize: Qt.size(56, 56)
                            source: Apps.iconFor(row.modelData.e); smooth: true; asynchronous: true
                        }
                        Column {
                            x: 52; width: parent.width - 52 - (row.isHiddenApp ? 48 : 20)
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
                                text: row.modelData.e.name
                                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: Theme.fontBody; font.weight: Font.Medium
                            }
                            Text {
                                width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
                                visible: text !== ""
                                text: row.modelData.e.genericName || ""
                                color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: Theme.fontCaption
                            }
                        }
                        // Marker for apps that are currently hidden.
                        Icon {
                            visible: row.isHiddenApp
                            anchors.right: parent.right; anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            name: "eye-off"; size: 18; tone: "gray"
                        }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            // Real pointer movement only: scrolling under a still pointer must not steal the selection.
                            onPositionChanged: root.selected = row.index
                            onClicked: m => {
                                if (m.button === Qt.RightButton) root.toggleHide(row.modelData.e)
                                else root.launch(row.modelData.e)
                            }
                        }
                    }
                }
            }
            Text {
                visible: root.results.length === 0
                anchors.centerIn: parent
                text: "No apps found"
                color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: Theme.fontLabel
            }
        }

        // Footer: hint on the left, hidden-apps toggle on the right.
        Item {
            width: parent.width; height: 22
            Text {
                anchors.left: parent.left; anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.showHidden ? "Right-click to unhide" : "Right-click to hide"
                color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: Theme.fontCaption
            }
            Text {
                visible: root.showHidden || Apps.hidden.length > 0
                anchors.right: parent.right; anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.showHidden ? "Done" : "Hidden (" + Apps.hidden.length + ")"
                color: toggleMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                font.family: Theme.font; font.pixelSize: Theme.fontCaption
                MouseArea {
                    id: toggleMouse
                    anchors.fill: parent; anchors.margins: -6
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.showHidden = !root.showHidden
                }
            }
        }
    }
}
