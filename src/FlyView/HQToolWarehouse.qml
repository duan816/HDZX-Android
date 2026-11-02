pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    property bool tuningVisible: true
    property bool hudVisible: true
    property bool pidVisible: true
    property bool dashboardVisible: true
    property bool expanded: false
    property bool acceptingDrop: false
    property bool dragging: false
    property bool animationsEnabled: true
    property real revealProgress: 1

    signal toolVisibilityRequested(string key, bool visible)
    signal settingsRequested()

    readonly property real margin: ScreenTools.defaultFontPixelWidth * 0.75
    readonly property real buttonSize: Math.max(ScreenTools.minTouchPixels, ScreenTools.defaultFontPixelHeight * 2.7)
    readonly property real openWidth: Math.min(ScreenTools.defaultFontPixelWidth * 40, parent ? parent.width * (ScreenTools.isMobile ? 0.92 : 0.60) : 360)
    readonly property real openHeight: panelColumn.implicitHeight + margin * 2
    readonly property bool contentVisible: expanded || conceal.running

    width: expanded ? openWidth : buttonSize
    height: expanded ? openHeight : buttonSize
    z: QGroundControl.zOrderTopMost + 35

    Behavior on width { enabled: root.animationsEnabled; NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
    Behavior on height { enabled: root.animationsEnabled; NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
    Behavior on x { enabled: !root.dragging; NumberAnimation { duration: 180; easing.type: Easing.OutQuart } }
    Behavior on y { enabled: !root.dragging; NumberAnimation { duration: 180; easing.type: Easing.OutQuart } }

    function clampPosition() {
        if (!parent) return
        x = Math.max(root.margin, Math.min(x, parent.width - width - root.margin))
        y = Math.max(root.margin, Math.min(y, parent.height - height - root.margin))
    }

    onExpandedChanged: {
        if (expanded) {
            conceal.stop()
            revealProgress = animationsEnabled ? 0 : 1
            if (animationsEnabled) reveal.restart()
            if (parent) {
                x = Math.max(margin, Math.min(x, parent.width - openWidth - margin))
                y = Math.max(margin, Math.min(y, parent.height - openHeight - margin))
            }
        } else {
            reveal.stop()
            if (animationsEnabled) conceal.restart()
        }
    }
    onVisibleChanged: if (!visible) { reveal.stop(); conceal.stop(); revealProgress = 1 }
    onAnimationsEnabledChanged: if (!animationsEnabled) { reveal.stop(); conceal.stop(); revealProgress = 1 }
    Timer { id: conceal; interval: 370 }
    NumberAnimation { id: reveal; target: root; property: "revealProgress"; to: 1; duration: 320; easing.type: Easing.OutCubic }
    Connections {
        target: root.parent
        function onWidthChanged() { Qt.callLater(root.clampPosition) }
        function onHeightChanged() { Qt.callLater(root.clampPosition) }
    }

    function isDeployed(key) {
        switch (key) {
        case "tuning": return tuningVisible
        case "hud": return hudVisible
        case "pid": return pidVisible
        case "dashboard": return dashboardVisible
        }
        return false
    }

    Rectangle {
        anchors.fill: parent
        radius: root.expanded ? 13 : Math.min(height / 2, root.buttonSize / 2)
        Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 160 } }
        color: root.acceptingDrop ? "#F2379E72" : (root.expanded ? "#F20A243A" : "#F20D3554")
        border.width: root.acceptingDrop ? 3 : 2
        border.color: root.acceptingDrop ? "#7DE15D" : "#38C9D6"
        clip: true

        ColumnLayout {
            id: panelColumn
            objectName: "warehouseStableContent"
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: root.contentVisible ? root.margin : 0
            width: root.contentVisible ? root.openWidth - root.margin * 2 : root.buttonSize
            spacing: root.margin * 0.55

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.contentVisible ? root.buttonSize * 0.8 : root.buttonSize
                RowLayout {
                    anchors.fill: parent
                    spacing: root.margin

                    Item {
                        Layout.preferredWidth: root.contentVisible ? root.buttonSize * 0.72 : root.buttonSize
                        Layout.fillHeight: true
                        HQToolIcon {
                            objectName: "warehouseToolboxIcon"
                            anchors.centerIn: parent
                            width: root.buttonSize * 0.58
                            height: width
                            kind: "toolbox"
                            color: root.acceptingDrop ? "#D7FFCA" : "#61E1E8"
                        }
                    }
                    QGCLabel {
                        Layout.fillWidth: true
                        visible: root.contentVisible
                        text: qsTr("飞行工具箱")
                        color: "white"
                        font.family: ScreenTools.hqUiFontFamily
                        font.weight: Font.Bold
                    }
                    QGCLabel {
                        visible: root.contentVisible
                        text: "×"
                        color: "#9FC7D9"
                        font.pixelSize: ScreenTools.defaultFontPixelHeight
                    }
                }

                MouseArea {
                    objectName: "warehouseHeader"
                    anchors.fill: parent
                    preventStealing: true
                    drag.target: root
                    drag.axis: Drag.XAndYAxis
                    drag.minimumX: root.margin
                    drag.maximumX: root.parent ? Math.max(root.margin, root.parent.width - root.width - root.margin) : root.margin
                    drag.minimumY: root.margin
                    drag.maximumY: root.parent ? Math.max(root.margin, root.parent.height - root.height - root.margin) : root.margin
                    property bool didDrag: false
                    onPressed: didDrag = false
                    onPositionChanged: if (drag.active) { didDrag = true; root.dragging = true }
                    onReleased: {
                        root.dragging = false
                        root.clampPosition()
                        if (!didDrag) root.expanded = !root.expanded
                    }
                    onCanceled: root.dragging = false
                }
            }

            QGCLabel {
                Layout.fillWidth: true
                visible: root.contentVisible
                opacity: root.expanded ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                text: root.acceptingDrop ? qsTr("松开即可收纳") : qsTr("选择要放到主界面的工具；也可把窗口拖回这里。")
                color: root.acceptingDrop ? "#BFFFAD" : "#93B7C9"
                wrapMode: Text.WordWrap
                font.pointSize: ScreenTools.smallFontPointSize
                font.weight: Font.DemiBold
            }

            GridLayout {
                Layout.fillWidth: true
                visible: root.contentVisible
                enabled: root.expanded
                opacity: root.expanded ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                columns: 2
                rowSpacing: root.margin * 0.5
                columnSpacing: root.margin * 0.5

                Repeater {
                    model: [
                        { key: "tuning", text: qsTr("扩展调参"), icon: "PID" },
                        { key: "hud", text: qsTr("经典飞行 HUD"), icon: "◇" },
                        { key: "pid", text: qsTr("PID 响应"), icon: "⌁" },
                        { key: "dashboard", text: qsTr("飞行仪表盘"), icon: "◉" }
                    ]

                    Button {
                        id: toolChoice
                        required property var modelData
                        required property int index
                        objectName: "warehouseChoice-" + modelData.key
                        readonly property real entrance: root.animationsEnabled
                            ? Math.max(0, Math.min(1, (root.revealProgress - index * 0.025) / 0.75)) : 1
                        opacity: entrance
                        transform: Translate { y: (1 - toolChoice.entrance) * 8 }
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(ScreenTools.minTouchPixels, ScreenTools.defaultFontPixelHeight * 2.5)
                        checkable: true
                        checked: root.isDeployed(modelData.key)
                        enabled: true
                        text: modelData.text

                        background: Rectangle {
                            scale: toolChoice.down ? 0.96 : 1
                            Behavior on scale { NumberAnimation { duration: toolChoice.down ? 120 : 320; easing.type: toolChoice.down ? Easing.OutCubic : Easing.OutBack; easing.overshoot: 0.35 } }
                            radius: 8
                            color: parent.checked ? "#283B9B82" : "#18204158"
                            Behavior on color { ColorAnimation { duration: 160 } }
                            border.width: 1
                            border.color: parent.checked ? "#62E0B0" : "#3A6075"
                            HQButtonRipple { control: toolChoice; animationsEnabled: root.animationsEnabled }
                        }
                        contentItem: QGCLabel {
                            text: parent.text
                            color: parent.enabled ? (parent.checked ? "#DFFFF1" : "#B8CAD4") : "#627887"
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: root.margin + 30
                            elide: Text.ElideRight
                            font.weight: Font.DemiBold
                            HQToolIcon { kind: toolChoice.modelData.key; width: 24; height: 24; x: root.margin; anchors.verticalCenter: parent.verticalCenter; color: "#80CADF" }
                        }
                        onClicked: root.toolVisibilityRequested(modelData.key, checked)
                    }
                }
            }

            QGCButton {
                Layout.fillWidth: true
                visible: root.contentVisible
                enabled: root.expanded
                text: qsTr("设置与 Remote ID 配置")
                font.weight: Font.DemiBold
                onClicked: root.settingsRequested()
            }
        }
    }
}
