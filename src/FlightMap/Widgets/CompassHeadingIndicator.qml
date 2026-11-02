import QtQuick
import QtQuick.Window

// Rotate a cached vector texture in the scene graph; no telemetry-driven repaint.
Image {
    id: control
    anchors.centerIn: parent
    width: compassSize / 3
    height: width
    property real compassSize: 0
    property real heading: 0
    property bool simplified: false
    source: "/hdzx/heading.svg"
    sourceSize.width: Math.ceil(width * Screen.devicePixelRatio)
    fillMode: Image.PreserveAspectFit
    mipmap: true
    rotation: Number.isFinite(heading) ? heading : 0
}
