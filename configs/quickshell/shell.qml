//@ pragma UseQApplication
// wallpaper layer removed; colours come from matugen via Common/Theme.qml.
import QtQuick
import Quickshell
import "Island"

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Island {
            required property var modelData
            screen: modelData
        }
    }
}
