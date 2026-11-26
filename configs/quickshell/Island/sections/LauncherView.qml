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
// With 2+ letters typed, matching packages from the official repos that are not installed
// yet are listed below the apps; Enter on one installs it in a kitty window.
// Keys arrive through the pill's Keys.forwardTo (see Island.qml).
Item {
    id: root
    signal done()
    readonly property int maxRows: 8
    readonly property int rowH: 42
    // Same hairline as the search bar and the card border.
    readonly property color hairline: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.20)
    implicitHeight: col.implicitHeight

    property string query: ""
    property int selected: 0
    // When true, hidden apps are listed too (dimmed) so they can be unhidden.
    property bool showHidden: false

    // Packages from the official repos that match the search (not installed yet).
    PkgSearch { id: pk; query: root.query; limit: 8 }

    // Flat list of { e: DesktopEntry, header: string }. `header` is a section title shown
    // above the row when it is the first of its group (empty otherwise).
    readonly property var results: {
        const q = root.query.trim()
        if (q !== "") {
            // With package results below, only the best matching apps are kept.
            const apps = Apps.search(q, pk.clean.length >= 2 ? 12 : 60, root.showHidden).map(e => ({ e: e, header: "" }))
            const extra = root.showHidden ? [] : pk.results.map((p, i) => ({ pkg: p, header: i === 0 ? "Install from repos" : "" }))
            return apps.concat(extra)
        }
        const top = root.showHidden ? [] : Apps.top(4)
        const topIds = top.map(e => e.id)
        const rest = Apps.list(1000, root.showHidden).filter(e => topIds.indexOf(e.id) < 0)
        const out = []
        top.forEach((e, i) => out.push({ e: e, header: i === 0 ? "Most used" : "" }))
        rest.forEach((e, i) => out.push({ e: e, header: (i === 0 && top.length > 0) ? "All apps" : "" }))
        return out
    }

    function reset() { pk.reset(); query = ""; selected = 0; showHidden = false }
    function move(d) { if (results.length > 0) selected = Math.max(0, Math.min(results.length - 1, selected + d)) }
    function launch(entry) { if (!entry) return; Apps.recordLaunch(entry); entry.execute(); done() }
    function install(p) { if (!p) return; pk.install(p); done() }
    // Enter / click on a result: launch the app or install the package.
    function activate(item) { if (!item) return; if (item.pkg) install(item.pkg); else launch(item.e) }
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
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.activate(root.results[root.selected]); e.accepted = true }
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
        spacing: 8

        // Search box (shows what you type): same slim style as the island search bar.
        Rectangle {
            width: parent.width; height: 34; radius: 17
            color: Theme.field
            border.width: 1; border.color: root.hairline
            Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 16; tone: "gray" }
            Text {
                x: 38; width: parent.width - 52; anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideLeft; textFormat: Text.PlainText
                text: root.query !== "" ? root.query : "Search apps & packages"
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
                        } else if (root.selected === 0) {
                            list.positionViewAtBeginning()
                        } else {
                            // Package results arriving must not throw the view off the selection.
                            list.positionViewAtIndex(root.selected, ListView.Contain)
                        }
                    }
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property int headH: row.modelData.header !== "" ? 26 : 0
                    readonly property bool isPkg: row.modelData.pkg !== undefined
                    readonly property bool isHiddenApp: !row.isPkg && Apps.isHidden(row.modelData.e)
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
                        width: parent.width; height: root.rowH; radius: 14
                        color: row.index === root.selected ? Theme.hover : "transparent"
                        // Selected row gets the same hairline as the other controls.
                        border.width: row.index === root.selected ? 1 : 0
                        border.color: root.hairline
                        opacity: row.isHiddenApp ? 0.45 : 1
                        Behavior on color { ColorAnimation { duration: Theme.durMicro } }
                        Image {
                            visible: !row.isPkg || row.modelData.pkg.icon !== ""
                            x: 12; anchors.verticalCenter: parent.verticalCenter
                            width: 26; height: 26; sourceSize: Qt.size(52, 52)
                            source: row.isPkg ? row.modelData.pkg.icon : Apps.iconFor(row.modelData.e); smooth: true; asynchronous: true
                        }
                        // Packages without an icon in the icon theme get a small tile with a plus.
                        Rectangle {
                            visible: row.isPkg && row.modelData.pkg.icon === ""
                            x: 12; anchors.verticalCenter: parent.verticalCenter
                            width: 26; height: 26; radius: 9
                            color: Theme.field
                            Icon { anchors.centerIn: parent; name: "plus"; size: 16; tone: "accent" }
                        }
                        Column {
                            x: 50; width: parent.width - 50 - (row.isHiddenApp ? 48 : 16)
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
                                text: row.isPkg ? row.modelData.pkg.name : row.modelData.e.name
                                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: Theme.fontBody; font.weight: Font.Medium
                            }
                            Text {
                                width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
                                visible: text !== ""
                                text: row.isPkg ? (row.modelData.pkg.repo + "  ·  " + row.modelData.pkg.ver + "  ·  " + row.modelData.pkg.desc) : (row.modelData.e.genericName || "")
                                color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: Theme.fontCaption
                            }
                        }
                        // Marker for apps that are currently hidden.
                        Icon {
                            visible: row.isHiddenApp
                            anchors.right: parent.right; anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            name: "eye-off"; size: 18; tone: "gray"
                        }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            // Real pointer movement only: scrolling under a still pointer must not steal the selection.
                            onPositionChanged: root.selected = row.index
                            onClicked: m => {
                                if (m.button === Qt.RightButton) { if (!row.isPkg) root.toggleHide(row.modelData.e) }
                                else root.activate(row.modelData)
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
                text: root.results[root.selected]?.pkg ? "Enter installs in a terminal" : (root.showHidden ? "Right-click to unhide" : "Right-click to hide")
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
