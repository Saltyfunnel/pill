// Theme.qml — shared sizes and timings, so the look is controlled from ONE place.
// (Colours live in Colors.qml and are generated from your wallpaper.)
// New files use these; older modules can be moved over one at a time.
pragma Singleton
import Quickshell
import QtQuick

Singleton {
  readonly property string font: "Hack Nerd Font"

  // corner radii
  readonly property int radiusLg: 18     // popups
  readonly property int radiusMd: 14     // panels inside popups
  readonly property int radiusSm: 10     // rows, buttons

  // spacing
  readonly property int pad: 18          // inside a popup
  readonly property int gap: 12          // between things

  // animation lengths (ms)
  readonly property int animFast: 150
  readonly property int animNormal: 250
}
