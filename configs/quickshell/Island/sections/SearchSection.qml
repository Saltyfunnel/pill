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
    function reset() { field.text = ""; field.focus = false }

    readonly property var results: Apps.search(query, 5)
    onResultsChanged: selected = 0

    function launch(entry) { if (entry) { entry.execute(); root.launched() } }

    Rectangle {
        id: box
        width: Math.round(parent.width); height: Theme.controlH + 8
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
                text: I18n.tr("Search")
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
        delegate: Rectangle {
            required property var modelData
            required property int index
            width: root.width; height: 40; radius: height / 2      // pill, like the field and launcher
            color: index === root.selected || hov.containsMouse ? Theme.field : "transparent"
            Image {
                id: ic
                x: 12; anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24
                sourceSize: Qt.size(48, 48)
                source: Apps.iconFor(modelData)
            }
            Text {
                anchors.left: ic.right; anchors.leftMargin: 12
                anchors.right: parent.right; anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: modelData.name
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: Theme.fontLabel
            }
            MouseArea {
                id: hov
                anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launch(modelData)
                onWheel: w => w.accepted = true   // do not change workspace over the list
            }
        }
    }
}
