pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

import QGroundControl
import QGroundControl.Controls
import "HQDashboardMath.js" as DashboardMath
import "HQDashboardTheme.js" as Theme

Item {
    id: root
    property var vehicle: null
    property bool expanded: false
    property bool fullScreen: false
    property bool resizing: false
    property bool dragging: false
    readonly property string dockTitle: qsTr("仪表")
    property int dockSide: 0
    property bool choosing: false
    property string floatingDragKey: ""
    readonly property bool modeAnimationsEnabled: preferences.modeAnimations
    readonly property var floatingEntries: parseFloatingLayout(preferences.floatingLayout)
    property real savedX: 0
    property real savedY: 0
    property real sizeFactor: ScreenTools.isMobile ? 0.8 : 1
    readonly property real margin: ScreenTools.defaultFontPixelWidth
    readonly property real scaleMin: 0.6
    readonly property real scaleMax: 1.6
    readonly property real openWidth: Math.min(660 * sizeFactor, parent ? parent.width * 0.92 : 660)
    readonly property real minimumOpenHeight: ScreenTools.defaultFontPixelHeight * 13
    readonly property real openHeight: Math.min(Math.max(minimumOpenHeight, 550 * sizeFactor * preferences.heightFactor), parent ? parent.height * 0.85 : 550)
    readonly property real heightFactor: preferences.heightFactor
    readonly property var compositeParts: preferences.compositeParts ? preferences.compositeParts.split(",") : []
    readonly property string actualFlightMode: connected && freshness.revision >= 0 && freshness.available("flightMode") ? vehicle.flightMode : ""
    readonly property var activeTheme: Theme.theme(preferences.followMode ? Theme.modeKey(actualFlightMode) : preferences.manualTheme)
    readonly property var selectedKeys: preferences.selection ? preferences.selection.split(",") : []
    readonly property bool connected: !!vehicle && !vehicle.vehicleLinkManager.communicationLost
    readonly property var primaryBattery: vehicle && vehicle.batteries.count > 0 ? vehicle.batteries.get(0) : null
    readonly property var instruments: [
        {key: "composite", title: qsTr("综合仪表盘数据 / Flight deck")},
        {key: "groundSpeed", title: qsTr("地速 / Ground speed"), unit: "m/s", min: 0, max: 30, color: "#55E3BE"},
        {key: "altitudeRelative", title: qsTr("相对高度 / Relative altitude"), unit: "m", min: -20, max: 200, color: "#5CD5F0"},
        {key: "climbRate", title: qsTr("爬升率 / Vertical speed"), unit: "m/s", min: -10, max: 10, color: "#FFBC61"},
        {key: "heading", title: qsTr("航向 / Heading"), unit: "°", min: 0, max: 360, color: "#5CD5F0"},
        {key: "battery", title: qsTr("电量 / Battery"), unit: "%", min: 0, max: 100, color: "#55E3BE"},
        {key: "rcRSSI", title: qsTr("遥控信号 / RC RSSI"), unit: "%", min: 0, max: 100, color: "#55E3BE"},
        {key: "airSpeed", title: qsTr("空速 / Airspeed"), unit: "m/s", min: 0, max: 40, color: "#55E3BE"},
        {key: "roll", title: qsTr("横滚角 / Roll"), unit: "°", min: -90, max: 90, color: "#B5A0FF"},
        {key: "pitch", title: qsTr("俯仰角 / Pitch"), unit: "°", min: -90, max: 90, color: "#B5A0FF"}
    ]
    readonly property bool compositeSelected: selectedKeys.indexOf("composite") >= 0
    readonly property int speedUnitIndex: Math.max(0, Math.min(4, preferences.speedUnit))
    readonly property var shownInstruments: instruments.filter(function(item) { return item.key !== "composite" && root.selectedKeys.indexOf(item.key) >= 0 })
    readonly property bool obstacleArrayAvailable: connected && freshness.revision >= 0 && freshness.available("obstacleDistance")
    readonly property bool radarAvailable: connected && freshness.revision >= 0 && (obstacleArrayAvailable || [0, 1, 2, 3, 4, 5, 6, 7].some(function(i) { return freshness.available("distance" + i) }))
    readonly property bool radarNeedsHeading: obstacleArrayAvailable && vehicle.objectAvoidance.frame === 0 && !isFinite(numberFor("heading"))
    readonly property var radarPoints: obstaclePoints()

    Settings {
        id: preferences
        category: "HQFlightDashboard"
        property string selection: "groundSpeed,altitudeRelative,climbRate,heading"
        property int speedUnit: 0
        property int centerMode: 0
        property int radarRangeIndex: 1
        property int warningIndex: 1
        property real heightFactor: 1
        property string compositeParts: "speed,center,mode"
        property bool followMode: true
        property bool modeAnimations: true
        property string manualTheme: "stabilize"
        property string floatingLayout: "{}"
    }
    HQDashboardController { id: freshness; objectName: "dashboardFreshness"; vehicle: root.vehicle }
    HQPanelMotion { id: panelMotion; targetItem: root }

    width: fullScreen && expanded && parent ? parent.width : expanded ? openWidth : Math.ceil(dashboardTitle.implicitWidth + margin * 2)
    height: fullScreen && expanded && parent ? parent.height : expanded ? openHeight : ScreenTools.defaultFontPixelHeight * 2.8
    z: QGroundControl.zOrderTopMost + (fullScreen ? 40 : 20)
    Behavior on width { enabled: panelMotion.animateGeometry; NumberAnimation { duration: panelMotion.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: panelMotion.fluidCurve } }
    Behavior on height { enabled: panelMotion.animateGeometry; NumberAnimation { duration: panelMotion.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: panelMotion.fluidCurve } }

    function setSelected(key, selected) {
        if (!instruments.some(function(item) { return item.key === key })) return
        const keys = selectedKeys.filter(function(item) { return item !== key })
        if (selected) keys.push(key)
        preferences.selection = keys.join(",")
    }
    function setCompositePart(key, selected) {
        if (["speed", "altitude", "center", "mode"].indexOf(key) < 0) return
        const keys = compositeParts.filter(function(item) { return item !== key })
        if (selected) keys.push(key)
        preferences.compositeParts = keys.join(",")
    }
    function moveCompositePart(key, direction) {
        const keys = compositeParts.slice()
        const index = keys.indexOf(key), next = index + direction
        if (index < 0 || next < 0 || next >= keys.length) return
        keys.splice(index, 1); keys.splice(next, 0, key)
        preferences.compositeParts = keys.join(",")
    }
    function setViewportHeight(pixels) {
        if (fullScreen) return
        const maxHeight = parent ? Math.max(minimumOpenHeight, parent.height - y - margin) : 900
        preferences.heightFactor = Math.max(minimumOpenHeight, Math.min(maxHeight, pixels)) / (550 * sizeFactor)
    }
    function resetViewportHeight() { preferences.heightFactor = 1 }
    function selectDefault() { preferences.selection = "groundSpeed,altitudeRelative,climbRate,heading" }
    function selectOnly(key) { if (instruments.some(function(item) { return item.key === key })) preferences.selection = key }
    function numberFor(key) {
        // Read the revision so both packet receipt and timeout reevaluate the binding.
        const revision = freshness.revision
        if (!connected) return NaN
        if (key === "battery") {
            if (!primaryBattery || !freshness.available("battery" + primaryBattery.id.rawValue)) return NaN
            const percent = Number(primaryBattery.percentRemaining.rawValue)
            return isFinite(percent) && percent >= 0 && percent <= 100 ? percent : NaN
        }
        if (!freshness.available(key) || !vehicle[key]) return NaN
        const value = Number(vehicle[key].rawValue)
        if (!isFinite(value) || (key === "rcRSSI" && (value < 0 || value > 100))) return NaN
        if (key === "missionItemIndex" && (value < 0 || value >= 65535)) return NaN
        return value
    }
    function obstaclePoints() {
        const revision = freshness.revision
        if (!radarAvailable) return []
        if (obstacleArrayAvailable && vehicle.objectAvoidance) {
            const data = vehicle.objectAvoidance
            return DashboardMath.obstaclePoints(data.distances, data.increment, data.angleOffset, data.frame, numberFor("heading"), data.minDistance, data.maxDistance)
        }
        if (!vehicle.distanceSensors) return []
        const fields = ["rotationNone", "rotationYaw45", "rotationYaw90", "rotationYaw135", "rotationYaw180", "rotationYaw225", "rotationYaw270", "rotationYaw315"]
        const result = []
        for (let i = 0; i < fields.length; ++i) {
            if (!freshness.available("distance" + i)) continue
            const value = Number(vehicle.distanceSensors[fields[i]].rawValue)
            if (isFinite(value) && value >= 0) result.push({bearing: i * 45, distance: value})
        }
        return result
    }
    function isSpeed(key) { return key === "groundSpeed" || key === "airSpeed" }
    function readingFor(key) { return isSpeed(key) ? DashboardMath.speed(numberFor(key), speedUnitIndex) : numberFor(key) }
    function maximumFor(item) { return isSpeed(item.key) ? DashboardMath.speedMaximum(item.key, speedUnitIndex) : item.max }
    function unitFor(item) { return isSpeed(item.key) ? DashboardMath.speedUnits[speedUnitIndex] : item.unit }
    function setSpeedUnit(index) { if (index >= 0 && index < 5) preferences.speedUnit = index }
    function speedIntervalsFor(key) { return DashboardMath.speedIntervals(key, speedUnitIndex) }
    function modeTokenFor(key) { return isSpeed(key) && preferences.followMode && actualFlightMode ? Theme.modeKey(actualFlightMode) : "" }
    function parseFloatingLayout(text) {
        let entries
        try { entries = JSON.parse(text) } catch (error) { return {} }
        if (!entries || typeof entries !== "object" || Array.isArray(entries)) return {}
        const valid = {}
        for (const item of instruments) {
            const entry = entries[item.key]
            if (item.key === "composite" || !entry || !isFinite(entry.x) || !isFinite(entry.y) || !isFinite(entry.size)) continue
            valid[item.key] = {x: Math.max(0, Math.min(1, entry.x)), y: Math.max(0, Math.min(1, entry.y)), size: Math.max(0.65, Math.min(1.8, entry.size))}
        }
        return valid
    }
    function floatingEntry(key) { return floatingEntries[key] || null }
    function floatingItem(key) {
        for (let i = 0; i < floatingRepeater.count; ++i) {
            const item = floatingRepeater.itemAt(i)
            if (item && item.instrumentKey === key) return item
        }
        return null
    }
    function saveFloating(key, placement) {
        if (!instruments.some(function(item) { return item.key === key && key !== "composite" })) return
        const entries = Object.assign({}, floatingEntries)
        entries[key] = placement
        preferences.floatingLayout = JSON.stringify(parseFloatingLayout(JSON.stringify(entries)))
    }
    function dockInstrument(key) {
        const entries = Object.assign({}, floatingEntries)
        delete entries[key]
        preferences.floatingLayout = JSON.stringify(entries)
        setSelected(key, true)
        floatingDragKey = ""
    }
    function acceptsInstrumentAt(point) {
        if (!expanded || !visible || !parent) return false
        const local = mapFromItem(parent, point.x, point.y)
        return local.x >= 0 && local.y >= 0 && local.x <= width && local.y <= height
    }
    function placeInstrument(key) {
        const index = instruments.findIndex(function(item) { return item.key === key }) - 1
        if (index < 0) return
        saveFloating(key, {x: 0.08 + (index % 3) * 0.32, y: 0.12 + Math.floor(index / 3) * 0.25, size: 0.85})
    }
    function detachInstrument(key) {
        if (!floatingEntry(key)) saveFloating(key, {x: 0.08, y: 0.6, size: 1})
    }
    function moveInstrumentFromCard(key, area, mouseX, mouseY) {
        if (!parent) return
        const point = area.mapToItem(parent, mouseX, mouseY)
        detachInstrument(key)
        floatingDragKey = key
        const item = floatingItem(key)
        if (item) item.moveCenter(point)
    }
    function finishInstrumentFromCard(key, area, mouseX, mouseY, canceled) {
        if (floatingDragKey !== key) return
        const item = floatingItem(key)
        if (item) item.finishDrag(area.mapToItem(parent, mouseX, mouseY), canceled)
        floatingDragKey = ""
    }
    function clampPosition() {
        if (!parent || dockSide !== 0 || resizing || fullScreen || panelMotion.sizing || panelMotion.fullScreenTransition) return
        x = Math.max(margin, Math.min(x, parent.width - width - margin))
        y = Math.max(margin, Math.min(y, parent.height - height - margin))
    }
    onExpandedChanged: {
        if (!expanded && fullScreen) { fullScreen = false; x = savedX; y = savedY }
    }

    Item {
        parent: root.parent
        anchors.fill: parent
        visible: root.visible
        z: QGroundControl.zOrderTopMost + (root.floatingDragKey ? 90 : 25)
        Repeater {
            id: floatingRepeater
            model: root.instruments.filter(function(item) { return item.key !== "composite" })
            HQDetachedInstrument {
                required property var modelData
                dashboard: root
                descriptor: modelData
            }
        }
    }

    Rectangle {
        visible: root.dockSide === 0
        anchors.fill: parent
        color: "#F20C2335"
        radius: root.fullScreen ? 0 : root.expanded ? 12 : 24
        border.width: 1
        border.color: "#4ABAC8"
        clip: true
        Behavior on radius { NumberAnimation { duration: panelMotion.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: panelMotion.fluidCurve } }

        RowLayout {
            id: header
            anchors.left: parent.left; anchors.top: parent.top
            anchors.margins: root.margin
            width: Math.max(0, (panelMotion.contentVisible ? panelMotion.contentWidth : parent.width) - root.margin * 2)
            height: ScreenTools.defaultFontPixelHeight * 1.7
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                HQToolIcon { width: 22; height: 22; anchors.verticalCenter: parent.verticalCenter; kind: "dashboard" }
                QGCLabel { id: dashboardTitle; anchors.fill: parent; leftPadding: 28; text: qsTr("飞行仪表盘"); color: "#DDFBFF"; verticalAlignment: Text.AlignVCenter; font.weight: Font.DemiBold }
                MouseArea {
                    id: toolHeaderMouse
                    HQButtonRipple { objectName: "headerRipple"; control: toolHeaderMouse }
                    objectName: "dashboardHeader"
                    anchors.fill: parent
                    preventStealing: true
                    drag.target: root.fullScreen ? null : root
                    drag.minimumX: 0
                    drag.maximumX: root.parent ? Math.max(0, root.parent.width - root.width) : 0
                    drag.minimumY: 0
                    drag.maximumY: root.parent ? Math.max(0, root.parent.height - root.height) : 0
                    property bool moved: false
                    onPressed: moved = false
                    onPositionChanged: if (drag.active) { moved = true; root.dragging = true }
                    onReleased: { root.dragging = false; if (moved) panelMotion.finishDockDrag(); else root.expanded = !root.expanded }
                    onCanceled: root.dragging = false
                }
            }
            QGCButton {
                visible: root.expanded
                text: root.choosing ? qsTr("完成") : qsTr("选择仪表")
                onClicked: root.choosing = !root.choosing
            }
            // Reserve space for the shared fullscreen button above this content.
            Item { visible: root.expanded; Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 2.7 }
        }

        ColumnLayout {
            objectName: "dashboardStableContent"
            visible: panelMotion.contentVisible
            enabled: root.expanded
            opacity: root.expanded ? 1 : 0
            Behavior on opacity { OpacityAnimator { duration: 180; easing.type: Easing.OutCubic } }
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.margins: root.margin
            width: Math.max(0, panelMotion.contentWidth - root.margin * 2)
            height: Math.max(0, panelMotion.contentHeight - header.height - footer.height - root.margin * 4)
            spacing: root.margin * 0.5
            QGCLabel {
                Layout.fillWidth: true
                text: !root.connected ? qsTr("未连接 · 等待飞控遥测") : qsTr("实时遥测 · 未上报或超过 5 秒未更新显示 --")
                color: root.connected ? "#9DC2CF" : "#FFBC61"
                font.pointSize: ScreenTools.smallFontPointSize
                wrapMode: Text.WordWrap
            }
            ScrollView {
                visible: root.choosing
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                ColumnLayout {
                    width: parent.width
                    QGCLabel { text: qsTr("独立显示仪表 · 点击放置，再次点击收回"); color: "#D9EFF4" }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.width < 480 ? 2 : 3
                        Repeater {
                            model: root.instruments.filter(function(item) { return item.key !== "composite" })
                            QGCButton {
                                required property var modelData
                                objectName: "quickPlace-" + modelData.key
                                Layout.fillWidth: true
                                text: modelData.title.split("/")[0].trim() + (root.floatingEntry(modelData.key) ? qsTr(" · 收回") : "")
                                onClicked: if (root.floatingEntry(modelData.key)) root.dockInstrument(modelData.key); else root.placeInstrument(modelData.key)
                            }
                        }
                    }
                    QGCLabel { text: qsTr("水平速度单位 / Speed unit"); color: "#B8D2DE" }
                    QGCComboBox { model: DashboardMath.speedUnits; currentIndex: root.speedUnitIndex; onActivated: root.setSpeedUnit(currentIndex) }
                    QGCLabel { text: qsTr("雷达显示范围（仅显示设置）"); color: "#B8D2DE" }
                    QGCComboBox { model: ["10 m", "20 m", "50 m", "100 m"]; currentIndex: preferences.radarRangeIndex; onActivated: preferences.radarRangeIndex = currentIndex }
                    QGCLabel { text: qsTr("雷达近距颜色提示（不控制飞控）"); color: "#B8D2DE" }
                    QGCComboBox { model: ["1 m", "2 m", "3 m", "5 m"]; currentIndex: preferences.warningIndex; onActivated: preferences.warningIndex = currentIndex }
                    QGCCheckBox { text: qsTr("主题跟随飞控实际模式"); checked: preferences.followMode; onClicked: preferences.followMode = checked }
                    QGCCheckBox { text: qsTr("仪表动效（指针扫满回位、数字轻跳，读数实时）"); checked: preferences.modeAnimations; onClicked: preferences.modeAnimations = checked }
                    QGCComboBox {
                        visible: !preferences.followMode
                        model: [qsTr("白色机械 · Stabilize / 自稳"), qsTr("白色精密 · AltHold / 定高"), qsTr("黑色 RS 风格 · Loiter / Position"), qsTr("黑色半圆 · RTL / Return"), qsTr("黑色航线 · Auto / Mission"), qsTr("红色性能 · Acro / 特技"), qsTr("黑色指令 · Guided / 引导"), qsTr("白色下降 · Land / 降落"), qsTr("黑色八角 · Brake / 刹停"), qsTr("黑色轨道 · Circle / Orbit"), qsTr("白色运动 · Sport"), qsTr("红色操纵 · Manual"), qsTr("黑色追踪 · Follow"), qsTr("红色翼形 · Rattitude"), qsTr("白色上升 · Takeoff"), qsTr("绿色外控 · Offboard / 外部控制")]
                        currentIndex: Math.max(0, Theme.keys().indexOf(preferences.manualTheme))
                        onActivated: preferences.manualTheme = Theme.keys()[currentIndex]
                    }
                    QGCLabel { text: qsTr("自由组合综合仪表（勾选后可调整顺序）"); color: "#D9EFF4" }
                    QGCLabel {
                        Layout.fillWidth: true
                        text: qsTr("拖动 ≡ 调整显示顺序；触屏长按拖动，也可使用下方箭头。")
                        color: "#9DC2CF"
                        wrapMode: Text.WordWrap
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                    HQInstrumentOrder {
                        objectName: "compositeOrderEditor"
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        keys: root.compositeParts
                        animationsEnabled: preferences.modeAnimations
                        enabled: root.expanded && root.choosing
                        onOrderRequested: function(key, index) {
                            root.moveCompositePart(key, index - root.compositeParts.indexOf(key))
                        }
                    }
                    Repeater {
                        model: [{key: "speed", label: qsTr("速度表")}, {key: "altitude", label: qsTr("高度带")}, {key: "center", label: qsTr("航点 / 雷达 / 概览")}, {key: "mode", label: qsTr("实际飞行模式")}]
                        delegate: RowLayout {
                            id: partChoice
                            required property var modelData
                            Layout.fillWidth: true
                            QGCCheckBox { Layout.fillWidth: true; text: partChoice.modelData.label; checked: root.compositeParts.indexOf(partChoice.modelData.key) >= 0; onClicked: root.setCompositePart(partChoice.modelData.key, checked) }
                            QGCButton { text: "↑"; enabled: root.compositeParts.indexOf(partChoice.modelData.key) > 0; onClicked: root.moveCompositePart(partChoice.modelData.key, -1) }
                            QGCButton { text: "↓"; enabled: root.compositeParts.indexOf(partChoice.modelData.key) >= 0 && root.compositeParts.indexOf(partChoice.modelData.key) < root.compositeParts.length - 1; onClicked: root.moveCompositePart(partChoice.modelData.key, 1) }
                        }
                    }
                    Repeater {
                        model: root.instruments
                        delegate: RowLayout {
                            id: choice
                            required property var modelData
                            Layout.fillWidth: true
                            QGCCheckBox {
                                Layout.fillWidth: true
                                text: choice.modelData.title
                                checked: root.selectedKeys.indexOf(choice.modelData.key) >= 0
                                onClicked: root.setSelected(choice.modelData.key, checked)
                            }
                            QGCButton {
                                objectName: "placeInstrument-" + choice.modelData.key
                                visible: choice.modelData.key !== "composite"
                                text: root.floatingEntry(choice.modelData.key) ? qsTr("收回") : qsTr("放到主界面")
                                onClicked: if (root.floatingEntry(choice.modelData.key)) root.dockInstrument(choice.modelData.key); else root.placeInstrument(choice.modelData.key)
                            }
                            QGCButton { text: qsTr("只显示此项"); onClicked: { root.selectOnly(choice.modelData.key); root.choosing = false } }
                        }
                    }
                    QGCButton {
                        text: qsTr("将已选单项仪表放到主界面")
                        enabled: root.shownInstruments.length > 0
                        onClicked: {
                            root.shownInstruments.forEach(function(item, index) {
                                root.saveFloating(item.key, {x: (index % 3) * 0.45, y: Math.floor(index / 3) * 0.45, size: 0.85})
                            })
                            root.choosing = false
                            root.expanded = false
                        }
                    }
                    QGCButton { text: qsTr("恢复常用四项"); onClicked: root.selectDefault() }
                }
            }
            ScrollView {
                id: dialScroll
                visible: !root.choosing
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                ColumnLayout {
                    width: dialScroll.availableWidth
                    HQCompositeDashboard {
                        dashboard: root
                        visible: root.compositeSelected
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        speed: root.readingFor("groundSpeed")
                        speedMaximum: DashboardMath.speedMaximum("groundSpeed", root.speedUnitIndex)
                        speedIntervals: DashboardMath.speedIntervals("groundSpeed", root.speedUnitIndex)
                        speedUnit: DashboardMath.speedUnits[root.speedUnitIndex]
                        flightMode: root.actualFlightMode
                        parts: root.compositeParts
                        followMode: preferences.followMode
                        manualTheme: preferences.manualTheme
                        animationsEnabled: preferences.modeAnimations
                        waypoint: root.numberFor("missionItemIndex")
                        distance: root.numberFor("distanceToNextWP")
                        altitude: root.numberFor("altitudeRelative")
                        climb: root.numberFor("climbRate")
                        heading: root.numberFor("heading")
                        battery: root.numberFor("battery")
                        obstacles: root.radarPoints
                        radarAvailable: root.radarAvailable
                        radarNeedsHeading: root.radarNeedsHeading
                        radarRange: [10, 20, 50, 100][Math.max(0, Math.min(3, preferences.radarRangeIndex))]
                        warningDistance: [1, 2, 3, 5][Math.max(0, Math.min(3, preferences.warningIndex))]
                        centerMode: Math.max(0, Math.min(2, preferences.centerMode))
                        onCenterModeSelected: function(mode) { preferences.centerMode = mode }
                    }
                GridLayout {
                    Layout.fillWidth: true
                    columns: root.shownInstruments.length === 1 ? 1 : Math.max(1, Math.min(root.shownInstruments.length <= 4 ? 2 : 4, Math.floor(width / 210)))
                    rowSpacing: root.margin; columnSpacing: root.margin
                    Repeater {
                        model: root.shownInstruments
                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            readonly property real reading: root.readingFor(modelData.key)
                            readonly property real maximum: root.maximumFor(modelData)
                            readonly property string unit: root.unitFor(modelData)
                            readonly property bool ring: modelData.key === "battery" || modelData.key === "rcRSSI"
                            readonly property bool linear: modelData.key === "altitudeRelative" || modelData.key === "climbRate"
                            readonly property bool angular: root.isSpeed(modelData.key) && root.activeTheme.kind === "digital"
                            readonly property bool available: isFinite(reading)
                            readonly property bool outside: available && (reading < modelData.min || reading > maximum)
                            readonly property bool detached: !!root.floatingEntry(modelData.key)
                            objectName: "dashboardCard-" + modelData.key
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.shownInstruments.length === 1 ? Math.max(180, Math.min(dialScroll.height - 5, 360)) : card.linear ? 250 : 200
                            Layout.minimumWidth: 140
                            color: "#142F40"; radius: 12; border.color: "#2A4D60"
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 10
                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: card.modelData.title
                                    color: "#DBEEF6"; font.pointSize: ScreenTools.smallFontPointSize
                                    horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                                }
                                Item {
                                    id: instrumentArea
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: Math.max(100, Math.min(card.width - 28, card.height - 66))
                                    Layout.preferredHeight: width
                                    HQFlightDial {
                                        anchors.fill: parent; visible: !card.detached && !card.ring && !card.linear && !card.angular
                                        value: card.reading; minimum: card.modelData.min; maximum: card.maximum
                                        majorIntervals: root.isSpeed(card.modelData.key) ? DashboardMath.speedIntervals(card.modelData.key, root.speedUnitIndex) : 6
                                        compass: card.modelData.key === "heading"
                                        valueText: card.available ? card.reading.toFixed(compass ? 0 : 1) : "--"
                                        unit: card.unit
                                        skin: root.activeTheme.skin
                                        accent: root.activeTheme.accent
                                        badge: root.isSpeed(card.modelData.key) ? root.activeTheme.name : ""
                                        modeToken: root.isSpeed(card.modelData.key) && preferences.followMode && root.actualFlightMode ? Theme.modeKey(root.actualFlightMode) : ""
                                        animationsEnabled: preferences.modeAnimations
                                    }
                                    HQLinearInstrument { anchors.fill: parent; visible: !card.detached && card.linear; value: card.reading; verticalSpeed: card.modelData.key === "climbRate"; accent: card.modelData.color; animationsEnabled: preferences.modeAnimations }
                                    HQAngularSpeed { anchors.fill: parent; visible: !card.detached && card.angular; value: card.reading; maximum: card.maximum; unit: card.unit; accent: root.activeTheme.accent; theme: root.activeTheme }
                                    HQCircularGauge {
                                        anchors.fill: parent; visible: !card.detached && card.ring
                                        instrumentStyle: false
                                        fraction: card.available ? card.reading / 100 : NaN
                                        valueText: card.available ? card.reading.toFixed(0) : "--"
                                        caption: "%"
                                        centerSymbol: card.modelData.key === "battery" ? "▰" : ""
                                        critical: card.available && card.reading <= 20
                                        accentColor: critical ? "#FF705E" : card.modelData.color
                                    }
                                    QGCLabel {
                                        anchors.centerIn: parent; width: parent.width
                                        visible: card.detached
                                        text: qsTr("已移到主界面\n拖回这里即可收纳")
                                        wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                                        color: "#9DB9C9"
                                    }
                                    HQInstrumentDragArea {
                                        objectName: "dashboardDrag-" + card.modelData.key
                                        anchors.fill: parent
                                        dashboard: root
                                        instrumentKey: card.modelData.key
                                    }
                                    QGCButton {
                                        objectName: "dialPlace-" + card.modelData.key
                                        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
                                        text: card.detached ? qsTr("收回仪表") : qsTr("独立显示")
                                        onClicked: if (card.detached) root.dockInstrument(card.modelData.key); else root.placeInstrument(card.modelData.key)
                                    }
                                }
                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: card.detached ? qsTr("主界面独立显示中") : !card.available ? qsTr("等待数据 / 数据已过期") : card.outside ? qsTr("超出显示量程 · 数值仍为实际值") : card.modelData.key === "battery" ? qsTr("飞控上报电量 · 非电压估算") : qsTr("实时值 · 刻度仅为显示量程")
                                    color: card.outside ? "#FFBC61" : "#819EAF"
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                    QGCLabel { visible: root.shownInstruments.length === 0 && !root.compositeSelected; text: qsTr("尚未选择仪表，请点击“选择仪表”。"); color: "#9DC2CF"; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                }
                }
            }
        }
        RowLayout {
            id: footer
            visible: root.expanded
            anchors.left: parent.left
            anchors.margins: root.margin
            width: Math.max(0, panelMotion.contentWidth - root.margin * 2)
            y: panelMotion.contentHeight - height - root.margin
            height: ScreenTools.defaultFontPixelHeight * 2
            QGCLabel { Layout.fillWidth: true; text: qsTr("拖出单项仪表；触屏长按后拖动"); color: "#819EAF"; font.pointSize: ScreenTools.smallFontPointSize; elide: Text.ElideRight }
            QGCComboBox { objectName: "dashboardSpeedUnit"; model: DashboardMath.speedUnits; currentIndex: root.speedUnitIndex; onActivated: root.setSpeedUnit(currentIndex) }
            QGCButton { text: qsTr("满高"); visible: root.heightFactor < 0.99; onClicked: root.resetViewportHeight() }
            QGCButton { text: "－"; enabled: !root.fullScreen && root.sizeFactor > root.scaleMin; onClicked: panelMotion.adjustSize(-0.1) }
            QGCButton { text: "＋"; enabled: !root.fullScreen && root.sizeFactor < root.scaleMax; onClicked: panelMotion.adjustSize(0.1) }
            QGCButton { text: qsTr("收起"); onClicked: root.expanded = false }
        }
    }
    Rectangle {
        anchors.fill: parent; anchors.margins: 4
        visible: root.expanded && root.floatingDragKey.length > 0
        color: "#1623BFA5"; radius: 12; border.width: 2; border.color: "#68BCA8"
        QGCLabel { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 12; text: qsTr("拖到面板内松开，收回仪表"); color: "#C6EEE3" }
    }
    HQResizeHandle { targetItem: root; motionController: panelMotion; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; visible: root.expanded && !root.fullScreen }
    HQDashboardHeightHandle { targetItem: root; motionController: panelMotion; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; visible: root.expanded && !root.fullScreen }
}
