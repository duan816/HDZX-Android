import QtQuick
import QtQuick.Controls
import QGroundControl
import QGroundControl.Controls

AbstractButton {
    id: root
    required property var status
    property real progress: NaN
    property bool animationsEnabled: true
    readonly property bool busy: status.initializing || (!status.connected && status.waitingForHeartbeat)
    readonly property real _pad: ScreenTools.defaultFontPixelWidth
    readonly property color _accent: status.accent
    implicitWidth: Math.min(ScreenTools.defaultFontPixelWidth * 34,
                           Math.max(ScreenTools.defaultFontPixelWidth * 20,
                                    Math.max(title.implicitWidth, subtitle.implicitWidth) + icon.width + _pad * 5))
    implicitHeight: ScreenTools.defaultFontPixelHeight * 3.3
    padding: 0
    focusPolicy: Qt.StrongFocus
    Accessible.name: status.label + " · " + subtitle.text
    ToolTip.visible: hovered
    ToolTip.text: Accessible.name
    background: Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: 12
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(root._accent.r, root._accent.g, root._accent.b, 0.90) }
            GradientStop { position: 1; color: Qt.rgba(root._accent.r, root._accent.g, root._accent.b, 0.28) }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: root.activeFocus ? 2 : 1
            radius: 11
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.darker(root._accent, 6.5) }
                GradientStop { position: 1; color: "#101d2d" }
            }
        }
        Rectangle {
            width: 3
            height: parent.height * 0.42
            anchors.left: parent.left
            anchors.leftMargin: 1
            anchors.verticalCenter: parent.verticalCenter
            radius: 1.5
            color: root._accent
        }
    }
    contentItem: Item {
        Item {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: root._pad * 1.3
            anchors.verticalCenter: parent.verticalCenter
            width: ScreenTools.defaultFontPixelHeight * 1.35
            height: width
            Rectangle {
                anchors.fill: parent
                radius: root.status.symbol === "alert" ? 5 : width / 2
                rotation: root.status.symbol === "alert" ? 45 : 0
                color: Qt.rgba(root._accent.r, root._accent.g, root._accent.b, 0.12)
                border.color: root._accent
                border.width: 1
            }
            Item {
                anchors.centerIn: parent
                width: parent.width * 0.6
                height: width
                visible: root.status.symbol === "check"
                Rectangle { x: parent.width * 0.06; y: parent.height * 0.51; width: parent.width * 0.39; height: 2; rotation: 45; color: root._accent }
                Rectangle { x: parent.width * 0.29; y: parent.height * 0.39; width: parent.width * 0.67; height: 2; rotation: -48; color: root._accent }
            }
            Item {
                anchors.centerIn: parent
                width: parent.width * 0.53
                height: width
                visible: root.status.symbol === "cross"
                Rectangle { anchors.centerIn: parent; width: parent.width; height: 2; rotation: 45; color: root._accent }
                Rectangle { anchors.centerIn: parent; width: parent.width; height: 2; rotation: -45; color: root._accent }
            }
            Item {
                anchors.centerIn: parent
                width: parent.width * 0.5
                height: parent.height * 0.6
                visible: root.status.symbol === "alert"
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 2; height: parent.height * 0.6; radius: 1; color: root._accent }
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; width: 3; height: 3; radius: 1.5; color: root._accent }
            }
            Row {
                anchors.centerIn: parent
                spacing: 2
                visible: root.status.symbol === "dots"
                Repeater {
                    model: 3
                    Rectangle { width: 3; height: 3; radius: 1.5; color: root._accent; opacity: 1 - index * 0.24 }
                }
            }
        }
        Column {
            anchors.left: icon.right
            anchors.leftMargin: root._pad
            anchors.right: parent.right
            anchors.rightMargin: root._pad * 1.2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            QGCLabel {
                id: title
                objectName: "hdzxStatusTitle"
                width: parent.width
                text: root.status.label
                color: "#f3f8ff"
                font.bold: true
                font.pointSize: ScreenTools.mediumFontPointSize
                elide: Text.ElideRight
            }
            QGCLabel {
                id: subtitle
                objectName: "hdzxStatusDetail"
                width: parent.width
                text: root.busy && isFinite(root.progress) && root.progress > 0 && root.progress <= 1
                    ? root.status.detail + " · " + Math.floor(root.progress * 100) + "%" : root.status.detail
                color: root._accent
                font.pointSize: ScreenTools.smallFontPointSize
                elide: Text.ElideRight
            }
        }
        HQConnectionProgress {
            objectName: "hdzxStatusProgress"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 7
            height: 3
            clip: true
            visible: root.busy
            connected: root.busy
            progress: root.progress
            indeterminate: !isFinite(progress) || progress <= 0
            accent: root._accent
            sourceToken: root.status.vehicle
            animationsEnabled: root.animationsEnabled
        }
    }
}
