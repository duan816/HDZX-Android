import QtQuick
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls

QGCButton {
    id: root

    required property Item targetItem

    z: 100
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: ScreenTools.defaultFontPixelWidth * 0.65
    visible: targetItem.expanded
    width: Math.max(ScreenTools.mobileTouchTarget, ScreenTools.defaultFontPixelHeight * 2.4)
    height: width
    padding: 0
    text: targetItem.fullScreen ? "↙" : "⛶"
    ToolTip.visible: hovered
    ToolTip.text: targetItem.fullScreen ? qsTr("退出全屏") : qsTr("全屏")

    onClicked: {
        if (targetItem.fullScreen) {
            if (targetItem.prepareFullScreenTransition !== undefined) targetItem.prepareFullScreenTransition()
            targetItem.fullScreen = false
            targetItem.x = targetItem.savedX
            targetItem.y = targetItem.savedY
            return
        }
        QGroundControl.showMessageDialog(root, qsTr("确认全屏显示"),
            qsTr("是否让此工具进入全屏显示？可随时点击“退出全屏”恢复。"),
            Dialog.Yes | Dialog.No, function() {
                targetItem.savedX = targetItem.x
                targetItem.savedY = targetItem.y
                if (targetItem.prepareFullScreenTransition !== undefined) targetItem.prepareFullScreenTransition()
                targetItem.expanded = true
                targetItem.fullScreen = true
                targetItem.x = 0
                targetItem.y = 0
            })
    }
}
