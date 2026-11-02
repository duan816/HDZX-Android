import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// A compact ArduPilot-oriented tuning workspace. Only parameters reported by
// the connected flight controller are shown. Values are staged locally and
// written only after an explicit confirmation.
Item {
    id: root

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool expanded: false
    property bool dragging: false
    readonly property string dockTitle: qsTr("调参")
    property int dockSide: 0
    property bool fullScreen: false
    property bool resizing: false

    HQPanelMotion { id: panelMotion; targetItem: root }

    Connections {
        target: root
        function onExpandedChanged() {
            if (!root.expanded && root.fullScreen) {
                root.fullScreen = false
                root.x = root.savedX
                root.y = root.savedY
            }
        }
    }
    property real savedX: 0
    property real savedY: 0
    property real sizeFactor: mobile ? 0.75 : 1.0
    readonly property real fontScale: Math.max(0.86, Math.min(1.24, 0.62 + 0.38 * sizeFactor))
    readonly property bool isPX4: workspace.model.isPX4
    readonly property bool parametersReady: workspace.model.parametersReady

    readonly property bool mobile: ScreenTools.isMobile
    readonly property real margin: ScreenTools.defaultFontPixelWidth * 0.75
    readonly property real headerHeight: Math.max(ScreenTools.minTouchPixels, ScreenTools.defaultFontPixelHeight * 2.8)
    readonly property real scaleMin: 0.60
    readonly property real scaleMax: 1.40
    readonly property real scaleStep: 0.10
    readonly property real collapsedWidth: Math.min(ScreenTools.defaultFontPixelWidth * 16 * sizeFactor, parent ? parent.width * 0.46 : 240 * sizeFactor)
    readonly property real openWidth: Math.min(parent ? parent.width * (mobile ? 0.94 : 0.76) * sizeFactor : 1180 * sizeFactor,
                                               parent ? parent.width * 0.96 : ScreenTools.defaultFontPixelWidth * 118 * sizeFactor)
    readonly property real openHeight: Math.min(parent ? parent.height * (mobile ? 0.86 : 0.82) * sizeFactor : 760 * sizeFactor,
                                                parent ? parent.height * 0.94 : ScreenTools.defaultFontPixelHeight * 48 * sizeFactor)

    readonly property var sections: workspace.sections

    width: fullScreen && expanded && parent ? parent.width : (expanded ? openWidth : collapsedWidth)
    height: fullScreen && expanded && parent ? parent.height : (expanded ? openHeight : headerHeight)
    z: QGroundControl.zOrderTopMost + (fullScreen ? 60 : 21)
    scale: dragging ? 1.012 : 1
    transformOrigin: Item.Center

    Behavior on width { enabled: panelMotion.animateGeometry; NumberAnimation { duration: panelMotion.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: panelMotion.fluidCurve } }
    Behavior on height { enabled: panelMotion.animateGeometry; NumberAnimation { duration: panelMotion.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: panelMotion.fluidCurve } }
    Behavior on scale { NumberAnimation { duration: 100 } }
    Behavior on x { enabled: root.dockSide === 0 && !root.dragging && panelMotion.animateGeometry && !panelMotion.sizing; NumberAnimation { duration: 220; easing.type: Easing.OutQuart } }
    Behavior on y { enabled: root.dockSide === 0 && !root.dragging && panelMotion.animateGeometry && !panelMotion.sizing; NumberAnimation { duration: 220; easing.type: Easing.OutQuart } }

    function parameterFact(names) { return workspace.model.parameterFact(names) }
    function pendingCount() { return workspace.model.pendingCount }
    function requestWrite() { workspace.model.requestWrite(root) }
    function reloadEditors() { workspace.model.requestReload(root) }

    function clampPosition() {
        if (root.resizing || root.fullScreen || panelMotion.sizing || panelMotion.fullScreenTransition) return
        if (!parent || dockSide !== 0) return
        x = Math.max(margin, Math.min(x, parent.width - width - margin))
        y = Math.max(margin, Math.min(y, parent.height - height - margin))
    }

    function adjustSize(delta) {
        panelMotion.adjustSize(delta)
    }

    Rectangle {
        visible: root.dockSide === 0
        anchors.fill: parent
        radius: root.expanded ? 12 : Math.min(height / 2, ScreenTools.defaultFontPixelHeight * 1.4)
        Behavior on radius { enabled: panelMotion.animateGeometry; NumberAnimation { duration: panelMotion.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: panelMotion.fluidCurve } }
        Behavior on color { ColorAnimation { duration: 160 } }
        color: root.expanded ? "#F40A1C2C" : "#EC15324B"
        border.width: 2
        border.color: root.expanded ? "#70D67D" : "#A7E65A"
        clip: true

        Rectangle {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root.headerHeight
            color: root.expanded ? "#F20D2A3F" : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.margin
                anchors.rightMargin: root.expanded ? root.margin + ScreenTools.minTouchPixels * 1.25 : root.margin
                spacing: root.margin
                QGCLabel { text: "PID"; color: "#A7E65A"; font.weight: Font.DemiBold; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.75 * root.fontScale }
                QGCLabel { Layout.fillWidth: true; text: qsTr("扩展调参"); color: "white"; font.weight: Font.DemiBold; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.82 * root.fontScale; elide: Text.ElideRight }
                QGCLabel { visible: root.expanded; text: !root.vehicle ? qsTr("等待飞控连接") : (!root.parametersReady ? qsTr("正在读取飞控参数…") : qsTr("仅显示飞控支持的参数")); color: root.parametersReady ? "#70D67D" : "#FFB067"; font.pixelSize: ScreenTools.smallFontPointSize * root.fontScale }
                QGCLabel { text: root.expanded ? "—" : "▼"; color: "#A7E65A" }
            }

            MouseArea {
                objectName: "toolPanelHeader"
                id: toolHeaderMouse
                HQButtonRipple { objectName: "headerRipple"; control: toolHeaderMouse }
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                preventStealing: true
                property bool didDrag: false
                drag.target: root.fullScreen ? null : root
                drag.axis: Drag.XAndYAxis
                drag.minimumX: 0
                drag.maximumX: root.parent ? Math.max(0, root.parent.width - root.width) : 0
                drag.minimumY: 0
                drag.maximumY: root.parent ? Math.max(0, root.parent.height - root.height) : 0
                drag.threshold: root.mobile ? 6 : 4
                onPressed: didDrag = false
                onPositionChanged: if (drag.active) { didDrag = true; root.dragging = true }
                onReleased: { root.dragging = false; if (didDrag) panelMotion.finishDockDrag() }
                onCanceled: root.dragging = false
                onClicked: if (!didDrag) { root.expanded = !root.expanded; Qt.callLater(root.clampPosition) }
            }
        }

        HQExtendedTuningWorkspace {
            id: workspace
            visible: root.expanded
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.bottom: footer.top
            anchors.margins: root.margin
            vehicle: root.vehicle
            textScale: root.fontScale
            showHeading: false
        }

        Rectangle {
            id: footer
            visible: root.expanded
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.max(ScreenTools.minTouchPixels * 1.15, ScreenTools.defaultFontPixelHeight * 3.2)
            color: "#F20A1825"

            RowLayout {
                anchors.fill: parent
                anchors.margins: root.margin * 0.55
                spacing: root.margin
                QGCLabel { visible: !root.mobile; Layout.fillWidth: true; text: root.vehicle && root.vehicle.armed ? qsTr("飞控已解锁：写入前请确认飞行安全") : qsTr("修改先保留在本页，确认后统一写入"); color: root.vehicle && root.vehicle.armed ? "#FF8A72" : "#8FB1C5"; wrapMode: Text.WordWrap; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68 * root.fontScale }
                Item { visible: root.mobile; Layout.fillWidth: true }
                QGCButton { text: "－"; enabled: root.sizeFactor > root.scaleMin; onClicked: root.adjustSize(-root.scaleStep) }
                QGCLabel { text: Math.round(root.sizeFactor * 100) + "%"; color: "#9EDBFF"; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 5; horizontalAlignment: Text.AlignHCenter }
                QGCButton { text: "＋"; enabled: root.sizeFactor < root.scaleMax; onClicked: root.adjustSize(root.scaleStep) }
                QGCButton { text: qsTr("隐藏"); onClicked: root.expanded = false }
            }
        }
    }
    HQResizeHandle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        targetItem: root
        motionController: panelMotion
        visible: root.expanded && !root.fullScreen
    }
}
