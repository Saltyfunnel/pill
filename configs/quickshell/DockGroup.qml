// DockGroup.qml — a row of icons with a fisheye zoom: they swell as the cursor nears them
// and ease back as it moves away. Used for both sides of the pill.
//   model: [{ view: "media", glyph: "...", label: "Media" }, ...]
//   activeView: the view that is open now (its icon stays highlighted)
//   triggered(view): an icon was left-clicked
//   secondary(view): an icon was right-clicked
//   scrolled(view, dir): the wheel moved over an icon (dir +1 = up, -1 = down)
import QtQuick

Item {
  id: dock

  property var model: []
  property string activeView: ""
  // the label of the icon under the cursor ("" when none), for the pill to show
  property string hoverLabel: ""
  signal triggered(string view)
  signal secondary(string view)
  signal scrolled(string view, int dir)

  implicitWidth: row.width
  implicitHeight: 24

  Row {
    id: row
    spacing: 4
    anchors.verticalCenter: parent.verticalCenter

    HoverHandler { id: dockHover }

    Repeater {
      model: dock.model

      Item {
        id: ic
        required property var modelData
        width: 22
        height: 24

        // distance from the cursor to this icon's centre -> zoom amount
        readonly property real dist: dockHover.hovered
          ? Math.abs(dockHover.point.position.x - (x + width / 2)) : 1000
        scale: 1 + 0.5 * Math.exp(-(dist * dist) / (2 * 26 * 26))
        Behavior on scale { NumberAnimation { duration: 70 } }

        Text {
          anchors.centerIn: parent
          // the weather icon shows the live conditions
          text: (ic.modelData.view === "weather" && Weather.loaded) ? Weather.icon : ic.modelData.glyph
          color: (iconMouse.containsMouse || dock.activeView === ic.modelData.view) ? Colors.text : Colors.accent
          font.family: "Hack Nerd Font"
          font.pixelSize: 15
          Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        MouseArea {
          id: iconMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onContainsMouseChanged: {
            if (containsMouse) dock.hoverLabel = ic.modelData.label ?? ""
            else if (dock.hoverLabel === (ic.modelData.label ?? "")) dock.hoverLabel = ""
          }
          onClicked: mouse => {
            if (mouse.button === Qt.RightButton) dock.secondary(ic.modelData.view)
            else dock.triggered(ic.modelData.view)
          }
        }

        // one step per wheel notch (touchpads accumulate until a full notch)
        WheelHandler {
          property real acc: 0
          onWheel: event => {
            acc += event.angleDelta.y
            while (acc >= 120)  { dock.scrolled(ic.modelData.view, 1);  acc -= 120 }
            while (acc <= -120) { dock.scrolled(ic.modelData.view, -1); acc += 120 }
            event.accepted = true
          }
        }
      }
    }
  }
}
