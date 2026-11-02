import QtQuick
import QtQuick.Controls
import QGroundControl
import QGroundControl.Controls
Switch {
    id: root
    HQAITheme { id: theme }
    implicitHeight: ScreenTools.isMobile ? 44 : 28
    implicitWidth: text !== "" ? label.implicitWidth : 42
    padding: 0
    Accessible.name: text
    contentItem: Text { id: label; text: root.text; font.family: theme.fontFamily; font.pointSize: 10; color: theme.text; verticalAlignment: Text.AlignVCenter; leftPadding: root.text !== "" ? 48 : 0 }
    indicator: Rectangle {
        implicitWidth: 36; implicitHeight: 18
        y: (root.height - height) / 2
        radius: 9
        color: root.checked ? theme.violet : theme.border
        opacity: root.enabled ? 1 : 0.45
        border.color: root.activeFocus ? theme.cyan : color
        Rectangle { width: 14; height: 14; y: 2; x: root.checked ? 20 : 2; radius: 7; color: "#eef1f7"; Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } } }
    }
}
