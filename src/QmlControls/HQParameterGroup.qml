pragma ComponentBehavior: Bound
import QtQuick
import QGroundControl
import QGroundControl.Controls

// Keep only the open/closing category materialized, behind a shrinking clip.
Item {
    id: root
    property string title
    property bool expanded: false
    property bool animationsEnabled: true
    property var groupModel
    required property Component groupDelegate
    property real reveal: expanded ? 1 : 0
    readonly property real bodyHeight: body.height
    signal toggleRequested()
    implicitHeight: categoryHeader.height + body.height

    Behavior on reveal {
        enabled: root.animationsEnabled
        NumberAnimation { duration: root.expanded ? 240 : 180; easing.type: Easing.OutCubic }
    }
    QGCButton {
        id: categoryHeader
        objectName: "parameterCategoryHeader"
        width: parent.width
        text: root.title
        checked: root.expanded
        leftPadding: ScreenTools.defaultFontPixelWidth
        rightPadding: ScreenTools.defaultFontPixelWidth * 3
        horizontalAlignment: Text.AlignLeft
        onClicked: root.toggleRequested()
        Text {
            anchors.right: parent.right
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth
            anchors.verticalCenter: parent.verticalCenter
            text: "›"
            color: QGroundControl.globalPalette.text
            font.pixelSize: ScreenTools.defaultFontPixelHeight
            rotation: 90 * root.reveal
        }
    }
    Item {
        id: body
        objectName: "parameterGroupBody"
        enabled: root.expanded
        anchors.top: categoryHeader.bottom
        width: parent.width
        height: loader.item ? loader.item.implicitHeight * root.reveal : 0
        clip: true
        Loader {
            id: loader
            width: parent.width
            active: root.expanded || root.reveal > 0
            sourceComponent: Column {
                spacing: Math.ceil(ScreenTools.defaultFontPixelHeight * 0.25)
                topPadding: spacing
                width: loader.width
                Repeater { model: root.groupModel; delegate: root.groupDelegate }
            }
        }
    }
}
