pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: root
    required property var hud
    property int currentPage: 0
    property var rcValues: []
    property var servoValues: []
    readonly property var pageTitles: [qsTr("快速"), qsTr("动作"), qsTr("消息"), qsTr("起飞检查"), qsTr("仪表"), qsTr("状态"), qsTr("通道"), qsTr("日志")]
    readonly property var modes: hud.connected && hud.vehicle.flightModes ? Array.from(hud.vehicle.flightModes) : []
    readonly property var quickReadings: [
        {title: qsTr("相对高度"), key: "altitudeRelative", unit: "m", color: "#CFB2ED"},
        {title: qsTr("GPS HDOP"), key: "gpsHdop", unit: "", color: "#F0BD8F"},
        {title: qsTr("横滚"), key: "roll", unit: "°", color: "#FFCE68"},
        {title: qsTr("地速"), key: "groundSpeed", unit: "m/s", color: "#8CD7C5"},
        {title: qsTr("离家距离"), key: "distanceToHome", unit: "m", color: "#F08F94"},
        {title: qsTr("航向"), key: "heading", unit: "°", color: "#A5E992"}
    ]
    readonly property var instrumentReadings: [
        {title: qsTr("横滚 Roll"), key: "roll", unit: "°"}, {title: qsTr("俯仰 Pitch"), key: "pitch", unit: "°"},
        {title: qsTr("航向 Heading"), key: "heading", unit: "°"}, {title: qsTr("空速"), key: "airSpeed", unit: "m/s"},
        {title: qsTr("地速"), key: "groundSpeed", unit: "m/s"}, {title: qsTr("爬升率"), key: "climbRate", unit: "m/s"},
        {title: qsTr("相对高度"), key: "altitudeRelative", unit: "m"}, {title: qsTr("电池电压"), key: "batteryVoltage", unit: "V"},
        {title: qsTr("电池电流"), key: "batteryCurrent", unit: "A"}, {title: qsTr("剩余电量"), key: "batteryPercent", unit: "%"}
    ]
    readonly property var actions: [
        {name: qsTr("解锁"), key: "Arm", show: "showArm"}, {name: qsTr("锁定"), key: "Disarm", show: "showDisarm"},
        {name: qsTr("起飞"), key: "Takeoff", show: "showTakeoff"}, {name: qsTr("返航"), key: "RTL", show: "showRTL"},
        {name: qsTr("降落"), key: "Land", show: "showLand"}, {name: qsTr("暂停"), key: "Pause", show: "showPause"},
        {name: qsTr("执行任务"), key: "StartMission", show: "showStartMission"}, {name: qsTr("继续任务"), key: "ContinueMission", show: "showContinueMission"},
        {name: qsTr("修改高度"), key: "ChangeAlt", show: "showChangeAlt"}, {name: qsTr("修改速度"), key: "ChangeSpeed", show: "showChangeSpeed"}
    ]
    color: "#14191F"
    clip: true

    Connections {
        target: root.hud.vehicle
        ignoreUnknownSignals: true
        function onRcChannelsRawChanged(channelValues) { root.rcValues = Array.from(channelValues) }
        function onServoOutputsChanged(servoValues) { root.servoValues = Array.from(servoValues) }
    }
    Connections {
        target: root.hud
        function onVehicleChanged() { root.rcValues = []; root.servoValues = [] }
        function onConnectedChanged() { if (!root.hud.connected) { root.rcValues = []; root.servoValues = [] } }
    }
    function choosePage(index) { if (index >= 0 && index < pageTitles.length) currentPage = index }
    onCurrentPageChanged: pageMotion.reveal()
    HQPageMotion { id: pageMotion; targetItem: dataScroll; translation: pageTranslation }
    function reading(key) {
        if (key === "heading") return hud.headingText(hud.heading)
        if (key === "gpsHdop") return hud.available("gps1") ? hud.format(Number(hud.vehicle.gps.hdop.rawValue), 2) : "--"
        if (key === "batteryVoltage") return hud.format(hud.batteryVoltage, 2)
        if (key === "batteryCurrent") return hud.format(hud.batteryCurrent)
        if (key === "batteryPercent") return hud.format(hud.batteryPercent, 0)
        return hud.format(hud.numberFor(key))
    }
    function channelText(values, index, available) {
        const value = index < values.length ? Number(values[index]) : NaN
        return available && isFinite(value) && value > 0 && value < 65535 ? value.toFixed(0) : "--"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Flickable {
            id: tabs
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(40, ScreenTools.minTouchPixels)
            contentWidth: tabRow.width
            contentHeight: height
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick
            clip: true
            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded; height: 3 }
            Row {
                id: tabRow
                height: tabs.height
                Repeater {
                    model: root.pageTitles
                    Button {
                        id: pageTab
                        required property string modelData
                        required property int index
                        objectName: "hudDataTab-" + index
                        width: Math.max(64, implicitWidth)
                        height: tabRow.height
                        text: modelData
                        padding: 10
                        font.pixelSize: Math.max(12, ScreenTools.defaultFontPixelHeight * 0.77)
                        onClicked: root.choosePage(index)
                        background: Rectangle {
                            color: root.currentPage === pageTab.index ? "#35556D" : pageTab.down ? "#34414D" : "#242E38"
                            border.color: "#455768"
                            border.width: 0.5
                            Behavior on color { ColorAnimation { duration: 140 } }
                            HQButtonRipple { control: pageTab }
                        }
                        contentItem: Text { text: parent.text; color: root.currentPage === parent.index ? "#FFFFFF" : "#CCD8E1"; font: parent.font; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter }
                    }
                }
            }
        }

        ScrollView {
            id: dataScroll
            objectName: "hudDataScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            transform: Translate { id: pageTranslation }
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ColumnLayout {
                width: dataScroll.availableWidth
                spacing: 7

                GridLayout {
                    visible: root.currentPage === 0
                    Layout.fillWidth: true
                    Layout.margins: 8
                    columns: root.width > 580 ? 3 : 2
                    columnSpacing: 8
                    rowSpacing: 8
                    Repeater {
                        model: root.quickReadings
                        ColumnLayout {
                            id: quickReading
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 2
                            QGCLabel { text: quickReading.modelData.title; color: "#C4CFD6"; font.pixelSize: Math.max(11, ScreenTools.defaultFontPixelHeight * 0.72) }
                            RowLayout {
                                QGCLabel { text: root.reading(quickReading.modelData.key); color: quickReading.modelData.color; font.pixelSize: Math.max(19, Math.min(30, root.width / 17)); font.weight: Font.Medium }
                                QGCLabel { text: quickReading.modelData.unit; color: "#A7B5C0"; font.pixelSize: 11; Layout.alignment: Qt.AlignBottom }
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: root.currentPage === 1
                    Layout.fillWidth: true
                    Layout.margins: 8
                    QGCLabel { Layout.fillWidth: true; text: qsTr("操作仅作用于当前主调试飞控，执行前沿用地面站确认流程。"); color: "#C5D3DE"; wrapMode: Text.WordWrap; font.pointSize: ScreenTools.smallFontPointSize }
                    QGCComboBox {
                        objectName: "hudFlightModeChoice"
                        Layout.fillWidth: true
                        model: root.modes
                        currentIndex: root.hud.connected ? root.modes.indexOf(root.hud.vehicle.flightMode) : -1
                        enabled: root.hud.connected && root.hud.vehicle.flightModeSetAvailable && root.modes.length > 0
                        onActivated: index => { if (index >= 0 && index < root.modes.length) root.hud.flightModeRequested(root.modes[index]) }
                        Accessible.name: qsTr("切换当前飞控的飞行模式")
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.width > 540 ? 3 : 2
                        Repeater {
                            model: root.actions
                            QGCButton {
                                required property var modelData
                                objectName: "hudAction-" + modelData.key
                                Layout.fillWidth: true
                                text: modelData.name
                                enabled: root.hud.connected && !!root.hud.guidedController && !!root.hud.guidedController[modelData.show]
                                onClicked: root.hud.actionRequested(modelData.key)
                            }
                        }
                    }
                    QGCButton { Layout.fillWidth: true; text: qsTr("打开参数设置"); enabled: root.hud.connected; onClicked: root.hud.setupRequested("parameters") }
                }

                ColumnLayout {
                    visible: root.currentPage === 2
                    Layout.fillWidth: true
                    Layout.margins: 8
                    QGCLabel { Layout.fillWidth: true; visible: !root.hud.vehicle || !root.hud.vehicle.formattedMessages; text: qsTr("暂无飞控消息"); color: "#B5C4CD" }
                    TextEdit {
                        objectName: "hudMessageHistory"
                        Layout.fillWidth: true
                        Layout.preferredHeight: contentHeight
                        text: root.currentPage === 2 && root.hud.vehicle ? root.hud.vehicle.formattedMessages : ""
                        readOnly: true
                        selectByMouse: !ScreenTools.isMobile
                        textFormat: TextEdit.RichText
                        wrapMode: TextEdit.Wrap
                        color: "#E3ECF0"
                        font.family: root.hud.roundedFont
                        font.pixelSize: Math.max(12, ScreenTools.defaultFontPixelHeight * 0.78)
                    }
                }

                ColumnLayout {
                    visible: root.currentPage === 3
                    Layout.fillWidth: true
                    Layout.margins: 8
                    QGCButton { Layout.fillWidth: true; text: qsTr("打开起飞前检查单"); onClicked: root.hud.preflightRequested() }
                    QGCButton { Layout.fillWidth: true; text: qsTr("查看解锁检查与报错说明"); onClicked: root.hud.statusRequested() }
                    QGCLabel { Layout.fillWidth: true; text: root.hud.warning && root.hud.warning.text ? root.hud.warning.text : root.hud.connected ? qsTr("当前没有飞控告警；请继续完成起飞前检查。"): qsTr("请先连接飞控。"); color: "#F0C58F"; wrapMode: Text.WordWrap }
                    Repeater {
                        model: root.hud.available("sysStatus") && root.hud.vehicle.sysStatusSensorInfo ? root.hud.vehicle.sysStatusSensorInfo.sensorNames : []
                        RowLayout {
                            id: sensorStatus
                            required property string modelData
                            required property int index
                            Layout.fillWidth: true
                            QGCLabel { Layout.fillWidth: true; text: sensorStatus.modelData; color: "#D5E2E8"; wrapMode: Text.WordWrap }
                            QGCLabel { text: root.hud.vehicle.sysStatusSensorInfo.sensorStatus[sensorStatus.index]; color: "#D5E2E8" }
                        }
                    }
                }

                GridLayout {
                    visible: root.currentPage === 4
                    Layout.fillWidth: true
                    Layout.margins: 8
                    columns: 2
                    Repeater {
                        model: root.instrumentReadings
                        ColumnLayout {
                            id: instrumentReading
                            required property var modelData
                            Layout.fillWidth: true
                            QGCLabel { Layout.fillWidth: true; text: instrumentReading.modelData.title; color: "#AEBFC9"; font.pointSize: ScreenTools.smallFontPointSize; wrapMode: Text.WordWrap }
                            QGCLabel { Layout.fillWidth: true; text: root.reading(instrumentReading.modelData.key) + " " + instrumentReading.modelData.unit; color: "#E4F1F5"; font.pixelSize: 19 }
                        }
                    }
                }
                RowLayout {
                    visible: root.currentPage === 4
                    Layout.fillWidth: true
                    Layout.margins: 8
                    QGCLabel { text: qsTr("HUD 高度基准"); color: "#BDCFD9" }
                    QGCComboBox {
                        objectName: "hudAltitudeReference"
                        Layout.fillWidth: true
                        model: [qsTr("相对高度 REL"), qsTr("海拔高度 AMSL")]
                        currentIndex: root.hud.altitudeReference
                        onActivated: index => root.hud.setAltitudeReference(index)
                    }
                }

                ColumnLayout {
                    visible: root.currentPage === 5
                    Layout.fillWidth: true
                    Layout.margins: 8
                    StatusLine { label: qsTr("连接"); value: root.hud.connected ? qsTr("已连接 · 飞控 %1").arg(root.hud.vehicle.id) : qsTr("未连接") }
                    StatusLine { label: qsTr("固件"); value: root.hud.vehicle ? root.hud.vehicle.firmwareTypeString : "--" }
                    StatusLine { label: qsTr("飞行模式"); value: root.hud.available("flightMode") ? root.hud.vehicle.flightMode : "--" }
                    StatusLine { label: qsTr("定位 / 卫星"); value: root.hud.available("gps1") ? String(root.hud.vehicle.gps.lock.enumOrValueString) + " / " + root.hud.satellites : "--" }
                    StatusLine { label: qsTr("GPS HDOP"); value: root.hud.available("gps1") ? root.hud.format(Number(root.hud.vehicle.gps.hdop.rawValue), 2) : "--" }
                    StatusLine { label: qsTr("遥控 RSSI"); value: root.hud.format(root.hud.numberFor("rcRSSI"), 0) + " %" }
                    StatusLine { label: qsTr("数传 RSSI"); value: root.hud.available("radioStatus") ? root.hud.format(Number(root.hud.vehicle.radioStatus.lrssi.rawValue), 0) : "--" }
                    StatusLine { label: qsTr("数传丢包"); value: root.hud.available("flightMode") ? root.hud.format(Number(root.hud.vehicle.mavlinkLossPercent), 1) + " %" : "--" }
                    StatusLine { label: qsTr("距离下一航点"); value: root.hud.format(root.hud.numberFor("distanceToNextWP")) + " m" }
                    RowLayout {
                        Layout.fillWidth: true
                        QGCButton { Layout.fillWidth: true; text: qsTr("EKF 详情"); onClicked: root.hud.openDiagnostics("ekf") }
                        QGCButton { Layout.fillWidth: true; text: qsTr("振动详情"); onClicked: root.hud.openDiagnostics("vibration") }
                    }
                }

                ColumnLayout {
                    visible: root.currentPage === 6
                    Layout.fillWidth: true
                    Layout.margins: 8
                    QGCLabel { text: qsTr("遥控输入 / RC · μs"); color: "#B5DCEB"; font.weight: Font.DemiBold }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.width >= 500 ? 3 : 2
                        Repeater {
                            model: 18
                            QGCLabel { required property int index; Layout.fillWidth: true; text: "RC " + (index + 1) + "  " + root.channelText(root.rcValues, index, root.hud.available("rcChannels")); color: "#D4E4EB"; font.pointSize: ScreenTools.smallFontPointSize }
                        }
                    }
                    QGCLabel { text: qsTr("输出通道 / Servo · μs"); color: "#B5DCEB"; font.weight: Font.DemiBold }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.width >= 500 ? 3 : 2
                        Repeater {
                            model: 16
                            QGCLabel { required property int index; Layout.fillWidth: true; text: "OUT " + (index + 1) + "  " + root.channelText(root.servoValues, index, root.hud.available("servoOutputs")); color: "#D4E4EB"; font.pointSize: ScreenTools.smallFontPointSize }
                        }
                    }
                    QGCLabel { Layout.fillWidth: true; text: qsTr("只显示飞控上报值，不发送遥控覆盖或执行器指令。"); color: "#A3B6C1"; wrapMode: Text.WordWrap; font.pointSize: ScreenTools.smallFontPointSize }
                }

                ColumnLayout {
                    visible: root.currentPage === 7
                    Layout.fillWidth: true
                    Layout.margins: 8
                    QGCButton { Layout.fillWidth: true; text: qsTr("打开日志查看与机载日志下载"); onClicked: root.hud.logsRequested() }
                    StatusLine { label: qsTr("收到消息"); value: root.hud.connected ? String(root.hud.vehicle.mavlinkReceivedCount) : "--" }
                    StatusLine { label: qsTr("发送消息"); value: root.hud.connected ? String(root.hud.vehicle.mavlinkSentCount) : "--" }
                    StatusLine { label: qsTr("丢失消息"); value: root.hud.connected ? String(root.hud.vehicle.mavlinkLossCount) : "--" }
                    QGCLabel { Layout.fillWidth: true; text: qsTr("日志分析、遥测回放和飞控日志下载沿用“分析”页面。"); color: "#BECBD4"; wrapMode: Text.WordWrap }
                }
                Item { Layout.preferredHeight: 6 }
            }
        }
    }

    component StatusLine: RowLayout {
        property string label
        property string value
        Layout.fillWidth: true
        QGCLabel { text: parent.label; color: "#AFC2CE"; Layout.preferredWidth: Math.min(150, root.width * 0.45); wrapMode: Text.WordWrap }
        QGCLabel { text: parent.value; color: "#E3EDF2"; Layout.fillWidth: true; wrapMode: Text.WordWrap }
    }
}
