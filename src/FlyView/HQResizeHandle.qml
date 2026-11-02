import QtQuick

import QGroundControl
import QGroundControl.Controls

Item {
    id: handle
    objectName: "panelResizeHandle"

    required property var targetItem
    required property var motionController

    width: ScreenTools.isMobile ? Math.max(ScreenTools.minTouchPixels * 0.72, ScreenTools.defaultFontPixelWidth * 3)
                               : ScreenTools.defaultFontPixelWidth * 1.6
    height: Math.max(ScreenTools.minTouchPixels * 1.8, ScreenTools.defaultFontPixelHeight * 6)
    z: QGroundControl.zOrderTopMost + 80

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: resizeMouse.pressed ? "#D94CCFD5" : "#A9276882"
        Behavior on color { ColorAnimation { duration: 110 } }
        border.width: 1
        border.color: "#8BE8EC"

        Column {
            anchors.centerIn: parent
            spacing: 4
            Repeater {
                model: 3
                Rectangle { width: handle.width * 0.42; height: 2; radius: 1; color: "white" }
            }
        }
    }

    MouseArea {
        id: resizeMouse
        anchors.fill: parent
        preventStealing: true
        cursorShape: Qt.SizeHorCursor
        property real startGlobalX: 0
        property real startFactor: 1
        property real referenceWidth: 1

        onPressed: function(mouse) {
            motionController.beginResize()
            var p = mapToItem(null, mouse.x, mouse.y)
            startGlobalX = p.x
            startFactor = targetItem.sizeFactor
            referenceWidth = Math.max(120, targetItem.width)
        }
        onPositionChanged: function(mouse) {
            if (!pressed) return
            var p = mapToItem(null, mouse.x, mouse.y)
            var next = startFactor * (1 + (p.x - startGlobalX) / referenceWidth)
            targetItem.sizeFactor = motionController.boundedFactor(next)
        }
        onReleased: {
            motionController.endResize()
        }
        onCanceled: motionController.endResize()
    }
}
