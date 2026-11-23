import QtQuick
import "../../Common"
import ".."

// Power page: log out / reboot / shut down (each needs a second click to confirm).
Item {
    id: root
    signal back()
    signal done()
    implicitHeight: col.implicitHeight

    // Disarms any pending confirmation (called when the island closes).
    function reset() { actions.reset() }

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
                text: I18n.tr("Power")
                color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: Theme.fontClock; font.weight: Font.DemiBold
            }
        }

        ActionsSection {
            id: actions
            anchors.horizontalCenter: parent.horizontalCenter
            onDone: root.done()
        }
    }
}
