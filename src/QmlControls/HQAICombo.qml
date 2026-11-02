pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QGroundControl
import QGroundControl.Controls
ComboBox {
    id: root
    HQAITheme { id: theme }
    implicitHeight: ScreenTools.isMobile ? 44 : 34
    implicitWidth: 180
    padding: 8
    font.family: theme.fontFamily
    font.pointSize: 10
    palette.text: theme.text
    palette.buttonText: theme.text
    palette.base: theme.panel
    palette.window: theme.panel
    palette.highlight: "#263244"
    palette.highlightedText: theme.text
    background: Rectangle { color: "#0e141d"; radius: 3; border.color: root.activeFocus ? theme.cyan : theme.border }
    contentItem: Text { text: root.displayText; color: theme.text; font: root.font; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; rightPadding: 20 }
    indicator: Text { text: "⌄"; color: theme.dim; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter }
    delegate: ItemDelegate {
        id: optionDelegate
        required property int index
        required property var modelData
        width: root.popup.width
        highlighted: root.highlightedIndex === index
        contentItem: Text { text: String(optionDelegate.modelData); color: theme.text; font: root.font; wrapMode: Text.WordWrap }
        background: Rectangle { color: optionDelegate.highlighted ? "#263244" : theme.panel }
    }
}
