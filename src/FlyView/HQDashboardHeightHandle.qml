pragma ComponentBehavior: Bound
import QtQuick
import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    required property var targetItem
    required property var motionController
    objectName: "dashboardHeightHandle"
    width: Math.max(ScreenTools.minTouchPixels * 2.4, ScreenTools.defaultFontPixelWidth * 12)
    height: ScreenTools.isMobile ? ScreenTools.minTouchPixels * 0.65 : ScreenTools.defaultFontPixelHeight
    Rectangle {
        anchors.centerIn: parent; width: parent.width * 0.7; height: 4; radius: 2
        color: resizeArea.pressed ? "#9AF6F0" : "#56A9BC"
    }
    MouseArea {
        id: resizeArea
        anchors.fill: parent; preventStealing: true; cursorShape: Qt.SizeVerCursor
        property real startY: 0
        property real startHeight: 0
        onPressed: {
            root.motionController.beginResize()
            startY = mapToItem(null, mouseX, mouseY).y
            startHeight = root.targetItem.height
        }
        onPositionChanged: if (pressed) root.targetItem.setViewportHeight(startHeight + mapToItem(null, mouseX, mouseY).y - startY)
        onReleased: root.motionController.endResize()
        onCanceled: root.motionController.endResize()
    }
}
