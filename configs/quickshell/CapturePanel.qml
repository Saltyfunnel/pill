// CapturePanel.qml — the dashboard's Capture tab: four screenshot tiles and a big record button.
// Asks the dashboard to close first (closeRequested) so it is not in the shot.
import QtQuick

DashPanel {
  signal closeRequested()

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
                     onClicked: { closeRequested(); Capture.screenshot("area") } }
        ActionTile { width: shots.tileW; height: shots.tileH; icon: "󱂬"; label: "Window";  sublabel: "Click a window"
                     onClicked: { closeRequested(); Capture.screenshot("window") } }
        ActionTile { width: shots.tileW; height: shots.tileH; icon: "󰔟";  label: "Fullscreen"; sublabel: "3 second delay"
                     onClicked: { closeRequested(); Capture.screenshot("screen") } }
        ActionTile { width: shots.tileW; height: shots.tileH; icon: "󰹑"; label: "Fullscreen"; sublabel: "Instant"
                     onClicked: { closeRequested(); Capture.screenshot("screen-nodelay") } }
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
        onClicked: { closeRequested(); Capture.toggleRecording() }
      }
    }
  }
}
