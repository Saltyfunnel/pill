// MediaPlayers.qml — which media player the dashboard shows (Spotify, mpv, a browser tab...).
// Prefers one that is playing right now, otherwise the first one found.
pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Singleton {
  readonly property var active: {
    const list = Mpris.players.values
    for (let i = 0; i < list.length; i++) {
      if (list[i].isPlaying) return list[i]
    }
    return list.length > 0 ? list[0] : null
  }
  readonly property bool playing: active?.isPlaying ?? false

  function fmt(s) {
    s = Math.max(0, Math.floor(s))
    const m = Math.floor(s / 60)
    const r = s % 60
    return m + ":" + (r < 10 ? "0" : "") + r
  }
}
