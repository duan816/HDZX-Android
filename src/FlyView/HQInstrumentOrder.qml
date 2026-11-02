pragma ComponentBehavior: Bound
import QtQuick
import QGroundControl
import QGroundControl.Controls

// This editor reorders display keys only, never vehicle objects or commands.
Item {
    id: root
    property var keys: []
    property bool animationsEnabled: true
    property int sourceIndex: -1
    property int destinationIndex: -1
    property real startY: 0
    property real dragOffset: 0
    readonly property bool dragging: sourceIndex >= 0
    readonly property real rowHeight: Math.max(ScreenTools.minTouchPixels, ScreenTools.defaultFontPixelHeight * 2.5)
    readonly property real stride: rowHeight + 6
    implicitHeight: keys.length * stride
    signal orderRequested(string key, int index)

    function title(key) {
        const names = {speed: qsTr("速度表"), altitude: qsTr("高度带"),
            center: qsTr("航点 / 雷达 / 概览"), mode: qsTr("实际飞行模式")}
        return names[key] || key
    }
    function beginDrag(index, sceneY) {
        if (!enabled || index < 0 || index >= keys.length) return
        sourceIndex = index
        destinationIndex = index
        startY = sceneY
        dragOffset = 0
    }
    function moveDrag(sceneY) {
        if (!dragging) return
        dragOffset = Math.max(-sourceIndex * stride,
            Math.min((keys.length - 1 - sourceIndex) * stride, sceneY - startY))
        destinationIndex = Math.max(0, Math.min(keys.length - 1, Math.round(sourceIndex + dragOffset / stride)))
    }
    function finishDrag(canceled) {
        const key = keys[sourceIndex]
        const destination = destinationIndex
        const changed = dragging && sourceIndex !== destination
        sourceIndex = -1
        destinationIndex = -1
        dragOffset = 0
        if (!canceled && changed) orderRequested(key, destination)
    }
    onEnabledChanged: if (!enabled) finishDrag(true)
    onVisibleChanged: if (!visible) finishDrag(true)
    onKeysChanged: finishDrag(true)

    Repeater {
        model: root.keys
        delegate: Item {
            id: row
            required property string modelData
            required property int index
            readonly property bool held: root.sourceIndex === index
            readonly property real displacement: held ? root.dragOffset
                : root.sourceIndex < root.destinationIndex && index > root.sourceIndex && index <= root.destinationIndex ? -root.stride
                : root.sourceIndex > root.destinationIndex && index >= root.destinationIndex && index < root.sourceIndex ? root.stride : 0
            width: root.width
            height: root.rowHeight
            y: index * root.stride
            z: held ? 2 : 0
            transform: Translate {
                y: row.displacement
                Behavior on y { enabled: root.animationsEnabled && !row.held; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
            Rectangle {
                anchors.fill: parent
                radius: 8
                color: row.held ? "#24485B" : "#132D40"
                border.color: row.held ? "#65DAE3" : "#345264"
                border.width: row.held ? 2 : 1
            }
            QGCLabel {
                anchors.left: parent.left
                width: root.rowHeight
                height: parent.height
                text: "≡"
                color: "#65DAE3"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                MouseArea {
                    objectName: "orderGrip-" + row.modelData
                    anchors.fill: parent
                    cursorShape: row.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    preventStealing: row.held
                    property real pressedY: 0
                    onPressed: function(mouse) {
                        pressedY = mapToItem(root, mouse.x, mouse.y).y
                        if (!ScreenTools.isMobile) root.beginDrag(row.index, pressedY)
                    }
                    onPressAndHold: root.beginDrag(row.index, pressedY)
                    onPositionChanged: function(mouse) {
                        if (pressed && row.held) root.moveDrag(mapToItem(root, mouse.x, mouse.y).y)
                    }
                    onReleased: if (row.held) root.finishDrag(false)
                    onCanceled: if (row.held) root.finishDrag(true)
                }
            }
            QGCLabel {
                anchors.left: parent.left
                anchors.leftMargin: root.rowHeight
                anchors.right: parent.right
                anchors.rightMargin: 10
                height: parent.height
                text: (row.index + 1) + "  " + root.title(row.modelData)
                color: "#D9EEF4"
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
    }
}
