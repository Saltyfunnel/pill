import QtQuick
import Quickshell
import "../../Common"
import ".."

// Screenshot page: pick what to capture. The island closes first so it never ends up in the picture.
Item {
    id: root
    signal back()
    signal done()
    implicitHeight: col.implicitHeight

    readonly property string script: Qt.resolvedUrl("../../scripts/screenshot.sh").toString().replace("file://", "")

    function shoot(mode, wait) {
        Quickshell.execDetached(["sh", "-c", 'sleep "$2"; exec "$0" "$1"', root.script, mode, String(wait)])
        root.done()
    }

    Column {
        id: col
        width: parent.width
        spacing: 16

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
                text: I18n.tr("Screenshot")
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: Theme.fontClock; font.weight: Font.DemiBold
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            MenuButton { icon: "capture"; label: I18n.tr("Area"); onActivated: root.shoot("area", 0.3) }
            MenuButton { icon: "desktops"; label: I18n.tr("Window"); onActivated: root.shoot("window", 0.7) }
            MenuButton { icon: "display"; label: I18n.tr("Screen"); onActivated: root.shoot("screen", 0.7) }
            MenuButton { icon: "clock"; label: I18n.tr("In 3 s"); onActivated: root.shoot("delay", 0.3) }
        }
    }
}
