pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import QGroundControl
import QGroundControl.Controls

// Read-only instruments delegate commands to the existing confirmation flow.
Item {
    id: root
    objectName: "hdzxMpHud"
    property var vehicle: QGroundControl.multiVehicleManager.activeVehicleAvailable
        ? QGroundControl.multiVehicleManager.activeVehicle : null
    property var guidedController: null
    property bool expanded: preferences.open
    property bool fullScreen: false
    property bool dragging: false
    property bool resizing: false
    property real savedX: 0
    property real savedY: 0
    property int dockSide: 0
    property real sizeFactor: 1
    readonly property string dockTitle: qsTr("飞行 HUD")
    readonly property real margin: ScreenTools.defaultFontPixelWidth * 0.75
    readonly property real scaleMin: 0.60
    readonly property real scaleMax: 1.60
    readonly property bool splitLayout: preferences.leftColumn
    readonly property bool connected: !!vehicle && !!vehicle.vehicleLinkManager && !vehicle.vehicleLinkManager.communicationLost
    readonly property var primaryBattery: vehicle && vehicle.batteries && vehicle.batteries.count > 0 ? vehicle.batteries.get(0) : null
    readonly property var warning: connected && vehicle.currentWarning !== undefined ? vehicle.currentWarning : ({})
    readonly property bool attitudeAvailable: available("roll") && available("pitch")
    readonly property real rollAngle: numberFor("roll")
    readonly property real pitchAngle: numberFor("pitch")
    readonly property real heading: numberFor("heading")
    readonly property real groundSpeed: numberFor("groundSpeed")
    readonly property real airSpeed: numberFor("airSpeed")
    readonly property int altitudeReference: preferences.altitudeReference
    readonly property string altitudeLabel: altitudeReference === 1 ? qsTr("海拔高度") : qsTr("相对高度")
    readonly property real altitude: numberFor(altitudeReference === 1 ? "altitudeAMSL" : "altitudeRelative")
    readonly property real climbRate: numberFor("climbRate")
    readonly property real batteryPercent: batteryValue("percentRemaining", "Remaining")
    readonly property real batteryVoltage: batteryValue("voltage", "Voltage")
    readonly property real batteryCurrent: batteryValue("current", "Current")
    readonly property int satellites: available("gps1Satellites") && vehicle.gps && isFinite(Number(vehicle.gps.count.rawValue)) && Number(vehicle.gps.count.rawValue) >= 0 && Number(vehicle.gps.count.rawValue) < 255 ? Number(vehicle.gps.count.rawValue) : -1
    readonly property real minimumWidth: parent ? Math.min(320 * ScreenTools.mobileUiScale, parent.width) : 320 * ScreenTools.mobileUiScale
    readonly property real minimumHeight: parent ? Math.min(330 * ScreenTools.mobileUiScale, parent.height) : 330 * ScreenTools.mobileUiScale
    readonly property real openWidth: parent ? Math.min(parent.width, Math.max(minimumWidth, parent.width * preferences.widthFraction)) : 480
    readonly property real openHeight: parent ? (splitLayout ? parent.height : Math.min(parent.height, Math.max(minimumHeight, parent.height * preferences.heightFraction))) : 420
    readonly property real headerHeight: Math.max(44 * ScreenTools.mobileUiScale, ScreenTools.minTouchPixels)
    readonly property real collapsedWidth: Math.min(220 * ScreenTools.mobileUiScale, parent ? parent.width : 220 * ScreenTools.mobileUiScale)
    readonly property real targetWidth: fullScreen && expanded && parent ? parent.width : expanded ? openWidth : collapsedWidth
    readonly property real targetHeight: fullScreen && expanded && parent ? parent.height : expanded ? openHeight : headerHeight
    // Match HQFullScreenControl's actual size and its two edge margins. Using
    // a multiple of header height can put the close button under fullscreen
    // when the operator increases the UI font size or display scaling.
    readonly property real fullScreenActionInset: Math.max(ScreenTools.minTouchPixels, ScreenTools.defaultFontPixelHeight * 2.4)
        + ScreenTools.defaultFontPixelWidth * 1.3
    readonly property string roundedFont: ScreenTools.hqUiFontFamily
    property bool initialized: false
    property bool changingGeometry: false
    signal closeRequested()
    signal preflightRequested()
    signal statusRequested()
    signal setupRequested(string kind)
    signal logsRequested()
    signal actionRequested(string action)
    signal flightModeRequested(string mode)

    width: fullScreen && expanded && parent ? parent.width : expanded ? openWidth : collapsedWidth
    height: fullScreen && expanded && parent ? parent.height : expanded ? openHeight : headerHeight
    z: QGroundControl.zOrderTopMost + (fullScreen ? 60 : 22)
    Behavior on width {
        enabled: root.initialized && panelMotion.animateGeometry
        NumberAnimation {
            duration: panelMotion.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: panelMotion.fluidCurve
        }
    }
    Behavior on height {
        enabled: root.initialized && panelMotion.animateGeometry
        NumberAnimation {
            duration: panelMotion.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: panelMotion.fluidCurve
        }
    }

    Settings {
        id: preferences
        objectName: "hudPreferences"
        category: "HQClassicFlightDeck"
        property real widthFraction: 0.34
        property real heightFraction: 0.54
        property real positionX: 1
        property real positionY: 1
        property bool leftColumn: false
        property bool open: true
        property int altitudeReference: 0
    }
    HQDashboardController { id: freshness; objectName: "hudFreshness"; vehicle: root.vehicle }
    HQPanelMotion { id: panelMotion; targetItem: root; animateFullScreen: true }
    Behavior on x {
        enabled: root.initialized && panelMotion.fullScreenTransition && !root.dragging && !root.resizing
        NumberAnimation { duration: panelMotion.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: panelMotion.fluidCurve }
    }
    Behavior on y {
        enabled: root.initialized && panelMotion.fullScreenTransition && !root.dragging && !root.resizing
        NumberAnimation { duration: panelMotion.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: panelMotion.fluidCurve }
    }

    function available(key) {
        const revision = freshness.revision
        return connected && freshness.available(key)
    }
    function numberFor(key) {
        if (!available(key) || !vehicle[key]) return NaN
        const value = Number(vehicle[key].rawValue)
        return isFinite(value) ? value : NaN
    }
    function batteryValue(key, suffix) {
        const revision = freshness.revision
        if (!connected || !primaryBattery) return NaN
        const id = Number(primaryBattery.id.rawValue)
        if (!freshness.available("battery" + id + suffix)) return NaN
        const value = Number(primaryBattery[key].rawValue)
        if (!isFinite(value) || (key === "percentRemaining" && (value < 0 || value > 100))) return NaN
        return value
    }
    function format(value, decimals) { return isFinite(value) ? Number(value).toFixed(decimals === undefined ? 1 : decimals) : "--" }
    function headingText(value) { return isFinite(value) ? String(Math.round((value % 360 + 360) % 360)).padStart(3, "0") : "---" }
    function setAltitudeReference(index) { if (index === 0 || index === 1) preferences.altitudeReference = index }
    function clampPosition() {
        if (!parent || fullScreen || resizing || dragging || dockSide !== 0) return
        if (splitLayout) { x = 0; y = 0; return }
        x = Math.max(0, Math.min(x, Math.max(0, parent.width - targetWidth)))
        y = Math.max(0, Math.min(y, Math.max(0, parent.height - targetHeight)))
    }
    function placeFromPreferences() {
        if (!parent || fullScreen || dragging || resizing || dockSide !== 0) return
        changingGeometry = true
        x = splitLayout ? 0 : Math.max(0, parent.width - targetWidth) * preferences.positionX
        y = splitLayout ? 0 : Math.max(0, parent.height - targetHeight) * preferences.positionY
        changingGeometry = false
    }
    function savePlacement() {
        if (!initialized || !parent || fullScreen || changingGeometry || dockSide !== 0) return
        if (!splitLayout) {
            preferences.positionX = Math.max(0, Math.min(1, x / Math.max(1, parent.width - targetWidth)))
            preferences.positionY = Math.max(0, Math.min(1, y / Math.max(1, parent.height - targetHeight)))
        }
    }
    function setLayout(leftColumn) {
        if (fullScreen) { prepareFullScreenTransition(); fullScreen = false; x = savedX; y = savedY }
        savePlacement()
        preferences.leftColumn = leftColumn
        dockSide = 0
        expanded = true
        Qt.callLater(placeFromPreferences)
    }
    function adjustSize(delta) {
        if (!parent || fullScreen) return
        preferences.widthFraction = Math.max(0.18, Math.min(0.95, preferences.widthFraction + delta * 0.3))
        preferences.heightFraction = Math.max(0.28, Math.min(1, preferences.heightFraction + delta * 0.4))
        clampPosition()
        savePlacement()
    }
    function finishDrag() { panelMotion.finishDockDrag(); clampPosition(); savePlacement() }
    function updateDockPosition() { panelMotion.updateDockPosition() }
    function restore() { dockSide = 0; expanded = true; Qt.callLater(placeFromPreferences) }
    function openDiagnostics(kind) { diagnostics.open(kind) }
    function prepareFullScreenTransition() { panelMotion.fullScreenTransition = true }

    Component.onCompleted: {
        placeFromPreferences()
        initialized = true
    }
    onExpandedChanged: if (initialized) {
        preferences.open = expanded
        if (!expanded && fullScreen) { prepareFullScreenTransition(); fullScreen = false; x = savedX; y = savedY }
        Qt.callLater(clampPosition)
    }
    onFullScreenChanged: if (!fullScreen) Qt.callLater(clampPosition)
    onVisibleChanged: if (initialized && visible) Qt.callLater(placeFromPreferences)
    onVehicleChanged: if (initialized) diagnostics.closeAll()
    Connections {
        target: root.parent
        function onWidthChanged() { Qt.callLater(root.placeFromPreferences) }
        function onHeightChanged() { Qt.callLater(root.placeFromPreferences) }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.dockSide === 0
        radius: root.splitLayout || root.fullScreen ? 0 : 8
        color: "#F5131B26"
        border.color: "#6B899B"
        border.width: 1
        clip: true
        Rectangle {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root.headerHeight
            color: "#152B3E"
            MouseArea {
                id: dragArea
                objectName: "toolPanelHeader"
                anchors.fill: parent
                anchors.leftMargin: root.expanded && !root.fullScreen && !root.splitLayout ? topLeftGrip.width : 0
                anchors.rightMargin: root.expanded ? root.fullScreenActionInset + root.headerHeight * 3.4 : root.headerHeight
                hoverEnabled: true
                preventStealing: true
                cursorShape: root.fullScreen ? Qt.ArrowCursor : pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property point pressPoint
                property point origin
                property bool moved: false
                onPressed: mouse => { moved = false; pressPoint = mapToItem(root.parent, mouse.x, mouse.y); origin = Qt.point(root.x, root.y) }
                onPositionChanged: mouse => {
                    if (!pressed || root.fullScreen || !root.parent) return
                    const p = mapToItem(root.parent, mouse.x, mouse.y)
                    if (!moved && Math.hypot(p.x - pressPoint.x, p.y - pressPoint.y) < Qt.styleHints.startDragDistance) return
                    root.dragging = true
                    if (!moved && root.splitLayout) preferences.leftColumn = false
                    moved = true
                    root.x = Math.max(0, Math.min(origin.x + p.x - pressPoint.x, root.parent.width - root.width))
                    root.y = Math.max(0, Math.min(origin.y + p.y - pressPoint.y, root.parent.height - root.height))
                }
                onReleased: { root.dragging = false; if (moved) root.finishDrag() }
                onCanceled: { root.dragging = false; root.clampPosition(); root.savePlacement() }
                onDoubleClicked: if (!moved) root.expanded = !root.expanded
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("拖动飞行 HUD，双击折叠或展开")
                HQButtonRipple { control: dragArea }
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.margin
                anchors.rightMargin: root.expanded ? root.fullScreenActionInset : 2
                spacing: 2
                QGCLabel { Layout.fillWidth: true; text: qsTr("飞行 HUD"); color: "#F0F5F8"; font.weight: Font.DemiBold; font.pixelSize: Math.max(13 * ScreenTools.mobileUiScale, ScreenTools.defaultFontPixelHeight * 0.85); elide: Text.ElideRight }
                QGCButton { objectName: "hudLayoutChoice"; visible: root.expanded; text: root.splitLayout ? qsTr("浮动") : qsTr("左栏"); Layout.preferredWidth: root.headerHeight * 1.2; Layout.preferredHeight: root.headerHeight - 4; onClicked: root.setLayout(!root.splitLayout); Accessible.name: root.splitLayout ? qsTr("改为浮动 HUD") : qsTr("改为左侧 HUD 分栏") }
                QGCButton { objectName: "hudCollapse"; text: root.expanded ? "−" : "+"; Layout.preferredWidth: root.headerHeight; Layout.preferredHeight: root.headerHeight - 4; onClicked: root.expanded = !root.expanded; Accessible.name: root.expanded ? qsTr("折叠 HUD") : qsTr("展开 HUD") }
                QGCButton { objectName: "hudHide"; visible: root.expanded; text: "×"; Layout.preferredWidth: root.headerHeight; Layout.preferredHeight: root.headerHeight - 4; onClicked: root.closeRequested(); Accessible.name: qsTr("关闭 HUD，可从全部工具重新开启") }
            }
        }
        HQClassicHud {
            id: flightInstrument
            objectName: "classicHudInstrument"
            hud: root
            // Keep the retained instruments at their final open size while
            // only the outer shell clips an interrupted expansion.
            visible: panelMotion.contentVisible
            enabled: root.expanded
            opacity: root.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            anchors.left: parent.left
            anchors.top: header.bottom
            anchors.margins: 2
            width: Math.max(0, panelMotion.contentWidth - 4)
            height: Math.max(0, panelMotion.contentHeight - root.headerHeight - 4)
            onEkfRequested: root.openDiagnostics("ekf")
            onVibrationRequested: root.openDiagnostics("vibration")
            onStatusRequested: root.statusRequested()
        }
    }
    Rectangle {
        id: cornerGrip
        objectName: "hudCornerResize"
        visible: root.expanded && !root.fullScreen && root.dockSide === 0
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: Math.max(34 * ScreenTools.mobileUiScale, ScreenTools.minTouchPixels)
        height: width
        color: cornerMouse.pressed ? "#C44594AE" : "#A5203C51"
        radius: 6
        z: 50
        QGCLabel { anchors.centerIn: parent; text: "◢"; color: "#C8E5ED"; font.pixelSize: 20 * ScreenTools.mobileUiScale }
        MouseArea {
            id: cornerMouse
            objectName: "hudCornerResizeMouse"
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: root.splitLayout ? Qt.SizeHorCursor : Qt.SizeFDiagCursor
            onPressed: root.resizing = true
            onPositionChanged: mouse => {
                if (!pressed || !root.parent) return
                const p = mapToItem(root.parent, mouse.x, mouse.y)
                const w = Math.max(root.minimumWidth, Math.min(root.parent.width - root.x, p.x - root.x))
                const h = Math.max(root.minimumHeight, Math.min(root.parent.height - root.y, p.y - root.y))
                preferences.widthFraction = w / root.parent.width
                if (!root.splitLayout) preferences.heightFraction = h / root.parent.height
            }
            onReleased: { root.resizing = false; root.savePlacement() }
            onCanceled: { root.resizing = false; root.savePlacement() }
            Accessible.role: Accessible.Slider
            Accessible.name: qsTr("调整 HUD 宽度和高度")
            activeFocusOnTab: true
            Keys.onLeftPressed: root.adjustSize(-0.05)
            Keys.onRightPressed: root.adjustSize(0.05)
            ToolTip.visible: containsMouse && !pressed
            ToolTip.text: qsTr("拖动边角改变大小")
        }
    }
    Rectangle {
        id: topLeftGrip
        objectName: "hudTopLeftResize"
        visible: root.expanded && !root.fullScreen && root.dockSide === 0 && !root.splitLayout
        anchors.left: parent.left
        anchors.top: parent.top
        width: ScreenTools.isMobile ? Math.max(28 * ScreenTools.mobileUiScale, ScreenTools.minTouchPixels * 0.75) : 16
        height: width
        color: topLeftMouse.pressed ? "#99B7D8E4" : "#34576B"
        radius: 3
        z: 70
        MouseArea {
            id: topLeftMouse
            objectName: "hudTopLeftResizeMouse"
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.SizeFDiagCursor
            property real fixedRight
            property real fixedBottom
            onPressed: { root.resizing = true; fixedRight = root.x + root.width; fixedBottom = root.y + root.height }
            onPositionChanged: mouse => {
                if (!pressed || !root.parent) return
                const point = mapToItem(root.parent, mouse.x, mouse.y)
                root.x = Math.max(0, Math.min(fixedRight - root.minimumWidth, point.x))
                root.y = Math.max(0, Math.min(fixedBottom - root.minimumHeight, point.y))
                preferences.widthFraction = (fixedRight - root.x) / root.parent.width
                preferences.heightFraction = (fixedBottom - root.y) / root.parent.height
            }
            onReleased: { root.resizing = false; root.savePlacement() }
            onCanceled: { root.resizing = false; root.savePlacement() }
            Accessible.name: qsTr("从左上角调整 HUD 大小")
        }
    }
    HQHudDiagnostics { id: diagnostics; hud: root }
}
