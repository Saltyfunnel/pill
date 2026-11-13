import QtQuick

// Monochrome icon (Fluent UI System Icons, Filled; map in assets/icons/map.json) from
// assets/icons/<tone>/<name>.svg.
Image {
    property string name
    property string tone: "dark"   // dark | gray | white
    property int size: 20
    width: size; height: size
    sourceSize: Qt.size(size * 2, size * 2)
    // In dark mode they are inverted: "dark" (main) → white, "white" (on fill) → dark.
    readonly property string resolvedTone: !Theme.dark ? tone : (tone === "dark" ? "white" : tone === "white" ? "dark" : "graydark")
    source: name ? Qt.resolvedUrl("../assets/icons/" + resolvedTone + "/" + name + ".svg") : ""
    smooth: true
}
