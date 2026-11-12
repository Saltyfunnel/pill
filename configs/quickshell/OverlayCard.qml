// OverlayCard.qml — the full-screen transparent overlay with a centred card.
// Clicking outside the card emits dismissed(). Anything you put inside it lands on the card.
//
//   OverlayCard {
//     shown: root.openPopup === root.popupName
//     cardWidth: 260; cardHeight: 280
//     onDismissed: root.toggle(root.popupName)
//     Column { anchors.fill: parent; anchors.margins: 20; ... }
//   }
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
  id: win

  property bool shown: false
  property int cardWidth: 260
  property int cardHeight: 280
  property int cardRadius: 18
  signal dismissed()
  default property alias content: holder.data

  visible: shown
  focusable: true
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"

  anchors { top: true; bottom: true; left: true; right: true }

  onVisibleChanged: if (visible) win.requestActivate()

  // transparent backdrop: a click anywhere outside the card dismisses it
  Rectangle {
    anchors.fill: parent
    color: "transparent"

    TapHandler { onTapped: win.dismissed() }

    Rectangle {
      anchors.centerIn: parent
      width: win.cardWidth
      height: win.cardHeight
      radius: win.cardRadius
      color: Colors.surface
      border.color: Colors.accent
      border.width: 1
      clip: true

      // absorb clicks inside the card so the backdrop doesn't see them
      MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

      Item { id: holder; anchors.fill: parent }
    }
  }
}
