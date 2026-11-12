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

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  PanelWindow {
    id: barWindow

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

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
      readonly property bool viewOpen: powerOpen || launcherOpen || wallpaperOpen

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
      Row {
        id: restRow
        anchors.centerIn: parent
        spacing: 14
        opacity: pill.viewOpen ? 0 : 1
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // Workspaces: hover only
        Item {
          id: wsSlot
          visible: opacity > 0.01
          opacity: pill.expanded ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 150 } }
          width: visible ? wsItem.implicitWidth : 0
          height: 24
          anchors.verticalCenter: parent.verticalCenter

          Workspaces {
            id: wsItem
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        // The clock: always visible. Click to open the launcher
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: Qt.formatTime(clock.date, "HH:mm")
          color: Colors.text
          font.family: "Hack Nerd Font"
          font.pixelSize: 13

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggle("launcher")
          }
        }

        // Tray: hover only, and only while an app has a tray icon
        Item {
          id: traySlot
          visible: trayModule.active && opacity > 0.01
          opacity: pill.expanded ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 150 } }
          width: visible ? trayModule.implicitWidth : 0
          height: 24
          anchors.verticalCenter: parent.verticalCenter

          TrayModule {
            id: trayModule
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        // Recording indicator: shown at rest while recording; click to stop
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

        // Power icon: hover only
        Item {
          id: powerSlot
          visible: opacity > 0.01
          opacity: pill.expanded ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 150 } }
          width: visible ? 15 : 0
          height: 24
          anchors.verticalCenter: parent.verticalCenter

          Text {
            anchors.centerIn: parent
            text: "󰐥"
            color: powerMouse.containsMouse ? Colors.text : Colors.accent
            font.family: "Hack Nerd Font"
            font.pixelSize: 15
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
          }

          MouseArea {
            id: powerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggle("power")
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
