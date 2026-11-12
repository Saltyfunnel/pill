// Config.qml — the few settings that are personal to you. Change them here.
pragma Singleton
import Quickshell
import QtQuick

Singleton {
  // Your town, for the weather. Anything wttr.in understands: "Lhanbryde", "Elgin,Scotland", ...
  readonly property string weatherTown: "Lhanbryde"
}
