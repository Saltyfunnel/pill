pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import "../../Common"

// MPRIS player: cover art, title/artist, line controls, and progress bar.
Item {
    id: root
    readonly property var players: Mpris.players.values
    // Active player, reactive to Mpris.players: first the one playing; otherwise, one in
    // pause with title. Ignore "ghost" entries (Chromium/Electron apps that leave an
    // MPRIS stopped and without metadata when closing the tab/media) and the playerctld proxy.
    function usable(p) {
        if (!p || (p.dbusName || "").indexOf("playerctld") >= 0) return false
        if (p.isPlaying) return true
        return p.playbackState === MprisPlaybackState.Paused && (p.trackTitle || "") !== ""
    }
    readonly property MprisPlayer player: {
        for (const p of players) if (p.isPlaying && usable(p)) return p
        for (const p of players) if (usable(p)) return p
        return null
    }
    visible: player !== null
    implicitHeight: visible ? 64 : 0

    Timer {
        running: root.visible && root.player !== null && root.player.isPlaying
        interval: 1000; repeat: true
        onTriggered: root.player.positionChanged()
    }

    // Circular cover art (real clipping with mask), spins like a vinyl when playing.
    Item {
        id: art
        width: Theme.space8 + Theme.space4; height: Theme.space8 + Theme.space4
        anchors.verticalCenter: parent.verticalCenter
        readonly property bool hasArt: cover.status === Image.Ready
        property real angle: 0

        NumberAnimation {
            target: art; property: "angle"
            // Only spins when playing; with reduceMotion it stays fixed (less menu idle CPU).
            running: root.visible && root.player !== null && art.hasArt && root.player.isPlaying && !Theme.reduceMotion
            from: art.angle; to: art.angle + 360
            duration: 8000; loops: Animation.Infinite
        }

        // Fallback: light gray circle with note icon.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.field
            visible: !art.hasArt
            Icon { anchors.centerIn: parent; name: "music"; tone: "gray"; size: Theme.iconSm + 4 }
        }

        // The cover art spins INSIDE a layer (at 2x); the circular mask does not spin.
        // Thus the border is defined solely by the smoothed mask: no ring, no jaggies, no halo.
        Item {
            id: coverLayer
            anchors.fill: parent
            visible: false
            layer.enabled: art.hasArt && root.visible
            layer.smooth: true
            layer.mipmap: true
            layer.textureSize: Qt.size(width * 2, height * 2)
            Image {
                id: cover
                anchors.centerIn: parent
                width: parent.width; height: parent.height
                rotation: art.angle
                source: root.player ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
                antialiasing: true
                sourceSize: Qt.size(art.width * 2, art.height * 2)
            }
        }
        Item {
            id: circleMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(width * 2, height * 2)
            Rectangle { anchors.fill: parent; radius: width / 2; antialiasing: true }
        }
        MultiEffect {
            anchors.fill: parent
            visible: art.hasArt
            source: coverLayer
            maskEnabled: true
            maskSource: circleMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
        // Subtle central hole, like a record.
        Rectangle {
            anchors.centerIn: parent
            width: 7; height: 7; radius: 3.5
            color: Theme.raised; opacity: 0.85
            antialiasing: true
            visible: art.hasArt
        }
    }

    Column {
        anchors.left: art.right; anchors.leftMargin: 16
        anchors.right: controls.left; anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            width: parent.width; elide: Text.ElideRight
            text: root.player ? (root.player.trackTitle || I18n.tr("Untitled")) : ""
            color: Theme.textPrimary; font.family: Theme.font; font.pixelSize: Theme.fontLabel; font.weight: Font.DemiBold
        }
        Text {
            width: parent.width; elide: Text.ElideRight
            text: root.player ? (root.player.trackArtist || root.player.identity) : ""
            color: Theme.textSecondary; font.family: Theme.font; font.pixelSize: Theme.fontCaption
        }
        Item { width: 1; height: 6 }
        Rectangle {
            width: parent.width; height: 3; radius: 1.5; color: Theme.track
            visible: root.player !== null && root.player.lengthSupported && root.player.length > 0
            Rectangle {
                height: parent.height; radius: 1.5; color: Theme.fill
                width: root.player && root.player.length > 0 ? parent.width * Math.min(1, root.player.position / root.player.length) : 0
            }
        }
    }

    Row {
        id: controls
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Repeater {
            model: [
                { i: "prev", a: "prev", ok: root.player !== null && root.player.canGoPrevious },
                { i: root.player && root.player.isPlaying ? "pause" : "play", a: "play", ok: root.player !== null && root.player.canTogglePlaying },
                { i: "next", a: "next", ok: root.player !== null && root.player.canGoNext }
            ]
            delegate: Item {
                required property var modelData
                width: 32; height: 32
                Icon { anchors.centerIn: parent; name: modelData.i; size: 20; tone: modelData.ok ? "dark" : "gray" }
                MouseArea {
                    anchors.fill: parent
                    enabled: modelData.ok
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.a === "prev") root.player.previous()
                        else if (modelData.a === "next") root.player.next()
                        else root.player.togglePlaying()
                    }
                }
            }
        }
    }
}
