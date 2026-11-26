import QtQuick
import Quickshell
import "../../Common"

// Installed applications search bar (DesktopEntries).
Column {
    id: root
    signal launched()
    property alias query: field.text
    readonly property bool hasFocus: field.activeFocus
    property int selected: 0
    spacing: Theme.space1

    function focusField() { field.text = ""; field.forceActiveFocus() }
    function reset() { field.text = ""; field.focus = false; pk.reset() }

    // Installed apps first, then (2+ letters) up to 3 packages from the official repos
    // that are not installed yet.
    PkgSearch { id: pk; query: root.query; limit: 3 }
    readonly property var results: {
        const apps = Apps.search(query, 5).map(e => ({ e: e }))
        return apps.concat(pk.clean.length >= 2 ? pk.results.map(p => ({ pkg: p })) : [])
    }
    onResultsChanged: selected = 0

    // Terminal apps (Terminal=true in the .desktop file, e.g. btop) need a terminal around them.
    function run(entry) {
        if (entry.runInTerminal)
            Quickshell.execDetached(["kitty", "-e"].concat(entry.command.filter(a => !/^%[a-zA-Z]$/.test(a))))
        else
            entry.execute()
    }

    // Launch the app, or install the package in a terminal.
    function launch(item) {
        if (!item) return
        if (item.pkg) pk.install(item.pkg)
        else { Apps.recordLaunch(item.e); run(item.e) }
        root.launched()
    }

    Rectangle {
        id: box
        width: Math.round(parent.width); height: Theme.controlH + 2
        radius: height / 2                   // pill
        // Spotlight style: fine semi-transparent thread; with focus, raised surface,
        // sharper border and a soft ring around it (without blur or panel transparency).
        readonly property bool on: field.activeFocus
        color: on ? Theme.raised : Theme.field
        border.width: 1
        border.color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, on ? 0.40 : 0.20)
        Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
        antialiasing: true
        Rectangle {
            anchors.fill: parent; anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.width: 3
            border.color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.08)
            opacity: box.on ? 1 : 0
            scale: box.on ? 1 : 0.985
            Behavior on opacity { NumberAnimation { duration: Theme.durFast + 40; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.durFast + 80; easing.type: Easing.OutCubic } }
            antialiasing: true
        }
        // The entire pill is clickable: a click anywhere focuses the field.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onPressed: field.forceActiveFocus()
            onWheel: w => w.accepted = true
        }
        Icon {
            id: lupa
            x: 16; anchors.verticalCenter: parent.verticalCenter
            name: "search"; tone: "gray"; size: Theme.iconSm
        }
        TextInput {
            id: field
            cursorVisible: activeFocus
            anchors.left: lupa.right; anchors.leftMargin: 8
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.textPrimary
            selectionColor: Theme.hover
            selectedTextColor: Theme.textPrimary
            // The "|" cursor is only drawn when the search bar has focus.
            cursorDelegate: Rectangle { width: 2; radius: 1; color: Theme.textPrimary; visible: field.activeFocus && field.cursorVisible }
            font.family: Theme.font; font.pixelSize: Theme.fontBody
            clip: true
            Text {
                visible: !field.text
                text: I18n.tr("Search apps & packages")
                color: Theme.textSecondary
                font: field.font
            }
            Keys.onDownPressed: root.selected = Math.min(root.selected + 1, root.results.length - 1)
            Keys.onUpPressed: root.selected = Math.max(root.selected - 1, 0)
            onAccepted: root.launch(root.results[root.selected])
        }
    }

    Repeater {
        model: root.results
        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool isPkg: row.modelData.pkg !== undefined
            // Small caption above the first package row.
            readonly property int headH: row.isPkg && (row.index === 0 || root.results[row.index - 1].pkg === undefined) ? 20 : 0
            width: root.width; height: row.headH + 40

            Text {
                visible: row.headH > 0
                x: 14; y: 3
                text: I18n.tr("Install from repos")
                color: Theme.textSecondary
                font.family: Theme.font; font.pixelSize: Theme.fontCaption; font.weight: Font.DemiBold
            }
            Rectangle {
                y: row.headH; width: parent.width; height: 40; radius: 20      // pill, like the field and launcher
                color: row.index === root.selected || hov.containsMouse ? Theme.field : "transparent"
                Image {
                    id: ic
                    visible: !row.isPkg || row.modelData.pkg.icon !== ""
                    x: 12; anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24
                    sourceSize: Qt.size(48, 48)
                    source: row.isPkg ? row.modelData.pkg.icon : Apps.iconFor(row.modelData.e)
                }
                // Packages without an icon in the icon theme get a small tile with a plus.
                Rectangle {
                    visible: row.isPkg && row.modelData.pkg.icon === ""
                    x: 12; anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24; radius: 8
                    color: Theme.raised
                    Icon { anchors.centerIn: parent; name: "plus"; size: 14; tone: "accent" }
                }
                Text {
                    anchors.left: ic.right; anchors.leftMargin: 12
                    anchors.right: row.isPkg ? ver.left : parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: row.isPkg ? row.modelData.pkg.name : row.modelData.e.name
                    color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: Theme.fontLabel
                }
                Text {
                    id: ver
                    visible: row.isPkg
                    anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.isPkg ? row.modelData.pkg.repo + "  ·  " + row.modelData.pkg.ver : ""
                    color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: Theme.fontCaption
                }
                MouseArea {
                    id: hov
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.launch(row.modelData)
                    onWheel: w => w.accepted = true   // do not change workspace over the list
                }
            }
        }
    }
}
