import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

ShellRoot {
  id: root

  // Centralized state tracker: which view the pill is showing ("" = resting)
  property string openPopup: ""

  // Most recently launched apps, newest first. Lives here so it
  // survives the launcher view being unloaded between opens.
  property var recentApps: []

  function toggle(name) {
    root.openPopup = root.openPopup === name ? "" : name
  }

  function noteLaunched(name) {
    let r = [name, ...root.recentApps.filter(n => n !== name)]
    if (r.length > 20) r.length = 20
    root.recentApps = r
  }

  // Right-click on a dock icon: a quick action that skips opening the view
  function secondary(view) {
    if (view === "mixer") {
      Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
    } else if (view === "media") {
      MediaPlayers.active?.togglePlaying()
    } else if (view === "capture") {
      Capture.toggleRecording()
    } else if (view === "connectivity") {
      Quickshell.execDetached(["sh", "-c",
        "if nmcli radio wifi | grep -q enabled; then nmcli radio wifi off; else nmcli radio wifi on; fi"])
    } else if (view === "wallpaper") {
      Quickshell.execDetached(["sh", "-c",
        "export PATH=\"$PATH:$HOME/.cargo/bin\"; " +
        "w=$(find \"$HOME/Pictures/Wallpapers\" -maxdepth 1 -type f " +
        "\\( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.jpeg' \\) | shuf -n1); " +
        "[ -n \"$w\" ] && \"$HOME/.config/scripts/setwall.sh\" \"$w\""])
    }
  }

  // Scrolling over a dock icon (dir: +1 up, -1 down)
  function scrolled(view, dir) {
    if (view === "mixer") {
      Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", dir > 0 ? "5%+" : "5%-"])
    } else if (view === "media") {
      if (dir > 0) MediaPlayers.active?.next()
      else MediaPlayers.active?.previous()
    }
  }

  // qs ipc call launcher toggle
  IpcHandler {
    target: "launcher"
    function toggle(): void { root.toggle("launcher") }
  }

  // qs ipc call power toggle
  IpcHandler {
    target: "power"
    function toggle(): void { root.toggle("power") }
  }

  // qs ipc call WallpaperPicker toggle
  IpcHandler {
    target: "WallpaperPicker"
    function toggle(): void { root.toggle("wallpaper") }
  }

  // qs ipc call media toggle
  IpcHandler {
    target: "media"
    function toggle(): void { root.toggle("media") }
  }

  // qs ipc call connectivity toggle
  IpcHandler {
    target: "connectivity"
    function toggle(): void { root.toggle("connectivity") }
  }

  // qs ipc call capture toggle
  IpcHandler {
    target: "capture"
    function toggle(): void { root.toggle("capture") }
  }

  // qs ipc call mixer toggle
  IpcHandler {
    target: "mixer"
    function toggle(): void { root.toggle("mixer") }
  }

  // qs ipc call weather toggle
  IpcHandler {
    target: "weather"
    function toggle(): void { root.toggle("weather") }
  }

  // qs ipc call performance toggle
  IpcHandler {
    target: "performance"
    function toggle(): void { root.toggle("performance") }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  PanelWindow {
    id: barWindow

    color: "transparent"
    // Act like a bar: reserve room for the resting pill (4px gap + 30px pill + 4px gap)
    // so windows tile below it. Opened views grow over the windows instead of pushing them.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 38

    // Typing in the launcher and wallpaper filter needs keyboard focus
    WlrLayershell.keyboardFocus: (root.openPopup === "launcher" || root.openPopup === "wallpaper")
      ? WlrKeyboardFocus.Exclusive
      : WlrKeyboardFocus.None

    // Fixed size, big enough for the largest view (wallpaper: 720 wide,
    // launcher / power: ~332 tall), so the window never resizes during a morph.
    implicitWidth: 740
    implicitHeight: 350
    anchors { top: true }

    // Only the pill takes input; the rest of the window is click-through
    mask: Region { item: pill }

    // ---------- THE PILL ----------
    Rectangle {
      id: pill
      readonly property bool powerOpen: root.openPopup === "power"
      readonly property bool launcherOpen: root.openPopup === "launcher"
      readonly property bool wallpaperOpen: root.openPopup === "wallpaper"
      readonly property bool mediaOpen: root.openPopup === "media"
      readonly property bool connectivityOpen: root.openPopup === "connectivity"
      readonly property bool captureOpen: root.openPopup === "capture"
      readonly property bool mixerOpen: root.openPopup === "mixer"
      readonly property bool weatherOpen: root.openPopup === "weather"
      readonly property bool performanceOpen: root.openPopup === "performance"
      readonly property bool viewOpen: performanceOpen || powerOpen || launcherOpen || wallpaperOpen || mediaOpen || connectivityOpen || captureOpen || mixerOpen || weatherOpen

      // Hover expands the pill; a short grace timer stops it flickering
      property bool expanded: false

      HoverHandler {
        id: hover
        onHoveredChanged: {
          if (hovered) {
            graceTimer.stop()
            pill.expanded = true
          } else {
            graceTimer.restart()
          }
        }
      }

      Timer {
        id: graceTimer
        interval: 300
        onTriggered: pill.expanded = false
      }

      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: 4

      // Target size per view. Add a line here for each view you port.
      readonly property size target:
        wallpaperOpen ? Qt.size(720, 172)
      : mediaOpen     ? Qt.size(600, 300)
      : connectivityOpen ? Qt.size(640, 300)
      : captureOpen   ? Qt.size(600, 260)
      : mixerOpen     ? Qt.size(220, 230)
      : weatherOpen   ? Qt.size(640, 330)
      : performanceOpen ? Qt.size(720, 320)
      : launcherOpen  ? Qt.size(360, 332)
      : powerOpen     ? Qt.size(260, 330)
      :                 Qt.size(restRow.implicitWidth + 28, 30)

      width: target.width
      height: target.height
      radius: Math.min(height / 2, 22)
      color: Colors.surface
      border.color: Colors.accent
      border.width: 1
      clip: true

      Behavior on width  { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
      Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

      // 0 while the pill is still growing, 1 once it has arrived
      readonly property real closeness:
        1 - Math.min(1, Math.max(Math.abs(width - target.width),
                                 Math.abs(height - target.height)) / 60)

      // ---------- REST / HOVER FACE ----------
      // Centre: the clock (and REC while recording). Left: workspaces + app icons.
      // Right: tray + system icons. Both sides are as wide as the wider one,
      // so the clock stays dead centre.
      Item {
        id: restRow
        anchors.centerIn: parent
        readonly property real sideW: pill.expanded ? Math.max(leftGroup.width, rightGroup.width) : 0
        readonly property real gap: pill.expanded ? 14 : 0
        implicitWidth: centerRow.width + 2 * (sideW + gap)
        width: implicitWidth
        height: 30
        opacity: pill.viewOpen ? 0 : 1
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // ----- centre: recording indicator + clock -----
        Row {
          id: centerRow
          anchors.centerIn: parent
          spacing: 10

          // shown at rest while recording; click to stop
          Text {
            id: recText
            visible: Capture.isRecording
            anchors.verticalCenter: parent.verticalCenter
            text: "󰑊  REC"
            color: "#FF5555"
            font.family: "Hack Nerd Font"
            font.pixelSize: 13

            SequentialAnimation on opacity {
              running: Capture.isRecording
              loops: Animation.Infinite
              NumberAnimation { to: 0.4; duration: 600 }
              NumberAnimation { to: 1.0; duration: 600 }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: Capture.toggleRecording()
            }
          }

          // the clock: click to open the launcher
          Text {
            anchors.verticalCenter: parent.verticalCenter
            // while an icon is hovered, the clock slot names it
            readonly property string hint: archMouse.containsMouse ? "Launcher" : dockIcons.hoverLabel
            text: hint !== "" ? hint : Qt.formatTime(clock.date, "HH:mm")
            color: hint !== "" ? Colors.accent : Colors.text
            width: pill.expanded ? 150 : implicitWidth
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.family: "Hack Nerd Font"
            font.pixelSize: 13

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggle("launcher")
            }
          }
        }

        // ----- left: Arch logo, workspaces, tray | active window -----
        Row {
          id: leftGroup
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: 12
          opacity: pill.expanded ? 1 : 0
          visible: opacity > 0.01
          Behavior on opacity { NumberAnimation { duration: 150 } }

          Row {
            id: leftBase
            spacing: 10
            anchors.verticalCenter: parent.verticalCenter

            // Arch logo: opens the launcher
            Text {
              id: archIcon
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf303"
              color: (archMouse.containsMouse || root.openPopup === "launcher") ? Colors.text : Colors.accent
              font.family: "Hack Nerd Font"
              font.pixelSize: 17
              Behavior on color { ColorAnimation { duration: Theme.animFast } }

              MouseArea {
                id: archMouse
                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggle("launcher")
              }
            }

            Item {
              width: wsItem.implicitWidth
              height: 24
              anchors.verticalCenter: parent.verticalCenter

              Workspaces {
                id: wsItem
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            // tray: only while an app has a tray icon
            Rectangle {
              visible: traySlot.visible
              width: 1; height: 14
              anchors.verticalCenter: parent.verticalCenter
              color: Colors.subtext
              opacity: 0.35
            }

            Item {
              id: traySlot
              visible: trayModule.active
              width: visible ? trayModule.implicitWidth : 0
              height: 24
              anchors.verticalCenter: parent.verticalCenter

              TrayModule {
                id: trayModule
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          Rectangle {
            width: 1; height: 14
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.subtext
            opacity: 0.35
          }

          // the active window: app name + title (for a browser, the page title).
          // It fills whatever room the right side's icons leave, so the pill never resizes.
          Item {
            id: winSlot
            readonly property var toplevel: ToplevelManager.activeToplevel
            readonly property string appName: {
              const id = toplevel ? (toplevel.appId || "") : ""
              return id === "" ? "" : id.charAt(0).toUpperCase() + id.slice(1)
            }
            width: Math.max(110, rightGroup.width - leftBase.width - 2 * leftGroup.spacing - 1)
            height: 24
            anchors.verticalCenter: parent.verticalCenter

            Row {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 8

              Text {
                id: appText
                text: winSlot.appName
                color: Colors.accent
                font.family: "Hack Nerd Font"
                font.pixelSize: 12
                font.bold: true
              }
              Text {
                width: Math.max(0, winSlot.width - appText.width - parent.spacing)
                text: winSlot.toplevel ? (winSlot.toplevel.title || "") : ""
                color: Colors.subtext
                elide: Text.ElideRight
                font.family: "Hack Nerd Font"
                font.pixelSize: 12
              }
            }
          }
        }

        // ----- right: every view as an icon -----
        Row {
          id: rightGroup
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          opacity: pill.expanded ? 1 : 0
          visible: opacity > 0.01
          Behavior on opacity { NumberAnimation { duration: 150 } }

          DockGroup {
            id: dockIcons
            anchors.verticalCenter: parent.verticalCenter
            activeView: root.openPopup
            onTriggered: view => root.toggle(view)
            onSecondary: view => root.secondary(view)
            onScrolled: (view, dir) => root.scrolled(view, dir)
            model: [
              { view: "wallpaper",    label: "Wallpaper", glyph: "\udb83\ude09" },
              { view: "weather",      label: "Weather", glyph: "\udb81\udd90" },
              { view: "media",        label: "Media", glyph: "\udb80\udf86" },
              { view: "performance",  label: "Performance", glyph: "\udb80\udf5b" },
              { view: "connectivity", label: "Network", glyph: "\udb81\udda9" },
              { view: "mixer",        label: "Mixer", glyph: "\udb81\udd7e" },
              { view: "capture",      label: "Capture", glyph: "\udb80\udd00" },
              { view: "power",        label: "Power", glyph: "\udb81\udc25" }
            ]
          }
        }
      }

      // ---------- POWER VIEW (only exists while open) ----------
      Loader {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        active: pill.powerOpen
        opacity: pill.closeness
        sourceComponent: PowerView {
          onCloseRequested: root.openPopup = ""
        }
      }

      // ---------- LAUNCHER VIEW (only exists while open) ----------
      Loader {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        active: pill.launcherOpen
        opacity: pill.closeness
        sourceComponent: LauncherView {
          recentApps: root.recentApps
          onLaunched: name => root.noteLaunched(name)
          onCloseRequested: root.openPopup = ""
        }
      }

      // ---------- WALLPAPER VIEW (only exists while open) ----------
      Loader {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        active: pill.wallpaperOpen
        opacity: pill.closeness
        sourceComponent: WallpaperView {
          onCloseRequested: root.openPopup = ""
        }
      }

      // ---------- PERFORMANCE VIEW (only exists while open) ----------
      Loader {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        active: pill.performanceOpen
        opacity: pill.closeness
        sourceComponent: PerformanceView {
          onCloseRequested: root.openPopup = ""
        }
      }

      // ---------- WEATHER VIEW (only exists while open) ----------
      Loader {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        active: pill.weatherOpen
        opacity: pill.closeness
        sourceComponent: WeatherView {
          onCloseRequested: root.openPopup = ""
        }
      }

      // ---------- MIXER VIEW (only exists while open) ----------
      Loader {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        active: pill.mixerOpen
        opacity: pill.closeness
        sourceComponent: MixerView {
          onCloseRequested: root.openPopup = ""
        }
      }

      // ---------- CAPTURE VIEW (only exists while open) ----------
      Loader {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        active: pill.captureOpen
        opacity: pill.closeness
        sourceComponent: CaptureView {
          onCloseRequested: root.openPopup = ""
        }
      }

      // ---------- CONNECTIVITY VIEW (only exists while open) ----------
      Loader {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        active: pill.connectivityOpen
        opacity: pill.closeness
        sourceComponent: ConnectivityView {
          onCloseRequested: root.openPopup = ""
        }
      }

      // ---------- MEDIA VIEW (only exists while open) ----------
      Loader {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        active: pill.mediaOpen
        opacity: pill.closeness
        sourceComponent: MediaView {
          onCloseRequested: root.openPopup = ""
        }
      }
    }

    // ---------- CLICK-OUTSIDE-TO-CLOSE ----------
    // The grab switches on shortly after a view opens, so the window
    // has time to take focus first (otherwise it clears instantly).
    property bool grabReady: false

    Connections {
      target: root
      function onOpenPopupChanged() {
        if (root.openPopup === "") {
          barWindow.grabReady = false
          grabDelay.stop()
        } else {
          grabDelay.restart()
        }
      }
    }

    Timer {
      id: grabDelay
      interval: 150
      onTriggered: barWindow.grabReady = root.openPopup !== ""
    }

    HyprlandFocusGrab {
      active: barWindow.grabReady
      windows: [ barWindow ]
      onCleared: {
        barWindow.grabReady = false
        root.openPopup = ""
      }
    }
  }
}
