import QtQuick
import QtQuick.Controls
import QGroundControl
import QGroundControl.Controls
Button {
    id: root
    property bool primary: false
    property bool danger: false
    property bool selected: false
    HQAITheme { id: theme }
    implicitHeight: ScreenTools.isMobile ? 44 : 36
    implicitWidth: Math.max(96, contentItem.implicitWidth + 24)
    padding: 10
    hoverEnabled: !ScreenTools.isMobile
    font.family: theme.fontFamily
    font.pointSize: 10
    scale: down ? 0.975 : 1
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
    contentItem: Text {
        text: root.text
        font: root.font
        color: !root.enabled ? theme.dim : root.primary ? theme.background : root.danger ? theme.red : root.selected ? theme.amber : theme.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
    }
    background: Rectangle {
        color: root.enabled && root.primary ? theme.amber : root.down ? "#2E4962" : root.hovered ? "#213448" : root.selected ? "#24384E" : theme.panel
        border.color: root.enabled && root.primary ? theme.amber : root.danger && root.enabled ? theme.red : root.activeFocus || root.hovered ? theme.cyan : theme.border
        Behavior on color { ColorAnimation { duration: 110 } }
        Behavior on border.color { ColorAnimation { duration: 110 } }
        radius: 3
        Rectangle { anchors.fill: parent; radius: 3; color: "white"; opacity: 0; Behavior on opacity { NumberAnimation { duration: 100 } } }
        HQButtonRipple { objectName: "actionButtonRipple"; control: root; rippleColor: root.primary ? theme.background : "#C6E5FF" }
    }
}
