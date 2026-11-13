// CaptureView.qml — four screenshot tiles and a big record button, hosted inside the morphing pill.
// Closes the pill first (closeRequested) so it is not in the shot.
// Needs ActionTile from the old qshell, plus the Capture singleton.
import QtQuick

Item {
  id: root

  signal closeRequested()

  implicitWidth: 600
  implicitHeight: 260

  Row {
    anchors.fill: parent
    anchors.margins: 20
    spacing: 16

    // ----- screenshots: 2 x 2 tiles -----
    Column {
      width: (parent.width - parent.spacing) * 0.58
      height: parent.height
      spacing: 10

      Text {
        text: "Screenshot"
        color: Colors.text
        font.family: Theme.font
        font.pixelSize: 16
        font.bold: true
      }

      Grid {
        id: shots
        columns: 2
        spacing: 10
        width: parent.width
        readonly property real tileW: (width - spacing) / 2
        readonly property real tileH: (parent.height - 26 - 10 - spacing) / 2

        ActionTile { width: shots.tileW; height: shots.tileH; icon: "󰩭";   label: "Area";    sublabel: "Drag to select"
                     onClicked: { root.closeRequested(); Capture.screenshot("area") } }
        ActionTile { width: shots.tileW; height: shots.tileH; icon: "󱂬"; label: "Window";  sublabel: "Click a window"
                     onClicked: { root.closeRequested(); Capture.screenshot("window") } }
        ActionTile { width: shots.tileW; height: shots.tileH; icon: "󰔟";  label: "Fullscreen"; sublabel: "3 second delay"
                     onClicked: { root.closeRequested(); Capture.screenshot("screen") } }
        ActionTile { width: shots.tileW; height: shots.tileH; icon: "󰹑"; label: "Fullscreen"; sublabel: "Instant"
                     onClicked: { root.closeRequested(); Capture.screenshot("screen-nodelay") } }
      }
    }

    // ----- recording: one big tile -----
    Column {
      width: (parent.width - parent.spacing) * 0.42
      height: parent.height
      spacing: 10

      Text {
        text: "Screen recording"
        color: Colors.text
        font.family: Theme.font
        font.pixelSize: 16
        font.bold: true
      }

      ActionTile {
        width: parent.width
        height: parent.height - 26 - 10
        icon: "󰑊"
        iconSize: 52
        iconColor: Capture.isRecording ? "#FF5555" : Colors.accent
        label: Capture.isRecording ? "Stop recording" : "Record screen"
        sublabel: Capture.isRecording ? "Recording..." : "Not recording"
        onClicked: { root.closeRequested(); Capture.toggleRecording() }
      }
    }
  }
}
