import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool expanded: false
    property bool dragging: false
    readonly property string dockTitle: qsTr("PID")
    property int loopMode: 0 // rate, attitude, local position, local velocity
    readonly property var rateSetting: QGroundControl.settingsManager.appSettings.pidMonitorRateHz
    property int refreshRateHz: Math.max(5, Math.min(50, Math.round(Number(rateSetting.rawValue) / 5) * 5))
    readonly property bool attitudeMode: loopMode === 1
    property int selectedAxis: -1
    property bool showResponse: true
    property bool showP: false
    property bool showI: false
    property bool showD: false
    property var termHistory: [[], [], []]
    property var _requestedVehicle: null
    readonly property bool termsSelected: showP || showI || showD
    readonly property bool linkLost: !!vehicle && !!vehicle.vehicleLinkManager && vehicle.vehicleLinkManager.communicationLost
    readonly property var axisLabels: loopMode < 2
        ? [qsTr("横滚（Roll）"), qsTr("俯仰（Pitch）"), qsTr("偏航（Yaw）")]
        : [qsTr("北向（N / X）"), qsTr("东向（E / Y）"), qsTr("向下（D / Z）")]
    readonly property string responseUnits: loopMode === 0 ? "°/s" : loopMode === 1 ? "°" : loopMode === 2 ? "m" : "m/s"
    objectName: "hdzxPidMonitor"
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
    property int dockSide: 0 // -1 left, 0 floating, 1 right
    // Mobile windows start 25% smaller; larger tablets can enlarge them manually.
    property real sizeFactor: ScreenTools.isMobile ? 0.75 : 1.0
    readonly property real fontScale: Math.max(0.82, Math.min(1.28, 0.55 + 0.45 * sizeFactor))
    property var rollTarget: []
    property var rollActual: []
    property var pitchTarget: []
    property var pitchActual: []
    property var yawTarget: []
    property var yawActual: []
    property var targetSnapshot: [NaN, NaN, NaN]
    property var actualSnapshot: [NaN, NaN, NaN]
    property real lastSampleTime: 0

    readonly property string roundedFont: ScreenTools.hqUiFontFamily
    readonly property real margin: ScreenTools.defaultFontPixelWidth * (compactMobile ? 0.62 : 0.75)
    readonly property bool compactMobile: ScreenTools.isMobile
    readonly property bool mobilePortrait: compactMobile && parent && parent.height >= parent.width
    readonly property real scaleMin: 0.60
    readonly property real scaleMax: 1.60
    readonly property real scaleStep: 0.10
    readonly property int maxSamples: compactMobile ? 110 : 170
    readonly property real preferredOpenWidth: compactMobile
                                           ? Math.min(parent ? parent.width * (mobilePortrait ? 0.90 : 0.42) * sizeFactor : 720,
                                                      parent ? parent.width * 0.94 : ScreenTools.defaultFontPixelWidth * 80)
                                           : Math.min(parent ? parent.width * 0.46 * sizeFactor : 720 * sizeFactor, ScreenTools.defaultFontPixelWidth * 76 * sizeFactor)
    readonly property real preferredOpenHeight: compactMobile
                                            ? Math.min(parent ? parent.height * (mobilePortrait ? 0.58 : 0.50) * sizeFactor : 600,
                                                       parent ? parent.height * 0.78 : ScreenTools.defaultFontPixelHeight * 31)
                                            : Math.min(parent ? parent.height * 0.72 * sizeFactor : 600 * sizeFactor, ScreenTools.defaultFontPixelHeight * 38 * sizeFactor)
    readonly property real openWidth: Math.min(parent ? parent.width * 0.94 : 720, Math.max(600, preferredOpenWidth))
    readonly property real openHeight: Math.min(parent ? parent.height * 0.94 : 600, Math.max(500, preferredOpenHeight))
    readonly property real collapsedScale: compactMobile ? 0.75 : 1.0
    readonly property real collapsedWidth: Math.min(ScreenTools.defaultFontPixelWidth * 15 * collapsedScale,
                                                     parent ? parent.width * (compactMobile ? 0.315 : 0.55) : ScreenTools.defaultFontPixelWidth * 15 * collapsedScale)
    readonly property real collapsedHeight: Math.max(ScreenTools.minTouchPixels * collapsedScale,
                                                      ScreenTools.defaultFontPixelHeight * 2.8 * collapsedScale)

    width: fullScreen && expanded && parent ? parent.width : (expanded ? openWidth : collapsedWidth)
    height: fullScreen && expanded && parent ? parent.height : (expanded ? openHeight : collapsedHeight)
    z: QGroundControl.zOrderTopMost + (expanded ? 80 : 18)

    scale: dragging ? 1.018 : 1.0
    transformOrigin: Item.Center

    Behavior on width { enabled: panelMotion.animateGeometry; NumberAnimation { duration: panelMotion.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: panelMotion.fluidCurve } }
    Behavior on height { enabled: panelMotion.animateGeometry; NumberAnimation { duration: panelMotion.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: panelMotion.fluidCurve } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on x {
        enabled: root.dockSide === 0 && !root.dragging && panelMotion.animateGeometry && !panelMotion.sizing
        NumberAnimation { duration: 260; easing.type: Easing.OutQuart }
    }
    Behavior on y {
        enabled: root.dockSide === 0 && !root.dragging && panelMotion.animateGeometry && !panelMotion.sizing
        NumberAnimation { duration: 260; easing.type: Easing.OutQuart }
    }

    function factNumber(fact) {
        const value = fact ? Number(fact.rawValue) : NaN
        return isFinite(value) ? value : NaN
    }

    function valueText(value) {
        return isFinite(value) ? value.toFixed(1) : "--"
    }

    function responseText(value) {
        return isFinite(value) ? value.toFixed(2) : qsTr("未上报")
    }

    function targetFact(axis) {
        if (!vehicle || linkLost) return null
        if (loopMode >= 2) {
            const group = vehicle.localPositionSetpoint
            if (!group || !group.fresh()) return null
            return loopMode === 2 ? (axis === 0 ? group.x : axis === 1 ? group.y : group.z)
                                  : (axis === 0 ? group.vx : axis === 1 ? group.vy : group.vz)
        }
        if (!vehicle.setpoint || !vehicle.setpoint.fresh()) return null
        if (attitudeMode) return axis === 0 ? vehicle.setpoint.roll : axis === 1 ? vehicle.setpoint.pitch : vehicle.setpoint.yaw
        return axis === 0 ? vehicle.setpoint.rollRate : axis === 1 ? vehicle.setpoint.pitchRate : vehicle.setpoint.yawRate
    }

    function actualFact(axis) {
        if (!vehicle || linkLost) return null
        if (loopMode >= 2) {
            const group = vehicle.localPosition
            if (!group) return null
            const fresh = loopMode === 3 && typeof group.velocityFresh === "function" ? group.velocityFresh() : group.fresh()
            if (!fresh) return null
            return loopMode === 2 ? (axis === 0 ? group.x : axis === 1 ? group.y : group.z)
                                  : (axis === 0 ? group.vx : axis === 1 ? group.vy : group.vz)
        }
        if (attitudeMode) return axis === 0 ? vehicle.roll : axis === 1 ? vehicle.pitch : vehicle.heading
        return axis === 0 ? vehicle.rollRate : axis === 1 ? vehicle.pitchRate : vehicle.yawRate
    }

    function appendSample(array, value) {
        const result = array.slice(0)
        result.push(value)
        if (result.length > maxSamples) result.shift()
        return result
    }

    function termValue(axis, term) {
        if (!vehicle || linkLost || loopMode !== 0 || !vehicle.setpoint
            || !vehicle.setpoint.pidTermsFresh(axis)) return NaN
        return factNumber(vehicle.setpoint.pidTerm(axis, term))
    }

    function selectCurves(preset) {
        showResponse = preset === 0
        showP = preset === 1 || preset === 4
        showI = preset === 2
        showD = preset === 3 || preset === 4
        clearHistory()
    }

    function sample() {
        if (!expanded || !vehicle) return
        const now = Date.now()
        if (lastSampleTime && now - lastSampleTime > 2000)
            console.warn("HDZX PID display sample delayed", now - lastSampleTime, "ms")
        lastSampleTime = now
        targetSnapshot = [factNumber(targetFact(0)), factNumber(targetFact(1)), factNumber(targetFact(2))]
        actualSnapshot = [factNumber(actualFact(0)), factNumber(actualFact(1)), factNumber(actualFact(2))]
        rollTarget = appendSample(rollTarget, targetSnapshot[0])
        rollActual = appendSample(rollActual, actualSnapshot[0])
        pitchTarget = appendSample(pitchTarget, targetSnapshot[1])
        pitchActual = appendSample(pitchActual, actualSnapshot[1])
        let yaw = actualSnapshot[2]
        let targetYaw = targetSnapshot[2]
        if (attitudeMode) {
            const previous = yawActual.length ? yawActual[yawActual.length - 1] : yaw
            if (isFinite(yaw) && isFinite(previous)) yaw += 360 * Math.round((previous - yaw) / 360)
            if (isFinite(targetYaw) && isFinite(yaw)) targetYaw += 360 * Math.round((yaw - targetYaw) / 360)
        }
        yawTarget = appendSample(yawTarget, targetYaw)
        yawActual = appendSample(yawActual, yaw)
        const updated = []
        for (let axis = 0; axis < 3; axis++) {
            const histories = []
            for (let term = 0; term < 3; term++) {
                const old = termHistory[axis] && termHistory[axis][term] ? termHistory[axis][term] : []
                histories.push(appendSample(old, termValue(axis, term)))
            }
            updated.push(histories)
        }
        termHistory = updated
        plot.requestPaint()
    }

    function clearHistory() {
        rollTarget = []; rollActual = []
        pitchTarget = []; pitchActual = []
        yawTarget = []; yawActual = []
        termHistory = [[], [], []]
        targetSnapshot = [NaN, NaN, NaN]
        actualSnapshot = [NaN, NaN, NaN]
        lastSampleTime = 0
        plot.requestPaint()
    }

    // QGC's built-in PID tuning page explicitly asks the autopilot for a high
    // rate ATTITUDE/ATTITUDE_TARGET stream. The Fly View monitor must do the
    // same, otherwise ArduPilot commonly leaves ATTITUDE_TARGET at its default
    // (often zero) stream rate and the setpoint traces remain empty.
    function updateTelemetryMode() {
        const ready = vehicle && !linkLost && (vehicle.initialConnectComplete === undefined || vehicle.initialConnectComplete)
        const target = visible && expanded && ready ? vehicle : null
        if (_requestedVehicle && _requestedVehicle !== target)
            _requestedVehicle.setPIDMonitorTelemetryMode(Vehicle.ModeDisabled)
        _requestedVehicle = target
        if (target) target.setPIDMonitorTelemetryMode(loopMode >= 2 ? Vehicle.ModeVelocityAndPosition
            : termsSelected ? Vehicle.ModeRateAndAttitudeAndPid : Vehicle.ModeRateAndAttitude, refreshRateHz)
    }

    function clampPosition() {
        if (root.resizing || root.fullScreen || panelMotion.sizing || panelMotion.fullScreenTransition) return
        if (!parent || dockSide !== 0) return
        x = Math.max(margin, Math.min(x, parent.width - width - margin))
        y = Math.max(margin, Math.min(y, parent.height - height - margin))
    }

    function adjustSize(delta) {
        panelMotion.adjustSize(delta)
    }

    function finishDrag() { panelMotion.finishDockDrag() }

    function updateDockPosition() { panelMotion.updateDockPosition() }

    function restore() {
        const side = dockSide
        dockSide = 0
        expanded = true
        Qt.callLater(function() {
            x = side < 0 ? margin : parent.width - width - margin
            clampPosition()
        })
    }

    function requestFullScreen() {
        QGroundControl.showMessageDialog(
            root,
            qsTr("全屏显示 PID 响应"),
            qsTr("是否进入全屏 PID 响应监视？进入后可点击“退出全屏”返回。"),
            Dialog.Yes | Dialog.No,
            function() { root.enterFullScreen() }
        )
    }

    function enterFullScreen() {
        if (fullScreen || !parent) return
        savedX = x
        savedY = y
        dockSide = 0
        expanded = true
        fullScreen = true
        x = 0
        y = 0
        Qt.callLater(plot.requestPaint)
    }

    function exitFullScreen() {
        if (!fullScreen) return
        fullScreen = false
        x = savedX
        y = savedY
        Qt.callLater(function() { root.clampPosition(); plot.requestPaint() })
    }

    onLoopModeChanged: {
        clearHistory()
        showResponse = true
        showP = false; showI = false; showD = false
        updateTelemetryMode()
    }
    onSelectedAxisChanged: plot.requestPaint()
    onShowResponseChanged: plot.requestPaint()
    onShowPChanged: { plot.requestPaint(); updateTelemetryMode() }
    onShowIChanged: { plot.requestPaint(); updateTelemetryMode() }
    onShowDChanged: { plot.requestPaint(); updateTelemetryMode() }
    onVisibleChanged: updateTelemetryMode()
    onLinkLostChanged: updateTelemetryMode()
    Connections {
        target: root.vehicle
        ignoreUnknownSignals: true
        function onInitialConnectComplete() { root.updateTelemetryMode() }
        function onInitialConnectCompleteChanged() { root.updateTelemetryMode() }
    }
    onExpandedChanged: updateTelemetryMode()
    onRefreshRateHzChanged: {
        clearHistory()
        updateTelemetryMode()
    }
    onVehicleChanged: {
        clearHistory()
        updateTelemetryMode()
    }

    Component.onDestruction: {
        if (_requestedVehicle)
            _requestedVehicle.setPIDMonitorTelemetryMode(Vehicle.ModeDisabled)
    }

    Timer {
        objectName: "hdzxPidSampleTimer"
        interval: Math.round(1000 / root.refreshRateHz)
        repeat: true
        running: root.visible && root.expanded && !!root.vehicle
        onRunningChanged: root.lastSampleTime = 0
        onTriggered: root.sample()
    }

    Rectangle {
        visible: root.dockSide === 0
        anchors.fill: parent
        radius: root.expanded ? 12 : Math.min(height / 2, ScreenTools.defaultFontPixelHeight * 1.4)
        Behavior on radius { enabled: panelMotion.animateGeometry; NumberAnimation { duration: panelMotion.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: panelMotion.fluidCurve } }
        Behavior on color { ColorAnimation { duration: 160 } }
        color: root.expanded ? "#FC0A1D2F" : (root.dockSide === 0 ? "#E90A3152" : "#F2FF7A18")
        border.width: 2
        border.color: root.expanded ? "#278ED5" : "#FF8A24"
        clip: true

        Rectangle {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root.expanded ? Math.max(ScreenTools.minTouchPixels, ScreenTools.defaultFontPixelHeight * 2.8) : root.collapsedHeight
            color: root.expanded ? "#F20A243A" : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.margin
                anchors.rightMargin: root.margin
                spacing: root.margin
                HQToolIcon { kind: "pid"; Layout.preferredWidth: 24; Layout.preferredHeight: 24; color: "#80CADF" }
                QGCLabel { Layout.fillWidth: true; text: qsTr("PID 响应"); color: "white"; font.family: root.roundedFont; font.weight: Font.DemiBold; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.82 * root.fontScale }
                QGCLabel { visible: root.expanded; text: root.vehicle ? qsTr("只读监视（Read-only）") : qsTr("等待飞控连接"); color: root.vehicle ? "#57E39D" : "#8EA8BC"; font.family: root.roundedFont; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68 * root.fontScale }
                QGCLabel { text: root.expanded ? "—" : (root.dockSide < 0 ? "▶" : root.dockSide > 0 ? "◀" : "▼"); color: "#FF9A3D"; font.family: root.roundedFont; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.82 * root.fontScale }
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
                drag.threshold: root.compactMobile ? 6 : 4
                onPressed: {
                    didDrag = false
                    if (root.fullScreen) return
                    if (root.dockSide !== 0) {
                        const side = root.dockSide
                        root.dockSide = 0
                        root.x = side < 0 ? root.margin : root.parent.width - root.width - root.margin
                    }
                }
                onPositionChanged: if (!root.fullScreen && drag.active) { didDrag = true; root.dragging = true }
                onReleased: {
                    root.dragging = false
                    if (didDrag) {
                        root.finishDrag()
                    }
                }
                onCanceled: root.dragging = false
                onClicked: {
                    if (!didDrag)
                        root.expanded = !root.expanded
                }
            }
        }

        Column {
            id: loopControls
            visible: root.expanded
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: root.margin
            spacing: 4
            Flow {
                width: parent.width
                spacing: 5
                QGCComboBox {
                    objectName: "hdzxPidLoopSelector"
                    model: [qsTr("速率环"), qsTr("姿态环"), qsTr("位置环"), qsTr("速度环")]
                    currentIndex: root.loopMode
                    onActivated: (index) => root.loopMode = index
                }
                QGCComboBox {
                    objectName: "hdzxPidAxisSelector"
                    model: [qsTr("全部方向")].concat(root.axisLabels)
                    currentIndex: root.selectedAxis + 1
                    onActivated: (index) => root.selectedAxis = index - 1
                }
                QGCComboBox {
                    objectName: "hdzxPidRateSelector"
                    model: ["5 Hz", "10 Hz", "15 Hz", "20 Hz", "25 Hz", "30 Hz", "35 Hz", "40 Hz", "45 Hz", "50 Hz"]
                    currentIndex: root.refreshRateHz / 5 - 1
                    displayText: qsTr("刷新 %1 Hz").arg(root.refreshRateHz)
                    onActivated: (index) => root.rateSetting.rawValue = (index + 1) * 5
                }
                QGCComboBox {
                    objectName: "hdzxPidCurvePreset"
                    enabled: root.loopMode === 0
                    model: [qsTr("目标 / 实际"), "P", "I", "D", "P + D"]
                    currentIndex: root.showResponse && !root.termsSelected ? 0
                        : !root.showResponse && !root.showI && root.showP && root.showD ? 4
                        : !root.showResponse && root.showP && !root.showI && !root.showD ? 1
                        : !root.showResponse && !root.showP && root.showI && !root.showD ? 2
                        : !root.showResponse && !root.showP && !root.showI && root.showD ? 3 : -1
                    displayText: currentIndex < 0 ? qsTr("自定义组合") : textAt(currentIndex)
                    onActivated: (index) => root.selectCurves(index)
                }
                QGCCheckBox { objectName: "hdzxPidResponse"; text: qsTr("响应"); checked: root.showResponse; onClicked: root.showResponse = checked }
                QGCCheckBox { objectName: "hdzxPidP"; text: "P"; enabled: root.loopMode === 0; checked: root.showP; onClicked: root.showP = checked }
                QGCCheckBox { objectName: "hdzxPidI"; text: "I"; enabled: root.loopMode === 0; checked: root.showI; onClicked: root.showI = checked }
                QGCCheckBox { objectName: "hdzxPidD"; text: "D"; enabled: root.loopMode === 0; checked: root.showD; onClicked: root.showD = checked }
            }
            QGCLabel {
                width: parent.width
                font.pointSize: ScreenTools.smallFontPointSize
                color: "#B6CDD9"
                wrapMode: Text.Wrap
                text: root.termsSelected
                    ? qsTr("P 绿 / I 紫 / D 金：飞控内部输出，独立量程；未上报或超过 1.5 秒无更新显示为空。AP 需上报 PID_TUNING；PX4 标准遥测通常不含分量。")
                    : root.loopMode >= 2 ? qsTr("本地 NED：北、东、向下，单位 %1。期望 %2/3 轴、实际 %3/3 轴有效。缺失表示飞控未回传、已过期或该轴被忽略；AP 自稳等模式可能不提供本地目标，不能用零代替。")
                        .arg(root.responseUnits).arg(root.targetSnapshot.filter(v => isFinite(v)).length).arg(root.actualSnapshot.filter(v => isFinite(v)).length)
                    : qsTr("橙色：目标　蓝色：实际　单位：%1；可选择单个方向放大观察。").arg(root.responseUnits)
            }
        }

        Flickable {
            id: chartArea
            objectName: "hdzxPidChartArea"
            visible: root.expanded
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: loopControls.bottom
            anchors.bottom: footer.top
            anchors.margins: root.margin
            clip: true
            contentWidth: width
            contentHeight: Math.max(height, (root.selectedAxis < 0 ? 3 : 1) * ScreenTools.defaultFontPixelHeight * 4)
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            Canvas {
                id: plot
                width: chartArea.width
                height: chartArea.contentHeight
                antialiasing: true
                renderStrategy: Canvas.Immediate
                renderTarget: Canvas.Image

                function drawSeries(ctx, values, x0, y0, w, h, scale, color, width, center = 0) {
                    if (!values || values.length < 2) return
                    ctx.strokeStyle = color
                    ctx.lineWidth = width
                    ctx.beginPath()
                    let started = false
                    for (let i = 0; i < values.length; i++) {
                        const value = Number(values[i])
                        if (!isFinite(value)) { started = false; continue }
                        const px = x0 + ((root.maxSamples - values.length + i) / Math.max(1, root.maxSamples - 1)) * w
                        const py = y0 + h * 0.5 - Math.max(-scale, Math.min(scale, value - center)) / scale * h * 0.43
                        if (!started) { ctx.moveTo(px, py); started = true } else ctx.lineTo(px, py)
                    }
                    ctx.stroke()
                }

                function rowScale(a, b, minimum, center = 0) {
                    let maximum = minimum
                    for (let i = 0; i < a.length; i++) if (isFinite(a[i])) maximum = Math.max(maximum, Math.abs(a[i] - center))
                    for (let j = 0; j < b.length; j++) if (isFinite(b[j])) maximum = Math.max(maximum, Math.abs(b[j] - center))
                    return maximum * 1.1
                }

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.fillStyle = "#B3082133"
                    ctx.fillRect(0, 0, width, height)
                    const labels = root.axisLabels
                    const targets = [root.rollTarget, root.pitchTarget, root.yawTarget]
                    const actuals = [root.rollActual, root.pitchActual, root.yawActual]
                    // Painting consumes immutable numeric snapshots, never vehicle QObject getters.
                    const targetNow = root.targetSnapshot
                    const actualNow = root.actualSnapshot
                    const rows = root.selectedAxis < 0 ? [0, 1, 2] : [root.selectedAxis]
                    const rowH = height / rows.length
                    const labelW = Math.min(width * 0.38, ScreenTools.defaultFontPixelWidth * 25)
                    for (let rowIndex = 0; rowIndex < rows.length; rowIndex++) {
                        const row = rows[rowIndex]
                        const top = rowIndex * rowH
                        ctx.fillStyle = row % 2 ? "#16000000" : "#08000000"
                        ctx.fillRect(0, top, width, rowH)
                        ctx.strokeStyle = "#34566D"; ctx.lineWidth = 1
                        ctx.beginPath(); ctx.moveTo(labelW, top + rowH * 0.5); ctx.lineTo(width, top + rowH * 0.5); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(0, top + rowH); ctx.lineTo(width, top + rowH); ctx.stroke()
                        ctx.font = "600 " + (Math.max(11, Math.min(16, rowH * 0.16)) * root.fontScale) + "px '" + root.roundedFont + "'"
                        ctx.fillStyle = "#D6E4EE"; ctx.textAlign = "left"; ctx.textBaseline = "top"
                        ctx.fillText(labels[row] + "  " + (root.showResponse ? root.responseUnits : qsTr("内部分量")), 8, top + 7)
                        ctx.font = "500 " + (Math.max(10, Math.min(14, rowH * 0.14)) * root.fontScale) + "px '" + root.roundedFont + "'"
                        if (root.showResponse) {
                            ctx.fillStyle = "#FF9A3D"; ctx.fillText(qsTr("期望") + "  " + root.responseText(targetNow[row]), 8, top + rowH * 0.42)
                            ctx.fillStyle = "#55C5FF"; ctx.fillText(qsTr("实际") + "  " + root.responseText(actualNow[row]), 8, top + rowH * 0.66)
                            const minimum = root.loopMode >= 2 ? 1 : root.attitudeMode ? 30 : 90
                            const history = actuals[row]
                            const latest = history.length ? history[history.length - 1] : NaN
                            const center = (root.loopMode >= 2 || (root.attitudeMode && row === 2)) && isFinite(latest) ? latest : 0
                            const scale = rowScale(targets[row], actuals[row], minimum, center)
                            drawSeries(ctx, targets[row], labelW, top, width - labelW, rowH, scale, "#FF8A24", 2.0, center)
                            drawSeries(ctx, actuals[row], labelW, top, width - labelW, rowH, scale, "#55C5FF", 1.8, center)
                        }
                        const enabled = [root.showP, root.showI, root.showD]
                        const colors = ["#6BE0AF", "#C4A4FF", "#FFD078"]
                        const names = ["P", "I", "D"]
                        const histories = root.termHistory[row] || []
                        let termScale = 0.01
                        for (let term = 0; term < 3; term++) {
                            if (!enabled[term]) continue
                            for (const value of histories[term] || []) if (isFinite(value)) termScale = Math.max(termScale, Math.abs(value) * 1.15)
                        }
                        if (root.termsSelected) {
                            ctx.fillStyle = "#91A8B8"
                            ctx.textAlign = "right"
                            ctx.fillText(qsTr("分量量程 ±") + termScale.toFixed(3), width - 8, top + 7)
                            ctx.textAlign = "left"
                        }
                        for (let term = 0; term < 3; term++) {
                            if (!enabled[term]) continue
                            ctx.fillStyle = colors[term]
                            const values = histories[term] || []
                            const latest = values.length ? values[values.length - 1] : NaN
                            const text = isFinite(latest) ? latest.toFixed(3) : qsTr("未上报")
                            ctx.fillText(names[term] + " " + text, labelW + term * Math.min(120, (width-labelW)/3), top + rowH - 22)
                            drawSeries(ctx, histories[term] || [], labelW, top, width - labelW, rowH, termScale, colors[term], 1.7)
                        }
                    }
                }
            }
        }

        RowLayout {
            id: footer
            visible: root.expanded
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: root.margin
            anchors.rightMargin: root.margin
            height: Math.max(ScreenTools.minTouchPixels, ScreenTools.defaultFontPixelHeight * 2.5)
            spacing: root.margin

            QGCLabel { Layout.fillWidth: true; visible: !root.compactMobile; text: root.termsSelected ? qsTr("P 绿　I 紫　D 金 · 分量独立刻度") : qsTr("橙色：期望　蓝色：实际"); color: "#91A8B8"; font.family: root.roundedFont; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.68 * root.fontScale; elide: Text.ElideRight }
            QGCButton { visible: !root.compactMobile; text: qsTr("清除"); onClicked: root.clearHistory() }
            QGCButton { visible: !root.fullScreen; text: "－"; enabled: root.sizeFactor > root.scaleMin; onClicked: root.adjustSize(-root.scaleStep); Layout.preferredWidth: Math.max(ScreenTools.minTouchPixels * 0.8, footer.height * 1.15) }
            QGCLabel { visible: !root.fullScreen; text: Math.round(root.sizeFactor * 100) + "%"; color: "#9EC8E2"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7 * root.fontScale; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 4 }
            QGCButton { visible: !root.fullScreen; text: "＋"; enabled: root.sizeFactor < root.scaleMax; onClicked: root.adjustSize(root.scaleStep); Layout.preferredWidth: Math.max(ScreenTools.minTouchPixels * 0.8, footer.height * 1.15) }
            QGCButton { text: root.fullScreen ? qsTr("退出全屏") : qsTr("全屏"); onClicked: root.fullScreen ? root.exitFullScreen() : root.requestFullScreen() }
            QGCButton { visible: !root.fullScreen; text: qsTr("隐藏"); onClicked: root.expanded = false }
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
