import QtQuick
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
Rectangle {
    id: root
    property string heading: ""
    property string caption: ""
    property color accent: "#222c3a"
    property real inset: 14
    default property alias cardContent: body.data
    HQAITheme { id: theme }
    color: theme.panel
    border.color: accent
    radius: 3
    implicitHeight: column.implicitHeight + inset * 2
    ColumnLayout {
        id: column
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: root.inset
        spacing: 10
        Text { Layout.fillWidth: true; visible: root.heading !== ""; text: root.heading; font.family: theme.fontFamily; font.pointSize: 11; font.bold: true; color: theme.text }
        Text { Layout.fillWidth: true; visible: root.caption !== ""; text: root.caption; font.family: theme.fontFamily; font.pointSize: 9; color: theme.dim; wrapMode: Text.WordWrap }
        ColumnLayout { id: body; Layout.fillWidth: true; spacing: 8 }
    }
}
