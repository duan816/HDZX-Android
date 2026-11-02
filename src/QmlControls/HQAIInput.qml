import QtQuick
import QtQuick.Controls
import QGroundControl
import QGroundControl.Controls
TextField {
    id: root
    property bool monospace: false
    HQAITheme { id: theme }
    color: theme.text
    placeholderTextColor: theme.dim
    font.family: monospace ? theme.monoFamily : theme.fontFamily
    font.pointSize: 10
    selectByMouse: true
    Accessible.name: placeholderText
    padding: 8
    implicitHeight: ScreenTools.isMobile ? 44 : 34
    background: Rectangle { color: "#0e141d"; radius: 3; border.color: root.activeFocus ? theme.cyan : theme.border }
}
