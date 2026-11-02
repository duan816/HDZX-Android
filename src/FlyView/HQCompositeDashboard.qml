pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import "HQDashboardTheme.js" as Theme

Rectangle {
    id: root
    property var dashboard: null
    property real speed: NaN
    property real speedMaximum: 120
    property int speedIntervals: 6
    property string speedUnit: "km/h"
    property string flightMode: ""
    property real waypoint: NaN
    property real distance: NaN
    property real altitude: NaN
    property real climb: NaN
    property real heading: NaN
    property real battery: NaN
    property var obstacles: []
    property bool radarAvailable: false
    property bool radarNeedsHeading: false
    property int centerMode: 0
    property real radarRange: 20
    property real warningDistance: 2
    property var parts: ["speed", "center", "mode"]
    property bool followMode: true
    property string manualTheme: "stabilize"
    property bool animationsEnabled: true
    readonly property var validParts: parts.filter(function(key, index, values) { return ["speed", "altitude", "center", "mode"].indexOf(key) >= 0 && values.indexOf(key) === index })
    readonly property string modeKey: Theme.modeKey(flightMode)
    readonly property var theme: Theme.theme(followMode ? modeKey : manualTheme)
    readonly property bool angularSpeed: theme.kind === "digital"
    readonly property int columns: wide && validParts.length === 3 ? 3 : Math.max(1, Math.min(2, validParts.length))
    property string previousMode: ""
    property bool ready: false
    property real reveal: 1
    property real scan: 0
    property real glow: 0
    readonly property bool transitionRunning: modeReveal.running
    readonly property bool modeBadgeReady: modeIcon.painted
    readonly property bool wide: width >= 600
    signal centerModeSelected(int mode)
    color: theme.surface
    radius: 12
    border.color: theme.accent
    implicitHeight: 85 + Math.ceil(Math.max(1, validParts.length) / columns) * (wide ? 285 : 240)
    Behavior on color { enabled: root.animationsEnabled; ColorAnimation { duration: 350 } }
    Behavior on border.color { enabled: root.animationsEnabled; ColorAnimation { duration: 350 } }

    function columnFor(key) { return Math.max(0, validParts.indexOf(key)) % columns }
    function rowFor(key) { return Math.floor(Math.max(0, validParts.indexOf(key)) / columns) }
    function changedMode() {
        modeReveal.stop(); sweep.stop(); halo.stop()
        reveal = 1; scan = 0; glow = 0
        const key = Theme.modeKey(flightMode)
        if (ready && visible && animationsEnabled && previousMode && key !== "neutral" && previousMode !== key && flightMode) {
            reveal = 0.72
            modeReveal.start(); sweep.start(); halo.start()
        }
        previousMode = flightMode ? key : ""
    }
    onFlightModeChanged: changedMode()
    onAnimationsEnabledChanged: if (!animationsEnabled) { modeReveal.stop(); sweep.stop(); halo.stop(); reveal = 1; glow = 0 }
    onVisibleChanged: if (!visible) { modeReveal.stop(); sweep.stop(); halo.stop(); reveal = 1; glow = 0 }
    Component.onCompleted: { previousMode = flightMode ? modeKey : ""; ready = true }
    NumberAnimation { id: modeReveal; target: root; property: "reveal"; to: 1; duration: 450; easing.type: Easing.OutCubic }
    NumberAnimation { id: sweep; target: root; property: "scan"; from: 0; to: 1; duration: 700; easing.type: Easing.InOutCubic }
    NumberAnimation { id: halo; target: root; property: "glow"; from: 0.75; to: 0; duration: 850; easing.type: Easing.OutCubic }

    function display(value, digits) { return isFinite(value) ? value.toFixed(digits) : "--" }
    function modeChinese(mode) {
        const names = {Stabilize: "自稳", AltHold: "定高", "Altitude Hold": "定高", Loiter: "定点", Auto: "自动任务", RTL: "返航", Land: "降落", Guided: "引导", Acro: "特技", Sport: "运动", PosHold: "位置保持", "Position Hold": "位置保持", Brake: "刹停", Manual: "手动", Hold: "保持", Mission: "任务", "Return": "返航", "Position": "位置", "Altitude": "高度", Stabilized: "自稳", Offboard: "外部控制", "Smart RTL": "智能返航", Circle: "绕圈"}
        return names[mode] || ""
    }
    // Decorative chassis only; every reading below comes from a live Fact.
    Rectangle { anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; width: parent.width * 0.64; height: 2; color: root.theme.accent }
    Rectangle { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: parent.width * 0.5; height: 2; color: root.theme.accent }
    Item {
        anchors.fill: parent; clip: true
        // Decoration stays behind the readings; no screen-wide mask.
        Rectangle { x: root.scan * (parent.width + width) - width; y: 12; width: parent.width * 0.12; height: parent.height - 24; rotation: -16; color: root.theme.accent; opacity: root.glow * 0.1 }
        Rectangle { anchors.fill: parent; anchors.margins: 3; radius: 10; color: "transparent"; border.color: root.theme.accent; border.width: 3; opacity: root.glow }
    }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 12; spacing: 10
        RowLayout {
            Layout.fillWidth: true
            QGCLabel { Layout.fillWidth: true; text: qsTr("综合仪表盘 / ") + root.theme.name; color: root.theme.accent; font.weight: Font.DemiBold; elide: Text.ElideRight }
            QGCComboBox { visible: root.validParts.indexOf("center") >= 0; objectName: "compositeCenterChoice"; Layout.maximumWidth: root.width * 0.48; model: [qsTr("航点导航"), qsTr("避障雷达"), qsTr("飞行概览")]; currentIndex: root.centerMode; onActivated: root.centerModeSelected(currentIndex) }
        }
        GridLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            columns: root.columns
            columnSpacing: 14; rowSpacing: 10
            ColumnLayout {
                visible: root.validParts.indexOf("speed") >= 0
                Layout.column: root.columnFor("speed"); Layout.row: root.rowFor("speed")
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.preferredWidth: root.wide ? root.width * 0.29 : root.width * 0.53
                QGCLabel { Layout.fillWidth: true; text: qsTr("地速 / GROUND SPEED"); color: "#97B8C5"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 12 }
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.max(100, Math.min(root.wide ? root.width * 0.27 : root.width * 0.44, root.wide ? 270 : 220))
                    Layout.preferredHeight: width
                    HQFlightDial {
                        objectName: "compositeSpeedDial"
                        anchors.fill: parent; visible: !root.angularSpeed && !(root.dashboard && root.dashboard.floatingEntry("groundSpeed"))
                        value: root.speed; maximum: root.speedMaximum; majorIntervals: root.speedIntervals
                        valueText: root.display(root.speed, 1); unit: root.speedUnit
                        skin: root.theme.skin; accent: root.theme.accent
                        badge: root.theme.name
                        modeToken: root.followMode && root.flightMode ? root.modeKey : ""
                        animationsEnabled: root.animationsEnabled
                    }
                    HQAngularSpeed { anchors.fill: parent; visible: root.angularSpeed && !(root.dashboard && root.dashboard.floatingEntry("groundSpeed")); value: root.speed; maximum: root.speedMaximum; unit: root.speedUnit; accent: root.theme.accent; theme: root.theme }
                    QGCLabel {
                        anchors.centerIn: parent
                        visible: !!root.dashboard && !!root.dashboard.floatingEntry("groundSpeed")
                        text: qsTr("已移到主界面")
                        color: "#9DB9C9"
                    }
                    HQInstrumentDragArea {
                        objectName: "compositeDrag-groundSpeed"
                        anchors.fill: parent
                        dashboard: root.dashboard
                        instrumentKey: "groundSpeed"
                    }
                }
                QGCLabel { Layout.fillWidth: true; text: !isFinite(root.speed) ? qsTr("等待数据 / 数据已过期") : root.speed > root.speedMaximum ? qsTr("超出显示量程 · 数值仍为实际值") : Theme.chineseName(root.modeKey); color: root.speed > root.speedMaximum ? "#FFBC61" : root.theme.accent; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
            }
            Rectangle {
                id: centerPanel
                visible: root.validParts.indexOf("center") >= 0
                Layout.column: root.columnFor("center")
                Layout.row: root.rowFor("center")
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumHeight: 225
                Layout.preferredWidth: root.width * 0.4
                color: "#0B1823"; radius: 8; border.color: root.theme.accent
                ColumnLayout {
                    visible: root.centerMode === 0
                    anchors.fill: parent; anchors.margins: 14
                    QGCLabel { Layout.fillWidth: true; text: qsTr("目标航点 / NEXT WAYPOINT"); color: root.theme.accent; font.pixelSize: 12; elide: Text.ElideRight }
                    HQAnimatedNumber { objectName: "waypointReadout"; Layout.fillWidth: true; Layout.fillHeight: true; value: root.waypoint; decimals: 0; prefix: "WP "; animationsEnabled: root.animationsEnabled; minimumInterval: 0; travel: font.pixelSize * 0.20; jumpScale: 1.055; color: "#F5E7D0"; font.pixelSize: Math.min(48, root.width * 0.065); font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    HQAnimatedNumber { Layout.fillWidth: true; value: root.distance; prefix: qsTr("距目标  "); suffix: " m"; animationsEnabled: root.animationsEnabled; color: "#DFECF0"; font.pixelSize: Math.max(14, Math.min(20, centerPanel.width * 0.085)); elide: Text.ElideRight }
                    HQAnimatedNumber { Layout.fillWidth: true; value: root.altitude; prefix: qsTr("相对高度  "); suffix: " m"; animationsEnabled: root.animationsEnabled; color: "#A3BDCB"; elide: Text.ElideRight }
                }
                ColumnLayout {
                    visible: root.centerMode === 2
                    anchors.fill: parent; anchors.margins: 14; spacing: 12
                    QGCLabel { text: qsTr("飞行概览 / FLIGHT STATUS"); color: "#66DAEB"; font.pixelSize: 12 }
                    Repeater {
                        model: 4
                        delegate: HQAnimatedNumber {
                            required property int index
                            Layout.fillWidth: true; Layout.fillHeight: true
                            value: [root.altitude, root.climb, root.heading, root.battery][index]
                            prefix: [qsTr("相对高度  "), qsTr("爬升率  "), qsTr("航向  "), qsTr("飞控电量  ")][index]
                            suffix: [" m", " m/s", "°", "%"][index]
                            decimals: index < 2 ? 1 : 0
                            animationsEnabled: root.animationsEnabled
                            color: "#E6EDF0"; font.pixelSize: Math.min(20, root.width * 0.036); verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
                Canvas {
                    id: radar
                    objectName: "compositeRadar"
                    visible: root.centerMode === 1
                    anchors.fill: parent; anchors.margins: 10
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onVisibleChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        const cx = width / 2, cy = height / 2, radius = Math.min(width, height) * 0.36
                        if (!isFinite(radius) || radius <= 0) return
                        ctx.strokeStyle = "#294553"; ctx.lineWidth = 1
                        for (let i = 1; i <= 4; ++i) { ctx.beginPath(); ctx.arc(cx, cy, radius * i / 4, 0, Math.PI * 2); ctx.stroke() }
                        for (let i = 0; i < 8; ++i) { const a = i * Math.PI / 4; ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx + Math.sin(a) * radius, cy - Math.cos(a) * radius); ctx.stroke() }
                        ctx.fillStyle = "#8CB6C4"; ctx.font = "11px \'" + ScreenTools.normalFontFamily + "\'"; ctx.textAlign = "center"
                        ctx.fillText("前 / FRONT", cx, 13); ctx.fillText(root.radarRange + " m", cx, height - 28)
                        ctx.fillStyle = "#67DCEC"; ctx.beginPath(); ctx.moveTo(cx, cy - 9); ctx.lineTo(cx - 6, cy + 6); ctx.lineTo(cx + 6, cy + 6); ctx.closePath(); ctx.fill()
                        if (!root.radarAvailable || root.radarNeedsHeading) return
                        for (let i = 0; i < root.obstacles.length; ++i) {
                            const point = root.obstacles[i], a = point.bearing * Math.PI / 180
                            const r = Math.min(1, point.distance / root.radarRange) * radius
                            ctx.fillStyle = point.distance <= root.warningDistance ? "#FF705E" : "#FFC278"
                            ctx.beginPath(); ctx.arc(cx + Math.sin(a) * r, cy - Math.cos(a) * r, 4, 0, Math.PI * 2); ctx.fill()
                        }
                    }
                }
                QGCLabel {
                    objectName: "compositeRadarStatus"
                    visible: root.centerMode === 1
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                    width: parent.width - 12; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    text: !root.radarAvailable ? qsTr("未收到有效避障遥测") : root.radarNeedsHeading ? qsTr("等待航向 · 无法转换北向坐标") : root.obstacles.length === 0 ? qsTr("无有效障碍读数 · 未知方向不代表安全") : qsTr("读数：") + root.obstacles.length + qsTr(" · 最近 ") + Math.min.apply(null, root.obstacles.map(function(point) { return point.distance })).toFixed(1) + " m"
                    font.pixelSize: 10; color: "#C8D9E0"
                }
            }
            HQLinearInstrument {
                visible: root.validParts.indexOf("altitude") >= 0
                Layout.column: root.columnFor("altitude"); Layout.row: root.rowFor("altitude")
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 225
                value: root.altitude; accent: root.theme.accent; animationsEnabled: root.animationsEnabled
                HQInstrumentDragArea {
                    objectName: "compositeDrag-altitudeRelative"
                    anchors.fill: parent
                    dashboard: root.dashboard
                    instrumentKey: "altitudeRelative"
                }
            }
            Rectangle {
                visible: root.validParts.indexOf("mode") >= 0
                Layout.column: root.columnFor("mode")
                Layout.row: root.rowFor("mode")
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.preferredWidth: root.width * 0.27
                Layout.minimumHeight: 225
                color: root.theme.face === "red" ? "#300E1B" : "#0C1822"; radius: root.theme.face === "red" ? Math.min(width, height) * 0.2 : 6 + root.theme.graph % 4 * 4; border.color: root.theme.accent
                Rectangle { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 3; height: parent.height * 0.6; color: root.theme.accent }
                Canvas {
                    anchors.fill: parent
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.strokeStyle = "#26404F"; ctx.lineWidth = 1
                        ctx.beginPath(); ctx.moveTo(12, height * 0.18); ctx.lineTo(12, 26); ctx.lineTo(28, 12); ctx.lineTo(width - 28, 12); ctx.lineTo(width - 12, 26); ctx.lineTo(width - 12, height * 0.18); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(12, height * 0.82); ctx.lineTo(12, height - 26); ctx.lineTo(28, height - 12); ctx.lineTo(width - 28, height - 12); ctx.lineTo(width - 12, height - 26); ctx.lineTo(width - 12, height * 0.82); ctx.stroke()
                    }
                }
                Column {
                    anchors.centerIn: parent; width: parent.width - 16; spacing: 10
                    opacity: root.reveal
                    QGCLabel { width: parent.width; text: qsTr("飞行模式 / MODE"); horizontalAlignment: Text.AlignHCenter; color: "#97B8C5"; font.pixelSize: 12 }
                    Canvas {
                        id: modeIcon
                        property bool painted: false
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 36; height: 36
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        Component.onCompleted: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d"), graph = root.theme.graph
                            ctx.clearRect(0,0,width,height); ctx.save(); ctx.scale(width/36,height/36)
                            ctx.strokeStyle = root.theme.accent; ctx.lineWidth = 2; ctx.lineCap = "round"; ctx.lineJoin = "round"
                            ctx.beginPath()
                            // Native vector mode badges avoid platform/font-dependent
                            // missing-symbol boxes on Android and Windows.
                            if (graph === 0) { ctx.moveTo(18,4); ctx.lineTo(32,18); ctx.lineTo(18,32); ctx.lineTo(4,18); ctx.closePath(); ctx.moveTo(9,18); ctx.lineTo(27,18) }
                            else if (graph === 1) { ctx.moveTo(7,10); ctx.lineTo(29,10); ctx.moveTo(7,26); ctx.lineTo(29,26); ctx.moveTo(18,4); ctx.lineTo(18,32); ctx.moveTo(14,8); ctx.lineTo(18,4); ctx.lineTo(22,8); ctx.moveTo(14,28); ctx.lineTo(18,32); ctx.lineTo(22,28) }
                            else if (graph === 2) { ctx.arc(18,18,10,0,Math.PI*2); ctx.moveTo(18,1); ctx.lineTo(18,9); ctx.moveTo(18,27); ctx.lineTo(18,35); ctx.moveTo(1,18); ctx.lineTo(9,18); ctx.moveTo(27,18); ctx.lineTo(35,18) }
                            else if (graph === 3) { ctx.moveTo(5,18); ctx.lineTo(18,6); ctx.lineTo(31,18); ctx.moveTo(10,16); ctx.lineTo(10,31); ctx.lineTo(26,31); ctx.lineTo(26,16); ctx.moveTo(14,31); ctx.lineTo(14,22); ctx.lineTo(22,22); ctx.lineTo(22,31) }
                            else if (graph === 4) { ctx.moveTo(5,28); ctx.lineTo(18,8); ctx.lineTo(30,22); ctx.moveTo(2,25); ctx.rect(2,25,6,6); ctx.moveTo(15,5); ctx.rect(15,5,6,6); ctx.moveTo(27,19); ctx.rect(27,19,6,6) }
                            else if (graph === 5) { ctx.moveTo(18,18); ctx.bezierCurveTo(4,-2,-5,36,18,18); ctx.bezierCurveTo(39,-2,42,36,18,18) }
                            else if (graph === 6) { ctx.moveTo(20,4); ctx.lineTo(6,4); ctx.lineTo(6,32); ctx.lineTo(20,32); ctx.moveTo(13,18); ctx.lineTo(32,18); ctx.moveTo(25,11); ctx.lineTo(32,18); ctx.lineTo(25,25) }
                            else if (graph === 7 || graph === 14) { const upward = graph === 14, tip = upward ? 4 : 27, base = upward ? 27 : 4; ctx.moveTo(18,base); ctx.lineTo(18,tip); ctx.moveTo(11,upward ? 11 : 20); ctx.lineTo(18,tip); ctx.lineTo(25,upward ? 11 : 20); ctx.moveTo(6,32); ctx.lineTo(30,32) }
                            else if (graph === 8) { ctx.moveTo(11,3); ctx.lineTo(25,3); ctx.lineTo(33,11); ctx.lineTo(33,25); ctx.lineTo(25,33); ctx.lineTo(11,33); ctx.lineTo(3,25); ctx.lineTo(3,11); ctx.closePath(); ctx.moveTo(11,18); ctx.lineTo(25,18) }
                            else if (graph === 9) { ctx.arc(18,18,12,.3,Math.PI*2); ctx.moveTo(30,18); ctx.lineTo(25,13); ctx.moveTo(30,18); ctx.lineTo(34,13) }
                            else if (graph === 10 || graph === 12) { ctx.moveTo(5,8); ctx.lineTo(15,18); ctx.lineTo(5,28); ctx.moveTo(17,8); ctx.lineTo(27,18); ctx.lineTo(17,28); if (graph === 12) { ctx.moveTo(32,13); ctx.lineTo(32,23) } }
                            else if (graph === 11) { ctx.moveTo(7,7); ctx.lineTo(29,29); ctx.moveTo(29,7); ctx.lineTo(7,29) }
                            else if (graph === 13) { ctx.moveTo(6,29); ctx.lineTo(30,6); ctx.lineTo(30,18); ctx.moveTo(30,6); ctx.lineTo(18,6); ctx.moveTo(5,16); ctx.lineTo(14,16); ctx.moveTo(20,30); ctx.lineTo(20,22) }
                            else if (graph === 15) { ctx.arc(18,18,10,0,Math.PI*2); ctx.moveTo(18,8); ctx.lineTo(18,2); ctx.moveTo(8,22); ctx.lineTo(2,29); ctx.moveTo(28,22); ctx.lineTo(34,29); ctx.moveTo(21,18); ctx.arc(18,18,3,0,Math.PI*2) }
                            ctx.stroke(); ctx.restore(); painted = true
                        }
                    }
                    QGCLabel { width: parent.width; text: root.flightMode || "--"; horizontalAlignment: Text.AlignHCenter; color: root.theme.accent; font.pixelSize: Math.min(30, root.width * 0.043); font.weight: Font.DemiBold; wrapMode: Text.WrapAnywhere }
                    QGCLabel { width: parent.width; text: Theme.chineseName(root.modeKey); horizontalAlignment: Text.AlignHCenter; color: "#E3D5C1"; font.pixelSize: 16 }
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: parent.width * 0.65; height: 1; color: "#4B6070" }
                }
            }
        }
        QGCLabel { visible: root.validParts.length === 0; Layout.fillWidth: true; Layout.fillHeight: true; text: qsTr("请在“选择仪表”中勾选综合仪表模块。"); color: "#9AB6C7"; wrapMode: Text.WordWrap }
    }
    Connections {
        target: root
        function onThemeChanged() { modeIcon.requestPaint() }
        function onObstaclesChanged() { radar.requestPaint() }
        function onRadarAvailableChanged() { radar.requestPaint() }
        function onRadarNeedsHeadingChanged() { radar.requestPaint() }
        function onRadarRangeChanged() { radar.requestPaint() }
        function onWarningDistanceChanged() { radar.requestPaint() }
    }
}
