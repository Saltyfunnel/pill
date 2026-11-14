pragma ComponentBehavior: Bound
import QtQuick
import "../../Common"

// App launcher page (Super+D): search box and a list of applications.
//   Type    filter apps (Backspace edits)
//   Up / Down (or Tab / Shift+Tab)  move the selection
//   Enter or click  launch
//   Esc     clears the search first, then closes the island
// Keys arrive through the pill's Keys.forwardTo (see Island.qml).
Item {
    id: root
    signal done()
    readonly property int maxRows: 8
    readonly property int rowH: 46
    implicitHeight: col.implicitHeight

    property string query: ""
    property int selected: 0
    // Empty query lists apps alphabetically; otherwise ranked search results.
    readonly property var results: query.trim() === "" ? Apps.list(1000) : Apps.search(query, 60)

    function reset() { query = ""; selected = 0 }
    function move(d) { if (results.length > 0) selected = Math.max(0, Math.min(results.length - 1, selected + d)) }
    function launch(entry) { if (!entry) return; entry.execute(); done() }
    onQueryChanged: selected = 0

    Keys.onPressed: e => {
        if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
        if (e.key === Qt.Key_Down) { root.move(1); e.accepted = true }
        else if (e.key === Qt.Key_Up) { root.move(-1); e.accepted = true }
        else if (e.key === Qt.Key_Tab) { root.move(1); e.accepted = true }
        else if (e.key === Qt.Key_Backtab) { root.move(-1); e.accepted = true }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.launch(root.results[root.selected]); e.accepted = true }
        else if (e.key === Qt.Key_Backspace) { if (root.query.length > 0) root.query = root.query.slice(0, -1); e.accepted = true }
        else if (e.key === Qt.Key_Escape) { if (root.query !== "") root.query = ""; else root.done(); e.accepted = true }
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
                // Keep the keyboard selection in view.
                Connections {
                    target: root
                    function onSelectedChanged() { list.positionViewAtIndex(root.selected, ListView.Contain) }
                    function onResultsChanged() { list.positionViewAtBeginning() }
                }
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width; height: root.rowH; radius: 16
                    color: row.index === root.selected ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durMicro } }
                    Image {
                        x: 12; anchors.verticalCenter: parent.verticalCenter
                        width: 28; height: 28; sourceSize: Qt.size(56, 56)
                        source: Apps.iconFor(row.modelData); smooth: true; asynchronous: true
                    }
                    Column {
                        x: 52; width: parent.width - 52 - 20
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
                            text: row.modelData.name
                            color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: Theme.fontBody; font.weight: Font.Medium
                        }
                        Text {
                            width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
                            visible: text !== ""
                            text: row.modelData.genericName || ""
                            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: Theme.fontCaption
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        // Real pointer movement only: scrolling under a still pointer must not steal the selection.
                        onPositionChanged: root.selected = row.index
                        onClicked: root.launch(row.modelData)
                    }
                }
            }
            // Slim scroll indicator (only when the list is longer than the window).
            Rectangle {
                visible: list.contentHeight > list.height
                x: parent.width - 4; width: 3; radius: 1.5
                color: Theme.textSecondary; opacity: 0.5
                height: Math.max(24, list.height * list.height / list.contentHeight)
                y: list.contentHeight > list.height ? (list.height - height) * list.contentY / (list.contentHeight - list.height) : 0
            }
            Text {
                visible: root.results.length === 0
                anchors.centerIn: parent
                text: "No apps found"
                color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: Theme.fontLabel
            }
        }
    }
}
