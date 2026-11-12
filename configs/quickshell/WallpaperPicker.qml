// WallpaperPicker.qml — bar icon + a carousel wallpaper picker.
//   A big preview of the selected wallpaper, and a coverflow strip of thumbnails.
//   Left / Right (or the mouse wheel) move along the strip, Enter or a click on the selected one applies it.
//   Type to search. Tab picks a random one. Esc closes.
//   Applying hands the path to setwall.sh, which recolours everything.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Effects

Item {
  id: root

  property string popupName: "wallpaper"
  property string openPopup: ""
  signal toggle(string name)

  IpcHandler {
    target: "WallpaperPicker"
    function toggle(): void {
      root.toggle(root.popupName)
    }
  }

  property alias popup: card        // shell.qml's focus grab uses this

  property bool isVisible: root.openPopup === root.popupName

  property string homeDir: Quickshell.env("HOME")
  property string wallpaperDir: homeDir + "/Pictures/Wallpapers"
  property string searchQuery: ""

  // every wallpaper found: [{ path, name }]
  property var all: []
  // the ones matching the search
  property var results: {
    const q = root.searchQuery
    if (q === "") return root.all
    return root.all.filter(w => w.name.toLowerCase().includes(q))
  }
  property var current: strip.currentIndex >= 0 && strip.currentIndex < results.length ? results[strip.currentIndex] : null

  implicitWidth: 32
  implicitHeight: 24

  function apply(w) {
    if (!w) return
    Quickshell.execDetached([
      "sh", "-c",
      "export PATH=\"$PATH:" + root.homeDir + "/.cargo/bin\"; " +
      "export HYPRLAND_INSTANCE_SIGNATURE=\"" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "\"; " +
      "\"" + root.homeDir + "/.config/scripts/setwall.sh\" \"" + w.path + "\""
    ])
    root.toggle(root.popupName)
  }

  // ---------- bar icon ----------
  Text {
    anchors.centerIn: parent
    color: Colors.text
    font.family: "Hack Nerd Font"
    font.pixelSize: 15
    text: "󰸉"
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggle(root.popupName)
  }

  // ---------- scanning the wallpaper folder whenever the card is open ----------
  Process {
    id: loadWallpapers
    command: ["sh", "-c", "find \"" + root.wallpaperDir + "\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.jpeg' \\) | sort"]
    running: root.isVisible
    onRunningChanged: if (running) root.all = []
    stdout: SplitParser {
      onRead: data => {
        const path = data.trim()
        if (path !== "") root.all = root.all.concat([{ path: path, name: path.split("/").pop() }])
      }
    }
  }

  // ---------- the card ----------
  OverlayCard {
    id: card
    shown: root.isVisible
    cardWidth: 1000
    cardHeight: 640
    cardRadius: 22
    onDismissed: root.toggle(root.popupName)

    onVisibleChanged: {
      if (!visible) {
        root.all = []
        root.searchQuery = ""
        searchField.text = ""
      } else {
        strip.currentIndex = 0
        searchField.forceActiveFocus()
      }
    }

    // ----- blurred wallpaper backdrop: the card takes on the colours of the selection -----
    Image {
      id: bgSrc
      anchors.fill: parent
      sourceSize.width: 160       // tiny decode, the blur hides it anyway
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      source: root.current ? "file://" + root.current.path : ""
      visible: false
      layer.enabled: true
    }
    Rectangle {                    // rounded-corner mask for the blur
      id: bgMask
      anchors.fill: parent
      radius: 22
      visible: false
      layer.enabled: true
    }
    MultiEffect {
      anchors.fill: parent
      source: bgSrc
      maskEnabled: true
      maskSource: bgMask
      blurEnabled: true
      blur: 1.0
      blurMax: 64
      saturation: 0.3
    }
    Rectangle {                    // darken so text stays readable
      anchors.fill: parent
      radius: 22
      color: Qt.rgba(0, 0, 0, 0.55)
    }

    // Mouse wheel / touchpad scrolling anywhere across the card.
    // Accumulates delta so a touchpad swipe steps once per ~120 units instead of firing wildly.
    WheelHandler {
      id: wheel
      property real acc: 0
      onWheel: event => {
        const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
        acc += delta
        while (acc >= 120) { strip.decrementCurrentIndex(); acc -= 120 }
        while (acc <= -120) { strip.incrementCurrentIndex(); acc += 120 }
        event.accepted = true
      }
    }

    Column {
      anchors.fill: parent
      anchors.margins: 24
      spacing: 14

      // ----- header: title + search -----
      Row {
        width: parent.width
        height: 38
        spacing: 16

        Row {
          spacing: 10
          anchors.verticalCenter: parent.verticalCenter
          Text {
            text: "󰸉"
            color: Colors.accent
            font.family: "Hack Nerd Font"
            font.pixelSize: 22
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: "Wallpapers"
            color: Colors.text
            font.family: "Hack Nerd Font"
            font.pixelSize: 18
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Rectangle {
          width: 280
          height: 34
          radius: 17
          color: Colors.card
          border.color: searchField.activeFocus ? Colors.accent : "transparent"
          border.width: 1
          anchors.verticalCenter: parent.verticalCenter

          Row {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 8

            Text {
              text: "󰍉"
              color: Colors.accent
              font.family: "Hack Nerd Font"
              font.pixelSize: 14
              anchors.verticalCenter: parent.verticalCenter
            }

            TextInput {
              id: searchField
              width: parent.width - 28
              height: parent.height
              color: Colors.text
              font.family: "Hack Nerd Font"
              font.pixelSize: 13
              verticalAlignment: TextInput.AlignVCenter
              clip: true

              onTextChanged: {
                root.searchQuery = text.trim().toLowerCase()
                strip.currentIndex = 0
              }
              Keys.onEscapePressed: root.toggle(root.popupName)
              Keys.onReturnPressed: root.apply(root.current)
              Keys.onEnterPressed: root.apply(root.current)
              // Left / Right move along the strip, unless you are editing a search
              Keys.onLeftPressed: event => { if (text === "") strip.decrementCurrentIndex(); else event.accepted = false }
              Keys.onRightPressed: event => { if (text === "") strip.incrementCurrentIndex(); else event.accepted = false }
              // Tab jumps to a random wallpaper
              Keys.onTabPressed: event => {
                if (root.results.length > 0)
                  strip.currentIndex = Math.floor(Math.random() * root.results.length)
                event.accepted = true
              }

              Text {
                text: "Search..."
                color: Colors.text
                opacity: 0.4
                font.family: "Hack Nerd Font"
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
                visible: searchField.text === ""
              }
            }
          }
        }
      }

      // ----- big preview of the selected wallpaper -----
      Item {
        width: parent.width
        height: 300

        Rectangle { anchors.fill: parent; radius: 16; color: Colors.card }

        RoundedImage {
          id: previewImg
          anchors.fill: parent
          radius: 16
          source: root.current ? "file://" + root.current.path : ""
        }

        Connections {
          target: root
          function onCurrentChanged() { swap.restart() }
        }
        ParallelAnimation {
          id: swap
          NumberAnimation { target: previewImg; property: "opacity"; from: 0.3; to: 1; duration: 260 }
          NumberAnimation { target: previewImg; property: "scale"; from: 0.96; to: 1; duration: 360; easing.type: Easing.OutCubic }
        }

        // caption pill: name + position
        Rectangle {
          visible: root.current !== null
          anchors.left: parent.left
          anchors.bottom: parent.bottom
          anchors.margins: 14
          height: 30
          width: capText.implicitWidth + 28
          radius: 15
          color: Qt.rgba(0, 0, 0, 0.55)
          Text {
            id: capText
            anchors.centerIn: parent
            color: "white"
            font.family: "Hack Nerd Font"
            font.pixelSize: 12
            text: root.current ? root.current.name + "   ·   " + (strip.currentIndex + 1) + " / " + root.results.length : ""
          }
        }

        Text {
          anchors.centerIn: parent
          visible: root.results.length === 0
          text: root.all.length === 0 ? "No wallpapers found in ~/Pictures/Wallpapers" : "No matches"
          color: Colors.subtext
          font.pixelSize: 14
        }
      }

      // ----- the strip -----
      ListView {
        id: strip
        width: parent.width
        height: 168
        orientation: ListView.Horizontal
        model: root.results
        clip: true
        currentIndex: 0
        highlightRangeMode: ListView.StrictlyEnforceRange     // keep the selected one centred
        preferredHighlightBegin: width / 2 - 120
        preferredHighlightEnd: width / 2 + 120
        highlightMoveDuration: 220

         interactive: false          // we drive currentIndex ourselves (wheel + drag below)

        // mouse wheel / touchpad over the strip
        WheelHandler {
          property real acc: 0
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: event => {
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
            acc += delta
            while (acc >= 120)  { strip.decrementCurrentIndex(); acc -= 120 }
            while (acc <= -120) { strip.incrementCurrentIndex(); acc += 120 }
            event.accepted = true
          }
        }

        // click and drag along the strip
        DragHandler {
          id: stripDrag
          target: null
          yAxis.enabled: false
          property real done: 0
          onActiveChanged: if (active) done = 0
          onTranslationChanged: {
            const step = 110
            while (translation.x - done >= step)  { strip.decrementCurrentIndex(); done += step }
            while (translation.x - done <= -step) { strip.incrementCurrentIndex(); done -= step }
          }
        }

        delegate: Item {
          id: del
          required property var modelData
          required property int index
          readonly property bool selected: ListView.isCurrentItem
          // distance from the strip's centre drives scale / opacity / tilt continuously
          readonly property real dist: (x + width / 2) - (strip.contentX + strip.width / 2)
          readonly property real norm: Math.max(-1, Math.min(1, dist / 320))

          width: 240
          height: strip.height
          z: 10 - Math.abs(norm) * 5
          scale: 1.15 - 0.3 * Math.abs(norm)
          opacity: 1 - 0.45 * Math.abs(norm)
          transform: Rotation {
            origin.x: del.width / 2
            origin.y: del.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: -del.norm * 35
          }

          Column {
            anchors.centerIn: parent
            spacing: 8

            Item {
              width: 200
              height: 112

              // accent glow: a plain rounded rect, blurred, sitting behind the thumbnail
              Rectangle {
                id: glowSrc
                anchors.fill: parent
                radius: 12
                color: Colors.accent
                visible: false
                layer.enabled: true
              }
              MultiEffect {
                anchors.fill: parent
                anchors.margins: -6
                source: glowSrc
                blurEnabled: true
                blur: 1.0
                blurMax: 32
                opacity: del.selected ? 0.8 : 0
                Behavior on opacity { NumberAnimation { duration: 220 } }
              }

              Rectangle {
                anchors.fill: parent
                radius: 12
                color: Colors.card
              }
              RoundedImage {
                anchors.fill: parent
                radius: 12
                decodeWidth: 400
                source: "file://" + del.modelData.path
              }
              Rectangle {
                anchors.fill: parent
                radius: 12
                color: "transparent"
                border.width: del.selected ? 2 : 0
                border.color: Colors.accent
              }
            }

            Text {
              width: 200
              text: del.modelData.name
              color: del.selected ? Colors.text : Colors.subtext
              font.family: "Hack Nerd Font"
              font.pixelSize: 11
              elide: Text.ElideMiddle
              horizontalAlignment: Text.AlignHCenter
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (del.selected) root.apply(del.modelData); else strip.currentIndex = del.index
          }
        }
      }

      // ----- keycap hints -----
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 18
        Repeater {
          model: [["← →", "browse"], ["Enter", "apply"], ["Tab", "random"], ["Esc", "close"]]
          delegate: Row {
            required property var modelData
            spacing: 6
            Rectangle {
              height: 20
              width: keyText.implicitWidth + 14
              radius: 6
              color: Colors.card
              border.color: Colors.subtext
              border.width: 1
              Text {
                id: keyText
                anchors.centerIn: parent
                text: modelData[0]
                color: Colors.text
                font.family: "Hack Nerd Font"
                font.pixelSize: 10
              }
            }
            Text {
              text: modelData[1]
              color: Colors.subtext
              font.family: "Hack Nerd Font"
              font.pixelSize: 11
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }
    }
  }
}
