pragma ComponentBehavior: Bound
import QtQuick
import "../../Common"

// Clipboard item: text (max 2 lines) or "Image".
// Click: copy. On hover: pin/unpin and remove.
Rectangle {
    id: row
    property string text
    property bool binary: false
    property bool pinned: false
    property bool removable: true
    signal picked()
    signal pinToggled()
    signal removeRequested()

    // "[[ binary data 182 KiB png 1920x1080 ]]" → "PNG Image · 1920 × 1080".
    function imageText() {
        const m = row.text.match(/binary data .*?(\w+)\s+(\d+)x(\d+)/)
        return m ? I18n.tr("%1 Image · %2 × %3", m[1].toUpperCase(), m[2], m[3]) : I18n.tr("Image")
    }

    implicitHeight: Math.max(44, label.implicitHeight + 22)
    radius: 12
    color: hov.hovered ? Theme.hover : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.durMicro } }

    HoverHandler { id: hov }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: row.picked() }

    Text {
        id: label
        anchors.left: parent.left; anchors.leftMargin: 14
        anchors.right: tools.left; anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: row.binary ? row.imageText() : row.text.replace(/\s+/g, " ").trim()
        maximumLineCount: 2
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        color: row.binary ? Theme.textSecondary : Theme.textPrimary
        font.family: Theme.font; font.pixelSize: Theme.fontLabel
    }
    Row {
        id: tools
        anchors.right: parent.right; anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        // Always visible if pinned; otherwise, only on hover.
        Rectangle {
            visible: !row.binary && (row.pinned || hov.hovered)
            width: 30; height: 30; radius: 15
            color: pm.containsMouse ? Theme.field : "transparent"
            Icon { anchors.centerIn: parent; name: "pin"; size: 16; tone: row.pinned ? "dark" : "gray" }
            MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.pinToggled() }
        }
        Rectangle {
            visible: row.removable && hov.hovered
            width: 30; height: 30; radius: 15
            color: xm.containsMouse ? Theme.field : "transparent"
            Icon { anchors.centerIn: parent; name: "dismiss"; size: 14; tone: "gray" }
            MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.removeRequested() }
        }
    }
}
