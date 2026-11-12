// Main.qml — SDDM login screen that follows the wallpaper colours.
// Reads /var/cache/wal/colors.json (written by matugen). Only plain QtQuick is used,
// so it needs no extra Qt modules. Font: Hack Nerd Font.
import QtQuick 2.15

Rectangle {
  id: root
  width: 1920
  height: 1080

  // ---------- colours (defaults until colors.json is read) ----------
  property color bg:      "#1e1e2e"
  property color fg:      "#cdd6f4"
  property color dark:    "#11111b"
  property color accent:  "#89b4fa"
  property color danger:  "#f38ba8"
  readonly property string fontName: "Hack Nerd Font"

  color: bg

  function loadColors() {
    var xhr = new XMLHttpRequest()
    xhr.open("GET", "file:///var/cache/wal/colors.json")
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      try {
        var j = JSON.parse(xhr.responseText)
        if (j.special && j.special.background) root.bg = j.special.background
        if (j.special && j.special.foreground) root.fg = j.special.foreground
        if (j.colors) {
          if (j.colors.color0) root.dark   = j.colors.color0
          if (j.colors.color4) root.accent = j.colors.color4
          if (j.colors.color1) root.danger = j.colors.color1
        }
      } catch (e) {
        console.log("colors.json not readable, using defaults:", e)
      }
    }
    xhr.send()
  }

  Component.onCompleted: {
    loadColors()
    if (userField.text === "") userField.forceActiveFocus()
    else passField.forceActiveFocus()
  }

  // ---------- logging in ----------
  property bool failed: false

  function tryLogin() {
    root.failed = false
    sddm.login(userField.text, passField.text, sessionModel.lastIndex)
  }

  Connections {
    target: sddm
    function onLoginFailed() {
      root.failed = true
      passField.text = ""
      passField.forceActiveFocus()
      shake.restart()
    }
  }

  // ---------- clock ----------
  Text {
    id: clock
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height * 0.18
    color: root.fg
    font.family: root.fontName
    font.pixelSize: 96
    text: Qt.formatDateTime(new Date(), "HH:mm")
  }
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: clock.bottom
    anchors.topMargin: 6
    color: root.accent
    font.family: root.fontName
    font.pixelSize: 20
    text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
  }
  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: clock.text = Qt.formatDateTime(new Date(), "HH:mm")
  }

  // ---------- login box ----------
  Column {
    id: box
    anchors.centerIn: parent
    anchors.verticalCenterOffset: 70
    spacing: 14
    width: 320

    SequentialAnimation {
      id: shake
      NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: -12; duration: 50 }
      NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: 12;  duration: 80 }
      NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: -8;  duration: 70 }
      NumberAnimation { target: box; property: "anchors.horizontalCenterOffset"; to: 0;   duration: 50 }
    }

    // username
    Rectangle {
      width: parent.width; height: 46; radius: 23
      color: root.dark
      border.width: 1
      border.color: userField.activeFocus ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)

      Text {
        x: 18; anchors.verticalCenter: parent.verticalCenter
        text: "󰀄"; color: root.accent
        font.family: root.fontName; font.pixelSize: 16
      }
      TextInput {
        id: userField
        anchors.fill: parent
        anchors.leftMargin: 48; anchors.rightMargin: 18
        verticalAlignment: TextInput.AlignVCenter
        color: root.fg
        font.family: root.fontName; font.pixelSize: 14
        clip: true
        text: userModel.lastUser
        KeyNavigation.tab: passField
        Keys.onReturnPressed: passField.forceActiveFocus()
        Keys.onEnterPressed: passField.forceActiveFocus()
      }
    }

    // password
    Rectangle {
      width: parent.width; height: 46; radius: 23
      color: root.dark
      border.width: 1
      border.color: root.failed ? root.danger
                  : passField.activeFocus ? root.accent
                  : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)

      Text {
        x: 18; anchors.verticalCenter: parent.verticalCenter
        text: "󰌾"; color: root.failed ? root.danger : root.accent
        font.family: root.fontName; font.pixelSize: 16
      }
      TextInput {
        id: passField
        anchors.fill: parent
        anchors.leftMargin: 48; anchors.rightMargin: 18
        verticalAlignment: TextInput.AlignVCenter
        color: root.fg
        font.family: root.fontName; font.pixelSize: 14
        echoMode: TextInput.Password
        passwordCharacter: "●"
        clip: true
        KeyNavigation.backtab: userField
        onTextChanged: root.failed = false
        Keys.onReturnPressed: root.tryLogin()
        Keys.onEnterPressed: root.tryLogin()

        Text {
          visible: passField.text === ""
          anchors.verticalCenter: parent.verticalCenter
          text: "Password"; color: root.fg; opacity: 0.4
          font.family: root.fontName; font.pixelSize: 14
        }
      }
    }

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      visible: root.failed
      text: "Wrong password, try again"
      color: root.danger
      font.family: root.fontName; font.pixelSize: 12
    }
  }

  // ---------- reboot / shutdown ----------
  Row {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 32
    spacing: 14

    Repeater {
      model: [
        { icon: "󰜉", tip: "Reboot",   run: "reboot",   ok: sddm.canReboot },
        { icon: "󰐥", tip: "Shutdown", run: "poweroff", ok: sddm.canPowerOff }
      ]
      delegate: Rectangle {
        required property var modelData
        visible: modelData.ok
        width: 44; height: 44; radius: 22
        color: btnMouse.containsMouse ? root.accent : root.dark
        border.width: 1
        border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)

        Text {
          anchors.centerIn: parent
          text: modelData.icon
          color: btnMouse.containsMouse ? root.dark : root.accent
          font.family: root.fontName; font.pixelSize: 18
        }
        MouseArea {
          id: btnMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: modelData.run === "reboot" ? sddm.reboot() : sddm.powerOff()
        }
      }
    }
  }
}
