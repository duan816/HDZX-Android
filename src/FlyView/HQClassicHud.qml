pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import "HQWarningPresentation.js" as WarningPresentation

Rectangle {
    id: root
    required property var hud
    // The compact aircraft card lists these extra numbers below its instruments.
    // Preserve the horizon, latest warning and diagnostic buttons in short maps.
    property bool compact: false
    readonly property real labelSize: Math.max(11 * ScreenTools.mobileUiScale, Math.min(17 * ScreenTools.mobileUiScale, width / 31))
    readonly property bool ekfAvailable: hud.available("estimatorStatus")
    readonly property bool vibrationAvailable: hud.available("vibration")
    readonly property var estimator: hud.vehicle ? hud.vehicle.estimatorStatus : null
    readonly property bool ekfAttitudeGood: ekfAvailable && estimator && estimator.goodAttitudeEstimate.rawValue
    readonly property bool ekfWarning: {
        if (!ekfAvailable || !estimator) return false
        if (!ekfAttitudeGood || estimator.gpsGlitch.rawValue
            || (estimator.reportType === "ESTIMATOR_STATUS" && estimator.accelError.rawValue)
            || (estimator.reportType === "EKF_STATUS_REPORT" && (Number(estimator.rawFlags.rawValue) & 1024))) return true
        for (const key of ["velRatio", "horizPosRatio", "vertPosRatio", "magRatio", "haglRatio", "tasRatio"]) {
            const value = Number(estimator[key].rawValue)
            if (isFinite(value) && value >= 0.8) return true
        }
        return false
    }
    readonly property var warningRows: hud.connected && hud.vehicle && hud.vehicle.recentWarnings ? hud.vehicle.recentWarnings : []
    readonly property var transientWarning: hud.connected && hud.vehicle
        ? WarningPresentation.speaking(QGroundControl.speakingAlert, hud.vehicle.id, warningRows) : null
    readonly property string warningText: transientWarning ? transientWarning.text : ""
    readonly property int gpsFixType: !hud.available("gps1") || !hud.vehicle || !hud.vehicle.gps ? -1
        : hud.vehicle.gps.fixType !== undefined ? hud.vehicle.gps.fixType : Number(hud.vehicle.gps.lock.rawValue)
    readonly property string gpsFix: [qsTr("无定位"), qsTr("无定位"), qsTr("2D定位"), qsTr("3D定位"),
        qsTr("差分定位"), qsTr("RTK 浮点解"), qsTr("RTK 固定解"), qsTr("静态定位"), qsTr("PPP定位")][gpsFixType] || "--"

    property string localTime: Qt.formatTime(new Date(), "hh:mm:ss")
    signal ekfRequested()
    signal vibrationRequested()
    signal statusRequested()
    color: "#27313A"
    clip: true
    Timer { interval: 1000; repeat: true; running: root.visible && root.hud.visible && root.hud.expanded; onTriggered: root.localTime = Qt.formatTime(new Date(), "hh:mm:ss") }

    RowLayout {
        z: 1
        visible: !root.compact
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Math.max(27, parent.height * 0.10)
        anchors.leftMargin: 7
        anchors.rightMargin: 7
        QGCLabel { Layout.fillWidth: true; text: "RC " + root.hud.format(root.hud.numberFor("rcRSSI"), 0) + "%"; color: "#FFFFFF"; font.pixelSize: root.labelSize * 0.78; style: Text.Outline; styleColor: "#22354B" }
        QGCLabel { text: qsTr("本机 ") + root.localTime; color: "#FFFFFF"; font.pixelSize: root.labelSize * 0.78; style: Text.Outline; styleColor: "#22354B" }
    }

    HQHudScene {
        objectName: "hudRetainedScene"
        anchors.fill: parent
        hud: root.hud
        labelSize: root.labelSize
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.34
        width: parent.width * 0.66
        spacing: 2
        QGCLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: !root.hud.connected ? qsTr("未连接") : !root.hud.available("flightMode") ? qsTr("状态未上报") : root.hud.vehicle.armed ? qsTr("已解锁") : qsTr("已锁定")
            color: !root.hud.connected ? "#E3E8EC" : root.hud.vehicle.armed ? "#FFEE67" : "#FD4030"
            font.weight: Font.Bold
            font.pixelSize: root.labelSize * 1.45
            style: Text.Outline
            styleColor: "#29323C"
        }
        QGCLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: !root.hud.connected ? "" : !root.hud.available("sysStatus") ? qsTr("解锁检查待上报") : root.hud.vehicle.readyToFlyAvailable ? (root.hud.vehicle.readyToFly ? qsTr("准备就绪") : qsTr("尚未就绪")) : root.hud.vehicle.healthAndArmingCheckReport && root.hud.vehicle.healthAndArmingCheckReport.supported ? (root.hud.vehicle.healthAndArmingCheckReport.canArm ? qsTr("允许解锁") : qsTr("解锁检查未通过")) : qsTr("点击查看解锁检查")
            color: "#FFEEAE"
            font.pixelSize: root.labelSize * 0.85
            style: Text.Outline
            styleColor: "#29323C"
        }
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: statusRow.top
        anchors.margins: 7
        spacing: 2
        QGCLabel {
            objectName: "hudLatestWarning"
            Layout.fillWidth: true
            visible: root.warningText.length > 0
            text: root.transientWarning ? qsTr("正在播报") + "\n" + WarningPresentation.bilingual(root.transientWarning) : ""
            color: "#FF3030"
            font.pixelSize: root.labelSize * 1.15
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            style: Text.Outline
            styleColor: "#220C14"
            MouseArea { anchors.fill: parent; onClicked: root.statusRequested() }
        }
        RowLayout {
            visible: !root.compact
            Layout.fillWidth: true
            QGCLabel { Layout.fillWidth: true; text: qsTr("空速 %1 · 地速 %2 m/s").arg(root.hud.format(root.hud.airSpeed)).arg(root.hud.format(root.hud.groundSpeed)); color: "white"; font.pixelSize: root.labelSize * 0.85; style: Text.Outline; styleColor: "#26332C"; elide: Text.ElideRight }
            QGCLabel { text: qsTr("升降 %1").arg(root.hud.format(root.hud.climbRate)); color: "white"; font.pixelSize: root.labelSize * 0.85; style: Text.Outline; styleColor: "#26332C" }
        }
        RowLayout {
            visible: !root.compact
            Layout.fillWidth: true
            QGCLabel { Layout.fillWidth: true; text: qsTr("电池 %1 V  %2 A  %3%").arg(root.hud.format(root.hud.batteryVoltage, 2)).arg(root.hud.format(root.hud.batteryCurrent)).arg(root.hud.format(root.hud.batteryPercent, 0)); color: "#FFFFFF"; font.pixelSize: root.labelSize * 0.85; style: Text.Outline; styleColor: "#26332C"; elide: Text.ElideRight }
            QGCLabel { text: root.hud.available("flightMode") ? root.hud.vehicle.flightMode : "--"; color: "#FFF7CF"; font.pixelSize: root.labelSize * 0.85; style: Text.Outline; styleColor: "#26332C"; Layout.maximumWidth: root.width * 0.35; elide: Text.ElideRight }
        }
    }

    RowLayout {
        id: statusRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 0
        height: Math.max(36 * ScreenTools.mobileUiScale, ScreenTools.minTouchPixels)
        HudStatusButton { objectName: "hudEkfButton"; text: root.ekfAvailable ? (root.ekfWarning ? "EKF !" : "EKF ✓") : "EKF --"; accent: root.ekfAvailable ? (root.ekfWarning ? "#FFB976" : "#95E9A0") : "#CBD2D8"; onClicked: root.ekfRequested() }
        HudStatusButton { objectName: "hudVibeButton"; text: root.vibrationAvailable ? "Vibe" : "Vibe --"; accent: root.vibrationAvailable ? "#C3E7D0" : "#CBD2D8"; onClicked: root.vibrationRequested() }
        HudStatusButton { objectName: "hudGpsButton"; text: "GPS " + root.gpsFix + (root.hud.satellites >= 0 ? " / " + root.hud.satellites : ""); accent: root.hud.available("gps1") && root.hud.vehicle.gps && root.gpsFixType >= 3 ? "#B5EEA3" : "#F7CB8A"; onClicked: root.statusRequested() }
    }
    component HudStatusButton: Button {
        property color accent: "white"
        Layout.fillWidth: true
        Layout.fillHeight: true
        font.pixelSize: root.labelSize * 0.9
        padding: 2
        background: Rectangle { color: parent.down ? "#EB35495A" : "#CA152638"; border.color: "#617286"; border.width: 0.5 }
        contentItem: Text { text: parent.text; color: parent.accent; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        Accessible.name: text + qsTr("，查看详情")
    }
}
