import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

ShellRoot {
  id: root

  // Centralized state tracker to ensure mutually exclusive popups
  property string openPopup: ""

  function toggle(name) {
    root.openPopup = root.openPopup === name ? "" : name
  }

  // The app launcher: one overlay for the whole shell, opened from a keybind with
  //   qs ipc call launcher toggle
  Launcher {
    id: launcher
    openPopup: root.openPopup
    onToggle: name => root.toggle(name)
  }

  IpcHandler {
    target: "launcher"
    function toggle(): void { root.toggle("launcher") }
  }

  WallpaperPicker {
    id: wallpaperPicker
    openPopup: root.openPopup
    onToggle: name => root.toggle(name)
  }

  // Multi-monitor support across all active screens
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: barWindow
      required property var modelData
      screen: modelData

      color: "transparent"
      implicitHeight: 36

      anchors {
        top: true
        left: true
        right: true
      }

      // ---------- LEFT ISLAND: Workspaces & Window Title ----------
      Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 28
        width: leftRow.implicitWidth + 20
        radius: 15
        color: Colors.surface
        border.color: Colors.accent
        border.width: 1

        Row {
          id: leftRow
          anchors.centerIn: parent
          spacing: 14

          Workspaces {
            anchors.verticalCenter: parent.verticalCenter
          }

          WindowTitle {
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      // ---------- CENTER ISLAND: Clock ----------
      Rectangle {
        anchors.centerIn: parent
        height: 28
        width: centerRow.implicitWidth + 20
        radius: 15
        color: Colors.surface
        border.color: Colors.accent
        border.width: 1

        Row {
          id: centerRow
          anchors.centerIn: parent

          Dashboard {
            id: dashboard
            openPopup: root.openPopup
            onToggle: name => root.toggle(name)
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      // ---------- RIGHT ISLAND: Power ----------
      Rectangle {
        id: powerIsland
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 28
        width: powerRow.implicitWidth + 20
        radius: 15
        color: Colors.surface
        border.color: Colors.accent
        border.width: 1

        Row {
          id: powerRow
          anchors.centerIn: parent

          PowerModule {
            id: powerModule
            openPopup: root.openPopup
            onToggle: name => root.toggle(name)
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }

      // ---------- TRAY: only visible while an app has a tray icon ----------
      Rectangle {
        id: trayIsland
        visible: trayModule.active
        anchors.right: powerIsland.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: 28
        width: trayModule.implicitWidth + 20
        radius: 15
        color: Colors.surface
        border.color: Colors.accent
        border.width: 1

        TrayModule {
          id: trayModule
          anchors.centerIn: parent
        }
      }

      // ---------- RECORDING INDICATOR: only while recording; click to stop ----------
      Rectangle {
        id: recIsland
        visible: Capture.isRecording
        anchors.right: trayIsland.visible ? trayIsland.left : powerIsland.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: 28
        width: recText.implicitWidth + 20
        radius: 8
        color: Colors.surface
        border.color: "#FF5555"
        border.width: 1

        Text {
          id: recText
          anchors.centerIn: parent
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
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: Capture.toggleRecording()
        }
      }

      // Native Hyprland focus grab including bar and popup windows
      HyprlandFocusGrab {
        active: root.openPopup !== ""
        windows: [ barWindow, powerModule.popup, launcher.popup, dashboard.popup, wallpaperPicker.popup ]
        onCleared: root.openPopup = ""
      }
    }
  }
}
