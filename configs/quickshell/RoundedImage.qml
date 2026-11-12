// RoundedImage.qml — an image with rounded corners (QML clips rectangles only, so this masks it).
//   RoundedImage { source: "file:///path/to.jpg"; radius: 12 }
import QtQuick
import QtQuick.Effects

Item {
  id: root

  property alias source: img.source
  property int radius: 12
  property int decodeWidth: 0        // >0 = decode the image smaller, to save memory on thumbnails
  readonly property bool ready: img.status === Image.Ready

  Image {
    id: img
    anchors.fill: parent
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    sourceSize.width: root.decodeWidth > 0 ? root.decodeWidth : 0
    visible: false                   // drawn through the rounded mask below
  }

  Rectangle {
    id: mask
    anchors.fill: parent
    radius: root.radius
    layer.enabled: true
    visible: false
  }

  MultiEffect {
    anchors.fill: parent
    source: img
    maskEnabled: true
    maskSource: mask
    visible: root.ready
  }
}
