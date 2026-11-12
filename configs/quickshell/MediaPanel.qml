// MediaPanel.qml — the dashboard's Media tab: blurred cover background, spinning record art,
// title, equalizer, progress, controls.
import Quickshell
import QtQuick
import QtQuick.Effects

DashPanel {
  id: root

  readonly property var player: MediaPlayers.active

  // MPRIS doesn't push position updates, so ask for one each second while this is on screen
  Timer {
    running: MediaPlayers.playing && root.visible
    interval: 1000
    repeat: true
    onTriggered: root.player?.positionChanged()
  }

  // run cava only while music is playing and this tab is on screen
  Binding {
    target: Cava
    property: "active"
    value: MediaPlayers.playing && root.visible
  }

  // ---------- blurred cover as the panel background ----------
  Image {
    id: bgSrc
    anchors.fill: parent
    visible: false
    source: root.player?.trackArtUrl ?? ""
    fillMode: Image.PreserveAspectCrop
    smooth: true
    asynchronous: true
  }

  Item {
    id: bgMask
    visible: false
    width: root.width
    height: root.height
    layer.enabled: true
    layer.smooth: true
    layer.samples: 4
    Rectangle { anchors.fill: parent; radius: root.radius; color: "black" }
  }

  MultiEffect {
    anchors.fill: parent
    visible: root.player !== null && bgSrc.status === Image.Ready
    source: bgSrc
    autoPaddingEnabled: false
    blurEnabled: true
    blur: 1.0
    blurMax: 64            // bigger = blurrier
    brightness: -0.35      // darker = text stays readable
    saturation: 0.3
    maskEnabled: true
    maskSource: bgMask
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1.0
  }

  Text {
    visible: root.player === null
    anchors.centerIn: parent
    text: "Nothing playing"
    color: Colors.subtext
    font.family: Theme.font
    font.pixelSize: 16
  }

  Row {
    visible: root.player !== null
    anchors.fill: parent
    anchors.margins: 24
    spacing: 28

    // album art as a spinning record
    Item {
      id: discSlot
      width: 250
      height: 250
      anchors.verticalCenter: parent.verticalCenter

      // source: placeholder + cover as plain squares
      Item {
        id: discSrc
        visible: false
        width: 250
        height: 250

        Rectangle {
          anchors.fill: parent
          color: Colors.track
          Text {
            anchors.centerIn: parent
            text: "󰎆"
            color: Colors.subtext
            font.family: Theme.font
            font.pixelSize: 56
          }
        }
        Image {
          anchors.fill: parent
          source: root.player?.trackArtUrl ?? ""
          fillMode: Image.PreserveAspectCrop
          smooth: true
          mipmap: true
          asynchronous: true
        }
      }

      // circle mask, a little smaller than the slot so the spinning edge never touches the quad edge
      Item {
        id: discMask
        visible: false
        width: 250
        height: 250
        layer.enabled: true
        layer.smooth: true
        layer.samples: 4
        Rectangle {
          anchors.centerIn: parent
          width: 242
          height: 242
          radius: 121
          color: "black"
        }
      }

      MultiEffect {
        id: disc
        anchors.fill: parent
        source: discSrc
        autoPaddingEnabled: false
        maskEnabled: true
        maskSource: discMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0

        RotationAnimator on rotation {
          from: 0
          to: 360
          duration: 18000          // lower = faster spin
          loops: Animation.Infinite
          running: root.visible
          paused: !MediaPlayers.playing
        }
      }

      // spindle hole (stays still, it is symmetric)
      Rectangle {
        anchors.centerIn: parent
        width: 20
        height: 20
        radius: 10
        antialiasing: true
        color: Qt.rgba(0, 0, 0, 0.65)
      }
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 250 - parent.spacing
      spacing: 18

      Column {
        width: parent.width
        spacing: 4
        Text {
          width: parent.width
          text: root.player?.trackTitle ?? ""
          color: Colors.text
          font.family: Theme.font
          font.pixelSize: 22
          font.bold: true
          elide: Text.ElideRight
        }
        Text {
          width: parent.width
          text: root.player?.trackArtist ?? ""
          color: Colors.subtext
          font.family: Theme.font
          font.pixelSize: 15
          elide: Text.ElideRight
        }
      }

      // cava equalizer
      Row {
        id: eq
        width: parent.width
        height: 40
        spacing: 4

        Repeater {
          model: Cava.bars
          Item {
            required property int index
            width: (eq.width - eq.spacing * (Cava.bars - 1)) / Cava.bars
            height: eq.height

            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              radius: width / 2
              height: Math.max(3, parent.height * (Cava.values[index] ?? 0))
              color: Colors.accent
              Behavior on height { NumberAnimation { duration: 70 } }
            }
          }
        }
      }

      // progress bar (click to seek) + times
      Column {
        width: parent.width
        spacing: 6
        visible: root.player?.lengthSupported ?? false

        Rectangle {
          width: parent.width
          height: 6
          radius: 3
          color: Colors.track

          Rectangle {
            height: parent.height
            radius: 3
            color: Colors.accent
            width: root.player && root.player.length > 0
                   ? parent.width * Math.min(1, root.player.position / root.player.length) : 0
          }
          MouseArea {
            anchors.fill: parent
            onPressed: mouse => {
              if (root.player?.canSeek && root.player.length > 0)
                root.player.position = (mouse.x / width) * root.player.length
            }
          }
        }
        Item {
          width: parent.width
          height: 14
          Text { text: MediaPlayers.fmt(root.player?.position ?? 0); color: Colors.subtext; font.pixelSize: 11 }
          Text {
            anchors.right: parent.right
            text: MediaPlayers.fmt(root.player?.length ?? 0)
            color: Colors.subtext
            font.pixelSize: 11
          }
        }
      }

      // prev / play-pause / next
      Row {
        spacing: 34
        Text {
          text: "󰒮"; color: Colors.text; font.pixelSize: 30; font.family: Theme.font
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.player?.previous() }
        }
        Text {
          text: MediaPlayers.playing ? "󰏤" : "󰐊"; color: Colors.accent; font.pixelSize: 38; font.family: Theme.font
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.player?.togglePlaying() }
        }
        Text {
          text: "󰒭"; color: Colors.text; font.pixelSize: 30; font.family: Theme.font
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.player?.next() }
        }
      }
    }
  }
}
