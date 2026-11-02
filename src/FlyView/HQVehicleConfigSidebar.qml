import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// Vehicle setup pages embedded over Fly View. The map, toolbar and live
// status stay visible while the operator configures the connected aircraft.
Item {
    id: root

    property bool opened: false
    property bool dockLeft: false
    property bool resizing: false
    property real panelWidth: parent ? Math.min(parent.width * (ScreenTools.isMobile ? 0.72 : 0.48), ScreenTools.defaultFontPixelWidth * 92) : 900
    property string pendingKind: "summary"
    property int pendingKnownComponent: -1

    readonly property real minWidth: parent ? parent.width * (ScreenTools.isMobile ? 0.42 : 0.34) : 420
    readonly property real maxWidth: parent ? parent.width * (ScreenTools.isMobile ? 0.98 : 0.94) : 1400
    readonly property real gripWidth: Math.max(ScreenTools.isMobile ? ScreenTools.minTouchPixels * 0.72 : 10,
                                               ScreenTools.defaultFontPixelWidth * 1.2)
    readonly property bool vehicleAvailable: QGroundControl.multiVehicleManager.activeVehicleAvailable
                                             && !!QGroundControl.multiVehicleManager.activeVehicle

    width: opened ? panelWidth : 0
    height: parent ? parent.height : 0
    x: !parent ? 0 : (dockLeft ? 0 : parent.width - width)
    y: 0
    visible: width > 1

    Behavior on width { enabled: !root.resizing; NumberAnimation { duration: 220; easing.type: Easing.OutQuart } }
    Behavior on x { enabled: !root.resizing; NumberAnimation { duration: 220; easing.type: Easing.OutQuart } }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged() {
            if (!QGroundControl.multiVehicleManager.activeVehicle) {
                root.opened = false
            }
        }
        function onActiveVehicleAvailableChanged() {
            // This signal is cleared in vehicle-removal phase 1, before the
            // delayed destruction of Vehicle and its setup/plugin objects.
            if (!QGroundControl.multiVehicleManager.activeVehicleAvailable) {
                root.opened = false
            }
        }
    }

    function openPage(kind, knownComponent) {
        if (!vehicleAvailable) {
            QGroundControl.showMessageDialog(root, qsTr("飞控未连接"), qsTr("请先连接飞控，再打开飞行页内配置。"), Dialog.Ok)
            return
        }
        pendingKind = kind || "summary"
        pendingKnownComponent = knownComponent === undefined ? -1 : knownComponent
        opened = true
        Qt.callLater(applyPendingPage)
    }

    function applyPendingPage() {
        if (configLoader.status !== Loader.Ready || !configLoader.item) return
        if (pendingKind === "summary") {
            configLoader.item.showSummaryPanel()
        } else if (pendingKind === "parameters") {
            configLoader.item.showParametersPanel()
        } else if (pendingKind === "extended") {
            configLoader.item.showPanel("hqExtendedTuning", "qrc:/qml/QGroundControl/VehicleSetup/HQExtendedTuningSetup.qml")
        } else if(pendingKind==="storage") {
            configLoader.item.showPanel("storageCard","qrc:/qml/QGroundControl/VehicleSetup/HQStorageCardSetup.qml")
        } else if (pendingKind === "ai") {
            configLoader.item.showPanel("aiTuning", "qrc:/qml/QGroundControl/VehicleSetup/HQAITuningSetup.qml")
        } else if (pendingKind === "aiLog") {
            configLoader.item.showPanel("aiLogAnalysis", "qrc:/qml/QGroundControl/VehicleSetup/HQAILogAnalysisSetup.qml")
        } else if (pendingKind === "known") {
            const vehicle = QGroundControl.multiVehicleManager.activeVehicle
            const component = vehicle && vehicle.autopilotPlugin
                ? vehicle.autopilotPlugin.findKnownVehicleComponent(pendingKnownComponent) : null
            if (component) configLoader.item.showVehicleComponentPanel(component)
            else QGroundControl.showMessageDialog(root, qsTr("当前飞控不支持"),
                qsTr("连接的飞控没有提供这个配置页面。"), Dialog.Ok)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#F5081827"
        border.width: 2
        border.color: "#43C9D8"

        Rectangle {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.max(ScreenTools.minTouchPixels, ScreenTools.defaultFontPixelHeight * 3.1)
            color: "#FA0A2A42"

            RowLayout {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth
                HQSetupIcon { kind: "tuning"; color: "#4FB3D1"; Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
                QGCLabel { Layout.fillWidth: true; text: qsTr("飞行页内配置"); color: "white"; font.weight: Font.Bold }
                QGCButton {
                    text: root.dockLeft ? qsTr("停靠右侧") : qsTr("停靠左侧")
                    onClicked: root.dockLeft = !root.dockLeft
                }
                QGCButton { text: "×"; onClicked: root.opened = false }
            }
        }

        Loader {
            id: configLoader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            anchors.margins: 2
            active: root.opened && root.vehicleAvailable
            source: "qrc:/qml/QGroundControl/VehicleSetup/VehicleConfigView.qml"
            onLoaded: {
                item.compactEmbedded = true
                root.applyPendingPage()
            }
        }

        // Separate grips avoid stale left/right anchor bindings stretching one
        // rectangle across the entire panel when its dock side changes.
        Rectangle {
            id: leftResizeGrip
            visible: !root.dockLeft
            width: root.gripWidth
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            color: leftResizeMouse.pressed ? "#70E7EF" : "#315D72"
            opacity: leftResizeMouse.containsMouse || leftResizeMouse.pressed ? 0.95 : 0.65

            MouseArea {
                id: leftResizeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                property real startWidth: 0
                property real startSceneX: 0
                onPressed: {
                    root.resizing = true
                    startWidth = root.panelWidth
                    startSceneX = mapToItem(root.parent, mouse.x, mouse.y).x
                }
                onPositionChanged: if (pressed) {
                    const sceneX = mapToItem(root.parent, mouse.x, mouse.y).x
                    // For a right-docked panel the dragged left edge must sit
                    // exactly beneath the finger, independent of scale/DPI.
                    const proposed = root.parent.width - sceneX
                    root.panelWidth = Math.max(root.minWidth, Math.min(root.maxWidth, proposed))
                }
                onReleased: root.resizing = false
                onCanceled: root.resizing = false
            }
        }

        Rectangle {
            id: rightResizeGrip
            visible: root.dockLeft
            width: root.gripWidth
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            color: rightResizeMouse.pressed ? "#70E7EF" : "#315D72"
            opacity: rightResizeMouse.containsMouse || rightResizeMouse.pressed ? 0.95 : 0.65

            MouseArea {
                id: rightResizeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                property real startWidth: 0
                property real startSceneX: 0
                onPressed: {
                    root.resizing = true
                    startWidth = root.panelWidth
                    startSceneX = mapToItem(root.parent, mouse.x, mouse.y).x
                }
                onPositionChanged: if (pressed) {
                    const sceneX = mapToItem(root.parent, mouse.x, mouse.y).x
                    // For a left-docked panel the right edge follows the
                    // finger's scene coordinate one-to-one.
                    const proposed = sceneX
                    root.panelWidth = Math.max(root.minWidth, Math.min(root.maxWidth, proposed))
                }
                onReleased: root.resizing = false
                onCanceled: root.resizing = false
            }
        }
    }
}
