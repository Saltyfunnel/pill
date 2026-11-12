// DashMedia.qml — compact now-playing card: blurred cover as the card background,
// the cover as a circle in a progress ring, title and controls over the art.
import Quickshell
import QtQuick
import QtQuick.Effects

DashPanel {
  id: root

  readonly property var player: MediaPlayers.active

  // false = title/controls always shown over the art
  // true  = they only appear while the mouse is over the art
  property bool overlayOnHover: false

  Timer {
    running: MediaPlayers.playing && root.visible
    interval: 1000
    repeat: true
    onTriggered: root.player?.positionChanged()
  }

  // ---------- blurred cover as the card background ----------
  Image {
    id: bgSrc
    anchors.fill: parent
    visible: false
    source: root.player?.trackArtUrl ?? ""
    fillMode: Image.PreserveAspectCrop
    smooth: true
    asynchronous: true
  }

  // rounded-rectangle mask matching the card corners
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
    brightness: -0.3       // darker = text stays readable
    saturation: 0.3
    maskEnabled: true
    maskSource: bgMask
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1.0
  }

  Text {
    visible: root.player === null
    anchors.centerIn: parent
    text: "󰎆  Nothing playing"
    color: Colors.subtext
    font.family: Theme.font
    font.pixelSize: 13
  }

  // ---------- art + ring, sized from the card so it grows when the card grows ----------
  Item {
    id: stage
    visible: root.player !== null
    anchors.centerIn: parent
    width: Math.max(0, Math.min(root.width, root.height) - 24)
    height: width

    readonly property real artSize: Math.max(0, width - 26)
    readonly property bool showOverlay: !root.overlayOnHover || hover.hovered

    HoverHandler { id: hover }

    // source for the round art: placeholder + cover, as plain squares
    Item {
      id: artSrc
      visible: false
      width: stage.artSize
      height: stage.artSize

      Rectangle {
        anchors.fill: parent
        color: Colors.track
        Text {
          anchors.centerIn: parent
          text: "󰎆"
          color: Colors.subtext
          font.family: Theme.font
          font.pixelSize: stage.artSize * 0.3
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

    // circle mask
    Item {
      id: circleMask
      visible: false
      width: stage.artSize
      height: stage.artSize
      layer.enabled: true
      layer.smooth: true
      layer.samples: 4
      Rectangle { anchors.fill: parent; radius: width / 2; color: "black" }
    }

    // the round art; brightness dims it so the text stays readable
    MultiEffect {
      anchors.centerIn: parent
      width: stage.artSize
      height: stage.artSize
      source: artSrc
      autoPaddingEnabled: false
      maskEnabled: true
      maskSource: circleMask
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1.0
      brightness: stage.showOverlay ? -0.45 : 0
      Behavior on brightness { NumberAnimation { duration: 150 } }
    }

    // progress ring
    Canvas {
      id: ring
      anchors.fill: parent
      property real progress: root.player && root.player.length > 0
                              ? Math.min(1, root.player.position / root.player.length) : 0
      onProgressChanged: requestPaint()
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()

      onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        const cx = width / 2, cy = height / 2, r = width / 2 - 5
        ctx.lineWidth = 5
        ctx.lineCap = "round"

        ctx.strokeStyle = Colors.track
        ctx.beginPath()
        ctx.arc(cx, cy, r, 0, 2 * Math.PI)
        ctx.stroke()

        if (progress > 0) {
          ctx.strokeStyle = Colors.accent
          ctx.beginPath()
          ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * progress)
          ctx.stroke()
        }
      }
    }

    // title, artist and controls, centred on the art
    Column {
      anchors.centerIn: parent
      width: stage.artSize * 0.74
      spacing: Math.max(4, stage.artSize * 0.03)
      opacity: stage.showOverlay ? 1 : 0
      enabled: stage.showOverlay
      Behavior on opacity { NumberAnimation { duration: 150 } }

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.player?.trackTitle ?? ""
        color: Colors.text
        font.family: Theme.font
        font.pixelSize: Math.max(12, Math.round(stage.artSize * 0.09))
        font.bold: true
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.player?.trackArtist ?? ""
        color: Colors.subtext
        font.family: Theme.font
        font.pixelSize: Math.max(10, Math.round(stage.artSize * 0.07))
        elide: Text.ElideRight
      }

      Item { width: 1; height: Math.max(2, stage.artSize * 0.02) }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Math.max(14, stage.artSize * 0.12)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰒮"; color: Colors.text; font.family: Theme.font
          font.pixelSize: Math.max(18, Math.round(stage.artSize * 0.15))
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.player?.previous() }
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: MediaPlayers.playing ? "󰏤" : "󰐊"; color: Colors.accent; font.family: Theme.font
          font.pixelSize: Math.max(22, Math.round(stage.artSize * 0.2))
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.player?.togglePlaying() }
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰒭"; color: Colors.text; font.family: Theme.font
          font.pixelSize: Math.max(18, Math.round(stage.artSize * 0.15))
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.player?.next() }
        }
      }
    }
  }
}
